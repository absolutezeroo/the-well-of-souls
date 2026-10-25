extends Node
## The online leaderboards (autoload "Leaderboards"; design/progression.md "Online leaderboards",
## docs/online.md). Listens for runs that end (Events.run_ended, a RunSummary from RunRecords),
## queues the scores the boards take (LeaderboardDef.accepts(): the Dawn Knell's official attempt
## for now), sends them through the session's backend and keeps trying while there is no network;
## reads the boards for the Leaderboards page. UI asks it, never the other way round.
##
## Its own file, user://leaderboards.json (never the player's save, never the Profile): the
## pseudonym, "publish my scores online" and the scores waiting to be sent. The device's anonymous
## id, the Talo player it became and the server itself are the OnlineSession's, shared by every
## online service. Nothing is sent for a debug run, a practice attempt, a run that fails
## RunSummary.check(), in the tests (they give the session an offline backend and no file), and
## **nothing at all, not even a read of a board, until the player chose to publish their scores**
## (PseudonymDialog: the choice is the consent the law asks for, docs/privacy-ops.md; the gate is
## OnlineSession.scores_allowed()).
##
## Without an access key (TaloBackend.read_key()) the session's backend is BoardBackend's offline
## one: nothing is sent, nothing fails, the page says the leaderboards are unavailable.

## Something the page shows changed: the name, the opt-out, a score sent or waiting.
signal changed
## A board asked with request_board() came back (`request`: the number it handed out).
signal board_loaded(view: View, request: int)

const PATH := "user://leaderboards.json"
const CONFIG := "res://data/leaderboards/leaderboards.tres"
## 2: the choice to publish became explicit (off until chosen); a version-1 file is asked again.
## 3: the device's id and player moved to the OnlineSession's file (it takes them from a version 2).
const VERSION := 3
## Seconds after the game starts before what waits is sent (the start isn't slowed).
const START_DELAY := 3.0

## The last request_board() number handed out.
var _requests := 0
var config: LeaderboardsConfig
## Its file, the scores waiting (`queue`), the flush latch and the retry timer.
var store := PersistedQueue.new(PATH, VERSION)
## The file's path. Empty = nothing is read or written (tests).
var path: String:
	get:
		return store.path
	set(value):
		store.path = value
## The pseudonym on the boards; `name_chosen`: the player picked it (or kept the default) once.
var pseudonym := ""
var name_chosen := false
## The name the server has for this player ("" none yet).
var synced_name := ""
## "Publish my scores online": off (the default until the player says yes), nothing is ever sent
## or read (and what waited is dropped).
var shown := false
## Scores waiting to be sent, oldest first: {board, period, score, props, at} (store.items).
var queue: Array[Dictionary]:
	get:
		return store.items
## Why the last run ended wasn't queued (RunSummary.check()), for the tests.
var last_rejection := ""
## Places on the boards the server gave as scores were sent this session: "board/period" -> rank.
var last_ranks := {}


## What the page shows for one board and period.
class View:
	extends RefCounted
	var status: BoardBackend.Status = BoardBackend.Status.UNAVAILABLE
	## The top of the board (config.top_count at most).
	var top: Array[BoardBackend.Entry] = []
	## The player's own line (null: none), and the lines around it when it is past the top.
	var mine: BoardBackend.Entry
	var around: Array[BoardBackend.Entry] = []
	## Entries on the board for that period.
	var total := 0
	## The player's score for that period still waits to be sent (its score, -1: none).
	var waiting := -1.0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(store)
	store.retry_due.connect(flush)
	boot()


## Its data and file, read (no other service is asked: OnlineSession, "start-up order").
func boot() -> void:
	config = load(CONFIG) as LeaderboardsConfig
	store.max_items = config.max_queue
	load_state()


func _ready() -> void:
	OnlineSession.register(self)
	Events.run_ended.connect(record)
	store.start_in(START_DELAY)


## The tests: no file, the session on an offline backend (or `fake`) with no device id, everything
## forgotten.
func use_for_tests(fake: BoardBackend = null) -> void:
	OnlineSession.use_for_tests(fake)
	path = ""
	reset()


## Everything forgotten (not the file: save_state() does), the flush and the retry stopped.
func reset() -> void:
	pseudonym = ""
	name_chosen = false
	synced_name = ""
	shown = false
	store.reset()
	last_rejection = ""
	last_ranks.clear()


## There is a server (an access key in this build).
func is_available() -> bool:
	return OnlineSession.is_available()


## The player hasn't chosen yet whether to publish their scores (ask before anything is sent).
func needs_name() -> bool:
	return is_available() and not name_chosen


## The name on the boards: the one picked, or the default ("Soul"). Without its tag: this is
## what is sent (the player's `name` prop and each entry's), the tag being added where it is shown.
func display_name() -> String:
	if not pseudonym.is_empty():
		return pseudonym
	return PlayerName.default_for(config)


## The player's tag ("4821"; docs/online.md "Names and tags"): from the device's online id, the
## one Talo keeps as the alias's identifier, so it is the tag every other player sees on this
## player's entries. Before the device has an id, from the one it will take
## (OnlineSession.preview_device(): drawn in memory, nothing written or sent), so the question
## already shows it.
func tag() -> String:
	return PlayerName.tag_of(OnlineSession.preview_device())


## The name as everyone sees it: "Clayton#4821".
func tagged_name() -> String:
	return PlayerName.tagged(display_name(), tag())


## Sets the pseudonym (tidied) if it passes PlayerName.problem(); returns the problem otherwise.
func set_pseudonym(text: String) -> PlayerName.Problem:
	var problem := PlayerName.problem(text, config)
	if problem != PlayerName.Problem.NONE:
		return problem
	pseudonym = PlayerName.tidy(text)
	name_chosen = true
	save_state()
	changed.emit()
	flush()
	return problem


## The default name kept as the pseudonym: not asked again.
func keep_default_name() -> void:
	if pseudonym.is_empty():
		pseudonym = display_name()
	name_chosen = true
	save_state()
	changed.emit()


## "Publish my scores online", the player's own choice (the dialog, the Options). Off drops what
## waits and never sends nor reads again until it is on. Either way it is an answer: not asked
## again.
func set_shown(on: bool) -> void:
	shown = on
	if on:
		OnlineSession.device()  # (the tag shown in the question then stays this device's)
	else:
		store.reset()  # invalidate sends and reads begun under the previous choice
		queue.clear()
	name_chosen = true
	save_state()
	changed.emit()


## "Delete my online data" (Privacy.forget_online(), with OnlineSession.forget() for the device's
## id and its server player): off, the pseudonym and the queue forgotten.
func forget() -> void:
	store.reset()
	pseudonym = ""
	synced_name = ""
	shown = false
	name_chosen = true
	queue.clear()
	last_ranks.clear()
	save_state()
	changed.emit()


## A run ended: its scores queued for the boards that take it, then sent. Returns how many were
## queued (none without a server: an offline build keeps nothing).
func record(summary: RunSummary) -> int:
	last_rejection = ""
	if not OnlineSession.scores_allowed() or summary.debug:
		return 0  # (scores_allowed(): a server, published, not stopped by the remote kill switch)
	var boards := config.boards.filter(func(def: LeaderboardDef) -> bool: return def.accepts(summary))
	if boards.is_empty():
		return 0
	last_rejection = summary.check(config)
	if not last_rejection.is_empty():
		return 0
	var props := summary.props()
	props[TaloBackend.NAME_PROP] = display_name()
	for def: LeaderboardDef in boards:
		var key := def.period_of(summary)
		var entry_props := props.duplicate()
		if not period_prop(def).is_empty():
			entry_props[period_prop(def)] = key
		_enqueue({ "board": String(def.id), "period": key, "score": def.score_of(summary), "props": entry_props, "at": OnlineSession.now() })
	save_state()
	changed.emit()
	flush()
	return boards.size()


## The prop an entry of `board` keeps its period in ("day", "week"; "" for all time): the page
## asks the server for one period's entries by it.
static func period_prop(board: LeaderboardDef) -> String:
	match board.period:
		LeaderboardDef.Period.DAILY:
			return "day"
		LeaderboardDef.Period.WEEKLY:
			return "week"
	return ""


## The score waiting for `board` in period `key`, or -1.
func waiting_score(board: LeaderboardDef, key: String) -> float:
	for item in queue:
		if item.board == String(board.id) and item.period == key:
			return float(item.score)
	return -1.0


## Sends what waits, in order; on no network (or a refused identity), tries again in
## config.retry_seconds, backing off (PersistedQueue.retry_later()). A score whose period is over
## (yesterday's, the board emptied at midnight UTC) or refused by the server is dropped. One flush
## at a time.
func flush() -> void:
	if store.is_busy() or not OnlineSession.scores_allowed():
		return
	if queue.is_empty() and (not name_chosen or synced_name == display_name()):
		return
	var token := store.begin_flush()
	var status := await OnlineSession.identity()
	if not store.still(token):
		return  # (reset meanwhile: the tests' next one)
	if status == BoardBackend.Status.REJECTED:
		status = BoardBackend.Status.OFFLINE  # (a refused identity is tried again later, by every service alike)
	var backend := OnlineSession.backend
	if OnlineSession.scores_allowed() and status == BoardBackend.Status.OK and synced_name != display_name() and (name_chosen or not queue.is_empty()):
		var named := display_name()
		@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
		status = await backend.set_pseudonym(named)
		if not store.still(token):
			return
		if status == BoardBackend.Status.OK:
			synced_name = named
			save_state()
	while OnlineSession.scores_allowed() and status != BoardBackend.Status.OFFLINE and status != BoardBackend.Status.UNAVAILABLE and not queue.is_empty():
		var item: Dictionary = queue[0]
		var def := config.board(StringName(item.board))
		if def == null or not def.submits or not def.is_open(str(item.period)):
			queue.pop_front()
			continue
		@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
		var sent := await backend.submit(def, float(item.score), str(item.period), item.props)
		if not store.still(token):
			return
		status = sent.status
		if status == BoardBackend.Status.OFFLINE:
			break
		if not queue.is_empty() and queue[0] == item:
			queue.pop_front()
		if status == BoardBackend.Status.OK and sent.rank > 0:
			last_ranks["%s/%s" % [item.board, item.period]] = sent.rank
	save_state()
	store.end_flush(token)
	changed.emit()
	if status == BoardBackend.Status.OFFLINE and (not queue.is_empty() or synced_name != display_name()):
		store.retry_later(config.retry_seconds, OnlineSession.max_backoff())
	elif status == BoardBackend.Status.OK:
		store.succeeded()


## Asks for a board (load_board()) and answers with board_loaded: a page listening to the signal
## is never resumed after it is freed, as one awaiting load_board() would be. Returns the request's
## number, to tell its answer from an older one's.
func request_board(board: LeaderboardDef, back: int = 0) -> int:
	_requests += 1
	var request := _requests
	_answer_board.call_deferred(board, back, request)  # (after the caller kept the number: an answer may come at once)
	return request


func _answer_board(board: LeaderboardDef, back: int, request: int) -> void:
	var view := await load_board(board, back)
	board_loaded.emit(view, request)


## The board for the period `back` periods ago (0: today), as the page shows it: the top, the
## player's line and those around it. What waits is sent first.
func load_board(board: LeaderboardDef, back: int = 0) -> View:
	var view := View.new()
	if not OnlineSession.scores_published():
		return view  # (not chosen to publish: the server isn't even read)
	var generation := store.generation()
	await flush()
	if not _may_read_board(generation):
		return view
	var key := board.period_key(back)
	var past := back > 0
	view.waiting = waiting_score(board, key)
	var identity_status := await OnlineSession.identity()
	var backend := OnlineSession.backend
	if not _may_read_board(generation):
		return View.new()
	@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
	var top := await backend.fetch(board, key, past, 0)
	if not _may_read_board(generation):
		return View.new()
	view.status = top.status
	if top.status != BoardBackend.Status.OK:
		return view
	view.total = top.total
	view.top.assign(top.entries.slice(0, config.top_count))
	if identity_status != BoardBackend.Status.OK or backend.alias_id() == 0:
		return view
	var me := backend.alias_id()
	for entry in top.entries:
		if entry.alias_id == me:
			view.mine = entry
			if entry.rank <= config.top_count:
				return view
	# Past the top: the player's entry, then the page around it.
	var page_size := BoardBackend.PAGE_SIZE
	if view.mine == null:
		if not _may_read_board(generation):
			return View.new()
		@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
		var mine := await backend.fetch_mine(board, key, past)
		if not _may_read_board(generation):
			return View.new()
		if mine.status != BoardBackend.Status.OK or mine.entries.is_empty():
			return view
		view.mine = mine.entries[0]
		if not mine.ranks_reliable:
			view.mine.rank = 0
			for page_index in range(1, config.rank_scan_pages):
				if top.last_page:
					break
				if not _may_read_board(generation):
					return View.new()
				@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
				var page := await backend.fetch(board, key, past, page_index)
				if not _may_read_board(generation):
					return View.new()
				if page.status != BoardBackend.Status.OK:
					break
				top = page
				for entry in page.entries:
					if entry.alias_id == me:
						view.mine = entry
						_fill_around(view, page.entries)
						return view
			return view
	var around := top
	var wanted := floori(float(view.mine.rank - 1) / page_size)
	if wanted != 0:
		if not _may_read_board(generation):
			return View.new()
		@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
		around = await backend.fetch(board, key, past, wanted)
		if not _may_read_board(generation):
			return View.new()
	if around.status == BoardBackend.Status.OK:
		_fill_around(view, around.entries)
	return view


func _fill_around(view: View, entries: Array[BoardBackend.Entry]) -> void:
	var index := -1
	for i in entries.size():
		if entries[i].alias_id == view.mine.alias_id:
			index = i
	if index < 0:
		view.around.append(view.mine)
		return
	view.mine = entries[index]
	view.around.assign(entries.slice(maxi(index - config.around, 0), index + config.around + 1))


## A score into the queue: one per board and period, the better one kept.
func _enqueue(item: Dictionary) -> void:
	var def := config.board(StringName(item.board))
	for i in queue.size():
		var other: Dictionary = queue[i]
		if other.board == item.board and other.period == item.period:
			var better := float(item.score) > float(other.score) if def.higher_first else float(item.score) < float(other.score)
			if better:
				queue[i] = item
			return
	store.push(item)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if not queue.is_empty() and not store.is_retrying():
			flush()


# --- The file ------------------------------------------------------------------

func save_state() -> void:
	store.write({
		"name": pseudonym,
		"name_chosen": name_chosen,
		"synced_name": synced_name,
		"shown": shown,
		"queue": queue,
	})


## Reads the file (an older one migrated: _migrate()). A version 2's device id is the
## OnlineSession's business (it takes it from there once).
func load_state() -> void:
	reset()
	var data := store.read(_migrate)
	if data.is_empty():
		return
	pseudonym = str(data.get("name", ""))
	synced_name = str(data.get("synced_name", ""))
	name_chosen = bool(data.get("name_chosen", false))
	shown = bool(data.get("shown", false))
	var saved: Variant = data.get("queue", []) if shown else []
	if saved is Array:
		for item: Variant in saved:
			if item is Dictionary and (item as Dictionary).has_all(["board", "period", "score", "props"]):
				queue.append(item)


## An older file as this version reads it. Before version 2, "shown" was on unless turned off:
## the player is asked again (not chosen, not shown, its queue dropped). Version 2 kept the
## device's id here too (left for OnlineSession.load_state()).
static func _migrate(data: Dictionary, version: int) -> Dictionary:
	var result := data.duplicate()
	if version < 2:
		result.erase("name_chosen")
		result.erase("shown")
	return result


## Every step of a board read belongs to the choice that started it.
func _may_read_board(generation: int) -> bool:
	return store.still(generation) and OnlineSession.scores_published()
