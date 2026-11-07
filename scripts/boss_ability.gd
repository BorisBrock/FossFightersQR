class_name BossAbility
extends RefCounted
## One use of one of the boss's @-abilities, which cards can prevent. See
## Fight.boss_ability() and FightRule.boss_ability_used().

## Which of the boss's abilities it is, for the boss's own code.
var id := ""
## Its number on the @, such as 5 for "@-Fähigkeit 5".
var strength := 0
## The hero it is used against, or null for one against everyone or none.
var target: FightHero
var prevented := false
## The title of what prevented it, such as a card's, for the message.
var prevented_by := {}


## Stops it, for the reason of title.
func prevent(title: Dictionary) -> void:
	prevented = true
	prevented_by = title

