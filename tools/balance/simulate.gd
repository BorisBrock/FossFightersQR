extends SceneTree
## Balance simulator: plays many fights against a boss with random parties and an AI for
## the players, and sums up how they went. See docs/balance.md.
##
##   godot --headless -s tools/balance/simulate.gd -- --games 200
##   godot --headless -s tools/balance/simulate.gd -- --players 2 --difficulty normal --set health=70
##
## The fight is the game's own (Fight, the boss's script, the card abilities), so the rules
## cannot drift from the app. What the app leaves to the table is played here: the heroes'
## decks, hands, health and status tokens, and the players' choices.

const CATALOG := "res://cards/cards.json"
const RACES: Array[String] = ["halfling", "dwarf", "elf", "troll", "goblin", "dryad"]
const CLASSES: Array[String] = ["paladin", "magician", "warrior", "thief", "druid", "shaman"]

## The items of the base game, by German title, unless --no-items. Fackel and Machete are only
## for a boss of the board game, Passen is the pass card.
const ITEMS: Array[String] = ["Heiltrank", "Rucksack", "Medizintasche", "Trinkschlauch", "Glücksbringer", "Opas Glasauge"]
const SEATS: Array[int] = [0, 2, 3, 5]
## Below this score, a hero rather passes and keeps their cards for the next round.
const PASS_BELOW := 0.5


## Messages that are only to read, or ask for nothing that matters to the simulated table.
const READ_ONLY: Array[String] = [
	"boss_taunt", "first_round", "boss_planning", "phase_action", "phase_attack_blocked", "boss_poison", "victory", "defeat",
	"support_without_attack", "mirefang_surfaces", "mirefang_out_of_reach", "boss_ability_prevented",
	"totems_returned", "totem_lightning", "shield_breaker", "card_repeated", "nothing_to_repeat",
	"attacks_weakened", "attacks_weakened_next_round", "attack_redirected", "attack_halved",
	"attack_effects_removed", "attack_delayed", "attack_cancelled", "delayed_attack_now",
	"threat_lowered", "threat_lowers_on_attack", "shields_lowered", "shield_lowered", "no_shield_to_lower",
	"shield_broken_poison", "next_cards_boosted", "poison_burst", "poison_burst_none", "poison_cleared",
	"poison_on_attack", "poison_on_attack_ready", "toxin_ready", "robot_part", "robot_built", "robot_destroyed",
	"extra_turns_now", "extra_turns_next_round", "card_wound_up", "play_from_top_rest", "random_hand_cards",
	"ward_placed", "ward_ready", "tear_placed", "totem_attack", "totem_support", "totem_protection", "transfer_health", "random_hand_reminder", "form_thorn", "form_blossom", "form_bark", "remove_curse",
]


## A hero at the table: what the app does not know.
class SimHero:
	var name := ""
	var race := ""
	var hero_class := ""
	var fight_hero: FightHero
	var max_health := 0
	var health := 0
	var hand_limit := 0
	## The top is the back.
	var pile: Array[Card] = []
	var hand: Array[Card] = []
	var discard: Array[Card] = []
	var play_area: Array[Card] = []
	## Items and the dryad's forms, which lie by the hero.
	var table: Array[Card] = []
	var removed: Array[Card] = []
	## Cards drawn to be played at once (draw_and_play).
	var drawn: Array[Card] = []
	var tokens := { "poison": 0, "panic": 0, "paralysis": 0, "fire": 0 }
	var max_poison := 0
	## Health lost to the boss (its attacks, bite and other abilities) and fire, not to poison or
	## their own cards: what the planner expects each round.
	var taken := 0
	## Health lost, by cause.
	var lost := {}


## One fight being played.
class Game:
	var fight: Fight
	var heroes: Array[SimHero] = []
	var by_name := {}
	var rng := RandomNumberGenerator.new()
	var dead: SimHero
	var death_cause := ""
	## The hero marked for the boss's bite this round.
	var bitten := ""
	var dives := 0
	var enraged_round := 0
	var spits := 0
	var poison_shield_hits := 0
	## The most poison tokens on the table at once, all heroes together.
	var max_poison_table := 0
	var cards_played := 0
	var passes := 0
	var unhandled := {}
	var log := false
	## The card the hero is playing, for the choices it asks for.
	var playing: Card
	## The round the boss last spat venom, once a round.
	var spat_round := 0


var _db: CardDatabase
var _cards: Array[Card] = []
var _options := {
	"boss": "mirefang",
	"games": 200,
	"players": [1, 2, 3, 4],
	"difficulty": ["easy", "normal", "hard"],
	"level": 1,
	"loot": 10,
	"items": true,
	"health": 0,
	"hand": 0,
	"set": {},
	"seed": 1,
	"max_rounds": 40,
	## Poison tokens in the game box.
	"tokens": 16,
	"csv": "",
	"log": false,
	## "planner" or "greedy", the older AI, see docs/balance.md.
	"ai": "planner",
}
var _game: Game
var _rows: Array[Dictionary] = []


func _initialize() -> void:
	if not _parse_args(OS.get_cmdline_user_args()):
		quit(2)
		return
	_db = CardDatabase.load_file(CATALOG)
	for card: Card in _db._cards_by_qr.values():
		_cards.append(card)
	_cards.sort_custom(func(a: Card, b: Card) -> bool: return a.qr < b.qr)
	_print_setup()
	var summaries: Array[Dictionary] = []
	var game_index := 0
	for players: int in _options.players:
		for difficulty: String in _options.difficulty:
			var results: Array[Dictionary] = []
			for i in _options.games:
				var result := _play(players, difficulty, _options.seed + game_index, _options.log and game_index == 0)
				game_index += 1
				results.append(result)
				_rows.append(result)
			summaries.append(_summarize(players, difficulty, results))
	_print_summaries(summaries)
	_print_rounds(summaries)
	_print_by_hero()
	_print_unhandled()
	if not _options.csv.is_empty():
		_write_csv(_options.csv)
	quit(0)


#region One fight
func _play(players: int, difficulty: String, game_seed: int, log := false) -> Dictionary:
	var game := Game.new()
	_game = game
	game.log = log
	game.rng.seed = game_seed
	var party := _random_party(players)
	var boss := Bosses.create(_options.boss)
	for key: String in _options.set:
		_override(boss, key, _options.set[key])
	game.fight = Fight.new(boss, difficulty, party, _db)
	game.fight.rng.seed = game_seed * 7919 + 13
	for fight_hero in game.fight.heroes:
		var hero: SimHero = game.by_name[fight_hero.name]
		hero.fight_hero = fight_hero
		game.heroes.append(hero)
	_deal_cards(players)
	game.fight.message.connect(_on_message)
	if log:
		print("\n=== Example fight: %s ===" % ", ".join(game.heroes.map(func(h: SimHero) -> String: return "%s %s/%s" % [h.name, h.race, h.hero_class])))
		game.fight.card_played.connect(func(play: CardPlay) -> void:
			print("    %s plays %s (dmg %d, shield %d)" % [play.hero.name, play.card.title.get("de", play.card.qr), play.damage, play.shield_damage]))
	var fight := game.fight
	var outcome := ""
	fight.start()
	var steps := 0
	while true:
		steps += 1
		if game.dead != null and not fight.over:
			fight.lose()
		if fight.over:
			outcome = "won" if fight.health == 0 else "lost"
			break
		if fight.round_number > _options.max_rounds or steps > 100000:
			fight.abandon()
			outcome = "timeout"
			break
		if fight._unread > 0 or fight._screen_holds > 0:
			fight.players_ready()
			while fight._screen_holds > 0:
				fight.release_screen()
		elif fight.request != null:
			_answer(fight.request)
		else:
			push_error("The fight waits for nothing (round %d, phase %d)" % [fight.round_number, fight.phase])
			fight.abandon()
			outcome = "stuck"
			break
	var lowest := 1.0
	for hero in game.heroes:
		lowest = minf(lowest, maxf(0.0, hero.health) / hero.max_health)
	var result := {
		"players": players,
		"difficulty": difficulty,
		"seed": game_seed,
		"outcome": outcome,
		"rounds": fight.round_number,
		"boss_health": fight.health,
		"boss_max": fight.max_health,
		"dives": game.dives,
		"enraged_round": game.enraged_round,
		"spits": game.spits,
		"poison_shield_hits": game.poison_shield_hits,
		"death_cause": game.death_cause,
		"dead_hero": "%s/%s" % [game.dead.race, game.dead.hero_class] if game.dead != null else "",
		"lowest_health": lowest,
		"cards_played": game.cards_played,
		"passes": game.passes,
		"party": game.heroes.map(func(h: SimHero) -> String: return "%s/%s" % [h.race, h.hero_class]),
		"max_poison": game.heroes.reduce(func(m: int, h: SimHero) -> int: return maxi(m, h.max_poison), 0),
		"max_poison_table": game.max_poison_table,
		"lost": {},
	}
	for hero in game.heroes:
		for cause: String in hero.lost:
			result.lost[cause] = result.lost.get(cause, 0) + hero.lost[cause]
	for id: String in game.unhandled:
		_unhandled[id] = _unhandled.get(id, 0) + game.unhandled[id]
	if log:
		print("=== %s after %d rounds, boss at %d/%d ===\n" % [outcome, fight.round_number, fight.health, fight.max_health])
	return result


var _unhandled := {}


func _random_party(players: int) -> Array[Party.Hero]:
	var races := RACES.duplicate()
	var classes := CLASSES.duplicate()
	_shuffle(races)
	_shuffle(classes)
	var party: Array[Party.Hero] = []
	for i in players:
		var hero := Party.Hero.new()
		hero.name = "H%d" % (i + 1)
		hero.race = races[i]
		hero.hero_class = classes[i]
		hero.seat = SEATS[i]
		hero.race_card = _level_card("race", hero.race)
		hero.class_card = _level_card("hero_class", hero.hero_class)
		party.append(hero)
		var sim := SimHero.new()
		sim.name = hero.name
		sim.race = hero.race
		sim.hero_class = hero.hero_class
		sim.max_health = _options.health if _options.health > 0 else HeroOptions.RACES[hero.race].health + HeroOptions.CLASSES[hero.hero_class].health
		sim.hand_limit = _options.hand if _options.hand > 0 else HeroOptions.hand_limit(hero.race, hero.hero_class)
		sim.health = sim.max_health
		_game.by_name[hero.name] = sim
	return party


## The QR code of the highest card for the hero's race or class up to --level.
func _level_card(field: String, value: String) -> String:
	var best: Card
	for card in _cards:
		if card.get(field) == value and card.level <= _options.level and (best == null or card.level > best.level):
			best = card
	return best.qr if best != null else ""


## Race and class deck, and one loot card of each level up to --loot, none twice in the
## party. Items and forms lie on the table.
func _deal_cards(_players: int) -> void:
	var taken := {}
	for hero in _game.heroes:
		var deck: Array[Card] = []
		for card in _cards:
			if card.deck == hero.race or card.deck == hero.hero_class:
				deck.append(card)
		for level in range(1, _options.loot + 1):
			var choices := _cards.filter(func(card: Card) -> bool:
				return card.deck == "loot" and card.level == level and not taken.has(card.qr))
			if choices.is_empty():
				continue
			var loot: Card = choices[_game.rng.randi() % choices.size()]
			taken[loot.qr] = true
			deck.append(loot)
		if _options.items:
			for card in _cards:
				if card.is_item() and card.title.get("de", "") in ITEMS:
					deck.append(card)
		for card in deck:
			if card.stays_on_table():
				hero.table.append(card)
			else:
				hero.pile.append(card)
		_shuffle(hero.pile)
		_draw(hero, hero.hand_limit)
#endregion


#region What the players answer
func _answer(request: Fight.Request) -> void:
	match request.kind:
		Fight.Request.Kind.ACTION:
			_answer_action(request)
		Fight.Request.Kind.HERO:
			_game.fight.choose(_choose_hero(request))
		Fight.Request.Kind.OPTION:
			_game.fight.choose_option(_choose_option(request))
		Fight.Request.Kind.SHIELD:
			_game.fight.choose_shield(_choose_shield(request))


func _answer_action(request: Fight.Request) -> void:
	var fight := _game.fight
	var hero: SimHero = _game.by_name[request.hero.name]
	if request.prompt != "prompt_play_drawn":
		_flush_drawn(hero)
	var candidates := _candidates(hero, request.prompt, request.values)
	var scored: Array[Array] = []
	if _options.ai == "planner":
		scored = _plan_scores(hero, candidates, request)
	else:
		for candidate: Array in candidates:
			scored.append([_score(hero, candidate[0]), candidate[0], candidate[1]])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var threshold := -INF
	match request.prompt:
		"prompt_action":
			threshold = PASS_BELOW
		"prompt_free_play", "prompt_top_card_or_item", "prompt_attack_or_item":
			threshold = 0.0
	# Panic: hand cards at random, one token less each.
	if hero.tokens.panic > 0 and request.prompt == "prompt_action":
		var from_hand := scored.filter(func(entry: Array) -> bool: return entry[2] == "hand")
		if not from_hand.is_empty():
			var pick: Array = from_hand[_game.rng.randi() % from_hand.size()]
			scored = [pick]
			threshold = -INF
			hero.tokens.panic -= 1
	for entry: Array in scored:
		var card: Card = entry[1]
		var source: String = entry[2]
		# The planner uses an item for any gain: it costs an action, but no card.
		var least := minf(threshold, 0.05) if _options.ai == "planner" and source == "table" else threshold
		if entry[0] < least:
			continue
		_game.playing = card
		_take(hero, card, source)
		if fight.scan(card) == "":
			_game.cards_played += 1
			return
		_untake(hero, card, source)
	_game.passes += 1
	fight.pass_action()


## What the hero can play now, as [card, where it is].
func _candidates(hero: SimHero, prompt: String, values: Dictionary) -> Array[Array]:
	var result: Array[Array] = []
	var add := func(cards: Array[Card], source: String, filter := Callable()) -> void:
		for card in cards:
			if not filter.is_valid() or filter.call(card):
				result.append([card, source])
	match prompt:
		"prompt_lucky_charm":
			_add_top(hero, result, 1)
		"prompt_play_drawn":
			add.call(hero.drawn, "drawn")
		"prompt_play_from_top":
			_add_top(hero, result, values.get("look", 3))
		"prompt_search_pile":
			add.call(hero.pile, "pile")
		"prompt_discard_or_top":
			add.call(hero.discard, "discard")
			_add_top(hero, result, 1)
		"prompt_use_item":
			add.call(hero.table, "table")
		"prompt_attack_or_item":
			add.call(hero.hand, "hand", func(card: Card) -> bool: return card.has_symbol("attack"))
			add.call(hero.table, "table")
		"prompt_top_card_or_item":
			_add_top(hero, result, 1)
			add.call(hero.table, "table")
		_:
			add.call(hero.hand, "hand")
			add.call(hero.table, "table")
	return result


func _add_top(hero: SimHero, result: Array[Array], count: int) -> void:
	if hero.pile.is_empty():
		_reshuffle(hero)
	for i in mini(count, hero.pile.size()):
		result.append([hero.pile[hero.pile.size() - 1 - i], "pile"])


func _source_list(hero: SimHero, source: String) -> Array[Card]:
	match source:
		"hand": return hero.hand
		"pile": return hero.pile
		"discard": return hero.discard
		"drawn": return hero.drawn
	return hero.table


## The card leaves where it is for the play area, before it is shown, so that what it
## does to the cards finds it there.
func _take(hero: SimHero, card: Card, source: String) -> void:
	if source == "table":
		return
	_source_list(hero, source).erase(card)
	if card.stays_on_table():
		hero.table.append(card)
	else:
		hero.play_area.append(card)


func _untake(hero: SimHero, card: Card, source: String) -> void:
	if source == "table":
		return
	hero.play_area.erase(card)
	hero.table.erase(card)
	_source_list(hero, source).append(card)


func _choose_hero(request: Fight.Request) -> FightHero:
	var choices := request.heroes
	var asking: SimHero = _game.by_name.get(request.values.get("player", ""))
	var best: FightHero = choices[0]
	var best_value := -INF
	var plan: bool = _options.ai == "planner"
	if plan:
		_make_look()
	for fight_hero in choices:
		var hero: SimHero = _game.by_name[fight_hero.name]
		var planned: Variant = _plan_target(request, hero) if plan else null
		var value: float = planned if planned != null else _greedy_target(request, hero, asking)
		if value > best_value:
			best_value = value
			best = fight_hero
	return best


## What the older AI thinks of hero as the answer to request.
func _greedy_target(request: Fight.Request, hero: SimHero, asking: SimHero) -> float:
	var fight_hero := hero.fight_hero
	match request.prompt:
		"prompt_protect", "prompt_halve_who", "prompt_redirect_who":
			return _danger(fight_hero) * 10.0 - hero.health * 0.1
		"prompt_heal_who", "prompt_reset_health_who", "prompt_chosen_hero", "prompt_redraw_hand_who":
			return float(hero.max_health - hero.health) / hero.max_health - hero.hand.size() * 0.01
		"prompt_remove_tokens_who":
			return hero.tokens.poison * 2 + hero.tokens.fire + hero.tokens.paralysis + hero.tokens.panic
		"prompt_choose_starter":
			return _strongest_attack(hero)
		"prompt_free_play_who", "prompt_play_top_who":
			return hero.hand.map(func(card: Card) -> float: return _score(hero, card)).max() if not hero.hand.is_empty() else -1.0
	return 1.0 if hero == asking else 0.0


func _choose_option(request: Fight.Request) -> int:
	match request.prompt:
		"prompt_if_healthy":
			var hero: SimHero = _game.by_name[request.values.player]
			return 0 if hero.health >= request.values.health else 1
	return 0


func _choose_shield(request: Fight.Request) -> String:
	var fight := _game.fight
	var best: String = request.kinds[0]
	for kind in request.kinds:
		var value: int = fight.shields.get(kind, 0) * 2 + (1 if _poisonous(kind) else 0)
		if value > fight.shields.get(best, 0) * 2 + (1 if _poisonous(best) else 0):
			best = kind
	return best
#endregion


#region The AI's judgement
## How good playing card is right now, roughly in health of the boss or the heroes.
func _score(hero: SimHero, card: Card) -> float:
	var fight := _game.fight
	var away := fight.boss_away
	var attacked := fight.attacked.duplicate()
	var shields := fight.shields.duplicate()
	var score := 0.0
	for symbol in card.symbols:
		var strength := symbol.strength
		match symbol.type:
			"attack", "support":
				if strength == 0:
					strength = _estimate(hero, card)
				if away:
					score -= 1.0
					continue
				if symbol.type == "support" and not symbol.damage_type in attacked and not _free_support(hero, card, symbol.damage_type):
					score -= 1.0
					continue
				var shield: int = shields.get(symbol.damage_type, 0)
				score += maxi(0, strength - shield) + 0.6 * mini(strength, shield)
				if shield > 0 and _poisonous(symbol.damage_type):
					score -= 1.5
				shields[symbol.damage_type] = maxi(0, shield - strength)
				if symbol.type == "attack" and not symbol.damage_type in attacked:
					attacked.append(symbol.damage_type)
					if _has_support(hero, symbol.damage_type):
						score += 2.0
			"protection":
				score += _protection_value(strength if strength > 0 else fight.round_number)
			"heal":
				score += 0.8 * mini(strength, _missing(hero, card))
			"draw":
				score += 0.8 * strength
			"take_from_pile":
				score += 1.0 * strength
			"lightning":
				score += 1.5 * strength
			"direct_damage":
				score += 0.0 if away else strength
			"poison":
				score += 0.0 if away else 2.0 * strength
			"health_loss":
				score -= (1.5 if hero.health > strength * 3 else 5.0) * strength
			"special":
				score += 1.5
	match card.ability:
		"heal_hero":
			score += 0.8 * mini(card.ability_values.get("amount", 8), _missing(hero, card))
		"remove_tokens":
			score += 0.5 * hero.tokens.poison
		"lower_shield":
			score += 0.0 if away else 0.5 * mini(card.ability_values.get("amount", 7), shields.values().max())
		"poison_burst":
			score += 0.0 if away else fight.poison * card.ability_values.get("damage", 1)
	return score


## A hand card's worth when choosing what to keep, apart from the fight's moment.
func _keep_value(card: Card) -> float:
	var weights := { "attack": 1.0, "support": 0.8, "protection": 0.9, "heal": 0.7, "draw": 0.8,
		"take_from_pile": 1.0, "lightning": 1.5, "direct_damage": 1.2, "poison": 1.5, "health_loss": -1.0, "special": 2.0 }
	var value := 0.0
	for symbol in card.symbols:
		value += weights.get(symbol.type, 0.0) * maxi(symbol.strength, 2 if symbol.type in ["attack", "special"] else 0)
	return value


## The strength of an attack whose strength the card's text decides.
func _estimate(hero: SimHero, card: Card) -> int:
	match card.ability:
		"attack_by_round":
			return _game.fight.round_number
		"attack_by_threat":
			return hero.fight_hero.threat
		"random_strength":
			return int((card.ability_values.get("min", 1) + card.ability_values.get("max", 3)) / 2.0)
	return 2


## The best a Protection of strength can do now.
func _protection_value(strength: int) -> float:
	var best := 0.0
	for fight_hero in _game.fight.heroes:
		if fight_hero.threat <= 0:
			continue
		var hero: SimHero = _game.by_name[fight_hero.name]
		var value := float(mini(strength, fight_hero.threat))
		if strength >= fight_hero.threat:
			value += 1.5 * fight_hero.threat_effects.get("poison", 0)
		if _danger(fight_hero) >= hero.health:
			value *= 2.0
		best = maxf(best, value)
	return best


## What the boss's attack against fight_hero costs them, poison counted once.
func _danger(fight_hero: FightHero) -> float:
	var tokens := 0
	for token: String in fight_hero.threat_effects:
		tokens += fight_hero.threat_effects[token]
	return fight_hero.threat + tokens


## The health a heal of card can give back: the hero's own, or for cards that heal others,
## the most anyone has lost.
func _missing(hero: SimHero, card: Card) -> int:
	if card.ability in ["for_chosen_hero", "heal_hero", "every_hero", "attack_by_round"]:
		return _game.heroes.reduce(func(m: int, h: SimHero) -> int: return maxi(m, h.max_health - h.health), 0)
	return hero.max_health - hero.health


func _free_support(hero: SimHero, card: Card, kind: String) -> bool:
	var play := CardPlay.new(hero.fight_hero, card)
	for rule in _game.fight.rules:
		if rule.support_without_attack(_game.fight, kind, play):
			return true
	return false


func _has_support(hero: SimHero, kind: String) -> bool:
	for other in _game.heroes:
		for card in other.hand:
			if card.symbols.any(func(s: Card.Symbol) -> bool: return s.type == "support" and s.damage_type == kind):
				return true
	return false


func _strongest_attack(hero: SimHero) -> float:
	var best := 0.0
	for card in hero.hand:
		best = maxf(best, _score(hero, card))
	return best


func _poisonous(kind: String) -> bool:
	return _game.fight.boss.shield_icon(kind) == Boss.SHIELD_POISON
#endregion


#region The planner (--ai planner)
## The planner judges every choice by the race it is in: the heroes lose if any of them
## falls to 0, so health is worth a lot only where it keeps a hero alive until the boss is
## dead, while damage to the boss is worth the same all the time. See docs/balance.md.

## The boss damage per hero and round the planner assumes before the fight shows the
## party's pace, and the health it assumes a hero loses per round besides poison. Each
## counts as one round already played.
const PACE_PRIOR := 5.0
const HIT_PRIOR := 6.0
## Health a hero has beyond what the rest of the fight should cost them, up to which more
## health is still worth a lot.
const SAFE_MARGIN := 8.0
## The part of the party's other attacks and supports of a damage type that it counts on to
## follow this round.
const FOLLOW_UP := 0.6
## What a fight's last use of an item with uses_per_fight is worth in hand, for later.
const KEEP_ONE_USE := 2.5

## How the race stands, made anew for each choice: "rounds" the boss still needs, this one
## included, "future" the rounds after this one, "kill_now" whether the party can likely
## finish it this round, and "hits", by hero name, the health they lose per round besides
## poison, and "lash" the health every hero loses this round after the attacks, such as
## to a tail lash.
var _look := {}


func _make_look() -> void:
	var fight := _game.fight
	var done := maxi(0, fight.round_number - 1)
	var pace := (float(fight.max_health - fight.health) + PACE_PRIOR * _game.heroes.size()) / (done + 1)
	var rounds := maxf(1.0, fight.health / maxf(pace, 1.0))
	var hits := {}
	for hero in _game.heroes:
		hits[hero.name] = (hero.taken + HIT_PRIOR) / (done + 1)
	# A pattern players soon learn: Mirefang lashes its tail every tail_every rounds.
	var boss := fight.boss
	var lash := 0
	if "tail" in boss and int(boss.get("tail_every")) > 0 and fight.round_number % int(boss.get("tail_every")) == 0:
		lash = int(boss.get("tail").get(fight.difficulty, 0))
	_look = {
		"rounds": rounds,
		"lash": lash,
		"future": rounds - 1.0,
		"kill_now": not fight.boss_away and 0.85 * _party_damage() >= fight.health,
		"hits": hits,
	}


## Scores the candidates ([card, where it is]) as [score, card, where it is], best first.
## A card with Lightning gives its action back: it scores what it does plus the best other
## card that action can play, so that it comes before cards without.
func _plan_scores(hero: SimHero, candidates: Array[Array], request: Fight.Request) -> Array[Array]:
	_make_look()
	var ignore_lightning: bool = request.settings.get("ignore_lightning", false)
	var values: Array[float] = []
	var lightning: Array[bool] = []
	for candidate: Array in candidates:
		var card: Card = candidate[0]
		values.append(_plan_value(hero, card))
		lightning.append(not ignore_lightning and card.symbols.any(func(s: Card.Symbol) -> bool: return s.type == "lightning"))
	var scored: Array[Array] = []
	for i in candidates.size():
		var score := values[i]
		if lightning[i] and score > 0.0:
			var other := 0.0
			for j in candidates.size():
				if j != i:
					other = maxf(other, values[j])
			score += other
		scored.append([score, candidates[i][0], candidates[i][1]])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	return scored


## What playing card now is worth, its Lightning left out.
func _plan_value(hero: SimHero, card: Card) -> float:
	var fight := _game.fight
	var away := fight.boss_away
	var shields := fight.shields.duplicate()
	var attacked := fight.attacked.duplicate()
	var value := 0.0
	var damage := 0
	var poisoned := 0
	var protection := 0
	var heal := 0
	var draw := 0
	var take := 0
	var lightning := 0
	var loss := 0
	for symbol in card.symbols:
		var strength := symbol.strength
		match symbol.type:
			"attack", "support":
				if strength == 0:
					strength = _estimate(hero, card)
				var kind := symbol.damage_type
				if away or (symbol.type == "support" and not kind in attacked and not _free_support(hero, card, kind)):
					value -= 1.0
					continue
				# Damage into a shield counts for what the party's other cards of the type
				# then get through.
				var pool := _follow_up(hero, card, kind)
				var opened: bool = kind in attacked or pool[0] > 0.0
				var without: float = pool[0] + (pool[1] if opened else 0.0)
				var with_card: float = pool[0] + pool[1]
				var shield: int = shields.get(kind, 0)
				value += maxf(0.0, with_card + strength - shield) - maxf(0.0, without - shield)
				damage += maxi(0, strength - shield)
				if shield > 0 and _poisonous(kind):
					poisoned += 1 + (int(fight.boss.get("enraged_bonus")) if fight.boss.get("enraged") == true else 0)
				shields[kind] = maxi(0, shield - strength)
				if symbol.type == "attack" and not kind in attacked:
					attacked.append(kind)
			"protection":
				protection += strength if strength > 0 else fight.round_number
			"heal":
				heal += strength
			"draw":
				draw += strength
			"take_from_pile":
				take += strength
			"lightning":
				lightning += strength
			"direct_damage":
				if not away:
					value += strength
					damage += strength
			"poison":
				# The boss's poison hurts it at the end of every round.
				if not away:
					value += strength * minf(_look.rounds, 4.0)
			"health_loss":
				loss += strength
			"special":
				value += 1.5
	var values := card.ability_values
	match card.ability:
		"heal_hero":
			var gains: Array = _game.heroes.map(func(h: SimHero) -> float: return _gain(h, values.get("amount", 8)))
			gains.sort()
			gains.reverse()
			for i in mini(values.get("heroes", 1), gains.size()):
				value += gains[i]
		"remove_tokens":
			var count: int = values.get("count", 2)
			match values.get("count_by", ""):
				"damage": count = damage
				"round": count = fight.round_number
			if count > 0:
				if values.get("group", false) or values.get("choose", false):
					value += _game.heroes.map(func(h: SimHero) -> float: return _gain(h, 0, 0, count)).max()
				else:
					value += _gain(hero, 0, 0, count)
			var every: int = values.get("every_hero", 0)
			for each in _game.heroes:
				value += _gain(each, 0, 0, every) if every > 0 else 0.0
		"lower_shield":
			value += 0.0 if away else 0.5 * mini(values.get("amount", 7), shields.values().max() if not shields.is_empty() else 0)
		"poison_burst":
			value += 0.0 if away else fight.poison * values.get("damage", 1)
		"attack_lowers_threat":
			value += _game.heroes.map(func(h: SimHero) -> float: return _gain(h, 0, values.get("amount", 2))).max()
	# The boss's answers to a hit: the poison shield, and a spit at a strong hit, once a round.
	if damage >= int(fight.boss.get("spit_damage") if "spit_damage" in fight.boss else 1 << 30) and _game.spat_round != fight.round_number:
		poisoned += int(fight.boss.get("spit_poison"))
	if damage >= fight.health and not away:
		value += 50.0
	if protection > 0:
		value += _game.heroes.map(func(h: SimHero) -> float: return _gain(h, 0, protection)).max()
	# Heal and Draw go to the hero who plays the card, to every hero, or to a chosen one.
	var actions := _actions_left(hero) - 1 + lightning
	var chosen: bool = card.ability == "for_chosen_hero" or values.get("chosen_hero", false)
	if heal > 0 or draw > 0 or take > 0 or chosen:
		if card.ability == "every_hero":
			for each in _game.heroes:
				value += _gain(each, heal) + _draw_value(each, card, draw, take, actions if each == hero else _actions_left(each))
		elif chosen:
			var best := -INF
			for each in _game.heroes:
				best = maxf(best, _chosen_value(hero, each, card, heal, draw, take, actions))
			value += best
		else:
			value += _gain(hero, heal) + _draw_value(hero, card, draw, take, actions)
	if loss > 0 or poisoned > 0:
		value += _gain(hero, 0, 0, -poisoned, loss)
	if card.uses_per_fight > 0 and hero.fight_hero.uses.get(card.qr, 0) == card.uses_per_fight - 1:
		value -= KEEP_ONE_USE
	return value


## What a card whose Heal and Draw go to a chosen hero gives to each.
func _chosen_value(hero: SimHero, each: SimHero, card: Card, heal: int, draw: int, take: int, actions: int) -> float:
	var extra := 1 if card.ability_values.get("action", false) else 0
	var value := _gain(each, heal) + _draw_value(each, card, draw, take, (actions if each == hero else _actions_left(each)) + extra)
	if extra > 0 and not each.hand.is_empty():
		value += 2.5
	return value


## What the planner thinks of hero as the answer to request, or null to leave it to the
## older AI.
func _plan_target(request: Fight.Request, hero: SimHero) -> Variant:
	var fight_hero := hero.fight_hero
	match request.prompt:
		"prompt_protect":
			return _gain(hero, 0, int(request.values.get("amount", 0)))
		"prompt_halve_who":
			return _gain(hero, 0, fight_hero.threat - fight_hero.threat / 2)
		"prompt_heal_who":
			return _gain(hero, int(request.values.get("amount", 8)))
		"prompt_reset_health_who":
			return _gain(hero, hero.max_health)
		"prompt_remove_tokens_who":
			return _gain(hero, 0, 0, int(request.values.get("count", 2)))
		"prompt_chosen_hero":
			var card := _game.playing
			if card == null:
				return null
			var heal := 0
			var draw := 0
			var take := 0
			for symbol in card.symbols:
				match symbol.type:
					"heal": heal += symbol.strength
					"draw": draw += symbol.strength
					"take_from_pile": take += symbol.strength
			var asking: SimHero = _game.by_name.get(request.values.get("player", ""))
			var actions := _actions_left(asking) if asking != null else 0
			if card.ability == "attack_lowers_threat":
				return _gain(hero, 0, card.ability_values.get("amount", 2))
			return _chosen_value(asking, hero, card, heal, draw, take, actions)
		"prompt_redraw_hand_who":
			if hero.hand.is_empty():
				return 0.0
			return -hero.hand.reduce(func(sum: float, card: Card) -> float: return sum + _keep_value(card), 0.0) / hero.hand.size()
	return null


## How much better the race stands for hero when they heal some health, the boss's attack
## on them is protect lower, cure of their poison tokens are gone (fewer than 0: more
## come) and they lose loss health.
func _gain(hero: SimHero, heal := 0, protect := 0, cure := 0, loss := 0) -> float:
	var fight_hero := hero.fight_hero
	var effects: int = fight_hero.threat_effects.get("poison", 0)
	var before := _hero_value(hero, hero.health, fight_hero.threat, effects, hero.tokens.poison)
	var healed := mini(heal, hero.max_health - hero.health)
	var poison := maxi(0, hero.tokens.poison - cure)
	var after := _hero_value(hero, hero.health + healed - loss, maxi(0, fight_hero.threat - protect), effects, poison)
	# What is cured beyond the poison takes the other tokens.
	var others: int = hero.tokens.fire + hero.tokens.paralysis + hero.tokens.panic
	return after - before + 0.7 * clampi(cure - hero.tokens.poison, 0, others)


## How well hero stands with this health, the boss's attack on them this round and its
## poison, and poison tokens: very badly if they fall this round, then by how much health
## they should have left when the boss falls.
func _hero_value(hero: SimHero, health: int, threat: int, effects: int, poison: int) -> float:
	if _look.kill_now:
		return 0.05 * health
	# An attack lowered to 0 loses its poison. The poison ticks at the end of this round.
	var tick := poison + (effects if threat > 0 else 0)
	var fire: int = 2 * hero.tokens.fire if health > 8 else 0
	var left := float(health - threat - tick - fire - int(_look.lash))
	var value := 2.0 * minf(left - 1.0, 0.0)
	if left <= 0.0:
		value -= 25.0
	var margin: float = left - _look.future * (_look.hits[hero.name] + tick)
	return value + minf(margin, 0.0) + 0.6 * clampf(margin, 0.0, SAFE_MARGIN) + 0.15 * maxf(margin - SAFE_MARGIN, 0.0)


## What drawing count cards and taking take of the best from the pile is worth to hero,
## who has actions left to play them this round: a card for an action they have no good
## card for. Beyond that, a little, for the better hand to keep.
func _draw_value(hero: SimHero, playing: Card, count: int, take: int, actions: int) -> float:
	if count <= 0 and take <= 0:
		return 0.0
	var good := hero.hand.filter(func(card: Card) -> bool: return card != playing and _keep_value(card) >= 3.0).size()
	var open := float(maxi(0, actions - good))
	var drawn := minf(0.6 * count, open)
	return 0.3 * count + 2.5 * drawn + 0.5 * take + 3.0 * minf(take, open - drawn)


## The actions hero has left this round, the one they are taking included.
func _actions_left(hero: SimHero) -> int:
	return hero.fight_hero.turns_left + hero.fight_hero.pending.size()


## The damage of kind the party's other cards will likely add this round, as [attacks,
## supports]: each hero's strongest, as many as they have actions left (Lightning cards
## free), counted at FOLLOW_UP.
func _follow_up(hero: SimHero, card: Card, kind: String) -> Array[float]:
	var result: Array[float] = [0.0, 0.0]
	for each in _game.heroes:
		var actions := _actions_left(each) - (1 if each == hero else 0)
		for entry: Array in _damage_cards(each, card, actions):
			for symbol: Card.Symbol in (entry[0] as Card).symbols:
				if symbol.damage_type == kind and symbol.type in ["attack", "support"]:
					result[0 if symbol.type == "attack" else 1] += FOLLOW_UP * (symbol.strength if symbol.strength > 0 else _estimate(each, entry[0]))
	return result


## The cards with damage hero can likely still play this round, as [card, damage], strongest
## first: those with Lightning, and as many others as actions.
func _damage_cards(hero: SimHero, except: Card, actions: int) -> Array[Array]:
	var cards: Array[Array] = []
	for card in hero.hand:
		if card == except or card.qr in hero.fight_hero.played:
			continue
		var damage := 0
		for symbol in card.symbols:
			if symbol.type in ["attack", "support", "direct_damage"]:
				damage += symbol.strength if symbol.strength > 0 else _estimate(hero, card)
		if damage > 0:
			cards.append([card, damage])
	cards.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	var result: Array[Array] = []
	for entry in cards:
		if (entry[0] as Card).has_symbol("lightning"):
			result.append(entry)
		elif actions > 0:
			actions -= 1
			result.append(entry)
	return result


## About the most damage the party can still do to the boss this round, past its shields.
func _party_damage() -> float:
	var fight := _game.fight
	var attacks := {}
	var supports := {}
	var direct := 0
	for hero in _game.heroes:
		for entry in _damage_cards(hero, null, _actions_left(hero)):
			var card: Card = entry[0]
			for symbol in card.symbols:
				var strength := symbol.strength if symbol.strength > 0 else _estimate(hero, card)
				match symbol.type:
					"attack": attacks[symbol.damage_type] = attacks.get(symbol.damage_type, 0) + strength
					"support": supports[symbol.damage_type] = supports.get(symbol.damage_type, 0) + strength
					"direct_damage": direct += strength
	var total := float(direct)
	for kind: String in Fight.DAMAGE_TYPES:
		var sum: int = attacks.get(kind, 0)
		if sum > 0 or kind in fight.attacked:
			sum += supports.get(kind, 0)
		total += maxi(0, sum - fight.shields.get(kind, 0))
	return total
#endregion


#region The table: what the messages ask the players to do
func _on_message(id: String, values: Dictionary) -> void:
	var game := _game
	var fight := game.fight
	var hero: SimHero = game.by_name.get(values.get("player", ""))
	if game.log and not id in ["round_end_discard", "round_end_draw"]:
		print("  [r%d] %s %s" % [fight.round_number, id, _brief(values)])
	match id:
		"heal":
			hero.health = mini(hero.max_health, hero.health + int(values.amount))
		"draw_cards", "may_draw":
			_draw(hero, int(values.count))
		"draw_cards_everyone":
			for each in game.heroes:
				_draw(each, int(values.count))
		"take_from_pile", "search_to_hand":
			for i in int(values.count):
				_take_best_from_pile(hero)
			_shuffle(hero.pile)
		"health_loss":
			_hurt(hero, int(values.amount), "card")
		"boss_attacks":
			for hit: Array in fight._hits:
				var struck: SimHero = game.by_name[hit[0].name]
				_hurt(struck, hit[1], "bite" if struck.name == game.bitten else "attack")
				_add_tokens(struck, hit[2])
		"mirefang_poison_shield":
			game.poison_shield_hits += 1
			_add_tokens(hero, { "poison": int(values.poison) })
		"mirefang_spit":
			game.spits += 1
			game.spat_round = fight.round_number
			_add_tokens(hero, { "poison": int(values.poison) })
		"mirefang_tail":
			for each in game.heroes:
				_hurt(each, int(values.damage), "tail")
		"mirefang_dive":
			game.dives += 1
			game.bitten = values.player
		"mirefang_enraged":
			game.enraged_round = fight.round_number
		"round_started", "first_round":
			game.bitten = ""
		"round_end_status":
			for each in game.heroes:
				_hurt(each, each.tokens.poison, "poison")
				for i in each.tokens.fire:
					if each.pile.is_empty():
						_reshuffle(each)
					if each.pile.is_empty():
						break
					var burnt: Card = each.pile.pop_back()
					if each.health > 8:
						each.discard.append(burnt)
						_hurt(each, 2, "fire")
					else:
						each.removed.append(burnt)
		"round_end_discard":
			for each in game.heroes:
				_flush_drawn(each)
				each.discard.append_array(each.play_area)
				each.play_area.clear()
				var limit := _limit(each)
				if each.hand.size() > limit:
					each.hand.sort_custom(func(a: Card, b: Card) -> bool: return _keep_value(a) > _keep_value(b))
					for card in each.hand.slice(limit):
						each.discard.append(card)
					each.hand.resize(limit)
		"round_end_draw":
			for each in game.heroes:
				_draw(each, _limit(each) - each.hand.size())
		"card_removed":
			var title: Variant = values.get("source", {}).get("title")
			_move_by_title(hero, hero.play_area, hero.removed, title)
		"searched_card_removed", "played_card_removed":
			_move_by_title(hero, hero.play_area, hero.removed, values.card)
		"card_back_to_pile":
			_move_by_title(hero, hero.play_area, hero.pile, values.card)
			_shuffle(hero.pile)
		"card_back_to_hand":
			_move_by_title(hero, hero.play_area, hero.hand, values.card)
		"shuffle_pile":
			_shuffle(hero.pile)
		"remove_tokens":
			_remove_tokens(hero, int(values.count))
		"remove_tokens_everyone":
			for each in game.heroes:
				_remove_tokens(each, int(values.count))
		"remove_tokens_group":
			for i in int(values.count):
				var most: SimHero = game.heroes[0]
				for each in game.heroes:
					if each.tokens.poison > most.tokens.poison:
						most = each
				_remove_tokens(most, 1)
		"take_token":
			# Panic costs the least: one random card, then it is gone.
			_add_tokens(hero, { "panic": int(values.count) })
		"random_token":
			_add_tokens(hero, _parse_tokens(values.tokens))
		"tokens_everyone":
			for each in game.heroes:
				_add_tokens(each, _parse_tokens(values.tokens))
		"card_to_pile":
			for i in mini(int(values.count), hero.hand.size()):
				var worst := _worst(hero.hand)
				hero.hand.erase(worst)
				hero.pile.append(worst)
		"discard_random":
			for i in mini(int(values.count), hero.hand.size()):
				hero.discard.append(hero.hand.pop_at(game.rng.randi() % hero.hand.size()))
		"redraw_hand":
			for card in hero.hand.duplicate():
				if _keep_value(card) < 2.0:
					hero.hand.erase(card)
					hero.discard.append(card)
			_draw(hero, _limit(hero) - hero.hand.size())
		"draw_and_return_everyone":
			for each in game.heroes:
				_draw(each, int(values.draw))
				for i in mini(int(values.back), each.hand.size()):
					var worst := _worst(each.hand)
					each.hand.erase(worst)
					each.pile.append(worst)
		"look_at_top_everyone":
			for each in game.heroes:
				var top: Array[Card] = []
				for i in int(values.look):
					if each.pile.is_empty():
						break
					top.append(each.pile.pop_back())
				top.sort_custom(func(a: Card, b: Card) -> bool: return _keep_value(a) > _keep_value(b))
				for i in top.size():
					if i < int(values.take):
						each.hand.append(top[i])
					else:
						each.pile.append(top[i])
		"draw_and_play":
			for i in int(values.draw):
				if hero.pile.is_empty():
					_reshuffle(hero)
				if hero.pile.is_empty():
					break
				hero.drawn.append(hero.pile.pop_back())
		"reset_health":
			hero.health = hero.max_health
		_:
			if not id in READ_ONLY:
				game.unhandled[id] = game.unhandled.get(id, 0) + 1


func _hurt(hero: SimHero, amount: int, cause: String) -> void:
	if amount <= 0:
		return
	hero.health -= amount
	hero.lost[cause] = hero.lost.get(cause, 0) + amount
	if not cause in ["poison", "card"]:
		hero.taken += amount
	if hero.health <= 0 and _game.dead == null:
		_game.dead = hero
		_game.death_cause = cause


func _add_tokens(hero: SimHero, tokens: Dictionary) -> void:
	for token: String in tokens:
		hero.tokens[token] = hero.tokens.get(token, 0) + int(tokens[token])
	hero.max_poison = maxi(hero.max_poison, hero.tokens.poison)
	var table := 0
	for each in _game.heroes:
		table += each.tokens.poison
	_game.max_poison_table = maxi(_game.max_poison_table, table)


## Poison goes first, as it hurts most.
func _remove_tokens(hero: SimHero, count: int) -> void:
	for token: String in ["poison", "fire", "paralysis", "panic"]:
		var removed := mini(count, hero.tokens[token])
		hero.tokens[token] -= removed
		count -= removed


## { "en": "1 poison, 2 fire" } as tokens.
## The tokens of a message value made by Fight.token_text(), as token -> count.
func _parse_tokens(text: Dictionary) -> Dictionary:
	var tokens := {}
	for part: Array in text.get("parts", []):
		tokens[(part[0] as String).trim_prefix("part_token_")] = int(part[1].count)
	return tokens


func _limit(hero: SimHero) -> int:
	return maxi(0, hero.hand_limit - hero.tokens.paralysis)


func _draw(hero: SimHero, count: int) -> void:
	for i in count:
		if hero.pile.is_empty():
			_reshuffle(hero)
		if hero.pile.is_empty():
			return
		hero.hand.append(hero.pile.pop_back())


func _reshuffle(hero: SimHero) -> void:
	hero.pile.append_array(hero.discard)
	hero.discard.clear()
	_shuffle(hero.pile)


func _take_best_from_pile(hero: SimHero) -> void:
	if hero.pile.is_empty():
		_reshuffle(hero)
	if hero.pile.is_empty():
		return
	var best: Card = hero.pile[0]
	for card in hero.pile:
		if _keep_value(card) > _keep_value(best):
			best = card
	hero.pile.erase(best)
	hero.hand.append(best)


func _flush_drawn(hero: SimHero) -> void:
	hero.discard.append_array(hero.drawn)
	hero.drawn.clear()


func _worst(cards: Array[Card]) -> Card:
	var worst: Card = cards[0]
	for card in cards:
		if _keep_value(card) < _keep_value(worst):
			worst = card
	return worst


func _move_by_title(_hero: SimHero, from: Array[Card], to: Array[Card], title: Variant) -> void:
	if not title is Dictionary:
		return
	for i in range(from.size() - 1, -1, -1):
		if from[i].title.get("de") == title.get("de"):
			to.append(from.pop_at(i))
			return


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := _game.rng.randi_range(0, i) if _game != null else randi_range(0, i)
		var swap: Variant = list[i]
		list[i] = list[j]
		list[j] = swap


func _brief(values: Dictionary) -> String:
	var parts := PackedStringArray()
	for key: String in values:
		if key in ["boss", "source", "taunt", "hits"]:
			continue
		var value: Variant = values[key]
		if value is Dictionary:
			value = _parse_tokens(value) if value.has("parts") else value.get("en", value.get("de", ""))
		parts.append("%s=%s" % [key, value])
	if values.has("hits"):
		for hit: Array in values.hits:
			parts.append("%s:%d%s" % [hit[1].player, hit[1].damage, "+" + str(_parse_tokens(hit[1].tokens)) if hit[1].has("tokens") else ""])
	return " ".join(parts)
#endregion


#region Options and results
func _parse_args(args: PackedStringArray) -> bool:
	var i := 0
	while i < args.size():
		var arg := args[i]
		var next := args[i + 1] if i + 1 < args.size() else ""
		match arg:
			"--help", "-h":
				print(HELP)
				return false
			"--items":
				_options.items = true
			"--no-items":
				_options.items = false
			"--log":
				_options.log = true
			"--boss", "--csv", "--ai":
				_options[arg.substr(2)] = next
				i += 1
			"--games", "--level", "--loot", "--health", "--hand", "--seed", "--max-rounds", "--tokens":
				_options[arg.substr(2).replace("-", "_")] = int(next)
				i += 1
			"--players":
				_options.players = Array(next.split(",")).map(func(s: String) -> int: return int(s))
				i += 1
			"--difficulty":
				_options.difficulty = Array(next.split(","))
				i += 1
			"--set":
				var parts := next.split("=", true, 1)
				if parts.size() != 2:
					printerr("--set needs key=value, got ", next)
					return false
				var parsed: Variant = JSON.parse_string(parts[1])
				_options.set[parts[0]] = _ints(parsed) if parsed != null else parts[1]
				i += 1
			_:
				printerr("Unknown option ", arg, "\n", HELP)
				return false
		i += 1
	if not _options.ai in ["planner", "greedy"]:
		printerr("Unknown AI ", _options.ai)
		return false
	if not Bosses.has(_options.boss):
		printerr("Unknown boss ", _options.boss)
		return false
	for difficulty: String in _options.difficulty:
		if not Bosses.DIFFICULTIES.has(difficulty):
			printerr("Unknown difficulty ", difficulty)
			return false
	return true


const HELP := """Usage: godot --headless -s tools/balance/simulate.gd -- [options]
  --games N          fights per player count and difficulty (200)
  --players 1,2,3,4  player counts to try
  --difficulty easy,normal,hard
  --boss ID          (mirefang)
  --ai planner|greedy  how the heroes decide (planner; greedy: the older AI)
  --level 1|5|8      hero level: the character and class cards up to it (1)
  --loot N           loot cards per hero, one of each level 1..N (10)
  --no-items         without the base game's items (each hero has them by default:
                     Heiltrank, Medizintasche, Trinkschlauch, ...)
  --health N         start health of every hero (else from HeroOptions: character + class)
  --hand N           hand limit of every hero (likewise)
  --set key=value    changes a variable of the boss, value as JSON, e.g.
                     --set health=70 --set shield_value=2 --set 'dive_below=[0.66,0.33]'
                     --set 'bite={"easy":{"damage":10,"poison":2},"normal":{"damage":12,"poison":2},"hard":{"damage":15,"poison":3}}'
  --tokens N         poison tokens in the box, for the >box column (16)
  --max-rounds N     a fight still running then counts as a timeout (40)
  --seed N           first seed; the same options give the same results (1)
  --csv PATH         one line per fight
  --log              play-by-play of the first fight"""


## JSON numbers are floats: whole ones become ints, for the boss's int variables.
func _ints(value: Variant) -> Variant:
	if value is float and value == floor(value) and absf(value) < 1e9:
		return int(value)
	if value is Array:
		return value.map(func(v: Variant) -> Variant: return _ints(v))
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[key] = _ints(value[key])
		return result
	return value


func _override(boss: Boss, key: String, value: Variant) -> void:
	if not key in boss:
		push_error("The boss has no variable '%s'" % key)
		quit(2)
		return
	var current: Variant = boss.get(key)
	if current is Array and value is Array:
		var typed: Array = current.duplicate()
		typed.clear()
		typed.assign(value)
		value = typed
	elif current is float and value is int:
		value = float(value)
	boss.set(key, value)


func _print_setup() -> void:
	print("Boss %s, %d fights per line, AI %s, hero level %d, %d loot, items %s, seed %d" % [
		_options.boss, _options.games, _options.ai, _options.level, _options.loot, "on" if _options.items else "off", _options.seed])
	if _options.health > 0 or _options.hand > 0:
		print("Every hero: health %s, hand limit %s" % [_options.health if _options.health > 0 else "by card", _options.hand if _options.hand > 0 else "by card"])
	if not _options.set.is_empty():
		print("Boss changes: %s" % JSON.stringify(_options.set))


func _summarize(players: int, difficulty: String, results: Array[Dictionary]) -> Dictionary:
	var won := results.filter(func(r: Dictionary) -> bool: return r.outcome == "won")
	var lost := results.filter(func(r: Dictionary) -> bool: return r.outcome == "lost")
	var causes := {}
	var damage := {}
	for r: Dictionary in results:
		if not r.death_cause.is_empty():
			causes[r.death_cause] = causes.get(r.death_cause, 0) + 1
		for cause: String in r.lost:
			damage[cause] = damage.get(cause, 0.0) + float(r.lost[cause]) / r.players / maxi(1, r.rounds)
	var mean := func(list: Array, key: String) -> float:
		if list.is_empty():
			return NAN
		return list.reduce(func(sum: float, r: Dictionary) -> float: return sum + float(r[key]), 0.0) / list.size()
	for cause: String in damage:
		damage[cause] /= results.size()
	return {
		"players": players, "difficulty": difficulty, "games": results.size(),
		"win": float(won.size()) / results.size(),
		"timeouts": results.filter(func(r: Dictionary) -> bool: return r.outcome in ["timeout", "stuck"]).size(),
		"rounds_won": mean.call(won, "rounds"),
		"rounds_lost": mean.call(lost, "rounds"),
		"boss_left": lost.reduce(func(s: float, r: Dictionary) -> float: return s + float(r.boss_health) / r.boss_max, 0.0) / lost.size() if not lost.is_empty() else NAN,
		"margin": mean.call(won, "lowest_health"),
		"dives": mean.call(results, "dives"),
		"enraged": float(results.filter(func(r: Dictionary) -> bool: return r.enraged_round > 0).size()) / results.size(),
		"spits": mean.call(results, "spits"),
		"poison_hits": mean.call(results, "poison_shield_hits"),
		"max_poison": mean.call(results, "max_poison"),
		"max_poison_table": mean.call(results, "max_poison_table"),
		"over_tokens": float(results.filter(func(r: Dictionary) -> bool: return r.max_poison_table > _options.tokens).size()) / results.size(),
		"passes": mean.call(results, "passes"),
		"rounds": results.map(func(r: Dictionary) -> int: return r.rounds),
		"causes": causes,
		"damage": damage,
	}


func _print_summaries(summaries: Array[Dictionary]) -> void:
	print("")
	print("pl diff    win%  rnd(won) rnd(lost) boss%left margin  dives enraged spits psh.hits maxpsn tblpsn >box  hero dmg/round: attack bite poison other   deaths: attack/bite/poison/other")
	for s in summaries:
		var d: Dictionary = s.damage
		var other := 0.0
		for cause: String in d:
			if not cause in ["attack", "bite", "poison"]:
				other += d[cause]
		var c: Dictionary = s.causes
		var c_other := 0
		for cause: String in c:
			if not cause in ["attack", "bite", "poison"]:
				c_other += c[cause]
		print("%2d %-6s %5.1f %8s %9s %9s %6s %6.2f %6.0f%% %5.2f %8.2f %6.1f %6.1f %3.0f%%  %20.1f %4.1f %6.1f %5.1f   %d/%d/%d/%d%s" % [
			s.players, s.difficulty, 100.0 * s.win, _num(s.rounds_won), _num(s.rounds_lost),
			_pct(s.boss_left), _pct(s.margin), s.dives, 100.0 * s.enraged, s.spits, s.poison_hits, s.max_poison, s.max_poison_table, 100.0 * s.over_tokens,
			d.get("attack", 0.0), d.get("bite", 0.0), d.get("poison", 0.0), other,
			c.get("attack", 0), c.get("bite", 0), c.get("poison", 0), c_other,
			"   (%d timeouts)" % s.timeouts if s.timeouts > 0 else ""])
	print("""
  win%       fights won
  rnd        mean rounds of the fights won / lost
  boss%left  mean health the boss had left when the heroes lost
  margin     mean health of the weakest hero at the end of a won fight, of their start health
  dives      mean dives per fight; enraged: fights in which it got enraged
  spits      venom spits per fight; psh.hits: hits on the poison shield per fight
  maxpsn     mean of the most poison tokens any hero had at once
  tblpsn     mean of the most poison tokens on the table at once, all heroes together
  >box       fights in which that was more than the box has (--tokens)
  hero dmg   health each hero lost per round, by cause (poison = their tokens at round end)
  deaths     fights lost, by what took the hero to 0""")


## Win rate by race and by class, over all fights.
## How many rounds the fights lasted, won or lost: for each line, and for each number of
## heroes over all difficulties.
func _print_rounds(summaries: Array[Dictionary]) -> void:
	print("\nRounds until the fight ends (won, lost or timed out):")
	print("pl diff     mean  median  10-90 %  min-max  fights over by round 3/4/5/6/7/8/10")
	var lines: Array[Array] = []
	for s in summaries:
		lines.append(["%2d %-6s" % [s.players, s.difficulty], s.rounds])
	if _options.difficulty.size() > 1:
		for players: int in _options.players:
			var all: Array = []
			for s in summaries:
				if s.players == players:
					all.append_array(s.rounds)
			lines.append(["%2d %-6s" % [players, "all"], all])
	for line in lines:
		var rounds: Array = line[1].duplicate()
		rounds.sort()
		var n := rounds.size()
		var at := func(share: float) -> int: return rounds[clampi(int(share * (n - 1) + 0.5), 0, n - 1)]
		var over := PackedStringArray()
		for limit: int in [3, 4, 5, 6, 7, 8, 10]:
			over.append("%3.0f" % (100.0 * rounds.filter(func(r: int) -> bool: return r <= limit).size() / n))
		print("%s %6.1f %7d %5d-%-3d %4d-%-3d  %s %%" % [line[0], rounds.reduce(func(sum: int, r: int) -> int: return sum + r, 0) / float(n),
			at.call(0.5), at.call(0.1), at.call(0.9), rounds[0], rounds[n - 1], "/".join(over)])


func _print_by_hero() -> void:
	var by := {}
	for r in _rows:
		for entry: String in r.party:
			for key: String in entry.split("/"):
				var counts: Array = by.get(key, [0, 0])
				counts[0] += 1
				counts[1] += 1 if r.outcome == "won" else 0
				by[key] = counts
	var line := PackedStringArray()
	for key: String in RACES + CLASSES:
		if by.has(key):
			line.append("%s %.0f%%" % [key, 100.0 * by[key][1] / by[key][0]])
	print("\nWin rate of the fights a race or class took part in: ", ", ".join(line))


func _print_unhandled() -> void:
	if _unhandled.is_empty():
		return
	print("\nMessages the simulated table did not act on (their effect is missing): ", _unhandled)


func _write_csv(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write ", path)
		return
	var keys := ["players", "difficulty", "seed", "outcome", "rounds", "boss_health", "boss_max", "dives", "enraged_round",
		"spits", "poison_shield_hits", "death_cause", "dead_hero", "lowest_health", "max_poison", "max_poison_table", "cards_played", "passes"]
	file.store_line(",".join(keys + ["party", "lost_attack", "lost_bite", "lost_poison", "lost_other"]))
	for r in _rows:
		var line := PackedStringArray()
		for key: String in keys:
			line.append(str(r[key]))
		line.append(" ".join(r.party))
		var other := 0
		for cause: String in r.lost:
			if not cause in ["attack", "bite", "poison"]:
				other += r.lost[cause]
		line.append_array([str(r.lost.get("attack", 0)), str(r.lost.get("bite", 0)), str(r.lost.get("poison", 0)), str(other)])
		file.store_line(",".join(line))
	print("\nWrote ", path)


func _num(value: float) -> String:
	return "-" if is_nan(value) else "%.1f" % value


func _pct(value: float) -> String:
	return "-" if is_nan(value) else "%.0f%%" % (100.0 * value)
#endregion
