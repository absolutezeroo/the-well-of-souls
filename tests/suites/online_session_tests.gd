class_name OnlineSessionTests
extends TestSuite
## What the online services share (OnlineSession, PersistedQueue; docs/online.md "The shared
## session"), on a fake server (FakeBoardBackend): never the network. run_unit(): the shared
## file helper (versions, migration, skipped writes, the bound, the latch, the backoff), one
## identify for every service at once, a refused identity tried again by every service alike, a
## reset that stops every flush and timer, the device's id taken from an older leaderboards file,
## the remote settings' ids checked against the content only when first needed, and **the start-up
## of every online autoload in a release build, in many orders, in every order-sensitive state**
## (the statistics accepted or not, a key or not, the remote kill switch on or off).


var _pid := OS.get_process_id()


func run_unit() -> void:
	_test_store_file()
	_test_store_queue_and_latch()
	await _test_backoff()
	await _test_single_identify()
	await _test_refused_identity()
	await _test_reset_stops_flushes()
	_test_legacy_device_id()
	_test_lazy_content_ids()
	_test_release_paths()
	_test_startup_orders()
	OnlineSession.use_all_for_tests()


func _temp(stem: String) -> String:
	return "user://test_%s_%d.json" % [stem, _pid]


func _remove(file: String) -> void:
	for candidate in [file, file + ".tmp"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))


## Every service on `fake`, nothing chosen; `consent`: published and the statistics accepted, the
## debug build allowed to send its counters.
func _fresh(fake: FakeBoardBackend, consent: bool) -> void:
	OnlineSession.use_all_for_tests(fake)
	if consent:
		Leaderboards.set_shown(true)
		Privacy.answer_age(true)
		Privacy.grant()
		WorldStats.debug_builds_send = true


func _test_store_file() -> void:
	var file := _temp("store")
	var store := PersistedQueue.new(file, 3)
	add_child(store)
	check(PersistedQueue.is_test_launch() and store.path.is_empty(), "a test launch is seen: the online files start with no path")
	store.path = file
	check(OnlineSession.path.is_empty() and Leaderboards.path.is_empty() and WorldStats.path.is_empty(), "...so the autoloads never read the player's real files in a test launch")
	check(store.write({ "a": 1 }) and int(store.read().get("a", 0)) == 1 and int(store.read().get("version", 0)) == 3, "a file written with its version, read back")
	# A write that changes nothing is skipped (an alt-tab writes no file).
	store.write({ "a": 1 })
	var outside := FileAccess.open(file, FileAccess.WRITE)
	outside.store_string(JSON.stringify({ "version": 3, "a": 2 }))
	outside.close()
	store.write({ "a": 1 })
	check(int(SafeFile.read_json(file).get("a", 0)) == 2, "the same content again: not written")
	store.read()
	store.write({ "a": 1 })
	check(int(SafeFile.read_json(file).get("a", 0)) == 1, "...but written after a read, or when it changed")
	# A newer game's file: not trusted.
	SafeFile.write_json(file, { "version": 4, "a": 9 })
	check(store.read().is_empty(), "a file from a newer version is not read")
	# An older one: migrated.
	SafeFile.write_json(file, { "version": 2, "old": 5 })
	var migrated := store.read(func(data: Dictionary, version: int) -> Dictionary:
		return { "a": int(data.old) * 10, "from": version })
	check(int(migrated.get("a", 0)) == 50 and int(migrated.get("from", 0)) == 2, "an older file goes through the migration")
	SafeFile.write_json(file, { "a": 7 })
	check(int(store.read(func(_data: Dictionary, version: int) -> Dictionary: return { "from": version }).get("from", 0)) == 1, "a file without a version is version 1")
	store.path = ""
	check(not store.write({ "a": 1 }) and store.read().is_empty(), "no path: nothing read or written")
	_remove(file)
	store.free()


func _test_store_queue_and_latch() -> void:
	var store := PersistedQueue.new("", 1)
	add_child(store)
	store.max_items = 3
	for i in 5:
		store.push({ "n": i })
	check(store.items.size() == 3 and int(store.items[0].n) == 2, "bounded: the oldest dropped")
	var token := store.begin_flush()
	check(token >= 0 and store.is_busy() and store.begin_flush() == -1, "one flush at a time")
	store.reset()
	check(not store.is_busy() and not store.still(token) and not store.end_flush(token) and store.items.is_empty(), "a reset frees the latch and makes the running flush stale")
	var next := store.begin_flush()
	check(next >= 0 and store.end_flush(next) and not store.is_busy(), "...and the next flush runs")
	store.free()


func _test_backoff() -> void:
	var store := PersistedQueue.new("", 1)
	add_child(store)
	var waits: Array[int] = []
	for i in 5:
		store.retry_later(10.0, 8.0)
		waits.append(roundi(store.retry_left()))
	check(waits == [10, 20, 40, 80, 80], "the retry backs off, doubling up to max_backoff times (%s)" % [waits])
	store.succeeded()
	store.retry_later(10.0, 8.0)
	check(roundi(store.retry_left()) == 10, "a success starts again from retry_seconds")
	var fired := [false]
	store.retry_due.connect(func() -> void: fired[0] = true)
	store.start_in(0.05)
	await get_tree().create_timer(0.2, true, false, true).timeout
	check(fired[0], "the timer tells when it is time")
	store.retry_later(10.0, 8.0)
	store.reset()
	check(not store.is_retrying() and store.failures == 0, "a reset stops the timer")
	check(OnlineSession.config.max_backoff >= 1.0 and OnlineSession.config.refused_identity_seconds > 0.0, "the session's numbers are data (data/online/online_session.tres)")
	store.free()


func _test_single_identify() -> void:
	var fake: FakeBoardBackend = FakeBoardBackend.new()
	fake.delay = 0.1
	_fresh(fake, true)
	var answers: Array = []
	for i in 4:
		(func() -> void: answers.append(await OnlineSession.identity())).call()
	check(fake.identifies == 1, "four callers at once: one identify (%d)" % fake.identifies)
	await get_tree().create_timer(0.4, true, false, true).timeout
	check(answers.size() == 4 and answers.all(func(status: Variant) -> bool: return status == BoardBackend.Status.OK), "...and every caller gets its answer (%s)" % [answers])
	# The services themselves, all at once (the start: the leaderboards' delay, the feedback's,
	# the statistics on a focus change).
	fake = FakeBoardBackend.new()
	fake.delay = 0.1
	_fresh(fake, true)
	Leaderboards.set_pseudonym("Kagari")
	Telemetry._enqueue({ "name": &"boss", "props": { "boss": "golem" }, "timestamp": 1 })
	Telemetry.flush()
	WorldStats.count(WorldStatDef.Feed.KILLS, 2)
	WorldStats.commit()
	Feedback.submit(&"bug", "The lantern went out.", {}, false)
	await get_tree().create_timer(0.6, true, false, true).timeout
	check(fake.identifies == 1, "four services flushing at once: one identify (%d)" % fake.identifies)
	check(Telemetry.queue.is_empty() and WorldStats.queue.is_empty() and Feedback.queue.is_empty() and Leaderboards.synced_name == "Kagari", "...and all of them sent")
	OnlineSession.use_all_for_tests()


func _test_refused_identity() -> void:
	var fake: FakeBoardBackend = FakeBoardBackend.new()
	fake.refuse_identify = true
	_fresh(fake, true)
	Leaderboards.set_pseudonym("Kagari")
	Telemetry._enqueue({ "name": &"boss", "props": { "boss": "golem" }, "timestamp": 1 })
	Telemetry.flush()
	WorldStats.count(WorldStatDef.Feed.KILLS, 2)
	WorldStats.commit()
	Feedback.submit(&"bug", "The lantern went out.", {}, false)
	await _frames(2)
	check(fake.identifies == 1, "a refused identify is answered again without a call for a while (%d calls)" % fake.identifies)
	check(Leaderboards.synced_name.is_empty() and Telemetry.queue.size() == 1 and int(WorldStats.queue.get("demons-slain", 0)) == 2 and Feedback.queue.size() == 1, "refused: everything still waits")
	check(Leaderboards.store.is_retrying() and Telemetry.store.is_retrying() and WorldStats.store.is_retrying() and Feedback.store.is_retrying(), "...and every service tries again later (the same rule for all)")
	# The refusal remembered no longer (the key fixed, the portal passed): every service goes.
	fake.refuse_identify = false
	OnlineSession._refused_until = 0
	Leaderboards.flush()
	Telemetry.flush()
	WorldStats.flush()
	Feedback.flush()
	await _frames(2)
	check(fake.identifies == 2 and Leaderboards.synced_name == "Kagari" and Telemetry.queue.is_empty() and WorldStats.queue.is_empty() and Feedback.queue.is_empty(), "the next try identifies once and sends everything")
	OnlineSession.use_all_for_tests()


func _test_reset_stops_flushes() -> void:
	var fake: FakeBoardBackend = FakeBoardBackend.new()
	fake.delay = 0.2
	_fresh(fake, true)
	Telemetry._enqueue({ "name": &"boss", "props": { "boss": "golem" }, "timestamp": 1 })
	Telemetry.flush()
	Feedback.submit(&"bug", "The lantern went out.", {}, false)
	WorldStats.count(WorldStatDef.Feed.KILLS, 2)
	WorldStats.commit()
	check(Telemetry.store.is_busy() and Feedback.store.is_busy() and WorldStats.store.is_busy(), "(flushes on their way)")
	Leaderboards.store.start_in(30.0)
	RemoteConfig.store.start_in(30.0)
	# (the same server stays: its answer to the flush in flight still comes, after the reset)
	OnlineSession.use_all_for_tests(fake)
	var calls := fake.calls
	var stores: Array[PersistedQueue] = [Leaderboards.store, Telemetry.store, WorldStats.store, Feedback.store, RemoteConfig.store, Privacy.store, OnlineSession.store]
	check(stores.all(func(store: PersistedQueue) -> bool: return not store.is_busy() and not store.is_retrying()), "a reset frees every flush latch and stops every timer")
	await get_tree().create_timer(0.6, true, false, true).timeout
	check(fake.calls == calls and fake.events.is_empty() and fake.feedback.is_empty() and Telemetry.queue.is_empty() and Feedback.queue.is_empty() and WorldStats.queue.is_empty(), "the flushes started before the reset change nothing after it (%d calls after)" % (fake.calls - calls))
	check(stores.all(func(store: PersistedQueue) -> bool: return not store.is_retrying()), "...and plan no retry")
	Telemetry._enqueue({ "name": &"boss", "props": { "boss": "golem" }, "timestamp": 2 })
	check(Telemetry.queue.size() == 1, "...nor touch the next test's queue")
	OnlineSession.use_all_for_tests()


## A game of version 0.3 or before kept the device's id in user://leaderboards.json (version 2):
## the session takes it once, the leaderboards keep their part.
func _test_legacy_device_id() -> void:
	OnlineSession.use_all_for_tests()
	var boards := _temp("legacy_boards")
	var session := _temp("legacy_online")
	SafeFile.write_json(boards, { "version": 2, "device_id": "abc123", "player_id": "p-9", "name": "Kagari", "name_chosen": true, "synced_name": "Kagari", "shown": true, "queue": [] })
	OnlineSession.path = session
	OnlineSession.legacy_path = boards
	OnlineSession.load_state()
	check(OnlineSession.device_id == "abc123" and OnlineSession.player_id == "p-9", "the device's id is taken from an older leaderboards file")
	check(str(SafeFile.read_json(session).get("device_id", "")) == "abc123", "...and kept in the session's own file")
	Leaderboards.path = boards
	Leaderboards.load_state()
	check(Leaderboards.shown and Leaderboards.name_chosen and Leaderboards.pseudonym == "Kagari", "a version 2 leaderboards file keeps its choices")
	Leaderboards.save_state()
	var saved: Dictionary = SafeFile.read_json(boards)
	check(int(saved.get("version", 0)) == Leaderboards.VERSION and not saved.has("device_id"), "...and is written again without the id (version %d)" % Leaderboards.VERSION)
	OnlineSession.legacy_path = ""
	SafeFile.write_json(session, { "version": 1, "device_id": "def456", "player_id": "" })
	OnlineSession.load_state()
	check(OnlineSession.device_id == "def456", "the session's own file wins once it exists")
	OnlineSession.path = ""
	Leaderboards.path = ""
	_remove(boards)
	_remove(session)
	OnlineSession.use_all_for_tests()


## A stored omen (a CONTENT_ID value) is checked against the content only when first needed: the
## whole ContentDB never loads while the autoloads start.
func _test_lazy_content_ids() -> void:
	OnlineSession.use_all_for_tests()
	var file := _temp("lazy_remote")
	var today := DailyRun.today()
	var date := Time.get_date_string_from_unix_time(today * 86400)
	SafeFile.write_json(file, { "version": 1, "fetched_at": 1, "values": { "daily_omen": "frostbound", "daily_omen_date": date, "event_floor_event": "made_up_event" } })
	RemoteConfig.path = file
	RemoteConfig._content = null
	RemoteConfig.boot()
	check(RemoteConfig._content == null, "starting with a stored omen loads no content")
	check(RemoteConfig.omen_for(today) == &"frostbound", "the omen is checked when first asked for, and kept")
	check(RemoteConfig._content != null and not RemoteConfig.latest.has("event_floor_event") and not RemoteConfig.active.has("event_floor_event"), "...an id the game doesn't have is dropped then")
	check(" ".join(RemoteConfig.ignored).contains("event_floor_event"), "...and listed as ignored")
	SafeFile.write_json(file, { "version": 1, "fetched_at": 1, "values": { "daily_omen": "../../src/game/game.gd", "daily_omen_date": date } })
	RemoteConfig._content = null
	RemoteConfig.boot()
	check(not RemoteConfig.latest.has("daily_omen"), "a value that isn't even an id's form is ignored at once")
	RemoteConfig.path = ""
	RemoteConfig.boot()
	_remove(file)
	OnlineSession.use_all_for_tests()


## What only a release build does, run here through OnlineSession.release_mode.
func _test_release_paths() -> void:
	OnlineSession.use_all_for_tests()
	OnlineSession.release_mode = true
	RemoteConfig.simulate("motd_en", "Simulated")
	check(RemoteConfig.simulated.is_empty(), "release: the debug panel's values are ignored")
	check(FeedbackInfo.game().get("build") == "release", "release: the feedback's details say so")
	var fake: FakeBoardBackend = FakeBoardBackend.new()
	OnlineSession.use_backend(fake)
	Privacy.answer_age(true)
	Privacy.grant()
	check(WorldStats.may_send() and not WorldStats.debug_builds_send, "release: the world counters go (no debug-build exception needed)")
	OnlineSession.release_mode = false
	check(not WorldStats.may_send() and Telemetry.is_active(), "a debug build: the counters stay home, the statistics are dev data")
	OnlineSession.use_all_for_tests()


# --- Start-up -------------------------------------------------------------------------

## The online autoloads in project.godot's order.
func _services() -> Array[OnlineService]:
	return [OnlineSession, Leaderboards, Privacy, Telemetry, WorldStats, RemoteConfig, Feedback]


## The files a consenting (or refusing) player leaves, the kill switch as read last.
func _write_files(consent: bool, kill: bool) -> Dictionary:
	var files := {
		"session": _temp("boot_online"), "boards": _temp("boot_boards"), "privacy": _temp("boot_privacy"),
		"telemetry": _temp("boot_telemetry"), "world": _temp("boot_world"), "remote": _temp("boot_remote"),
		"feedback": _temp("boot_feedback"),
	}
	var consent_version := (load(Privacy.DEFS) as PrivacyDef).consent_version
	SafeFile.write_json(files.session, { "version": 1, "device_id": "dev1", "player_id": "p1" })
	SafeFile.write_json(files.boards, { "version": 3, "name": "Kagari", "name_chosen": true, "synced_name": "Kagari", "shown": true, "queue": [] })
	SafeFile.write_json(files.privacy, { "version": 1, "age_answered": true, "old_enough": true, "analytics": "granted" if consent else "refused",
		"answered_at": 1, "answered_version": consent_version, "history": [] })
	SafeFile.write_json(files.telemetry, { "version": 1, "queue": [], "draft": [{ "name": "run_end", "props": { "result": "abandoned" }, "timestamp": 1 }] })
	SafeFile.write_json(files.world, { "version": 1, "queue": {}, "mine": {}, "sent": {},
		"draft": { "run": "run1", "counts": { "demons-slain": 4 }, "run_counts": { "demons-slain": 4 } } })
	SafeFile.write_json(files.remote, { "version": 1, "fetched_at": 1, "values": { "statistics_off": "true" if kill else "false" } })
	SafeFile.write_json(files.feedback, { "version": 1, "last_at": 5, "queue": [{ "category": "bug", "comment": "The door.", "props": {}, "at": 1 }] })
	return files


func _point_at(files: Dictionary) -> void:
	OnlineSession.path = files.get("session", "")
	OnlineSession.legacy_path = ""
	Leaderboards.path = files.get("boards", "")
	Privacy.path = files.get("privacy", "")
	Telemetry.path = files.get("telemetry", "")
	WorldStats.path = files.get("world", "")
	RemoteConfig.path = files.get("remote", "")
	Feedback.path = files.get("feedback", "")


## Every service as Godot has it before its _init(): nothing read (no data at all).
func _unborn() -> void:
	OnlineSession.config = null
	OnlineSession.use_backend(null)
	Leaderboards.config = null
	Privacy.def = null
	Telemetry.config = null
	WorldStats.config = null
	RemoteConfig.config = null
	Feedback.config = null


## One start-up in a release build: each service's _init() part (boot()) in `order`, the others
## not made yet, then each one's _ready() part (settle()) in the same order.
func _start_up(order: Array[OnlineService], key: bool) -> void:
	_unborn()
	for service in order:
		service.boot()
		if service == OnlineSession:
			var fake: FakeBoardBackend = FakeBoardBackend.new()
			fake.configured = key
			OnlineSession.use_backend(fake)
	for service in order:
		service.settle()


func _test_startup_orders() -> void:
	OnlineSession.use_all_for_tests()
	var orders: Array = []
	var project := _services()
	for shift in project.size():
		var rotated: Array[OnlineService] = []
		for i in project.size():
			rotated.append(project[(i + shift) % project.size()])
		orders.append(rotated)
		var backwards: Array[OnlineService] = []
		for i in range(rotated.size() - 1, -1, -1):
			backwards.append(rotated[i])
		orders.append(backwards)
	var failed := PackedStringArray()
	for consent in [true, false]:
		for kill in [false, true]:
			for key in [true, false]:
				for order: Array[OnlineService] in orders:
					var files := _write_files(consent, kill)
					_point_at(files)
					OnlineSession.release_mode = true
					WorldStats.debug_builds_send = false
					_start_up(order, key)
					var sends: bool = consent and key and not kill
					var problems := PackedStringArray()
					if OnlineSession.config == null or Leaderboards.config == null or Privacy.def == null or Telemetry.config == null \
							or WorldStats.config == null or RemoteConfig.config == null or Feedback.config == null:
						problems.append("a service didn't finish starting")
					if OnlineSession.device_id != "dev1" or not Leaderboards.shown or Feedback.queue.size() != 1 or Feedback.last_at != 5:
						problems.append("a file wasn't read")
					if Privacy.analytics_allowed() != consent or RemoteConfig.statistics_off() != kill:
						problems.append("the choices or the kill switch read wrong")
					if Telemetry.queue.filter(func(e: Dictionary) -> bool: return e.name == "run_end").size() != 1:
						problems.append("the statistics' draft didn't join the queue")
					if WorldStats.may_send() != sends or int(WorldStats.queue.get("demons-slain", 0)) != (4 if sends else 0):
						problems.append("the world counters' draft settled wrong (%s)" % [WorldStats.queue])
					if not problems.is_empty():
						var names := PackedStringArray()
						for service in order:
							names.append(String(service.name))
						failed.append("consent %s, kill switch %s, key %s, order %s: %s" % [consent, kill, key, ",".join(names), "; ".join(problems)])
					for file: String in files.values():
						_remove(file)
	check(failed.is_empty(), "release build: every online autoload starts in any order, in every state (%d orders x 8 states)%s" % [orders.size(), "" if failed.is_empty() else ": " + failed[0]])
	# Back to the tests' usual: no files, the data read again, nothing chosen.
	OnlineSession.release_mode = false
	WorldStats.debug_builds_send = false
	_point_at({})
	for service in _services():
		service.boot()
	OnlineSession.use_all_for_tests()
