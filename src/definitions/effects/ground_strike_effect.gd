class_name GroundStrikeEffect
extends Effect
## Marks spots on the ground around the user's target (a warning circle filling up for `fuse`
## seconds each, GroundStrike), then strikes them: tentacles slamming down, columns of false
## sunlight, a lantern's flame closing in on the hero. The first lands where the target stands
## when the skill goes off; the others are scattered within `spread` of it, never on top of each
## other. Only the user's enemies are hurt. Without a target (the hero using it): along the aim.
## Its `element` (Effect.element): what it is made of (data/vfx/elements/): its nova where it
## strikes, its hits' flash.

## How many spots.
@export_range(1, 12) var count: int = 1
@export var radius: float = 48.0
## Seconds each warning fills before it strikes.
@export var fuse: float = 0.9
## Seconds between one spot showing and the next (0: all at once).
@export var stagger: float = 0.0
## The other spots fall within this distance of the first.
@export var spread: float = 120.0
## Damage = flat_damage + user's skill power x multiplier.
@export var damage_multiplier: float = 1.0
@export var flat_damage: int = 0
@export var knockback: float = 220.0
## A sheet played on each spot as it strikes (a column of light falling), at the art's size.
@export var strike: VfxSheetDef
@export var status: OnHitStatus
## Screen shake per strike.
@export var shake: float = 0.2
@export var sound: AudioStream
## A flash of light on the user as it goes off and on each spot as it lands (alpha 0: none):
## Tôma's lantern flaring violet in the dark.
@export var glow: Color = Color(0, 0, 0, 0)


func apply(user: Actor, aim: Vector2) -> void:
	var world := user.world
	var first := _first_spot(user, aim)
	var amount := hit_amount(user)
	var spots: Array[Vector2] = [first]
	var tries := 0
	while spots.size() < count and tries < count * 12:
		tries += 1
		var spot := first + Vector2.from_angle(world.rng.randf() * TAU) * world.rng.randf_range(radius, maxf(spread, radius + 1.0))
		if not world.is_solid_ground(spot):
			continue
		if spots.any(func(other: Vector2) -> bool: return other.distance_to(spot) < radius * 1.4):
			continue
		spots.append(spot)
	for i in spots.size():
		var node := GroundStrike.create(world, user, spots[i], radius, fuse, amount, knockback, element)
		node.delay = stagger * i
		node.strike = strike
		node.status = status
		node.shake = shake
		node.sound = sound
		node.glow = glow
		world.spawn_vfx(node)
	if glow.a > 0.0:
		world.flash_light(user.global_position + Vector2(0, -user.head_height * 0.5), glow, 160.0)


## Where the target stands (a monster's), else in front of the user along the aim.
func _first_spot(user: Actor, aim: Vector2) -> Vector2:
	var monster := user as Monster
	if monster and is_instance_valid(monster.target) and not monster.target.is_dead:
		return monster.target.global_position
	return user.global_position + aim * maxf(spread, radius * 2.0)


func hit_status() -> OnHitStatus:
	return status


func with_hit_status(new_status: OnHitStatus) -> Effect:
	var copy := copied() as GroundStrikeEffect
	copy.status = new_status
	return copy


func hurts() -> bool:
	return true


## Its flat damage plus the user's skill power times its multiplier.
func hit_amount(user: Actor) -> int:
	return flat_damage + roundi(user.get_skill_power() * damage_multiplier)
