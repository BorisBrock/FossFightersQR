extends CardAbility
## Strengthens one hero's cards until the end of the round, such as the Vulkan-Totem.
## It comes first on the card, so if the players choose the hero who plays it, the card's
## own effects of that type are stronger too. A card tagged "totem" gives that hero its
## totem token, which they give back when the round ends (Fight.has_totem).
## values: "bonus" (1), and "type", the symbol it adds to ("attack").


## Stays in the fight for the round and adds the bonus to every card of its hero.
class Boost extends FightRule:
	var hero: FightHero
	var type: String
	var bonus: int
	var totem := false

	func card_playing(_fight: Fight, play: CardPlay) -> void:
		if play.hero == hero:
			play.boost(type, bonus)

	func buff() -> FightBuff:
		var icons: Array[String] = [type]
		if totem:
			icons.push_front("totem")
		var shown := FightBuff.new(hero, icons, "%+d" % bonus)
		shown.totem = totem
		return shown


func before_effects(fight: Fight, play: CardPlay) -> void:
	var boost := Boost.new()
	boost.type = value("type", "attack")
	boost.bonus = value("bonus", 1)
	boost.totem = "totem" in card.tags
	boost.hero = await fight.choose_hero(fight.heroes, "prompt_empower_who", { "player": play.hero.name })
	if boost.hero == null:
		return
	fight.add_rule(boost, true)
	if boost.hero == play.hero:
		play.boost(boost.type, boost.bonus)
	var values := { "player": boost.hero.name, "bonus": boost.bonus, "kind": Fight.NAMES.get(boost.type, boost.type), "card": play.card.title }
	var id := "totem_" + boost.type
	fight.tell(id if boost.totem and Messages.has(id) else "empowered", values)
