extends CardAbility
## A hero's trait: their first attack each round ignores what the boss's shields do
## besides absorbing damage (Boss.shield_hit), as with the Elite Warrior.

var _round := 0
var _first: CardPlay


func card_playing(fight: Fight, play: CardPlay) -> void:
	if is_mine(play) and play.has_effect("attack") and _round != fight.round_number:
		_round = fight.round_number
		_first = play


func ignores_shield_effect(_fight: Fight, _kind: String, play: CardPlay) -> bool:
	return play != null and play == _first
