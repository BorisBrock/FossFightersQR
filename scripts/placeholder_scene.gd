extends Node2D
## Stands in for the game's animated scene until it exists: a few slowly orbiting
## dots, so that there is motion on screen and power measurements stay realistic.

const DOT_COUNT := 12
const ORBIT_RADIUS := 220.0
const DOT_RADIUS := 12.0
const TURNS_PER_SECOND := 0.05
const DOT_COLOR := Color(0.25, 0.55, 0.8)

var _angle := 0.0


func _process(delta: float) -> void:
	_angle += delta * TURNS_PER_SECOND * TAU
	queue_redraw()


func _draw() -> void:
	var center := get_viewport_rect().size / 2.0
	for i in DOT_COUNT:
		var direction := Vector2.from_angle(_angle + TAU * i / DOT_COUNT)
		draw_circle(center + direction * ORBIT_RADIUS, DOT_RADIUS, DOT_COLOR)
