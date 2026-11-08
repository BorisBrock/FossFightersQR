extends CardAbility
## The first time its hero plays the card in a round, they may take it back into their
## hand right after, as the Klingen-Jo-Jo, and play it again this round.


func after_effects(fight: Fight, play: CardPlay) -> void:
	if play.replay:
		return
	var earlier := fight.history.filter(func(other: CardPlay) -> bool:
		return other != play and other.hero == play.hero and other.card.qr == play.card.qr and other.round_number == play.round_number)
	if not earlier.is_empty():
		return
	play.hero.played.erase(play.card.qr)
	fight.tell("card_back_to_hand", { "player": play.hero.name, "card": play.card.title })
