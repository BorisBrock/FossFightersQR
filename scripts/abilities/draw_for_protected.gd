extends CardAbility
## The card's Draw is for the heroes its Protection protected, instead of its hero, as with
## the Moosumhang. If it protected no one, no one draws.

var _count := 0


func before_effects(_fight: Fight, play: CardPlay) -> void:
	_count = play.strength_of("draw")
	for i in range(play.effects.size() - 1, -1, -1):
		if play.effects[i].type == "draw":
			play.effects.remove_at(i)


func after_effects(fight: Fight, play: CardPlay) -> void:
	if _count <= 0:
		return
	for target in play.protected:
		fight.tell("draw_cards", { "player": target.name, "count": _count })
