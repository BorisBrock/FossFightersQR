extends CardAbility
## A hero's trait: whenever they lose health, they may draw, as the Archmage does.
## values: "count" (1).


func hero_hurt(fight: Fight, hero: FightHero, _amount: int, _play: CardPlay) -> void:
	if hero == owner:
		fight.tell("may_draw", { "player": owner.name, "count": value("count", 1) })
