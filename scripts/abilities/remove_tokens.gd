extends CardAbility
## A hero removes some of their status tokens. The tokens are on the table, so the
## players are only told.
## values: "count" (2), "choose" (false): true for a hero of the players' choice,
## otherwise the hero who played the card, and "every_hero" (0): then each hero removes
## that many more, as with the Elixier der Sorglosigkeit.


func after_effects(fight: Fight, play: CardPlay) -> void:
	var count: int = value("count", 2)
	var hero := play.hero
	if value("choose", false):
		hero = await fight.choose_hero(fight.heroes, "prompt_remove_tokens_who", { "player": play.hero.name, "count": count })
	if hero != null:
		fight.tell("remove_tokens", { "player": hero.name, "count": count })
	var every: int = value("every_hero", 0)
	if every > 0:
		fight.tell("remove_tokens_everyone", { "count": every })
