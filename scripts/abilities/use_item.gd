extends CardAbility
## The hero uses an item of their choice at once, as part of this action, as with the
## Lianenschlange. Lightning on it gives extra actions, as the card's own would.


func after_effects(fight: Fight, play: CardPlay) -> void:
	var item := await fight.take_action(play.hero, {
		"prompt": "prompt_use_item",
		"limited": true,
		"can_skip": true,
		"only": func(card: Card) -> bool: return card.is_item(),
	})
	if item != null:
		fight.give_actions(play, item.extra_actions)
