extends MenuScreen
## The fight against the chosen boss. Everything every fight has is here: the boss's
## background and figure in the middle, the heroes at their seats, the round, the boss's
## health, and buttons to give up and for the settings. What is special about a boss
## comes from its script in scripts/bosses/.
##
## The rules of a turn are not built yet, so the round stays at 1 for now.

const SELECTION_SCENE := "res://boss_selection.tscn"
const CONFIRM_DIALOG := preload("res://confirm_dialog.tscn")
const GIVE_UP_FADE_SEC := 0.7
const BANNER_SEC := 3.0
## Messages wait while the boss is introduced.
const INTRO_SEC := 1.6
const TEXT := {
	"give_up_title": { "de": "Aufgeben?", "en": "Give up?" },
	"give_up_message": { "de": "Der Kampf ist dann verloren, und ihr kehrt zur Bossauswahl zurück.", "en": "The fight is then lost, and you return to the boss list." },
	"give_up": { "de": "Aufgeben", "en": "Give up" },
	"keep_fighting": { "de": "Weiterkämpfen", "en": "Keep fighting" },
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
var fight: Fight

var _banner_tween: Tween
var _give_up_dialog: ConfirmDialog

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


func _ready() -> void:
	super()
	# Only when run on its own, as from the editor.
	if not Bosses.has(Encounter.boss):
		Encounter.boss = Bosses.IDS[0]
	if not Bosses.DIFFICULTIES.has(Encounter.difficulty):
		Encounter.difficulty = Bosses.DEFAULT_DIFFICULTY
	fight = Fight.new(Bosses.create(Encounter.boss), Encounter.difficulty)
	fight.round_changed.connect(_on_round_changed)
	fight.health_changed.connect(_on_health_changed)
	fight.message.connect(show_message)

	_show_boss(fight.boss)
	_show_party(Party.load_file(party_path))
	_give_up.pressed.connect(go_back)
	resized.connect(_place_ambience)
	_place_ambience()
	_on_health_changed(fight.health, fight.max_health)
	_play_intro()
	fight.start()


## Back does not leave a fight by accident: it asks to give up.
func go_back() -> void:
	if _leaving or _dialog_open() or is_instance_valid(_give_up_dialog):
		return
	var dialog: ConfirmDialog = CONFIRM_DIALOG.instantiate()
	dialog.name = "GiveUpDialog"
	dialog.title = _t("give_up_title")
	dialog.message = _t("give_up_message")
	dialog.confirm_text = _t("give_up")
	dialog.cancel_text = _t("keep_fighting")
	dialog.confirmed.connect(give_up)
	_give_up_dialog = dialog
	# The back button of a phone arrives while the tree passes it on, which is no time
	# to add to it.
	add_child.call_deferred(dialog)


func give_up() -> void:
	leave_to(load(SELECTION_SCENE).instantiate(), GIVE_UP_FADE_SEC)


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


func _play_intro() -> void:
	_figure.modulate.a = 0.0
	var intro := create_tween()
	intro.tween_property(_figure, "modulate:a", 1.0, 0.8).set_delay(0.2)
	for i in _seats.size():
		var seat: Control = _seats[i]
		seat.scale = Vector2.ZERO
		create_tween().tween_property(seat, "scale", Vector2.ONE, 0.4).set_delay(0.5 + i * 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	messages.hold(INTRO_SEC)
	_banner.modulate.a = 0.0
	show_banner(CardDatabase.localized(fight.boss.title, TranslationServer.get_locale()))


func _pop(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2(1.3, 1.3)
	create_tween().tween_property(control, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
