class_name FakeCameraFeed
extends CameraFeed
## Stands in for a phone camera: delivers frames the way the Android backend does,
## as a luminance image with a separate half-size chroma image.

var luma: Image
var _chroma: Image


func _init(new_name := "Fake back camera", new_position := CameraFeed.FEED_BACK) -> void:
	set_name(new_name)
	set_position(new_position)


func show_image(path: String) -> void:
	luma = Image.load_from_file(ProjectSettings.globalize_path(path))
	luma.convert(Image.FORMAT_R8)
	_chroma = Image.create_empty(luma.get_width() / 2, luma.get_height() / 2, false, Image.FORMAT_RG8)
	_chroma.fill(Color(0.5, 0.5, 0.0))


func deliver_frame() -> void:
	if feed_is_active and luma:
		set_ycbcr_images(luma, _chroma)


func _activate_feed() -> bool:
	return true


func _deactivate_feed() -> void:
	pass


func _get_formats() -> Array:
	return [{ "width": 1280, "height": 720, "format": "YUV_420_888" }]


func _set_format(_index: int, _parameters: Dictionary) -> bool:
	return true
