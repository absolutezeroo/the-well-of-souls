class_name MonsterSteering
extends RefCounted
## How a monster's body gets where its AI sends it (Monster.steering): whether it can walk
## straight to a point, whether it sees someone, whether it is stuck, and the small corrections
## to the way it walks (room between bodies, no stepping into a hole). The AI states ask the
## Monster (`has_clear_walk()`, `can_see()`, `is_stuck()`), which asks this. The answers asked
## every frame are cached here (docs/performance.md).

## Stuck: walking but getting nowhere for this long (see is_stuck()).
const STUCK_AFTER := 0.3
## Moving slower than this share of its speed counts as not getting anywhere.
const STUCK_PROGRESS := 0.3
## Monsters keep this many pixels between their bodies when they walk (no crowding into a pile).
const SPACING := 6.0
## A straight walk to a point is checked again after this long (see has_clear_walk()).
const WALK_CHECK_INTERVAL := 0.2
## The walks remembered at most (the targets' cells): more, and they are all forgotten.
const WALK_CHECKS_KEPT := 16
## A line of sight is cast again after this long (s), or once either end moved SIGHT_MOVE px.
const SIGHT_RECHECK := 0.1
const SIGHT_MOVE := 4.0
## The turns (radians) a walker tries, in order, to keep off a hole ahead (avoid_holes()).
const HOLE_TURNS: Array[float] = [0.0, 0.6, -0.6, 1.3, -1.3]
## The push away from the others is summed every this many physics frames (each monster on its
## own beat) and kept between: a crowd moves a pixel or two a frame, the push barely changes, and
## a crowd of 100 summed every frame cost ~2 ms (docs/performance.md, "A crowd").
const SPACING_EVERY := 3
## A standing monster eases out of a heap at most this share of its speed (stand_apart()).
const STAND_APART := 0.6


## A straight walk checked toward one cell: when, and whether it was clear.
class WalkCheck:
	var frame: int
	var clear: bool

	func _init(at_frame: int, is_clear: bool) -> void:
		frame = at_frame
		clear = is_clear


var _monster: Monster
var _stuck_time := 0.0
var _last_position := Vector2.INF
## The walks checked lately, by the target's cell (has_clear_walk()).
var _walk_checks: Dictionary[Vector2i, WalkCheck] = {}
## One shape query kept for the walks (a crowd asks often): only its radius, place and motion change.
var _walk_query: PhysicsShapeQueryParameters2D
## The last line of sight cast (can_see()): to whom, when, from where to where, and its answer.
var _sight_of := 0  # (an instance id: the one seen may be freed meanwhile)
var _sight_frame := -1000
var _sight_from := Vector2.ZERO
var _sight_to := Vector2.ZERO
var _sight_clear := false
## The last push away from the others (keep_spacing), and the physics frame it was summed.
var _push := Vector2.ZERO
var _push_frame := -1000


func _init(monster: Monster) -> void:
	_monster = monster


## Walking but getting nowhere (a corner, a crowd, a pond's edge): the AI goes around.
func is_stuck() -> bool:
	return _stuck_time >= STUCK_AFTER


## Starts counting afresh (it fell asleep or woke up: where it was means nothing now).
func reset_progress() -> void:
	_stuck_time = 0.0
	_last_position = Vector2.INF


## Wants to walk, barely moves: counts toward being stuck. Knockback and dashes don't count.
func track_progress(delta: float) -> void:
	var monster := _monster
	var speed := monster.move_direction.length() * monster.get_move_speed()
	if _last_position != Vector2.INF and speed > 10.0 and not monster.is_dashing() and delta > 0.0:
		var moved := monster.global_position.distance_to(_last_position) / delta
		if moved < speed * STUCK_PROGRESS:
			_stuck_time += delta
		else:
			_stuck_time = maxf(_stuck_time - delta * 2.0, 0.0)
	else:
		_stuck_time = maxf(_stuck_time - delta, 0.0)
	_last_position = monster.global_position


## Can its body walk straight to `point`: no wall or corner in the way of its width, and, for
## walkers, no water, hole or obstacle on the line. Cached a moment per target cell.
func has_clear_walk(point: Vector2) -> bool:
	var cell := _monster.world.map.world_to_cell(point)
	var frame := Engine.get_physics_frames()
	var cached: WalkCheck = _walk_checks.get(cell)
	if cached and frame - cached.frame < roundi(WALK_CHECK_INTERVAL * Engine.physics_ticks_per_second):
		return cached.clear
	var clear := _walk_is_clear(point)
	if _walk_checks.size() > WALK_CHECKS_KEPT:
		_walk_checks.clear()
	_walk_checks[cell] = WalkCheck.new(frame, clear)
	return clear


## Forgets the walks checked (the ground changed under them: tests block a cell on the way).
func forget_walks() -> void:
	_walk_checks.clear()


func _walk_is_clear(point: Vector2) -> bool:
	var monster := _monster
	var world := monster.world
	var from := monster.global_position
	var motion := point - from
	if motion.length() < 1.0:
		return true
	if not monster.flies:
		# Holes, ponds, props: the cells along the way (but the ends, where bodies stand).
		var steps := ceili(motion.length() / (world.map.tile_size * 0.5))
		var from_cell := world.map.world_to_cell(from)
		var to_cell := world.map.world_to_cell(point)
		for i in range(1, steps):
			var cell := world.map.world_to_cell(from + motion * (float(i) / steps))
			if cell != from_cell and cell != to_cell and (world.nav.is_blocked(cell) or world.has_pit(cell)):
				return false
	if _walk_query == null:
		_walk_query = PhysicsShapeQueryParameters2D.new()
		_walk_query.shape = CircleShape2D.new()
		_walk_query.exclude = [monster.get_rid()]
	var query := _walk_query
	(query.shape as CircleShape2D).radius = maxf(monster.radius - 1.0, 2.0)
	query.transform = Transform2D(0.0, from)
	query.motion = motion
	query.collision_mask = Layers.WORLD | (0 if monster.flies else Layers.WATER)
	var result := monster.get_world_2d().direct_space_state.cast_motion(query)
	return result.is_empty() or result[0] >= 0.999


## Within `max_distance` and nothing on the world's layer between them. The ray is cast again
## only after SIGHT_RECHECK seconds or once either moved SIGHT_MOVE px (a chasing pack asks
## every frame: one ray each per frame was the costliest of its physics; docs/performance.md).
func can_see(other: Actor, max_distance: float) -> bool:
	var from := _monster.global_position
	if from.distance_to(other.global_position) > max_distance:
		return false
	var frame := Engine.get_physics_frames()
	if other.get_instance_id() != _sight_of or frame - _sight_frame >= roundi(SIGHT_RECHECK * Engine.physics_ticks_per_second) \
			or from.distance_squared_to(_sight_from) > SIGHT_MOVE * SIGHT_MOVE \
			or other.global_position.distance_squared_to(_sight_to) > SIGHT_MOVE * SIGHT_MOVE:
		_sight_of = other.get_instance_id()
		_sight_frame = frame
		_sight_from = from
		_sight_to = other.global_position
		_sight_clear = _monster.world.has_line_of_sight(from, other.global_position)
	return _sight_clear


## Steps aside from the monsters it bumps into, so a pack spreads around the hero instead of
## pushing in a line through a door.
func keep_spacing(direction: Vector2) -> Vector2:
	_refresh_push()
	if _push == Vector2.ZERO:
		return direction
	return (direction + _push * 1.2).limit_length(direction.length())


## Standing still, the way out of the monsters it overlaps, at most STAND_APART of its speed (none
## when it overlaps nobody): monsters don't collide with each other, so a pack that stopped round
## the hero spreads out by itself instead of standing in one heap.
func stand_apart() -> Vector2:
	_refresh_push()
	return _push.limit_length(STAND_APART)


## The push away from the others, summed again on this monster's beat (SPACING_EVERY).
func _refresh_push() -> void:
	var frame := Engine.get_physics_frames()
	if frame - _push_frame >= SPACING_EVERY or (frame + _monster.get_instance_id()) % SPACING_EVERY == 0:
		_push = _spacing_push()
		_push_frame = frame


## The push away from the monsters it overlaps (with SPACING), summed now.
func _spacing_push() -> Vector2:
	var monster := _monster
	var world := monster.world
	var push := Vector2.ZERO
	var awake := world.activity.awake
	# Only those in the cells around (the same sum, in the same order, as over the whole list).
	for index in world.activity.buckets.near(awake, monster.global_position, monster.radius + SPACING):
		var entry: Variant = awake[index]
		if not is_instance_valid(entry) or entry == monster:
			continue
		var other := entry as Monster
		if other.is_dead:
			continue
		var away := monster.global_position - other.global_position
		var limit := monster.radius + other.radius + SPACING
		var distance := away.length()
		if distance < limit and distance > 0.01:
			push += away / distance * (1.0 - distance / limit)
	return push


## Walking monsters don't step into holes on their own (being knocked in is another story):
## they veer off, or stop.
func avoid_holes(direction: Vector2) -> Vector2:
	var monster := _monster
	var world := monster.world
	var look_ahead := monster.radius + 12.0
	for angle in HOLE_TURNS:
		var turned := direction.rotated(angle)
		if not world.has_pit(world.map.world_to_cell(monster.global_position + turned.normalized() * look_ahead)):
			return turned
	return Vector2.ZERO
