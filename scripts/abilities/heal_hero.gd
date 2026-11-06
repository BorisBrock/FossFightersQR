extends CardAbility
## One hero of the players' choice heals, such as with a Healing Potion.
## values: "amount" (8).


func after_effects(fight: Fight, play: CardPlay) -> void:
	var amount: int = value("amount", 8)
	var target := await fight.choose_hero(fight.heroes, "prompt_heal_who", { "player": play.hero.name, "amount": amount })
	if target != null:
		fight.tell("heal", { "player": target.name, "amount": amount })
