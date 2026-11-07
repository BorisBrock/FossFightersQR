extends CardAbility
## The card's Heal and Draw are for a hero of the players' choice, such as the Toad
## Smoothie. With "action", that hero may then take an action at once, without using a
## turn, such as with the Chieftain's Horn.
## values: "action" (false).


var _chosen: FightHero


func before_effects(fight: Fight, play: CardPlay) -> void:
	_chosen = await fight.choose_hero(fight.heroes, "prompt_chosen_hero", { "player": play.hero.name })
	if _chosen != null:
		play.targets = [_chosen]


func after_effects(fight: Fight, _play: CardPlay) -> void:
	if value("action", false) and _chosen != null:
		await fight.play_actions(_chosen, 1, { "prompt": "prompt_free_play", "can_skip": true })
