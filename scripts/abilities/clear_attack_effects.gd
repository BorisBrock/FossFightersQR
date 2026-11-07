extends CardAbility
## The boss's attacks the card's Protection lowered lose what they do besides damage,
## such as poison, as with the Smoke Bomb.


func after_effects(fight: Fight, play: CardPlay) -> void:
	for hero in play.protected:
		if not hero.threat_effects.is_empty():
			hero.threat_effects.clear()
			fight.hero_changed.emit(hero)
			fight.tell("attack_effects_removed", { "player": hero.name })
