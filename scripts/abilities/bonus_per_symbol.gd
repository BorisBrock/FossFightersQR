extends CardAbility
## The card's effects of a symbol are stronger for each other card with that symbol the hero
## has played this round: Supports, as with the Geisterwolf, or Attacks, as with the
## Zeitschnitter.
## values: "symbol" (support), "bonus" (2), per card.


func before_effects(fight: Fight, play: CardPlay) -> void:
	var symbol: String = value("symbol", "support")
	var count := 0
	for earlier in fight.history:
		if earlier != play and earlier.hero == play.hero and earlier.round_number == fight.round_number \
				and not earlier.cancelled and earlier.card.has_symbol(symbol):
			count += 1
	if count > 0:
		play.boost(symbol, count * value("bonus", 2))
