extends CardAbility
## A hero's trait: their Supports deal more damage if they have played an attack of that
## type themselves this round, as the Elven Keeper's do.
## values: "bonus" (2).

var _round := 0
var _attacked: Array[String] = []


func card_playing(fight: Fight, play: CardPlay) -> void:
	if not is_mine(play):
		return
	_forget_old(fight)
	for effect in play.effects:
		if effect.type == "support" and effect.damage_type in _attacked:
			effect.strength += value("bonus", 2)


func card_played(fight: Fight, play: CardPlay) -> void:
	if not is_mine(play) or play.cancelled:
		return
	_forget_old(fight)
	for effect in play.effects:
		if effect.type == "attack" and not effect.damage_type in _attacked:
			_attacked.append(effect.damage_type)


func _forget_old(fight: Fight) -> void:
	if _round != fight.round_number:
		_round = fight.round_number
		_attacked.clear()
