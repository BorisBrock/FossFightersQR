extends CardAbility
## The hero gets more turns, such as a 4th action next round from a Warhorse.
## values: "turns" (1), and "now" (false): true for this round, otherwise the next.


func after_effects(fight: Fight, play: CardPlay) -> void:
	var turns: int = value("turns", 1)
	if value("now", false):
		play.hero.turns_left += turns
		fight.tell("extra_turns_now", { "player": play.hero.name, "count": turns })
	else:
		play.hero.bonus_turns += turns
		fight.tell("extra_turns_next_round", { "player": play.hero.name, "count": turns })
	fight.hero_changed.emit(play.hero)
