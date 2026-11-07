extends CardAbility
## A hero's trait: when their Protection lowers an attack to 0, they may play a card with
## an attack, or use an item, at once, as the Dwarven Treasure Keeper does.


func hero_protected(fight: Fight, hero: FightHero, before: int, play: CardPlay) -> void:
	if not is_mine(play) or before <= 0 or hero.threat > 0:
		return
	await fight.take_action(owner, {
		"prompt": "prompt_attack_or_item",
		"limited": true,
		"can_skip": true,
		"only": func(card: Card) -> bool: return card.is_item() or card.has_symbol("attack"),
	})
