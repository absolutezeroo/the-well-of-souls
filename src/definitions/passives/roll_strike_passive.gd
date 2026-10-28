class_name RollStrikePassive
extends Passive
## The roll is an attack, paid in blood (Bleeding Stride, a relic that bends a rule, the Blood
## family): each roll costs `health_cost` of the owner's max Health, and while it rolls every
## enemy its body passes through (within `reach` of it) is cut once, for `damage_multiplier` of
## its power. The price never deals the last blow (a relic's own cost leaves 1 Health:
## docs/design/builds.md "Rule-bending relics"). Only the roll (the hero's innate skills,
## PlayerDef.innate_skills), not a weapon skill's dash.

@export_range(0.0, 0.5, 0.01) var health_cost: float = 0.04
## Damage of each cut = the owner's power x this.
@export var damage_multiplier: float = 1.5
## How close to the rolling body an enemy's body must come (past both radii).
@export var reach: float = 6.0
@export var knockback: float = 120.0
## What it cuts with (blood): its flash, the trail left along the roll.
@export var element: VfxElementDef


func ticks() -> bool:
	return true


func on_skill_used(owner: Actor, skill: SkillDef, perk: PerkSet.Entry) -> void:
	if not is_roll(owner, skill):
		return
	perk.memory["_rolling"] = true
	perk.memory["_from"] = owner.global_position
	perk.memory["_struck"] = []
	Passive.pay_health(owner, health_cost, &"altar", element)


## The hero's roll: one of his innate skills (the buttons that are always his).
static func is_roll(owner: Actor, skill: SkillDef) -> bool:
	return owner is Player and (owner as Player).def != null and (owner as Player).def.innate_skills.has(skill)


func tick(owner: Actor, _delta: float, perk: PerkSet.Entry) -> void:
	if not perk.memory.get("_rolling", false):
		return
	if not owner.is_dashing():
		perk.memory["_rolling"] = false
		if owner.world and element:
			Vfx.trail(owner.world, perk.memory.get("_from", owner.global_position), owner.global_position, element, 0.2)
		return
	var struck: Array = perk.memory["_struck"]
	var center := owner.global_position
	for actor in owner.world.actors_this_frame():
		if actor.is_dead or actor.faction == owner.faction or struck.has(actor.get_instance_id()):
			continue
		var offset := actor.global_position - center
		var touch := owner.radius + actor.radius + reach
		if offset.length_squared() > touch * touch:
			continue
		struck.append(actor.get_instance_id())
		var cut := Combat.make_hit_from(owner, maxi(1, roundi(owner.get_power() * damage_multiplier)))
		cut.is_secondary = true  # a cut of the relic's: no on-hit perks (nothing loops)
		cut.element = element
		cut.origin = center
		cut.knockback = offset.normalized() * knockback
		actor.take_hit(cut)


## Shows as the element it cuts with (ItemLook).
func look_element() -> VfxElementDef:
	return element
