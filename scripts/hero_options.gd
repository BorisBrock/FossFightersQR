class_name HeroOptions
extends RefCounted
## What players can choose from during onboarding. Character and class cards point to
## these ids through their "race" and "hero_class" fields, see cards/cards.schema.json.
##
## "health" and "hand" are printed on the level 1 character and class cards, which the
## catalog does not have: a hero's start health and hand limit are the sums of their
## character's and class's.

const RACES := {
	"halfling": {
		"health": 15,
		"hand": 6,
		"title": { "de": "Hügel-Halbling", "en": "Halfling" },
		"art": "res://assets/onboarding/portraits/CharacterHalfling.png",
		"names": ["Rosie", "Bilwin", "Tilda", "Odo", "Fenna", "Wim"],
	},
	"dwarf": {
		"health": 19,
		"hand": 5,
		"title": { "de": "Kupfer-Zwerg", "en": "Dwarf" },
		"art": "res://assets/onboarding/portraits/CharacterDwarf.png",
		"names": ["Brogan", "Durgrim", "Helga", "Borin", "Gunnhild", "Kazrik"],
	},
	"elf": {
		"health": 14,
		"hand": 5,
		"title": { "de": "Wald-Elfe", "en": "Elf" },
		"art": "res://assets/onboarding/portraits/CharacterElb.png",
		"names": ["Elaria", "Thalion", "Sylwen", "Aerin", "Lorien", "Faelar"],
	},
	"troll": {
		"health": 22,
		"hand": 4,
		"title": { "de": "Dschungel-Troll", "en": "Troll" },
		"art": "res://assets/onboarding/portraits/CharacterTroll.png",
		"names": ["Grumbold", "Ugra", "Morgrim", "Krag", "Brumma", "Zottel"],
	},
	"goblin": {
		"health": 19,
		"hand": 5,
		"title": { "de": "Goblin-Tüftler", "en": "Goblin Inventor" },
		"art": "res://assets/onboarding/portraits/CharacterGoblin.png",
		"names": ["Fizzwick", "Zündi", "Sprocket", "Nixie", "Klonk", "Gizmo"],
	},
	"dryad": {
		"health": 22,
		"hand": 4,
		"title": { "de": "Dryaden-Hüterin", "en": "Forest Dryad" },
		"art": "res://assets/onboarding/portraits/CharacterDryad.png",
		# Her portrait while she has taken a form (FightHero.form).
		"forms": {
			"thorn": "res://assets/onboarding/portraits/CharacterDryadThorn.png",
			"blossom": "res://assets/onboarding/portraits/CharacterDryadBlossom.png",
			"bark": "res://assets/onboarding/portraits/CharacterDryadBark.png",
		},
		"names": ["Ivy", "Birka", "Fernwen", "Salvia", "Eschia", "Moosine"],
	},
}

const CLASSES := {
	"paladin": {
		"health": 15,
		"hand": 1,
		"title": { "de": "Paladin", "en": "Paladin" },
		"art": "res://assets/onboarding/crests/ClassPaladin.png",
	},
	"magician": {
		"health": 11,
		"hand": 2,
		"title": { "de": "Magier", "en": "Magician" },
		"art": "res://assets/onboarding/crests/ClassMagician.png",
	},
	"warrior": {
		"health": 15,
		"hand": 1,
		"title": { "de": "Krieger", "en": "Warrior" },
		"art": "res://assets/onboarding/crests/ClassWarrior.png",
	},
	"thief": {
		"health": 10,
		"hand": 1,
		"title": { "de": "Schurke", "en": "Thief" },
		"art": "res://assets/onboarding/crests/ClassThief.png",
	},
	"druid": {
		"health": 11,
		"hand": 2,
		"title": { "de": "Druide", "en": "Druid" },
		"art": "res://assets/onboarding/crests/ClassDruid.png",
	},
	"shaman": {
		"health": 11,
		"hand": 2,
		"title": { "de": "Schamane", "en": "Shaman" },
		"art": "res://assets/onboarding/crests/ClassShaman.png",
	},
}


## A hero's hand limit, from their character and class (level 1, see above), or 0 for
## an unknown one.
static func hand_limit(race: String, hero_class: String) -> int:
	if not RACES.has(race) or not CLASSES.has(hero_class):
		return 0
	return RACES[race].hand + CLASSES[hero_class].hand


## A name for this race that is not in taken, or an empty string if none is left.
static func suggest_name(race: String, taken: PackedStringArray) -> String:
	var names: Array = RACES[race].names.duplicate()
	names.shuffle()
	for candidate: String in names:
		if not taken.has(candidate):
			return candidate
	return ""
