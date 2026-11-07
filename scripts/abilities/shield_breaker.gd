extends CardAbility
## A hero's trait: when they break a shield of the boss, the boss loses health at once, as
## with the Halfling Luckmaster.
## values: "damage" (4).


func shield_broken(fight: Fight, _kind: String, play: CardPlay) -> void:
	if not is_mine(play):
		return
	var damage: int = value("damage", 4)
	fight.tell("shield_breaker", { "player": owner.name, "boss": fight.boss.title, "damage": damage })
	await fight.deal_damage(damage, Fight.DIRECT, play)
