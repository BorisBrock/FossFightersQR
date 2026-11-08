extends CardAbility
## The dryad takes a form, whose perk she keeps until she takes another (FightHero.form).
## The form cards lie by her character card and can be played again and again
## (Card.stays_on_table).
## values: "form", one of FORMS: "thorn" (her attacks and supports +1), "blossom" (she
## heals 3 each time her attack or support costs the boss health) or "bark" (her
## Protection +1).

const FORMS: Array[String] = ["thorn", "blossom", "bark"]
const BONUS := 1
const BLOSSOM_HEAL := 3
## Where the hero's form keeps its perk in the fight, see FightHero.notes.
const NOTE := "dryad_form"


## The perk of the form a hero has, which stays in the fight until they take another.
class Perk extends FightRule:
	var hero: FightHero
	var form: String
	## By card being played: how often its attacks and supports cost the boss health.
	var _hits := {}

	func card_playing(_fight: Fight, play: CardPlay) -> void:
		if form == "thorn" and play.hero == hero:
			play.boost("attack", BONUS)
			play.boost("support", BONUS)

	func protection(_fight: Fight, amount: int, _hero: FightHero, play: CardPlay) -> int:
		if form == "bark" and play != null and play.hero == hero and amount > 0:
			return amount + BONUS
		return amount

	func damage_taken(_fight: Fight, amount: int, kind: String, play: CardPlay) -> int:
		if form == "blossom" and play != null and play.hero == hero and amount > 0 and kind in Fight.DAMAGE_TYPES:
			_hits[play] = _hits.get(play, 0) + 1
		return amount

	func card_played(fight: Fight, play: CardPlay) -> void:
		var hits: int = _hits.get(play, 0)
		_hits.erase(play)
		for i in hits:
			fight.stats.healed(hero, BLOSSOM_HEAL)
			fight.tell("heal", { "player": hero.name, "amount": BLOSSOM_HEAL })


func can_play(_fight: Fight, play: CardPlay) -> String:
	if play.hero.form == value("form", ""):
		return "notice_form_already"
	return ""


func after_effects(fight: Fight, play: CardPlay) -> void:
	var form: String = value("form", "")
	if not form in FORMS:
		push_warning("Card %s: unknown form '%s'" % [play.card.qr, form])
		return
	var hero := play.hero
	var old: FightRule = hero.notes.get(NOTE)
	if old != null:
		fight.remove_rule(old)
	var perk := Perk.new()
	perk.hero = hero
	perk.form = form
	hero.notes[NOTE] = perk
	fight.add_rule(perk)
	hero.form = form
	fight.hero_changed.emit(hero)
	fight.tell("form_" + form, { "player": hero.name })
