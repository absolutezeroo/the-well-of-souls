class_name RegionPopulationTests
extends TestSuite
## Real native rewards and durable population, with AI disabled only to make state assertions
## independent of attack timing. Native damage, death, chest, coin and spawn paths still run.

const PROOF := preload("res://tools/rpg/region_proof.tscn")
const ATLAS: RegionAtlas = preload("res://data/regions/proof/atlas.tres")
const SLIME: MonsterDef = preload("res://data/monsters/slime.tres")
const THIEF: MonsterDef = preload("res://data/monsters/thief_racoon.tres")
const RANK: MonsterRankDef = preload("res://data/monster_ranks/elite.tres")
const VAMPIRIC: EliteAffixDef = preload("res://data/elites/vampiric.tres")

var _proof: RegionProof


func run_unit() -> void:
	var state := RegionState.new()
	state.id = ATLAS.regions[0].id
	state.initialized = true
	state.layout_stamp = ATLAS.regions[0].stamp()
	check(RegionPopulation.initialize(state, ATLAS.regions[0], CONTENT), "authored population initializes through native Monster/FloorRules")
	check(state.monsters.size() == 2 and state.chests.size() == 1 and state.population_initialized,
		"an authored population is seeded once as distinct stable records")
	check(RegionState.from_data(state.to_data()) != null, "population snapshots are fully serializable before any live destination is built")
	var monster: RegionMonsterState = state.monsters.values()[0]
	for damage in ["definition", "health", "death", "traits", "memory", "rank"]:
		var data := monster.to_data()
		match damage:
			"definition": data.definition = "@monster:missing"
			"health": data.health = 0.5
			"death": data.dead = true
			"traits": data.traits.append({ "kind": "unavailable", "data": {} })
			"memory": data.memory = { "missing_perk": { "used": 1 } }
			"rank": data.rank = "@rank:missing"
		check(RegionMonsterState.from_data(data) == null, "invalid persistent enemy is refused whole: " + damage)
	var chest: Dictionary = state.chests.values()[0].to_data()
	chest.fuse = 0.5
	check(RegionChestState.from_data(chest) == null, "a closed untrapped chest cannot carry an active fuse")
	check(RegionGoldState.from_data({ "id": "coins", "position": [10, 10], "amount": -1 }) == null,
		"a negative pile cannot become a durable currency reward")
	var corridor := ATLAS.regions[0].duplicate() as RegionDef
	corridor.rows = PackedStringArray(["#######", "#.....#", "#######"])
	corridor.entries = { "home": Vector2i(1, 1) }
	corridor.items = []
	corridor.monsters = []
	var exit := RegionLinkDef.new()
	exit.id = "exit"
	exit.cell = Vector2i(5, 1)
	corridor.links = [exit]
	var obstacle := RegionChestDef.new()
	obstacle.id = "blocked"
	obstacle.cell = Vector2i(3, 1)
	obstacle.chest = load("res://data/chests/chest.tres") as ChestDef
	corridor.chests = [obstacle]
	check(not corridor.valid(), "authored chest collision cannot silently close the only route to an exit")


func run_world() -> void:
	var path := "user://test_population_%d.json" % OS.get_process_id()
	_clean(path)
	_open(path)
	await _frames(3)
	check(_proof.started, "populated proof starts with the new schema and native actors")
	if not _proof.started:
		_proof.free()
		return
	var hero := _proof.session.character
	hero.invincible = true
	var coordinator := _proof.coordinator
	var world := _proof.world
	check(_monsters().size() == 2 and _chests().size() == 1, "the authored region contains its two enemies and chest")
	var survivor := _monsters()[0]
	var victim := _monsters()[1]
	survivor.hp = maxi(1, survivor.hp - 5)
	var wounded := survivor.hp
	var survivor_ref := RunSave.ref(survivor.def)
	var victim_ref := RunSave.ref(victim.def)
	var xp_before := _total_xp(hero)
	victim.take_hit(Combat.make_secondary_hit(hero, 99999))
	check(victim.is_dead and _total_xp(hero) > xp_before, "native enemy death pays experience once")
	var xp_after := _total_xp(hero)
	var chest := _chests()[0]
	var observations: Array[bool] = []
	var coordinator_ref: WeakRef = weakref(coordinator)
	chest.opened.connect(func(_chest: Chest) -> void:
		var current := coordinator_ref.get_ref() as RegionCoordinator
		observations.append(current != null and not current.checkpoint() and current.last_failure == RegionCoordinator.Failure.SETTLING))
	chest.open()
	check(chest.is_open and observations == [true], "an opened signal cannot checkpoint before native chest rewards finish")
	# Pending item/coin nodes are already tracked, even before insertion in the tree.
	check(coordinator.checkpoint(), "completed native rewards checkpoint with the open chest and dead enemy")
	await _frames(3)
	var wealth := _wealth()
	check(wealth > 0 and not _proof.session.campaign.world_state.regions[coordinator.current_id].gold.is_empty(),
		"native chest/death coins are included in the regional ledger")
	var item_count := _proof.session.campaign.world_state.regions[coordinator.current_id].objects.size()
	check(coordinator.travel("to_hall"), "leaving stores wounds, death, chest and all rewards together")
	await _frames(2)
	check(coordinator.travel("to_courtyard"), "return loads the persistent population")
	await _frames(3)
	var alive := _monsters()
	check(alive.size() == 1 and RunSave.ref(alive[0].def) == survivor_ref and alive[0].hp == wounded,
		"the wounded enemy keeps exact Health while the defeated enemy does not respawn")
	check(not alive.any(func(monster: Monster) -> bool: return RunSave.ref(monster.def) == victim_ref),
		"a death tombstone is not restored by replaying native die or granting another kill")
	check(_total_xp(hero) == xp_after and _chests()[0].is_open and _wealth() == wealth,
		"revisiting neither pays experience again nor reopens/rerolls chest currency")
	check(_proof.session.campaign.world_state.regions[coordinator.current_id].objects.size() == item_count,
		"chest/death item rewards are not created again on revisit")
	var coins := _coins()
	var amount := coins[0].amount
	var gold_before := hero.gold
	var gold_observations: Array[bool] = []
	hero.gold_changed.connect(func(_gold: int) -> void:
		var current := coordinator_ref.get_ref() as RegionCoordinator
		gold_observations.append(current != null and not current.checkpoint()
			and current.last_failure == RegionCoordinator.Failure.SETTLING), CONNECT_ONE_SHOT)
	check(coins[0].take(hero) and not coins[0].take(hero) and hero.gold == gold_before + amount,
		"one pile transfers exactly once even before its node has been freed")
	check(gold_observations == [true], "a currency-change signal cannot save before the ground pile is removed")
	check(coordinator.checkpoint(), "collected currency and removal from the ground commit together")
	await _frames(2)
	check(_wealth() == wealth, "collecting a restored pile preserves total wealth without a second scaling")
	# Dynamic ranked enemy and native lasting perk memory use stable composition references.
	var ranked := world.spawn_monster(SLIME, world.map.cell_to_world(Vector2i(12, 11)))
	ranked.make_ranked(RANK, [VAMPIRIC])
	ranked.process_mode = Node.PROCESS_MODE_DISABLED
	ranked.hp -= 3
	var ranked_health := ranked.hp
	ranked.perks.get_entry(VAMPIRIC.perk).memory[&"used"] = 2
	var thief := world.spawn_monster(THIEF, world.map.cell_to_world(Vector2i(4, 9)))
	thief.process_mode = Node.PROCESS_MODE_DISABLED
	hero.gold += 50
	var thief_trait := thief.get_trait(ThiefTrait) as ThiefTrait
	thief_trait.on_hit_player(thief, hero)
	var stolen := thief_trait.stolen(thief)
	check(stolen > 0 and coordinator.checkpoint(), "a native thief's stolen currency is part of the same checkpoint")
	wealth = _wealth() + stolen
	check(coordinator.travel("to_hall") and coordinator.travel("to_courtyard"), "dynamic population survives an immediate two-way traversal")
	await _frames(3)
	var ranked_back: Monster
	var thief_back: Monster
	for monster in _monsters():
		if monster.rank == RANK:
			ranked_back = monster
		if monster.def == THIEF:
			thief_back = monster
	check(ranked_back != null and ranked_back.hp == ranked_health and ranked_back.affixes == [VAMPIRIC]
		and ranked_back.perks.get_entry(VAMPIRIC.perk).memory.get(&"used", 0) == 2,
		"rank, affixes, exact wounds and limited-use passive memory survive revisits")
	check(thief_back != null and (thief_back.get_trait(ThiefTrait) as ThiefTrait).stolen(thief_back) == stolen
		and _wealth() + stolen == wealth, "the thief does not lose or refund stolen currency during loading")
	# Native death offspring are deferred. Until settled, direct snapshots refuse; a portal
	# request waits for the batch and then retains its children in the source region.
	var split := world.spawn_monster(load("res://data/monsters/big_slime.tres") as MonsterDef,
		world.map.cell_to_world(Vector2i(3, 11)))
	split.process_mode = Node.PROCESS_MODE_DISABLED
	split.take_hit(Combat.make_secondary_hit(hero, 99999))
	check(not world.spawns.is_settled() and not coordinator.checkpoint(),
		"a deferred native offspring batch blocks a partial checkpoint")
	coordinator.request_travel("to_hall")
	await _frames(5)
	check(coordinator.current_id == "proof:hall", "queued travel proceeds after native offspring settle")
	check(coordinator.travel("to_courtyard"), "the source with offspring can be revisited")
	await _frames(3)
	check(_monsters().size() >= 5, "native children persist alongside the original survivor and runtime enemies")
	var dead_records := 0
	for saved in _proof.session.campaign.world_state.regions[coordinator.current_id].monsters.values():
		if saved.dead:
			dead_records += 1
	check(dead_records == 1, "only the authored victim needs a tombstone; dead runtime summons do not accumulate")
	check(coordinator.checkpoint(), "the full current population checkpoints before restart")
	var expected_alive := _monsters().size()
	var expected_health := ranked_back.hp if is_instance_valid(ranked_back) else ranked_health
	var current_wealth := _wealth()
	var campaign_id := _proof.session.campaign.id
	_test_v2(path + ".v2")
	_proof.free()
	await _frames(2)
	_open(path)
	await _frames(3)
	check(_proof.started and _proof.session.campaign.id == campaign_id and _monsters().size() == expected_alive,
		"a fresh scene restores the same campaign and remaining enemies, without dead authored enemies")
	check(_chests()[0].is_open and _wealth() == current_wealth,
		"restart preserves an open chest and exact uncollected/collected wealth")
	for monster in _monsters():
		if monster.rank == RANK:
			check(monster.hp == expected_health, "restart preserves exact ranked enemy Health")
	_proof.free()
	await _frames(2)
	_clean(path)
	await _test_trap(path + ".trap")
	await _test_stale_batch()


func _open(path: String) -> void:
	_proof = PROOF.instantiate() as RegionProof
	_proof.checkpoint_path = path
	_proof.get_node("Coordinator").region_changed.connect(_freeze)
	add_child(_proof)
	_freeze(null)


func _freeze(_region: RegionDef) -> void:
	for monster in _monsters():
		monster.process_mode = Node.PROCESS_MODE_DISABLED
	for coin in _coins():
		coin.process_mode = Node.PROCESS_MODE_DISABLED


func _monsters() -> Array[Monster]:
	var result: Array[Monster] = []
	for node in get_tree().get_nodes_in_group("monsters"):
		if _proof.world.is_ancestor_of(node) and not (node as Monster).is_dead:
			result.append(node as Monster)
	return result


func _chests() -> Array[Chest]:
	var result: Array[Chest] = []
	for node in get_tree().get_nodes_in_group("chests"):
		if _proof.world.is_ancestor_of(node):
			result.append(node as Chest)
	return result


func _coins() -> Array[GoldPickup]:
	var result: Array[GoldPickup] = []
	for node in get_tree().get_nodes_in_group("gold"):
		if _proof.world.is_ancestor_of(node) and not (node as GoldPickup).is_collected():
			result.append(node as GoldPickup)
	return result


func _wealth() -> int:
	var total := _proof.session.character.gold
	for saved in _proof.session.campaign.world_state.regions.values():
		for pile in saved.gold.values():
			total += pile.amount
	return total


func _total_xp(hero: Player) -> int:
	# These proof kills stay below the first level-up; keep both fields to detect replay.
	return hero.level * 100000 + hero.xp


func _test_v2(path: String) -> void:
	_clean(path)
	var data := _proof.session.campaign.to_data()
	for region: Dictionary in data.world.regions.values():
		for field in ["gold", "monsters", "chests", "population_initialized", "population_stamp", "explored"]:
			region.erase(field)
	var payload := JSON.stringify(data)
	SafeFile.write_json(path, { "format": CampaignSave.FORMAT, "version": 2, "payload": payload, "sha256": payload.sha256_text() })
	var original := FileAccess.get_file_as_bytes(path)
	var loaded := CampaignSave.new(path).load_state()
	check(loaded != null and not loaded.world_state.regions["proof:courtyard"].population_initialized,
		"v2 gains an explicit uninitialized population rather than resetting old geometry or loot")
	check(loaded != null and JSON.parse_string(JSON.stringify(loaded.hero.to_data())) == JSON.parse_string(JSON.stringify(data.hero))
		and FileAccess.get_file_as_bytes(path) == original, "v2 read migration preserves the hero and leaves original bytes untouched")
	_clean(path)


func _test_trap(path: String) -> void:
	_clean(path)
	_open(path)
	await _frames(2)
	var chest := _proof.world.spawn_chest(load("res://data/chests/chest.tres") as ChestDef, Vector2i(15, 11), true)
	chest.restore_opened(true, 0.4)  # fixture: paused just after an explosive chest opened
	check(_proof.coordinator.checkpoint(), "an opened trapped chest with a pending fuse can checkpoint")
	_proof.free()
	await _frames(2)
	_open(path)
	await _frames(2)
	var restored: Chest
	for candidate in _chests():
		if candidate.trapped:
			restored = candidate
	check(restored != null and restored.is_open and restored.trap_time_left() > 0.0 and restored.trap_time_left() < 0.4,
		"restart resumes the remaining trap fuse without opening the chest a second time")
	check(_wealth() == 0, "restoring an opened trap does not generate another chest reward")
	await _frames(32)
	check(restored.trap_time_left() == -1.0 and _proof.coordinator.checkpoint(),
		"a completed trap has a canonical saved fuse and permits future checkpoints")
	_proof.free()
	await _frames(2)
	_open(path)
	await _frames(2)
	for candidate in _chests():
		if candidate.trapped:
			check(candidate.trap_time_left() == -1.0 and _wealth() == 0,
				"a completed trap is not armed or rewarded again after restart")
	_proof.free()
	await _frames(2)
	_clean(path)


func _test_stale_batch() -> void:
	var world := (load("res://src/world/world.tscn") as PackedScene).instantiate() as World
	add_child(world)
	world.difficulty = CONTENT.default_difficulty
	world.build_floor(1, CONTENT, null, RegionFloorKind.new(ATLAS.regions[0], ATLAS.start_entry))
	world.spawns.defer_monsters([SLIME], 2, world.map.cell_to_world(Vector2i(5, 9)), 24.0, null)
	world.build_floor(1, CONTENT, null, RegionFloorKind.new(ATLAS.regions[1], "from_courtyard"))
	await _frames(3)
	check(world.monster_count() == 0 and world.spawns.is_settled(),
		"a forced legacy floor replacement discards old offspring without leaking into the new floor")
	world.free()


func _clean(path: String) -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
