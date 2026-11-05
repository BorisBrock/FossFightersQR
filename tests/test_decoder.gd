extends SceneTree
## Decoder checks that need no camera or GPU.
## Run with: godot --headless -s tests/test_decoder.gd

const TIMEOUT_MSEC := 3000
const EXPECTED_CHECKS := 17

var _failures := 0
var _expected_checks_remaining := 0


func _initialize() -> void:
	_expected_checks_remaining = EXPECTED_CHECKS
	await _run()
	_check(_expected_checks_remaining == 1, "all checks ran")
	print("test_decoder: %s" % ("PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _run() -> void:
	var decoder: RefCounted = ClassDB.instantiate("QrDecoder")
	_check(decoder != null, "QrDecoder is registered")

	var image := _load_luminance("res://tests/fixtures/qr_vivosaur.png")
	var size := image.get_size()

	_check(not decoder.submit_frame(image.get_data(), size.x, size.y + 1, 1), "rejects data smaller than announced")
	_check(not decoder.submit_frame(image.get_data(), 0, size.y, 1), "rejects an empty frame")
	_check(not decoder.submit_frame(image.get_data(), size.x, size.y, 5), "rejects an unknown pixel layout")

	var result := await _decode(decoder, image.get_data(), size, 1)
	_check(result.get("text") == "FOSS-FIGHTER:VIVOSAUR:0137", "reads luminance: %s" % result.get("text"))
	_check(result.get("corners", PackedVector2Array()).size() == 4, "reports four corners")
	_check(result.get("frame_size") == size, "reports the frame size")

	var unicode := _load_luminance("res://tests/fixtures/qr_unicode.png")
	result = await _decode(decoder, unicode.get_data(), unicode.get_size(), 1)
	_check(result.get("text") == "Grüße aus dem Fossilien-Labor 🦖", "reads UTF-8: %s" % result.get("text"))

	var rgba := image.duplicate()
	rgba.convert(Image.FORMAT_RGBA8)
	decoder = ClassDB.instantiate("QrDecoder")
	result = await _decode(decoder, rgba.get_data(), size, 4)
	_check(result.get("text") == "FOSS-FIGHTER:VIVOSAUR:0137", "reads RGBA frames")

	var two_channel := image.duplicate()
	two_channel.convert(Image.FORMAT_LA8)
	decoder = ClassDB.instantiate("QrDecoder")
	result = await _decode(decoder, two_channel.get_data(), size, 2)
	_check(result.get("text") == "FOSS-FIGHTER:VIVOSAUR:0137", "reads two channel frames")

	decoder = ClassDB.instantiate("QrDecoder")
	var empty := _load_luminance("res://tests/fixtures/no_code.png")
	result = await _decode(decoder, empty.get_data(), empty.get_size(), 1)
	_check(result.is_empty(), "stays silent on a frame without a code")

	await _check_idle_behaviour(empty, image)


## A static picture must stop the decoding work, and a change must restart it at once.
func _check_idle_behaviour(empty: Image, code: Image) -> void:
	var decoder: RefCounted = ClassDB.instantiate("QrDecoder")
	var size := empty.get_size()
	await _submit_for(decoder, empty.get_data(), size, 3200)
	_check(not decoder.is_scene_active(), "goes idle when the picture stays the same")

	var before: int = decoder.get_stats().frames_decoded
	var submitted_before: int = decoder.get_stats().frames_submitted
	await _submit_for(decoder, empty.get_data(), size, 2000)
	var decoded: int = decoder.get_stats().frames_decoded - before
	var submitted: int = decoder.get_stats().frames_submitted - submitted_before
	_check(submitted > 30 and decoded <= 3, "barely decodes while idle: %d of %d frames" % [decoded, submitted])

	var start := Time.get_ticks_msec()
	var result := await _decode(decoder, code.get_data(), size, 1)
	var elapsed := Time.get_ticks_msec() - start
	_check(result.get("text") == "FOSS-FIGHTER:VIVOSAUR:0137", "reads a code that appears while idle")
	_check(elapsed < 200, "reads it right away: %d ms" % elapsed)
	_check(decoder.is_scene_active(), "scans again after the change")


func _submit_for(decoder: RefCounted, data: PackedByteArray, size: Vector2i, duration_msec: int) -> void:
	var deadline := Time.get_ticks_msec() + duration_msec
	while Time.get_ticks_msec() < deadline:
		decoder.submit_frame(data, size.x, size.y, 1)
		await process_frame
		OS.delay_msec(33)


func _load_luminance(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	image.convert(Image.FORMAT_L8)
	return image


## Submits like a camera would until the decoder answers, or gives up.
func _decode(decoder: RefCounted, data: PackedByteArray, size: Vector2i, bytes_per_pixel: int) -> Dictionary:
	var deadline := Time.get_ticks_msec() + (TIMEOUT_MSEC if bytes_per_pixel > 0 else 0)
	while Time.get_ticks_msec() < deadline:
		decoder.submit_frame(data, size.x, size.y, bytes_per_pixel)
		await process_frame
		OS.delay_msec(16)
		var result: Dictionary = decoder.poll_result()
		if not result.is_empty():
			return result
	return {}


func _check(condition: bool, description: String) -> void:
	_expected_checks_remaining -= 1
	print(("  ok   " if condition else "  FAIL ") + description)
	if not condition:
		_failures += 1
