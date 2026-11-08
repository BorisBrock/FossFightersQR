extends CardAbility
## A card that is wound up and let go in turn, as the Aufziehbare Ratte: after each time
## its hero plays it, it switches. Not wound up, only its Lightning works, and the hero
## shuffles it back into their draw pile instead of the play area, wound up. Wound up,
## only its other effects work, and it is discarded as usual, no longer wound up. Each
## card starts a fight not wound up. A replay takes effect as the play it repeats.

## By hero: the QR codes of their cards that are wound up (FightHero.notes).
const NOTE := "wound_up"

var _wound := false


func before_effects(_fight: Fight, play: CardPlay) -> void:
	var wound: Array = play.hero.notes.get_or_add(NOTE, [])
	_wound = play.card.qr in wound
	if play.replay:
		_wound = not _wound
	elif _wound:
		wound.erase(play.card.qr)
	else:
		wound.append(play.card.qr)
	# Only the card's own symbols, not what rules gave it.
	for i in play.card.symbols.size():
		var symbol := play.card.symbols[i]
		if (symbol.type == "lightning") == _wound:
			_remove_first(play, symbol.type)


func after_effects(fight: Fight, play: CardPlay) -> void:
	if _wound or play.replay:
		return
	play.hero.played.erase(play.card.qr)
	fight.tell("card_wound_up", { "player": play.hero.name, "card": play.card.title })


func _remove_first(play: CardPlay, type: String) -> void:
	for i in play.effects.size():
		if play.effects[i].type == type:
			play.effects.remove_at(i)
			return
