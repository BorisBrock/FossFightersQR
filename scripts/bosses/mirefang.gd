extends Boss
## A dummy boss to build the screens with. Its hints describe rules that do not exist yet.


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
