extends Node
## What every online service shares (autoload "OnlineSession", the first of them; docs/online.md
## "The shared session"): the backend (Talo, or the offline one without an access key), the
## device's player on it (its random id, made the first time a feature is turned on, and the
## identify call, **one at a time for every service**), the consent gates, the clock and whether
## this is a release build. Leaderboards, Telemetry, WorldStats, Feedback and RemoteConfig talk to
## the server only through it; Privacy and RemoteConfig's kill switches feed its gates.
##
## Start-up order: every online service reads its data and its file in its own `_init()` and calls
## no other service there (Godot makes every autoload before any `_ready()`), so from the first
## `_ready()` on any service may ask any other, whatever their order in project.godot. What needs
## another service at start-up (WorldStats dropping a queue the consent no longer allows) is done
## in `settle()`, from `_ready()`. The tests check every order (OnlineSessionTests).
##
## Its own file, user://online.json: the device's id and its Talo player (until version 0.3 they
## were in user://leaderboards.json: taken from there once).

const PATH := "user://online.json"
## Where the device's id was kept before this file (Leaderboards' file, version 2).
const LEGACY_PATH := "user://leaderboards.json"
const DEFS := "res://data/online/online_session.tres"
const VERSION := 1

## Answered when an identify in flight ends (every caller waiting on it gets the same answer).
signal _identity_answered(status: BoardBackend.Status)
## The player identified is forgotten (another backend, the online data deleted, the tests):
## what holds a connection for them (Presence) closes it.
signal identity_forgotten

var config: OnlineSessionDef
var backend: BoardBackend
## Made on the device the first time it is needed (a feature turned on), random, never derived
## from the device: the player on the server. Shown in Options > Privacy (for a deletion request).
var device_id := ""
## The server's id for that player once identified ("" before): goes in a deletion request.
var player_id := ""
## A release build: what a debug build never does (WorldStats sends, RemoteConfig ignores the
## debug panel's values, Talo's data isn't dev data) happens. The tests set it to run those paths.
var release_mode := not OS.is_debug_build()
## A fixed clock for the tests (Unix seconds; -1: the real one), for every online service.
var fake_now := -1
## Where an older game kept the device's id ("" none: the tests).
var legacy_path := LEGACY_PATH
## The services that registered (their _ready()): the tests reset and start them all.
var services: Array[Node] = []
## The id this device will take when a feature is turned on, drawn early so the pseudonym's
## question can show the player's tag before the choice (Leaderboards.tag()): in memory only,
## never written nor sent until device() adopts it (the rule "no id before the choice" is about
## what is kept and sent). Forgotten with the player.
var _pending_id := ""

## Its file (versioned, atomic).
var store: PersistedQueue
## The file's path ("" none: tests).
var path: String:
	get:
		return store.path
	set(value):
		store.path = value
var _identified := false
var _identifying := false
## Bumped when the backend or the player changes: an identify answered after it is not kept.
var _generation := 0
## A refused identify is answered again without a call until then (Time.get_ticks_msec()).
var _refused_until := 0
## use_all_for_tests() is resetting the services (their own calls to use_for_tests() wait).
var _all_for_tests := false


func _init() -> void:
	store = PersistedQueue.new(PATH, VERSION)
	add_child(store)
	if store.path.is_empty():
		legacy_path = ""
	boot()
	use_backend(default_backend())


## Its data and file, read (no other service is asked: start-up order).
func boot() -> void:
	config = load(DEFS) as OnlineSessionDef
	load_state()


## The backend this build has: Talo with an access key (TaloBackend.read_key()), else offline.
func default_backend() -> BoardBackend:
	if str(TaloBackend.read_key().key).is_empty():
		return BoardBackend.new()
	var talo := TaloBackend.new()
	talo.dev_build = not release_mode
	return talo


## Talks to `new_backend` from now on (the tests' fake or offline one). The player is identified
## again on it.
func use_backend(new_backend: BoardBackend) -> void:
	if backend == new_backend and backend != null:
		_forget_identity()  # (the same server: only the player is identified again)
		return
	if backend and is_instance_valid(backend):
		remove_child(backend)
		backend.queue_free()
	backend = new_backend
	_forget_identity()
	if backend:
		add_child(backend)


## A service tells it exists (from its _ready()).
func register(service: Node) -> void:
	if not services.has(service):
		services.append(service)


## The tests: no file, an offline backend (or `fake`), no device id, a debug build's rules.
func use_for_tests(fake: BoardBackend = null) -> void:
	if _all_for_tests:
		return
	store.path = ""
	legacy_path = ""
	release_mode = false
	use_backend(fake if fake else BoardBackend.new())
	reset()


## The tests' whole online layer back to nothing: this, its clock, and every service's
## use_for_tests() (the runner's start, a test that changed many).
func use_all_for_tests(fake: BoardBackend = null) -> void:
	_all_for_tests = true  # (Leaderboards.use_for_tests() would put the session on another backend)
	for service in services:
		if service != self and service.has_method("use_for_tests"):
			service.call("use_for_tests")
	_all_for_tests = false
	fake_now = -1
	use_for_tests(fake)


## The player forgotten (not the file: save_state() does).
func reset() -> void:
	device_id = ""
	player_id = ""
	_pending_id = ""
	_forget_identity()
	store.reset()


# --- The clock and the build ---------------------------------------------------------------

## Now, in Unix seconds (the tests' clock if set).
func now() -> int:
	return fake_now if fake_now >= 0 else int(Time.get_unix_time_from_system())


## Now in Unix milliseconds (Talo's events' timestamp; the tests' clock if set).
func now_ms() -> int:
	return fake_now * 1000 if fake_now >= 0 else int(Time.get_unix_time_from_system() * 1000.0)


# --- The gates (every consent rule in one place; docs/privacy-ops.md) ------------------------

## There is a server (an access key in this build).
func is_available() -> bool:
	return backend != null and backend.is_configured()


## The player chose to publish their scores, and there is a server (the boards may be read).
func scores_published() -> bool:
	return is_available() and Leaderboards.shown


## Scores may be queued and sent: published, and not stopped by the remote kill switch.
func scores_allowed() -> bool:
	return scores_published() and not RemoteConfig.scores_off()


## The gameplay statistics (and the world counters' shares) may be collected and sent: accepted
## (Privacy.analytics_allowed()), a server, not stopped by the remote kill switch, and a release
## build unless `debug_builds` (Telemetry's events are dev data in a debug build; WorldStats'
## counters would count in the world's numbers).
func statistics_allowed(debug_builds: bool = true) -> bool:
	return Privacy.analytics_allowed() and is_available() and (debug_builds or release_mode) and not RemoteConfig.statistics_off()


## An online feature is on (the scores published, or the statistics accepted): what reads the
## server without the player's data (the world counters, the remote settings) may. Before that
## choice the game makes no call at all.
func online_chosen() -> bool:
	return is_available() and (Leaderboards.shown or Privacy.analytics_allowed())


# --- The player ------------------------------------------------------------------------

## The device's id, made the first time (and kept in the file): the one preview_device() showed,
## if it drew one.
func device() -> String:
	if device_id.is_empty():
		device_id = preview_device()
		_pending_id = ""
		save_state()
	return device_id


## The device's id, or the one it will take (drawn now, kept in memory only: nothing is written
## nor sent). The player's tag before the choice comes from it, and stays the same after.
func preview_device() -> String:
	if not device_id.is_empty():
		return device_id
	if _pending_id.is_empty():
		_pending_id = Crypto.new().generate_random_bytes(16).hex_encode()
	return _pending_id


## The device's player on the server, made the first time. One identify at a time: a caller
## asking while one is on its way waits for that one's answer. A refused one is answered again
## without a call for config.refused_identity_seconds. Only called once the player turned a
## feature on (or sends a message).
func identity() -> BoardBackend.Status:
	if _identified:
		return BoardBackend.Status.OK
	if backend == null:
		return BoardBackend.Status.UNAVAILABLE
	if _identifying:
		var waited: BoardBackend.Status = await _identity_answered
		return waited
	if Time.get_ticks_msec() < _refused_until:
		return BoardBackend.Status.REJECTED
	_identifying = true
	var generation := _generation
	@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
	var status: BoardBackend.Status = await backend.identify(device())
	if generation != _generation:
		return status  # (the backend or the player changed meanwhile: _forget_identity() answered the waiting)
	_identifying = false
	_identified = status == BoardBackend.Status.OK
	if status == BoardBackend.Status.REJECTED and config:
		_refused_until = Time.get_ticks_msec() + int(config.refused_identity_seconds * 1000.0)
	if _identified and backend.player_id() != player_id:
		player_id = backend.player_id()
		save_state()
	_identity_answered.emit(status)
	return status


## Identified on this backend now.
func is_identified() -> bool:
	return _identified


## "Delete my online data" (Privacy.forget_online()): the device's id and its server player
## forgotten. A new random id is made if the player turns a feature on again, so this device is no
## longer linked to the old record.
func forget() -> void:
	device_id = ""
	player_id = ""
	_pending_id = ""
	_forget_identity()
	if backend:
		backend.forget()
	save_state()


func _forget_identity() -> void:
	identity_forgotten.emit()
	_identified = false
	_refused_until = 0
	_generation += 1
	if _identifying:
		_identifying = false
		_identity_answered.emit(BoardBackend.Status.OFFLINE)


## Backoff for a service's retry: its retry_seconds, doubled per failure, up to this many times.
func max_backoff() -> float:
	return config.max_backoff if config else 1.0


# --- The file ------------------------------------------------------------------

func save_state() -> void:
	store.write({ "device_id": device_id, "player_id": player_id })


## Reads the file; without one, the device's id kept by an older game in Leaderboards' file is
## taken (and written here).
func load_state() -> void:
	device_id = ""
	player_id = ""
	_pending_id = ""
	var data := store.read()
	if data.is_empty() and not legacy_path.is_empty():
		var old: Variant = SafeFile.read_json(legacy_path)
		if old is Dictionary and not str((old as Dictionary).get("device_id", "")).is_empty():
			device_id = str((old as Dictionary).get("device_id", ""))
			player_id = str((old as Dictionary).get("player_id", ""))
			save_state()
		return
	device_id = str(data.get("device_id", ""))
	player_id = str(data.get("player_id", ""))
