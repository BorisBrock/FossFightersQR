extends CardAbility
## Only a hero of one race or class can use the card, such as Opas Glasauge, which only the
## troll can use. For the cards of a race's or class's deck the fight checks this itself;
## this is for items, which can be used again in the same round.
## values: "race" or "hero_class" (or both: either will do).


func can_play(_fight: Fight, play: CardPlay) -> String:
	var race: String = value("race", "")
	var hero_class: String = value("hero_class", "")
	if (not race.is_empty() and play.hero.hero.race == race) or (not hero_class.is_empty() and play.hero.hero.hero_class == hero_class):
		return ""
	return "notice_not_your_card"
