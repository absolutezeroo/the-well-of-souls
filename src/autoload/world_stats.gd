extends OnlineService
## The world counters, "The Well's Toll" (autoload "WorldStats"; docs/online.md "World
## counters"): numbers every player adds to, kept by Talo as global game stats (the demons slain in
## the Well by everyone, the bells rung, the souls offered to the Tree...), and each player's own
## share. The counters are data (data/online/world_stats.tres, WorldStatsDef, WorldStatDef).
##
## Counting: it listens to the Events bus during a run (kills, bosses, floors, potions, a death, a
## new Dawn Knell) and at the shrine (souls offered); a run's counts wait in `pending` and join the
## queue when the run ends (Events.run_ended, then Events.ending_chosen for the ending), capped to
## each counter's max change.
##
## A run left without ending (Events.run_left, as the gameplay statistics: quit to the title, the
## app closed) sends what it counted so far too. It may be resumed: each run has a key, and its
## counts so far go into its save (Events.run_saving: RunState.world_stats); what of it was queued
## is kept per key in the file (`sent`). A resumed run takes its counts back from the save and
## only queues what goes past what was sent (a save older than what was sent counts nothing twice);
## counts the save had but that never went (the app killed) go at its end. The app put in the
## background (maybe killed there) leaves the unsent part as a draft in the file: dropped when the
## app comes back, queued at the next launch otherwise. The queue is sent with **one update per counter** (Talo's PUT, its
## maxChange and rate limits respected: never one call per kill), through the OnlineSession's server
## and player (same device id as the leaderboards). Without network it waits in its own file,
## user://world_stats.json, and is tried again every retry_seconds, at the next run's end and when
## the app comes back.
##
## Consent: the counts are tied to the player on Talo (its own totals, and a snapshot of each
## update), so they are part of the **gameplay statistics**: only with Privacy.analytics_allowed()
## (16 or older, accepted, for the current consent version); refusing or withdrawing drops what
## waited. Never from a debug run, nor from a debug build (Talo adds a dev build's updates to the
## world's numbers: its PUT ignores X-Talo-Dev-Build), nor in the tests (no file, no consent).
##
## Reading: the world's numbers are read (one GET for all) at most every refresh_seconds, only once
## the player turned an online feature on (published their scores, or accepted the statistics):
## before that choice the game makes no call at all. The player's own share is read only with the
## statistics' consent. Offline, without a key or a choice: nothing is shown (title_lines() is empty,
## the page says why), and nothing fails.

## The world's numbers, the player's share or what waits changed (the screens follow).
signal changed

const PATH := "user://world_stats.json"
const DEFS := "res://data/online/world_stats.tres"
const VERSION := 1
## How many runs' sent shares the file remembers (a run left then resumed; older keys are dropped).
const KEPT_RUNS := 8

var config: WorldStatsDef
## Its file, the flush latch and the retry timer (the queue is a dictionary of its own).
var store := PersistedQueue.new(PATH, VERSION)
## The file's path. Empty = nothing is read or written (tests).
var path: String:
	get:
		return store.path
	set(value):
		store.path = value
## The run going on (or a run left unfinished): counted, not queued yet. Internal name -> amount.
var pending := {}
## Waiting to be sent: internal name -> amount (runs played offline add up).
var queue := {}
## The key of the run being played ("" between runs), and all it counted (its save keeps them).
var run_key := ""
var run_counts := {}
## What of each recent run was queued: run key -> {internal name -> amount}. Saved in the file.
var sent := {}
## The app is in the background mid-run: what would go if it never came back {run, counts,
## run_counts} (queued at the next launch; dropped when the app comes back). Empty otherwise.
var draft := {}
## The world's numbers last read (internal name -> value), in memory only: hidden until read.
var world := {}
## The player's own lifetime share (the server's when read, plus what was sent since).
var mine := {}
## When the world's numbers were read (Unix seconds; 0: not yet), and how the last read went.
var read_at := 0
var read_status: BoardBackend.Status = BoardBackend.Status.UNAVAILABLE
## A debug build sends nothing (its updates would count in the world's numbers on Talo). The
## tests turn it on, on a fake server (or run the release path: OnlineSession.release_mode).
var debug_builds_send := false

var _player: Player
## The deepest floor of the run reached so far (a floor is counted once, not when a run resumes).
var _depth := 1
## A read of the world's numbers is on its way, and which (reset() makes it stale).
var _reading := false
var _read_generation := 0
## Read from the file, waiting for settle() to know whether the consent still lets it go.
var _left_over := {}


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(store)
	store.retry_due.connect(flush)
	boot()


## Its data and file, read (no other service is asked: OnlineSession, "start-up order"). What
## depends on the consent waits for settle().
func boot() -> void:
	config = load(DEFS) as WorldStatsDef
	_read_file()


func _ready() -> void:
	OnlineSession.register(self)
	settle()
	Events.run_started.connect(_on_run_started)
	Events.run_ended.connect(_on_run_ended)
	Events.run_saving.connect(_on_run_saving)
	Events.run_left.connect(_on_run_left)
	Events.monster_killed.connect(_on_monster_killed)
	Events.boss_defeated.connect(func(_boss: Monster) -> void: count(WorldStatDef.Feed.BOSSES))
	Events.depth_changed.connect(_on_depth_changed)
	Events.ending_chosen.connect(_on_ending_chosen)
	Events.souls_offered.connect(_on_souls_offered)


## The tests: no file, nothing counted or read, debug builds kept silent.
func use_for_tests(_fake: BoardBackend = null) -> void:
	path = ""
	debug_builds_send = false
	reset()


## Everything forgotten (not the file), the flush, the read and the retry stopped.
func reset() -> void:
	store.reset()
	_reading = false
	_read_generation += 1
	_left_over.clear()
	pending.clear()
	queue.clear()
	run_key = ""
	run_counts.clear()
	sent.clear()
	draft.clear()
	world.clear()
	mine.clear()
	read_at = 0
	read_status = BoardBackend.Status.UNAVAILABLE
	_depth = 1
	_bind(null)


## The player's shares may be counted and sent now: the statistics accepted, a server, a release
## build (or the tests'), not stopped by the remote kill switch (OnlineSession.statistics_allowed()).
func may_send() -> bool:
	return OnlineSession.statistics_allowed(debug_builds_send)


## The world's numbers may be read: a server, and the player turned an online feature on.
func may_read() -> bool:
	return OnlineSession.online_chosen()


## The world's number for `def` (-1: not known: not read, offline, or not allowed).
func world_value(def: WorldStatDef) -> float:
	if not may_read() or not world.has(def.internal_name):
		return -1.0
	return float(world[def.internal_name])


## The player's own share of `def`, sent or waiting (-1: not counted: no consent).
func my_value(def: WorldStatDef) -> float:
	if not may_send():
		return -1.0
	return float(mine.get(def.internal_name, 0.0)) + float(queue.get(def.internal_name, 0)) + float(pending.get(def.internal_name, 0))


## The title screen's lines, each with its number in the game's language: the counters that have
## one and reached title_min_count. Empty when nothing is known.
func title_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for def in config.enabled_stats():
		var value := world_value(def)
		if def.title_line.is_empty() or value < config.title_min_count:
			continue
		lines.append(tr(def.title_line).format({ "count": NumberText.of(int(value)) }))
	return lines


# --- Counting -------------------------------------------------------------------------

## Adds `amount` to the counters fed by `feed` (an ENDING feed: only the one for `ending`), for the
## run going on. Nothing without consent, nor in a debug run.
func count(feed: WorldStatDef.Feed, amount: int = 1, ending: StringName = &"") -> void:
	if amount <= 0 or not may_send() or DebugCheats.debug_run:
		return
	for def in config.enabled_stats():
		if def.feed == feed and (feed != WorldStatDef.Feed.ENDING or def.ending == ending):
			_add(def.internal_name, amount)


## Counts `amount` for `internal_name`. In a run: into its counts, and into `pending` only what
## goes past what the run already sent (a resumed run replaying a part already sent).
func _add(internal_name: String, amount: int) -> void:
	if run_key.is_empty():
		pending[internal_name] = int(pending.get(internal_name, 0)) + amount
		return
	var before := _unsent(internal_name)
	run_counts[internal_name] = int(run_counts.get(internal_name, 0)) + amount
	var more := _unsent(internal_name) - before
	if more > 0:
		pending[internal_name] = int(pending.get(internal_name, 0)) + more


## What the run counted for `internal_name` past what it sent.
func _unsent(internal_name: String) -> int:
	var done: Dictionary = sent.get(run_key, {})
	return maxi(0, int(run_counts.get(internal_name, 0)) - int(done.get(internal_name, 0)))


## The run's counts join the queue (each capped to its counter's max change: no real run adds
## more), then go.
func commit() -> void:
	for internal_name: String in pending.keys():
		var def := config.stat(internal_name)
		var amount := int(pending[internal_name])
		if def == null or not def.enabled or amount <= 0:
			continue
		queue[internal_name] = int(queue.get(internal_name, 0)) + mini(amount, def.max_change)
	pending.clear()
	if not run_key.is_empty():
		_mark_sent(run_key, run_counts)
	save_state()
	changed.emit()
	flush()


## `counts` (a run's whole counts) are queued for run `key`: what was sent is at least that.
func _mark_sent(key: String, counts: Dictionary) -> void:
	var done: Dictionary = sent.get(key, {})
	sent.erase(key)  # (back at the end: the most recent run is kept longest)
	for internal_name: String in counts:
		done[internal_name] = maxi(int(done.get(internal_name, 0)), int(counts[internal_name]))
	sent[key] = done
	while sent.size() > KEPT_RUNS:
		sent.erase(sent.keys()[0])


func _on_run_started(run: RunState, player: Player) -> void:
	_bind(player)
	_depth = run.depth
	draft.clear()
	run_counts.clear()
	run_key = ""
	var saved_key: Variant = run.world_stats.get("run")
	var saved_counts: Variant = run.world_stats.get("counts")
	if run.time > 0.0 and saved_key is String and not (saved_key as String).is_empty() and saved_counts is Dictionary:
		# A run picked up again: its counts so far; what of them never went (the app killed
		# before it could tell them) is still to send.
		run_key = saved_key
		_read_amounts(saved_counts, run_counts)
		if may_send() and not DebugCheats.debug_run:
			for internal_name: String in run_counts:
				if _unsent(internal_name) > 0:
					pending[internal_name] = int(pending.get(internal_name, 0)) + _unsent(internal_name)
	else:
		run_key = Crypto.new().generate_random_bytes(6).hex_encode()
	if run.is_daily() and run.time <= 0.0:
		count(WorldStatDef.Feed.DAILY_RUNS)  # (a new Dawn Knell, not one resumed)


## The run is being saved: its counts so far go with it.
func _on_run_saving(run: RunState) -> void:
	if not run_key.is_empty():
		run.world_stats = { "run": run_key, "counts": run_counts.duplicate() }


## The player left the run without it ending (Events.run_left). For good (the title, the app
## closed): what it counted so far goes now, and the run is no longer followed (resumed, it is
## followed again from its save). Put in the background: the same share as a draft only (the
## app may come back to the run).
func _on_run_left(summary: RunSummary, for_good: bool) -> void:
	draft.clear()
	if summary.debug or DebugCheats.debug_run:
		pending.clear()  # (a debug run's counts never go anywhere)
		save_state()
		return
	if for_good:
		commit()
		_unbind_run()
		return
	if not pending.is_empty() and may_send():
		draft = { "run": run_key, "counts": pending.duplicate(), "run_counts": run_counts.duplicate() }
	save_state()


## No run followed any more: later counts (the shrine) are nobody's run.
func _unbind_run() -> void:
	run_key = ""
	run_counts.clear()
	_bind(null)


## The app came back to the run: the draft is not needed.
func _drop_draft() -> void:
	if draft.is_empty():
		return
	draft.clear()
	save_state()


func _bind(player: Player) -> void:
	if _player and is_instance_valid(_player) and _player.consumable_used.is_connected(_on_consumable_used):
		_player.consumable_used.disconnect(_on_consumable_used)
	_player = player
	if player:
		player.consumable_used.connect(_on_consumable_used)


func _on_monster_killed(monster: Monster) -> void:
	if not monster.summoned:  # (called in by another: not a kill, as RunRecords counts them)
		count(WorldStatDef.Feed.KILLS)


func _on_depth_changed(depth: int) -> void:
	if depth > _depth:
		count(WorldStatDef.Feed.FLOORS, depth - _depth)
	_depth = maxi(_depth, depth)


func _on_consumable_used(item: ItemDef) -> void:
	if item is ConsumableDef and PlayerPack.heals(item as ConsumableDef):
		count(WorldStatDef.Feed.POTIONS)


func _on_run_ended(summary: RunSummary) -> void:
	if summary.debug or DebugCheats.debug_run:
		pending.clear()  # (a debug run's counts never go anywhere)
		save_state()
		return
	var dead := _player != null and is_instance_valid(_player) and _player.is_dead
	if dead:
		count(WorldStatDef.Feed.DEATHS)
	commit()
	if dead:
		_unbind_run()  # (a won run goes on: the endless floors, then the ending)


func _on_ending_chosen(ending: EndingDef) -> void:
	count(WorldStatDef.Feed.ENDING, 1, ending.id)
	commit()


func _on_souls_offered(amount: int) -> void:
	count(WorldStatDef.Feed.SOULS_OFFERED, amount)
	if not pending.is_empty():
		commit()


## Consent withdrawn (or the scores unpublished): nothing waits any more, nothing is shown.
func reconcile_choices() -> void:
	if not may_send() and (not pending.is_empty() or not queue.is_empty() or not draft.is_empty()):
		pending.clear()
		queue.clear()
		draft.clear()
		save_state()
	if not may_read() and not world.is_empty():
		world.clear()
		read_at = 0
		read_status = BoardBackend.Status.UNAVAILABLE
	changed.emit()


## "Delete my online data": every count, share and number forgotten.
func forget() -> void:
	reset()
	save_state()
	changed.emit()


# --- The server -------------------------------------------------------------------------

## Sends what waits: one update per counter (a share past its max change goes in parts). Without
## network (or with a refused identity), tries again in retry_seconds, backing off; a counter the
## server refuses is dropped (not resent).
func flush() -> void:
	if store.is_busy() or queue.is_empty() or not may_send():
		return
	var token := store.begin_flush()
	var status := await OnlineSession.identity()
	if not store.still(token):
		return  # (reset meanwhile: the tests' next one)
	for internal_name: String in queue.keys():
		if status != BoardBackend.Status.OK or not may_send():
			break
		var def := config.stat(internal_name)
		if def == null or not def.enabled:
			queue.erase(internal_name)
			continue
		while int(queue.get(internal_name, 0)) > 0 and may_send():
			var part := mini(int(queue[internal_name]), def.max_change)
			@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
			status = await OnlineSession.backend.add_to_stat(internal_name, part)
			if not store.still(token):
				return
			if status == BoardBackend.Status.OFFLINE or status == BoardBackend.Status.UNAVAILABLE or not queue.has(internal_name):
				break
			if status == BoardBackend.Status.REJECTED:
				queue.erase(internal_name)  # refused for good (no such counter, a change it won't take)
				status = BoardBackend.Status.OK
				break
			queue[internal_name] = int(queue[internal_name]) - part
			mine[internal_name] = float(mine.get(internal_name, 0.0)) + part
			if world.has(internal_name):
				world[internal_name] = float(world[internal_name]) + part
		if int(queue.get(internal_name, 0)) <= 0:
			queue.erase(internal_name)
	save_state()
	store.end_flush(token)
	changed.emit()
	if status != BoardBackend.Status.OK and not queue.is_empty():
		store.retry_later(config.retry_seconds, OnlineSession.max_backoff())
	elif status == BoardBackend.Status.OK:
		store.succeeded()


## Reads the world's numbers (and the player's own share, with consent), unless they were read less
## than refresh_seconds ago (`force`: read anyway, the page's Try again). What waits is sent first.
func refresh(force: bool = false) -> void:
	if _reading or not may_read():
		return
	var now := OnlineSession.now()
	if not force and read_at > 0 and now - read_at < config.refresh_seconds:
		return
	_reading = true
	var generation := _read_generation
	await flush()
	if generation != _read_generation:
		return
	if not may_read():
		_reading = false
		return
	@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
	var read := await OnlineSession.backend.fetch_world_stats()
	if generation != _read_generation:
		return  # (reset meanwhile)
	if not may_read():
		_reading = false
		return
	read_status = read.status
	if read.status == BoardBackend.Status.OK:
		world.clear()
		for def in config.enabled_stats():
			if read.values.has(def.internal_name):
				world[def.internal_name] = float(read.values[def.internal_name])
		read_at = now
		if may_send() and await OnlineSession.identity() == BoardBackend.Status.OK and may_send() and generation == _read_generation:
			@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
			var own := await OnlineSession.backend.fetch_my_stats()
			if generation != _read_generation:
				return
			if own.status == BoardBackend.Status.OK:
				for internal_name: String in own.values:
					# (the server's answer may be a little older than what was just sent)
					mine[internal_name] = maxf(float(own.values[internal_name]), float(mine.get(internal_name, 0.0)))
				save_state()
	_reading = false
	changed.emit()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			save_state()  # (the queue, and a run's draft if the app is killed in the background)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_drop_draft()
			if not queue.is_empty() and not store.is_retrying():
				flush()


# --- The file ------------------------------------------------------------------

## Writes the file (only if it changed: an alt-tab writes nothing new).
func save_state() -> void:
	store.write({ "queue": queue, "mine": mine, "sent": sent, "draft": draft })


## Reads the file, then settles it with the consent (settle()).
func load_state() -> void:
	_read_file()
	settle()


## Reads the file. A draft left there (the app killed in the background mid-run) counts as sent for
## its run and waits in `_left_over` with an older file's `pending` (a run left unfinished) for
## settle(). Asks no other service (start-up order).
func _read_file() -> void:
	reset()
	var saved := store.read()
	if saved.is_empty():
		return
	_read_amounts(saved.get("queue"), queue)
	_read_amounts(saved.get("mine"), mine, true)
	var saved_sent: Variant = saved.get("sent")
	if saved_sent is Dictionary:
		for key: Variant in saved_sent:
			var done := {}
			_read_amounts((saved_sent as Dictionary)[key], done)
			sent[str(key)] = done
	_read_amounts(saved.get("pending"), _left_over)  # (an older file's)
	var saved_draft: Variant = saved.get("draft")
	if saved_draft is Dictionary and not (saved_draft as Dictionary).is_empty():
		var parts: Dictionary = saved_draft
		_read_amounts(parts.get("counts"), _left_over)
		var counts := {}
		_read_amounts(parts.get("run_counts"), counts)
		var key: Variant = parts.get("run")
		if key is String and not (key as String).is_empty():
			_mark_sent(key, counts)


## What the file left waits for the consent (every service started: OnlineSession, "start-up
## order"): allowed, a killed run's draft joins the queue; withdrawn meanwhile (or switched off
## remotely), nothing goes.
func settle() -> void:
	var left_over := _left_over.duplicate()
	_left_over.clear()
	if not may_send():
		queue.clear()  # (the consent was withdrawn meanwhile: nothing goes)
		return
	for internal_name: String in left_over:
		var def := config.stat(internal_name) if config else null
		if def and def.enabled:
			queue[internal_name] = int(queue.get(internal_name, 0)) + mini(int(left_over[internal_name]), def.max_change)
	if not left_over.is_empty():
		save_state()  # (sent with the next flush: a run's end, the app coming back)


## Copies the positive amounts of `saved` (read from a file) into `into` (floats if `as_float`).
static func _read_amounts(saved: Variant, into: Dictionary, as_float := false) -> void:
	if not saved is Dictionary:
		return
	for internal_name: Variant in saved:
		var value: Variant = (saved as Dictionary)[internal_name]
		if (value is int or value is float) and float(value) > 0.0:
			if as_float:
				into[str(internal_name)] = float(value)
			else:
				into[str(internal_name)] = int(value)
