extends Node
## Runs the real game scene and the real GPU readback against a fake camera,
## following the behaviour the game promises.
## Needs a rendering device, so not headless: godot res://tests/test_game.tscn

const CODE_A := "FOSS-FIGHTER:VIVOSAUR:0137"
const CODE_B := "Grüße aus dem Fossilien-Labor 🦖"
const CODE_CARD := "CORE-001"
const UNKNOWN_TITLE := "Unknown card"
const UNKNOWN_TITLE_GERMAN := "Unbekannte Karte"
const CAMERA_FPS := 30.0
const READ_TIMEOUT_SEC := 2.0
const EXPECTED_CHECKS := 26

var _feed: FakeCameraFeed
var _back_feed: FakeCameraFeed
var _failures := 0
var _checks_run := 0
var _main: Node
var _frame_accumulator := 0.0


func _ready() -> void:
	TranslationServer.set_locale("en")
	# A new feed takes the first id no registered feed uses, so each one has to be
	# registered before the next is created. Otherwise both get the same id.
	_feed = FakeCameraFeed.new("Fake front camera", CameraFeed.FEED_FRONT)
	CameraServer.add_feed(_feed)
	_back_feed = FakeCameraFeed.new("Fake back camera", CameraFeed.FEED_BACK)
	CameraServer.add_feed(_back_feed)
	_feed.show_image("res://tests/fixtures/no_code.png")
	_back_feed.show_image("res://tests/fixtures/qr_unicode.png")
	_main = load("res://main.tscn").instantiate()
	# The real catalog changes, while the code in the picture of a card stays.
	_main._cards = CardDatabase.load_file("res://tests/fixtures/game_cards.json")
	add_child(_main)
	await _run()
	_check(_checks_run == EXPECTED_CHECKS, "all checks ran")
	print("test_game: %s" % ("PASSED" if _failures == 0 else "%d FAILED" % _failures))
	# The engine cannot clean up a script-based feed that is still registered at exit.
	_main.queue_free()
	await get_tree().process_frame
	CameraServer.remove_feed(_feed)
	CameraServer.remove_feed(_back_feed)
	_feed = null
	_back_feed = null
	get_tree().quit(1 if _failures > 0 else 0)


func _process(delta: float) -> void:
	_frame_accumulator += delta
	if _frame_accumulator >= 1.0 / CAMERA_FPS:
		_frame_accumulator = 0.0
		if _feed:
			_feed.deliver_frame()
			_back_feed.deliver_frame()


func _run() -> void:
	var panel: Control = _main.get_node("Hud/Result")
	var title: Label = _main.get_node("Hud/Result/Margin/Content/Title")
	var label: Label = _main.get_node("Hud/Result/Margin/Content/Details")
	var pling: AudioStreamPlayer = _main.get_node("Pling")

	await get_tree().create_timer(1.0).timeout
	_check(not panel.visible, "nothing shown without a code")
	_check(not pling.playing, "no pling without a code")

	# First read.
	var start := Time.get_ticks_msec()
	_feed.show_image("res://tests/fixtures/qr_vivosaur.png")
	await _until(func() -> bool: return panel.visible, READ_TIMEOUT_SEC)
	var read_msec := Time.get_ticks_msec() - start
	_check(panel.visible and title.text == UNKNOWN_TITLE, "a code without a card is unknown: '%s'" % title.text)
	_check(label.text == CODE_A, "its value is shown: '%s'" % label.text)
	_check(pling.playing, "pling plays on the read")
	print("  info time from code visible to read: %d ms" % read_msec)
	_check(read_msec < 500, "read within 500 ms")

	# While the code stays visible: text stays, no repeated plings.
	await get_tree().create_timer(1.0).timeout
	_check(not pling.playing, "pling does not repeat while the code stays visible")
	_check(panel.visible, "text stays while the code is visible")

	# After the code leaves: text stays for 5 more seconds, then disappears.
	_feed.show_image("res://tests/fixtures/no_code.png")
	var gone := Time.get_ticks_msec()
	await get_tree().create_timer(4.5).timeout
	_check(panel.visible, "text still shown 4.5 s after the code disappeared")
	await _until(func() -> bool: return not panel.visible, 2.0)
	var shown_sec := (Time.get_ticks_msec() - gone) / 1000.0
	print("  info text disappeared after %.2f s" % shown_sec)
	_check(not panel.visible and shown_sec < 5.5, "text gone about 5 s after the code disappeared")

	# A code coming back plings again; a different code replaces the text at once.
	_feed.show_image("res://tests/fixtures/qr_vivosaur.png")
	await _until(func() -> bool: return panel.visible, READ_TIMEOUT_SEC)
	_check(pling.playing, "same code plings again after being away")
	await get_tree().create_timer(0.8).timeout
	_feed.show_image("res://tests/fixtures/qr_unicode.png")
	await _until(func() -> bool: return label.text == CODE_B, READ_TIMEOUT_SEC)
	_check(label.text == CODE_B, "different code replaces the text: '%s'" % label.text)
	_check(pling.playing, "different code plings")

	# A code with a card shows the card's data in the device's language.
	TranslationServer.set_locale("de")
	_feed.show_image("res://tests/fixtures/no_code.png")
	await get_tree().create_timer(0.5).timeout
	_feed.show_image("res://tests/fixtures/qr_card.png")
	await _until(func() -> bool: return title.text == "Feuerball", READ_TIMEOUT_SEC)
	_check(title.text == "Feuerball", "known card shows its title: '%s'" % title.text)
	_check(label.text.begins_with(CODE_CARD + " · loot · Stufe 3\nAngriff 3 · Unterstützung 1\nFüge"), "known card shows its data: '%s'" % label.text)
	_check(pling.playing, "known card plings")
	var result_top := panel.global_position.y
	_check(result_top >= 0.0 and panel.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y, "card fits on the screen: top at %.0f" % result_top)

	# Changing the language reaches what is on screen.
	TranslationServer.set_locale("en")
	await get_tree().process_frame
	_check(label.text.contains("Level 3\nAttack 3 · Support 1"), "the card follows the language: '%s'" % label.text)
	_check(_main.get_node("Hud/Status").text == "Hold a QR code over the camera", "the status follows the language")
	TranslationServer.set_locale("de")

	# Back to a short text: the panel shrinks again and the card data is gone.
	_feed.show_image("res://tests/fixtures/qr_vivosaur.png")
	await _until(func() -> bool: return title.text == UNKNOWN_TITLE_GERMAN, READ_TIMEOUT_SEC)
	await get_tree().process_frame
	_check(label.text == CODE_A and panel.global_position.y > result_top, "unknown code replaces a card")
	TranslationServer.set_locale("en")

	# Switching cameras: the other camera is scanned, and back again.
	var scanner: QrCameraScanner = _main.get_node("QrCameraScanner")
	var switch_button: Button = _main.get_node("Hud/SwitchCamera")
	_check(switch_button.visible, "switch button is shown when there are two cameras")
	_feed.show_image("res://tests/fixtures/no_code.png")
	await get_tree().create_timer(5.5).timeout
	_check(not panel.visible, "no text before switching")
	switch_button.pressed.emit()
	await _until(func() -> bool: return panel.visible, READ_TIMEOUT_SEC)
	_check(panel.visible and scanner._feed == _back_feed and label.text == CODE_B, "back camera is scanned after switching: '%s'" % label.text)
	_check(not _feed.feed_is_active, "front camera is closed after switching")
	await _until(func() -> bool: return not switch_button.disabled, READ_TIMEOUT_SEC)
	switch_button.pressed.emit()
	await _until(func() -> bool: return not switch_button.disabled, READ_TIMEOUT_SEC)
	_check(scanner._feed == _feed and _feed.feed_is_active and not _back_feed.feed_is_active, "switching back returns to the front camera")

	var stats: Dictionary = scanner.get_stats()
	print("  info decoder stats: %s, game %d fps" % [stats, Engine.get_frames_per_second()])
	_check(stats.frames_submitted > 100, "frames keep flowing from the GPU to the decoder")


func _until(condition: Callable, timeout_sec: float) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _check(condition: bool, description: String) -> void:
	_checks_run += 1
	print(("  ok   " if condition else "  FAIL ") + description)
	if not condition:
		_failures += 1
