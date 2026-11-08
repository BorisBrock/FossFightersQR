extends CardAbility
## Whether the boss's shield of "kind" was already broken (at 0) before the card took
## effect changes what it does, as with the Klauenstutzer and the Raketenrucksack.
## While it was not, the card's effects of "type" have strength "otherwise", if given.
## If it was, with "use_item", the hero uses an item at once afterwards.
## values: "kind" (ranged), "type" (support), "otherwise", "use_item" (false).

var _broken := false


func set_strength(fight: Fight, play: CardPlay) -> void:
	_broken = fight.shields.get(value("kind", "ranged"), 0) <= 0
	if _broken or not values.has("otherwise"):
		return
	for effect in play.effects:
		if effect.type == value("type", "support"):
			effect.strength = int(value("otherwise", 0))


func after_effects(fight: Fight, play: CardPlay) -> void:
	if not _broken or not value("use_item", false):
		return
	var item := await fight.take_action(play.hero, {
		"prompt": "prompt_use_item",
		"limited": true,
		"can_skip": true,
		"only": func(card: Card) -> bool: return card.is_item(),
	})
	if item != null:
		fight.give_actions(play, item.extra_actions)
