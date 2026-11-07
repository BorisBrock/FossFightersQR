extends CardAbility
## If the card's attack breaks a shield of the boss, the boss loses "damage" health at once,
## as with the Kristallorb. While the card takes effect, the ability is a rule of the fight
## that sees the shield break.
## values: "damage" (3).

var _play: CardPlay


func before_effects(fight: Fight, play: CardPlay) -> void:
	_play = play
	fight.add_rule(self)


func after_effects(fight: Fight, _play_done: CardPlay) -> void:
	fight.remove_rule(self)


func shield_broken(fight: Fight, _kind: String, play: CardPlay) -> void:
	if play == null or play != _play:
		return
	var damage: int = value("damage", 3)
	fight.tell("shield_breaker", { "player": play.hero.name, "boss": fight.boss.title, "damage": damage })
	await fight.deal_damage(damage, Fight.DIRECT, play)
