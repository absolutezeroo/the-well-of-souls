class_name WinterAuraPassive
extends Passive
## The cold around him (Heart of Winter, a relic that bends a rule, the Frost family): every
## `pulse`, every enemy within `radius` of the owner is chilled by `status` (a slow lasting a
## little longer than the pulse, so it holds while they stay close and fades soon after they
## leave). Its price is the owner's own pace (PerkDef.bonuses: less move speed). Every
## `show_every` seconds while an enemy is in it, frost glints at the aura's edge (Vfx.riding) so
## its reach reads in a fight. The chill feeds the Frost family (+50% on slowed enemies).

@export var radius: float = 100.0
@export var pulse: float = 0.25
@export var status: OnHitStatus
@export var show_every: float = 1.2
@export var element: VfxElementDef


func ticks() -> bool:
	return true


func tick(owner: Actor, delta: float, perk: PerkSet.Entry) -> void:
	var memory := perk.memory
	var left: float = memory.get("_pulse", 0.0) - delta
	var shown: float = memory.get("_shown", 0.0) - delta
	memory["_shown"] = shown
	if left > 0.0:
		memory["_pulse"] = left
		return
	memory["_pulse"] = left + pulse
	var world := owner.world
	if world == null or not is_instance_valid(world) or status == null:
		return
	var center := owner.global_position
	var any := false
	for actor in world.actors_this_frame():
		if actor.is_dead or actor.faction == owner.faction:
			continue
		var reach := radius + actor.radius
		if center.distance_squared_to(actor.global_position) > reach * reach:
			continue
		status.apply_to(actor, owner)
		any = true
	if any and shown <= 0.0 and element:
		memory["_shown"] = show_every
		Vfx.riding(world, center, radius, element)


## Shows as its element (ItemLook).
func look_element() -> VfxElementDef:
	return element
