extends "res://scripts/menu_panel.gd"
## What the party needs to know about the chosen boss before the fight: its story and how
## to beat it. The difficulty is chosen here, too.

## Fight! was tapped, with the boss and difficulty in Encounter.
signal fight_pressed

## The picture flying on from the boss list.
const FLIGHT_SEC := 0.5
const TEXT := {
	"hints": { "de": "Taktik", "en": "Strategy" },
	"difficulty": { "de": "Schwierigkeit", "en": "Difficulty" },
	"back": { "de": "Zurück", "en": "Back" },
	"fight": { "de": "Zum Kampf!", "en": "Fight!" },
}

## The button of each difficulty, by id.
var _difficulty_buttons := {}
var _boss: Boss
## The picture waits for its copy flying on from the list, instead of coming in with the rest.
var _picture_flying := false

@onready var _header: Control = $Stage/Margin/Layout/Header
@onready var _name: Label = $Stage/Margin/Layout/Header/Titles/Name
@onready var _tagline: Label = $Stage/Margin/Layout/Header/Titles/Tagline
@onready var _scroll: ScrollContainer = $Stage/Margin/Layout/Scroll
@onready var _picture: TextureRect = $Stage/Margin/Layout/Scroll/Content/Picture
@onready var _story: Label = $Stage/Margin/Layout/Scroll/Content/Story
@onready var _hints_heading: Label = $Stage/Margin/Layout/Scroll/Content/HintsHeading
@onready var _hints: VBoxContainer = $Stage/Margin/Layout/Scroll/Content/Hints
@onready var _difficulty_label: Label = $Stage/Margin/Layout/DifficultyLabel
@onready var _difficulty_row: HBoxContainer = $Stage/Margin/Layout/Difficulty
@onready var _difficulty_hint: Label = $Stage/Margin/Layout/DifficultyHint
@onready var _footer: Control = $Stage/Margin/Layout/Footer
@onready var _back: Button = $Stage/Margin/Layout/Footer/Back
@onready var _fight: Button = $Stage/Margin/Layout/Footer/Fight
@onready var _fanfare_sound: AudioStreamPlayer = $FanfareSound


func _ready() -> void:
	if not Bosses.DIFFICULTIES.has(Encounter.difficulty):
		Encounter.difficulty = Bosses.DEFAULT_DIFFICULTY
	var group := ButtonGroup.new()
	for id: String in Bosses.DIFFICULTIES:
		var button := Button.new()
		button.name = id
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 24)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(choose_difficulty.bind(id))
		_difficulty_row.add_child(button)
		_difficulty_buttons[id] = button
	_back.pressed.connect(request_back)
	_fight.pressed.connect(start_fight)
	show_boss(Encounter.boss if Bosses.has(Encounter.boss) else Bosses.IDS[0])


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_text()


## Fills the overview in for this boss, before it is shown.
func show_boss(id: String) -> void:
	_boss = Bosses.create(id)
	PictureCrop.show(_picture, load(_boss.art), _boss.art_focus)
	for hint in _hints.get_children():
		_hints.remove_child(hint)
		hint.queue_free()
	for i in _boss.hints.size():
		_hints.add_child(_make_hint())
	_refresh_text()


## from is where the boss's picture is on screen in the list, if it flies on from there.
## The rest comes in around it.
func play_in(from := Rect2()) -> void:
	_scroll.scroll_vertical = 0
	if not from.has_area():
		await super()
		return
	var flight := _fly_picture(from)
	await super()
	if flight.is_running():
		await flight.finished


func choose_difficulty(id: String) -> void:
	Encounter.difficulty = id
	_refresh_difficulty()


func start_fight() -> void:
	if not active:
		return
	active = false
	_fanfare_sound.play()
	fight_pressed.emit()


func _parts() -> Array[Control]:
	var parts: Array[Control] = [_header]
	if not _picture_flying:
		parts.append(_picture)
	parts.append_array([_story, _hints_heading])
	for hint: Control in _hints.get_children():
		parts.append(hint)
	parts.append(_difficulty_label)
	for button: Control in _difficulty_row.get_children():
		parts.append(button)
	parts.append_array([_difficulty_hint, _footer])
	return parts


## A copy of the picture flies from the list to its place here, its crop following its
## shape on the way, and the picture takes over when it lands.
func _fly_picture(from: Rect2) -> Tween:
	var flyer := TextureRect.new()
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.clip_contents = true
	add_child(flyer)
	flyer.global_position = from.position
	flyer.size = from.size
	PictureCrop.show(flyer, load(_boss.art), _boss.art_focus)
	_picture_flying = true
	_picture.modulate.a = 0.0
	_picture.scale = Vector2.ONE
	var flight := create_tween()
	flight.tween_method(func(t: float) -> void:
		# Asked anew each step, as the overview is only laid out once shown.
		var to := _picture.get_global_rect()
		var eased := ease(t, -2.4)
		flyer.global_position = from.position.lerp(to.position, eased)
		flyer.size = from.size.lerp(to.size, eased), 0.0, 1.0, FLIGHT_SEC)
	flight.tween_callback(func() -> void:
		_picture_flying = false
		_picture.modulate.a = 1.0
		flyer.queue_free())
	return flight


func _t(key: String) -> String:
	return CardDatabase.localized(TEXT[key], TranslationServer.get_locale())


func _refresh_text() -> void:
	var locale := TranslationServer.get_locale()
	_name.text = CardDatabase.localized(_boss.title, locale)
	_tagline.text = CardDatabase.localized(_boss.tagline, locale)
	_story.text = CardDatabase.localized(_boss.story, locale)
	_hints_heading.text = _t("hints")
	for i in _boss.hints.size():
		_hints.get_child(i).get_node("Text").text = CardDatabase.localized(_boss.hints[i], locale)
	_difficulty_label.text = _t("difficulty")
	for id: String in _difficulty_buttons:
		_difficulty_buttons[id].text = CardDatabase.localized(Bosses.DIFFICULTIES[id].title, locale)
	_back.text = _t("back")
	_fight.text = _t("fight")
	_refresh_difficulty()


## As in the settings, the chosen button is the bright one.
func _refresh_difficulty() -> void:
	for id: String in _difficulty_buttons:
		var button: Button = _difficulty_buttons[id]
		var selected: bool = id == Encounter.difficulty
		button.set_pressed_no_signal(selected)
		button.theme_type_variation = &"PrimaryButton" if selected else &""
	_difficulty_hint.text = CardDatabase.localized(Bosses.DIFFICULTIES[Encounter.difficulty].description, TranslationServer.get_locale())


## A hint with a gold diamond in front, which lines up with its first line.
func _make_hint() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	# Containers undo the rotation of their children, so the diamond sits in a plain Control.
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(14, 0)
	var marker := ColorRect.new()
	marker.color = Color(0.98, 0.82, 0.48)
	marker.size = Vector2(9, 9)
	marker.pivot_offset = marker.size / 2.0
	marker.position = Vector2(2, 13)
	marker.rotation_degrees = 45.0
	holder.add_child(marker)
	row.add_child(holder)
	var text := Label.new()
	text.name = "Text"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 23)
	row.add_child(text)
	return row
