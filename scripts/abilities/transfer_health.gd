extends CardAbility
## The hero may give as much of their health as they like to exactly one other hero, as
## with the Uralter Samen. The heroes' health is on the table, so the players are only told.


func after_effects(fight: Fight, play: CardPlay) -> void:
	if fight.others(play.hero).is_empty():
		return
	fight.tell("transfer_health", { "player": play.hero.name })
