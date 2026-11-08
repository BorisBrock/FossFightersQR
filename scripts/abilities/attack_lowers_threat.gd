extends CardAbility
## A hero of the players' choice: each time they play a card with an attack this round,
## the boss's attack against them is "amount" lower, as with the Segen des
## Gleichgewichts. It is no Protection, so what changes Protection does not change it.
## values: "amount" (2).


## In the fight until the end of the round.
class LowerOnAttack extends FightRule:
	var hero: FightHero
	## Who played the card, for the statistics.
	var by: FightHero
	var amount: int

	func card_played(fight: Fight, play: CardPlay) -> void:
		if play.replay or play.hero != hero or not play.has_effect("attack") or hero.threat <= 0:
			return
		var before := hero.threat
		fight.protect(hero, amount)
		fight.stats.protected(by, before - hero.threat)
		fight.tell("threat_lowered", { "boss": fight.boss.title, "player": hero.name, "amount": before - hero.threat })


func after_effects(fight: Fight, play: CardPlay) -> void:
	var chosen := await fight.choose_hero(fight.heroes, "prompt_chosen_hero", { "player": play.hero.name })
	if chosen == null:
		return
	var rule := LowerOnAttack.new()
	rule.hero = chosen
	rule.by = play.hero
	rule.amount = value("amount", 2)
	fight.add_rule(rule, true)
	fight.tell("threat_lowers_on_attack", { "player": chosen.name, "amount": rule.amount })
