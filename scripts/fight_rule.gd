class_name FightRule
extends RefCounted
## Something that takes part in the rules of a fight and can step in at its moments: the
## boss, a card's ability that lasts a while, later a hero's level-up ability.
##
## The fight calls each hook below on every rule it has (Fight.rules), the boss first, in
## the order they were added. The defaults do nothing, so a rule only overrides what it
## needs. Every hook gets the fight, which a rule can read and change.
##
## A hook may wait for the players, such as `await fight.choose_hero(...)`: the fight
## waits for it. A hook that changes a value returns it, and the fight passes the result
## on to the next rule.

#region The fight and its rounds
func fight_started(_fight: Fight) -> void:
	pass


## A new round has begun, before anything else in it happens. Fight.round_number is the
## new round.
func round_started(_fight: Fight) -> void:
	pass


## The players have chosen who starts the action phase this round.
func starter_chosen(_fight: Fight, _hero: FightHero) -> void:
	pass


## The boss has planned its attacks (Fight.threaten). Rules can still change them.
func attacks_planned(_fight: Fight) -> void:
	pass


## The boss's shields are up (Fight.shields). Rules can still change them.
func shields_raised(_fight: Fight) -> void:
	pass


func action_phase_started(_fight: Fight) -> void:
	pass


func action_phase_ended(_fight: Fight) -> void:
	pass


## After the boss's attacks, before the status tokens take effect.
func attack_phase_ended(_fight: Fight) -> void:
	pass


## The last thing in a round, after the draw phase.
func round_ended(_fight: Fight) -> void:
	pass
#endregion

#region Turns and cards
func turn_started(_fight: Fight, _hero: FightHero) -> void:
	pass


func turn_ended(_fight: Fight, _hero: FightHero) -> void:
	pass


## A card is about to take effect. Rules can change what it does through play.effects,
## or stop it with play.cancelled, such as a boss that ignores the first card each round.
func card_playing(_fight: Fight, _play: CardPlay) -> void:
	pass


## A card has taken effect.
func card_played(_fight: Fight, _play: CardPlay) -> void:
	pass
#endregion

#region Values the rules can change
## The damage the boss really takes from damage that got through its shield. kind is
## melee, ranged or magic. play is the card that did it, or null.
func damage_taken(_fight: Fight, amount: int, _kind: String, _play: CardPlay) -> int:
	return amount


## The boss's health went down from old to new, such as for something that happens at
## half health.
func boss_hurt(_fight: Fight, _old: int, _new: int) -> void:
	pass


## How much a Protection lowers the attack against hero.
func protection(_fight: Fight, amount: int, _hero: FightHero, _play: CardPlay) -> int:
	return amount
#endregion
