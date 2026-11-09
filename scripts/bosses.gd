class_name Bosses
extends RefCounted
## The bosses players can fight, and the difficulty levels.
##
## Each boss is a script in scripts/bosses/, named after its id (see scripts/boss.gd).
## The boss list shows them in the order of IDS.
##
## Mirefang is the first boss.

const IDS: Array[String] = ["mirefang"]
const SCRIPT_PATH := "res://scripts/bosses/%s.gd"

const DIFFICULTIES := {
	"easy": {
		"title": { "de": "Leicht", "en": "Easy" },
		"description": { "de": "Für den ersten Kampf oder einen entspannten Abend.", "en": "For a first fight, or a relaxed evening." },
		"health_factor": 0.75,
		"attack_bonus": -1,
	},
	"normal": {
		"title": { "de": "Normal", "en": "Normal" },
		"description": { "de": "Der Boss, wie er gedacht ist.", "en": "The boss as it is meant to be." },
		"health_factor": 1.0,
		"attack_bonus": 0,
	},
	"hard": {
		"title": { "de": "Schwer", "en": "Hard" },
		"description": { "de": "Für erfahrene Helden. Jeder Fehler tut weh.", "en": "For seasoned heroes. Every mistake hurts." },
		"health_factor": 1.25,
		"attack_bonus": 1,
	},
}

const DEFAULT_DIFFICULTY := "normal"


static func has(id: String) -> bool:
	return id in IDS


## A new boss with this id, which has to be one of IDS. Each fight gets its own, so a
## boss can keep track of things during the fight in its own variables.
static func create(id: String) -> Boss:
	var boss: Boss = load(SCRIPT_PATH % id).new()
	boss.id = id
	return boss
