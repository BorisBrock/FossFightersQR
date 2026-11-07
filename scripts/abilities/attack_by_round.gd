extends CardAbility
## The card's attack is as strong as the round: 1 in round 1, 2 in round 2, and so on,
## such as Krawumm.
## values: "type", the symbol whose strength it sets ("attack").


func before_effects(fight: Fight, play: CardPlay) -> void:
	var type: String = value("type", "attack")
	for effect in play.effects:
		if effect.type == type:
			effect.strength = fight.round_number
