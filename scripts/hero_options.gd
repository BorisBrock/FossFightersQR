class_name HeroOptions
extends RefCounted
## What players can choose from during onboarding. Character and class cards point to
## these ids through their "race" and "hero_class" fields, see cards/cards.schema.json.

const RACES := {
	"halfling": {
		"title": { "de": "Hügel-Halbling", "en": "Halfling" },
		"art": "res://assets/onboarding/portraits/CharacterHalfling.png",
		"names": ["Rosie", "Bilwin", "Tilda", "Odo", "Fenna", "Wim"],
	},
	"dwarf": {
		"title": { "de": "Kupfer-Zwerg", "en": "Dwarf" },
		"art": "res://assets/onboarding/portraits/CharacterDwarf.png",
		"names": ["Brogan", "Durgrim", "Helga", "Borin", "Gunnhild", "Kazrik"],
	},
	"elf": {
		"title": { "de": "Wald-Elfe", "en": "Elf" },
		"art": "res://assets/onboarding/portraits/CharacterElb.png",
		"names": ["Elaria", "Thalion", "Sylwen", "Aerin", "Lorien", "Faelar"],
	},
	"troll": {
		"title": { "de": "Dschungel-Troll", "en": "Troll" },
		"art": "res://assets/onboarding/portraits/CharacterTroll.png",
		"names": ["Grumbold", "Ugra", "Morgrim", "Krag", "Brumma", "Zottel"],
	},
	"goblin": {
		"title": { "de": "Goblin-Tüftler", "en": "Goblin Inventor" },
		"art": "res://assets/onboarding/portraits/CharacterGoblin.png",
		"names": ["Fizzwick", "Zündi", "Sprocket", "Nixie", "Klonk", "Gizmo"],
	},
	"dryad": {
		"title": { "de": "Dryaden-Hüterin", "en": "Forest Dryad" },
		"art": "res://assets/onboarding/portraits/CharacterDryad.png",
		"names": ["Ivy", "Birka", "Fernwen", "Salvia", "Eschia", "Moosine"],
	},
}

const CLASSES := {
	"paladin": {
		"title": { "de": "Paladin", "en": "Paladin" },
		"art": "res://assets/onboarding/crests/ClassPaladin.png",
	},
	"magician": {
		"title": { "de": "Magier", "en": "Magician" },
		"art": "res://assets/onboarding/crests/ClassMagician.png",
	},
	"warrior": {
		"title": { "de": "Krieger", "en": "Warrior" },
		"art": "res://assets/onboarding/crests/ClassWarrior.png",
	},
	"thief": {
		"title": { "de": "Schurke", "en": "Thief" },
		"art": "res://assets/onboarding/crests/ClassThief.png",
	},
	"druid": {
		"title": { "de": "Druide", "en": "Druid" },
		"art": "res://assets/onboarding/crests/ClassDruid.png",
	},
	"shaman": {
		"title": { "de": "Schamane", "en": "Shaman" },
		"art": "res://assets/onboarding/crests/ClassShaman.png",
	},
}


## A name for this race that is not in taken, or an empty string if none is left.
static func suggest_name(race: String, taken: PackedStringArray) -> String:
	var names: Array = RACES[race].names.duplicate()
	names.shuffle()
	for candidate: String in names:
		if not taken.has(candidate):
			return candidate
	return ""
