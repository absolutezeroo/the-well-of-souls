class_name SkillHungerPassive
extends Passive
## Skills feed on deaths (Starving Litany, a relic that bends a rule, the Arcane family): the
## owner's skills no longer recharge with time; each kill takes `kill_share` of every running
## cooldown's length off it, and each direct blow on a boss `boss_hit_share` (a warden alone
## would starve them). The roll is left alone (the hero's innate skills keep their time: dodging
## is never starved). The relic's own skill damage is its bonus (PerkDef.bonuses).
## The cooldown is held still by putting back each frame the time that passed (SkillSet.wind):
## the HUD's pie stands still on a starving skill.

@export_range(0.0, 1.0, 0.05) var kill_share: float = 0.25
@export_range(0.0, 0.2, 0.005) var boss_hit_share: float = 0.03


func ticks() -> bool:
	return true


func tick(owner: Actor, delta: float, _perk: PerkSet.Entry) -> void:
	var skills := owner.skills
	for i in skills.skills.size():
		if _starves(owner, i):
			skills.wind(i, delta * owner.cooldown_speed)


func on_kill(owner: Actor, _victim: Actor, _perk: PerkSet.Entry) -> void:
	_feed(owner, kill_share)


func on_hit_dealt(owner: Actor, target: Actor, hit: HitInfo, _damage: int, _perk: PerkSet.Entry) -> void:
	if not hit.is_secondary and target is Monster and (target as Monster).is_boss():
		_feed(owner, boss_hit_share)


## Every starving skill's cooldown shortened by `share` of its length.
func _feed(owner: Actor, share: float) -> void:
	var skills := owner.skills
	for i in skills.skills.size():
		if _starves(owner, i):
			var skill := skills.skills[i]
			skills.wind(i, -skill.cooldown * share)


## A skill that waits for deaths: any but the hero's innate ones (his roll).
func _starves(owner: Actor, index: int) -> bool:
	var skill := owner.skills.skills[index]
	if skill == null:
		return false
	return not (owner is Player and (owner as Player).def != null and (owner as Player).def.innate_skills.has(skill))
