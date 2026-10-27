class_name BalanceModel
extends RefCounted
## The fast, static half of the balance tools: from the real content (ContentDB, FloorRules,
## StatBlock, WeaponDef, monster and boss defs, ranks, affixes, the passives' exported numbers) it
## works out damage per second, time to kill, damage taken and a face-tank estimate for:
## - every monster kind x every rank (plain, Elite with each affix, Epic, Legendary, Shiny...) x
##   every depth it appears at x every difficulty (with Nightmare +N), against the act's expected build;
## - every boss x every phase x every boss rank x every difficulty;
## - every weapon x every rarity x every armor value monsters have, on each act's expected hero;
## and checks them against BalanceTargets (FLAGS). No game runs: a build is put on a real Player
## (BalanceBuild.make_player) so its stats come from the game's own code, but fights are
## arithmetic. The arena and the lab (BalanceArena, BalanceLab) measure them on the engine.
##
## Assumptions (also in docs/balance.md, "Tools"):
## - damage is the average over the ±15% variance and the crit chance, after armor (Combat);
## - DPS assumes 100% uptime (always hitting); against a boss, a fan of projectiles lands
##   1 + (count - 1) x BOSS_FAN_SHARE of its shots, against a common monster one;
## - a skill's damaging effects each hit the target once (rings and fans: see the fan share);
## - statuses: a burn or slow source's uptime is 1 - exp(-rate x duration); DoTs of the same
##   kind don't stack (StatusSet keeps the strongest);
## - healing from hits, kills and skills is capped by SustainRules' refill rate (x boss_fight_rate
##   against a boss); potions, springs, healing spells are not;
## - procs the model can't place (chain lightning, kill bursts, rolls, thorns) are left out of the
##   boss numbers and estimated for packs only; the lab measures them for real;
## - a monster attacks every wind-up x telegraph + max(recovery, weapon cooldown / attack speed)
##   seconds and uses each skill it can at its fighting distance off cooldown;
## - face-tank: the boss melees on that cycle unless casting, every damaging effect hits; the hero
##   can't be hit more often than its i-frames (PlayerDef.hit_invulnerability) allows; the boss' anti face-tank
##   shockwave costs SHOCKWAVE_DOWNTIME seconds of hitting each time.

## Share of the extra projectiles of a fan or ring that hit a boss (big body, close range).
const BOSS_FAN_SHARE := 0.6
## Seconds a boss' shockwave (700 knockback) costs the hero: thrown ~175 px, walking back.
const SHOCKWAVE_DOWNTIME := 1.0
## Longest a "time to die" can be (a build that out-heals everything).
const TTD_CAP := 600.0
## Average monsters on the hero in a room (the room context of perk values).
const ROOM_PACK := 3
## A guarded monster (shield, shell) blocks this share of the hero's direct hits (face to face
## half the time, GuardTrait.block of them).
const GUARD_FACING := 0.5

var content: ContentDB
var targets: BalanceTargets
## Builds to report on (all of them by default).
var builds: Array[BalanceBuildDef] = []
## Every build (the reference build and the expected builds are looked up here).
var all_builds: Array[BalanceBuildDef] = []
var difficulties: Array[DifficultyDef] = []
## Bosses to report on (all of them by default).
var bosses: Array[BossDef] = []
## Fewer rows (the opt-in test suite): Normal and Hard, no per-depth monster rows.
var quick := false
var report := BalanceReport.new()

## Players made for builds, freed by free_players().
var _players := {}


func _init(content_db: ContentDB, balance_targets: BalanceTargets, every_build: Array[BalanceBuildDef]) -> void:
	content = content_db
	targets = balance_targets
	all_builds = every_build
	builds = every_build
	difficulties = BalanceContent.difficulties(content, PackedStringArray())
	bosses = BalanceContent.bosses(content)


## Works everything out; returns the report (also in `report`).
func run() -> BalanceReport:
	var started := Time.get_ticks_msec()
	report.title = "Balance model"
	report.notes.append("Static estimates from the content (no game running): every monster x rank x depth x difficulty, every boss x phase x rank x difficulty, every weapon x rarity x armor. Assumptions: docs/balance.md > Tools.")
	report.notes.append("Difficulties: %s. Builds: %s." % [", ".join(difficulties.map(func(d: DifficultyDef) -> String: return BalanceContent.key(d))), ", ".join(builds.map(func(b: BalanceBuildDef) -> String: return b.name))])
	_check_build_data()
	_coverage()
	_build_table()
	_monster_tables()
	_floor_curve()
	_rank_chances()
	_boss_tables()
	_weapon_tables()
	_perk_table()
	_degenerate_ratios()
	free_players()
	report.timings["model"] = (Time.get_ticks_msec() - started) / 1000.0
	return report


func free_players() -> void:
	for player: Player in _players.values():
		if is_instance_valid(player):
			player.free()
	_players.clear()


# --- Lookups -------------------------------------------------------------------------

func player_for(build: BalanceBuildDef) -> Player:
	if not _players.has(build):
		_players[build] = BalanceBuild.make_player(build, content)
	return _players[build]


func act_of(boss: BossDef) -> int:
	return BalanceContent.act_of_boss(content, boss)


func boss_depth(act: int) -> int:
	return BalanceContent.boss_depth(content, act)


func expected_build(act: int) -> BalanceBuildDef:
	return BalanceBuild.expected(all_builds, act)


func normal() -> DifficultyDef:
	return BalanceContent.difficulty(content, "normal")


## [passive, stacks, tag] for everything granting passives to `actor` (perks, families, gear).
static func passives_of(actor: Actor) -> Array:
	var result: Array = []
	for entry: PerkSet.Entry in actor.perks._all:
		for passive in entry.passives():
			if passive:
				result.append([passive, entry.stacks, String(entry.source_tag())])
	return result


# --- Damage arithmetic ------------------------------------------------------------------

## Average damage of a hit of `base` (before variance and crit) against `defense`.
static func hit_mean(base: float, crit: float, defense: int) -> float:
	var samples := 9
	var total := 0.0
	crit = clampf(crit, 0.0, 1.0)
	for i in samples:
		var u := 1.0 - Combat.RULES.damage_variance + 2.0 * Combat.RULES.damage_variance * (i + 0.5) / samples
		var normal_hit := Combat.mitigate(maxi(1, roundi(base * u)), defense)
		var critical := Combat.mitigate(maxi(1, roundi(base * u * Combat.RULES.crit_multiplier)), defense)
		total += (1.0 - crit) * normal_hit + crit * critical
	return total / samples


static func uptime(rate: float, duration: float) -> float:
	return clampf(1.0 - exp(-rate * duration), 0.0, 1.0)


## Health the hero's sustain budget gives back per second (SustainRules), or INF without rules.
func sustain_rate(max_hp: int, boss_fight: bool) -> float:
	var rules := content.dungeon.sustain
	return rules.refill_per_second(max_hp, boss_fight) if rules else INF


## What `player` deals to a target with `defense` (boss: fans land better, kill heals only from
## the boss), per second, and the healing that comes with it.
func hero_output(player: Player, defense: int, is_boss: bool, low_hp: bool = false) -> Dictionary:
	var stats := player.get_stats()
	var weapon := player.get_weapon()
	var power := float(player.get_power())
	var crit := clampf(stats.crit_chance, 0.0, 1.0)
	var attacks_per_s := 1.0 / player.get_attack_cooldown(weapon) if weapon else 0.0
	var passives := passives_of(player)

	var extra_projectiles := 0
	var extra_cap := 99  # ExtraProjectilesPassive.max_extra (every source together)
	var extra_share := 1.0  # ExtraProjectilesPassive.extra_damage
	var lifesteal_ratio := 0.0
	var lifesteal_tags := PackedStringArray()
	var kill_heal := 0.0
	var kill_heal_tags := PackedStringArray()
	var skill_heal_flat := 0.0
	var skill_heal_min_cd := 0.0
	var echo_fail := 1.0  # chance that no echo source fires (each rolls on its own)
	var execute_mult := 1.0
	var execute_threshold := 0.0
	var low_hp_bonus := 0.0
	var shock_sources: Array = []
	var burn_sources: Array = []  # [tick, interval, duration, chance]
	var poison_sources: Array = []
	var slow_sources: Array = []  # [duration, chance]
	var status_bonus: Array = []  # [condition, bonus]
	var skill_effects_extra: Array[Effect] = []
	var chains: Array = []  # [every, jumps, mult]
	var ward := 0
	var cheat_death := 0.0
	for item: Array in passives:
		var passive: Passive = item[0]
		var stacks: int = item[1]
		var tag: String = item[2]
		if passive is LifestealPassive:
			lifesteal_ratio += (passive as LifestealPassive).ratio_per_stack * stacks
			lifesteal_tags.append(tag)
		elif passive is HealOnKillPassive:
			kill_heal += (passive as HealOnKillPassive).heal_per_stack * stacks
			kill_heal_tags.append(tag)
		elif passive is BloodlustPassive:
			var blood := passive as BloodlustPassive
			kill_heal += player.get_max_hp() * blood.heal_per_kill
			kill_heal_tags.append(tag)
			low_hp_bonus += blood.low_health_bonus * stacks
		elif passive is HealOnSkillPassive:
			skill_heal_flat += (passive as HealOnSkillPassive).heal_per_stack * stacks
			skill_heal_min_cd = (passive as HealOnSkillPassive).min_cooldown
		elif passive is SkillEchoPassive:
			echo_fail *= 1.0 - clampf((passive as SkillEchoPassive).chance_per_stack * stacks, 0.0, 1.0)
		elif passive is ExecutePassive:
			var ex := passive as ExecutePassive
			execute_mult *= 1.0 + ex.bonus_per_stack * stacks
			execute_threshold = maxf(execute_threshold, ex.hp_threshold)
		elif passive is CritShockwavePassive:
			var cs := passive as CritShockwavePassive
			if cs.hits_target:  # otherwise only the enemies around the one struck (packs)
				shock_sources.append(roundi(power * cs.damage_multiplier * stacks))
		elif passive is BurnOnHitPassive:
			var b := passive as BurnOnHitPassive
			var entry := [b.damage_per_stack * stacks, b.interval, b.duration, b.chance]
			if b.status_id == &"burn":
				burn_sources.append(entry)
			else:
				poison_sources.append(entry)
		elif passive is SlowOnHitPassive:
			slow_sources.append([(passive as SlowOnHitPassive).duration, 1.0])
		elif passive is StatusDamagePassive:
			var sd := passive as StatusDamagePassive
			status_bonus.append([sd.condition, sd.bonus_per_stack * stacks])
		elif passive is ExtraProjectilesPassive:
			var xp := passive as ExtraProjectilesPassive
			extra_projectiles += xp.count_per_stack * stacks
			extra_cap = mini(extra_cap, xp.max_extra)
			extra_share = minf(extra_share, xp.extra_damage)
		elif passive is EffectsOnSkillPassive:
			skill_effects_extra.append_array((passive as EffectsOnSkillPassive).effects)
		elif passive is FloorWardPassive:
			ward += (passive as FloorWardPassive).ward_per_stack * stacks
		elif passive is CheatDeathPassive:
			cheat_death += (passive as CheatDeathPassive).heal_ratio * stacks
		elif passive is ChainLightningPassive:
			var cl := passive as ChainLightningPassive
			chains.append([cl.every_hits, cl.jumps, cl.damage_multiplier])

	if weapon and weapon.on_hit:
		if weapon.on_hit.burn_damage > 0:
			burn_sources.append([weapon.on_hit.burn_damage, 0.5, weapon.on_hit.burn_duration, 1.0])
		if weapon.on_hit.poison_damage > 0:
			poison_sources.append([weapon.on_hit.poison_damage, 1.0, weapon.on_hit.poison_duration, 1.0])
		if weapon.on_hit.slow > 0.0:
			slow_sources.append([weapon.on_hit.slow_duration, 1.0])

	# Shots per attack that land on this target.
	var hits_per_attack := 1.0
	var volley_share := 1.0  # extra projectiles share the volley's damage
	if weapon and weapon.kind == WeaponDef.Kind.RANGED:
		var extra := mini(extra_projectiles, extra_cap)
		var count := weapon.projectile_count + extra
		volley_share = (weapon.projectile_count + extra_share * extra) / float(count)
		hits_per_attack = 1.0 + (count - 1) * (BOSS_FAN_SHARE if is_boss else 0.0)
	var hit_rate := attacks_per_s * hits_per_attack
	var weapon_base := power * (weapon.projectile_damage * volley_share if weapon and weapon.kind == WeaponDef.Kind.RANGED else 1.0)

	# Statuses kept up by the hits (the strongest of a kind counts).
	var burn := _dot(burn_sources, hit_rate, defense)
	var poison := _dot(poison_sources, hit_rate, defense)
	var slow_up := 0.0
	for source: Array in slow_sources:
		slow_up = maxf(slow_up, uptime(hit_rate * float(source[1]), float(source[0])))
	var mult := 1.0
	for bonus: Array in status_bonus:
		var up: float = burn.up if bonus[0] == StatusDamagePassive.Condition.BURNING else (poison.up if bonus[0] == StatusDamagePassive.Condition.POISONED else slow_up)
		mult *= 1.0 + float(bonus[1]) * up
	if low_hp:
		mult *= 1.0 + low_hp_bonus

	var hit := hit_mean(weapon_base * mult, crit, defense)
	var direct_dps: float = hit * hit_rate
	var shock_dps := 0.0
	for amount: int in shock_sources:
		shock_dps += hit_rate * crit * Combat.mitigate(amount, defense)
	var chain_dps := 0.0  # on the others in a pack only
	for chain: Array in chains:
		chain_dps += attacks_per_s / float(chain[0]) * mini(int(chain[1]), ROOM_PACK - 1) * Combat.mitigate(roundi(power * float(chain[2])), defense)

	# Skills (the weapon's two and the learned spell; not the roll).
	var skill_power := player.get_skill_power()
	var cdr := clampf(stats.cooldown_reduction, 0.0, Combat.RULES.max_cooldown_reduction)
	var skill_dps := 0.0
	var skill_heal_hps := 0.0
	var sustain_skill_hps := 0.0
	var skills_used := PackedStringArray()
	var skill_rows: Array = []
	for i in range(1, player.skills.skills.size()):
		var skill := player.skills.skills[i]
		if skill == null:
			continue
		# An echo resets the cooldown, and an echo can't echo: uses per cooldown = 1 + chance one
		# fires (every source together, capped: DungeonConfig.skill_echo_max_chance).
		var echo := minf(1.0 - echo_fail, content.dungeon.skill_echo_max_chance)
		var cooldown := skill.cooldown * (1.0 - cdr) / (1.0 + echo)
		if cooldown <= 0.0:
			continue
		var per_use := effects_damage(skill.effects, skill_power * mult, crit, defense, is_boss)
		per_use += effects_damage(skill_effects_extra, skill_power * mult, crit, defense, is_boss)
		skill_dps += per_use / cooldown
		skill_heal_hps += effects_heal(skill.effects, player.get_max_hp()) / cooldown
		if skill.cooldown >= skill_heal_min_cd:
			sustain_skill_hps += skill_heal_flat / cooldown
		skills_used.append(String(skill.id))
		skill_rows.append({ "id": String(skill.id), "damage": per_use, "cooldown": cooldown })

	var lifesteal_hps := (direct_dps + skill_dps) * lifesteal_ratio
	var total: float = direct_dps + shock_dps + burn.dps + poison.dps + skill_dps
	if is_boss and execute_mult > 1.0:
		total *= 1.0 / ((1.0 - execute_threshold) + execute_threshold / execute_mult)
	return {
		"power": power, "crit": crit, "attacks_per_s": attacks_per_s, "hits_per_attack": hits_per_attack,
		"hit": hit, "direct_dps": direct_dps, "shock_dps": shock_dps, "burn_dps": burn.dps,
		"poison_dps": poison.dps, "skill_dps": skill_dps, "chain_dps": chain_dps, "dps": total, "skills": skills_used,
		"skill_rows": skill_rows, "lifesteal_ratio": lifesteal_ratio, "lifesteal_tags": lifesteal_tags,
		"lifesteal_hps": lifesteal_hps, "skill_heal_hps": skill_heal_hps, "sustain_skill_hps": sustain_skill_hps,
		"kill_heal": kill_heal, "kill_heal_tags": kill_heal_tags,
		"execute_mult": execute_mult, "execute_threshold": execute_threshold, "low_hp_bonus": low_hp_bonus,
		"ward": ward, "cheat_death": cheat_death, "burn_uptime": burn.up, "slow_uptime": slow_up,
		"max_hp": player.get_max_hp(), "defense": stats.defense,
	}


## { dps, up } of the strongest of `sources` ([tick, interval, duration, chance]) kept up by
## `hit_rate` hits a second, ticks after armor.
static func _dot(sources: Array, hit_rate: float, defense: int) -> Dictionary:
	var best := 0.0
	var best_up := 0.0
	for source: Array in sources:
		var up := uptime(hit_rate * float(source[3]), float(source[2]))
		var dps := Combat.mitigate(int(source[0]), defense) / float(source[1]) * up
		if dps > best:
			best = dps
		best_up = maxf(best_up, up)
	return { "dps": best, "up": best_up }


## Average damage of one use of `effects` on one target (damage areas, dash strikes, projectiles;
## fans and rings land 1 + (count - 1) x BOSS_FAN_SHARE shots on a boss, at most 3).
static func effects_damage(effects: Array[Effect], skill_power: float, crit: float, defense: int, is_boss: bool) -> float:
	var total := 0.0
	for effect in effects:
		if effect is DamageAreaEffect:
			var area := effect as DamageAreaEffect
			total += hit_mean(area.flat_damage + roundf(skill_power * area.damage_multiplier), crit, defense)
		elif effect is DashStrikeEffect:
			var strike := effect as DashStrikeEffect
			total += hit_mean(strike.flat_damage + roundf(skill_power * strike.damage_multiplier), crit, defense)
		elif effect is ProjectileEffect:
			var shot := effect as ProjectileEffect
			var landing := 1.0 + (shot.count - 1) * (BOSS_FAN_SHARE if is_boss else 0.0)
			total += hit_mean(shot.flat_damage + roundf(skill_power * shot.damage_multiplier), crit, defense) * minf(landing, 3.0)
	return total


static func effects_heal(effects: Array[Effect], max_hp: int) -> float:
	var total := 0.0
	for effect in effects:
		if effect is HealEffect:
			var heal := effect as HealEffect
			total += heal.amount + roundi(max_hp * heal.max_hp_ratio)
	return total


# --- Monsters and bosses: what they deal --------------------------------------------------

## A monster (or boss) as the hero meets it: stats on that floor, rank and affixes applied, its
## attack cycle and skills at its fighting distance. `stat_bonus`: a boss phase's bonuses.
func foe_numbers(def: MonsterDef, rules: FloorRules, rank: MonsterRankDef, affixes: Array, hero: Player, stat_bonus: StatBlock = null, skill_list: Array = [], windup_mult: float = 1.0, cooldown_speed: float = 1.0) -> Dictionary:
	var is_boss := def is BossDef
	var stats := rules.scale_monster(def.stats, is_boss)
	var hp_factor := 1.0
	if rank:
		hp_factor = rank.boss_hp_multiplier if is_boss else rank.hp_multiplier_at(rules.depth)
	var thorns := 0
	var lifesteal := 0.0
	var venom := 0.0
	var burst := 0
	var affix_names := PackedStringArray()
	for a: EliteAffixDef in affixes:
		affix_names.append(String(a.id))
		if not is_boss:
			hp_factor *= a.hp_multiplier
		if a.perk:
			if a.perk.bonuses:
				stats = stats.plus(a.perk.bonuses)
			for p in a.perk.passives:
				if p is ThornsPassive:
					thorns += (p as ThornsPassive).damage_per_stack
				elif p is LifestealPassive:
					lifesteal += (p as LifestealPassive).ratio_per_stack
				elif p is BurnOnHitPassive:
					var b := p as BurnOnHitPassive
					venom = maxf(venom, Combat.mitigate(b.damage_per_stack, hero.get_stats().defense) / b.interval)
				elif p is DeathBurstPassive:
					burst = rules.dungeon_damage((p as DeathBurstPassive).damage)
	stats.max_hp = roundi(stats.max_hp * hp_factor)
	if stat_bonus:
		stats = stats.plus(stat_bonus)
	var hero_defense := hero.get_stats().defense
	var rank_damage := rank.damage_multiplier if rank and not is_boss else 1.0
	var power := maxi(1, roundi(((def.weapon.damage if def.weapon else 1) + stats.attack) * rules.monster_damage(is_boss) * rank_damage))
	var skill_power := power * maxf(1.0 + stats.skill_power, 0.1)
	var melee := hit_mean(power * (def.weapon.projectile_damage if def.weapon and def.weapon.kind == WeaponDef.Kind.RANGED else 1.0), stats.crit_chance, hero_defense)
	var weapon_cd := (def.weapon.cooldown if def.weapon else 1.0) / maxf(1.0 + stats.attack_speed, 0.25)
	var windup := def.attack_windup * rules.telegraph_time() * windup_mult
	var cycle := windup + maxf(def.attack_recovery, weapon_cd) + 1.0 / 60.0
	var ranged := def.weapon != null and def.weapon.kind == WeaponDef.Kind.RANGED
	var distance := (def.keep_distance if def.keep_distance > 0.0 else def.weapon.reach * 0.7) if ranged else def.radius + hero.radius + (def.weapon.reach if def.weapon else 20.0) * 0.6
	var skills: Array = []
	var busy := 0.0
	var skill_dps := 0.0
	var skill_hits := 0.0
	var summons := 0.0
	var support := false
	for skill: SkillDef in (skill_list if not skill_list.is_empty() else def.skills):
		if skill == null:
			continue
		var damage := 0.0
		var hits := 0
		var delays := {}
		var summon_count := 0
		for effect in skill.effects:
			if effect is SummonEffect:
				summon_count += (effect as SummonEffect).count
			elif effect is AllyEffect:
				support = true
			var one := effects_damage([effect] as Array[Effect], skill_power, stats.crit_chance, hero_defense, true)
			if one > 0.0:
				# Hits within the hero's i-frames (PlayerDef.hit_invulnerability) count once.
				var slot := floori(effect.delay / content.player.hit_invulnerability)
				if not delays.has(slot):
					delays[slot] = one
					hits += 1
				else:
					delays[slot] = maxf(delays[slot], one)
		for value: float in delays.values():
			damage += value
		var usable := distance >= skill.ai_min_range and distance <= skill.ai_max_range and skill.ai_ally_need == SkillDef.AllyNeed.NONE
		var rate := 1.0 / maxf(skill.cooldown / cooldown_speed, 0.1)
		skills.append({ "id": String(skill.id), "rate": rate, "damage": damage, "hits": hits,
			"cast": skill.cast_time * rules.telegraph_time() * windup_mult, "summons": summon_count, "usable": usable,
			"below": skill.ai_below_hp_ratio })
		if usable and skill.ai_below_hp_ratio >= 1.0:
			busy += rate * skill.cast_time * rules.telegraph_time() * windup_mult
			skill_dps += rate * damage
			skill_hits += rate * hits
			summons += rate * summon_count
	busy = clampf(busy, 0.0, 0.9)
	var melee_rate := (1.0 - busy) / cycle
	var hits_per_s := melee_rate + skill_hits
	var dps := melee_rate * melee + skill_dps
	if venom > 0.0:
		dps += venom * 0.8  # poison ticks (after armor), kept up most of the time by its hits
	var cap := 1.0 / content.player.hit_invulnerability
	if hits_per_s > cap:
		dps *= cap / hits_per_s
		hits_per_s = cap
	var average_hit := dps / hits_per_s if hits_per_s > 0.0 else melee
	var guard := 0.0
	for t in def.traits:
		if t is GuardTrait:
			guard = (t as GuardTrait).block * GUARD_FACING
	return {
		"hp": stats.max_hp, "defense": stats.defense, "power": power, "melee": melee, "cycle": cycle,
		"dps": dps, "hits_per_s": hits_per_s, "average_hit": average_hit, "skills": skills, "summons_per_s": summons,
		"support": support, "thorns": thorns, "lifesteal": lifesteal, "burst": burst, "guard": guard,
		"affixes": affix_names, "speed": stats.move_speed,
	}


## Seconds `hero` needs to kill a foe (foe_numbers) by hitting it: hits needed x attack time, or
## HP / DPS when damage over time helps; a Vampiric foe heals 60% of what it deals meanwhile.
func ttk_on(foe: Dictionary, out: Dictionary) -> float:
	var per_hit: float = out.hit * (1.0 - float(foe.guard))
	var hit_rate: float = out.attacks_per_s * out.hits_per_attack
	var hp: float = foe.hp
	var ttk := ceilf(hp / maxf(per_hit, 0.01)) / maxf(hit_rate, 0.01)
	var dps: float = out.direct_dps * (1.0 - float(foe.guard)) + out.burn_dps + out.poison_dps + out.shock_dps + out.skill_dps
	if out.burn_dps + out.poison_dps + out.shock_dps + out.skill_dps > 0.0:
		ttk = minf(ttk, hp / maxf(dps, 0.01))
	if float(foe.lifesteal) > 0.0:
		var heal: float = float(foe.lifesteal) * float(foe.dps)
		ttk = hp / maxf(hp / ttk - heal, 0.01) if hp / ttk > heal else TTD_CAP
	return ttk


# --- Builds -----------------------------------------------------------------------------

func _check_build_data() -> void:
	for build in builds:
		for problem in BalanceBuild.problems(build, content):
			report.flag(BalanceReport.ERROR, "build data", build.name, problem, "valid ids", "fix data/balance/builds/%s.tres" % build.name)


func _coverage() -> void:
	var rows: Array = []
	for line in BalanceContent.unlisted(content):
		rows.append([line])
		report.flag(BalanceReport.WARN, "content: unlisted", line.get_slice(":", 0), line.get_slice(": ", 1), "listed in content_db.tres", "never appears in a run, still measured by the tools")
	var counts := [
		["Weapons (data/items/weapons)", BalanceContent.weapons().size()],
		["Perks and relics", BalanceContent.perks().size()],
		["Families", content.synergies.size()],
		["Runes", content.runes.size()],
		["Item affixes", content.item_affixes.size()],
		["Shrine upgrades", content.upgrades.size()],
		["Elite affixes", content.elite_affixes.size()],
		["Monster ranks", BalanceContent.ranks(content).size()],
		["Monsters (in acts)", content.all_monsters().size()],
		["Bosses", BalanceContent.bosses(content).size()],
		["Encounters", content.encounters.size()],
		["Difficulties (+ ascensions)", "%d (+%d)" % [content.difficulties.size(), content.ascensions.size()]],
		["Builds (data/balance/builds)", all_builds.size()],
	]
	report.table("coverage", "Content", "What the tools walk (found in ContentDB and data/, never hand-picked)", PackedStringArray(["Content", "Count"]), counts)
	if not rows.is_empty():
		report.table("unlisted", "Content", "Content files not used by the game", PackedStringArray(["What"]), rows)


func _build_table() -> void:
	var rows: Array = []
	var data := {}
	for build in builds:
		var player := player_for(build)
		var stats := player.get_stats()
		var weapon := player.get_weapon()
		var boss := content.dungeon.acts[build.act - 1].boss
		var defense := FloorRules.make(content.dungeon, normal(), null, boss_depth(build.act)).scale_monster(boss.stats, true).defense
		var out := hero_output(player, defense, true)
		var families := PackedStringArray()
		for synergy in player.perks.awakened():
			families.append(String(synergy.id))
		var sustain := PackedStringArray()
		if out.lifesteal_ratio > 0.0:
			sustain.append("lifesteal %d%% (%s)" % [roundi(out.lifesteal_ratio * 100.0), ", ".join(out.lifesteal_tags)])
		if out.kill_heal > 0.0:
			sustain.append("%.1f Health/kill (%s)" % [out.kill_heal, ", ".join(out.kill_heal_tags)])
		if out.sustain_skill_hps + out.skill_heal_hps > 0.0:
			sustain.append("%.1f Health/s from skills" % (out.sustain_skill_hps + out.skill_heal_hps))
		if out.ward > 0:
			sustain.append("ward %d" % out.ward)
		if out.cheat_death > 0.0:
			sustain.append("cheat death x%.0f" % (out.cheat_death / 0.5))
		var cap := sustain_rate(player.get_max_hp(), true)
		rows.append([build.name, ",".join(build.tags), build.act, build.level, weapon.display_name if weapon else "-",
			stats.max_hp, player.get_power(), stats.defense, BalanceReport.pct(stats.crit_chance),
			"%.2f" % out.attacks_per_s, out.dps, ", ".join(families), "; ".join(sustain), cap])
		data[build.name] = {
			"act": build.act, "level": build.level, "tags": build.tags, "weapon": weapon.display_name if weapon else "",
			"max_hp": stats.max_hp, "power": player.get_power(), "attack": stats.attack, "defense": stats.defense,
			"crit_chance": stats.crit_chance, "attack_speed": stats.attack_speed, "skill_power": stats.skill_power,
			"cooldown_reduction": stats.cooldown_reduction, "move_speed": stats.move_speed, "families": families,
			"vs_act_boss": out, "description": build.description, "sustain_cap_boss": cap,
		}
	report.data["builds"] = data
	report.table("builds", "Builds", "Builds (DPS vs their act's main boss on Normal, 100% uptime; sustain cap = Health/s the shared budget refills in a boss fight)",
		PackedStringArray(["Build", "Tags", "Act", "Lvl", "Weapon", "Max HP", "Power", "Armor", "Crit", "Attacks/s", "DPS", "Families", "Sustain", "Cap /s (boss)"]), rows)
	var reasons: Array = []
	for build in builds:
		reasons.append([build.name, build.description])
	report.table("build_reasons", "Builds", "Why each build looks like this (data/balance/builds/*.tres)", PackedStringArray(["Build", "Reasoning"]), reasons)


func _degenerate_ratios() -> void:
	var rows: Array = []
	for build in builds:
		if build.has_tag("expected") or build.has_tag("baseline"):
			continue
		var expected := expected_build(build.act)
		if expected == null:
			continue
		var boss := content.dungeon.acts[build.act - 1].boss
		var defense := FloorRules.make(content.dungeon, normal(), null, boss_depth(build.act)).scale_monster(boss.stats, true).defense
		var mine: float = hero_output(player_for(build), defense, true).dps
		var theirs: float = hero_output(player_for(expected), defense, true).dps
		var ratio := mine / maxf(theirs, 0.01)
		rows.append([build.name, ",".join(build.tags), expected.name, String(boss.id), mine, theirs, "%.2fx" % ratio])
		if build.has_tag("degenerate") and ratio > targets.degenerate_dps_ratio_max:
			report.flag(BalanceReport.WARN, "model: degenerate DPS", "%s vs %s" % [build.name, expected.name], "%.2fx" % ratio,
				"<= %.1fx" % targets.degenerate_dps_ratio_max, "single-target DPS vs %s" % boss.id)
	report.table("degenerate_dps", "Builds", "Degenerate and family builds: DPS against their act's main boss (Normal) vs the expected build (model)",
		PackedStringArray(["Build", "Tags", "Expected", "Boss", "DPS", "Expected DPS", "Ratio"]), rows)


# --- Monsters ---------------------------------------------------------------------------

## Every way a monster can come: plain, then each rank with each of its affixes (an Elite with
## each affix alone; Epic/Legendary: averaged as one row per rank with typical affixes listed).
func rank_variants() -> Array:
	var result: Array = [{ "rank": null, "affixes": [], "label": "plain" }]
	for rank in BalanceContent.ranks(content):
		if rank.affixes <= 0:
			result.append({ "rank": rank, "affixes": [], "label": String(rank.id) })
		elif rank.affixes == 1:
			for affix in content.elite_affixes:
				result.append({ "rank": rank, "affixes": [affix], "label": "%s %s" % [rank.id, affix.id] })
		else:
			# Every affix in turn plus the next ones (a fair spread of combinations).
			for i in content.elite_affixes.size():
				var picked: Array = []
				for k in rank.affixes:
					picked.append(content.elite_affixes[(i + k) % content.elite_affixes.size()])
				result.append({ "rank": rank, "affixes": picked, "label": "%s %s" % [rank.id, "+".join(picked.map(func(a: EliteAffixDef) -> String: return String(a.id)))] })
	return result


func _monster_tables() -> void:
	var all_rows: Array = []
	var md_rows: Array = []
	var curve_rows: Array = []
	var affix_rows: Array = []
	var results: Array = []
	var summoned := BalanceContent.summoners(content)
	var variants := rank_variants()
	var affix_effect := {}  # affix id -> [ttk ratios, dps ratios]
	var ladder := {}  # act -> rank id ("plain" too) -> [TTK, share of the hero's health lost while killing it], Normal
	for act_index in content.dungeon.acts.size():
		var act := content.dungeon.acts[act_index]
		var build := expected_build(act_index + 1)
		if build == null:
			continue
		var hero := player_for(build)
		var last_normal := boss_depth(act_index + 1) - 1
		for difficulty in difficulties:
			var curve_ttk: Array = []
			var curve_hits: Array = []
			var curve_dps: Array = []
			for monster in act.monsters:
				if monster == null:
					continue
				var depths := BalanceContent.monster_depths(content, act_index + 1, monster)
				if depths.is_empty():
					depths = [last_normal]  # only summoned or spawned here
				var row_depths: Array = depths if not quick else [depths.back()]
				for depth: int in row_depths:
					var rules := FloorRules.make(content.dungeon, difficulty, null, depth)
					var by_variant := {}
					for variant: Dictionary in variants:
						if variant.rank and depth < (variant.rank as MonsterRankDef).min_depth and variant.rank != content.dungeon.elite_rank:
							continue
						var foe := foe_numbers(monster, rules, variant.rank, variant.affixes, hero)
						var out := hero_output(hero, int(foe.defense), false)
						var ttk := ttk_on(foe, out)
						var taken: float = float(foe.dps) * ttk
						var hits_to_kill: float = hero.get_max_hp() / maxf(float(foe.average_hit), 0.01)
						by_variant[variant.label] = { "ttk": ttk, "foe": foe, "taken": taken, "hits_to_kill": hits_to_kill }
						var entry := {
							"act": act_index + 1, "monster": String(monster.id), "roles": BalanceContent.roles(monster),
							"depth": depth, "difficulty": BalanceContent.key(difficulty), "variant": variant.label,
							"rank": String((variant.rank as MonsterRankDef).id) if variant.rank else "plain",
							"hp": foe.hp, "armor": foe.defense, "hit": foe.average_hit, "dps": foe.dps, "ttk": ttk,
							"hits_to_kill_hero": hits_to_kill, "taken_while_killing": taken, "build": build.name,
							"spawns": monster.spawn_weight > 0, "summoned_by": summoned.get(monster.id, PackedStringArray()),
						}
						results.append(entry)
						all_rows.append([act_index + 1, String(monster.id), depth, BalanceContent.key(difficulty), variant.label,
							foe.hp, foe.defense, foe.average_hit, foe.dps, ttk, hits_to_kill, taken])
					if depth != depths.back():
						continue
					var plain: Dictionary = by_variant.plain
					if monster.spawn_weight > 0:
						curve_ttk.append(plain.ttk)
						curve_hits.append(plain.hits_to_kill)
						curve_dps.append(float(plain.foe.dps) / hero.get_max_hp())
					var is_normal := BalanceContent.key(difficulty) == "normal"
					var rank_ttk := {}
					if is_normal and monster.spawn_weight > 0:
						for label: String in by_variant:
							var key := label.get_slice(" ", 0)
							var cell: Dictionary = ladder.get_or_add(act_index + 1, {})
							cell.get_or_add(key, []).append([by_variant[label].ttk, by_variant[label].taken / maxf(hero.get_max_hp(), 1.0)])
					for label: String in by_variant:
						var rank_id := label.get_slice(" ", 0)
						if label == "plain":
							continue
						if not rank_ttk.has(rank_id):
							rank_ttk[rank_id] = []
						rank_ttk[rank_id].append(by_variant[label].ttk)
						if is_normal and rank_id == String(content.dungeon.elite_rank.id):
							var affix_id := label.get_slice(" ", 1)
							if not affix_effect.has(affix_id):
								affix_effect[affix_id] = [[], [], []]
							affix_effect[affix_id][0].append(by_variant[label].ttk / maxf(plain.ttk, 0.01))
							affix_effect[affix_id][1].append(float(by_variant[label].foe.dps) / maxf(float(plain.foe.dps), 0.01))
							affix_effect[affix_id][2].append(by_variant[label].taken / maxf(plain.taken, 0.01))
					if is_normal:
						var cells := [act_index + 1, String(monster.id), ", ".join(BalanceContent.roles(monster)), depth, plain.foe.hp, plain.foe.defense,
							plain.foe.average_hit, plain.foe.dps, plain.ttk, plain.hits_to_kill]
						for rank in BalanceContent.ranks(content):
							var list: Array = rank_ttk.get(String(rank.id), [])
							if list.is_empty():
								cells.append("-")
							else:
								cells.append(BalanceContent.mean(list))
						md_rows.append(cells)
						if monster.spawn_weight > 0:
							_check_monster(build, monster, depth, plain, rank_ttk)
			curve_rows.append([act_index + 1, BalanceContent.key(difficulty), build.name, BalanceContent.mean(curve_ttk),
				BalanceContent.mean(curve_hits), BalanceReport.pct(BalanceContent.mean(curve_dps))])
	_check_monster_curve(ladder)
	for affix_id: String in affix_effect:
		var values: Array = affix_effect[affix_id]
		affix_rows.append([affix_id, "x%.2f" % BalanceContent.mean(values[0]), "x%.2f" % BalanceContent.mean(values[1]), "x%.2f" % BalanceContent.mean(values[2])])
	report.data["monsters"] = results
	var rank_columns := PackedStringArray(["Act", "Monster", "Roles", "Depth", "HP", "Armor", "Hit on hero", "DPS on hero", "TTK s", "Hits to kill hero"])
	for rank in BalanceContent.ranks(content):
		rank_columns.append("TTK %s s" % rank.id)
	report.table("monsters", "Monsters", "Every monster of each act on Normal, at its act's last normal floor, against the act's expected build (model). Rank columns: average over its affixes",
		rank_columns, md_rows)
	report.table("monster_curve", "Monsters", "Monster curve: average common monster of each act (spawning ones) per difficulty, vs the act's expected build (model)",
		PackedStringArray(["Act", "Difficulty", "Build", "Avg TTK s", "Avg hits to kill hero", "Avg DPS on hero (share of max HP /s)"]), curve_rows)
	report.table("elite_affixes", "Monsters", "Elite affixes: effect on an Elite vs its plain kind (Normal, averaged over every act monster, model)",
		PackedStringArray(["Affix", "TTK", "DPS on hero", "Damage taken while killing it"]), affix_rows)
	report.table("monsters_all", "Monsters", "Every monster x depth x difficulty x rank/affix (model; the full list is in the CSV and data.json)",
		PackedStringArray(["Act", "Monster", "Depth", "Difficulty", "Variant", "HP", "Armor", "Hit", "DPS on hero", "TTK s", "Hits to kill hero", "Taken while killing"]), all_rows, 40, false)


func _check_monster(build: BalanceBuildDef, monster: MonsterDef, depth: int, plain: Dictionary, rank_ttk: Dictionary) -> void:
	var subject := "%s vs %s (normal, depth %d)" % [build.name, monster.id, depth]
	if plain.ttk < targets.common_ttk_min or plain.ttk > targets.common_ttk_max:
		report.flag(BalanceReport.WARN, "model: monster TTK", subject, BalanceReport.secs(plain.ttk), "%.1f-%.1f s" % [targets.common_ttk_min, targets.common_ttk_max],
			"%d HP, %d armor" % [plain.foe.hp, plain.foe.defense])
	if plain.hits_to_kill < targets.common_hits_to_kill_min:
		report.flag(BalanceReport.WARN, "model: monster hits to kill", subject, "%.1f hits" % plain.hits_to_kill, ">= %.0f" % targets.common_hits_to_kill_min,
			"average hit %.1f on %d max health" % [plain.foe.average_hit, player_for(build).get_max_hp()])
	for rank_id: String in rank_ttk:
		var wanted: Variant = targets.rank_ttk.get(rank_id)
		if wanted == null:
			continue
		var ttk := BalanceContent.mean(rank_ttk[rank_id])
		if ttk < (wanted as Vector2).x or ttk > (wanted as Vector2).y:
			report.flag(BalanceReport.WARN, "model: %s TTK" % rank_id, "%s vs %s %s (normal, depth %d)" % [build.name, rank_id, monster.id, depth],
				BalanceReport.secs(ttk), "%.0f-%.0f s" % [(wanted as Vector2).x, (wanted as Vector2).y], "average over its affixes")


## The commons' curve and the ranks' ladder on Normal (medians over each act's spawning monsters):
## a common costs a little more health to kill each act (x act_threat_step_min-max, like the
## bosses), within the common TTK target; each rank takes longer to kill than the one below it
## (plain < Elite < Epic < Legendary) and costs more health.
func _check_monster_curve(ladder: Dictionary) -> void:
	var rows: Array = []
	var previous := 0.0
	for act: int in ladder.keys():
		var cell: Dictionary = ladder[act]
		var medians := {}
		for key: String in cell:
			medians[key] = [BalanceContent.median(cell[key].map(func(v: Array) -> float: return v[0])),
				BalanceContent.median(cell[key].map(func(v: Array) -> float: return v[1]))]
		var plain: Array = medians.get("plain", [0.0, 0.0])
		var row := [act, BalanceReport.secs(plain[0]), _pct1(plain[1])]
		var step: float = plain[1] / previous if previous > 0.0 else 0.0
		row.append("x%.2f" % step if previous > 0.0 else "-")
		if plain[0] < targets.common_ttk_min or plain[0] > targets.common_ttk_max:
			report.flag(BalanceReport.WARN, "model: monster curve", "act %d commons (normal, median)" % act, BalanceReport.secs(plain[0]),
				"%.1f-%.1f s" % [targets.common_ttk_min, targets.common_ttk_max], "median time to kill of the act's commons")
		var step_max := targets.first_act_step_max if act == 2 else targets.act_threat_step_max
		if previous > 0.0 and (step < targets.monster_step_min or step > step_max):
			report.flag(BalanceReport.WARN, "model: monster curve", "act %d vs act %d commons (normal, median)" % [act, act - 1], "x%.2f" % step,
				"x%.2f-x%.1f" % [targets.monster_step_min, step_max], "share of the hero's health lost killing one, face to face: %s" % ("a flat stretch" if step < targets.monster_step_min else "a cliff"))
		previous = plain[1]
		var below: Array = plain
		var below_id := "plain"
		for rank_id in ["elite", "epic", "legendary"]:
			if not medians.has(rank_id):
				row.append("-")
				continue
			var m: Array = medians[rank_id]
			row.append("%s / %s" % [BalanceReport.secs(m[0]), _pct1(m[1])])
			if m[0] < below[0] * targets.rank_ladder_step_min or m[1] <= below[1]:
				report.flag(BalanceReport.WARN, "model: rank ladder", "act %d: %s vs %s (normal, median)" % [act, rank_id, below_id],
					"%s / %s vs %s / %s" % [BalanceReport.secs(m[0]), _pct1(m[1]), BalanceReport.secs(below[0]), _pct1(below[1])],
					"x%.1f+ longer and costlier" % targets.rank_ladder_step_min, "each rank a clearly tougher fight than the one below")
			below = m
			below_id = rank_id
		row.append("%s / %s" % [BalanceReport.secs(medians.get("shiny", [0.0, 0.0])[0]), _pct1(medians.get("shiny", [0.0, 0.0])[1])])
		rows.append(row)
	report.table("monster_ladder", "Monsters", "Commons' curve and ranks' ladder (Normal, medians over each act's spawning monsters, model): time to kill / share of the expected build's health lost killing one face to face; step = commons' share vs the previous act",
		PackedStringArray(["Act", "Common TTK", "Common health lost", "Step", "Elite", "Epic", "Legendary", "Shiny"]), rows)


## A share with one decimal ("1.4%"): the commons' costs are small numbers.
static func _pct1(value: float) -> String:
	return "%.1f%%" % (value * 100.0)


## Chance for a monster to come at each rank, per depth and difficulty (World.roll_elite order:
## the rare ranks first, then the plain elite).
func _rank_chances() -> void:
	var rows: Array = []
	var ranks := BalanceContent.ranks(content)
	for difficulty in difficulties:
		for depth in range(1, content.dungeon.total_floors() + 1):
			if content.dungeon.boss_for_depth(depth):
				continue
			var rules := FloorRules.make(content.dungeon, difficulty, null, depth)
			var left := 1.0
			var cells := [BalanceContent.key(difficulty), depth]
			var chances := {}
			for rank in content.dungeon.rare_ranks:
				var c := minf(rules.rank_chance(rank), 1.0) * left
				chances[rank.id] = c
				left -= c
			chances[content.dungeon.elite_rank.id] = minf(rules.elite_chance(), 1.0) * left
			for rank in ranks:
				cells.append(BalanceReport.pct(chances.get(rank.id, 0.0)) if chances.get(rank.id, 0.0) >= 0.005 else ("%.1f%%" % (chances.get(rank.id, 0.0) * 100.0)))
			rows.append(cells)
	var columns := PackedStringArray(["Difficulty", "Depth"])
	for rank in ranks:
		columns.append(String(rank.id))
	report.table("rank_chances", "Monsters", "Chance for a spawned monster to come at each rank (per depth and difficulty)", columns, rows, 24)


# --- Bosses -------------------------------------------------------------------------------

## A boss on a difficulty (and rank), phase by phase, against `hero`:
## { hp, phases: [{ from, to, defense, foe (foe_numbers), roar }] }.
func boss_profile(boss: BossDef, difficulty: DifficultyDef, hero: Player, rank: MonsterRankDef = null, affixes: Array = []) -> Dictionary:
	var depth := boss_depth(act_of(boss))
	var rules := FloorRules.make(content.dungeon, difficulty, null, depth)
	var ratios: Array[float] = [1.0]
	for phase in boss.phases:
		ratios.append(phase.hp_ratio)
	ratios.append(0.0)
	var bonus := StatBlock.new()
	var skill_list: Array = boss.skills
	var windup := 1.0
	var speed := 1.0
	var phases: Array = []
	var hp := 0
	for i in ratios.size() - 1:
		if i > 0:
			var phase := boss.phases[i - 1]
			if phase.bonuses:
				bonus = bonus.plus(phase.bonuses)
			if not phase.skills.is_empty():
				skill_list = phase.skills
			windup *= phase.windup_multiplier
			speed /= phase.cooldown_multiplier
		var foe := foe_numbers(boss, rules, rank, affixes, hero, bonus, skill_list, windup, speed)
		if i == 0:
			hp = foe.hp
		phases.append({ "from": ratios[i], "to": ratios[i + 1], "defense": foe.defense, "foe": foe,
			"roar": boss.phase_roar_time if i > 0 else 0.0 })
	var shock := rules.dungeon_damage(boss.shockwave_base_damage, boss.shockwave_damage_per_depth)
	return { "id": String(boss.id), "depth": depth, "hp": hp, "phases": phases, "shockwave": shock,
		"shockwave_after": boss.shockwave_after_hits, "shockwave_cooldown": boss.shockwave_cooldown, "rules": rules }


## Seconds to kill the boss with pure damage (no downtime): the model's TTK.
func boss_ttk(player: Player, profile: Dictionary) -> float:
	var time := 0.0
	for phase: Dictionary in profile.phases:
		var out := hero_output(player, int(phase.defense), true)
		var share: float = phase.from - phase.to
		var dps: float = out.dps
		if float(phase.foe.lifesteal) > 0.0:
			dps = maxf(dps - float(phase.foe.lifesteal) * float(phase.foe.dps), 0.01)
		time += float(profile.hp) * share / maxf(dps, 0.01) + phase.roar
	return time


## A face-tank fight, phase by phase: the hero stands in melee, hits, never dodges or drinks.
## { win, time, hp_left, death_time, healed, taken, heal_share, dps_in }.
func face_tank(player: Player, profile: Dictionary) -> Dictionary:
	var first := hero_output(player, int(profile.phases[0].defense), true)
	var max_hp: int = first.max_hp
	var hp: float = float(max_hp) + first.ward
	var revives: float = first.cheat_death
	var time := 0.0
	var healed := 0.0
	var taken := 0.0
	var hero_hits_per_s: float = first.attacks_per_s * first.hits_per_attack
	var cap := sustain_rate(max_hp, true)
	for phase: Dictionary in profile.phases:
		var out := hero_output(player, int(phase.defense), true)
		var foe: Dictionary = phase.foe
		var shock_rate := 0.0
		if int(profile.shockwave_after) > 0:
			shock_rate = minf(hero_hits_per_s / float(profile.shockwave_after), 1.0 / float(profile.shockwave_cooldown))
		var uptime_share := 1.0 / (1.0 + shock_rate * SHOCKWAVE_DOWNTIME)
		var in_dps: float = float(foe.dps) + shock_rate * float(profile.shockwave) + float(foe.thorns) * 0.0
		var capped: float = minf((out.lifesteal_hps + out.sustain_skill_hps) * uptime_share, cap)
		var heal_hps: float = capped + out.skill_heal_hps
		var dps: float = out.dps * uptime_share
		if float(foe.lifesteal) > 0.0:
			dps = maxf(dps - float(foe.lifesteal) * float(foe.dps), 0.01)
		var phase_time: float = float(profile.hp) * (phase.from - phase.to) / maxf(dps, 0.01) + phase.roar
		var net := heal_hps - in_dps
		if net >= 0.0:
			healed += minf(heal_hps * phase_time, in_dps * phase_time + (max_hp - minf(hp, max_hp)))
			taken += in_dps * phase_time
			hp = minf(float(max_hp), hp + net * phase_time)
		else:
			var left := phase_time
			while hp / -net < left:
				var lasts := hp / -net
				healed += heal_hps * lasts
				taken += in_dps * lasts
				left -= lasts
				if revives < 0.25:
					var dead_at := time + phase_time - left
					return { "win": false, "time": dead_at, "death_time": dead_at, "hp_left": 0.0,
						"healed": healed, "taken": taken, "heal_share": healed / maxf(taken, 1.0) }
				revives -= 0.5  # a Phoenix Feather: back to half health once per stack
				hp = max_hp * 0.5
			healed += heal_hps * left
			taken += in_dps * left
			hp += net * left
		time += phase_time
	return { "win": true, "time": time, "death_time": INF, "hp_left": hp, "healed": healed, "taken": taken,
		"heal_share": healed / maxf(taken, 1.0) }


func _boss_tables() -> void:
	var rows: Array = []
	var phase_rows: Array = []
	var rank_rows: Array = []
	var affix_rows: Array = []
	var results: Array = []
	var threat := {}  # "boss|difficulty" -> threat
	var boss_ranks: Array = [null]
	boss_ranks.append_array(BalanceContent.boss_ranks(content))
	for boss in bosses:
		var act := act_of(boss)
		var ref_build := expected_build(act)
		for difficulty in difficulties:
			var d_key := BalanceContent.key(difficulty)
			for build in builds:
				if build.act != act:
					continue
				var player := player_for(build)
				for rank: Variant in boss_ranks:
					if rank != null and (build != ref_build or (quick and d_key != "normal")):
						continue  # ranks: the expected build only
					var profile := boss_profile(boss, difficulty, player, rank)
					var ttk := boss_ttk(player, profile)
					var tank := face_tank(player, profile)
					var first: Dictionary = profile.phases[0].foe
					var last: Dictionary = profile.phases.back().foe
					var out := hero_output(player, int(profile.phases[0].defense), true)
					var cap := sustain_rate(player.get_max_hp(), true)
					var heal_hps: float = minf(out.lifesteal_hps + out.sustain_skill_hps, cap) + out.skill_heal_hps
					var hits_first: float = player.get_max_hp() / maxf(float(first.average_hit), 0.01)
					var hits_last: float = player.get_max_hp() / maxf(float(last.average_hit), 0.01)
					var fight_threat: float = float(first.dps) * ttk / player.get_max_hp()
					var rank_id: String = String((rank as MonsterRankDef).id) if rank else "plain"
					var entry := {
						"boss": String(boss.id), "act": act, "difficulty": d_key, "build": build.name, "rank": rank_id,
						"tags": build.tags, "boss_hp": profile.hp, "boss_defense": profile.phases[0].defense,
						"hero_max_hp": player.get_max_hp(), "hero_defense": player.get_stats().defense,
						"dps": out.dps, "ttk": ttk, "heal_hps": heal_hps, "sustain_cap": cap, "boss_dps_p1": first.dps,
						"boss_dps_last": last.dps, "hits_to_kill_p1": hits_first, "hits_to_kill_last": hits_last,
						"facetank_win": tank.win, "facetank_time": tank.time, "facetank_hp_left": tank.hp_left,
						"facetank_heal_share": tank.heal_share, "facetank_taken": tank.taken, "threat": fight_threat,
					}
					results.append(entry)
					if rank == null:
						rows.append([String(boss.id), act, d_key, build.name, profile.hp, profile.phases[0].defense, out.dps, ttk,
							first.dps, last.dps, heal_hps, hits_first, hits_last,
							"WINS (%.0f%% left)" % (100.0 * tank.hp_left / player.get_max_hp()) if tank.win else "dies at %.0f s" % tank.death_time,
							BalanceReport.pct(tank.heal_share), BalanceReport.pct(fight_threat)])
						_check_boss(entry, build, boss, difficulty)
						if build == ref_build:
							threat["%s|%s" % [boss.id, d_key]] = fight_threat
					else:
						rank_rows.append([String(boss.id), d_key, rank_id, "x%.2f" % (rank as MonsterRankDef).boss_hp_multiplier, profile.hp, ttk,
							"WINS" if tank.win else "dies at %.0f s" % tank.death_time, BalanceReport.pct(fight_threat)])
						if d_key == "normal" and ttk > targets.ranked_boss_ttk_max:
							report.flag(BalanceReport.WARN, "model: ranked boss TTK", "%s vs %s %s (normal)" % [build.name, rank_id, boss.id], BalanceReport.secs(ttk),
								"<= %.0f s" % targets.ranked_boss_ttk_max, "boss HP x%.2f" % (rank as MonsterRankDef).boss_hp_multiplier)
		if ref_build:
			var hero := player_for(ref_build)
			var profile := boss_profile(boss, normal(), hero)
			for p: Dictionary in profile.phases:
				var foe: Dictionary = p.foe
				var skill_text := PackedStringArray()
				for s: Dictionary in foe.skills:
					var flags := ""
					if not s.usable:
						flags = " (not at melee)"
					elif float(s.below) < 1.0:
						flags = " (below %d%%)" % roundi(float(s.below) * 100.0)
					skill_text.append("%s %.0f x%d /%.1fs%s%s" % [s.id, s.damage, s.hits, 1.0 / s.rate, " +%d adds" % s.summons if int(s.summons) > 0 else "", flags])
				phase_rows.append([String(boss.id), "%d-%d%%" % [roundi(p.to * 100), roundi(p.from * 100)], p.defense, foe.power,
					foe.melee, foe.cycle, "; ".join(skill_text), foe.dps, hero.get_max_hp() / maxf(float(foe.average_hit), 0.01)])
			for affix in content.elite_affixes:
				var with_affix := boss_profile(boss, normal(), hero, null, [affix])
				var plain_ttk := boss_ttk(hero, profile)
				var affix_ttk := boss_ttk(hero, with_affix)
				affix_rows.append([String(boss.id), String(affix.id), "x%.2f" % (affix_ttk / maxf(plain_ttk, 0.01)),
					"x%.2f" % (float(with_affix.phases[0].foe.dps) / maxf(float(profile.phases[0].foe.dps), 0.01))])
	_check_curve(threat)
	report.data["bosses"] = results
	report.table("boss_fights", "Bosses", "Every boss vs the builds of its act, every difficulty (model; TTK at 100% uptime; threat = boss DPS x TTK / max health: the share of the hero's health a face-tank fight costs)",
		PackedStringArray(["Boss", "Act", "Difficulty", "Build", "Boss HP", "Armor", "Hero DPS", "TTK s", "Boss DPS (p1)", "Boss DPS (last)", "Heal/s (capped)", "Hits to kill (p1)", "Hits to kill (last)", "Face-tank", "Heal / taken", "Threat"]), rows)
	report.table("boss_phases", "Bosses", "Boss phases on Normal vs the act's expected build (damage after its armor)",
		PackedStringArray(["Boss", "HP range", "Armor", "Power", "Melee hit", "Melee cycle s", "Skills (dmg x hits / cooldown)", "DPS in", "Hits to kill"]), phase_rows)
	report.table("boss_ranks", "Bosses", "Boss ranks (World.roll_boss_rank: Epic, Legendary, Shiny; boss HP multiplier) vs the act's expected build (model, affixes left out: see the next table)",
		PackedStringArray(["Boss", "Difficulty", "Rank", "HP mult", "Boss HP", "TTK s", "Face-tank", "Threat"]), rank_rows)
	report.table("boss_affixes", "Bosses", "Each elite affix on each boss (Normal, model): TTK and boss DPS vs the plain boss",
		PackedStringArray(["Boss", "Affix", "TTK", "Boss DPS"]), affix_rows)


func _check_boss(entry: Dictionary, build: BalanceBuildDef, boss: BossDef, difficulty: DifficultyDef) -> void:
	var d_key := BalanceContent.key(difficulty)
	var subject := "%s vs %s (%s)" % [build.name, boss.id, d_key]
	if build.has_tag("expected") and d_key == "normal":
		var ttk: float = entry.ttk
		if ttk < targets.boss_ttk_min or ttk > targets.boss_ttk_max:
			report.flag(BalanceReport.WARN, "model: boss TTK", subject, BalanceReport.secs(ttk), "%d-%d s" % [targets.boss_ttk_min, targets.boss_ttk_max],
				"expected build kills the boss %s (100%% uptime)" % ("too fast" if ttk < targets.boss_ttk_min else "too slowly"))
		var hits: float = entry.hits_to_kill_p1
		if hits < targets.boss_hits_to_kill_min or hits > targets.boss_hits_to_kill_max:
			report.flag(BalanceReport.WARN, "model: boss hits to kill", subject, "%.1f hits" % hits, "%d-%d" % [targets.boss_hits_to_kill_min, targets.boss_hits_to_kill_max],
				"average boss hit (phase 1) vs the expected build's max health")
	var must_lose := false
	for tag in targets.facetank_must_lose_tags:
		must_lose = must_lose or build.has_tag(tag)
	if must_lose and BalanceContent.rank_of(d_key) >= BalanceContent.rank_of(String(targets.facetank_must_lose_from)) and entry.facetank_win:
		report.flag(BalanceReport.WARN, "model: face-tank wins", subject, "wins with %.0f HP left" % entry.facetank_hp_left, "must die from %s" % targets.facetank_must_lose_from,
			"standing and hitting beats the boss (model)")
	var share_max := targets.heal_share_max_expected if build.has_tag("expected") else targets.heal_share_max_degenerate
	var felt: bool = float(entry.facetank_taken) >= targets.heal_share_min_taken * float(entry.hero_max_hp)
	if not build.has_tag("baseline") and felt and entry.facetank_heal_share > share_max and d_key == "normal":
		report.flag(BalanceReport.WARN, "model: heal share", subject, BalanceReport.pct(entry.facetank_heal_share), "<= %s" % BalanceReport.pct(share_max),
			"healing during the face-tank fight / damage taken")


## The curve (pillar 5): each act's threat vs the previous act's, and each difficulty vs Normal.
func _check_curve(threat: Dictionary) -> void:
	var rows: Array = []
	var acts := content.dungeon.acts.size()
	var keys := difficulties.map(func(d: DifficultyDef) -> String: return BalanceContent.key(d))
	for act in range(1, acts + 1):
		for d_key: String in keys:
			var values: Array = []
			var normal_values: Array = []
			for boss in content.dungeon.acts[act - 1].all_bosses():
				if threat.has("%s|%s" % [boss.id, d_key]):
					values.append(threat["%s|%s" % [boss.id, d_key]])
				if threat.has("%s|normal" % boss.id):
					normal_values.append(threat["%s|normal" % boss.id])
			if values.is_empty():
				continue
			var mean := BalanceContent.mean(values)
			var vs_normal := mean / maxf(BalanceContent.mean(normal_values), 0.0001) if not normal_values.is_empty() else -1.0
			var step := -1.0
			if act > 1:
				var previous: Array = []
				for boss in content.dungeon.acts[act - 2].all_bosses():
					if threat.has("%s|%s" % [boss.id, d_key]):
						previous.append(threat["%s|%s" % [boss.id, d_key]])
				if not previous.is_empty():
					step = mean / maxf(BalanceContent.mean(previous), 0.0001)
			rows.append([act, d_key, BalanceReport.pct(mean), "x%.2f" % vs_normal if vs_normal >= 0.0 else "-", "x%.2f" % step if step >= 0.0 else "-"])
			if d_key == "normal" and step >= 0.0 and (step < targets.act_threat_step_min or step > targets.act_threat_step_max):
				report.flag(BalanceReport.WARN, "model: act curve", "act %d vs act %d (normal)" % [act, act - 1], "x%.2f" % step,
					"x%.1f-x%.1f" % [targets.act_threat_step_min, targets.act_threat_step_max], "boss threat for the expected build (%s)" % BalanceReport.pct(mean))
			var band: Variant = targets.difficulty_threat.get(d_key)
			if band != null and vs_normal >= 0.0 and (vs_normal < (band as Vector2).x or vs_normal > (band as Vector2).y):
				report.flag(BalanceReport.WARN, "model: difficulty curve", "act %d, %s vs normal" % [act, d_key], "x%.2f" % vs_normal,
					"x%.1f-x%.1f" % [(band as Vector2).x, (band as Vector2).y], "boss threat for the expected build")
	report.table("curve", "Bosses", "The curve: boss threat (share of the hero's health a face-tank fight costs) for each act's expected build, per difficulty; act step = vs the previous act",
		PackedStringArray(["Act", "Difficulty", "Threat", "vs Normal", "Act step"]), rows)


# --- Weapons -------------------------------------------------------------------------------

## Every armor value monsters and bosses have (any depth, any difficulty, phases and Armored
## elites included), sorted.
func armor_values() -> Array[int]:
	var values: Array[int] = [0]
	var foes: Array = content.all_monsters()
	foes.append_array(BalanceContent.bosses(content))
	var extra := [0]
	for affix in content.elite_affixes:
		if affix.perk and affix.perk.bonuses and affix.perk.bonuses.defense > 0:
			extra.append(affix.perk.bonuses.defense)
	for foe: MonsterDef in foes:
		var base := foe.stats.defense
		var phase_bonus := [0]
		if foe is BossDef:
			var total := 0
			for phase in (foe as BossDef).phases:
				if phase.bonuses:
					total += phase.bonuses.defense
					phase_bonus.append(total)
		for p: int in phase_bonus:
			for e: int in extra:
				if not values.has(base + p + e):
					values.append(base + p + e)
	values.sort()
	return values


func _weapon_tables() -> void:
	var armors := armor_values()
	var rows: Array = []
	var md_rows: Array = []
	var skill_rows: Array = []
	var entries: Array = []
	var weapons := BalanceContent.weapons()
	for act in range(1, content.dungeon.acts.size() + 1):
		var ref_build := expected_build(act)
		if ref_build == null:
			continue
		var boss := content.dungeon.acts[act - 1].boss
		var boss_defense := FloorRules.make(content.dungeon, normal(), null, boss_depth(act)).scale_monster(boss.stats, true).defense
		var by_rarity := {}
		for rarity in 4:
			for weapon in weapons:
				var build := ref_build.duplicate() as BalanceBuildDef
				build.weapon = weapon
				build.weapon_rarity = rarity
				build.weapon_affixes = PackedStringArray()
				build.runes = PackedStringArray()
				var player := BalanceBuild.make_player(build, content)
				var at_armor := []
				for armor in armors:
					at_armor.append(hero_output(player, armor, false).dps)
				var vs_boss := hero_output(player, boss_defense, true)
				var open := hero_output(player, 0, false)
				if rarity == 0 and act == 2:
					for s: Dictionary in open.skill_rows:
						skill_rows.append([String(weapon.id), s.id, s.damage, s.cooldown, s.damage / maxf(s.cooldown, 0.01)])
				player.free()
				var e := { "act": act, "weapon": String(weapon.id), "rarity": ItemRarity.NAMES[rarity],
					"kind": "ranged" if weapon.kind == WeaponDef.Kind.RANGED else "melee", "attacks_per_s": open.attacks_per_s,
					"power": open.power, "dps_by_armor": at_armor, "dps_boss": vs_boss.dps, "skill_dps_boss": vs_boss.skill_dps }
				entries.append(e)
				if not by_rarity.has(rarity):
					by_rarity[rarity] = []
				by_rarity[rarity].append(e)
				var row := [act, String(weapon.id), ItemRarity.NAMES[rarity], e.kind, open.attacks_per_s, open.power]
				row.append_array(at_armor)
				row.append(vs_boss.dps)
				rows.append(row)
		for rarity: int in by_rarity:
			var group: Array = by_rarity[rarity]
			var median := BalanceContent.median(group.map(func(e: Dictionary) -> float: return e.dps_boss))
			for e: Dictionary in group:
				var ratio: float = e.dps_boss / maxf(median, 0.01)
				e["ratio_to_median"] = ratio
				if rarity == 0 or not quick:
					if rarity == 0:
						md_rows.append([act, e.weapon, e.kind, e.attacks_per_s, e.power, e.dps_by_armor[0], e.dps_boss, e.skill_dps_boss, "%.2fx" % ratio])
					if ratio < targets.weapon_dps_ratio_min or ratio > targets.weapon_dps_ratio_max:
						report.flag(BalanceReport.WARN, "model: weapon DPS", "%s %s (act %d hero vs %s)" % [e.rarity, e.weapon, act, boss.id],
							"%.2fx median" % ratio, "%.1f-%.1fx" % [targets.weapon_dps_ratio_min, targets.weapon_dps_ratio_max],
							"%.1f DPS vs a median of %.1f (armor %d)" % [e.dps_boss, median, boss_defense])
	report.data["weapons"] = entries
	report.data["armor_values"] = armors
	report.table("weapons", "Weapons", "Weapons (Common) on each act's expected hero: DPS = hits/s x average hit (variance, crit, armor) + skills + statuses (model)",
		PackedStringArray(["Act", "Weapon", "Kind", "Attacks/s", "Power", "DPS (armor 0)", "DPS vs act boss", "of which skills", "vs median"]), md_rows)
	var columns := PackedStringArray(["Act", "Weapon", "Rarity", "Kind", "Attacks/s", "Power"])
	for armor in armors:
		columns.append("armor %d" % armor)
	columns.append("vs act boss")
	report.table("weapons_armor", "Weapons", "Every weapon x rarity x every armor value monsters have (%s), DPS on each act's expected hero (model)" % ", ".join(armors.map(func(a: int) -> String: return str(a))),
		columns, rows, 64)
	report.table("weapon_skills", "Weapons", "Weapon skills on the act II expected hero (Common weapon, armor 0): damage per use, cooldown after its cooldown reduction",
		PackedStringArray(["Weapon", "Skill", "Damage per use", "Cooldown s", "DPS"]), skill_rows)


# --- Perks (static estimate; the lab measures them) -----------------------------------------

## A build's fight power against its act's main boss (Normal): [ttk, time to die standing in
## melee] and in a room of ROOM_PACK common monsters: [clear time, time to die].
func fight_power(player: Player, act: int) -> Dictionary:
	var boss := content.dungeon.acts[act - 1].boss
	var profile := boss_profile(boss, normal(), player)
	var out := hero_output(player, int(profile.phases[0].defense), true)
	var foe: Dictionary = profile.phases[0].foe
	var ehp: float = player.get_max_hp() * (1.0 + out.cheat_death) + out.ward
	var heal: float = minf(out.lifesteal_hps + out.sustain_skill_hps, sustain_rate(player.get_max_hp(), true)) + out.skill_heal_hps
	var ttd := minf(ehp / maxf(float(foe.dps) - heal, 0.001), TTD_CAP) if float(foe.dps) > heal else TTD_CAP
	var rules := FloorRules.make(content.dungeon, normal(), null, boss_depth(act) - 1)
	var weight := 0.0
	var ttk := 0.0
	var room_dps := 0.0
	var room_hits := 0.0
	for monster in content.dungeon.acts[act - 1].monsters:
		if monster == null or monster.spawn_weight <= 0:
			continue
		var numbers := foe_numbers(monster, rules, null, [], player)
		var mo := hero_output(player, int(numbers.defense), false)
		weight += monster.spawn_weight
		ttk += ttk_on(numbers, mo) * monster.spawn_weight
		room_dps += float(numbers.dps) * monster.spawn_weight
		room_hits += float(numbers.hits_per_s) * monster.spawn_weight
	ttk /= maxf(weight, 1.0)
	room_dps = room_dps / maxf(weight, 1.0) * ROOM_PACK
	room_hits = room_hits / maxf(weight, 1.0) * ROOM_PACK
	if room_hits > 1.0 / content.player.hit_invulnerability:
		room_dps *= (1.0 / content.player.hit_invulnerability) / room_hits
	var room_out := hero_output(player, 1, false)
	var room_clear: float = ttk * ROOM_PACK / (1.0 + room_out.chain_dps / maxf(room_out.dps, 0.01))
	var room_heal: float = minf(room_out.lifesteal_hps + room_out.sustain_skill_hps + room_out.kill_heal / maxf(ttk, 0.1), sustain_rate(player.get_max_hp(), false)) + room_out.skill_heal_hps
	var room_ttd := minf(ehp / maxf(room_dps - room_heal, 0.001), TTD_CAP) if room_dps > room_heal else TTD_CAP
	return { "boss_ttk": boss_ttk(player, profile), "boss_ttd": ttd, "room_clear": room_clear, "room_ttd": room_ttd,
		"dps": out.dps, "ehp": ehp, "heal": heal }


func _perk_table() -> void:
	var ref_build := BalanceBuild.find(all_builds, targets.perk_reference_build)
	if ref_build == null:
		report.flag(BalanceReport.ERROR, "targets", "perk_reference_build", targets.perk_reference_build, "an existing build", "no such build: perk values skipped")
		return
	var base_player := BalanceBuild.make_player(ref_build, content)
	var base := fight_power(base_player, ref_build.act)
	base_player.free()
	var entries: Array = []
	for perk in BalanceContent.perks():
		var build := ref_build.duplicate() as BalanceBuildDef
		build.perks = ref_build.perks.duplicate()
		build.perks[String(perk.id)] = perk.max_stacks
		var player := BalanceBuild.make_player(build, content)
		var power := fight_power(player, ref_build.act)
		player.free()
		var boss_value: float = (base.boss_ttk / maxf(power.boss_ttk, 0.01)) * (power.boss_ttd / maxf(base.boss_ttd, 0.01)) - 1.0
		var room_value: float = (base.room_clear / maxf(power.room_clear, 0.01)) * (power.room_ttd / maxf(base.room_ttd, 0.01)) - 1.0
		entries.append({ "perk": String(perk.id), "rarity": "relic" if perk.rarity == PerkDef.Rarity.RARE else "common",
			"stacks": perk.max_stacks, "boss_value": boss_value, "room_value": room_value,
			"boss_ttk": power.boss_ttk, "boss_ttd": power.boss_ttd, "room_clear": power.room_clear, "room_ttd": power.room_ttd })
	var rows: Array = []
	for rarity in ["common", "relic"]:
		var group := entries.filter(func(e: Dictionary) -> bool: return e.rarity == rarity)
		group.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.boss_value + a.room_value > b.boss_value + b.room_value)
		for e: Dictionary in group:
			rows.append([e.perk, e.rarity, e.stacks, BalanceReport.delta(e.boss_value), BalanceReport.delta(e.room_value),
				e.boss_ttk, e.boss_ttd, e.room_clear, e.room_ttd])
	report.data["perks_model"] = { "reference": ref_build.name, "base": base, "values": entries }
	report.table("perks_model", "Marginal values", "Perk values at max level on %s, static estimate (fight power = faster kill x longer life, vs the act's main boss on Normal and vs a room of %d monsters; TTD capped at %d s). The lab measures them (tables above)" % [ref_build.name, ROOM_PACK, TTD_CAP],
		PackedStringArray(["Perk", "Rarity", "Stacks", "Boss value", "Room value", "Boss TTK s", "Boss TTD s", "Room clear s", "Room TTD s"]), rows)


# --- The floors' curve ------------------------------------------------------------------------

## Every normal floor (each difficulty): what a room of it costs, face to face, the hero an
## average player has there (BalanceBuild.hero_at: what he brought into the act on its first
## floor, the act's expected build later) and the same hero with the starting weapon (Common,
## item level 1). A room = the floor's room
## size of monsters drawn by spawn weight, each at a rank with the floor's own chances (rank cost:
## the mean over its affixes). The model's view of the curve the gauntlet measures on the engine
## (its "curve" part): deterministic, every floor, every difficulty.
func _floor_curve() -> void:
	var rows: Array = []
	var by_act := {}  # difficulty -> act -> [room costs] (the hero there)
	var variants := rank_variants()
	var starters := {}
	for act_index in content.dungeon.acts.size():
		var act := content.dungeon.acts[act_index]
		var first := content.dungeon.first_depth(act_index)
		for depth in range(first, boss_depth(act_index + 1)):
			var at := BalanceBuild.hero_at(all_builds, content, depth)
			if at == null:
				continue
			if not starters.has(at):
				starters[at] = BalanceBuild.with_starter_weapon(all_builds, content, at)
			var heroes: Array[BalanceBuildDef] = [at]
			if starters[at]:
				heroes.append(starters[at])
			for difficulty in difficulties:
				var rules := FloorRules.make(content.dungeon, difficulty, null, depth)
				var room := _room_size(depth, difficulty)
				for build in heroes:
					var hero := player_for(build)
					var weight_sum := 0.0
					var cost := 0.0
					var plain_cost := 0.0
					for monster in act.monsters:
						if monster == null or monster.spawn_weight <= 0 or depth < monster.min_depth:
							continue
						var w := float(monster.spawn_weight)
						var per_rank := {}  # rank (or null) -> [costs over its affixes]
						for variant: Dictionary in variants:
							var rank: MonsterRankDef = variant.rank
							if rank and depth < rank.min_depth and rank != content.dungeon.elite_rank:
								continue
							var foe := foe_numbers(monster, rules, rank, variant.affixes, hero)
							var ttk := ttk_on(foe, hero_output(hero, int(foe.defense), false))
							per_rank.get_or_add(rank, []).append(minf(float(foe.dps) * ttk / maxf(hero.get_max_hp(), 1.0), 2.0))
						var plain := BalanceContent.mean(per_rank.get(null, [0.0]))
						var expected := 0.0
						var rest := 1.0
						for rank in content.dungeon.rare_ranks:
							if rank and per_rank.has(rank):
								var p := rest * rules.rank_chance(rank)
								expected += p * BalanceContent.mean(per_rank[rank])
								rest -= p
						var elite := content.dungeon.elite_rank
						if elite and per_rank.has(elite):
							var p := rest * rules.elite_chance()
							expected += p * BalanceContent.mean(per_rank[elite])
							rest -= p
						expected += rest * plain
						weight_sum += w
						cost += w * expected
						plain_cost += w * plain
					if weight_sum <= 0.0:
						continue
					var per_monster := cost / weight_sum
					var room_cost := per_monster * room
					var d_key := BalanceContent.key(difficulty)
					var starter := build.name.ends_with("+starter_weapon")
					rows.append([depth, act_index + 1, d_key, build.name, room, _pct1(plain_cost / weight_sum), _pct1(per_monster), BalanceReport.pct(room_cost)])
					report.data.get_or_add("floor_curve", []).append({ "depth": depth, "act": act_index + 1, "difficulty": d_key, "hero": build.name,
						"starter": starter, "room": room, "common": plain_cost / weight_sum, "per_monster": per_monster, "room_cost": room_cost })
					if not starter:
						by_act.get_or_add(d_key, {}).get_or_add(act_index + 1, []).append(room_cost)
	report.table("floor_curve", "Monsters", "The floors' curve (model): every normal floor, a room of its monsters (its room size, drawn by spawn weight, ranks with the floor's chances) vs the hero an average player has there (on an act's first floor what he brought in: the previous act's expected build, a fresh hero in act I; later the act's expected build) and the same hero with the starting weapon; cost = share of max Health lost killing them face to face",
		PackedStringArray(["Depth", "Act", "Difficulty", "Hero", "Monsters a room", "A common", "A monster (ranks counted)", "A room"]), rows, 60)
	_check_floor_curve(by_act)


## Keeper's floors: act I's rooms gentle, then no act's rooms cheaper than the last's (no dip).
## Not a step's size: the hero's power is a step at each act (an act's first floor meets what he
## brought in, the next ones the act's expected build), so this curve is a saw; the commons' curve
## ("model: monster curve") holds the steps.
func _check_floor_curve(by_act: Dictionary) -> void:
	var keeper: Dictionary = by_act.get("normal", {})
	var previous := 0.0
	var acts := keeper.keys()
	acts.sort()
	for act: int in acts:
		var cost := BalanceContent.mean(keeper[act])
		if act == 1 and cost > targets.curve_first_act_cost_max:
			report.flag(BalanceReport.WARN, "model: floor curve", "act I rooms (normal, a fresh hero)", BalanceReport.pct(cost),
				"<= %s" % BalanceReport.pct(targets.curve_first_act_cost_max), "the first floors are where a player learns: they stay gentle")
		if previous > 0.0:
			var step := cost / previous
			if step < targets.act_threat_step_min:
				report.flag(BalanceReport.WARN, "model: floor curve", "act %d vs act %d rooms (normal, the hero there)" % [act, act - 1], "x%.2f" % step,
					">= x%.1f" % targets.act_threat_step_min, "a dip: this act's floors cost less than the last's")
		previous = cost


## Monsters in a room at `depth` on `difficulty` (as BalanceLab.room_size()).
func _room_size(depth: int, difficulty: DifficultyDef) -> int:
	var config := content.dungeon
	var rules := FloorRules.make(config, difficulty, null, depth)
	var base := roundi((config.monsters_per_room_min + config.monsters_per_room_max) * 0.5)
	return mini(base + rules.extra_monsters(), config.max_monsters_per_room + difficulty.extra_monsters)
