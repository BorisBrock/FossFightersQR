extends CardAbility
## A hero's active curse goes to the curse discard pile, as with the Fluchbrecher. Curses
## are cards on the table, so the players are only told.


func after_effects(fight: Fight, play: CardPlay) -> void:
	fight.tell("remove_curse", { "player": play.hero.name })
