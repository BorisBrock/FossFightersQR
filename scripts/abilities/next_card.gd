extends CardAbility
## What the next card played, by anyone, gets if it has an attack of "damage_type": a
## Lightning, as after the Lichtpfeile, or to take effect twice, as after the Stachelbola.
## values: "damage_type" (ranged), "then" ("lightning" or "repeat").


## In the fight until the next card is played.
class NextCard extends FightRule:
	var damage_type: String
	var then: String
	var _repeat: CardPlay

	func card_playing(fight: Fight, play: CardPlay) -> void:
		if play.replay or _repeat != null:
			return
		var fits := play.effects.any(func(effect: CardPlay.Effect) -> bool:
			return effect.type == "attack" and effect.damage_type == damage_type)
		if not fits:
			fight.remove_rule(self)
		elif then == "lightning":
			fight.remove_rule(self)
			play.add_effect("lightning", 1)
		else:
			_repeat = play

	func card_played(fight: Fight, play: CardPlay) -> void:
		if play != _repeat:
			return
		fight.remove_rule(self)
		if play.cancelled:
			return
		fight.tell("card_repeated", { "player": play.hero.name, "card": play.card.title })
		await fight.play_again(play, play)


func after_effects(fight: Fight, _play: CardPlay) -> void:
	var next := NextCard.new()
	next.damage_type = value("damage_type", "ranged")
	next.then = value("then", "lightning")
	fight.add_rule(next)
