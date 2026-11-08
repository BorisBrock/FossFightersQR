class_name FightRule
extends RefCounted
## Something that takes part in the rules of a fight and can step in at its moments: the
## boss, a card's ability that lasts a while, later a hero's level-up ability.
##
## The fight calls each hook below on every rule it has (Fight.rules), the boss first, in
## the order they were added. The defaults do nothing, so a rule only overrides what it
## needs. Every hook gets the fight, which a rule can read and change.
##
## A rule that lasts a while, such as a Totem, can show on screen through buff().
##
## A hook may wait for the players, such as `await fight.choose_hero(...)`: the fight
## waits for it. A hook that changes a value returns it, and the fight passes the result
## on to the next rule.

## What the screen shows of this rule while it is in the fight, or null for nothing (see
## FightBuff). A rule whose buff changes, such as a count going down, says so with
## Fight.buffs_changed.
func buff() -> FightBuff:
	return null


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


## After the boss's attacks and what rules did on them, before the end of the round.
func attack_phase_ended(_fight: Fight) -> void:
	pass


## The end of the round has begun (status, discard and draw, Fight.Phase.ROUND_END),
## before the players are told what to do in it. Such as for reminders of what to do with
## the cards in the play area instead of discarding them.
func round_end_started(_fight: Fight) -> void:
	pass


## The last thing in a round, after the players have drawn.
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


## play has the first attack of kind this round, by anyone.
func attack_type_opened(_fight: Fight, _kind: String, _play: CardPlay) -> void:
	pass


## A Protection of play lowered the attack against hero, which was before.
func hero_protected(_fight: Fight, _hero: FightHero, _before: int, _play: CardPlay) -> void:
	pass
#endregion

#region The boss and the heroes
## The boss's shield of kind is broken, by play or by something else (null).
func shield_broken(_fight: Fight, _kind: String, _play: CardPlay) -> void:
	pass


## The boss's attack struck hero with damage, what was left of it after everything that
## lowered it (Fight.strike). Once the players have been told of all the boss's hits this
## round, before hero_hurt.
func hero_struck(_fight: Fight, _hero: FightHero, _damage: int) -> void:
	pass


## hero lost amount health, from the boss's attack or a card (play, or null). The app
## does not count the heroes' health, so this only says that it happened.
func hero_hurt(_fight: Fight, _hero: FightHero, _amount: int, _play: CardPlay) -> void:
	pass


## The boss is about to use one of its @-abilities. A rule can stop it with
## ability.prevented, and says by what through ability.prevented_by.
func boss_ability_used(_fight: Fight, _ability: BossAbility) -> void:
	pass
#endregion

#region Values the rules can change
## The damage the boss really takes from damage that got through its shield. kind is
## melee, ranged or magic. play is the card that did it, or null.
func damage_taken(_fight: Fight, amount: int, _kind: String, _play: CardPlay) -> int:
	return amount


## The boss got amount poison tokens (Fight.poison), from play or something else (null).
func boss_poisoned(_fight: Fight, _amount: int, _play: CardPlay) -> void:
	pass


## How much the boss's poison hurts it at the end of the round, by default 1 per token
## (Fight.poison).
func poison_damage(_fight: Fight, amount: int) -> int:
	return amount


## The boss's health went down from old to new, such as for something that happens at
## half health.
func boss_hurt(_fight: Fight, _old: int, _new: int) -> void:
	pass


## How much a Protection lowers the attack against hero.
func protection(_fight: Fight, amount: int, _hero: FightHero, _play: CardPlay) -> int:
	return amount


## Whether a Support of kind in play works without an attack of its kind this round. If
## any rule says so, it does.
func support_without_attack(_fight: Fight, _kind: String, _play: CardPlay) -> bool:
	return false


## Whether play hitting the boss's shield of kind ignores what that shield does besides
## absorbing damage (Boss.shield_hit). If any rule says so, it does.
func ignores_shield_effect(_fight: Fight, _kind: String, _play: CardPlay) -> bool:
	return false
#endregion
