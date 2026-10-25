class_name PersistedQueue
extends Node
## What the online services (Leaderboards, Telemetry, WorldStats, Feedback, RemoteConfig, Privacy,
## OnlineSession) have in common with their file and their sending, written once (docs/online.md
## "The shared session"). Each service keeps one as a child:
## - **Its file**, versioned and written atomically (SafeFile): write() adds the version and skips a
##   write that would change nothing (an alt-tab writes no file); read() returns {} for a missing,
##   damaged or *newer* file (a downgraded game trusts nothing it doesn't know: every choice off,
##   asked again) and hands an older one to the service's migration.
## - **A bounded list** (`items`, `max_items`: the oldest dropped), for the services that queue
##   whole messages (scores, events, feedback).
## - **One flush at a time**: begin_flush() gives a token, or -1 while another flush runs;
##   reset() makes every token stale, so a flush started before a test's reset never writes over
##   the next test (still()).
## - **The retry timer, with backoff**: retry_later() waits the service's retry_seconds, twice
##   that after another failure, up to OnlineSessionDef.max_backoff times; succeeded() starts again.
##   `retry_due` is emitted when it is time.
##
## In a test launch (the test runner's scene on the command line) the file's path starts empty, so
## the player's real files are never read nor written while the autoloads start; tests point it at
## a temporary file of their own.

## Time to try again (the retry timer, or the start delay).
signal retry_due

## Empty = nothing is read or written (tests).
var path := ""
## The file's format; read() refuses newer ones and migrates older ones.
var version := 1
## The queued messages, oldest first (unused by the services that keep their own shape).
var items: Array[Dictionary] = []
## The most `items` holds (0: no limit); past it the oldest are dropped.
var max_items := 0
## Failed tries in a row (the backoff's step).
var failures := 0

var _timer: Timer
var _busy := false
var _generation := 0
var _last_written := ""


func _init(file_path: String = "", file_version: int = 1) -> void:
	name = "Store"
	path = "" if is_test_launch() else file_path
	version = file_version
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(func() -> void: retry_due.emit())
	add_child(_timer)


## This launch is the test runner's (its scene named on the command line): no real file.
static func is_test_launch() -> bool:
	for arg in OS.get_cmdline_args():
		if arg.ends_with("tests/run_tests.tscn"):
			return true
	return false


# --- The list --------------------------------------------------------------------------

## Adds `item` at the end, dropping the oldest past max_items.
func push(item: Dictionary) -> void:
	items.append(item)
	while max_items > 0 and items.size() > max_items:
		items.pop_front()


# --- The file --------------------------------------------------------------------------

## Writes `data` (plus "version") to the file, unless it holds exactly that already.
func write(data: Dictionary) -> bool:
	if path.is_empty():
		return false
	var content := data.duplicate()
	content["version"] = version
	var text := path + "\n" + JSON.stringify(content)
	if text == _last_written and FileAccess.file_exists(path):
		return true
	if not SafeFile.write_json(path, content):
		return false
	_last_written = text
	return true


## The file's content ({} if missing, damaged or newer than `version`). An older one goes through
## `migrate` (data, its version) -> data first, when given.
func read(migrate: Callable = Callable()) -> Dictionary:
	_last_written = ""
	if path.is_empty():
		return {}
	var data: Variant = SafeFile.read_json(path)
	if not data is Dictionary:
		return {}
	var found := int((data as Dictionary).get("version", 1))
	if found > version:
		if not is_test_launch():  # (the tests make such files on purpose)
			push_warning("%s is from a newer version of the game (%d > %d): not read" % [path, found, version])
		return {}
	var result: Dictionary = data
	if found < version and migrate.is_valid():
		result = migrate.call(result, found)
	return result


# --- One flush at a time ---------------------------------------------------------------

## A token for the flush that starts now, or -1 if one is running already.
func begin_flush() -> int:
	if _busy:
		return -1
	_busy = true
	return _generation


## The flush `token` is over (nothing if a reset made it stale). True if it was still current.
func end_flush(token: int) -> bool:
	if token != _generation:
		return false
	_busy = false
	return true


## The flush `token` may go on (no reset since it began).
func still(token: int) -> bool:
	return token == _generation


## Snapshot for an operation that does not claim the sending lock (e.g. a board read).
func generation() -> int:
	return _generation


func is_busy() -> bool:
	return _busy


# --- Trying again ----------------------------------------------------------------------

## Another try in `seconds` (the start delay; no backoff step).
func start_in(seconds: float) -> void:
	_timer.start(maxf(seconds, 0.05))


## It failed: another try after `base_seconds`, doubled for each failure in a row, at most
## `max_factor` times `base_seconds`.
func retry_later(base_seconds: float, max_factor: float = 1.0) -> void:
	failures += 1
	var factor := minf(pow(2.0, failures - 1), maxf(max_factor, 1.0))
	_timer.start(maxf(base_seconds * factor, 0.05))


## It worked: the next failure waits base_seconds again.
func succeeded() -> void:
	failures = 0


## A try is planned.
func is_retrying() -> bool:
	return not _timer.is_stopped()


## Seconds before the planned try (0: none).
func retry_left() -> float:
	return 0.0 if _timer.is_stopped() else _timer.time_left


func stop_retry() -> void:
	_timer.stop()


## Everything forgotten but the path: the list, the timer, the backoff, the running flush (stale).
func reset() -> void:
	items.clear()
	_timer.stop()
	failures = 0
	_busy = false
	_generation += 1
	_last_written = ""
