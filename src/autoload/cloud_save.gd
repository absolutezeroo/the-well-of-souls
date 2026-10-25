extends OnlineService
## The online save (autoload "CloudSave"; docs/online.md "Accounts and the online save"): with an
## account signed in (Account), the profile (Profile.to_data(): souls, the Tree, records, the
## bestiary, the codex...; never a run in progress nor the settings) is kept online as one of the
## account's Talo game saves, so a phone and a PC share it.
##
## Each copy carries a revision (`rev`). This device remembers the revision its profile last
## matched (`base_rev`) and whether it changed since (`dirty`). A sync reads the online copy:
## - the same revision: this device's changes, if any, go up as the next revision;
## - a newer one and nothing changed here: it replaces the profile (out of a run only: in a run it
##   waits for the menus);
## - a newer one and this device changed too, or a first sign-in with progress on both sides that
##   differs: a **conflict**, the player chooses which to keep (CloudConflictDialog, both
##   summarised: runs, souls, deepest floor, when, from what);
## - none online yet: this profile goes up (if it has anything).
## A sync runs at sign-in, at launch, `upload_delay` seconds after the profile is written, when
## the app goes to the background or comes back, and after a failure with a backoff. A session
## taken by another device (INVALID_SESSION) asks Account to sign in again (by itself with "Stay
## signed in"). Its file, user://cloud_save.json, holds only the ids, the revision and the dates.

signal changed
## Both sides changed: the player picks one (keep_this_device() or take_online()).
signal conflict_found
## The profile was replaced by the online one (the screens showing it refresh).
signal applied

const PATH := "user://cloud_save.json"
const VERSION := 1
const ProfileScript := preload("res://src/autoload/profile.gd")

## OFF: no account. IDLE: in step. SYNCING: on its way. OFFLINE: no answer (tried again).
## REFUSED: the server refused (the key's scopes?). CONFLICT: the player chooses. TOO_BIG: the
## profile weighs more than max_bytes. WAITING: a newer online profile waits for the menus.
enum Step { OFF, IDLE, SYNCING, OFFLINE, REFUSED, CONFLICT, TOO_BIG, WAITING }

var state: Step = Step.OFF
## The account player these numbers are for (another account starts again from nothing).
var account_player := ""
var save_id := 0
var base_rev := 0
var dirty := false
## When the last sync ended in step (Unix seconds; 0 never).
var synced_at := 0
## The online copy in a conflict, or waiting for the menus (a CloudSlot; null none).
var online: BoardBackend.CloudSlot
## The server's reason for the last refusal (Talo's errorCode, or "HTTP 403": a scope missing).
var refused_reason := ""
## A run is being played (the profile is never replaced then).
var in_run := false

var store: PersistedQueue
var path: String:
	get:
		return store.path
	set(value):
		store.path = value
var _upload_wait := -1.0
var _applying := false
## Every saved mutation, including one made while an upload is awaiting its answer.
var _mutation := 0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	store = PersistedQueue.new(PATH, VERSION)
	add_child(store)
	store.retry_due.connect(sync)
	load_state()


func _ready() -> void:
	OnlineSession.register(self)
	Events.run_started.connect(func(_run: RunState, _player: Player) -> void: in_run = true)
	Events.run_closed.connect(_out_of_run)
	Events.run_left.connect(func(_summary: RunSummary, for_good: bool) -> void:
		if for_good:
			_out_of_run())
	if Account.is_signed_in():
		state = Step.IDLE
		store.start_in(3.0)


## The tests: no file, nothing known, no account.
func use_for_tests(_fake: BoardBackend = null) -> void:
	path = ""
	reset()


func reset() -> void:
	store.reset()
	state = Step.OFF
	account_player = ""
	save_id = 0
	base_rev = 0
	dirty = false
	synced_at = 0
	online = null
	in_run = false
	_upload_wait = -1.0
	_applying = false


## The config (Account's data).
func config() -> AccountDef:
	return Account.config


## The profile was written: the online copy is behind (sent after upload_delay).
func mark_dirty() -> void:
	if _applying:
		return
	_mutation += 1
	if not dirty:
		dirty = true
		save_state()
	if Account.is_signed_in() and state != Step.CONFLICT:
		_upload_wait = config().upload_delay


func _process(delta: float) -> void:
	if _upload_wait < 0.0 or Profile.held or DebugCheats.debug_run:
		return
	_upload_wait -= delta
	if _upload_wait < 0.0:
		sync()


## Reads the online copy and brings both in step (the rules above). Answers when done.
func sync() -> void:
	if not Account.is_signed_in() or state == Step.CONFLICT or Profile.held or DebugCheats.debug_run:
		return
	_upload_wait = -1.0
	var token := store.begin_flush()
	if token < 0:
		return
	var auth := Account.auth
	_set_state(Step.SYNCING)
	var backend := OnlineSession.backend
	@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
	var listed: BoardBackend.SaveAnswer = await backend.saves_list(auth)
	if not store.end_flush(token) or auth != Account.auth or not Account.is_signed_in():
		return
	if not await _answered(listed) or not store.still(token) or auth != Account.auth:
		return
	var slot: BoardBackend.CloudSlot = null
	for item in listed.saves:
		if item.name == config().save_name and (slot == null or item.id == save_id):
			slot = item
	await _decide(slot)


func _decide(slot: BoardBackend.CloudSlot) -> void:
	if slot == null:
		if Profile.has_progress() or dirty:
			await _upload(0, base_rev + 1)
		else:
			_in_step()
		return
	var rev := revision_of(slot)
	var first := base_rev == 0 or slot.id != save_id
	if first:
		if not Profile.has_progress() or _same_profile(slot):
			_take(slot)
		else:
			_conflict(slot)
		return
	if rev == base_rev:
		if dirty:
			await _upload(slot.id, rev + 1)
		else:
			_in_step()
	elif rev > base_rev:
		if dirty:
			_conflict(slot)
		else:
			_take(slot)
	else:
		await _upload(slot.id, base_rev + 1)  # (the online copy is older than what this device had)


## Conflict: this device's profile goes up, over the online one.
func keep_this_device() -> void:
	if state != Step.CONFLICT or online == null:
		return
	var slot := online
	online = null
	_set_state(Step.SYNCING)
	await _upload(slot.id, maxi(revision_of(slot), base_rev) + 1)


## Conflict: the online profile replaces this device's.
func take_online() -> void:
	if state != Step.CONFLICT or online == null:
		return
	var slot := online
	online = null
	_set_state(Step.IDLE)
	_take(slot)


## What the window shows of a profile (to_data()'s form) and its copy: {runs, souls, depth,
## victories, saved_at (Unix, 0 unknown), platform}.
static func summary(profile: Dictionary, saved_at: int = 0, platform: String = "") -> Dictionary:
	return {
		"runs": int(profile.get("runs", 0)), "souls": int(profile.get("souls", 0)),
		"depth": maxi(int(profile.get("deepest", 0)), int(profile.get("best_depth", 0))),
		"victories": int(profile.get("victories", 0)), "saved_at": saved_at, "platform": platform,
	}


## This device's profile and the online one in a conflict.
func local_summary() -> Dictionary:
	return summary(Profile.to_data(), 0, OS.get_name())


func online_summary() -> Dictionary:
	if online == null:
		return {}
	var profile: Variant = online.content.get("profile", {})
	return summary(profile if profile is Dictionary else {}, int(online.content.get("saved_at", 0)), str(online.content.get("platform", "")))


static func revision_of(slot: BoardBackend.CloudSlot) -> int:
	var rev: Variant = slot.content.get("rev", 0) if slot else 0
	return int(rev) if (rev is int or rev is float) else 0


## The account deleted: what was known of its save forgotten (the profile stays here).
func forget() -> void:
	store.reset()
	account_player = ""
	save_id = 0
	base_rev = 0
	online = null
	_upload_wait = -1.0
	_set_state(Step.OFF)
	save_state()


# --- Inside ---------------------------------------------------------------------------

## A server's answer handled; false when the sync stops there (offline, refused, the session
## gone: signed in again by itself and tried once more, or signed out).
func _answered(answer: BoardBackend.SaveAnswer) -> bool:
	match answer.status:
		BoardBackend.Status.OK:
			store.succeeded()
			return true
		BoardBackend.Status.OFFLINE:
			_set_state(Step.OFFLINE)
			store.retry_later(config().retry_seconds, OnlineSession.max_backoff())
			return false
		BoardBackend.Status.UNAVAILABLE:
			_set_state(Step.OFF)
			return false
	if answer.error == "INVALID_SESSION" or answer.error == "MISSING_SESSION":
		_set_state(Step.IDLE)
		if await Account.session_refused():
			store.start_in(0.1)  # (signed in again: the sync once more)
		return false
	refused_reason = answer.error
	_set_state(Step.REFUSED)
	store.retry_later(config().retry_seconds, OnlineSession.max_backoff())
	return false


func _upload(slot_id: int, rev: int) -> void:
	if not Account.is_signed_in() or Profile.held or DebugCheats.debug_run:
		return
	var auth := Account.auth
	var mutation := _mutation
	var content := {
		"rev": rev, "saved_at": OnlineSession.now(), "platform": OS.get_name(),
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"profile": Profile.to_data().duplicate(true),
	}
	if JSON.stringify(content).to_utf8_buffer().size() > config().max_bytes:
		_set_state(Step.TOO_BIG)
		return
	var token := store.begin_flush()
	if token < 0:
		return
	var backend := OnlineSession.backend
	var answer: BoardBackend.SaveAnswer
	if slot_id > 0:
		@warning_ignore("redundant_await")
		answer = await backend.save_update(auth, slot_id, content)
	else:
		@warning_ignore("redundant_await")
		answer = await backend.save_create(auth, config().save_name, content)
	if not store.end_flush(token) or auth != Account.auth or not Account.is_signed_in():
		return
	if answer.status == BoardBackend.Status.REJECTED and slot_id > 0 and (answer.error.is_empty() or answer.error == "HTTP 404"):
		# (that save is gone from the server: made again at the next sync)
		save_id = 0
		base_rev = 0
	if not await _answered(answer) or not store.still(token) or auth != Account.auth:
		return
	save_id = answer.slot.id
	base_rev = rev
	dirty = _mutation != mutation
	if dirty:
		_upload_wait = config().upload_delay
	_in_step()


func _take(slot: BoardBackend.CloudSlot) -> void:
	if not Account.is_signed_in():
		return
	if in_run or Profile.held or DebugCheats.debug_run:
		online = slot
		_set_state(Step.WAITING)
		return
	var profile: Variant = slot.content.get("profile")
	_applying = true
	var ok := Profile.from_data(profile)
	_applying = false
	if not ok:
		_set_state(Step.REFUSED)  # (not a profile this game can read: left online as it is)
		return
	online = null
	save_id = slot.id
	base_rev = revision_of(slot)
	dirty = false
	_in_step()
	applied.emit()


func _conflict(slot: BoardBackend.CloudSlot) -> void:
	online = slot
	_set_state(Step.CONFLICT)
	conflict_found.emit()


## Online and here hold the same profile (a first sign-in on a device already in step).
func _same_profile(slot: BoardBackend.CloudSlot) -> bool:
	var profile: Variant = slot.content.get("profile")
	if not ProfileScript.is_valid_data(profile):
		return false
	# Read as this game reads a profile (a copy of the Profile script, never added to the tree),
	# so what reading changes (old fields, numbers) doesn't count as a difference.
	var reader: Node = (Profile.get_script() as GDScript).new()
	reader.set("save_path", "")
	reader.call("_read", profile)
	var same := _canonical(reader.call("to_data")) == _canonical(Profile.to_data())
	reader.free()
	return same


## A profile as one text, its keys sorted and its numbers as JSON reads them.
static func _canonical(profile: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(profile)), "", true)


func _in_step() -> void:
	synced_at = OnlineSession.now()
	save_state()
	_set_state(Step.IDLE)


func _set_state(new_state: Step) -> void:
	state = new_state
	save_state()
	changed.emit()


func on_signed_in() -> void:
	store.reset()
	if Account.auth.player_id != account_player:
		account_player = Account.auth.player_id
		save_id = 0
		base_rev = 0
	online = null
	_set_state(Step.IDLE)
	sync()


func on_signed_out() -> void:
	store.reset()
	_upload_wait = -1.0
	online = null
	_set_state(Step.OFF)


func _out_of_run() -> void:
	in_run = false
	if state == Step.WAITING and online:
		var slot := online
		online = null
		if dirty:
			_conflict(slot)
		else:
			_take(slot)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			if dirty and Account.is_signed_in():
				sync()
		NOTIFICATION_APPLICATION_RESUMED:
			if Account.is_signed_in():
				sync()


# --- The file ------------------------------------------------------------------

func save_state() -> void:
	store.write({ "player": account_player, "save_id": save_id, "base_rev": base_rev, "dirty": dirty, "synced_at": synced_at })


func load_state() -> void:
	var data := store.read()
	account_player = str(data.get("player", ""))
	save_id = int(data.get("save_id", 0))
	base_rev = int(data.get("base_rev", 0))
	dirty = bool(data.get("dirty", false))
	synced_at = int(data.get("synced_at", 0))
