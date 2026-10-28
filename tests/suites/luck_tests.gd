class_name LuckTests
extends TestSuite
## Engineered luck (decision 0012; docs/design/loot.md "Bad-luck protection", dungeon.md "No
## repeats", "Boss arenas"): the pity on Rare finds, draws without repeats (curses, events,
## encounters, pacts, trials) that a floor laid again draws the same, the spring before every boss.

const WORLD_SCENE := "res://src/world/world.tscn"


func run_unit() -> void:
	_test_pity()
	_test_draws()
	_test_saved()
	var world := (load(WORLD_SCENE) as PackedScene).instantiate() as World
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	_test_floors_without_repeats(world)
	_test_offers(world)
	_test_boss_spring(world)
	world.clear_floor()
	remove_child(world)
	world.free()


## After a streak of finds without a Rare, the odds grow until one comes; told odds stay honest.
func _test_pity() -> void:
	var config := CONTENT.dungeon
	check(config.pity_after > 0 and config.pity_growth > 0.0, "bad-luck protection is on (after %d finds, +%d%% each)" % [config.pity_after, roundi(config.pity_growth * 100.0)])
	check(LootRoller.rarity_weights(3, 1.0, config) == LootRoller.rarity_weights(3, 1.0, config, config.pity_after - 1), "no change before the streak is long enough")
	var plain := LootRoller.rarity_weights(3, 1.0, config)
	var pitied := LootRoller.rarity_weights(3, 1.0, config, config.pity_after + 4)
	check(is_equal_approx(pitied[ItemRarity.RARE], plain[ItemRarity.RARE] * (1.0 + config.pity_growth * 5.0)) and pitied[ItemRarity.COMMON] == plain[ItemRarity.COMMON],
		"past the streak, Rare and Epic weigh more with every find (x%.1f five finds on)" % (pitied[ItemRarity.RARE] / plain[ItemRarity.RARE]))
	var item: EquipmentDef
	for candidate in CONTENT.items:
		if candidate is EquipmentDef and not (candidate as EquipmentDef).is_rolled():
			item = candidate
			break
	var rng := RandomNumberGenerator.new()
	var longest := {}
	var counted := true
	for protected: bool in [false, true]:
		rng.seed = 4242
		var luck := RunLuck.new()
		var streak := 0
		var worst := 0
		for i in 3000:
			var found := LootRoller.roll(item, 1, 1.0, config, CONTENT.item_affixes, rng, ItemRarity.COMMON, luck if protected else null) as EquipmentDef
			streak = 0 if found.rarity >= ItemRarity.RARE else streak + 1
			worst = maxi(worst, streak)
			counted = counted and (not protected or luck.rare_drought == streak)
		longest[protected] = worst
	check(counted, "the drought counts the finds since the last Rare or better")
	check(longest[true] <= config.pity_after + 20 and longest[true] * 2 < longest[false], "on the first floor, the longest run of finds without a Rare: %d with the protection, %d without" % [longest[true], longest[false]])


## RunLuck.draw(): the least drawn first, the floors below not counted, a floor forgotten.
func _test_draws() -> void:
	var pool := CONTENT.encounters.filter(func(e: EncounterDef) -> bool: return e.min_depth <= 5)
	var luck := RunLuck.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in pool.size() * 2:
		var def := luck.draw(RunLuck.ENCOUNTER, CONTENT.encounters, 5, 6, rng)
		luck.record(RunLuck.ENCOUNTER, def, 5)
		seen[def] = int(seen.get(def, 0)) + 1
		if i == pool.size() - 1:
			check(seen.size() == pool.size(), "each of the %d encounters comes once before any comes twice" % pool.size())
	check(seen.values().all(func(n: int) -> bool: return n == 2), "...and twice before any comes three times %s" % str(seen.values()))
	var later := RunLuck.new()
	later.record(RunLuck.ENCOUNTER, pool[0], 9)
	check(later.times_drawn(RunLuck.ENCOUNTER, String(pool[0].id), 9) == 0 and later.times_drawn(RunLuck.ENCOUNTER, String(pool[0].id), 10) == 1, "a floor's draws see the floors above it, not the ones below")
	later.forget(9)
	check(later.times_drawn(RunLuck.ENCOUNTER, String(pool[0].id), 99) == 0, "a floor laid again forgets what it drew")


func _test_saved() -> void:
	var luck := RunLuck.new()
	luck.rare_drought = 13
	luck.record(RunLuck.CURSE, CONTENT.curses[0], 4)
	luck.record(RunLuck.PACT, CONTENT.dungeon.pacts[0], 6)
	var back := RunLuck.from_data(JSON.parse_string(JSON.stringify(luck.to_data())))
	check(back.rare_drought == 13 and back.times_drawn(RunLuck.CURSE, String(CONTENT.curses[0].id), 5) == 1 and back.times_drawn(RunLuck.PACT, String(CONTENT.dungeon.pacts[0].id), 7) == 1, "the run's luck is saved and read back")
	var damaged := RunLuck.from_data({"drawn": {"curse": "nonsense", "pact": {"x": ["a", 3]}}, "rare_drought": -4})
	check(damaged.rare_drought == 0 and damaged.times_drawn(RunLuck.PACT, "x", 9) == 1 and RunLuck.from_data(null).drawn.is_empty(), "a damaged or older save reads as what it can")
	var rng := RandomNumberGenerator.new()
	var run := RunState.create(CONTENT, {}, rng)
	run.luck = luck
	var again := RunState.create(CONTENT, JSON.parse_string(JSON.stringify(run.to_data())), rng)
	check(again.luck.rare_drought == 13 and again.luck.times_drawn(RunLuck.CURSE, String(CONTENT.curses[0].id), 5) == 1 and RunSave.SHAPE.get("luck") == "dict", "the run's save holds its luck, a run picked up has it back")


## Floors in a row, each drawing among what the run drew least: three cursed floors, three curses.
func _test_floors_without_repeats(world: World) -> void:
	var cursed := CONTENT.get_difficulty(&"normal").duplicate() as DifficultyDef
	cursed.curse_chance = 1.0
	world.difficulty = cursed
	world.luck = RunLuck.new()
	var curses: Array[StringName] = []
	var encounters := {}
	for depth in range(2, 9):
		if CONTENT.dungeon.boss_for_depth(depth):
			continue
		world.rng.seed = hash("luck-%d" % depth)
		world.build_floor(depth, CONTENT)
		if world.curse:
			curses.append(world.curse.id)
		for child in world._entities.get_children():
			if child is Encounter:
				encounters[(child as Encounter).def.id] = int(encounters.get((child as Encounter).def.id, 0)) + 1
	var first_three := curses.slice(0, CONTENT.curses.size())
	var distinct := {}
	for id in first_three:
		distinct[id] = true
	check(curses.size() >= CONTENT.curses.size() and distinct.size() == CONTENT.curses.size(), "cursed floors in a row: every curse once before any twice %s" % str(curses))
	var counts := encounters.values()
	counts.sort()
	check(not counts.is_empty() and int(counts.back()) - int(counts.front()) <= 1, "encounters come in turn over a run %s" % str(encounters))
	# A floor laid again from its seed (a run picked up) draws what it drew.
	var depth := 6 if not CONTENT.dungeon.boss_for_depth(6) else 5
	world.rng.seed = hash("luck-%d" % depth)
	world.build_floor(depth, CONTENT)
	var before := _draws(world)
	world.rng.seed = hash("luck-%d" % depth)
	world.build_floor(depth, CONTENT)
	check(_draws(world) == before, "a floor laid again draws the same (%s)" % before)
	world.difficulty = CONTENT.get_difficulty(&"normal")


func _draws(world: World) -> String:
	var ids: Array[String] = [str(world.curse.id) if world.curse else "", str(world.floor_event.id) if world.floor_event else ""]
	for child in world._entities.get_children():
		if child is Encounter:
			ids.append(str((child as Encounter).def.id))
	return ",".join(ids)


## The ways down leave out the curses the run drew above, and don't share one.
func _test_offers(_world: World) -> void:
	var cursed := CONTENT.get_difficulty(&"normal").duplicate() as DifficultyDef
	cursed.curse_chance = 1.0
	var luck := RunLuck.new()
	var curses := CONTENT.curses.duplicate()
	for i in curses.size() - 1:
		luck.record(RunLuck.CURSE, curses[i], 3)
	var depth := 5
	while CONTENT.dungeon.boss_for_depth(depth) or CONTENT.dungeon.boss_for_depth(depth - 1):
		depth += 1
	var ways := FloorRoute.offer(CONTENT, depth, cursed, 99, null, luck, depth - 1)
	check(ways.size() >= 2 and ways[0].curse == curses.back(), "the first way down gets the curse not seen yet (%s)" % (ways[0].curse.id if ways and ways[0].curse else &"none"))
	check(ways.size() >= 2 and ways[1].curse != ways[0].curse, "the two ways don't share a curse")
	var again := FloorRoute.offer(CONTENT, depth, cursed, 99, null, luck, depth - 1)
	check(again.size() == ways.size() and again[0].curse == ways[0].curse and again[1].curse == ways[1].curse, "the same offer whenever it is asked")


## A heal before every boss: the spring by where the hero arrives, on every difficulty.
func _test_boss_spring(world: World) -> void:
	var spring := CONTENT.dungeon.boss_spring
	check(spring != null and spring.choices.size() == 1 and spring.choices[0].gold_cost == 0 and spring.choices[0].max_hp_cost == 0.0
		and spring.choices[0].outcomes.size() == 1 and spring.choices[0].outcomes[0].heal_ratio >= 1.0 and spring.choices[0].outcomes[0].damage_ratio == 0.0,
		"the spring before a boss heals fully, for nothing, every time")
	check(not CONTENT.encounters.has(spring), "...and is never one of the floors' random encounters")
	var boss_depth := 1
	while CONTENT.dungeon.boss_for_depth(boss_depth) == null:
		boss_depth += 1
	for difficulty in CONTENT.difficulties:
		world.difficulty = difficulty
		world.rng.seed = hash("spring-%s" % difficulty.id)
		world.build_floor(boss_depth, CONTENT)
		var found: Encounter = null
		for child in world._entities.get_children():
			if child is Encounter and (child as Encounter).def == spring:
				found = child
		var cell := world.map.world_to_cell(found.global_position) if found else Vector2i(-1, -1)
		check(world.arena != null and found != null and world.map.rooms[0].has_point(cell) and cell != world.map.start_cell,
			"%s: the boss floor's first room holds the spring, beside where the hero arrives" % difficulty.id)
	world.difficulty = CONTENT.get_difficulty(&"normal")
