extends CardAbility
## The hero discards "count" random cards from their hand, if they have any, as with the
## Säuremottenschwarm. Their hand is on the table, so the players are only told.
## values: "count" (1).


func after_effects(fight: Fight, play: CardPlay) -> void:
	fight.tell("discard_random", { "player": play.hero.name, "count": value("count", 1) })
