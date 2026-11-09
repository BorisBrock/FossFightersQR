extends Node
## Runs the real onboarding scene against a fake camera, as a group of players would.
## Needs a rendering device, so not headless: godot res://tests/test_onboarding.tscn

const PARTY_PATH := "user://test_onboarding_party.json"
## The catalog that goes with the QR codes in these pictures.
const CARDS_PATH := "res://tests/fixtures/onboarding_cards.json"
const DWARF := "res://tests/fixtures/qr_char_dwarf.png"
const ELF := "res://tests/fixtures/qr_char_elf.png"
const THIEF := "res://tests/fixtures/qr_class_thief.png"
const DRUID := "res://tests/fixtures/qr_class_druid.png"
const FIREBALL := "res://tests/fixtures/qr_card.png"
const NOTHING := "res://tests/fixtures/no_code.png"
const VIEW_PARTY := 0
const VIEW_EDITOR := 1
const READ_TIMEOUT_SEC := 2.0
## Longer than the code needs to count as taken away.
const AWAY_SEC := 2.3
## Time for a read if the card were going to count.
const IGNORE_SEC := 1.0
const EXPECTED_CHECKS := 74

var _feed: FakeCameraFeed
var _scene: Node
var _failures := 0
var _checks_run := 0
var _frame_accumulator := 0.0


func _ready() -> void:
	# German has the longest words, so this is where the layout is tightest.
	TranslationServer.set_locale("de")
	DirAccess.remove_absolute(PARTY_PATH)
	_feed = FakeCameraFeed.new("Fake front camera", CameraFeed.FEED_FRONT)
	CameraServer.add_feed(_feed)
	_feed.show_image(NOTHING)
	await _run()
	_check(_checks_run == EXPECTED_CHECKS, "all checks ran: %d" % _checks_run)
	print("test_onboarding: %s" % ("PASSED" if _failures == 0 else "%d FAILED" % _failures))
	_scene.queue_free()
	await get_tree().process_frame
	CameraServer.remove_feed(_feed)
	_feed = null
	DirAccess.remove_absolute(PARTY_PATH)
	get_tree().quit(1 if _failures > 0 else 0)


func _process(delta: float) -> void:
	_frame_accumulator += delta
	if _frame_accumulator >= 1.0 / 30.0:
		_frame_accumulator = 0.0
		if _feed:
			_feed.deliver_frame()


func _run() -> void:
	_open_scene()
	var splash: Splash = _scene.get_node("Splash")
	_check(splash.visible and splash.modulate.a == 1.0, "the logo covers the table at the start")
	await _until(func() -> bool: return splash.modulate.a < 1.0, 2.0)
	_check(is_instance_valid(splash) and splash.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the table can be tapped once the logo starts to fade")
	await _until(func() -> bool: return not _scene.has_node("Splash"), 2.0)
	_check(not _scene.has_node("Splash"), "the logo goes away by itself")
	var done: Button = _scene.get_node("Stage/Margin/Layout/Footer/Primary")
	var delete: Button = _scene.get_node("Stage/Margin/Layout/Footer/Delete")
	var seat_three: SeatToken = _scene.get_node("Seats/Seat3")
	var seat_five: SeatToken = _scene.get_node("Seats/Seat5")

	# An empty party starts at the table.
	_check(_scene._view == VIEW_PARTY, "an empty party starts at the table")
	_check(_scene.get_node("Seats").get_child_count() == 7 and Party.SEAT_COUNT == 7, "the table has seven seats")
	_check(seat_three.mode == SeatToken.Mode.SELECTABLE, "free seats can be tapped")
	_check(done.disabled, "cannot go to battle without heroes")

	# The party's name takes the place of a title, and can be typed right there.
	var party_name: LineEdit = _scene._party_name_edit
	_check(party_name.visible and party_name.text.is_empty() and not party_name.placeholder_text.is_empty(), "an unnamed party is asked for its name")
	party_name.grab_focus()
	_check(party_name.placeholder_text.is_empty(), "the placeholder makes way for typing")
	party_name.release_focus()
	_check(not party_name.placeholder_text.is_empty(), "and comes back if nothing was typed")
	party_name.text = " Furious Four "
	party_name.text_changed.emit(" Furious Four ")
	_check(Party.load_file(PARTY_PATH).party_name == "Furious Four", "the name of the party is saved as it is typed")
	var full_size: int = party_name.get_theme_font_size("font_size")
	var long_name := "W".repeat(Party.MAX_PARTY_NAME_LENGTH)
	party_name.text = long_name
	party_name.text_changed.emit(long_name)
	await get_tree().process_frame
	_check(party_name.get_theme_font_size("font_size") < full_size and party_name.size.x <= _scene._stage.size.x, "a long name gets smaller and leaves the panel as it is")
	party_name.text = "Furious Four"
	party_name.text_changed.emit("Furious Four")

	# Tapping a seat opens the editor for it, and cancelling leaves nothing behind.
	seat_three.pressed.emit()
	_check(_scene._view == VIEW_EDITOR and _scene._draft.seat == 3, "tapping a free seat opens the editor for it")
	_check(not party_name.visible and _scene._title.visible, "the editor shows the hero's number instead of the party's name")
	_check(seat_three.mode == SeatToken.Mode.ACTIVE and seat_five.mode == SeatToken.Mode.QUIET_SELECTABLE, "the seat being edited stands out")
	_check(_scene._camera_problem.is_empty() and _scene._camera_view.visible, "debug builds show the camera while waiting for a card")
	_check(done.disabled and not delete.visible, "a new hero cannot be finished or deleted yet")
	_check(not _scene.has_node("Stage/Margin/Layout/Footer/Cancel"), "there is no cancel button, tapping the table cancels")
	await get_tree().process_frame
	_check(done.size_flags_horizontal == Control.SIZE_EXPAND_FILL and is_equal_approx(_scene._footer_spacer.size.x, done.size.x), "done keeps its place on the right")
	_check(done.has_meta(&"clicks") and delete.has_meta(&"clicks"), "the buttons click")
	_tap(_scene._stage.global_position + Vector2(_scene._stage.size.x / 2.0, 12.0))
	_check(_scene._view == VIEW_EDITOR, "a tap inside the panel stays in the editor")
	_tap_table()
	_check(_scene._view == VIEW_PARTY and _scene._party.heroes.is_empty(), "tapping the table cancels a new hero, leaving the party empty")
	seat_three.pressed.emit()

	# Cards choose on the one page, in any order.
	_feed.show_image(FIREBALL)
	await get_tree().create_timer(IGNORE_SEC).timeout
	_check(_scene._draft.race.is_empty() and _scene._draft.hero_class.is_empty(), "a playing card is ignored")
	_feed.show_image(DWARF)
	var pling: AudioStreamPlayer = _scene._pling
	await _until(func() -> bool: return pling.playing, READ_TIMEOUT_SEC)
	_check(pling.playing and _scene._draft.race.is_empty(), "a card read plings first, before it chooses anything")
	await _until(func() -> bool: return not _scene._draft.race.is_empty(), READ_TIMEOUT_SEC)
	_check(_scene._draft.race == "dwarf", "a character card chooses the race: '%s'" % _scene._draft.race)
	_check(_scene._draft.name in HeroOptions.RACES.dwarf.names, "the race suggests a name: '%s'" % _scene._draft.name)
	_check(done.disabled, "cannot finish without a class")

	# Another card replaces the choice, and the suggested name goes along with it.
	await get_tree().create_timer(0.9).timeout
	_feed.show_image(ELF)
	await _until(func() -> bool: return _scene._draft.race == "elf", READ_TIMEOUT_SEC)
	_check(_scene._draft.race == "elf" and _scene._draft.name in HeroOptions.RACES.elf.names, "another card changes race and suggested name")
	var name_edit: LineEdit = _scene._name_edit
	name_edit.text = "Boris"
	name_edit.text_changed.emit("Boris")
	await get_tree().create_timer(0.9).timeout
	_feed.show_image(DWARF)
	await _until(func() -> bool: return _scene._draft.race == "dwarf", READ_TIMEOUT_SEC)
	_check(_scene._draft.name == "Boris", "a typed name survives changing the race")

	_feed.show_image(THIEF)
	await _until(func() -> bool: return not _scene._draft.hero_class.is_empty(), READ_TIMEOUT_SEC)
	_check(_scene._draft.hero_class == "thief" and _scene._draft.race == "dwarf", "a class card chooses the class on the same page")
	_check(not done.disabled, "can finish with character, class and name")
	name_edit.text = "  "
	name_edit.text_changed.emit("  ")
	_check(done.disabled, "cannot finish without a name")
	name_edit.text = "Boris"
	name_edit.text_changed.emit("Boris")

	# Finishing at once leaves the reveal unfinished, which must not get in the way.
	done.pressed.emit()
	var flyer: TextureRect = _scene._overlay.get_child(0)
	_check(flyer.texture.resource_path == HeroOptions.RACES.dwarf.art, "the character flies to the seat")
	_scene._apply_card(_scene._cards.find("CHAR-ELF"))
	_check(_scene._party.hero_at(3).race == "dwarf", "a card read during the flight changes nothing")
	await _until(func() -> bool: return _scene._editor.visible == false, READ_TIMEOUT_SEC)
	_check(_scene._view == VIEW_PARTY and _scene._party.hero_at(3) != null, "finishing seats the hero")
	_check(seat_three.get_node("NamePlate/Name").text == "Boris", "the seat shows the hero")
	_check(not done.disabled, "with a hero, the party can go to battle")

	# The second player still has the first player's card in front of the camera.
	_feed.show_image(DWARF)
	await get_tree().create_timer(0.5).timeout
	seat_five.pressed.emit()
	await get_tree().create_timer(IGNORE_SEC).timeout
	_check(_scene._draft.race.is_empty() and not _scene._hint.text.contains("Boris"), "a card still in view does not count for the next hero")
	_check(seat_three.mode == SeatToken.Mode.DIMMED, "another hero's seat stays in the background")
	_feed.show_image(NOTHING)
	await get_tree().create_timer(AWAY_SEC).timeout

	# Every character and class can only be picked once, and the class may come first.
	_feed.show_image(THIEF)
	var hint: Label = _scene._hint
	await _until(func() -> bool: return hint.text.contains("Boris"), READ_TIMEOUT_SEC)
	_check(_scene._draft.hero_class.is_empty() and hint.text.contains("Boris"), "a class that is taken is refused, saying by whom: '%s'" % hint.text)
	_feed.show_image(DRUID)
	await _until(func() -> bool: return not _scene._draft.hero_class.is_empty(), READ_TIMEOUT_SEC)
	_check(_scene._draft.hero_class == "druid" and _scene._draft.name.is_empty(), "the class can come first")
	await get_tree().create_timer(0.9).timeout
	_feed.show_image(DWARF)
	await _until(func() -> bool: return hint.text.contains("Boris"), READ_TIMEOUT_SEC)
	_check(_scene._draft.race.is_empty(), "a character that is taken is refused")
	_feed.show_image(ELF)
	await _until(func() -> bool: return not _scene._draft.race.is_empty(), READ_TIMEOUT_SEC)
	_check(_scene._draft.race == "elf" and not done.disabled, "a free character completes the hero")
	done.pressed.emit()
	await _until(func() -> bool: return _scene._editor.visible == false, READ_TIMEOUT_SEC)

	# Next time the game starts, everything is still there.
	_scene.queue_free()
	await get_tree().process_frame
	_open_scene()
	var tap := InputEventMouseButton.new()
	tap.pressed = true
	_scene.get_node("Splash")._gui_input(tap)
	_check(_scene.get_node("Splash").mouse_filter == Control.MOUSE_FILTER_IGNORE, "a tap skips the wait for the logo")
	await get_tree().create_timer(0.6).timeout
	var reloaded: Party = _scene._party
	_check(_scene._view == VIEW_PARTY and reloaded.heroes.size() == 2, "the party is remembered between runs")
	_check(_scene._party_name_edit.text == "Furious Four", "with its name")
	_check(reloaded.hero_at(3).name == "Boris" and reloaded.hero_at(3).race == "dwarf" and reloaded.hero_at(3).hero_class == "thief", "with names and choices")
	var loaded_token: SeatToken = _scene.get_node("Seats/Seat5")
	_check(reloaded.hero_at(5) != null and loaded_token.get_node("NamePlate").visible, "and seats")

	# Changing a hero.
	delete = _scene.get_node("Stage/Margin/Layout/Footer/Delete")
	done = _scene.get_node("Stage/Margin/Layout/Footer/Primary")
	var token: SeatToken = _scene.get_node("Seats/Seat3")
	_feed.show_image(NOTHING)
	await get_tree().create_timer(AWAY_SEC).timeout
	token.pressed.emit()
	_check(_scene._view == VIEW_EDITOR and not done.disabled and delete.visible, "tapping a seated hero opens them for changes")
	# The question on the delete button is its longest text.
	delete.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var stage_width: float = _scene.size.x - _scene.get_node("Ornaments").offset_left + _scene.get_node("Ornaments").offset_right
	_check(is_equal_approx(_scene._stage.size.x, stage_width), "all footer buttons fit, so the panel stays clear of the seats: %s of %s" % [_scene._stage.size.x, stage_width])
	_check(delete.size == done.size and is_equal_approx(delete.position.y, done.position.y) and delete.position.x < done.position.x, "delete and done are the same size, side by side: %s and %s" % [delete.get_rect(), done.get_rect()])
	_scene._disarm_delete()
	await get_tree().create_timer(0.9).timeout
	_feed.show_image(ELF)
	await get_tree().create_timer(IGNORE_SEC).timeout
	_check(_scene._draft.race == "dwarf", "they cannot take the character of another hero")
	_feed.show_image(DWARF)
	await get_tree().create_timer(IGNORE_SEC).timeout
	_check(_scene._hint.text.contains("Boris") == false and _scene._draft.race == "dwarf", "and their own is not refused")
	var renamed: LineEdit = _scene._name_edit
	renamed.text = "Boris II"
	renamed.text_changed.emit("Boris II")
	_tap_table()
	_check(_scene._view == VIEW_PARTY and reloaded.hero_at(3).name == "Boris", "tapping the table discards the change")
	token.pressed.emit()
	_check(renamed.text == "Boris", "and the editor starts from the saved hero again")
	renamed.text = "Boris II"
	renamed.text_changed.emit("Boris II")
	done.pressed.emit()
	await _until(func() -> bool: return _scene._editor.visible == false, READ_TIMEOUT_SEC)
	_check(_scene._view == VIEW_PARTY and Party.load_file(PARTY_PATH).hero_at(3).name == "Boris II", "done saves it, keeping the seat")
	_check(Party.load_file(PARTY_PATH).party_name == "Furious Four", "saving a hero keeps the name of the party")

	# Moving to another seat: shown at once, but only saved with done.
	var free_target: SeatToken = _scene.get_node("Seats/Seat6")
	var saved_hero: Party.Hero = reloaded.hero_at(3)
	token.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	_check(done.scale == Vector2.ONE, "the buttons keep still")
	_check(free_target.mode == SeatToken.Mode.QUIET_SELECTABLE and loaded_token.mode == SeatToken.Mode.DIMMED, "free seats can be moved to, those of other heroes not")
	loaded_token.pressed.emit()
	_check(_scene._draft.seat == 3, "tapping another hero's seat does not move there")
	free_target.pressed.emit()
	_check(free_target.mode == SeatToken.Mode.ACTIVE and free_target.get_node("NamePlate/Name").text == "Boris II" and not token.get_node("NamePlate").visible, "tapping a free seat shows the hero there")
	_check(reloaded.hero_at(3) == saved_hero and Party.load_file(PARTY_PATH).hero_at(3) != null, "which is not saved yet")
	_tap_table()
	_check(reloaded.hero_at(3) == saved_hero and token.get_node("NamePlate").visible and not free_target.get_node("NamePlate").visible, "tapping the table leaves the hero where they were")
	token.pressed.emit()
	free_target.pressed.emit()
	done.pressed.emit()
	await _until(func() -> bool: return _scene._editor.visible == false, READ_TIMEOUT_SEC)
	var moved := Party.load_file(PARTY_PATH)
	_check(moved.hero_at(6) != null and moved.hero_at(6).name == "Boris II" and moved.hero_at(3) == null, "done saves the new seat")
	free_target.pressed.emit()
	token.pressed.emit()
	done.pressed.emit()
	await _until(func() -> bool: return _scene._editor.visible == false, READ_TIMEOUT_SEC)

	# Two quick choices: the first reveal is cut short, but its choice must still show.
	_scene.get_node("Seats/Seat0").pressed.emit()
	_scene._last_selection_msec = -_scene.SELECTION_DWELL_MSEC
	_scene._select_race("troll")
	_scene._last_selection_msec = -_scene.SELECTION_DWELL_MSEC
	_scene._select_class("shaman")
	await get_tree().create_timer(0.5).timeout
	_check(_scene._portrait.texture.resource_path == HeroOptions.RACES.troll.art and _scene._badge.texture.resource_path == HeroOptions.CLASSES.shaman.art, "quick choices both show")
	_tap_table()

	# With four heroes there is no room for more.
	for id: Array in [["goblin", "paladin", 0], ["troll", "warrior", 1]]:
		var extra := Party.Hero.new()
		extra.name = id[0]
		extra.race = id[0]
		extra.hero_class = id[1]
		extra.seat = id[2]
		reloaded.heroes.append(extra)
	_scene._show_view(VIEW_PARTY)
	var free_seat: SeatToken = _scene.get_node("Seats/Seat6")
	free_seat.pressed.emit()
	_check(free_seat.mode == SeatToken.Mode.DIMMED and _scene._view == VIEW_PARTY, "a full party cannot take another hero")
	reloaded.heroes.resize(2)
	_scene._show_view(VIEW_PARTY)

	# Deleting asks once more, and works for the last hero too.
	loaded_token.pressed.emit()
	delete.pressed.emit()
	_check(reloaded.heroes.size() == 2, "the first tap on delete only asks")
	delete.pressed.emit()
	_check(reloaded.hero_at(5) == null and Party.load_file(PARTY_PATH).heroes.size() == 1, "the second deletes the hero for good")
	token.pressed.emit()
	delete.pressed.emit()
	delete.pressed.emit()
	_check(_scene._view == VIEW_PARTY and reloaded.heroes.is_empty() and done.disabled, "without heroes it is back at the table, with no way to battle")

	# A laptop webcam delivers colour frames instead of Android's format. The hero's card
	# was just in view, so it has to leave first.
	token.pressed.emit()
	_feed.show_image(NOTHING)
	await get_tree().create_timer(AWAY_SEC).timeout
	_feed.deliver_rgb = true
	_feed.show_image(DWARF)
	await _until(func() -> bool: return not _scene._draft.race.is_empty(), READ_TIMEOUT_SEC)
	_check(_scene._draft.race == "dwarf", "reads a card from colour frames, as on a laptop")

	# Changing the language reaches what is on screen, in both views.
	var prompt: Label = _scene._prompt
	_check(done.text == "Fertig" and prompt.text == "Deine Klassenkarte", "the editor starts in German")
	TranslationServer.set_locale("en")
	await get_tree().process_frame
	_check(done.text == "Done" and prompt.text == "Your class card", "the open editor follows the language")
	_tap_table()
	_check(done.text == "To Battle!", "the table stays in that language")
	TranslationServer.set_locale("de")
	await get_tree().process_frame
	_check(done.text == "Zum Kampf!" and _scene._party_name_edit.placeholder_text == "Name der Gruppe", "the table follows the language")


func _open_scene() -> void:
	_scene = load("res://onboarding.tscn").instantiate()
	_scene.party_path = PARTY_PATH
	_scene.cards_path = CARDS_PATH
	add_child(_scene)


## A tap at a place in the scene, sent through the viewport like a real one.
func _tap(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var tap := InputEventMouseButton.new()
		tap.button_index = MOUSE_BUTTON_LEFT
		tap.pressed = pressed
		tap.position = at
		tap.global_position = at
		get_viewport().push_input(tap, true)


## The table above the panel, where there are no seats.
func _tap_table() -> void:
	_tap(Vector2(_scene.size.x / 2.0, _scene._stage.global_position.y / 2.0))


func _until(condition: Callable, timeout_sec: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _check(condition: bool, description: String) -> void:
	_checks_run += 1
	print(("  ok   " if condition else "  FAIL ") + description)
	if not condition:
		_failures += 1
