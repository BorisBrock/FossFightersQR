extends CardAbility
## The card's attack is as strong as the boss's attack against its hero, such as the Rune
## of Revenge. If it deals at least "threshold" damage, to the shields and the boss
## together, the hero loses "health_loss".
## values: "threshold" (0: never), "health_loss" (0).


func set_strength(_fight: Fight, play: CardPlay) -> void:
	for effect in play.effects:
		if effect.type == "attack":
			effect.strength = play.hero.threat


func after_effects(fight: Fight, play: CardPlay) -> void:
	var threshold: int = value("threshold", 0)
	if threshold > 0 and play.damage + play.shield_damage >= threshold:
		await fight.hurt_hero(play.hero, value("health_loss", 0), play)
