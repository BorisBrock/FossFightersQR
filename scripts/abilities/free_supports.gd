extends CardAbility
## A hero's trait: their Supports work without an attack of their type before, as the
## Rogue King's do.


func support_without_attack(_fight: Fight, _kind: String, play: CardPlay) -> bool:
	return is_mine(play)
