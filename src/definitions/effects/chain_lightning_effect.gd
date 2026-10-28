class_name ChainLightningEffect
extends Effect
## A bolt from the user's hand to the closest enemy ahead (within `max_range` and `cone_degrees`
## of the aim), then jumping from one enemy to the next nearest, `jumps` times, each jump
## weaker. With no enemy ahead, it forks into the floor at `max_range`. In its element's
## language (storm: a jagged BeamVfx, its impacts, a body crackling). The Spark Wand's charged
## attack.

@export var max_range: float = 300.0
## Width of the cone in front of the user where the first target is looked for, in degrees.
@export_range(10.0, 360.0) var cone_degrees: float = 70.0
## Damage of the first strike = flat_damage + user's skill power x multiplier.
@export var damage_multiplier: float = 2.0
@export var flat_damage: int = 0
@export_range(0, 8) var jumps: int = 3
## How far a jump reaches from the last enemy struck.
@export var jump_reach: float = 150.0
## Each jump deals this share of the strike before it.
@export_range(0.1, 1.0) var jump_falloff: float = 0.7
@export var knockback: float = 120.0
@export var status: OnHitStatus


func apply(user: Actor, aim: Vector2) -> void:
	var world := user.world
	var origin := user.shot_origin(aim)
	if origin == Vector2.INF:
		origin = user.global_position + Vector2(0, -8)
	var amount := float(hit_amount(user))
	var color := element.color() if element else Color("c9b8ff")
	var target := _first_target(user, aim)
	if target == null:
		# Nothing ahead: it forks into the floor at its range.
		var end := user.global_position + aim * max_range
		world.spawn_vfx(_beam(user, origin, end, color))
		if element:
			Vfx.pop(world, end, element, 16.0, aim)
		return
	var from := origin
	var struck: Array[Actor] = []
	var next := target
	for i in jumps + 1:
		if next == null:
			break
		var at := next.global_position + Vector2(0, -8)
		world.spawn_vfx(_beam(user, from, at, color) if struck.is_empty() else BeamVfx.create(from, at, color, element))
		var hit := Combat.make_hit_from(user, maxi(1, roundi(amount)))
		hit.knockback = from.direction_to(at) * knockback
		hit.origin = from
		hit.status = status
		hit.element = element
		next.take_hit(hit)
		struck.append(next)
		from = at
		amount *= jump_falloff
		next = _nearest(user, next.global_position, struck)


## The bolt out of the hand: behind the hero's body when it goes north (docs/vfx.md 2b), sorted
## from where it starts.
func _beam(user: Actor, from: Vector2, to: Vector2, color: Color) -> BeamVfx:
	var beam := BeamVfx.create(from, to, color, element)
	if user is Player and VfxLayer.goes_behind(to - from):
		VfxLayer.apply(beam, VfxLayer.Layer.STANDING)
	return beam


## The closest enemy in sight ahead of the user.
func _first_target(user: Actor, aim: Vector2) -> Actor:
	var best: Actor = null
	var best_distance := max_range
	var half_cone := deg_to_rad(cone_degrees) * 0.5
	for enemy in user.world.get_hostiles(user.faction):
		if enemy.is_dead:
			continue
		var offset := enemy.global_position - user.global_position
		var distance := offset.length() - enemy.radius
		if distance >= best_distance or absf(aim.angle_to(offset)) > half_cone:
			continue
		if not user.world.has_line_of_sight(user.global_position, enemy.global_position):
			continue
		best = enemy
		best_distance = distance
	return best


func _nearest(user: Actor, from: Vector2, skip: Array[Actor]) -> Actor:
	var best: Actor = null
	var best_distance := jump_reach
	for enemy in user.world.get_hostiles(user.faction):
		if enemy.is_dead or skip.has(enemy):
			continue
		var distance := from.distance_to(enemy.global_position)
		if distance < best_distance and user.world.has_line_of_sight(from, enemy.global_position):
			best = enemy
			best_distance = distance
	return best


func hit_status() -> OnHitStatus:
	return status


func with_hit_status(new_status: OnHitStatus) -> Effect:
	var copy := copied() as ChainLightningEffect
	copy.status = new_status
	return copy


func hurts() -> bool:
	return true


## Its flat damage plus the user's skill power times its multiplier.
func hit_amount(user: Actor) -> int:
	return flat_damage + roundi(user.get_skill_power() * damage_multiplier)
