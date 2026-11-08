extends CardAbility
## The card lies by its hero for the rest of the fight, and when any hero would lose
## health, the players may discard it to prevent that, as with the Träne des Mitleids.
## Heroes lose health in ways the app does not see, such as from their tokens, so the
## players keep track of it on the table: they are only told.


func after_effects(fight: Fight, play: CardPlay) -> void:
	fight.tell("tear_placed", { "player": play.hero.name, "card": play.card.title })
