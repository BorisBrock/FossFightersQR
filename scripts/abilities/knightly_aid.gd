extends CardAbility
## The boss's attack against the hero is gone. Instead, an attack against another hero
## of the players' choice goes to them, with its effects.


func after_effects(fight: Fight, play: CardPlay) -> void:
	var hero := play.hero
	hero.threat = 0
	hero.threat_effects.clear()
	fight.hero_changed.emit(hero)
	var threatened := fight.heroes_where(func(other: FightHero) -> bool: return other != hero and other.threat > 0)
	var other := await fight.choose_hero(threatened, "prompt_redirect_who", { "player": hero.name })
	if other == null:
		fight.tell("attack_cancelled", { "player": hero.name })
		return
	var damage := other.threat
	fight.redirect_attack(other, hero)
	fight.tell("attack_redirected", { "player": hero.name, "other": other.name, "damage": damage })
