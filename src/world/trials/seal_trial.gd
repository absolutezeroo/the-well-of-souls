class_name SealTrial
extends RoomTrial
## The Unbound Seal (SealTrialDef): a side room shut behind spikes, a star drawn on the floor
## before its door with a point for each lantern, every one dark; the lanterns (SealLantern)
## stand put out in other rooms of the floor. Lighting one (Interact: "Light") lights its point
## of the star, and the dark answers with foes around it; all lit, the spikes go down and the
## room's hoard (a chest seen through the bars all along) is the hero's.

const STAR_RADIUS := 44.0
const DIM := Color(0.5, 0.42, 0.62)

var room: Rect2i
var lanterns: Array[SealLantern] = []
var door_cell := Vector2i.ZERO
var outward := Vector2i.DOWN

var _gates: RoomGates
var _star: Node2D
var _time := 0.0
var _drawn_key := -1


## The room `index` sealed, its hoard inside, a lantern in each of the first rooms of
## `lantern_rooms` with a free spot near its middle (SealTrialDef.lanterns of them at most).
func setup_seal(world: World, trial: SealTrialDef, index: int, lantern_rooms: Array, taken: Dictionary) -> void:
	room = world.map.rooms[index]
	_world = world
	_gates = RoomGates.new()
	add_child(_gates)
	_gates.setup(world, room)
	var door := _gates.get_cells()
	door_cell = door[int(door.size() / 2.0)] if not door.is_empty() else room.get_center()
	var first: Vector2i = door[0] if not door.is_empty() else door_cell
	if first.y == room.position.y - 1:
		outward = Vector2i.UP
	elif first.y == room.end.y:
		outward = Vector2i.DOWN
	elif first.x == room.position.x - 1:
		outward = Vector2i.LEFT
	else:
		outward = Vector2i.RIGHT
	_gates.close(true)
	_gates.modulate = Color(0.75, 0.62, 1.0)  # the seal's violet spikes
	FloorPopulator._reserve_rect(taken, room)  # its hoard alone inside
	if trial.chest:
		world.spawn_chest(trial.chest, room.get_center(), false)
	var placed: Array[SealLantern] = []
	for room_index: Variant in lantern_rooms:
		if placed.size() >= trial.lanterns:
			break
		var cell := FloorPopulator._free_near_middle(world, int(room_index), taken)
		if cell == Vector2i(-1, -1):
			continue
		FloorPopulator._reserve_around(taken, cell, 1)
		var lantern := SealLantern.new()
		lantern.setup(trial.lantern, placed.size(), trial.color)
		lantern.position = world.map.cell_to_world(cell)
		world.add_entity(lantern)
		world.set_cell_blocked(cell, true)
		lantern.lit.connect(_on_lit)
		placed.append(lantern)
	lanterns = placed
	setup_trial(world, trial, lanterns.size())
	_star = Node2D.new()
	_star.name = "Star"
	_star.z_index = -1  # on the floor, under whoever walks on it
	_star.position = _front()
	_star.draw.connect(_draw_star)
	add_child(_star)


## Where the star lies: on the floor just outside the door's middle.
func _front() -> Vector2:
	var map := _world.map
	var outside := door_cell + outward * 2
	return map.cell_to_world(outside) if map.is_floor(outside) else map.cell_to_world(door_cell + outward)


func _on_lit(lantern: SealLantern) -> void:
	_send_foes(lantern.global_position)
	_world.flash_light(lantern.global_position, def.color, 180.0)
	_step(lantern.global_position)


func _on_completed() -> void:
	_gates.open()
	var at := _world.map.cell_to_world(door_cell)
	Vfx.magic(_world, at, def.color)
	Vfx.burst(_world, Vfx.SPARKLES, at + Vector2(0, -16), def.color, Vector2.UP, 1.4)


func _process(delta: float) -> void:
	_time += delta
	if _star and Vfx.on_screen(_star, STAR_RADIUS + 8.0):
		var key := floori(_time * 8.0) * 16 + done
		if key != _drawn_key:
			_drawn_key = key
			_star.queue_redraw()


## The seal on the floor: a ring, and a star of `total` points, the lit ones in its color, the
## others dark; the whole breathing slowly, broken (dim and still) once done.
func _draw_star() -> void:
	var ring := Color(def.color, 1.0) if not completed else DIM
	var pulse := 0.8 + 0.2 * (1.0 if fmod(_time, 2.0) < 1.0 else 0.0)
	var squash := 0.6
	PixelDraw.disc(_star, Vector2.ZERO, STAR_RADIUS, Color(ring, 0.12), 1.0, squash)
	PixelDraw.ring(_star, Vector2.ZERO, STAR_RADIUS, Color(ring, 1.0), 2, pulse, squash)
	var points := PackedVector2Array()
	var n := maxi(total, 2)
	for i in n:
		points.append(Vector2.from_angle(-PI / 2.0 + TAU * i / n) * Vector2(STAR_RADIUS - 4.0, (STAR_RADIUS - 4.0) * squash))
	# The star: every second point joined (a pentagram for five).
	var step := 2 if n >= 5 else 1
	for i in n:
		var a := points[i]
		var b := points[(i + step) % n]
		PixelDraw.line(_star, a, b, Color(DIM if not completed else ring, 1.0), 1, 1.0)
	for i in n:
		var lit_point := i < lanterns.size() and lanterns[i].is_lit
		if lit_point:
			PixelDraw.disc(_star, points[i], 8.0, Color(def.color, 0.3), 1.0, squash)
		PixelDraw.disc(_star, points[i], 4.0, Color(def.color.lightened(0.3) if lit_point else DIM.darkened(0.3), 1.0))


func save_data() -> Dictionary:
	var lit: Array = []
	for lantern in lanterns:
		if lantern.is_lit:
			lit.append(lantern.index)
	var data := super.save_data()
	data["lit"] = lit
	return data


func restore(saved: Dictionary) -> void:
	if str(saved.get("id", "")) != String(def.id):
		return
	var lit: Variant = saved.get("lit", [])
	if not lit is Array:
		return
	for entry: Variant in lit:
		var i := int(entry) if (entry is int or entry is float) else -1
		if i >= 0 and i < lanterns.size() and not lanterns[i].is_lit:
			lanterns[i].light(true)
			done += 1
	if total > 0 and done >= total:
		completed = true
		_gates.open(true)
