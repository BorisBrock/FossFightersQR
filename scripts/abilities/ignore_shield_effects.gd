extends CardAbility
## The card's attacks do not set off what the boss's shields do besides absorbing damage
## (Boss.shield_hit), as with the Arkanfalter. While the card takes effect, the ability
## is a rule of the fight, which says so for this card only.

var _play: CardPlay


func before_effects(fight: Fight, play: CardPlay) -> void:
	_play = play
	fight.add_rule(self)


func after_effects(fight: Fight, _play_done: CardPlay) -> void:
	fight.remove_rule(self)


func ignores_shield_effect(_fight: Fight, _kind: String, play: CardPlay) -> bool:
	return play != null and play == _play
