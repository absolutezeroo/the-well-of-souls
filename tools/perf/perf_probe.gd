extends TestSuite
## Performance probe (docs/performance.md): the real game, headless, with fixed seeds.
##   godot --headless --fixed-fps 60 res://tools/perf/perf_probe.tscn [-- --fight-frames=1200 --floors=4 --pack=40]
## 1. Floor generation: lays the same floors (seeds x depths) and times `World.build_floor`; prints
##    a digest of each floor (tiles, monsters, props, items), so a change that should only be
##    faster can be checked to lay exactly the same floors.
## 2. A heavy fight: a bot fights a pack of monsters kept at 40 around it (its Health refilled),
##    and every frame's process and physics times are kept: average and 95th percentile.
## Exit code 0. The numbers depend on the machine: compare runs made on the same one.
## (It extends TestSuite for its bot and helpers; it checks nothing.)

## The monsters of the fight, spawned in turn (melee, ranged, casters, fliers).
const FIGHTERS: Array[String] = [
	"res://data/monsters/rat.tres",
	"res://data/monsters/skeleton.tres",
	"res://data/monsters/slime.tres",
	"res://data/monsters/bat.tres",
	"res://data/monsters/spider.tres",
	"res://data/monsters/eye.tres",
	"res://data/monsters/shaman.tres",
	"res://data/monsters/snake.tres",
]
## Monsters kept around the bot in the fight (--pack=N: a crowd of 120...).
const PACK := 40
const DEPTHS: Array[int] = [1, 2, 3, 4, 6, 7, 8, 9]

## Each measured frame: [process ms (with the drawing), physics ms (its physics steps), whole frame ms].
var _samples: Array[PackedFloat32Array] = []
var _measuring := false
## The fight's crowd (PACK, or --pack).
var _pack := PACK
var _last_usec := 0
var _process_usec := 0
## Whether _now_usec() reads the thread's CPU time (false once it can't).
var _cpu_clock := true


func _ready() -> void:
	Sfx.enabled = false
	Profile.save_path = ""
	Profile.reset()
	Settings.tutorial_hints = false
	Settings.boss_stories = Settings.STORIES_OFF
	Settings.path = ""
	Settings.language = "en"
	Settings.apply()
	OnlineSession.use_all_for_tests()
	InputDevice.use(InputDevice.Kind.TOUCH)
	RunSave.path = "user://perf_run_%d.json" % OS.get_process_id()
	HitStop.enabled = false  # (its pauses last real seconds: the fight would hang on the machine's speed)
	seed(1)
	var fight_frames := int(_option("fight-frames", "1200"))
	var floors := int(_option("floors", "4"))
	_pack = int(_option("pack", str(PACK)))
	var game := GAME_SCENE.instantiate() as Game
	game.show_act_cards = false
	add_child(game)
	await _frames(5)
	game.world.run_bosses.clear()  # (the run's bosses are rolled unseeded: the act's first ones)
	var generation := await _measure_generation(game, floors)
	var fight := await _measure_fight(game, fight_frames)
	print("\n== perf probe (%s) ==" % ("main thread CPU time" if _cpu_clock else "wall clock"))
	print("generation: %d floors, avg %.1f ms, p95 %.1f ms, max %.1f ms" % [generation.size(), _avg(generation), _pct(generation, 0.95), _pct(generation, 1.0)])
	for key: String in ["process", "physics", "both", "frame"]:
		var values: PackedFloat32Array = fight[key]
		print("fight %-8s avg %.2f ms, p95 %.2f ms, max %.2f ms" % [key, _avg(values), _pct(values, 0.95), _pct(values, 1.0)])
	print("fight: %d frames, %d kills, %d awake monsters on average, digest %d" % [fight["frames"], fight["kills"], fight["awake"], fight["digest"]])
	RunSave.erase()
	get_tree().quit(0)


func _option(key: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % key):
			return arg.get_slice("=", 1)
	return fallback


## Lays `floors` seeds x DEPTHS floors; their build times in ms (prints a digest per floor).
func _measure_generation(game: Game, floors: int) -> PackedFloat32Array:
	var world := game.world
	var times := PackedFloat32Array()
	for run_seed in floors:
		for depth in DEPTHS:
			world.rng.seed = hash("perf-%d-%d" % [run_seed, depth])
			var started := _now_usec()
			world.build_floor(depth, CONTENT)
			times.append((_now_usec() - started) / 1000.0)
			print("floor seed %d depth %d: %.1f ms, digest %d" % [run_seed, depth, times[-1], _digest(world)])
			world.place_player(game.player)
			await _frames(2)
	return times


## What a floor laid: its tiles, and where its monsters, props and things lying around are.
func _digest(world: World) -> int:
	var parts: Array[String] = [str(hash(world.map.tiles)), str(world.map.rooms)]
	var things: Array[String] = []
	for group: String in ["monsters", "props", "pickups", "gold", "chests", "traps", "heat_sources", "quicksand", "crumbling_floors", "encounters", "forges"]:
		for node in get_tree().get_nodes_in_group(group):
			var thing := node as Node2D
			if thing and not thing.is_queued_for_deletion():
				things.append("%s %s %s" % [group, thing.name.rstrip("0123456789@"), thing.global_position.round()])
	things.sort()
	parts.append_array(things)
	if _option("dump-depth", "") == str(world.depth):
		print("\n".join(parts))
	return hash("|".join(parts))


## A bot against `_pack` monsters around it for `frames` physics frames, from a fixed floor.
func _measure_fight(game: Game, frames: int) -> Dictionary:
	var world := game.world
	var player := game.player
	seed(2)
	world.rng.seed = hash("perf-fight")
	world.build_floor(3, CONTENT)
	world.place_player(player)
	await _frames(3)
	await _clear_monsters(world)
	var fighters: Array[MonsterDef] = []
	for path in FIGHTERS:
		fighters.append(load(path) as MonsterDef)
	var kills := [0]
	var on_kill := func(_monster: Monster) -> void: kills[0] += 1
	Events.monster_killed.connect(on_kill)
	var spawned := [0]
	var awake_total := [0]
	var keep_up := func() -> void:
		player.hp = player.get_max_hp()
		var missing := _pack - world.monster_count()
		for i in missing:
			var angle := TAU * float(spawned[0] % 12) / 12.0
			var at := world.nearest_free_point(player.global_position + Vector2.from_angle(angle) * 110.0)
			world.spawn_monster(fighters[spawned[0] % fighters.size()], at)
			spawned[0] += 1
		awake_total[0] += world.activity.awake.size()
	keep_up.call()
	await _frames(30)  # (the pack wakes)
	_samples.clear()
	_process_usec = 0
	get_tree().physics_frame.connect(_on_physics_start)
	get_tree().physics_frame.connect(keep_up)
	get_tree().process_frame.connect(_on_process_start)
	_measuring = true
	await _bot_play(game, frames)
	_measuring = false
	get_tree().physics_frame.disconnect(_on_physics_start)
	get_tree().process_frame.disconnect(_on_process_start)
	get_tree().physics_frame.disconnect(keep_up)
	Events.monster_killed.disconnect(on_kill)
	var result := {"process": PackedFloat32Array(), "physics": PackedFloat32Array(), "both": PackedFloat32Array(), "frame": PackedFloat32Array()}
	for sample in _samples.slice(1):  # (the first frame includes the setup)
		result["process"].append(sample[0])
		result["physics"].append(sample[1])
		result["both"].append(sample[0] + sample[1])
		result["frame"].append(sample[2])
	result["frames"] = frames
	var where: Array[String] = ["%s" % player.global_position.round()]
	for monster in world.get_hostiles(Actor.Faction.PLAYER):
		where.append("%s %s %d" % [monster.def.id, monster.global_position.round(), monster.hp])
	where.sort()
	result["digest"] = hash("|".join(where))
	result["kills"] = kills[0]
	result["awake"] = roundi(awake_total[0] / maxf(1.0, float(frames)))
	return result


## A physics step starts (SceneTree.physics_frame, before any node's _physics_process): the
## last frame ends here, the process part of it from its process_frame on.
func _on_physics_start() -> void:
	var now := _now_usec()
	if _measuring and _process_usec > 0:
		_samples.append(PackedFloat32Array([
			(now - _process_usec) / 1000.0,
			(_process_usec - _last_usec) / 1000.0,
			(now - _last_usec) / 1000.0,
		]))
	_last_usec = now
	_process_usec = 0


## The process part of the frame starts (after its physics steps).
func _on_process_start() -> void:
	_process_usec = _now_usec()


## The main thread's own CPU time (µs) where the system tells it (Linux: /proc/thread-self/
## schedstat), so other programs on the machine don't count; else the clock.
func _now_usec() -> int:
	if _cpu_clock:
		var stat := FileAccess.open("/proc/thread-self/schedstat", FileAccess.READ)
		if stat:
			return roundi(int(stat.get_line().get_slice(" ", 0)) / 1000.0)
		_cpu_clock = false
	return Time.get_ticks_usec()


func _avg(values: PackedFloat32Array) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / maxf(1.0, float(values.size()))


## The `share` percentile (1.0: the largest).
func _pct(values: PackedFloat32Array, share: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(ceili(share * sorted.size()) - 1, 0, sorted.size() - 1)]
