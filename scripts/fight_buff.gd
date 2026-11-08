class_name FightBuff
extends RefCounted
## What the screen shows of a rule that lasts a while (FightRule.buff()): a small chip,
## by the seat of its hero or, for one that is for everyone, at the top of the screen.
## Such as a Totem (+1 on a hero's attacks) or Muttis Nachtisch (+1 on the next 8 cards).

const ICONS := {
	"attack": "res://assets/fight/icon_damage.svg",
	"support": "res://assets/fight/icon_support.svg",
	"protection": "res://assets/fight/icon_shield.svg",
	"heal": "res://assets/fight/icon_heal.svg",
	"lightning": "res://assets/fight/icon_lightning.svg",
	"draw": "res://assets/fight/icon_card.svg",
	"card": "res://assets/fight/icon_card.svg",
	"poison": "res://assets/fight/icon_poison.svg",
	"melee": "res://assets/fight/icon_melee.svg",
	"ranged": "res://assets/fight/icon_ranged.svg",
	"magic": "res://assets/fight/icon_magic.svg",
	"totem": "res://assets/fight/icon_totem.svg",
	"robot": "res://assets/fight/icon_robot.svg",
}

## Whose it is, or null for one that is for everyone.
var hero: FightHero
## What it is about, as keys of ICONS, shown one after the other.
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


## The icon of a symbol or damage type, such as "attack" or "magic", or "" for none.
static func icon(key: String) -> String:
	return ICONS.get(key, "")
