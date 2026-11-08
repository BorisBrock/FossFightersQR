class_name SeatToken
extends Control
## One place at the table. Turned towards the edge of the table, so that a player
## sitting there can read it.

signal pressed

enum Mode {
	## Nothing can be done with this seat right now.
	IDLE,
	## A player can tap it, as it is free or their own.
	SELECTABLE,
	## Stays in the background while the players are busy with something else.
	DIMMED,
	## The hero of this seat is being set up, which tapping it would not help with.
	ACTIVE,
	## A player can tap it, but it does not call for attention like a selectable seat.
	QUIET_SELECTABLE,
}

const DASH_COUNT := 16
const RING_RADIUS := 36.0
const GOLD := Color(0.98, 0.82, 0.45)
const SELECTABLE_TURNS_PER_SECOND := 0.08
## The forms the dryad can take (FightHero.form): a badge by her portrait, and the colour
## of its ring and of her picture.
const FORMS := {
	"thorn": { "icon": "res://assets/fight/icon_form_thorn.svg", "ring": Color(0.88, 0.3, 0.18), "tint": Color(1.0, 0.86, 0.8) },
	"blossom": { "icon": "res://assets/fight/icon_form_blossom.svg", "ring": Color(0.94, 0.54, 0.69), "tint": Color(1.0, 0.92, 0.94) },
	"bark": { "icon": "res://assets/fight/icon_form_bark.svg", "ring": Color(0.55, 0.36, 0.18), "tint": Color(0.92, 0.84, 0.74) },
}
const RING_COLOR := Color(0.85, 0.66, 0.3)

@export_range(0, 6) var seat := 0
## How far the token is turned: 0 faces the bottom edge, 90 the left and -90 the right.
@export var facing_degrees := 0.0

var mode := Mode.IDLE
## The form the hero here has taken, see FORMS. Empty for none.
var form := ""
var _hero: Party.Hero
var _time := 0.0

@onready var _portrait: TextureRect = $Portrait
@onready var _crest: TextureRect = $Crest
@onready var _form: TextureRect = $Form
@onready var _plate: Control = $NamePlate
@onready var _name: Label = $NamePlate/Name
@onready var _hit: Button = $Hit


func _ready() -> void:
	pivot_offset = size / 2.0
	rotation_degrees = facing_degrees
	_portrait.material = PortraitMaterial.new(0.5, 0.05)
	_crest.material = PortraitMaterial.new(0.5, 0.08)
	_hit.pressed.connect(pressed.emit)
	show_hero(null)
	set_mode(Mode.IDLE)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var center := _portrait.position + _portrait.size / 2.0
	var selectable := mode == Mode.SELECTABLE or mode == Mode.ACTIVE
	var pulse := 0.5 + 0.5 * sin(_time * 4.0) if selectable else 0.0
	if _hero != null:
		if mode == Mode.ACTIVE:
			draw_circle(center, RING_RADIUS + 8.0 + pulse * 6.0, Color(GOLD, 0.3 + pulse * 0.25))
		return
	if selectable:
		draw_circle(center, RING_RADIUS + 8.0 + pulse * 6.0, Color(GOLD, 0.14 + pulse * 0.14))
	draw_circle(center, RING_RADIUS, Color(0.06, 0.03, 0.02, 0.72))

	var ring_color := Color(GOLD, 1.0) if selectable else Color(GOLD, 0.45)
	var spin := _time * TAU * SELECTABLE_TURNS_PER_SECOND if selectable else 0.0
	for i in DASH_COUNT:
		var start := spin + TAU * i / DASH_COUNT
		draw_arc(center, RING_RADIUS, start, start + TAU / DASH_COUNT * 0.6, 8, ring_color, 3.0, true)
	var arm := 12.0 if selectable else 8.0
	var mark_color := Color(GOLD, 0.6 + pulse * 0.4) if selectable else Color(GOLD, 0.3)
	draw_line(center - Vector2(arm, 0), center + Vector2(arm, 0), mark_color, 4.0, true)
	draw_line(center - Vector2(0, arm), center + Vector2(0, arm), mark_color, 4.0, true)


func show_hero(hero: Party.Hero) -> void:
	_hero = hero
	_portrait.visible = hero != null
	_crest.visible = hero != null
	_plate.visible = hero != null
	if hero != null:
		_portrait.texture = load(HeroOptions.RACES[hero.race].art)
		_crest.texture = load(HeroOptions.CLASSES[hero.hero_class].art)
		_name.text = hero.name
	show_form("")
	queue_redraw()


## Shows the form the hero has taken, see FORMS, or none for "".
func show_form(new_form: String) -> void:
	form = new_form if FORMS.has(new_form) else ""
	var look: Dictionary = FORMS.get(form, {})
	_form.visible = not look.is_empty()
	_form.texture = load(look.icon) if not look.is_empty() else null
	_portrait.self_modulate = look.get("tint", Color.WHITE)
	(_portrait.material as ShaderMaterial).set_shader_parameter("ring_color", look.get("ring", RING_COLOR))
	if _form.visible:
		_form.scale = Vector2(0.2, 0.2)
		create_tween().tween_property(_form, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	_hit.mouse_filter = MOUSE_FILTER_STOP if mode == Mode.SELECTABLE or mode == Mode.QUIET_SELECTABLE else MOUSE_FILTER_IGNORE
	# The tokens only need redrawing while their dashes are moving.
	set_process(mode == Mode.SELECTABLE or mode == Mode.ACTIVE)
	var target := Color(0.72, 0.72, 0.72, 0.7) if mode == Mode.DIMMED else Color.WHITE
	create_tween().tween_property(self, "modulate", target, 0.25)
	queue_redraw()


## Where the portrait is on screen, for pictures flying to this seat.
func portrait_center() -> Vector2:
	return get_global_transform() * (_portrait.position + _portrait.size / 2.0)


func portrait_size() -> Vector2:
	return _portrait.size


func pop() -> void:
	scale = Vector2(1.35, 1.35)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
