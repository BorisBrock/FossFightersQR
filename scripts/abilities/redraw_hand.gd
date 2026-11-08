extends CardAbility
## A hero of the players' choice discards as many hand cards as they like, then draws up
## to their hand limit, as with the Phönixbeere. Their hand is on the table, so the
## players are only told.


func after_effects(fight: Fight, play: CardPlay) -> void:
	var chosen := await fight.choose_hero(fight.heroes, "prompt_redraw_hand_who", { "player": play.hero.name })
	if chosen != null:
		fight.tell("redraw_hand", { "player": chosen.name })
