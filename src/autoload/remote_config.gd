extends OnlineService
## The remote settings (autoload "RemoteConfig"; docs/online.md "Remote settings"): a few values
## the game takes from Talo's game config, so a balance hotfix, a weekend event, the Dawn Knell's
## omen, a message of the day or a kill switch needs no update. The game's own data stays the
## default: with no network, no key, no choice or no value, the game is exactly as its data makes
## it.
##
## Safe by construction:
## - **An allow-list in data** (data/online/remote_config.tres, RemoteKeyDef): a key not on it, a
##   value of the wrong form or out of its bounds, an unknown curse or event id is ignored (and
##   listed in `ignored`, printed in debug builds). A value only ever reaches one of the fixed
##   hooks (RemoteKeyDef.Hook): no code, no resource path comes from the server.
## - **Applied at safe points only**: `active` (what the game reads) is taken from the last read at
##   the title screen (at_title()) and when a run starts (begin_run()), never in the middle of a
##   run; a run's own values are then fixed and saved with it (RemoteTuning, RunState.tuning). The
##   kill switches (scores_off, statistics_off) are the exception: they apply as soon as read.
## - **A version gate**: min_version / max_version make the whole config apply to those game
##   versions only (outside, everything is ignored, kill switches too).
## - **The last good read is kept** in user://remote_config.json, so a value holds offline after a
##   restart; nothing personal is in it.
##
## Privacy (docs/privacy-ops.md): the config is read only once the player turned an online feature
## on (published scores, or the statistics accepted), like the world counters: before that choice
## the game makes no call at all. The read carries no player id (TaloBackend.fetch_config()); Talo
## sees the device's IP address, as with any request.

## A read came back: `latest` changed (the kill switches already apply; the rest waits for a safe
## point).
signal received
## `active` changed (a safe point): the title screen shows its message and event again.
signal applied

const PATH := "user://remote_config.json"
const DEFS := "res://data/online/remote_config.tres"
const CONTENT := "res://data/content_db.tres"
const VERSION := 1
const DAY := 86400

var config: RemoteConfigDef
## Its file (the last good read), the one-read-at-a-time latch and the start timer.
var store := PersistedQueue.new(PATH, VERSION)
## The file's path. Empty = nothing is read or written (tests).
var path: String:
	get:
		return store.path
	set(value):
		store.path = value
## The last good read: key -> value text, the allow-list's keys only (kept in the file).
var fetched := {}
## When it was read (Unix seconds; 0: never).
var fetched_at := 0
## Debug builds only: values set from the debug panel (key -> text), over the server's, checked
## the same way.
var simulated := {}
## The last read (and the simulated values), checked: key -> typed value, valid keys only. The kill
## switches read it.
var latest := {}
## What the game uses: `latest` as it was at the last safe point.
var active := {}
## The config is for other game versions (its min_version / max_version): all of it ignored.
var gated := false
## What the last check ignored, "key: why" (debug panel, tests, printed in debug builds).
var ignored := PackedStringArray()
## How the last read went.
var status: BoardBackend.Status = BoardBackend.Status.UNAVAILABLE
## A run is going on (begin_run() until at_title()): what is read waits.
var in_run := false
## The tests' game version ("": the project's). (The clock is OnlineSession.fake_now.)
var game_version := ""
## No printing (the tests).
var quiet := false

var _read_this_session := false
## Keys the server has that the allow-list doesn't (ignored; never saved).
var _unknown: PackedStringArray = []
var _content: ContentDB
## While the file is read at start-up, a curse or event id is only checked for its form: the
## content (ContentDB, the whole game's data) loads later, at the first safe point that needs it.
var _defer_ids := false
## Some CONTENT_ID values in `latest`/`active` are not checked against the content yet.
var _ids_unchecked := false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(store)
	store.retry_due.connect(fetch)
	boot()


## Its data and file, read (no other service is asked: OnlineSession, "start-up order"; nor the
## content: _defer_ids).
func boot() -> void:
	config = load(DEFS) as RemoteConfigDef
	_defer_ids = true
	load_state()
	_defer_ids = false


func _ready() -> void:
	OnlineSession.register(self)
	_print_ignored()  # (what the file had that this version ignores, now that the build is known)
	# The game asks through RemoteTuning's hooks (no load cycle from World and RunState to here).
	RemoteTuning.for_run_hook = tuning
	RemoteTuning.omen_hook = omen_for
	RemoteTuning.run_starting_hook = begin_run
	store.start_in(config.start_delay)


## The tests: no file, nothing read, the game's own values.
func use_for_tests(_fake: BoardBackend = null) -> void:
	path = ""
	quiet = true
	reset()


## Everything forgotten (not the file), the read in flight and the start timer stopped, the real
## clock back (OnlineSession.fake_now).
func reset() -> void:
	store.reset()
	_ids_unchecked = false
	fetched.clear()
	fetched_at = 0
	simulated.clear()
	latest.clear()
	active.clear()
	gated = false
	ignored.clear()
	status = BoardBackend.Status.UNAVAILABLE
	in_run = false
	OnlineSession.fake_now = -1
	game_version = ""
	_read_this_session = false
	_unknown.clear()


## Now, in Unix seconds (OnlineSession.now(): the tests' clock if set).
func now() -> int:
	return OnlineSession.now()


## The config may be read: a server, and the player turned an online feature on (before that
## choice the game makes no call at all: OnlineSession.online_chosen()).
func may_fetch() -> bool:
	return OnlineSession.online_chosen()


# --- Safe points ----------------------------------------------------------------------------

## The title screen shows: no run any more; what was read applies, and the config is read again
## if it is old.
func at_title() -> void:
	in_run = false
	apply()
	fetch()


## A run starts (or is resumed): what was read applies, then waits until the title again.
func begin_run() -> void:
	apply()
	in_run = true


## Takes the last read as the game's values (a safe point). Ids read from the file at start-up
## are checked against the content now (_check_ids()).
func apply() -> void:
	_check_ids()
	active = latest.duplicate()
	applied.emit()


# --- What the game asks -------------------------------------------------------------------

## The run's remote changes, fixed at its start: the difficulty `difficulty_id`'s multipliers,
## the souls (with a running event's bonus) and a running event's floor event boost.
##
## A Dawn Knell (`daily_day` >= 0; -1: not a daily run) gets its day's omen and nothing else: it is
## one race for everyone that UTC day, compared on one board, so a value that changes during the
## day (a hotfix, an event starting at 18:00 somewhere) must not make two players' runs differ.
## The omen is keyed by the UTC day itself (omen_for()), the same for all.
func tuning(difficulty_id: StringName, daily_day: int = -1) -> RemoteTuning:
	var result := RemoteTuning.new()
	if daily_day >= 0:
		result.omen = omen_for(daily_day)
		return result
	result.enemy_health = _number(RemoteKeyDef.Hook.ENEMY_HEALTH, difficulty_id)
	result.enemy_damage = _number(RemoteKeyDef.Hook.ENEMY_DAMAGE, difficulty_id)
	result.souls = _number(RemoteKeyDef.Hook.SOULS)
	var event := event_info()
	if not event.is_empty():
		result.souls *= float(event.souls)
		result.event_name = str(event.name)
		if event.floor_event != &"" and float(event.weight) > 1.0:
			result.event_boost[String(event.floor_event)] = float(event.weight)
	return result


## The curse or floor event id the config puts on the Dawn Knell of day `day` (a UTC day number,
## DailyRun.today()) (&"": none; only the UTC day its date names, whatever the device's time zone:
## parse_date() reads dates as UTC).
func omen_for(day: int) -> StringName:
	var id: Variant = _value(RemoteKeyDef.Hook.DAILY_OMEN)
	var date: Variant = _value(RemoteKeyDef.Hook.DAILY_OMEN_DATE)
	if id == null or not date is Dictionary or floori(float((date as Dictionary).at) / DAY) != day:
		return &""
	return id as StringName


## The limited-time event running now: {name (in the game's language), ends (Unix seconds),
## souls, floor_event (&"" none), weight}; empty when none (no name, no end, or over).
func event_info() -> Dictionary:
	var event_name := _text(RemoteKeyDef.Hook.EVENT_NAME)
	var ends: Variant = _value(RemoteKeyDef.Hook.EVENT_ENDS)
	if event_name.is_empty() or not ends is Dictionary:
		return {}
	var end_at := int((ends as Dictionary).at) + (DAY if bool((ends as Dictionary).day_only) else 0)
	if now() >= end_at:
		return {}
	var floor_event: Variant = _value(RemoteKeyDef.Hook.EVENT_FLOOR_EVENT)
	return {
		"name": event_name,
		"ends": end_at,
		"souls": _number(RemoteKeyDef.Hook.EVENT_SOULS),
		"floor_event": floor_event as StringName if floor_event != null else &"",
		"weight": _number(RemoteKeyDef.Hook.EVENT_FLOOR_WEIGHT),
	}


## The message of the day in the game's language (English if none in it; "" none).
func message() -> String:
	return _text(RemoteKeyDef.Hook.MESSAGE)


## Kill switches (they apply as soon as read, mid-run too): no score queued or sent / no gameplay
## statistics or world counters queued or sent.
func scores_off() -> bool:
	return _switch(RemoteKeyDef.Hook.SCORES_OFF)


func statistics_off() -> bool:
	return _switch(RemoteKeyDef.Hook.STATISTICS_OFF)


## The active value of `def` as it is shown (the debug panel): the remote one, or "-" (the game's).
func shown_value(def: RemoteKeyDef, values: Dictionary) -> String:
	if not values.has(def.key):
		return "-"
	var value: Variant = values[def.key]
	if value is Dictionary:
		return str(fetched.get(def.key, simulated.get(def.key, "")))
	return str(value)


func _value(hook: RemoteKeyDef.Hook, difficulty_id: StringName = &"") -> Variant:
	_check_ids()
	for def in config.for_hook(hook):
		if (def.difficulty == &"" or def.difficulty == difficulty_id) and active.has(def.key):
			return active[def.key]
	return null


func _number(hook: RemoteKeyDef.Hook, difficulty_id: StringName = &"") -> float:
	for def in config.for_hook(hook):
		if def.difficulty == &"" or def.difficulty == difficulty_id:
			return float(active.get(def.key, def.default_number))
	return 1.0


## A per-language text: the game's language's, else English's.
func _text(hook: RemoteKeyDef.Hook) -> String:
	var language := TranslationServer.get_locale().substr(0, 2)
	var fallback := ""
	for def in config.for_hook(hook):
		var text := str(active.get(def.key, ""))
		if def.language == language and not text.is_empty():
			return text
		if def.language == "en":
			fallback = text
	return fallback


func _switch(hook: RemoteKeyDef.Hook) -> bool:
	if config == null:
		return false  # (never before its data is read; kept safe for any start-up order)
	for def in config.for_hook(hook):
		if bool(latest.get(def.key, false)):
			return true
	return false


# --- Reading and checking -----------------------------------------------------------------

## Reads the config (unless read less than refresh_seconds ago this session; `force`: anyway).
## Offline, refused, no key, no choice: the values kept stay.
func fetch(force: bool = false) -> void:
	if store.is_busy() or not may_fetch():
		return
	if not force and _read_this_session and now() - fetched_at < config.refresh_seconds:
		return
	var token := store.begin_flush()
	@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
	var read := await OnlineSession.backend.fetch_config()
	if not store.end_flush(token):
		return  # (reset meanwhile: the tests' next one)
	status = read.status
	if read.status != BoardBackend.Status.OK or not may_fetch():
		return
	_read_this_session = true
	var was_off := scores_off() or statistics_off()
	fetched.clear()
	_unknown.clear()
	for key: String in read.values:
		if config.find(key):
			fetched[key] = str(read.values[key])
		else:
			_unknown.append(key)
	fetched_at = now()
	save_state()
	check()
	received.emit()
	if not in_run:
		apply()
	if was_off and not scores_off():
		Leaderboards.flush()
	if was_off and not statistics_off():
		Telemetry.flush()
		WorldStats.flush()


## Debug builds: `text` as if the server had it for `key` ("" forgets the simulated value). It
## applies at the next safe point, like a real one.
func simulate(key: String, text: String) -> void:
	if OnlineSession.release_mode:
		return
	if text.is_empty():
		simulated.erase(key)
	else:
		simulated[key] = text
	check()
	received.emit()


func clear_simulations() -> void:
	simulated.clear()
	check()
	received.emit()


## Checks every value read (and simulated, in a debug build) against the allow-list into `latest`.
func check() -> void:
	ignored.clear()
	_ids_unchecked = false
	for key in _unknown:
		ignored.append("%s: not on the allow-list" % key)
	var raw := fetched.duplicate()
	if not simulated.is_empty() and not OnlineSession.release_mode:
		raw.merge(simulated, true)
	var values := {}
	for key: String in raw:
		var def := config.find(key)
		if def == null:
			ignored.append("%s: not on the allow-list" % key)
			continue
		var text := str(raw[key]).strip_edges()
		if text.is_empty():
			continue  # (set to nothing: the game's own value)
		var value: Variant = parse(def, text)
		if value == null:
			ignored.append("%s: \"%s\" is not a valid %s" % [key, text.left(60), _kind_name(def)])
			continue
		values[key] = value
	gated = not version_allowed(values)
	if gated:
		ignored.append("everything: the config is for game versions %s to %s, this is %s" % [
			str(raw.get("min_version", "-")), str(raw.get("max_version", "-")), _game_version()])
	latest = {} if gated else values
	if not _defer_ids:
		_print_ignored()


## Debug builds: what the last check ignored, printed (not the tests: `quiet`).
func _print_ignored() -> void:
	if not OnlineSession.release_mode and not quiet:
		for line in ignored:
			print("RemoteConfig: ignored %s" % line)


## `text` as `def`'s kind wants it, or null (wrong form, out of bounds, unknown id).
func parse(def: RemoteKeyDef, text: String) -> Variant:
	match def.kind:
		RemoteKeyDef.Kind.NUMBER:
			if not text.is_valid_float():
				return null
			var number := text.to_float()
			if number < def.min_number - 0.0001 or number > def.max_number + 0.0001:
				return null
			return number
		RemoteKeyDef.Kind.FLAG:
			var word := text.to_lower()
			if word in ["true", "1", "on", "yes"]:
				return true
			if word in ["false", "0", "off", "no"]:
				return false
			return null
		RemoteKeyDef.Kind.TEXT:
			if text.length() > def.max_length:
				return null
			var clean := ""
			for i in text.length():
				clean += " " if text.unicode_at(i) < 32 else text[i]
			return clean
		RemoteKeyDef.Kind.CONTENT_ID:
			var id := StringName(text.to_lower())
			if _defer_ids and _content == null:
				# (start-up: its form only; the content checks it at the first safe point)
				if RegEx.create_from_string("^[a-z0-9_]+$").search(String(id)):
					_ids_unchecked = true
					return id
				return null
			if _content_ids(def.pool).has(id):
				return id
		RemoteKeyDef.Kind.DATE:
			return parse_date(text)
		RemoteKeyDef.Kind.VERSION:
			if _version_parts(text).size() > 0:
				return text
	return null


## "2026-10-26" -> {at: that day's 00:00 UTC, day_only: true}; "2026-10-26T18:00:00Z" (or
## "...T18:00", "... 18:00:00") -> {at, day_only: false}; null otherwise.
static func parse_date(text: String) -> Variant:
	var pattern := RegEx.create_from_string("^(\\d{4})-(\\d{2})-(\\d{2})(?:[T ](\\d{2}):(\\d{2})(?::(\\d{2}))?(?:Z|\\+00:00)?)?$")
	var found := pattern.search(text)
	if found == null:
		return null
	var month := found.get_string(2).to_int()
	var day := found.get_string(3).to_int()
	var day_only := found.get_string(4).is_empty()
	var hour := 0 if day_only else found.get_string(4).to_int()
	var minute := 0 if day_only else found.get_string(5).to_int()
	var second := found.get_string(6).to_int() if not found.get_string(6).is_empty() else 0
	var year := found.get_string(1).to_int()
	if month < 1 or month > 12 or day < 1 or day > _days_in(year, month) or hour > 23 or minute > 59 or second > 59:
		return null  # (a day past its month's end, 2026-02-31: Time would print an error)
	var at := Time.get_unix_time_from_datetime_dict({ "year": year, "month": month, "day": day, "hour": hour, "minute": minute, "second": second })
	return { "at": at, "day_only": day_only }


## How many days month `month` (1-12) of `year` has.
static func _days_in(year: int, month: int) -> int:
	if month == 2:
		return 29 if (year % 4 == 0 and year % 100 != 0) or year % 400 == 0 else 28
	return 30 if month in [4, 6, 9, 11] else 31


## The game's version is inside the config's min_version / max_version (each optional).
func version_allowed(values: Dictionary) -> bool:
	var mine := _game_version()
	for def in config.for_hook(RemoteKeyDef.Hook.MIN_VERSION):
		if values.has(def.key) and compare_versions(mine, str(values[def.key])) < 0:
			return false
	for def in config.for_hook(RemoteKeyDef.Hook.MAX_VERSION):
		if values.has(def.key) and compare_versions(mine, str(values[def.key])) > 0:
			return false
	return true


## -1, 0, 1: version `a` before, equal to, after `b` ("0.10.0" after "0.9.2"; missing parts are 0).
static func compare_versions(a: String, b: String) -> int:
	var left := _version_parts(a)
	var right := _version_parts(b)
	for i in maxi(left.size(), right.size()):
		var x := left[i] if i < left.size() else 0
		var y := right[i] if i < right.size() else 0
		if x != y:
			return -1 if x < y else 1
	return 0


## "0.3.0" -> [0, 3, 0]; empty when it isn't a version.
static func _version_parts(text: String) -> PackedInt32Array:
	var parts := PackedInt32Array()
	if not RegEx.create_from_string("^\\d+(\\.\\d+){0,3}$").search(text.strip_edges()):
		return parts
	for part in text.strip_edges().split("."):
		parts.append(part.to_int())
	return parts


func _game_version() -> String:
	return game_version if not game_version.is_empty() else str(ProjectSettings.get_setting("application/config/version", "0"))


func _kind_name(def: RemoteKeyDef) -> String:
	match def.kind:
		RemoteKeyDef.Kind.NUMBER:
			return "number from %s to %s" % [def.min_number, def.max_number]
		RemoteKeyDef.Kind.FLAG:
			return "true/false"
		RemoteKeyDef.Kind.TEXT:
			return "text of at most %d characters" % def.max_length
		RemoteKeyDef.Kind.CONTENT_ID:
			return "curse or floor event id" if def.pool == RemoteKeyDef.Pool.CURSES_AND_EVENTS else "floor event id"
		RemoteKeyDef.Kind.DATE:
			return "date (2026-10-26 or 2026-10-26T18:00:00Z)"
	return "version (0.3.0)"


## Ids taken from the file at start-up only for their form: checked against the content now, the
## first time a value is asked for or applied (loading the content then, not while the autoloads
## start). What was in use stays in use, less the ids the game doesn't have.
func _check_ids() -> void:
	if not _ids_unchecked:
		return
	var was_active := active == latest
	check()
	if was_active:
		active = latest.duplicate()


## The ids a CONTENT_ID of `pool` may name (the game's own content).
func _content_ids(pool: RemoteKeyDef.Pool) -> Array[StringName]:
	if _content == null:
		_content = load(CONTENT) as ContentDB
	var ids: Array[StringName] = []
	for event in _content.floor_events:
		if event:
			ids.append(event.id)
	if pool == RemoteKeyDef.Pool.CURSES_AND_EVENTS:
		for curse in _content.curses:
			if curse:
				ids.append(curse.id)
	return ids


## A choice was made (scores published, statistics accepted): the config may be read now.
func reconcile_choices() -> void:
	if may_fetch() and not _read_this_session:
		fetch()


# --- The file ------------------------------------------------------------------------------

func save_state() -> void:
	store.write({ "fetched_at": fetched_at, "values": fetched })


## The last good read back (a restart offline keeps its values), checked again (this version's
## allow-list), and taken as the game's values (the game's start is a safe point).
func load_state() -> void:
	fetched.clear()
	fetched_at = 0
	var data := store.read()
	if data.get("values") is Dictionary:
		fetched_at = int(data.get("fetched_at", 0))
		var values: Dictionary = data.values
		for key: Variant in values:
			if config.find(str(key)) and values[key] is String:
				fetched[str(key)] = values[key]
	check()
	active = latest.duplicate()
