extends CardAbility
## Next round, every attack of the boss is "amount" lower, as with the Magische Eruption.
## With "chosen_hero", the card's Heal and Draw are for a hero of the players' choice, as
## with for_chosen_hero.
## values: "amount" (3), "chosen_hero" (false).


## In the fight until the boss has planned its attacks next round.
class Weaken extends FightRule:
	var round_number: int
	var amount: int
	var hero: FightHero
	var card: Card

	func attacks_planned(fight: Fight) -> void:
		if fight.round_number < round_number:
			return
		fight.remove_rule(self)
		for target in fight.heroes:
			var before := target.threat
			fight.protect(target, amount)
			fight.stats.protected(hero, before - target.threat)
		fight.tell("attacks_weakened", { "player": hero.name, "card": card.title, "amount": amount })


func before_effects(fight: Fight, play: CardPlay) -> void:
	if not value("chosen_hero", false):
		return
	var chosen := await fight.choose_hero(fight.heroes, "prompt_chosen_hero", { "player": play.hero.name })
	if chosen != null:
		play.targets = [chosen]


func after_effects(fight: Fight, play: CardPlay) -> void:
	var weaken := Weaken.new()
	weaken.round_number = fight.round_number + 1
	weaken.amount = value("amount", 3)
	weaken.hero = play.hero
	weaken.card = play.card
	fight.add_rule(weaken)
	fight.tell("attacks_weakened_next_round", { "player": play.hero.name, "card": play.card.title, "amount": weaken.amount })
