class_name ActionSpheres
extends Control
## A hero's actions left this round, as a row of spheres: blue for their turns, yellow
## for extra ones such as from Lightning, red for extra ones that only allow some cards.
## The first is played next and glows while it is being played.

const COLORS := {
	FightHero.Action.TURN: Color(0.3, 0.58, 1.0),
	FightHero.Action.BONUS: Color(1.0, 0.82, 0.25),
	FightHero.Action.LIMITED: Color(0.95, 0.3, 0.25),
}
const RADIUS := 11.0
const GAP := 5.0
const GLOW_COLOR := Color(1.0, 0.95, 0.75)

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
	custom_minimum_size = Vector2(width, RADIUS * 2.0 + 4.0)
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
		var color: Color = COLORS[_actions[i]]
		if i == 0 and _active:
			var pulse := 0.5 + 0.5 * sin(_time * 5.0)
			draw_circle(center, RADIUS + 2.0 + pulse * 2.5, Color(GLOW_COLOR, 0.25 + pulse * 0.3))
		# A dark rim, the ball, and a light from the top left make it a sphere.
		draw_circle(center, RADIUS + 1.0, Color(0.05, 0.03, 0.02, 0.9))
		draw_circle(center, RADIUS, color.darkened(0.35))
		draw_circle(center + Vector2(-1.0, -1.0), RADIUS * 0.78, color)
		draw_circle(center + Vector2(-RADIUS * 0.35, -RADIUS * 0.35), RADIUS * 0.3, Color(1, 1, 1, 0.75))
