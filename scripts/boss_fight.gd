extends MenuScreen
## The fight against the chosen boss. Everything every fight has is here: the boss's
## background and figure in the middle, the heroes at their seats, the round, the boss's
## health and shields, and buttons to give up and for the settings. What is special about
## a boss comes from its script in scripts/bosses/.
##
## The rules are in Fight. This screen shows what goes on in it, and passes on what the
## players do: confirming messages, tapping heroes and buttons, and showing cards.

const GAME_OVER_SCENE := "res://game_over.tscn"
const CARDS_PATH := "res://cards/cards.json"
## A code seen this recently is taken to be still in view, as the camera reads a card
## that stays in view over and over. It has to leave for this long to count again.
const STILL_IN_VIEW_MSEC := 2000
const NOTICE_SEC := 3.0
## How long the boss's health takes to count up at the start.
const HEALTH_COUNT_SEC := 1.2
const BADGE_ICON_SIZE := 30
const SHIELD_ICON_SIZE := 40
## How long the shields take to rise, one after the other, each counting up. Messages wait
## meanwhile.
const SHIELD_APPEAR_SEC := 0.35
const SHIELD_STAGGER_SEC := 0.2
const SHIELD_COUNT_SEC := 0.6
const SHIELD_BANNER_SEC := 1.4
const HIT_COLOR := Color(1.0, 0.36, 0.28)
const TOKEN_ICONS := {
	"poison": "res://assets/fight/icon_poison.svg",
	"panic": "res://assets/fight/icon_panic.svg",
	"paralysis": "res://assets/fight/icon_paralysis.svg",
	"fire": "res://assets/fight/icon_fire.svg",
}
const SHIELD_ICONS := {
	"melee": "res://assets/fight/icon_melee.svg",
	"ranged": "res://assets/fight/icon_ranged.svg",
	"magic": "res://assets/fight/icon_magic.svg",
}

const CONFIRM_DIALOG := preload("res://confirm_dialog.tscn")
const GIVE_UP_FADE_SEC := 0.7
const BANNER_SEC := 3.0
## Messages wait while the boss is introduced.
const INTRO_SEC := 1.6
const TEXT := {
	"give_up_title": { "de": "Kampf beenden?", "en": "End the fight?" },
	"give_up_message": {
		"de": "Ist ein Held gefallen? Dann hat der Boss gewonnen. Ihr könnt den Kampf auch ohne Ergebnis abbrechen.",
		"en": "Has a hero fallen? Then the boss has won. You can also stop the fight without a result.",
	},
	"we_lost": { "de": "Wir haben verloren", "en": "We have lost" },
	"abort": { "de": "Kampf abbrechen", "en": "Stop the fight" },
	"keep_fighting": { "de": "Weiterkämpfen", "en": "Keep fighting" },
	"shields_raised": { "de": "Schilde", "en": "Shields" },
	"no_shields": { "de": "Keine Schilde", "en": "No shields" },
}
## The particles over the background, by Boss.Ambience. Areas are in parts of the screen.
const AMBIENCES := {
	Boss.Ambience.EMBERS: {
		"amount": 28, "lifetime": 8.0, "area": Rect2(0.0, 1.0, 1.0, 0.0),
		"direction": Vector2(0, -1), "spread": 18.0, "speed": Vector2(25, 75),
		"gravity": Vector2(0, -3), "scale": Vector2(0.15, 0.5),
	},
	Boss.Ambience.FIREFLIES: {
		"amount": 22, "lifetime": 6.0, "area": Rect2(0.0, 0.2, 1.0, 0.8),
		"direction": Vector2(0, -1), "spread": 180.0, "speed": Vector2(6, 22),
		"gravity": Vector2.ZERO, "scale": Vector2(0.2, 0.45),
	},
	Boss.Ambience.DUST: {
		"amount": 40, "lifetime": 14.0, "area": Rect2(-0.1, 0.0, 1.0, 1.0),
		"direction": Vector2(1, 0.15), "spread": 20.0, "speed": Vector2(8, 26),
		"gravity": Vector2(0, 1), "scale": Vector2(0.08, 0.25),
	},
}

## Replaced by tests, so that they do not touch the real party.
var party_path := Party.SAVE_PATH
## Replaced by tests, which bring their own cards.
var cards_path := CARDS_PATH
var fight: Fight

var _cards: CardDatabase
var _banner_tween: Tween
var _give_up_dialog: ConfirmDialog
var _code_seen_msec := {}
var _notice_tween: Tween
var _prompt_tween: Tween
## By seat: the badge at each hero's seat, with the boss's attack.
var _badges := {}
## By damage type: the plate of each shield.
var _shield_plates := {}
var _camera_problem := ""
## The style of the HUD's plates, for the badges and shields.
var _plate: StyleBox

@onready var _background: TextureRect = $Background
@onready var _ambience: CPUParticles2D = $Ambience
@onready var _figure: TextureRect = $Figure
@onready var _seats: Array[Node] = $Seats.get_children()
@onready var _banner: Control = $Banner
@onready var _banner_text: Label = $Banner/Text
@onready var messages: MessageBox = $Messages
@onready var _give_up: BaseButton = $Hud/GiveUp/Button
@onready var _round: Label = $Hud/Round/Row/Value
@onready var _health: Label = $Hud/Health/Row/Value
@onready var _shields: HBoxContainer = $Shields
@onready var _prompt: Control = $Prompt
@onready var _prompt_text: RichTextLabel = $Prompt/Layout/Text
@onready var _notice: RichTextLabel = $Prompt/Layout/Notice
@onready var _buttons: HBoxContainer = $Prompt/Layout/Buttons
@onready var _scanner: QrCameraScanner = $QrCameraScanner


func _ready() -> void:
	super()
	# Only when run on its own, as from the editor.
	if not Bosses.has(Encounter.boss):
		Encounter.boss = Bosses.IDS[0]
	if not Bosses.DIFFICULTIES.has(Encounter.difficulty):
		Encounter.difficulty = Bosses.DEFAULT_DIFFICULTY
	var party := Party.load_file(party_path)
	_cards = CardDatabase.load_file(cards_path)
	fight = Fight.new(Bosses.create(Encounter.boss), Encounter.difficulty, party.heroes)
	fight.round_changed.connect(_on_round_changed)
	fight.health_changed.connect(_on_health_changed)
	fight.shields_changed.connect(_on_shields_changed)
	fight.shields_raised.connect(_on_shields_raised)
	fight.hero_changed.connect(_refresh_badge)
	fight.phase_changed.connect(_on_phase_changed)
	fight.turn_changed.connect(func(_hero: FightHero) -> void: _refresh_seats())
	fight.request_changed.connect(_on_request_changed)
	fight.message.connect(show_message)
	fight.notice.connect(show_notice)
	fight.boss_hit.connect(_on_boss_hit)
	fight.won.connect(_on_won)
	messages.all_confirmed.connect(_on_messages_read)

	_show_boss(fight.boss)
	_show_party(party)
	_plate = ($Hud/Round as PanelContainer).get_theme_stylebox("panel")
	_make_badges()
	_make_shields()
	for token: SeatToken in _seats:
		token.pressed.connect(_on_seat_pressed.bind(token.seat))
	_give_up.pressed.connect(go_back)
	_scanner.code_read.connect(_on_code_read)
	_scanner.failed.connect(_on_camera_failed)
	_scanner.camera_started.connect(_on_camera_started)
	resized.connect(_place_ambience)
	_place_ambience()
	_play_intro()
	fight.start()


func _exit_tree() -> void:
	super()
	# Lets the fight's rules stop waiting for players who have left.
	if fight != null:
		fight.abandon()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_prompt()


## Back does not leave a fight by accident: it asks whether the fight is lost, or to be
## stopped.
func go_back() -> void:
	if _leaving or _dialog_open() or is_instance_valid(_give_up_dialog):
		return
	var dialog: ConfirmDialog = CONFIRM_DIALOG.instantiate()
	dialog.name = "GiveUpDialog"
	dialog.title = _t("give_up_title")
	dialog.message = _t("give_up_message")
	dialog.confirm_text = _t("we_lost")
	dialog.extra_text = _t("abort")
	dialog.cancel_text = _t("keep_fighting")
	dialog.confirmed.connect(admit_defeat)
	dialog.extra_confirmed.connect(give_up)
	_give_up_dialog = dialog
	# The back button of a phone arrives while the tree passes it on, which is no time
	# to add to it.
	add_child.call_deferred(dialog)


## A hero has fallen: the fight is lost. Once the players have read so, the game is over.
func admit_defeat() -> void:
	fight.lose()


## Stops the fight without a result, and shows how far it got.
func give_up() -> void:
	fight.abandon()
	_game_over(GIVE_UP_FADE_SEC)


func _game_over(fade_sec: float) -> void:
	var screen: Node = load(GAME_OVER_SCENE).instantiate()
	screen.fight = fight
	leave_to(screen, fade_sec)


## Plays the card with this QR code, as if it had been shown to the camera. Returns what
## Fight.scan() returns.
func scan_code(code: String) -> String:
	return fight.scan(_cards.find(code))


## Shows a short note in the prompt for a while, such as why a card was not played.
func show_notice(id: String, values := {}) -> void:
	_notice.text = "[center]%s[/center]" % Messages.render(id, values, TranslationServer.get_locale(), _symbol_size(_notice)).body
	_notice.show()
	_notice.modulate.a = 1.0
	if _notice_tween != null:
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(NOTICE_SEC)
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 0.4)
	_notice_tween.tween_callback(_notice.hide)


## Shows a message large over the fight until the players confirm it. Messages that
## arrive meanwhile wait. The id is one from messages/<language>.json.
func show_message(id: String, values := {}) -> void:
	messages.tell(id, values)


## Shows text across the middle of the screen for a while, such as whose turn it is.
func show_banner(text: String, seconds := BANNER_SEC) -> void:
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_text.text = text
	_banner.show()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.3)
	_banner_tween.tween_interval(seconds)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)
	_banner_tween.tween_callback(_banner.hide)


func _t(key: String) -> String:
	return CardDatabase.localized(TEXT[key], TranslationServer.get_locale())


func _show_boss(boss: Boss) -> void:
	_background.texture = load(boss.background)
	(_background.material as ShaderMaterial).set_shader_parameter("mist_color", boss.mist_color)
	_figure.texture = load(boss.figure)
	var figure_material := _figure.material as ShaderMaterial
	figure_material.set_shader_parameter("seconds", boss.motion_seconds)
	var parameter: String = {
		Boss.Motion.BREATHE: "breathe",
		Boss.Motion.HOVER: "hover",
		Boss.Motion.SWAY: "sway",
	}[boss.motion]
	figure_material.set_shader_parameter(parameter, boss.motion_amount)

	var preset: Dictionary = AMBIENCES[boss.ambience]
	_ambience.amount = preset.amount
	_ambience.lifetime = preset.lifetime
	_ambience.preprocess = preset.lifetime
	_ambience.direction = preset.direction
	_ambience.spread = preset.spread
	_ambience.initial_velocity_min = preset.speed.x
	_ambience.initial_velocity_max = preset.speed.y
	_ambience.gravity = preset.gravity
	_ambience.scale_amount_min = preset.scale.x
	_ambience.scale_amount_max = preset.scale.y
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	ramp.colors = PackedColorArray([
		Color(boss.ambience_color, 0.0), Color(boss.ambience_color, 0.9),
		Color(boss.ambience_color, 0.6), Color(boss.ambience_color, 0.0),
	])
	_ambience.color_ramp = ramp


## The particles fill the area of their preset on any shape of screen.
func _place_ambience() -> void:
	var area: Rect2 = AMBIENCES[fight.boss.ambience].area
	var screen := size
	_ambience.position = (area.position + area.size / 2.0) * screen
	_ambience.emission_rect_extents = (area.size * screen / 2.0).max(Vector2(8, 8))


## Only seats with a hero show.
func _show_party(party: Party) -> void:
	for token: SeatToken in _seats:
		var hero := party.hero_at(token.seat)
		token.show_hero(hero)
		token.visible = hero != null


func _on_round_changed(round_number: int) -> void:
	_round.text = str(round_number)
	_pop(_round)


func _on_health_changed(health: int, _max_health: int) -> void:
	_health.text = str(health)
	_pop(_health)


func _on_messages_read() -> void:
	if fight.over:
		var won := fight.stats.outcome == FightStats.Outcome.WON
		_game_over(FADE_SEC * 3.0 if won else GIVE_UP_FADE_SEC)
	else:
		fight.players_ready()


#region The players
func _on_seat_pressed(seat: int) -> void:
	var hero := fight.hero_at(seat)
	if hero != null:
		fight.choose(hero)


func _on_code_read(text: String, _corners: PackedVector2Array, _frame_size: Vector2i) -> void:
	var now := Time.get_ticks_msec()
	var last: int = _code_seen_msec.get(text, -STILL_IN_VIEW_MSEC)
	_code_seen_msec[text] = now
	if now - last >= STILL_IN_VIEW_MSEC:
		scan_code(text)


func _on_camera_failed(reason: String) -> void:
	_camera_problem = reason
	_refresh_prompt()


func _on_camera_started() -> void:
	_camera_problem = ""
	_refresh_prompt()


func _on_request_changed(_request: Fight.Request) -> void:
	_refresh_seats()
	_refresh_prompt()
	# The action being played glows.
	for hero in fight.heroes:
		_refresh_badge(hero)


## Heroes who can be chosen call for attention, whoever's turn it is glows.
func _refresh_seats() -> void:
	var request := fight.request
	for token: SeatToken in _seats:
		var hero := fight.hero_at(token.seat)
		if hero == null:
			continue
		var mode := SeatToken.Mode.IDLE
		if request != null and request.kind == Fight.Request.Kind.HERO:
			mode = SeatToken.Mode.SELECTABLE if hero in request.heroes else SeatToken.Mode.DIMMED
		elif hero == fight.active_hero or (request != null and request.hero == hero):
			mode = SeatToken.Mode.ACTIVE
		elif fight.active_hero != null:
			mode = SeatToken.Mode.DIMMED
		if token.mode != mode:
			token.set_mode(mode)


## What the fight asks for, with buttons for what can be done besides tapping a hero or
## showing a card.
func _refresh_prompt() -> void:
	var request := fight.request
	var shown := request != null
	if shown != _prompt.visible or (_prompt_tween != null and _prompt_tween.is_running()):
		_fade_prompt(shown)
	if not shown:
		return
	var locale := TranslationServer.get_locale()
	var text: String = Messages.render(request.prompt, request.values, locale, _symbol_size(_prompt_text)).body
	if request.kind == Fight.Request.Kind.ACTION and not _camera_problem.is_empty():
		text += "\n[color=#ff9a80]%s[/color]" % _camera_problem.replace("[", "[lb]")
	_prompt_text.text = "[center]%s[/center]" % text
	for button in _buttons.get_children():
		_buttons.remove_child(button)
		button.queue_free()
	match request.kind:
		Fight.Request.Kind.ACTION:
			_add_button("option_pass", fight.pass_action)
		Fight.Request.Kind.OPTION:
			for i in request.options.size():
				_add_button(request.options[i], fight.choose_option.bind(i))
	# Declining a free card is passing on it, so actions need no button to skip.
	if request.can_skip and request.kind != Fight.Request.Kind.ACTION:
		_add_button("option_skip", fight.skip)
	_buttons.visible = _buttons.get_child_count() > 0


func _add_button(id: String, action: Callable) -> void:
	var button := Button.new()
	button.text = Messages.find(id).get("body", id)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(150, 64)
	button.pressed.connect(action)
	_buttons.add_child(button)


func _fade_prompt(shown: bool) -> void:
	if _prompt_tween != null:
		_prompt_tween.kill()
	_prompt_tween = create_tween()
	if shown:
		_prompt.show()
		_prompt.modulate.a = 0.0
		_prompt_tween.tween_property(_prompt, "modulate:a", 1.0, 0.25)
	else:
		_prompt_tween.tween_property(_prompt, "modulate:a", 0.0, 0.2)
		_prompt_tween.tween_callback(_prompt.hide)
#endregion


#region What the fight shows
## A badge by each hero, facing them: the boss's attack against them, with what it does
## besides, and the actions they have left this round. Their own status tokens are on
## the table.
func _make_badges() -> void:
	for token: SeatToken in _seats:
		var hero := fight.hero_at(token.seat)
		if hero == null:
			continue
		var badge := PanelContainer.new()
		badge.name = "Badge"
		badge.add_theme_stylebox_override("panel", _plate)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.anchor_left = 0.5
		badge.anchor_right = 0.5
		badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
		badge.offset_top = -50.0
		badge.offset_bottom = -6.0
		var row := HBoxContainer.new()
		row.name = "Row"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 4)
		badge.add_child(row)
		var threat := HBoxContainer.new()
		threat.name = "Threat"
		threat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		threat.add_theme_constant_override("separation", 4)
		threat.add_child(_icon("res://assets/fight/icon_damage.svg", BADGE_ICON_SIZE))
		var value := Label.new()
		value.name = "Value"
		value.theme_type_variation = &"Title"
		value.add_theme_font_size_override("font_size", 26)
		threat.add_child(value)
		var effects := HBoxContainer.new()
		effects.name = "Effects"
		effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
		threat.add_child(effects)
		row.add_child(threat)
		var actions := ActionSpheres.new()
		actions.name = "Actions"
		actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(actions)
		badge.hide()
		token.add_child(badge)
		_badges[token.seat] = badge


func _refresh_badge(hero: FightHero) -> void:
	var badge: Control = _badges.get(hero.seat)
	if badge == null:
		return
	var threat: Control = badge.get_node("Row/Threat")
	var planned := fight.phase in [Fight.Phase.PLANNING, Fight.Phase.SHIELD, Fight.Phase.ACTION, Fight.Phase.ATTACK]
	threat.visible = planned
	var value: Label = threat.get_node("Value")
	var old := value.text
	value.text = str(hero.threat)
	threat.modulate.a = 1.0 if hero.threat > 0 else 0.45
	var effects: Control = threat.get_node("Effects")
	_clear(effects)
	for token: String in hero.threat_effects:
		effects.add_child(_icon(TOKEN_ICONS.get(token, ""), BADGE_ICON_SIZE))
	var actions: ActionSpheres = badge.get_node("Row/Actions")
	var old_actions := actions.actions()
	var request := fight.request
	var playing := request != null and request.kind == Fight.Request.Kind.ACTION and request.hero == hero
	var left: Array[FightHero.Action] = []
	if fight.phase != Fight.Phase.OVER:
		left = hero.actions()
	actions.show_actions(left, playing)
	var was_visible := badge.visible
	badge.visible = planned or actions.visible
	# Size the badge to what it holds now, centred over the seat.
	badge.offset_left = 0.0
	badge.offset_right = 0.0
	badge.reset_size()
	if badge.visible and (not was_visible or old != value.text or actions.actions().size() > old_actions.size()):
		badge.pivot_offset = badge.size / 2.0
		_pop(badge)


func _on_phase_changed(_phase: Fight.Phase) -> void:
	for hero in fight.heroes:
		_refresh_badge(hero)


func _make_shields() -> void:
	for kind in Fight.DAMAGE_TYPES:
		var plate := PanelContainer.new()
		plate.add_theme_stylebox_override("panel", _plate)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.name = "Row"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 6)
		row.add_child(_icon(SHIELD_ICONS[kind], SHIELD_ICON_SIZE))
		var value := Label.new()
		value.name = "Value"
		value.theme_type_variation = &"Title"
		value.add_theme_font_size_override("font_size", 30)
		value.custom_minimum_size.x = 26
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(value)
		plate.add_child(row)
		_shields.add_child(plate)
		_shield_plates[kind] = plate


func _on_shields_changed(shields: Dictionary) -> void:
	# While the boss raises them, they appear once it is done (see _on_shields_raised).
	if fight.phase == Fight.Phase.SHIELD:
		return
	if _shields.modulate.a < 1.0:
		create_tween().tween_property(_shields, "modulate:a", 1.0, 0.4)
	for kind: String in _shield_plates:
		var plate: Control = _shield_plates[kind]
		var value: Label = plate.get_node("Row/Value")
		var text := str(shields.get(kind, 0))
		if value.text != text:
			value.text = text
			plate.pivot_offset = plate.size / 2.0
			_pop(plate)
		plate.modulate.a = 1.0 if shields.get(kind, 0) > 0 else 0.4


## Instead of a message: the shields appear one after the other and count up to their
## values. The next message waits until they are done.
func _on_shields_raised(shields: Dictionary) -> void:
	var kinds: Array = _shield_plates.keys()
	var seconds := SHIELD_APPEAR_SEC + SHIELD_STAGGER_SEC * (kinds.size() - 1) + SHIELD_COUNT_SEC
	messages.hold(seconds + 0.2)
	var none := not shields.values().any(func(value: int) -> bool: return value > 0)
	show_banner(_t("no_shields" if none else "shields_raised"), SHIELD_BANNER_SEC)
	var appearing := _shields.modulate.a < 1.0
	if appearing:
		create_tween().tween_property(_shields, "modulate:a", 1.0, SHIELD_APPEAR_SEC)
	for i in kinds.size():
		var kind: String = kinds[i]
		var plate: Control = _shield_plates[kind]
		var value: Label = plate.get_node("Row/Value")
		var from := 0 if appearing else value.text.to_int()
		var to: int = shields.get(kind, 0)
		var delay := SHIELD_STAGGER_SEC * i
		var tween := create_tween()
		if appearing:
			value.text = "0"
			plate.modulate.a = 0.4
			plate.pivot_offset = plate.size / 2.0
			plate.scale = Vector2.ZERO
			tween.tween_property(plate, "scale", Vector2.ONE, SHIELD_APPEAR_SEC).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			tween.tween_interval(SHIELD_APPEAR_SEC + delay)
		if from != to:
			tween.tween_callback(func() -> void: plate.modulate.a = 1.0)
			tween.tween_method(func(shown: int) -> void: value.text = str(shown), from, to, SHIELD_COUNT_SEC)
			tween.tween_callback(_pop.bind(plate))
		tween.tween_callback(func() -> void:
			value.text = str(to)
			plate.modulate.a = 1.0 if to > 0 else 0.4)


func _on_boss_hit(_kind: String, _absorbed: int, dealt: int) -> void:
	if dealt <= 0:
		return
	var material := _figure.material as ShaderMaterial
	var flash := create_tween()
	flash.tween_method(func(value: float) -> void: material.set_shader_parameter("flash", value), 0.8, 0.0, 0.45)
	var number := Label.new()
	number.text = "-%d" % dealt
	number.theme_type_variation = &"Title"
	number.add_theme_font_size_override("font_size", 72)
	number.add_theme_color_override("font_color", HIT_COLOR)
	number.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.0))
	number.add_theme_constant_override("outline_size", 10)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(number)
	move_child(number, _figure.get_index() + 1)
	number.reset_size()
	number.position = _figure.position + _figure.size * Vector2(0.5, 0.4) - number.size / 2.0
	var rise := create_tween().set_parallel()
	rise.tween_property(number, "position:y", number.position.y - 120.0, 1.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	rise.tween_property(number, "modulate:a", 0.0, 0.5).set_delay(0.6)
	rise.chain().tween_callback(number.queue_free)


func _on_won() -> void:
	var fade := create_tween().set_parallel()
	fade.tween_property(_figure, "modulate:a", 0.0, 1.6).set_delay(0.3)
	fade.tween_property(_shields, "modulate:a", 0.0, 0.5)
#endregion


func _icon(path: String, icon_size: int) -> TextureRect:
	var icon := TextureRect.new()
	if not path.is_empty():
		icon.texture = load(path)
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


## Symbols as tall as the text around them, a little larger.
func _symbol_size(label: RichTextLabel) -> int:
	return roundi(label.get_theme_font_size("normal_font_size") * 1.15)


func _play_intro() -> void:
	_figure.modulate.a = 0.0
	var intro := create_tween()
	intro.tween_property(_figure, "modulate:a", 1.0, 0.8).set_delay(0.2)
	for i in _seats.size():
		var seat: Control = _seats[i]
		seat.scale = Vector2.ZERO
		create_tween().tween_property(seat, "scale", Vector2.ONE, 0.4).set_delay(0.5 + i * 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	messages.hold(INTRO_SEC)
	# The boss's health counts up as it appears.
	_health.text = "0"
	var count := create_tween()
	count.tween_method(func(value: int) -> void: _health.text = str(value), 0, fight.max_health, HEALTH_COUNT_SEC).set_delay(0.4)
	count.tween_callback(_pop.bind(_health))
	_banner.modulate.a = 0.0
	show_banner(CardDatabase.localized(fight.boss.title, TranslationServer.get_locale()))


func _pop(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2(1.3, 1.3)
	create_tween().tween_property(control, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
