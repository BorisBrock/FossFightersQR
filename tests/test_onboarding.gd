extends Node
## Runs the real onboarding scene against a fake camera, as a group of players would.
## Needs a rendering device, so not headless: godot res://tests/test_onboarding.tscn

const PARTY_PATH := "user://test_onboarding_party.json"
const DWARF := "res://tests/fixtures/qr_char_dwarf.png"
const ELF := "res://tests/fixtures/qr_char_elf.png"
const THIEF := "res://tests/fixtures/qr_class_thief.png"
const DRUID := "res://tests/fixtures/qr_class_druid.png"
const FIREBALL := "res://tests/fixtures/qr_card.png"
const NOTHING := "res://tests/fixtures/no_code.png"
const VIEW_PARTY := 0
const VIEW_CHARACTER := 1
const VIEW_CLASS := 2
const VIEW_SEAT := 3
const READ_TIMEOUT_SEC := 2.0
## Longer than the code needs to count as taken away.
const AWAY_SEC := 2.3
## Time for a read if the card were going to count.
const IGNORE_SEC := 1.0
const EXPECTED_CHECKS := 41

var _feed: FakeCameraFeed
var _scene: Node
var _failures := 0
var _checks_run := 0
var _frame_accumulator := 0.0


func _ready() -> void:
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
	await get_tree().create_timer(0.6).timeout
	var next: Button = _scene.get_node("Stage/Margin/Layout/Footer/Next")
	var remove: Button = _scene.get_node("Stage/Margin/Layout/Footer/Remove")
	var back: Button = _scene.get_node("Stage/Margin/Layout/Footer/Back")

	# The first player chooses a character.
	_check(_scene._view == VIEW_CHARACTER, "an empty party starts with the first hero's character")
	_check(_scene.get_node("Seats").get_child_count() == 7 and Party.SEAT_COUNT == 7, "the table has seven seats")
	_check(_scene._camera_problem.is_empty() and _scene._camera_view.visible, "debug builds show the camera while waiting for a card")
	_check(next.disabled and not back.visible, "cannot go on or back before choosing")
	_feed.show_image(THIEF)
	await get_tree().create_timer(IGNORE_SEC).timeout
	_check(_scene._draft.race.is_empty() and _scene._draft.hero_class.is_empty(), "a class card is ignored when choosing a character")
	_feed.show_image(FIREBALL)
	await get_tree().create_timer(IGNORE_SEC).timeout
	_check(_scene._draft.race.is_empty(), "a playing card is ignored")
	_feed.show_image(DWARF)
	await _until(func() -> bool: return not _scene._draft.race.is_empty(), READ_TIMEOUT_SEC)
	_check(_scene._draft.race == "dwarf", "a character card chooses the race: '%s'" % _scene._draft.race)
	_check(_scene._draft.name in HeroOptions.RACES.dwarf.names, "the race suggests a name: '%s'" % _scene._draft.name)
	_check(not next.disabled, "can go on after choosing")

	# Another card replaces the choice, and the suggested name goes along with it.
	await get_tree().create_timer(0.9).timeout
	_feed.show_image(ELF)
	await _until(func() -> bool: return _scene._draft.race == "elf", READ_TIMEOUT_SEC)
	_check(_scene._draft.race == "elf" and _scene._draft.name in HeroOptions.RACES.elf.names, "another card changes race and suggested name")
	var name_edit: LineEdit = _scene.get_node("Stage/Margin/Layout/Views/Wizard/Info/NameRow/NameEdit")
	name_edit.text = "Boris"
	name_edit.text_changed.emit("Boris")
	await get_tree().create_timer(0.9).timeout
	_feed.show_image(DWARF)
	await _until(func() -> bool: return _scene._draft.race == "dwarf", READ_TIMEOUT_SEC)
	_check(_scene._draft.name == "Boris", "a typed name survives changing the race")
	name_edit.text = "  "
	name_edit.text_changed.emit("  ")
	_check(next.disabled, "cannot go on without a name")
	name_edit.text = "Boris"
	name_edit.text_changed.emit("Boris")

	# The class step takes only class cards.
	next.pressed.emit()
	_check(_scene._view == VIEW_CLASS and next.disabled, "goes on to the class")
	await get_tree().create_timer(IGNORE_SEC).timeout
	_check(_scene._draft.hero_class.is_empty() and _scene._draft.race == "dwarf", "the character card still in view is ignored")
	_feed.show_image(THIEF)
	await _until(func() -> bool: return not _scene._draft.hero_class.is_empty(), READ_TIMEOUT_SEC)
	_check(_scene._draft.hero_class == "thief", "a class card chooses the class")

	# The seat step takes no cards at all, just a tap. Moving on at once leaves the
	# reveal of the class card unfinished, which must not overwrite the picture.
	next.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	var shown: TextureRect = _scene.get_node("Stage/Margin/Layout/Views/Wizard/CardArea/Frame/Portrait")
	_check(shown.texture.resource_path == HeroOptions.RACES.dwarf.art, "the seat step shows the character, not the crest being revealed")
	_check(_scene._view == VIEW_SEAT and next.disabled, "goes on to the seat, which a new hero must tap")
	_tap_step(VIEW_CHARACTER)
	_check(_scene._view == VIEW_CHARACTER and _scene._draft.race == "dwarf" and _scene._draft.hero_class == "thief", "tapping a step goes back to change it, keeping all choices")
	await get_tree().create_timer(0.9).timeout
	_feed.show_image(ELF)
	await _until(func() -> bool: return _scene._draft.race == "elf", READ_TIMEOUT_SEC)
	_check(_scene._draft.race == "elf" and _scene._draft.name == "Boris", "the race can be changed that way")
	_tap_step(VIEW_SEAT)
	_check(_scene._view == VIEW_SEAT, "tapping a later step that is complete jumps there")
	_tap_step(VIEW_CHARACTER)
	await get_tree().create_timer(0.9).timeout
	_feed.show_image(DWARF)
	await _until(func() -> bool: return _scene._draft.race == "dwarf", READ_TIMEOUT_SEC)
	_tap_step(VIEW_SEAT)
	var seat_three: SeatToken = _scene.get_node("Seats/Seat3")
	_check(seat_three.mode == SeatToken.Mode.SELECTABLE, "free seats can be tapped")
	seat_three.pressed.emit()
	await _until(func() -> bool: return _scene._view == VIEW_PARTY, READ_TIMEOUT_SEC)
	_check(_scene._view == VIEW_PARTY and _scene._party.hero_at(3) != null, "tapping seats the hero and shows the party")
	_check(seat_three.get_node("NamePlate/Name").text == "Boris", "the seat shows the hero")

	# The second player still has the first player's card in front of the camera.
	_feed.show_image(DWARF)
	await get_tree().create_timer(0.5).timeout
	_scene._start_new_hero()
	await get_tree().create_timer(IGNORE_SEC).timeout
	_check(_scene._draft.race.is_empty(), "a card still in view does not count for the next hero")
	_tap_step(VIEW_SEAT)
	_check(_scene._view == VIEW_CHARACTER, "steps that are not complete cannot be opened")
	_feed.show_image(NOTHING)
	await get_tree().create_timer(AWAY_SEC).timeout

	# Every character and class can only be picked once.
	_feed.show_image(DWARF)
	var hint: Label = _scene._hint
	await _until(func() -> bool: return hint.text.contains("Boris"), READ_TIMEOUT_SEC)
	_check(_scene._draft.race.is_empty() and hint.text.contains("Boris"), "a character that is taken is refused, saying by whom: '%s'" % hint.text)
	_feed.show_image(ELF)
	await _until(func() -> bool: return not _scene._draft.race.is_empty(), READ_TIMEOUT_SEC)
	_check(_scene._draft.race == "elf", "a free character can be picked")
	next.pressed.emit()
	await get_tree().create_timer(0.3).timeout
	_feed.show_image(THIEF)
	await _until(func() -> bool: return hint.text.contains("Boris"), READ_TIMEOUT_SEC)
	_check(_scene._draft.hero_class.is_empty(), "a class that is taken is refused")
	_feed.show_image(DRUID)
	await _until(func() -> bool: return not _scene._draft.hero_class.is_empty(), READ_TIMEOUT_SEC)
	_check(_scene._draft.hero_class == "druid", "a free class can be picked")
	next.pressed.emit()
	_check(seat_three.mode == SeatToken.Mode.DIMMED, "another hero's seat cannot be tapped")
	var seat_five: SeatToken = _scene.get_node("Seats/Seat5")
	seat_five.pressed.emit()
	await _until(func() -> bool: return _scene._view == VIEW_PARTY, READ_TIMEOUT_SEC)

	# Next time the game starts, everything is still there.
	_scene.queue_free()
	await get_tree().process_frame
	_open_scene()
	await get_tree().create_timer(0.6).timeout
	var reloaded: Party = _scene._party
	_check(_scene._view == VIEW_PARTY and reloaded.heroes.size() == 2, "the party is remembered between runs")
	_check(reloaded.hero_at(3).name == "Boris" and reloaded.hero_at(3).race == "dwarf" and reloaded.hero_at(3).hero_class == "thief", "with names and choices")
	var loaded_token: SeatToken = _scene.get_node("Seats/Seat5")
	_check(reloaded.hero_at(5) != null and loaded_token.get_node("NamePlate").visible, "and seats")

	# Changing a hero: one change is enough, without walking through the other steps.
	remove = _scene.get_node("Stage/Margin/Layout/Footer/Remove")
	next = _scene.get_node("Stage/Margin/Layout/Footer/Next")
	back = _scene.get_node("Stage/Margin/Layout/Footer/Back")
	var token: SeatToken = _scene.get_node("Seats/Seat3")
	_feed.show_image(NOTHING)
	await get_tree().create_timer(AWAY_SEC).timeout
	token.pressed.emit()
	_check(_scene._view == VIEW_CHARACTER and not next.disabled, "tapping a seated hero opens them for changes")
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
	back.pressed.emit()
	_check(_scene._view == VIEW_PARTY and reloaded.hero_at(3).name == "Boris", "leaving with back discards the change")
	token.pressed.emit()
	renamed.text = "Boris II"
	renamed.text_changed.emit("Boris II")
	next.pressed.emit()
	_check(_scene._view == VIEW_PARTY and Party.load_file(PARTY_PATH).hero_at(3).name == "Boris II", "done saves it right away, keeping the seat")

	# Removing asks once more.
	token.pressed.emit()
	remove.pressed.emit()
	_check(reloaded.heroes.size() == 2, "the first tap on remove only asks")
	remove.pressed.emit()
	_check(reloaded.hero_at(3) == null and Party.load_file(PARTY_PATH).heroes.size() == 1, "the second removes the hero for good")

	# A laptop webcam delivers colour frames instead of Android's format. The hero's card
	# was just in view, so it has to leave first.
	_scene._start_new_hero()
	_feed.show_image(NOTHING)
	await get_tree().create_timer(AWAY_SEC).timeout
	_feed.deliver_rgb = true
	_feed.show_image(DWARF)
	await _until(func() -> bool: return not _scene._draft.race.is_empty(), READ_TIMEOUT_SEC)
	_check(_scene._draft.race == "dwarf", "reads a card from colour frames, as on a laptop")


func _tap_step(view: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	_scene._on_pip_input(event, view)


func _open_scene() -> void:
	_scene = load("res://onboarding.tscn").instantiate()
	_scene.party_path = PARTY_PATH
	add_child(_scene)


func _until(condition: Callable, timeout_sec: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _check(condition: bool, description: String) -> void:
	_checks_run += 1
	print(("  ok   " if condition else "  FAIL ") + description)
	if not condition:
		_failures += 1
