extends CardAbility
## "If you have 15 health or more afterwards: …", such as the Troll's cards. The app does
## not know the heroes' health, so it asks the players.
## values: "health" (15), and what the hero then gets: "heal", "draw" or
## "remove_tokens", each a number.


func after_effects(fight: Fight, play: CardPlay) -> void:
	var hero := play.hero
	if not await fight.confirm("prompt_if_healthy", { "player": hero.name, "health": value("health", 15) }):
		return
	var heal: int = value("heal", 0)
	if heal > 0:
		fight.stats.healed(hero, heal)
		fight.tell("heal", { "player": hero.name, "amount": heal })
	var draw: int = value("draw", 0)
	if draw > 0:
		fight.tell("draw_cards", { "player": hero.name, "count": draw })
	var tokens: int = value("remove_tokens", 0)
	if tokens > 0:
		fight.tell("remove_tokens", { "player": hero.name, "count": tokens })
