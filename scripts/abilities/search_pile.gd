extends CardAbility
## The hero searches their draw pile for a card and plays it, then shuffles the pile. The
## card they found is out of the game for the rest of the fight, as with the Magmahorn.
## Lightning on it gives extra actions, as the card's own would.


func after_effects(fight: Fight, play: CardPlay) -> void:
	var found := await fight.take_action(play.hero, { "prompt": "prompt_search_pile", "limited": true })
	if found == null:
		fight.tell("shuffle_pile", { "player": play.hero.name })
		return
	fight.give_actions(play, found.extra_actions)
	if not found.card.qr in fight.removed:
		fight.removed.append(found.card.qr)
	fight.tell("searched_card_removed", { "player": play.hero.name, "card": found.card.title })
