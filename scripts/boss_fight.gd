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
## The marks beside each hero: the boss's attack on their left, what it does besides on
## their right, in the seat's own coordinates (SeatToken), where the portrait is centred
## at PORTRAIT_MIDDLE.
const THREAT_ICON_SIZE := 34
const PORTRAIT_MIDDLE := 39.0
const THREAT_RIGHT := 36.0
const EFFECTS_LEFT := 144.0
## A shield above each attack type, both large.
const SHIELD_SIZE := Vector2(92, 100)
const ATTACK_STATE_SIZE := 76
const GRAY_SHADER := preload("res://assets/fight/gray.gdshader")
## How long the boss takes to plan its attack against each hero, while the message says
## so: the attack pops up and counts up, then what it does besides.
const PLAN_START_SEC := 0.5
const PLAN_COUNT_SEC := 0.45
const PLAN_HERO_SEC := 0.75
const PLAN_END_SEC := 0.9
## How long the shields take to rise, one after the other, each counting up. Messages wait
## meanwhile.
const SHIELD_APPEAR_SEC := 0.35
const SHIELD_STAGGER_SEC := 0.2
const SHIELD_COUNT_SEC := 0.6
const SHIELD_BANNER_SEC := 1.4
## A hit on the boss shows one step after the other, and the fight waits meanwhile (see
## _show_step): the attack (AttackEffects), its shield counting down, the shield breaking,
## and the damage that is left coming off its health.
## The shield counts down a point each SHIELD_TICK_SEC, in SHIELD_COUNT_MAX_SEC at most.
const SHIELD_TICK_SEC := 0.24
const SHIELD_COUNT_MAX_SEC := 1.2
## A breaking shield trembles and glows, bursts into shards, then shows broken.
const SHIELD_TREMBLE_SEC := 0.45
const SHIELD_BROKEN_SEC := 0.9
const BROKEN_ALPHA := 0.45
const DAMAGE_SEC := 0.25
const HEALTH_STEP_SEC := 0.8
## Between the steps of a hit.
const STEP_PAUSE_SEC := 0.2
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
## By damage type: whether it was attacked this round, a medallion each below its shield.
var _attack_states := {}
## By seat: whether the attack planned against the hero has been shown yet. The boss plans
## them one after the other, while its message says so (_animate_planning).
var _revealed := {}
var _camera_problem := ""
## The style of the HUD's plates, for the badges and shields.
var _plate: StyleBox
## What lasts a while for everyone, such as Muttis Nachtisch, at the top of the screen.
var _global_buffs: BuffChips
## The sound effects of what happens in the fight. See docs/sounds.md.
var _sfx: Sfx
## The big effects of the heroes' attacks, over the boss.
var _effects: AttackEffects
## What the screen shows one after the other, as [what, seconds], such as the steps of a
## hit on the boss. The fight and its messages wait meanwhile.
var _steps: Array[Array] = []
var _steps_running := false
## When the steps waiting now will be done.
var _steps_end_msec := 0
## The boss's health and shields once the steps waiting now are done.
var _shown_health := 0
var _shown_shields := {}
## The boss is raising its shields: they show all at once, when it is done.
var _raising := false
var _flash_tween: Tween
var _shake_tween: Tween

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
## The boss's poison tokens, shown once it has any.
@onready var _poison: Control = $Hud/Poison
@onready var _poison_value: Label = $Hud/Poison/Row/Value
@onready var _shields: HBoxContainer = $Shields
@onready var _prompt: Control = $Prompt
@onready var _prompt_text: RichTextLabel = $Prompt/Layout/Text
@onready var _notice: RichTextLabel = $Prompt/Layout/Notice
@onready var _buttons: HBoxContainer = $Prompt/Layout/Buttons
@onready var _scanner: QrCameraScanner = $QrCameraScanner
@onready var _pling: AudioStreamPlayer = $Pling


func _ready() -> void:
	super()
	_sfx = Sfx.new()
	_sfx.name = "Sfx"
	add_child(_sfx)
	# Only when run on its own, as from the editor.
	if not Bosses.has(Encounter.boss):
		Encounter.boss = Bosses.IDS[0]
	if not Bosses.DIFFICULTIES.has(Encounter.difficulty):
		Encounter.difficulty = Bosses.DEFAULT_DIFFICULTY
	var party := Party.load_file(party_path)
	_cards = CardDatabase.load_file(cards_path)
	fight = Fight.new(Bosses.create(Encounter.boss), Encounter.difficulty, party.heroes, _cards)
	fight.round_changed.connect(_on_round_changed)
	fight.health_changed.connect(_on_health_changed)
	fight.shields_changed.connect(_on_shields_changed)
	fight.poison_changed.connect(_on_poison_changed)
	fight.shields_raised.connect(_on_shields_raised)
	fight.boss_attacked.connect(_on_boss_attacked)
	fight.hero_changed.connect(_refresh_badge)
	fight.hero_changed.connect(_refresh_form)
	fight.phase_changed.connect(_on_phase_changed)
	fight.turn_changed.connect(func(_hero: FightHero) -> void: _refresh_seats())
	fight.request_changed.connect(_on_request_changed)
	fight.message.connect(show_message)
	fight.notice.connect(show_notice)
	fight.boss_hit.connect(_on_boss_hit)
	fight.won.connect(_on_won)
	fight.buffs_changed.connect(_refresh_buffs)
	fight.attacked_changed.connect(_on_attacked_changed)
	messages.all_confirmed.connect(_on_messages_read)
	messages.shown.connect(_on_message_shown)

	_show_boss(fight.boss)
	_show_party(party)
	_plate = ($Hud/Round as PanelContainer).get_theme_stylebox("panel")
	_make_badges()
	_make_global_buffs()
	_make_shields()
	_shown_health = fight.health
	_shown_shields = fight.shields.duplicate()
	_effects = AttackEffects.new()
	_effects.sfx = _sfx
	_effects.impact.connect(_on_impact)
	add_child(_effects)
	# Over the boss, the heroes and the shields, under the prompt, messages and HUD.
	move_child(_effects, _shields.get_index() + 1)
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
	return fight.scan(_cards.find(code), code)


## Shows a short note in the prompt for a while, such as why a card was not played.
func show_notice(id: String, values := {}) -> void:
	# Lightning is good news, every other notice says why a card was not played.
	_sfx.play("lightning" if id == "notice_lightning" else "rejected")
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
	# The boss plans its attacks anew, shown one by one (_animate_planning).
	for seat: int in _badges:
		_revealed[seat] = false


## The health shown counts to the new value, after what the screen shows before it, such
## as the attack that hurt the boss.
func _on_health_changed(health: int, _max_health: int) -> void:
	var old := _shown_health
	_shown_health = health
	if health != old:
		_show_step(_count_health.bind(old, health), HEALTH_STEP_SEC)


func _count_health(from: int, to: int) -> void:
	var count := create_tween()
	count.tween_method(func(value: int) -> void: _health.text = str(value), from, to, HEALTH_STEP_SEC * 0.6)
	count.tween_callback(func() -> void:
		_health.text = str(to)
		_pop(_health))


func _on_poison_changed(poison: int) -> void:
	if poison > _poison_value.text.to_int():
		_sfx.play("poison")
	_poison_value.text = str(poison)
	_poison.visible = poison > 0
	if poison > 0:
		_pop(_poison_value)


func _on_messages_read() -> void:
	if fight.over:
		var won := fight.stats.outcome == FightStats.Outcome.WON
		_game_over(FADE_SEC * 3.0 if won else GIVE_UP_FADE_SEC)
	else:
		fight.players_ready()


#region The players
func _on_seat_pressed(seat: int) -> void:
	var hero := fight.hero_at(seat)
	if hero == null:
		return
	var request := fight.request
	if request != null and request.kind == Fight.Request.Kind.HERO and hero in request.heroes:
		_sfx.play("select")
	fight.choose(hero)


func _on_code_read(text: String, _corners: PackedVector2Array, _frame_size: Vector2i) -> void:
	var now := Time.get_ticks_msec()
	var last: int = _code_seen_msec.get(text, -STILL_IN_VIEW_MSEC)
	_code_seen_msec[text] = now
	if now - last < STILL_IN_VIEW_MSEC:
		return
	# Every card plings when it is read, even one that does nothing now, so the players
	# know they can take it back. What the card does comes after the pling.
	_pling.play()
	var wait := create_tween()
	wait.tween_interval(QrCameraScanner.CONFIRM_SEC)
	wait.tween_callback(func() -> void:
		if not _leaving:
			scan_code(text))


func _on_camera_failed(reason: String) -> void:
	_camera_problem = reason
	_refresh_prompt()


func _on_camera_started() -> void:
	_camera_problem = ""
	_refresh_prompt()


func _on_request_changed(request: Fight.Request) -> void:
	# The players have to do something: a hero shows a card, or they choose.
	if request != null:
		_sfx.play("turn" if request.kind == Fight.Request.Kind.ACTION else "choose")
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
	# A hero passes by showing a Pass card, so actions get no button for it.
	if request.kind == Fight.Request.Kind.OPTION:
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
	button.pressed.connect(_sfx.play.bind("select"))
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
## The marks by each hero, facing them: the boss's attack against them on their left,
## what it does besides (tokens such as poison) on their right, and above their portrait a
## badge with the actions they have left this round and what lasts a while for them, such
## as a Totem (FightBuff). Their own status tokens are on the table.
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
		var actions := ActionSpheres.new()
		actions.name = "Actions"
		actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(actions)
		var buffs := BuffChips.new()
		buffs.name = "Buffs"
		row.add_child(buffs)
		badge.hide()
		token.add_child(badge)
		_badges[token.seat] = badge
		_revealed[token.seat] = true

		var threat := _side_plate("Threat", token, THREAT_RIGHT, Control.GROW_DIRECTION_BEGIN)
		var column := VBoxContainer.new()
		column.name = "Column"
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 0)
		var value := Label.new()
		value.name = "Value"
		value.theme_type_variation = &"Title"
		value.add_theme_font_size_override("font_size", 32)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(value)
		column.add_child(_icon("res://assets/fight/icon_damage.svg", THREAT_ICON_SIZE))
		threat.add_child(column)
		var effects := _side_plate("Effects", token, EFFECTS_LEFT, Control.GROW_DIRECTION_END)
		var effect_row := HBoxContainer.new()
		effect_row.name = "Row"
		effect_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effect_row.add_theme_constant_override("separation", 6)
		effects.add_child(effect_row)


## A plate beside the portrait of a seat, its edge at x in the seat's coordinates and
## growing away from it, centred on the portrait.
func _side_plate(plate_name: String, token: SeatToken, x: float, grow: Control.GrowDirection) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.name = plate_name
	plate.add_theme_stylebox_override("panel", _plate)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.anchor_left = x / token.size.x
	plate.anchor_right = plate.anchor_left
	plate.anchor_top = PORTRAIT_MIDDLE / token.size.y
	plate.anchor_bottom = plate.anchor_top
	plate.grow_horizontal = grow
	plate.grow_vertical = Control.GROW_DIRECTION_BOTH
	plate.hide()
	token.add_child(plate)
	return plate


## The dryad's seat shows the form she has taken.
func _refresh_form(hero: FightHero) -> void:
	for token: SeatToken in _seats:
		if token.seat == hero.seat and token.form != hero.form:
			token.show_form(hero.form)
			token.pop()


func _refresh_badge(hero: FightHero) -> void:
	var badge: Control = _badges.get(hero.seat)
	if badge == null:
		return
	var token := badge.get_parent() as SeatToken
	var threat: Control = token.get_node("Threat")
	var effects: Control = token.get_node("Effects")
	var planned := fight.phase in [Fight.Phase.PLANNING, Fight.Phase.SHIELD, Fight.Phase.ACTION, Fight.Phase.ATTACK]
	var shown: bool = planned and _revealed.get(hero.seat, true)
	var value: Label = threat.get_node("Column/Value")
	var old := value.text
	var was_shown := threat.visible
	value.text = str(hero.threat)
	# An attack lowered by a card, as by a Protection.
	if fight.phase == Fight.Phase.ACTION and hero.threat < old.to_int():
		_sfx.play("protect")
	threat.visible = shown
	threat.modulate.a = 1.0 if hero.threat > 0 else 0.45
	_fit(threat)
	if shown and was_shown and old != value.text:
		_pop(threat)

	var row: Control = effects.get_node("Row")
	var old_effects := row.get_child_count()
	_clear(row)
	for token_name: String in hero.threat_effects:
		row.add_child(_effect(token_name, hero.threat_effects[token_name]))
	effects.visible = shown and not hero.threat_effects.is_empty()
	_fit(effects)
	if effects.visible and was_shown and hero.threat_effects.size() > old_effects:
		_pop(effects)

	var actions: ActionSpheres = badge.get_node("Row/Actions")
	var old_actions := actions.actions()
	var request := fight.request
	var playing := request != null and request.kind == Fight.Request.Kind.ACTION and request.hero == hero
	var left: Array[FightHero.Action] = []
	if fight.phase != Fight.Phase.OVER:
		left = hero.actions()
	actions.show_actions(left, playing)
	var was_visible := badge.visible
	var buffs: BuffChips = badge.get_node("Row/Buffs")
	badge.visible = actions.visible or buffs.visible
	# Size the badge to what it holds now, centred over the seat.
	badge.offset_left = 0.0
	badge.offset_right = 0.0
	badge.reset_size()
	if badge.visible and (not was_visible or actions.actions().size() > old_actions.size()):
		badge.pivot_offset = badge.size / 2.0
		_pop(badge)


## A token the boss's attack gives besides damage, with how many.
func _effect(token_name: String, count: int) -> Control:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	var value := Label.new()
	value.theme_type_variation = &"Title"
	value.add_theme_font_size_override("font_size", 32)
	value.add_theme_color_override("font_color", Color(0.714, 0.878, 0.29) if token_name == "poison" else Color(0.98, 0.88, 0.62))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.text = str(count)
	column.add_child(value)
	column.add_child(_icon(TOKEN_ICONS.get(token_name, ""), THREAT_ICON_SIZE))
	return column


## Sizes a plate beside a seat to what it holds now, keeping where it is anchored.
func _fit(plate: Control) -> void:
	plate.offset_left = 0.0
	plate.offset_right = 0.0
	plate.offset_top = 0.0
	plate.offset_bottom = 0.0
	plate.reset_size()


## The chips for everyone at the top of the screen, between the buttons.
func _make_global_buffs() -> void:
	_global_buffs = BuffChips.new()
	_global_buffs.name = "Buffs"
	_global_buffs.anchor_left = 0.5
	_global_buffs.anchor_right = 0.5
	_global_buffs.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_global_buffs.offset_top = 28.0
	_global_buffs.offset_bottom = 80.0
	$Hud.add_child(_global_buffs)


## Shows what lasts a while (Fight.buffs), for everyone and at each hero's seat. A hero
## with a totem token has a glow around their portrait too.
func _refresh_buffs() -> void:
	_global_buffs.show_buffs(fight.buffs(null, true), _plate)
	for hero in fight.heroes:
		var badge: Control = _badges.get(hero.seat)
		if badge != null:
			(badge.get_node("Row/Buffs") as BuffChips).show_buffs(fight.buffs(hero), _plate)
			_refresh_badge(hero)
	for token: SeatToken in _seats:
		var hero := fight.hero_at(token.seat)
		token.show_totem(hero != null and fight.has_totem(hero))


func _on_phase_changed(phase: Fight.Phase) -> void:
	if phase == Fight.Phase.SHIELD:
		_raising = true
	for hero in fight.heroes:
		_refresh_badge(hero)


## A column for each damage type: the boss's shield, with its value on it, and below it
## a medallion for the attack type, grey until a hero attacks with it this round. Then it
## is in colour: supports of that type can be played.
func _make_shields() -> void:
	var medallion := StyleBoxFlat.new()
	medallion.bg_color = Color(0.08, 0.04, 0.02, 0.85)
	medallion.border_color = Color(0.84, 0.65, 0.28)
	medallion.set_border_width_all(3)
	medallion.set_corner_radius_all(ATTACK_STATE_SIZE / 2)
	for kind in Fight.DAMAGE_TYPES:
		var column := VBoxContainer.new()
		column.name = kind.to_pascal_case()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 4)
		var shield := Control.new()
		shield.name = "Shield"
		shield.custom_minimum_size = SHIELD_SIZE
		shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var picture := _icon(fight.boss.shield_icon(kind), 0)
		picture.name = "Icon"
		picture.set_anchors_preset(Control.PRESET_FULL_RECT)
		picture.material = _gray_material()
		shield.add_child(picture)
		var value := Label.new()
		value.name = "Value"
		value.theme_type_variation = &"Title"
		value.add_theme_font_size_override("font_size", 40)
		value.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.0))
		value.add_theme_constant_override("outline_size", 8)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.set_anchors_preset(Control.PRESET_FULL_RECT)
		# The middle of the shield's face, a little below that of the picture.
		value.offset_top = 6.0
		value.text = "0"
		shield.add_child(value)
		column.add_child(shield)

		var state := PanelContainer.new()
		state.name = "Attack"
		state.custom_minimum_size = Vector2(ATTACK_STATE_SIZE, ATTACK_STATE_SIZE)
		state.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		state.mouse_filter = Control.MOUSE_FILTER_IGNORE
		state.add_theme_stylebox_override("panel", medallion)
		state.material = _gray_material()
		var icon := _icon(SHIELD_ICONS[kind], ATTACK_STATE_SIZE - 22)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.use_parent_material = true
		state.add_child(icon)
		column.add_child(state)
		_shields.add_child(column)
		_shield_plates[kind] = shield
		_attack_states[kind] = state
	_on_attacked_changed(fight.attacked)


func _gray_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GRAY_SHADER
	return material


## A shield at 0 is broken: grey and faint.
func _show_shield_state(shield: Control, value: int) -> void:
	var broken := value <= 0
	shield.modulate.a = 0.45 if broken else 1.0
	((shield.get_node("Icon") as CanvasItem).material as ShaderMaterial).set_shader_parameter("gray", 1.0 if broken else 0.0)


## The attack types attacked this round are in colour, those not yet grey. One that has
## just been attacked lights up.
func _on_attacked_changed(kinds: Array[String]) -> void:
	for kind: String in _attack_states:
		var state: Control = _attack_states[kind]
		var material := state.material as ShaderMaterial
		var open := kind in kinds
		var was_open: bool = state.get_meta("open", false)
		state.set_meta("open", open)
		if open == was_open:
			material.set_shader_parameter("gray", 0.0 if open else 1.0)
			state.modulate.a = 1.0 if open else 0.6
			continue
		if open:
			var light := create_tween().set_parallel()
			light.tween_method(func(gray: float) -> void: material.set_shader_parameter("gray", gray), 1.0, 0.0, 0.35)
			light.tween_property(state, "modulate:a", 1.0, 0.35)
			_pop(state)
		else:
			material.set_shader_parameter("gray", 1.0)
			state.modulate.a = 0.6


## The shields shown follow the fight's, after what the screen shows before: a shield that
## takes a hit counts down, and breaks at 0.
func _on_shields_changed(shields: Dictionary) -> void:
	# While the boss raises them, they appear once it is done (see _on_shields_raised).
	if _raising:
		return
	for kind: String in _shield_plates:
		var old: int = _shown_shields.get(kind, 0)
		var new: int = shields.get(kind, 0)
		if new == old:
			continue
		_shown_shields[kind] = new
		if new > old:
			_show_step(_set_shield.bind(kind, new), 0.35)
			continue
		_show_step(_count_shield.bind(kind, old, new), _shield_count_seconds(old - new) + STEP_PAUSE_SEC)
		if new == 0:
			_show_step(_break_shield.bind(kind), SHIELD_TREMBLE_SEC + SHIELD_BROKEN_SEC + STEP_PAUSE_SEC)


func _set_shield(kind: String, value: int) -> void:
	if _shields.modulate.a < 1.0:
		create_tween().tween_property(_shields, "modulate:a", 1.0, 0.4)
	var plate: Control = _shield_plates[kind]
	(plate.get_node("Value") as Label).text = str(value)
	_show_shield_state(plate, value)
	_pop(plate)


func _shield_count_seconds(points: int) -> float:
	return 0.15 + points * _shield_tick(points) + 0.2


func _shield_tick(points: int) -> float:
	return minf(SHIELD_TICK_SEC, SHIELD_COUNT_MAX_SEC / maxi(1, points))


## The shield takes the hit: it grows, and counts down a point at a time, clanking.
func _count_shield(kind: String, from: int, to: int) -> void:
	var plate: Control = _shield_plates[kind]
	var value: Label = plate.get_node("Value")
	var tick := _shield_tick(from - to)
	plate.pivot_offset = plate.size / 2.0
	var tween := create_tween()
	tween.tween_property(plate, "scale", Vector2.ONE * 1.18, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for shown in range(from - 1, to - 1, -1):
		tween.tween_callback(func() -> void:
			value.text = str(shown)
			value.add_theme_color_override("font_color", HIT_COLOR)
			plate.scale = Vector2.ONE * 1.3
			_sfx.play("shield_block", 1.0 + 0.05 * (from - shown))
			_effects.spark(plate))
		tween.tween_property(plate, "scale", Vector2.ONE * 1.18, tick).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		value.text = str(to)
		value.remove_theme_color_override("font_color")
		if to > 0:
			_show_shield_state(plate, to))
	tween.tween_property(plate, "scale", Vector2.ONE, 0.2)


## The shield at 0 breaks: it trembles and glows, bursts into shards, and shows broken.
func _break_shield(kind: String) -> void:
	var plate: Control = _shield_plates[kind]
	var picture: TextureRect = plate.get_node("Icon")
	plate.pivot_offset = plate.size / 2.0
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		plate.rotation = sin(t * 48.0) * 0.12 * t
		plate.scale = Vector2.ONE * (1.0 + 0.22 * t)
		picture.self_modulate = Color.WHITE.lerp(Color(2.4, 2.1, 1.7), t), 0.0, 1.0, SHIELD_TREMBLE_SEC).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_sfx.play("shield_break")
		_effects.shatter(picture)
		plate.rotation = 0.0
		plate.scale = Vector2.ONE
		picture.self_modulate = Color.WHITE
		_show_shield_state(plate, 0)
		plate.modulate.a = 0.0)
	tween.tween_interval(SHIELD_BROKEN_SEC - 0.4)
	tween.tween_property(plate, "modulate:a", BROKEN_ALPHA, 0.4)


## Instead of a message: the shields appear one after the other and count up to their
## values. The fight and the next message wait until they are done.
func _on_shields_raised(shields: Dictionary) -> void:
	_raising = false
	_shown_shields = shields.duplicate()
	var seconds := SHIELD_APPEAR_SEC + SHIELD_STAGGER_SEC * (_shield_plates.size() - 1) + SHIELD_COUNT_SEC
	_show_step(_raise_shields.bind(shields.duplicate()), seconds + 0.2)


func _raise_shields(shields: Dictionary) -> void:
	var kinds: Array = _shield_plates.keys()
	var none := not shields.values().any(func(value: int) -> bool: return value > 0)
	if not none:
		_sfx.play("shields_up")
	show_banner(_t("no_shields" if none else "shields_raised"), SHIELD_BANNER_SEC)
	var appearing := _shields.modulate.a < 1.0
	if appearing:
		create_tween().tween_property(_shields, "modulate:a", 1.0, SHIELD_APPEAR_SEC)
	for i in kinds.size():
		var kind: String = kinds[i]
		var plate: Control = _shield_plates[kind]
		var value: Label = plate.get_node("Value")
		var from := 0 if appearing else value.text.to_int()
		var to: int = shields.get(kind, 0)
		var delay := SHIELD_STAGGER_SEC * i
		var tween := create_tween()
		if appearing:
			value.text = "0"
			_show_shield_state(plate, 0)
			plate.pivot_offset = plate.size / 2.0
			plate.scale = Vector2.ZERO
			tween.tween_property(plate, "scale", Vector2.ONE, SHIELD_APPEAR_SEC).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			tween.tween_interval(SHIELD_APPEAR_SEC + delay)
		if from != to:
			tween.tween_callback(_show_shield_state.bind(plate, to))
			tween.tween_method(func(shown: int) -> void: value.text = str(shown), from, to, SHIELD_COUNT_SEC)
			tween.tween_callback(_pop.bind(plate))
		tween.tween_callback(func() -> void:
			value.text = str(to)
			_show_shield_state(plate, to))


## A hero attacks: the big effect of the attack's kind plays over the boss first.
func _on_boss_attacked(kind: String, amount: int) -> void:
	var seconds := AttackEffects.duration(kind, amount)
	if seconds > 0.0:
		_show_step(func() -> void: _effects.play(kind, amount, _boss_area()), seconds)


func _on_boss_hit(_kind: String, _absorbed: int, dealt: int) -> void:
	if dealt > 0:
		_show_step(_show_damage.bind(dealt), DAMAGE_SEC)


## The damage that reaches the boss's health rises from it, before the health counts down.
func _show_damage(dealt: int) -> void:
	_sfx.play("hit")
	_on_impact(Vector2.ZERO, 0.7, Color.WHITE)
	var number := Label.new()
	number.text = "-%d" % dealt
	number.theme_type_variation = &"Title"
	number.add_theme_font_size_override("font_size", 84)
	number.add_theme_color_override("font_color", HIT_COLOR)
	number.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.0))
	number.add_theme_constant_override("outline_size", 12)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(number)
	move_child(number, _effects.get_index() + 1)
	number.reset_size()
	number.pivot_offset = number.size / 2.0
	number.position = _figure.position + _figure.size * Vector2(0.5, 0.4) - number.size / 2.0
	number.scale = Vector2.ONE * 0.4
	var rise := create_tween().set_parallel()
	rise.tween_property(number, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.tween_property(number, "position:y", number.position.y - 140.0, 1.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	rise.tween_property(number, "modulate:a", 0.0, 0.5).set_delay(0.9)
	rise.chain().tween_callback(number.queue_free)


## Something hit the boss: it lights up in the colour of the hit, and shakes.
func _on_impact(_point: Vector2, strength: float, color: Color) -> void:
	var material := _figure.material as ShaderMaterial
	material.set_shader_parameter("flash_color", color.lerp(Color.WHITE, 0.5))
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(value: float) -> void: material.set_shader_parameter("flash", value), 0.45 * strength, 0.0, 0.35)
	if _shake_tween != null:
		_shake_tween.kill()
	var phase := randf() * TAU
	_shake_tween = create_tween()
	_shake_tween.tween_method(func(t: float) -> void:
		material.set_shader_parameter("shake", Vector2(sin(phase + t * 55.0), cos(phase + t * 41.0)) * 18.0 * strength * (1.0 - t)), 0.0, 1.0, 0.35)


## Where the boss's picture is drawn, in the screen's coordinates.
func _boss_area() -> Rect2:
	var area := Rect2(_figure.position, _figure.size)
	if _figure.texture == null:
		return area
	var texture_size := _figure.texture.get_size()
	var fit := minf(area.size.x / texture_size.x, area.size.y / texture_size.y)
	var drawn := texture_size * fit
	return Rect2(area.position + (area.size - drawn) / 2.0, drawn)


## Shows what step does, after the steps before it are done. It takes seconds, which the
## fight waits for (Fight.hold_screen), and the messages too.
func _show_step(step: Callable, seconds: float) -> void:
	_steps.append([step, seconds])
	var now := Time.get_ticks_msec()
	_steps_end_msec = maxi(_steps_end_msec, now) + roundi(seconds * 1000.0)
	messages.hold((_steps_end_msec - now) / 1000.0)
	if not _steps_running:
		_run_steps()


## Whether the screen is still showing steps (_show_step), such as a hit on the boss.
func is_showing_steps() -> bool:
	return _steps_running


func _run_steps() -> void:
	_steps_running = true
	fight.hold_screen()
	while not _steps.is_empty():
		var step: Array = _steps.pop_front()
		(step[0] as Callable).call()
		if step[1] > 0.0:
			await get_tree().create_timer(step[1]).timeout
		if not is_inside_tree():
			return
	_steps_running = false
	fight.release_screen()


func _on_message_shown(id: String) -> void:
	if not Messages.is_animated(id):
		return
	if id == "round_started":
		_animate_planning()
	else:
		messages.finish(id)


## While its message says so, the boss plans its attack against each hero, one after the
## other: the attack pops up by the hero and counts up, then what it does besides. Then the
## message closes. There is nothing to confirm, the players see it all happen.
func _animate_planning() -> void:
	await get_tree().create_timer(PLAN_START_SEC).timeout
	if not is_inside_tree() or messages.current() != "round_started":
		return
	# A rule that waits for the players as the round starts would hold up the planning:
	# then the attacks show as they come.
	if fight.phase != Fight.Phase.PLANNING:
		for seat: int in _revealed:
			_revealed[seat] = true
		messages.finish("round_started")
		return
	for hero in fight.heroes:
		if not is_inside_tree() or fight.over:
			return
		_reveal_threat(hero)
		await get_tree().create_timer(PLAN_HERO_SEC).timeout
	if not is_inside_tree():
		return
	await get_tree().create_timer(PLAN_END_SEC).timeout
	if is_inside_tree():
		messages.finish("round_started")


func _reveal_threat(hero: FightHero) -> void:
	_revealed[hero.seat] = true
	_refresh_badge(hero)
	var token: SeatToken = _badges[hero.seat].get_parent()
	var threat: Control = token.get_node("Threat")
	var effects: Control = token.get_node("Effects")
	var value: Label = threat.get_node("Column/Value")
	_sfx.play("select")
	threat.pivot_offset = threat.size / 2.0
	threat.scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(threat, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(shown: int) -> void: value.text = str(shown), 0, hero.threat, PLAN_COUNT_SEC)
	tween.tween_callback(func() -> void: value.text = str(hero.threat))
	if effects.visible:
		effects.pivot_offset = effects.size / 2.0
		effects.scale = Vector2.ZERO
		tween.tween_callback(_sfx.play.bind("poison" if hero.threat_effects.has("poison") else "select"))
		tween.tween_property(effects, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Once the last hit has shown, the boss fades away.
func _on_won() -> void:
	_show_step(func() -> void:
		var fade := create_tween().set_parallel()
		fade.tween_property(_figure, "modulate:a", 0.0, 1.6).set_delay(0.3)
		fade.tween_property(_shields, "modulate:a", 0.0, 0.5), 0.0)
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
	_sfx.play("boss_appears")
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
