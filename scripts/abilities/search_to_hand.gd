extends CardAbility
## The hero searches their draw pile for "count" cards of their choice, takes them into
## their hand and shuffles the pile, as with the Verlorene Seele. The cards are on the
## table, so the players are only told.
## values: "count" (1).


func after_effects(fight: Fight, play: CardPlay) -> void:
	fight.tell("search_to_hand", { "player": play.hero.name, "count": value("count", 1) })
