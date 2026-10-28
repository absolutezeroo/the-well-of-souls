class_name DungeonGenerator
## Builds a DungeonMap: random non-overlapping rooms chained by wide corridors.
## Each room connects to the previous one, so every room is reachable; rooms keep
## DungeonConfig.room_gap cells of rock between them (closer, smooth() would open the wall and
## merge them), and a corridor bends the way that cuts through fewer other rooms. A room may take one of
## its biome's shapes (RoomShapeDef: round, pillared, a ring, a chasm crossed by walkways...):
## its outline is carved first, the corridors cut through it, then its core and pillars are laid
## and anything that would cut floor off is taken back (_finish).


## `size_scale`, `room_scale`: the difficulty's (DifficultyDef.floor_size, rooms). `biome`: the
## floor's world, whose rooms take its shapes (BiomeDef.room_shapes) and now and then its
## signature room (BiomeDef.set_pieces); null: plain rectangles. `depth`: for the shapes' min_depth.
static func generate(config: DungeonConfig, rng: RandomNumberGenerator, size_scale: float = 1.0, room_scale: float = 1.0, biome: BiomeDef = null, depth: int = 1) -> DungeonMap:
	var width := roundi(config.width * size_scale)
	var height := roundi(config.height * size_scale)
	var max_rooms := maxi(roundi(config.max_rooms * room_scale), 2)
	var map := DungeonMap.new(width, height, config.tile_size)
	var shaper := RoomShaper.new(biome, depth, rng)
	var limit := Vector2i(width - 6, height - 6)

	for attempt in max_rooms * 12:
		if map.rooms.size() >= max_rooms:
			break
		var shape := shaper.pick(map.rooms.size())
		var size := shape.pick_size(rng, limit) if shape else Vector2i(
			rng.randi_range(config.room_min_size, config.room_max_size),
			rng.randi_range(config.room_min_size, config.room_max_size))
		var room := Rect2i(
			Vector2i(rng.randi_range(2, width - size.x - 2), rng.randi_range(2, height - size.y - 2)),
			size)
		if _overlaps_any(room, map.rooms, config.room_gap):
			shaper.missed(shape)
			continue

		var room_plan := shaper.plan(room, shape)
		_carve_room(map, room_plan)
		if not map.rooms.is_empty():
			_carve_corridor(map, map.rooms.back().get_center(), room.get_center(), config.corridor_width, rng, map.rooms)
		map.rooms.append(room)
		map.plans.append(room_plan)
		shaper.placed(shape)

	_finish(map)
	map.start_cell = map.heart(0)
	map.stairs_cell = map.heart(_farthest_room(map))
	map.second_stairs_cell = _second_exit(map)
	map.secrets = SecretRoomPlan.plan_all(map, config, secret_rng(rng))
	return map


## A small closed maze (the Deeps, AbyssDef): up to `room_count` rooms between `room_size.x` and
## `room_size.y` cells wide, chained by corridors in a `size` map; the start in the first room,
## the way out (`stairs_cell`) in the room farthest from it. No secrets, no second way.
## `biome`: the shapes its rooms may take (no signature room down there).
static func generate_small(size: Vector2i, room_count: int, room_size: Vector2i, corridor_width: int, tile_size: int, rng: RandomNumberGenerator, biome: BiomeDef = null) -> DungeonMap:
	var map := DungeonMap.new(size.x, size.y, tile_size)
	var shaper := RoomShaper.new(biome, 1, rng, false)
	var limit := Vector2i(mini(size.x - 6, room_size.y + 4), mini(size.y - 6, room_size.y + 4))
	for attempt in room_count * 30:
		if map.rooms.size() >= room_count:
			break
		var shape := shaper.pick(map.rooms.size())
		var room_cells := shape.pick_size(rng, limit) if shape else Vector2i(rng.randi_range(room_size.x, room_size.y), rng.randi_range(room_size.x, room_size.y))
		if room_cells.x + 4 > size.x or room_cells.y + 4 > size.y:
			continue
		var room := Rect2i(
			Vector2i(rng.randi_range(2, size.x - room_cells.x - 2), rng.randi_range(2, size.y - room_cells.y - 2)),
			room_cells)
		if _overlaps_any(room, map.rooms):
			continue
		var room_plan := shaper.plan(room, shape)
		_carve_room(map, room_plan)
		if not map.rooms.is_empty():
			_carve_corridor(map, map.rooms.back().get_center(), room.get_center(), corridor_width, rng)
		map.rooms.append(room)
		map.plans.append(room_plan)
		shaper.placed(shape)
	_finish(map)
	map.start_cell = map.heart(0)
	map.stairs_cell = _farthest_walk(map)
	return map


## Picks the rooms' shapes for one floor: the first room (where the hero arrives) a plain
## rectangle; then the biome's signature room first if the floor gets one; then any of its
## shapes, or a plain rectangle, by weight, each no more often than its `max_per_floor`.
class RoomShaper:
	var biome: BiomeDef
	var depth: int
	var rng: RandomNumberGenerator
	## The signature room still to place (null: none on this floor, or placed already).
	var set_piece: RoomShapeDef
	var set_piece_tries := 0
	var counts := {}  # RoomShapeDef -> rooms of it so far

	func _init(world_biome: BiomeDef, floor_depth: int, random: RandomNumberGenerator, with_set_piece: bool = true) -> void:
		biome = world_biome
		depth = floor_depth
		rng = random
		if biome and with_set_piece and not biome.set_pieces.is_empty() and rng.randf() < biome.set_piece_chance:
			set_piece = ContentDB.pick_from(biome.set_pieces, depth, rng) as RoomShapeDef

	## The shape of the next room (`index`: how many rooms there are already); null: a rectangle.
	func pick(index: int) -> RoomShapeDef:
		if biome == null or index == 0:
			return null
		if set_piece and set_piece_tries < 40:
			return set_piece
		var candidates: Array = [null]
		var weights := PackedInt32Array([biome.plain_weight])
		for shape in biome.room_shapes:
			if shape == null or shape.min_depth > depth or shape.spawn_weight <= 0:
				continue
			if shape.max_per_floor > 0 and counts.get(shape, 0) >= shape.max_per_floor:
				continue
			candidates.append(shape)
			weights.append(shape.spawn_weight)
		var total := 0
		for weight in weights:
			total += maxi(weight, 0)
		if total <= 0:
			return null
		var roll := rng.randi_range(1, total)
		for i in candidates.size():
			roll -= maxi(weights[i], 0)
			if roll <= 0:
				return candidates[i]
		return null

	## A room of `shape` didn't fit where it was tried.
	func missed(shape: RoomShapeDef) -> void:
		if shape and shape == set_piece:
			set_piece_tries += 1

	func placed(shape: RoomShapeDef) -> void:
		if shape == null:
			return
		counts[shape] = counts.get(shape, 0) + 1
		if shape == set_piece:
			set_piece = null

	## The plan of a room of `shape` at `room`: an L leaves out a random corner.
	func plan(room: Rect2i, shape: RoomShapeDef) -> RoomPlan:
		var flip := Vector2i.ONE
		if shape and shape.outline == RoomShapeDef.Outline.L_SHAPE:
			flip = Vector2i(1 if rng.randf() < 0.5 else -1, 1 if rng.randf() < 0.5 else -1)
		return RoomPlan.new(room, shape, flip)


## Carves a room's outline (corridors cut through whatever they cross afterwards).
static func _carve_room(map: DungeonMap, room_plan: RoomPlan) -> void:
	if room_plan.shape == null:
		_carve_rect(map, room_plan.rect)
		return
	var rect := room_plan.rect
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if room_plan.has_cell(Vector2i(x, y)):
				map.set_floor(Vector2i(x, y))


## Once every corridor is dug: the rooms' cores and pillars, the walls smoothed, the hearts found,
## and any core or pillars that cut a piece of floor off taken back.
static func _finish(map: DungeonMap) -> void:
	var rock := {}  # room index -> the cells its core turned to rock
	for i in map.plans.size():
		rock[i] = _lay_core(map, i)
	smooth(map)
	for attempt in map.rooms.size() + 1:
		_find_hearts(map)
		var cut_off := _cut_off(map)
		if cut_off.is_empty():
			return
		# Undo the shaped rooms the floor that can't be reached lies in (or right by).
		var undone := false
		for i in map.plans.size():
			var shape := map.plans[i].shape
			if shape == null or (shape.core == RoomShapeDef.Core.NONE and shape.pillars == RoomShapeDef.Pillars.NONE):
				continue
			var bounds := map.rooms[i].grow(2)
			if not cut_off.any(func(cell: Vector2i) -> bool: return bounds.has_point(cell)):
				continue
			if _undo_core(map, i, rock.get(i, [])):
				undone = true
		if not undone:
			_find_hearts(map)
			return  # (not a shape's doing: the plain generator never cuts anything off)


## Lays room `index`'s core and pillars; returns the cells turned to rock.
static func _lay_core(map: DungeonMap, index: int) -> Array[Vector2i]:
	var rocks: Array[Vector2i] = []
	var room_plan := map.plans[index]
	var shape := room_plan.shape
	if shape == null:
		return rocks
	var rect := room_plan.rect
	if shape.core != RoomShapeDef.Core.NONE:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				if not map.is_floor(cell):
					continue
				match shape.core_at(cell - rect.position, rect.size):
					RoomShapeDef.Core.ROCK:
						map.tiles[y * map.width + x] = DungeonMap.Tile.WALL
						rocks.append(cell)
					RoomShapeDef.Core.CHASM:
						map.features[cell] = DungeonMap.Feature.CHASM
					RoomShapeDef.Core.POOL:
						map.features[cell] = DungeonMap.Feature.POOL
	for local in shape.pillar_cells(rect.size, room_plan.flip):
		var cell := rect.position + local
		if map.is_floor(cell) and not map.features.has(cell):
			map.pillars[cell] = index
	return rocks


## Takes back room `index`'s core and pillars: plain floor again. False if it had none left.
static func _undo_core(map: DungeonMap, index: int, rocks: Array) -> bool:
	var changed := not rocks.is_empty()
	for cell: Vector2i in rocks:
		map.set_floor(cell)
	rocks.clear()
	var rect := map.rooms[index]
	for cell: Vector2i in map.features.keys():
		if rect.has_point(cell):
			map.features.erase(cell)
			changed = true
	for cell: Vector2i in map.pillars.keys():
		if map.pillars[cell] == index:
			map.pillars.erase(cell)
			changed = true
	return changed


## Every room's heart: the ground cell nearest its middle, with ground all around it if it can.
static func _find_hearts(map: DungeonMap) -> void:
	for i in map.rooms.size():
		var room_plan := map.plan(i)
		var rect := room_plan.rect
		var middle := Vector2(rect.position) + Vector2(rect.size) * 0.5 - Vector2(0.5, 0.5)
		var best := rect.get_center()
		var best_score := INF
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				if not map.is_ground(cell):
					continue
				var score := Vector2(cell).distance_squared_to(middle)
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if not map.is_ground(cell + Vector2i(dx, dy)):
							score += 1000.0  # cramped: only if nothing roomier
				if score < best_score:
					best_score = score
					best = cell
		room_plan.heart = best


## Ground that can't be walked to from the first room's heart (a chasm, a pool or pillars in the
## way): empty when the whole floor is one piece.
static func _cut_off(map: DungeonMap) -> Array[Vector2i]:
	var w := map.width
	var seen := PackedByteArray()
	seen.resize(w * map.height)
	var start := map.heart(0)
	var queue: Array[Vector2i] = [start]
	seen[start.y * w + start.x] = 1
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for step: Vector2i in GridDirs.FOUR:
			var next := cell + step
			if map.is_ground(next) and seen[next.y * w + next.x] == 0:
				seen[next.y * w + next.x] = 1
				queue.append(next)
	var cut: Array[Vector2i] = []
	for y in map.height:
		for x in w:
			if seen[y * w + x] == 0 and map.is_ground(Vector2i(x, y)):
				cut.append(Vector2i(x, y))
	return cut


## The middle of the room farthest from the start on foot (not as the crow flies: the way out of
## a maze is at the end of its longest walk).
static func _farthest_walk(map: DungeonMap) -> Vector2i:
	var steps := {map.start_cell: 0}
	var open: Array[Vector2i] = [map.start_cell]
	var at := 0
	while at < open.size():
		var cell := open[at]
		at += 1
		for step: Vector2i in GridDirs.FOUR:
			var next := cell + step
			if not steps.has(next) and map.is_ground(next):
				steps[next] = steps[cell] + 1
				open.append(next)
	var best := map.heart(_farthest_room(map))
	var best_steps := -1
	for i in map.rooms.size():
		var center := map.heart(i)
		if steps.get(center, -1) > best_steps:
			best_steps = steps[center]
			best = center
	return best


## The floor's own stream for its secrets, drawn from the floor's seed without touching `rng`:
## the rest of the floor (monsters, chests...) comes out the same with or without them.
static func secret_rng(rng: RandomNumberGenerator) -> RandomNumberGenerator:
	var secret := RandomNumberGenerator.new()
	secret.seed = hash("secrets-%d" % rng.seed)
	return secret


## Boss floor: a small start room and one big arena, joined by a single corridor
## (so the arena has only one entrance to close). The stairs appear in the arena later.
## `plan`: the arena's size and shape (ArenaDef); without one, a plain room of config.arena_size.
static func generate_arena(config: DungeonConfig, rng: RandomNumberGenerator, plan: ArenaDef = null) -> DungeonMap:
	var map := DungeonMap.new(config.width, config.height, config.tile_size)
	var arena_size := plan.size if plan else config.arena_size
	arena_size = Vector2i(mini(arena_size.x, config.width - 22), mini(arena_size.y, config.height - 8))
	var arena := Rect2i(
		Vector2i(config.width - arena_size.x - rng.randi_range(4, 8), int((config.height - arena_size.y) / 2.0) + rng.randi_range(-4, 4)),
		arena_size)
	var start := Rect2i(Vector2i(rng.randi_range(4, 8), arena.get_center().y - 3 + rng.randi_range(-8, 8)), Vector2i(7, 7))
	_carve_rect(map, start)
	if plan:
		for cell in plan.cells(arena.position):
			map.set_floor(cell)
	else:
		_carve_rect(map, arena)
	_carve_corridor(map, start.get_center(), arena.get_center(), config.corridor_width, rng)
	smooth(map)
	map.rooms.append(start)
	map.rooms.append(arena)
	map.boss_room = arena
	map.start_cell = start.get_center()
	map.stairs_cell = arena.get_center()
	# The second way down, beside the first once the boss falls.
	for offset in [Vector2i(5, 0), Vector2i(-5, 0), Vector2i(0, 4), Vector2i(0, -4)]:
		if map.is_floor(map.stairs_cell + offset) and arena.has_point(map.stairs_cell + offset):
			map.second_stairs_cell = map.stairs_cell + offset
			break
	return map


## The hidden floor (HiddenFloorDef): a start room and `room_count` rooms in a row on the left,
## then one arena on the right, joined by a single corridor (one entrance to close, like a boss
## floor; a way through the dark first). `plan`: the arena's size and shape.
static func generate_hidden(config: DungeonConfig, rng: RandomNumberGenerator, plan: ArenaDef, room_count: int) -> DungeonMap:
	var map := DungeonMap.new(config.width, config.height, config.tile_size)
	var arena_size := plan.size if plan else config.arena_size
	arena_size = Vector2i(mini(arena_size.x, int(config.width / 2.0) - 4), mini(arena_size.y, config.height - 12))
	var arena := Rect2i(
		Vector2i(config.width - arena_size.x - 4, int((config.height - arena_size.y) / 2.0) + rng.randi_range(-6, 6)),
		arena_size)
	var right := arena.position.x - 6  # the rooms keep to the left of this
	var rooms: Array[Rect2i] = [Rect2i(Vector2i(4, int(config.height / 2.0) - 3 + rng.randi_range(-12, 12)), Vector2i(7, 7))]
	for attempt in room_count * 40:
		if rooms.size() > room_count:
			break
		var size := Vector2i(
			rng.randi_range(config.room_min_size, mini(config.room_max_size, 11)),
			rng.randi_range(config.room_min_size, mini(config.room_max_size, 11)))
		if right - size.x <= 12:
			continue
		var room := Rect2i(Vector2i(rng.randi_range(12, right - size.x), rng.randi_range(3, config.height - size.y - 3)), size)
		if not _overlaps_any(room, rooms):
			rooms.append(room)
	# Left to right, so the way leads on toward the arena.
	var ahead := rooms.slice(1)
	ahead.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.position.x < b.position.x)
	var ordered: Array[Rect2i] = [rooms[0]]
	ordered.append_array(ahead)
	rooms = ordered
	for i in rooms.size():
		_carve_rect(map, rooms[i])
		if i > 0:
			_carve_corridor(map, rooms[i - 1].get_center(), rooms[i].get_center(), config.corridor_width, rng)
	if plan:
		for cell in plan.cells(arena.position):
			map.set_floor(cell)
	else:
		_carve_rect(map, arena)
	_carve_corridor(map, rooms[rooms.size() - 1].get_center(), arena.get_center(), config.corridor_width, rng)
	smooth(map)
	map.rooms = rooms
	map.rooms.append(arena)
	map.boss_room = arena
	map.start_cell = rooms[0].get_center()
	map.stairs_cell = arena.get_center()
	for offset in [Vector2i(5, 0), Vector2i(-5, 0), Vector2i(0, 4), Vector2i(0, -4)]:
		if map.is_floor(map.stairs_cell + offset) and arena.has_point(map.stairs_cell + offset):
			map.second_stairs_cell = map.stairs_cell + offset
			break
	return map


## Walls between two floors thinner than this (in cells, across or along) read as flimsy
## fences, not rock: they are opened up.
const MIN_WALL_THICKNESS := 3


## Removes wall shapes the cliff tiles can't draw or that look wrong: walls thinner than
## MIN_WALL_THICKNESS with floor on both sides, and walls touching each other only by a corner
## (checkerboard). They become floor. The outer border always stays solid.
static func smooth(map: DungeonMap) -> void:
	# A work list instead of whole-map passes: only the walls near a cell just opened are looked
	# at again (a thin run is at most MIN_WALL_THICKNESS long). Same rules, a fraction of the time.
	var w := map.width
	var h := map.height
	var tiles := map.tiles
	var floor_tile := DungeonMap.Tile.FLOOR
	var queued := PackedByteArray()
	queued.resize(w * h)
	var queue := PackedInt32Array()
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var i := y * w + x
			if tiles[i] != floor_tile and _floor_in_reach(tiles, w, h, x, y):
				queue.append(i)
				queued[i] = 1
	var reach := MIN_WALL_THICKNESS
	while not queue.is_empty():
		var i := queue[queue.size() - 1]
		queue.resize(queue.size() - 1)
		queued[i] = 0
		if tiles[i] == floor_tile:
			continue
		var x := i % w
		var y := int(i / float(w))
		if not (_thin(tiles, w, h, x, y, 1, 0) or _thin(tiles, w, h, x, y, 0, 1) or _pinched(tiles, w, h, x, y)):
			continue
		tiles[i] = floor_tile
		for ny in range(maxi(y - reach, 1), mini(y + reach + 1, h - 1)):
			for nx in range(maxi(x - reach, 1), mini(x + reach + 1, w - 1)):
				var n := ny * w + nx
				if tiles[n] != floor_tile and queued[n] == 0:
					queue.append(n)
					queued[n] = 1
	map.tiles = tiles


## A floor cell 1 or 2 steps away along an axis (or diagonal): the only walls smooth() may open.
static func _floor_in_reach(tiles: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	for dy in range(-2, 3):
		var ny := y + dy
		if ny < 0 or ny >= h:
			continue
		for dx in range(-2, 3):
			var nx := x + dx
			if nx >= 0 and nx < w and tiles[ny * w + nx] == DungeonMap.Tile.FLOOR:
				return true
	return false


## is_thin_wall() on the raw tiles (smooth() calls it thousands of times).
static func _thin(tiles: PackedByteArray, w: int, h: int, x: int, y: int, ax: int, ay: int) -> bool:
	var run := 1
	for side_sign in [1, -1]:
		var nx: int = x + ax * side_sign
		var ny: int = y + ay * side_sign
		while true:
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				return false  # the border
			if tiles[ny * w + nx] == DungeonMap.Tile.FLOOR:
				break
			if run >= MIN_WALL_THICKNESS:
				return false  # thick enough
			run += 1
			nx += ax * side_sign
			ny += ay * side_sign
	return run < MIN_WALL_THICKNESS


## _is_pinch() on the raw tiles (outside the map counts as wall).
static func _pinched(tiles: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	for dx in GridDirs.SIGNS:
		for dy in GridDirs.SIGNS:
			var cx: int = x + dx
			var cy: int = y + dy
			var diagonal_wall := cx < 0 or cy < 0 or cx >= w or cy >= h or tiles[cy * w + cx] != DungeonMap.Tile.FLOOR
			if diagonal_wall and _is_open(tiles, w, h, cx, y) and _is_open(tiles, w, h, x, cy):
				return true
	return false


static func _is_open(tiles: PackedByteArray, w: int, h: int, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h and tiles[y * w + x] == DungeonMap.Tile.FLOOR


## Wall cell in a run of walls (along `axis`) with floor at both ends, shorter than
## MIN_WALL_THICKNESS.
static func is_thin_wall(map: DungeonMap, cell: Vector2i, axis: Vector2i) -> bool:
	var run := 1
	for direction: Vector2i in [axis, -axis]:
		var next := cell + direction
		while not map.is_floor(next):
			if not map.in_bounds(next) or run >= MIN_WALL_THICKNESS:
				return false  # the border, or thick enough
			run += 1
			next += direction
	return run < MIN_WALL_THICKNESS


## Wall cell whose diagonal neighbour is a wall while both cells between them are floor.
static func _is_pinch(map: DungeonMap, cell: Vector2i) -> bool:
	for dx in GridDirs.SIGNS:
		for dy in GridDirs.SIGNS:
			var diagonal := cell + Vector2i(dx, dy)
			if not map.is_floor(diagonal) and map.is_floor(cell + Vector2i(dx, 0)) and map.is_floor(cell + Vector2i(0, dy)):
				return true
	return false


## `room` comes closer than `gap` cells to one of `rooms`.
static func _overlaps_any(room: Rect2i, rooms: Array[Rect2i], gap: int = 2) -> bool:
	for other in rooms:
		if room.grow(gap).intersects(other):
			return true
	return false


static func _carve_rect(map: DungeonMap, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			map.set_floor(Vector2i(x, y))


## L-shaped corridor: horizontal then vertical, or the other way round. With `rooms` (the ones
## already laid), the bend that cuts through fewer of the other rooms' cells (or brushes their
## walls: smooth() would open the thin rock between and merge them); the dice when both cross as
## many.
static func _carve_corridor(map: DungeonMap, from: Vector2i, to: Vector2i, corridor_width: int, rng: RandomNumberGenerator, rooms: Array[Rect2i] = []) -> void:
	var across := Vector2i(to.x, from.y)
	var down := Vector2i(from.x, to.y)
	var corner := across if rng.randf() < 0.5 else down
	if not rooms.is_empty():
		var through_across := _cells_through(from, across, to, corridor_width, rooms)
		var through_down := _cells_through(from, down, to, corridor_width, rooms)
		if through_across != through_down:
			corner = across if through_across < through_down else down
	_carve_line(map, from, corner, corridor_width)
	_carve_line(map, corner, to, corridor_width)


## Cells of a corridor from `from` by `corner` to `to`, a cell wider each side, inside one of
## `rooms` other than the ones holding `from` and `to`.
static func _cells_through(from: Vector2i, corner: Vector2i, to: Vector2i, corridor_width: int, rooms: Array[Rect2i]) -> int:
	var count := 0
	var half := floori(corridor_width / 2.0) + 1
	for room in rooms:
		if room.has_point(from) or room.has_point(to):
			continue
		for leg: Array in [[from, corner], [corner, to]]:
			var a: Vector2i = leg[0]
			var b: Vector2i = leg[1]
			var band := Rect2i(a.min(b) - Vector2i.ONE * half, (a - b).abs() + Vector2i.ONE * (half * 2 + 1))
			count += band.intersection(room).get_area()
	return count


static func _carve_line(map: DungeonMap, from: Vector2i, to: Vector2i, corridor_width: int) -> void:
	var step := (to - from).sign()
	var low := -floori(corridor_width / 2.0)
	var high := low + corridor_width
	var cell := from
	while true:
		for dy in range(low, high):
			for dx in range(low, high):
				var c := cell + Vector2i(dx, dy)
				# Keep a solid border so the dungeon is always closed.
				if c.x >= 1 and c.y >= 1 and c.x < map.width - 1 and c.y < map.height - 1:
					map.set_floor(c)
		if cell == to:
			break
		cell += step


## The second way down: the room farthest from both the start and the first stairs (no rng:
## the rest of the floor comes out the same). NO_CELL if no room is far enough from both.
static func _second_exit(map: DungeonMap) -> Vector2i:
	var best := DungeonMap.NO_CELL
	var best_distance := 12.0  # cells, at least, from the start and from the first stairs
	for i in range(1, map.rooms.size()):
		var center := map.heart(i)
		if map.rooms[i].has_point(map.stairs_cell) or not map.is_ground(center):
			continue
		var distance := minf(Vector2(center).distance_to(Vector2(map.start_cell)), Vector2(center).distance_to(Vector2(map.stairs_cell)))
		if distance > best_distance:
			best_distance = distance
			best = center
	return best


## The index of the room whose heart is farthest from the start.
static func _farthest_room(map: DungeonMap) -> int:
	var best := 0
	var best_distance := -1.0
	for i in map.rooms.size():
		var distance := Vector2(map.heart(i)).distance_to(Vector2(map.start_cell))
		if distance > best_distance:
			best_distance = distance
			best = i
	return best
