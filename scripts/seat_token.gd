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
## A hero who can be chosen grows and shrinks a little, to catch the players' eye.
const PULSE_SCALE := 0.1
const PULSE_SPEED := 5.0
## The glow around a hero who has a totem token (Fight.has_totem), as on the totem chip.
const TOTEM_COLOR := Color(0.25, 0.75, 0.7)

@export_range(0, 6) var seat := 0
## How far the token is turned: 0 faces the bottom edge, 90 the left and -90 the right.
@export var facing_degrees := 0.0

var mode := Mode.IDLE
## The form the hero here has taken (FightHero.form), which shows as another portrait,
## see HeroOptions.RACES. Empty for none.
var form := ""
## The hero here has a totem token, so their portrait glows.
var totem := false
var _hero: Party.Hero
var _time := 0.0
var _ring_radius := RING_RADIUS
## The fight shows no class crest (use_fight_look).
var _shows_crest := true

@onready var _portrait: TextureRect = $Portrait
@onready var _crest: TextureRect = $Crest
@onready var _plate: Control = $NamePlate
@onready var _name: Label = $NamePlate/Name
@onready var _hit: Button = $Hit


func _ready() -> void:
	pivot_offset = size / 2.0
	rotation_degrees = facing_degrees
	_center_pivots()
	_portrait.material = PortraitMaterial.new(0.5, 0.05)
	_crest.material = PortraitMaterial.new(0.5, 0.08)
	_hit.pressed.connect(pressed.emit)
	show_hero(null)
	set_mode(Mode.IDLE)


func _center_pivots() -> void:
	var middle := _portrait.position + _portrait.size / 2.0
	for picture: Control in [_portrait, _crest]:
		picture.pivot_offset = middle - picture.position


## The fight's look (BossFight): the portrait factor times as large, its bottom staying
## by the name plate, and no class crest. The seat itself keeps its size.
func use_fight_look(factor: float) -> void:
	_shows_crest = false
	_crest.hide()
	var old := Rect2(_portrait.position, _portrait.size)
	var grown := old.size * factor
	var rect := Rect2(Vector2(old.get_center().x - grown.x / 2.0, old.end.y - grown.y), grown)
	_portrait.position = rect.position
	_portrait.size = rect.size
	_ring_radius = RING_RADIUS * factor
	# The whole portrait can be tapped.
	_hit.offset_top = minf(0.0, rect.position.y)
	_center_pivots()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _pulsing():
		var grown := 1.0 + PULSE_SCALE * (0.5 - 0.5 * cos(_time * PULSE_SPEED))
		_scale_portrait(Vector2(grown, grown))
	queue_redraw()


func _pulsing() -> bool:
	return mode == Mode.SELECTABLE and _hero != null


func _scale_portrait(factor: Vector2) -> void:
	for picture: Control in [_portrait, _crest]:
		picture.scale = factor


func _draw() -> void:
	var center := _portrait.position + _portrait.size / 2.0
	var selectable := mode == Mode.SELECTABLE or mode == Mode.ACTIVE
	var pulse := 0.5 + 0.5 * sin(_time * 4.0) if selectable else 0.0
	if _hero != null:
		if totem:
			var glow := 0.5 + 0.5 * sin(_time * 2.0)
			draw_circle(center, _ring_radius + 6.0 + glow * 4.0, Color(TOTEM_COLOR, 0.22 + glow * 0.18))
		if mode == Mode.ACTIVE:
			draw_circle(center, _ring_radius + 8.0 + pulse * 6.0, Color(GOLD, 0.3 + pulse * 0.25))
		elif _pulsing():
			var grown := 0.5 - 0.5 * cos(_time * PULSE_SPEED)
			draw_circle(center, _ring_radius + 6.0 + grown * 10.0, Color(GOLD, 0.2 + grown * 0.3))
		return
	# A free seat sits in the middle of the space between the screen's edge and the panel.
	center = size / 2.0
	if selectable:
		draw_circle(center, _ring_radius + 8.0 + pulse * 6.0, Color(GOLD, 0.14 + pulse * 0.14))
	draw_circle(center, _ring_radius, Color(0.06, 0.03, 0.02, 0.72))

	var ring_color := Color(GOLD, 1.0) if selectable else Color(GOLD, 0.45)
	var spin := _time * TAU * SELECTABLE_TURNS_PER_SECOND if selectable else 0.0
	for i in DASH_COUNT:
		var start := spin + TAU * i / DASH_COUNT
		draw_arc(center, _ring_radius, start, start + TAU / DASH_COUNT * 0.6, 8, ring_color, 3.0, true)
	var arm := 12.0 if selectable else 8.0
	var mark_color := Color(GOLD, 0.6 + pulse * 0.4) if selectable else Color(GOLD, 0.3)
	draw_line(center - Vector2(arm, 0), center + Vector2(arm, 0), mark_color, 4.0, true)
	draw_line(center - Vector2(0, arm), center + Vector2(0, arm), mark_color, 4.0, true)


func show_hero(hero: Party.Hero) -> void:
	_hero = hero
	_portrait.visible = hero != null
	_crest.visible = hero != null and _shows_crest
	_plate.visible = hero != null
	if hero != null:
		_crest.texture = load(HeroOptions.CLASSES[hero.hero_class].art)
		_name.text = hero.name
	form = ""
	show_form("")
	show_totem(false)
	queue_redraw()


## Shows the form the hero has taken, as the portrait of that form, or the usual
## portrait for "" or a form without one.
func show_form(new_form: String) -> void:
	var race: Dictionary = HeroOptions.RACES[_hero.race] if _hero != null else {}
	var forms: Dictionary = race.get("forms", {})
	var old := form
	form = new_form if forms.has(new_form) else ""
	if race.is_empty():
		return
	_portrait.texture = load(forms[form] if not form.is_empty() else race.art)
	if form != old:
		_portrait.scale = Vector2(0.85, 0.85)
		create_tween().tween_property(_portrait, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_totem(has_totem: bool) -> void:
	if totem == has_totem:
		return
	totem = has_totem
	_update_process()
	queue_redraw()


func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	if not _pulsing():
		_scale_portrait(Vector2.ONE)
	_hit.mouse_filter = MOUSE_FILTER_STOP if mode == Mode.SELECTABLE or mode == Mode.QUIET_SELECTABLE else MOUSE_FILTER_IGNORE
	_update_process()
	var target := Color(0.72, 0.72, 0.72, 0.7) if mode == Mode.DIMMED else Color.WHITE
	create_tween().tween_property(self, "modulate", target, 0.25)
	queue_redraw()


## The tokens only need redrawing while something on them moves.
func _update_process() -> void:
	set_process(mode == Mode.SELECTABLE or mode == Mode.ACTIVE or totem)


## Where the portrait is on screen, for pictures flying to this seat.
func portrait_center() -> Vector2:
	return get_global_transform() * (_portrait.position + _portrait.size / 2.0)


func portrait_size() -> Vector2:
	return _portrait.size


## Where the portrait is, in the seat's own coordinates.
func portrait_rect() -> Rect2:
	return Rect2(_portrait.position, _portrait.size)


func pop() -> void:
	scale = Vector2(1.35, 1.35)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
