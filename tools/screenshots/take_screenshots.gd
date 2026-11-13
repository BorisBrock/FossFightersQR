extends Node
## Takes the screenshots for the README, with a made-up party, from the real scenes.
## Needs a window, like the GUI tests:
## godot --disable-vsync res://tools/screenshots/take_screenshots.tscn
## Writes JPEGs to docs/screenshots/, which the README shows. JPEG keeps them small: the
## same shots as PNG are over 2 MB each.

const PARTY_PATH := "user://screenshots_party.json"
const SETTINGS_PATH := "user://screenshots_settings.cfg"
const OUT_DIR := "res://docs/screenshots/"
const JPEG_QUALITY := 0.85
const SIZE := Vector2i(1080, 1920)
const NOTHING := "res://tests/fixtures/no_code.png"
## Feuerball, a magician's card with a magic attack.
const FIREBALL := "QQAAAA=="
const HEROES := [
	["Sonja", "dryad", "druid", 1],
	["Borin", "dwarf", "warrior", 3],
	["Lirael", "elf", "magician", 5],
	["Pippa", "halfling", "thief", 6],
]

var _feed: FakeCameraFeed


func _ready() -> void:
	Settings.load_file(SETTINGS_PATH)
	AudioServer.set_bus_mute(0, true)
	TranslationServer.set_locale("en")
	get_window().size = SIZE
	# Never the real webcam: debug builds show its picture in the editor.
	_feed = FakeCameraFeed.new("Fake front camera", CameraFeed.FEED_FRONT)
	_feed.show_image(NOTHING)
	CameraServer.add_feed(_feed)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save_party()
	await _onboarding()
	await _fight()
	await _game_over()
	CameraServer.remove_feed(_feed)
	DirAccess.remove_absolute(PARTY_PATH)
	DirAccess.remove_absolute(SETTINGS_PATH)
	get_tree().quit()


func _onboarding() -> void:
	var scene: Node = load("res://onboarding.tscn").instantiate()
	scene.party_path = PARTY_PATH
	scene.show_splash = false
	add_child(scene)
	await _wait(3.0)
	await _shot("onboarding_party")

	scene._start_editing(scene._party.heroes[0])
	await _wait(1.5)
	await _shot("onboarding_editor")
	scene._cancel_editing()
	await _wait(1.0)

	scene._to_bosses()
	await _wait(2.5)
	scene._show_boss("mirefang")
	await _wait(2.5)
	await _shot("boss_overview")
	scene.queue_free()
	await _wait(0.2)


func _fight() -> void:
	Encounter.boss = "mirefang"
	Encounter.difficulty = "normal"
	var screen: Node = load("res://boss_fight.tscn").instantiate()
	screen.party_path = PARTY_PATH
	screen.change_scene = func(next: Node) -> void: next.free()
	add_child(screen)
	screen.fight.rng.seed = 7
	await _wait(2.2)

	# Through the messages to the question who starts, with the attacks and shields shown.
	var box: MessageBox = screen.messages
	var deadline := Time.get_ticks_msec() + 30000
	while screen.fight.request == null and Time.get_ticks_msec() < deadline:
		if box.is_showing():
			var confirm: Button = box.get_node("Margin/Panel/Margin/Layout/Confirm")
			if confirm.visible and not confirm.disabled:
				confirm.pressed.emit()
		await _wait(0.2)
	await _wait(1.5)
	await _shot("fight_planning")

	var lirael: FightHero = screen.fight.heroes.filter(func(h: FightHero) -> bool: return h.name == "Lirael")[0]
	screen.fight.choose(lirael)
	await _wait(1.5)
	screen.scan_code(FIREBALL)
	# The bolts hit the boss in their coloured rings, under the card's name.
	await _wait(1.5)
	await _shot("fight_attack")
	await _wait(6.0)
	screen.queue_free()
	await _wait(0.2)


func _game_over() -> void:
	var party := Party.load_file(PARTY_PATH)
	var fight := Fight.new(Bosses.create("mirefang"), "normal", party.heroes)
	var stats := fight.stats
	var by_name := {}
	for hero in fight.heroes:
		by_name[hero.name] = hero
	var damage := { "Sonja": 18, "Borin": 34, "Lirael": 41, "Pippa": 27 }
	var health := fight.max_health
	for round_number in range(1, 6):
		stats.round_started(round_number)
		for hero_name: String in damage:
			var hero: FightHero = by_name[hero_name]
			var dealt: int = mini(damage[hero_name] / 5 + (1 if round_number <= damage[hero_name] % 5 else 0), health)
			if dealt > 0:
				stats.damage_dealt(dealt, 0, CardPlay.new(hero, Card.new()))
				health -= dealt
			stats.attack_planned(hero, 3)
			var blocked := 3 if hero_name == "Sonja" or round_number % 2 == 0 else 1
			stats.protected(hero, blocked)
			stats.attack_resolved(hero, 3 - blocked)
			if blocked < 3:
				stats.hero_hit(hero, 3 - blocked, 0)
		stats.round_ended(health)
	stats.finished(FightStats.Outcome.WON, 0)
	var screen: Node = load("res://game_over.tscn").instantiate()
	screen.fight = fight
	screen.change_scene = func(next: Node) -> void: next.free()
	add_child(screen)
	await _wait(4.0)
	await _shot("victory")
	screen.queue_free()


func _save_party() -> void:
	var party := Party.new(PARTY_PATH)
	party.party_name = "The Mud Raiders"
	for entry: Array in HEROES:
		var hero := Party.Hero.new()
		hero.name = entry[0]
		hero.race = entry[1]
		hero.hero_class = entry[2]
		hero.seat = entry[3]
		party.heroes.append(hero)
	party.save()


func _process(_delta: float) -> void:
	if _feed:
		_feed.deliver_frame()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_jpg(ProjectSettings.globalize_path(OUT_DIR + shot_name + ".jpg"), JPEG_QUALITY)
	print("%s: %s" % [shot_name, image.get_size()])
