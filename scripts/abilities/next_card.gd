extends CardAbility
## What the next card played, by anyone, gets if it has an effect of "symbol" (of
## "damage_type", for attacks and supports): a Lightning, as after the Lichtpfeile, to take
## effect twice, as after the Stachelbola, or "bonus" more on those effects, as after the
## Schwelende Keule (protection) or the Drachenschuppe (magic attack). With "own", only
## the next card of the hero who played it counts, as with the Rauchholzpulver.
## values: "symbol" (attack), "damage_type" (ranged), "then" ("lightning", "repeat" or
## "boost"), "bonus" (2), "own" (false).


## In the fight until the next card is played.
class NextCard extends FightRule:
	var symbol: String
	var damage_type: String
	var then: String
	var bonus: int
	## Only this hero's next card counts, or anyone's for null.
	var hero: FightHero
	var _repeat: CardPlay

	func _fits(effect: CardPlay.Effect) -> bool:
		if effect.type != symbol:
			return false
		return effect.damage_type == damage_type if symbol in ["attack", "support"] else true

	func card_playing(fight: Fight, play: CardPlay) -> void:
		if play.replay or _repeat != null or (hero != null and play.hero != hero):
			return
		if not play.effects.any(_fits):
			fight.remove_rule(self)
		elif then == "lightning":
			fight.remove_rule(self)
			play.add_effect("lightning", 1)
		elif then == "boost":
			fight.remove_rule(self)
			for effect in play.effects:
				if _fits(effect):
					effect.strength += bonus
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

	func buff() -> FightBuff:
		var icons: Array[String] = ["card", damage_type if symbol in ["attack", "support"] else symbol]
		var text := ""
		match then:
			"lightning":
				icons.append("lightning")
			"repeat":
				text = "×2"
			_:
				text = "%+d" % bonus
		return FightBuff.new(hero, icons, text)


func after_effects(fight: Fight, play: CardPlay) -> void:
	var next := NextCard.new()
	next.symbol = value("symbol", "attack")
	next.damage_type = value("damage_type", "ranged")
	next.then = value("then", "lightning")
	next.bonus = value("bonus", 2)
	if value("own", false):
		next.hero = play.hero
	fight.add_rule(next)
