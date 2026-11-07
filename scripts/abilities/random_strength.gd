extends CardAbility
## The strength of each of the card's effects of "type" is rolled, from "min" to "max",
## each on its own, as with the Meteoritenschauer (attacks of 1-3).
## values: "type" (attack), "min" (1), "max" (3).


func before_effects(fight: Fight, play: CardPlay) -> void:
	var type: String = value("type", "attack")
	for effect in play.effects:
		if effect.type == type:
			effect.strength = fight.rng.randi_range(value("min", 1), value("max", 3))
