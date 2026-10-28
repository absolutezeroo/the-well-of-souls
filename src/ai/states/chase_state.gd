extends State
## Goes after the target: straight at it when its body can walk there, along a path around walls,
## water, holes and props otherwise (even in sight: seeing across a pond is not reaching).
## Uses skills when their conditions match (through Cast when they have a cast time)
## and switches to Attack when in range. Stuck on a corner or in a crowd, it steps aside and
## finds another way.

const REPATH_INTERVAL := 0.4
const WAYPOINT_REACHED := 8.0
## Stuck: follow the path (not the straight line) this long.
const PATH_AFTER_STUCK := 1.2
## Stuck on the path too: step aside this long, then look for the way again.
const SIDESTEP_TIME := 0.35
## Waypoints a path may skip when the body can walk past them straight.
const SMOOTH_LOOKAHEAD := 4

var _path := PackedVector2Array()
var _repath_timer := 0.0
var _unseen_time := 0.0
var _path_only := 0.0
var _sidestep := Vector2.ZERO
var _sidestep_time := 0.0
var _sidestep_side := 1.0


func enter() -> void:
	_path.clear()
	_repath_timer = 0.0
	_unseen_time = 0.0
	_path_only = 0.0
	_sidestep_time = 0.0


func physics_update(delta: float) -> void:
	if not actor.notice_target():
		machine.transition_to(&"Idle")
		return

	var target := actor.target
	var to_target := target.global_position - actor.global_position
	var distance := to_target.length()
	var aim := to_target.normalized()
	# Chasing, it sees further than idle (MonsterDef.chase_sight_multiplier).
	var sees := actor.can_see(target, actor.chase_detect_radius())

	_unseen_time = 0.0 if sees else _unseen_time + delta
	if _unseen_time > actor.def.chase_give_up_after:
		actor.target = null
		machine.transition_to(&"Idle")
		return

	_path_only = maxf(_path_only - delta, 0.0)
	if _sidestep_time > 0.0:
		_sidestep_time -= delta
		actor.move_direction = _sidestep
		if _sidestep_time <= 0.0:
			_repath_timer = 0.0  # then the way again, from where it stands
		return

	if sees:
		var skill_index := actor.pick_skill(distance)
		if skill_index >= 0:
			_use_skill(skill_index, aim)
			return
		if distance <= actor.attack_range(target) and actor.can_attack():
			machine.transition_to(&"Attack")
			return

	if actor.is_stuck():
		_unstick(aim)
		return
	if sees and _path_only <= 0.0 and actor.has_clear_walk(target.global_position):
		_move_in_sight(distance, aim)
	else:
		_follow_path(delta, target)
		if sees:
			actor.facing = aim


## Walking into something: first take the path; already on it, step aside (left, then right).
func _unstick(aim: Vector2) -> void:
	if _path_only <= 0.0:
		_path_only = PATH_AFTER_STUCK
		_repath_timer = 0.0
		_follow_path(0.0, actor.target)
		return
	_sidestep_side = -_sidestep_side
	var heading := actor.move_direction.normalized() if actor.move_direction != Vector2.ZERO else aim
	_sidestep = (heading.orthogonal() * _sidestep_side - heading * 0.3).normalized()
	_sidestep_time = SIDESTEP_TIME
	actor.move_direction = _sidestep


## Telegraphed skills go through the Cast state (every one that hurts: Monster.skill_cast_time()),
## instant ones (a summon, a ward, a step) fire right away.
func _use_skill(index: int, aim: Vector2) -> void:
	actor.facing = aim
	actor.move_direction = Vector2.ZERO
	if actor.skill_cast_time(actor.skills.skills[index]) > 0.0:
		actor.casting_index = index
		machine.transition_to(&"Cast")
	else:
		actor.skills.try_use(index, actor, aim)


func _move_in_sight(distance: float, aim: Vector2) -> void:
	actor.facing = aim
	var keep := actor.def.keep_distance
	if keep > 0.0 and distance < keep:
		actor.move_direction = -aim                  # too close: back off
	elif keep > 0.0 and distance <= actor.attack_range(actor.target):
		actor.move_direction = aim.orthogonal() * 0.4  # in range: strafe while reloading
	else:
		actor.move_direction = aim


func _follow_path(delta: float, target: Actor) -> void:
	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = REPATH_INTERVAL
		_path = actor.world.find_path(actor.global_position, target.global_position)
		_smooth_path()
	while not _path.is_empty() and actor.global_position.distance_to(_path[0]) < WAYPOINT_REACHED:
		_path.remove_at(0)
	if _path.is_empty():
		actor.move_direction = Vector2.ZERO
	else:
		actor.move_direction = actor.global_position.direction_to(_path[0])
		actor.facing = actor.move_direction


## Cuts the corners of a fresh path: heads for the furthest of the next waypoints its body can
## walk to straight (no zig-zag from cell centre to cell centre).
func _smooth_path() -> void:
	var furthest := 0
	for i in range(mini(SMOOTH_LOOKAHEAD, _path.size()) - 1, 0, -1):
		if actor.has_clear_walk(_path[i]):
			furthest = i
			break
	if furthest > 0:
		_path = _path.slice(furthest)
