extends CardAbility
## A hero's trait: the first time in their turn they hurt the boss with an attack, they
## play the top card of their draw pile, or use an item, as the Troll Chieftain does.

var _done := false


func turn_started(_fight: Fight, hero: FightHero) -> void:
	if hero == owner:
		_done = false


func card_played(fight: Fight, play: CardPlay) -> void:
	if _done or not is_mine(play) or fight.active_hero != owner or play.damage <= 0 or not play.has_effect("attack"):
		return
	_done = true
	await fight.take_action(owner, { "prompt": "prompt_top_card_or_item", "limited": true, "can_skip": true })
