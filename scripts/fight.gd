class_name Fight
extends RefCounted
## The rules of a boss fight, and what is going on in it: the boss, its health and shields,
## the heroes, the round and the phase. See docs/boss_fight.md.
##
## The fight runs by itself from start() on, round after round, phase after phase, and
## waits for the players whenever it needs them:
## - until they have read its messages (players_ready()),
## - for an answer to what it asks (request, request_changed): a hero to choose
##   (choose()), a card to play (scan(), pass_action()) or an option (choose_option()).
## The screen shows all of it and passes on what the players do, so the rules can run
## and be tested without a screen.
##
## What is special about a boss, a card or a hero comes from rules (FightRule), which the
## fight asks at every moment that matters. A rule's hook can wait for the players too.

signal round_changed(round_number: int)
signal phase_changed(phase: Phase)
signal health_changed(health: int, max_health: int)
signal shields_changed(shields: Dictionary)
## Its attack, its tokens or its turns changed.
signal hero_changed(hero: FightHero)
## null once nobody's turn is on.
signal turn_changed(hero: FightHero)
## What the fight waits for from the players, or null once it no longer does.
signal request_changed(request: Request)
## A message the players have to read and confirm, see Messages. values fill in its
## placeholders.
signal message(id: String, values: Dictionary)
## A short note that needs no confirming, such as why a card cannot be played now.
signal notice(id: String, values: Dictionary)
## Damage went to the boss: absorbed by its shield of kind, and dealt to its health.
signal boss_hit(kind: String, absorbed: int, dealt: int)
signal card_played(play: CardPlay)
signal won
signal lost

enum Phase { SETUP, PLANNING, SHIELD, ACTION, ATTACK, STATUS, DISCARD, DRAW, OVER }

const DAMAGE_TYPES: Array[String] = ["melee", "ranged", "magic"]
const TURNS_PER_ROUND := 3
## For the text of messages: symbols, damage types and tokens.
const NAMES := {
	"attack": { "de": "Angriff", "en": "attack" },
	"support": { "de": "Unterstützung", "en": "support" },
	"protection": { "de": "Schutz", "en": "protection" },
	"heal": { "de": "Heilung", "en": "healing" },
	"melee": { "de": "Nahkampf", "en": "melee" },
	"ranged": { "de": "Fernkampf", "en": "ranged" },
	"magic": { "de": "Magie", "en": "magic" },
	"poison": { "de": "Gift", "en": "poison" },
	"panic": { "de": "Panik", "en": "panic" },
	"paralysis": { "de": "Lähmung", "en": "paralysis" },
	"fire": { "de": "Feuer", "en": "fire" },
}


## Something the fight waits for from the players.
class Request:
	enum Kind {
		## A hero, one of heroes. Answered with choose(), or skip() if can_skip.
		HERO,
		## A card from hero, answered with scan(), or pass_action().
		ACTION,
		## One of options, answered with choose_option(), or skip() if can_skip.
		OPTION,
	}
	var kind: Kind
	## The message (see Messages) that says what to do. It needs no confirming.
	var prompt: String
	var values := {}
	var heroes: Array[FightHero] = []
	## For ACTION, whose card it is.
	var hero: FightHero
	## Message ids, one per option, for OPTION.
	var options: Array[String] = []
	var can_skip := false
	## For ACTION, what the card gets: see Fight.take_action.
	var settings := {}


var boss: Boss
var difficulty: String
## In seat order, which is clockwise around the table.
var heroes: Array[FightHero] = []
## Everything that takes part in the rules, the boss first. See add_rule().
var rules: Array[FightRule] = []
## Counts from 1.
var round_number := 0
var phase := Phase.SETUP
var health := 0
var max_health := 0
## The boss's shields, by damage type.
var shields := {}
## The damage types attacked this round, which Supports need.
var attacked: Array[String] = []
## Who starts this round's action phase.
var starter: FightHero
## Whose turn it is in the action phase, or null.
var active_hero: FightHero
## What the fight waits for from the players, or null.
var request: Request
var over := false
## For everything left to chance, seeded by tests.
var rng := RandomNumberGenerator.new()

var _round_rules: Array[FightRule] = []
var _unread := 0

signal _read
signal _answered(value: Variant)


func _init(fight_boss: Boss, fight_difficulty: String, party_heroes: Array[Party.Hero] = []) -> void:
	boss = fight_boss
	difficulty = fight_difficulty
	max_health = boss.max_health(difficulty)
	health = max_health
	rules.append(boss)
	var sorted := party_heroes.duplicate()
	sorted.sort_custom(func(a: Party.Hero, b: Party.Hero) -> bool: return a.seat < b.seat)
	for party_hero: Party.Hero in sorted:
		heroes.append(FightHero.new(party_hero))


## Runs the fight, until it is won, lost or abandoned.
func start() -> void:
	_run()


#region The players
## The players have read and confirmed all messages, so the fight goes on.
func players_ready() -> void:
	if _unread > 0:
		_unread = 0
		_read.emit()


## Answers a HERO request.
func choose(hero: FightHero) -> void:
	if request != null and request.kind == Request.Kind.HERO and hero in request.heroes:
		_answered.emit(hero)


## Answers an OPTION request with the index of an option.
func choose_option(index: int) -> void:
	if request != null and request.kind == Request.Kind.OPTION and index >= 0 and index < request.options.size():
		_answered.emit(index)


## Declines a request that can be skipped.
func skip() -> void:
	if request != null and request.can_skip:
		_answered.emit(null)


## The hero whose card is asked for gives up the action, as with a Pass card.
func pass_action() -> void:
	if request != null and request.kind == Request.Kind.ACTION:
		_answered.emit(null)


## A card was shown to the camera. Plays it if a card is asked for and it can be played.
## Returns "" if it was played, otherwise the id of a notice for why not (see Messages).
## Returns "ignored" for codes that are not meant for the fight, such as a class card.
func scan(card: Card) -> String:
	if request == null or request.kind != Request.Kind.ACTION:
		return "ignored"
	var hero := request.hero
	if card == null:
		notice.emit("notice_unknown_card", { "player": hero.name })
		return "notice_unknown_card"
	if not card.race.is_empty() or not card.hero_class.is_empty():
		return "ignored"
	var play := CardPlay.new(hero, card)
	play.ignore_lightning = request.settings.get("ignore_lightning", false)
	var problem := _why_not(play)
	if problem.is_empty():
		_answered.emit(play)
	else:
		notice.emit(problem, { "player": hero.name })
	return problem
#endregion


#region For rules
## Shows the players a message, which they confirm before the fight goes on.
func tell(id: String, values := {}) -> void:
	if over:
		return
	_unread += 1
	message.emit(id, values)


## Waits until the players have read every message so far.
func until_read() -> void:
	if _unread > 0 and not over:
		await _read


## Asks the players for a hero. Returns it at once if only one fits and the players
## cannot skip, null if none fits or they skipped.
func choose_hero(choices: Array[FightHero], prompt: String, values := {}, can_skip := false) -> FightHero:
	if choices.is_empty() or over:
		return null
	if choices.size() == 1 and not can_skip:
		return choices[0]
	var asked := Request.new()
	asked.kind = Request.Kind.HERO
	asked.heroes = choices
	asked.prompt = prompt
	asked.values = values
	asked.can_skip = can_skip
	return await _ask(asked)


## Asks the players to pick one of options, each the id of a message. Returns its index,
## or -1 if they skipped.
func choose_from(options: Array[String], prompt: String, values := {}, can_skip := false) -> int:
	if options.is_empty() or over:
		return -1
	var asked := Request.new()
	asked.kind = Request.Kind.OPTION
	asked.options = options
	asked.prompt = prompt
	asked.values = values
	asked.can_skip = can_skip
	var answer: Variant = await _ask(asked)
	return -1 if answer == null else answer


## Lets hero play cards: count actions, plus those Lightning gives. A card played this
## way costs no turn, so abilities use it for cards played "right now".
## settings: "prompt" (a message id, with {player}), "can_skip" (the hero may decline,
## which ends it) and "ignore_lightning".
## Returns the cards played.
func play_actions(hero: FightHero, count: int, settings := {}) -> Array[CardPlay]:
	var plays: Array[CardPlay] = []
	var left := count
	while left > 0 and not over:
		left -= 1
		var play := await take_action(hero, settings)
		if play == null:
			if settings.get("can_skip", false):
				break
			continue
		plays.append(play)
		left += play.extra_actions
	return plays


## Asks hero for one card and plays it, see play_actions(). Returns null if they passed.
func take_action(hero: FightHero, settings := {}) -> CardPlay:
	if over:
		return null
	var asked := Request.new()
	asked.kind = Request.Kind.ACTION
	asked.hero = hero
	asked.heroes = [hero]
	var panic := hero.token_count("panic") > 0
	asked.prompt = settings.get("prompt", "prompt_action_panic" if panic else "prompt_action")
	asked.values = { "player": hero.name }
	asked.can_skip = settings.get("can_skip", false)
	asked.settings = settings
	var play: CardPlay = await _ask(asked)
	if play == null:
		return null
	await play_card(play)
	return play


## Plays a card: the rules see it, then its ability and symbols take effect.
func play_card(play: CardPlay) -> void:
	var hero := play.hero
	if not play.card.is_item():
		hero.played.append(play.card.qr)
	hero.uses[play.card.qr] = hero.uses.get(play.card.qr, 0) + 1
	play.ability = CardAbility.create(play.card)
	await _each_rule("card_playing", [play])
	if play.cancelled or over:
		return
	if play.ability != null:
		await play.ability.before_effects(self, play)
	for effect in play.effects:
		if over or play.cancelled:
			return
		await _apply(play, effect)
	if play.ability != null and not over:
		await play.ability.after_effects(self, play)
	# A panicking hero plays at random, and calms down a little each time.
	if not play.card.is_item() and hero.token_count("panic") > 0:
		hero.add_tokens("panic", -1)
		hero_changed.emit(hero)
		notice.emit("notice_panic_token", { "player": hero.name })
	if over:
		return
	await _each_rule("card_played", [play])
	card_played.emit(play)
	await until_read()


## Damage of kind to the boss: its shield of that kind takes it first. play is the card
## that does it, or null. Returns the damage that reached its health.
func deal_damage(amount: int, kind: String, play: CardPlay = null) -> int:
	if over or amount <= 0:
		return 0
	var absorbed := mini(amount, shields.get(kind, 0))
	if absorbed > 0:
		shields[kind] -= absorbed
		shields_changed.emit(shields)
	var dealt := 0
	if amount > absorbed:
		dealt = amount - absorbed
		for rule in rules.duplicate():
			dealt = rule.damage_taken(self, dealt, kind, play)
		dealt = clampi(dealt, 0, health)
	if play != null:
		play.shield_damage += absorbed
		play.damage += dealt
	boss_hit.emit(kind, absorbed, dealt)
	if dealt > 0:
		var old := health
		set_health(health - dealt)
		await _each_rule("boss_hurt", [old, health])
	return dealt


func set_health(value: int) -> void:
	health = clampi(value, 0, max_health)
	health_changed.emit(health, max_health)
	if health == 0 and not over:
		_finish(true)


## The boss attacks hero with amount this round. effects are what the attack does
## besides damage, as token -> count, such as { "poison": 1 }.
func threaten(hero: FightHero, amount: int, effects := {}) -> void:
	hero.threat = maxi(0, amount)
	hero.threat_effects = effects.duplicate()
	hero_changed.emit(hero)


## Lowers the attack against hero. At exactly 0, its effects are gone too.
func protect(hero: FightHero, amount: int) -> void:
	if hero.threat <= 0:
		return
	hero.threat = maxi(0, hero.threat - amount)
	if hero.threat == 0:
		hero.threat_effects.clear()
	hero_changed.emit(hero)


## The boss strikes hero with what is left of its attack, and its effects.
func strike(hero: FightHero) -> void:
	if hero.threat <= 0:
		return
	var values := { "boss": boss.title, "player": hero.name, "damage": hero.threat }
	if hero.threat_effects.is_empty():
		tell("boss_hits", values)
	else:
		values.tokens = token_text(hero.threat_effects)
		tell("boss_hits_with_tokens", values)
		for token: String in hero.threat_effects:
			hero.add_tokens(token, hero.threat_effects[token])
	hero_changed.emit(hero)


func set_shields(values: Dictionary) -> void:
	shields = {}
	for kind in DAMAGE_TYPES:
		shields[kind] = maxi(0, values.get(kind, 0))
	shields_changed.emit(shields)


## Adds a rule to the fight, such as the lasting effect of a card. With for_round, it
## leaves the fight again at the end of the round.
func add_rule(rule: FightRule, for_round := false) -> void:
	rules.append(rule)
	if for_round:
		_round_rules.append(rule)


func remove_rule(rule: FightRule) -> void:
	rules.erase(rule)
	_round_rules.erase(rule)


## The heroes in turn order, starting with first.
func heroes_from(first: FightHero) -> Array[FightHero]:
	var start := maxi(0, heroes.find(first))
	var ordered: Array[FightHero] = []
	for i in heroes.size():
		ordered.append(heroes[(start + i) % heroes.size()])
	return ordered


func hero_at(seat: int) -> FightHero:
	for hero in heroes:
		if hero.seat == seat:
			return hero
	return null


func others(hero: FightHero) -> Array[FightHero]:
	return heroes_where(func(other: FightHero) -> bool: return other != hero)


## The heroes for whom condition, a Callable taking a FightHero, is true.
func heroes_where(condition: Callable) -> Array[FightHero]:
	var result: Array[FightHero] = []
	for hero in heroes:
		if condition.call(hero):
			result.append(hero)
	return result


## Tokens as text for messages, such as "1 poison, 2 fire", in every language.
func token_text(tokens: Dictionary) -> Dictionary:
	var text := {}
	for language: String in ["de", "en"]:
		var parts := PackedStringArray()
		for token: String in tokens:
			parts.append("%d %s" % [tokens[token], NAMES[token][language]])
		text[language] = ", ".join(parts)
	return text


## Ends the fight as lost, such as when a hero has fallen.
func lose() -> void:
	if not over:
		_finish(false)


## Ends the fight without a result, such as when the players give up.
func abandon() -> void:
	if over:
		return
	over = true
	_release()
#endregion


func _run() -> void:
	await _each_rule("fight_started")
	tell("boss_taunt", { "boss": boss.title, "taunt": boss.taunt })
	await until_read()
	while not over:
		await _play_round()


func _play_round() -> void:
	round_number += 1
	attacked.clear()
	for hero in heroes:
		hero.threat = 0
		hero.threat_effects.clear()
		hero.played.clear()
		hero.turns_left = TURNS_PER_ROUND + hero.bonus_turns
		hero.bonus_turns = 0
		hero_changed.emit(hero)
	round_changed.emit(round_number)
	tell("round_started", { "round": round_number })
	await _each_rule("round_started")
	await until_read()
	if over:
		return

	await _phase(Phase.PLANNING)
	tell("phase_planning", { "boss": boss.title })
	await boss.plan_attacks(self)
	await _each_rule("attacks_planned")
	await until_read()
	if over:
		return
	# Knowing the boss's attacks, the players choose who starts.
	await _choose_starter()
	if over:
		return

	await _phase(Phase.SHIELD)
	await boss.raise_shields(self)
	await _each_rule("shields_raised")
	if shields.values().any(func(value: int) -> bool: return value > 0):
		tell("phase_shield", { "boss": boss.title, "melee": shields.melee, "ranged": shields.ranged, "magic": shields.magic })
	else:
		tell("phase_shield_none", { "boss": boss.title })
	await until_read()
	if over:
		return

	await _phase(Phase.ACTION)
	tell("phase_action", { "player": starter.name if starter != null else "" })
	await _each_rule("action_phase_started")
	await until_read()
	if over:
		return
	await _action_phase()
	await _each_rule("action_phase_ended")
	await until_read()
	if over:
		return

	await _phase(Phase.ATTACK)
	var hit := false
	for hero in heroes:
		if hero.threat > 0:
			hit = true
		await boss.attack_hero(self, hero)
		if over:
			return
	if not hit:
		tell("phase_attack_blocked", { "boss": boss.title })
	await _each_rule("attack_phase_ended")
	await until_read()
	if over:
		return

	await _phase(Phase.STATUS)
	var suffered := false
	for hero in heroes:
		if hero.token_count("poison") > 0:
			suffered = true
			tell("status_poison", { "player": hero.name, "count": hero.token_count("poison") })
		if hero.token_count("fire") > 0:
			suffered = true
			tell("status_fire", { "player": hero.name, "count": hero.token_count("fire") })
	if not suffered:
		tell("phase_status_none")
	await until_read()
	if over:
		return

	await _phase(Phase.DISCARD)
	tell("phase_discard")
	await until_read()
	if over:
		return

	await _phase(Phase.DRAW)
	tell("phase_draw")
	for hero in heroes:
		if hero.token_count("paralysis") > 0:
			tell("reminder_paralysis", { "player": hero.name, "count": hero.token_count("paralysis") })
	await until_read()
	if over:
		return

	await _each_rule("round_ended")
	for rule in _round_rules:
		rules.erase(rule)
	_round_rules.clear()
	await until_read()
	if over:
		return


func _choose_starter() -> void:
	if starter == null or not starter in heroes:
		starter = heroes[0] if not heroes.is_empty() else null
	var chosen := await choose_hero(heroes, "prompt_choose_starter")
	if chosen != null:
		starter = chosen
	if starter != null:
		await _each_rule("starter_chosen", [starter])


func _action_phase() -> void:
	if starter == null:
		return
	var order := heroes_from(starter)
	var any_left := true
	while any_left and not over:
		any_left = false
		for hero in order:
			if hero.turns_left <= 0 or over:
				continue
			hero.turns_left -= 1
			await _take_turn(hero)
			any_left = any_left or hero.turns_left > 0
		# Turns gained during the round, such as from a card, still count.
		any_left = any_left or order.any(func(hero: FightHero) -> bool: return hero.turns_left > 0)
	active_hero = null
	turn_changed.emit(null)


func _take_turn(hero: FightHero) -> void:
	active_hero = hero
	hero_changed.emit(hero)
	turn_changed.emit(hero)
	await _each_rule("turn_started", [hero])
	await play_actions(hero, 1)
	if not over:
		await _each_rule("turn_ended", [hero])


func _apply(play: CardPlay, effect: CardPlay.Effect) -> void:
	var hero := play.hero
	match effect.type:
		"attack":
			if not effect.damage_type in attacked:
				attacked.append(effect.damage_type)
			await deal_damage(effect.strength, effect.damage_type, play)
		"support":
			if effect.damage_type in attacked:
				await deal_damage(effect.strength, effect.damage_type, play)
			else:
				tell("support_without_attack", { "player": hero.name, "kind": NAMES.get(effect.damage_type, effect.damage_type) })
		"protection":
			var threatened := heroes_where(func(other: FightHero) -> bool: return other.threat > 0)
			var target := await choose_hero(threatened, "prompt_protect", { "player": hero.name, "amount": effect.strength })
			if target != null:
				var amount := effect.strength
				for rule in rules.duplicate():
					amount = rule.protection(self, amount, target, play)
				protect(target, amount)
		"heal":
			tell("heal", { "player": hero.name, "amount": effect.strength })
		"lightning":
			if not play.ignore_lightning:
				play.extra_actions += effect.strength
				notice.emit("notice_lightning", { "player": hero.name })
		"draw":
			tell("draw_cards", { "player": hero.name, "count": effect.strength })
		_:
			push_warning("Card %s: unknown symbol '%s'" % [play.card.qr, effect.type])
	await until_read()


func _why_not(play: CardPlay) -> String:
	var card := play.card
	var hero := play.hero
	if card.qr in hero.played:
		return "notice_played_already"
	var deck_owner := card.deck in HeroOptions.RACES or card.deck in HeroOptions.CLASSES
	if deck_owner and card.deck != hero.hero.race and card.deck != hero.hero.hero_class:
		return "notice_not_your_card"
	if card.uses_per_fight > 0 and hero.uses.get(card.qr, 0) >= card.uses_per_fight:
		return "notice_used_up"
	var ability := CardAbility.create(card)
	if ability != null:
		return ability.can_play(self, play)
	return ""


func _phase(new_phase: Phase) -> void:
	if over and new_phase != Phase.OVER:
		return
	phase = new_phase
	phase_changed.emit(phase)


func _ask(asked: Request) -> Variant:
	await until_read()
	if over:
		return null
	request = asked
	request_changed.emit(asked)
	var answer: Variant = await _answered
	if request == asked:
		request = null
		request_changed.emit(null)
	return answer


func _each_rule(hook: String, arguments := []) -> void:
	for rule in rules.duplicate():
		if over:
			return
		await rule.callv(hook, [self] + arguments)


func _finish(victory: bool) -> void:
	over = true
	_phase(Phase.OVER)
	_unread += 1
	message.emit("victory" if victory else "defeat", { "boss": boss.title })
	if victory:
		won.emit()
	else:
		lost.emit()
	_release()


## Lets everything that waits for the players run to its end, now that the fight is over.
func _release() -> void:
	active_hero = null
	if request != null:
		request = null
		request_changed.emit(null)
	_answered.emit(null)
	_read.emit()
