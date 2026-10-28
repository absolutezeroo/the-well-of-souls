class_name BossBrain
extends RefCounted
## What makes a Monster a boss in a fight (BossDef): its phases (stronger as it loses Health,
## a roar into each), the shockwave answering a hero who strikes too often in a row, and the
## intro it may wait out. Made by Monster.setup() for a BossDef only (Monster.brain), so a plain
## monster carries none of it.

## The boss it drives.
var monster: Monster
var def: BossDef
## The phases it went through (0: still in its first). See BossDef.phases.
var phases_done := 0
## Its current phase's tint (BossPhase.tint), over its body's color.
var tint := Color.WHITE
## Hits taken in a row (each less than BossDef.streak_gap after the last), and the time left
## for the next one to count.
var hit_streak := 0
var streak_time := 0.0
## Hits in a row before it answers (BossDef.shockwave_after_hits; a phase may change it, 0:
## never).
var shockwave_after := 0
## Seconds before another shockwave can come (BossDef.shockwave_cooldown).
var shockwave_cooldown := 0.0
## Seconds of its roar still running (untouchable meanwhile).
var roar_time := 0.0
## Seconds of its intro still playing, while a boss that waits it out (BossDef.waits_intro)
## neither moves nor strikes.
var intro_left := 0.0


func _init(boss: Monster, boss_def: BossDef) -> void:
	monster = boss
	def = boss_def
	shockwave_after = def.shockwave_after_hits


## Woken with its intro played: one that waits it out stands still for its length.
func on_intro(length: float) -> void:
	if def.waits_intro:
		intro_left = length


## Still in its intro (no moving, striking or casting).
func in_intro() -> bool:
	return intro_left > 0.0


## Bosses get stronger as they lose HP (see BossDef.phases).
func update_phase() -> void:
	if monster.is_dead or monster.hp <= 0:
		return
	while phases_done < def.phases.size() and float(monster.hp) / monster.get_max_hp() <= def.phases[phases_done].hp_ratio:
		_enter_phase(def.phases[phases_done])
		phases_done += 1
		monster.announce_phase(phases_done)


func tick(delta: float) -> void:
	intro_left = maxf(intro_left - delta, 0.0)
	streak_time = maxf(streak_time - delta, 0.0)
	shockwave_cooldown = maxf(shockwave_cooldown - delta, 0.0)
	if roar_time > 0.0:
		roar_time -= delta
		if roar_time <= 0.0:
			monster.invincible = false


## The quality of what it drops: the dungeon's boss quality, more for a rare rank's affixes
## (DungeonConfig.boss_rank_loot_per_affix each, one at least).
func loot_quality(config: DungeonConfig) -> float:
	var quality := config.boss_loot_quality
	if monster.rank:
		quality *= 1.0 + config.boss_rank_loot_per_affix * maxi(monster.affixes.size(), 1)
	return quality


func _enter_phase(phase: BossPhase) -> void:
	take_phase(phase)
	# A roar: untouchable for a moment, and whoever stands close is thrown off.
	monster.invincible = true
	roar_time = def.phase_roar_time
	_shockwave(def.roar_shockwave_fuse)
	var world := monster.world
	if not phase.message.is_empty():
		world.spawn_floating_text(monster.head_position() + Vector2(0, -12), tr(phase.message), Palette.DANGER)
		Events.log_message(tr("%s: %s") % [monster.display_name, tr(phase.message)], Palette.DANGER)
	Vfx.magic(world, monster.global_position, Palette.DANGER)
	Sfx.play_at(Sfx.bank.boss_roar, monster.global_position)
	Events.screen_shake.emit(0.6)
	Settings.vibrate(0.5)  # a boss's turn is one of the few things the phone buzzes for


## What `phase` changes in the fight, without its roar: its stats, skills, wind-ups (the
## fairness floor still holds: Monster.windup_for()), cooldowns, shockwave and tint. The fairness
## tests walk the phases through here.
func take_phase(phase: BossPhase) -> void:
	if phase.bonuses:
		monster.base_stats = monster.base_stats.plus(phase.bonuses)
		monster.invalidate_stats()
	if not phase.skills.is_empty():
		monster.skills.set_skills(phase.skills)
		monster.casting_index = -1
	monster.scale_telegraph(phase.windup_multiplier)
	monster.cooldown_speed /= phase.cooldown_multiplier
	if phase.shockwave_after_hits > 0:
		shockwave_after = phase.shockwave_after_hits
	tint = phase.tint


## Hit again (a hostile blow, not a tick) soon after the last hit: the streak grows; too long,
## and it throws the hero off.
func count_hit() -> void:
	hit_streak = hit_streak + 1 if streak_time > 0.0 else 1
	streak_time = def.streak_gap
	if shockwave_after > 0 and hit_streak >= shockwave_after and shockwave_cooldown <= 0.0:
		hit_streak = 0
		_shockwave(def.streak_shockwave_fuse)


## A warning ring, then a blast all around that pushes its enemies far away.
func _shockwave(fuse: float) -> void:
	if monster.ai_frozen():
		return
	var world := monster.world
	shockwave_cooldown = def.shockwave_cooldown
	Combat.shockwave(world, monster, def.shockwave_radius + monster.radius, shockwave_damage(world.rules), def.shockwave_knockback, fuse)


## Its shockwave's damage under `rules` (null: none): the dungeon's small blast, or its share of
## the boss's power when that is more.
func shockwave_damage(rules: FloorRules) -> int:
	var damage := rules.dungeon_damage(def.shockwave_base_damage, def.shockwave_damage_per_depth) if rules else def.shockwave_fallback_damage
	if def.shockwave_power > 0.0:
		damage = maxi(damage, roundi(monster.get_power() * def.shockwave_power))
	return damage
