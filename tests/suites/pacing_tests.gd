class_name PacingTests
extends TestSuite
## The floors' rhythm (decision 0012, docs/design/dungeon.md "Pacing"): normal floors built from
## fixed seeds on three difficulties, then measured as the level probe measures them
## (FloorPacing): fights in a row on the way down, a treasure on every floor, monsters by the
## room's size, the peak and the release where they belong, rooms that keep apart instead of
## merging into sprawling halls, room left around pillars, a seal that can still be broken.

const WORLD_SCENE := "res://src/world/world.tscn"
## Normal floors measured: every difficulty below at each depth, for each seed.
const DIFFICULTIES: Array[StringName] = [&"easy", &"normal", &"nightmare"]
const DEPTHS: Array[int] = [2, 4, 7, 10]
const SEEDS := 2


func run_unit() -> void:
	var world := (load(WORLD_SCENE) as PackedScene).instantiate() as World
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	var config := CONTENT.dungeon
	var floors := 0
	var long_runs: Array[String] = []
	var no_chest: Array[String] = []
	var seal_out: Array[String] = []
	var squeezed: Array[String] = []
	var areas := PackedFloat64Array()
	var counts := PackedFloat64Array()
	var peaks := PackedFloat64Array()
	var releases := PackedFloat64Array()
	var halls := 0
	var merged_halls := 0
	var hall_sizes := PackedInt32Array()
	var bodies := {}  # difficulty -> monsters on its floors
	for difficulty_id in DIFFICULTIES:
		world.difficulty = CONTENT.get_difficulty(difficulty_id)
		bodies[difficulty_id] = 0
		for depth in DEPTHS:
			for s in SEEDS:
				world.rng.seed = hash("pacing-%s-%d-%d" % [difficulty_id, depth, s])
				world.build_floor(depth, CONTENT)
				if world.arena:
					continue
				floors += 1
				var case_name := "%s/%d/%d" % [difficulty_id, depth, s]
				var map := world.map
				var pacing := FloorPacing.new(map)
				var monsters := {}  # room -> monsters standing in it
				var chests := 0
				var standing: Array[Vector2i] = []  # props and chests, not the pillars
				for child in world._entities.get_children():
					var cell := map.world_to_cell((child as Node2D).global_position) if child is Node2D else Vector2i(-1, -1)
					if child is Monster:
						var room := map.room_at(cell)
						monsters[room] = int(monsters.get(room, 0)) + 1
						bodies[difficulty_id] += 1
					elif child is Chest:
						chests += 1
						standing.append(cell)
					elif child is Prop and not map.pillars.has(cell):
						standing.append(cell)
				# Calm: the start, rooms without monsters; but an ambush and a pact door are fights.
				var calm := {}
				for i in map.rooms.size():
					if not monsters.has(i):
						calm[i] = true
				var forced := _special_rooms(world)
				for i: int in forced:
					calm.erase(i)
				var run := pacing.longest_fight_run(calm)
				if run > config.max_fights_in_a_row:
					long_runs.append("%s: %d" % [case_name, run])
				if chests < 1:
					no_chest.append(case_name)
				if world.seal.needed > world.monster_count():
					seal_out.append("%s: %d of %d" % [case_name, world.seal.needed, world.monster_count()])
				for i in range(1, map.rooms.size()):
					if monsters.has(i) and not forced.has(i):
						areas.append(FloorPopulator.ground_cells(map, map.rooms[i]))
						counts.append(int(monsters[i]))
				for i: int in forced:
					peaks.append(pacing.progress.get(i, 0.0))
				for node in world._entities.get_children():
					if node is Merchant or node is Forge:
						releases.append(pacing.progress.get(map.room_at(map.world_to_cell((node as Node2D).global_position)), 0.0))
				for cell in standing:
					for pillar: Vector2i in map.pillars:
						if maxi(absi(cell.x - pillar.x), absi(cell.y - pillar.y)) <= FloorPopulator.PILLAR_CLEARANCE:
							squeezed.append("%s: %s by the pillar %s" % [case_name, cell, pillar])
							break
				var hall_facts := _halls(map, hall_sizes)
				halls += hall_facts.x
				merged_halls += hall_facts.y
	check(floors >= 20, "normal floors measured (%d)" % floors)
	check(long_runs.is_empty(), "never more than %d fight rooms in a row on the way to any stairs, ambushes and pact doors counted (%s)" % [config.max_fights_in_a_row, ", ".join(long_runs.slice(0, 4))])
	check(no_chest.is_empty(), "a treasure on every floor: a chest at least (%s)" % ", ".join(no_chest.slice(0, 4)))
	check(seal_out.is_empty(), "the seal asks for no more kills than the floor has monsters (%s)" % ", ".join(seal_out.slice(0, 4)))
	var r := _pearson(areas, counts)
	check(r >= 0.5, "monsters follow the room's size: r(open cells, monsters) = %.2f over %d fight rooms (0.02 before decision 0012)" % [r, areas.size()])
	var peak := _median(peaks)
	check(peaks.size() >= 5 and peak >= config.peak_from - 0.1 and peak <= config.peak_to + 0.1, "ambushes and pact doors stand at the peak, about %.0f-%.0f%% of the way (median %.2f of %d)" % [config.peak_from * 100.0, config.peak_to * 100.0, peak, peaks.size()])
	var release := _median(releases)
	check(releases.size() >= 5 and release >= config.peak_to - 0.05, "the merchant and the forge come after the peak (median %.2f of the way, %d)" % [release, releases.size()])
	check(squeezed.is_empty(), "two free cells at least between a pillar and a crate, lamp, chest or furniture (%s)" % ", ".join(squeezed.slice(0, 3)))
	# Rooms kept 3 cells apart: smooth() no longer opens the rock between them into one sprawl.
	# (Before decision 0012, on these difficulties: 31% of the open spaces held two rooms or more,
	# p90 62 cells across; after, 21% and 50.)
	var share := float(merged_halls) / maxf(halls, 1.0)
	hall_sizes.sort()
	var p90 := hall_sizes[int(hall_sizes.size() * 0.9)] if not hall_sizes.is_empty() else 0
	check(share <= 0.26, "few rooms merged into one open space: %.0f%% of %d (31%% before)" % [share * 100.0, halls])
	check(p90 <= 56, "the open spaces stay about room-sized: p90 %d cells across (62 before)" % p90)
	# The floor's monsters as before the rooms were counted by size (the probe's 960 floors:
	# Pilgrim 47, Keeper 65, Nightmare 97 a floor): the same fight, spread by the rooms' sizes.
	var per_floor := float(floors) / DIFFICULTIES.size()
	for difficulty_id: StringName in [&"easy", &"nightmare"]:
		var mean := float(bodies[difficulty_id]) / maxf(per_floor, 1.0)
		var wanted := 47.0 if difficulty_id == &"easy" else 97.0
		check(absf(mean - wanted) <= wanted * 0.25, "%s floors hold about as many monsters as before (%.0f, %.0f before)" % [difficulty_id, mean, wanted])
	world.clear_floor()
	remove_child(world)
	world.free()


## Rooms that hold a fight whatever their monsters: the ambush, the pact door, the sealed trial.
func _special_rooms(world: World) -> Dictionary:
	var rooms := {}
	var map := world.map
	if world.ambush:
		rooms[map.rooms.find(world.ambush.room)] = true
	if world.pact:
		for step: Vector2i in GridDirs.FOUR:
			var room := map.room_at(world.pact.door_cell + step)
			if room > 0:
				rooms[room] = true
				break
	if world.room_trial is SealTrial:
		rooms[map.rooms.find((world.room_trial as SealTrial).room)] = true
	rooms.erase(-1)
	return rooms


## The floor's open spaces as the level probe finds them: floor eroded by 2 cells (3-wide
## corridors vanish), each piece's room hearts counted. (pieces, pieces holding 2 hearts or more);
## each piece's size across (its width or height, the larger) added to `sizes`.
func _halls(map: DungeonMap, sizes: PackedInt32Array) -> Vector2i:
	var w := map.width
	var core := PackedByteArray()
	core.resize(w * map.height)
	for y in range(2, map.height - 2):
		for x in range(2, w - 2):
			var open := true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if not map.is_floor(Vector2i(x + dx, y + dy)):
						open = false
						break
				if not open:
					break
			core[y * w + x] = 1 if open else 0
	var hearts := {}
	for i in map.rooms.size():
		hearts[map.heart(i)] = true
	var pieces := 0
	var merged := 0
	var seen := PackedByteArray()
	seen.resize(core.size())
	for start in core.size():
		if core[start] == 0 or seen[start] == 1:
			continue
		pieces += 1
		var in_it := 0
		var low := Vector2i(w, map.height)
		var high := Vector2i(-1, -1)
		var queue := PackedInt32Array([start])
		seen[start] = 1
		var head := 0
		while head < queue.size():
			var at := queue[head]
			head += 1
			var cell := Vector2i(at % w, int(at / float(w)))
			low = low.min(cell)
			high = high.max(cell)
			if hearts.has(cell):
				in_it += 1
			for step: Vector2i in GridDirs.FOUR:
				var next := cell + step
				var index := next.y * w + next.x
				if map.in_bounds(next) and core[index] == 1 and seen[index] == 0:
					seen[index] = 1
					queue.append(index)
		if in_it >= 2:
			merged += 1
		sizes.append(maxi(high.x - low.x, high.y - low.y) + 5)
	return Vector2i(pieces, merged)


static func _pearson(xs: PackedFloat64Array, ys: PackedFloat64Array) -> float:
	var n := xs.size()
	if n < 2:
		return 0.0
	var mx := 0.0
	var my := 0.0
	for i in n:
		mx += xs[i]
		my += ys[i]
	mx /= n
	my /= n
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in n:
		sxy += (xs[i] - mx) * (ys[i] - my)
		sxx += (xs[i] - mx) * (xs[i] - mx)
		syy += (ys[i] - my) * (ys[i] - my)
	return sxy / sqrt(maxf(sxx * syy, 0.000001))


static func _median(values: PackedFloat64Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[int(sorted.size() / 2.0)]
