extends CardAbility
## The hero plays a card from their discard pile or the top card of their draw pile, which
## is then out of the game for the rest of the fight, as with the Deja-Vu. Lightning on it
## gives extra actions, as the card's own would.


func after_effects(fight: Fight, play: CardPlay) -> void:
	var found := await fight.take_action(play.hero, { "prompt": "prompt_discard_or_top", "limited": true })
	if found == null:
		return
	fight.give_actions(play, found.extra_actions)
	if not found.card.qr in fight.removed:
		fight.removed.append(found.card.qr)
	fight.tell("played_card_removed", { "player": play.hero.name, "card": found.card.title })
