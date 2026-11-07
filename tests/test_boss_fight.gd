extends Node
## The boss fight screen: what it shows, how the players take part in the fight, and
## ending it, and the game over screen. The rules themselves are tested in test_fight.gd.
## Runs as a scene, because it needs the autoloads:
## godot --headless res://tests/test_boss_fight.tscn

const PARTY_PATH := "user://test_boss_fight_party.json"
const SETTINGS_PATH := "user://test_boss_fight_settings.cfg"
const CARDS_PATH := "res://tests/fixtures/fight_cards.json"
const EXPECTED_CHECKS := 69

var _failures := 0
var _checks_run := 0
var _next: Node


func _ready() -> void:
	Settings.load_file(SETTINGS_PATH)
	TranslationServer.set_locale("en")
	_check_fight_state()
	await _check_screen()
	await _check_messages()
	await _check_round()
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
	_check(boss.calls[-1] == "round_started 1" and told[-1] == "round_started 1", "then round 1 is announced, and the boss told")
	fight.deal_damage(5, "melee")
	_check(fight.health == 15, "an attack takes off health")
	fight.deal_damage(5, "magic")
	_check(fight.health == 15, "the boss decides how much an attack hurts")
	fight.deal_damage(100, "melee")
	_check(fight.health == 0 and won[0], "health stops at 0, which wins the fight")

	var colossus := Fight.new(Bosses.create("colossus"), "normal")
	colossus.deal_damage(9, "melee")
	_check(colossus.health == colossus.max_health - 4, "the colossus's armour halves attacks")

	var bosses_differ := Bosses.create("ashwing") != Bosses.create("ashwing")
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
	_check(figure_material.get_shader_parameter("breathe") == boss.motion_amount, "and moves as it says")
	_check((screen.get_node("Ambience") as CPUParticles2D).color_ramp.get_color(1).r == boss.ambience_color.r, "with its own particles")
	_check(screen.get_node("Hud/Round/Row/Value").text == "1", "the fight starts in round 1")
	_check(screen.get_node("Hud/Health/Row/Value").text == "0", "the boss's health counts up")
	await get_tree().create_timer(screen.HEALTH_COUNT_SEC + 0.6).timeout
	_check(screen.get_node("Hud/Health/Row/Value").text == str(boss.max_health("hard")), "to its full health")
	var shown := []
	for token: SeatToken in screen.get_node("Seats").get_children():
		if token.visible:
			shown.append(token.seat)
	_check(shown == [1, 3], "only seats with a hero show")
	_check(screen.get_node("Banner/Text").text == "Old Mirefang", "the boss's name is announced")
	_check(not get_tree().quit_on_go_back, "the back button of a phone does not quit the app")

	screen.fight.deal_damage(7, "magic")
	_check(screen.get_node("Hud/Health/Row/Value").text == str(boss.max_health("hard") - 7), "the health shown follows the fight")
	_check(not screen.get_node("Hud/Poison").visible, "the boss's poison only shows once it has some")
	screen.fight.poison_boss(2)
	_check(screen.get_node("Hud/Poison").visible and screen.get_node("Hud/Poison/Row/Value").text == "2", "then how much")
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
	_check(box.visible and layout.get_node("Title").text == "[center]Old Mirefang[/center]", "then its words show")
	_check(layout.get_node("Body").get_parsed_text().contains("hundred years"), "in its own words")
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
	_check(not layout.get_node("Title").visible and box.visible, "a message without a title shows only its body")
	confirm.pressed.emit()
	await get_tree().create_timer(MessageBox.FADE_SEC + 0.1).timeout
	_check(confirmed == ["boss_taunt", "example_magic_potion", "example_reminder"] and all_confirmed[0], "each message is confirmed in turn")
	_check(box.current() == "round_started", "and once all are read, the fight goes on")
	screen.queue_free()


## A round as the players see it: choosing who starts, the phases, and playing cards.
func _check_round() -> void:
	Encounter.boss = "ashwing"
	Encounter.difficulty = "normal"
	var screen := await _open()
	var box: MessageBox = screen.messages
	var tokens := {}
	for token: SeatToken in screen.get_node("Seats").get_children():
		tokens[token.seat] = token
	await get_tree().create_timer(screen.INTRO_SEC).timeout
	await _confirm(box)
	_check(box.current() == "round_started", "after the boss's words, the round begins")
	await _confirm(box)
	_check(box.current() == "phase_planning", "the boss plans its attacks")
	var badge: Control = tokens[1].get_node("Badge")
	_check(badge.visible and badge.get_node("Row/Threat/Value").text == str(screen.fight.hero_at(1).threat), "each hero sees the attack against them")
	await _confirm(box)
	await get_tree().create_timer(MessageBox.FADE_SEC + 0.1).timeout
	var prompt: Control = screen.get_node("Prompt")
	_check(prompt.visible and tokens[1].mode == SeatToken.Mode.SELECTABLE and tokens[3].mode == SeatToken.Mode.SELECTABLE, "then the players are asked who starts")
	tokens[3].pressed.emit()
	await get_tree().process_frame
	_check(screen.fight.starter.name == "Borin", "tapping a hero chooses them")
	var shield: Label = screen.get_node("Shields").get_child(0).get_node("Row/Value")
	_check(box.current() == "phase_action" and not box.visible and shield.text == "0", "the boss's shields rise, and the next message waits")
	await get_tree().create_timer(1.6).timeout
	_check(shield.text == "2", "they count up to the shields the boss raised")
	_check(box.current() == "phase_action" and box.visible, "then the action phase begins")
	await _confirm(box)
	await get_tree().create_timer(MessageBox.FADE_SEC + 0.1).timeout
	var text: RichTextLabel = screen.get_node("Prompt/Layout/Text")
	_check(prompt.visible and text.get_parsed_text().contains("Borin") and tokens[3].mode == SeatToken.Mode.ACTIVE, "the chosen hero is asked for a card")
	var spheres: ActionSpheres = tokens[3].get_node("Badge/Row/Actions")
	_check(spheres.visible and spheres.actions().size() == 3, "each hero sees the actions they have left")

	var health: int = screen.fight.health
	screen._on_code_read("AXE", PackedVector2Array(), Vector2i())
	_check(screen.fight.health == health - 2 and screen.get_node("Hud/Health/Row/Value").text == str(health - 2), "a card shown to the camera is played")
	_check(text.get_parsed_text().contains("Sonja") and tokens[1].mode == SeatToken.Mode.ACTIVE, "then it is the next hero's turn")
	screen._on_code_read("AXE", PackedVector2Array(), Vector2i())
	_check(not screen.get_node("Prompt/Layout/Notice").visible, "a card still in view does not count again")
	screen._on_code_read("NOPE", PackedVector2Array(), Vector2i())
	_check(screen.get_node("Prompt/Layout/Notice").visible, "an unknown card is pointed out")
	var pass_button: Button = screen.get_node("Prompt/Layout/Buttons").get_child(0)
	_check(pass_button.text == "Pass", "a hero can pass")
	pass_button.pressed.emit()
	_check(text.get_parsed_text().contains("Borin"), "which ends their turn")
	screen.queue_free()


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
	var fight := Fight.new(Bosses.create("ashwing"), "normal", heroes)
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
	_check(screen.get_node("Margin/Layout/Header/Subtitle").text.contains("Ashwing"), "against whom")
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
		var other := Fight.new(Bosses.create("ashwing"), "normal", heroes)
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
