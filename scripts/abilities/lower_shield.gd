extends CardAbility
## Lowers a shield of the boss of the players' choice by "amount", as with the
## Explosivkristall. It is no attack: what the shield does besides absorbing is not set
## off, and what is more than the shield has does not reach the boss (Fight.lower_shield).
## values: "amount" (7).


func after_effects(fight: Fight, play: CardPlay) -> void:
	var amount: int = value("amount", 7)
	var kinds: Array[String] = []
	for kind in Fight.DAMAGE_TYPES:
		if fight.shields.get(kind, 0) > 0:
			kinds.append(kind)
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
