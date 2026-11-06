extends Node
## The settings, what they do to the audio buses, and the dialog that changes them.
## Runs as a scene, because it needs the autoloads:
## godot --headless res://tests/test_settings.tscn

const PATH := "user://test_settings.cfg"
const EXPECTED_CHECKS := 47

var _failures := 0
var _checks_run := 0


func _ready() -> void:
	DirAccess.remove_absolute(PATH)
	_check_sounds_use_the_buses()
	_check_defaults()
	_check_buses()
	_check_round_trip()
	_check_damaged_files()
	_check_language()
	await _check_dialog()
	await _check_language_in_dialog()
	await _check_buttons()
	DirAccess.remove_absolute(PATH)
	_check(_checks_run == EXPECTED_CHECKS - 1, "all checks ran: %d" % _checks_run)
	print("test_settings: %s" % ("PASSED" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _check_sounds_use_the_buses() -> void:
	_check(get_tree().root.get_node("Music").bus == Settings.MUSIC_BUS, "the music plays on its bus")
	var scenes := {
		"res://main.tscn": ["Pling"],
		"res://onboarding.tscn": ["RevealSound", "SeatSound", "FanfareSound"],
		"res://settings_dialog.tscn": ["PreviewSound"],
		"res://boss_selection.tscn": ["SelectSound"],
		"res://boss_overview.tscn": ["FanfareSound"],
		"res://message_box.tscn": ["Sound"],
	}
	for path: String in scenes:
		var scene: Node = load(path).instantiate()
		for sound: String in scenes[path]:
			var player: AudioStreamPlayer = scene.get_node(sound)
			_check(player.bus == Settings.SFX_BUS, "%s plays on the sound effects bus" % sound)
		scene.free()


func _check_defaults() -> void:
	Settings.load_file(PATH)
	_check(Settings.music_on and Settings.sfx_on, "everything is on without a file")
	_check(Settings.music_volume == Settings.DEFAULT_MUSIC_VOLUME and Settings.sfx_volume == Settings.DEFAULT_SFX_VOLUME, "default volumes without a file")
	var music_player: AudioStreamPlayer = get_tree().root.get_node("Music")
	var total_db := music_player.volume_db + _bus_db(Settings.MUSIC_BUS)
	_check(is_equal_approx(snappedf(total_db, 0.1), -20.0), "the music starts low enough to talk over: %.1f dB" % total_db)
	_check(is_zero_approx(_bus_db(Settings.SFX_BUS)), "sound effects start at full volume")


func _check_buses() -> void:
	Settings.music_on = false
	_check(_is_muted(Settings.MUSIC_BUS) and not _is_muted(Settings.SFX_BUS), "turning off the music leaves the sound effects")
	Settings.music_on = true
	_check(not _is_muted(Settings.MUSIC_BUS), "turning it on again")
	Settings.sfx_volume = 0.0
	_check(_is_muted(Settings.SFX_BUS), "no volume means silence")
	Settings.sfx_volume = 0.5
	_check(not _is_muted(Settings.SFX_BUS) and absf(_bus_db(Settings.SFX_BUS) + 12.04) < 0.05, "half the slider is a quarter of the amplitude")
	Settings.music_volume = 7.0
	_check(Settings.music_volume == 1.0, "volumes stay in range")


func _check_round_trip() -> void:
	Settings.music_on = false
	Settings.music_volume = 0.25
	Settings.sfx_on = false
	Settings.sfx_volume = 0.75
	_check(Settings.save(), "saves")
	Settings.load_file(PATH)
	_check(not Settings.music_on and not Settings.sfx_on and Settings.music_volume == 0.25 and Settings.sfx_volume == 0.75, "keeps everything")
	_check(_is_muted(Settings.MUSIC_BUS) and _is_muted(Settings.SFX_BUS), "loading applies to the buses")


func _check_damaged_files() -> void:
	_write("[audio\nnot a config")
	Settings.load_file(PATH)
	_check(Settings.music_on and Settings.music_volume == Settings.DEFAULT_MUSIC_VOLUME, "damaged file gives the defaults")
	_write("[audio]\nmusic_on=\"yes\"\nmusic_volume=\"loud\"\nsfx_volume=99.0\n")
	Settings.load_file(PATH)
	_check(Settings.music_on and Settings.music_volume == Settings.DEFAULT_MUSIC_VOLUME, "wrong types give the defaults")
	_check(Settings.sfx_volume == 1.0, "a volume out of range is limited")
	DirAccess.remove_absolute(PATH)
	Settings.load_file(PATH)


func _check_language() -> void:
	Settings.load_file(PATH)
	_check(Settings.language == Settings.SYSTEM_LANGUAGE, "follows the device without a file")
	_check(TranslationServer.get_locale() == TranslationServer.standardize_locale(OS.get_locale()), "starts in the language of the device: %s" % TranslationServer.get_locale())
	Settings.language = "de"
	_check(TranslationServer.get_locale() == "de", "German can be chosen")
	Settings.language = "en"
	_check(TranslationServer.get_locale() == "en", "English can be chosen")
	_check(Settings.save(), "saves the language")
	Settings.language = "de"
	Settings.load_file(PATH)
	_check(Settings.language == "en" and TranslationServer.get_locale() == "en", "keeps the language")
	_write("[display]\nlanguage=\"tlh\"\n")
	Settings.load_file(PATH)
	_check(Settings.language == Settings.SYSTEM_LANGUAGE, "a language the game does not have gives the device's")
	_write("[display]\nlanguage=7\n")
	Settings.load_file(PATH)
	_check(Settings.language == Settings.SYSTEM_LANGUAGE, "a wrong type gives the device's")
	DirAccess.remove_absolute(PATH)
	Settings.load_file(PATH)


func _check_language_in_dialog() -> void:
	Settings.language = "en"
	var dialog: Node = load("res://settings_dialog.tscn").instantiate()
	add_child(dialog)
	var layout := "Dim/Center/Panel/Margin/Layout/"
	var title: Label = dialog.get_node(layout + "Title")
	var system: Button = dialog.get_node(layout + "Language/System")
	var german: Button = dialog.get_node(layout + "Language/German")
	var english: Button = dialog.get_node(layout + "Language/English")
	_check(english.button_pressed and not german.button_pressed and not system.button_pressed, "shows the current language")
	_check(title.text == "Settings", "the dialog speaks it")
	german.pressed.emit()
	await get_tree().process_frame
	_check(Settings.language == "de" and german.button_pressed and not english.button_pressed, "another language counts at once")
	_check(title.text == "Einstellungen" and dialog.get_node(layout + "LanguageLabel").text == "Sprache", "the open dialog changes with it")
	system.pressed.emit()
	await get_tree().process_frame
	_check(Settings.language == Settings.SYSTEM_LANGUAGE and system.button_pressed and not german.button_pressed, "back to the device's language")
	dialog.queue_free()
	await get_tree().process_frame
	Settings.load_file(PATH)
	_check(Settings.language == Settings.SYSTEM_LANGUAGE, "closing saves the language")


func _check_dialog() -> void:
	Settings.music_volume = 0.3
	var dialog: Node = load("res://settings_dialog.tscn").instantiate()
	add_child(dialog)
	var layout := "Dim/Center/Panel/Margin/Layout/"
	var music_toggle: CheckButton = dialog.get_node(layout + "MusicToggle")
	var music_slider: HSlider = dialog.get_node(layout + "MusicVolume")
	var sfx_toggle: CheckButton = dialog.get_node(layout + "SfxToggle")
	var sfx_slider: HSlider = dialog.get_node(layout + "SfxVolume")
	var done: Button = dialog.get_node(layout + "Done")
	_check(music_slider.value == 0.3 and music_toggle.button_pressed, "shows the current settings")
	music_slider.value = 0.8
	_check(Settings.music_volume == 0.8, "the slider counts at once")
	music_toggle.button_pressed = false
	_check(not Settings.music_on and _is_muted(Settings.MUSIC_BUS) and not music_slider.editable, "the toggle mutes and locks the slider")
	sfx_slider.value = 0.4
	sfx_toggle.button_pressed = false
	_check(not Settings.sfx_on and Settings.sfx_volume == 0.4, "sound effects have their own settings")
	done.pressed.emit()
	await get_tree().process_frame
	_check(not is_instance_valid(dialog), "done closes the dialog")
	Settings.load_file(PATH)
	_check(not Settings.music_on and Settings.music_volume == 0.8 and not Settings.sfx_on, "closing saves")


func _check_buttons() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	var button: BaseButton = game.get_node("Hud/Settings")
	# Without the camera and everything else of the scene, only the button is needed here.
	button.get_parent().remove_child(button)
	button.owner = null
	add_child(button)
	game.free()
	button.pressed.emit()
	await get_tree().process_frame
	var dialog: Node = button.get_node_or_null("SettingsDialog")
	_check(dialog != null, "the button opens the dialog")
	var dim: Control = dialog.get_node("Dim")
	var tap := InputEventMouseButton.new()
	tap.pressed = true
	dim.gui_input.emit(tap)
	await get_tree().process_frame
	_check(button.get_child_count() == 0, "a tap next to the dialog closes it")
	button.free()


func _bus_db(bus: StringName) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))


func _is_muted(bus: StringName) -> bool:
	return AudioServer.is_bus_mute(AudioServer.get_bus_index(bus))


func _write(text: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _check(ok: bool, what: String) -> void:
	_checks_run += 1
	if not ok:
		_failures += 1
		print("FAILED: ", what)
