extends CardAbility
## The hero removes some of their own status tokens. The tokens are on the table, so the
## players are only told.
## values: "count" (2).


func after_effects(fight: Fight, play: CardPlay) -> void:
	fight.tell("remove_tokens", { "player": play.hero.name, "count": value("count", 2) })
