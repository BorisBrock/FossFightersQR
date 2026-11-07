extends CardAbility
## A hero's trait: each round, the first card of a kind they play gets a Lightning, such
## as the High Druid's first Protection.
## values: "symbol", a symbol the card needs, or "tag", one of its tags (Card.tags).

var _used_round := 0


func card_playing(fight: Fight, play: CardPlay) -> void:
	if not is_mine(play) or _used_round == fight.round_number or not _fits(play):
		return
	_used_round = fight.round_number
	play.add_effect("lightning", 1)


func _fits(play: CardPlay) -> bool:
	var symbol: String = value("symbol", "")
	if not symbol.is_empty() and play.has_effect(symbol):
		return true
	var tag: String = value("tag", "")
	return not tag.is_empty() and tag in play.card.tags
