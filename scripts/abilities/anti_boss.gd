extends CardAbility
## Prevents the boss's next @-ability of at most "strength", against anyone, as with the
## Anti-Boss-3000. The card is then out of the fight, which its uses_per_fight says.
## values: "strength" (5).


## In the fight until it has prevented an ability.
class Ward extends FightRule:
	var strength: int
	var title: Dictionary

	func boss_ability_used(fight: Fight, ability: BossAbility) -> void:
		if not ability.prevented and ability.strength <= strength:
			ability.prevent(title)
			fight.remove_rule(self)


func after_effects(fight: Fight, play: CardPlay) -> void:
	var ward := Ward.new()
	ward.strength = value("strength", 5)
	ward.title = play.card.title
	fight.add_rule(ward)
	fight.tell("ward_ready", { "player": play.hero.name, "card": play.card.title, "strength": ward.strength })
