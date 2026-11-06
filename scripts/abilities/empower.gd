extends CardAbility
## Strengthens one hero's cards until the end of the round, such as a Totem.
## values: "bonus" (1), and "type", the symbol it adds to ("attack").


## Stays in the fight for the round and adds the bonus to every card of its hero.
class Boost extends FightRule:
	var hero: FightHero
	var type: String
	var bonus: int

	func card_playing(_fight: Fight, play: CardPlay) -> void:
		if play.hero == hero:
			play.boost(type, bonus)


func after_effects(fight: Fight, play: CardPlay) -> void:
	var boost := Boost.new()
	boost.type = value("type", "attack")
	boost.bonus = value("bonus", 1)
	boost.hero = await fight.choose_hero(fight.heroes, "prompt_empower_who", { "player": play.hero.name })
	if boost.hero == null:
		return
	fight.add_rule(boost, true)
	fight.tell("empowered", { "player": boost.hero.name, "bonus": boost.bonus, "kind": Fight.NAMES.get(boost.type, boost.type) })
