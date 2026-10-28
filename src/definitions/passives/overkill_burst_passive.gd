class_name OverkillBurstPassive
extends Passive
## A killing blow bursts (Burst Veins, the Blood family): what it dealt beyond the Health the
## enemy had left bursts out of the body as jets of blood, hurting every other enemy within
## `radius` (+ `radius_per_stack` a level above the first). The burst is at least `minimum` of
## the killer's power (a level) and at most `cap` of it, so a heavy blow (a hammer's charge, a
## crit) on a weak monster clears the pack around it, and a quick blade still splashes a little.
## The burst is a secondary hit (no on-hit perks, no burst of its own).

@export var radius: float = 52.0
@export var radius_per_stack: float = 10.0
## The smallest burst = the killer's power x this, per stack.
@export var minimum: float = 0.5
## The biggest burst = the killer's power x this.
@export var cap: float = 2.0
## Small: a burst that throws the pack apart leaves a blade swinging at air (the lab measured a
## slower pack clear at 140).
@export var knockback: float = 30.0
## What bursts (blood): its jets around the body, its flash on the enemies hit.
@export var element: VfxElementDef


## Remembers the Health the enemy has before the blow lands (the overkill is what goes past it).
func modify_outgoing_hit(_owner: Actor, target: Actor, _hit: HitInfo, perk: PerkSet.Entry) -> void:
	perk.memory["_left"] = target.hp


func on_hit_dealt(owner: Actor, target: Actor, hit: HitInfo, damage: int, perk: PerkSet.Entry) -> void:
	if hit.is_secondary or target == null or target.hp > 0 or owner.world == null or target.is_falling:
		return
	var left: int = perk.memory.get("_left", 0)
	var power := owner.get_power()
	var amount := clampi(damage - left, roundi(power * minimum * perk.stacks), maxi(1, roundi(power * cap)))
	amount = maxi(1, amount)
	var at := target.global_position
	var size := radius + radius_per_stack * (perk.stacks - 1)
	for other in owner.world.actors_this_frame():
		if other == target or other.is_dead or other.faction == owner.faction:
			continue
		var offset := other.global_position - at
		if offset.length() > size + other.radius:
			continue
		var burst := Combat.make_secondary_hit(owner, amount)
		burst.knockback = offset.normalized() * knockback
		burst.origin = at
		burst.element = element
		other.take_hit(burst)
	Combat.hit_props(owner.world, owner, at, size)
	Vfx.nova(owner.world, at, size, element)
	Vfx.pop(owner.world, at, element, 18.0, Vector2.UP)
	if element:
		owner.world.add_splat(at, element.edge(), 1.4)


## Shows as the element it bursts in (ItemLook).
func look_element() -> VfxElementDef:
	return element
