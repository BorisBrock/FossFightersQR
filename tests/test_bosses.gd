extends Node
## The boss list and the boss overview: what they show, and where each button leads.
## Runs as a scene, because it needs the autoloads:
## godot --headless res://tests/test_bosses.tscn

const PARTY_PATH := "user://test_bosses_party.json"
## The settings dialog saves when it closes, which must not touch the real settings.
const SETTINGS_PATH := "user://test_bosses_settings.cfg"
const EXPECTED_CHECKS := 46

var _failures := 0
var _checks_run := 0
## Where the screen under test went, instead of changing the real scene.
var _next: Node


func _ready() -> void:
	Settings.load_file(SETTINGS_PATH)
	TranslationServer.set_locale("en")
	_check_catalog()
	await _check_selection()
	await _check_overview()
	await _check_back_button()
	await _check_return_to_table()
	_check(_checks_run == EXPECTED_CHECKS - 1, "all checks ran: %d" % _checks_run)
	DirAccess.remove_absolute(SETTINGS_PATH)
	print("test_bosses: %s" % ("PASSED" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _check_catalog() -> void:
	_check(not Bosses.IDS.is_empty(), "there are bosses")
	var complete := true
	var pictures := true
	for id: String in Bosses.IDS:
		var boss := Bosses.create(id)
		complete = complete and boss.id == id
		for field: String in ["title", "tagline", "story"]:
			complete = complete and _has_both_languages(boss.get(field))
		complete = complete and not boss.hints.is_empty()
		for hint: Dictionary in boss.hints:
			complete = complete and _has_both_languages(hint)
		for field: String in ["art", "figure", "background"]:
			pictures = pictures and ResourceLoader.exists(boss.get(field)) and load(boss.get(field)) is Texture2D
	_check(complete, "every boss has all its text in both languages")
	_check(pictures, "every boss has its pictures")
	_check(Bosses.DIFFICULTIES.has(Bosses.DEFAULT_DIFFICULTY), "the default difficulty exists")
	for id: String in Bosses.DIFFICULTIES:
		var difficulty: Dictionary = Bosses.DIFFICULTIES[id]
		complete = complete and _has_both_languages(difficulty.title) and _has_both_languages(difficulty.description)
		complete = complete and difficulty.health_factor > 0.0
	_check(complete, "every difficulty has its text in both languages, and scales health")


func _check_selection() -> void:
	Encounter.boss = ""
	var screen := await _open("res://boss_selection.tscn")
	var list: Container = screen.get_node("Stage/Margin/Layout/Scroll/List")
	var names := []
	for entry in list.get_children():
		names.append(str(entry.name))
	_check(names == Array(Bosses.IDS), "the list shows every boss, in order")
	var first: Control = list.get_child(0)
	_check(first.get_node("Caption/Name").text == Bosses.create(names[0]).title.en, "an entry shows the boss's name")
	_check(screen.get_node("Stage/Margin/Layout/Footer/Back").text == "Back", "the screen is in English")
	_check(not get_tree().quit_on_go_back, "the back button of a phone does not quit the app here")

	var second: Button = list.get_child(0)
	second.button_down.emit()
	second.pressed.emit()
	await _until_left(screen)
	_check(Encounter.boss == names[0], "tapping a boss chooses it")
	_check(_next != null and _next.scene_file_path == "res://boss_overview.tscn", "and shows its overview")
	_next.free()
	_next = null
	second.pressed.emit()
	await get_tree().process_frame
	_check(_next == null, "a second tap while leaving does nothing")
	screen.queue_free()
	await get_tree().process_frame
	_check(get_tree().quit_on_go_back, "the back button of a phone quits again elsewhere")

	# Coming back to the list marks the last boss chosen.
	screen = await _open("res://boss_selection.tscn")
	list = screen.get_node("Stage/Margin/Layout/Scroll/List")
	var frame_of := func(index: int) -> StyleBoxFlat: return list.get_child(index).get_child(3).get_theme_stylebox("panel")
	_check(frame_of.call(0).border_color == screen.CHOSEN_FRAME_COLOR, "the last boss chosen stands out")
	screen.go_back()
	await _until_left(screen)
	_check(_next != null and _next.scene_file_path == "res://onboarding.tscn", "Back leads to the table")
	_check(_next != null and not _next.show_splash, "without showing the logo again")
	if _next != null:
		_next.free()
	screen.queue_free()


func _check_overview() -> void:
	Encounter.boss = "mirefang"
	Encounter.difficulty = Bosses.DEFAULT_DIFFICULTY
	var mirefang := Bosses.create("mirefang")
	var screen := await _open("res://boss_overview.tscn")
	var layout := screen.get_node("Stage/Margin/Layout")
	_check(layout.get_node("Header/Titles/Name").text == "Mirefang", "the overview shows the chosen boss")
	_check(layout.get_node("Scroll/Content/Story").text == mirefang.story.en, "and its story")
	var hints: Container = layout.get_node("Scroll/Content/Hints")
	_check(hints.get_child_count() == mirefang.hints.size(), "and all its hints")
	_check(hints.get_child(0).get_node("Text").text == mirefang.hints[0].en, "in the right order")
	_check((layout.get_node("Scroll/Content/Picture") as TextureRect).texture != null, "and its picture")

	var buttons: Container = layout.get_node("Difficulty")
	_check(buttons.get_child_count() == Bosses.DIFFICULTIES.size(), "each difficulty has a button")
	var normal: Button = buttons.get_node("normal")
	var hard: Button = buttons.get_node("hard")
	_check(normal.button_pressed and not hard.button_pressed, "normal is chosen at first")
	hard.pressed.emit()
	_check(Encounter.difficulty == "hard" and hard.button_pressed and not normal.button_pressed, "tapping hard chooses it")
	_check(layout.get_node("DifficultyHint").text == Bosses.DIFFICULTIES.hard.description.en, "and explains it")

	TranslationServer.set_locale("de")
	await get_tree().process_frame
	_check(layout.get_node("Header/Titles/Name").text == "Moorzahn" and hard.text == "Schwer", "the overview follows the language")
	_check(layout.get_node("DifficultyHint").text == Bosses.DIFFICULTIES.hard.description.de, "the explanation, too")
	TranslationServer.set_locale("en")
	await get_tree().process_frame

	layout.get_node("Footer/Fight").pressed.emit()
	await _until_left(screen)
	_check(_next != null and _next.scene_file_path == "res://boss_fight.tscn", "Fight! starts the fight")
	_check(Encounter.boss == "mirefang" and Encounter.difficulty == "hard", "with the boss and difficulty chosen")
	if _next != null:
		_next.free()
	screen.queue_free()

	screen = await _open("res://boss_overview.tscn")
	_check(screen.get_node("Stage/Margin/Layout/Difficulty/hard").button_pressed, "the difficulty is kept when coming back")
	screen.get_node("Stage/Margin/Layout/Footer/Back").pressed.emit()
	await _until_left(screen)
	_check(_next != null and _next.scene_file_path == "res://boss_selection.tscn", "Back leads to the boss list")
	if _next != null:
		_next.free()
	screen.queue_free()


## The back button of a phone, or Escape, leaves the screen, unless the settings are open.
func _check_back_button() -> void:
	var screen := await _open("res://boss_overview.tscn")
	var settings: BaseButton = screen.get_node("Stage/Margin/Layout/Header/Settings")
	settings.pressed.emit()
	await get_tree().process_frame
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().create_timer(MenuScreen.FADE_SEC + 0.1).timeout
	_check(_next == null, "with the settings open, the back button only closes them")
	_check(settings.get_child_count() == 0, "the settings closed")
	_check(not get_tree().quit_on_go_back, "and the back button still does not quit the app")

	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	settings.pressed.emit()
	await get_tree().process_frame
	get_viewport().push_input(escape)
	await get_tree().create_timer(MenuScreen.FADE_SEC + 0.1).timeout
	_check(_next == null and settings.get_child_count() == 0, "Escape also only closes the settings")

	get_viewport().push_input(escape)
	await _until_left(screen)
	_check(_next != null and _next.scene_file_path == "res://boss_selection.tscn", "without them, Escape goes back")
	if _next != null:
		_next.free()
	screen.queue_free()

	screen = await _open("res://boss_selection.tscn")
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _until_left(screen)
	_check(_next != null and _next.scene_file_path == "res://onboarding.tscn", "and so does the back button of a phone")
	if _next != null:
		_next.free()
	screen.queue_free()
	await get_tree().process_frame


func _check_return_to_table() -> void:
	DirAccess.remove_absolute(PARTY_PATH)
	var table: Node = load("res://onboarding.tscn").instantiate()
	table.party_path = PARTY_PATH
	table.show_splash = false
	add_child(table)
	await get_tree().process_frame
	_check(not table.has_node("Splash"), "coming back, the table shows without the logo")
	await get_tree().create_timer(0.6).timeout
	_check(table.get_node("Stage").modulate.a == 1.0, "and plays its intro")
	table.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(PARTY_PATH)


## As in a real change of scene, the screen before is gone when the next one starts.
func _open(path: String) -> MenuScreen:
	await get_tree().process_frame
	_next = null
	var screen: MenuScreen = load(path).instantiate()
	screen.change_scene = func(next: Node) -> void: _next = next
	add_child(screen)
	await get_tree().process_frame
	return screen


func _until_left(screen: MenuScreen) -> void:
	var deadline := Time.get_ticks_msec() + 2000
	while _next == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(screen._leaving, "%s fades out before leaving" % screen.name)


func _has_both_languages(text: Dictionary) -> bool:
	return not str(text.get("de", "")).is_empty() and not str(text.get("en", "")).is_empty()


func _check(condition: bool, description: String) -> void:
	_checks_run += 1
	print(("  ok   " if condition else "  FAIL ") + description)
	if not condition:
		_failures += 1
