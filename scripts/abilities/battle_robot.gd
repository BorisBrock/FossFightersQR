extends CardAbility
## A hero's trait: while their battle robot works (see build_robot), their attacks are
## stronger, as the Goblin Genius's are. Whether it still works is on the table, so each
## round the players are asked.
## values: "bonus" (2).


func action_phase_started(fight: Fight) -> void:
	if owner.notes.get("robot", false) and not await fight.confirm("prompt_robot_working", { "player": owner.name }):
		owner.notes.erase("robot")


func card_playing(_fight: Fight, play: CardPlay) -> void:
	if is_mine(play) and owner.notes.get("robot", false):
		play.boost("attack", value("bonus", 2))
