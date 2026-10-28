class_name RestlessStormPassive
extends Passive
## A storm that wants him moving (Restless Storm, a relic that bends a rule, the Storm family).
## It rages only while an enemy is within `reach` (a shop, a talk, a quiet room are left alone):
## while the owner moves (walks or rolls), lightning strikes the nearest enemy every `interval`,
## for `damage_multiplier` of his power; once he has stood still `still_after` seconds, it
## strikes him instead, `self_damage` of his max Health every `self_interval`, as a
## tick (no hit stop, no free invulnerability) that never deals the last blow (a relic's own
## cost leaves 1 Health: docs/design/builds.md "Rule-bending relics"). Attacking while walking is
## how it is played.

@export var interval: float = 0.7
@export var reach: float = 150.0
## Damage of a strike on an enemy = the owner's power x this (a secondary hit: no on-hit perks).
@export var damage_multiplier: float = 1.0
@export var still_after: float = 1.0
@export_range(0.0, 0.2, 0.005) var self_damage: float = 0.03
@export var self_interval: float = 1.0
## The bolt falling on what it strikes (Thunder's).
@export var strike: VfxSheetDef
@export var element: VfxElementDef


func ticks() -> bool:
	return true


func tick(owner: Actor, delta: float, perk: PerkSet.Entry) -> void:
	var memory := perk.memory
	var foe := _nearest_foe(owner)
	if foe == null:
		memory["_still"] = 0.0
		memory["_self"] = 0.0
		return
	var moving := owner.is_dashing() or owner.get_move_direction() != Vector2.ZERO
	if moving:
		memory["_still"] = 0.0
		memory["_self"] = 0.0  # the first strike on him a whole `still_after` after he stops
		var left: float = memory.get("_strike", interval) - delta
		if left <= 0.0:
			left += interval
			_strike_foe(owner, foe)
		memory["_strike"] = left
		return
	var still: float = memory.get("_still", 0.0) + delta
	memory["_still"] = still
	if still < still_after:
		return
	var left_self: float = memory.get("_self", 0.0) - delta
	if left_self <= 0.0:
		left_self += self_interval
		_strike_self(owner)
	memory["_self"] = left_self


## The enemy nearest the owner within `reach`, or null.
func _nearest_foe(owner: Actor) -> Actor:
	var world := owner.world
	if world == null or not is_instance_valid(world):
		return null
	var best: Actor = null
	var best_distance := reach * reach
	for actor in world.actors_this_frame():
		if actor.is_dead or actor.faction == owner.faction:
			continue
		var distance := owner.global_position.distance_squared_to(actor.global_position)
		if distance < best_distance:
			best = actor
			best_distance = distance
	return best


func _strike_foe(owner: Actor, foe: Actor) -> void:
	var bolt := Combat.make_secondary_hit(owner, maxi(1, roundi(owner.get_power() * damage_multiplier)))
	bolt.element = element
	bolt.origin = foe.global_position + Vector2(0, -60)
	foe.take_hit(bolt)
	_show(owner.world, foe.global_position)


func _strike_self(owner: Actor) -> void:
	if owner.world and Passive.pay_health(owner, self_damage, &"shockwave", element) > 0:
		_show(owner.world, owner.global_position)


func _show(world: World, at: Vector2) -> void:
	if strike:
		world.spawn_vfx(SheetVfx.play(strike, at, Vector2.DOWN, element))
	elif element:
		Vfx.pop(world, at, element, 14.0, Vector2.DOWN)


## Shows as the element it strikes with (ItemLook).
func look_element() -> VfxElementDef:
	return element
