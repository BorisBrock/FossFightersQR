class_name PictureCrop
extends RefCounted
## Shows a picture covering a TextureRect, as STRETCH_KEEP_ASPECT_COVERED does, but
## cropped around a focus instead of the middle, such as a boss's face (Boss.art_focus).


## Shows texture in picture, with focus (parts of its width and height) as near the middle
## as the picture allows. It follows the picture's size.
static func show(picture: TextureRect, texture: Texture2D, focus: Vector2) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	picture.texture = atlas
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	var fit := func() -> void:
		var full := texture.get_size()
		var area := picture.size
		if area.x <= 0.0 or area.y <= 0.0:
			atlas.region = Rect2(Vector2.ZERO, full)
			return
		var shown := area / maxf(area.x / full.x, area.y / full.y)
		var start := (full * focus - shown / 2.0).clamp(Vector2.ZERO, full - shown)
		atlas.region = Rect2(start, shown)
	picture.resized.connect(fit)
	fit.call()
