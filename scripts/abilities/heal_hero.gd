extends CardAbility
## One hero of the players' choice heals, such as with a Healing Potion. With "heroes",
## that many different heroes of the players' choice heal, as with the Drachenspeichel.
## values: "amount" (8), "heroes" (1).


func after_effects(fight: Fight, play: CardPlay) -> void:
	var amount: int = value("amount", 8)
	var count: int = value("heroes", 1)
	var choices: Array[FightHero] = fight.heroes.duplicate()
	for i in count:
		var target := await fight.choose_hero(choices, "prompt_heal_who", { "player": play.hero.name, "amount": amount })
		if target == null:
			return
		choices.erase(target)
		fight.stats.healed(play.hero, amount)
		fight.tell("heal", { "player": target.name, "amount": amount })
		if i < count - 1:
			await fight.until_read()
