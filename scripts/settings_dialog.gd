extends CanvasLayer
## Changes count at once, so that players hear what they set. They are saved when leaving.

const SLIDER_OFF_ALPHA := 0.4
const TEXT := {
	"title": { "de": "Einstellungen", "en": "Settings" },
	"music": { "de": "Musik", "en": "Music" },
	"sfx": { "de": "Soundeffekte", "en": "Sound effects" },
	"language": { "de": "Sprache", "en": "Language" },
	"done": { "de": "Fertig", "en": "Done" },
}

@onready var _dim: Control = $Dim
@onready var _title: Label = $Dim/Center/Panel/Margin/Layout/Title
@onready var _music_toggle: CheckButton = $Dim/Center/Panel/Margin/Layout/MusicToggle
@onready var _music_volume: HSlider = $Dim/Center/Panel/Margin/Layout/MusicVolume
@onready var _sfx_toggle: CheckButton = $Dim/Center/Panel/Margin/Layout/SfxToggle
@onready var _sfx_volume: HSlider = $Dim/Center/Panel/Margin/Layout/SfxVolume
@onready var _language_label: Label = $Dim/Center/Panel/Margin/Layout/LanguageLabel
@onready var _language_buttons := {
	Settings.SYSTEM_LANGUAGE: $Dim/Center/Panel/Margin/Layout/Language/System,
	"de": $Dim/Center/Panel/Margin/Layout/Language/German,
	"en": $Dim/Center/Panel/Margin/Layout/Language/English,
}
@onready var _done: Button = $Dim/Center/Panel/Margin/Layout/Done
@onready var _preview: AudioStreamPlayer = $PreviewSound


func _ready() -> void:
	_refresh_text()
	_music_toggle.button_pressed = Settings.music_on
	_music_volume.value = Settings.music_volume
	_sfx_toggle.button_pressed = Settings.sfx_on
	_sfx_volume.value = Settings.sfx_volume
	_refresh_sliders()
	var language_group := ButtonGroup.new()
	for language: String in _language_buttons:
		var button: Button = _language_buttons[language]
		button.button_group = language_group
		button.pressed.connect(_on_language_pressed.bind(language))
	_refresh_language_buttons()

	_music_toggle.toggled.connect(_on_music_toggled)
	_music_volume.value_changed.connect(func(value: float) -> void: Settings.music_volume = value)
	_sfx_toggle.toggled.connect(_on_sfx_toggled)
	_sfx_volume.value_changed.connect(func(value: float) -> void: Settings.sfx_volume = value)
	# Music can be heard all the time, but sound effects need something to listen to.
	_sfx_volume.drag_ended.connect(func(_changed: bool) -> void: _preview.play())
	_done.pressed.connect(close)
	_dim.gui_input.connect(_on_dim_input)
	# The back button of a phone should only leave the dialog, not the game.
	get_tree().quit_on_go_back = false


func _exit_tree() -> void:
	get_tree().quit_on_go_back = true
	Settings.save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		close()
	elif what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_text()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()


func close() -> void:
	queue_free()


func _t(key: String) -> String:
	return CardDatabase.localized(TEXT[key], TranslationServer.get_locale())


func _refresh_text() -> void:
	_title.text = _t("title")
	_music_toggle.text = _t("music")
	_sfx_toggle.text = _t("sfx")
	_language_label.text = _t("language")
	_done.text = _t("done")


func _on_language_pressed(language: String) -> void:
	Settings.language = language
	_refresh_language_buttons()


## The names of the languages stay the same in every language, for finding one's own.
func _refresh_language_buttons() -> void:
	for language: String in _language_buttons:
		var button: Button = _language_buttons[language]
		var selected := language == Settings.language
		button.set_pressed_no_signal(selected)
		button.theme_type_variation = &"PrimaryButton" if selected else &""


func _on_music_toggled(on: bool) -> void:
	Settings.music_on = on
	_refresh_sliders()


func _on_sfx_toggled(on: bool) -> void:
	Settings.sfx_on = on
	_refresh_sliders()
	if on:
		_preview.play()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()


## A slider that is off would change nothing that can be heard.
func _refresh_sliders() -> void:
	_set_slider_active(_music_volume, Settings.music_on)
	_set_slider_active(_sfx_volume, Settings.sfx_on)


func _set_slider_active(slider: HSlider, active: bool) -> void:
	slider.editable = active
	slider.modulate.a = 1.0 if active else SLIDER_OFF_ALPHA
