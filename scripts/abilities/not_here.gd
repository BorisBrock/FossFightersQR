extends CardAbility
## A card the app does not use, such as the Fackel and the Machete, which only matter
## against one boss of the board game. It is refused with a note when scanned.


func can_play(_fight: Fight, _play: CardPlay) -> String:
	return "notice_not_here"
