extends OnlineService
## "Send feedback" (autoload "Feedback"; docs/online.md "Player feedback", design/interface.md):
## a bug, an idea or anything else the player writes in the form (FeedbackDialog, from the pause
## menu and the title's credits), sent to Talo's game feedback, where it shows in the dashboard
## under its category. The categories, the length limits, the delay between two messages and the
## queue's size are data (data/online/feedback.tres, FeedbackDef).
##
## What goes: the category, the words, and only what the player left ticked: the game's details
## (FeedbackInfo: version, system, device, screen, controls, language, the run, the end of the
## log) and the pseudonym. Sending is the player's own explicit act, for that message only (no
## consent question: docs/privacy-ops.md says why); the form says what is sent. The message is tied
## on Talo to the device's random id (OnlineSession.identity(): the same player as the
## leaderboards, made if there was none), so a deletion request removes it with the rest.
##
## Without network the message waits in its own file, user://feedback.json (at most max_queue,
## the oldest dropped), and goes at the next try (every retry_seconds, when the app comes back, at
## the next launch). One message per min_seconds_between (kept in the file: a restart doesn't
## reset it). A debug build's messages are Talo dev data (TaloBackend's X-Talo-Dev-Build). The tests
## give it no file and the session an offline or fake server: never the network.

## The queue or the delay changed (the form follows).
signal changed

const PATH := "user://feedback.json"
const DEFS := "res://data/online/feedback.tres"
const VERSION := 1
## Seconds after the game starts before what waits is sent (the start isn't slowed).
const START_DELAY := 5.0

## What submit() made of a message. QUEUED: kept and on its way. EMPTY, TOO_SHORT, TOO_LONG: the
## words (FeedbackDef's limits). TOO_SOON: wait seconds_to_wait(). UNAVAILABLE: no online
## service in this build. UNKNOWN_CATEGORY: not in the data.
enum Result { QUEUED, EMPTY, TOO_SHORT, TOO_LONG, TOO_SOON, UNAVAILABLE, UNKNOWN_CATEGORY }

var config: FeedbackDef
## Its file, the messages waiting (`queue`), the flush latch and the retry timer.
var store := PersistedQueue.new(PATH, VERSION)
## The file's path. Empty = nothing is read or written (tests).
var path: String:
	get:
		return store.path
	set(value):
		store.path = value
## Messages waiting to be sent, oldest first: {category (Talo's internal name), comment, props, at}
## (store.items).
var queue: Array[Dictionary]:
	get:
		return store.items
## When the last message was taken (Unix seconds, OnlineSession.now(); 0: never).
var last_at := 0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(store)
	store.retry_due.connect(flush)
	boot()


## Its data and file, read (no other service is asked: OnlineSession, "start-up order").
func boot() -> void:
	config = load(DEFS) as FeedbackDef
	store.max_items = config.max_queue
	load_state()


func _ready() -> void:
	OnlineSession.register(self)
	if not queue.is_empty():
		store.start_in(START_DELAY)


## The tests: no file, nothing waiting, no delay.
func use_for_tests(_fake: BoardBackend = null) -> void:
	path = ""
	reset()


## Everything forgotten (not the file), the flush and the retry stopped.
func reset() -> void:
	store.reset()
	last_at = 0


## The game has an online service to send to (an access key in this build). No consent gate on
## purpose: each message is the player's own act (docs/privacy-ops.md).
func is_available() -> bool:
	return OnlineSession.is_available()


## Seconds before another message may be sent (0: now).
func seconds_to_wait() -> int:
	if last_at <= 0:
		return 0
	return maxi(last_at + config.min_seconds_between - OnlineSession.now(), 0)


## What is wrong with `text` as a message (QUEUED: nothing), before the delay and the service.
func check_text(text: String) -> Result:
	var words := text.strip_edges()
	if words.is_empty():
		return Result.EMPTY
	if words.length() < config.min_length:
		return Result.TOO_SHORT
	if words.length() > config.max_length:
		return Result.TOO_LONG
	return Result.QUEUED


## The player sends `text` to `category` (FeedbackCategoryDef.id). `details`: the game's details
## (FeedbackInfo) if "Include game info" is ticked, else empty; `signed`: the pseudonym goes too
## (only if the player has one). Queued, then sent at once if the network allows.
func submit(category: StringName, text: String, details: Dictionary, signed: bool) -> Result:
	var def := config.category(category)
	if def == null:
		return Result.UNKNOWN_CATEGORY
	var problem := check_text(text)
	if problem != Result.QUEUED:
		return problem
	if not is_available():
		return Result.UNAVAILABLE
	if seconds_to_wait() > 0:
		return Result.TOO_SOON
	var props := FeedbackInfo.clean(details)
	props.erase(TaloBackend.NAME_PROP)
	if signed and not Leaderboards.pseudonym.is_empty():
		props[TaloBackend.NAME_PROP] = PlayerName.tagged(Leaderboards.pseudonym, Leaderboards.tag())  # (its tag: which Clayton wrote, the message's sender being hidden)
	store.push({ "category": def.internal_name, "comment": text.strip_edges(), "props": props, "at": OnlineSession.now() })
	last_at = OnlineSession.now()
	save_state()
	changed.emit()
	flush()
	return Result.QUEUED


## Sends what waits, in order, as the device's player (OnlineSession.identity()). A message the
## server refuses for good (a prop too long) is dropped; without network (or, on Talo, its category
## not made yet in the dashboard: TaloBackend.send_feedback(); or a refused identity), tried again
## in retry_seconds, backing off. One flush at a time.
func flush() -> void:
	if store.is_busy() or queue.is_empty() or not is_available():
		return
	var token := store.begin_flush()
	var status := await OnlineSession.identity()
	if not store.still(token):
		return  # (reset meanwhile: the tests' next one)
	if status == BoardBackend.Status.REJECTED:
		status = BoardBackend.Status.OFFLINE  # (a refused identity is tried again later, by every service alike)
	while status == BoardBackend.Status.OK and not queue.is_empty():
		var item: Dictionary = queue[0]
		@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
		status = await OnlineSession.backend.send_feedback(str(item.category), str(item.comment), item.props)
		if not store.still(token):
			return
		if status == BoardBackend.Status.OFFLINE or status == BoardBackend.Status.UNAVAILABLE:
			break
		if not queue.is_empty() and queue[0] == item:
			queue.pop_front()
		status = BoardBackend.Status.OK  # (a refused one is gone: on to the next)
	save_state()
	store.end_flush(token)
	changed.emit()
	if status == BoardBackend.Status.OFFLINE and not queue.is_empty():
		store.retry_later(config.retry_seconds, OnlineSession.max_backoff())
	elif status == BoardBackend.Status.OK:
		store.succeeded()


## "Delete my online data" (Privacy.forget_online()): what waits is dropped.
func forget() -> void:
	queue.clear()
	save_state()
	changed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if not queue.is_empty() and not store.is_retrying():
			flush()


# --- The file ------------------------------------------------------------------

func save_state() -> void:
	store.write({
		"last_at": last_at,
		"queue": queue,
	})


func load_state() -> void:
	reset()
	var data := store.read()
	if data.is_empty():
		return
	last_at = int(data.get("last_at", 0))
	var saved: Variant = data.get("queue", [])
	if saved is Array:
		for item: Variant in saved:
			if item is Dictionary and (item as Dictionary).has_all(["category", "comment", "props"]) and (item as Dictionary).props is Dictionary:
				store.push(item)
