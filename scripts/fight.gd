class_name Fight
extends RefCounted
## The rules of a boss fight, and what is going on in it: the boss, its health and shields,
## the heroes, the round and the phase. See docs/boss_fight.md.
##
## The fight runs by itself from start() on, round after round, phase after phase, and
## waits for the players whenever it needs them:
## - until they have read its messages (players_ready()), and seen what the screen shows
##   (hold_screen(), release_screen()), such as a hit on the boss,
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
## The boss went out of reach, such as under water, or came back (see boss_away).
signal boss_away_changed(away: bool)
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
## A hero attacks the boss with amount of kind, one of DAMAGE_TYPES, before its shield
## takes any of it (see boss_hit). The screen shows the attack.
signal boss_attacked(kind: String, amount: int)
## Damage went to the boss: absorbed by its shield of kind, and dealt to its health.
signal boss_hit(kind: String, absorbed: int, dealt: int)
## The damage types attacked this round changed (attacked): one was attacked for the first
## time, or a new round cleared them.
signal attacked_changed(kinds: Array[String])
signal card_played(play: CardPlay)
## A card begins to be played, before anything it does: the screen shows its name.
signal card_started(play: CardPlay)
## A rule that shows on screen (FightRule.buff) came or went, or its buff changed. See
## buffs().
signal buffs_changed
signal won
signal lost

## ROUND_END is phases 5 to 7 of the rules, status, discard and draw: the players do them
## at the table, together.
enum Phase { SETUP, PLANNING, SHIELD, ACTION, ATTACK, ROUND_END, OVER }

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
		## One of the boss's shields, by damage type, one of kinds. Answered with
		## choose_shield(), or skip() if can_skip. The screen makes the shields tappable.
		SHIELD,
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
	## Damage types, one per shield that can be chosen, for SHIELD.
	var kinds: Array[String] = []
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
## Whether the boss is out of reach, such as under water: damage from cards and the
## poison they give do not reach it. Its own poison at the end of a round still does.
var boss_away := false
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
## How many things the screen is showing that the fight waits for, see hold_screen().
var _screen_holds := 0
## The boss's hits in this attack phase, as [hero, damage, effects], told together.
var _hits: Array[Array] = []
## Where what happens now comes from, innermost last, see source().
var _sources: Array[Dictionary] = []

signal _read
signal _screen_released
signal _answered(value: Variant)


## cards is where the heroes' character and class cards are looked up, for what their
## levels give them (see _add_traits). Without, the heroes have none.
func _init(fight_boss: Boss, fight_difficulty: String, party_heroes: Array[Party.Hero] = [], cards: CardDatabase = null) -> void:
	boss = fight_boss
	difficulty = fight_difficulty
	rules.append(boss)
	var sorted := party_heroes.duplicate()
	sorted.sort_custom(func(a: Party.Hero, b: Party.Hero) -> bool: return a.seat < b.seat)
	for party_hero: Party.Hero in sorted:
		heroes.append(FightHero.new(party_hero))
	max_health = boss.max_health(difficulty, heroes.size())
	health = max_health
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


## The screen shows something the players should see before the fight goes on, such as
## a hit on the boss: until_read() waits for it, as for messages. Each call needs a
## release_screen().
func hold_screen() -> void:
	_screen_holds += 1


## The screen is done with what hold_screen() waited for.
func release_screen() -> void:
	if _screen_holds <= 0:
		return
	_screen_holds -= 1
	if _screen_holds == 0:
		_screen_released.emit()


## Answers a HERO request.
func choose(hero: FightHero) -> void:
	if request != null and request.kind == Request.Kind.HERO and hero in request.heroes:
		_answered.emit(hero)


## Answers an OPTION request with the index of an option.
func choose_option(index: int) -> void:
	if request != null and request.kind == Request.Kind.OPTION and index >= 0 and index < request.options.size():
		_answered.emit(index)


## Answers a SHIELD request with the damage type of a shield.
func choose_shield(kind: String) -> void:
	if request != null and request.kind == Request.Kind.SHIELD and kind in request.kinds:
		_answered.emit(kind)


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
## code is the value of the QR code, shown to the players if no card has it.
func scan(card: Card, code := "") -> String:
	if request == null or request.kind != Request.Kind.ACTION:
		return "ignored"
	var hero := request.hero
	if card == null:
		notice.emit("notice_unknown_card", { "player": hero.name, "code": code })
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
## Shows the players a message, which they confirm before the fight goes on. It comes
## with where it comes from, as values.source (see source()), unless values has one.
func tell(id: String, values := {}) -> void:
	if over:
		return
	_unread += 1
	if not values.has("source") and not source().is_empty():
		values = values.duplicate()
		values.source = source()
	message.emit(id, values)


## Where what happens now comes from, so that the players know what a message is about:
## the card being played, the rule acting, such as a hero's class or a card's lasting
## effect, or the boss. { "title": its name, as text or { "de": …, "en": … }, "hero": the
## name of the hero it is for } (each only if known), or empty for the fight itself.
func source() -> Dictionary:
	return _sources.back() if not _sources.is_empty() else {}


## Waits until the players have read every message so far, and the screen has shown what
## happened (hold_screen()).
func until_read() -> void:
	while not over and (_unread > 0 or _screen_holds > 0):
		if _unread > 0:
			await _read
		else:
			await _screen_released


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


## Asks the players to tap one of the boss's shields, by damage type, one of kinds.
## Returns it at once if only one fits and the players cannot skip, "" if none fits or
## they skipped.
func choose_shield_from(kinds: Array[String], prompt: String, values := {}, can_skip := false) -> String:
	if kinds.is_empty() or over:
		return ""
	if kinds.size() == 1 and not can_skip:
		return kinds[0]
	var asked := Request.new()
	asked.kind = Request.Kind.SHIELD
	asked.kinds = kinds
	asked.prompt = prompt
	asked.values = values
	asked.can_skip = can_skip
	var answer: Variant = await _ask(asked)
	return "" if answer == null else answer


## Asks the players a question with yes and no. Returns true for yes.
func confirm(prompt: String, values := {}) -> bool:
	return await choose_from(["option_yes", "option_no"], prompt, values) == 0


## hero loses amount health, from play or something else (null). The players are told,
## as the heroes' health is on the table, unless told: a message has already told them,
## such as one for several heroes at once.
func hurt_hero(hero: FightHero, amount: int, play: CardPlay = null, told := false) -> void:
	if amount <= 0 or over:
		return
	if not told:
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
## as to the top card of the draw pile, which the screen shows), "only" (a Callable
## taking a Card, false for cards that cannot be played now) and "values" (more values
## for the prompt, besides {player}).
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
## With "reserved" in settings, the action is one reserve_actions() already shows.
func take_action(hero: FightHero, settings := {}) -> CardPlay:
	if over:
		return null
	if not settings.get("reserved", false):
		_reserve(hero, _action_kind(settings), 1)
	var play := await _take_reserved(hero, settings)
	if play != null:
		_unreserve(hero, play.extra_actions)
	return play


## Shows count actions of the kind settings ask for (see play_actions()) among hero's,
## for abilities that then take them one by one with take_action() and "reserved", so
## that all of them show from the start. Those the fight ends before are dropped.
func reserve_actions(hero: FightHero, count: int, settings := {}) -> void:
	if count > 0 and not over:
		_reserve(hero, _action_kind(settings), count)


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
	asked.values = settings.get("values", {}).duplicate()
	asked.values.player = hero.name
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
## What it tells comes from the card (source()).
func play_card(play: CardPlay) -> void:
	_sources.push_back({ "title": play.card.title, "hero": play.hero.name })
	await _play_card(play)
	_sources.pop_back()


func _play_card(play: CardPlay) -> void:
	var hero := play.hero
	play.round_number = round_number
	if not play.replay:
		if not play.card.stays_on_table():
			hero.played.append(play.card.qr)
		hero.uses[play.card.qr] = hero.uses.get(play.card.qr, 0) + 1
		history.append(play)
		play.ability = CardAbility.create(play.card)
		card_started.emit(play)
	if play.ability != null:
		play.ability.set_strength(self, play)
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
	if boss_away and kind != POISON:
		_miss(play)
		return 0
	if kind in DAMAGE_TYPES:
		boss_attacked.emit(kind, amount)
	var absorbed := mini(amount, shields.get(kind, 0))
	if absorbed > 0:
		shields[kind] -= absorbed
		shields_changed.emit(shields)
		var ignored := false
		for rule in rules.duplicate():
			ignored = ignored or _rule_value(rule, "ignores_shield_effect", [kind, play])
		if not ignored:
			await _rule_hook(boss, "shield_hit", [kind, absorbed, play])
		if shields[kind] == 0:
			await _each_rule("shield_broken", [kind, play])
		if over:
			return 0
	var dealt := 0
	if amount > absorbed:
		dealt = amount - absorbed
		for rule in rules.duplicate():
			dealt = _rule_value(rule, "damage_taken", [dealt, kind, play])
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


## Lowers the boss's shield of kind by up to amount, from play or something else (null),
## without setting off what the shield does besides absorbing (Boss.shield_hit). What is
## more than the shield has is lost: it does not reach the boss's health. A shield brought
## to 0 is broken (FightRule.shield_broken). Returns how much it went down.
func lower_shield(kind: String, amount: int, play: CardPlay = null) -> int:
	var lowered := mini(maxi(0, amount), shields.get(kind, 0))
	if over or lowered <= 0:
		return 0
	shields[kind] -= lowered
	shields_changed.emit(shields)
	if play != null:
		play.shield_damage += lowered
	stats.damage_dealt(0, lowered, play)
	boss_hit.emit(kind, lowered, 0)
	if shields[kind] == 0:
		await _each_rule("shield_broken", [kind, play])
	return lowered


## The boss gets amount poison tokens, from play or something else (null).
func poison_boss(amount: int, play: CardPlay = null) -> void:
	if amount <= 0 or over:
		return
	if boss_away and play != null:
		_miss(play)
		return
	poison += amount
	poison_changed.emit(poison)
	await _each_rule("boss_poisoned", [amount, play])


## The boss goes out of reach, or comes back (boss_away).
func set_boss_away(away: bool) -> void:
	if away == boss_away:
		return
	boss_away = away
	boss_away_changed.emit(away)


## A card's damage or poison misses the boss, which is out of reach. The players are told
## once per card.
func _miss(play: CardPlay) -> void:
	if play != null:
		if play.missed:
			return
		play.missed = true
	tell(boss.away_message, { "boss": boss.title })


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


## The boss strikes hero with what is left of its attack, and its effects, in the attack
## phase. The players are told of all its hits at once, when every hero has been struck,
## and put the tokens on the table. Only then do the rules hear of them (hero_struck,
## hero_hurt), so that what they tell follows the hits.
func strike(hero: FightHero) -> void:
	if hero.threat <= 0:
		return
	var token_count := 0
	for token: String in hero.threat_effects:
		token_count += hero.threat_effects[token]
	stats.hero_hit(hero, hero.threat, token_count)
	_hits.append([hero, hero.threat, hero.threat_effects.duplicate()])
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
	if rule.origin.is_empty():
		rule.origin = source()
	if rule.buff() != null:
		buffs_changed.emit()


func remove_rule(rule: FightRule) -> void:
	if not rule in rules:
		return
	var shown := rule.buff() != null
	rules.erase(rule)
	_round_rules.erase(rule)
	if shown:
		buffs_changed.emit()


## What the rules in the fight show on screen (FightRule.buff), in the order they came.
## With hero, only that hero's; with everyone, only those for everyone.
func buffs(hero: FightHero = null, everyone := false) -> Array[FightBuff]:
	var result: Array[FightBuff] = []
	for rule in rules:
		var buff := rule.buff()
		if buff == null:
			continue
		if (hero != null and buff.hero != hero) or (everyone and buff.hero != null):
			continue
		result.append(buff)
	return result


## Whether hero has a totem token on the table: a Totem played this round is for them.
func has_totem(hero: FightHero) -> bool:
	return buffs(hero).any(func(buff: FightBuff) -> bool: return buff.totem)


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
	if over:
		return
	while not over:
		await _play_round()


## Each hero's hand limit, as message parts, one per hero: how many cards they draw up to,
## for their starting hand and at the end of each round.
func _hand_limits() -> Array:
	var parts := []
	for hero in heroes:
		parts.append(["hand_limit_draw", { "player": hero.name, "count": HeroOptions.hand_limit(hero.hero.race, hero.hero.hero_class) }])
	return parts


func _play_round() -> void:
	round_number += 1
	stats.round_started(round_number)
	attacked.clear()
	attacked_changed.emit(attacked)
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
	# The new round with a word from the boss, then its planning, which the screen shows
	# as it happens. The first round also has everyone draw their starting hand, so it
	# waits for the check mark.
	var values := { "round": round_number, "boss": boss.title, "flavor": boss.round_text(round_number) }
	if round_number == 1:
		values.draws = _hand_limits()
		tell("first_round", values)
	else:
		tell("round_started", values)
	await _each_rule("round_started")
	if over:
		return

	await _phase(Phase.PLANNING)
	tell("boss_planning", { "boss": boss.title })
	await _rule_hook(boss, "plan_attacks")
	await _each_rule("attacks_planned")
	await until_read()
	if over:
		return

	await _phase(Phase.SHIELD)
	await _rule_hook(boss, "raise_shields")
	await _each_rule("shields_raised")
	await until_read()
	if over:
		return
	shields_raised.emit(shields)
	# Knowing the boss's attacks and shields, the players choose who starts.
	await _choose_starter()
	if over:
		return

	await _phase(Phase.ACTION)
	# In the first round nobody can have a curse yet.
	if round_number > 1:
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
	_hits.clear()
	for hero in heroes:
		if hero.threat > 0:
			hit = true
		stats.attack_resolved(hero, hero.threat)
		await _rule_hook(boss, "attack_hero", [hero])
		if over:
			return
	if not hit:
		tell("phase_attack_blocked", { "boss": boss.title })
	await _tell_hits()
	if over:
		return
	await _each_rule("attack_phase_ended")
	await until_read()
	if over:
		return

	# Status, discard and draw: the status tokens and the cards are on the table, so the
	# players do all three there, told in a short message each. What rules remind them of
	# comes first, such as a card not to discard.
	await _phase(Phase.ROUND_END)
	await _each_rule("round_end_started")
	tell("round_end_status")
	tell("round_end_discard")
	tell("round_end_draw", { "draws": _hand_limits() })
	await until_read()
	if over:
		return

	await _poison_tick()
	if over:
		return
	await _each_rule("round_ended")
	await _end_round_rules()
	stats.round_ended(health)
	await until_read()
	if over:
		return


## Tells the players of the boss's hits, one line each, then lets the rules hear of them.
func _tell_hits() -> void:
	if _hits.is_empty():
		return
	var parts := []
	for hit in _hits:
		var effects: Dictionary = hit[2]
		var values := { "player": hit[0].name, "damage": hit[1] }
		if effects.is_empty():
			parts.append(["part_hit", values])
		else:
			values.tokens = token_text(effects)
			parts.append(["part_hit_with_tokens", values])
	tell("boss_attacks", { "boss": boss.title, "hits": parts })
	for hit in _hits:
		await _each_rule("hero_struck", [hit[0], hit[1]])
		await _each_rule("hero_hurt", [hit[0], hit[1], null])
		if over:
			return


## The rules for the round leave the fight. The heroes with a Totem give back its token.
func _end_round_rules() -> void:
	var holders := PackedStringArray()
	var shown := false
	for rule in _round_rules:
		var buff := rule.buff()
		shown = shown or buff != null
		if buff != null and buff.totem and buff.hero != null and not buff.hero.name in holders:
			holders.append(buff.hero.name)
		rules.erase(rule)
	_round_rules.clear()
	if shown:
		buffs_changed.emit()
	if not holders.is_empty():
		tell("totems_returned", { "players": ", ".join(holders) })


## At the end of the round, the boss's poison hurts it, past its shields.
func _poison_tick() -> void:
	if poison <= 0:
		return
	var damage := poison
	for rule in rules.duplicate():
		damage = _rule_value(rule, "poison_damage", [damage])
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
				attacked_changed.emit(attacked)
			stats.power_played(hero, effect.damage_type, effect.strength)
			await deal_damage(effect.strength, effect.damage_type, play)
			if opened:
				await _each_rule("attack_type_opened", [effect.damage_type, play])
		"support":
			var allowed := effect.damage_type in attacked
			for rule in rules.duplicate():
				allowed = allowed or _rule_value(rule, "support_without_attack", [effect.damage_type, play])
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
					amount = _rule_value(rule, "protection", [amount, target, play])
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
	if card.is_room():
		return "notice_cannot_play_now"
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
		await _rule_hook(rule, hook, arguments)


## Calls a hook of rule that may wait for the players. What it tells comes from the rule.
func _rule_hook(rule: FightRule, hook: String, arguments := []) -> void:
	_sources.push_back(_source_of(rule))
	await rule.callv(hook, [self] + arguments)
	_sources.pop_back()


## What rule tells comes from it, or, if it does not say, from what it acts within.
func _source_of(rule: FightRule) -> Dictionary:
	var own := rule.message_source()
	return own if not own.is_empty() else source()


## Calls a hook of rule that returns a value at once, such as damage_taken.
func _rule_value(rule: FightRule, hook: String, arguments: Array) -> Variant:
	_sources.push_back(_source_of(rule))
	var result: Variant = rule.callv(hook, [self] + arguments)
	_sources.pop_back()
	return result


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
	_screen_released.emit()
