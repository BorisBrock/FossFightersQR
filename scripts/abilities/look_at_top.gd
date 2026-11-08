extends CardAbility
## Each hero looks at the top "look" cards of their draw pile, takes "take" of them into
## their hand and puts the others back in any order, as with the Kompass der Verdammten.
## The cards are on the table, so the players are only told.
## values: "look" (3), "take" (1).


func after_effects(fight: Fight, _play: CardPlay) -> void:
	var look: int = value("look", 3)
	var take: int = value("take", 1)
	fight.tell("look_at_top_everyone", { "look": look, "take": take, "back": look - take })
