extends Node
## The player's settings, kept between runs. As an autoload it applies them before any
## scene starts. Other parts of the game read and set them as Settings.music_on and so on.
## Changes count at once, save() keeps them.

const SAVE_PATH := "user://settings.cfg"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const DEFAULT_MUSIC_VOLUME := 0.5
const DEFAULT_SFX_VOLUME := 1.0
## Follows the language of the device.
const SYSTEM_LANGUAGE := ""
const LANGUAGES: Array[String] = ["de", "en"]

var music_on := true:
	set(value):
		music_on = value
		_apply_bus(MUSIC_BUS, music_on, music_volume)
## From 0 to 1, as for all volumes.
var music_volume := DEFAULT_MUSIC_VOLUME:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		_apply_bus(MUSIC_BUS, music_on, music_volume)
var sfx_on := true:
	set(value):
		sfx_on = value
		_apply_bus(SFX_BUS, sfx_on, sfx_volume)
var sfx_volume := DEFAULT_SFX_VOLUME:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
		_apply_bus(SFX_BUS, sfx_on, sfx_volume)
## One of LANGUAGES or SYSTEM_LANGUAGE. Everything showing text gets told through
## NOTIFICATION_TRANSLATION_CHANGED.
var language := SYSTEM_LANGUAGE:
	set(value):
		language = value if LANGUAGES.has(value) else SYSTEM_LANGUAGE
		TranslationServer.set_locale(OS.get_locale() if language == SYSTEM_LANGUAGE else language)

var _path := SAVE_PATH


func _ready() -> void:
	load_file(SAVE_PATH)


## Takes the settings from this file and saves there from now on. Whatever is missing or
## damaged gets its default, as the player can simply set it again.
func load_file(path: String) -> void:
	_path = path
	var config := ConfigFile.new()
	if FileAccess.file_exists(path) and config.load(path) != OK:
		push_warning("Ignoring the damaged settings file: ", path)
	music_on = _read(config, "audio", "music_on", true)
	music_volume = _read(config, "audio", "music_volume", DEFAULT_MUSIC_VOLUME)
	sfx_on = _read(config, "audio", "sfx_on", true)
	sfx_volume = _read(config, "audio", "sfx_volume", DEFAULT_SFX_VOLUME)
	language = _read(config, "display", "language", SYSTEM_LANGUAGE)


func save() -> bool:
	var config := ConfigFile.new()
	config.set_value("audio", "music_on", music_on)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_on", sfx_on)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("display", "language", language)
	var result := config.save(_path)
	if result != OK:
		push_error("Cannot save the settings: ", error_string(result))
	return result == OK


func _read(config: ConfigFile, section: String, key: String, fallback: Variant) -> Variant:
	var value: Variant = config.get_value(section, key, fallback)
	return value if typeof(value) == typeof(fallback) else fallback


## The volume is squared because hearing is not linear: this way the middle of a slider
## also sounds like the middle.
func _apply_bus(bus: StringName, on: bool, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(index, not on or volume <= 0.0)
	if volume > 0.0:
		AudioServer.set_bus_volume_linear(index, volume * volume)
