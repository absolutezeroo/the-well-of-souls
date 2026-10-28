extends Node
## The balance tools' command line (tools/balance/balance.tscn). From the project root:
##   godot --headless --fixed-fps 60 res://tools/balance/balance.tscn -- --mode=model
## Options (all optional):
##   --mode=model|arena|pack|marginal|economy|compound|gauntlet|all   what to run (default model)
##       model     static tables: every monster x rank x depth x difficulty, boss x phase x rank,
##                 weapon x rarity x armor, builds, the curve (seconds)
##       arena     real boss fights (every boss x builds of its act x difficulty x bot, boss ranks)
##                 and every weapon vs every boss
##       pack      rooms of each act's monsters: each kind, mixed rooms, ranked monsters
##       marginal  every perk level, relic, family, rune, affix, shrine level, encounter outcome
##                 added alone to each act's expected build (engine)
##       economy   real floors harvested: gold, XP, loot, shop prices, souls vs the shrine
##       compound  stacks that multiply: attack speed x crit x damage, projectiles, echo, burns,
##                 armor vs weak hits, healing vs the sustain cap
##       gauntlet  each act played as a player would: its last floor's rooms (elites and all),
##                 then its boss, Health and potions carried, by a bot with a reaction time
##       all       everything above, one report
##   --quick                       a small subset of each mode (the "balance" test suite)
##   --only=act2,king_slime,...    restrict to acts (act1..act4), bosses, builds, weapons,
##                                 difficulties (any mix; see docs/balance.md)
##   --boss=king_slime,...         bosses (arena)
##   --build=expected_a1,...       builds (data/balance/builds/<name>.tres)
##   --difficulty=normal,hard      easy, normal, hard, nightmare, nightmare+N (default: all six of
##                                 easy..nightmare+10; --quick: normal)
##   --bot=face_tank,kite          arena/pack bots (default both)
##   --acts=2,4                    marginal: acts measured (default all)
##   --picks=ignite,cinder_wake    marginal: only these picks (perk, relic, family, rune, affix ids;
##                                 the "vs median" column then compares them among themselves)
##   --out=<dir>                   where reports go (default user://balance/)
##   --seed=N                      every measure starts from this seed (default 1): same run, same numbers
##   --all-pairs                   arena: every build against every boss
##   --timeout=240                 arena: game seconds before a fight is called a timeout
##   --plain                       arena: plain bosses only (no Epic/Legendary/Shiny fights)
##   --no-weapons                  arena: skip the weapon arena (boss fights only)
##   --hits                        arena: print every hit the hero takes in each fight measured (what,
##                                 how hard it pushed, near a hole?), and the falls with their cause
##   --jobs=N                      worker processes sharing the measures (default 2: this machine's CPUs)
##   --cache=<dir>                 where measures are kept between runs (default user://balance_cache)
##   --no-cache                    measure everything again (the results are still kept)
##   --gauntlet=acts|curve|all     gauntlet: each act's last floor and boss, every floor's cost, or both
##   --no-renew                    a new game for every measure (the floors are not rebuilt in place)
##   --classic                     the game as seen (effects, HUD, light) and a new game per measure:
##                                 the tools before they simulated (slower; to compare)
##   --in=<dir>,<dir>              merge: combine the reports of earlier runs (their state.json) into --out
## Each mode writes report.md (FLAGS first, numbered, then numbered tables), data.json, csv/ and
## state.json into <out>/<mode>/; --mode=all also writes <out>/report.md and <out>/data.json
## with everything; every run writes <out>/summary.md (also printed). Exit code 0 (flags are
## findings, not failures).
##
## How a run goes (BalanceJobs): the engine measures are units (a fight, a room, a measured
## build, a floor). Phase 1: the N processes (this one and N-1 workers started with
## --worker=k/N) deal the units out in turn and measure their own into the cache, skipping what
## the cache already holds for the same code and data. Phase 2: this process builds every
## report from the cache.

const DEFAULT_OUT := "user://balance"
const DEFAULT_CACHE := "user://balance_cache"
const MODES := ["model", "arena", "pack", "marginal", "economy", "compound", "gauntlet"]

var _args := {}
var _jobs: BalanceJobs


func _ready() -> void:
	var args := parse_args(OS.get_cmdline_user_args())
	_args = args
	var started := Time.get_ticks_msec()
	if args.classic:
		BalanceLab.simulate = false
		BalanceLab.renew_floors = false
	if args.no_renew:
		BalanceLab.renew_floors = false
	BalanceLab.isolate_profile()
	var content: ContentDB = load("res://data/content_db.tres")
	var targets := BalanceBuild.load_targets()
	var every_build := BalanceBuild.load_all()
	var problem := _apply_only(args, content, every_build)
	if not problem.is_empty():
		printerr("balance: %s" % problem)
		await _quit(1)
		return
	var builds := BalanceBuild.select(every_build, args.builds)
	var out_dir: String = _absolute(args.out)
	var mode: String = args.mode
	if mode == "merge":
		_merge(args.inputs, out_dir)
		await _quit(0)
		return
	if builds.is_empty():
		printerr("balance: no build matches %s (see data/balance/builds/)" % ", ".join(args.builds))
		await _quit(1)
		return
	var keys: PackedStringArray = args.difficulties
	if keys.is_empty() and args.quick:
		keys = PackedStringArray(["normal"])
	var difficulties := BalanceContent.difficulties(content, keys)
	var bosses := _bosses(content, args.bosses)
	var modes: Array = MODES.duplicate() if mode == "all" else [mode]
	if not MODES.has(mode) and mode != "all":
		printerr("balance: unknown --mode=%s (%s, all, merge)" % [mode, ", ".join(MODES)])
		await _quit(1)
		return

	var lab := BalanceLab.new()
	lab.content = content
	lab.seed_value = args.seed
	add_child(lab)
	_jobs = BalanceJobs.new(_absolute(args.cache))
	_jobs.read_cache = not args.no_cache
	_jobs.options = "seed=%d|quick=%s|classic=%s|renew=%s" % [args.seed, str(args.quick), str(args.classic), str(BalanceLab.renew_floors)]
	var engine_modes := modes.filter(func(m: String) -> bool: return m != "model")

	# A worker: phase 1 only, its share of the units, then out.
	if not String(args.worker).is_empty():
		_jobs.worker = int(String(args.worker).get_slice("/", 0))
		_jobs.workers = maxi(int(String(args.worker).get_slice("/", 1)), 1)
		_jobs.claims_dir = args.claims
		for m: String in engine_modes:
			await _run_mode(m, content, targets, every_build, builds, difficulties, bosses, lab)
		print("balance worker %s: %s" % [args.worker, _jobs.summary()])
		lab.queue_free()
		await _quit(0)
		return

	# Phase 1: this process and the workers measure what the cache doesn't hold.
	var workers := maxi(int(args.jobs), 1)
	var pids: Array[int] = []
	var phase_started := Time.get_ticks_msec()
	var claims := ""
	if not engine_modes.is_empty():
		_jobs.workers = workers
		_jobs.worker = 0
		if workers > 1:
			# This run's claims (BalanceJobs): a fresh folder, removed at the end.
			claims = _absolute(args.cache).path_join("claims-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
			DirAccess.make_dir_recursive_absolute(claims)
			_jobs.claims_dir = claims
			_args["claims"] = claims
		for k in range(1, workers):
			var pid := OS.create_process(OS.get_executable_path(), _worker_args(k, workers))
			pids.append(pid)
		if workers > 1:
			print("balance: %d worker process(es) started (--jobs=%d)" % [pids.size(), workers])
		for m: String in engine_modes:
			await _run_mode(m, content, targets, every_build, builds, difficulties, bosses, lab)
		for pid in pids:
			while OS.is_process_running(pid):
				await get_tree().create_timer(1.0).timeout
	if not claims.is_empty():
		_remove_dir(claims)
	var measure_time := (Time.get_ticks_msec() - phase_started) / 1000.0
	var measured := _jobs.measured
	var own_time := _jobs.measure_seconds
	var kept := _jobs.hits

	# Phase 2: every report from the cache (anything missing is measured here).
	_jobs.measuring = false
	_jobs.rewind()
	_jobs.hits = 0
	var reports: Array[BalanceReport] = []
	var lines := PackedStringArray()
	for m: String in modes:
		var mode_started := Time.get_ticks_msec()
		var before := _jobs.measured
		var report: BalanceReport = await _run_mode(m, content, targets, every_build, builds, difficulties, bosses, lab)
		if report == null:
			continue
		report.notes.append("Run: %s" % _command(args))
		report.timings[m] = (Time.get_ticks_msec() - mode_started) / 1000.0
		report.write(out_dir.path_join(m))
		report.save_state(out_dir.path_join(m).path_join("state.json"))
		reports.append(report)
		print(report.summary())
		lines.append("| %s | %d | %d | %d |%s" % [m, report.error_count(), report.warn_count(), report.tables.size(),
			" (%d measured late)" % (_jobs.measured - before) if _jobs.measured > before else ""])

	if mode == "all":
		var combined := _combine(reports)
		combined.notes.insert(0, "Run: %s" % _command(args))
		combined.write(out_dir)
		combined.save_state(out_dir.path_join("state.json"))
		print("")
		print(combined.summary(20))
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	var summary := _summary(args, seconds, measure_time, measured, own_time, kept, workers, lines, reports)
	BalanceReport._write_file(out_dir.path_join("summary.md"), summary)
	print("")
	print(summary)
	print("balance: %s done in %.0f s (real time). Reports in %s" % [mode, seconds, out_dir])
	lab.queue_free()
	await _quit(0)


## The compact account of a run: time, units measured or kept, flags per mode, the headline
## numbers (the gauntlet's Keeper table when it ran).
func _summary(args: Dictionary, seconds: float, measure_time: float, measured: int, own_time: float, kept: int, workers: int, lines: PackedStringArray, reports: Array[BalanceReport]) -> String:
	var out := PackedStringArray()
	out.append("# Balance run summary")
	out.append("")
	out.append("- Command: `%s`" % _command(args))
	out.append("- Real time: %.0f s (measuring %.0f s with %d process(es), then the reports from the cache). This process measured %d units (%.0f s) and found %d already kept (same code and data); the workers printed their share." % [
		seconds, measure_time, workers, measured, own_time, kept])
	out.append("")
	out.append("| Mode | Errors | Warnings | Tables |")
	out.append("|---|---|---|---|")
	out.append_array(lines)
	for report in reports:
		var headline: Variant = report.data.get("headline")
		if headline is String and not (headline as String).is_empty():
			out.append("")
			out.append(headline)
	return "\n".join(out) + "\n"


## The same command for worker k of n (phase 1 only).
func _worker_args(k: int, n: int) -> PackedStringArray:
	var result := PackedStringArray(["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
		"res://tools/balance/balance.tscn", "--"])
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--jobs") or arg.begins_with("--worker") or arg.begins_with("--cache") or arg.begins_with("--claims"):
			continue
		result.append(arg)
	result.append("--cache=%s" % _absolute(_args.cache))
	result.append("--worker=%d/%d" % [k, n])
	if not String(_args.get("claims", "")).is_empty():
		result.append("--claims=%s" % _args.claims)
	return result


## `dir` and the (empty) folders in it.
static func _remove_dir(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		DirAccess.remove_absolute(dir.path_join(sub))
	DirAccess.remove_absolute(dir)


static func _absolute(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path


func _run_mode(m: String, content: ContentDB, targets: BalanceTargets, every_build: Array[BalanceBuildDef], builds: Array[BalanceBuildDef],
		difficulties: Array[DifficultyDef], bosses: Array[BossDef], lab: BalanceLab) -> BalanceReport:
	var args := _args
	match m:
		"model":
			var model := BalanceModel.new(content, targets, every_build)
			model.builds = builds
			model.difficulties = difficulties if not args.quick else BalanceContent.difficulties(content, PackedStringArray(["normal", "hard"]))
			model.bosses = bosses
			model.quick = args.quick
			return model.run()
		"arena":
			var arena := _arena(content, targets, every_build, builds, difficulties, bosses, lab)
			if not args.keeper.is_empty():
				# The bottom of the Well only (the Nameless Keepers and Tôma).
				var bottom := await arena.run_bottom()
				arena.queue_free()
				return bottom
			var report := await arena.run_bosses()
			if not args.no_weapons:
				var weapons := await arena.run_weapons()
				report.merge(weapons, "weapons")
			report.title = "Balance arena"
			arena.queue_free()
			return report
		"pack":
			var arena := _arena(content, targets, every_build, builds, difficulties, bosses, lab)
			var report := await arena.run_packs()
			arena.queue_free()
			return report
		"marginal":
			var marginal := BalanceMarginal.new()
			marginal.lab = lab
			marginal.jobs = _jobs
			marginal.content = content
			marginal.targets = targets
			marginal.all_builds = every_build
			marginal.seed_value = args.seed
			marginal.quick = args.quick
			marginal.picks = args.picks
			marginal.verbose = _jobs.measuring
			for a: String in args.acts:
				marginal.acts.append(int(a))
			if args.quick and marginal.acts.is_empty():
				marginal.acts.append(2)
			add_child(marginal)
			var report := await marginal.run()
			marginal.queue_free()
			return report
		"economy":
			var economy := BalanceEconomy.new()
			economy.lab = lab
			economy.jobs = _jobs
			economy.content = content
			economy.targets = targets
			economy.all_builds = every_build
			economy.difficulties = difficulties
			economy.seed_value = args.seed
			economy.quick = args.quick
			economy.verbose = _jobs.measuring
			add_child(economy)
			var report := await economy.run()
			economy.queue_free()
			return report
		"compound":
			# One unit: its measures share sessions (a few minutes in all).
			var state: Variant = await _jobs.unit("compound", PackedStringArray(["res://data/"]), func() -> Dictionary:
				var compound := BalanceCompound.new()
				compound.lab = lab
				compound.content = content
				compound.targets = targets
				compound.all_builds = every_build
				compound.seed_value = args.seed
				compound.quick = args.quick
				add_child(compound)
				var compound_report := await compound.run()
				compound.queue_free()
				return compound_report.to_state())
			return BalanceReport.from_state(state) if state != null else null
		"gauntlet":
			var gauntlet := BalanceGauntlet.new()
			gauntlet.lab = lab
			gauntlet.jobs = _jobs
			gauntlet.content = content
			gauntlet.targets = targets
			gauntlet.all_builds = every_build
			gauntlet.builds = builds
			gauntlet.difficulties = difficulties if not args.difficulties.is_empty() or args.quick else BalanceContent.difficulties(content, PackedStringArray(["easy", "normal", "hard"]))
			if args.bots_given:
				gauntlet.bots = args.bots
			gauntlet.timeout = args.timeout
			gauntlet.part = args.gauntlet
			gauntlet.seed_value = args.seed
			gauntlet.quick = args.quick
			gauntlet.verbose = _jobs.measuring
			for a: String in args.acts:
				gauntlet.acts.append(int(a))
			add_child(gauntlet)
			var report := await gauntlet.run()
			gauntlet.queue_free()
			return report
	return null


func _arena(content: ContentDB, targets: BalanceTargets, every_build: Array[BalanceBuildDef], builds: Array[BalanceBuildDef],
		difficulties: Array[DifficultyDef], bosses: Array[BossDef], lab: BalanceLab) -> BalanceArena:
	var arena := BalanceArena.new()
	arena.lab = lab
	arena.jobs = _jobs
	arena.content = content
	arena.targets = targets
	arena.all_builds = every_build
	arena.builds = builds
	arena.difficulties = difficulties
	arena.core = arena.core_difficulties()
	arena.bosses = bosses
	arena.bots = _args.bots
	arena.seed_value = _args.seed
	arena.all_pairs = _args.all_pairs
	arena.timeout = _args.timeout
	arena.quick = _args.quick
	arena.plain_only = _args.plain
	BalanceArena.FightLog.log_hits = _args.hits
	arena.verbose = _jobs.measuring
	arena.weapon_ids = _args.weapons
	arena.keeper_weapons = _args.keeper
	for a: String in _args.acts:
		arena.acts.append(int(a))
	add_child(arena)
	return arena


## --only=a,b,c: each name sorted into what it restricts (an act, a boss, a build, a weapon, a
## difficulty). An act restricts the bosses, builds, rooms and marginal values to that act.
## Returns a problem to report, or "".
static func _apply_only(args: Dictionary, content: ContentDB, every_build: Array[BalanceBuildDef]) -> String:
	var only: PackedStringArray = args.only
	if only.is_empty():
		return ""
	var boss_ids := BalanceContent.bosses(content).map(func(b: BossDef) -> String: return String(b.id))
	var build_names := every_build.map(func(b: BalanceBuildDef) -> String: return b.name)
	var weapon_ids := BalanceContent.weapons().map(func(w: WeaponDef) -> String: return String(w.id))
	var acts := PackedStringArray()
	for token in only:
		var t := token.strip_edges().to_lower()
		if t.begins_with("act") and t.trim_prefix("act").is_valid_int():
			acts.append(t.trim_prefix("act"))
		elif BalanceContent.ALL_DIFFICULTIES.has(t) or t.begins_with("nightmare+"):
			(args.difficulties as PackedStringArray).append(t)
		elif boss_ids.has(t):
			(args.bosses as PackedStringArray).append(t)
		elif build_names.has(t):
			(args.builds as PackedStringArray).append(t)
		elif weapon_ids.has(t):
			(args.weapons as PackedStringArray).append(t)
		else:
			return "--only: '%s' is no act (act1..act%d), boss, build, weapon or difficulty" % [token, content.dungeon.acts.size()]
	if not acts.is_empty():
		args.acts = acts
		if (args.bosses as PackedStringArray).is_empty():
			for boss in BalanceContent.bosses(content):
				if acts.has(str(BalanceContent.act_of_boss(content, boss))):
					(args.bosses as PackedStringArray).append(String(boss.id))
		if (args.builds as PackedStringArray).is_empty():
			for build in every_build:
				if acts.has(str(build.act)):
					(args.builds as PackedStringArray).append(build.name)
	return ""


static func _combine(reports: Array[BalanceReport]) -> BalanceReport:
	var combined := BalanceReport.new()
	combined.title = "Balance report"
	for report in reports:
		var key := report.title.trim_prefix("Balance ").to_lower().replace(" ", "_")
		combined.notes.append("%s: %d errors, %d warnings, %.0f s" % [report.title, report.error_count(), report.warn_count(), _total(report.timings)])
		combined.merge(report, key)
	combined.notes.append("Real time per part: %s" % ", ".join(combined.timings.keys().map(func(k: String) -> String: return "%s %.0f s" % [k, combined.timings[k]])))
	return combined


static func _total(timings: Dictionary) -> float:
	var total := 0.0
	for k: String in timings:
		total += float(timings[k])
	return total


func _merge(inputs: PackedStringArray, out_dir: String) -> void:
	var reports: Array[BalanceReport] = []
	for dir in inputs:
		var path := dir.path_join("state.json")
		var report := BalanceReport.load_state(path)
		if report == null:
			printerr("balance: no state.json in %s" % dir)
			continue
		reports.append(report)
	var combined := _combine(reports)
	combined.write(out_dir)
	combined.save_state(out_dir.path_join("state.json"))
	print(combined.summary(20))
	print("balance: merged %d reports into %s" % [reports.size(), out_dir])


func _quit(code: int) -> void:
	for i in 2:
		await get_tree().process_frame
	get_tree().quit(code)


## { mode, bosses, builds, difficulties, bots, acts, weapons, only, out, seed, all_pairs, timeout,
## quick, jobs, worker, cache, no_cache, classic, inputs } from the command line.
static func parse_args(user_args: PackedStringArray) -> Dictionary:
	var args := {
		"mode": "model", "bosses": PackedStringArray(), "builds": PackedStringArray(), "difficulties": PackedStringArray(),
		"bots": PackedStringArray(["face_tank", "kite"]), "acts": PackedStringArray(), "weapons": PackedStringArray(),
		"only": PackedStringArray(), "out": DEFAULT_OUT, "seed": 1,
		"all_pairs": false, "timeout": 240.0, "quick": false, "jobs": 2, "worker": "", "cache": DEFAULT_CACHE, "no_cache": false,
		"inputs": PackedStringArray(), "keeper": PackedStringArray(), "plain": false, "no_weapons": false, "classic": false, "no_renew": false, "hits": false, "bots_given": false, "gauntlet": "all", "claims": "", "picks": PackedStringArray(),
	}
	for arg in user_args:
		var key := arg.get_slice("=", 0)
		var value := arg.substr(key.length() + 1) if arg.contains("=") else ""
		match key:
			"--mode": args.mode = value
			"--boss", "--bosses": args.bosses = value.split(",", false)
			"--build", "--builds": args.builds = value.split(",", false)
			"--difficulty", "--difficulties": args.difficulties = value.split(",", false)
			"--bot", "--bots":
				args.bots = value.split(",", false)
				args.bots_given = true
			"--acts", "--act": args.acts = value.split(",", false)
			"--picks", "--pick": args.picks = value.split(",", false)
			"--only": args.only = value.split(",", false)
			"--out": args.out = value
			"--seed": args.seed = int(value)
			"--all-pairs": args.all_pairs = true
			"--timeout": args.timeout = float(value)
			"--quick": args.quick = true
			"--plain": args.plain = true
			"--no-weapons": args.no_weapons = true
			"--hits": args.hits = true
			"--jobs": args.jobs = maxi(1, int(value))
			"--worker": args.worker = value
			"--cache": args.cache = value
			"--no-cache": args.no_cache = true
			"--classic": args.classic = true
			"--no-renew": args.no_renew = true
			"--gauntlet": args.gauntlet = value
			"--keeper", "--keepers": args.keeper = value.split(",", false)
			"--claims": args.claims = value
			"--in": args.inputs = value.split(",", false)
	return args


static func _command(args: Dictionary) -> String:
	var parts := PackedStringArray(["--mode=%s" % args.mode])
	if args.quick:
		parts.append("--quick")
	for key: String in ["only", "bosses", "builds", "difficulties", "bots", "acts", "keeper", "picks"]:
		if not (args.get(key, PackedStringArray()) as PackedStringArray).is_empty():
			parts.append("--%s=%s" % [key, ",".join(args[key])])
	parts.append("--seed=%d" % args.seed)
	if args.all_pairs:
		parts.append("--all-pairs")
	if args.get("plain", false):
		parts.append("--plain")
	if args.get("no_weapons", false):
		parts.append("--no-weapons")
	if args.get("classic", false):
		parts.append("--classic")
	if args.get("no_cache", false):
		parts.append("--no-cache")
	parts.append("--jobs=%d" % args.jobs)
	return " ".join(parts)


static func _bosses(content: ContentDB, ids: PackedStringArray) -> Array[BossDef]:
	var result: Array[BossDef] = []
	for boss in BalanceContent.bosses(content):
		if ids.is_empty() or ids.has(String(boss.id)):
			result.append(boss)
	return result
