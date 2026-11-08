class_name BuffChips
extends HBoxContainer
## A row of chips, one per FightBuff: its icons, its text such as "+1", and a small count
## for one that works a few more times. A Totem's chip has a turquoise frame, like the
## totem token on the table. New chips pop up, so that the players notice them.

const ICON_SIZE := 26
const TOTEM_COLOR := Color(0.25, 0.75, 0.7)
const TEXT_COLOR := Color(0.6, 0.95, 0.55)

## The chips shown, by what they show, to tell which are new.
var _shown: Array[String] = []
## The chips that came since the last frame, by what they show, to pop up once the row
## has its size. The row can be rebuilt more than once in between.
var _new: Array[String] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	alignment = BoxContainer.ALIGNMENT_CENTER
	visible = false


func show_buffs(buffs: Array[FightBuff], plate: StyleBox) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var keys: Array[String] = []
	for buff in buffs:
		var key := _key(buff)
		var chip := _chip(buff, plate)
		chip.set_meta("key", key)
		add_child(chip)
		if not key in _shown and not key in _new:
			if _new.is_empty():
				_pop_new.call_deferred()
			_new.append(key)
		keys.append(key)
	_shown = keys
	visible = not buffs.is_empty()


func _chip(buff: FightBuff, plate: StyleBox) -> Control:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := plate.duplicate() as StyleBox
	if style is StyleBoxFlat:
		var flat := style as StyleBoxFlat
		flat.content_margin_left = 6.0
		flat.content_margin_right = 6.0
		flat.content_margin_top = 2.0
		flat.content_margin_bottom = 2.0
		if buff.totem:
			flat.border_color = TOTEM_COLOR
			flat.set_border_width_all(3)
			flat.shadow_color = Color(TOTEM_COLOR, 0.45)
			flat.shadow_size = 6
	chip.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2)
	chip.add_child(row)
	for key in buff.icons:
		var path := FightBuff.icon(key)
		if path.is_empty():
			continue
		var icon := TextureRect.new()
		icon.texture = load(path)
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	if not buff.text.is_empty():
		row.add_child(_label(buff.text, 22, TEXT_COLOR))
	if buff.count > 0:
		var count := _label("×%d" % buff.count, 16, Color(0.98, 0.88, 0.62))
		count.size_flags_vertical = Control.SIZE_SHRINK_END
		row.add_child(count)
	return chip


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Title"
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The count is left out, so that a chip counting down is not new.
static func _key(buff: FightBuff) -> String:
	return "%s|%s|%s|%s" % [buff.hero.seat if buff.hero != null else -1, ",".join(buff.icons), buff.text, buff.totem]


func _pop_new() -> void:
	for chip: Control in get_children():
		if chip.is_queued_for_deletion() or not chip.get_meta("key") in _new:
			continue
		chip.pivot_offset = chip.size / 2.0
		chip.scale = Vector2(0.2, 0.2)
		chip.create_tween().tween_property(chip, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_new.clear()
