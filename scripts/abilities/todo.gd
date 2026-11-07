extends CardAbility
## A placeholder for a card whose ability is not written yet, such as one with the special
## symbol (*). It does nothing beyond the card's symbols and warns when the card is played,
## so that the card can be recorded now and its real ability given later.


func before_effects(_fight: Fight, _play: CardPlay) -> void:
	push_warning("Card %s: its ability is still the placeholder 'todo'" % card.qr)
