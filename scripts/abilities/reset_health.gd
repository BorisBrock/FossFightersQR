extends CardAbility
## Each hero takes "tokens" status tokens, such as 2 fire, then a hero of the players'
## choice sets their health back to their starting health, as with the Phönixfeder. Health
## and tokens are on the table, so the players are only told. It happens before the card's
## symbols, so that the card's removal (remove_from_game) comes last, as the text says.
## values: "tokens" ({}), as token -> count, such as { "fire": 2 }.


func before_effects(fight: Fight, play: CardPlay) -> void:
	var tokens: Dictionary = value("tokens", {})
	if not tokens.is_empty():
		fight.tell("tokens_everyone", { "tokens": fight.token_text(tokens) })
		await fight.until_read()
	var chosen := await fight.choose_hero(fight.heroes, "prompt_reset_health_who", { "player": play.hero.name })
	if chosen != null:
		fight.tell("reset_health", { "player": chosen.name })
		await fight.until_read()
