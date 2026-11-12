class_name FightBuff
extends RefCounted
## What the screen shows of a rule that lasts a while (FightRule.buff()): a small chip,
## by the seat of its hero or, for one that is for everyone, at the top of the screen.
## Such as a Totem (+1 on a hero's attacks) or Muttis Nachtisch (+1 on the next 8 cards).

## A key with several icons, such as "support" (supports of every type), shows them
## overlapping as one symbol.
const ICONS := {
	"attack": "res://assets/fight/icon_damage.png",
	"support": [
		"res://assets/fight/icon_melee_support.png",
		"res://assets/fight/icon_ranged_support.png",
		"res://assets/fight/icon_magic_support.png",
	],
	"protection": "res://assets/fight/icon_protection.png",
	"heal": "res://assets/fight/icon_heal.png",
	"lightning": "res://assets/fight/icon_lightning.png",
	"draw": "res://assets/fight/icon_card.png",
	"card": "res://assets/fight/icon_card.png",
	"poison": "res://assets/fight/icon_poison.png",
	"melee": "res://assets/fight/icon_melee.png",
	"ranged": "res://assets/fight/icon_ranged.png",
	"magic": "res://assets/fight/icon_magic.png",
	"melee_support": "res://assets/fight/icon_melee_support.png",
	"ranged_support": "res://assets/fight/icon_ranged_support.png",
	"magic_support": "res://assets/fight/icon_magic_support.png",
	"totem": "res://assets/fight/icon_totem.png",
	"robot": "res://assets/fight/icon_robot.png",
}

## A key that shows a small grid of other keys, row by row, such as "every_type": the
## three attacks above the three supports, for what boosts all attacks and supports.
const GRIDS := {
	"every_type": [
		["melee", "ranged", "magic"],
		["melee_support", "ranged_support", "magic_support"],
	],
}

## Whose it is, or null for one that is for everyone.
var hero: FightHero
## What it is about, as keys of ICONS or GRIDS, shown one after the other.
var icons: Array[String] = []
## Short, such as "+1". Empty for none.
var text := ""
## How often it still works, such as the cards Muttis Nachtisch still boosts, shown small
## by the chip. 0 for no count.
var count := 0
## Something with health, such as the goblin's battle robot, shown as a small bar by the
## chip: what is left of it, out of bar_max. bar_max 0 for no bar.
var bar := 0
var bar_max := 0
## A Totem: the hero has its totem token on the table until the round ends. Its chip is
## framed like one.
var totem := false


func _init(buff_hero: FightHero = null, buff_icons: Array[String] = [], buff_text := "") -> void:
	hero = buff_hero
	icons = buff_icons
	text = buff_text


## The pictures of a symbol or damage type, such as "attack" or "magic": one, several for
## one shown as overlapping icons, or none.
static func icon_paths(key: String) -> Array[String]:
	var found: Variant = ICONS.get(key)
	var paths: Array[String] = []
	if found is String:
		paths.append(found)
	elif found is Array:
		paths.assign(found)
	return paths


## The key of a symbol and damage type, such as "magic" for a magic attack and
## "magic_support" for a magic support.
static func typed_key(symbol: String, damage_type: String) -> String:
	return damage_type + "_support" if symbol == "support" else damage_type
