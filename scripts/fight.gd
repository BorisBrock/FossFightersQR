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
## The boss's poison tokens changed.
signal poison_changed(poison: int)
## The boss has raised its shields for the round. The view shows them rising instead of a
## message, so the fight goes on without waiting for the players.
signal shields_raised(shields: Dictionary)
## Its attack, its turns or its actions changed.
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
## The kind of damage from the broken heart: no shield takes it.
const DIRECT := "direct"
## The kind of damage the boss's poison does at the end of a round: no shield takes it.
const POISON := "poison"
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
## The boss's poison tokens. They stay for the whole fight, and at the end of each round
## each costs the boss 1 health (see FightRule.poison_damage).
var poison := 0
## The cards out of the game for the rest of the fight (remove_from_game), by QR code.
## They cannot be played again, by any hero.
var removed: Array[String] = []
## Every card played in the fight so far, in order, not counting replays
## (CardPlay.replay).
var history: Array[CardPlay] = []
## The damage types attacked this round, which Supports need.
var attacked: Array[String] = []
## Who starts this round's action phase.
var starter: FightHero
## Whose turn it is in the action phase, or null.
var active_hero: FightHero
## What the fight waits for from the players, or null.
var request: Request
var over := false
## What happened in the fight so far, for the game over screen.
var stats: FightStats
## For everything left to chance, seeded by tests.
var rng := RandomNumberGenerator.new()

var _round_rules: Array[FightRule] = []
var _unread := 0

signal _read
signal _answered(value: Variant)


## cards is where the heroes' character and class cards are looked up, for what their
## levels give them (see _add_traits). Without, the heroes have none.
func _init(fight_boss: Boss, fight_difficulty: String, party_heroes: Array[Party.Hero] = [], cards: CardDatabase = null) -> void:
	boss = fight_boss
	difficulty = fight_difficulty
	max_health = boss.max_health(difficulty)
	health = max_health
	rules.append(boss)
	var sorted := party_heroes.duplicate()
	sorted.sort_custom(func(a: Party.Hero, b: Party.Hero) -> bool: return a.seat < b.seat)
	for party_hero: Party.Hero in sorted:
		heroes.append(FightHero.new(party_hero))
	stats = FightStats.new(heroes, max_health)
	if cards != null:
		_add_traits(cards)


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
	var only: Callable = request.settings.get("only", Callable())
	if problem.is_empty() and only.is_valid() and not only.call(card):
		problem = "notice_not_allowed_now"
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


## Asks the players a question with yes and no. Returns true for yes.
func confirm(prompt: String, values := {}) -> bool:
	return await choose_from(["option_yes", "option_no"], prompt, values) == 0


## hero loses amount health, from play or something else (null). The players are told,
## as the heroes' health is on the table.
func hurt_hero(hero: FightHero, amount: int, play: CardPlay = null) -> void:
	if amount <= 0 or over:
		return
	tell("health_loss", { "player": hero.name, "amount": amount })
	await _each_rule("hero_hurt", [hero, amount, play])


## The boss is about to use its @-ability id, of this strength, against target (null for
## everyone or nobody). Returns whether it may: cards can prevent it, and then the players
## are told by what.
func boss_ability(id: String, strength: int, target: FightHero = null) -> bool:
	if over:
		return false
	var ability := BossAbility.new()
	ability.id = id
	ability.strength = strength
	ability.target = target
	await _each_rule("boss_ability_used", [ability])
	if ability.prevented:
		tell("boss_ability_prevented", { "boss": boss.title, "card": ability.prevented_by })
		await until_read()
	return not ability.prevented and not over


## The attack against from now threatens to instead, with its effects. from is no
## longer threatened. What instead was threatened with is gone.
func redirect_attack(from: FightHero, to: FightHero) -> void:
	to.threat = from.threat
	to.threat_effects = from.threat_effects.duplicate()
	from.threat = 0
	from.threat_effects.clear()
	hero_changed.emit(from)
	hero_changed.emit(to)


## Lets hero play cards: count actions, plus those Lightning gives. A card played this
## way costs no turn, so abilities use it for cards played "right now".
## settings: "prompt" (a message id, with {player}), "can_skip" (the hero may decline,
## which ends it), "ignore_lightning", "limited" (what can be played is limited, such
## as to the top card of the draw pile, which the screen shows), and "only" (a Callable
## taking a Card, false for cards that cannot be played now).
## Returns the cards played.
func play_actions(hero: FightHero, count: int, settings := {}) -> Array[CardPlay]:
	var plays: Array[CardPlay] = []
	if count <= 0 or over:
		return plays
	_reserve(hero, _action_kind(settings), count)
	var left := count
	while left > 0 and not over:
		left -= 1
		var play := await _take_reserved(hero, settings)
		if play == null:
			if settings.get("can_skip", false):
				_unreserve(hero, left)
				break
			continue
		plays.append(play)
		left += play.extra_actions
	return plays


## Asks hero for one card and plays it, see play_actions(). Returns null if they passed.
## Lightning on the card is left to the caller, through CardPlay.extra_actions.
func take_action(hero: FightHero, settings := {}) -> CardPlay:
	if over:
		return null
	_reserve(hero, _action_kind(settings), 1)
	var play := await _take_reserved(hero, settings)
	if play != null:
		_unreserve(hero, play.extra_actions)
	return play


## The card gives its hero count more actions right away, such as from Lightning.
func give_actions(play: CardPlay, count: int) -> void:
	if count <= 0:
		return
	play.extra_actions += count
	_reserve(play.hero, FightHero.Action.BONUS, count)


## Asks for the card of an action already among hero.pending, which it spends.
func _take_reserved(hero: FightHero, settings: Dictionary) -> CardPlay:
	if over:
		return null
	var asked := Request.new()
	asked.kind = Request.Kind.ACTION
	asked.hero = hero
	asked.heroes = [hero]
	asked.prompt = settings.get("prompt", "prompt_action")
	asked.values = { "player": hero.name }
	asked.can_skip = settings.get("can_skip", false)
	asked.settings = settings
	var play: CardPlay = await _ask(asked)
	_unreserve(hero, 1)
	if play == null:
		if not over:
			stats.passed(hero)
		return null
	await play_card(play)
	return play


func _action_kind(settings: Dictionary) -> FightHero.Action:
	if settings.get("limited", false):
		return FightHero.Action.LIMITED
	return settings.get("action", FightHero.Action.BONUS)


func _reserve(hero: FightHero, kind: FightHero.Action, count: int) -> void:
	for i in count:
		hero.pending.append(kind)
	hero_changed.emit(hero)


func _unreserve(hero: FightHero, count: int) -> void:
	if count <= 0 or hero.pending.is_empty():
		return
	hero.pending.resize(maxi(0, hero.pending.size() - count))
	hero_changed.emit(hero)


## Plays a card: the rules see it, then its ability and symbols take effect.
## A replay (CardPlay.replay) is not counted as played, and keeps the ability it has.
func play_card(play: CardPlay) -> void:
	var hero := play.hero
	play.round_number = round_number
	if not play.replay:
		if not play.card.is_item():
			hero.played.append(play.card.qr)
		hero.uses[play.card.qr] = hero.uses.get(play.card.qr, 0) + 1
		history.append(play)
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
	if over:
		return
	await _each_rule("card_played", [play])
	if not play.replay:
		stats.card_played(play)
	card_played.emit(play)
	await until_read()


## Plays the card of original once more, as some cards make happen: the rules see it
## again, then its ability and symbols take effect, but the card is not played a second
## time (CardPlay.replay). Lightning on it gives extra actions only if by, the card that
## makes it happen, is of the same hero, and then through by, as by's own Lightning would.
func play_again(original: CardPlay, by: CardPlay) -> CardPlay:
	var again := CardPlay.new(original.hero, original.card)
	again.replay = true
	again.ignore_lightning = original.ignore_lightning or by == null or by.hero != original.hero
	again.ability = CardAbility.create(original.card)
	await play_card(again)
	if not again.ignore_lightning:
		by.extra_actions += again.extra_actions
	return again


## Damage of kind to the boss: its shield of that kind takes it first. DIRECT damage has no
## shield and goes straight to its health. play is the card
## that does it, or null. Returns the damage that reached its health.
func deal_damage(amount: int, kind: String, play: CardPlay = null) -> int:
	if over or amount <= 0:
		return 0
	var absorbed := mini(amount, shields.get(kind, 0))
	if absorbed > 0:
		shields[kind] -= absorbed
		shields_changed.emit(shields)
		var ignored := false
		for rule in rules.duplicate():
			ignored = ignored or rule.ignores_shield_effect(self, kind, play)
		if not ignored:
			await boss.shield_hit(self, kind, absorbed, play)
		if shields[kind] == 0:
			await _each_rule("shield_broken", [kind, play])
		if over:
			return 0
	var dealt := 0
	if amount > absorbed:
		dealt = amount - absorbed
		for rule in rules.duplicate():
			dealt = rule.damage_taken(self, dealt, kind, play)
		dealt = clampi(dealt, 0, health)
	if play != null:
		play.shield_damage += absorbed
		play.damage += dealt
	stats.damage_dealt(dealt, absorbed, play)
	boss_hit.emit(kind, absorbed, dealt)
	if dealt > 0:
		var old := health
		set_health(health - dealt)
		await _each_rule("boss_hurt", [old, health])
	return dealt


## The boss gets amount poison tokens, from play or something else (null).
func poison_boss(amount: int, play: CardPlay = null) -> void:
	if amount <= 0 or over:
		return
	poison += amount
	poison_changed.emit(poison)
	await _each_rule("boss_poisoned", [amount, play])


func set_poison(value: int) -> void:
	poison = maxi(0, value)
	poison_changed.emit(poison)


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
	stats.attack_planned(hero, hero.threat)
	hero_changed.emit(hero)


## Lowers the attack against hero. At exactly 0, its effects are gone too.
func protect(hero: FightHero, amount: int) -> void:
	if hero.threat <= 0:
		return
	hero.threat = maxi(0, hero.threat - amount)
	if hero.threat == 0:
		hero.threat_effects.clear()
	hero_changed.emit(hero)


## The boss strikes hero with what is left of its attack, and its effects. The players
## put the tokens on the table.
func strike(hero: FightHero) -> void:
	if hero.threat <= 0:
		return
	var values := { "boss": boss.title, "player": hero.name, "damage": hero.threat }
	var token_count := 0
	for token: String in hero.threat_effects:
		token_count += hero.threat_effects[token]
	stats.hero_hit(hero, hero.threat, token_count)
	if hero.threat_effects.is_empty():
		tell("boss_hits", values)
	else:
		values.tokens = token_text(hero.threat_effects)
		tell("boss_hits_with_tokens", values)
	hero_changed.emit(hero)
	await _each_rule("hero_hurt", [hero, hero.threat, null])


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
	stats.finished(FightStats.Outcome.ABORTED, health)
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
	stats.round_started(round_number)
	attacked.clear()
	for hero in heroes:
		hero.threat = 0
		hero.threat_effects.clear()
		hero.played.clear()
		hero.turns_left = TURNS_PER_ROUND + hero.bonus_turns
		hero.extra_turns = hero.bonus_turns
		hero.bonus_turns = 0
		hero.pending.clear()
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
	await until_read()
	if over:
		return
	shields_raised.emit(shields)

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
		stats.attack_resolved(hero, hero.threat)
		await boss.attack_hero(self, hero)
		if over:
			return
	if not hit:
		tell("phase_attack_blocked", { "boss": boss.title })
	await _each_rule("attack_phase_ended")
	await until_read()
	if over:
		return

	# The status tokens are on the table, so the players apply them.
	await _phase(Phase.STATUS)
	tell("phase_status")
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
	await until_read()
	if over:
		return

	await _poison_tick()
	if over:
		return
	await _each_rule("round_ended")
	for rule in _round_rules:
		rules.erase(rule)
	_round_rules.clear()
	stats.round_ended(health)
	await until_read()
	if over:
		return


## At the end of the round, the boss's poison hurts it, past its shields.
func _poison_tick() -> void:
	if poison <= 0:
		return
	var damage := poison
	for rule in rules.duplicate():
		damage = rule.poison_damage(self, damage)
	if damage <= 0:
		return
	tell("boss_poison", { "boss": boss.title, "poison": poison, "damage": damage })
	await until_read()
	await deal_damage(damage, POISON)


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
			var kind := FightHero.Action.BONUS if hero.next_turn_is_extra() else FightHero.Action.TURN
			hero.turns_left -= 1
			await _take_turn(hero, kind)
			any_left = any_left or hero.turns_left > 0
		# Turns gained during the round, such as from a card, still count.
		any_left = any_left or order.any(func(hero: FightHero) -> bool: return hero.turns_left > 0)
	active_hero = null
	turn_changed.emit(null)


func _take_turn(hero: FightHero, kind: FightHero.Action) -> void:
	active_hero = hero
	hero_changed.emit(hero)
	turn_changed.emit(hero)
	await _each_rule("turn_started", [hero])
	await play_actions(hero, 1, { "action": kind })
	if not over:
		await _each_rule("turn_ended", [hero])


func _apply(play: CardPlay, effect: CardPlay.Effect) -> void:
	var hero := play.hero
	match effect.type:
		"attack":
			var opened := not effect.damage_type in attacked
			if opened:
				attacked.append(effect.damage_type)
			stats.power_played(hero, effect.damage_type, effect.strength)
			await deal_damage(effect.strength, effect.damage_type, play)
			if opened:
				await _each_rule("attack_type_opened", [effect.damage_type, play])
		"support":
			var allowed := effect.damage_type in attacked
			for rule in rules.duplicate():
				allowed = allowed or rule.support_without_attack(self, effect.damage_type, play)
			if allowed:
				stats.power_played(hero, effect.damage_type, effect.strength)
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
				var before := target.threat
				protect(target, amount)
				stats.protected(hero, before - target.threat)
				if not target in play.protected:
					play.protected.append(target)
				await _each_rule("hero_protected", [target, before, play])
		"heal":
			for receiver in play.receivers():
				stats.healed(hero, effect.strength)
				tell("heal", { "player": receiver.name, "amount": effect.strength })
		"lightning":
			if not play.ignore_lightning:
				give_actions(play, effect.strength)
				notice.emit("notice_lightning", { "player": hero.name })
		"draw":
			var receivers := play.receivers()
			if receivers.size() > 1 and receivers.size() == heroes.size():
				tell("draw_cards_everyone", { "count": effect.strength })
			else:
				for receiver in receivers:
					tell("draw_cards", { "player": receiver.name, "count": effect.strength })
		"health_loss":
			await hurt_hero(hero, effect.strength, play)
		"direct_damage":
			await deal_damage(effect.strength, DIRECT, play)
		"take_from_pile":
			for receiver in play.receivers():
				tell("take_from_pile", { "player": receiver.name, "count": effect.strength })
		"poison":
			await poison_boss(effect.strength, play)
		"remove_from_game":
			if not play.card.qr in removed:
				removed.append(play.card.qr)
			tell("card_removed", { "player": hero.name })
		"special":
			pass  # Only marks the card: what it does is its ability.
		_:
			push_warning("Card %s: unknown symbol '%s'" % [play.card.qr, effect.type])
	await until_read()


func _why_not(play: CardPlay) -> String:
	var card := play.card
	var hero := play.hero
	if card.qr in removed:
		return "notice_removed"
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


## What the heroes' levels give them: the ability of their character and class card,
## which stays in the fight as a rule, for its hero (CardAbility.owner).
func _add_traits(cards: CardDatabase) -> void:
	for fight_hero in heroes:
		for qr: String in [fight_hero.hero.race_card, fight_hero.hero.class_card]:
			var card := cards.find(qr) if not qr.is_empty() else null
			# Only a card of the hero's own race or class, should the party file say otherwise.
			if card == null or (card.race != fight_hero.hero.race and card.hero_class != fight_hero.hero.hero_class):
				continue
			var ability := CardAbility.create(card)
			if ability != null:
				ability.owner = fight_hero
				rules.append(ability)


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
	stats.finished(FightStats.Outcome.WON if victory else FightStats.Outcome.LOST, health)
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
	for hero in heroes:
		if not hero.pending.is_empty():
			hero.pending.clear()
			hero_changed.emit(hero)
	if request != null:
		request = null
		request_changed.emit(null)
	_answered.emit(null)
	_read.emit()
