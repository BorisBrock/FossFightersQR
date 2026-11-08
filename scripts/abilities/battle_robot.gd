extends CardAbility
## A hero's trait, the Goblin Genius's: their battle robot. On the table it is three
## markers, one for each of PARTS. Each card of the hero with an effect of a part flips
## that marker; once all three are flipped, the robot works, and the hero's attacks are
## "bonus" stronger. It has "health": each card the hero plays afterwards costs it "wear",
## and each time the hero loses health, it loses as much. At 0 it is destroyed, its
## markers go back, and the hero can build it again.
## values: "bonus" (2), "health" (8), "wear" (1).

const PARTS: Array[String] = ["attack", "support", "protection"]

## The parts flipped so far, while the robot is not built.
var parts: Array[String] = []
## What is left of its health while it works, 0 while it does not.
var health := 0


func works() -> bool:
	return health > 0


func buff() -> FightBuff:
	if owner == null:
		return null
	var shown := FightBuff.new(owner, ["robot"])
	if works():
		shown.icons.append("attack")
		shown.text = "+%d" % value("bonus", 2)
		shown.bar = health
		shown.bar_max = value("health", 8)
	else:
		shown.icons.append_array(parts)
		shown.text = "%d/%d" % [parts.size(), PARTS.size()]
	return shown


func card_playing(_fight: Fight, play: CardPlay) -> void:
	if is_mine(play) and works():
		play.boost("attack", value("bonus", 2))


func card_played(fight: Fight, play: CardPlay) -> void:
	if not is_mine(play) or play.replay:
		return
	if works():
		await _damage(fight, value("wear", 1))
		return
	var flipped: Array[String] = []
	for part in PARTS:
		if not part in parts and play.has_effect(part):
			parts.append(part)
			flipped.append(part)
	if flipped.is_empty():
		return
	if parts.size() < PARTS.size():
		fight.buffs_changed.emit()
		fight.tell("robot_part", { "player": owner.name, "count": parts.size(), "total": PARTS.size() })
		return
	parts.clear()
	health = value("health", 8)
	fight.buffs_changed.emit()
	fight.tell("robot_built", { "player": owner.name, "bonus": value("bonus", 2), "health": health })


func hero_hurt(fight: Fight, hero: FightHero, amount: int, _play: CardPlay) -> void:
	if hero == owner and works():
		await _damage(fight, amount)


func _damage(fight: Fight, amount: int) -> void:
	if amount <= 0:
		return
	health = maxi(0, health - amount)
	fight.buffs_changed.emit()
	if not works():
		fight.tell("robot_destroyed", { "player": owner.name })
