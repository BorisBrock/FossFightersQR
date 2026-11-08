extends CardAbility
## The hero looks at the top "look" cards of their draw pile and plays one of them at once,
## then puts the others back on top of the pile or below it, in any order, as with the
## Maske der Hellsicht. Lightning on the card they play gives extra actions, as the card's
## own would. The cards are on the table, so the players are only told.
## values: "look" (3).


func after_effects(fight: Fight, play: CardPlay) -> void:
	var look: int = value("look", 3)
	var found := await fight.take_action(play.hero, { "prompt": "prompt_play_from_top", "limited": true, "values": { "look": look } })
	if fight.over:
		return
	if found != null:
		fight.give_actions(play, found.extra_actions)
	fight.tell("play_from_top_rest", { "player": play.hero.name, "count": look - 1 if found != null else look })
