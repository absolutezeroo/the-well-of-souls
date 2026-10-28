class_name BalanceLab
extends Node
## The tools' workbench on the real engine: starts a run of the real Game scene at a depth
## (headless, the run save in memory), puts a build on the hero and measures what happens.
## Shared by the arena (boss fights, packs), the marginal values, the compound checks and the
## economy. Everything is seeded (`seed_value`): the same command gives the same numbers.
## Hit stop is off (it freezes real time, not game time: the fight is the same, only faster to
## simulate); times are game seconds at 60 physics frames a second.
##
## Measures:
## - dummy(): the hero hits a boss that doesn't fight back (its AI off), face-tank, the hero
##   untouchable: damage per second, time to kill (the boss' HP can be scaled down to save time:
##   phases and execute thresholds are shares of HP, so they still happen). When the boss is
##   half dead the hero drops to 45% health (low-health bonuses: half the fight).
## - pack(): a room of monsters around the hero, a bot at the controls: clear time, time to
##   kill each, damage taken, healing by source, death.

const GAME_SCENE := "res://src/game/game.tscn"
## Physics frames a second (--fixed-fps 60).
const FPS := 60.0
## Frames waited between two measures (timers of the last one go off first).
const SETTLE_FRAMES := 90

## Fresh measures rebuild the session's floor in the running game (restart(), renew()) instead
## of starting a new game each time. Off: a new game every time (the old way, to compare).
static var renew_floors := true

var content: ContentDB
var seed_value := 1
## Dungeon and rank chances changed for the measures (restored by restore_chances()).
var _saved_chances := {}


## The game runs as a simulation (`Vfx.shown` off, no HUD, no light, no ambience): nothing in
## the measures reads them, and a fight runs about twice as fast. `--classic` keeps them (to
## compare, or to look at a fight).
static var simulate := true


## Sound off, the profile, settings and run save in memory only, the remote settings off (like
## tests/run_tests.gd).
static func isolate_profile() -> void:
	Vfx.shown = not simulate
	Sfx.enabled = false
	Profile.save_path = ""
	Profile.reset()
	Settings.path = ""
	Settings.tutorial_hints = false
	RunSave.path = "user://balance_run_%d.json" % OS.get_process_id()
	RunSave.erase()
	# The data's numbers, never the remote settings' multipliers (docs/balance.md).
	RemoteConfig.use_for_tests()


## A clean profile for one measure: no bestiary mastery (+10% damage) carried over from the
## previous fights, every difficulty and ascension open, no shrine upgrade (builds bring theirs).
func fresh_profile() -> void:
	Profile.reset()
	for difficulty in content.difficulties:
		Profile.wins[String(difficulty.id)] = 1
	Profile.ascension_unlocked = content.ascensions.size()


# --- The game ------------------------------------------------------------------------------

## A run resumed at `depth` (RunSave in memory: the same seed every time), with `boss` drawn for
## its act. `plain`: no floor event or curse. `rank`: the boss comes at this rank.
## `unpeopled`: the floor without its monsters and loose items (World.unpeopled: the lab's
## sessions spawn their own fights and would only clear them away).
## `extra`: more of the run's save (the bottom of the Well: finale, keeper; RunState.to_data()).
func start_game(depth: int, difficulty: DifficultyDef, boss: BossDef = null, plain: bool = true, rank: MonsterRankDef = null, run_seed: int = -1, unpeopled: bool = false,
		extra: Dictionary = {}) -> Game:
	fresh_profile()
	HitStop.enabled = false
	HitStop.reset()
	get_tree().paused = false
	var s := seed_value if run_seed < 0 else run_seed
	seed(s)
	var run_bosses: Array = []
	for act in content.dungeon.acts:
		run_bosses.append(boss if boss and act.all_bosses().has(boss) else act.boss)
	var base := content.player.base_stats
	var save := {
		"seed": s, "depth": depth, "difficulty": String(difficulty.id), "ascension": difficulty.ascension,
		"bosses": RunSave.refs(run_bosses), "rerolls": 0, "banishes": 0, "time": 0.0,
		"player": { "level": 1, "hp": base.max_hp, "base_stats": base.to_dict() },
	}
	save.merge(extra, true)
	RunSave.write(save)
	Game.resume_requested = true
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.show_act_cards = false
	var world := game.get_node("World") as World
	world.overrides.plain = plain
	world.overrides.boss_rank = rank
	world.unpeopled = unpeopled
	if not Vfx.shown:
		# Nobody watches: the HUD and the screen's layers stay asleep (they only show the game).
		for layer: String in ["Hud", "ScreenFx", "Ambience"]:
			var node := game.get_node_or_null(layer)
			if node:
				node.process_mode = Node.PROCESS_MODE_DISABLED
				if node is CanvasLayer:
					(node as CanvasLayer).visible = false
	add_child(game)
	for i in 3:
		await get_tree().physics_frame
	return game


func end_game(game: Game) -> void:
	BalanceBot.release_all()
	get_tree().paused = false
	HitStop.reset()
	# Delayed effects (a blast's fuse, a combo's next stab) hold the world in their timers: let
	# them go off on a frozen game before freeing it, or they would call into freed objects.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 90:
		await get_tree().physics_frame
	game.queue_free()
	for i in 2:
		await get_tree().process_frame
	RunSave.erase()


## A run for a series of measures: { game, depth, difficulty, boss, plain, fresh, used, restarts }.
## Pass it to dummy() and pack(). `fresh` (the default): every measure starts on a new run of the
## same seed - lights, effects and timers of a floor roll random numbers on their own schedule,
## so a measure is only repeatable (and two builds comparable) on a world that starts from
## scratch. A hero who died is always replaced by a fresh run.
## The floor is built without its own monsters and items (`unpeopled`): the lab clears them
## before each measure anyway, and they are the last things a floor places, so the ground is the
## same. A new run for a fresh measure rebuilds the same floor in the running game (`renew`)
## instead of starting a new game: the same world from scratch, without the HUD, the menus and
## the hero made again (a new game when the hero died or left the floor).
func session(depth: int, difficulty: DifficultyDef, boss: BossDef = null, plain: bool = true, fresh: bool = true) -> Dictionary:
	return { "game": null, "depth": depth, "difficulty": difficulty, "boss": boss, "plain": plain, "fresh": fresh, "used": false, "restarts": 0, "renewals": 0 }


## The session's game for the next measure: started, or started again (fresh session, dead hero).
func ensure(s: Dictionary) -> Game:
	var game: Game = s.game
	var alive: bool = game != null and is_instance_valid(game) and not game.player.is_dead
	if alive and not (s.fresh and s.used):
		s.used = true
		return game
	await restart(s)
	s.used = true
	return s.game


## A new run of the same seed for the session: its floor rebuilt in the running game when it
## can be (`renew`), else a new game.
func restart(s: Dictionary) -> Game:
	if s.game != null and is_instance_valid(s.game):
		var game: Game = s.game
		if renew_floors and not game.player.is_dead and game.player.world == game.world and game.world.is_inside_tree():
			await renew(s)
			s.renewals += 1
			s.used = false
			return s.game
		await end_game(s.game)
		s.restarts += 1
	s.game = await start_game(s.depth, s.difficulty, s.boss, s.plain, null, -1, renew_floors)
	s.used = false
	return s.game


## The session's floor built again from its seed in the same game, as start_game() would build
## it: the last measure's timers go off on a frozen world first (a blast's fuse, a combo's next
## stab), then the floor is cleared and made again, the hero put back at its start. Everything a
## measure reads starts from scratch (ready_hero() puts the build on the hero, seeds the rest).
func renew(s: Dictionary) -> void:
	var game: Game = s.game
	BalanceBot.release_all()
	get_tree().paused = false
	HitStop.reset()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	game.process_mode = Node.PROCESS_MODE_INHERIT
	fresh_profile()
	var world := game.world
	world.overrides.plain = s.plain
	world.unpeopled = true
	# As Game._enter_floor(): the same seed, the same ways down, the same way in.
	world.rng.seed = hash("%d-floor-%d" % [game.run.run_seed, s.depth])
	world.next_routes = FloorRoute.offer(content, s.depth + 1, game.difficulty, game.run.route_seed(s.depth + 1))
	world.build_floor(s.depth, content, game._route_to(s.depth))
	world.place_player(game.player)
	for i in 3:
		await get_tree().physics_frame


func close(s: Dictionary) -> void:
	if s.game != null and is_instance_valid(s.game):
		await end_game(s.game)
	s.game = null


## A menu opened by itself (a level up, a shop...) is closed: the fight goes on.
func unpause(game: Game) -> void:
	if not get_tree().paused:
		return
	game.offers.clear()
	game.menus.hide_all()
	get_tree().paused = false


## No ambush, merchant, forge, encounter or event in the way; bosses never roll a rare rank
## (unless forced). Restored by restore_chances().
func override_chances() -> void:
	if not _saved_chances.is_empty():
		return
	var dungeon := content.dungeon
	_saved_chances = { "ambush": dungeon.ambush_chance, "merchant": dungeon.merchant_chance, "forge": dungeon.forge_chance,
		"forge_growth": dungeon.forge_chance_growth, "encounters": dungeon.encounters_max, "event": dungeon.floor_event_chance, "ranks": {} }
	dungeon.ambush_chance = 0.0
	dungeon.merchant_chance = 0.0
	dungeon.forge_chance = 0.0
	dungeon.forge_chance_growth = 0.0
	dungeon.encounters_max = 0
	dungeon.floor_event_chance = 0.0
	for rank in dungeon.rare_ranks:
		if rank:
			_saved_chances.ranks[rank] = rank.boss_chance
			rank.boss_chance = 0.0


func restore_chances() -> void:
	if _saved_chances.is_empty():
		return
	var dungeon := content.dungeon
	dungeon.ambush_chance = _saved_chances.ambush
	dungeon.merchant_chance = _saved_chances.merchant
	dungeon.forge_chance = _saved_chances.forge
	dungeon.forge_chance_growth = _saved_chances.forge_growth
	dungeon.encounters_max = _saved_chances.encounters
	dungeon.floor_event_chance = _saved_chances.event
	for rank: MonsterRankDef in _saved_chances.ranks:
		rank.boss_chance = _saved_chances.ranks[rank]
	_saved_chances = {}


## Every monster of the floor gone (the lab spawns its own).
func clear_monsters(world: World, settle: bool = false) -> void:
	# On a reused run: let the last measure's timers go off first (a shockwave's fuse, a delayed
	# blast, effects that roll random numbers).
	BalanceBot.release_all()
	if settle:
		for i in SETTLE_FRAMES:
			await get_tree().physics_frame
	# The dead too (a dissolving body still pushes), what they dropped, shots in the air.
	for group: String in ["monsters", "pickups", "gold"]:
		for node in get_tree().get_nodes_in_group(group):
			if world.is_ancestor_of(node):
				node.queue_free()
	for node in world.get_node("Projectiles").get_children():
		node.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame


## Puts `build` on the game's hero, full health, at the floor's start, the same random numbers
## as every other measure (seeded).
func ready_hero(game: Game, build: BalanceBuildDef, difficulty: DifficultyDef, measure_seed: int) -> Player:
	var player := game.player
	var world := game.world
	player.invincible = false
	player.statuses.clear()
	# Nothing carried over from the previous measure (cooldowns, pushes, a dash, the ward).
	player._attack_cooldown = 0.0
	player._invulnerable_time = 0.0
	player._knockback = Vector2.ZERO
	player._dash_time = 0.0
	player._dash_velocity = Vector2.ZERO
	player.controls.aim_hold = 0.0
	player.facing = Vector2.RIGHT
	player.last_hit = null
	player.ward = 0
	player._ward_time = 0.0
	player.temperature.reset()
	BalanceBuild.apply(build, player, content, difficulty)
	player.perks.on_floor_started(player)  # floor-start perks (a ward) as on arrival
	player.xp = -1000000  # the build keeps its level: no level up (and no perk menu) mid-measure
	player.global_position = world.map.cell_to_world(world.map.start_cell)
	player.velocity = Vector2.ZERO
	player.sustain = SustainMeter.new()
	player.ward = maxi(player.ward, 0)
	seed(measure_seed)
	world.rng.seed = measure_seed
	return player


# --- Measures -------------------------------------------------------------------------------

## The hero (face-tank bot, untouchable) hits `boss_def` that doesn't fight back until it dies
## or `limit` game seconds. The boss' HP is scaled by `hp_scale` (phases and thresholds are
## shares: they still happen). Returns { time, dps, damage, roar_time, ttk_est, killed, skills }:
## ttk_est = the time the full-HP boss would take.
## `full_hp`: the boss' health at full (its own floor's, when measured on another floor; 0: as spawned).
func dummy(s: Dictionary, build: BalanceBuildDef, boss_def: MonsterDef, hp_scale: float, limit: float, measure_seed: int, rank: MonsterRankDef = null, full_hp: int = 0) -> Dictionary:
	var game: Game = await ensure(s)
	var difficulty: DifficultyDef = s.difficulty
	var world := game.world
	await clear_monsters(world, not s.fresh)
	var player := ready_hero(game, build, difficulty, measure_seed)
	player.invincible = true
	var at := world.find_open_point_near(player.global_position, 70.0)
	var boss := world.spawn_monster(boss_def, at)
	if rank:
		world.make_ranked(boss, rank)
	if full_hp <= 0:
		full_hp = boss.get_max_hp()
	boss.base_stats.max_hp = maxi(1, roundi(full_hp * hp_scale) - (boss.get_max_hp() - boss.base_stats.max_hp))
	boss.invalidate_stats()
	boss.hp = boss.get_max_hp()
	var machine := boss.get_node_or_null("StateMachine")
	if machine:
		machine.process_mode = Node.PROCESS_MODE_DISABLED
	boss.move_direction = Vector2.ZERO
	await get_tree().physics_frame
	var bot := BalanceBot.create("face_tank", player, world, boss)
	var dealt := 0
	var last_hp := boss.hp
	var roar_frames := 0
	var frames := 0
	var hurt_frames := 0
	var healed := [0]
	var sources := {}
	var on_heal := func(amount: int, source: StringName) -> void:
		if is_instance_valid(boss) and boss.hp <= boss.get_max_hp() * 0.5:
			healed[0] += amount
			sources[String(source)] = int(sources.get(String(source), 0)) + amount
	player.healed.connect(on_heal)
	var limit_frames := roundi(limit * FPS)
	while frames < limit_frames:
		await get_tree().physics_frame
		frames += 1
		unpause(game)
		if not is_instance_valid(boss) or boss.is_dead:
			dealt += maxi(last_hp, 0)
			break
		if boss.hp < last_hp:
			dealt += last_hp - boss.hp
		last_hp = boss.hp
		if boss.hp <= boss.get_max_hp() * 0.5:
			# Half way: the hero is hurt (as at the end of a real fight) and stays so, healing or
			# not: low-health bonuses count for half the fight, the same for every build.
			hurt_frames += 1
			var low := maxi(1, roundi(player.get_max_hp() * 0.45))
			if player.hp != low:
				player.hp = low
				player.health_changed.emit(player.hp, player.get_max_hp())
		if boss.invincible:
			roar_frames += 1
		boss.move_direction = Vector2.ZERO
		bot.step()
	BalanceBot.release_all()
	player.healed.disconnect(on_heal)
	var killed := not is_instance_valid(boss) or boss.is_dead
	var time := frames / FPS
	var roar := roar_frames / FPS
	var fighting := maxf(time - roar, 0.01)
	var dps := dealt / fighting
	var ttk_est := full_hp / maxf(dps, 0.01) + roar if dealt > 0 else INF
	if is_instance_valid(boss) and not boss.is_dead:
		boss.queue_free()
	player.invincible = false
	return { "time": time, "dps": dps, "damage": dealt, "roar_time": roar, "ttk_est": ttk_est, "killed": killed,
		"skills": bot.skills_used, "full_hp": full_hp, "hp_scale": hp_scale,
		"sustain_hps": healed[0] / maxf(hurt_frames / FPS, 0.01), "heal_sources": sources }


## A room of monsters that don't fight back (their AI off, spread 70-200 px around the hero, at
## least 40 px apart: one swing can't reach them all),
## the hero (face-tank, untouchable) held at `hp_share` of its health so kill heals show:
## clear time for many targets (cleaves, chains, bursts, kill effects), healing per second.
## Monsters that come out (splits) get their AI off too. Returns { clear_time, cleared, healed,
## sustain_hps, heal_sources, kills }.
func dummy_pack(s: Dictionary, build: BalanceBuildDef, defs: Array, hp_share: float, limit: float, measure_seed: int) -> Dictionary:
	var game: Game = await ensure(s)
	var difficulty: DifficultyDef = s.difficulty
	var world := game.world
	await clear_monsters(world, not s.fresh)
	var player := ready_hero(game, build, difficulty, measure_seed)
	player.invincible = true
	var rng := RandomNumberGenerator.new()
	rng.seed = measure_seed
	var placed: Array[Vector2] = []
	for foe: Dictionary in defs:
		var at := player.global_position
		for attempt in 30:
			at = player.global_position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(70.0, 200.0)
			if world.is_solid_ground(at) and world.has_line_of_sight(player.global_position, at) \
					and placed.all(func(other: Vector2) -> bool: return other.distance_to(at) >= 40.0):
				break
		if not world.is_solid_ground(at):
			at = world.find_open_point_near(player.global_position, 120.0)
		placed.append(at)
		world.spawn_monster(foe.def, at)
	var healed := [0]
	var sources := {}
	var on_heal := func(amount: int, source: StringName) -> void:
		healed[0] += amount
		sources[String(source)] = int(sources.get(String(source), 0)) + amount
	player.healed.connect(on_heal)
	var kills := [0]
	var on_kill := func(_m: Monster) -> void: kills[0] += 1
	Events.monster_killed.connect(on_kill)
	var bot := BalanceBot.create("face_tank", player, world)
	var frames := 0
	var cleared := false
	var limit_frames := roundi(limit * FPS)
	var held := maxi(1, roundi(player.get_max_hp() * hp_share))
	while frames < limit_frames:
		await get_tree().physics_frame
		frames += 1
		unpause(game)
		var hostiles := world.get_hostiles(player.faction)
		if hostiles.is_empty():
			cleared = true
			break
		for actor in hostiles:
			var machine := actor.get_node_or_null("StateMachine")
			if machine and machine.process_mode != Node.PROCESS_MODE_DISABLED:
				machine.process_mode = Node.PROCESS_MODE_DISABLED
			(actor as Monster).move_direction = Vector2.ZERO
		if player.hp != held:
			player.hp = held
			player.health_changed.emit(player.hp, player.get_max_hp())
		bot.step()
	BalanceBot.release_all()
	player.healed.disconnect(on_heal)
	Events.monster_killed.disconnect(on_kill)
	player.invincible = false
	var time := frames / FPS
	return { "clear_time": time, "cleared": cleared, "healed": healed[0], "sustain_hps": healed[0] / maxf(time, 0.01),
		"heal_sources": sources, "kills": kills[0] }


## A room: `foes` ([{ def, rank, affixes }]) appear around the hero at 140-200 px and go for it;
## `bot_name` plays. Until they (and what they summon) are all dead, the hero dies, or `limit`.
## Returns { result: clear | died | timeout, clear_time, away_time (in the Deeps or the
## Threshold), ttks, ttk_by_kind, taken, hits, healed,
## heal_sources, min_hp_share, hero_max_hp, kills }.
## `carry`: the hero comes as the last room left it (Health, statuses, cooldowns: the gauntlet's
## rooms one after the other), only put back at the floor's start; the build is not put on again.
func pack(s: Dictionary, build: BalanceBuildDef, foes: Array, bot_name: String, limit: float, measure_seed: int, carry: bool = false) -> Dictionary:
	var game: Game = s.game
	if not carry or game == null or not is_instance_valid(game):
		game = await ensure(s)
	var difficulty: DifficultyDef = s.difficulty
	var world := game.world
	await clear_monsters(world, not s.fresh)
	var player := game.player
	if carry:
		player.global_position = world.map.cell_to_world(world.map.start_cell)
		player.velocity = Vector2.ZERO
		seed(measure_seed)
		world.rng.seed = measure_seed
	else:
		player = ready_hero(game, build, difficulty, measure_seed)
	var spawned: Array[Monster] = []
	for foe: Dictionary in foes:
		var at := world.find_open_point_near(player.global_position, world.rng.randf_range(140.0, 200.0))
		var monster := world.spawn_monster(foe.def, at)
		if foe.get("rank"):
			var affixes: Array[EliteAffixDef] = []
			for a: EliteAffixDef in foe.get("affixes", []):
				affixes.append(a)
			if affixes.is_empty() and (foe.rank as MonsterRankDef).affixes > 0:
				world.make_ranked(monster, foe.rank)
			else:
				monster.make_ranked(foe.rank, affixes)
		monster.target = player
		spawned.append(monster)
	var pack_log := PackLog.new(player, spawned, world)
	var bot := BalanceBot.create(bot_name, player, world)
	var away_frames := 0
	var frames := 0
	var limit_frames := roundi(limit * FPS)
	var outcome := "timeout"
	while frames < limit_frames:
		await get_tree().physics_frame
		frames += 1
		unpause(game)
		if not world.is_inside_tree():
			# The hero is in a world of his own for a while (the Deeps after a fall, the
			# Threshold's trial): the room waits frozen, the bot plays there.
			away_frames += 1
			bot.step()
			continue
		pack_log.frame()
		if player.is_dead:
			outcome = "died"
			break
		if world.get_hostiles(player.faction).is_empty():
			outcome = "clear"
			break
		bot.step()
	BalanceBot.release_all()
	pack_log.frame()
	pack_log.close()
	var result := pack_log.summary()
	result["result"] = outcome
	result["clear_time"] = frames / FPS
	result["hero_max_hp"] = player.get_max_hp()
	result["rolls"] = bot.rolls
	result["drinks"] = bot.drinks
	result["away_time"] = away_frames / FPS
	# (The next measure clears the room, or starts a fresh run.)
	return result


## A pack's foes from the act's monster list by spawn weight (seeded): `count` of them.
func roll_room(act: int, depth: int, count: int, rng_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var result: Array = []
	for i in count:
		var def := ContentDB.pick_from(content.dungeon.acts[act - 1].monsters, depth, rng) as MonsterDef
		if def:
			result.append({ "def": def })
	return result


## Monsters in a room of DungeonConfig.room_cells open cells at `depth` on `difficulty`
## (FloorRules.room_monsters(): the first floor's monsters_per_room, the depth's and the
## difficulty's extra ones, capped; what a room held before the rooms were counted by size, so
## the measures keep their room; a floor's rooms hold that times their size).
func room_size(depth: int, difficulty: DifficultyDef) -> int:
	var config := content.dungeon
	var rules := FloorRules.make(config, difficulty, null, depth)
	return rules.room_monsters(config.room_cells, 0.5)


## What a pack fight did: when each monster was first hurt and when it died (a one-hit kill
## counts 0 s), damage taken, healing by source (Actor.healed), the lowest health.
class PackLog:
	var player: Player
	var world: World
	## In spawn order (the ones it summons are added as they come).
	var monsters: Array[Monster] = []
	var ttks: Array[float] = []
	var ttk_by_kind := {}
	## TTK of each spawned foe, in spawn order (-1: not killed).
	var foe_ttks: Array[float] = []
	var foes: Array = []
	var taken := 0
	var hits := 0
	var healed_by := {}
	var min_hp := 0
	var kills := 0
	var _first_hurt := {}  # monster -> physics frame
	var _spawned := 0
	var _expected_hp := 0

	func _init(hero: Player, spawned: Array[Monster], in_world: World) -> void:
		player = hero
		world = in_world
		_spawned = spawned.size()
		for m in spawned:
			_watch(m)
			foes.append({ "id": String(m.def.id), "rank": String(m.rank.id) if m.rank else "", "affixes": m.affix_names(), "max_hp": m.get_max_hp(), "defense": m.get_stats().defense })
		foe_ttks.resize(spawned.size())
		foe_ttks.fill(-1.0)
		min_hp = player.hp
		_expected_hp = player.hp
		player.damaged.connect(_on_damaged)
		player.healed.connect(_on_healed)
		Events.monster_killed.connect(_on_killed)

	func _watch(m: Monster) -> void:
		monsters.append(m)
		m.health_changed.connect(func(current: int, maximum: int) -> void:
			if current < maximum and not _first_hurt.has(m):
				_first_hurt[m] = Engine.get_physics_frames())

	func _on_damaged(amount: int) -> void:
		if amount <= 0:
			return
		taken += amount
		_expected_hp -= amount
		hits += 1

	func _on_healed(amount: int, source: StringName) -> void:
		var key := String(source) if not String(source).is_empty() else "unattributed"
		healed_by[key] = int(healed_by.get(key, 0)) + amount
		_expected_hp += amount

	func _on_killed(monster: Monster) -> void:
		kills += 1
		var index := monsters.find(monster)
		if index < 0:
			return
		var first: int = _first_hurt.get(monster, Engine.get_physics_frames())
		var ttk := (Engine.get_physics_frames() - first) / FPS
		ttks.append(ttk)
		var kind := String(monster.def.id)
		if not ttk_by_kind.has(kind):
			ttk_by_kind[kind] = []
		ttk_by_kind[kind].append(ttk)
		if index < _spawned:
			foe_ttks[index] = ttk

	func frame() -> void:
		if not world.is_inside_tree():
			return  # the hero fell into the Deeps: this room is gone
		# Summoned adds join the room.
		for actor in world.get_hostiles(player.faction):
			var m := actor as Monster
			if m and not monsters.has(m):
				_watch(m)
		if is_instance_valid(player):
			if player.hp > maxi(_expected_hp, 0):
				healed_by["other"] = int(healed_by.get("other", 0)) + player.hp - maxi(_expected_hp, 0)
			_expected_hp = player.hp
			min_hp = mini(min_hp, player.hp)

	func close() -> void:
		if is_instance_valid(player):
			if player.damaged.is_connected(_on_damaged):
				player.damaged.disconnect(_on_damaged)
			if player.healed.is_connected(_on_healed):
				player.healed.disconnect(_on_healed)
		if Events.monster_killed.is_connected(_on_killed):
			Events.monster_killed.disconnect(_on_killed)

	func summary() -> Dictionary:
		var healed := 0
		for value: int in healed_by.values():
			healed += value
		return { "ttks": ttks, "ttk_by_kind": ttk_by_kind, "ttk": BalanceContent.mean(ttks), "foe_ttks": foe_ttks, "foes": foes,
			"taken": taken, "hits": hits, "healed": healed, "heal_sources": healed_by.duplicate(), "min_hp": min_hp,
			"min_hp_share": min_hp / float(maxi(player.get_max_hp(), 1)), "kills": kills }


## "rune:leech_rune 120, perk:vampirism 14"
static func sources_text(sources: Dictionary) -> String:
	var keys := sources.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(sources[a]) > int(sources[b]))
	var parts := PackedStringArray()
	for key: Variant in keys:
		parts.append("%s %d" % [key, int(sources[key])])
	return ", ".join(parts) if not parts.is_empty() else "-"
