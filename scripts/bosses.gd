class_name Bosses
extends RefCounted
## The bosses players can fight, and the difficulty levels. The boss list shows them in
## this order.
##
## These three are dummies to build the screens with. Replace them when the real bosses
## are designed: each needs a title, a tagline for the list, a story, a few hints and a
## picture (see art/import_boss_art.sh).

const BOSSES := {
	"mirefang": {
		"title": { "de": "Der alte Moorschlund", "en": "Old Mirefang" },
		"tagline": { "de": "Herr des versunkenen Moors", "en": "Lord of the Sunken Marsh" },
		"art": "res://assets/bosses/BossMirefang.png",
		"story": {
			"de": "Seit hundert Jahren schläft eine Kröte von der Größe eines Hauses im Schlamm unter dem Dorf Krummbach. Jetzt ist sie aufgewacht, und sie ist hungrig. Brücken versinken, Brunnen werden zu Sumpf, und wer nachts ans Ufer geht, kommt nicht wieder.",
			"en": "For a hundred years, a toad the size of a house has slept in the mud beneath the village of Crookbrook. Now it is awake, and it is hungry. Bridges sink, wells turn to swamp, and whoever walks the shore at night never comes back.",
		},
		"hints": [
			{ "de": "Taucht der Moorschlund ab, sammelt er Kraft. Nutzt die Zeit, um euch zu heilen.", "en": "When Mirefang dives, it gathers strength. Use the time to heal." },
			{ "de": "Seine Zunge packt immer den Helden mit den wenigsten Lebenspunkten. Schützt ihn.", "en": "Its tongue always grabs the hero with the least health. Protect them." },
			{ "de": "Feuer trocknet seine Haut aus und macht ihn verwundbar.", "en": "Fire dries out its skin and makes it vulnerable." },
		],
	},
	"ashwing": {
		"title": { "de": "Aschenschwinge", "en": "Ashwing" },
		"tagline": { "de": "Der Glutwurm vom Schwarzen Kamm", "en": "The Ember Wyrm of Blackridge" },
		"art": "res://assets/bosses/BossAshwing.png",
		"story": {
			"de": "Aschenschwinge war einst die Wächterin der Feuerberge. Seit ein Dieb ihr Ei gestohlen hat, brennt sie jedes Dorf nieder, das sie findet. Sie wird nicht ruhen, bis sie den Dieb gefunden hat, oder bis jemand sie aufhält.",
			"en": "Ashwing was once the guardian of the Fire Mountains. Ever since a thief stole its egg, it has burned every village it can find. It will not rest until it finds the thief, or until someone stops it.",
		},
		"hints": [
			{ "de": "Bevor Aschenschwinge Feuer speit, holt sie zwei Runden lang Luft. Haltet dann Schilde bereit.", "en": "Before Ashwing breathes fire, it draws breath for two turns. Have your shields ready." },
			{ "de": "Feuer heilt sie. Setzt auf Eis und Wasser.", "en": "Fire heals it. Rely on ice and water." },
			{ "de": "Am Boden ist sie schwach. Holt sie vom Himmel, dann schlagt gemeinsam zu.", "en": "It is weak on the ground. Bring it down, then strike together." },
		],
	},
	"colossus": {
		"title": { "de": "Der Messingkoloss", "en": "The Brass Colossus" },
		"tagline": { "de": "Maschine des irren Tüftlers", "en": "Engine of the Mad Tinker" },
		"art": "res://assets/bosses/BossColossus.png",
		"story": {
			"de": "Meister Zahnradius wollte eine Maschine bauen, die die Stadt beschützt. Doch der Koloss hat beschlossen, dass die Stadt am sichersten ist, wenn niemand mehr darin wohnt. Sein Erbauer ist verschwunden, und nur die Helden können ihn noch abschalten.",
			"en": "Master Gearwright wanted to build a machine to protect the city. But the colossus decided the city would be safest with nobody living in it. Its maker has vanished, and only the heroes can still switch it off.",
		},
		"hints": [
			{ "de": "Der Koloss wird mit jeder Runde heißer. Kühlt ihn ab, bevor er überhitzt und explodiert.", "en": "The colossus gets hotter every turn. Cool it down before it overheats and explodes." },
			{ "de": "Seine Panzerung hält normale Angriffe ab. Magie geht durch die Fugen.", "en": "Its armour stops ordinary attacks. Magic slips through the joints." },
			{ "de": "Wenn er stillsteht, lädt er nach. Das ist der Moment für den großen Schlag.", "en": "When it stands still, it is reloading. That is the moment for the big blow." },
		],
	},
}

const DIFFICULTIES := {
	"easy": {
		"title": { "de": "Leicht", "en": "Easy" },
		"description": { "de": "Für den ersten Kampf oder einen entspannten Abend.", "en": "For a first fight, or a relaxed evening." },
	},
	"normal": {
		"title": { "de": "Normal", "en": "Normal" },
		"description": { "de": "Der Boss, wie er gedacht ist.", "en": "The boss as it is meant to be." },
	},
	"hard": {
		"title": { "de": "Schwer", "en": "Hard" },
		"description": { "de": "Für erfahrene Helden. Jeder Fehler tut weh.", "en": "For seasoned heroes. Every mistake hurts." },
	},
}

const DEFAULT_DIFFICULTY := "normal"
