extends CardAbility
## A hero of the players' choice: until the end of the fight, each time the boss's attack
## strikes them with "threshold" or more, the boss gets "poison" poison tokens, as with the
## Krone des Prinzen. With "remove_card", the card is then out of the game.
## values: "threshold" (4), "poison" (1), "remove_card" (false).


## In the fight from the card on, until its end.
class PoisonOnAttack extends FightRule:
	var hero: FightHero
	var threshold: int
	var poison: int
	var card: Card

	func hero_struck(fight: Fight, struck: FightHero, damage: int) -> void:
		if struck != hero or damage < threshold:
			return
		fight.tell("poison_on_attack", { "boss": fight.boss.title, "player": hero.name, "card": card.title, "poison": poison })
		await fight.poison_boss(poison)


func before_effects(_fight: Fight, play: CardPlay) -> void:
	if value("remove_card", false) and not play.has_effect("remove_from_game"):
		play.add_effect("remove_from_game", 0)


func after_effects(fight: Fight, play: CardPlay) -> void:
	var rule := PoisonOnAttack.new()
	rule.threshold = value("threshold", 4)
	rule.poison = value("poison", 1)
	rule.card = play.card
	rule.hero = await fight.choose_hero(fight.heroes, "prompt_poison_on_attack_who", { "player": play.hero.name, "threshold": rule.threshold, "poison": rule.poison })
	if rule.hero == null:
		return
	fight.add_rule(rule)
	fight.tell("poison_on_attack_ready", { "player": rule.hero.name, "card": play.card.title, "threshold": rule.threshold, "poison": rule.poison })
