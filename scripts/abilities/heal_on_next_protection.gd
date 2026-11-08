extends CardAbility
## If the next card the hero plays has a Protection, each hero it protects heals as much as
## that Protection, as with the Rindenmaske. Any other card of theirs ends it.


## In the fight until the hero's next card.
class NextProtection extends FightRule:
	var hero: FightHero
	var _watched: CardPlay
	## [hero, amount] for each Protection of the watched card.
	var _heals: Array[Array] = []

	func card_playing(fight: Fight, play: CardPlay) -> void:
		if play.replay or play.hero != hero:
			return
		if _watched == null and play.has_effect("protection"):
			_watched = play
		else:
			fight.remove_rule(self)

	func buff() -> FightBuff:
		return FightBuff.new(hero, ["card", "protection", "heal"])

	func protection(_fight: Fight, amount: int, target: FightHero, play: CardPlay) -> int:
		if play != null and play == _watched and amount > 0:
			_heals.append([target, amount])
		return amount

	func card_played(fight: Fight, play: CardPlay) -> void:
		if play != _watched:
			return
		fight.remove_rule(self)
		for heal in _heals:
			var target: FightHero = heal[0]
			fight.stats.healed(hero, heal[1])
			fight.tell("heal", { "player": target.name, "amount": heal[1] })


func after_effects(fight: Fight, play: CardPlay) -> void:
	var next := NextProtection.new()
	next.hero = play.hero
	fight.add_rule(next)
