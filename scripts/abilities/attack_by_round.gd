extends CardAbility
## The card's attack is as strong as the round: 1 in round 1, 2 in round 2, and so on,
## such as Krawumm. With "type" heal, its Heal is, as with the Lichtelixier, and with
## "chosen_hero", the card's Heal and Draw are for a hero of the players' choice, as with
## for_chosen_hero.
## values: "type", the symbol whose strength it sets ("attack"), "chosen_hero" (false).


func set_strength(fight: Fight, play: CardPlay) -> void:
	var type: String = value("type", "attack")
	for effect in play.effects:
		if effect.type == type:
			effect.strength = fight.round_number


func before_effects(fight: Fight, play: CardPlay) -> void:
	if not value("chosen_hero", false):
		return
	var chosen := await fight.choose_hero(fight.heroes, "prompt_chosen_hero", { "player": play.hero.name })
	if chosen != null:
		play.targets = [chosen]
