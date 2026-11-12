class_name CountdownBar
extends Control
## The bar in a message's check mark that runs down until the message closes by itself
## (see MessageBox): a glowing ember in a groove pressed into the gold, which burns
## hotter, and flickers, as it runs out.

## How much is left, from 1 (full) to 0 (empty).
@export_range(0.0, 1.0) var value := 1.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()

## Below this much left, the ember turns hot and flickers.
const LOW := 0.3
const GROOVE := Color(0.34, 0.16, 0.03, 0.9)
const GROOVE_SHADOW := Color(0.14, 0.05, 0.0, 0.6)
const GROOVE_RIM := Color(1.0, 0.92, 0.6, 0.55)
const FILL_TOP := Color(1.0, 0.94, 0.7)
const FILL_BOTTOM := Color(0.93, 0.45, 0.08)
const HOT_TOP := Color(1.0, 0.86, 0.6)
const HOT_BOTTOM := Color(0.86, 0.22, 0.06)
const GLOW := Color(1.0, 0.85, 0.45)

var _time := 0.0
var _box := StyleBoxFlat.new()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var r := size.y / 2.0
	var groove := Rect2(Vector2.ZERO, size)
	# The groove: a light rim below and a shadow along its top make it look pressed in.
	_round_rect(groove.grow_individual(1, 1, 1, 2), GROOVE_RIM, r + 1)
	_round_rect(groove, GROOVE, r)
	_round_rect(Rect2(groove.position, Vector2(size.x, size.y * 0.45)), GROOVE_SHADOW, r)

	if value <= 0.0:
		return
	# Hotter, and flickering, as it runs low.
	var heat := clampf((LOW - value) / LOW, 0.0, 1.0)
	var flicker := 1.0 + heat * 0.18 * sin(_time * 14.0)
	var top := FILL_TOP.lerp(HOT_TOP, heat)
	var bottom := FILL_BOTTOM.lerp(HOT_BOTTOM, heat)
	var inset := 2.0
	var inner := groove.grow(-inset)
	var width := maxf(inner.size.y, inner.size.x * value)
	var fill := Rect2(inner.position, Vector2(width, inner.size.y))
	var fr := fill.size.y / 2.0

	# A soft glow around the ember, spilling onto the gold.
	for i in 3:
		var spread := 2.0 + i * 2.5
		var glow := GLOW.lerp(bottom, 0.4)
		glow.a = (0.22 - i * 0.06) * flicker
		_round_rect(fill.grow(spread), glow, fr + spread)

	# The ember: light on top, deep below, with a shine along its top.
	_round_rect(fill, bottom, fr)
	_round_rect(Rect2(fill.position, Vector2(fill.size.x, fill.size.y * 0.6)), top, fr)
	var shine := Rect2(fill.position + Vector2(fr, 1.0), Vector2(maxf(0.0, fill.size.x - 2.0 * fr), maxf(1.0, fill.size.y * 0.22)))
	if shine.size.x > 0.0:
		draw_rect(shine, Color(1, 1, 1, 0.45))

	# The burning tip, where it runs down.
	var tip := Vector2(fill.end.x - fr, fill.get_center().y)
	var pulse := 0.85 + 0.15 * sin(_time * 6.0)
	draw_circle(tip, fr * 2.6 * pulse, Color(GLOW, 0.18 * flicker))
	draw_circle(tip, fr * 1.6 * pulse, Color(GLOW, 0.35 * flicker))
	draw_circle(tip, fr * 0.9, Color(1, 1, 0.92, 0.95))


func _round_rect(rect: Rect2, color: Color, radius: float) -> void:
	_box.bg_color = color
	_box.set_corner_radius_all(roundi(radius))
	draw_style_box(_box, rect)
