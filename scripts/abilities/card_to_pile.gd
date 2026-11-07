extends CardAbility
## To play the card, the hero puts other cards from their hand on their draw pile, as for
## the Pestbote. The cards are in the hero's hand, so the players are only told.
## values: "count" (1).


func before_effects(fight: Fight, play: CardPlay) -> void:
	fight.tell("card_to_pile", { "player": play.hero.name, "count": value("count", 1) })
