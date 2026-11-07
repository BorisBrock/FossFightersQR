extends CardAbility
## The card lies by its hero for the rest of the fight. When the boss uses an @-ability
## against them, the players may discard it to prevent that, as with the Raven's Curse.
## Until then it cannot be played again.


## In the fight while the card lies by its hero.
class Ward extends FightRule:
	var hero: FightHero
	var card: Card

	func boss_ability_used(fight: Fight, ability: BossAbility) -> void:
		if ability.prevented or ability.target != hero:
			return
		if await fight.confirm("prompt_use_ward", { "player": hero.name, "card": card.title, "boss": fight.boss.title }):
			ability.prevent(card.title)
			fight.remove_rule(self)
			hero.notes.erase(Ward.key(card))

	static func key(for_card: Card) -> String:
		return "ward " + for_card.qr


func can_play(_fight: Fight, play: CardPlay) -> String:
	return "notice_still_in_play" if play.hero.notes.has(Ward.key(play.card)) else ""


func after_effects(fight: Fight, play: CardPlay) -> void:
	var ward := Ward.new()
	ward.hero = play.hero
	ward.card = play.card
	play.hero.notes[Ward.key(play.card)] = true
	fight.add_rule(ward)
	fight.tell("ward_placed", { "player": play.hero.name, "card": play.card.title })
