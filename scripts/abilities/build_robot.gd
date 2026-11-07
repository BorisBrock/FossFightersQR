extends CardAbility
## The hero builds a battle robot, for the Goblin Genius (battle_robot). It works until
## the players say it no longer does.


func after_effects(fight: Fight, play: CardPlay) -> void:
	play.hero.notes["robot"] = true
	fight.tell("robot_built", { "player": play.hero.name })
