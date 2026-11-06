extends Boss
## A dummy boss to build the screens with. Its hints describe rules that do not exist yet,
## except for its armour, which shows how a boss changes a rule.


func _init() -> void:
	title = { "de": "Der Messingkoloss", "en": "The Brass Colossus" }
	tagline = { "de": "Maschine des irren Tüftlers", "en": "Engine of the Mad Tinker" }
	story = {
		"de": "Meister Zahnradius wollte eine Maschine bauen, die die Stadt beschützt. Doch der Koloss hat beschlossen, dass die Stadt am sichersten ist, wenn niemand mehr darin wohnt. Sein Erbauer ist verschwunden, und nur die Helden können ihn noch abschalten.",
		"en": "Master Gearwright wanted to build a machine to protect the city. But the colossus decided the city would be safest with nobody living in it. Its maker has vanished, and only the heroes can still switch it off.",
	}
	hints = [
		{ "de": "Der Koloss wird mit jeder Runde heißer. Kühlt ihn ab, bevor er überhitzt und explodiert.", "en": "The colossus gets hotter every turn. Cool it down before it overheats and explodes." },
		{ "de": "Seine Panzerung hält normale Angriffe ab. Magie geht durch die Fugen.", "en": "Its armour stops ordinary attacks. Magic slips through the joints." },
		{ "de": "Wenn er stillsteht, lädt er nach. Das ist der Moment für den großen Schlag.", "en": "When it stands still, it is reloading. That is the moment for the big blow." },
	]
	art = "res://assets/bosses/BossColossus.png"
	figure = "res://assets/bosses/FigureColossus.png"
	background = "res://assets/bosses/BackgroundColossus.png"
	health = 60
	ambience = Ambience.DUST
	ambience_color = Color(1.0, 0.85, 0.55)
	mist_color = Color(0.6, 0.5, 0.38)
	motion = Motion.SWAY
	motion_amount = 10.0
	motion_seconds = 5.0
	taunt = {
		"de": "Bedrohung erkannt. Beginne Säuberung der Stadt.",
		"en": "Threat detected. Commencing city cleansing.",
	}


## Its armour halves melee and ranged damage, rounded down. Magic slips through.
func damage_taken(_fight: Fight, amount: int, kind: String, _play: CardPlay) -> int:
	return amount if kind == "magic" else floori(amount / 2.0)
