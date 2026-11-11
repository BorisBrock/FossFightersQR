extends Control
## A panel the table shows in place of the party, such as the boss list (see
## scripts/onboarding.gd). It animates its parts in and out instead of changing the scene,
## and only takes taps while fully shown.

## Back, Escape or the back button of a phone.
signal back_pressed

const IN_SEC := 0.35
const OUT_SEC := 0.25
## Between one part and the next, from the top down.
const STAGGER_SEC := 0.06

## Fully shown: taps count. Off while animating, and after a tap that leads on.
var active := false

@onready var stage: PanelContainer = $Stage


## Leads to what was shown before, if the panel takes taps. The table calls this for
## Escape and the back button of a phone, too.
func request_back() -> void:
	if active:
		active = false
		back_pressed.emit()


## Shows the panel, its parts one after the other. Returns once all are in.
func play_in() -> void:
	active = false
	show()
	var parts := _parts()
	stage.self_modulate.a = 0.0
	for part: Control in parts:
		part.modulate.a = 0.0
	# The parts need their places to pivot around.
	await get_tree().process_frame
	var appear := create_tween().set_parallel()
	appear.tween_property(stage, "self_modulate:a", 1.0, IN_SEC)
	var delay := 0.1
	for part: Control in parts:
		_pop_in(appear, part, delay)
		delay += STAGGER_SEC
	await appear.finished
	active = true


## Fades the parts out, the panel behind them last, and hides it. Returns once it is gone.
func play_out() -> void:
	active = false
	var vanish := create_tween().set_parallel()
	var delay := 0.0
	for part: Control in _parts():
		if part.modulate.a > 0.0:
			_shrink_out(vanish, part, delay)
			delay += STAGGER_SEC * 0.5
	vanish.tween_property(stage, "self_modulate:a", 0.0, OUT_SEC).set_delay(delay)
	await vanish.finished
	hide()


## What animates in, from the top down. Each panel says which.
func _parts() -> Array[Control]:
	return []


func _pop_in(tween: Tween, part: Control, delay: float) -> void:
	part.pivot_offset = part.size / 2.0
	part.scale = Vector2(0.9, 0.9)
	tween.tween_property(part, "modulate:a", 1.0, IN_SEC * 0.8).set_delay(delay)
	tween.tween_property(part, "scale", Vector2.ONE, IN_SEC).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shrink_out(tween: Tween, part: Control, delay: float) -> void:
	part.pivot_offset = part.size / 2.0
	tween.tween_property(part, "modulate:a", 0.0, OUT_SEC).set_delay(delay)
	tween.tween_property(part, "scale", Vector2(0.92, 0.92), OUT_SEC).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
