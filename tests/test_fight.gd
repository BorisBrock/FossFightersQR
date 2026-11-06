extends SceneTree
## The rules of a fight, without a screen: the rounds and phases, what cards do, and how
## bosses and abilities step in. The fight waits for the players, and the test plays them.
## Run with: godot --headless -s tests/test_fight.gd

const EXPECTED_CHECKS := 82

var _failures := 0
var _checks_run := 0
## What the fight told the players, in order, by message id.
var _told: Array[String] = []
var _values: Array[Dictionary] = []
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


func _initialize() -> void:
	_check_round()
	_check_cards()
	_check_abilities()
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
	_check(fight.starter == fight.hero_at(3) and _told[-1] == "phase_shield" and fight.shields == { "melee": 2, "ranged": 0, "magic": 1 }, "and raises its shields")
	_ready(fight)
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
	_check(_told[-1] == "phase_status_none", "nobody is poisoned this time")
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
	_check(_told[-1] == "boss_hits_with_tokens" and fight.hero_at(5).token_count("poison") == 1, "a poisonous attack gives poison")
	_ready(fight)
	_check(_told[-1] == "status_poison" and _values[-1].count == 1, "which hurts in the status phase")

	# What the game over screen shows of these two rounds.
	var stats := fight.stats
	var borin := stats.of(fight.hero_at(3))
	_check(borin.damage == 5 and borin.shield_damage == 2 and borin.cards == 2, "the stats count each hero's damage, to the boss and to its shields")
	_check(borin.power == { "melee": 7, "ranged": 0, "magic": 0 }, "and the power of their attacks and supports by type, only supports that count")
	_check(stats.of(fight.hero_at(1)).protection == 5, "and how much their protection lowered attacks")
	_check(stats.of(fight.hero_at(1)).damage_taken == 8 and stats.of(fight.hero_at(5)).damage_taken == 6, "and the damage they took, poison included")
	_check(stats.attacks == 6 and stats.attacks_blocked == 1 and stats.of(fight.hero_at(5)).attacks_blocked == 1, "and the boss's attacks, and those blocked")
	_check(stats.rounds == 2 and stats.health_by_round == [30, 25] and stats.damage_by_round == [5, 0], "and the boss's health and the damage, round by round")
	_check(stats.team_damage() == 5 and stats.boss_damage() == 18 and stats.outcome == FightStats.Outcome.NONE, "and the totals, while the fight goes on")
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
	rosie.add_tokens("panic", 2)
	fight.pass_action()
	_check(fight.request.prompt == "prompt_action_panic", "a panicking hero is told to pick at random")
	fight.scan(_card("CALM", [["lightning", 1]], "halfling"))
	_check(rosie.token_count("panic") == 1 and _notices[-1] == "notice_panic_token", "and loses a panic token with each card")
	_check(fight.scan(backpack) == "" and rosie.token_count("panic") == 1, "an item can be used again in the same round, and is no random card")
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

	# The medical bag removes tokens of the players' choice.
	var bag := _card("BAG", [], "items")
	bag.ability = "remove_tokens"
	_check(fight.scan(bag) == "notice_no_tokens", "an ability can refuse a card")
	fight.hero_at(1).add_tokens("poison", 1)
	fight.hero_at(1).add_tokens("fire", 2)
	fight.scan(bag)
	_check(fight.request.kind == Fight.Request.Kind.OPTION and fight.request.options == ["option_token_poison", "option_token_fire"], "the medical bag asks which token")
	fight.choose_option(1)
	fight.choose_option(0)
	_check(fight.hero_at(1).tokens == { "fire": 1 }, "and removes them")
	fight.abandon()


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


## A fight against boss with Rosie, Borin and Sonja, its messages noted.
func _fight(boss: Boss, difficulty := "normal") -> Fight:
	var heroes: Array[Party.Hero] = []
	for entry: Array in [["Sonja", "dryad", "druid", 5], ["Rosie", "halfling", "thief", 1], ["Borin", "dwarf", "warrior", 3]]:
		var hero := Party.Hero.new()
		hero.name = entry[0]
		hero.race = entry[1]
		hero.hero_class = entry[2]
		hero.seat = entry[3]
		heroes.append(hero)
	var fight := Fight.new(boss, difficulty, heroes)
	fight.rng.seed = 7
	_told.clear()
	_values.clear()
	_notices.clear()
	fight.message.connect(func(id: String, values: Dictionary) -> void:
		_told.append(id)
		_values.append(values))
	fight.notice.connect(func(id: String, _values: Dictionary) -> void: _notices.append(id))
	return fight


## A fight up to the first card of round 1, with Rosie starting. Without to_cards, up to
## the boss planning its attacks.
func _started(boss: Boss, difficulty := "normal", to_cards := true) -> Fight:
	var fight := _fight(boss, difficulty)
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
