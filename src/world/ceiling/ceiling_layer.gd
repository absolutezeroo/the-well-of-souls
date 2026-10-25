class_name CeilingLayer
extends Node2D
## What hangs over a floor's rooms (BiomeDef.ceiling, a CeilingDef): roots, chains, banners,
## arches... drawn over the actors (z Z: over the bodies, under the floor's light so the room
## lights them, under the wall mist and the shots), and dithered away around every body under
## them (ceiling.gdshader), so the hero and the monsters always read. Their shadows lie on the
## floor (z SHADOW_Z, under the bodies).
##
## Laid once when the floor is built (build()), from the floor's own stream of its seed: the
## same floor, the same ceiling. Drawn in chunks of CHUNK cells, each one canvas item over one
## atlas (a draw call or so each; off-screen chunks are skipped by the renderer); every frame
## only the bodies' places are handed to the shader. Cosmetic: nothing of it in a simulation
## (Vfx.shown off).

## Over the actors (Entities z 0), under the floor's light (LightField.Z 3) and the mist (4).
const Z := 2
## The shadows: on the floor, under the bodies, over the grounds and the splats.
const SHADOW_Z := -6
## Cells on a chunk's side.
const CHUNK := 12
## Bodies the shader looks at (the hero first, then the nearest).
const MAX_BODIES := 16
const SHADER := preload("res://src/world/ceiling/ceiling.gdshader")


## One square of the ceiling: its pieces (or their shadows), drawn by the layer.
class Chunk:
	extends Node2D
	var layer: CeilingLayer
	var pieces: Array = []
	var shadows := false

	func _draw() -> void:
		if shadows:
			layer.draw_shadows(self, pieces)
		else:
			layer.draw_pieces(self, pieces)


## A piece laid on the floor: where it is drawn and its shadow.
class Laid:
	var def: CeilingPieceDef
	## The picture's rectangles in the atlas and in the world (an ACROSS piece has several).
	var sources: Array[Rect2] = []
	var targets: Array[Rect2] = []
	var flip := false
	## Its shadow (a flat ellipse or band on the floor); no size: none.
	var shadow := Rect2()
	## The floor right under it (screenshots, tests).
	var under := Vector2.ZERO


var def: CeilingDef
var laid: Array[Laid] = []
## The bodies handed to the shader this frame (feet, radius, height): for the tests.
var bodies := PackedVector4Array()
## Fixed nearest-body and upload buffers; steady frames allocate and upload nothing.
var _near: Array[Actor] = []
var _distances := PackedFloat32Array()
var _padded := PackedVector4Array()
var _sent_count := -1

var _world: World
var _material: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _taken := {}  # cells near a piece already (spacing)
var _per_room := {}  # room index -> pieces


## Lays the ceiling `ceiling` over `world`'s floor (not over `skip`: a boss arena stays clear).
func build(world: World, ceiling: CeilingDef, skip: Rect2i = Rect2i()) -> void:
	_world = world
	def = ceiling
	name = "Ceiling"
	_rng.seed = hash("ceiling-%d" % world.rng.seed)
	_near.resize(MAX_BODIES)
	_distances.resize(MAX_BODIES)
	_padded.resize(MAX_BODIES)
	_sent_count = -1
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("clear_radius", def.clear_radius)
	_material.set_shader_parameter("fade_band", def.fade_band)
	var map := world.map
	var walls := FloorDresser.wall_distance(map)
	var order := def.pieces.duplicate()
	RandomUtils.shuffle(order, _rng)
	for piece: CeilingPieceDef in order:
		if piece == null or def.atlas == null:
			continue
		match piece.where:
			CeilingPieceDef.Where.ACROSS:
				_lay_across(piece, skip)
			CeilingPieceDef.Where.OVER_ROOM:
				_lay_over_rooms(piece, walls, skip)
			_:
				_lay_by_walls(piece, skip)
	_make_chunks()


## How many pieces may still go in room `room` (-1: a corridor) for `piece`.
func _room_left(piece: CeilingPieceDef, room: int) -> int:
	if room < 0:
		return 1000 if piece.in_corridors else 0
	var density := def.density_scale
	var shape := _world.map.plan(room).shape
	if shape:
		density *= shape.ceiling_scale
	var most := roundi(piece.max_per_room * density)
	return most - int(_per_room.get("%d:%d" % [room, piece.get_instance_id()], 0))


func _chance(piece: CeilingPieceDef, room: int) -> float:
	var density := def.density_scale
	if room >= 0 and _world.map.plan(room).shape:
		density *= _world.map.plan(room).shape.ceiling_scale
	return piece.density * density


func _free(cell: Vector2i) -> bool:
	return not _taken.has(cell)


func _claim(piece: CeilingPieceDef, cell: Vector2i, room: int) -> void:
	for dy in range(-piece.spacing + 1, piece.spacing):
		for dx in range(-piece.spacing + 1, piece.spacing):
			_taken[cell + Vector2i(dx, dy)] = true
	if room >= 0:
		_per_room["%d:%d" % [room, piece.get_instance_id()]] = int(_per_room.get("%d:%d" % [room, piece.get_instance_id()], 0)) + 1


## Pieces hung along the walls: from the cliff above a room's top edge, down a side wall, in a
## top corner.
func _lay_by_walls(piece: CeilingPieceDef, skip: Rect2i) -> void:
	var map := _world.map
	var ts := float(map.tile_size)
	var size := Vector2(piece.region.size) * 2.0
	var spots: Array[Vector2i] = []
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			if not map.is_floor(cell) or skip.has_point(cell):
				continue
			var up := not map.is_floor(cell + Vector2i.UP)
			var left := not map.is_floor(cell + Vector2i.LEFT)
			var right := not map.is_floor(cell + Vector2i.RIGHT)
			match piece.where:
				CeilingPieceDef.Where.TOP_WALL:
					# A stretch of cliff: wall above it and its neighbours (not a corridor's mouth).
					if up and not map.is_floor(cell + Vector2i(-1, -1)) and not map.is_floor(cell + Vector2i(1, -1)):
						spots.append(cell)
				CeilingPieceDef.Where.SIDE_WALL:
					if (left or right) and not up and not (left and right):
						spots.append(cell)
				CeilingPieceDef.Where.CORNER:
					if up and (left != right):
						spots.append(cell)
	RandomUtils.shuffle(spots, _rng)
	for cell in spots:
		var room := map.room_at(cell)
		if not _free(cell) or _room_left(piece, room) <= 0 or _rng.randf() >= _chance(piece, room):
			continue
		var at := Vector2.ZERO
		var flip := piece.mirror and _rng.randf() < 0.5
		match piece.where:
			CeilingPieceDef.Where.TOP_WALL:
				# Hanging from the plateau's edge, over the cliff face and the floor below.
				at = Vector2(cell.x * ts + (ts - size.x) * 0.5 + _rng.randi_range(-3, 3) * 2.0, (cell.y - 1) * ts + 4.0)
			CeilingPieceDef.Where.SIDE_WALL:
				var on_right := not map.is_floor(cell + Vector2i.RIGHT)
				var edge := (cell.x + 1) * ts if on_right else cell.x * ts
				at = Vector2(edge - size.x * 0.5, cell.y * ts - ts * 0.5)
				flip = on_right  # facing into the room
			CeilingPieceDef.Where.CORNER:
				var on_right := not map.is_floor(cell + Vector2i.RIGHT)
				at = Vector2((cell.x + 1) * ts - size.x if on_right else cell.x * ts, (cell.y - 1) * ts + ts * 0.5)
				flip = on_right
		var one := _laid(piece, at, flip)
		one.under = Vector2(at.x + size.x * 0.5, minf(at.y + size.y, (cell.y + 1) * ts) - 4.0)
		if piece.height > 0.0:
			one.shadow = _shadow_under(Rect2(at, size), piece.height)
		laid.append(one)
		_claim(piece, cell, room)


## Pieces hanging from the unseen ceiling over the rooms, two cells or more from any wall.
func _lay_over_rooms(piece: CeilingPieceDef, walls: Dictionary, skip: Rect2i) -> void:
	var map := _world.map
	var size := Vector2(piece.region.size) * 2.0
	for room in map.rooms.size():
		if map.rooms[room].intersects(skip) and skip.has_area():
			continue
		var cells: Array[Vector2i] = []
		var rect := map.rooms[room]
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				if int(walls.get(cell, 0)) >= 3:
					cells.append(cell)
		RandomUtils.shuffle(cells, _rng)
		for cell in cells:
			if _room_left(piece, room) <= 0:
				break
			if not _free(cell) or _rng.randf() >= _chance(piece, room):
				continue
			var foot := map.cell_to_world(cell)
			var bottom := foot.y - piece.height
			var at := Vector2(foot.x - size.x * 0.5, bottom - size.y)
			var one := _laid(piece, at, piece.mirror and _rng.randf() < 0.5)
			one.under = foot
			if piece.height > 0.0:
				one.shadow = Rect2(foot - Vector2(size.x * 0.4, 4.0), Vector2(size.x * 0.8, 8.0))
			laid.append(one)
			_claim(piece, cell, room)


## Pieces spanning a room from wall to wall (beams, arches), at most `max_per_room` a room.
func _lay_across(piece: CeilingPieceDef, skip: Rect2i) -> void:
	var map := _world.map
	var ts := float(map.tile_size)
	var part := Vector2(piece.region.size.x / 3.0, piece.region.size.y)
	for room in map.rooms.size():
		var rect := map.rooms[room]
		if (skip.has_area() and rect.intersects(skip)) or rect.size.y < 6:
			continue
		if _room_left(piece, room) <= 0 or _rng.randf() >= _chance(piece, room):
			continue
		# Across the middle of the room (near its top it would read as part of the wall).
		var rows := range(rect.position.y + int(rect.size.y / 3.0) + 1, rect.end.y - 2)
		RandomUtils.shuffle(rows, _rng)
		for y: int in rows:
			var middle := Vector2i(map.heart(room).x, y)
			if not map.is_floor(middle) or not _free(middle):
				continue
			# The run of floor across the room on this row, wall at both ends.
			var x0 := middle.x
			while map.is_floor(Vector2i(x0 - 1, y)) and rect.has_point(Vector2i(x0 - 1, y)):
				x0 -= 1
			var x1 := middle.x
			while map.is_floor(Vector2i(x1 + 1, y)) and rect.has_point(Vector2i(x1 + 1, y)):
				x1 += 1
			if map.is_floor(Vector2i(x0 - 1, y)) or map.is_floor(Vector2i(x1 + 1, y)) or x1 - x0 < 3:
				continue  # open at an end (a corridor runs on): nothing to rest on
			var one := Laid.new()
			one.def = piece
			var top := y * ts - piece.height - part.y * 2.0
			var left := x0 * ts - ts * 0.5
			var right := (x1 + 1) * ts + ts * 0.5
			var width := part.x * 2.0
			var src := Rect2(piece.region.position, Vector2(part.x, part.y))
			one.sources.append(src)
			one.targets.append(Rect2(Vector2(left, top), part * 2.0))
			var x := left + width
			while x + width <= right - width + 0.5:
				if _rng.randf() >= piece.broken:
					one.sources.append(Rect2(src.position + Vector2(part.x, 0), src.size))
					one.targets.append(Rect2(Vector2(x, top), part * 2.0))
				x += width
			one.sources.append(Rect2(src.position + Vector2(part.x * 2.0, 0), src.size))
			one.targets.append(Rect2(Vector2(right - width, top), part * 2.0))
			one.under = Vector2((left + right) * 0.5, (y + 0.5) * ts)
			one.shadow = Rect2(Vector2(left + ts * 0.5, y * ts + 8.0), Vector2(right - left - ts, 16.0))
			laid.append(one)
			for cx in range(x0, x1 + 1):
				_taken[Vector2i(cx, y)] = true
			_claim(piece, middle, room)
			break


func _laid(piece: CeilingPieceDef, at: Vector2, flip: bool) -> Laid:
	var one := Laid.new()
	one.def = piece
	one.flip = flip
	one.sources.append(Rect2(piece.region))
	one.targets.append(Rect2(at.snapped(Vector2(2, 2)), Vector2(piece.region.size) * 2.0))
	return one


## The shadow of a piece hanging `height` above the floor: a flat ellipse that far below it.
func _shadow_under(target: Rect2, height: float) -> Rect2:
	var foot := Vector2(target.get_center().x, target.end.y + height)
	return Rect2(foot - Vector2(target.size.x * 0.4, 4.0), Vector2(target.size.x * 0.8, 8.0))


## The chunks (pieces by where they hang, shadows by where they lie) and the emitters.
func _make_chunks() -> void:
	var map := _world.map
	var ts := float(map.tile_size)
	var piece_chunks := {}
	var shadow_chunks := {}
	for one in laid:
		var key := Vector2i((one.under / (ts * CHUNK)).floor())
		if one.sources[0].size != Vector2.ZERO:
			if not piece_chunks.has(key):
				piece_chunks[key] = []
			(piece_chunks[key] as Array).append(one)
		if one.shadow.size != Vector2.ZERO:
			if not shadow_chunks.has(key):
				shadow_chunks[key] = []
			(shadow_chunks[key] as Array).append(one)
		if one.def.emitter:
			var motes := one.def.emitter.instantiate() as Node2D
			var bottom := one.targets[0]
			motes.position = Vector2(bottom.get_center().x, bottom.end.y) + one.def.emitter_offset
			motes.z_index = Z
			add_child(motes)
	for key: Vector2i in piece_chunks:
		_add_chunk(piece_chunks[key], false, key)
	for key: Vector2i in shadow_chunks:
		_add_chunk(shadow_chunks[key], true, key)


func _add_chunk(pieces: Array, shadows: bool, key: Vector2i) -> void:
	var chunk := Chunk.new()
	chunk.layer = self
	chunk.pieces = pieces
	chunk.shadows = shadows
	chunk.name = ("Shadow_%d_%d" if shadows else "Chunk_%d_%d") % [key.x, key.y]
	chunk.z_index = SHADOW_Z if shadows else Z
	if not shadows:
		chunk.material = _material
	add_child(chunk)


func draw_pieces(canvas: CanvasItem, pieces: Array) -> void:
	for one: Laid in pieces:
		for i in one.sources.size():
			var target := one.targets[i]
			if one.flip:
				target = Rect2(target.position + Vector2(target.size.x, 0), Vector2(-target.size.x, target.size.y))
			canvas.draw_texture_rect_region(def.atlas, target, one.sources[i])


func draw_shadows(canvas: CanvasItem, pieces: Array) -> void:
	for one: Laid in pieces:
		var r := one.shadow
		if r.size.y <= 10.0 and r.size.x <= 64.0:
			PixelDraw.disc(canvas, r.get_center(), r.size.x * 0.5, def.shadow_color, 1.0, r.size.y / maxf(r.size.x, 1.0))
		else:
			canvas.draw_rect(Rect2(r.position.snapped(Vector2(2, 2)), r.size.snapped(Vector2(2, 2))), def.shadow_color)


## Where pieces hang over the floor (screenshots, tests).
func piece_spots() -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for one in laid:
		spots.append(one.under)
	return spots


func _process(_delta: float) -> void:
	if _world == null or _material == null:
		return
	var view := _world.view_rect(64.0)
	var hero := _world.player
	var has_hero := is_instance_valid(hero) and not hero.is_dead
	var capacity := MAX_BODIES - (1 if has_hero else 0)
	var count := 0
	var worst := 0
	for actor in _world.actors_this_frame():
		if actor == hero or not is_instance_valid(actor) or not view.has_point(actor.global_position):
			continue
		var distance := actor.global_position.distance_squared_to(hero.global_position) if has_hero else 0.0
		if count < capacity:
			_near[count] = actor
			_distances[count] = distance
			if distance > _distances[worst]:
				worst = count
			count += 1
		elif has_hero and distance < _distances[worst]:
			_near[worst] = actor
			_distances[worst] = distance
			for i in count:
				if _distances[i] > _distances[worst]:
					worst = i
	var total := count + (1 if has_hero else 0)
	if bodies.size() != total:
		bodies.resize(total)
	if has_hero:
		bodies[0] = _body(hero)
	for i in count:
		bodies[i + (1 if has_hero else 0)] = _body(_near[i])
	var changed := total != _sent_count
	for i in MAX_BODIES:
		var value := bodies[i] if i < total else Vector4.ZERO
		if _padded[i] != value:
			_padded[i] = value
			changed = true
	if changed:
		_material.set_shader_parameter("bodies", _padded)
	if total != _sent_count:
		_material.set_shader_parameter("body_count", total)
		_sent_count = total


func _body(actor: Actor) -> Vector4:
	var feet := actor.global_position
	return Vector4(feet.x, feet.y, actor.radius, maxf(feet.y - actor.head_position().y, actor.radius))


## How much of the ceiling shows at `point` (0: none, around a body; 1: all of it), as the shader
## works it out (before its dither): for the tests.
func shown_at(point: Vector2) -> float:
	var nearest := INF
	for b in bodies:
		var q := Vector2(b.x, clampf(point.y, b.y - b.w, b.y))
		nearest = minf(nearest, point.distance_to(q) - b.z)
	return clampf((nearest - def.clear_radius) / maxf(def.fade_band, 1.0), 0.0, 1.0)
