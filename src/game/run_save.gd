class_name RunSave
## The run in progress, kept on disk (user://run.json) so it survives the app being closed:
## a phone call, the system killing it in the background... Saved when a floor begins and when
## the app goes to the background. Resuming builds the floor again from its seed at the saved
## depth, with the hero exactly as saved and what was used up on the floor kept used up
## (World.spent_data(), "floor").
##
## Content is saved by stable namespaced ids through ContentCatalog. Version 3 migrates old
## paths, whose aliases stay valid after a file moves. Unknown content resolves to null.
##
## Robustness: a save from an older version is migrated (_migrate()), not thrown away; one from a
## newer game is refused. A damaged or hand-edited file never crashes the game: every field the
## game reads is checked against SHAPE first, and a field of the wrong kind is dropped (and
## logged), so its default is used. The floor's block carries a stamp of the build that wrote it
## (floor_stamp()): after a game update the floor may come out otherwise from the same seed, and
## its cell-keyed data (chests, holes, cracks) would land on the wrong things, so floor_of() drops
## it: the hero and the run come back, the floor is laid fresh.

const PATH := "user://run.json"
## 3: stable content references. 2: the floor's stamp, the things laid on it used up (FloorLedger), the merchant's stock, the
## ambush, the last boss. 1: the first saves.
const VERSION := 3
## The oldest version _migrate() still reads.
const OLDEST_VERSION := 1
## Bump it when a change makes a floor come out otherwise from the same seed (the generator, the
## order things are laid in, the pools they are drawn from) without a new game version: saved
## floors are then laid fresh (floor_of()). 4: rooms kept apart, monsters by the rooms' size, calm
## rooms, draws without repeats (decision 0012).
const FLOOR_FORMAT := 4

## What a field may hold: "number" (int or float, as JSON reads it), "bool" (or a number),
## "string", "dict", "array", "any"; a Dictionary: a dictionary whose listed keys are checked
## ("*": every value); [shape]: an array whose entries of another shape are dropped.
const SHAPE := {
	"version": "number",
	"depth": "number",
	"kills": "number",
	"bosses_slain": "number",
	"has_won": "bool",
	"souls_awarded": "number",
	"run_gold": "number",
	"history_recorded": "bool",
	"bosses": "array",
	"rerolls": "number",
	"banishes": "number",
	"banished": "array",
	"daily_day": "number",
	"daily_official": "bool",
	"seed": "number", "journey_id": "string",
	"time": "number",
	"splits": ["number"],
	"finish_time": "number",
	"routes": { "*": "number" },
	"hidden_floor": "bool",
	"hidden_done": "bool",
	"finale_open": "bool",
	"finale": "bool",
	"ending_due": "bool",
	"keeper": "dict",
	"secrets_found": "number",
	"bonus_souls": "number",
	"telemetry": "dict",
	"world_stats": "dict",
	"marks": "dict",
	"met_floors": "array",
	"luck": "dict",
	"difficulty": "string",
	"ascension": "number",
	"remote": "dict",
	"last_boss": "string",
	"boss_slain": "bool",
	"floors_without_forge": "number",
	"player": {
		"level": "number",
		"xp": "number",
		"hp": "number",
		"gold": "number",
		"base_stats": { "*": "number" },
		"equipment": "dict",
		"inventory": "array",
		"belt": "array",
		"perks": [{ "stacks": "number", "memory": "dict" }],
	},
	"offers": [{ "level": "number", "rarity": "number", "count": "number", "on_demand": "bool", "cards": "array" }],
	"kept_stock": [{ "price": "number" }],
	"floor": {
		"stamp": "string",
		"chests": "array",
		"bought": "array",
		"secrets": "array",
		"pact": "number",
		"fragment": "bool",
		"seal_kills": "number",
		"sealed": "array",
		"collapsed": "array",
		"slain": "array",
		"spent": "dict",
		"merchant": "dict",
		"ambush": "dict",
		# The floor's hurt monsters, [floor_index, id, Health share], and those that came later
		# (World.spent_data()); optional: a save without them restores them whole / not at all.
		"wounded": ["array"],
		"later": [{ "def": "string", "id": "string", "at": "array", "health": "number", "rank": "string", "affixes": "array", "summoned": "bool" }],
		# The warden fell before quitting: the run picks up in his cleared arena, with what lay
		# there ([kind, data, x, y]; FloorSave.left_behind()).
		"arena_cleared": "bool",
		# The floor's room trial: its id and steps done (RoomTrial.save_data()).
		"trial": "dict",
		"left": ["array"],
	},
}

## Empty = nothing is read or written.
static var path := PATH


static func exists() -> bool:
	return not path.is_empty() and not read().is_empty()


static func write(data: Dictionary) -> void:
	if path.is_empty():
		return
	data["version"] = VERSION
	SafeFile.write_json(path, data)


## The saved run, or an empty Dictionary if there is none (or it can't be read: not a run, from a
## newer game, the hero damaged). Older versions come migrated, damaged fields dropped.
static func read() -> Dictionary:
	if path.is_empty():
		return {}
	return parse(SafeFile.read_json(path))


## read()'s checks on data read from a save file: {} if it can't be a run, else the run migrated to
## VERSION with its damaged fields dropped (each one logged).
static func parse(data: Variant) -> Dictionary:
	if not data is Dictionary:
		if data != null:
			push_warning("Run save: not a run, ignored.")
		return {}
	var version: Variant = (data as Dictionary).get("version", 0)
	if not (version is float or version is int) or int(version) < OLDEST_VERSION or int(version) > VERSION:
		push_warning("Run save: version %s can't be read (%d to %d), ignored." % [version, OLDEST_VERSION, VERSION])
		return {}
	if (data as Dictionary).has("player") and not (data as Dictionary).player is Dictionary:
		push_warning("Run save: the hero is damaged, the run is ignored.")
		return {}
	var clean := sanitized(data, SHAPE, "") as Dictionary
	return _migrate(clean)


## `value` as `shape` allows (see SHAPE); what doesn't fit is dropped and logged. Null when
## `value` itself doesn't fit.
static func sanitized(value: Variant, shape: Variant, where: String) -> Variant:
	if shape is Dictionary:
		if not value is Dictionary:
			return null
		var result := {}
		for key: Variant in value:
			var key_shape: Variant = shape.get(str(key), shape.get("*", "any"))
			var kept: Variant = sanitized(value[key], key_shape, "%s/%s" % [where, key])
			if kept == null and str(key_shape) != "any":
				push_warning("Run save: dropped the damaged field %s/%s." % [where, key])
				continue
			result[key] = kept
		return result
	if shape is Array:
		if not value is Array:
			return null
		var entries: Array = []
		for entry: Variant in value:
			var kept: Variant = sanitized(entry, shape[0], where + "[]")
			if kept == null:
				push_warning("Run save: dropped a damaged entry of %s." % where)
				continue
			entries.append(kept)
		return entries
	match str(shape):
		"number":
			return value if (value is float or value is int) and is_finite(float(value)) else null
		"bool":
			return value if value is bool or value is float or value is int else null
		"string":
			return value if value is String or value is StringName else null
		"dict":
			return value if value is Dictionary else null
		"array":
			return value if value is Array else null
	return value


## An older save brought up to VERSION, field by field (each step one version up).
static func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", OLDEST_VERSION))
	if version < 2:
		# Version 1 had no floor stamp: floor_of() lays its floor fresh (the generator may have
		# changed with the update that brought version 2), the hero and the run are kept whole.
		version = 2
	if version < 3:
		data = catalog().migrate(data) as Dictionary
		version = 3
	data["version"] = version
	return data


## The build a floor's save comes from: the game's version and FLOOR_FORMAT.
static func floor_stamp() -> String:
	return "%s/%d" % [ProjectSettings.get_setting("application/config/version", ""), FLOOR_FORMAT]


## The saved floor's block (World.restore_spent()) if this build lays the floor as it was: {}
## when there is none, or when its stamp is another build's (see floor_outdated()).
static func floor_of(saved: Dictionary) -> Dictionary:
	var floor_data: Variant = saved.get("floor", {})
	if not floor_data is Dictionary or floor_outdated(saved):
		return {}
	return floor_data


## The saved floor was written by another build: it is laid fresh (floor_of()). The Game says so.
static func floor_outdated(saved: Dictionary) -> bool:
	var floor_data: Variant = saved.get("floor")
	return floor_data is Dictionary and not (floor_data as Dictionary).is_empty() \
		and str((floor_data as Dictionary).get("stamp", "")) != floor_stamp()


static func erase() -> void:
	for file in [path, path + ".tmp"]:
		if not path.is_empty() and FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file) if file.begins_with("user://") else file)


# --- Content references ------------------------------------------------------

static var _catalog: ContentCatalog


## Loaded lazily, after class registration: preloading the catalog would cycle through skills.
static func catalog() -> ContentCatalog:
	if _catalog == null:
		_catalog = load("res://data/save/content_catalog.tres") as ContentCatalog
	return _catalog


static func ref(resource: Resource) -> String:
	return catalog().encode(resource) if resource else ""


## Resolves a stable id or historical path; null for unknown or removed content.
static func load_ref(saved_ref: Variant) -> Resource:
	return catalog().resolve(saved_ref)


static func refs(resources: Array) -> Array:
	return resources.map(func(resource: Resource) -> String: return ref(resource))
