extends CardAbility
## Lowers a shield of the boss of the players' choice by "amount", as with the
## Explosivkristall. It is no attack: what the shield does besides absorbing is not set
## off, and what is more than the shield has does not reach the boss (Fight.lower_shield).
## With "all", every shield goes down by "amount", as with the Hammer des Zorns, and
## without shields nothing is said, as the card does something else too. With "poison",
## the boss gets that many poison tokens if the shield breaks from it, as with the
## Waffengift.
## values: "amount" (7), "all" (false), "poison" (0).


func after_effects(fight: Fight, play: CardPlay) -> void:
	var amount: int = value("amount", 7)
	var kinds: Array[String] = []
	for kind in Fight.DAMAGE_TYPES:
		if fight.shields.get(kind, 0) > 0:
			kinds.append(kind)
	if value("all", false):
		if kinds.is_empty():
			return
		for kind in kinds:
			await fight.lower_shield(kind, amount, play)
		fight.tell("shields_lowered", { "boss": fight.boss.title, "amount": amount })
		return
	if kinds.is_empty():
		fight.tell("no_shield_to_lower", { "boss": fight.boss.title, "player": play.hero.name, "card": play.card.title })
		return
	var kind := kinds[0]
	if kinds.size() > 1:
		var options: Array[String] = []
		for each in kinds:
			options.append("option_shield_%s" % each)
		var index := await fight.choose_from(options, "prompt_lower_shield", { "player": play.hero.name, "amount": amount })
		if index < 0:
			return
		kind = kinds[index]
	var lowered := await fight.lower_shield(kind, amount, play)
	fight.tell("shield_lowered", { "boss": fight.boss.title, "kind": Fight.NAMES[kind], "amount": lowered })
	var poison: int = value("poison", 0)
	if poison > 0 and lowered > 0 and fight.shields.get(kind, 0) == 0:
		await fight.poison_boss(poison, play)
		fight.tell("shield_broken_poison", { "boss": fight.boss.title, "poison": poison })
