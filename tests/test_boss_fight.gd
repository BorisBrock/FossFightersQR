extends Node
## The boss fight screen: what it shows, how the players take part in the fight, and
## ending it, and the game over screen. The rules themselves are tested in test_fight.gd.
## Runs as a scene, because it needs the autoloads:
## godot --headless res://tests/test_boss_fight.tscn

const PARTY_PATH := "user://test_boss_fight_party.json"
const SETTINGS_PATH := "user://test_boss_fight_settings.cfg"
const CARDS_PATH := "res://tests/fixtures/fight_cards.json"
const EXPECTED_CHECKS := 105

var _failures := 0
var _checks_run := 0
var _next: Node


func _ready() -> void:
	Settings.load_file(SETTINGS_PATH)
	TranslationServer.set_locale("en")
	_check_fight_state()
	await _check_screen()
	await _check_messages()
	await _check_countdown()
	await _check_round()
	await _check_shield_choice()
	await _check_boss_look()
	await _check_give_up()
	await _check_defeat()
	await _check_game_over()
	_check(_checks_run == EXPECTED_CHECKS - 1, "all checks ran: %d" % _checks_run)
	DirAccess.remove_absolute(SETTINGS_PATH)
	DirAccess.remove_absolute(PARTY_PATH)
	print("test_boss_fight: %s" % ("PASSED" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


## A boss that remembers which hooks were called, as a boss with special rules would.
class TestBoss extends Boss:
	var calls: Array[String] = []

	func _init() -> void:
		health = 20

	func fight_started(_fight: Fight) -> void:
		calls.append("fight_started")

	func round_started(fight: Fight) -> void:
		calls.append("round_started %d" % fight.round_number)

	func damage_taken(_fight: Fight, amount: int, kind: String, _play: CardPlay) -> int:
		return 0 if kind == "magic" else amount


func _check_fight_state() -> void:
	var boss := TestBoss.new()
	_check(boss.max_health("easy") == 15 and boss.max_health("normal") == 20 and boss.max_health("hard") == 25, "the difficulty scales the boss's health")
	var fight := Fight.new(boss, "normal")
	var won := [false]
	fight.won.connect(func() -> void: won[0] = true)
	var told: Array[String] = []
	fight.message.connect(func(id: String, values: Dictionary) -> void: told.append("%s %s" % [id, values.get("round")]))
	fight.start()
	_check(boss.calls == ["fight_started"] and told == ["boss_taunt <null>"], "a fight starts with the boss's greeting")
	fight.players_ready()
	_check(told.has("first_round 1") and boss.calls[-1] == "round_started 1", "then round 1 is announced, with drawing the cards, and the boss told")
	fight.deal_damage(5, "melee")
	_check(fight.health == 15, "an attack takes off health")
	fight.deal_damage(5, "magic")
	_check(fight.health == 15, "the boss decides how much an attack hurts")
	fight.deal_damage(100, "melee")
	_check(fight.health == 0 and won[0], "health stops at 0, which wins the fight")

	var plain := Fight.new(Bosses.create("mirefang"), "normal")
	plain.set_shields({ "melee": 2 })
	plain.deal_damage(9, "melee")
	_check(plain.health == plain.max_health - 7, "a boss's shield absorbs its part of an attack")

	var bosses_differ := Bosses.create("mirefang") != Bosses.create("mirefang")
	_check(bosses_differ, "each fight gets its own boss")


func _check_screen() -> void:
	var party := Party.new(PARTY_PATH)
	for entry: Array in [["Sonja", "dryad", "druid", 1], ["Borin", "dwarf", "warrior", 3]]:
		var hero := Party.Hero.new()
		hero.name = entry[0]
		hero.race = entry[1]
		hero.hero_class = entry[2]
		hero.seat = entry[3]
		party.heroes.append(hero)
	party.save()
	Encounter.boss = "mirefang"
	Encounter.difficulty = "hard"
	var screen := await _open()
	var boss := Bosses.create("mirefang")
	_check(screen.fight.boss.id == "mirefang" and screen.fight.difficulty == "hard", "the fight is against the chosen boss")
	_check(screen.get_node("Figure").texture == load(boss.figure), "the boss stands in the middle")
	_check(screen.get_node("Background").texture == load(boss.background), "in front of its own background")
	var figure_material: ShaderMaterial = screen.get_node("Figure").material
	_check(figure_material.get_shader_parameter("slither") == boss.motion_amount, "and moves as it says")
	_check((screen.get_node("Ambience") as CPUParticles2D).color_ramp.get_color(1).r == boss.ambience_color.r, "with its own particles")
	_check(screen.get_node("Hud/Round/Row/Value").text == "1", "the fight starts in round 1")
	_check(screen.get_node("Hud/Health/Row/Value").text == "0", "the boss's health counts up")
	await get_tree().create_timer(screen.HEALTH_COUNT_SEC + 0.6).timeout
	_check(screen.get_node("Hud/Health/Row/Value").text == str(boss.max_health("hard", 2)), "to its full health")
	var shown := []
	for token: SeatToken in screen.get_node("Seats").get_children():
		if token.visible:
			shown.append(token.seat)
	_check(shown == [1, 3], "only seats with a hero show")
	_check(screen.get_node("Banner/Text").text == "Mirefang", "the boss's name is announced")
	_check(not get_tree().quit_on_go_back, "the back button of a phone does not quit the app")

	screen.fight.deal_damage(7, "magic")
	await get_tree().create_timer(0.5).timeout
	_check(screen.is_showing_steps() and screen.get_node("AttackEffects").get_child_count() > 0, "an attack shows on the boss, with particles")
	_check(screen.get_node("Hud/Health/Row/Value").text == str(boss.max_health("hard", 2)), "before the health goes down")
	await _until(func() -> bool: return not screen.is_showing_steps(), 6.0)
	_check(screen.get_node("Hud/Health/Row/Value").text == str(boss.max_health("hard", 2) - 7), "the health shown follows the fight")
	_check(not screen.get_node("Hud/Poison").visible, "the boss's poison only shows once it has some")
	screen.fight.poison_boss(2)
	_check(screen.get_node("Hud/Poison").visible and screen.get_node("Hud/Poison/Row/Value").text == "2", "then how much")

	# What lasts a while: a Totem by its hero's seat, Muttis Nachtisch for everyone.
	var borin: FightHero = screen.fight.hero_at(3)
	var seat: SeatToken = screen.get_node("Seats/Seat3")
	var chips: BuffChips = seat.get_node("Badge/Row/Buffs")
	var totem: FightRule = load("res://scripts/abilities/empower.gd").Boost.new()
	totem.hero = borin
	totem.type = "attack"
	totem.bonus = 1
	totem.totem = true
	screen.fight.add_rule(totem, true)
	_check(chips.visible and chips.get_child_count() == 1 and seat.get_node("Badge").visible and seat.totem, "a Totem shows by its hero, whose portrait glows")
	var dessert: FightRule = load("res://scripts/abilities/boost_next_cards.gd").Boost.new()
	dessert.left = 8
	dessert.bonus = 1
	screen.fight.add_rule(dessert)
	var global: BuffChips = screen.get_node("Hud/Buffs")
	_check(global.visible and global.get_child_count() == 1 and chips.get_child_count() == 1, "a buff for everyone shows at the top, not by a seat")
	screen.fight.remove_rule(totem)
	screen.fight.remove_rule(dessert)
	_check(not chips.visible and not global.visible and not seat.totem, "and both go once they are over")
	# A badge that grows and shrinks again, as buffs and actions come and go, stays on the
	# portrait instead of creeping up.
	var badge: Control = seat.get_node("Badge")
	var bottom: float = seat.portrait_rect().position.y - screen.BADGE_GAP
	for i in 3:
		screen.fight.add_rule(totem, true)
		screen.fight.remove_rule(totem)
	screen.fight.add_rule(totem, true)
	_check(is_equal_approx(badge.position.y + badge.size.y, bottom), "a badge that grew and shrank stays on its portrait")
	screen.fight.remove_rule(totem)
	screen.queue_free()


func _check_messages() -> void:
	var screen := await _open()
	var box: MessageBox = screen.messages
	var layout := box.get_node("Margin/Panel/Margin/Layout")
	var confirm: Button = layout.get_node("Confirm")
	var confirmed: Array[String] = []
	box.confirmed.connect(func(id: String) -> void: confirmed.append(id))
	var all_confirmed := [false]
	box.all_confirmed.connect(func() -> void: all_confirmed[0] = true)
	_check(box.current() == "boss_taunt" and not box.visible, "the boss speaks, but not over its name")
	await get_tree().create_timer(screen.INTRO_SEC + MessageBox.CONFIRM_DELAY_SEC + 0.5).timeout
	_check(box.visible and layout.get_node("Header/Title").text == "[center]Mirefang[/center]", "then its words show")
	_check(layout.get_node("Body").get_parsed_text().contains("hungry"), "in its own words")
	screen.fight.tell("example_magic_potion", { "health": 10 })
	screen.show_message("example_reminder")
	_check(box.queue.size() == 3 and box.current() == "boss_taunt", "later messages wait their turn")

	confirm.pressed.emit()
	_check(confirmed == ["boss_taunt"] and box.current() == "example_magic_potion", "the check mark shows the next message")
	_check(layout.get_node("Body").get_parsed_text().contains("10 health points"), "with its placeholders filled in")
	confirm.pressed.emit()
	_check(box.current() == "example_magic_potion", "a quick second tap does not close it unread")
	await get_tree().create_timer(MessageBox.CONFIRM_DELAY_SEC + 0.2).timeout
	TranslationServer.set_locale("de")
	await get_tree().process_frame
	_check(layout.get_node("Body").get_parsed_text().contains("10 Lebenspunkte"), "a new language shows at once")
	TranslationServer.set_locale("en")
	await get_tree().process_frame

	confirm.pressed.emit()
	await get_tree().create_timer(MessageBox.CONFIRM_DELAY_SEC + 0.2).timeout
	_check(not layout.get_node("Header").visible and box.visible, "a message without a title shows only its body")
	confirm.pressed.emit()
	await get_tree().create_timer(MessageBox.FADE_SEC + 0.1).timeout
	_check(confirmed == ["boss_taunt", "example_magic_potion", "example_reminder"] and all_confirmed[0], "each message is confirmed in turn")
	_check(box.current() == "first_round", "and once all are read, the fight goes on")
	screen.queue_free()


## Messages that ask nothing of the players close by themselves, unless a player taps them.
func _check_countdown() -> void:
	var screen := await _open()
	var box: MessageBox = screen.messages
	var bar: CountdownBar = box.get_node("Margin/Panel/Margin/Layout/Confirm/Countdown")
	await get_tree().create_timer(screen.INTRO_SEC + MessageBox.CONFIRM_DELAY_SEC + 0.3).timeout
	_check(box.current() == "boss_taunt" and box.is_counting_down() and bar.visible and bar.value < 1.0, "the boss's words, which ask nothing, run down in the check mark")

	var panel: Control = box.get_node("Margin/Panel")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = panel.get_global_rect().get_center() - Vector2(0, panel.size.y / 2.0 - 20.0)
	get_viewport().push_input(tap, true)
	var release := tap.duplicate()
	release.pressed = false
	get_viewport().push_input(release, true)
	await get_tree().process_frame
	_check(box.current() == "boss_taunt" and not box.is_counting_down() and not bar.visible, "tapping the message stops it, and it waits for the check mark")

	await _confirm(box)
	await get_tree().create_timer(MessageBox.CONFIRM_DELAY_SEC + 0.3).timeout
	_check(box.current() == "first_round" and not box.is_counting_down(), "round 1, with drawing the cards, waits for the check mark")
	await _confirm(box)
	var check_mark: Control = box.get_node("Margin/Panel/Margin/Layout/Confirm")
	_check(box.current() == "boss_planning" and not box.is_counting_down() and not check_mark.visible and not box.get_node("Dim").visible, "while the boss plans its attacks, its message has no check mark and leaves the fight undimmed")
	await _until(func() -> bool: return box.current() != "boss_planning", 8.0)
	_check(box.current() != "boss_planning", "once the attacks are shown, it closes by itself")
	# Then maybe Mirefang's bite, which asks nothing either.
	while box.is_showing():
		box._countdown_left = 0.1
		await get_tree().create_timer(MessageBox.FADE_SEC + MessageBox.CONFIRM_DELAY_SEC + 0.2).timeout
	await _until(func() -> bool: return screen.fight.request != null, 4.0)
	_check(not box.is_showing() and screen.fight.request != null, "when they have run down, they close, and the fight goes on")

	screen.show_message("boss_poison", { "boss": "Toad", "poison": 1, "damage": 1 })
	await get_tree().create_timer(MessageBox.CONFIRM_DELAY_SEC + 0.3).timeout
	_check(box.current() == "boss_poison" and box.is_counting_down() and check_mark.visible, "the next one runs down again, with its check mark")
	var dialog := Node.new()
	dialog.add_to_group(MenuScreen.DIALOG_GROUP)
	add_child(dialog)
	var left := box.countdown_left()
	await get_tree().create_timer(0.3).timeout
	_check(is_equal_approx(box.countdown_left(), left), "not while a dialog is open, such as the settings")
	dialog.free()
	await _confirm(box)

	screen.show_message("example_reminder")
	await get_tree().create_timer(MessageBox.CONFIRM_DELAY_SEC + 0.3).timeout
	_check(box.current() == "example_reminder" and not box.is_counting_down(), "a message that asks something waits for the check mark")
	await _confirm(box)
	Settings.message_time = "off"
	screen.show_message("boss_poison", { "boss": "Toad", "poison": 1, "damage": 1 })
	await get_tree().create_timer(MessageBox.CONFIRM_DELAY_SEC + 0.3).timeout
	_check(box.current() == "boss_poison" and not box.is_counting_down(), "in the settings, players can have every message wait")
	Settings.message_time = "normal"
	var short := MessageBox.auto_seconds("Two words")
	var long := MessageBox.auto_seconds(" ".join(PackedStringArray(range(100).map(func(i: int) -> String: return "word"))))
	Settings.message_time = "slow"
	var slow := MessageBox.auto_seconds("Two words")
	Settings.message_time = "normal"
	_check(short == MessageBox.AUTO_MIN_SEC and long == MessageBox.AUTO_MAX_SEC and slow > short, "the more there is to read, the longer, within limits, and longer for slow")
	screen.queue_free()


## A round as the players see it: choosing who starts, the phases, and playing cards.
func _check_round() -> void:
	Encounter.boss = "mirefang"
	Encounter.difficulty = "normal"
	var screen := await _open()
	screen.fight.rng.seed = 2
	screen.fight.boss.shield_value = 2
	screen.fight.boss.shield_by_heroes.clear()
	screen.fight.boss.shield_low.clear()
	screen.fight.boss.shield_high.clear()
	var box: MessageBox = screen.messages
	var tokens := {}
	for token: SeatToken in screen.get_node("Seats").get_children():
		tokens[token.seat] = token
	await get_tree().create_timer(screen.INTRO_SEC).timeout
	await _confirm(box)
	await get_tree().create_timer(MessageBox.FADE_SEC + 0.1).timeout
	_check(box.current() == "first_round" and screen.get_node("Hud/Round/Row/Value").text == "1", "after the boss's words, round 1 begins, with drawing the cards")
	await _confirm(box)
	_check(box.current() == "boss_planning", "and the boss plans its attacks")
	var threats: Array[Control] = [tokens[1].get_node("Threat"), tokens[3].get_node("Threat")]
	_check(not threats[0].visible and not threats[1].visible, "the attacks are not shown yet")
	await get_tree().create_timer(screen.PLAN_START_SEC + 0.1).timeout
	_check(threats[0].visible and not threats[1].visible, "the boss plans them one hero after the other")
	await _until(func() -> bool: return not box.is_showing(), 6.0)
	_check(threats[1].visible and threats[0].get_node("Column/Value").text == str(screen.fight.hero_at(1).threat), "each hero sees the attack against them, beside their portrait")
	await get_tree().process_frame
	var prompt: Control = screen.get_node("Prompt")
	var shield: Label = screen.get_node("Shields").get_child(0).get_node("Shield/Value")
	_check(shield.text == "0" and not prompt.visible, "the boss's shields rise, and the players wait")
	await get_tree().create_timer(1.6).timeout
	_check(shield.text == "2", "they count up to the shields the boss raised")
	await _until(func() -> bool: return prompt.visible, 3.0)
	_check(prompt.visible and tokens[1].mode == SeatToken.Mode.SELECTABLE and tokens[3].mode == SeatToken.Mode.SELECTABLE, "then the players are asked who starts")
	await get_tree().create_timer(0.2).timeout
	_check(tokens[1].get_node("Portrait").scale.x > 1.0, "the heroes to choose from pulse")
	tokens[3].pressed.emit()
	await get_tree().process_frame
	_check(screen.fight.starter.name == "Borin", "tapping a hero chooses them")
	_check(tokens[1].get_node("Portrait").scale.x == 1.0, "and stop once one is chosen")
	await get_tree().create_timer(MessageBox.FADE_SEC + 0.1).timeout
	_check(not box.is_showing(), "in the first round nobody has curses to reveal: the action phase begins at once")
	var text: RichTextLabel = screen.get_node("Prompt/Layout/Text")
	_check(prompt.visible and text.get_parsed_text().contains("Borin") and tokens[3].mode == SeatToken.Mode.ACTIVE, "the chosen hero is asked for a card")
	var spheres: ActionSpheres = tokens[3].get_node("Badge/Row/Actions")
	_check(spheres.visible and spheres.actions().size() == 3, "each hero sees the actions they have left")

	# Mirefang's poison shield is not the melee one, which the axe hits.
	screen.fight.boss.poison_shield = "magic"
	var health: int = screen.fight.health
	var pling: AudioStreamPlayer = screen.get_node("Pling")
	screen._on_code_read("AXE", PackedVector2Array(), Vector2i())
	_check(pling.playing and screen.fight.health == health, "a card shown to the camera plings at once, and does nothing yet")
	await get_tree().create_timer(QrCameraScanner.CONFIRM_SEC / 2.0).timeout
	_check(screen.fight.health == health, "the card waits for the pling")
	await get_tree().create_timer(QrCameraScanner.CONFIRM_SEC / 2.0 + 0.1).timeout
	_check(screen.fight.health == health - 2 and screen.is_showing_steps(), "after the pling, the card is played, and its attack shows")
	_check(screen.get_node("CardName").visible and screen.get_node("CardName").text == "Axe", "with the card's name over the boss")
	var melee: Control = screen.get_node("Shields/Melee/Attack")
	var magic: Control = screen.get_node("Shields/Magic/Attack")
	_check(melee.get_meta("open") and not magic.get_meta("open"), "the attack type it attacked with lights up, the others stay grey")
	pling.stop()
	screen._on_code_read("AXE", PackedVector2Array(), Vector2i())
	_check(not pling.playing, "a card still in view does not pling again")
	await get_tree().create_timer(QrCameraScanner.CONFIRM_SEC + 0.1).timeout
	_check(not screen.get_node("Prompt/Layout/Notice").visible, "a card still in view does not count again")
	var health_shown: Label = screen.get_node("Hud/Health/Row/Value")
	_check(screen.fight.request == null and not prompt.visible and health_shown.text == str(health), "the next hero waits until the attack has shown, and the health too")
	await _until(func() -> bool: return not screen.is_showing_steps(), 8.0)
	await get_tree().process_frame
	_check(shield.text == "0" and health_shown.text == str(health - 2), "the shield takes what it can, breaks, and the rest comes off the health")
	_check(text.get_parsed_text().contains("Sonja") and tokens[1].mode == SeatToken.Mode.ACTIVE, "then it is the next hero's turn")
	screen._on_code_read("NOPE", PackedVector2Array(), Vector2i())
	_check(pling.playing, "an unknown card plings too, as it was read")
	await get_tree().create_timer(QrCameraScanner.CONFIRM_SEC + 0.1).timeout
	_check(screen.get_node("Prompt/Layout/Notice").visible and screen.get_node("Prompt/Layout/Notice").get_parsed_text().contains("NOPE"), "an unknown card is pointed out, with its QR code")
	_check(not screen.get_node("Prompt/Layout/Buttons").visible, "a card is asked for without a button to pass")
	screen.queue_free()


## A card that lowers a shield of the players' choice: they tap the shield, which pulses.
func _check_shield_choice() -> void:
	var screen := await _open()
	var fight: Fight = screen.fight
	var answers: Array = []
	fight._answered.connect(func(value: Variant) -> void: answers.append(value))
	var asked := Fight.Request.new()
	asked.kind = Fight.Request.Kind.SHIELD
	asked.kinds = ["melee", "magic"]
	asked.prompt = "prompt_lower_shield"
	asked.values = { "player": "Sonja", "amount": 2 }
	fight.request = asked
	fight.request_changed.emit(asked)
	await get_tree().create_timer(0.3).timeout
	var melee: Control = screen.get_node("Shields/Melee/Shield")
	var ranged: Control = screen.get_node("Shields/Ranged/Shield")
	var magic: Control = screen.get_node("Shields/Magic/Shield")
	var text: RichTextLabel = screen.get_node("Prompt/Layout/Text")
	_check(text.get_parsed_text().contains("tap the shield you want to lower by 2") and not screen.get_node("Prompt/Layout/Buttons").visible, "the players are asked to tap a shield, without buttons")
	_check(melee.scale.x > 1.0 and magic.scale.x > 1.0 and ranged.scale.x == 1.0, "the shields to choose from pulse, the others do not")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	ranged.gui_input.emit(tap)
	_check(answers.is_empty(), "a shield that cannot be chosen does nothing")
	magic.gui_input.emit(tap)
	_check(answers == ["magic"], "tapping a shield chooses it")
	fight.request = null
	fight.request_changed.emit(null)
	await get_tree().create_timer(0.5).timeout
	_check(magic.scale.x == 1.0 and melee.scale.x == 1.0 and magic.mouse_filter == Control.MOUSE_FILTER_IGNORE and not screen.get_node("Prompt").visible, "then the shields stop pulsing, and the prompt goes")
	screen.queue_free()


## Waits until condition holds, at most seconds.
## The boss going under water and coming up, and its look changing, as Mirefang's do.
func _check_boss_look() -> void:
	Encounter.boss = "mirefang"
	var screen := await _open()
	var figure: ShaderMaterial = screen.get_node("Figure").material
	var shields: Control = screen.get_node("Shields")
	screen.fight.set_boss_away(true)
	await get_tree().create_timer(screen.SINK_SEC + 0.3).timeout
	_check(is_equal_approx(figure.get_shader_parameter("sink"), 1.0) and shields.modulate.a == 0.0, "out of reach, the boss sinks, and its shields are gone")
	screen.fight.set_boss_away(false)
	await get_tree().create_timer(screen.SURFACE_SEC + 0.3).timeout
	_check(is_equal_approx(figure.get_shader_parameter("sink"), 0.0), "then it comes back up")
	var boss: Boss = screen.fight.boss
	boss.eye_color = Color.RED
	boss.motion_seconds = 2.0
	boss.look_changed.emit()
	_check(figure.get_shader_parameter("eye_color") == Color.RED and figure.get_shader_parameter("seconds") == 2.0, "its look can change during the fight")
	screen.queue_free()


## Lets the message id, which closes by itself, run down at once.
func _run_down(box: MessageBox, id: String) -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while box.current() == id and Time.get_ticks_msec() < deadline:
		if box.is_counting_down():
			box._countdown_left = minf(box._countdown_left, 0.1)
		await get_tree().process_frame
	await _until(func() -> bool: return box.is_showing(), 2.0)


func _until(condition: Callable, seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _confirm(box: MessageBox) -> void:
	var confirm: Button = box.get_node("Margin/Panel/Margin/Layout/Confirm")
	var deadline := Time.get_ticks_msec() + 3000
	while (confirm.disabled or not box.is_showing()) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	confirm.pressed.emit()
	await get_tree().process_frame


func _check_give_up() -> void:
	var screen := await _open()
	screen.get_node("Hud/GiveUp/Button").pressed.emit()
	await get_tree().process_frame
	var dialog: ConfirmDialog = screen.get_node_or_null("GiveUpDialog")
	var extra: Button = dialog.get_node("Dim/Center/Panel/Margin/Layout/Extra") if dialog != null else null
	_check(dialog != null and dialog.get_node("Dim/Center/Panel/Margin/Layout/Buttons/Confirm").text == "We have lost", "ending the fight asks whether it is lost")
	_check(extra != null and extra.visible and extra.text == "Stop the fight", "or is to be stopped")
	dialog.get_node("Dim/Center/Panel/Margin/Layout/Buttons/Cancel").pressed.emit()
	await get_tree().create_timer(MenuScreen.FADE_SEC + 0.1).timeout
	_check(_next == null and not screen.has_node("GiveUpDialog"), "keep fighting closes the question and stays")

	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().process_frame
	_check(screen.has_node("GiveUpDialog"), "the back button of a phone asks to give up, too")
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await get_tree().create_timer(MenuScreen.FADE_SEC + 0.1).timeout
	_check(_next == null and not screen.has_node("GiveUpDialog"), "pressing it again only closes the question")

	screen.go_back()
	await get_tree().process_frame
	screen.get_node("GiveUpDialog/Dim/Center/Panel/Margin/Layout/Extra").pressed.emit()
	var deadline := Time.get_ticks_msec() + 2000
	while _next == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(_next != null and _next.scene_file_path == "res://game_over.tscn", "stopping the fight leads to the game over screen")
	_check(_next != null and _next.fight == screen.fight and screen.fight.stats.outcome == FightStats.Outcome.ABORTED, "with the fight, stopped")
	if _next != null:
		_next.free()
	screen.queue_free()
	await get_tree().process_frame
	_check(get_tree().quit_on_go_back, "the back button of a phone quits again elsewhere")


## A fallen hero: the players say they have lost, read so, and the game is over.
func _check_defeat() -> void:
	var screen := await _open()
	var box: MessageBox = screen.messages
	screen.go_back()
	await get_tree().process_frame
	screen.get_node("GiveUpDialog/Dim/Center/Panel/Margin/Layout/Buttons/Confirm").pressed.emit()
	_check(screen.fight.stats.outcome == FightStats.Outcome.LOST and box.queue.back()[0] == "defeat", "we have lost ends the fight as lost, and says so")
	await get_tree().process_frame
	_check(_next == null, "the players read it first")
	var deadline := Time.get_ticks_msec() + 10000
	while _next == null and Time.get_ticks_msec() < deadline:
		await _confirm(box)
	_check(_next != null and _next.scene_file_path == "res://game_over.tscn" and _next.fight.stats.outcome == FightStats.Outcome.LOST, "then the game is over")
	if _next != null:
		_next.free()
	screen.queue_free()


func _check_game_over() -> void:
	var heroes: Array[Party.Hero] = []
	for entry: Array in [["Sonja", "dryad", "druid", 1], ["Borin", "dwarf", "warrior", 3]]:
		var hero := Party.Hero.new()
		hero.name = entry[0]
		hero.race = entry[1]
		hero.hero_class = entry[2]
		hero.seat = entry[3]
		heroes.append(hero)
	var fight := Fight.new(Bosses.create("mirefang"), "normal", heroes)
	var sonja := fight.heroes[0]
	var borin := fight.heroes[1]
	fight.stats.round_started(1)
	fight.stats.damage_dealt(9, 2, CardPlay.new(borin, Card.new()))
	fight.stats.damage_dealt(4, 0, CardPlay.new(sonja, Card.new()))
	fight.stats.protected(sonja, 3)
	fight.stats.attack_planned(sonja, 3)
	fight.stats.attack_resolved(sonja, 0)
	fight.stats.attack_planned(borin, 4)
	fight.stats.attack_resolved(borin, 4)
	fight.stats.hero_hit(borin, 4, 1)
	fight.stats.round_ended(fight.max_health - 13)
	fight.stats.finished(FightStats.Outcome.WON, fight.max_health - 13)

	await get_tree().process_frame
	_next = null
	var screen: MenuScreen = load("res://game_over.tscn").instantiate()
	screen.fight = fight
	screen.change_scene = func(next: Node) -> void: _next = next
	add_child(screen)
	await get_tree().process_frame
	_check(screen.get_node("Margin/Layout/Header/Title").text == "Victory!", "the game over screen shows how the fight ended")
	_check(screen.get_node("Margin/Layout/Header/Subtitle").text.contains("Mirefang"), "against whom")
	_check(screen.awards.get(borin, {}).get("stat") == "damage" and screen.awards.get(sonja, {}).get("stat") == "protection", "the heroes earn titles for what they did most")
	screen.get_node("Margin/Layout/Continue").pressed.emit()
	await get_tree().create_timer(MenuScreen.FADE_SEC + 0.1).timeout
	_check(_next == null, "a tap right away does not skip it")
	await get_tree().create_timer(2.5).timeout
	var tiles := screen.get_node("Margin/Layout/Tiles")
	var values := []
	for tile in tiles.get_children():
		values.append((tile.find_child("Value", true, false) as Label).text)
	_check(values == ["1", "13", "4", "1/2"], "the team's numbers count up: rounds, damage dealt and taken, attacks blocked")
	screen.get_node("Margin/Layout/Continue").pressed.emit()
	var deadline := Time.get_ticks_msec() + 2000
	while _next == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(_next != null and _next.scene_file_path == "res://onboarding.tscn", "the button leads back to the table")
	if _next != null:
		_next.free()
	screen.queue_free()

	for outcome: Array in [[FightStats.Outcome.LOST, "Defeat"], [FightStats.Outcome.ABORTED, "Retreat"]]:
		var other := Fight.new(Bosses.create("mirefang"), "normal", heroes)
		other.stats.finished(outcome[0], other.max_health)
		var shown: Control = load("res://game_over.tscn").instantiate()
		shown.fight = other
		add_child(shown)
		_check(shown.get_node("Margin/Layout/Header/Title").text == outcome[1], "a fight %s shows as such" % outcome[1].to_lower())
		shown.free()


func _open() -> MenuScreen:
	await get_tree().process_frame
	_next = null
	var screen: MenuScreen = load("res://boss_fight.tscn").instantiate()
	screen.party_path = PARTY_PATH
	screen.cards_path = CARDS_PATH
	screen.change_scene = func(next: Node) -> void: _next = next
	add_child(screen)
	await get_tree().process_frame
	return screen


func _check(condition: bool, description: String) -> void:
	_checks_run += 1
	print(("  ok   " if condition else "  FAIL ") + description)
	if not condition:
		_failures += 1
