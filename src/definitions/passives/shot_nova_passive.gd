class_name ShotNovaPassive
extends Passive
## A shot that strikes bursts (the Rimeheart Staff, an evolved Frost Staff): where a direct shot
## hits an enemy, a nova of its element (`radius`) hurts the other enemies around for
## `damage_multiplier` of the owner's power and leaves `status` on all of them, the one struck
## included. Secondary hits (no on-hit perks); an exploding shot's blast is not a shot.

@export var radius: float = 48.0
@export var damage_multiplier: float = 0.5
@export var knockback: float = 60.0
@export var status: OnHitStatus
@export var element: VfxElementDef


func on_hit_dealt(owner: Actor, target: Actor, hit: HitInfo, _damage: int, _perk: PerkSet.Entry) -> void:
	if hit.is_secondary or hit.shot == Vector2.ZERO or target == null or owner.world == null:
		return
	var world := owner.world
	var center := target.global_position
	var amount := maxi(1, roundi(owner.get_power() * damage_multiplier))
	if status and not target.is_dead:
		status.apply_to(target, owner)
	for other in world.actors_this_frame():
		if other == target or other.is_dead or other.faction == owner.faction:
			continue
		var offset := other.global_position - center
		if offset.length() > radius + other.radius:
			continue
		var burst := Combat.make_secondary_hit(owner, amount)
		burst.status = status
		burst.element = element
		burst.origin = center
		burst.knockback = offset.normalized() * knockback
		other.take_hit(burst)
	Vfx.nova(world, center, radius, element)


## Shows as the element it bursts in (ItemLook).
func look_element() -> VfxElementDef:
	return element
