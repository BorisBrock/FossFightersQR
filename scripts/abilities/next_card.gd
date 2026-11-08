extends CardAbility
## What the next card played, by anyone, gets if it has an effect of "symbol" (of
## "damage_type", for attacks and supports): a Lightning, as after the Lichtpfeile, to take
## effect twice, as after the Stachelbola, or "bonus" more on those effects, as after the
## Schwelende Keule (protection) or the Drachenschuppe (magic attack). With "heal", a hero
## of the players' choice heals as much as those effects of the card, as after the
## Phönix-Eule. With "own", only the next card of the hero who played it counts, as with
## the Rauchholzpulver. "damage_type" "any" is for attacks or supports of every type, as
## with the Diadem der Unsichtbarkeit.
## values: "symbol" (attack), "damage_type" (ranged), "then" ("lightning", "repeat",
## "boost" or "heal"), "bonus" (2), "own" (false).


## In the fight until the next card is played.
class NextCard extends FightRule:
	var symbol: String
	var damage_type: String
	var then: String
	var bonus: int
	## Only this hero's next card counts, or anyone's for null.
	var hero: FightHero
	## The card that is repeated, or whose effects heal, once it is played.
	var _watched: CardPlay

	func _fits(effect: CardPlay.Effect) -> bool:
		if effect.type != symbol:
			return false
		if symbol in ["attack", "support"] and damage_type != "any":
			return effect.damage_type == damage_type
		return true

	func card_playing(fight: Fight, play: CardPlay) -> void:
		if play.replay or _watched != null or (hero != null and play.hero != hero):
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
			_watched = play

	func card_played(fight: Fight, play: CardPlay) -> void:
		if play != _watched:
			return
		fight.remove_rule(self)
		if play.cancelled:
			return
		if then == "heal":
			await _heal(fight, play)
			return
		fight.tell("card_repeated", { "player": play.hero.name, "card": play.card.title })
		await fight.play_again(play, play)

	## A hero of the players' choice heals as much as the card's effects that fit, as they
	## were when it took effect.
	func _heal(fight: Fight, play: CardPlay) -> void:
		var amount := 0
		for effect in play.effects:
			if _fits(effect):
				amount += effect.strength
		if amount <= 0:
			return
		var chosen := await fight.choose_hero(fight.heroes, "prompt_heal_who", { "player": play.hero.name, "amount": amount })
		if chosen != null:
			fight.stats.healed(play.hero, amount)
			fight.tell("heal", { "player": chosen.name, "amount": amount })

	func buff() -> FightBuff:
		var by_type := symbol in ["attack", "support"] and damage_type != "any"
		var icons: Array[String] = ["card", damage_type if by_type else symbol]
		var text := ""
		match then:
			"lightning":
				icons.append("lightning")
			"repeat":
				text = "×2"
			"heal":
				icons.append("heal")
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
