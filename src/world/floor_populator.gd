class_name FloorPopulator
## Fills a freshly generated floor: the merchant, the smith's forge, a pact door, lights, the biome's dressing (FloorDresser),
## a fragment of the past now and then (FragmentPlacer, last),
## props and hazards first (they claim their cells), then the ambush room, chests, monsters and
## items on the free cells. The first room is where the player starts: no monsters or hazards.
## The floor's rhythm (FloorPacing, decision 0012): monsters by each room's size, a calm room on
## the way after a few fights, the ambush or the pact door at the peak, the merchant and the forge
## after it, a chest on every floor.

## Free cells kept between a room's pillar and a crate or lamp along its walls (near_pillar()).
const PILLAR_CLEARANCE := 2


static func populate(world: World, content: ContentDB, depth: int) -> void:
	var map := world.map
	var rng := world.rng
	var config := content.dungeon
	# Bigger floors (the difficulty's) get more of everything: chests, hazards, encounters, items.
	var spread := maxf(float(map.rooms.size()) / maxf(config.max_rooms, 1.0), 1.0)
	var taken := {}  # cells used by props and hazards
	_reserve_around(taken, map.start_cell, 2)
	# The shaped rooms' chasms and pools, a step around them (nothing knocked in at once, the
	# rim kept clear), and their pillars (RoomFeatures put them up already).
	for cell: Vector2i in map.features:
		_reserve_around(taken, cell, 1)
	for cell: Vector2i in map.pillars:
		taken[cell] = true
	# Two free cells between a pillar and the furniture and lamps the dressing stands along the walls:
	# no one-cell squeeze (crates and chests keep clear by near_pillar()). Given back once they
	# stand: a trial's souls, an encounter, the monsters only need their own room.
	var pillar_clearance := {}
	for cell: Vector2i in map.pillars:
		for dy in range(-PILLAR_CLEARANCE, PILLAR_CLEARANCE + 1):
			for dx in range(-PILLAR_CLEARANCE, PILLAR_CLEARANCE + 1):
				var near := cell + Vector2i(dx, dy)
				if not taken.has(near):
					taken[near] = true
					pillar_clearance[near] = true
	for cell in map.exit_cells():
		_reserve_around(taken, cell, 1)
	# Nothing in front of a cracked wall (SecretRoomPlan): the way to it stays clear.
	for secret in map.secrets:
		for cell in secret.crack:
			_reserve_around(taken, cell - secret.direction, 1)
	if map.rooms.size() < 2:
		for room in map.rooms:
			place_lights(world, config, room, taken)
		return
	var pacing := FloorPacing.new(map)
	var after_peak := pacing.rooms_from(config.peak_to)  # the release: the merchant, the forge

	# The merchant waits in a quiet room (no monsters, no hazards, no props around).
	var event := world.floor_event
	var merchant_index := -1
	if config.merchant and (rng.randf() < config.merchant_chance or (event and event.merchant)):
		merchant_index = _pick_quiet_room(map, rng, -1, after_peak)
		if merchant_index >= 0:
			var cell := map.heart(merchant_index)
			world.spawn_merchant(config.merchant, cell)
			_reserve_around(taken, cell, 1)

	if merchant_index >= 0:
		place_lights(world, config, map.rooms[merchant_index], taken)
		_reserve_rect(taken, map.rooms[merchant_index])  # nothing else in his room

	# The smith's forge: in another quiet room, more likely the longer it has been away.
	var forge_index := -1
	if config.forge and rng.randf() < config.forge_chance + config.forge_chance_growth * world.floors_without_forge:
		forge_index = _pick_quiet_room(map, rng, merchant_index, after_peak)
		if forge_index >= 0:
			var cell := map.heart(forge_index)
			world.spawn_forge(config.forge, cell)
			_reserve_around(taken, cell, 2)
			place_lights(world, config, map.rooms[forge_index], taken)
			_reserve_rect(taken, map.rooms[forge_index])  # a quiet room: nothing else in it
	world.floors_without_forge = 0 if forge_index >= 0 else world.floors_without_forge + 1
	# A dead-end room may hold a pact door (PactRoom), picked before the ambush claims it.
	# Never a room a secret opens off: an unsworn pact would wall its crack in for good.
	var not_pact: Array[int] = [merchant_index, forge_index]
	for secret in map.secrets:
		not_pact.append(secret.host)
	# A room trial (RoomTrial), on a floor with no other event; a floor with one has no pact.
	var trial_plan := RoomTrial.plan(world, config, depth, not_pact)
	world.luck.record(RunLuck.TRIAL, trial_plan.get("trial") as TrialDef, depth)
	var peak := pacing.rooms_between(config.peak_from, config.peak_to)
	var pact_plan := PactRoom.plan(world, config, depth, not_pact, peak) if trial_plan.is_empty() else {}
	var pact_index: int = pact_plan.get("room", -1)
	world.luck.record(RunLuck.PACT, pact_plan.get("pact") as PactDef, depth)
	# The Unbound Seal shuts a room as a pact door does: nothing else in it.
	if trial_plan.get("trial") is SealTrialDef:
		pact_index = int(trial_plan.room)
	# One quiet room may be an ambush: no monsters in it until the hero walks in, and no
	# chest or encounter either (picked now, before they claim rooms).
	var ambush_index := -1
	if rng.randf() < config.ambush_chance:
		for attempt in 6:
			ambush_index = _pick_quiet_room(map, rng, merchant_index, peak)
			if ambush_index != forge_index and ambush_index != pact_index:
				break
			ambush_index = -1  # not by the smith, nor behind a pact door
	# The calm rooms on the way: never more than max_fights_in_a_row fights in a row.
	var calm := {0: true}
	var forced := {}
	for i in [merchant_index, forge_index]:
		if i >= 0:
			calm[i] = true
	for i in [ambush_index, pact_index]:
		if i >= 0:
			forced[i] = true
	pacing.plan_breathers(config.max_fights_in_a_row, calm, forced)
	# The biome's grounds, scenes and decor, before anything else claims the rooms.
	FloorDresser.dress(world, taken)
	for i in map.rooms.size():
		if i != merchant_index and i != forge_index:
			place_lights(world, config, map.rooms[i], taken)
	if not pact_plan.is_empty():
		world.spawn_pact(pact_plan.pact, map.rooms[pact_index], taken)
		_reserve_rect(taken, map.rooms[pact_index])  # its own fight only: nothing else in it
	for cell: Vector2i in pillar_clearance:
		if not (pact_index >= 0 and map.rooms[pact_index].has_point(cell)):
			taken.erase(cell)
	if not trial_plan.is_empty():
		world.spawn_trial(trial_plan, taken)

	# Springs, altars, statues: in the middle of a room, before anything else claims it.
	var encounter_count := roundi(rng.randi_range(config.encounters_min, config.encounters_max) * spread)
	if event and config.encounters_max > 0:
		encounter_count += event.extra_encounters
	var encounter_rooms: Array[int] = []  # one encounter per room: never two side by side
	var calm_first := pacing.by_window(pacing.breather_rooms(), 1.0, INF)  # the latest first
	for n in encounter_count:
		var encounter := world.luck.draw(RunLuck.ENCOUNTER, content.encounters, depth, depth + 1, rng) as EncounterDef
		if encounter == null:
			continue
		# The calm rooms on the way first (a spring, an altar to break the fights), then a few tries
		# anywhere: a room's middle may hold a scene (a statue, a pond...); then near it.
		var placed := false
		for index in calm_first:
			if index in encounter_rooms:
				continue
			var cell := _free_near_middle(world, index, taken)
			if cell != Vector2i(-1, -1):
				world.spawn_encounter(encounter, cell)
				world.luck.record(RunLuck.ENCOUNTER, encounter, depth)
				_reserve_around(taken, cell, config.encounter_clearance)
				encounter_rooms.append(index)
				placed = true
				break
		for attempt in 0 if placed else 8:
			var index := rng.randi_range(1, map.rooms.size() - 1)
			if index in encounter_rooms or index == merchant_index or index == forge_index \
					or index == ambush_index or index == pact_index:
				continue
			var cell := _free_near_middle(world, index, taken)
			if cell != Vector2i(-1, -1):
				world.spawn_encounter(encounter, cell)
				world.luck.record(RunLuck.ENCOUNTER, encounter, depth)
				_reserve_around(taken, cell, config.encounter_clearance)
				encounter_rooms.append(index)
				break

	if world.curse:
		place_curse(world, world.curse, taken)

	for room in map.rooms:
		_place_props(world, content, depth, room, taken)
	var act := config.act_for_depth(depth)
	if act:
		var hazard_groups := roundi(rng.randi_range(config.hazard_groups_min, config.hazard_groups_max) * spread)
		if event:
			hazard_groups += event.extra_hazards
		var hazard_rooms: Array[int] = []  # (the calm rooms stay calm)
		for i in range(1, map.rooms.size()):
			if not pacing.breathers.has(i):
				hazard_rooms.append(i)
		for n in hazard_groups if not hazard_rooms.is_empty() else 0:
			var hazard := world.biome.pick_hazard(act, depth, rng) if world.biome else act.pick_hazard(depth, rng)
			if hazard:
				hazard.place(world, map.rooms[hazard_rooms[rng.randi_range(0, hazard_rooms.size() - 1)]], taken)

	if ambush_index >= 0:
		world.spawn_ambush(map.rooms[ambush_index])

	if config.chest:
		var chest_count := roundi(rng.randi_range(config.chests_min, config.chests_max) * spread)
		if event:
			chest_count += event.extra_chests
		for n in chest_count:
			# The first in a dead end (the reward for the detour), else a calm room on the way, else
			# any room with a free spot (a floor never goes without its treasure).
			if n == 0 and _place_treasure(world, config, pacing, [ambush_index, pact_index], taken):
				continue
			# A few tries: some rooms have no free spot along their walls.
			for attempt in 12:
				var index := rng.randi_range(1, map.rooms.size() - 1)
				if index == ambush_index or index == pact_index:
					continue
				var room := map.rooms[index]
				var cells := _shuffled(edge_cells(map, room, taken), rng)
				if not cells.is_empty():
					world.spawn_chest(config.chest, cells[0], rng.randf() < config.chest.trapped_chance)
					_reserve_around(taken, cells[0], 1)
					break

	if world.unpeopled:
		return  # the monsters and the items lying around come last: the rest is as it would be
	var counts := {}  # room index -> its share of monsters (by its size; a tough one counts more)
	var total := 0
	for i in range(1, map.rooms.size()):
		if i == ambush_index or i == merchant_index or i == forge_index or i == pact_index or pacing.breathers.has(i):
			continue
		counts[i] = world.rules.room_monsters(ground_cells(map, map.rooms[i]), rng.randf())
		total += counts[i]
	# The peak: the ambush or the pact door, else an elite in the fight room there.
	var peak_room := -1
	if depth >= config.peak_elite_min_depth and not peak.has(ambush_index) and not peak.has(pact_index):
		var fights: Array[int] = []
		for i: int in counts:
			if pacing.on_route(i) and counts[i] > 0:
				fights.append(i)
		var by_peak := pacing.by_window(fights, config.peak_from, config.peak_to)
		peak_room = by_peak[0] if not by_peak.is_empty() else -1
	# Too many for one floor: every room gets fewer (at least one).
	if config.max_monsters_per_floor > 0 and total > config.max_monsters_per_floor:
		var keep := float(config.max_monsters_per_floor) / total
		for i: int in counts:
			counts[i] = maxi(floori(counts[i] * keep), mini(counts[i], 1))
	var floor_index := 0
	for i: int in counts:
		var room := map.rooms[i]
		# Each body clear of the ones already standing in the room: two spawned into each other
		# are shoved apart by the physics on the first frame, hard enough to end in a wall or a
		# crate (level_tests "as built").
		var placed: Array[Actor] = []
		var share: int = counts[i]
		while share > 0:
			var def := content.pick_monster(depth, rng)
			share -= 1 if def else share  # (no monster for this depth: the room stays as it is)
			if def:
				var monster := world.spawn_monster(def, _free_point_in(world, room, rng, taken, WorldSpace.room_for(def), placed))
				world.roll_elite(monster)
				if i == peak_room and placed.is_empty() and not monster.is_elite():
					world.make_elite(monster)  # the floor's peak
				if monster.is_elite() or def.radius >= config.tough_radius:
					share -= config.tough_cost - 1  # a tough one takes more of the room's share
				# An elite grew: its bigger body must fit where it stands too.
				if monster.radius > WorldSpace.room_for(def) and (not _fits(world, monster.global_position, monster.radius) \
						or WorldSpace.is_under_body(monster.global_position, placed, monster.radius)):
					monster.global_position = _free_point_in(world, room, rng, taken, monster.radius, placed)
				placed.append(monster)
				monster.floor_index = floor_index  # (the seed's order: a resumed run's same monster)
				floor_index += 1

	# Items lie around, not in the merchant's or the smith's room.
	var item_rooms: Array[int] = []
	for i in range(1, map.rooms.size()):
		if i != merchant_index and i != forge_index and i != pact_index:
			item_rooms.append(i)
	for n in roundi(config.items_per_floor * spread):
		if item_rooms.is_empty():
			break
		var room := map.rooms[item_rooms[rng.randi_range(0, item_rooms.size() - 1)]]
		var item := content.pick_item(depth, rng)
		if item:
			world.spawn_loot(item, _free_point_in(world, room, rng, taken))

	# Last, from its own random numbers: a fragment of the past, now and then (FragmentPlacer).
	FragmentPlacer.place(world, content, depth, taken)


## A cursed floor: the look over every room, the darkness, and campfires (or springs) spread
## around, one in the first room.
static func place_curse(world: World, curse: CurseDef, taken: Dictionary) -> void:
	var map := world.map
	if curse.room_look:
		for room in map.rooms:
			world.spawn_heat_source(curse.room_look, room)
	if curse.darkness:
		var whole := Rect2i(Vector2i.ZERO, Vector2i(map.width, map.height))
		world.spawn_dark_room(curse.darkness, whole)
	if curse.warm_spot == null:
		return
	if not curse.warm_spot.place_one(world, map.rooms[0], taken):
		# A small first room: the nearest free spot to where the hero appears (on floor, never
		# in a wall: a blind offset used to put the oasis inside the rock).
		var rect := HazardDef.nearest_free_rect(world, map.start_cell, taken, curse.warm_spot.size)
		if rect.size != Vector2i.ZERO:
			HazardDef.take_rect(taken, rect)
			world.spawn_heat_source(curse.warm_spot, rect)
	var rooms := range(1, map.rooms.size())
	RandomUtils.shuffle(rooms, world.rng)
	var wanted := world.rng.randi_range(curse.spot_count.x, curse.spot_count.y)
	for i: int in rooms:
		if wanted <= 0:
			break
		if curse.warm_spot.place_one(world, map.rooms[i], taken):
			wanted -= 1


## The free cell closest to the heart of room `index` (at most 2 cells away), or (-1, -1).
static func _free_near_middle(world: World, index: int, taken: Dictionary) -> Vector2i:
	var room := world.map.rooms[index]
	var middle := world.map.heart(index)
	for radius in 3:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var cell := middle + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == radius and room.grow(-1).has_point(cell) \
						and not taken.has(cell) and RoomSpace.is_free(world, cell):
					return cell
	return Vector2i(-1, -1)


## A big enough room, not the first one, without the stairs and not `except` (-1 if none); not
## a chasm room nor a biome's signature room (RoomPlan.is_quiet()). One of `preferred` if any of
## them will do (the floor's peak, its release: FloorPacing).
static func _pick_quiet_room(map: DungeonMap, rng: RandomNumberGenerator, except: int, preferred: Array[int] = []) -> int:
	var candidates: Array[int] = []
	for i in range(1, map.rooms.size()):
		var room := map.rooms[i]
		if i != except and map.plan(i).is_quiet() and room.size.x >= 7 and room.size.y >= 7 and not map.exit_cells().any(func(c: Vector2i) -> bool: return room.grow(1).has_point(c)):
			candidates.append(i)
	var wanted := candidates.filter(func(i: int) -> bool: return preferred.has(i))
	if not wanted.is_empty():
		candidates.assign(wanted)
	return candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else -1


## The floor's first chest (decision 0012: a treasure on every floor): in a dead end if one has a
## free spot by its walls (the reward for the detour), else a calm room on the way, else any room
## but `not_in` (the ambush's, the pact's). False if no room had room for it.
static func _place_treasure(world: World, config: DungeonConfig, pacing: FloorPacing, not_in: Array, taken: Dictionary) -> bool:
	var map := world.map
	var dead_ends: Array[int] = []
	var others: Array[int] = []
	for i in range(1, map.rooms.size()):
		if not_in.has(i):
			continue
		if pacing.is_dead_end(i):
			dead_ends.append(i)
		elif not pacing.breathers.has(i):
			others.append(i)
	RandomUtils.shuffle(dead_ends, world.rng)
	var order: Array[int] = dead_ends
	order.append_array(pacing.breather_rooms())
	order.append_array(others)
	for index in order:
		var cells := _shuffled(edge_cells(map, map.rooms[index], taken), world.rng)
		if not cells.is_empty():
			world.spawn_chest(config.chest, cells[0], world.rng.randf() < config.chest.trapped_chance)
			_reserve_around(taken, cells[0], 1)
			return true
	return false


## Open ground cells in `room` (no rock, chasm, pool or pillar): what its monsters are counted by.
static func ground_cells(map: DungeonMap, room: Rect2i) -> int:
	var count := 0
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			if map.is_ground(Vector2i(x, y)):
				count += 1
	return count


## Lanterns along the walls of a room (also used for boss arenas).
## `count`: how many at most (-1: the dungeon's `lights_per_room`).
static func place_lights(world: World, config: DungeonConfig, room: Rect2i, taken: Dictionary, count: int = -1) -> void:
	var light := world.biome.light if world.biome and world.biome.light else config.room_light
	var most := config.lights_per_room if count < 0 else count
	if light == null or most <= 0:
		return
	var cells := edge_cells(world.map, room, taken)
	var placed: Array[Vector2i] = []
	for cell in _shuffled(cells, world.rng):
		if placed.size() >= most:
			break
		# Spread them out.
		if placed.any(func(other: Vector2i) -> bool: return Vector2(other).distance_to(Vector2(cell)) < 5.0):
			continue
		if not light.is_breakable() and not RoomSpace.stays_open(world, room, {cell: true}):
			continue  # it would close a gap between a scene's furniture and the wall
		world.spawn_prop(light, cell)
		_reserve_around(taken, cell, 1)
		placed.append(cell)


## Crates, pots and barrels in small clusters against the walls.
static func _place_props(world: World, content: ContentDB, depth: int, room: Rect2i, taken: Dictionary) -> void:
	var rng := world.rng
	var config := content.dungeon
	var clusters := rng.randi_range(config.prop_clusters_min, config.prop_clusters_max)
	var cells := _shuffled(edge_cells(world.map, room, taken), rng)
	for n in mini(clusters, cells.size()):
		var start: Vector2i = cells[n]
		if taken.has(start):
			continue
		var size := rng.randi_range(1, 3)
		var cell := start
		for k in size:
			if taken.has(cell) or not _is_edge(world.map, room, cell):
				break
			var prop := world.biome.pick_prop(content, depth, rng) if world.biome else content.pick_prop(depth, rng)
			if prop:
				world.spawn_prop(prop, cell)
			taken[cell] = true
			cell += [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][rng.randi_range(0, 3)]


## Floor cells of the room touching a wall, away from doorways.
static func edge_cells(map: DungeonMap, room: Rect2i, taken: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			var cell := Vector2i(x, y)
			if not taken.has(cell) and _is_edge(map, room, cell):
				cells.append(cell)
	return cells


static func _is_edge(map: DungeonMap, room: Rect2i, cell: Vector2i) -> bool:
	if not room.has_point(cell) or not map.is_floor(cell):
		return false
	var touches_wall := false
	for dir: Vector2i in GridDirs.FOUR:
		touches_wall = touches_wall or not map.is_floor(cell + dir)
	if not touches_wall:
		return false
	return not near_doorway(map, room, cell) and not near_pillar(map, cell)


## A room's pillar stands within PILLAR_CLEARANCE cells: a crate or a lamp there would leave a
## one-cell squeeze between it and the pillar (docs/design/dungeon.md "Pacing": two free cells
## at least between obstacles).
static func near_pillar(map: DungeonMap, cell: Vector2i) -> bool:
	if map.pillars.is_empty():
		return false
	for dy in range(-PILLAR_CLEARANCE, PILLAR_CLEARANCE + 1):
		for dx in range(-PILLAR_CLEARANCE, PILLAR_CLEARANCE + 1):
			if map.pillars.has(cell + Vector2i(dx, dy)):
				return true
	return false


## Next to a corridor mouth (floor outside the room): something there would block the way.
static func near_doorway(map: DungeonMap, room: Rect2i, cell: Vector2i) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var near := cell + Vector2i(dx, dy)
			if map.is_floor(near) and not room.has_point(near):
				return true
	return false


static func _reserve_rect(taken: Dictionary, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			taken[Vector2i(x, y)] = true


static func _reserve_around(taken: Dictionary, center: Vector2i, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			taken[center + Vector2i(dx, dy)] = true


static func _shuffled(cells: Array[Vector2i], rng: RandomNumberGenerator) -> Array[Vector2i]:
	var result := cells.duplicate()
	RandomUtils.shuffle(result, rng)
	return result


## A random point in the room, on free ground (not on a prop, a trap, a chest, a pond, a hole).
## `radius`: a body that must fit there (a monster: nothing that stops it within it, a pillar, a
## wall's corner, the water's edge); 0 for an item lying on the floor. `bodies`: monsters the
## body must not overlap (each by its radius + `radius`).
static func _free_point_in(world: World, room: Rect2i, rng: RandomNumberGenerator, taken: Dictionary, radius: float = 0.0, bodies: Array[Actor] = []) -> Vector2:
	var map := world.map
	var cell := map.random_cell_in(room, rng)
	for attempt in 12:
		if not taken.has(cell) and world.is_free_cell(cell):  # pillars of a themed room are walls
			var center := map.cell_to_world(cell)
			var at := center + Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0))
			if radius <= 0.0 or (_fits(world, at, radius) and not WorldSpace.is_under_body(at, bodies, radius)):
				return at
			if _fits(world, center, radius) and not WorldSpace.is_under_body(center, bodies, radius):
				return center
		cell = map.random_cell_in(room, rng)
	if radius > 0.0:
		# A big body in a round room, a crowded one: every free cell of the room, the first it fits in.
		var cells: Array[Vector2i] = []
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				var spot := Vector2i(x, y)
				if not taken.has(spot) and world.is_free_cell(spot):
					cells.append(spot)
		for spot in _shuffled(cells, rng):
			if _fits(world, map.cell_to_world(spot), radius) and not WorldSpace.is_under_body(map.cell_to_world(spot), bodies, radius):
				return map.cell_to_world(spot)
	return world.nearest_free_point(map.cell_to_world(cell), 12, bodies, radius)


## A body of `radius` fits at `point`: no wall, prop, pillar, pond or pool within it, by the
## physics (what is there already) and by the grid (what was put up this very frame: a blocked
## cell counts whole).
static func _fits(world: World, point: Vector2, radius: float) -> bool:
	if not world.body_fits(point, radius):
		return false
	var map := world.map
	var ts := float(map.tile_size)
	var reach := ceili(radius / ts) + 1
	var at := map.world_to_cell(point)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var cell := at + Vector2i(dx, dy)
			if map.is_floor(cell) and not world.nav.is_blocked(cell):
				continue
			var box := Rect2(Vector2(cell) * ts, Vector2(ts, ts))
			var nearest := Vector2(clampf(point.x, box.position.x, box.end.x), clampf(point.y, box.position.y, box.end.y))
			if nearest.distance_to(point) < radius:
				return false
	return true
