extends OnlineService
## The gameplay statistics (autoload "Telemetry"; docs/online.md "Gameplay statistics"): with the
## player's consent only (OnlineSession.statistics_allowed(): Privacy.analytics_allowed(), a
## server, the kill switch), the summary of each run that ends and the events of its boss fights,
## perk choices, purchases and pacts go to Talo's events, to balance the game and find its bugs.
## The list of events and of their fields is data (data/online/telemetry.tres, TelemetryDef).
##
## A RunTelemetry follows each run from Events.run_started; its counts are kept in the run's save
## (Events.run_saving: RunState.telemetry) and taken back when the run is resumed, so the run's
## end covers the whole run. At Events.run_ended its events are queued, if the player consented
## and the run is not a debug run, then sent in batches through the OnlineSession (same device id,
## same player as the leaderboards). A run left without ending (Events.run_left: quit
## to the title, the app closed) sends its run_end too, result "abandoned" and quit 1, under the
## same run id as its later end if it is resumed: the dashboard keeps each run id's latest
## run_end. The app put in the background (maybe killed there) leaves that end as a draft in the
## file, dropped when the app comes back, queued at the next launch otherwise.
## The queue waits in its own file, user://telemetry.json, bounded (TelemetryDef.max_queue), while
## there is no network, and goes when the network is back, at a run's end, or when the app goes
## to the background. Refusing or withdrawing drops what waited. The game never depends on it:
## it only listens. The tests give it no file (and the session an offline or fake server).

const PATH := "user://telemetry.json"
const DEFS := "res://data/online/telemetry.tres"
const VERSION := 1

var config: TelemetryDef
## Its file, the events waiting (`queue`), the flush latch and the retry timer.
var store := PersistedQueue.new(PATH, VERSION)
## The file's path. Empty = nothing is read or written (tests).
var path: String:
	get:
		return store.path
	set(value):
		store.path = value
## Events waiting to be sent, oldest first: {name, props, timestamp} (store.items).
var queue: Array[Dictionary]:
	get:
		return store.items
## The run being followed (null between runs).
var tracker: RunTelemetry
## The last run's end event as queued (props after sanitize()), for the tests.
var last_summary := {}
## What would go if the app, put in the background, never came back: the run's events so far and
## its "abandoned" end, sanitized (queued at the next launch; dropped when the app comes back).
var draft: Array[Dictionary] = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(store)
	store.retry_due.connect(flush)
	boot()


## Its data and file, read (no other service is asked: OnlineSession, "start-up order").
func boot() -> void:
	config = load(DEFS) as TelemetryDef
	store.max_items = config.max_queue
	load_state()


func _ready() -> void:
	OnlineSession.register(self)
	Events.run_started.connect(_on_run_started)
	Events.run_ended.connect(record)
	Events.run_saving.connect(_on_run_saving)
	Events.run_left.connect(_on_run_left)


## The tests: no file, nothing waiting, no run followed.
func use_for_tests(_fake: BoardBackend = null) -> void:
	path = ""
	reset()


## Everything forgotten (not the file), the flush and the retry stopped.
func reset() -> void:
	store.reset()
	draft.clear()
	last_summary = {}
	if tracker:
		tracker.unbind()
	tracker = null


## Unix time in milliseconds (Talo's events' timestamp; the session's test clock when set).
func now_ms() -> int:
	return OnlineSession.now_ms()


## The statistics may be collected and sent now (OnlineSession.statistics_allowed(): consent, a
## server, not stopped by the remote kill switch).
func is_active() -> bool:
	return OnlineSession.statistics_allowed()


func _on_run_started(run: RunState, player: Player) -> void:
	if tracker:
		tracker.unbind()
	tracker = RunTelemetry.new()
	tracker.bind(run, player)


## The run is being saved: the counts so far go with it.
func _on_run_saving(run: RunState) -> void:
	if tracker and tracker.run == run:
		run.telemetry = tracker.to_data()


## A run ended (Events.run_ended), or was left (`left`: quit to the title, the app closed): its
## events queued, if allowed, then sent. Returns how many were queued. A debug run, or a run
## without consent, queues nothing; a run that goes on (a win, then the endless floors; a run left
## then resumed) is told again at its real end, with more, under the same run id.
func record(summary: RunSummary, left := false) -> int:
	draft.clear()
	if tracker == null or not _allowed(summary):
		if tracker:
			tracker.pending.clear()
		return 0
	var before := queue.size()
	var events := tracker.pending.duplicate()
	tracker.pending.clear()
	var props := tracker.summary(summary, left)
	events.append_array(tracker.pending)
	tracker.pending.clear()
	events.append({ "name": &"run_end", "props": props, "timestamp": now_ms() })
	for event: Dictionary in events:
		_enqueue(event)
	save_state()
	flush()
	return queue.size() - before


## The events may be kept: consent, a server, not a debug run.
func _allowed(summary: RunSummary) -> bool:
	return not summary.debug and not DebugCheats.debug_run and is_active()


## The player left the run without it ending (Events.run_left). For good (the title, the app
## closed): its "abandoned" end queued now, and the run no longer followed (resumed, it is
## followed again from its save). Put in the background: the same end as a draft only (the app
## may come back to the run).
func _on_run_left(summary: RunSummary, for_good: bool) -> void:
	if tracker == null:
		return
	if for_good:
		record(summary, true)
		tracker.unbind()
		tracker = null
		return
	draft.clear()
	if _allowed(summary):
		var events := tracker.pending.duplicate()
		events.append({ "name": &"run_end", "props": tracker.summary(summary, true, false), "timestamp": now_ms() })
		for event: Dictionary in events:
			var item := _prepared(event)
			if not item.is_empty():
				draft.append(item)
	save_state()


## The app came back to the run: the draft is not needed.
func _drop_draft() -> void:
	if draft.is_empty():
		return
	draft.clear()
	save_state()


## Puts `event` in the queue as it will be sent (_prepared()). False if its event is off.
func _enqueue(event: Dictionary) -> bool:
	var item := _prepared(event)
	if item.is_empty():
		return false
	if item.name == "run_end":
		last_summary = item.props
	store.push(item)
	return true


## `event` as it will be sent: its event on, its props sanitized, the game's version added.
## Empty if its event is off.
func _prepared(event: Dictionary) -> Dictionary:
	var def := config.event(StringName(event.name))
	if def == null or not def.enabled:
		return {}
	var props: Dictionary = (event.props as Dictionary).duplicate()
	props["v"] = str(ProjectSettings.get_setting("application/config/version", ""))
	return { "name": String(def.name), "props": config.sanitize(def, props), "timestamp": int(event.timestamp) }


## Everything waiting dropped (consent refused or withdrawn, "delete my online data").
func drop_queue() -> void:
	queue.clear()
	draft.clear()
	if tracker:
		tracker.pending.clear()
	save_state()


## Sends what waits, a batch at a time; without network (or a refused identity), tries again in
## config.retry_seconds, backing off. Only with consent. A batch the server refuses for good is
## dropped.
func flush() -> void:
	if store.is_busy() or queue.is_empty() or not is_active():
		return
	var token := store.begin_flush()
	var status := await OnlineSession.identity()
	if not store.still(token):
		return  # (reset meanwhile: the tests' next one)
	if status == BoardBackend.Status.REJECTED:
		status = BoardBackend.Status.OFFLINE  # (a refused identity is tried again later, by every service alike)
	while status == BoardBackend.Status.OK and not queue.is_empty() and is_active():
		var batch: Array[Dictionary] = []
		batch.assign(queue.slice(0, config.batch_size))
		@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
		status = await OnlineSession.backend.send_events(batch)
		if not store.still(token):
			return
		if status == BoardBackend.Status.OFFLINE or status == BoardBackend.Status.UNAVAILABLE:
			break
		# OK or refused for good: these are done (the queue may have changed meanwhile).
		for item in batch:
			queue.erase(item)
		if status != BoardBackend.Status.OK:
			status = BoardBackend.Status.OK  # (a refused batch doesn't stop the next one)
	save_state()
	store.end_flush(token)
	if status == BoardBackend.Status.OFFLINE and not queue.is_empty():
		store.retry_later(config.retry_seconds, OnlineSession.max_backoff())
	elif status == BoardBackend.Status.OK:
		store.succeeded()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			# To the background (or closing): what waits is kept (written only if it changed), and
			# sent if it can be.
			save_state()
			flush()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_drop_draft()
			flush()


# --- The file ------------------------------------------------------------------

func save_state() -> void:
	store.write({ "queue": queue, "draft": draft })


## Reads the file; a draft left there (the app killed in the background mid-run) joins the queue.
func load_state() -> void:
	queue.clear()
	draft.clear()
	var data := store.read()
	if data.is_empty():
		return
	var left_over := false
	for key in ["queue", "draft"]:
		var saved: Variant = data.get(key, [])
		if saved is Array:
			for item: Variant in saved:
				if item is Dictionary and (item as Dictionary).has_all(["name", "props", "timestamp"]):
					store.push(item)
					left_over = left_over or key == "draft"
	if left_over:
		save_state()
