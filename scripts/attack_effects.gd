class_name AttackEffects
extends Control
## The big effects over the boss when a hero attacks it, one for each damage type, each
## with its sound: bolts of magic that splash on the boss, a sword's slash across it, and
## a volley of arrows. Also a shield breaking into shards (shatter()).
##
## They are made of particles (CPUParticles2D) and sprites from assets/fight/particles/,
## and vary each time: where they hit, from where, in which colours and how many.
##
## play() starts one, and takes duration() seconds, until the last hit; what it leaves
## behind fades out meanwhile. At each hit, impact tells the screen, which lights the boss
## up and shakes it.

## Something hit the boss at point (in this control's coordinates), as hard as strength,
## from 0 to 1, in color.
signal impact(point: Vector2, strength: float, color: Color)

const STAR := preload("res://assets/fight/particles/star_04.png")
const STAR_BRIGHT := preload("res://assets/fight/particles/star_06.png")
const STAR_LONG := preload("res://assets/fight/particles/star_07.png")
const STAR_CROSS := preload("res://assets/fight/particles/star_08.png")
const DOT := preload("res://assets/fight/particles/circle_05.png")
const RING := preload("res://assets/fight/particles/circle_02.png")
const GLOW := preload("res://assets/fight/particles/magic_05.png")
const RUNES: Array[Texture2D] = [
	preload("res://assets/fight/particles/magic_01.png"),
	preload("res://assets/fight/particles/magic_02.png"),
]
const SPARKS: Array[Texture2D] = [
	preload("res://assets/fight/particles/spark_01.png"),
	preload("res://assets/fight/particles/spark_02.png"),
]
const STREAK := preload("res://assets/fight/particles/trace_07.png")
const DUST: Array[Texture2D] = [
	preload("res://assets/fight/particles/dirt_01.png"),
	preload("res://assets/fight/particles/dirt_02.png"),
]
const SWIRL := preload("res://assets/fight/particles/twirl_02.png")

## Magic: bolts from the heroes around the table, launched within MAGIC_WINDOW_SEC, each
## flying for MAGIC_FLIGHT_SEC.
const MAGIC_BOLTS := Vector2i(4, 5)
const MAGIC_WINDOW_SEC := 0.7
const MAGIC_FLIGHT_SEC := Vector2(0.32, 0.42)
const MAGIC_COLORS: Array[Color] = [
	Color(0.7, 0.42, 1.0), Color(0.38, 0.62, 1.0), Color(1.0, 0.42, 0.92), Color(0.4, 0.95, 1.0),
]
## Ranged: a volley of arrows from the bottom of the screen.
const ARROWS := Vector2i(5, 7)
const ARROW_WINDOW_SEC := 0.6
const ARROW_FLIGHT_SEC := Vector2(0.2, 0.26)
const ARROW_LENGTH := 84.0
const ARROW_SCALE := 1.8
## Melee: one slash, more for stronger attacks, each SLASH_GAP_SEC after the last. The
## blade crosses the boss in SLASH_SWING_SEC and hits halfway.
const SLASH_GAP_SEC := 0.32
const SLASH_SWING_SEC := 0.14
const MAX_SLASHES := 3
const SLASH_COLORS: Array[Color] = [Color(0.55, 0.82, 1.0), Color(1.0, 0.72, 0.32), Color(1.0, 0.4, 0.32)]
## After the last hit, before the screen goes on.
const AFTER_SEC := 0.35
## A broken shield's shards fly for this long.
const SHATTER_SEC := 0.9
const SHARDS := 9

var sfx: Sfx
var rng := RandomNumberGenerator.new()

var _additive: CanvasItemMaterial
var _shrink: Curve
var _swell_and_shrink: Curve


func _init() -> void:
	name = "AttackEffects"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_additive = CanvasItemMaterial.new()
	_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_shrink = Curve.new()
	_shrink.add_point(Vector2(0.0, 1.0))
	_shrink.add_point(Vector2(1.0, 0.0))
	_swell_and_shrink = Curve.new()
	_swell_and_shrink.add_point(Vector2(0.0, 0.3))
	_swell_and_shrink.add_point(Vector2(0.2, 1.0))
	_swell_and_shrink.add_point(Vector2(1.0, 0.0))
	rng.randomize()


## How long the effect of an attack of kind with amount takes, until its last hit and a
## little after. 0 for kinds without one.
static func duration(kind: String, amount: int) -> float:
	match kind:
		"magic":
			return MAGIC_WINDOW_SEC + MAGIC_FLIGHT_SEC.y + AFTER_SEC
		"ranged":
			return ARROW_WINDOW_SEC + ARROW_FLIGHT_SEC.y + AFTER_SEC
		"melee":
			return SLASH_GAP_SEC * (slashes(amount) - 1) + SLASH_SWING_SEC + AFTER_SEC + 0.15
	return 0.0


## How many times the blade strikes for a melee attack of amount.
static func slashes(amount: int) -> int:
	return clampi(1 + amount / 3, 1, MAX_SLASHES)


## Plays the effect of an attack of kind with amount on the boss, which is in area (in
## this control's coordinates).
func play(kind: String, amount: int, area: Rect2) -> void:
	match kind:
		"magic":
			_magic(area)
		"ranged":
			_ranged(area)
		"melee":
			_melee(area, amount)


#region Magic
## Bolts of magic fly in from the heroes around the table and splash on the boss, each in
## a colour of its own.
func _magic(area: Rect2) -> void:
	var count := rng.randi_range(MAGIC_BOLTS.x, MAGIC_BOLTS.y)
	var first := rng.randi() % MAGIC_COLORS.size()
	for i in count:
		var launch := clampf(MAGIC_WINDOW_SEC * (i + rng.randf_range(-0.3, 0.3)) / (count - 1), 0.0, MAGIC_WINDOW_SEC)
		var color := MAGIC_COLORS[(first + i) % MAGIC_COLORS.size()].lerp(Color.WHITE, rng.randf_range(0.0, 0.2))
		var flight := rng.randf_range(MAGIC_FLIGHT_SEC.x, MAGIC_FLIGHT_SEC.y)
		_later(launch, _magic_bolt.bind(_from_the_table(), _point_in(area), color, flight))


func _magic_bolt(start: Vector2, target: Vector2, color: Color, flight: float) -> void:
	var bolt := Node2D.new()
	bolt.position = start
	add_child(bolt)
	var trail := _emitter(bolt, DOT, 70, 0.45, Vector2(0.1, 0.24), _ramp([Color.WHITE, color, Color(color, 0.0)]))
	trail.initial_velocity_min = 10.0
	trail.initial_velocity_max = 60.0
	var glitter := _emitter(bolt, STAR, 18, 0.6, Vector2(0.08, 0.17), _ramp([Color.WHITE, color, Color(color, 0.0)]))
	glitter.initial_velocity_min = 40.0
	glitter.initial_velocity_max = 130.0
	glitter.angular_velocity_min = -360.0
	glitter.angular_velocity_max = 360.0
	var glow := _sprite(GLOW, Vector2.ZERO, color, 0.7, bolt)
	var core := _sprite(STAR_BRIGHT, Vector2.ZERO, Color.WHITE, 0.32, bolt)

	# A curve, different for each bolt.
	var bend := (target - start).orthogonal() * rng.randf_range(-0.3, 0.3)
	var control := (start + target) / 2.0 + bend
	var spin := rng.randf_range(6.0, 12.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		bolt.position = _bezier(start, control, target, t)
		core.rotation = t * spin
		glow.scale = Vector2.ONE * (0.62 + 0.14 * sin(t * 40.0)), 0.0, 1.0, flight).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		glow.hide()
		core.hide()
		trail.emitting = false
		glitter.emitting = false
		_magic_splash(target, color))
	tween.tween_interval(0.6)
	tween.tween_callback(bolt.queue_free)


func _magic_splash(at: Vector2, color: Color) -> void:
	impact.emit(at, 0.55, color)
	if sfx != null:
		sfx.play("magic_hit", rng.randf_range(0.88, 1.15))
	_pulse(GLOW, at, color, 0.5, 1.8, 0.45)
	_pulse(STAR_CROSS, at, Color.WHITE, 1.1, 0.2, 0.28, rng.randf_range(-1.0, 1.0))
	_pulse(RING, at, color.lightened(0.2), 0.1, rng.randf_range(0.9, 1.2), 0.5)
	var rune := _pulse(RUNES[rng.randi() % RUNES.size()], at, color.lightened(0.35), 0.25, rng.randf_range(0.75, 0.95), 0.65, rng.randf_range(-1.2, 1.2))
	rune.rotation = rng.randf() * TAU
	var spark := _sprite(SPARKS[rng.randi() % SPARKS.size()], at, color.lightened(0.5), rng.randf_range(0.6, 0.8))
	spark.rotation = rng.randf() * TAU
	var flicker := create_tween()
	flicker.tween_interval(0.06)
	flicker.tween_callback(func() -> void: spark.rotation += PI * 0.6)
	flicker.tween_property(spark, "modulate:a", 0.0, 0.18)
	flicker.tween_callback(spark.queue_free)

	var sparks := _burst(at, STAR, 28, 0.8, Vector2(260.0, 720.0), Vector2(0.09, 0.22), _ramp([Color.WHITE, color, Color(color, 0.0)]))
	sparks.damping_min = 500.0
	sparks.damping_max = 850.0
	sparks.angular_velocity_min = -400.0
	sparks.angular_velocity_max = 400.0
	var motes := _burst(at, DOT, 16, 1.1, Vector2(40.0, 200.0), Vector2(0.07, 0.16), _ramp([Color(color, 0.0), color.lightened(0.3), Color(color, 0.0)], [0.0, 0.2, 1.0]))
	motes.gravity = Vector2(0.0, -90.0)
	_flash_screen(color, 0.1, 0.25)
#endregion


#region Ranged
## A volley of arrows from the bottom of the screen, where the heroes are. Each one sticks
## in the boss, quivers and fades.
func _ranged(area: Rect2) -> void:
	var count := rng.randi_range(ARROWS.x, ARROWS.y)
	var archer := rng.randf_range(0.3, 0.7) * size.x
	for i in count:
		var launch := clampf(ARROW_WINDOW_SEC * (i + rng.randf_range(-0.35, 0.35)) / (count - 1), 0.0, ARROW_WINDOW_SEC)
		var start := Vector2(archer + rng.randf_range(-0.4, 0.4) * size.x, size.y + 100.0)
		var flight := rng.randf_range(ARROW_FLIGHT_SEC.x, ARROW_FLIGHT_SEC.y)
		_later(launch, _arrow.bind(start, _point_in(area), flight))


func _arrow(start: Vector2, target: Vector2, flight: float) -> void:
	var arrow := Arrow.new()
	arrow.length = ARROW_LENGTH * rng.randf_range(0.9, 1.1)
	arrow.fletching = [Color(0.78, 0.16, 0.12), Color(0.95, 0.92, 0.85), Color(0.2, 0.45, 0.25)][rng.randi() % 3]
	arrow.position = start
	arrow.scale = Vector2.ONE * ARROW_SCALE * rng.randf_range(0.9, 1.1)
	add_child(arrow)
	var streak := _sprite(STREAK, Vector2(-arrow.length * 0.9, 0.0), Color(1.0, 0.92, 0.75, 0.6), 1.0, arrow)
	streak.rotation = PI / 2.0
	streak.scale = Vector2(0.18, 0.9)

	# A flat arc, as arrows fly.
	var control := (start + target) / 2.0 + Vector2(0.0, -start.distance_to(target) * rng.randf_range(0.08, 0.2))
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		arrow.position = _bezier(start, control, target, t)
		arrow.rotation = (_bezier(start, control, target, minf(1.0, t + 0.02)) - _bezier(start, control, target, maxf(0.0, t - 0.02))).angle(), 0.0, 1.0, flight)
	# As it arrives.
	var direction := (target - control).normalized()
	tween.tween_callback(func() -> void:
		streak.queue_free()
		_arrow_hit(target, direction))
	# It sinks in, quivers, and fades.
	tween.tween_method(func(t: float) -> void: arrow.position = target + direction * 22.0 * t, 0.0, 1.0, 0.05)
	tween.tween_method(func(t: float) -> void: arrow.rotation = direction.angle() + sin(t * 42.0) * 0.1 * (1.0 - t), 0.0, 1.0, 0.4)
	tween.tween_interval(0.2)
	tween.tween_property(arrow, "modulate:a", 0.0, 0.3)
	tween.tween_callback(arrow.queue_free)


func _arrow_hit(at: Vector2, direction: Vector2) -> void:
	var warm := Color(1.0, 0.82, 0.5)
	impact.emit(at, 0.35, warm)
	if sfx != null:
		sfx.play("arrow_hit", rng.randf_range(0.88, 1.18))
	_pulse(STAR_LONG, at, Color.WHITE, 0.8, 0.1, 0.2, rng.randf_range(-0.5, 0.5)).rotation = rng.randf() * TAU
	_pulse(RING, at, warm, 0.06, 0.5, 0.3)
	_pulse(GLOW, at, warm, 0.3, 0.9, 0.3)
	var dust := _pulse(DUST[rng.randi() % DUST.size()], at, Color(0.62, 0.5, 0.38, 0.85), 0.15, rng.randf_range(0.5, 0.7), 0.55, rng.randf_range(-0.6, 0.6))
	dust.material = null
	dust.rotation = rng.randf() * TAU
	# Splinters fly back, and fall.
	var splinters := _burst(at, STREAK, 12, 0.65, Vector2(300.0, 750.0), Vector2(0.1, 0.18), _ramp([Color(0.95, 0.8, 0.55), Color(0.6, 0.42, 0.25), Color(0.5, 0.35, 0.2, 0.0)]))
	splinters.material = null
	splinters.direction = -direction
	splinters.spread = 55.0
	splinters.gravity = Vector2(0.0, 1300.0)
	splinters.particle_flag_align_y = true
	var sparks := _burst(at, STAR, 12, 0.45, Vector2(200.0, 560.0), Vector2(0.07, 0.15), _ramp([Color.WHITE, warm, Color(warm, 0.0)]))
	sparks.damping_min = 500.0
	sparks.damping_max = 800.0
	_flash_screen(warm, 0.05, 0.15)
#endregion


#region Melee
## The blade slashes across the boss, once or more, each at another angle.
func _melee(area: Rect2, amount: int) -> void:
	var color := SLASH_COLORS[rng.randi() % SLASH_COLORS.size()]
	var angle := rng.randf_range(0.5, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	for i in slashes(amount):
		_later(SLASH_GAP_SEC * i, _slash.bind(area, angle, color))
		# The next crosses this one.
		angle = -angle + rng.randf_range(-0.25, 0.25)


func _slash(area: Rect2, angle: float, color: Color) -> void:
	var center := area.get_center() + Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.15, 0.05)) * area.size
	var reach := maxf(area.size.x, area.size.y * 0.7) * rng.randf_range(1.0, 1.25)
	var along := Vector2.from_angle(angle)
	if rng.randf() < 0.5:
		along = -along
	var start := center - along * reach / 2.0
	var end := center + along * reach / 2.0
	var control := center + along.orthogonal() * reach * rng.randf_range(0.08, 0.2) * (1.0 if rng.randf() < 0.5 else -1.0)
	var path := PackedVector2Array()
	for i in 33:
		path.append(_bezier(start, control, end, i / 32.0))

	var slash := Slash.new()
	slash.material = _additive
	slash.path = path
	slash.width = rng.randf_range(30.0, 42.0)
	slash.color = color
	add_child(slash)
	var glint := _sprite(STAR_CROSS, start, Color.WHITE, 0.5)
	if sfx != null:
		sfx.play("slash", rng.randf_range(0.92, 1.1))

	var swing := create_tween()
	swing.tween_method(func(t: float) -> void:
		slash.head = t
		slash.queue_redraw()
		glint.position = slash.point_at(t)
		glint.rotation = t * 3.0, 0.0, 1.0, SLASH_SWING_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swing.tween_callback(glint.queue_free)
	var fade := create_tween()
	fade.tween_interval(SLASH_SWING_SEC * 0.55)
	fade.tween_method(func(t: float) -> void:
		slash.tail = t
		slash.queue_redraw(), 0.0, 1.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.tween_callback(slash.queue_free)
	_later(SLASH_SWING_SEC * 0.5, _slash_hit.bind(path, center, color))


## The blade hits: the screen flashes, sparks fly off along the cut, which glows a while.
func _slash_hit(path: PackedVector2Array, center: Vector2, color: Color) -> void:
	impact.emit(center, 1.0, color)
	_flash_screen(Color.WHITE, 0.18, 0.25)
	_pulse(GLOW, center, color, 0.5, 1.4, 0.35)

	var cut := Slash.new()
	cut.material = _additive
	cut.path = path
	cut.width = 9.0
	cut.color = color.lerp(Color(1.0, 0.25, 0.15), 0.5)
	cut.head = 1.0
	add_child(cut)
	var glow := create_tween()
	glow.tween_interval(0.12)
	glow.tween_property(cut, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	glow.tween_callback(cut.queue_free)

	# Sparks off both sides of the cut.
	var points := PackedVector2Array()
	var normals := PackedVector2Array()
	for i in range(2, path.size() - 2):
		var across := (path[i + 1] - path[i - 1]).orthogonal().normalized()
		for side: float in [1.0, -1.0]:
			points.append(path[i])
			normals.append(across * side)
	var sparks := _burst(Vector2.ZERO, STREAK, 56, 0.55, Vector2(300.0, 900.0), Vector2(0.08, 0.15), _ramp([Color.WHITE, color, Color(color, 0.0)]))
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_DIRECTED_POINTS
	sparks.emission_points = points
	sparks.emission_normals = normals
	sparks.spread = 30.0
	sparks.damping_min = 500.0
	sparks.damping_max = 900.0
	sparks.particle_flag_align_y = true
	sparks.gravity = Vector2(0.0, 300.0)
	var stars := _burst(Vector2.ZERO, STAR, 18, 0.7, Vector2(80.0, 320.0), Vector2(0.08, 0.18), _ramp([Color.WHITE, color, Color(color, 0.0)]))
	stars.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	stars.emission_points = points
	stars.damping_min = 200.0
	stars.damping_max = 300.0
#endregion


#region Shields
## The picture of a shield breaks into shards, which fly apart and fall. The picture
## itself is left to the caller to hide.
func shatter(picture: TextureRect, color := Color(1.0, 0.86, 0.55)) -> void:
	var texture := picture.texture
	if texture == null:
		return
	var to_here := get_global_transform().affine_inverse() * picture.get_global_transform()
	var texture_size := texture.get_size()
	var fit := minf(picture.size.x / texture_size.x, picture.size.y / texture_size.y)
	var drawn := Rect2((picture.size - texture_size * fit) / 2.0, texture_size * fit)
	var center := drawn.get_center() + Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.08)) * drawn.size
	# Cracks from near the middle to the edge, and the corners, in order around it.
	var rim: Array[Vector2] = [drawn.position, drawn.position + Vector2(drawn.size.x, 0.0), drawn.end, drawn.position + Vector2(0.0, drawn.size.y)]
	for i in SHARDS:
		rim.append(_to_edge(center, TAU * (i + rng.randf_range(-0.3, 0.3)) / SHARDS, drawn))
	rim.sort_custom(func(a: Vector2, b: Vector2) -> bool: return (a - center).angle() < (b - center).angle())
	for i in rim.size():
		var a := rim[i]
		var b := rim[(i + 1) % rim.size()]
		if a.distance_to(b) < 2.0:
			continue
		var middle := (center + a + b) / 3.0
		var shard := Polygon2D.new()
		shard.texture = texture
		shard.polygon = PackedVector2Array([center - middle, a - middle, b - middle])
		shard.uv = PackedVector2Array([(center - drawn.position) / fit, (a - drawn.position) / fit, (b - drawn.position) / fit])
		shard.transform = to_here * Transform2D(0.0, middle)
		add_child(shard)
		var from := shard.position
		var velocity := (middle - center).normalized() * rng.randf_range(150.0, 320.0) + Vector2(0.0, -rng.randf_range(120.0, 260.0))
		var spin := rng.randf_range(-10.0, 10.0)
		var turn := shard.rotation
		var tween := create_tween()
		tween.tween_method(func(t: float) -> void:
			shard.position = from + velocity * t + Vector2(0.0, 1100.0) * t * t / 2.0
			shard.rotation = turn + spin * t, 0.0, SHATTER_SEC, SHATTER_SEC)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, 0.35).set_delay(SHATTER_SEC - 0.35)
		tween.tween_callback(shard.queue_free)

	var at := to_here * drawn.get_center()
	_pulse(STAR_CROSS, at, Color.WHITE, 1.1, 0.2, 0.35, 0.8)
	_pulse(GLOW, at, color, 0.4, 1.3, 0.4)
	_pulse(RING, at, color, 0.1, 0.95, 0.5)
	_pulse(SWIRL, at, color, 0.3, 0.8, 0.45, 2.5).rotation = rng.randf() * TAU
	var sparks := _burst(at, STAR, 26, 0.8, Vector2(220.0, 620.0), Vector2(0.08, 0.18), _ramp([Color.WHITE, color, Color(color, 0.0)]))
	sparks.damping_min = 300.0
	sparks.damping_max = 500.0
	sparks.gravity = Vector2(0.0, 500.0)


## A shield takes a hit: a small spark on it.
func spark(picture: Control, color := Color(1.0, 0.86, 0.55)) -> void:
	var to_here := get_global_transform().affine_inverse() * picture.get_global_transform()
	var at := to_here * (picture.size * Vector2(rng.randf_range(0.3, 0.7), rng.randf_range(0.25, 0.6)))
	_pulse(STAR_LONG, at, Color.WHITE, 0.55, 0.08, 0.18, 1.0).rotation = rng.randf() * TAU
	var sparks := _burst(at, STAR, 9, 0.4, Vector2(160.0, 420.0), Vector2(0.05, 0.11), _ramp([Color.WHITE, color, Color(color, 0.0)]))
	sparks.damping_min = 400.0
	sparks.damping_max = 600.0


## Where a ray from inside rect at angle leaves it.
func _to_edge(from: Vector2, angle: float, rect: Rect2) -> Vector2:
	var direction := Vector2.from_angle(angle)
	var distance := INF
	if not is_zero_approx(direction.x):
		distance = minf(distance, ((rect.end.x if direction.x > 0.0 else rect.position.x) - from.x) / direction.x)
	if not is_zero_approx(direction.y):
		distance = minf(distance, ((rect.end.y if direction.y > 0.0 else rect.position.y) - from.y) / direction.y)
	return from + direction * distance
#endregion


#region Building blocks
## A spot on the boss, away from the edges of its picture, where its body is.
func _point_in(area: Rect2) -> Vector2:
	return area.position + area.size * Vector2(rng.randf_range(0.25, 0.75), rng.randf_range(0.2, 0.65))


## Somewhere around the lower part of the screen, just outside it: where the heroes sit.
func _from_the_table() -> Vector2:
	match rng.randi() % 3:
		0:
			return Vector2(-40.0, rng.randf_range(0.45, 0.95) * size.y)
		1:
			return Vector2(size.x + 40.0, rng.randf_range(0.45, 0.95) * size.y)
	return Vector2(rng.randf_range(0.1, 0.9) * size.x, size.y + 40.0)


func _bezier(a: Vector2, control: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(control, t).lerp(control.lerp(b, t), t)


func _later(seconds: float, action: Callable) -> void:
	if seconds <= 0.0:
		action.call()
		return
	create_tween().tween_callback(action).set_delay(seconds)


func _ramp(colors: Array[Color], offsets: Array[float] = []) -> Gradient:
	var ramp := Gradient.new()
	if offsets.is_empty():
		for i in colors.size():
			offsets.append(float(i) / (colors.size() - 1))
	ramp.offsets = PackedFloat32Array(offsets)
	ramp.colors = PackedColorArray(colors)
	return ramp


## A glowing sprite (added to what is under it), at at in parent, sized as scale of its
## 256 pixels.
func _sprite(texture: Texture2D, at: Vector2, color: Color, sprite_scale: float, parent: Node = self) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.material = _additive
	sprite.position = at
	sprite.modulate = color
	sprite.scale = Vector2.ONE * sprite_scale
	parent.add_child(sprite)
	return sprite


## A sprite that grows (or shrinks) from one scale to the other and fades, turning by spin.
func _pulse(texture: Texture2D, at: Vector2, color: Color, from: float, to: float, seconds: float, spin := 0.0) -> Sprite2D:
	var sprite := _sprite(texture, at, color, from)
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "scale", Vector2.ONE * to, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if spin != 0.0:
		tween.tween_property(sprite, "rotation", spin, seconds).as_relative()
	tween.chain().tween_callback(sprite.queue_free)
	return sprite


## Particles that keep coming while emitting, left behind where they came from.
func _emitter(parent: Node, texture: Texture2D, amount: int, lifetime: float, sprite_scale: Vector2, colors: Gradient) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.material = _additive
	particles.texture = texture
	particles.amount = amount
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.spread = 180.0
	particles.angle_min = -180.0
	particles.angle_max = 180.0
	particles.scale_amount_min = sprite_scale.x
	particles.scale_amount_max = sprite_scale.y
	particles.scale_amount_curve = _shrink
	particles.color_ramp = colors
	particles.gravity = Vector2.ZERO
	parent.add_child(particles)
	particles.emitting = true
	return particles


## Particles that burst out all at once, and go away when they are done.
func _burst(at: Vector2, texture: Texture2D, amount: int, lifetime: float, speed: Vector2, sprite_scale: Vector2, colors: Gradient) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.material = _additive
	particles.texture = texture
	particles.position = at
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.5
	particles.lifetime_randomness = 0.4
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = speed.x
	particles.initial_velocity_max = speed.y
	particles.angle_min = -180.0
	particles.angle_max = 180.0
	particles.scale_amount_min = sprite_scale.x
	particles.scale_amount_max = sprite_scale.y
	particles.scale_amount_curve = _swell_and_shrink
	particles.color_ramp = colors
	add_child(particles)
	particles.emitting = true
	_later(lifetime + 0.2, particles.queue_free)
	return particles


## The whole screen lights up in color, and fades.
func _flash_screen(color: Color, alpha: float, seconds: float) -> void:
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.material = _additive
	flash.color = Color(color, alpha)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, seconds).set_ease(Tween.EASE_OUT)
	tween.tween_callback(flash.queue_free)
#endregion


## An arrow, its tip at the origin, pointing to the right.
class Arrow:
	extends Node2D

	var length := 84.0
	var fletching := Color(0.78, 0.16, 0.12)

	func _draw() -> void:
		var wood := Color(0.5, 0.33, 0.18)
		draw_line(Vector2(-length, 0.0), Vector2(-6.0, 0.0), Color(0.12, 0.07, 0.03), 6.0)
		draw_line(Vector2(-length, 0.0), Vector2(-6.0, 0.0), wood, 3.5)
		draw_line(Vector2(-length, -0.8), Vector2(-6.0, -0.8), wood.lightened(0.35), 1.2)
		var head := PackedVector2Array([Vector2(8.0, 0.0), Vector2(-10.0, -8.0), Vector2(-6.0, 0.0), Vector2(-10.0, 8.0)])
		draw_colored_polygon(head, Color(0.86, 0.9, 0.95))
		draw_polyline(head + PackedVector2Array([head[0]]), Color(0.2, 0.22, 0.26), 1.5)
		for side: float in [-1.0, 1.0]:
			var feather := PackedVector2Array([
				Vector2(-length + 22.0, 0.0), Vector2(-length + 4.0, 10.0 * side),
				Vector2(-length - 6.0, 10.0 * side), Vector2(-length + 6.0, 0.0),
			])
			draw_colored_polygon(feather, fletching)


## A slash of a blade along path, as a band that is widest in its middle, from tail to
## head (0 to 1 along it): the head runs ahead as the blade swings, the tail follows.
class Slash:
	extends Node2D

	var path := PackedVector2Array()
	var head := 0.0
	var tail := 0.0
	var width := 36.0
	var color := Color.WHITE

	func point_at(t: float) -> Vector2:
		var at := clampf(t, 0.0, 1.0) * (path.size() - 1)
		var i := mini(int(at), path.size() - 2)
		return path[i].lerp(path[i + 1], at - i)

	func _draw() -> void:
		if head - tail < 0.002 or path.size() < 2:
			return
		# A wide glow, the blade's colour, and a white-hot core.
		_band(width * 2.4, Color(color, 0.22))
		_band(width * 1.2, Color(color, 0.75))
		_band(width * 0.45, Color(1.0, 1.0, 1.0, 0.95))

	func _band(band_width: float, band_color: Color) -> void:
		var steps := 28
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var colors := PackedColorArray()
		for i in steps + 1:
			var k := float(i) / steps
			var t := lerpf(tail, head, k)
			var at := point_at(t)
			var across := (point_at(t + 0.01) - point_at(t - 0.01)).orthogonal().normalized()
			# Thin at both ends, widest towards the head, as a crescent.
			var thickness := band_width * pow(sin(PI * pow(k, 1.4)), 0.7) / 2.0
			left.append(at + across * thickness)
			right.append(at - across * thickness)
			colors.append(Color(band_color, band_color.a * (0.25 + 0.75 * k)))
		for i in steps:
			draw_primitive(
				PackedVector2Array([left[i], left[i + 1], right[i + 1], right[i]]),
				PackedColorArray([colors[i], colors[i + 1], colors[i + 1], colors[i]]),
				PackedVector2Array())
