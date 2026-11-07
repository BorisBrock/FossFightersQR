extends CardAbility
## The card's Supports are stronger for each other card with a Support the hero has played
## this round, as with the Geisterwolf.
## values: "bonus" (2), per card.


func before_effects(fight: Fight, play: CardPlay) -> void:
	var count := 0
	for earlier in fight.history:
		if earlier != play and earlier.hero == play.hero and earlier.round_number == fight.round_number \
				and not earlier.cancelled and earlier.card.has_symbol("support"):
			count += 1
	if count > 0:
		play.boost("support", count * value("bonus", 2))
