extends CardAbility
## The hero removes some of their own status tokens, choosing which.
## values: "count" (2).


func can_play(_fight: Fight, play: CardPlay) -> String:
	return "" if play.hero.has_tokens() else "notice_no_tokens"


func after_effects(fight: Fight, play: CardPlay) -> void:
	var hero := play.hero
	for i in value("count", 2):
		if not hero.has_tokens():
			return
		var kinds: Array[String] = []
		var options: Array[String] = []
		for token in FightHero.TOKENS:
			if hero.token_count(token) > 0:
				kinds.append(token)
				options.append("option_token_" + token)
		var choice := await fight.choose_from(options, "prompt_remove_token", { "player": hero.name }, true)
		if choice < 0:
			return
		hero.add_tokens(kinds[choice], -1)
		fight.hero_changed.emit(hero)
