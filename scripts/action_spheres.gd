class_name ActionSpheres
extends Control
## A hero's actions left this round, as a row of orbs: blue for their turns, yellow for
## extra ones such as from Lightning, red for extra ones that only allow some cards.
## The first is played next and glows while it is being played.

const ORBS := {
	FightHero.Action.TURN: preload("res://assets/fight/action_orb_blue.png"),
	FightHero.Action.BONUS: preload("res://assets/fight/action_orb_yellow.png"),
	FightHero.Action.LIMITED: preload("res://assets/fight/action_orb_red.png"),
}
const RADIUS := 11.0
const GAP := 5.0
const GLOW_COLOR := Color(1.0, 0.95, 0.75)
## Each orb has a soft drop shadow and a thin dark rim, to stand out over the boss.
const SHADOW_OFFSET := Vector2(0.0, 2.5)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.22)
const RIM_WIDTH := 1.5
const RIM_COLOR := Color(0.07, 0.04, 0.02, 0.9)

var _actions: Array[FightHero.Action] = []
var _active := false
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## active: the first of them is being played now.
func show_actions(actions: Array[FightHero.Action], active := false) -> void:
	_actions = actions.duplicate()
	_active = active and not actions.is_empty()
	set_process(_active)
	var width := 0.0 if actions.is_empty() else actions.size() * RADIUS * 2.0 + (actions.size() - 1) * GAP
	custom_minimum_size = Vector2(width, RADIUS * 2.0 + 6.0)
	visible = not actions.is_empty()
	queue_redraw()


func actions() -> Array[FightHero.Action]:
	return _actions


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var y := size.y / 2.0
	for i in _actions.size():
		var center := Vector2(RADIUS + i * (RADIUS * 2.0 + GAP), y)
		if i == 0 and _active:
			var pulse := 0.5 + 0.5 * sin(_time * 5.0)
			draw_circle(center, RADIUS + 2.0 + pulse * 2.5, Color(GLOW_COLOR, 0.25 + pulse * 0.3))
		for spread in [3.5, 2.0, 0.5]:
			draw_circle(center + SHADOW_OFFSET, RADIUS + spread, SHADOW_COLOR)
		draw_circle(center, RADIUS + RIM_WIDTH, RIM_COLOR)
		var orb: Texture2D = ORBS[_actions[i]]
		draw_texture_rect(orb, Rect2(center - Vector2(RADIUS, RADIUS), Vector2(RADIUS, RADIUS) * 2.0), false)
