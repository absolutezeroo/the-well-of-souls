class_name GuardTrait
extends MonsterTrait
## A shield (or a shell) in front: blows from that side lose most of their damage and push.
## It turns slower than the monster looks around, so a quick roll gets behind it. Burns, poison
## and blasts (secondary hits) go around it.

## Part of the damage blocked from the front.
@export_range(0.0, 1.0, 0.05) var block: float = 0.8
## Width of the shielded side, in degrees.
@export_range(30.0, 360.0) var arc: float = 150.0
## Radians per second.
@export var turn_speed: float = 2.2
## Part of the push still felt on a blocked hit.
@export_range(0.0, 1.0) var knockback_kept: float = 0.2
@export var color: Color = Color(0.85, 0.85, 0.9, 0.75)


## One guard's values (Monster.trait_state()).
class GuardState:
	extends RefCounted
	## Where the shield points; until set (on_spawn()), the way the monster faces.
	var direction := Vector2.ZERO
	var has_direction := false


func make_state() -> RefCounted:
	return GuardState.new()


func _state(monster: Monster) -> GuardState:
	return monster.trait_state(self) as GuardState


func on_spawn(monster: Monster) -> void:
	var state := _state(monster)
	state.direction = monster.facing
	state.has_direction = true


## Where the shield points.
func direction_of(monster: Monster) -> Vector2:
	var state := _state(monster)
	return state.direction if state.has_direction else monster.facing


func set_direction(monster: Monster, direction: Vector2) -> void:
	var state := _state(monster)
	state.direction = direction.normalized()
	state.has_direction = true


func update(monster: Monster, delta: float) -> void:
	var current := direction_of(monster)
	var turn := current.angle_to(monster.facing)
	set_direction(monster, current.rotated(clampf(turn, -turn_speed * delta, turn_speed * delta)))


func incoming_damage(monster: Monster, hit: HitInfo, damage: int) -> int:
	if hit.is_secondary:
		return damage
	var from := Vector2.ZERO
	if hit.origin != Vector2.INF:
		from = monster.global_position.direction_to(hit.origin)
	elif hit.knockback != Vector2.ZERO:
		from = -hit.knockback.normalized()
	elif is_instance_valid(hit.source):
		from = monster.global_position.direction_to(hit.source.global_position)
	if from == Vector2.ZERO or absf(direction_of(monster).angle_to(from)) > deg_to_rad(arc) * 0.5:
		return damage
	hit.knockback *= knockback_kept
	var world := monster.world
	Vfx.hit(world, monster.global_position + from * monster.radius, from, color)
	Sfx.play_at(Sfx.bank.projectile_impact, monster.global_position, -2.0, 1.4)
	world.spawn_floating_text(monster.head_position() + Vector2(0, -8), tr("Blocked"), color)
	return maxi(1, roundi(damage * (1.0 - block)))


## The shielded side: an arc in front.
func draws_under() -> bool:
	return true


func draw_under(monster: Monster, canvas: CanvasItem) -> void:
	var half := deg_to_rad(arc) * 0.5
	var angle := direction_of(monster).angle()
	PixelDraw.arc(canvas, Vector2(0, -monster.radius * 0.3), monster.radius + 7.0, angle - half, angle + half, Color(color, 1.0), 2)


func describe() -> String:
	return tr("Blocks %d%% of the blows from the front.") % roundi(block * 100.0)
