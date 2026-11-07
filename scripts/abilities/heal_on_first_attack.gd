extends CardAbility
## A hero's trait: whenever they play the first attack of a damage type in a round, they
## heal, as the Celestial Paladin does.
## values: "amount" (3).


func attack_type_opened(fight: Fight, _kind: String, play: CardPlay) -> void:
	if not is_mine(play):
		return
	var amount: int = value("amount", 3)
	fight.stats.healed(owner, amount)
	fight.tell("heal", { "player": owner.name, "amount": amount })
