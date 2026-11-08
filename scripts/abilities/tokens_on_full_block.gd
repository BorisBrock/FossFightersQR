extends CardAbility
## If the card's Protection lowers an attack of the boss to 0, the hero it protected may
## remove "count" of their status tokens, as with the Himmelsschild. The tokens are on the
## table, so the players are only told.
## values: "count" (2).


func after_effects(fight: Fight, play: CardPlay) -> void:
	for target in play.protected:
		if target.threat == 0:
			fight.tell("remove_tokens", { "player": target.name, "count": value("count", 2) })
