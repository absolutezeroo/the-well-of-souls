class_name BalanceJobs
extends RefCounted
## The engine measures cut into units of work (a boss fight, a room, a perk measured on a
## build...), shared between worker processes and kept between runs.
##
## - **Cache.** A unit's result is stored under a key made of what it measured (its id, the
##   seed, the options), the game's code (every .gd and .tscn in src/ and tools/balance/) and the
##   data it depends on: the files its resources load (ResourceLoader dependencies, followed
##   through), so a boss fight of act I is measured again when act I's monsters or the build's
##   perks change, not when an act III monster does. `--no-cache` measures everything again.
## - **Workers.** With `--jobs=N`, N processes (the same command run as `--worker=k/N`) walk
##   the same units in the same order; each takes the next unit no other has claimed (a folder
##   made in `claims_dir`: making it is atomic, the first one wins), so a long unit never holds
##   the others back. Then the first process assembles every mode's report from the cache
##   (`measuring` off), measuring itself anything left undone.
##
## A mode asks for each unit with `await jobs.unit(id, roots, callable)`: the result (measured,
## or read back), or null when the unit belongs to another worker in this pass.

## Files that list everything (followed, they would make every unit depend on all the data):
## hashed as files, their references not followed. What a unit needs from them it names itself.
## An act is followed (its monsters, bosses, biomes and hazards): a unit that names its act
## depends on all of them, so a change to one of its monsters measures the act again.
const SHALLOW := ["res://data/content_db.tres", "res://data/dungeon/dungeon_config.tres"]
const SHALLOW_DIRS: Array[String] = []
## Data every engine measure depends on (the hero, the rules of the floor, ranks and affixes,
## what stands on a floor: props, chests, arenas, hazards; the core combat numbers).
const COMMON_ROOTS := ["res://data/content_db.tres", "res://data/dungeon/dungeon_config.tres", "res://data/player/", "res://data/combat/",
	"res://data/monster_ranks/", "res://data/elites/", "res://data/perks/synergies/", "res://data/items/item_levels.tres",
	"res://data/dungeon/sustain.tres", "res://data/props/", "res://data/chests/", "res://data/arenas/", "res://data/hazards/"]
const CODE_DIRS := ["res://src/", "res://tools/balance/"]
const VERSION := "2"

## This process' share: units whose turn % workers == worker.
var worker := 0
var workers := 1
## Where the processes of one run claim units (empty: units dealt out in turn instead).
var claims_dir := ""
## Phase 1 (true): measure this worker's units that the cache doesn't have. Phase 2 (false): every
## unit read back from the cache (measured here if missing).
var measuring := true
## Where results are kept (one file per key). Empty: no cache, every unit measured.
var cache_dir := ""
## Trust results kept by earlier runs (off: --no-cache; this run's own are always used).
var read_cache := true
## Part of every key: the seed and the options that change what a measure gives.
var options := ""

var hits := 0
var measured := 0
var skipped := 0
var measure_seconds := 0.0
var _turn := 0
var _code_hash := ""
var _this_run := {}
var _file_hashes := {}
var _closures := {}


func _init(dir: String = "") -> void:
	cache_dir = dir
	if not cache_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(cache_dir)


## The unit `id`'s result: kept, measured (`measure`, awaited: it returns the result), or null
## when it is another worker's (phase 1). `roots`: the data files or folders it depends on
## (COMMON_ROOTS are added).
## `shared`: every worker that needs it measures it (a setup the others depend on: cheap,
## and the same in every process); it takes no turn.
func unit(id: String, roots: PackedStringArray, measure: Callable, shared: bool = false) -> Variant:
	var turn := _turn
	if not shared:
		_turn += 1
	var key := key_of(id, roots)
	if not measuring or read_cache or _this_run.has(key):
		var kept: Variant = _read(key)
		if kept != null:
			hits += 1
			return kept
	if measuring and not shared and workers > 1:
		var taken := DirAccess.make_dir_absolute(claims_dir.path_join(key)) != OK if not claims_dir.is_empty() else turn % workers != worker
		if taken:
			skipped += 1
			return null
	var started := Time.get_ticks_usec()
	var result: Variant = await measure.call()
	measure_seconds += (Time.get_ticks_usec() - started) / 1e6
	measured += 1
	_write(key, result)
	_this_run[key] = true
	return result


## Starts a new pass over the units (the turns count from 0 again: every process deals them out
## the same way).
func rewind() -> void:
	_turn = 0


func key_of(id: String, roots: PackedStringArray) -> String:
	var parts := PackedStringArray([VERSION, id, options, code_hash()])
	var all := PackedStringArray(COMMON_ROOTS)
	all.append_array(roots)
	parts.append(data_hash(all))
	return "|".join(parts).md5_text()


## A hash of every .gd and .tscn the measures run (the game and the tools).
func code_hash() -> String:
	if _code_hash.is_empty():
		var files := PackedStringArray()
		for dir: String in CODE_DIRS:
			_list(dir, files, ["gd", "tscn"])
		files.sort()
		var hashes := PackedStringArray()
		for f in files:
			hashes.append(_md5(f))
		_code_hash = "".join(hashes).md5_text()
	return _code_hash


## A hash of the files `roots` (files or folders) load, followed through their dependencies.
func data_hash(roots: PackedStringArray) -> String:
	var files := {}
	for root in roots:
		if root.is_empty():
			continue
		if root.ends_with("/"):
			var listed := PackedStringArray()
			_list(root, listed, ["tres", "res"])
			for f in listed:
				_close(f, files)
		else:
			_close(root, files)
	var paths := files.keys()
	paths.sort()
	var hashes := PackedStringArray()
	for p: String in paths:
		hashes.append("%s=%s" % [p, _md5(p)])
	return "".join(hashes).md5_text()


## `path` and what it loads (data only: scripts count in code_hash()).
func _close(path: String, into: Dictionary) -> void:
	if into.has(path) or path.is_empty():
		return
	into[path] = true
	if SHALLOW.has(path) or SHALLOW_DIRS.any(func(d: String) -> bool: return path.begins_with(d)):
		return
	if not _closures.has(path):
		var deps := PackedStringArray()
		for d in ResourceLoader.get_dependencies(path):
			var dep := d.get_slice("::", d.get_slice_count("::") - 1) if d.contains("::") else d
			if dep.begins_with("uid://"):
				dep = ResourceUID.get_id_path(ResourceUID.text_to_id(dep))
			if dep.begins_with("res://") and not dep.ends_with(".gd") and not dep.ends_with(".gdshader"):
				deps.append(dep)
		_closures[path] = deps
	for dep: String in _closures[path]:
		_close(dep, into)


func _md5(path: String) -> String:
	if not _file_hashes.has(path):
		_file_hashes[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else "missing"
	return _file_hashes[path]


static func _list(dir: String, into: PackedStringArray, extensions: Array) -> void:
	var access := DirAccess.open(dir)
	if access == null:
		return
	for f in access.get_files():
		if extensions.has(f.get_extension()):
			into.append(dir.path_join(f))
	for sub in access.get_directories():
		if not sub.begins_with("."):
			_list(dir.path_join(sub) + "/", into, extensions)


func _read(key: String) -> Variant:
	if cache_dir.is_empty():
		return null
	var path := cache_dir.path_join(key + ".bin")
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return f.get_var()


func _write(key: String, value: Variant) -> void:
	if cache_dir.is_empty():
		return
	var path := cache_dir.path_join(key + ".bin")
	var tmp := path + ".%d.tmp" % OS.get_process_id()
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_var(value)
	f.close()
	DirAccess.rename_absolute(tmp, path)


## Roots of a build: its own file and everything it names by id (perks, runes, affixes,
## shrine upgrades, families, gear).
static func build_roots(build: BalanceBuildDef, content: ContentDB) -> PackedStringArray:
	var roots := PackedStringArray()
	if build == null:
		return roots
	if not build.resource_path.is_empty() and build.resource_path.begins_with("res://"):
		roots.append(build.resource_path)
	if build.weapon:
		roots.append(build.weapon.resource_path)
	if build.oath:
		roots.append(build.oath.resource_path)
		for perk in build.oath.starting_perks:
			if perk:
				roots.append(perk.resource_path)
	for armor in build.armors:
		if armor:
			roots.append(armor.resource_path)
	for id: String in build.perks:
		var perk := BalanceBuild.perk(content, id)
		if perk:
			roots.append(perk.resource_path)
	for id in build.runes:
		var rune := BalanceBuild.rune(content, id)
		if rune:
			roots.append(rune.resource_path)
	for text: String in Array(build.weapon_affixes) + Array(build.armor_affixes):
		for id in text.split(",", false):
			var affix := BalanceBuild.affix(content, id.strip_edges())
			if affix:
				roots.append(affix.resource_path)
	for id: String in build.upgrades:
		var upgrade := BalanceBuild.upgrade(content, id)
		if upgrade:
			roots.append(upgrade.resource_path)
	for synergy in build.extra_families + build.suppress_families:
		if synergy:
			roots.append(synergy.resource_path)
	if build.learned_skill:
		roots.append(build.learned_skill.resource_path)
	var clean := PackedStringArray()
	for r in roots:
		if not r.is_empty() and r.begins_with("res://") and not r.contains("::"):
			clean.append(r)
	return clean


## A build's fingerprint for a unit id: its name plus everything a variant may change (an
## in-memory variant keeps its base's name).
static func build_id(build: BalanceBuildDef) -> String:
	var perks := build.perks.keys()
	perks.sort()
	var ups := build.upgrades.keys()
	ups.sort()
	var parts := PackedStringArray([build.name, "lv%d" % build.level, "il%d/%d" % [build.item_level, build.weapon_item_level],
		build.weapon.resource_path if build.weapon else "-", "r%d" % build.weapon_rarity, ",".join(build.weapon_affixes), ",".join(build.runes),
		",".join(build.armors.map(func(a: ArmorDef) -> String: return a.resource_path if a else "-")), str(build.armor_rarities), "|".join(build.armor_affixes),
		",".join(perks.map(func(p: String) -> String: return "%s%d" % [p, int(build.perks[p])])),
		",".join(ups.map(func(u: String) -> String: return "%s%d" % [u, int(build.upgrades[u])])),
		",".join(build.extra_families.map(func(f: SynergyDef) -> String: return String(f.id))),
		",".join(build.suppress_families.map(func(f: SynergyDef) -> String: return String(f.id))),
		",".join(build.buffs.map(func(b: Variant) -> String: return _buff_text(b))),
		str(build.ignore_sockets), "%.3f" % build.max_hp_cost, build.learned_skill.resource_path if build.learned_skill else "-",
		build.oath.resource_path if build.oath else "-"])
	return ";".join(parts)


static func _buff_text(buff: Variant) -> String:
	if buff is Array and not (buff as Array).is_empty() and (buff as Array)[0] is StatBlock:
		return "%s/%s" % [((buff as Array)[0] as StatBlock).describe(), str((buff as Array)[1])]
	return str(buff)


## A one-line account for the run's summary.
func summary() -> String:
	return "%d measured (%.0f s), %d from the cache%s" % [measured, measure_seconds, hits, ", %d left to other workers" % skipped if skipped > 0 else ""]
