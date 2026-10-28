class_name BalanceTests
extends TestSuite
## Opt-in suite (only with --only=balance): the game's balance against its targets
## (data/balance/targets.tres), with the balance tools in their --quick form (tools/balance/,
## docs/balance.md > Tools):
## - the builds' data is sound, every kind of build exists, the content is all listed;
## - the model (Normal and Hard): one check per kind of target (all its flags are target breaks);
## - three real duels against the act I boss on Normal: the degenerate lifesteal build and the
##   expected build face-tanking (both must lose, with little healing), the expected build kiting
##   (should win); the expected builds of acts II-IV face-tanking their boss; the Azure Wyrm, Gorr
##   and the Jade Wyrm on Keeper (kite wins, face-tank loses, no bot walks into a hole); the act
##   III caster stack face-tanking the Jade Wyrm loses. A face-tank win after dying once (a second life) is a
##   loss, and a second life's heal is not counted as healing (targets.facetank_second_life_is_loss);
## - the lab's quick marginal values (act II, a few picks) and economy (two Normal floors) run.
## Some of these FAIL today, on purpose: they are the balance work to do. Those are listed in
## KNOWN and printed as "FAIL (KNOWN ...)": they still count as failures. When one starts
## passing, remove it from KNOWN; a failure not in KNOWN is new.

## Checks known to fail on KNOWN_DATE (the baseline before any rebalancing), by the key printed with them.
## Phase 2A fixed "model: face-tank wins", "model: heal share", "model: act curve" and
## "duel: degenerate_lifesteal_a1 face-tank loses" (boss shockwave, boss-fight sustain, armor).
const KNOWN := [
	"model: boss TTK", "model: boss hits to kill",
	"model: monster TTK", "model: elite TTK", "model: epic TTK", "model: legendary TTK", "model: shiny TTK",
	# Phase 2C: Vampirism (heals on kill) reads ~0 in the lab: kills in a boss fight heal nothing
	# (2A) and the dummy rooms don't hurt, so a kill heal has nothing to show; its value is pack
	# sustain (Taken (live), the arena). A measuring blind spot, not a trap: buffed to 3 a kill.
	"marginal: too weak",
]
const KNOWN_DATE := "2026-10-20"


## The main run, and an act's alternate warden on its own (each test has its time).
func test_cases() -> Array:
	return [["", Callable(self, &"run")], ["alternates", Callable(self, &"run_alternates")]]


## The Ember Ronin (act III's alternate warden), hard but fair on Keeper over four seeds
## (2026-10-28: the kite bot won 2 of 8 with the floors' tempo kept, 7 of 8 with his second fierce
## arc and last-phase blade lighter; here 3 of 4): the kite bot wins 3 of 4 at least, the
## face-tank loses every one. The Mire Matron (act I's) is a coin toss for the kite bot (8 of 12
## over these seeds and the command line's), not guarded yet: balance log 2026-10-28.
func run_alternates() -> void:
	var shown := Vfx.shown
	Vfx.shown = false
	var targets := BalanceBuild.load_targets()
	var builds := BalanceBuild.load_all()
	var lab := BalanceLab.new()
	lab.content = CONTENT
	add_child(lab)
	var arena := BalanceArena.new()
	arena.lab = lab
	arena.content = CONTENT
	arena.targets = targets
	arena.all_builds = builds
	arena.verbose = false
	add_child(arena)
	lab.override_chances()
	var normal := BalanceContent.difficulty(CONTENT, "normal")
	for boss_id: StringName in [&"red_samurai"]:
		var fair: BossDef = null
		for candidate: BossDef in BalanceContent.bosses(CONTENT):
			if candidate.id == boss_id:
				fair = candidate
		var expected := BalanceBuild.expected(builds, BalanceContent.act_of_boss(CONTENT, fair) if fair else 0)
		check(fair != null and expected != null, "%s and its act's expected build exist" % boss_id)
		if fair == null or expected == null:
			continue
		var kite_wins := 0
		var lines := PackedStringArray()
		for s in range(1, 5):
			lab.seed_value = s
			for bot in ["kite", "face_tank"]:
				var r := await arena.fight_boss(fair, expected, normal, bot)
				var line := BalanceArena.fight_line(r)
				print("  duel (seed %d): %s" % [s, line])
				if bot == "kite":
					kite_wins += 1 if r.result == "win" else 0
					lines.append(line)
				else:
					_target(r.result == "loss" or (r.result == "win" and not BalanceArena.facetank_won(r, targets)), "duel: %s face-tank loses on Keeper" % fair.display_name, "seed %d: %s" % [s, line])
		_target(kite_wins >= 3, "duel: %s kite wins on Keeper" % fair.display_name, "%d of 4 seeds won (target >= 3): %s" % [kite_wins, " / ".join(lines)])
	arena.queue_free()
	lab.queue_free()
	BalanceLab.isolate_profile()
	Vfx.shown = shown


func run() -> void:
	var shown := Vfx.shown
	Vfx.shown = false  # the tools simulate (BalanceLab.simulate): nothing to see, twice as fast
	var targets := BalanceBuild.load_targets()
	var builds := BalanceBuild.load_all()
	check(builds.size() >= 10, "balance builds found in data/balance/builds/ (%d)" % builds.size())
	for tag in ["baseline", "expected", "degenerate", "family"]:
		check(builds.any(func(b: BalanceBuildDef) -> bool: return b.has_tag(tag)), "a %s build exists" % tag)
	for act in range(1, CONTENT.dungeon.acts.size() + 1):
		check(BalanceBuild.expected(builds, act) != null, "an expected build for act %d" % act)
	for synergy in CONTENT.synergies:
		check(builds.any(func(b: BalanceBuildDef) -> bool: return b.has_tag("family") and b.has_tag(String(synergy.id))), "a family build for %s" % synergy.id)
	for build in builds:
		for problem in BalanceBuild.problems(build, CONTENT):
			check(false, "build data: %s" % problem)
	for key in BalanceContent.ALL_DIFFICULTIES:
		check(BalanceContent.difficulty(CONTENT, key) != null, "the tools know the difficulty %s" % key)

	# The model: one check per kind of target.
	var model := BalanceModel.new(CONTENT, targets, builds)
	model.difficulties = BalanceContent.difficulties(CONTENT, PackedStringArray(["normal", "hard"]))
	model.quick = true
	var report := model.run()
	check(report.tables.size() >= 10, "the model wrote its tables (%d)" % report.tables.size())
	_targets_of(report, ["model: boss TTK", "model: boss hits to kill", "model: face-tank wins", "model: heal share",
		"model: monster TTK", "model: monster hits to kill", "model: elite TTK", "model: epic TTK", "model: legendary TTK",
		"model: shiny TTK", "model: monster curve", "model: floor curve", "model: rank ladder", "model: ranked boss TTK", "model: act curve", "model: difficulty curve", "model: degenerate DPS",
		"model: weapon DPS", "content: unlisted", "build data"])

	# Phase 2C: the five families built on purpose stay comparable (DPS vs the expected act III
	# build: each 1.0x-1.5x; Blood's strength is its sustain and low-health power, not raw DPS).
	var family_ratios := {}
	for table: Dictionary in report.tables:
		if table.name == "degenerate_dps":
			for row: Array in table.rows:
				family_ratios[String(row[0])] = float(String(row[6]).trim_suffix("x"))
	for synergy in CONTENT.synergies:
		var key := "family_%s_a3" % synergy.id
		var ratio: float = family_ratios.get(key, -1.0)
		_target(ratio >= 1.0 and ratio <= 1.5, "family: %s DPS" % synergy.id, "%s: %.2fx the expected build's DPS (target 1.0-1.5x)" % [key, ratio])

	# Real duels on the engine.
	var lab := BalanceLab.new()
	lab.content = CONTENT
	add_child(lab)
	var arena := BalanceArena.new()
	arena.lab = lab
	arena.content = CONTENT
	arena.targets = targets
	arena.all_builds = builds
	arena.verbose = false
	add_child(arena)
	lab.override_chances()
	var boss: BossDef = CONTENT.dungeon.acts[0].boss
	var normal := BalanceContent.difficulty(CONTENT, "normal")
	for duel: Array in [["degenerate_lifesteal_a1", "face_tank"], ["expected_a1", "face_tank"], ["expected_a1", "kite"]]:
		var build := BalanceBuild.find(builds, duel[0])
		if build == null:
			check(false, "build %s exists" % duel[0])
			continue
		var r := await arena.fight_boss(boss, build, normal, duel[1])
		var line := BalanceArena.fight_line(r)
		print("  duel: %s" % line)
		check(r.result != "error", "the duel %s %s ran (%s)" % [duel[0], duel[1], r.get("error", "")])
		if duel[1] == "face_tank":
			_target(not BalanceArena.facetank_won(r, targets), "duel: %s face-tank loses" % duel[0], "%s vs %s on Normal: %s" % [duel[0], boss.id, line])
			var share_max := targets.heal_share_max_degenerate if build.has_tag("degenerate") else targets.heal_share_max_expected
			_target(BalanceArena.sustain_share(r) <= share_max, "duel: %s heal share" % duel[0], "healed %d%% of the damage taken (target <= %d%%): %s" % [
				roundi(BalanceArena.sustain_share(r) * 100.0), roundi(share_max * 100.0), BalanceLab.sources_text(r.get("heal_sources", {}))])
		else:
			_target(r.result == "win", "duel: %s kite wins" % duel[0], "%s vs %s on Normal: %s" % [duel[0], boss.id, line])
	await _boss_guards(arena, builds, targets, normal)
	await _gauntlet_guards(lab, builds, targets)
	lab.restore_chances()
	arena.queue_free()

	# The lab: quick marginal values and economy run and measure something.
	var marginal := BalanceMarginal.new()
	marginal.lab = lab
	marginal.content = CONTENT
	marginal.targets = targets
	marginal.all_builds = builds
	marginal.quick = true
	marginal.verbose = false
	marginal.acts = [2] as Array[int]
	add_child(marginal)
	var m_report := await marginal.run()
	var values: Array = m_report.data.get("marginal", [])
	check(values.size() >= 6, "marginal values measured (%d)" % values.size())
	check(values.any(func(e: Dictionary) -> bool: return e.id == "strength" and e.dps > 0.0), "Strength adds measured DPS on the act II build")
	check(values.any(func(e: Dictionary) -> bool: return e.id == "might" and e.dps > 0.0), "the Might shrine level adds measured DPS")
	_targets_of(m_report, ["marginal: too strong", "marginal: too weak"])
	marginal.queue_free()
	var economy := BalanceEconomy.new()
	economy.lab = lab
	economy.content = CONTENT
	economy.targets = targets
	economy.all_builds = builds
	economy.difficulties = [normal] as Array[DifficultyDef]
	economy.quick = true
	economy.verbose = false
	add_child(economy)
	var e_report := await economy.run()
	var floors: Array = e_report.data.get("floors", [])
	check(floors.size() >= 2, "economy floors harvested (%d)" % floors.size())
	check(floors.all(func(f: Dictionary) -> bool: return f.kills > 0 and f.gold_monsters + f.gold_chests + f.gold_props > 0), "every harvested floor gave kills and gold")
	_targets_of(e_report, ["economy: shop", "economy: reroll", "economy: forge", "economy: souls", "economy: build level"])
	economy.queue_free()
	lab.queue_free()
	BalanceLab.isolate_profile()  # back to a clean in-memory profile for whatever runs next
	Vfx.shown = shown


## Phase 2A (bosses, sustain, armor): the rules that let a build out-heal or out-armor a boss.
## - armor (Combat.mitigate): the most armored build of the game (36) is hit for more than 1 by
##   most act IV monsters (flat armor brought all of them down to 1);
## - the boss-fight sustain budget (SustainRules): a minute of it heals well under half the
##   hero's health, and its refill is under the act IV boss' damage per second on that build;
## - the expected build of acts II-IV face-tanking its act's boss on Normal loses, and its
##   healing stays under the target share of the damage taken.
func _boss_guards(arena: BalanceArena, builds: Array[BalanceBuildDef], targets: BalanceTargets, normal: DifficultyDef) -> void:
	var armor := 36
	var act_iv := CONTENT.dungeon.acts.size()
	var depth := BalanceContent.boss_depth(CONTENT, act_iv) - 1
	var rules := FloorRules.make(CONTENT.dungeon, normal, null, depth)
	var floored := 0
	var total := 0
	for monster in CONTENT.dungeon.acts[act_iv - 1].monsters:
		if monster == null:
			continue
		var stats := rules.scale_monster(monster.stats, false)
		var raw := maxi(1, roundi(((monster.weapon.damage if monster.weapon else 1) + stats.attack) * rules.monster_damage()))
		total += 1
		if Combat.mitigate(raw, armor) <= 1:
			floored += 1
	_target(total > 0 and floored <= total * targets.min_damage_share_max, "armor: weak hits vs %d armor" % armor,
		"%d of %d act IV monsters hit a %d-armor build for 1 (target <= %d%%)" % [floored, total, armor, roundi(targets.min_damage_share_max * 100.0)])

	var sustain: SustainRules = CONTENT.dungeon.sustain
	var expected_iv := BalanceBuild.expected(builds, act_iv)
	if sustain and expected_iv:
		var hero := BalanceBuild.make_player(expected_iv, CONTENT, normal)
		var max_hp := hero.get_max_hp()
		hero.free()
		var minute := sustain.capacity(max_hp, true) + sustain.refill_per_second(max_hp, true) * 60.0
		_target(minute <= max_hp * 0.35, "sustain: a minute of a boss fight",
			"the boss-fight budget heals %d in a minute for %d Health (target <= 35%%)" % [roundi(minute), max_hp])

	for act in range(2, act_iv + 1):
		var build := BalanceBuild.expected(builds, act)
		var boss: BossDef = CONTENT.dungeon.acts[act - 1].boss
		if build == null or boss == null:
			continue
		var r := await arena.fight_boss(boss, build, normal, "face_tank")
		var line := BalanceArena.fight_line(r)
		print("  duel: %s" % line)
		_target(r.result == "loss" or (r.result == "win" and not BalanceArena.facetank_won(r, targets)), "duel: %s face-tank loses" % build.name, "%s vs %s on Normal: %s" % [build.name, boss.id, line])
		_target(BalanceArena.sustain_share(r) <= targets.heal_share_max_expected, "duel: %s heal share" % build.name,
			"healed %d%% of the damage taken (target <= %d%%): %s" % [roundi(BalanceArena.sustain_share(r) * 100.0), roundi(targets.heal_share_max_expected * 100.0),
			BalanceLab.sources_text(r.get("heal_sources", {}))])

	# Hard but fair bosses on Keeper, over four seeds: playing them wins most fights, standing in
	# front of them still loses. The Azure Wyrm's pass (2026-10-23: her slows chained into
	# short-warned dives; the command line measured 6 kite wins of 8, 1 before) and Gorr's and the
	# Jade Wyrm's (2026-10-23: most of the bots' losses were their own reading: walking into
	# holes, a fan's cone, a Quake's later ring). And the bots never walk into a hole they can see:
	# a fall is a blow's doing (BalanceArena.FightLog.falls_walked).
	var fair_bosses := { &"azure_wyrm": 2, &"demon_cyclops": 3, &"jade_wyrm": 3 }
	var walked := 0
	var walked_lines := PackedStringArray()
	for boss_id: StringName in fair_bosses:
		var fair: BossDef = null
		for candidate: BossDef in BalanceContent.bosses(CONTENT):
			if candidate.id == boss_id:
				fair = candidate
		var act := BalanceContent.act_of_boss(CONTENT, fair) if fair else 0
		var expected := BalanceBuild.expected(builds, act)
		check(fair != null and expected != null, "%s and its act's expected build exist" % boss_id)
		if fair == null or expected == null:
			continue
		var kept_seed := arena.lab.seed_value
		var kite_wins := 0
		var lines := PackedStringArray()
		for s in range(1, 5):
			arena.lab.seed_value = s
			for bot in ["kite", "face_tank"]:
				var r := await arena.fight_boss(fair, expected, normal, bot)
				var line := BalanceArena.fight_line(r)
				print("  duel (seed %d): %s" % [s, line])
				if int(r.get("falls_walked", 0)) > 0:
					walked += int(r.falls_walked)
					walked_lines.append("seed %d: %s" % [s, line])
				if bot == "kite":
					kite_wins += 1 if r.result == "win" else 0
					lines.append(line)
				else:
					_target(r.result == "loss" or (r.result == "win" and not BalanceArena.facetank_won(r, targets)), "duel: %s face-tank loses on Keeper" % fair.display_name, "seed %d: %s" % [s, line])
		arena.lab.seed_value = kept_seed
		_target(kite_wins >= int(fair_bosses[boss_id]), "duel: %s kite wins on Keeper" % fair.display_name, "%d of 4 seeds won (target >= %d): %s" % [kite_wins, fair_bosses[boss_id], " / ".join(lines)])
	_target(walked == 0, "duel: the bots never walk into a hole", "%d falls walked into: %s" % [walked, " / ".join(walked_lines)])

	# The bottom of the Well: a Nameless Keeper with a bow or a wand (2026-10-24) keeps his
	# distance and shoots. The kite bot closes in across his shots (BalanceBot.CLOSE_IN) and wins,
	# instead of a standoff out of his range; standing in front of him still loses.
	var finale := CONTENT.dungeon.finale
	if finale and finale.keeper and expected_iv:
		var kept_seed := arena.lab.seed_value
		for weapon: String in ["bow", "magic_wand"]:
			var snapshot := BalanceContent.keeper_snapshot(CONTENT, weapon)
			check(KeeperSnapshot.is_valid(snapshot) and finale.keeper.build(KeeperSnapshot.new(snapshot), CONTENT).weapon.id == StringName(weapon), "the tools make a Nameless Keeper with a %s" % weapon)
			var bottom := { "keeper": snapshot, "label": "keeper:%s" % weapon }
			for s in range(1, 3):
				arena.lab.seed_value = s
				for bot in ["kite", "face_tank"]:
					var r := await arena.fight_boss(finale.keeper, expected_iv, normal, bot, null, 0, [] as Array[ItemDef], false, bottom)
					var line := BalanceArena.fight_line(r)
					print("  duel (seed %d): %s" % [s, line])
					check(r.result != "error" and r.boss == bottom.label, "the bottom of the Well with a %s Keeper ran (%s)" % [weapon, r.get("error", "")])
					if bot == "kite":
						_target(r.result == "win", "duel: a %s Keeper is fought and beaten by the kite bot on Keeper" % weapon, "seed %d: %s" % [s, line])
					else:
						_target(not BalanceArena.facetank_won(r, targets), "duel: a %s Keeper beats a face-tank on Keeper" % weapon, "seed %d: %s" % [s, line])
		arena.lab.seed_value = kept_seed

	# The act III caster stack (degenerate_skills_a3) won face-tanking the Jade Wyrm on two seeds
	# of four (its echoes skipped 69% of its cooldowns on top of the cooldown cap): with echoes
	# capped (DungeonConfig.skill_echo_max_chance) it must lose standing still.
	var jade: BossDef = null
	for candidate: BossDef in BalanceContent.bosses(CONTENT):
		if candidate.id == &"jade_wyrm":
			jade = candidate
	var caster: BalanceBuildDef = null
	for build in builds:
		if build.name == "degenerate_skills_a3":
			caster = build
	if jade and caster:
		var kept := arena.lab.seed_value
		for s in range(1, 5):
			arena.lab.seed_value = s
			var r := await arena.fight_boss(jade, caster, normal, "face_tank")
			var line := BalanceArena.fight_line(r)
			print("  duel (seed %d): %s" % [s, line])
			_target(not BalanceArena.facetank_won(r, targets), "duel: degenerate_skills_a3 face-tank loses to the Jade Wyrm", "seed %d: %s" % [s, line])
		arena.lab.seed_value = kept

## One _target per category: passes when the report has no flag of it.
func _targets_of(report: BalanceReport, categories: Array) -> void:
	var by_category := {}
	for flag in report.flags:
		if not by_category.has(flag.category):
			by_category[flag.category] = []
		by_category[flag.category].append(flag)
	for category: String in categories:
		var flags: Array = by_category.get(category, [])
		var examples := PackedStringArray()
		for i in mini(flags.size(), 3):
			examples.append("%s: %s (target %s)" % [flags[i].subject, flags[i].value, flags[i].target])
		_target(flags.is_empty(), category, "%d broken%s" % [flags.size(), (": " + "; ".join(examples)) if not examples.is_empty() else ""])


## A target check: counted like check(), printed as KNOWN when it is a known failure.
## Keeper's pass (2026-10-22): act I played through as a player meets it (its last floor's rooms,
## then its boss, BalanceGauntlet): the average player (player bot) on Pilgrim and the decent
## one (kite) on Keeper get through; floors 1-2 stay gentle for the hero who walks them.
func _gauntlet_guards(lab: BalanceLab, builds: Array[BalanceBuildDef], targets: BalanceTargets) -> void:
	var gauntlet := BalanceGauntlet.new()
	gauntlet.lab = lab
	gauntlet.content = CONTENT
	gauntlet.targets = targets
	gauntlet.all_builds = builds
	gauntlet.difficulties = BalanceContent.difficulties(CONTENT, PackedStringArray(["easy", "normal"]))
	gauntlet.bots = PackedStringArray(["kite", "player"])
	gauntlet.acts = [1] as Array[int]
	gauntlet.verbose = false
	add_child(gauntlet)
	var report := await gauntlet.run()
	gauntlet.queue_free()
	var runs: Array = report.data.get("gauntlet", [])
	check(runs.size() == 4, "the act I gauntlet ran (%d runs)" % runs.size())
	for r: Dictionary in runs:
		print("  gauntlet: %s" % BalanceGauntlet.run_line(r))
		if (r.difficulty == "easy" and r.bot == "player") or (r.difficulty == "normal" and r.bot == "kite"):
			_target(r.outcome == "win", "gauntlet: act I %s wins on %s" % [r.bot, r.difficulty], BalanceGauntlet.run_line(r))
	for f: Dictionary in report.data.get("curve", []):
		if f.difficulty == "normal" and f.bot == "kite" and not f.starter:
			_target(float(f.cost) <= targets.curve_first_act_cost_max, "curve: floor %d gentle on Keeper" % f.depth,
				"the kite bot lost %d%% of its Health over the floor's rooms (target <= %d%%)" % [roundi(100.0 * f.cost), roundi(100.0 * targets.curve_first_act_cost_max)])


func _target(ok: bool, key: String, details: String) -> void:
	checks += 1
	if ok:
		if KNOWN.has(key):
			print("  PASS (was a known failure, remove it from KNOWN): %s" % key)
		return
	failures += 1
	if KNOWN.has(key):
		printerr("FAIL (KNOWN, current state %s): %s | %s" % [KNOWN_DATE, key, details])
	else:
		printerr("FAIL: %s | %s" % [key, details])
