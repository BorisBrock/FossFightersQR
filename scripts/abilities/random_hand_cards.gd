extends CardAbility
## For the rest of the round, each card the hero plays from their hand has to be a random
## one of their hand cards, as with the Voodoo-Puppe. Their hand is on the table, so the
## players are told, and reminded at each of the hero's turns this round.


## In the fight until the end of the round.
class RandomHand extends FightRule:
	var hero: FightHero

	func turn_started(fight: Fight, turn_hero: FightHero) -> void:
		if turn_hero == hero:
			fight.tell("random_hand_reminder", { "player": hero.name })

	func buff() -> FightBuff:
		return FightBuff.new(hero, ["card"], "?")


func after_effects(fight: Fight, play: CardPlay) -> void:
	var rule := RandomHand.new()
	rule.hero = play.hero
	fight.add_rule(rule, true)
	fight.tell("random_hand_cards", { "player": play.hero.name, "card": play.card.title })
