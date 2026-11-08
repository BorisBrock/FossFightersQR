extends CardAbility
## From now on, each of the boss's poison tokens costs it more health at the end of the
## round, as with the Toxikum. Its uses_per_fight takes it out of the fight afterwards.
## values: "damage" (1), more per token.


## In the fight from the card on, until its end.
class Toxin extends FightRule:
	var damage: int

	func poison_damage(fight: Fight, amount: int) -> int:
		return amount + fight.poison * damage

	func buff() -> FightBuff:
		return FightBuff.new(null, ["poison"], "%+d" % damage)


func after_effects(fight: Fight, play: CardPlay) -> void:
	var toxin := Toxin.new()
	toxin.damage = value("damage", 1)
	fight.add_rule(toxin)
	fight.tell("toxin_ready", { "player": play.hero.name, "card": play.card.title, "damage": toxin.damage })
