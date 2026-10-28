class_name FloorPacing
extends RefCounted
## A floor's rhythm (docs/design/dungeon.md "Pacing", decision 0012): the way the hero walks from
## where he arrives to each way down, how far along that walk every room lies, which rooms are
## dead ends, and which rooms on the way are kept calm so no more than
## DungeonConfig.max_fights_in_a_row fights follow one another. FloorPopulator asks it where the
## floor's specials go: the ambush and the pacts at the peak, the merchant and the forge after it,
## encounters and the treasure in the calm rooms and the dead ends.
##
## Pure grid work on the DungeonMap, no dice: the same map gives the same answers (a resumed floor
## is laid the same).

## The walk's neighbour order (right, left, down, up), as the level probe measures it
## (tools/levels/floor_pacing_probe.py): the same shortest way when two are as short.
const WALK: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var map: DungeonMap
## Steps from the start to each ground cell (-1: not reached), row by row.
var steps := PackedInt32Array()
## The cell each walked cell was first reached from (its index), -1 for the start.
var _came_from := PackedInt32Array()
## Rooms crossed walking from the start to each way down, in order (the start's room first).
var routes: Array[PackedInt32Array] = []
## Room index -> how far along the walk to the first stairs its heart lies (0 the start, 1 the
## stairs; more than 1 beyond them).
var progress := {}
## Room index -> rooms it opens on (through a corridor or wall to wall).
var neighbours := {}
## Rooms kept calm on the way (no monsters): room index -> true. See plan_breathers().
var breathers := {}


func _init(floor_map: DungeonMap) -> void:
	map = floor_map
	_walk()
	for exit in map.exit_cells():
		routes.append(route_to(exit))
	var stairs_steps := maxf(float(steps_at(map.stairs_cell)), 1.0)
	for i in map.rooms.size():
		progress[i] = maxf(float(steps_at(map.heart(i))), 0.0) / stairs_steps
	_link_rooms()


## Steps from the start to `cell`, -1 if it can't be walked to.
func steps_at(cell: Vector2i) -> int:
	return steps[cell.y * map.width + cell.x] if map.in_bounds(cell) else -1


## The rooms crossed walking the shortest way from the start to `goal`, in order, each once in a
## row (the start's room first; corridors between rooms don't count).
func route_to(goal: Vector2i) -> PackedInt32Array:
	var reversed := PackedInt32Array()
	if steps_at(goal) < 0:
		return reversed
	var at := goal.y * map.width + goal.x
	while at >= 0:
		var room := map.room_at(Vector2i(at % map.width, int(at / float(map.width))))
		if room != -1 and (reversed.is_empty() or reversed[reversed.size() - 1] != room):
			reversed.append(room)
		at = _came_from[at]
	reversed.reverse()
	return reversed


## A room with a single way in (it opens on one other room only), never the start.
func is_dead_end(room: int) -> bool:
	return room > 0 and (neighbours.get(room, {}) as Dictionary).size() == 1


## Is room `room` crossed on the way to any stairs?
func on_route(room: int) -> bool:
	return routes.any(func(route: PackedInt32Array) -> bool: return route.has(room))


## The rooms on the way, kept calm so that at most `most` fights follow one another on any way
## down (`calm`: rooms already calm, the merchant's, the forge's; `forced`: rooms that hold a fight
## whatever happens, an ambush, a pact door, a sealed trial). The fight that would make one too
## many becomes calm, or, if it can't, the last ordinary fight before it. Fills `breathers`.
func plan_breathers(most: int, calm: Dictionary, forced: Dictionary) -> void:
	if most <= 0:
		return
	for route in routes:
		var run_start := 1
		var k := 1
		while k < route.size():
			var room := route[k]
			if room == 0 or calm.has(room) or breathers.has(room):
				run_start = k + 1
			elif k - run_start + 1 > most:
				var quiet := -1
				for back in range(k, run_start - 1, -1):
					if not forced.has(route[back]) and route[back] != 0:
						quiet = back
						break
				if quiet < 0:
					run_start = k + 1  # (nothing there may be calmed: forced fights only)
				else:
					breathers[route[quiet]] = true
					run_start = quiet + 1
			k += 1


## The longest run of fights in a row on any way down: rooms crossed that are not the start, not
## in `calm` and not breathers (what the tests and the level probe measure).
func longest_fight_run(calm: Dictionary) -> int:
	var longest := 0
	for route in routes:
		var run := 0
		for k in range(1, route.size()):
			if route[k] == 0 or calm.has(route[k]) or breathers.has(route[k]):
				run = 0
			else:
				run += 1
				longest = maxi(longest, run)
	return longest


## The calm rooms on the way (breathers), lowest index first.
func breather_rooms() -> Array[int]:
	var rooms: Array[int] = []
	for room: int in breathers:
		rooms.append(room)
	rooms.sort()
	return rooms


## Rooms (not the start) whose heart lies between `from` and `to` along the walk to the stairs.
func rooms_between(from: float, to: float) -> Array[int]:
	var rooms: Array[int] = []
	for i in range(1, map.rooms.size()):
		var at: float = progress.get(i, 0.0)
		if at >= from and at <= to:
			rooms.append(i)
	return rooms


## Rooms (not the start) whose heart lies at least `from` along the walk (1: by the stairs, and
## beyond them).
func rooms_from(from: float) -> Array[int]:
	return rooms_between(from, INF)


## `candidates` sorted by how close each lies to the window [from, to] along the walk (inside it
## first, in their given order), the rooms beyond the stairs last.
func by_window(candidates: Array[int], from: float, to: float) -> Array[int]:
	var keyed: Array[Vector2] = []  # (distance to the window, place in `candidates`)
	for i in candidates.size():
		var at: float = progress.get(candidates[i], 0.0)
		keyed.append(Vector2(maxf(from - at, 0.0) + maxf(at - to, 0.0), i))
	keyed.sort()  # (the place breaks ties: the given order kept)
	var sorted: Array[int] = []
	for key in keyed:
		sorted.append(candidates[int(key.y)])
	return sorted


## Breadth-first from the start's cell over ground (no rock, chasm, pool or pillar).
func _walk() -> void:
	var w := map.width
	steps.resize(w * map.height)
	steps.fill(-1)
	_came_from.resize(w * map.height)
	_came_from.fill(-1)
	var start := map.start_cell
	if not map.is_ground(start):
		return
	var queue := PackedInt32Array([start.y * w + start.x])
	steps[queue[0]] = 0
	var head := 0
	while head < queue.size():
		var at := queue[head]
		head += 1
		var cell := Vector2i(at % w, int(at / float(w)))
		for step in WALK:
			var next := cell + step
			if not map.is_ground(next):
				continue
			var index := next.y * w + next.x
			if steps[index] >= 0:
				continue
			steps[index] = steps[at] + 1
			_came_from[index] = at
			queue.append(index)


## Which rooms open on which: two rooms whose cells touch, or touched by the same stretch of
## corridor (floor outside every room).
func _link_rooms() -> void:
	var w := map.width
	var owner := PackedInt32Array()
	owner.resize(w * map.height)
	owner.fill(-2)  # rock
	for y in map.height:
		for x in w:
			if map.is_floor(Vector2i(x, y)):
				owner[y * w + x] = -1
	for i in map.rooms.size():
		neighbours[i] = {}
		var rect := map.rooms[i]
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if owner[y * w + x] == -1:
					owner[y * w + x] = i
	var seen := PackedByteArray()
	seen.resize(w * map.height)
	for start in owner.size():
		var mine := owner[start]
		if mine >= 0:
			# Wall to wall: two rooms whose floors touch.
			for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var x := start % w + step.x
				var y := int(start / float(w)) + step.y
				if x < w and y < map.height:
					var other := owner[y * w + x]
					if other >= 0 and other != mine:
						_link(mine, other)
			continue
		if mine != -1 or seen[start] == 1:
			continue
		# A stretch of corridor: every room it touches opens on every other.
		var touched := {}
		var queue := PackedInt32Array([start])
		seen[start] = 1
		var head := 0
		while head < queue.size():
			var at := queue[head]
			head += 1
			var cell := Vector2i(at % w, int(at / float(w)))
			for step in WALK:
				var next := cell + step
				if not map.in_bounds(next):
					continue
				var index := next.y * w + next.x
				var other := owner[index]
				if other >= 0:
					touched[other] = true
				elif other == -1 and seen[index] == 0:
					seen[index] = 1
					queue.append(index)
		for a: int in touched:
			for b: int in touched:
				if a != b:
					_link(a, b)


func _link(a: int, b: int) -> void:
	(neighbours[a] as Dictionary)[b] = true
	(neighbours[b] as Dictionary)[a] = true
