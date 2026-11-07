extends CardAbility
## The boss's attack against a hero of the players' choice is halved, rounded down, and
## loses what it does besides damage, as with the Kultistenkette.


func after_effects(fight: Fight, play: CardPlay) -> void:
	var threatened := fight.heroes_where(func(other: FightHero) -> bool: return other.threat > 0)
	var hero := await fight.choose_hero(threatened, "prompt_halve_who", { "player": play.hero.name })
	if hero == null:
		return
	var before := hero.threat
	hero.threat = floori(before / 2.0)
	hero.threat_effects.clear()
	fight.stats.protected(play.hero, before - hero.threat)
	fight.hero_changed.emit(hero)
	fight.tell("attack_halved", { "player": hero.name, "damage": hero.threat })
