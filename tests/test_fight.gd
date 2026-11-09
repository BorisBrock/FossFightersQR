extends SceneTree
## The rules of a fight, without a screen: the rounds and phases, what cards do, and how
## bosses and abilities step in. The fight waits for the players, and the test plays them.
## Run with: godot --headless -s tests/test_fight.gd

const EXPECTED_CHECKS := 495
const EMPOWER := preload("res://scripts/abilities/empower.gd")
const BOOST_NEXT_CARDS := preload("res://scripts/abilities/boost_next_cards.gd")
const NEXT_CARD := preload("res://scripts/abilities/next_card.gd")
const DRYAD_FORM := preload("res://scripts/abilities/dryad_form.gd")

var _failures := 0
var _checks_run := 0
## What the fight told the players, in order, by message id.
var _told: Array[String] = []
var _values: Array[Dictionary] = []
var _raised: Array[Dictionary] = []
var _notices: Array[String] = []


## A boss whose attacks and shields are known, and which notes what it was told.
## A boss whose armour halves melee and ranged damage and tells the players so, for the
## damage_taken hook.
class ArmouredBoss extends Boss:
	func _init() -> void:
		title = { "de": "Gepanzert", "en": "Armoured" }
		health = 60

	func damage_taken(fight: Fight, amount: int, kind: String, _play: CardPlay) -> int:
		if kind not in ["melee", "ranged"]:
			return amount
		var halved := floori(amount / 2.0)
		fight.tell("armour", { "damage": halved })
		return halved


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
	_check_new_loot_cards()
	_check_last_loot_cards()
	_check_final_loot_cards()
	_check_elf_cards()
	_check_druid_cards()
	_check_items()
	_check_dryad_forms()
	_check_dryad_cards()
	_check_paladin_cards()
	_check_shaman_cards()
	_check_battle_robot()
	_check_goblin_cards()
	_check_buffs()
	_check_boss_poison()
	_check_combos()
	_check_set_strength()
	_check_replays()
	_check_shield_breaks()
	_check_redirects()
	_check_nested_plays()
	_check_ends_mid_chain()
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
	_check(fight.phase == Fight.Phase.PLANNING and _values[-1].has("boss") and fight.request == null, "and the boss plans its attacks, told in the same message")
	_check(fight.hero_at(1).threat == 4 and fight.hero_at(5).threat_effects == { "poison": 1 }, "against each hero")
	var attacked := []
	fight.boss_attacked.connect(func(kind: String, amount: int) -> void: attacked.append([kind, amount]))
	# The screen shows the shields rising, and the fight waits for it.
	fight.shields_raised.connect(func(_shields: Dictionary) -> void: fight.hold_screen(), CONNECT_ONE_SHOT)
	_ready(fight)
	_check(fight.phase == Fight.Phase.SHIELD and fight.shields == { "melee": 2, "ranged": 0, "magic": 1 }, "then the boss raises its shields")
	_check(not _told.has("phase_shield") and _raised == [fight.shields], "shown as they rise, without a message")
	_check(fight.request == null, "and the players wait while the screen shows them")
	fight.release_screen()
	_check(fight.request != null and fight.request.kind == Fight.Request.Kind.HERO and fight.request.heroes.size() == 3, "knowing the attacks and shields, the players choose who starts")
	fight.choose(fight.hero_at(3))
	_check(fight.starter == fight.hero_at(3), "tapping a hero chooses them")
	_check(_told[-1] == "phase_action" and _values[-1].player == "Borin", "the action phase starts with the chosen hero")
	_ready(fight)
	_check(_asks_card_of(fight, 3), "whose card is asked for first")

	# Borin: a melee attack breaks the shield first.
	_check(fight.scan(_card("AXE", [["attack", 5, "melee"]], "dwarf")) == "", "a card is played")
	_check(fight.shields.melee == 0 and fight.health == 27, "its damage breaks the shield of its kind, then hurts")
	_check(attacked == [["melee", 5]], "the screen hears of the attack, to show it")
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
	var unknown_values := {}
	fight.notice.connect(func(_id: String, values: Dictionary) -> void: unknown_values.merge(values), CONNECT_ONE_SHOT)
	_check(fight.scan(null, "XYZ") == "notice_unknown_card", "an unknown card is not played")
	_check(unknown_values.get("code") == "XYZ", "and its QR code is shown")
	_check(fight.scan(_card("HALL", [["attack", 3, "melee"]], "rooms")) == "notice_cannot_play_now", "nor a room card")
	fight.pass_action()
	_check(_asks_card_of(fight, 1), "passing gives up the action")
	for i in 4:
		fight.pass_action()
	_check(fight.active_hero == null and _told[-1] == "boss_attacks" and _told.count("boss_attacks") == 1, "after three turns each, the boss attacks, told in one message")
	var hits: Array = _values[-1].hits
	_check(hits.map(func(hit: Array) -> String: return hit[1].player) == ["Rosie", "Borin"] and hits[1] == ["part_hit", { "player": "Borin", "damage": 2 }], "every hero it still threatens, one line each")
	_ready(fight)
	_check(_told.slice(-3) == ["round_end_status", "round_end_discard", "round_end_draw"] and fight.phase == Fight.Phase.ROUND_END, "then the players apply their status tokens, discard and draw, told in a message each")
	_ready(fight)
	_check(_told[-1] == "round_started" and fight.round_number == 2, "and the next round begins")
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
	_check(_told[-1] == "boss_attacks" and _values[-1].hits[-1][0] == "part_hit_with_tokens" and _values[-1].hits[-1][1].tokens.en == "1 poison", "a poisonous attack tells the hero to take poison")
	_ready(fight)
	_check(_told[-1] == "round_end_draw", "which the players apply at the end of the round")

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
	_check(_values[-1].get("source", {}).get("title") == catalog.find("ugEAAA==").title and _values[-1].source.get("hero") == rosie.name, "told as the Celestial Paladin's, with its hero, for the message's title")
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
	fight.scan(_card("B1", [["attack", 1, "ranged"]], "halfling"))
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
	_check(fight.request.kind == Fight.Request.Kind.SHIELD and fight.request.kinds == ["melee", "magic"], "Explosivkristall: which shield? The players tap it")
	fight.choose_shield("ranged")
	_check(fight.request != null and fight.request.kind == Fight.Request.Kind.SHIELD, "Explosivkristall: a broken shield cannot be chosen")
	fight.choose_shield("melee")
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
	_pass_until(fight, "round_end_draw")
	_check(fight.poison == 1 and _told.count("poison_on_attack") == 1 and _values[_told.find("poison_on_attack")].player == "Borin", "Krone des Prinzen: attack of 4 on Borin, the boss gets 1 poison")
	_check(_told.find("poison_on_attack") == _told.find("boss_attacks") + 1, "Krone des Prinzen: told right after the boss's hits")
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
	_pass_until(fight, "round_end_draw")
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
	_pass_until(fight, "round_started")
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


## More loot cards from the catalog.
func _check_new_loot_cards() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	# Spinneneier: as many tokens as the attack cost the boss, from a hero of the players' choice.
	var fight := _started(TestBoss.new())
	fight.scan(catalog.find("zwEAAA=="))
	_check(fight.health == 28 and fight.request.prompt == "prompt_remove_tokens_who" and fight.request.values.count == 2, "Spinneneier: 2 damage, so 2 tokens, from whom?")
	fight.choose(fight.hero_at(5))
	_check(_told[-1] == "remove_tokens" and _values[-1].player == "Sonja" and _values[-1].count == 2, "Spinneneier: Sonja removes 2 tokens")
	fight.abandon()
	var boss := TestBoss.new()
	boss.shields = { "melee": 0, "ranged": 5, "magic": 0 }
	fight = _started(boss)
	fight.scan(catalog.find("zwEAAA=="))
	_check(fight.health == 30 and not _told.has("remove_tokens") and fight.request.prompt != "prompt_remove_tokens_who", "Spinneneier: none if the shield takes it all")
	fight.abandon()

	# Stachel des Frostskorpions: 3 straight to the boss's health, and 2 poison.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("YAEAAA=="))
	_check(fight.health == 27 and fight.poison == 2, "Stachel des Frostskorpions: 3 damage and 2 poison")
	fight.abandon()

	# Drachenspeichel: two different heroes heal 6 each.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("LAEAAA=="))
	_check(fight.request.prompt == "prompt_heal_who" and fight.request.heroes.size() == 3, "Drachenspeichel: who heals?")
	fight.choose(fight.hero_at(5))
	_check(_told[-1] == "heal" and _values[-1].player == "Sonja" and _values[-1].amount == 6, "Drachenspeichel: Sonja heals 6")
	_ready(fight)
	_check(fight.request.prompt == "prompt_heal_who" and fight.request.heroes.size() == 2 and not fight.hero_at(5) in fight.request.heroes, "Drachenspeichel: then another hero")
	fight.choose(fight.hero_at(3))
	_check(_told[-1] == "heal" and _values[-1].player == "Borin" and _values[-1].amount == 6 and _told.count("heal") == 2, "Drachenspeichel: Borin heals 6")
	fight.abandon()

	# Kompass der Verdammten: each hero looks at their top 3 and takes 1, then another action.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("0gEAAA=="))
	_check(_told[-1] == "look_at_top_everyone" and _values[-1].look == 3 and _values[-1].take == 1 and _values[-1].back == 2, "Kompass der Verdammten: everyone looks at 3 and takes 1")
	_ready(fight)
	_check(_asks_card_of(fight, 1), "Kompass der Verdammten: then another action")
	fight.abandon()

	# Verlorene Seele: a card of the hero's choice from the draw pile into the hand.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("ygEAAA=="))
	_check(_told[-1] == "search_to_hand" and _values[-1].player == "Rosie" and _values[-1].count == 1, "Verlorene Seele: Rosie takes 1 card from her pile")
	fight.abandon()

	# Sonnenring: together, as many tokens as the round, then another action.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("zQEAAA=="))
	_check(_told[-1] == "remove_tokens_group" and _values[-1].count == 1, "Sonnenring: 1 token in round 1, together")
	_ready(fight)
	_check(_asks_card_of(fight, 1), "Sonnenring: then another action")
	fight.abandon()

	# Banner des Mutes: another hero acts at once, then another action.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("CQEAAA=="))
	_check(fight.request.prompt == "prompt_free_play_who" and not fight.hero_at(1) in fight.request.heroes, "Banner des Mutes: which other hero?")
	fight.choose(fight.hero_at(3))
	_check(_asks_card_of(fight, 3) and fight.request.prompt == "prompt_free_play", "Banner des Mutes: Borin acts at once")
	fight.skip()
	_check(_asks_card_of(fight, 1), "Banner des Mutes: then Rosie's Lightning")
	fight.abandon()

	# Geflügelter Schild: protection 4, then another action.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("NwEAAA=="))
	fight.choose(fight.hero_at(5))
	_check(fight.hero_at(5).threat == 0 and _asks_card_of(fight, 1), "Geflügelter Schild: protection 4, then another action")
	fight.abandon()

	# Güldis Angel: a hero of the players' choice draws 5, plays 2 of them, discards 3.
	boss = TestBoss.new()
	boss.shields = { "melee": 0, "ranged": 0, "magic": 0 }
	fight = _started(boss)
	fight.scan(catalog.find("1wEAAA=="))
	_check(fight.request.prompt == "prompt_chosen_hero", "Güldis Angel: for whom?")
	fight.choose(fight.hero_at(3))
	_check(_told[-1] == "draw_and_play" and _values[-1].player == "Borin" and _values[-1].draw == 5 and _values[-1].play == 2 and _values[-1].discard == 3, "Güldis Angel: Borin draws 5, plays 2, discards 3")
	_ready(fight)
	_check(_asks_card_of(fight, 3) and fight.request.prompt == "prompt_play_drawn", "Güldis Angel: Borin plays a drawn card")
	fight.scan(_card("DRAWN1", [["attack", 2, "melee"], ["lightning", 1]], "dwarf"))
	_check(_asks_card_of(fight, 3) and fight.request.prompt == "prompt_play_drawn", "Güldis Angel: and a second")
	fight.scan(_card("DRAWN2", [["attack", 1, "melee"]], "dwarf"))
	_ready(fight)
	_check(fight.health == 27 and _asks_card_of(fight, 3) and fight.request.prompt == "prompt_free_play", "Güldis Angel: both hit, then the Lightning on them")
	fight.abandon()

	# Geisterrüstung: two protections of 3, and the hero takes a status token.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("HwEAAA=="))
	fight.choose(fight.hero_at(5))
	_ready(fight)
	fight.choose(fight.hero_at(3))
	_check(fight.hero_at(5).threat == 0 and fight.hero_at(3).threat == 0 and _told[-1] == "take_token" and _values[-1].player == "Rosie" and _values[-1].count == 1, "Geisterrüstung: Sonja and Borin protected, Rosie takes a token")
	fight.abandon()


func _check_last_loot_cards() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	# Träne des Mitleids: lies by Rosie, the players handle it on the table.
	var fight := _started(TestBoss.new())
	fight.scan(catalog.find("XwEAAA=="))
	_check(_told[-1] == "tear_placed" and _values[-1].player == "Rosie", "Träne des Mitleids: Rosie places it by her hero card")
	fight.abandon()

	# Trommel der Ahnen: 2 tokens off every hero.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("IAEAAA=="))
	_check(_told[-1] == "remove_tokens_everyone" and _values[-1].count == 2 and not _told.has("remove_tokens"), "Trommel der Ahnen: each hero removes 2 tokens")
	fight.abandon()

	# Perfektes Zusammenspiel: each hero draws 2 and puts 1 back, then another action.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("FwEAAA=="))
	_check(_told[-1] == "draw_and_return_everyone" and _values[-1].draw == 2 and _values[-1].back == 1, "Perfektes Zusammenspiel: everyone draws 2, puts 1 back")
	_ready(fight)
	_check(_asks_card_of(fight, 1), "Perfektes Zusammenspiel: then another action")
	fight.abandon()

	# Stachelschild: protection 3 and 2 straight to the boss's health.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("yQEAAA=="))
	fight.choose(fight.hero_at(5))
	_check(fight.hero_at(5).threat == 0 and fight.health == 28 and fight.shields.melee == 2, "Stachelschild: Sonja protected, the boss loses 2 past its shields")
	fight.abandon()

	# Schicksalsmünze: a melee support of 5.
	fight = _started(TestBoss.new())
	fight.scan(_card("HIT", [["attack", 2, "melee"], ["lightning", 1]], "halfling"))
	_ready(fight)
	fight.scan(catalog.find("DQEAAA=="))
	_check(fight.health == 25, "Schicksalsmünze: melee support 5 after a melee attack")
	fight.abandon()

	# Muttis Nachtisch: the next 8 cards get +1 on attacks and supports, a random hero gets poison.
	fight = _started(TestBoss.new())
	var rules_before := fight.rules.size()
	fight.scan(catalog.find("0AEAAA=="))
	_check(_told[-1] == "next_cards_boosted" and _values[-1].cards == 8 and _values[-1].bonus == 1, "Muttis Nachtisch: the next 8 cards are boosted")
	_ready(fight)
	_check(_told[-1] == "random_token" and _values[-1].player in ["Rosie", "Borin", "Sonja"] and _values[-1].tokens.en == "1 poison", "Muttis Nachtisch: a random hero takes 1 poison")
	_ready(fight)
	var decks := { 1: "halfling", 3: "dwarf", 5: "dryad" }
	for i in 8:
		fight.scan(_card("ARROW%d" % i, [["attack", 1, "ranged"]], decks[fight.request.hero.seat]))
		_ready(fight)
		if i == 6:
			_check(fight.health == 16 and fight.rules.size() == rules_before + 1, "Muttis Nachtisch: 7 attacks of 1 hit for 2 each")
	_check(fight.health == 14 and fight.rules.size() == rules_before, "Muttis Nachtisch: the 8th too, and then it is over")
	fight.abandon()

	# Gaias Köcher: ranged 4 and 1 poison.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("MAEAAA=="))
	_check(fight.health == 26 and fight.poison == 1, "Gaias Köcher: 4 damage and 1 poison")
	fight.abandon()

	# Vampirischer Sog: magic 4, and a hero of the players' choice heals 4.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("NgEAAA=="))
	_check(fight.request.prompt == "prompt_chosen_hero", "Vampirischer Sog: who heals?")
	fight.choose(fight.hero_at(3))
	_check(fight.health == 27 and _told[-1] == "heal" and _values[-1].player == "Borin" and _values[-1].amount == 4, "Vampirischer Sog: 3 past the magic shield, Borin heals 4")
	fight.abandon()

	# Pyro-Falle: a shield of the players' choice goes down by 4, without its effect.
	var boss := TestBoss.new()
	fight = _started(boss)
	fight.scan(catalog.find("FAEAAA=="))
	_check(fight.request.prompt == "prompt_lower_shield" and fight.request.values.amount == 4, "Pyro-Falle: which shield?")
	fight.choose_shield("melee")
	_check(fight.shields.melee == 0 and fight.health == 30 and not boss.calls.has("shield_hit melee") and _values[-1].amount == 2, "Pyro-Falle: the melee shield breaks, nothing beyond it")
	fight.abandon()

	# Donnerspeer: ranged 8, then out of the game for everyone.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("MgEAAA=="))
	_check(fight.health == 22 and _told[-1] == "card_removed" and "MgEAAA==" in fight.removed, "Donnerspeer: 8 damage, then out of the game")
	_ready(fight)
	_check(fight.scan(catalog.find("MgEAAA==")) == "notice_removed", "Donnerspeer: no hero can play it again")
	fight.abandon()


## The last loot cards from the catalog, and the rooms.
func _check_final_loot_cards() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	# Giftexplosion: 3 per poison token of the boss, then its poison is gone; its own poison symbol adds none.
	var fight := _started(TestBoss.new())
	fight.set_poison(2)
	fight.scan(catalog.find("aQEAAA=="))
	_check(_told[-1] == "poison_burst" and _values[-1].poison == 2 and _values[-1].damage == 6, "Giftexplosion: 2 poison, 6 damage")
	_ready(fight)
	_check(fight.health == 24 and fight.shields.melee == 2 and fight.poison == 0 and _told[-1] == "poison_cleared", "Giftexplosion: past the shields, then the poison is gone")
	fight.abandon()
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("aQEAAA=="))
	_check(_told[-1] == "poison_burst_none" and fight.poison == 0 and fight.health == 30, "Giftexplosion: without poison, nothing happens")
	fight.abandon()

	# Stab der Vergiftung: 1 per poison token, which stay, then another action.
	fight = _started(TestBoss.new())
	fight.set_poison(3)
	fight.scan(catalog.find("agEAAA=="))
	_ready(fight)
	_check(fight.health == 27 and fight.poison == 3 and _asks_card_of(fight, 1), "Stab der Vergiftung: 3 poison, 3 damage, the poison stays, another action")
	fight.abandon()

	# Smaragdschild: Protection 2, and the protected hero acts at once.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("0QEAAA=="))
	fight.choose(fight.hero_at(3))
	_check(fight.hero_at(3).threat == 1 and _asks_card_of(fight, 3) and fight.request.prompt == "prompt_free_play", "Smaragdschild: Borin protected by 2, and he acts at once")
	fight.abandon()

	# Waffengift: a shield of the players' choice goes down by 2; if it breaks, the boss gets 2 poison.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("ZwEAAA=="))
	_check(fight.request.prompt == "prompt_lower_shield" and fight.request.values.amount == 2, "Waffengift: which shield?")
	fight.choose_shield("melee")
	_check(fight.shields.melee == 0 and fight.poison == 2 and _told[-1] == "shield_broken_poison", "Waffengift: the melee shield of 2 breaks, the boss gets 2 poison")
	fight.abandon()
	var boss := TestBoss.new()
	boss.shields = { "melee": 5 }
	fight = _started(boss)
	fight.scan(catalog.find("ZwEAAA=="))
	_check(fight.shields.melee == 3 and fight.poison == 0 and _told[-1] == "shield_lowered", "Waffengift: a shield that holds gives no poison")
	fight.abandon()

	# Magische Haut: Protection as high as the round, then another action.
	boss = TestBoss.new()
	boss.threats = { 3: 6 }
	fight = _started(boss)
	fight.scan(catalog.find("FQEAAA=="))
	fight.choose(fight.hero_at(3))
	_check(fight.hero_at(3).threat == 5, "Magische Haut: Protection 1 in round 1")
	_ready(fight)
	_check(_asks_card_of(fight, 1), "Magische Haut: and another action")
	print("PROBE ", _actions(fight.hero_at(1)), " ", fight.hero_at(1).pending)
	fight.abandon()
	for th in [{}, { 1: 6 }, { 1: 3, 3: 4 }]:
		boss = TestBoss.new()
		boss.threats = th
		fight = _started(boss)
		fight.scan(catalog.find("FQEAAA=="))
		if fight.request != null and fight.request.kind != Fight.Request.Kind.ACTION:
			fight.choose(fight.hero_at(1))
		print("PROBE th", th, " ", _actions(fight.hero_at(1)))
		fight.abandon()
	for r in [2, 3]:
		boss = TestBoss.new()
		boss.threats = { 3: 6 }
		fight = _started(boss)
		fight.round_number = r
		fight.scan(catalog.find("FQEAAA=="))
		print("PROBE r", r, " before choose ", _actions(fight.hero_at(1)))
		fight.choose(fight.hero_at(3))
		print("PROBE r", r, " ", _actions(fight.hero_at(1)), " threat ", fight.hero_at(3).threat)
		fight.abandon()

	# Stiefel: Protection 1, and a hero of the players' choice draws 1.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("GQEAAA=="))
	_check(fight.request.prompt == "prompt_chosen_hero", "Stiefel: who draws?")
	fight.choose(fight.hero_at(5))
	fight.choose(fight.hero_at(3))
	_check(fight.hero_at(3).threat == 2 and _told[-1] == "draw_cards" and _values[-1].player == "Sonja" and _values[-1].count == 1, "Stiefel: Borin protected, Sonja draws 1")
	fight.abandon()

	# Feenkokon: every hero heals 3.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("EwEAAA=="))
	var healed := []
	for i in _told.size():
		if _told[i] == "heal" and _values[i].amount == 3:
			healed.append(_values[i].player)
	_check(healed.size() == 3 and "Rosie" in healed and "Borin" in healed and "Sonja" in healed, "Feenkokon: every hero heals 3")
	fight.abandon()

	# Voodoo-Puppe: random hand cards for the rest of the round, with a reminder at her turns; 3 more actions.
	fight = _started(TestBoss.new())
	var rosie := fight.hero_at(1)
	fight.scan(catalog.find("2gEAAA=="))
	_check(_told[-1] == "random_hand_cards" and _values[-1].player == "Rosie" and fight.buffs(rosie).size() == 1, "Voodoo-Puppe: Rosie plays random hand cards, her seat shows it")
	_ready(fight)
	_check(_asks_card_of(fight, 1) and _actions(rosie).begins_with("BBB"), "Voodoo-Puppe: 3 more actions")
	for i in 5:
		fight.pass_action()
	_check(_told[-1] == "random_hand_reminder" and _values[-1].player == "Rosie", "Voodoo-Puppe: reminded at her next turn")
	_pass_until(fight, "round_started")
	_check(fight.round_number == 2 and fight.buffs(rosie).is_empty(), "Voodoo-Puppe: over with the round")
	fight.abandon()

	# Phönixfeder: 2 fire for every hero, a hero's health back to their start, then out of the game.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("2wEAAA=="))
	_check(_told[-1] == "tokens_everyone" and _values[-1].tokens.en == "2 fire", "Phönixfeder: every hero takes 2 fire")
	_ready(fight)
	_check(fight.request.prompt == "prompt_reset_health_who", "Phönixfeder: whose health?")
	fight.choose(fight.hero_at(3))
	_check(_told[-1] == "reset_health" and _values[-1].player == "Borin", "Phönixfeder: Borin back to his starting health")
	_ready(fight)
	_check(_told[-1] == "card_removed" and "2wEAAA==" in fight.removed, "Phönixfeder: then out of the game")
	fight.abandon()

	# Rooms are not played.
	fight = _started(TestBoss.new())
	_check(fight.scan(catalog.find("wwEAAA==")) == "notice_cannot_play_now" and _asks_card_of(fight, 1), "Ort: Empore cannot be played")
	fight.abandon()


## The elf's cards from the catalog, played by Rosie as an elf.
func _check_elf_cards() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	# Gezielter Schuss: a ranged attack as strong as the round, then another action.
	var fight := _started(TestBoss.new())
	fight.hero_at(1).hero.race = "elf"
	fight.scan(catalog.find("VwEAAA=="))
	_check(fight.health == 29 and _asks_card_of(fight, 1), "Gezielter Schuss: ranged 1 in round 1, another action")
	fight.abandon()

	# Gaias Bogen: ranged 4, and a hero of the players' choice draws 1.
	fight = _started(TestBoss.new())
	fight.hero_at(1).hero.race = "elf"
	fight.scan(catalog.find("KAAAAA=="))
	fight.choose(fight.hero_at(3))
	_check(fight.health == 26 and _told[-1] == "draw_cards" and _values[-1].player == "Borin", "Gaias Bogen: 4 damage, Borin draws 1")
	fight.abandon()

	# Diadem der Unsichtbarkeit: her next attack, of any type, is 3 higher.
	fight = _started(TestBoss.new())
	var rosie := fight.hero_at(1)
	rosie.hero.race = "elf"
	fight.scan(catalog.find("WAEAAA=="))
	_check(_asks_card_of(fight, 1) and fight.buffs(rosie).size() == 1, "Diadem der Unsichtbarkeit: another action, her seat shows it")
	fight.scan(_card("BLADE", [["attack", 2, "melee"]], "elf"))
	_check(fight.health == 27 and fight.buffs(rosie).is_empty(), "Diadem der Unsichtbarkeit: melee 2 is 5, 3 past the shield, and it is used up")
	fight.abandon()

	# Lyrias Ring: every hero heals 2.
	fight = _started(TestBoss.new())
	fight.hero_at(1).hero.race = "elf"
	fight.scan(catalog.find("JgAAAA=="))
	_check(_told.count("heal") == 3 and _values[-1].amount == 2, "Lyrias Ring: every hero heals 2")
	fight.abandon()


## The druid's cards from the catalog, played by Rosie as a druid.
func _check_druid_cards() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	# Pilzpulver: a hero of the players' choice heals 5 and acts at once.
	var fight := _started(TestBoss.new())
	fight.hero_at(1).hero.hero_class = "druid"
	fight.scan(catalog.find("XQAAAA=="))
	fight.choose(fight.hero_at(5))
	_check(_told[-1] == "heal" and _values[-1].player == "Sonja" and _values[-1].amount == 5, "Pilzpulver: Sonja heals 5")
	_ready(fight)
	_check(_asks_card_of(fight, 5) and fight.request.prompt == "prompt_free_play", "Pilzpulver: and acts at once")
	fight.abandon()

	# Maske der Hellsicht: she plays one of her top 3 cards, its Lightning gives her an action, the other 2 go back.
	fight = _started(TestBoss.new())
	fight.hero_at(1).hero.hero_class = "druid"
	fight.scan(catalog.find("VQAAAA=="))
	_check(_asks_card_of(fight, 1) and fight.request.prompt == "prompt_play_from_top" and fight.request.values.look == 3, "Maske der Hellsicht: which of the top 3?")
	fight.scan(_card("TOP", [["attack", 1, "ranged"], ["lightning", 1]], "druid"))
	_check(fight.health == 29 and _told[-1] == "play_from_top_rest" and _values[-1].count == 2, "Maske der Hellsicht: it is played, the other 2 go back")
	_ready(fight)
	_check(_asks_card_of(fight, 1), "Maske der Hellsicht: its Lightning gives her another action")
	fight.abandon()

	# Phönix-Eule: her next attack heals a hero of the players' choice as much as it.
	fight = _started(TestBoss.new())
	fight.hero_at(1).hero.hero_class = "druid"
	fight.scan(catalog.find("VgAAAA=="))
	_check(_asks_card_of(fight, 1) and fight.buffs(fight.hero_at(1)).size() == 1, "Phönix-Eule: another action, her seat shows it")
	fight.scan(_card("BOLT", [["attack", 3, "magic"]], "druid"))
	_check(fight.health == 28 and fight.request.prompt == "prompt_heal_who" and fight.request.values.amount == 3, "Phönix-Eule: magic 3, who heals 3?")
	fight.choose(fight.hero_at(3))
	_check(_told[-1] == "heal" and _values[-1].player == "Borin" and _values[-1].amount == 3 and fight.buffs(fight.hero_at(1)).is_empty(), "Phönix-Eule: Borin heals 3, and it is used up")
	fight.abandon()

	# Antidot: a hero of the players' choice removes 2 tokens, then another action.
	fight = _started(TestBoss.new())
	fight.hero_at(1).hero.hero_class = "druid"
	fight.scan(catalog.find("WwAAAA=="))
	_check(fight.request.prompt == "prompt_remove_tokens_who", "Antidot: whose tokens?")
	fight.choose(fight.hero_at(5))
	_check(_told[-1] == "remove_tokens" and _values[-1].player == "Sonja" and _values[-1].count == 2, "Antidot: Sonja removes 2")
	_ready(fight)
	_check(_asks_card_of(fight, 1), "Antidot: and another action")
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
	fight.hero_at(1).hero.hero_class = "magician"
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
		ability.set_strength(fight, meteors)
		for effect in meteors.effects:
			if effect.type == "attack":
				rolls[effect.strength] = true
		kept = kept and meteors.effects[3].strength == 2
	_check(rolls.keys().all(func(n: int) -> bool: return n >= 1 and n <= 3) and rolls.size() == 3 and kept, "Meteoritenschauer: attacks of 1 to 3, the health loss kept")
	fight.abandon()


## The dryad's form cards: they lie by her, can be played again and again, and give her
## the perk of the form until she takes another.
func _check_dryad_forms() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	var thorn := catalog.find("vQEAAA==")
	var blossom := catalog.find("vgEAAA==")
	var bark := catalog.find("vAEAAA==")
	var fight := _dryad_starts()
	var sonja := fight.hero_at(5)
	_check(sonja.form == "" and fight.scan(thorn) == "" and sonja.form == "thorn" and _told[-1] == "form_thorn", "Stachelform: the dryad takes the thorn form")
	_ready(fight)
	_check(_asks_card_of(fight, 1) and fight.scan(thorn) == "notice_not_your_card", "Stachelform: only for the dryad")
	fight.pass_action()
	fight.pass_action()
	_check(_asks_card_of(fight, 5) and fight.scan(thorn) == "notice_form_already" and _asks_card_of(fight, 5), "Stachelform: not again while she has it, which costs no action")
	fight.scan(_card("THORN_HIT", [["attack", 2, "ranged"], ["lightning", 1]], "dryad"))
	fight.scan(_card("THORN_SUP", [["support", 1, "ranged"], ["lightning", 1]], "dryad"))
	_check(fight.health == 25, "Stachelform: her attacks and supports +1")
	_check(fight.scan(bark) == "" and sonja.form == "bark" and fight.rules.filter(func(rule: FightRule) -> bool: return rule.get("form") != null).size() == 1, "Borkenform: a new form replaces the old one")
	_ready(fight)
	fight.pass_action()
	fight.pass_action()
	_check(_asks_card_of(fight, 5) and fight.scan(thorn) == "" and sonja.form == "thorn", "the forms can be played again in the same round")
	fight.abandon()

	fight = _dryad_starts()
	fight.scan(bark)
	_ready(fight)
	fight.pass_action()
	fight.pass_action()
	fight.scan(_card("BARK_GUARD", [["protection", 2]], "dryad"))
	fight.choose(fight.hero_at(1))
	_check(fight.hero_at(1).threat == 0, "Borkenform: her protection +1")
	fight.abandon()

	fight = _dryad_starts()
	fight.scan(blossom)
	_ready(fight)
	fight.scan(_card("OTHER_HIT", [["attack", 2, "ranged"]], "halfling"))
	_check(not _told.has("heal"), "Blütenform: not from the attacks of others")
	fight.pass_action()
	fight.scan(_card("BLOSSOM_HIT", [["attack", 2, "ranged"], ["attack", 1, "melee"], ["direct_damage", 1]], "dryad"))
	_check(fight.health == 25 and _told.count("heal") == 1 and _values[_told.find("heal")].amount == 3 and _values[_told.find("heal")].player == "Sonja", "Blütenform: she heals 3 each time her attack costs the boss health")
	fight.abandon()


## The dryad's deck: the cards with an ability, from the catalog.
func _check_dryad_cards() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	# Stachelfaust: 1 stronger each time it was played before, back into the draw pile.
	var fist := catalog.find("mQEAAA==")
	var fight := _dryad_starts()
	fight.scan(fist)
	_check(fight.health == 29, "Stachelfaust: a melee attack of 3")
	_pass_until(fight, "round_end_draw")
	_check(_told[-4] == "card_back_to_pile" and _values[-4].player == "Sonja" and fight.phase == Fight.Phase.ROUND_END, "Stachelfaust: a reminder at the end of the round, before the players discard, to shuffle it back into the draw pile")
	_pass_until(fight, "phase_action")
	_ready(fight)
	for i in 6:
		if _asks_card_of(fight, 5):
			break
		fight.pass_action()
	var before := fight.health
	fight.scan(fist)
	_check(before - fight.health == 2, "Stachelfaust: 4 the second time, against the shield of 2")
	fight.abandon()

	# Rindenmaske: her next Protection heals the hero it protects.
	fight = _dryad_starts()
	fight.scan(catalog.find("mAEAAA=="))
	_check(_asks_card_of(fight, 5), "Rindenmaske: another action")
	fight.scan(_card("MASK_GUARD", [["protection", 2], ["lightning", 1]], "dryad"))
	fight.choose(fight.hero_at(1))
	_check(_told[-1] == "heal" and _values[-1].player == "Rosie" and _values[-1].amount == 2 and fight.hero_at(1).threat == 1, "Rindenmaske: the protected hero heals as much as the Protection")
	_ready(fight)
	fight.scan(_card("MASK_GUARD2", [["protection", 2]], "dryad"))
	fight.choose(fight.hero_at(3))
	_check(_told.count("heal") == 1, "Rindenmaske: only for the next card")
	fight.abandon()

	# Moosumhang: the protected hero draws, not the dryad.
	fight = _dryad_starts()
	fight.scan(catalog.find("mwEAAA=="))
	fight.choose(fight.hero_at(3))
	_check(fight.hero_at(3).threat == 0 and _told[-1] == "draw_cards" and _values[-1].player == "Borin" and _told.count("draw_cards") == 1, "Moosumhang: the protected hero draws 1")
	fight.abandon()

	# Uralter Samen: she heals, may give health away, and acts again.
	fight = _dryad_starts()
	fight.scan(catalog.find("nQEAAA=="))
	_check(_told[-1] == "heal" and _values[-1].amount == 3 and _values[-1].player == "Sonja", "Uralter Samen: she heals 3")
	_ready(fight)
	_check(_told[-1] == "transfer_health" and _values[-1].player == "Sonja", "Uralter Samen: then she may give health to another hero")
	_ready(fight)
	_check(_asks_card_of(fight, 5), "Uralter Samen: another action")
	fight.abandon()

	# Phönixbeere: a chosen hero swaps hand cards.
	fight = _dryad_starts()
	fight.scan(catalog.find("nAEAAA=="))
	_check(fight.request != null and fight.request.kind == Fight.Request.Kind.HERO and fight.request.heroes.size() == 3, "Phönixbeere: for a hero of the players' choice")
	fight.choose(fight.hero_at(1))
	_check(_told[-1] == "redraw_hand" and _values[-1].player == "Rosie", "Phönixbeere: they discard and draw up to their hand limit")
	fight.abandon()

	# Säuremottenschwarm: a magic attack, then a random hand card goes.
	fight = _dryad_starts()
	fight.scan(catalog.find("mgEAAA=="))
	_check(fight.health == 26 and _told[-1] == "discard_random" and _values[-1].count == 1 and _values[-1].player == "Sonja", "Säuremottenschwarm: magic attack 5, then she discards 1 random card")
	fight.abandon()


## The paladin's deck, from the catalog, with Rosie as the paladin.
func _check_paladin_cards() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	# Schlachtross: a melee support, and a 4th action next round.
	var fight := _paladin_starts(TestBoss.new())
	fight.scan(catalog.find("sQEAAA=="))
	_check(_told[-1] == "support_without_attack", "Schlachtross: its melee support needs a melee attack first")
	_ready(fight)
	_check(_told[-1] == "extra_turns_next_round" and _values[-1].count == 1 and fight.hero_at(1).bonus_turns == 1, "Schlachtross: 1 more action next round")
	_check(_values[-1].get("source", {}).get("title") == catalog.find("sQEAAA==").title and _values[-1].source.get("hero") == fight.hero_at(1).name, "what a card tells is told as the card's, with its hero")
	fight.abandon()

	# Lichtelixier: a hero of the players' choice heals as much as the round, then another action.
	fight = _paladin_starts(TestBoss.new())
	fight.scan(catalog.find("qQEAAA=="))
	_check(fight.request != null and fight.request.kind == Fight.Request.Kind.HERO and fight.request.prompt == "prompt_chosen_hero", "Lichtelixier: for a hero of the players' choice")
	fight.choose(fight.hero_at(3))
	_ready(fight)
	_check(_told[-1] == "heal" and _values[-1].player == "Borin" and _values[-1].amount == 1 and _asks_card_of(fight, 1), "Lichtelixier: Borin heals 1 in round 1, and Rosie acts again")
	fight.abandon()

	# Aura der Reinigung: each hero removes 1 token, then another action.
	fight = _paladin_starts(TestBoss.new())
	fight.scan(catalog.find("sAEAAA=="))
	_check(_told[-1] == "remove_tokens_everyone" and _values[-1].count == 1 and not _told.has("remove_tokens"), "Aura der Reinigung: 1 token from each hero")
	fight.abandon()

	# Geweihte Rüstung: the protected hero heals, not the paladin.
	fight = _paladin_starts(TestBoss.new())
	fight.scan(catalog.find("rgEAAA=="))
	fight.choose(fight.hero_at(3))
	_check(fight.hero_at(3).threat == 0 and _told[-1] == "heal" and _values[-1].player == "Borin" and _values[-1].amount == 3 and _told.count("heal") == 1, "Geweihte Rüstung: the protected hero heals 3")
	fight.abandon()

	# Hammer des Zorns: a melee attack of 3, then every shield 1 lower without its effect.
	var boss := TestBoss.new()
	fight = _paladin_starts(boss)
	fight.scan(catalog.find("qAEAAA=="))
	_check(fight.health == 29 and fight.shields.values().all(func(n: int) -> bool: return n == 0) and "shield_hit melee" in boss.calls and not "shield_hit magic" in boss.calls and _told[-1] == "shields_lowered", "Hammer des Zorns: 1 through the melee shield, then the magic shield goes down by 1 without its effect")
	fight.abandon()

	# Himmelsschild: an attack lowered to 0 lets the protected hero remove 2 tokens.
	boss = TestBoss.new()
	boss.threats = { 3: 2 }
	fight = _paladin_starts(boss)
	fight.scan(catalog.find("rwEAAA=="))
	fight.choose(fight.hero_at(3))
	_check(fight.hero_at(3).threat == 0 and _told[-1] == "remove_tokens" and _values[-1].player == "Borin" and _values[-1].count == 2, "Himmelsschild: the attack on Borin is 0, he removes 2 tokens")
	fight.abandon()
	fight = _paladin_starts(TestBoss.new())
	fight.scan(catalog.find("rwEAAA=="))
	fight.choose(fight.hero_at(5))
	_check(fight.hero_at(5).threat == 1 and not _told.has("remove_tokens"), "Himmelsschild: not if the attack is still above 0")
	fight.abandon()

	# Segen des Gleichgewichts: the chosen hero's attacks lower the boss's attack against them.
	fight = _paladin_starts(TestBoss.new())
	fight.scan(catalog.find("rQEAAA=="))
	fight.choose(fight.hero_at(3))
	_check(_told[-1] == "threat_lowers_on_attack" and _values[-1].player == "Borin" and _values[-1].amount == 2, "Segen des Gleichgewichts: for Borin this round")
	_ready(fight)
	fight.scan(_card("PAL_HIT", [["attack", 1, "magic"]], "paladin"))
	_ready(fight)
	_check(fight.hero_at(3).threat == 3 and fight.hero_at(1).threat == 3 and _asks_card_of(fight, 3), "Segen des Gleichgewichts: another hero's attack does nothing")
	fight.scan(_card("AXE", [["attack", 1, "melee"]], "dwarf"))
	_check(fight.hero_at(3).threat == 1 and _told[-1] == "threat_lowered" and _values[-1].amount == 2, "Segen des Gleichgewichts: Borin's attack lowers the attack against him by 2")
	fight.abandon()

	# Gleißendes Licht: a ranged support, and a hero of the players' choice draws 1.
	fight = _paladin_starts(TestBoss.new())
	fight.scan(catalog.find("rAEAAA=="))
	_check(fight.request != null and fight.request.kind == Fight.Request.Kind.HERO, "Gleißendes Licht: for a hero of the players' choice")
	fight.choose(fight.hero_at(5))
	_ready(fight)
	_check(_told[-1] == "draw_cards" and _values[-1].player == "Sonja" and _values[-1].count == 1, "Gleißendes Licht: Sonja draws 1")
	fight.abandon()


func _check_shaman_cards() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	var totems := ["nwEAAA==", "ngEAAA==", "oQEAAA==", "oAEAAA=="]
	_check(totems.all(func(qr: String) -> bool: return "totem" in catalog.find(qr).tags), "the four totems are tagged as totems, for the Soul Shaman")

	# Muschel-Talisman: draw as many as the round, then another action.
	var fight := _paladin_starts(TestBoss.new(), "shaman")
	fight.scan(catalog.find("ogEAAA=="))
	_check(_told[-1] == "draw_cards" and _values[-1].player == "Rosie" and _values[-1].count == 1, "Muschel-Talisman: Rosie draws 1 in round 1")
	_ready(fight)
	_check(_asks_card_of(fight, 1), "Muschel-Talisman: and acts again")
	fight.abandon()

	# Rauchholzpulver: Rosie's next card, a Protection, is 3 higher.
	var boss := TestBoss.new()
	boss.threats = { 3: 6 }
	fight = _paladin_starts(boss, "shaman")
	fight.scan(catalog.find("pwEAAA=="))
	_check(fight.buffs(fight.hero_at(1)).size() == 1, "Rauchholzpulver: Rosie's seat shows it")
	_ready(fight)
	fight.scan(_card("GUARD", [["protection", 2]], "shaman"))
	fight.choose(fight.hero_at(3))
	_check(fight.hero_at(3).threat == 1 and fight.buffs(fight.hero_at(1)).is_empty(), "Rauchholzpulver: her Protection 2 lowers the attack on Borin by 5, and it is used up")
	fight.abandon()

	# Vulkan-Totem: for herself, its own attack is 1 higher too, and so are her others this round.
	fight = _paladin_starts(TestBoss.new(), "shaman")
	fight.scan(catalog.find("ngEAAA=="))
	_check(fight.request != null and fight.request.prompt == "prompt_empower_who", "Vulkan-Totem: for a hero of the players' choice")
	fight.choose(fight.hero_at(1))
	var rosie := fight.hero_at(1)
	_check(_told[-1] == "totem_attack" and _values[-1].player == "Rosie" and fight.has_totem(rosie), "Vulkan-Totem: Rosie gets the totem token")
	_check(fight.health == 28, "Vulkan-Totem: its melee attack 3 is 4, 2 of it through the shield")
	_ready(fight)
	fight.scan(_card("AXE", [["attack", 1, "ranged"]], "dwarf"))
	_check(fight.health == 27 and not fight.has_totem(fight.hero_at(3)), "Vulkan-Totem: Borin's attack is not boosted")
	_ready(fight)
	fight.pass_action()
	fight.scan(_card("SLING", [["attack", 1, "ranged"]], "shaman"))
	_check(fight.health == 25, "Vulkan-Totem: Rosie's next attack is")
	_pass_until(fight, "totems_returned")
	_check(_told[-1] == "totems_returned" and _values[-1].players == "Rosie" and not fight.has_totem(rosie) and fight.buffs().is_empty(), "Vulkan-Totem: at the end of the round, Rosie gives the token back")
	fight.abandon()

	# Sonnenwind-Totem: for Borin, so Rosie's own support is not boosted.
	fight = _paladin_starts(TestBoss.new(), "shaman")
	fight.scan(catalog.find("nwEAAA=="))
	fight.choose(fight.hero_at(3))
	_check(_told.has("totem_support") and fight.has_totem(fight.hero_at(3)) and not fight.has_totem(fight.hero_at(1)), "Sonnenwind-Totem: Borin gets the totem token")
	_ready(fight)
	fight.scan(_card("AXE", [["attack", 1, "melee"], ["support", 2, "melee"]], "dwarf"))
	_check(fight.health == 28, "Sonnenwind-Totem: Borin's melee support 2 is 3, 2 through the shield with his attack")
	fight.abandon()

	# Eismond-Totem: for herself, its own Protection 3 is 4.
	boss = TestBoss.new()
	boss.threats = { 3: 6 }
	fight = _paladin_starts(boss, "shaman")
	fight.scan(catalog.find("oAEAAA=="))
	fight.choose(fight.hero_at(1))
	_check(_told[-1] == "totem_protection" and fight.has_totem(fight.hero_at(1)), "Eismond-Totem: Rosie gets the totem token")
	_ready(fight)
	fight.choose(fight.hero_at(3))
	_check(fight.hero_at(3).threat == 2, "Eismond-Totem: its Protection 3 lowers the attack on Borin by 4")
	fight.abandon()

	# Donner-Totem: the protected hero may remove a token for each Lightning they play this round.
	fight = _paladin_starts(TestBoss.new(), "shaman")
	fight.scan(catalog.find("oQEAAA=="))
	fight.choose(fight.hero_at(3))
	_check(_told[-1] == "totem_lightning" and _values[-1].player == "Borin" and fight.has_totem(fight.hero_at(3)) and not fight.has_totem(fight.hero_at(1)), "Donner-Totem: Borin, whom it protected, gets the totem token")
	_ready(fight)
	fight.scan(_card("BOLT", [["attack", 1, "melee"], ["lightning", 2]], "dwarf"))
	_check(_told[-1] == "remove_tokens" and _values[-1].player == "Borin" and _values[-1].count == 2, "Donner-Totem: 2 Lightning, 2 tokens")
	fight.abandon()


## The Goblin Genius's battle robot: built from an attack, a support and a protection, it
## makes the goblin's attacks 2 stronger until its 8 health are gone.
func _check_battle_robot() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	var fight := _goblin_starts(TestBoss.new(), catalog)
	var rosie := fight.hero_at(1)
	var robot := func() -> FightBuff: return fight.buffs(rosie)[0]
	_check(fight.buffs(rosie).size() == 1 and robot.call().text == "0/3" and robot.call().bar_max == 0, "the goblin's seat shows the robot, not built yet")
	fight.scan(_card("ZAP", [["attack", 1, "ranged"], ["lightning", 1]], "goblin"))
	_check(fight.health == 29 and _told[-1] == "robot_part" and _values[-1].count == 1, "an attack flips its first part")
	_check(robot.call().text == "1/3" and robot.call().icons == ["robot", "attack"], "which the seat shows")
	_ready(fight)
	var told_before := _told.size()
	fight.scan(_card("ZAP2", [["attack", 1, "ranged"], ["lightning", 1]], "goblin"))
	_check(_told.size() == told_before and robot.call().text == "1/3", "another attack flips nothing more")
	fight.scan(_card("HELP", [["support", 1, "ranged"], ["lightning", 1]], "goblin"))
	_check(_told[-1] == "robot_part" and _values[-1].count == 2 and fight.health == 27, "a support the second")
	_ready(fight)
	fight.scan(_card("GUARD", [["protection", 1], ["lightning", 1]], "goblin"))
	fight.choose(fight.hero_at(3))
	_check(_told[-1] == "robot_built" and robot.call().text == "+2" and robot.call().bar == 8 and robot.call().bar_max == 8, "a protection the third: the robot works, with 8 health")
	_ready(fight)
	fight.scan(_card("ZAP3", [["attack", 1, "ranged"], ["lightning", 1]], "goblin"))
	_check(fight.health == 24 and robot.call().bar == 7, "the goblin's attacks are 2 stronger, and each card costs the robot 1 health")
	fight.scan(_card("OUCH", [["health_loss", 3], ["lightning", 1]], "goblin"))
	_check(_told[-1] == "health_loss" and robot.call().bar == 4, "when the goblin loses health, the robot loses as much")
	_ready(fight)
	_check(robot.call().bar == 3, "and the card costs it 1 after")
	fight.scan(_card("OUCH2", [["health_loss", 3]], "goblin"))
	_check(_told[-1] == "robot_destroyed" and robot.call().text == "0/3" and robot.call().bar_max == 0, "at 0 the robot is destroyed, to be built again")
	_ready(fight)
	fight.pass_action()
	fight.pass_action()
	fight.scan(_card("ZAP4", [["attack", 1, "ranged"]], "goblin"))
	_check(fight.health == 23 and robot.call().text == "1/3", "without the bonus, and the first part is flipped again")
	fight.abandon()

	# Astraler Robo-Schrauber flips all three parts at once; the boss's attack wears it down.
	fight = _goblin_starts(TestBoss.new(), catalog)
	rosie = fight.hero_at(1)
	fight.scan(catalog.find("jgEAAA=="))
	_check(_told[-1] == "support_without_attack", "Astraler Robo-Schrauber: its support comes first, so without a magic attack before, it does nothing")
	_ready(fight)
	fight.choose(fight.hero_at(3))
	_ready(fight)
	_check(fight.health == 29 and _told.slice(-2) == ["card_removed", "robot_built"], "Astraler Robo-Schrauber: still, its three symbols build the robot at once")
	_pass_until(fight, "round_end_draw")
	_check(fight.buffs(rosie)[0].bar == 5, "the boss's attack of 3 on the goblin costs the robot 3 health")
	fight.abandon()


## The goblin's own cards from the catalog.
func _check_goblin_cards() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	var goblin := catalog._cards_by_qr.values().filter(func(card: Card) -> bool: return card.deck == "goblin")
	_check(goblin.size() == 10 and goblin.all(func(card: Card) -> bool: return card.ability != "todo"), "every goblin card has its ability")

	# Aufziehbare Ratte: a Lightning and back into the pile, then 4 damage, then again.
	var fight := _goblin_starts(TestBoss.new(), catalog, false)
	var rosie := fight.hero_at(1)
	fight.scan(catalog.find("kwEAAA=="))
	_check(fight.health == 30 and _notices[-1] == "notice_lightning" and _told[-1] == "card_wound_up", "Aufziehbare Ratte: first a Lightning, and it goes back into the draw pile")
	_ready(fight)
	_check(_asks_card_of(fight, 1) and not "kwEAAA==" in rosie.played, "Aufziehbare Ratte: so it can come again this round")
	fight.scan(catalog.find("kwEAAA=="))
	_check(fight.health == 26 and _asks_card_of(fight, 3) and "kwEAAA==" in rosie.played, "Aufziehbare Ratte: wound up, the boss loses 4, without a Lightning")
	_pass_until(fight, "round_started")
	_pass_until(fight, "phase_action")
	_ready(fight)
	fight.scan(catalog.find("kwEAAA=="))
	_check(fight.health == 26 and _told[-1] == "card_wound_up", "Aufziehbare Ratte: then it is not wound up again")
	fight.abandon()

	# Klingen-Jo-Jo: back to the hand the first time in a round, not the second.
	fight = _goblin_starts(TestBoss.new(), catalog, false)
	rosie = fight.hero_at(1)
	fight.scan(catalog.find("igEAAA=="))
	_check(fight.health == 29 and _told[-1] == "card_back_to_hand" and not "igEAAA==" in rosie.played, "Klingen-Jo-Jo: melee 3, and back to the hand")
	_ready(fight)
	fight.pass_action()
	fight.pass_action()
	fight.scan(catalog.find("igEAAA=="))
	_check(fight.health == 26 and _told.count("card_back_to_hand") == 1 and "igEAAA==" in rosie.played, "Klingen-Jo-Jo: the second time, it stays")
	fight.abandon()

	# Klauenstutzer: ranged support 5 with the ranged shield broken, else 3.
	fight = _goblin_starts(TestBoss.new(), catalog, false)
	fight.scan(_card("ZAP", [["attack", 1, "ranged"], ["lightning", 1]], "goblin"))
	fight.scan(catalog.find("jwEAAA=="))
	_check(fight.health == 24, "Klauenstutzer: ranged support 5 when the ranged shield is broken")
	fight.abandon()
	var boss := TestBoss.new()
	boss.shields = { "melee": 0, "ranged": 5, "magic": 0 }
	fight = _goblin_starts(boss, catalog, false)
	fight.scan(_card("ZAP", [["attack", 1, "ranged"], ["lightning", 1]], "goblin"))
	fight.scan(catalog.find("jwEAAA=="))
	_check(fight.shields.ranged == 1 and fight.health == 30, "Klauenstutzer: otherwise 3")
	fight.abandon()

	# Raketenrucksack: an item at once, if the ranged shield was already broken.
	fight = _goblin_starts(TestBoss.new(), catalog, false)
	fight.scan(catalog.find("jAEAAA=="))
	_check(fight.health == 27 and _asks_card_of(fight, 1) and fight.request.prompt == "prompt_use_item", "Raketenrucksack: ranged 3, then an item, with the ranged shield broken")
	fight.abandon()
	boss = TestBoss.new()
	boss.shields = { "melee": 0, "ranged": 3, "magic": 0 }
	fight = _goblin_starts(boss, catalog, false)
	fight.scan(catalog.find("jAEAAA=="))
	_check(fight.shields.ranged == 0 and _asks_card_of(fight, 3), "Raketenrucksack: not if its own attack breaks it")
	fight.abandon()

	# Tick-Tick-Bumm: magic 2-7, and the goblin loses 2.
	boss = TestBoss.new()
	boss.shields = { "melee": 0, "ranged": 0, "magic": 0 }
	fight = _goblin_starts(boss, catalog, false)
	fight.scan(catalog.find("jQEAAA=="))
	_check(fight.health >= 23 and fight.health <= 28 and _told[-1] == "health_loss" and _values[-1].amount == 2, "Tick-Tick-Bumm: magic 2-7, then 2 health lost")
	fight.abandon()

	# Helferlein: a hero of the players' choice plays their top card, then another action.
	fight = _goblin_starts(TestBoss.new(), catalog, false)
	fight.scan(catalog.find("kAEAAA=="))
	_check(fight.request != null and fight.request.prompt == "prompt_play_top_who", "Helferlein: for a hero of the players' choice")
	fight.choose(fight.hero_at(3))
	fight.scan(_card("TOP", [["attack", 1, "ranged"]], "dwarf"))
	_check(fight.health == 29 and _asks_card_of(fight, 1), "Helferlein: Borin plays his top card, then Rosie acts again")
	fight.abandon()


## A fight up to the first card of round 1, with Rosie, a goblin, starting. With robot,
## she is a Goblin Genius, with the battle robot.
func _goblin_starts(boss: Boss, catalog: CardDatabase, robot := true) -> Fight:
	var fight := _fight(boss)
	fight.hero_at(1).hero.race = "goblin"
	if robot:
		_give_trait(fight, catalog, "hwEAAA==", fight.hero_at(1))
	fight.start()
	_ready(fight)
	_ready(fight)
	_ready(fight)
	fight.choose(fight.hero_at(1))
	_ready(fight)
	_ready(fight)
	return fight


## What lasts a while shows on screen (Fight.buffs), and the fight says when that changes.
func _check_buffs() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	var fight := _started(TestBoss.new())
	var changes := [0]
	fight.buffs_changed.connect(func() -> void: changes[0] += 1)
	fight.scan(catalog.find("0AEAAA=="))
	var global := fight.buffs(null, true)
	_check(global.size() == 1 and global[0].hero == null and global[0].count == 8 and global[0].text == "+1" and changes[0] == 1, "Muttis Nachtisch shows for everyone, with 8 cards to go")
	_ready(fight)
	_ready(fight)
	fight.scan(_card("ARROW", [["attack", 1, "ranged"]], "dwarf"))
	_check(fight.buffs(null, true)[0].count == 7 and changes[0] == 2, "and counts down")
	_check(fight.buffs(fight.hero_at(1)).is_empty(), "a hero's own buffs leave it out")
	fight.abandon()


## A fight up to the first card of round 1, with Rosie, as a paladin or hero_class, starting.
func _paladin_starts(boss: Boss, hero_class := "paladin") -> Fight:
	var fight := _fight(boss, "normal", false, hero_class)
	fight.start()
	_ready(fight)
	_ready(fight)
	_ready(fight)
	fight.choose(fight.hero_at(1))
	_ready(fight)
	_ready(fight)
	return fight


## A fight up to the first card of round 1, with Sonja, the dryad, starting.
func _dryad_starts() -> Fight:
	var fight := _fight(TestBoss.new())
	fight.start()
	_ready(fight)
	_ready(fight)
	_ready(fight)
	fight.choose(fight.hero_at(5))
	_ready(fight)
	_ready(fight)
	return fight


## The boss's poison: kept for the whole fight, and it hurts the boss at the end of each round.
func _check_boss_poison() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	var fight := _started(TestBoss.new())
	var changes: Array[int] = []
	fight.poison_changed.connect(func(poison: int) -> void: changes.append(poison))
	_pass_until(fight, "round_end_draw")
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
	_pass_until(fight, "round_end_draw")
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


## Cards whose text sets the strength of their effects, such as Krawumm's attack as strong as
## the round, keep what other rules add: the strength is set first, then the bonuses come.
func _check_set_strength() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	var bonuses := {
		"a +2 Totem": func(fight: Fight) -> FightRule:
			var boost: FightRule = EMPOWER.Boost.new()
			boost.hero = fight.hero_at(1)
			boost.type = "attack"
			boost.bonus = 2
			return boost,
		"Muttis Nachtisch +2": func(_fight: Fight) -> FightRule:
			var boost: FightRule = BOOST_NEXT_CARDS.Boost.new()
			boost.left = 8
			boost.bonus = 2
			return boost,
		"a next-card boost +2": func(_fight: Fight) -> FightRule:
			var next: FightRule = NEXT_CARD.NextCard.new()
			next.symbol = "attack"
			next.damage_type = "any"
			next.then = "boost"
			next.bonus = 2
			return next,
		"the thorn form +1": func(fight: Fight) -> FightRule:
			var perk: FightRule = DRYAD_FORM.Perk.new()
			perk.hero = fight.hero_at(1)
			perk.form = "thorn"
			return perk,
		"the battle robot +2": func(fight: Fight) -> FightRule:
			var robot := CardAbility.create(catalog.find("hwEAAA=="))
			robot.owner = fight.hero_at(1)
			robot.set("health", 8)
			return robot,
	}
	var bonus_of := { "a +2 Totem": 2, "Muttis Nachtisch +2": 2, "a next-card boost +2": 2, "the thorn form +1": 1, "the battle robot +2": 2 }
	# Each card is a ranged attack, against no ranged shield, by Rosie, whom the boss attacks with 3.
	var cards := {
		"attack_by_round": [{}, 1],
		"random_strength": [{ "min": 2, "max": 2 }, 2],
		"attack_by_threat": [{}, 3],
	}
	for ability: String in cards:
		for bonus: String in bonuses:
			var fight := _started(TestBoss.new())
			fight.add_rule(bonuses[bonus].call(fight))
			var card := _card("SET", [["attack", 0, "ranged"]], "halfling")
			card.ability = ability
			card.ability_values = cards[ability][0]
			fight.scan(card)
			var expected: int = cards[ability][1] + bonus_of[bonus]
			_check(30 - fight.health == expected, "%s with %s: %d damage (%d)" % [ability, bonus, expected, 30 - fight.health])
			fight.abandon()

	# The cards themselves: Vulkan-Totem, then Krawumm, as strong as the round, +1.
	var fight := _paladin_starts(TestBoss.new(), "shaman")
	var rosie := fight.hero_at(1)
	rosie.hero.race = "troll"
	fight.scan(catalog.find("ngEAAA=="))
	fight.choose(rosie)
	_ready(fight)
	_check(fight.health == 28 and fight.has_totem(rosie), "Vulkan-Totem: Rosie's melee attack 3 is 4, 2 through the shield")
	fight.pass_action()
	fight.pass_action()
	fight.scan(catalog.find("EwAAAA=="))
	_check(fight.health == 26, "Krawumm with the Vulkan-Totem: 1 in round 1, +1")
	fight.abandon()

	# Magische Haut, a Protection as strong as the round, with a +2 Protection Totem.
	fight = _started(TestBoss.new())
	var totem := _card("ICE", [["lightning", 1]], "halfling")
	totem.ability = "empower"
	totem.ability_values = { "type": "protection", "bonus": 2 }
	fight.scan(totem)
	fight.choose(fight.hero_at(1))
	_ready(fight)
	fight.scan(catalog.find("FQEAAA=="))
	fight.choose(fight.hero_at(3))
	_check(fight.hero_at(3).threat == 0, "Magische Haut with a +2 Protection Totem: 1 in round 1, +2, blocks 3")
	fight.abandon()

	# Klauenstutzer, Support 3 while the ranged shield stands, after the Elven Keeper's own ranged attack: +2.
	var boss := TestBoss.new()
	boss.shields = { "melee": 0, "ranged": 10, "magic": 0 }
	fight = _goblin_starts(boss, catalog, false)
	_give_trait(fight, catalog, "/QAAAA==", fight.hero_at(1))
	fight.scan(_card("BOW", [["attack", 1, "ranged"], ["lightning", 1]], "goblin"))
	fight.scan(catalog.find("jwEAAA=="))
	_check(fight.shields.ranged == 4, "Klauenstutzer with the Elven Keeper: Support 3 +2 into the ranged shield")
	fight.abandon()


## Replays (CardPlay.replay): a card taking effect once more is not played again.
func _check_replays() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	# The battle robot: a replay neither wears it, nor is it without the bonus.
	var boss := TestBoss.new()
	boss.shields = { "melee": 0, "ranged": 0, "magic": 0 }
	var fight := _goblin_starts(boss, catalog)
	var robot: CardAbility = fight.rules.filter(func(rule: FightRule) -> bool: return rule is CardAbility and rule.id == "battle_robot")[0]
	robot.set("health", 8)
	fight.scan(_card("ZAP", [["attack", 1, "ranged"], ["lightning", 1]], "goblin"))
	_check(fight.health == 27 and robot.get("health") == 7, "the robot's attack 1 +2, and it wears by 1")
	fight.scan(catalog.find("HgEAAA=="))
	_ready(fight)
	_check(fight.health == 24 and robot.get("health") == 6, "Amulett der Zeit repeats it, +2 again: the Amulett wears the robot, the replay does not")
	fight.abandon()

	# Muttis Nachtisch neither counts nor boosts a replay, such as from Stachelbola.
	fight = _started(TestBoss.new())
	var dessert := _card("DESSERT", [["lightning", 1]], "halfling")
	dessert.ability = "boost_next_cards"
	dessert.ability_values = { "cards": 8, "bonus": 1 }
	fight.scan(dessert)
	_ready(fight)
	fight.scan(catalog.find("OQEAAA=="))
	fight.scan(_card("BOW", [["attack", 1, "ranged"]], "halfling"))
	_ready(fight)
	_check(fight.health == 27 and fight.buffs(null, true)[0].count == 6, "Muttis Nachtisch: Stachelbola and the attack count, 2 damage, the replay 1 more and not counted")
	fight.abandon()

	# Stachelfaust repeated by Amulett der Zeit: the replay is not a second play, so no bonus.
	fight = _dryad_starts()
	fight.scan(catalog.find("mQEAAA=="))
	_check(fight.health == 29 and fight.shields.melee == 0, "Stachelfaust: melee 3, 2 into the shield")
	fight.scan(catalog.find("HgEAAA=="))
	_ready(fight)
	_check(fight.health == 26, "Amulett der Zeit repeats it at 3, not 4")
	fight.abandon()

	# Amulett der Zeit repeating Donnerspeer, which is then out of the game: the replay hits too.
	fight = _started(TestBoss.new())
	fight.scan(catalog.find("MgEAAA=="))
	_pass_until_asked(fight)
	_check(fight.health == 22 and "MgEAAA==" in fight.removed, "Donnerspeer: ranged 8, then out of the game")
	fight.scan(catalog.find("HgEAAA=="))
	_pass_until_asked(fight)
	_check(fight.health == 14 and fight.removed.count("MgEAAA==") == 1, "Amulett der Zeit repeats it, 8 again, still out of the game once")
	fight.abandon()

	# A card with a use limit, repeated: it is not used again.
	fight = _started(TestBoss.new())
	var flask := _card("FLASK", [["attack", 1, "ranged"], ["lightning", 1]], "halfling")
	flask.uses_per_fight = 2
	fight.scan(flask)
	fight.scan(catalog.find("HgEAAA=="))
	_ready(fight)
	_check(fight.health == 28 and fight.hero_at(1).uses.get("FLASK", 0) == 1, "Amulett der Zeit: a card with a limit, repeated, is used once")
	fight.abandon()

	# Aufziehbare Ratte, wound up and repeated: the replay takes effect as the play it repeats.
	fight = _goblin_starts(TestBoss.new(), catalog, false)
	var rat := catalog.find("kwEAAA==")
	fight.scan(rat)
	_ready(fight)
	var again := _card("AGAIN", [["lightning", 1]], "goblin")
	again.ability = "next_card"
	again.ability_values = { "symbol": "direct_damage", "then": "repeat" }
	fight.scan(again)
	fight.scan(rat)
	_pass_until_asked(fight)
	_check(fight.health == 22 and _asks_card_of(fight, 3), "Aufziehbare Ratte: wound up, 4, and again 4, without a Lightning")
	_check(not "kwEAAA==" in fight.hero_at(1).notes.get("wound_up", []), "and it is not wound up after, as after one play")
	fight.abandon()


## What happens when a shield breaks, with several rules that see it.
func _check_shield_breaks() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	# Kristallorb by the Halfling Luckmaster: both see the magic shield break.
	var fight := _started(TestBoss.new())
	_give_trait(fight, catalog, "AAEAAA==", fight.hero_at(1))
	fight.scan(catalog.find("zgEAAA=="))
	_pass_until_asked(fight)
	_check(fight.health == 21 and _told.count("shield_breaker") == 2, "Kristallorb and the Luckmaster: 2 through the shield, 3 and 4 more")
	fight.abandon()

	# Explosivkristall lowers a shield without damage, but it still breaks: the Luckmaster sees it.
	fight = _started(TestBoss.new())
	_give_trait(fight, catalog, "AAEAAA==", fight.hero_at(1))
	fight.scan(catalog.find("OgEAAA=="))
	fight.choose_shield("melee")
	_pass_until_asked(fight)
	_check(fight.shields.melee == 0 and fight.health == 26 and _told.count("shield_breaker") == 1, "Explosivkristall and the Luckmaster: the melee shield breaks, 4 to the boss")
	fight.abandon()

	# Hammer des Zorns by a paladin Luckmaster: its attack breaks the melee shield, the lowering the magic one.
	fight = _paladin_starts(TestBoss.new())
	_give_trait(fight, catalog, "AAEAAA==", fight.hero_at(1))
	fight.scan(catalog.find("qAEAAA=="))
	_pass_until_asked(fight)
	_check(fight.health == 21 and _told.count("shield_breaker") == 2, "Hammer des Zorns and the Luckmaster: 1 through, 4 for each broken shield")
	fight.abandon()

	# A shield already broken does not break again.
	fight = _started(TestBoss.new())
	_give_trait(fight, catalog, "AAEAAA==", fight.hero_at(1))
	fight.scan(_card("ZAP", [["attack", 1, "magic"], ["lightning", 1]], "halfling"))
	_pass_until_asked(fight)
	fight.scan(_card("ZAP2", [["attack", 1, "magic"]], "halfling"))
	_check(fight.health == 25 and _told.count("shield_breaker") == 1, "the Luckmaster: a broken shield only counts once")
	fight.abandon()


## An attack that Ritterlicher Beistand takes on, with what looks at attacks on heroes.
func _check_redirects() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	var aid := catalog.find("PQAAAA==")
	# Krone des Prinzen sees the attack Borin took on.
	var boss := TestBoss.new()
	boss.threats = { 1: 3, 3: 2, 5: 3 }
	var fight := _started(boss)
	fight.scan(catalog.find("yAEAAA=="))
	_ready(fight)
	fight.choose(fight.hero_at(3))
	_ready(fight)
	fight.pass_action()
	fight.scan(aid)
	fight.choose(fight.hero_at(5))
	_check(fight.hero_at(3).threat == 3 and fight.hero_at(5).threat == 0, "Ritterlicher Beistand: Borin takes on Sonja's 3")
	_pass_until(fight, "round_end_draw")
	_check(fight.poison == 0, "Krone des Prinzen: 3 on Borin is below 4, no poison")
	fight.abandon()

	boss = TestBoss.new()
	boss.threats = { 1: 3, 3: 2, 5: 5 }
	fight = _started(boss)
	fight.scan(catalog.find("yAEAAA=="))
	_ready(fight)
	fight.choose(fight.hero_at(3))
	_ready(fight)
	fight.pass_action()
	fight.scan(aid)
	fight.choose(fight.hero_at(5))
	_pass_until(fight, "round_end_draw")
	_check(fight.poison == 1, "Krone des Prinzen: Sonja's 5, taken on by Borin, poisons the boss")
	fight.abandon()

	# Rune der Rache after Ritterlicher Beistand: as strong as the attack taken on.
	boss = TestBoss.new()
	boss.threats = { 1: 3, 3: 2, 5: 9 }
	fight = _started(boss)
	fight.pass_action()
	_ready(fight)
	fight.scan(aid)
	fight.choose(fight.hero_at(5))
	_pass_until_asked(fight)
	fight.pass_action()
	fight.pass_action()
	fight.scan(catalog.find("WgEAAA=="))
	_pass_until_asked(fight)
	_check(fight.health == 21 and _told.has("health_loss"), "Rune der Rache: 9, Sonja's attack on Borin, and he loses 4")
	fight.abandon()

	# The goblin taking on an attack: the robot loses what hits her.
	boss = TestBoss.new()
	boss.threats = { 1: 1, 3: 4, 5: 3 }
	fight = _fight(boss)
	fight.hero_at(1).hero.race = "goblin"
	fight.hero_at(1).hero.hero_class = "warrior"
	_give_trait(fight, catalog, "hwEAAA==", fight.hero_at(1))
	fight.start()
	for i in 3:
		_ready(fight)
	fight.choose(fight.hero_at(1))
	_ready(fight)
	_ready(fight)
	var robot: CardAbility = fight.rules.filter(func(rule: FightRule) -> bool: return rule is CardAbility and rule.id == "battle_robot")[0]
	robot.set("health", 8)
	fight.scan(aid)
	fight.choose(fight.hero_at(3))
	_check(robot.get("health") == 7, "the goblin takes on Borin's 4, the card wears the robot by 1")
	_pass_until(fight, "round_end_draw")
	_check(robot.get("health") == 3, "the boss's 4 on her costs the robot 4")
	fight.abandon()


## Cards played inside cards: the actions come back to who they belong to.
func _check_nested_plays() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	# Güldis Angel for Borin, who plays Wunderlampe among the drawn cards: Sonja plays her top 3.
	var boss := TestBoss.new()
	boss.shields = { "melee": 0, "ranged": 0, "magic": 0 }
	var fight := _started(boss)
	var borin := fight.hero_at(3)
	var sonja := fight.hero_at(5)
	fight.scan(catalog.find("1wEAAA=="))
	fight.choose(borin)
	_ready(fight)
	fight.scan(catalog.find("GwEAAA=="))
	_check(fight.request.prompt == "prompt_play_top_who", "Güldis Angel, then Wunderlampe: who plays their top cards?")
	fight.choose(sonja)
	_ready(fight)
	for i in 3:
		_check(_asks_card_of(fight, 5) and fight.request.prompt == "prompt_lucky_charm", "Sonja shows top card %d" % (i + 1))
		fight.scan(_card("TOP%d" % i, [["attack", 1, "melee"], ["lightning", 1]], "dryad"))
		_pass_until_asked(fight)
	_check(fight.health == 27, "each of them hits, their Lightning for later")
	_check(_asks_card_of(fight, 5) and fight.request.prompt == "prompt_free_play", "the Lightning on them: an action for Sonja")
	fight.skip()
	_pass_until_asked(fight)
	_check(_asks_card_of(fight, 3) and fight.request.prompt == "prompt_play_drawn", "then Borin's second drawn card")
	fight.scan(_card("DRAWN", [["attack", 1, "melee"]], "dwarf"))
	_pass_until_asked(fight)
	_check(fight.health == 26 and _asks_card_of(fight, 3) and fight.request.prompt != "prompt_play_drawn", "then Borin's own turn")
	_check(_actions(fight.hero_at(1)) == "TT" and _actions(borin) == "TTT" and _actions(sonja) == "TTT", "the turns are where they were")
	fight.abandon()

	# Banner des Mutes inside Banner des Mutes: Rosie's lets Borin play his, which lets Sonja play.
	fight = _started(TestBoss.new())
	borin = fight.hero_at(3)
	sonja = fight.hero_at(5)
	var banner := catalog.find("CQEAAA==")
	fight.scan(banner)
	fight.choose(fight.hero_at(3))
	fight.scan(banner)
	_check(fight.request.prompt == "prompt_free_play_who" and not fight.hero_at(3) in fight.request.heroes, "Banner des Mutes in Banner des Mutes: Borin chooses another hero")
	fight.choose(sonja)
	_check(_asks_card_of(fight, 5) and fight.request.prompt == "prompt_free_play", "Sonja acts at once")
	fight.scan(_card("SUP", [["protection", 1]], "dryad"))
	fight.choose(sonja)
	_pass_until_asked(fight)
	_check(_asks_card_of(fight, 3) and fight.request.prompt == "prompt_free_play", "then the Lightning on Borin's Banner: another free card for him")
	fight.skip()
	_pass_until_asked(fight)
	_check(_asks_card_of(fight, 1), "then Rosie's Lightning")
	_check(_actions(fight.hero_at(1)) == "BTT" and _actions(borin) == "TTT" and _actions(sonja) == "TTT", "and nobody else's turns are used up")
	fight.abandon()


## The boss defeated in the middle of something: nothing more is asked or told.
func _check_ends_mid_chain() -> void:
	var catalog := CardDatabase.load_file("res://cards/cards.json")
	var finished := func(fight: Fight) -> bool:
		_pass_until_asked(fight)
		return fight.over and fight.request == null and _told.count("victory") == 1 and _told[-1] == "victory"
	# By the first hit of Stachelbola's repeat.
	var fight := _started(TestBoss.new())
	fight.set_health(5)
	fight.scan(catalog.find("OQEAAA=="))
	fight.scan(catalog.find("JwEAAA=="))
	_check(finished.call(fight) and fight.health == 0, "Stachelbola: the boss falls to the repeat, then nothing more")
	# By Amulett der Zeit's repeat.
	fight = _started(TestBoss.new())
	fight.set_health(6)
	fight.scan(_card("BOW", [["attack", 4, "ranged"], ["lightning", 1]], "halfling"))
	fight.scan(catalog.find("HgEAAA=="))
	_check(finished.call(fight), "Amulett der Zeit: the boss falls to the repeat, then nothing more")
	# By Bombling, at the start of the next round.
	fight = _started(TestBoss.new())
	fight.set_health(5)
	fight.scan(catalog.find("1gEAAA=="))
	_pass_until(fight, "round_end_draw")
	for i in 4:
		_ready(fight)
	fight.choose(fight.hero_at(1))
	_check(finished.call(fight), "Bombling: the boss falls at the start of the next round, then no turn")
	# By the first card Güldis Angel lets Borin play: no second one.
	var boss := TestBoss.new()
	boss.shields = { "melee": 0, "ranged": 0, "magic": 0 }
	fight = _started(boss)
	fight.set_health(2)
	fight.scan(catalog.find("1wEAAA=="))
	fight.choose(fight.hero_at(3))
	_ready(fight)
	fight.scan(_card("DRAWN", [["attack", 2, "melee"], ["lightning", 1]], "dwarf"))
	_check(finished.call(fight), "Güldis Angel: the boss falls to the first drawn card, no second one is asked for")
	# By the Luckmaster's shield break, in the middle of Kristallorb.
	fight = _started(TestBoss.new())
	_give_trait(fight, catalog, "AAEAAA==", fight.hero_at(1))
	fight.set_health(5)
	fight.scan(catalog.find("zgEAAA=="))
	_check(finished.call(fight) and _told.count("shield_breaker") <= 2, "Kristallorb and the Luckmaster: the boss falls, then nothing more")


## Reads every message until the fight asks for something or is over.
func _pass_until_asked(fight: Fight) -> void:
	for i in 50:
		if fight.over or fight.request != null:
			return
		_ready(fight)


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
	var armoured := Fight.new(ArmouredBoss.new(), "normal")
	armoured.deal_damage(9, "melee")
	_check(armoured.health == armoured.max_health - 4, "a boss's armour halves melee")
	armoured.deal_damage(9, "magic")
	_check(armoured.health == armoured.max_health - 13, "but not magic")
	var armour_told: Array = []
	var armour_source := []
	armoured.message.connect(func(id: String, values: Dictionary) -> void:
		armour_told.append([id, values.get("damage")])
		armour_source.append(values.get("source", {})))
	armoured.deal_damage(5, "ranged")
	_check(armoured.health == armoured.max_health - 15 and armour_told == [["armour", 2]], "the players are told how much the armour let through")
	_check(armour_source == [{ "title": armoured.boss.title }], "as the boss's")
	armoured.deal_damage(4, Fight.DIRECT)
	_check(armoured.health == armoured.max_health - 19 and armour_told.size() == 1, "direct damage is no attack: the armour does not halve it")

	var easy := Bosses.create("mirefang").attack_range("easy")
	var hard := Bosses.create("mirefang").attack_range("hard")
	_check(hard.x == easy.x + 2 and hard.y == easy.y + 2, "the difficulty changes the boss's attacks")
	_check_mirefang()


## Mirefang: poisonous attacks and shield, venom spit, its dives and its rage.
func _check_mirefang() -> void:
	var boss := Bosses.create("mirefang")
	var away_changes: Array[bool] = []
	var fight := _fight(boss)
	fight.boss_away_changed.connect(func(away: bool) -> void: away_changes.append(away))
	fight.start()
	_ready(fight)
	_ready(fight)
	_check(fight.max_health == 80, "Mirefang has 80 health on normal")
	_check(fight.heroes.all(func(hero: FightHero) -> bool:
		var poison: int = hero.threat_effects.get("poison", 0)
		return hero.threat >= 2 and hero.threat <= 5 and poison >= 1 and poison <= 3), "each of its attacks poisons, with 1 to 3")
	var kinds := Fight.DAMAGE_TYPES.filter(func(kind: String) -> bool: return kind != boss.poison_shield)
	_check(fight.shields.values() == [3, 3, 3] and kinds.size() == 2, "it raises three shields of 3, one of them poisonous")
	_check(boss.shield_icon(boss.poison_shield) == Boss.SHIELD_POISON and boss.shield_icon(kinds[0]) == Boss.SHIELD_NORMAL, "which shows on the shield")
	fight.choose(fight.hero_at(1))
	_ready(fight)

	fight.scan(_card("M1", [["attack", 2, boss.poison_shield]], "items"))
	_check(_told[-1] == "mirefang_poison_shield" and _values[-1].player == "Rosie" and _values[-1].poison == 1, "whoever hits its poison shield is poisoned")
	_ready(fight)
	fight.scan(_card("M2", [["attack", 9, kinds[0]]], "items"))
	_check(fight.health == 74 and not _told.has("mirefang_spit"), "a card that costs it 6 health is not enough to make it spit")
	_ready(fight)
	fight.scan(_card("M3", [["attack", 10, kinds[1]]], "items"))
	_check(fight.health == 67 and _told[-1] == "mirefang_spit" and _values[-1].poison == 1, "one that costs it 7 makes it spit venom on every hero")
	_ready(fight)
	fight.scan(_card("M4", [["direct_damage", 7]], "items"))
	_check(fight.health == 60 and _told.count("mirefang_spit") == 1, "once a round")
	_check(not fight.boss_away and not _told.has("mirefang_dive"), "at exactly 75 % of its health, it stays")

	_ready(fight)
	fight.scan(_card("M5", [["direct_damage", 1]], "items"))
	var bitten := fight.heroes_where(func(hero: FightHero) -> bool: return hero.threat > 0)
	_check(fight.boss_away and away_changes == [true] and _told[-1] == "mirefang_dive", "below it, it dives")
	_check(fight.shields.values() == [0, 0, 0], "its shields are gone")
	_check(bitten.size() == 1 and bitten[0].threat == 15 and bitten[0].threat_effects == { "poison": 3 }, "and so are its attacks, but for its bite against one hero")
	_check(_values[-1].player == bitten[0].name and _values[-1].damage == 15, "whom the players are told of")
	_check(_actions(fight.hero_at(1)) == "TB" and _actions(fight.hero_at(5)) == "TTB", "every hero gets an action more")
	_ready(fight)
	var health := fight.health
	fight.scan(_card("M6", [["attack", 5, "melee"], ["poison", 2], ["heal", 3]], "items"))
	_check(fight.health == health and fight.poison == 0, "under water, attacks and poison do not reach it")
	_ready(fight)
	_check(_told.count("mirefang_out_of_reach") == 1 and _told[-1] == "heal", "told once for the card, whose other symbols still work")
	_ready(fight)
	while fight.phase == Fight.Phase.ACTION and fight.request != null and fight.request.kind == Fight.Request.Kind.ACTION:
		fight.pass_action()
	_check(_told.has("mirefang_surfaces") and not fight.boss_away and away_changes == [true, false], "after the action phase, it surfaces")
	_ready(fight)
	var hits: Array = _values[_told.find("boss_attacks")].hits
	_check(hits.size() == 1 and hits[0][1].player == bitten[0].name and hits[0][1].damage == 15, "and bites the hero it chose")
	_check(not boss.enraged, "above half its health, it is not enraged")
	# The rest of round 1, then round 2 up to the first card.
	for i in 6:
		_ready(fight)
	fight.choose(fight.hero_at(1))
	_ready(fight)
	_check(_asks_card_of(fight, 1) and fight.shields.values() == [3, 3, 3], "the next round, it is back with its shields")

	var looks := [0]
	boss.look_changed.connect(func() -> void: looks[0] += 1)
	fight.scan(_card("M7", [["direct_damage", 41]], "items"))
	_check(_told[-1] == "mirefang_spit" and _told.count("mirefang_spit") == 2, "the spit comes first, once in each round")
	_ready(fight)
	_check(fight.health == 18 and _told.count("mirefang_dive") == 2 and _told[-1] == "mirefang_dive", "a hit past two marks makes it dive once")
	_ready(fight)
	while fight.phase == Fight.Phase.ACTION and fight.request != null and fight.request.kind == Fight.Request.Kind.ACTION:
		fight.pass_action()
	_ready(fight)
	_check(boss.enraged and _told[-1] == "mirefang_enraged" and looks[0] == 1, "surfacing below half its health, it is enraged, and looks it")
	for i in 6:
		_ready(fight)
	_check(fight.round_number == 3 and fight.shields.values() == [4, 4, 4], "enraged, its shields are stronger")
	_check(fight.heroes.all(func(hero: FightHero) -> bool: return hero.threat >= 3 and hero.threat <= 6), "and its attacks too")
	fight.choose(fight.hero_at(1))
	_ready(fight)
	fight.scan(_card("M8", [["direct_damage", 1]], "items"))
	_check(not fight.boss_away and _told.count("mirefang_dive") == 2, "the mark it skipped is gone")
	fight.abandon()

	boss = Bosses.create("mirefang")
	fight = _fight(boss, "hard")
	fight.start()
	_ready(fight)
	_ready(fight)
	fight.deal_damage(30, Fight.POISON)
	_check(not fight.boss_away, "passing a mark outside the action phase, as by its poison, it waits")
	fight.choose(fight.hero_at(1))
	_check(fight.boss_away and _told[-1] == "mirefang_dive" and _values[-1].damage == 18 and _values[-1].poison == 3, "and dives as the action phase starts, biting harder on hard")
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
## With rosie_class, Rosie has another class, such as paladin.
func _fight(boss: Boss, difficulty := "normal", levels := false, rosie_class := "thief") -> Fight:
	var heroes: Array[Party.Hero] = []
	for entry: Array in [["Sonja", "dryad", "druid", 5, "iAEAAA==", "KwEAAA=="], ["Rosie", "halfling", rosie_class, 1, "AAEAAA==", "KgEAAA=="],
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
