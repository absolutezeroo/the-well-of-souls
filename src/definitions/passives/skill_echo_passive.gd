class_name SkillEchoPassive
extends Passive
## Using a skill may leave it ready again at once (chance per stack).
## An echo can't echo: the cast an echo made ready rolls nothing, whatever the sources (Echo
## perk, Echo runes, of Echoes), so a skill is used at most twice per cooldown. The sources
## count together (as if each rolled on its own, a single success being enough) and the total
## stops at DungeonConfig.skill_echo_max_chance: the first source to see a cast rolls for all.

@export_range(0.0, 1.0) var chance_per_stack: float = 0.15
@export var color: Color = Color("b388eb")

## Owner meta: { skill, frame, spent } of the last echo (shared by every echo source).
const STATE := &"_skill_echo"


func on_skill_used(owner: Actor, skill: SkillDef, _perk: PerkSet.Entry) -> void:
	var frame := Engine.get_process_frames()
	var state: Dictionary = owner.get_meta(STATE, {})
	if not state.is_empty() and state.skill == skill:
		if state.frame == frame:
			return  # another source already decided for this cast
		if not state.spent:
			# This cast is the echo: it can't echo again.
			owner.set_meta(STATE, { "skill": skill, "frame": frame, "spent": true })
			return
	if randf() >= total_chance(owner):
		# Decided for this cast: the other sources don't roll again.
		owner.set_meta(STATE, { "skill": skill, "frame": frame, "spent": true })
		return
	owner.set_meta(STATE, { "skill": skill, "frame": frame, "spent": false })
	owner.skills.reset_cooldown(skill)
	owner.world.spawn_floating_text(owner.head_position(), tr("Echo"), color)


## The chance a cast of `owner` echoes: every echo source he has (perks, runes, affixes, each
## with its stacks), 1 - the chance that none would, capped by the dungeon's
## skill_echo_max_chance (`cap`: that cap; below 0, read from the owner's floor).
static func total_chance(owner: Actor, cap: float = -1.0) -> float:
	var none := 1.0
	for entry in owner.perks.all_entries():
		for passive in entry.passives():
			var echo := passive as SkillEchoPassive
			if echo:
				none *= 1.0 - clampf(echo.chance_per_stack * entry.stacks, 0.0, 1.0)
	if cap < 0.0:
		cap = 1.0
		if is_instance_valid(owner.world) and owner.world.rules and owner.world.rules.config:
			cap = owner.world.rules.config.skill_echo_max_chance
	return minf(1.0 - none, cap)


## Arcane on the weapon that carries it (ItemLook).
func look_element() -> VfxElementDef:
	return VfxElementDef.named(&"arcane")
