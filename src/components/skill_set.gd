class_name SkillSet
extends RefCounted
## The skills of an actor and their cooldowns. A slot may be empty (null). Cooldown reduction
## counts up to CombatRulesDef.max_cooldown_reduction.

var skills: Array[SkillDef] = []
var _cooldowns := PackedFloat32Array()
## Length of the cooldown currently running in each slot (for the HUD pie).
var _durations := PackedFloat32Array()


func set_skills(list: Array[SkillDef]) -> void:
	replace(list, 0.0)


## Swaps the skill list (new weapon, new spell). Skills kept from the old list keep their
## cooldown; new ones start with `new_skill_cooldown` (so swapping weapons can't skip cooldowns).
func replace(list: Array[SkillDef], new_skill_cooldown: float) -> void:
	var old_skills := skills
	var old_cooldowns := _cooldowns
	var old_durations := _durations
	skills = list.duplicate()
	_cooldowns = PackedFloat32Array()
	_durations = PackedFloat32Array()
	_cooldowns.resize(skills.size())
	_durations.resize(skills.size())
	for i in skills.size():
		# (the last slot that held it: two empty slots are one "skill", the later one counts)
		var was := old_skills.rfind(skills[i])
		_cooldowns[i] = old_cooldowns[was] if was >= 0 else new_skill_cooldown
		_durations[i] = old_durations[was] if was >= 0 else new_skill_cooldown


func tick(delta: float) -> void:
	for i in _cooldowns.size():
		_cooldowns[i] = maxf(_cooldowns[i] - delta, 0.0)


func is_ready(index: int) -> bool:
	return index >= 0 and index < skills.size() and skills[index] != null and _cooldowns[index] <= 0.0


## 1 right after use, 0 when ready. Used by the HUD.
func cooldown_ratio(index: int) -> float:
	if index < 0 or index >= skills.size() or _durations[index] <= 0.0:
		return 0.0
	return _cooldowns[index] / _durations[index]


## The cooldown running in slot `index` shortened by `seconds` (of cooldown time; never below 0).
func shorten(index: int, seconds: float) -> void:
	if index >= 0 and index < _cooldowns.size() and seconds > 0.0:
		_cooldowns[index] = maxf(_cooldowns[index] - seconds, 0.0)


## Ready again at once (an echoing perk).
func reset_cooldown(skill: SkillDef) -> void:
	var index := skills.find(skill)
	if index >= 0:
		_cooldowns[index] = 0.0


func try_use(index: int, user: Actor, aim: Vector2) -> bool:
	if not is_ready(index):
		return false
	var reduction := clampf(user.get_stats().cooldown_reduction, 0.0, Combat.RULES.max_cooldown_reduction)
	_durations[index] = skills[index].cooldown * (1.0 - reduction)
	_cooldowns[index] = DebugCheats.cooldown(user, _durations[index])  # the debug panel's No cooldowns
	# Its hits and heals are credited to it (Actor.healed, HitInfo.via), delayed ones too.
	Actor.with_source(StringName("skill:%s" % skills[index].id), skills[index].activate.bind(user, aim))
	user.perks.on_skill_used(user, skills[index])
	return true
