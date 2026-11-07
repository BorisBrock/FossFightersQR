extends CardAbility
## The card's attacks only take effect at the start of the hero's first turn in the next
## round, as with the Bombling.


## In the fight until the attacks have taken effect.
class Delayed extends FightRule:
	var hero: FightHero
	var card: Card
	var effects: Array[CardPlay.Effect] = []
	var round_number := 0

	func turn_started(fight: Fight, turn_hero: FightHero) -> void:
		if turn_hero != hero or fight.round_number <= round_number:
			return
		fight.remove_rule(self)
		fight.tell("delayed_attack_now", { "player": hero.name, "card": card.title })
		var later := CardPlay.new(hero, card)
		later.replay = true
		later.effects = effects
		await fight.play_card(later)


func before_effects(fight: Fight, play: CardPlay) -> void:
	var delayed := Delayed.new()
	delayed.hero = play.hero
	delayed.card = play.card
	delayed.round_number = fight.round_number
	var now: Array[CardPlay.Effect] = []
	for effect in play.effects:
		if effect.type == "attack":
			delayed.effects.append(effect)
		else:
			now.append(effect)
	if delayed.effects.is_empty():
		return
	play.effects = now
	fight.add_rule(delayed)
	fight.tell("attack_delayed", { "player": play.hero.name, "card": play.card.title })
