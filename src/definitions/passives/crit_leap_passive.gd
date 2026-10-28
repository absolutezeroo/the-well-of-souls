class_name CritLeapPassive
extends Passive
## A critical hit leaps (Leaping Bolt, the Storm family): lightning carries the blow from the
## enemy struck to the nearest other one within `reach`, which takes `damage_share` of the
## critical hit, as a critical hit too (the cross, the flash); `jumps` leaps, one more a level
## above the first, each from the last enemy struck. Thunderclap's wave hurts the crowd around the
## target; this one reaches the enemy standing apart (an archer, a caster). The leaps are
## secondary hits (no on-hit perks, no further leaps).

@export_range(1, 6) var jumps: int = 1
@export var jumps_per_stack: int = 1
@export var reach: float = 150.0
## Each leap's damage = the critical hit's (before armor) x this.
@export_range(0.1, 1.0, 0.05) var damage_share: float = 0.7
## What leaps (storm): the bolt and the flash take its ramp.
@export var element: VfxElementDef


func on_hit_dealt(owner: Actor, target: Actor, hit: HitInfo, _damage: int, perk: PerkSet.Entry) -> void:
	if not hit.is_crit or hit.is_secondary or target == null or owner.world == null:
		return
	var world := owner.world
	var amount := maxi(1, roundi(hit.amount * damage_share))
	var from := target.global_position
	var last := target
	var struck: Array[Actor] = [target]
	for i in jumps + jumps_per_stack * (perk.stacks - 1):
		var next := _nearest(world, owner, from, struck)
		if next == null:
			break
		var bolt := element.color() if element else Color("c9b8ff")
		world.spawn_vfx(BeamVfx.create(from + Vector2(0, -8), next.global_position + Vector2(0, -8), bolt, element))
		var leap := Combat.make_secondary_hit(owner, amount)
		leap.is_crit = true
		leap.element = element
		leap.origin = last.global_position
		leap.knockback = from.direction_to(next.global_position) * 90.0
		next.take_hit(leap)
		struck.append(next)
		last = next
		from = next.global_position


func _nearest(world: World, owner: Actor, from: Vector2, skip: Array[Actor]) -> Actor:
	var best: Actor = null
	var best_distance := reach
	for actor in world.actors_this_frame():
		if actor.is_dead or actor.faction == owner.faction or skip.has(actor):
			continue
		var distance := from.distance_to(actor.global_position)
		if distance < best_distance:
			best = actor
			best_distance = distance
	return best


## Shows as the element it leaps in (ItemLook).
func look_element() -> VfxElementDef:
	return element
