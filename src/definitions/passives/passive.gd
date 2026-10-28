class_name Passive
extends Resource
## Behaviour granted by a perk (see PerkDef). Override only the hooks you need.
## `perk` holds the stack count and a `memory` dictionary for state that must last
## the whole run (charges, timers...): never store run state on the Passive itself,
## the resource is shared by everyone who has the perk. Memory keys starting with "_" are not
## saved (frame numbers: the engine's counter starts over with the game).


## Before an outgoing hit is mitigated: change its damage, crit...
func modify_outgoing_hit(_owner: Actor, _target: Actor, _hit: HitInfo, _perk: PerkSet.Entry) -> void:
	pass


## After the owner's hit landed on `target` (direct hits only, see HitInfo.is_secondary).
func on_hit_dealt(_owner: Actor, _target: Actor, _hit: HitInfo, _damage: int, _perk: PerkSet.Entry) -> void:
	pass


## After the owner took damage.
func on_damaged(_owner: Actor, _hit: HitInfo, _damage: int, _perk: PerkSet.Entry) -> void:
	pass


## The owner killed `victim`.
func on_kill(_owner: Actor, _victim: Actor, _perk: PerkSet.Entry) -> void:
	pass


## The owner used a skill.
func on_skill_used(_owner: Actor, _skill: SkillDef, _perk: PerkSet.Entry) -> void:
	pass


## The owner started a dash or roll.
func on_dash(_owner: Actor, _perk: PerkSet.Entry) -> void:
	pass


## Every projectile volley the owner fires (weapons and skills) goes through here.
func modify_projectiles(_owner: Actor, _spec: ProjectileSpec, _perk: PerkSet.Entry) -> void:
	pass


## The owner arrived on a new floor.
func on_floor_started(_owner: Actor, _perk: PerkSet.Entry) -> void:
	pass


## Whether it acts by itself over time (tick()): something circling the owner, a trail left
## burning, a storm that strikes while he moves. Only the passives that say so are called each
## frame (PerkSet.tick()); the others cost nothing there.
func ticks() -> bool:
	return false


## Every physics frame while the owner is alive and on its feet (ticks() true only).
## Runs every frame: no allocation here (docs/performance.md, "No allocation in a hot path").
func tick(_owner: Actor, _delta: float, _perk: PerkSet.Entry) -> void:
	pass


## The owner died (monsters with the "explosive" elite affix blow up...).
func on_died(_owner: Actor, _perk: PerkSet.Entry) -> void:
	pass


## The owner is about to die. Return true to keep it alive (it is the passive's job to restore HP).
func prevent_death(_owner: Actor, _perk: PerkSet.Entry) -> bool:
	return false


## The element it shows as on a weapon that carries it (an affix, a rune: ItemLook): the
## element it strikes with, null when it is none (a plain bonus). Each kind that strikes in an
## element answers with its own (a burn's `element`, a burst's `blast_element`...), and so do
## those that are an element without saying so (drinking blood, arcane echoes).
func look_element() -> VfxElementDef:
	return null
