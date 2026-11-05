extends SceneTree
## Saving and loading the party.
## Run with: godot --headless -s tests/test_party.gd

const PATH := "user://test_party.json"
const EXPECTED_CHECKS := 18

var _failures := 0
var _checks_run := 0


func _initialize() -> void:
	_check_round_trip()
	_check_damaged_files()
	_check_options()
	DirAccess.remove_absolute(PATH)
	_check(_checks_run == EXPECTED_CHECKS - 1, "all checks ran")
	print("test_party: %s" % ("PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _check_round_trip() -> void:
	DirAccess.remove_absolute(PATH)
	_check(Party.load_file(PATH).heroes.is_empty(), "no file gives an empty party")
	var party := Party.new(PATH)
	party.heroes.append(_hero("Brogan", "dwarf", "thief", 3))
	party.heroes.append(_hero("Grüße", "elf", "druid", 6))
	_check(party.save(), "saves")
	_check(not FileAccess.file_exists(PATH + ".tmp"), "leaves no temporary file")
	var loaded := Party.load_file(PATH)
	_check(loaded.heroes.size() == 2, "loads both heroes")
	var hero := loaded.hero_at(6)
	_check(hero != null and hero.name == "Grüße" and hero.race == "elf" and hero.hero_class == "druid", "keeps what they chose")
	_check(typeof(hero.seat) == TYPE_INT and loaded.hero_at(0) == null, "seat is a whole number and other seats are free")
	_check(loaded.party_name.is_empty(), "a party starts without a name")
	party.party_name = "Furious Four"
	party.save()
	_check(Party.load_file(PATH).party_name == "Furious Four", "keeps the name of the party")


func _check_damaged_files() -> void:
	_write("{ not json")
	_check(Party.load_file(PATH).heroes.is_empty(), "damaged file gives an empty party")
	_write(JSON.stringify({ "version": 99, "heroes": [] }))
	_check(Party.load_file(PATH).heroes.is_empty(), "another version gives an empty party")
	var good := { "name": "A", "race": "dwarf", "hero_class": "thief", "seat": 0 }
	var bad_ones: Array = [
		"text",
		{ "name": "", "race": "dwarf", "hero_class": "thief", "seat": 1 },
		{ "name": "B", "race": "robot", "hero_class": "thief", "seat": 1 },
		{ "name": "B", "race": "dwarf", "hero_class": "robot", "seat": 1 },
		{ "name": "B", "race": "dwarf", "hero_class": "thief", "seat": Party.SEAT_COUNT },
		{ "name": "B", "race": "dwarf", "hero_class": "thief", "seat": 1.5 },
		{ "name": "B", "race": "elf", "hero_class": "druid", "seat": 0 },
		{ "name": "B", "race": "dwarf", "hero_class": "druid", "seat": 1 },
		{ "name": "B", "race": "elf", "hero_class": "thief", "seat": 1 },
	]
	_write(JSON.stringify({ "version": Party.SAVE_VERSION, "heroes": [good] + bad_ones }))
	var loaded := Party.load_file(PATH)
	_check(loaded.heroes.size() == 1 and loaded.heroes[0].name == "A", "skips bad heroes and shared seats, races and classes, keeps the good one")
	var crowd := []
	for i in HeroOptions.RACES.size():
		crowd.append({ "name": "H%d" % i, "race": HeroOptions.RACES.keys()[i], "hero_class": HeroOptions.CLASSES.keys()[i], "seat": i })
	_write(JSON.stringify({ "version": Party.SAVE_VERSION, "heroes": crowd }))
	_check(Party.load_file(PATH).heroes.size() == Party.MAX_HEROES, "keeps no more than the allowed heroes")
	_write(JSON.stringify({ "version": Party.SAVE_VERSION, "heroes": [good] }))
	loaded = Party.load_file(PATH)
	_check(loaded.party_name.is_empty() and loaded.heroes.size() == 1, "a file from before party names still loads")
	_write(JSON.stringify({ "version": Party.SAVE_VERSION, "name": "  %s  " % "x".repeat(99), "heroes": [good] }))
	_check(Party.load_file(PATH).party_name == "x".repeat(Party.MAX_PARTY_NAME_LENGTH), "trims a saved party name that is too long")


func _check_options() -> void:
	var party := Party.new(PATH)
	var dwarf := _hero("A", "dwarf", "thief", 0)
	party.heroes.append(dwarf)
	_check(party.hero_with_race("dwarf") == dwarf and party.hero_with_race("dwarf", dwarf) == null and party.hero_with_class("druid") == null, "finds who has a race or class, leaving out one hero")
	_check(HeroOptions.suggest_name("dwarf", PackedStringArray()) in HeroOptions.RACES.dwarf.names, "suggests a name of the race")
	var all_taken := PackedStringArray(HeroOptions.RACES.dwarf.names)
	_check(HeroOptions.suggest_name("dwarf", all_taken).is_empty(), "suggests nothing when all names are taken")


func _hero(hero_name: String, race: String, hero_class: String, seat: int) -> Party.Hero:
	var hero := Party.Hero.new()
	hero.name = hero_name
	hero.race = race
	hero.hero_class = hero_class
	hero.seat = seat
	return hero


func _write(text: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _check(condition: bool, description: String) -> void:
	_checks_run += 1
	print(("  ok   " if condition else "  FAIL ") + description)
	if not condition:
		_failures += 1
