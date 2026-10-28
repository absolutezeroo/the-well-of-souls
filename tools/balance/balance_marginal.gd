class_name BalanceMarginal
extends Node
## Marginal values, measured on the engine (BalanceLab): every perk at each level, every relic,
## every family's bonus, every rune, every item affix, every shrine upgrade level and every
## encounter outcome, added ALONE to each act's expected build (Normal, its act's last normal
## floor). Every measure starts on a fresh run of the same seed (repeatable to the frame):
## - DPS, boss time to kill, sustain against a boss: the act's main boss as a dummy (doesn't
##   fight back; its health scaled so the base build needs ~DUMMY_SECONDS: phases, roars and
##   execute thresholds still happen). The hero is untouchable and held at 45% health once the
##   boss is half dead: low-health bonuses count for half the fight, and every heal from hits,
##   kills and skills shows (Health/s, the budget of a boss fight applied);
## - pack clear time: a room of the act's monsters (room size + PACK_EXTRA) that don't fight back,
##   spread around the hero, the hero held at 90% health (kill heals show): cleaves, chains,
##   bursts and kill effects count (DUMMY_ROOMS placements, averaged);
## - boss time to die: (max health + ward) x (1 + revives x half) / (the act boss' damage per
##   second on this hero, after its armor, from the model - sustain per second), at most TTD_CAP;
## - effective health vs the act's monsters (armor on their hits), and, at max level, damage
##   taken in LIVE_ROOMS real rooms (face-tank; informative: chaotic, not in the value).
## value = offense x defense - 1, offense = sqrt(boss TTK ratio x pack clear ratio), defense =
## boss time-to-die ratio, each ratio kept within 1/RATIO_CLAMP..RATIO_CLAMP. Ranked per category at max level; a pick worth more than
## perk_value_max_vs_median (or less than perk_value_min_vs_median) times its category's median
## is flagged. A perk the build already has is measured from the build without it (its families
## kept awake: the perk's own worth; the family's bonus is measured on its own).

const DUMMY_SECONDS := 15.0
const DUMMY_LIMIT := 60.0
## Monsters added to the act's room size for the pack dummy and the live rooms.
const PACK_EXTRA := 2
const PACK_LIMIT := 40.0
const LIVE_ROOMS := 1
## Dummy rooms per measure (placements and random numbers differ), averaged.
const DUMMY_ROOMS := 2
## Each part of the value (boss TTK, pack clear, boss time to die ratios) is kept within
## [1 / RATIO_CLAMP, RATIO_CLAMP]: one part can't swamp the value (an act I room wiped by one
## skill, a hero who out-heals the boss).
const RATIO_CLAMP := 5.0
## Boss time to die counts up to this (s): surviving longer than any fight adds nothing.
const TTD_CAP := 200.0
const CATEGORIES := ["perk", "relic", "family", "rune", "affix", "upgrade", "encounter"]

var lab: BalanceLab
## Units of work (BalanceJobs): each build measured is one, kept and shared between workers.
var jobs := BalanceJobs.new()
var content: ContentDB
var targets: BalanceTargets
var all_builds: Array[BalanceBuildDef] = []
var seed_value := 1
## Acts measured (all by default; --quick: act II only, a few variants).
var acts: Array[int] = []
var quick := false
## Only these picks (ids; --picks): a targeted measure of new content next to a few known ones.
var picks := PackedStringArray()
var verbose := true

## Per act: { base, hp_scale, room, raw_hits, session, boss, boss_rules }.
var _ctx := {}
var _model: BalanceModel


func run() -> BalanceReport:
	var report := BalanceReport.new()
	report.title = "Balance marginal values"
	var started := Time.get_ticks_msec()
	_model = BalanceModel.new(content, targets, all_builds)
	lab.override_chances()
	if acts.is_empty():
		for i in content.dungeon.acts.size():
			acts.append(i + 1)
	var rows: Array = []
	var results: Array = []
	var base_rows: Array = []
	for act in acts:
		var expected := BalanceBuild.expected(all_builds, act)
		if expected == null:
			continue
		var ctx := await _setup(act, expected)
		var base: Variant = ctx.base
		var repeat: Variant = await measure_unit(act, expected, seed_value, true, "repeat")
		var other_seed: Variant = await measure_unit(act, expected, seed_value + 101, true)
		if base != null and repeat != null and other_seed != null:
			base_rows.append([act, expected.name, base.dps, base.boss_ttk, base.pack_clear, base.boss_dps_in, base.sustain_boss, base.boss_ttd,
				base.ehp, base.live_taken, BalanceReport.delta(_value(base, repeat).value), BalanceReport.delta(_value(base, other_seed).value)])
		var variants := variants_for(expected)
		if quick:
			variants = variants.filter(func(v: Dictionary) -> bool: return ["vampirism", "strength", "leech_rune", "sharp", "might", "blood"].has(v.id))
		if not picks.is_empty():
			variants = variants.filter(func(v: Dictionary) -> bool: return picks.has(String(v.id)))
		var bases := { "": base }
		var count := 0
		for v: Dictionary in variants:
			count += 1
			var from_key: String = v.get("from", "")
			if not bases.has(from_key):
				bases[from_key] = await measure_unit(act, v.from_build, seed_value, true)
			var top: bool = int(v.level) >= int(v.max_level)
			var measured: Variant = await measure_unit(act, v.build, seed_value, top)
			if measured == null or bases[from_key] == null:
				continue  # another worker's
			var reference: Dictionary = bases[from_key]
			var m: Dictionary = measured
			var value := _value(reference, m)
			var entry := {
				"act": act, "category": v.category, "id": v.id, "level": v.level, "max_level": v.max_level, "label": v.label,
				"value": value.value, "offense": value.offense, "defense": value.defense,
				"dps": m.dps / maxf(reference.dps, 0.01) - 1.0, "boss_ttk": m.boss_ttk, "boss_ttk_delta": reference.boss_ttk / maxf(m.boss_ttk, 0.01) - 1.0,
				"pack_clear": m.pack_clear, "pack_clear_delta": reference.pack_clear / maxf(m.pack_clear, 0.01) - 1.0,
				"boss_ttd_delta": m.boss_ttd / maxf(reference.boss_ttd, 0.01) - 1.0, "ehp_delta": m.ehp / maxf(reference.ehp, 0.01) - 1.0,
				"sustain": m.sustain_boss - reference.sustain_boss, "sustain_pack": m.sustain_pack - reference.sustain_pack,
				"taken_delta": (m.live_taken + 1.0) / (reference.live_taken + 1.0) - 1.0 if top else NAN,
				"deaths": m.deaths, "from": from_key, "heal_sources": m.heal_sources,
			}
			results.append(entry)
			if verbose and (count % 20 == 0 or count == variants.size()):
				print("  marginal: act %d, %d/%d (%s)" % [act, count, variants.size(), v.label])
		await lab.close(ctx.session)
	lab.restore_chances()
	_encounters(results)
	_rank(report, results)
	for e: Dictionary in results:
		rows.append([e.act, e.category, e.label, "%d/%d" % [e.level, e.max_level] if e.max_level > 0 else "-", BalanceReport.delta(e.value),
			BalanceReport.delta(e.dps), BalanceReport.delta(e.boss_ttk_delta), BalanceReport.delta(e.pack_clear_delta),
			BalanceReport.delta(e.get("boss_ttd_delta", NAN)), BalanceReport.delta(e.ehp_delta), "%+.2f" % e.sustain, "%+.2f" % e.get("sustain_pack", 0.0),
			BalanceReport.delta(e.taken_delta), e.get("ratio_text", ""), e.deaths])
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	report.notes.append("Marginal values: %d variants measured on the engine in %.0f s of real time (acts %s, Normal, seed %d)." % [results.size(), seconds, ", ".join(acts.map(func(a: int) -> String: return str(a))), seed_value])
	report.timings["marginal"] = seconds
	report.data["marginal"] = results
	report.table("marginal_base", "Marginal values", "The expected builds as the lab measures them (Normal). Repeat = the same measure again (must be +0%: the lab is repeatable); other seed = with other random numbers (differences smaller than this are luck)",
		PackedStringArray(["Act", "Build", "Dummy DPS", "Boss TTK s (est.)", "Pack clear s", "Boss DPS on it", "Sustain /s (boss)", "Boss time to die s", "EHP", "Taken (live room)", "Repeat", "Other seed"]), base_rows)
	report.table("marginal_all", "Marginal values", "Every pick added alone to each act's expected build, at each level (engine). Value = offense x defense - 1; deltas vs the build without it; sustain = Health/s healed (boss dummy, budget of a boss fight; packs)",
		PackedStringArray(["Act", "Category", "Pick", "Level", "Value", "DPS", "Boss TTK", "Pack clear", "Boss TTD", "EHP", "Sustain /s (boss)", "Sustain /s (pack)", "Taken (live)", "vs median", "Deaths"]), rows)
	return report


func _setup(act: int, expected: BalanceBuildDef) -> Dictionary:
	var normal := BalanceContent.difficulty(content, "normal")
	var depth := BalanceContent.boss_depth(content, act) - 1
	var s := lab.session(depth, normal)
	var boss := content.dungeon.acts[act - 1].boss
	var room := lab.roll_room(act, depth, lab.room_size(depth, normal) + PACK_EXTRA, seed_value * 1000 + 500 + act * 10)
	var rules := FloorRules.make(content.dungeon, normal, null, depth)
	var raw_hits: Array = []
	for monster in content.dungeon.acts[act - 1].monsters:
		if monster and monster.spawn_weight > 0:
			var stats := rules.scale_monster(monster.stats, false)
			raw_hits.append(maxi(1, roundi(((monster.weapon.damage if monster.weapon else 1) + stats.attack) * rules.monster_damage())))
	var boss_rules := FloorRules.make(content.dungeon, normal, null, depth + 1)
	var ctx := { "session": s, "boss": boss, "room": room, "raw_hits": raw_hits, "hp_scale": 1.0, "boss_rules": boss_rules,
		"boss_hp": boss_rules.scale_monster(boss.stats, true).max_hp }
	_ctx[act] = ctx
	# Scale the dummy so the base build needs about DUMMY_SECONDS (every worker needs it: shared).
	var probe: Dictionary = await jobs.unit("marginal-probe|%d|%s|%d" % [act, BalanceJobs.build_id(expected), seed_value], _roots(act, expected),
		func() -> Dictionary: return await lab.dummy(s, expected, boss, 1.0, 8.0, seed_value, null, ctx.boss_hp), true)
	ctx.hp_scale = clampf(DUMMY_SECONDS * float(probe.dps) / maxf(float(probe.full_hp), 1.0), 0.05, 1.0)
	ctx["base"] = await measure_unit(act, expected, seed_value, true)
	return ctx


## measure() as a unit of work (BalanceJobs): kept in the cache, dealt to a worker; null when it
## is another worker's. `tag` tells two identical measures apart (the repeat).
func measure_unit(act: int, build: BalanceBuildDef, measure_seed: int, live: bool, tag: String = "") -> Variant:
	var ctx: Dictionary = _ctx[act]
	var id := "marginal|%d|%s|%d|%s|%.5f|%s" % [act, BalanceJobs.build_id(build), measure_seed, str(live), ctx.hp_scale, tag]
	return await jobs.unit(id, _roots(act, build), func() -> Dictionary: return await measure(act, build, measure_seed, live))


func _roots(act: int, build: BalanceBuildDef) -> PackedStringArray:
	var roots := PackedStringArray([content.dungeon.acts[act - 1].resource_path, "res://data/difficulties/normal.tres"])
	roots.append_array(BalanceJobs.build_roots(build, content))
	return roots


## One build measured: { dps, boss_ttk, sustain_boss, pack_clear, sustain_pack, boss_dps_in,
## boss_ttd, ehp, live_taken, deaths, heal_sources, max_hp }. `live`: also a real room.
func measure(act: int, build: BalanceBuildDef, measure_seed: int, live: bool) -> Dictionary:
	var ctx: Dictionary = _ctx[act]
	var s: Dictionary = ctx.session
	var d: Dictionary = await lab.dummy(s, build, ctx.boss, ctx.hp_scale, DUMMY_LIMIT, measure_seed, null, ctx.boss_hp)
	var full_ttk: float = (float(d.time) - float(d.roar_time)) / float(ctx.hp_scale) + float(d.roar_time) if d.killed else float(d.ttk_est)
	var game: Game = s.game
	var player := game.player
	var max_hp := player.get_max_hp()
	var ehp := effective_health(player, ctx.raw_hits)
	# The boss on this hero (its armor), and what the hero heals per second against it.
	var foe := _model.foe_numbers(ctx.boss, ctx.boss_rules, null, [], player)
	var budgeted := 0.0
	var free := 0.0
	for k: String in d.heal_sources:
		if k.begins_with("perk:") or k.begins_with("rune:") or k.begins_with("affix:") or k.begins_with("family:"):
			budgeted += float(d.heal_sources[k])
		else:
			free += float(d.heal_sources[k])
	var hurt_time := maxf(float(d.time) * 0.5, 0.01)
	var sustain_boss := minf(budgeted / hurt_time, _model.sustain_rate(max_hp, true)) + free / hurt_time
	var revives := 0.0
	for item: Array in BalanceModel.passives_of(player):
		if item[0] is CheatDeathPassive:
			revives += (item[0] as CheatDeathPassive).heal_ratio * int(item[1])
	var boss_dps: float = foe.dps
	var ttd := minf((max_hp + player.ward) * (1.0 + revives) / maxf(boss_dps - sustain_boss, 0.01), TTD_CAP)
	var sources: Dictionary = d.heal_sources.duplicate()
	var clear := 0.0
	var sustain_pack := 0.0
	for i in DUMMY_ROOMS:
		var p: Dictionary = await lab.dummy_pack(s, build, ctx.room, 0.9, PACK_LIMIT, measure_seed + i)
		clear += (float(p.clear_time) if p.cleared else PACK_LIMIT * 1.5) / DUMMY_ROOMS
		sustain_pack += float(p.sustain_hps) / DUMMY_ROOMS
		for k: String in p.heal_sources:
			sources[k] = int(sources.get(k, 0)) + int(p.heal_sources[k])
	var live_taken := 0.0
	var deaths := 0
	if live:
		for i in LIVE_ROOMS:
			var r: Dictionary = await lab.pack(s, build, ctx.room, "face_tank", PACK_LIMIT, measure_seed + i)
			live_taken += float(r.taken) / LIVE_ROOMS
			if r.result == "died":
				deaths += 1
	return { "dps": d.dps, "boss_ttk": full_ttk, "sustain_boss": sustain_boss, "pack_clear": clear,
		"sustain_pack": sustain_pack, "boss_dps_in": boss_dps, "boss_ttd": ttd, "ehp": ehp, "live_taken": live_taken,
		"deaths": deaths, "heal_sources": sources, "max_hp": max_hp }


## (Max health + ward) x what armor saves on `raw_hits` x (1 + half health per revive).
static func effective_health(player: Player, raw_hits: Array) -> float:
	var defense := player.get_stats().defense
	var saved := 0.0
	for raw: int in raw_hits:
		saved += float(raw) / Combat.mitigate(raw, defense)
	saved /= maxf(raw_hits.size(), 1.0)
	var revives := 0.0
	for item: Array in BalanceModel.passives_of(player):
		if item[0] is CheatDeathPassive:
			revives += (item[0] as CheatDeathPassive).heal_ratio * int(item[1])
	return (player.get_max_hp() + player.ward) * maxf(saved, 1.0) * (1.0 + revives)


## { value, offense, defense } of `m` against `base`.
static func _value(base: Dictionary, m: Dictionary) -> Dictionary:
	var ttk := clampf(float(base.boss_ttk) / maxf(float(m.boss_ttk), 0.01), 1.0 / RATIO_CLAMP, RATIO_CLAMP)
	var clear := clampf(float(base.pack_clear) / maxf(float(m.pack_clear), 0.01), 1.0 / RATIO_CLAMP, RATIO_CLAMP)
	var offense := sqrt(ttk * clear)
	var defense := clampf(float(m.boss_ttd) / maxf(float(base.boss_ttd), 0.01), 1.0 / RATIO_CLAMP, RATIO_CLAMP)
	return { "value": offense * defense - 1.0, "offense": offense - 1.0, "defense": defense - 1.0 }


## Everything that can be added to `build`: [{ category, id, level, max_level, label, build, from, from_build }].
func variants_for(build: BalanceBuildDef) -> Array:
	var result: Array = []
	var probe := BalanceBuild.make_player(build, content)
	var awake := probe.perks.awakened()
	probe.free()
	for perk in BalanceContent.perks():
		var id := String(perk.id)
		var category := "relic" if perk.rarity == PerkDef.Rarity.RARE else "perk"
		var from := build
		var from_key := ""
		if build.perks.has(id):
			# The build without it, its families kept awake (the perk's own worth, not the family's).
			from = BalanceBuild.variant(build, content, "perk", id, 0)
			for synergy in awake:
				if not from.extra_families.has(synergy):
					from.extra_families.append(synergy)
			from_key = "without %s" % id
		for level in range(1, perk.max_stacks + 1):
			var v := BalanceBuild.variant(from, content, "perk", id, level)
			result.append({ "category": category, "id": id, "level": level, "max_level": perk.max_stacks, "label": id, "build": v, "from": from_key, "from_build": from })
	for synergy in content.synergies:
		var id := String(synergy.id)
		if awake.has(synergy):
			var without := BalanceBuild.variant(build, content, "no_family", id)
			result.append({ "category": "family", "id": id, "level": 1, "max_level": 1, "label": "%s (awake in the build)" % id, "build": build, "from": "without family %s" % id, "from_build": without })
		else:
			result.append({ "category": "family", "id": id, "level": 1, "max_level": 1, "label": id, "build": BalanceBuild.variant(build, content, "family", id), "from": "", "from_build": build })
	for r in content.runes:
		result.append({ "category": "rune", "id": String(r.id), "level": 1, "max_level": 1, "label": String(r.id), "build": BalanceBuild.variant(build, content, "rune", String(r.id)), "from": "", "from_build": build })
	for a in content.item_affixes:
		var v := BalanceBuild.variant(build, content, "affix", String(a.id))
		if v:
			result.append({ "category": "affix", "id": String(a.id), "level": 1, "max_level": 1, "label": String(a.id), "build": v, "from": "", "from_build": build })
	for u in content.upgrades:
		var id := String(u.id)
		if u.kind != UpgradeDef.Kind.STATS and u.kind != UpgradeDef.Kind.STARTING_PERK:
			continue  # items, unlocks, rerolls: not a fight value (see the economy and weapon tables)
		var from := build
		var from_key := ""
		if build.upgrades.has(id) and int(build.upgrades[id]) > 0:
			from = BalanceBuild.variant(build, content, "upgrade", id, 0)
			from_key = "without shrine %s" % id
		for level in range(1, u.max_level + 1):
			result.append({ "category": "upgrade", "id": id, "level": level, "max_level": u.max_level, "label": id,
				"build": BalanceBuild.variant(from, content, "upgrade", id, level), "from": from_key, "from_build": from })
	for encounter in content.encounters:
		for choice in encounter.choices:
			if choice.max_hp_cost > 0.0:
				result.append({ "category": "encounter", "id": "%s: %s (price)" % [encounter.id, choice.label], "level": 0, "max_level": 0,
					"label": "%s: %s, price (-%d%% max health)" % [encounter.id, choice.label, roundi(choice.max_hp_cost * 100.0)],
					"build": BalanceBuild.variant(build, content, "max_hp_cost", "", 0, choice.max_hp_cost), "from": "", "from_build": build })
			for outcome in choice.outcomes:
				for effect in outcome.effects:
					if effect is BuffEffect and (effect as BuffEffect).bonuses:
						result.append({ "category": "encounter", "id": "%s: %s (buff)" % [encounter.id, choice.label], "level": 0, "max_level": 0,
							"label": "%s: %s, %s for %.0f s" % [encounter.id, choice.label, (effect as BuffEffect).bonuses.describe(), (effect as BuffEffect).duration],
							"build": BalanceBuild.variant(build, content, "buff", "", 0, (effect as BuffEffect).bonuses), "from": "", "from_build": build })
	return result


## Encounter outcomes that are not a stat change: their value from the measured ones (a perk or a
## relic gift = the average measured perk (level 1) or relic of the same act; heals and wounds
## = that share of effective health; gold and items: the economy).
func _encounters(results: Array) -> void:
	for act in acts:
		var perk_values: Array = []
		var relic_values: Array = []
		for e: Dictionary in results:
			if e.act != act:
				continue
			if e.category == "perk" and e.level == 1:
				perk_values.append(e.value)
			elif e.category == "relic" and e.level == 1:
				relic_values.append(e.value)
		for encounter in content.encounters:
			for choice in encounter.choices:
				var chances := choice.chances()
				var ev := 0.0
				var fight_only := choice.gold_cost <= 0  # only fight values: compared with the median
				var parts := PackedStringArray()
				for i in choice.outcomes.size():
					var o := choice.outcomes[i]
					var value := 0.0
					var what := PackedStringArray()
					if o.gift == EncounterOutcome.Gift.PERK:
						if perk_values.is_empty():
							fight_only = false
							what.append("a perk (not measured)")
						else:
							value += BalanceContent.mean(perk_values)
							what.append("a perk (avg level-1 perk %s)" % BalanceReport.delta(BalanceContent.mean(perk_values)))
					elif o.gift == EncounterOutcome.Gift.RELIC:
						if relic_values.is_empty():
							fight_only = false
							what.append("a relic (not measured)")
						else:
							value += BalanceContent.mean(relic_values)
							what.append("a relic (avg relic %s)" % BalanceReport.delta(BalanceContent.mean(relic_values)))
					if o.heal_ratio > 0.0:
						value += o.heal_ratio * 0.5  # a heal is worth its share of health, about half the time it is needed
						what.append("heals %d%%" % roundi(o.heal_ratio * 100.0))
					if o.damage_ratio > 0.0:
						value -= o.damage_ratio
						what.append("hurts %d%%" % roundi(o.damage_ratio * 100.0))
					if o.monsters > 0:
						fight_only = false
						what.append("%d %smonsters" % [o.monsters, "elite " if o.elite_monsters else ""])
					if o.gold > 0:
						fight_only = false
						what.append("%d gold" % o.gold)
					if o.item_quality > 0.0:
						fight_only = false
						what.append("an item (quality %.0f)" % o.item_quality)
					for effect in o.effects:
						if effect is BuffEffect:
							for e: Dictionary in results:
								if e.act == act and e.category == "encounter" and String(e.id).begins_with("%s: %s (buff)" % [encounter.id, choice.label]):
									value += e.value
									what.append("buff (measured %s)" % BalanceReport.delta(e.value))
					ev += chances[i] * value
					parts.append("%d%% %s" % [roundi(chances[i] * 100.0), ", ".join(what) if not what.is_empty() else "nothing"])
				if choice.max_hp_cost > 0.0:
					for e: Dictionary in results:
						if e.act == act and e.category == "encounter" and String(e.id) == "%s: %s (price)" % [encounter.id, choice.label]:
							ev += e.value
							parts.append("price measured %s" % BalanceReport.delta(e.value))
				var gold := choice.cost_in_gold(BalanceContent.boss_depth(content, act) - 1)
				results.append({ "act": act, "category": "encounter", "id": "%s: %s (expected)" % [encounter.id, choice.label], "level": 0, "max_level": 0,
					"label": "%s: %s, expected value%s: %s" % [encounter.id, choice.label, " (costs %d gold)" % gold if gold > 0 else "", "; ".join(parts)],
					"value": ev, "offense": 0.0, "defense": 0.0, "dps": 0.0, "boss_ttk": 0.0, "boss_ttk_delta": 0.0, "pack_clear": 0.0,
					"pack_clear_delta": 0.0, "boss_ttd_delta": NAN, "ehp_delta": 0.0, "sustain": 0.0, "sustain_pack": 0.0, "taken_delta": NAN, "deaths": 0, "from": "derived", "heal_sources": {},
					"fight_only": fight_only })


## Per act and category: the median value at max level, each pick's ratio to it, flags, and the
## ranking table.
func _rank(report: BalanceReport, results: Array) -> void:
	var rank_rows: Array = []
	for act in acts:
		for category: String in CATEGORIES:
			var top: Array = results.filter(func(e: Dictionary) -> bool:
				return e.act == act and e.category == category and (e.max_level == 0 or e.level == e.max_level) and not (category == "encounter" and not String(e.id).ends_with("(expected)")))
			if top.is_empty():
				continue
			var values: Array = top.map(func(e: Dictionary) -> float: return e.value)
			var positive: Array = values.filter(func(v: float) -> bool: return v > 0.0)
			var median := BalanceContent.median(positive if not positive.is_empty() else values)
			top.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.value > b.value)
			var position := 0
			for e: Dictionary in top:
				position += 1
				var ratio: float = e.value / median if median > 0.0001 else 0.0
				e["ratio_to_median"] = ratio
				e["ratio_text"] = "%.2fx" % ratio
				rank_rows.append([act, category, position, e.label, "%d" % e.max_level if e.max_level > 0 else "-", BalanceReport.delta(e.value), "%.2fx" % ratio,
					BalanceReport.delta(e.dps), BalanceReport.delta(e.boss_ttk_delta), BalanceReport.delta(e.pack_clear_delta), BalanceReport.delta(e.get("boss_ttd_delta", NAN)),
					BalanceReport.delta(e.ehp_delta), "%+.2f" % e.sustain])
				if median <= 0.0001 or not e.get("fight_only", true):
					continue  # (gold, items, monsters: the economy tables price them)
				var subject := "%s %s%s (act %d)" % [category, e.label, " x%d" % e.max_level if e.max_level > 1 else "", act]
				if ratio > targets.perk_value_max_vs_median:
					report.flag(BalanceReport.WARN, "marginal: too strong", subject, "%.2fx median (%s)" % [ratio, BalanceReport.delta(e.value)],
						"<= %.1fx" % targets.perk_value_max_vs_median, "median of the %ss: %s" % [category, BalanceReport.delta(median)])
				elif ratio < targets.perk_value_min_vs_median:
					report.flag(BalanceReport.WARN, "marginal: too weak", subject, "%.2fx median (%s)" % [ratio, BalanceReport.delta(e.value)],
						">= %.1fx" % targets.perk_value_min_vs_median, "median of the %ss: %s%s" % [category, BalanceReport.delta(median),
							" (no fight value: economy or utility)" if absf(e.value) < 0.02 else ""])
	report.table("marginal_rank", "Marginal values", "Ranking per act and category at max level (engine): value, its ratio to the category's median (flags beyond %.1fx / %.1fx), and its parts" % [targets.perk_value_max_vs_median, targets.perk_value_min_vs_median],
		PackedStringArray(["Act", "Category", "#", "Pick", "Max", "Value", "vs median", "DPS", "Boss TTK", "Pack clear", "Boss TTD", "EHP", "Sustain /s (boss)"]), rank_rows)
