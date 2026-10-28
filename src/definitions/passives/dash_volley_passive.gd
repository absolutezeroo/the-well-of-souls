class_name DashVolleyPassive
extends Passive
## The roll looses a volley (the Oath of the Fletcher's draw): starting a roll, the owner shoots
## `count` shots fanned over `spread_degrees` at the nearest enemy within `reach` (none near: the
## way he faces), each `damage_multiplier` of his power. They are his ranged weapon's own shots
## (an arrow from a bow, a spark from a wand: Combat.spec_from_weapon), or, with a blade in hand,
## `fallback` (an arrow). Secondary shots (ProjectileSpec.secondary): no on-hit perks, no extra
## projectiles, so a roll every second and a half stays a volley, not a storm of procs.

@export var count: int = 3
@export var spread_degrees: float = 24.0
@export var reach: float = 320.0
## Damage of each shot = the owner's power x this.
@export var damage_multiplier: float = 0.5
## Shot drawn when the weapon in hand is not a ranged one.
@export var fallback: VfxSheetDef


func on_dash(owner: Actor, _perk: PerkSet.Entry) -> void:
	var world := owner.world
	if world == null or not is_instance_valid(world):
		return
	var aim := owner.facing if owner.facing != Vector2.ZERO else Vector2.RIGHT
	var best_distance := reach * reach
	for actor in world.actors_this_frame():
		if actor.is_dead or actor.faction == owner.faction:
			continue
		var distance := owner.global_position.distance_squared_to(actor.global_position)
		if distance < best_distance:
			best_distance = distance
			aim = owner.global_position.direction_to(actor.global_position)
	var weapon := owner.get_weapon()
	var spec: ProjectileSpec
	if weapon and weapon.kind == WeaponDef.Kind.RANGED:
		spec = Combat.spec_from_weapon(owner, weapon)
	else:
		spec = ProjectileSpec.new()
		spec.sheet = fallback
		spec.speed = 560.0
		spec.glow = 0.0
		spec.knockback = 90.0
	spec.damage = maxi(1, roundi(owner.get_power() * damage_multiplier))
	spec.count = count
	spec.spread_degrees = spread_degrees
	spec.max_distance = reach
	spec.pierce = 0
	spec.secondary = true
	world.fire_projectiles(owner, aim, spec)
