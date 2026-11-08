extends CardAbility
## The card's Heal and Draw are for the heroes its Protection protected, instead of its
## hero, as with the Moosumhang and the Geweihte Rüstung. If it protected no one, no one
## heals or draws. With "action", each hero it protected may then take an action at once,
## without using a turn, as with the Smaragdschild.
## values: "action" (false).

## [type, strength] of the Heal and Draw effects taken from the card.
var _effects: Array[Array] = []


func before_effects(_fight: Fight, play: CardPlay) -> void:
	for i in range(play.effects.size() - 1, -1, -1):
		var effect := play.effects[i]
		if effect.type == "heal" or effect.type == "draw":
			_effects.push_front([effect.type, effect.strength])
			play.effects.remove_at(i)


func after_effects(fight: Fight, play: CardPlay) -> void:
	for effect in _effects:
		var amount: int = effect[1]
		if amount <= 0:
			continue
		for target in play.protected:
			if effect[0] == "heal":
				fight.stats.healed(play.hero, amount)
				fight.tell("heal", { "player": target.name, "amount": amount })
			else:
				fight.tell("draw_cards", { "player": target.name, "count": amount })
	if not value("action", false):
		return
	for target in play.protected:
		await fight.play_actions(target, 1, { "prompt": "prompt_free_play", "can_skip": true })
