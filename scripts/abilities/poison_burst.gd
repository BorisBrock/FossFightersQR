extends CardAbility
## The boss loses "damage" health at once for each of its poison tokens, past its shields,
## as with the Stab der Vergiftung. With "clear", its poison tokens are gone afterwards, as
## with the Giftexplosion. The poison symbol on these cards only shows what they are about:
## it gives the boss no poison, so the card counts the tokens the boss already has.
## values: "damage" (1), "clear" (false).


func before_effects(_fight: Fight, play: CardPlay) -> void:
	for i in range(play.effects.size() - 1, -1, -1):
		if play.effects[i].type == "poison":
			play.effects.remove_at(i)


func after_effects(fight: Fight, play: CardPlay) -> void:
	var poison := fight.poison
	if poison <= 0:
		fight.tell("poison_burst_none", { "boss": fight.boss.title, "card": play.card.title })
		return
	var damage: int = value("damage", 1) * poison
	fight.tell("poison_burst", { "boss": fight.boss.title, "card": play.card.title, "poison": poison, "damage": damage })
	await fight.until_read()
	await fight.deal_damage(damage, Fight.DIRECT, play)
	if value("clear", false) and not fight.over:
		fight.set_poison(0)
		fight.tell("poison_cleared", { "boss": fight.boss.title })
