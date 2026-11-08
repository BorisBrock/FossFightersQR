extends CardAbility
## Each hero draws "draw" cards, then puts "back" of their hand cards face down on their
## draw pile, as with the Perfektes Zusammenspiel. The cards are on the table, so the
## players are only told.
## values: "draw" (2), "back" (1).


func after_effects(fight: Fight, _play: CardPlay) -> void:
	fight.tell("draw_and_return_everyone", { "draw": value("draw", 2), "back": value("back", 1) })
