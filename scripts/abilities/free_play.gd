extends CardAbility
## Another hero may play cards right now, without using a turn of theirs. Lightning on
## those cards gives them more actions right away.
## values: "cards", how many (1).


func after_effects(fight: Fight, play: CardPlay) -> void:
	var other := await fight.choose_hero(fight.others(play.hero), "prompt_free_play_who", { "player": play.hero.name }, true)
	if other == null:
		return
	await fight.play_actions(other, value("cards", 1), { "prompt": "prompt_free_play", "can_skip": true })
