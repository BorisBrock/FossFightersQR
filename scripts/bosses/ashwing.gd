extends Boss
## A dummy boss to build the screens with. Its hints describe rules that do not exist yet.


func _init() -> void:
	title = { "de": "Aschenschwinge", "en": "Ashwing" }
	tagline = { "de": "Der Glutwurm vom Schwarzen Kamm", "en": "The Ember Wyrm of Blackridge" }
	story = {
		"de": "Aschenschwinge war einst die Wächterin der Feuerberge. Seit ein Dieb ihr Ei gestohlen hat, brennt sie jedes Dorf nieder, das sie findet. Sie wird nicht ruhen, bis sie den Dieb gefunden hat, oder bis jemand sie aufhält.",
		"en": "Ashwing was once the guardian of the Fire Mountains. Ever since a thief stole its egg, it has burned every village it can find. It will not rest until it finds the thief, or until someone stops it.",
	}
	hints = [
		{ "de": "Bevor Aschenschwinge Feuer speit, holt sie zwei Runden lang Luft. Haltet dann Schilde bereit.", "en": "Before Ashwing breathes fire, it draws breath for two turns. Have your shields ready." },
		{ "de": "Feuer heilt sie. Setzt auf Eis und Wasser.", "en": "Fire heals it. Rely on ice and water." },
		{ "de": "Am Boden ist sie schwach. Holt sie vom Himmel, dann schlagt gemeinsam zu.", "en": "It is weak on the ground. Bring it down, then strike together." },
	]
	art = "res://assets/bosses/BossAshwing.png"
	figure = "res://assets/bosses/FigureAshwing.png"
	background = "res://assets/bosses/BackgroundAshwing.png"
	health = 40
	ambience = Ambience.EMBERS
	ambience_color = Color(1.0, 0.6, 0.25)
	mist_color = Color(0.45, 0.3, 0.25)
	motion = Motion.HOVER
	motion_amount = 18.0
	motion_seconds = 3.0
