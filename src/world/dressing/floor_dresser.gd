class_name FloorDresser
## Dresses a floor in its biome (World.biome), the way the hand-made parts of Dead Cells or the
## "flavor machines" of Brogue do: never anything thrown about at random.
##   1. Grounds (GroundLayerDef): sand, moss... in organic patches shaped by noise, pushed toward
##      or away from the walls.
##   2. Scenes (SceneDef): little scenes made by hand, a few per room depending on its size,
##      each where its anchor says, never walling anything off.
##   3. Decor (DecorRuleDef): a few small things, each with a reason to be there (at the foot
##      of a wall, around a scene's furniture, on its ground); room middles and corridors clear.
## The first room (where the hero arrives) gets no scene. The floor tiles carry no decor of
## their own (DungeonTheme.decor_chance is 0 for biomes): all of it comes from here.

## The scenes put on the last floor dressed (SceneDef -> how many): for tests and the debug panel.
static var last_scenes := {}
## Texture -> the part of it that shows (Rect2, drawn at 2x, around the piece's centre).
static var _drawn_cache := {}
## The nudges tried to get a piece off the walls, nearest first (built once).
static var _nudges: Array[Vector2] = []


## `taken`: cells already used (see HazardDef). `with_scenes`: false in a boss arena.
## `kept_clear`: cells of `taken` kept free only to leave room around the pillars
## (FloorPopulator.PILLAR_CLEARANCE): a room shape's own scenes (a signature room's throne and
## rubble, made around its columns) may stand there, nothing else.
static func dress(world: World, taken: Dictionary, with_scenes: bool = true, kept_clear: Dictionary = {}) -> void:
	var biome := world.biome
	if biome == null:
		return
	var walls := wall_distance(world.map)
	for layer in biome.grounds:
		if layer:
			_lay_ground(world, layer, walls)
	var standing := {}  # cells of what the scenes put up
	if with_scenes:
		_place_scenes(world, biome, taken, standing, kept_clear)
	for rule in biome.decor:
		if rule and not rule.pieces.is_empty():
			_scatter(world, rule, walls, standing)


## Cells from each floor cell to the nearest wall (1 = touching one).
static func wall_distance(map: DungeonMap) -> Dictionary:
	# A breadth-first walk on the raw tiles (fast), then the cells in reading order.
	var w := map.width
	var h := map.height
	var tiles := map.tiles
	var floor_tile := DungeonMap.Tile.FLOOR
	var steps := PackedInt32Array()
	steps.resize(w * h)
	var queue := PackedInt32Array()
	for y in h:
		for x in w:
			var i := y * w + x
			if tiles[i] != floor_tile:
				continue
			if x == 0 or y == 0 or x == w - 1 or y == h - 1 or tiles[i - 1] != floor_tile or tiles[i + 1] != floor_tile \
					or tiles[i - w] != floor_tile or tiles[i + w] != floor_tile:
				steps[i] = 1
				queue.append(i)
	var head := 0
	var around := PackedInt32Array([0, 0, 0, 0])  # (one buffer: no array built per cell)
	while head < queue.size():
		var i := queue[head]
		head += 1
		var x := i % w
		around[0] = i - 1 if x > 0 else -1
		around[1] = i + 1 if x < w - 1 else -1
		around[2] = i - w
		around[3] = i + w
		for next in around:
			if next >= 0 and next < w * h and tiles[next] == floor_tile and steps[next] == 0:
				steps[next] = steps[i] + 1
				queue.append(next)
	var distance := {}
	for i in w * h:
		if steps[i] > 0:
			distance[Vector2i(i % w, int(i / float(w)))] = steps[i]
	return distance


## Noise plus the pull toward (or away from) the walls: higher = more likely there.
static func _score(noise: FastNoiseLite, cell: Vector2i, walls: Dictionary, wall_bias: float) -> float:
	var near_wall := 1.0 - clampf((float(walls.get(cell, 4)) - 1.0) / 3.0, 0.0, 1.0)
	return noise.get_noise_2d(cell.x, cell.y) + wall_bias * (near_wall - 0.5) * 1.2


static func _noise(rng: RandomNumberGenerator, scale: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = scale
	noise.fractal_octaves = 2
	return noise


static func _lay_ground(world: World, layer: GroundLayerDef, walls: Dictionary) -> void:
	var noise := _noise(world.rng, layer.noise_scale)
	# Never over a chasm or a pool (a shaped room's core).
	var floor_cells: Array = walls.keys().filter(func(cell: Vector2i) -> bool: return not world.map.features.has(cell))
	if floor_cells.is_empty():
		return
	var scores := PackedFloat32Array()
	scores.resize(floor_cells.size())
	for i in floor_cells.size():
		scores[i] = _score(noise, floor_cells[i], walls, layer.wall_bias)
	# The best `coverage` of the cells: above the score that many cells reach (a native sort).
	var keep := roundi(floor_cells.size() * layer.coverage)
	var cells := {}
	if keep > 0:
		var sorted := scores.duplicate()
		sorted.sort()
		var threshold := sorted[sorted.size() - keep]
		for i in floor_cells.size():
			if scores[i] >= threshold:
				cells[floor_cells[i]] = true
	# Smooth it out: no lone cells, no pinholes.
	for pass_index in 2:
		var smoothed := {}
		for cell: Vector2i in floor_cells:
			var around := 0
			for dir: Vector2i in GridDirs.FOUR:
				if cells.has(cell + dir):
					around += 1
			if (cells.has(cell) and around >= 2) or around >= 3:
				smoothed[cell] = true
		cells = smoothed
	if cells.is_empty():
		return
	world.grounds[layer] = cells
	var view := GroundLayer.new()
	view.setup(layer, world.map, cells)
	world.spawn_vfx(view)


static func _place_scenes(world: World, biome: BiomeDef, taken: Dictionary, standing: Dictionary, kept_clear: Dictionary = {}) -> void:
	if biome.scenes.is_empty():
		return
	var map := world.map
	var rng := world.rng
	var placed := {}  # SceneDef -> count on this floor
	last_scenes = placed
	var rooms := range(1, map.rooms.size())
	RandomUtils.shuffle(rooms, rng)
	for i: int in rooms:
		var room := map.rooms[i]
		var big := room.get_area() >= biome.big_room_area
		var wanted := rng.randi_range(biome.scenes_big_room.x, biome.scenes_big_room.y) if big \
			else rng.randi_range(biome.scenes_small_room.x, biome.scenes_small_room.y)
		# A shape's own scenes first (RoomShapeDef.scenes), in their order; a signature room has
		# only its own (it is that place, nothing else).
		var shape := map.plan(i).shape
		if shape:
			# (The room around its own pillars is the shape's to dress: kept clear for the others.)
			var opened: Array[Vector2i] = []
			if not shape.scenes.is_empty() and not kept_clear.is_empty():
				for y in range(room.position.y, room.end.y):
					for x in range(room.position.x, room.end.x):
						var cell := Vector2i(x, y)
						if kept_clear.has(cell) and taken.has(cell):
							taken.erase(cell)
							opened.append(cell)
			for scene in shape.scenes:
				if scene and scene.try_place(world, room, taken, rng, standing):
					placed[scene] = placed.get(scene, 0) + 1
					wanted -= 1
			for cell in opened:
				taken[cell] = true
			if shape.set_piece:
				wanted = 0
		var tries := wanted * 4
		while wanted > 0 and tries > 0:
			tries -= 1
			var scene := _pick_scene(biome, room, big, placed, world.depth, rng)
			if scene == null:
				break
			if scene.try_place(world, room, taken, rng, standing):
				placed[scene] = placed.get(scene, 0) + 1
				wanted -= 1


static func _pick_scene(biome: BiomeDef, room: Rect2i, big: bool, placed: Dictionary, depth: int, rng: RandomNumberGenerator) -> SceneDef:
	var fitting := biome.scenes.filter(func(scene: SceneDef) -> bool:
		if scene == null or (scene.max_per_floor > 0 and placed.get(scene, 0) >= scene.max_per_floor):
			return false
		if (scene.room_size == SceneDef.RoomSize.BIG and not big) or (scene.room_size == SceneDef.RoomSize.SMALL and big):
			return false
		var span := scene.size()
		return span.x <= room.size.x and span.y <= room.size.y)
	return ContentDB.pick_from(fitting, depth, rng) as SceneDef


static func _scatter(world: World, rule: DecorRuleDef, walls: Dictionary, standing: Dictionary) -> void:
	var map := world.map
	var rng := world.rng
	var noise := _noise(rng, rule.noise_scale)
	var on: Dictionary = world.grounds.get(rule.ground, {}) if rule.ground else {}
	var layer := DecorLayer.new()
	layer.z_index = -8
	layer.sway = rule.sway
	layer.world = world
	var used := {}
	var exits := map.exit_cells()
	for room in map.rooms:
		var spots: Array = []  # [noise, cell]
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				var cell := Vector2i(x, y)
				if not walls.has(cell) or used.has(cell) or world.nav.is_blocked(cell) \
						or cell == map.start_cell or exits.has(cell) or not _fits_rule(rule, cell, walls, standing, on):
					continue
				spots.append([noise.get_noise_2d(cell.x, cell.y), cell])
		# The noise's high spots first: pieces gather there.
		spots.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		var count := 0
		for spot: Array in spots:
			if count >= rule.max_per_room:
				break
			var cluster := (float(spot[0]) + 1.0) * 0.5
			if rng.randf() >= rule.density * lerpf(1.0, cluster * 2.0, rule.clumping):
				continue
			var cell: Vector2i = spot[1]
			used[cell] = true
			count += 1
			var at := map.cell_to_world(cell) + Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0))
			var piece := rule.pieces[rng.randi() % rule.pieces.size()]
			at = fit_on_floor(map, at.snapped(Vector2(2, 2)), piece)
			if at != Vector2.INF:
				layer.pieces.append([piece, at])
	if not layer.pieces.is_empty():
		world.spawn_vfx(layer)
	else:
		layer.free()


## Is `cell` a place for this rule's pieces?
static func _fits_rule(rule: DecorRuleDef, cell: Vector2i, walls: Dictionary, standing: Dictionary, on: Dictionary) -> bool:
	match rule.where:
		DecorRuleDef.Where.ALONG_WALLS:
			return walls[cell] == 1
		DecorRuleDef.Where.AROUND_SCENES:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if standing.has(cell + Vector2i(dx, dy)):
						return true
			return false
		DecorRuleDef.Where.ON_GROUND:
			return on.has(cell)
	return false


## Where a piece of decor drawn around `at` (its centre; DecorLayer draws it at 2x) lies wholly
## on the floor, nothing of it over a wall: `at` itself, or nudged off the walls it would cover,
## an art pixel at a time, up to half a tile. Vector2.INF if it fits nowhere near: left out.
static func fit_on_floor(map: DungeonMap, at: Vector2, texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.INF
	var drawn := drawn_rect(texture)
	if _nudges.is_empty():
		var reach := 16
		for y in range(-reach, reach + 1, 2):
			for x in range(-reach, reach + 1, 2):
				_nudges.append(Vector2(x, y))
		_nudges.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.length_squared() < b.length_squared())
	for nudge in _nudges:
		if nudge.length() > map.tile_size * 0.5:
			break
		if on_floor(map, Rect2(drawn.position + at + nudge, drawn.size)):
			return at + nudge
	return Vector2.INF


## Whether `rect` (world space) lies on floor cells only (an art pixel of slack at its edges).
static func on_floor(map: DungeonMap, rect: Rect2) -> bool:
	var inner := rect.grow(-2.0)
	var first := map.world_to_cell(inner.position)
	var last := map.world_to_cell(inner.end)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if not map.is_floor(Vector2i(x, y)):
				return false
	return true


## The part of `texture` that shows, drawn at 2x around the piece's centre: its opaque pixels
## when the image can be read (not in a headless run: then the whole picture, a safe bound).
static func drawn_rect(texture: Texture2D) -> Rect2:
	if _drawn_cache.has(texture):
		return _drawn_cache[texture]
	var size := texture.get_size() * 2.0
	var rect := Rect2(-size * 0.5, size)
	var image := texture.get_image() if DisplayServer.get_name() != "headless" else null
	if image and not image.is_empty():
		var used := image.get_used_rect()
		if used.has_area():
			rect = Rect2(Vector2(used.position) * 2.0 - size * 0.5, Vector2(used.size) * 2.0)
	_drawn_cache[texture] = rect
	return rect
