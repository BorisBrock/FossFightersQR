extends CardAbility
## A hero of the players' choice draws "draw" cards, plays "play" of them at once and
## discards the rest, as with Güldis Angel. Lightning on the cards played gives that hero
## extra actions afterwards, which can be any card.
## values: "draw" (5), "play" (2).


func after_effects(fight: Fight, play: CardPlay) -> void:
	var draw: int = value("draw", 5)
	var count: int = value("play", 2)
	var hero := await fight.choose_hero(fight.heroes, "prompt_chosen_hero", { "player": play.hero.name })
	if hero == null:
		return
	fight.tell("draw_and_play", { "player": hero.name, "draw": draw, "play": count, "discard": maxi(0, draw - count) })
	await fight.until_read()
	var settings := { "prompt": "prompt_play_drawn", "limited": true, "reserved": true }
	fight.reserve_actions(hero, count, settings)
	var extra := 0
	for i in count:
		var drawn := await fight.take_action(hero, settings)
		if drawn != null:
			extra += drawn.extra_actions
	await fight.play_actions(hero, extra, { "prompt": "prompt_free_play", "can_skip": true })
