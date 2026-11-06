extends Node
## The boss fight: what it shows, the hooks for a boss's own rules, and giving up.
## Runs as a scene, because it needs the autoloads:
## godot --headless res://tests/test_boss_fight.tscn

const PARTY_PATH := "user://test_boss_fight_party.json"
const SETTINGS_PATH := "user://test_boss_fight_settings.cfg"
const EXPECTED_CHECKS := 27

var _failures := 0
var _checks_run := 0
var _next: Node


func _ready() -> void:
	Settings.load_file(SETTINGS_PATH)
	TranslationServer.set_locale("en")
	_check_fight_state()
	await _check_screen()
	await _check_give_up()
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

	func damage_taken(_fight: Fight, amount: int, kind: String) -> int:
		return 0 if kind == "fire" else amount


func _check_fight_state() -> void:
	var boss := TestBoss.new()
	_check(boss.max_health("easy") == 15 and boss.max_health("normal") == 20 and boss.max_health("hard") == 25, "the difficulty scales the boss's health")
	var fight := Fight.new(boss, "normal")
	var won := [false]
	fight.won.connect(func() -> void: won[0] = true)
	fight.start()
	_check(boss.calls == ["fight_started", "round_started 1"], "a fight starts in round 1 and tells the boss")
	fight.next_round()
	_check(fight.round_number == 2 and boss.calls[-1] == "round_started 2", "each round tells the boss")
	fight.attack(5)
	_check(fight.health == 15, "an attack takes off health")
	fight.attack(5, "fire")
	_check(fight.health == 15, "the boss decides how much an attack hurts")
	fight.attack(100)
	_check(fight.health == 0 and won[0], "health stops at 0, which wins the fight")

	var colossus := Fight.new(Bosses.create("colossus"), "normal")
	colossus.attack(9)
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
	_check(screen.get_node("Hud/Health/Row/Value").text == str(boss.max_health("hard")), "with the boss's full health")
	var shown := []
	for token: SeatToken in screen.get_node("Seats").get_children():
		if token.visible:
			shown.append(token.seat)
	_check(shown == [1, 3], "only seats with a hero show")
	_check(screen.get_node("Banner/Text").text == "Old Mirefang", "the boss's name is announced")
	_check(not get_tree().quit_on_go_back, "the back button of a phone does not quit the app")

	screen.fight.attack(7)
	_check(screen.get_node("Hud/Health/Row/Value").text == str(boss.max_health("hard") - 7), "the health shown follows the fight")
	screen.fight.next_round()
	_check(screen.get_node("Hud/Round/Row/Value").text == "2", "and so does the round")
	screen.queue_free()


func _check_give_up() -> void:
	var screen := await _open()
	screen.get_node("Hud/GiveUp/Button").pressed.emit()
	await get_tree().process_frame
	var dialog: ConfirmDialog = screen.get_node_or_null("GiveUpDialog")
	_check(dialog != null and dialog.get_node("Dim/Center/Panel/Margin/Layout/Buttons/Confirm").text == "Give up", "giving up asks first")
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
	screen.get_node("GiveUpDialog/Dim/Center/Panel/Margin/Layout/Buttons/Confirm").pressed.emit()
	var deadline := Time.get_ticks_msec() + 2000
	while _next == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(_next != null and _next.scene_file_path == "res://boss_selection.tscn", "giving up leads to the boss list")
	if _next != null:
		_next.free()
	screen.queue_free()
	await get_tree().process_frame
	_check(get_tree().quit_on_go_back, "the back button of a phone quits again elsewhere")


func _open() -> MenuScreen:
	await get_tree().process_frame
	_next = null
	var screen: MenuScreen = load("res://boss_fight.tscn").instantiate()
	screen.party_path = PARTY_PATH
	screen.change_scene = func(next: Node) -> void: _next = next
	add_child(screen)
	await get_tree().process_frame
	return screen


func _check(condition: bool, description: String) -> void:
	_checks_run += 1
	print(("  ok   " if condition else "  FAIL ") + description)
	if not condition:
		_failures += 1
