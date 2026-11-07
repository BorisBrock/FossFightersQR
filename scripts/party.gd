class_name Party
extends RefCounted
## The heroes at the table, kept between runs in a small JSON file.

const SAVE_PATH := "user://party.json"
const SAVE_VERSION := 1
const MAX_HEROES := 4
## Seats run clockwise around the table as seen on the screen: 0 to 2 down the right side,
## 3 at the table head at the bottom, 4 to 6 up the left side.
const SEAT_COUNT := 7
const MAX_NAME_LENGTH := 16
const MAX_PARTY_NAME_LENGTH := 24


class Hero:
	var name := ""
	var race := ""
	var hero_class := ""
	## -1 until the player has chosen a seat.
	var seat := -1
	## The QR codes of the character and class card shown for them, which say their
	## level. Empty if they were chosen without one, which is the first level.
	var race_card := ""
	var class_card := ""

	func copy_from(other: Hero) -> void:
		name = other.name
		race = other.race
		hero_class = other.hero_class
		seat = other.seat
		race_card = other.race_card
		class_card = other.class_card


## What the group calls itself. Empty until they have chosen one.
var party_name := ""
var heroes: Array[Hero] = []
var _path: String


func _init(path := SAVE_PATH) -> void:
	_path = path


## Returns the party saved at this path. A missing or damaged file gives an empty party
## or one without the damaged heroes, as the players can simply choose again.
static func load_file(path := SAVE_PATH) -> Party:
	var party := Party.new(path)
	if not FileAccess.file_exists(path):
		return party
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("Ignoring the damaged party file: ", json.get_error_message())
		return party
	var document: Variant = json.data
	if not document is Dictionary or document.get("version") != SAVE_VERSION or not document.get("heroes") is Array:
		return party
	# Files from before parties had names do not have this.
	var name_value: Variant = document.get("name")
	if name_value is String:
		party.party_name = name_value.strip_edges().left(MAX_PARTY_NAME_LENGTH)
	for entry: Variant in document.heroes:
		var hero := _hero_from_data(entry)
		if hero != null and party.heroes.size() < MAX_HEROES and party._has_room_for(hero):
			party.heroes.append(hero)
	return party


func save() -> bool:
	var entries := []
	for hero in heroes:
		entries.append({ "name": hero.name, "race": hero.race, "hero_class": hero.hero_class, "seat": hero.seat,
			"race_card": hero.race_card, "class_card": hero.class_card })
	# Written to the side first, so that a crash cannot leave half a file behind.
	var temporary := _path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_error("Cannot save the party: ", error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify({ "version": SAVE_VERSION, "name": party_name, "heroes": entries }, "\t"))
	file.close()
	var result := DirAccess.rename_absolute(temporary, _path)
	if result != OK:
		push_error("Cannot save the party: ", error_string(result))
	return result == OK


func hero_at(seat: int) -> Hero:
	for hero in heroes:
		if hero.seat == seat:
			return hero
	return null


## The hero who has this race, leaving out except. Each race can only be picked once.
func hero_with_race(race: String, except: Hero = null) -> Hero:
	for hero in heroes:
		if hero != except and hero.race == race:
			return hero
	return null


## The hero who has this class, leaving out except. Each class can only be picked once.
func hero_with_class(hero_class: String, except: Hero = null) -> Hero:
	for hero in heroes:
		if hero != except and hero.hero_class == hero_class:
			return hero
	return null


func _has_room_for(hero: Hero) -> bool:
	return hero_at(hero.seat) == null and hero_with_race(hero.race) == null and hero_with_class(hero.hero_class) == null


func names() -> PackedStringArray:
	var result := PackedStringArray()
	for hero in heroes:
		result.append(hero.name)
	return result


static func _hero_from_data(data: Variant) -> Hero:
	if not data is Dictionary:
		return null
	var name_value: Variant = data.get("name")
	var race_value: Variant = data.get("race")
	var class_value: Variant = data.get("hero_class")
	var seat_value: Variant = data.get("seat")
	if not name_value is String or name_value.strip_edges().is_empty():
		return null
	if not HeroOptions.RACES.has(race_value) or not HeroOptions.CLASSES.has(class_value):
		return null
	# Godot's JSON parser returns every number as a float.
	if not seat_value is float or seat_value != floor(seat_value) or seat_value < 0 or seat_value >= SEAT_COUNT:
		return null
	var hero := Hero.new()
	hero.name = name_value.strip_edges().left(MAX_NAME_LENGTH)
	hero.race = race_value
	hero.hero_class = class_value
	hero.seat = int(seat_value)
	# Files from before levels were kept do not have these.
	var race_card_value: Variant = data.get("race_card", "")
	var class_card_value: Variant = data.get("class_card", "")
	hero.race_card = race_card_value if race_card_value is String else ""
	hero.class_card = class_card_value if class_card_value is String else ""
	return hero
