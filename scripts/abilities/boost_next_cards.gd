extends CardAbility
## The next "cards" cards played, by anyone and over rounds, get "bonus" more on all their
## attacks and supports, as with Muttis Nachtisch. Cards played once more (CardPlay.replay)
## are not counted, and not boosted. With "random_token", a random hero then takes one
## status token of that kind, such as "poison".
## values: "cards" (8), "bonus" (1), "random_token" ("").


## In the fight until it has boosted its cards.
class Boost extends FightRule:
	var left: int
	var bonus: int

	func card_playing(fight: Fight, play: CardPlay) -> void:
		if play.replay:
			return
		play.boost("attack", bonus)
		play.boost("support", bonus)
		left -= 1
		if left <= 0:
			fight.remove_rule(self)
		else:
			fight.buffs_changed.emit()

	func buff() -> FightBuff:
		var shown := FightBuff.new(null, ["card"], "%+d" % bonus)
		shown.count = left
		return shown


func after_effects(fight: Fight, _play: CardPlay) -> void:
	var boost := Boost.new()
	boost.left = value("cards", 8)
	boost.bonus = value("bonus", 1)
	fight.add_rule(boost)
	fight.tell("next_cards_boosted", { "cards": boost.left, "bonus": boost.bonus })
	var token: String = value("random_token", "")
	if token.is_empty() or fight.heroes.is_empty():
		return
	await fight.until_read()
	var hero := fight.heroes[fight.rng.randi_range(0, fight.heroes.size() - 1)]
	fight.tell("random_token", { "player": hero.name, "tokens": fight.token_text({ token: 1 }) })
