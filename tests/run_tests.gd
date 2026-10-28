extends Node
## Headless test runner. From a terminal at the project root:
##   godot --headless --fixed-fps 60 res://tests/run_tests.tscn
## Options, after `--` (docs/testing.md, "Running the tests"):
##   --only=unit,title     these suites only
##   --test=game.pacts,... these tests only: a test's full name (`suite.test`), a suite's name,
##                         or a pattern with `*` (`game.combat_*`)
##   --shard=i/n           the i-th of n shares of the tests (0-based), balanced on
##                         tests/timings.json (tools/run_tests.py runs every share in parallel)
##   --seed=N              the run's seed (printed at the start: a failure can be played again)
##   --timings             a table of every test's time at the end, slowest first
##   --list                the tests' names (with the filters above), nothing run
## Suites (tests/suites/): unit (rules and data), title (title screen), game (the real game, in
## tests that each start a fresh run), tutorial (the first steps and the hints). A suite cut in
## tests gives them in TestSuite.test_cases(); every test starts from the same shared state (the
## profile, the settings, the online layer, the input device, the pause, the cheats: _reset()).
## Exit code = number of failed checks.

const SUITES := {
	"unit": preload("res://tests/suites/unit_tests.gd"),
	"title": preload("res://tests/suites/title_tests.gd"),
	"game": preload("res://tests/suites/game_tests.gd"),
	"tutorial": preload("res://tests/suites/tutorial_tests.gd"),
}
## Opt-in suites, run only when named in --only (balance: the balance targets with tools/balance;
## some of its checks fail on purpose today, see docs/balance.md). Loaded then, so a broken tool
## can't stop the other suites.
const OPT_IN := {
	"balance": "res://tests/suites/balance_tests.gd",
}
## Each test's last measured seconds (tools/run_tests.py --save-timings writes it): what --shard
## balances the shares on. A test it doesn't know counts DEFAULT_SECONDS.
const TIMINGS_PATH := "res://tests/timings.json"
const DEFAULT_SECONDS := 5.0
## A test still running after this many seconds is stuck (a coroutine that never resumes): it
## fails, and the run stops there rather than hang forever.
const TEST_TIMEOUT := 900.0

## The settings as the runner set them up: put back before every test.
var _settings_kept := {}
## The test running now (the watchdog's).
var _current := ""
## [full name, checks, failed, msec] of each test run.
var _results: Array = []
## The suites asked for, made (put in the tree when their turn comes): name -> TestSuite.
var _suites := {}


func _ready() -> void:
	# Without a sound card, playbacks are never released; keep the output clean.
	Sfx.enabled = false
	# Never touch the player's real save.
	Profile.save_path = ""
	# Hints would pop up all over the other tests (the tutorial tests turn them on).
	Settings.tutorial_hints = false
	# No boss story before each fight either (the story tests turn them on).
	Settings.boss_stories = Settings.STORIES_OFF
	Settings.path = ""
	# The checks read English texts, whatever the machine's (or the saved) language.
	Settings.language = "en"
	_settings_kept = _script_vars(Settings)
	RunSave.path = "user://test_run_%d.json" % OS.get_process_id()  # one per test process
	var options := _options()
	var run_seed := int(options.get("seed", -1))
	if run_seed < 0:
		randomize()
		run_seed = randi() % 1000000
	print("Seed %d (play the same tests again with --seed=%d)" % [run_seed, run_seed])
	var plan := _plan(options)
	if options.has("list"):
		for entry: Dictionary in plan:
			print(entry.name)
		for suite: TestSuite in _suites.values():
			suite.free()
		get_tree().quit(0)
		return
	if not _helpers_compile():
		TestSuite.failures += 1
	var watchdog := Timer.new()
	watchdog.one_shot = true
	watchdog.ignore_time_scale = true
	watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	watchdog.timeout.connect(_on_stuck)
	add_child(watchdog)
	var suite_names: Array[String] = []
	for entry: Dictionary in plan:
		if not suite_names.has(entry.suite):
			suite_names.append(entry.suite)
	for suite_name in suite_names:
		var suite: TestSuite = _suites[suite_name]
		add_child(suite)
		var before := TestSuite.checks
		_reset()
		await Callable(suite, &"before_cases").call()  # (a coroutine in some suites)
		for entry: Dictionary in plan:
			if entry.suite != suite_name:
				continue
			_reset()
			var case_seed := absi(hash("%d/%s" % [run_seed, entry.name]))
			seed(case_seed)
			Game.seed_runs(case_seed)
			var checks_before := TestSuite.checks
			var failed_before := TestSuite.failures
			var started := Time.get_ticks_msec()
			_current = entry.name
			watchdog.start(TEST_TIMEOUT)
			await (entry.call as Callable).call()
			watchdog.stop()
			var took := Time.get_ticks_msec() - started
			_results.append([entry.name, TestSuite.checks - checks_before, TestSuite.failures - failed_before, took])
			print("[test] %s: %d checks, %d failed, %.1f s" % [entry.name, TestSuite.checks - checks_before, TestSuite.failures - failed_before, took / 1000.0])
		await Callable(suite, &"after_cases").call()
		print("%s: %d checks" % [suite_name, TestSuite.checks - before])
		suite.queue_free()
		_suites.erase(suite_name)
		await get_tree().process_frame
	Game.seed_runs(-1)
	RunSave.erase()
	if options.has("timings"):
		_print_timings()
	print("\n%d checks, %d failed" % [TestSuite.checks, TestSuite.failures])
	Sfx.stop_all()
	HitStop.reset()
	for i in 2:
		await get_tree().process_frame
	get_tree().quit(TestSuite.failures)


## The tests to run in this process, in the suites' order: {suite, name, call} each. A suite that
## doesn't compile is a failure, not 0 checks.
func _plan(options: Dictionary) -> Array:
	var only: PackedStringArray = options.get("only", PackedStringArray())
	var wanted: PackedStringArray = options.get("test", PackedStringArray())
	var scripts := SUITES.duplicate()
	for suite_name: String in OPT_IN:
		if only.has(suite_name) or wanted.has(suite_name) or Array(wanted).any(func(p: String) -> bool: return p.begins_with(suite_name + ".")):
			scripts[suite_name] = load(OPT_IN[suite_name])
	var plan: Array = []
	for suite_name: String in scripts:
		if not only.is_empty() and not only.has(suite_name):
			continue
		var script: GDScript = scripts[suite_name]
		if script == null or not script.can_instantiate():
			TestSuite.failures += 1
			printerr("FAIL: the %s suite doesn't compile" % suite_name)
			continue
		var suite: TestSuite = script.new()
		var taken := false
		for case: Array in suite.test_cases():
			var full := suite_name if case[0] == "" else "%s.%s" % [suite_name, case[0]]
			if not wanted.is_empty() and not Array(wanted).any(func(p: String) -> bool: return full == p or full.begins_with(p + ".") or full.match(p)):
				continue
			plan.append({ "suite": suite_name, "name": full, "call": case[1] })
			taken = true
		if taken:
			_suites[suite_name] = suite
		else:
			suite.free()
	if options.has("shard"):
		plan = _share(plan, options.shard[0], options.shard[1])
	return plan


## The `index`-th of `count` shares of `plan`, balanced on the tests' last times (the longest
## first, each to the lightest share), in the plan's order.
func _share(plan: Array, index: int, count: int) -> Array:
	var seconds := {}
	var text := FileAccess.get_file_as_string(TIMINGS_PATH)
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if parsed is Dictionary:
		seconds = parsed
	var order := range(plan.size())
	var weight := func(i: int) -> float: return float(seconds.get(plan[i].name, DEFAULT_SECONDS))
	order.sort_custom(func(a: int, b: int) -> bool: return weight.call(a) > weight.call(b) or (weight.call(a) == weight.call(b) and a < b))
	var loads: Array[float] = []
	loads.resize(count)
	loads.fill(0.0)
	var mine := {}
	for i: int in order:
		var lightest := 0
		for share in count:
			if loads[share] < loads[lightest]:
				lightest = share
		loads[lightest] += weight.call(i)
		if lightest == index:
			mine[i] = true
	var result: Array = []
	for i in plan.size():
		if mine.has(i):
			result.append(plan[i])
	return result


## Before every test: the shared state as the runner first set it, whatever the last test left.
func _reset() -> void:
	get_tree().paused = false
	DebugCheats.reset()
	HitStop.reset()
	Profile.held = false
	Profile.save_path = ""
	Profile.reset()
	for key: String in _settings_kept:
		Settings.set(key, _settings_kept[key])
	Settings.apply()
	# The online layer (OnlineSession and every service: the leaderboards, the privacy choices, the
	# gameplay statistics, the world counters, the remote settings, the feedback): no file, no
	# server (never the network; their suites use a fake), no question on the title screen,
	# nothing queued, no timer running, the game's own values.
	OnlineSession.use_all_for_tests()
	# The suites play the phone's game (touch controls, "Tap" texts) unless a test picks a
	# keyboard or a gamepad (the pc tests); a test that sends a key puts touch back after it.
	InputDevice.use(InputDevice.Kind.TOUCH)
	for action in InputMap.get_actions():
		Input.action_release(action)
	RunSave.erase()
	# The first runs' sheltered first room and slow first monster (FirstSteps) would change every
	# fight the tests stage on floor 1 of a fresh profile: off, but in their own tests.
	FirstSteps.enabled = false


## A script's own variables on `node` (not the private ones): name -> value.
func _script_vars(node: Object) -> Dictionary:
	var found := {}
	for property in node.get_property_list():
		var key: String = property.name
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not key.begins_with("_"):
			found[key] = node.get(key)
	return found


func _on_stuck() -> void:
	TestSuite.failures += 1
	printerr("FAIL: %s still running after %d s (stuck): the run stops" % [_current, TEST_TIMEOUT])
	_print_timings()
	print("\n%d checks, %d failed" % [TestSuite.checks, TestSuite.failures])
	get_tree().quit(TestSuite.failures)


func _print_timings() -> void:
	var sorted := _results.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[3] > b[3])
	var total := 0
	print("\nTimings (slowest first):")
	for result: Array in sorted:
		total += int(result[3])
		print("%8.1f s  %s (%d checks)" % [result[3] / 1000.0, result[0], result[1]])
	print("%8.1f s  in all, %d tests" % [total / 1000.0, sorted.size()])


## The command line's options (after `--`): only, test (lists), shard ([i, n]), seed, timings, list.
func _options() -> Dictionary:
	var options := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			options.only = arg.trim_prefix("--only=").split(",", false)
		elif arg.begins_with("--test="):
			options.test = arg.trim_prefix("--test=").split(",", false)
		elif arg.begins_with("--shard="):
			var parts := arg.trim_prefix("--shard=").split("/")
			if parts.size() == 2 and int(parts[1]) > 0:
				options.shard = [clampi(int(parts[0]), 0, int(parts[1]) - 1), int(parts[1])]
		elif arg.begins_with("--seed="):
			options.seed = absi(int(arg.trim_prefix("--seed=")))
		elif arg == "--timings":
			options.timings = true
		elif arg == "--list":
			options.list = true
	return options


## Every script of tests/suites/ compiles (one the suites borrow from would otherwise only show
## as a script error, with 0 failed).
func _helpers_compile() -> bool:
	var ok := true
	for file in DirAccess.get_files_at("res://tests/suites"):
		if not file.ends_with(".gd"):
			continue
		var helper := load("res://tests/suites/" + file) as GDScript
		if helper == null or not helper.can_instantiate():
			printerr("FAIL: tests/suites/%s doesn't compile" % file)
			ok = false
	return ok
