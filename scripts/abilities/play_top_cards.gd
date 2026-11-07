extends CardAbility
## A hero of the players' choice plays the top cards of their draw pile at once, as with
## the Wunderlampe. Lightning on them gives that hero extra actions afterwards. Its
## uses_per_fight takes the card out of the fight.
## values: "cards" (3).


func after_effects(fight: Fight, play: CardPlay) -> void:
	var count: int = value("cards", 3)
	var hero := await fight.choose_hero(fight.heroes, "prompt_play_top_who", { "player": play.hero.name, "count": count })
	if hero == null:
		return
	var extra := 0
	for i in count:
		var top := await fight.take_action(hero, { "prompt": "prompt_lucky_charm", "limited": true })
		if top != null:
			extra += top.extra_actions
	await fight.play_actions(hero, extra, { "prompt": "prompt_free_play", "can_skip": true })
