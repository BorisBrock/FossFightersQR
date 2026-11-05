class_name QrCameraScanner
extends Node
## Runs a device camera and continuously scans its picture for QR codes.
##
## Takes care of the permission, picks the camera and keeps it alive. On Android the
## decoder's native camera delivers frames directly. Other platforms use Godot's
## camera feed, with each frame copied back from the GPU.
## Add it to a scene and connect to code_read.

## A code was read. corners are in frame pixels, clockwise from the code's top-left.
signal code_read(text: String, corners: PackedVector2Array, frame_size: Vector2i)
## The current camera started delivering frames.
signal camera_started
## Scanning cannot run, with a reason to show the player.
signal failed(reason: String)

const PERMISSION_CAMERA := "CAMERA"
const CAMERA_RECOVERY_INTERVAL_SEC := 1.0
const READBACK_TIMEOUT_MSEC := 1000
## How long to wait for a camera to show up before telling the player there is none.
## The Linux backend takes about half a second to list them.
const FEED_SEARCH_GRACE_SEC := 2.0
## GPU copies take a few rendered frames. Letting them overlap means that no camera
## frames get skipped because of that delay.
const MAX_READBACKS_IN_FLIGHT := 2

## Upper limit for the camera resolution. On a Pixel 8 with a normally lit scene, 1080p
## drew about 780 mW more than 720p while decoding every frame. The price is range:
## 1080p reads a given code from about 1.5x as far away. See docs/qr_scanning.md.
const MAX_CAMERA_PIXELS := 1280 * 720
## Native camera frame rates. The rate drops while the picture is static, and the camera
## returns to the active rate as soon as a change is seen.
const NATIVE_IDLE_FPS := 15
const NATIVE_ACTIVE_FPS := 30
## Minimum time between frames copied for the decoder while the picture is static,
## for Godot's camera feed. Slightly under 66 ms, so that timing jitter does not turn
## every second frame of a 30 fps camera into every third.
const FEED_IDLE_FRAME_INTERVAL_MSEC := 60

var _decoder: RefCounted
var _app_paused := false
var _recovery_timer := 0.0
var _reported_camera_start := false

var _uses_native_camera := false
var _native_front := true
var _native_frames_at_start := 0

var _feed: CameraFeed
var _texture: CameraTexture
var _readbacks_in_flight := 0
var _readback_started_msec := 0
var _last_scan_msec := 0


func _ready() -> void:
	# Children are ready before their parents. Waiting a moment means that whoever owns
	# this node has connected its signals, and hears about a camera that cannot start.
	_begin.call_deferred()


func _begin() -> void:
	if not ClassDB.can_instantiate("QrDecoder"):
		failed.emit("The QR decoder library is missing for this platform.\nRun native/build.sh.")
		set_process(false)
		return
	_decoder = ClassDB.instantiate("QrDecoder")

	if OS.get_name() == "Android" and not _has_camera_permission():
		get_tree().on_request_permissions_result.connect(_on_permission_result)
		OS.request_permission(PERMISSION_CAMERA)
		return
	_start_camera()


func _exit_tree() -> void:
	if _uses_native_camera:
		_decoder.stop_native_camera()
	elif _feed:
		_feed.frame_changed.disconnect(_on_frame_changed)
		_feed.feed_is_active = false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_app_paused = true
			if _uses_native_camera:
				_decoder.stop_native_camera()
		NOTIFICATION_APPLICATION_RESUMED:
			_app_paused = false
			_readbacks_in_flight = 0 # Whatever was in flight will not arrive any more.
			_recovery_timer = 0.0


func _process(delta: float) -> void:
	if _decoder == null:
		return

	var result: Dictionary = _decoder.poll_result()
	if not result.is_empty():
		code_read.emit(result.text, result.corners, result.frame_size)

	if _uses_native_camera and not _reported_camera_start and _decoder.get_stats().frames_submitted > _native_frames_at_start:
		_report_camera_start()

	# The system closes the camera when another app takes it or on device errors.
	# Scanning must never just silently stop, so keep trying to get it back.
	_recovery_timer -= delta
	if not _app_paused and _recovery_timer <= 0.0:
		_recovery_timer = CAMERA_RECOVERY_INTERVAL_SEC
		if _uses_native_camera and not _decoder.is_native_camera_running():
			_start_native_camera()
		elif _feed and not _feed.feed_is_active:
			_feed.feed_is_active = true


## Decoder counters for diagnostics, see QrDecoder.get_stats().
func get_stats() -> Dictionary:
	return _decoder.get_stats() if _decoder else {}


## Whether the device has a camera on the other side to switch to.
func can_switch_camera() -> bool:
	if _uses_native_camera:
		return _decoder.has_native_camera(not _native_front)
	return _opposite_feed() != null


## The camera picture, for debugging. Null on the native camera, which has no picture.
func get_preview_texture() -> Texture2D:
	return _texture


## Moves scanning to the camera on the other side. camera_started fires once the
## new camera delivers its first frame.
func switch_camera() -> void:
	if _uses_native_camera:
		_native_front = not _native_front
		_start_native_camera()
		return
	var target := _opposite_feed()
	if target == null:
		return
	_feed.frame_changed.disconnect(_on_frame_changed)
	_feed.feed_is_active = false
	_readbacks_in_flight = 0
	_activate_feed(target)


func _has_camera_permission() -> bool:
	return OS.get_granted_permissions().has("android.permission.CAMERA")


func _on_permission_result(permission: String, granted: bool) -> void:
	if not permission.ends_with(PERMISSION_CAMERA):
		return
	get_tree().on_request_permissions_result.disconnect(_on_permission_result)
	if granted:
		_start_camera()
	else:
		failed.emit("Camera permission denied.\nAllow camera access in the system settings.")


func _start_camera() -> void:
	# The device lies on the table with its screen up, so the front camera is the one
	# with a view.
	if _decoder.has_native_camera(true) or _decoder.has_native_camera(false):
		_uses_native_camera = true
		_native_front = _decoder.has_native_camera(true)
		_start_native_camera()
	else:
		_start_feed_search()


func _start_native_camera() -> void:
	_reported_camera_start = false
	_native_frames_at_start = _decoder.get_stats().frames_submitted
	_decoder.start_native_camera(_native_front, MAX_CAMERA_PIXELS, NATIVE_IDLE_FPS, NATIVE_ACTIVE_FPS)


func _report_camera_start() -> void:
	_reported_camera_start = true
	camera_started.emit()


# Godot's camera feed ---------------------------------------------------------------


func _start_feed_search() -> void:
	# Feeds can appear late (the Linux backend enumerates on a thread), or only
	# after the search started, so listen in addition to looking right away.
	_texture = CameraTexture.new()
	CameraServer.camera_feed_added.connect(_on_feed_added)
	CameraServer.monitoring_feeds = true
	_try_select_feed()
	await get_tree().create_timer(FEED_SEARCH_GRACE_SEC).timeout
	if _feed == null:
		failed.emit("No camera found.")


## The Linux backend calls this from its own thread, where the camera would be half set
## up while _process already looks at it.
func _on_feed_added(_id: int) -> void:
	_try_select_feed.call_deferred()


func _try_select_feed() -> void:
	if _feed != null:
		return
	var feeds := CameraServer.feeds()
	if feeds.is_empty():
		return
	# The first feed of a position is that side's main camera. Laptops do not say what
	# position a camera has, but may list a face recognition camera next to the real one.
	var chosen: CameraFeed = feeds[0]
	for candidate: CameraFeed in feeds:
		if candidate.get_position() == CameraFeed.FEED_FRONT:
			chosen = candidate
			break
		if chosen.get_name().contains(" IR ") and not candidate.get_name().contains(" IR "):
			chosen = candidate
	_activate_feed(chosen)


func _opposite_feed() -> CameraFeed:
	if _feed == null:
		return null
	var wanted := CameraFeed.FEED_FRONT if _feed.get_position() == CameraFeed.FEED_BACK else CameraFeed.FEED_BACK
	for candidate: CameraFeed in CameraServer.feeds():
		if candidate.get_position() == wanted:
			return candidate
	# Cameras of unknown position, as on a laptop: any other one will do.
	if _feed.get_position() == CameraFeed.FEED_UNSPECIFIED:
		for candidate: CameraFeed in CameraServer.feeds():
			if candidate != _feed:
				return candidate
	return null


func _activate_feed(new_feed: CameraFeed) -> void:
	_feed = new_feed
	_reported_camera_start = false
	var format_index := _choose_format(_feed.formats)
	if format_index >= 0:
		_feed.set_format(format_index, {})
		print("QR scanner: camera '%s', format %s" % [_feed.get_name(), _feed.formats[format_index]])
	_texture.camera_feed_id = _feed.get_id()
	_texture.which_feed = CameraServer.FEED_Y_IMAGE
	_feed.frame_changed.connect(_on_frame_changed)
	_feed.feed_is_active = true


## The largest format within the resolution limit. Formats the camera delivers as
## separate luminance data are preferred, because that plane is what gets decoded.
func _choose_format(formats: Array) -> int:
	var best := -1
	var best_score := -1
	for i in formats.size():
		var format: Dictionary = formats[i]
		var pixels: int = format.get("width", 0) * format.get("height", 0)
		if pixels <= 0 or pixels > MAX_CAMERA_PIXELS:
			continue
		var score := pixels
		if String(format.get("format", "")).begins_with("YUV"):
			score += MAX_CAMERA_PIXELS
		if score > best_score:
			best_score = score
			best = i
	return best


func _on_frame_changed() -> void:
	if not _reported_camera_start:
		_report_camera_start()

	var now := Time.get_ticks_msec()
	if not _decoder.is_scene_active() and now - _last_scan_msec < FEED_IDLE_FRAME_INTERVAL_MSEC:
		return
	if now - _readback_started_msec > READBACK_TIMEOUT_MSEC:
		_readbacks_in_flight = 0 # Never let a lost callback end scanning.
	if _readbacks_in_flight >= MAX_READBACKS_IN_FLIGHT:
		return
	_last_scan_msec = now
	_readbacks_in_flight += 1
	_readback_started_msec = now

	if RenderingServer.get_rendering_device():
		RenderingServer.call_on_render_thread(_begin_gpu_readback.bind(_texture.get_rid(), _texture.get_width(), _texture.get_height()))
	else:
		_blocking_readback()


## Copies the texture without waiting for the GPU, so that the game keeps its
## frame rate. Texture.get_image() would stall the renderer on every camera frame.
func _begin_gpu_readback(texture: RID, width: int, height: int) -> void:
	var device := RenderingServer.get_rendering_device()
	var device_texture := RenderingServer.texture_get_rd_texture(texture)
	if not device_texture.is_valid():
		_readbacks_in_flight -= 1
		return
	var error := device.texture_get_data_async(device_texture, 0, _on_gpu_data.bind(width, height))
	if error != OK:
		_readbacks_in_flight -= 1


func _on_gpu_data(data: PackedByteArray, width: int, height: int) -> void:
	_readbacks_in_flight = maxi(_readbacks_in_flight - 1, 0)
	if width > 0 and height > 0:
		_decoder.submit_frame(data, width, height, data.size() / (width * height))


## For the Compatibility renderer, which is the fallback on devices without Vulkan.
func _blocking_readback() -> void:
	_readbacks_in_flight = 0
	var image := _texture.get_image()
	if image == null or image.is_empty():
		return
	var data := image.get_data()
	_decoder.submit_frame(data, image.get_width(), image.get_height(), data.size() / (image.get_width() * image.get_height()))
