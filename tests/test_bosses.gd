extends Node
## Choosing the boss on the table's screen: the boss list and the boss overview, what they
## show, and where each button leads. Runs as a scene, because it needs the autoloads:
## godot --headless res://tests/test_bosses.tscn

const PARTY_PATH := "user://test_bosses_party.json"
const CARDS_PATH := "res://tests/fixtures/onboarding_cards.json"
## The settings dialog saves when it closes, which must not touch the real settings.
const SETTINGS_PATH := "user://test_bosses_settings.cfg"
const BossSelection := preload("res://scripts/boss_selection.gd")
const BossOverview := preload("res://scripts/boss_overview.gd")
const PHASE_TABLE := 0
const PHASE_BOSSES := 1
const PHASE_BOSS := 2
const EXPECTED_CHECKS := 60

var _failures := 0
var _checks_run := 0
## Where the screen went, instead of changing the real scene.
var _next: Node
var _scene: Node


func _ready() -> void:
	Settings.load_file(SETTINGS_PATH)
	TranslationServer.set_locale("en")
	_check_catalog()
	await _open()
	await _check_leaving_table()
	await _check_selection()
	await _check_overview()
	await _check_back_button()
	await _check_return_to_table()
	await _check_fight()
	_check(_checks_run == EXPECTED_CHECKS - 1, "all checks ran: %d" % _checks_run)
	_scene.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(SETTINGS_PATH)
	DirAccess.remove_absolute(PARTY_PATH)
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


func _check_leaving_table() -> void:
	var go: Button = _scene.get_node("Stage/Margin/Layout/Footer/Primary")
	_check(go.text == "Let's go!" and not go.disabled, "with a hero, the table shows Let's go!")
	_check(not _scene.get_node("BossSelection").visible and not _scene.get_node("BossOverview").visible, "the boss screens wait out of sight")
	_check(get_tree().quit_on_go_back, "at the table, the back button of a phone quits the app")
	var seat: SeatToken = _scene.get_node("Seats/Seat3")
	var seat_home := seat.offset_top
	go.pressed.emit()
	await get_tree().process_frame
	_check(_scene._overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "taps wait while the screen moves on")
	await _until_still()
	_check(seat.offset_top > seat_home, "the seats slid off the edge of the screen")
	_check(not _scene.get_node("Seats").visible and not _scene.get_node("Stage").visible, "the seats and the party made way")
	_check(not _scene.get_node("Settings").visible, "and so did the table's own buttons")
	_check(is_equal_approx(_scene.get_node("Table").material.get_shader_parameter("dim"), _scene.TABLE_DIM_BOSSES), "the table darkened")
	_check(_scene._phase == PHASE_BOSSES and _scene.get_node("BossSelection").visible, "the boss list came in, on the same screen")
	_check(not get_tree().quit_on_go_back, "the back button of a phone does not quit the app here")
	_check(_scene._overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "and taps count again")
	_scene._apply_card(_scene._cards.find("CHAR-ELF"))
	_check(_scene._view == 0 and _scene._phase == PHASE_BOSSES, "cards do nothing at the boss list")


func _check_selection() -> void:
	var screen: BossSelection = _scene.get_node("BossSelection")
	var list: Container = screen.get_node("Stage/Margin/Layout/Scroll/List")
	var names := []
	for entry in list.get_children():
		names.append(str(entry.name))
	_check(names == Array(Bosses.IDS), "the list shows every boss, in order")
	var first: Button = list.get_child(0)
	_check(first.get_node("Caption/Name").text == Bosses.create(names[0]).title.en, "an entry shows the boss's name")
	_check(screen.get_node("Stage/Margin/Layout/Footer/Back").text == "Back", "the list is in English")
	_check(first.modulate.a == 1.0 and first.scale == Vector2.ONE, "its entries are all in")

	var chosen := []
	screen.chosen.connect(func(id: String) -> void: chosen.append(id))
	first.button_down.emit()
	first.pressed.emit()
	await get_tree().process_frame
	first.pressed.emit()
	_check(chosen.size() == 1, "a second tap while moving on does nothing")
	_check(Encounter.boss == names[0], "tapping a boss chooses it")
	_check(_scene._boss_overview.get_child_count() > 2, "its picture flies on into the overview")
	await _until_still()
	_check(_scene._phase == PHASE_BOSS and _scene.get_node("BossOverview").visible and not screen.visible, "and its overview took the list's place")
	_check(_scene.get_node("BossOverview").get_child_count() == 2, "the flying picture has landed")
	_check(not get_tree().quit_on_go_back, "the back button of a phone still does not quit")


func _check_overview() -> void:
	Encounter.difficulty = Bosses.DEFAULT_DIFFICULTY
	var screen: BossOverview = _scene.get_node("BossOverview")
	screen._refresh_difficulty()
	var mirefang := Bosses.create("mirefang")
	var layout := screen.get_node("Stage/Margin/Layout")
	_check(layout.get_node("Header/Titles/Name").text == "Mirefang", "the overview shows the chosen boss")
	_check(layout.get_node("Scroll/Content/Story").text == mirefang.story.en, "and its story")
	var hints: Container = layout.get_node("Scroll/Content/Hints")
	_check(hints.get_child_count() == mirefang.hints.size(), "and all its hints")
	_check(hints.get_child(0).get_node("Text").text == mirefang.hints[0].en, "in the right order")
	var picture: TextureRect = layout.get_node("Scroll/Content/Picture")
	_check(picture.texture != null and picture.modulate.a == 1.0, "and its picture")
	_check(layout.get_node("Footer").modulate.a == 1.0 and layout.get_node("Footer/Fight").text == "Fight!", "everything has come in, down to Fight!")

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

	layout.get_node("Footer/Back").pressed.emit()
	await _until_still()
	var selection: BossSelection = _scene.get_node("BossSelection")
	_check(_scene._phase == PHASE_BOSSES and selection.visible and not screen.visible, "Back leads to the boss list")
	var frame: Panel = selection.get_node("Stage/Margin/Layout/Scroll/List").get_child(0).get_node("Frame")
	_check(frame.get_theme_stylebox("panel").border_color == selection.CHOSEN_FRAME_COLOR, "where the last boss chosen stands out")
	selection.choose(Encounter.boss)
	await _until_still()
	_check(screen.get_node("Stage/Margin/Layout/Difficulty/hard").button_pressed, "the difficulty is kept when coming back")


## The back button of a phone, or Escape, lead back a step, unless the settings are open.
func _check_back_button() -> void:
	var settings: BaseButton = _scene.get_node("BossOverview/Stage/Margin/Layout/Header/Settings")
	settings.pressed.emit()
	await get_tree().process_frame
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _until_still()
	_check(_scene._phase == PHASE_BOSS, "with the settings open, the back button only closes them")
	_check(settings.get_child_count() == 0, "the settings closed")
	_check(not get_tree().quit_on_go_back, "and the back button still does not quit the app")

	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	settings.pressed.emit()
	await get_tree().process_frame
	get_viewport().push_input(escape)
	await _until_still()
	_check(_scene._phase == PHASE_BOSS and settings.get_child_count() == 0, "Escape also only closes the settings")

	get_viewport().push_input(escape)
	await get_tree().process_frame
	await _until_still()
	_check(_scene._phase == PHASE_BOSSES, "without them, Escape goes back to the list")
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	_check(_scene._phase == PHASE_TABLE, "and the back button of a phone back to the table")


func _check_return_to_table() -> void:
	await _until_still()
	var seat: SeatToken = _scene.get_node("Seats/Seat3")
	_check(_scene.get_node("Seats").visible and seat.offset_top == seat.get_meta(&"home").y, "the seats slid back to their places")
	_check(seat.mode == SeatToken.Mode.SELECTABLE, "and can be tapped again")
	_check(_scene.get_node("Stage").modulate.a == 1.0 and _scene.get_node("Stage").visible, "the party is back")
	_check(not _scene.get_node("BossSelection").visible, "the list is gone")
	_check(get_tree().quit_on_go_back, "the back button of a phone quits again")
	_check(is_equal_approx(_scene.get_node("Table").material.get_shader_parameter("dim"), _scene.TABLE_DIM), "the table lit up again")
	_scene._apply_card(_scene._cards.find("CHAR-ELF"))
	_check(_scene._view == 1, "cards count at the table again")
	_scene._cancel_editing()


func _check_fight() -> void:
	await _until_still()
	_scene.get_node("Stage/Margin/Layout/Footer/Primary").pressed.emit()
	await _until_still()
	_scene._boss_selection.choose(Bosses.IDS[0])
	await _until_still()
	_scene.get_node("BossOverview/Stage/Margin/Layout/Footer/Fight").pressed.emit()
	await get_tree().process_frame
	_check(_scene._fade.visible, "Fight! fades out the screen")
	var deadline := Time.get_ticks_msec() + 2000
	while _next == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(_next != null and _next.scene_file_path == "res://boss_fight.tscn", "and starts the fight")
	_check(Encounter.boss == "mirefang" and Encounter.difficulty == "hard", "with the boss and difficulty chosen")
	if _next != null:
		_next.free()


## The table with one hero, coming back from a fight, so without the logo.
func _open() -> void:
	DirAccess.remove_absolute(PARTY_PATH)
	var party := Party.load_file(PARTY_PATH)
	var hero := Party.Hero.new()
	hero.name = "Borin"
	hero.race = "dwarf"
	hero.hero_class = "thief"
	hero.seat = 3
	party.heroes.append(hero)
	party.save()
	_scene = load("res://onboarding.tscn").instantiate()
	_scene.party_path = PARTY_PATH
	_scene.cards_path = CARDS_PATH
	_scene.show_splash = false
	_scene.change_scene = func(next: Node) -> void: _next = next
	add_child(_scene)
	await get_tree().process_frame
	_check(not _scene.has_node("Splash"), "coming back from a fight, the table shows without the logo")
	await get_tree().create_timer(0.6).timeout


## Waits until the screen has moved on to the next phase.
func _until_still() -> void:
	var deadline := Time.get_ticks_msec() + 3000
	await get_tree().process_frame
	while _scene._moving and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _has_both_languages(text: Dictionary) -> bool:
	return not str(text.get("de", "")).is_empty() and not str(text.get("en", "")).is_empty()


func _check(condition: bool, description: String) -> void:
	_checks_run += 1
	print(("  ok   " if condition else "  FAIL ") + description)
	if not condition:
		_failures += 1
