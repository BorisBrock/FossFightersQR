extends CardAbility
## The card's Heal and Draw are for every hero, such as the King's Rune.


func before_effects(fight: Fight, play: CardPlay) -> void:
	play.targets = fight.heroes.duplicate()
