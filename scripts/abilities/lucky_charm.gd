extends CardAbility
## The hero plays the top card of their draw pile at once, as part of this action.
## Lightning on it gives no extra action.


func after_effects(fight: Fight, play: CardPlay) -> void:
	await fight.take_action(play.hero, { "prompt": "prompt_lucky_charm", "ignore_lightning": true })
