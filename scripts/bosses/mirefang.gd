extends Boss
## A dummy boss to build the screens with. Its hints describe rules that do not exist yet,
## except for its venomous bite, which shows how a boss plans its own attacks.


func _init() -> void:
	title = { "de": "Der alte Moorschlund", "en": "Old Mirefang" }
	tagline = { "de": "Herr des versunkenen Moors", "en": "Lord of the Sunken Marsh" }
	story = {
		"de": "Seit hundert Jahren schläft eine Kröte von der Größe eines Hauses im Schlamm unter dem Dorf Krummbach. Jetzt ist sie aufgewacht, und sie ist hungrig. Brücken versinken, Brunnen werden zu Sumpf, und wer nachts ans Ufer geht, kommt nicht wieder.",
		"en": "For a hundred years, a toad the size of a house has slept in the mud beneath the village of Crookbrook. Now it is awake, and it is hungry. Bridges sink, wells turn to swamp, and whoever walks the shore at night never comes back.",
	}
	hints = [
		{ "de": "Taucht der Moorschlund ab, sammelt er Kraft. Nutzt die Zeit, um euch zu heilen.", "en": "When Mirefang dives, it gathers strength. Use the time to heal." },
		{ "de": "Seine Zunge packt immer den Helden mit den wenigsten Lebenspunkten. Schützt ihn.", "en": "Its tongue always grabs the hero with the least health. Protect them." },
		{ "de": "Feuer trocknet seine Haut aus und macht ihn verwundbar.", "en": "Fire dries out its skin and makes it vulnerable." },
	]
	art = "res://assets/bosses/BossMirefang.png"
	figure = "res://assets/bosses/FigureMirefang.png"
	background = "res://assets/bosses/BackgroundMirefang.png"
	health = 48
	ambience = Ambience.FIREFLIES
	ambience_color = Color(0.75, 1.0, 0.45)
	mist_color = Color(0.55, 0.7, 0.45)
	motion = Motion.BREATHE
	motion_amount = 16.0
	motion_seconds = 4.5
	taunt = {
		"de": "Quaaak! Ich hab seit hundert Jahren nichts gegessen. Wie nett, dass ihr vorbeikommt.",
		"en": "Croooak! I have not eaten in a hundred years. How kind of you to drop by.",
	}


## Its strongest attack each round is a venomous bite, which poisons. With a tie, the
## players choose who is bitten. The poison icon on that hero's attack shows it; nothing
## is told.
func plan_attacks(fight: Fight) -> void:
	super(fight)
	var strongest := 0
	for hero in fight.heroes:
		strongest = maxi(strongest, hero.threat)
	if strongest == 0:
		return
	var candidates := fight.heroes_where(func(hero: FightHero) -> bool: return hero.threat == strongest)
	var bitten := await fight.choose_hero(candidates, "prompt_tied_target", { "boss": title })
	if bitten != null:
		fight.threaten(bitten, bitten.threat, { "poison": 1 })
