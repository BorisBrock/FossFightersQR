class_name Splash
extends ColorRect
## Takes over from the engine's boot splash with the same picture in the same place, holds
## it for a moment and then fades to reveal the table. A tap skips the wait.

## The table should start its intro now, as the fade has begun.
signal revealing

const HOLD_SEC := 0.9
const FADE_SEC := 0.5

var _hold: Tween
var _revealed := false

@onready var _logo: Control = $Logo


func _ready() -> void:
	resized.connect(func() -> void: _logo.pivot_offset = _logo.size / 2.0)
	_logo.pivot_offset = _logo.size / 2.0
	_hold = create_tween()
	_hold.tween_property(_logo, "scale", Vector2(1.03, 1.03), HOLD_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hold.tween_callback(_reveal)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:
		_reveal()


func _reveal() -> void:
	if _revealed:
		return
	_revealed = true
	_hold.kill()
	# Taps during the fade are already for the table underneath.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	revealing.emit()
	var fade := create_tween().set_parallel()
	fade.tween_property(self, "modulate:a", 0.0, FADE_SEC)
	fade.tween_property(_logo, "scale", Vector2(1.1, 1.1), FADE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade.chain().tween_callback(queue_free)
