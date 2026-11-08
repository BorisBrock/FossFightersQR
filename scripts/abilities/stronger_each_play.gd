extends CardAbility
## The card's effects of "type" are "bonus" stronger for each time its hero played it
## before in the fight, as the Stachelfaust. With "back_to_pile", the players are reminded
## at the end of the round that the hero shuffles it back into their draw pile instead of
## discarding it, so that it comes again.
## values: "type" (attack), "bonus" (1), "back_to_pile" (false).


## In the fight until the end of the round.
class BackToPile extends FightRule:
	var hero: FightHero
	var card: Card

	func round_end_started(fight: Fight) -> void:
		fight.remove_rule(self)
		fight.tell("card_back_to_pile", { "player": hero.name, "card": card.title })


func before_effects(fight: Fight, play: CardPlay) -> void:
	# The history has this play already, or for a replay the play it repeats.
	var plays := fight.history.filter(func(other: CardPlay) -> bool:
		return other.hero == play.hero and other.card.qr == play.card.qr).size()
	var earlier := maxi(0, plays - 1)
	if earlier > 0:
		play.boost(value("type", "attack"), earlier * value("bonus", 1))


func after_effects(fight: Fight, play: CardPlay) -> void:
	if not value("back_to_pile", false) or play.replay:
		return
	var back := BackToPile.new()
	back.hero = play.hero
	back.card = play.card
	fight.add_rule(back, true)
