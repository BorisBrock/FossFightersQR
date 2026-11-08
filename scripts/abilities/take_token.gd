extends CardAbility
## The hero takes "count" status tokens of their choice from the supply, as with the
## Geisterrüstung. The tokens are on the table, so the players are only told.
## values: "count" (1).


func after_effects(fight: Fight, play: CardPlay) -> void:
	fight.tell("take_token", { "player": play.hero.name, "count": value("count", 1) })
