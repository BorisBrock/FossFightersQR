extends CardAbility
## The last card with an attack played in the fight, by anyone, takes effect once more,
## as with the Amulett der Zeit. Lightning on it gives extra actions only if it is the
## hero's own (Fight.play_again).


func after_effects(fight: Fight, play: CardPlay) -> void:
	for i in range(fight.history.size() - 1, -1, -1):
		var earlier := fight.history[i]
		if earlier != play and not earlier.cancelled and earlier.card.has_symbol("attack"):
			fight.tell("card_repeated", { "player": earlier.hero.name, "card": earlier.card.title })
			await fight.play_again(earlier, play)
			return
	fight.tell("nothing_to_repeat", { "player": play.hero.name })
