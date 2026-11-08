extends CardAbility
## Until the end of the round, each hero the card's Protection protected may remove "count"
## of their status tokens for each Lightning on the cards they play, as with the
## Donner-Totem. Lightning that gives no action (CardPlay.ignore_lightning) and cards
## played once more (CardPlay.replay) do not count. A card tagged "totem" gives each of
## those heroes its totem token, which they give back when the round ends.
## values: "count" (1), tokens per Lightning.


## In the fight until the end of the round.
class TokensPerLightning extends FightRule:
	var hero: FightHero
	var count: int
	var totem := false
	## The card that made this, whose own Lightning does not count.
	var source: CardPlay

	func card_played(fight: Fight, play: CardPlay) -> void:
		if play == source or play.replay or play.cancelled or play.ignore_lightning or play.hero != hero:
			return
		var lightning := play.strength_of("lightning")
		if lightning > 0:
			fight.tell("remove_tokens", { "player": hero.name, "count": lightning * count })

	func buff() -> FightBuff:
		var icons: Array[String] = ["lightning"]
		if totem:
			icons.push_front("totem")
		var shown := FightBuff.new(hero, icons, "-%d" % count)
		shown.totem = totem
		return shown


func after_effects(fight: Fight, play: CardPlay) -> void:
	for protected in play.protected:
		var rule := TokensPerLightning.new()
		rule.hero = protected
		rule.count = value("count", 1)
		rule.totem = "totem" in card.tags
		rule.source = play
		fight.add_rule(rule, true)
		fight.tell("totem_lightning" if rule.totem else "tokens_per_lightning", { "player": protected.name, "count": rule.count, "card": play.card.title })
