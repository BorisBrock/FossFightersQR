extends CardAbility
## After its other effects, the card is out of the game for the rest of the fight, as the
## Donnerspeer, for cards whose print shows that with the special symbol (*) instead of
## the ripped card (remove_from_game).


func before_effects(_fight: Fight, play: CardPlay) -> void:
	if not play.has_effect("remove_from_game"):
		play.add_effect("remove_from_game", 0)
