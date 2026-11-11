extends "res://scripts/menu_panel.gd"
## The list of bosses, which the table shows once the party is set up. Tapping one shows
## what it is about before the fight starts (scripts/boss_overview.gd).

## A boss was tapped. Encounter.boss is set to it already.
signal chosen(id: String)

const ENTRY_HEIGHT := 300.0
const SCROLL_TOLERANCE := 12
const FRAME_COLOR := Color(0.72, 0.54, 0.22)
## The last boss chosen, when coming back to the list.
const CHOSEN_FRAME_COLOR := Color(0.98, 0.82, 0.48)
const TEXT := {
	"title": { "de": "Wählt euren Gegner", "en": "Choose your foe" },
	"hint": { "de": "Tippt auf einen Boss, um mehr über ihn zu erfahren.", "en": "Tap a boss to learn more about it." },
	"back": { "de": "Zurück", "en": "Back" },
}

## The entry of each boss, by id.
var _entries := {}
## Where the list was when a finger came down on an entry. If it moved since, the finger
## was scrolling, not choosing.
var _scroll_at_press := 0

@onready var _header: Control = $Stage/Margin/Layout/Header
@onready var _title: Label = $Stage/Margin/Layout/Header/Title
@onready var _hint: Label = $Stage/Margin/Layout/Hint
@onready var _scroll: ScrollContainer = $Stage/Margin/Layout/Scroll
@onready var _list: VBoxContainer = $Stage/Margin/Layout/Scroll/List
@onready var _footer: Control = $Stage/Margin/Layout/Footer
@onready var _back: Button = $Stage/Margin/Layout/Footer/Back
@onready var _select_sound: AudioStreamPlayer = $SelectSound


func _ready() -> void:
	_back.pressed.connect(request_back)
	for id: String in Bosses.IDS:
		var entry := _make_entry(id)
		_list.add_child(entry)
		_entries[id] = entry
	_refresh_text()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_text()


## Coming back to the list marks the last boss chosen.
func play_in() -> void:
	_scroll.scroll_vertical = 0
	_refresh_frames()
	await super()


func choose(id: String) -> void:
	if not active:
		return
	active = false
	Encounter.boss = id
	_select_sound.play()
	_pop(_entries[id])
	chosen.emit(id)


## Where the entry of a boss is on screen, for its picture to fly on from there.
func entry_rect(id: String) -> Rect2:
	return (_entries[id] as Control).get_global_rect()


## The entry the picture flies on from is gone at once, as the picture takes its place.
func play_out_without(id: String) -> void:
	_entries[id].modulate.a = 0.0
	await play_out()


func _parts() -> Array[Control]:
	var parts: Array[Control] = [_header, _hint]
	for entry: Control in _list.get_children():
		parts.append(entry)
	parts.append(_footer)
	return parts


func _on_entry_pressed(id: String) -> void:
	if absi(_scroll.scroll_vertical - _scroll_at_press) <= SCROLL_TOLERANCE:
		choose(id)


func _t(key: String) -> String:
	return CardDatabase.localized(TEXT[key], TranslationServer.get_locale())


func _refresh_text() -> void:
	_title.text = _t("title")
	_hint.text = _t("hint")
	_back.text = _t("back")
	var locale := TranslationServer.get_locale()
	for id: String in _entries:
		var entry: Control = _entries[id]
		var boss := Bosses.create(id)
		entry.get_node("Caption/Name").text = CardDatabase.localized(boss.title, locale)
		entry.get_node("Caption/Tagline").text = CardDatabase.localized(boss.tagline, locale)


## A picture across the whole width, with the name on a shadow at the bottom.
func _make_entry(id: String) -> Control:
	var entry := Button.new()
	entry.name = id
	entry.flat = true
	entry.focus_mode = Control.FOCUS_NONE
	entry.custom_minimum_size = Vector2(0, ENTRY_HEIGHT)
	entry.clip_contents = true
	# Lets the list scroll when the drag starts on an entry, which on a phone is always.
	entry.mouse_filter = Control.MOUSE_FILTER_PASS
	entry.button_down.connect(func() -> void: _scroll_at_press = _scroll.scroll_vertical)
	ButtonSounds.silence(entry)
	entry.pressed.connect(_on_entry_pressed.bind(id))

	var picture := TextureRect.new()
	picture.name = "Picture"
	var boss := Bosses.create(id)
	PictureCrop.show(picture, load(boss.art), boss.art_focus)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	entry.add_child(picture)

	var shadow := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0))
	gradient.set_color(1, Color(0, 0, 0, 0.85))
	var shadow_texture := GradientTexture2D.new()
	shadow_texture.gradient = gradient
	shadow_texture.fill_from = Vector2(0, 0)
	shadow_texture.fill_to = Vector2(0, 1)
	shadow.texture = shadow_texture
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.anchor_top = 0.45
	entry.add_child(shadow)

	var caption := VBoxContainer.new()
	caption.name = "Caption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_constant_override("separation", 0)
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 20
	caption.offset_right = -20
	caption.offset_bottom = -14
	caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	entry.add_child(caption)
	caption.add_child(_make_label("Name", &"Title", 36))
	caption.add_child(_make_label("Tagline", &"Hint", 22))

	var frame := Panel.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	entry.add_child(frame)
	return entry


func _refresh_frames() -> void:
	for id: String in _entries:
		var style := StyleBoxFlat.new()
		style.draw_center = false
		style.set_border_width_all(4 if id == Encounter.boss else 3)
		style.border_color = CHOSEN_FRAME_COLOR if id == Encounter.boss else FRAME_COLOR
		style.set_corner_radius_all(6)
		(_entries[id].get_node("Frame") as Control).add_theme_stylebox_override("panel", style)


func _make_label(label_name: String, variation: StringName, font_size: int) -> Label:
	var label := Label.new()
	label.name = label_name
	label.theme_type_variation = variation
	label.add_theme_font_size_override("font_size", font_size)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _pop(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2(1.04, 1.04)
	create_tween().tween_property(control, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
