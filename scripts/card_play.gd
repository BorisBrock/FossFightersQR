class_name CardPlay
extends RefCounted
## One card being played: by whom, and what it does. Rules can change what it does before
## it takes effect (FightRule.card_playing).


## One thing a card does, from one of its symbols.
class Effect:
	## attack, support, protection, heal, lightning or draw.
	var type: String
	var strength: int
	## melee, ranged or magic for attacks and supports, otherwise empty.
	var damage_type: String

	func _init(effect_type: String, effect_strength: int, effect_damage_type := "") -> void:
		type = effect_type
		strength = effect_strength
		damage_type = effect_damage_type


var hero: FightHero
var card: Card
var effects: Array[Effect] = []
## Its special rule, if the card has one (Card.ability).
var ability: CardAbility
## Lightning on it gives no extra action, as with the Lucky Charm.
var ignore_lightning := false
## Extra actions it gives right away, from Lightning or its ability.
var extra_actions := 0
## Set by a rule to stop the card from taking effect. It still counts as played.
var cancelled := false
## What it did, for rules that react to it: damage to shields and to the boss.
var shield_damage := 0
var damage := 0


func _init(play_hero: FightHero, played_card: Card) -> void:
	hero = play_hero
	card = played_card
	for symbol in card.symbols:
		effects.append(Effect.new(symbol.type, symbol.strength, symbol.damage_type))


func strength_of(type: String) -> int:
	var total := 0
	for effect in effects:
		if effect.type == type:
			total += effect.strength
	return total


## Adds bonus to every effect of this type, such as +2 to attacks.
func boost(type: String, bonus: int) -> void:
	for effect in effects:
		if effect.type == type:
			effect.strength = maxi(0, effect.strength + bonus)
