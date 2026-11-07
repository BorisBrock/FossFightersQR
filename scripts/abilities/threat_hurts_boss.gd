extends CardAbility
## The boss loses as much health as is left of its attack against the heroes the card's
## Protection was for, as with the Schleimiger Helm.


func after_effects(fight: Fight, play: CardPlay) -> void:
	for hero in play.protected:
		if hero.threat > 0:
			await fight.deal_damage(hero.threat, Fight.DIRECT, play)
