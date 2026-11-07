extends SceneTree
## The rules of a fight, without a screen: the rounds and phases, what cards do, and how
## bosses and abilities step in. The fight waits for the players, and the test plays them.
## Run with: godot --headless -s tests/test_fight.gd

const EXPECTED_CHECKS := 241

var _failures := 0
var _checks_run := 0
## What the fight told the players, in order, by message id.
var _told: Array[String] = []
var _values: Array[Dictionary] = []
var _raised: Array[Dictionary] = []
var _notices: Array[String] = []


## A boss whose attacks and shields are known, and which notes what it was told.
class TestBoss extends Boss:
	var calls: Array[String] = []
	var threats := {}

	func _init() -> void:
		health = 30
		shields = { "melee": 2, "ranged": 0, "magic": 1 }

	func plan_attacks(fight: Fight) -> void:
		for hero in fight.heroes:
			fight.threaten(hero, threats.get(hero.seat, 3), { "poison": 1 } if hero.seat == 5 else {})

	func fight_started(_fight: Fight) -> void:
		calls.append("fight_started")

	func round_started(fight: Fight) -> void:
		calls.append("round %d" % fight.round_number)

	func card_played(_fight: Fight, play: CardPlay) -> void:
		calls.append("played %s" % play.card.qr)

	func boss_hurt(_fight: Fight, old: int, new: int) -> void:
		calls.append("hurt %d %d" % [old, new])

	## Before striking the hero at ability_seat, it uses an @-ability of ability_strength.
	var ability_seat := -1
	var ability_strength := 0

	func attack_hero(fight: Fight, hero: FightHero) -> void:
		if hero.seat == ability_seat and await fight.boss_ability("test", ability_strength, hero):
			calls.append("ability")
		await super(fight, hero)

	func shield_hit(_fight: Fight, kind: String, _amount: int, _play: CardPlay) -> void:
		calls.append("shield_hit %s" % kind)


func _initialize() -> void:
	_check_round()
	_check_cards()
	_check_abilities()
	_check_card_abilities()
	_check_boss_abilities()
	_check_traits()
	_check_more_traits()
	_check_catalog_abilities()
	_check_loot_cards()
	_check_more_loot_cards()
	_check_magic_loot_cards()
	_check_items()
	_check_boss_poison()
	_check_combos()
	_check_actions()
	_check_bosses()
	_check_end()
	_check(_checks_run == EXPECTED_CHECKS - 1, "all checks ran: %d" % _checks_run)
	print("test_fight: %s" % ("PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _check_round() -> void:
	var boss := TestBoss.new()
	boss.threats = { 1: 4, 3: 2, 5: 5 }
	var fight := _fight(boss)
	_check(fight.heroes.map(func(hero: FightHero) -> int: return hero.seat) == [1, 3, 5], "the heroes sit clockwise, by seat")
	fight.start()
	_check(_told == ["boss_taunt"] and boss.calls == ["fight_started"], "the boss greets the heroes first")
	_check(fight.request == null, "and the fight waits until they have read it")
	_check(fight.scan(_card("AXE", [["attack", 5, "melee"]], "dwarf")) == "ignored" and fight.health == 30, "cards are only taken when one is asked for")
	_ready(fight)
	_check(_told[-1] == "round_started" and fight.round_number == 1 and boss.calls[-1] == "round 1", "then round 1 begins")
	_ready(fight)
	_check(_told[-1] == "phase_planning" and fight.request == null, "then the boss plans its attacks")
	_check(fight.hero_at(1).threat == 4 and fight.hero_at(5).threat_effects == { "poison": 1 }, "against each hero")
	_ready(fight)
	_check(fight.request != null and fight.request.kind == Fight.Request.Kind.HERO and fight.request.heroes.size() == 3, "knowing them, the players choose who starts")
	fight.choose(fight.hero_at(3))
	_check(fight.starter == fight.hero_at(3) and fight.shields == { "melee": 2, "ranged": 0, "magic": 1 }, "and raises its shields")
	_check(not _told.has("phase_shield") and _raised == [fight.shields], "shown as they rise, without a message")
	_check(_told[-1] == "phase_action" and _values[-1].player == "Borin", "the action phase starts with the chosen hero")
	_ready(fight)
	_check(_asks_card_of(fight, 3), "whose card is asked for first")

	# Borin: a melee attack breaks the shield first.
	_check(fight.scan(_card("AXE", [["attack", 5, "melee"]], "dwarf")) == "", "a card is played")
	_check(fight.shields.melee == 0 and fight.health == 27, "its damage breaks the shield of its kind, then hurts")
	_check(boss.calls.slice(-2) == ["hurt 30 27", "played AXE"], "the boss hears of it")
	_check(_asks_card_of(fight, 5), "the next hero clockwise follows")

	# Sonja: a support of another kind does nothing, the turn still ends.
	fight.scan(_card("SUP", [["support", 3, "magic"]], "dryad"))
	_check(_told[-1] == "support_without_attack" and fight.health == 27, "a support needs an attack of its kind first")
	_check(fight.request == null, "the players read why first")
	_ready(fight)
	_check(_asks_card_of(fight, 1), "then the turn goes round to the start")

	# Rosie: lightning gives another action at once, protection lowers an attack.
	fight.scan(_card("ZAP", [["lightning", 1], ["draw", 2]], "halfling"))
	_check(_told[-1] == "draw_cards" and _notices[-1] == "notice_lightning", "lightning and draw")
	_ready(fight)
	_check(_asks_card_of(fight, 1), "lightning keeps the turn with the same hero")
	fight.scan(_card("SHIELD", [["protection", 5]], "halfling"))
	_check(fight.request.kind == Fight.Request.Kind.HERO and fight.request.heroes.size() == 3, "protection asks for whom")
	fight.choose(fight.hero_at(5))
	_check(fight.hero_at(5).threat == 0 and fight.hero_at(5).threat_effects.is_empty(), "an attack lowered to 0 loses its poison too")
	_check(_asks_card_of(fight, 3), "then the next turn")

	# Second turns: a support after an attack of its kind.
	fight.scan(_card("SUP2", [["support", 2, "melee"]], "dwarf"))
	_check(fight.health == 25, "a support hurts after an attack of its kind")
	_check(fight.scan(_card("SUP", [["support", 3, "magic"]], "dryad")) == "notice_played_already", "a card cannot be played twice in a round")
	_check(_notices[-1] == "notice_played_already", "which the players are told")
	_check(fight.scan(_card("AXE2", [], "dwarf")) == "notice_not_your_card", "nor a card of another hero's deck")
	_check(fight.scan(null) == "notice_unknown_card", "an unknown card is not played")
	fight.pass_action()
	_check(_asks_card_of(fight, 1), "passing gives up the action")
	for i in 4:
		fight.pass_action()
	_check(fight.active_hero == null and _told[-1] == "boss_hits", "after three turns each, the boss attacks")
	_check(_told.slice(-2) == ["boss_hits", "boss_hits"] and _values[-1].damage == 2, "every hero it still threatens")
	_ready(fight)
	_check(_told[-1] == "phase_status", "then the players apply their status tokens")
	_ready(fight)
	_check(_told[-1] == "phase_discard", "then the players discard")
	_ready(fight)
	_check(_told[-1] == "phase_draw", "and draw")
	_ready(fight)
	_check(_told[-1] == "round_started" and fight.round_number == 2, "and the next round begins")
	_ready(fight)
	_ready(fight)
	_check(fight.request.kind == Fight.Request.Kind.HERO and fight.hero_at(1).threat > 0, "again by planning, then choosing who starts")
	fight.choose(fight.hero_at(5))
	_ready(fight)
	_ready(fight)
	_check(fight.scan(_card("SUP", [["support", 3, "magic"]], "dryad")) == "", "cards can be played again in a new round")
	_check(fight.health == 25, "and attacks of the last round no longer help supports")
	_ready(fight)
	for i in 8:
		fight.pass_action()
	_check(_told[-1] == "boss_hits_with_tokens" and _values[-1].tokens.en == "1 poison", "a poisonous attack tells the hero to take poison")
	_ready(fight)
	_check(_told[-1] == "phase_status", "which the players apply in the status phase")

	# What the game over screen shows of these two rounds.
	var stats := fight.stats
	var borin := stats.of(fight.hero_at(3))
	_check(borin.damage == 5 and borin.shield_damage == 2 and borin.cards == 2, "the stats count each hero's damage, to the boss and to its shields")
	_check(borin.power == { "melee": 7, "ranged": 0, "magic": 0 }, "and the power of their attacks and supports by type, only supports that count")
	_check(stats.of(fight.hero_at(1)).protection == 5, "and how much their protection lowered attacks")
	_check(stats.of(fight.hero_at(1)).damage_taken == 8 and stats.of(fight.hero_at(5)).damage_taken == 5, "and the damage they took from attacks")
	_check(stats.attacks == 6 and stats.attacks_blocked == 1 and stats.of(fight.hero_at(5)).attacks_blocked == 1, "and the boss's attacks, and those blocked")
	_check(stats.rounds == 2 and stats.health_by_round == [30, 25] and stats.damage_by_round == [5, 0], "and the boss's health and the damage, round by round")
	_check(stats.team_damage() == 5 and stats.boss_damage() == 17 and stats.outcome == FightStats.Outcome.NONE, "and the totals, while the fight goes on")
	fight.abandon()
	_check(stats.outcome == FightStats.Outcome.ABORTED and stats.health_by_round == [30, 25, 25], "a fight given up is aborted, in the middle of a round")


func _check_cards() -> void:
	var fight := _started(TestBoss.new())
	var rosie := fight.hero_at(1)
	var potion := _card("POTION", [["heal", 8]], "items")
	potion.uses_per_fight = 1
	_check(fight.scan(potion) == "" and _told[-1] == "heal", "an item heals")
	_check(fight.stats.of(rosie).healing == 8, "which counts for the stats")
	_ready(fight)
	fight.pass_action()
	fight.pass_action()
	_check(_asks_card_of(fight, 1) and fight.scan(potion) == "notice_used_up", "a card with a limit is used up")
	var backpack := _card("PACK", [["draw", 3]], "items")
	_check(fight.scan(backpack) == "", "an item")
	_ready(fight)
	fight.pass_action()
	fight.pass_action()
	fight.scan(_card("CALM", [["lightning", 1]], "halfling"))
	_check(fight.scan(backpack) == "", "an item can be used again in the same round")
	fight.abandon()
	fight = _started(TestBoss.new())
	_check(fight.scan(_card("STAR", [["health_loss", 2]], "halfling")) == "" and _told[-1] == "health_loss", "losing health is told")
	_check(fight.stats.of(fight.hero_at(1)).healing == 0, "and is no healing")
	fight.abandon()
	fight = _started(TestBoss.new())
	fight.set_shields({ "melee": 5, "ranged": 5, "magic": 5 })
	var health_before := fight.health
	fight.scan(_card("HART", [["direct_damage", 2]], "halfling"))
	_check(fight.health == health_before - 2, "direct damage hurts the boss past its shields")
	_check(fight.shields == { "melee": 5, "ranged": 5, "magic": 5 }, "and leaves the shields alone")
	fight.abandon()
	fight = _started(TestBoss.new())
	var told_before := _told.size()
	_check(fight.scan(_card("WISH", [["special", 0]], "halfling")) == "" and _told.size() == told_before, "the special mark does nothing by itself")
	fight.abandon()
	fight = _started(TestBoss.new())
	var horn := _card("MAGMA", [["take_from_pile", 1], ["remove_from_game", 0]], "items")
	fight.scan(horn)
	_check(_told[-1] == "take_from_pile" and _values[-1].count == 1, "a card taken from the draw pile is told")
	_ready(fight)
	_check(_told[-1] == "card_removed", "and so is a card put away")
	_ready(fight)
	_check(fight.request != null and fight.scan(horn) == "notice_removed", "a card out of the game cannot be played again")
	fight.abandon()


func _check_abilities() -> void:
	# Another hero plays a card at once, which costs them no turn.
	var fight := _started(TestBoss.new())
	var gift := _card("GIFT", [], "halfling")
	gift.ability = "free_play"
	fight.scan(gift)
	_check(fight.request.kind == Fight.Request.Kind.HERO and fight.request.can_skip and fight.request.heroes.size() == 2, "a free card for another hero: who?")
	fight.choose(fight.hero_at(5))
	_check(_asks_card_of(fight, 5) and fight.request.prompt == "prompt_free_play" and fight.request.can_skip, "they may play one now")
	fight.scan(_card("BOLT", [["attack", 4, "magic"], ["lightning", 1]], "dryad"))
	_check(fight.health == 27, "it takes effect")
	_check(_asks_card_of(fight, 5) and fight.request.prompt == "prompt_free_play", "and its lightning gives them another")
	fight.skip()
	_check(_asks_card_of(fight, 3) and fight.hero_at(5).turns_left == 3, "then the turns go on, theirs untouched")
	fight.abandon()

	# The lucky charm plays the top card, without its lightning.
	fight = _started(TestBoss.new())
	var charm := _card("CHARM", [], "items")
	charm.ability = "lucky_charm"
	fight.scan(charm)
	_check(_asks_card_of(fight, 1) and fight.request.prompt == "prompt_lucky_charm", "the lucky charm asks for the top card")
	fight.scan(_card("TOP", [["lightning", 1]], "halfling"))
	_check(_asks_card_of(fight, 3), "whose lightning is ignored")

	# A totem strengthens a hero's attacks until the end of the round.
	var totem := _card("TOTEM", [], "dwarf")
	totem.ability = "empower"
	totem.ability_values = { "bonus": 2 }
	fight.scan(totem)
	fight.choose(fight.hero_at(5))
	_check(_told[-1] == "empowered" and fight.rules.size() == 2, "a totem strengthens a hero")
	_ready(fight)
	fight.scan(_card("WHIP", [["attack", 1, "ranged"]], "dryad"))
	_check(fight.health == 27, "whose attacks hit harder")

	# A warhorse gives a turn more next round.
	var horse := _card("HORSE", [], "halfling")
	horse.ability = "extra_turns"
	fight.scan(horse)
	_check(_told[-1] == "extra_turns_next_round" and fight.hero_at(1).bonus_turns == 1, "a warhorse gives a turn more next round")
	_ready(fight)
	for i in 6:
		fight.pass_action()
	for i in 6:
		_ready(fight)
	_check(fight.round_number == 2 and fight.rules.size() == 1, "the totem ends with the round")
	_ready(fight)
	_ready(fight)
	fight.choose(fight.hero_at(1))
	_ready(fight)
	_ready(fight)
	_check(fight.hero_at(1).turns_left == 3, "the extra turn is there next round")

	# The medical bag reminds the hero to remove their tokens, which are on the table.
	var bag := _card("BAG", [], "items")
	bag.ability = "remove_tokens"
	_check(fight.scan(bag) == "" and _told[-1] == "remove_tokens" and _values[-1].count == 2, "the medical bag tells the hero to remove 2 tokens")
	fight.abandon()


## The abilities of the cards in the catalog.
func _check_card_abilities() -> void:
	# Krawumm: as strong as the round.
	var fight := _started(TestBoss.new())
	var krawumm := _card("KRA", [["attack", 0, "ranged"], ["lightning", 1]], "halfling")
	krawumm.ability = "attack_by_round"
	fight.scan(krawumm)
	_check(fight.health == 29 and _asks_card_of(fight, 1), "an attack as strong as the round, 1 in round 1")

	# Every hero draws.
	var rune := _card("KING", [["draw", 1]], "halfling")
	rune.ability = "every_hero"
	fight.scan(rune)
	_check(_told[-1] == "draw_cards_everyone" and _values[-1].count == 1, "a card can make every hero draw")
	_ready(fight)

	# A Draw for a hero of the players' choice, who then acts at once.
	var horn := _card("HORN", [["draw", 3], ["special", 0]], "dwarf")
	horn.ability = "for_chosen_hero"
	horn.ability_values = { "action": true }
	fight.scan(horn)
	_check(fight.request.kind == Fight.Request.Kind.HERO and fight.request.prompt == "prompt_chosen_hero", "a card for a hero of the players' choice: who?")
	fight.choose(fight.hero_at(5))
	_check(_told[-1] == "draw_cards" and _values[-1].player == "Sonja", "that hero draws")
	_ready(fight)
	_check(_asks_card_of(fight, 5) and fight.request.prompt == "prompt_free_play", "and may act at once")
	fight.skip()
	_check(_asks_card_of(fight, 5) and fight.hero_at(5).turns_left == 2, "then Sonja's own turn")

	# Gardehelm: a hero of the players' choice removes a token.
	var helmet := _card("HELM", [["protection", 2], ["special", 0]], "dryad")
	helmet.ability = "remove_tokens"
	helmet.ability_values = { "count": 1, "choose": true }
	fight.scan(helmet)
	fight.choose(fight.hero_at(1))
	_check(fight.request.prompt == "prompt_remove_tokens_who", "removing a token: from whom?")
	fight.choose(fight.hero_at(3))
	_check(_told[-1] == "remove_tokens" and _values[-1].player == "Borin" and _values[-1].count == 1, "that hero removes it")
	fight.abandon()

	# "If you have 15 health or more afterwards", which the players are asked.
	fight = _started(TestBoss.new())
	var club := _card("CLUB", [["attack", 1, "ranged"], ["special", 0]], "halfling")
	club.ability = "if_healthy"
	club.ability_values = { "draw": 2 }
	fight.scan(club)
	_check(fight.request.kind == Fight.Request.Kind.OPTION and fight.request.options == ["option_yes", "option_no"] and fight.health == 29, "after its attack, a troll card asks about the hero's health")
	fight.choose_option(0)
	_check(_told[-1] == "draw_cards" and _values[-1].count == 2, "with enough, the hero gets more")
	_ready(fight)
	var belt := _card("BELT", [["special", 0]], "dwarf")
	belt.ability = "if_healthy"
	belt.ability_values = { "heal": 3 }
	var told_before := _told.size()
	fight.scan(belt)
	fight.choose_option(1)
	_check(_told.size() == told_before and _asks_card_of(fight, 5), "without, nothing more")

	# Rauchbombe: the protected attack loses its poison.
	var smoke := _card("SMOKE", [["protection", 1], ["special", 0]], "dryad")
	smoke.ability = "clear_attack_effects"
	fight.scan(smoke)
	fight.choose(fight.hero_at(5))
	_check(fight.hero_at(5).threat == 2 and fight.hero_at(5).threat_effects.is_empty(), "a protection can take away an attack's poison")
	_check(_told[-1] == "attack_effects_removed", "which the players are told")
	fight.abandon()

	# Rune der Rache: as strong as the attack against the hero, and costly when strong.
	var boss := TestBoss.new()
	boss.threats = { 1: 9, 5: 6 }
	fight = _started(boss)
	var revenge := _card("REVENGE", [["attack", 0, "ranged"], ["special", 0]], "halfling")
	revenge.ability = "attack_by_threat"
	revenge.ability_values = { "threshold": 9, "health_loss": 4 }
	fight.scan(revenge)
	_check(fight.health == 21 and _told[-1] == "health_loss" and _values[-1].amount == 4, "an attack as strong as the boss's against the hero, which hurts them at 9")

	# Ritterlicher Beistand: the hero takes on another hero's attack instead of their own.
	_ready(fight)
	var aid := _card("AID", [["special", 0]], "dwarf")
	aid.ability = "knightly_aid"
	fight.scan(aid)
	_check(fight.request.kind == Fight.Request.Kind.HERO and fight.request.heroes == [fight.hero_at(1), fight.hero_at(5)], "taking on an attack: whose?")
	fight.choose(fight.hero_at(5))
	var borin := fight.hero_at(3)
	_check(borin.threat == 6 and borin.threat_effects == { "poison": 1 } and fight.hero_at(5).threat == 0, "the attack and its poison go to the hero, their own is gone")
	_check(_told[-1] == "attack_redirected" and _values[-1].other == "Sonja", "which the players are told")
	fight.abandon()


## Cards that prevent the boss's @-abilities.
func _check_boss_abilities() -> void:
	var boss := TestBoss.new()
	boss.ability_seat = 1
	boss.ability_strength = 7
	var fight := _started(boss)
	var raven := _card("RAVEN", [["direct_damage", 2]], "halfling")
	raven.ability = "raven_curse"
	fight.scan(raven)
	_check(fight.health == 28 and _told[-1] == "ward_placed", "the raven's curse lies by its hero")
	_ready(fight)
	for i in 8:
		fight.pass_action()
	_check(fight.request.kind == Fight.Request.Kind.OPTION and fight.request.prompt == "prompt_use_ward", "when the boss uses an @-ability against them, the players are asked")
	fight.choose_option(0)
	_check(_told[-1] == "boss_ability_prevented" and not "ability" in boss.calls, "discarding it prevents the ability")
	_check(fight.rules.size() == 1 and not fight.hero_at(1).notes.has("ward RAVEN"), "and the card is gone")
	fight.abandon()

	boss = TestBoss.new()
	boss.ability_seat = 3
	boss.ability_strength = 5
	fight = _started(boss)
	var anti := _card("ANTI", [["special", 0]], "halfling")
	anti.ability = "anti_boss"
	anti.ability_values = { "strength": 5 }
	anti.uses_per_fight = 1
	fight.scan(anti)
	_check(_told[-1] == "ward_ready", "a card can prevent the next @-ability")
	_ready(fight)
	for i in 8:
		fight.pass_action()
	_check(_told.has("boss_ability_prevented") and not "ability" in boss.calls and fight.rules.size() == 1, "it does, without asking, once")
	fight.abandon()

	boss = TestBoss.new()
	boss.ability_seat = 3
	boss.ability_strength = 6
	fight = _started(boss)
	fight.scan(anti)
	_ready(fight)
	for i in 8:
		fight.pass_action()
	_check("ability" in boss.calls, "but not one that is too strong")
	fight.abandon()


## What the heroes' levels give them, from their character and class cards in the catalog.
func _check_traits() -> void:
	var boss := TestBoss.new()
	var fight := _started(boss, "normal", true, true)
	_check(fight.rules.size() == 7, "each hero's character and class card joins the fight")
	# Rosie, Rogue King: a support without an attack. Halfling Luckmaster: breaking the magic
	# shield costs the boss 4 more.
	fight.scan(_card("SUP", [["support", 3, "magic"]], "halfling"))
	_check(fight.health == 24 and fight.shields.magic == 0 and _told.has("shield_breaker"), "the Rogue King's support needs no attack, the Luckmaster's broken shield hurts")
	_ready(fight)
	# Borin, Elite Warrior: his first attack ignores what the shield does.
	fight.scan(_card("HIT", [["attack", 1, "melee"]], "dwarf"))
	_check(fight.shields.melee == 1 and not "shield_hit melee" in boss.calls, "the Elite Warrior's first attack ignores the shield's effect")
	# Sonja, High Druid: her first Protection gets a Lightning. Dryad Primal Force: so does
	# her first form.
	fight.scan(_card("GUARD", [["protection", 2]], "dryad"))
	fight.choose(fight.hero_at(3))
	_check(_asks_card_of(fight, 5) and _notices[-1] == "notice_lightning", "the High Druid's first protection gets a lightning")
	var form := _card("FORM", [], "dryad")
	form.tags = ["form"]
	fight.scan(form)
	_check(_asks_card_of(fight, 5) and fight.hero_at(5).turns_left == 2, "and the dryad's first form")
	fight.pass_action()
	fight.pass_action()
	fight.scan(_card("HIT2", [["attack", 1, "melee"]], "dwarf"))
	_check("shield_hit melee" in boss.calls, "his second attack does not ignore it")
	fight.pass_action()
	fight.pass_action()
	# Borin, Dwarven Treasure Keeper: lowering an attack to 0 gives an attack card at once.
	fight.scan(_card("WALL", [["protection", 1]], "dwarf"))
	fight.choose(fight.hero_at(3))
	_check(_asks_card_of(fight, 3) and fight.request.prompt == "prompt_attack_or_item", "blocking an attack fully lets the Treasure Keeper attack")
	_check(fight.scan(_card("NOPE", [["protection", 1]], "dwarf")) == "notice_not_allowed_now", "only with an attack or an item")
	_check(fight.scan(_card("AXE", [["attack", 2, "ranged"]], "dwarf")) == "" and fight.health == 22, "which is played")
	fight.abandon()


## Traits of the other heroes, given to Rosie for the test.
func _check_more_traits() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	var fight := _started(TestBoss.new())
	var rosie := fight.hero_at(1)
	_give_trait(fight, catalog, "ugEAAA==", rosie)
	fight.scan(_card("A1", [["attack", 1, "ranged"], ["lightning", 1]], "halfling"))
	_check(_told[-1] == "heal" and _values[-1].amount == 3, "the Celestial Paladin heals from the first attack of a type")
	_ready(fight)
	_give_trait(fight, catalog, "/QAAAA==", rosie)
	var told_before := _told.size()
	fight.scan(_card("A2", [["attack", 1, "ranged"], ["lightning", 1]], "halfling"))
	_check(_told.size() == told_before, "but not from the second")
	fight.scan(_card("S1", [["support", 2, "ranged"], ["lightning", 1]], "halfling"))
	_check(fight.health == 24, "the Elven Keeper's supports hit 2 harder after her own attack of their type")
	_give_trait(fight, catalog, "KQEAAA==", rosie)
	fight.scan(_card("OUCH", [["health_loss", 1]], "halfling"))
	_check(_told.slice(-2) == ["health_loss", "may_draw"], "the Archmage may draw when losing health")
	fight.abandon()

	fight = _started(TestBoss.new())
	rosie = fight.hero_at(1)
	_give_trait(fight, catalog, "/gAAAA==", rosie)
	_give_trait(fight, catalog, "hwEAAA==", rosie)
	var robot := _card("ROBOT", [["lightning", 1]], "goblin")
	robot.deck = "items"
	robot.ability = "build_robot"
	fight.scan(robot)
	_check(_told[-1] == "robot_built" and rosie.notes.get("robot", false), "a goblin builds a battle robot")
	_ready(fight)
	fight.scan(_card("B1", [["attack", 1, "ranged"]], "halfling"))
	_check(fight.health == 27, "with which the Goblin Genius's attacks are 2 stronger")
	_check(_asks_card_of(fight, 1) and fight.request.prompt == "prompt_top_card_or_item", "the Troll Chieftain's first hit in a turn plays the top card")
	fight.scan(_card("B2", [["attack", 1, "ranged"]], "halfling"))
	_check(_asks_card_of(fight, 3), "but only the first")
	fight.abandon()


## More loot cards with an ability, from the catalog.
func _check_more_loot_cards() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	# Zeitschnitter: 2 more for each attack the hero played this round.
	var boss := TestBoss.new()
	boss.shields = { "melee": 0, "ranged": 0, "magic": 0 }
	var fight := _started(boss)
	fight.scan(_card("ZAP", [["attack", 1, "ranged"], ["lightning", 1]], "halfling"))
	fight.scan(catalog.find("1QEAAA=="))
	_check(fight.health == 25 and _asks_card_of(fight, 3), "Zeitschnitter: 2, and 2 more for the attack before")
	fight.abandon()

	# Drachenschuppe: the next card with a magic attack hits 2 harder, only that one.
	boss = TestBoss.new()
	boss.shields = { "melee": 0, "ranged": 0, "magic": 0 }
	fight = _started(boss)
	fight.scan(catalog.find("zAEAAA=="))
	fight.choose(fight.hero_at(5))
	_check(fight.hero_at(5).threat == 0 and _asks_card_of(fight, 3), "Drachenschuppe: protection 4")
	fight.scan(_card("BOLT", [["attack", 1, "magic"]], "dwarf"))
	_check(fight.health == 27, "and the next magic attack is 2 stronger")
	fight.scan(_card("BOLT2", [["attack", 1, "magic"]], "dryad"))
	_check(fight.health == 26, "but not the one after")
	fight.abandon()

	# Schwelende Keule: the next card's Protection is 3 stronger.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("JgEAAA=="))
	fight.scan(_card("GUARD", [["protection", 1]], "dwarf"))
	fight.choose(fight.hero_at(5))
	_check(fight.hero_at(5).threat == 0, "Schwelende Keule: the next Protection is 3 stronger")
	fight.abandon()

	# Geweihte Schulterplatten: the protected attack loses its poison.
	boss = TestBoss.new()
	boss.threats = { 5: 6 }
	fight = _started(boss)
	fight.scan(catalog.find("CgEAAA=="))
	fight.choose(fight.hero_at(5))
	_check(fight.hero_at(5).threat == 2 and fight.hero_at(5).threat_effects.is_empty() and _told[-1] == "attack_effects_removed", "Geweihte Schulterplatten: protection 4, and the attack loses its poison")
	fight.abandon()

	# Anspornen: a hero of the players' choice draws 3 and acts at once.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("DgEAAA=="))
	fight.choose(fight.hero_at(5))
	_check(_told[-1] == "draw_cards" and _values[-1].player == "Sonja" and _values[-1].count == 3, "Anspornen: the chosen hero draws 3")
	_ready(fight)
	_check(_asks_card_of(fight, 5) and fight.request.prompt == "prompt_free_play", "and acts at once")
	fight.abandon()


## The magic loot cards, from the catalog.
func _check_magic_loot_cards() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	# Explosivkristall: a shield of the players' choice goes down by 7, without its effect,
	# and nothing reaches the boss.
	var boss := TestBoss.new()
	var fight := _started(boss)
	fight.scan(catalog.find("OgEAAA=="))
	_check(fight.request.kind == Fight.Request.Kind.OPTION and fight.request.options == ["option_shield_melee", "option_shield_magic"], "Explosivkristall: which shield?")
	fight.choose_option(0)
	_check(fight.shields.melee == 0 and fight.shields.magic == 1 and fight.health == 30 and not "shield_hit melee" in boss.calls and _told[-1] == "shield_lowered", "Explosivkristall: the shield is down, without its effect or damage")
	fight.abandon()
	boss = TestBoss.new()
	boss.shields = { "melee": 0, "ranged": 0, "magic": 0 }
	fight = _started(boss)
	fight.scan(catalog.find("OgEAAA=="))
	_check(_told[-1] == "no_shield_to_lower" and fight.shields.values().all(func(n: int) -> bool: return n == 0), "Explosivkristall: without shields, nothing happens")
	fight.abandon()

	# Kristallorb: breaking the shield costs the boss 3 more health.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("zgEAAA=="))
	_check(fight.shields.magic == 0 and fight.health == 25 and _told.has("shield_breaker"), "Kristallorb: magic attack 3 breaks the shield, the boss loses 3 more")
	fight.abandon()
	boss = TestBoss.new()
	boss.shields = { "melee": 0, "ranged": 0, "magic": 0 }
	fight = _started(boss)
	fight.scan(catalog.find("zgEAAA=="))
	_check(fight.health == 27 and not _told.has("shield_breaker"), "Kristallorb: no shield broken, no more damage")
	fight.abandon()

	# Himmelsrune: a hero of the players' choice draws 1.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("DwEAAA=="))
	fight.choose(fight.hero_at(3))
	_check(fight.health == 27 and _told.has("draw_cards") and _values[_told.find("draw_cards")].player == "Borin", "Himmelsrune: magic attack 4, the chosen hero draws 1")
	fight.abandon()

	# Kettenblitz: the next magic attack is 3 stronger.
	boss = TestBoss.new()
	boss.shields = { "melee": 0, "ranged": 0, "magic": 0 }
	fight = _started(boss)
	fight.scan(catalog.find("JQEAAA=="))
	fight.scan(_card("BOLT", [["attack", 1, "magic"]], "dwarf"))
	_check(fight.health == 22, "Kettenblitz: 4, and the next magic attack 3 stronger")
	fight.abandon()

	# Astrale Linse: an extra action, and the next card with a magic attack takes effect twice.
	fight = _started(boss)
	fight.scan(catalog.find("PAEAAA=="))
	_ready(fight)
	_check(_asks_card_of(fight, 1), "Astrale Linse: 1 more action")
	fight.scan(_card("BOLT", [["attack", 2, "magic"]], "halfling"))
	_check(fight.health == 26 and _told.has("card_repeated"), "Astrale Linse: the magic attack takes effect twice")
	fight.abandon()

	# Elixier der Sorglosigkeit: 1 token from a hero of choice, then 1 from each hero.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("EQEAAA=="))
	fight.choose(fight.hero_at(5))
	_check(_told.slice(-2) == ["remove_tokens", "remove_tokens_everyone"] and _values[-2].player == "Sonja" and _values[-2].count == 1 and _values[-1].count == 1, "Elixier der Sorglosigkeit: 1 token from Sonja, then 1 from everyone")
	fight.abandon()

	# Krone des Prinzen: the boss gets 1 poison when its attack of 4 or more strikes the
	# chosen hero; the card is then out of the game.
	boss = TestBoss.new()
	boss.threats = { 1: 3, 3: 4, 5: 6 }
	fight = _started(boss)
	fight.scan(catalog.find("yAEAAA=="))
	_ready(fight)
	fight.choose(fight.hero_at(3))
	_check("yAEAAA==" in fight.removed and _told[-1] == "poison_on_attack_ready", "Krone des Prinzen: for Borin, then out of the game")
	_ready(fight)
	_check(_asks_card_of(fight, 1), "Krone des Prinzen: 1 more action")
	_pass_until(fight, "phase_status")
	_check(fight.poison == 1 and _told.count("poison_on_attack") == 1 and _values[_told.find("poison_on_attack")].player == "Borin", "Krone des Prinzen: attack of 4 on Borin, the boss gets 1 poison")
	fight.abandon()
	boss = TestBoss.new()
	boss.threats = { 3: 5 }
	fight = _started(boss)
	fight.scan(catalog.find("yAEAAA=="))
	_ready(fight)
	fight.choose(fight.hero_at(3))
	_ready(fight)
	fight.scan(_card("GUARD", [["protection", 2]], "halfling"))
	fight.choose(fight.hero_at(3))
	_pass_until(fight, "phase_status")
	_check(fight.poison == 0 and not _told.has("poison_on_attack"), "Krone des Prinzen: lowered to 3, no poison")
	fight.abandon()

	# Magische Eruption: the chosen hero draws 2, and next round every attack is 3 lower.
	boss = TestBoss.new()
	boss.threats = { 1: 3, 3: 5, 5: 2 }
	fight = _started(boss)
	fight.scan(catalog.find("MwEAAA=="))
	fight.choose(fight.hero_at(5))
	_ready(fight)
	_check(_told.has("draw_cards") and _values[_told.find("draw_cards")].player == "Sonja" and _values[_told.find("draw_cards")].count == 2 and _told[-1] == "attacks_weakened_next_round", "Magische Eruption: Sonja draws 2")
	_check(fight.hero_at(3).threat == 5, "Magische Eruption: not this round")
	_pass_until(fight, "attacks_weakened")
	_check(fight.round_number == 2 and fight.hero_at(1).threat == 0 and fight.hero_at(3).threat == 2 and fight.hero_at(5).threat == 0 and fight.hero_at(5).threat_effects.is_empty(), "Magische Eruption: next round, every attack 3 lower")
	_pass_until(fight, "phase_planning")
	_ready(fight)
	_check(fight.round_number == 3 and fight.hero_at(3).threat == 5, "Magische Eruption: only that round")
	fight.abandon()


## Every ability the catalog names exists, and is one.
func _check_catalog_abilities() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	var missing := PackedStringArray()
	var file := FileAccess.open("res://cards/cards.json", FileAccess.READ)
	for entry: Dictionary in JSON.parse_string(file.get_as_text()).cards:
		var card := catalog.find(entry.qr)
		if card.ability.is_empty():
			continue
		var ability := CardAbility.create(card)
		if ability == null:
			missing.append("%s (%s)" % [card.ability, card.qr])
	_check(missing.is_empty(), "every ability of the catalog exists: %s" % ", ".join(missing))


## The loot cards with an ability, from the catalog.
func _check_loot_cards() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	# Arkanfalter: its attack does not set off the shield's effect.
	var boss := TestBoss.new()
	var fight := _started(boss)
	fight.scan(catalog.find("NAEAAA=="))
	_check(fight.health == 28 and not boss.calls.has("shield_hit magic") and _asks_card_of(fight, 1), "Arkanfalter: past the shield's effect, then another action")
	# Lichtpfeile: the next card with a ranged attack gets a Lightning.
	fight.scan(catalog.find("JwEAAA=="))
	_check(fight.health == 24 and _asks_card_of(fight, 3), "Lichtpfeile: a ranged attack")
	fight.scan(_card("BOW", [["attack", 1, "ranged"]], "dwarf"))
	_check(fight.health == 23 and _asks_card_of(fight, 3), "and the next ranged attack gets a Lightning")
	# Stachelbola: the next card with a ranged attack takes effect twice.
	fight.scan(catalog.find("OQEAAA=="))
	_check(_asks_card_of(fight, 3), "Stachelbola gives another action")
	fight.scan(_card("BOW2", [["attack", 2, "ranged"]], "dwarf"))
	_check(fight.health == 19 and _told[-1] == "card_repeated", "and the next ranged attack takes effect twice")
	_ready(fight)
	_check(_asks_card_of(fight, 5) and fight.hero_at(3).played.count("BOW2") == 1, "but is played once")
	# Amulett der Zeit: the last card with an attack, by anyone, once more.
	fight.scan(catalog.find("HgEAAA=="))
	_check(fight.health == 17 and _told[-1] == "card_repeated" and _values[-1].player == "Borin", "Amulett der Zeit: the last attack again")
	fight.abandon()

	# Geisterwolf: stronger for each Support the hero played this round.
	boss = TestBoss.new()
	boss.threats = { 1: 9 }
	fight = _started(boss)
	fight.scan(_card("ZAP", [["attack", 1, "magic"], ["lightning", 1]], "halfling"))
	fight.scan(_card("SUP", [["support", 1, "magic"], ["lightning", 1]], "halfling"))
	fight.scan(catalog.find("2QEAAA=="))
	_check(fight.health == 23 and _asks_card_of(fight, 3), "Geisterwolf: 2 more for the Support before")
	# Kultistenkette: a hero's attack is halved and loses its effects.
	fight.scan(catalog.find("0wEAAA=="))
	fight.choose(fight.hero_at(5))
	_check(fight.hero_at(5).threat == 1 and fight.hero_at(5).threat_effects.is_empty() and _told[-1] == "attack_halved", "Kultistenkette: an attack halved, without its poison")
	_ready(fight)
	# Schleimiger Helm: the boss loses what is left of the attack.
	fight.scan(catalog.find("2AEAAA=="))
	fight.choose(fight.hero_at(1))
	_check(fight.hero_at(1).threat == 5 and fight.health == 18, "Schleimiger Helm: the boss loses what is left of the attack")
	fight.abandon()

	# Bombling: its attack goes off at the start of the hero's first turn next round.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("1gEAAA=="))
	_check(fight.health == 30 and _told[-1] == "attack_delayed", "Bombling: no damage yet")
	_ready(fight)
	for i in 8:
		fight.pass_action()
	for i in 20:
		if fight.request != null:
			break
		_ready(fight)
	fight.choose(fight.hero_at(1))
	_ready(fight)
	_check(fight.round_number == 2 and fight.health == 25 and _told[-1] == "delayed_attack_now", "but at the start of the hero's turn next round")
	_ready(fight)
	_check(_asks_card_of(fight, 1), "which is still theirs")
	fight.abandon()

	# Magmahorn: a card from the draw pile, which is then out of the game.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("1AEAAA=="))
	_check(_asks_card_of(fight, 1) and fight.request.prompt == "prompt_search_pile", "Magmahorn: which card from the pile?")
	fight.scan(_card("FOUND", [["attack", 2, "ranged"], ["lightning", 1]], "halfling"))
	_check(fight.health == 28 and "FOUND" in fight.removed and _told[-1] == "searched_card_removed", "it is played, then out of the game")
	_ready(fight)
	_check(_asks_card_of(fight, 1), "its Lightning still counts")
	# Lianenschlange: an item at once.
	fight.scan(catalog.find("ywEAAA=="))
	_check(fight.request.prompt == "prompt_use_item" and fight.scan(_card("AXE", [["attack", 1, "melee"]], "halfling")) == "notice_not_allowed_now", "Lianenschlange: only an item")
	fight.scan(_card("POTION", [["heal", 2]], "items"))
	_check(_told[-1] == "heal", "which is used")
	_ready(fight)
	_check(fight.poison == 1, "and the boss gets its poison")
	# Toxikum: each poison costs the boss more health.
	fight.scan(catalog.find("awEAAA=="))
	_check(_told[-1] == "toxin_ready", "Toxikum")
	_ready(fight)
	# Pestbote: a hand card on the pile, then poison.
	fight.scan(catalog.find("aAEAAA=="))
	_check(_told[-1] == "card_to_pile" and fight.health == 28, "Pestbote: first a hand card on the pile")
	_ready(fight)
	_check(fight.poison == 3 and fight.health == 28, "then the boss gets its poison")
	_ready(fight)
	# Fluchbrecher: the players are told.
	fight.scan(catalog.find("CAEAAA=="))
	_check(_told[-1] == "remove_curse", "Fluchbrecher")
	_ready(fight)
	# Borax' Kriegshammer: an attack, and a hero of the players' choice removes a token.
	fight.scan(catalog.find("HQEAAA=="))
	fight.choose(fight.hero_at(5))
	_check(fight.health == 26 and _told[-1] == "remove_tokens" and _values[-1].count == 1, "Borax' Kriegshammer")
	_ready(fight)
	# Wunderlampe: a hero of the players' choice plays their top 3 cards.
	fight.scan(catalog.find("GwEAAA=="))
	_check(fight.request.prompt == "prompt_play_top_who", "Wunderlampe: who?")
	fight.choose(fight.hero_at(3))
	_check(_asks_card_of(fight, 3) and fight.request.prompt == "prompt_lucky_charm", "that hero shows their top card")
	fight.scan(_card("TOP1", [["attack", 1, "ranged"], ["lightning", 1]], "dwarf"))
	fight.pass_action()
	fight.scan(_card("TOP3", [["draw", 1]], "dwarf"))
	_check(fight.health == 25 and _told[-1] == "draw_cards", "three times")
	_ready(fight)
	_check(_asks_card_of(fight, 3) and fight.request.prompt == "prompt_free_play", "then the Lightning on them")
	fight.skip()
	_check(_asks_card_of(fight, 1), "then the next turn")
	_pass_until(fight, "boss_poison")
	_check(_values[-1].poison == 3 and _values[-1].damage == 6, "at the end of the round, Toxikum doubles what the poison costs")
	_ready(fight)
	_check(fight.health == 19, "past the shields")
	fight.abandon()


## The items from the catalog.
func _check_items() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	var potion := catalog.find("TQEAAA==")
	var fight := _started(TestBoss.new())
	# Heiltrank: a hero of the players' choice heals 8, once per hero and fight.
	_check(fight.scan(potion) == "" and fight.request.kind == Fight.Request.Kind.HERO and fight.request.heroes.size() == 3, "Heiltrank: who heals?")
	fight.choose(fight.hero_at(5))
	_check(_told[-1] == "heal" and _values[-1].player == "Sonja" and _values[-1].amount == 8, "Heiltrank: the chosen hero heals 8")
	_ready(fight)
	_check(_asks_card_of(fight, 3) and fight.scan(potion) == "", "Heiltrank: every hero has their own")
	fight.choose(fight.hero_at(3))
	_ready(fight)
	fight.pass_action()
	_check(_asks_card_of(fight, 1) and fight.scan(potion) == "notice_used_up", "Heiltrank: used once per fight")
	# Rucksack: the hero draws 3.
	_check(fight.scan(catalog.find("mQAAAA==")) == "" and _told[-1] == "draw_cards" and _values[-1].count == 3 and _values[-1].player == "Rosie", "Rucksack: draw 3")
	_ready(fight)
	# Opas Glasauge: only for the troll.
	var eye := catalog.find("fAEAAA==")
	_check(_asks_card_of(fight, 3) and fight.scan(eye) == "notice_not_your_card", "Opas Glasauge: not for the dwarf")
	fight.hero_at(3).hero.race = "troll"
	_check(fight.scan(eye) == "", "Opas Glasauge: for the troll")
	_ready(fight)
	# Fackel and Machete: not used in the app.
	_check(_asks_card_of(fight, 5) and fight.scan(catalog.find("wQEAAA==")) == "notice_not_here" and _notices[-1] == "notice_not_here", "Fackel: cannot be used here")
	_check(fight.scan(catalog.find("xwEAAA==")) == "notice_not_here" and _asks_card_of(fight, 5), "Machete: cannot be used here, and costs no action")
	# Trinkschlauch: the hero heals 3.
	_check(fight.scan(catalog.find("mAAAAA==")) == "" and _told[-1] == "heal" and _values[-1].player == "Sonja" and _values[-1].amount == 3, "Trinkschlauch: heal 3")
	_ready(fight)
	# Glücksbringer: the top card, without its lightning.
	_check(_asks_card_of(fight, 1) and fight.scan(catalog.find("BQEAAA==")) == "" and fight.request.prompt == "prompt_lucky_charm", "Glücksbringer: play the top card")
	fight.scan(_card("TOP", [["lightning", 1]], "halfling"))
	_check(_asks_card_of(fight, 3), "Glücksbringer: its lightning ignored")
	# Medizintasche: the hero removes 2 tokens.
	_check(fight.scan(catalog.find("BAEAAA==")) == "" and _told[-1] == "remove_tokens" and _values[-1].count == 2 and _values[-1].player == "Borin", "Medizintasche: remove 2 tokens")
	fight.abandon()

	# Deja-Vu: a card from the discard pile or the top of the draw pile, then out of the game.
	fight = _started(TestBoss.new())
	_check(fight.scan(catalog.find("SQAAAA==")) == "" and _asks_card_of(fight, 1) and fight.request.prompt == "prompt_discard_or_top", "Deja-Vu: which card?")
	fight.scan(_card("AGAIN", [["attack", 2, "ranged"], ["lightning", 1]], "halfling"))
	_check(fight.health == 28 and "AGAIN" in fight.removed and _told[-1] == "played_card_removed", "Deja-Vu: it is played, then out of the game")
	_ready(fight)
	_check(_asks_card_of(fight, 1), "Deja-Vu: its Lightning still counts")
	# Improvisieren: a hero of the players' choice plays their top 2 cards.
	_check(fight.scan(catalog.find("NQAAAA==")) == "" and fight.request.kind == Fight.Request.Kind.HERO and fight.request.values.get("count") == 2, "Improvisieren: who plays their top 2 cards?")
	fight.abandon()
	# Meteoritenschauer: each attack rolled from 1 to 3.
	fight = _started(TestBoss.new())
	var rolls := {}
	var kept := true
	var ability := CardAbility.create(catalog.find("WQEAAA=="))
	for i in 30:
		var meteors := CardPlay.new(fight.hero_at(1), ability.card)
		ability.before_effects(fight, meteors)
		for effect in meteors.effects:
			if effect.type == "attack":
				rolls[effect.strength] = true
		kept = kept and meteors.effects[3].strength == 2
	_check(rolls.keys().all(func(n: int) -> bool: return n >= 1 and n <= 3) and rolls.size() == 3 and kept, "Meteoritenschauer: attacks of 1 to 3, the health loss kept")
	fight.abandon()


## The boss's poison: kept for the whole fight, and it hurts the boss at the end of each round.
func _check_boss_poison() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	var fight := _started(TestBoss.new())
	var changes: Array[int] = []
	fight.poison_changed.connect(func(poison: int) -> void: changes.append(poison))
	_pass_until(fight, "phase_draw")
	_ready(fight)
	_check(not _told.has("boss_poison") and fight.round_number == 2, "without poison, nothing happens at the end of a round")
	for i in 3:
		_ready(fight)
	fight.choose(fight.hero_at(1))
	_ready(fight)
	_ready(fight)
	fight.scan(catalog.find("UQAAAA=="))
	_check(fight.poison == 1 and changes == [1] and fight.health == 28, "Vipernzahn: an attack and 1 poison, shown on screen")
	# Two Toxikum, from two heroes, add up.
	fight.scan(catalog.find("awEAAA=="))
	_ready(fight)
	fight.scan(catalog.find("awEAAA=="))
	_ready(fight)
	_pass_until(fight, "boss_poison")
	_check(_values[-1].damage == 3 and fight.health == 28, "two Toxikum: 3 per token, told before it hurts")
	_ready(fight)
	_check(fight.health == 25 and fight.poison == 1, "the poison hurts, and stays")
	_pass_until(fight, "boss_poison")
	_ready(fight)
	_check(fight.round_number == 4 and fight.health == 22, "and hurts again the next round")
	fight.abandon()

	# Poison can win the fight.
	fight = _started(TestBoss.new())
	fight.set_health(2)
	fight.scan(catalog.find("aAEAAA=="))
	_ready(fight)
	_pass_until(fight, "boss_poison")
	_ready(fight)
	_check(fight.over and fight.health == 0 and _told[-1] == "victory", "poison can defeat the boss")


## Cards that meet each other.
func _check_combos() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	# Stachelbola, then Lichtpfeile: it takes effect twice, so the next ranged attack gets two Lightnings.
	var fight := _started(TestBoss.new())
	fight.scan(catalog.find("OQEAAA=="))
	fight.scan(catalog.find("JwEAAA=="))
	_check(fight.health == 22 and _told[-1] == "card_repeated", "Stachelbola and Lichtpfeile: 4 damage twice")
	_ready(fight)
	fight.scan(_card("BOW", [["attack", 1, "ranged"]], "dwarf"))
	_check(fight.health == 21 and _asks_card_of(fight, 3) and _actions(fight.hero_at(3)) == "BBTT", "and the next ranged attack gets two Lightnings")
	fight.abandon()

	# Lichtpfeile, then Stachelbola: Stachelbola is the next card, which uses up the Lightning.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("JwEAAA=="))
	fight.scan(catalog.find("OQEAAA=="))
	fight.scan(_card("BOW", [["attack", 1, "ranged"]], "dwarf"))
	_check(fight.health == 24 and _told[-1] == "card_repeated", "Lichtpfeile, then Stachelbola: the next ranged attack twice")
	_ready(fight)
	_check(_asks_card_of(fight, 5), "but without a Lightning")
	fight.abandon()

	# A card that is not a ranged attack uses up Stachelbola.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("OQEAAA=="))
	fight.scan(_card("SHIELD", [["protection", 1]], "halfling"))
	fight.choose(fight.hero_at(1))
	fight.scan(_card("BOW", [["attack", 1, "ranged"]], "dwarf"))
	_check(fight.health == 29 and _asks_card_of(fight, 5), "Stachelbola: only the very next card counts")
	fight.abandon()

	# Amulett der Zeit and Arkanfalter: again past the shield's effect, with its Lightning.
	var boss := TestBoss.new()
	fight = _started(boss)
	fight.scan(catalog.find("NAEAAA=="))
	fight.scan(catalog.find("HgEAAA=="))
	_check(fight.health == 25 and not boss.calls.has("shield_hit magic"), "Amulett der Zeit repeats Arkanfalter, past the shield's effect")
	_ready(fight)
	_check(_asks_card_of(fight, 1), "with its Lightning for the same hero")
	fight.pass_action()
	fight.scan(catalog.find("HgEAAA=="))
	_ready(fight)
	_check(fight.health == 22 and _asks_card_of(fight, 5), "for another hero, without")
	_check(fight.hero_at(1).played.count("NAEAAA==") == 1 and fight.history.size() == 3, "repeated cards are not played again")
	fight.abandon()

	# Amulett der Zeit and Bombling: two blasts next round.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("1gEAAA=="))
	_ready(fight)
	fight.scan(catalog.find("HgEAAA=="))
	_check(_told[-1] == "attack_delayed" and fight.health == 30, "Amulett der Zeit repeats Bombling: it waits too")
	_pass_until(fight, "phase_draw")
	for i in 4:
		_ready(fight)
	fight.choose(fight.hero_at(1))
	_ready(fight)
	_check(fight.health == 25 and _told[-1] == "delayed_attack_now", "next round, the first blast")
	_ready(fight)
	_check(fight.health == 18 and _told[-1] == "delayed_attack_now", "then the second, past the broken shield")
	_ready(fight)
	_check(_asks_card_of(fight, 1), "then the hero's turn")
	fight.abandon()

	# Lichtpfeile repeated by Amulett der Zeit: the Amulett is the next card, which uses up
	# the first Lightning, but the repeat gives a new one.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("JwEAAA=="))
	fight.scan(catalog.find("HgEAAA=="))
	_check(fight.health == 22, "Amulett der Zeit repeats Lichtpfeile")
	_ready(fight)
	fight.scan(_card("BOW", [["attack", 1, "ranged"]], "dryad"))
	_check(fight.health == 21 and _actions(fight.hero_at(5)) == "BTT", "the next ranged attack gets one Lightning")
	fight.abandon()

	# Kultistenkette, then Schleimiger Helm on the same hero: nothing left to hurt the boss.
	boss = TestBoss.new()
	boss.threats = { 1: 9 }
	fight = _started(boss)
	fight.scan(catalog.find("0wEAAA=="))
	fight.choose(fight.hero_at(1))
	_ready(fight)
	fight.scan(catalog.find("2AEAAA=="))
	fight.choose(fight.hero_at(1))
	_check(fight.hero_at(1).threat == 0 and fight.health == 30, "Kultistenkette and Schleimiger Helm: 9 halved to 4, then blocked")
	fight.abandon()

	# Geisterwolf counts only the hero's own Supports.
	fight = _started(TestBoss.new())
	fight.scan(_card("ZAP", [["attack", 1, "magic"]], "halfling"))
	fight.scan(_card("SUP", [["support", 1, "magic"]], "dwarf"))
	fight.scan(_card("SUP2", [["support", 1, "magic"]], "dryad"))
	fight.scan(catalog.find("2QEAAA=="))
	_check(fight.health == 24, "Geisterwolf: no bonus for the Supports of others")
	fight.abandon()

	# Magmahorn finding Lianenschlange: its poison, and an item, all in one action.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("1AEAAA=="))
	fight.scan(catalog.find("ywEAAA=="))
	_check(fight.request.prompt == "prompt_use_item", "Magmahorn plays Lianenschlange, which asks for an item")
	fight.skip()
	_check(fight.poison == 1 and "ywEAAA==" in fight.removed and _told[-1] == "searched_card_removed", "the boss is poisoned, the card out of the game")
	_ready(fight)
	_check(_asks_card_of(fight, 3), "and the turn is over")
	_check(fight.scan(catalog.find("ywEAAA==")) == "notice_removed", "nobody can play it again")
	fight.abandon()


## Passes every action, reads every message and chooses the first hero asked for, until
## the fight tells id.
func _pass_until(fight: Fight, id: String) -> void:
	var start := _told.size()
	for i in 200:
		if fight.over or (_told.size() > start and _told[-1] == id):
			return
		if fight.request != null and fight.request.kind == Fight.Request.Kind.ACTION:
			fight.pass_action()
		elif fight.request != null and fight.request.kind == Fight.Request.Kind.HERO:
			fight.choose(fight.request.heroes[0])
		else:
			_ready(fight)


func _give_trait(fight: Fight, catalog: CardDatabase, qr: String, hero: FightHero) -> void:
	var ability := CardAbility.create(catalog.find(qr))
	ability.owner = hero
	fight.add_rule(ability)


## The actions each hero has left, which the screen shows as spheres: T for their turns,
## B for extra ones and L for extra ones that allow only some cards.
func _check_actions() -> void:
	var fight := _started(TestBoss.new())
	var rosie := fight.hero_at(1)
	_check(_actions(rosie) == "TTT" and _actions(fight.hero_at(3)) == "TTT", "each hero has 3 actions, counting the one being played")
	fight.scan(_card("SPARK", [["lightning", 1]], "halfling"))
	_check(_asks_card_of(fight, 1) and _actions(rosie) == "BTT", "lightning gives an extra one, played next")
	var charm := _card("CHARM", [], "items")
	charm.ability = "lucky_charm"
	fight.scan(charm)
	_check(_asks_card_of(fight, 1) and _actions(rosie) == "LTT", "the lucky charm's card is a limited one")
	fight.scan(_card("TOP", [["lightning", 1]], "halfling"))
	_check(_asks_card_of(fight, 3) and _actions(rosie) == "TT", "once played, it is gone")

	var gift := _card("GIFT", [], "dwarf")
	gift.ability = "free_play"
	fight.scan(gift)
	fight.choose(fight.hero_at(5))
	_check(_asks_card_of(fight, 5) and _actions(fight.hero_at(5)) == "BTTT", "a free card is an extra action")
	fight.skip()
	_check(_actions(fight.hero_at(5)) == "TTT" and _actions(fight.hero_at(3)) == "TT", "declined, it is gone too")

	fight.pass_action()
	var horse := _card("HORSE", [], "halfling")
	horse.ability = "extra_turns"
	horse.ability_values = { "now": true }
	fight.scan(horse)
	_check(_actions(rosie) == "TB", "a turn more this round comes last")
	_ready(fight)
	fight.pass_action()
	fight.pass_action()
	_check(_asks_card_of(fight, 1) and _actions(rosie) == "TB" and rosie.turns_left == 1, "the turns are taken first")
	for i in 3:
		fight.pass_action()
	_check(_asks_card_of(fight, 1) and _actions(rosie) == "B", "then the extra one")
	fight.abandon()
	_check(_actions(rosie) == "", "when the fight is over, none are left")


func _check_bosses() -> void:
	var colossus := Fight.new(Bosses.create("colossus"), "normal")
	colossus.deal_damage(9, "melee")
	_check(colossus.health == colossus.max_health - 4, "the colossus's armour halves melee")
	colossus.deal_damage(9, "magic")
	_check(colossus.health == colossus.max_health - 13, "but not magic")

	var mirefang := Bosses.create("mirefang")
	mirefang.attack_min = 4
	mirefang.attack_max = 4
	var fight := _started(mirefang, "normal", false)
	_ready(fight)
	_check(fight.request != null and fight.request.prompt == "prompt_tied_target" and fight.request.heroes.size() == 3, "with a tie, the players choose whom the boss targets")
	fight.choose(fight.hero_at(3))
	_check(fight.hero_at(3).threat_effects == { "poison": 1 } and _told[-1] == "mirefang_bite", "Mirefang's bite poisons")

	var easy := Bosses.create("ashwing").attack_range("easy")
	var hard := Bosses.create("ashwing").attack_range("hard")
	_check(hard.x == easy.x + 2 and hard.y == easy.y + 2, "the difficulty changes the boss's attacks")
	fight.abandon()


func _check_end() -> void:
	var fight := _started(TestBoss.new())
	var won := [false]
	fight.won.connect(func() -> void: won[0] = true)
	fight.scan(_card("BIG", [["attack", 99, "magic"]], "halfling"))
	_check(won[0] and fight.over and fight.health == 0, "the boss at 0 health is defeated")
	_check(_told[-1] == "victory" and fight.request == null and fight.phase == Fight.Phase.OVER, "which ends the fight")
	_check(fight.stats.outcome == FightStats.Outcome.WON and fight.stats.health_by_round[-1] == 0, "as won")
	_ready(fight)
	_check(_told[-1] == "victory", "and nothing follows")

	fight = _started(TestBoss.new())
	var lost := [false]
	fight.lost.connect(func() -> void: lost[0] = true)
	fight.lose()
	_check(lost[0] and _told[-1] == "defeat" and fight.request == null, "a fight can be lost")
	fight.abandon()
	_check(fight.stats.outcome == FightStats.Outcome.LOST, "and stays lost")


## A fight against boss with Rosie, Borin and Sonja, its messages noted. With levels,
## they have shown their level cards from the catalog: Rosie is a Halfling Luckmaster and
## Rogue King, Borin a Dwarven Treasure Keeper and Elite Warrior, Sonja a Dryad Primal
## Force and High Druid.
func _fight(boss: Boss, difficulty := "normal", levels := false) -> Fight:
	var heroes: Array[Party.Hero] = []
	for entry: Array in [["Sonja", "dryad", "druid", 5, "iAEAAA==", "KwEAAA=="], ["Rosie", "halfling", "thief", 1, "AAEAAA==", "KgEAAA=="],
			["Borin", "dwarf", "warrior", 3, "/wAAAA==", "KAEAAA=="]]:
		var hero := Party.Hero.new()
		hero.name = entry[0]
		hero.race = entry[1]
		hero.hero_class = entry[2]
		hero.seat = entry[3]
		if levels:
			hero.race_card = entry[4]
			hero.class_card = entry[5]
		heroes.append(hero)
	var fight := Fight.new(boss, difficulty, heroes, CardDatabase.load_file("res://cards/cards.json"))
	fight.rng.seed = 7
	_told.clear()
	_values.clear()
	_notices.clear()
	_raised.clear()
	fight.shields_raised.connect(func(shields: Dictionary) -> void: _raised.append(shields.duplicate()))
	fight.message.connect(func(id: String, values: Dictionary) -> void:
		_told.append(id)
		_values.append(values))
	fight.notice.connect(func(id: String, _values: Dictionary) -> void: _notices.append(id))
	return fight


## A fight up to the first card of round 1, with Rosie starting. Without to_cards, up to
## the boss planning its attacks.
func _started(boss: Boss, difficulty := "normal", to_cards := true, levels := false) -> Fight:
	var fight := _fight(boss, difficulty, levels)
	fight.start()
	_ready(fight)
	_ready(fight)
	if to_cards:
		_ready(fight)
		fight.choose(fight.hero_at(1))
		_ready(fight)
		_ready(fight)
	return fight


func _ready(fight: Fight) -> void:
	fight.players_ready()


func _actions(hero: FightHero) -> String:
	var letters := ""
	for action in hero.actions():
		letters += "TBL"[action]
	return letters


func _asks_card_of(fight: Fight, seat: int) -> bool:
	return fight.request != null and fight.request.kind == Fight.Request.Kind.ACTION and fight.request.hero.seat == seat


## symbols are [type, strength, damage type].
func _card(qr: String, symbols: Array, deck: String) -> Card:
	var data := { "qr": qr, "deck": deck, "symbols": [] }
	for symbol: Array in symbols:
		data.symbols.append({ "type": symbol[0], "strength": symbol[1], "damage_type": symbol[2] if symbol.size() > 2 else "" })
	return Card.from_data(data)


func _check(condition: bool, description: String) -> void:
	_checks_run += 1
	print(("  ok   " if condition else "  FAIL ") + description)
	if not condition:
		_failures += 1
