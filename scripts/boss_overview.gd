extends MenuScreen
## What the party needs to know about the chosen boss before the fight: its story and how
## to beat it. The difficulty is chosen here, too.

const SELECTION_SCENE := "res://boss_selection.tscn"
const FIGHT_SCENE := "res://boss_fight.tscn"
const FIGHT_FADE_SEC := 0.7
const TEXT := {
	"hints": { "de": "Taktik", "en": "Strategy" },
	"difficulty": { "de": "Schwierigkeit", "en": "Difficulty" },
	"back": { "de": "Zurück", "en": "Back" },
	"fight": { "de": "Zum Kampf!", "en": "Fight!" },
}

## The button of each difficulty, by id.
var _difficulty_buttons := {}
var _boss: Boss

@onready var _name: Label = $Stage/Margin/Layout/Header/Titles/Name
@onready var _tagline: Label = $Stage/Margin/Layout/Header/Titles/Tagline
@onready var _picture: TextureRect = $Stage/Margin/Layout/Scroll/Content/Picture
@onready var _story: Label = $Stage/Margin/Layout/Scroll/Content/Story
@onready var _hints_heading: Label = $Stage/Margin/Layout/Scroll/Content/HintsHeading
@onready var _hints: VBoxContainer = $Stage/Margin/Layout/Scroll/Content/Hints
@onready var _difficulty_label: Label = $Stage/Margin/Layout/DifficultyLabel
@onready var _difficulty_row: HBoxContainer = $Stage/Margin/Layout/Difficulty
@onready var _difficulty_hint: Label = $Stage/Margin/Layout/DifficultyHint
@onready var _back: Button = $Stage/Margin/Layout/Footer/Back
@onready var _fight: Button = $Stage/Margin/Layout/Footer/Fight
@onready var _fanfare_sound: AudioStreamPlayer = $FanfareSound


func _ready() -> void:
	super()
	# Only when run on its own, as from the editor.
	if not Bosses.has(Encounter.boss):
		Encounter.boss = Bosses.IDS[0]
	if not Bosses.DIFFICULTIES.has(Encounter.difficulty):
		Encounter.difficulty = Bosses.DEFAULT_DIFFICULTY
	_boss = Bosses.create(Encounter.boss)
	PictureCrop.show(_picture, load(_boss.art), _boss.art_focus)
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
	for i in _boss.hints.size():
		_hints.add_child(_make_hint())
	_back.pressed.connect(go_back)
	_fight.pressed.connect(start_fight)
	_refresh_text()


func _notification(what: int) -> void:
	super(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_text()


func go_back() -> void:
	leave_to(load(SELECTION_SCENE).instantiate())


func choose_difficulty(id: String) -> void:
	Encounter.difficulty = id
	_refresh_difficulty()


func start_fight() -> void:
	if _leaving:
		return
	_fanfare_sound.play()
	leave_to(load(FIGHT_SCENE).instantiate(), FIGHT_FADE_SEC)


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
