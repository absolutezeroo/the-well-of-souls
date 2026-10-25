extends Node
## The live session and presence (autoload "Presence"; docs/online.md "Sessions and presence"):
## while the gameplay statistics are allowed (OnlineSession.statistics_allowed(): the player's
## consent, a server, the remote kill switch), the game keeps one live connection open to Talo
## (a WebSocket, LiveLink). The player identified on it, Talo starts a session and shows them
## online; the connection gone, it ends the session (its length) and shows them offline. That is
## what fills the dashboard's "Total sessions", "Average session duration" and "Online players".
##
## Its steps: the player identified (OnlineSession.identity()), a one-use ticket and the player's
## socket token asked (BoardBackend.live_access()), the connection opened with the ticket, then,
## once the server says "v1.connected", the player identified on it ("v1.players.identify");
## "v1.players.identify.success": live. The app put in the background (a phone) or closed: the
## connection is closed, so the session ends there; back: a new one. A failure or a connection
## lost tries again after PresenceDef.retry_seconds, doubled per failure. Consent taken back, the
## online data deleted or the kill switch: closed within check_seconds. Nothing else goes on it,
## and the game never waits for it.
##
## While live, a **custom status** says where the player is (PresenceDef: "In the menus", "Floor
## 7", "Dawn Knell, floor 3"; PUT /v1/players/presence), sent when it changes, at most every
## status_min_seconds (only the last change goes).

## The player is shown online (a session started).
signal went_live
## The session ended (closed, lost, or the consent taken back).
signal went_off

const DEFS := "res://data/online/presence.tres"

## OFF: no connection. ASKING: the ticket asked. CONNECTING: opening. IDENTIFYING: open, the
## player sent. LIVE: a session runs.
enum Phase { OFF, ASKING, CONNECTING, IDENTIFYING, LIVE }

var config: PresenceDef
var phase := Phase.OFF
## The app is in the background (or closing): no session.
var in_background := false
## Sessions started since launch (the tests count them).
var sessions := 0
## Where the player is now (the status to show) and the last one the server took.
var status := ""
var sent_status := ""
## Statuses the server took (the tests count them).
var statuses_sent := 0

var _link: LiveLink
var _token := ""
## Seconds in the current phase (its timeout).
var _since := 0.0
## Seconds before a new try may start.
var _wait := 0.0
## Seconds before the next look at whether a connection should be open.
var _check := 0.0
var _failures := 0
## Bumped when it stops: a step answered after that is dropped.
var _generation := 0
## Seconds before a status may be sent again.
var _status_wait := 0.0
var _sending_status := false
## The run being played is a Dawn Knell.
var _daily := false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # (the game paused: still online)
	config = load(DEFS) as PresenceDef


func _ready() -> void:
	OnlineSession.register(self)
	Privacy.changed.connect(_on_privacy_changed)
	OnlineSession.identity_forgotten.connect(_on_identity_forgotten)
	Events.run_started.connect(func(run: RunState, _player: Player) -> void: _daily = run.daily_day >= 0)
	Events.floor_entered.connect(_on_floor_entered)
	Events.run_ended.connect(func(_summary: RunSummary) -> void: show_menus())
	Events.run_left.connect(func(_summary: RunSummary, for_good: bool) -> void:
		if for_good:
			show_menus())
	show_menus()


## The tests: closed, nothing counted, nothing waited for, in the foreground.
func use_for_tests() -> void:
	stop()
	sessions = 0
	_failures = 0
	_wait = 0.0
	_check = 0.0
	in_background = false
	statuses_sent = 0
	sent_status = ""
	_status_wait = 0.0
	_daily = false
	show_menus()


## A connection should be open now.
func wanted() -> bool:
	return config != null and config.enabled and not in_background and OnlineSession.statistics_allowed()


func is_live() -> bool:
	return phase == Phase.LIVE


## The player is out of a run.
func show_menus() -> void:
	set_status(config.menus_status if config else "")


func _on_floor_entered(world: World) -> void:
	if config and world:
		set_status((config.daily_status if _daily else config.floor_status).format({ "depth": world.depth }))


## Where the player is now: sent when live (now or once the wait is over).
func set_status(text: String) -> void:
	status = text


func _process(delta: float) -> void:
	if not wanted():
		if phase != Phase.OFF:
			stop()
		return
	if _link:
		_poll(delta)
	_status_wait -= delta
	if phase == Phase.LIVE and status != sent_status and _status_wait <= 0.0 and not _sending_status and config.send_status:
		_send_status()
	_wait -= delta
	_check -= delta
	if _check > 0.0:
		return
	_check = config.check_seconds if config else 2.0
	if not wanted():
		if phase != Phase.OFF:
			stop()
		return
	if phase == Phase.OFF and _wait <= 0.0:
		start()


## Opens the connection (the player identified first). Answers at once; the steps follow.
func start() -> void:
	if phase != Phase.OFF or not wanted():
		return
	phase = Phase.ASKING
	_since = 0.0
	var generation := _generation
	var identified: BoardBackend.Status = await OnlineSession.identity()
	if generation != _generation or not wanted():
		return
	if identified != BoardBackend.Status.OK:
		_failed()
		return
	var backend := OnlineSession.backend
	@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
	var access: BoardBackend.LiveAccess = await backend.live_access(func() -> bool: return generation == _generation and wanted())
	if generation != _generation:
		return
	if access.status != BoardBackend.Status.OK or access.url.is_empty() or not wanted():
		_failed()
		return
	_token = access.token
	_link = backend.open_live()
	if _link == null or _link.open(access.url) != OK:
		_link = null
		_failed()
		return
	phase = Phase.CONNECTING
	_since = 0.0


## Closed: the session ends (the server sees the connection go).
func stop() -> void:
	_generation += 1
	var was_live := phase == Phase.LIVE
	if _link:
		_link.close()
	_link = null
	_token = ""
	sent_status = ""  # (a new session: its status sent again)
	_sending_status = false
	phase = Phase.OFF
	if was_live:
		went_off.emit()


## The player forgotten: their session ends now; the next one (if still allowed) is the new
## player's.
func _on_identity_forgotten() -> void:
	if phase != Phase.OFF:
		stop()
		_wait = 0.0


func _poll(delta: float) -> void:
	_link.poll()
	_since += delta
	var state := _link.state()
	if state == LiveLink.LinkState.CLOSED or state == LiveLink.LinkState.CLOSING:
		_lost()
		return
	if state == LiveLink.LinkState.OPEN:
		while _link:
			var text := _link.receive()
			if text.is_empty():
				break
			_on_message(text)
	if _link and phase != Phase.LIVE and _since > config.connect_timeout:
		_failed()


## A message from the server: {"res": name, "data": {...}}. The rest (other players' presence,
## channels) is not the game's.
func _on_message(text: String) -> void:
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return
	match str((json.data as Dictionary).get("res", "")):
		"v1.connected":
			if phase == Phase.CONNECTING:
				phase = Phase.IDENTIFYING
				_link.send(JSON.stringify({ "req": "v1.players.identify", "data": {
					"playerAliasId": OnlineSession.backend.alias_id(),
					"socketToken": _token,
				} }))
		"v1.players.identify.success":
			if phase == Phase.IDENTIFYING:
				phase = Phase.LIVE
				_failures = 0
				sessions += 1
				went_live.emit()
		"v1.error":
			if phase != Phase.LIVE:
				_failed()  # (a token refused: asked again at the next try)


func _send_status() -> void:
	if not wanted() or phase != Phase.LIVE:
		return
	var text := status
	var generation := _generation
	_sending_status = true
	_status_wait = config.status_min_seconds
	@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
	var answer: BoardBackend.Status = await OnlineSession.backend.set_presence_status(text)
	_sending_status = false
	if generation != _generation:
		return
	if answer == BoardBackend.Status.OK:
		statuses_sent += 1
	if answer == BoardBackend.Status.OK or answer == BoardBackend.Status.REJECTED:
		sent_status = text  # (refused for good, e.g. the key's scope missing: not asked again for it)


## A try failed: again after retry_seconds, doubled per failure up to the session's max backoff.
func _failed() -> void:
	stop()
	_failures += 1
	var factor := minf(pow(2.0, _failures - 1), OnlineSession.max_backoff())
	_wait = config.retry_seconds * factor


## The connection went (the network, the server): a live one is opened again after
## retry_seconds; one that never got live counts as a failure.
func _lost() -> void:
	if phase == Phase.LIVE:
		stop()
		_failures = 0
		_wait = config.retry_seconds
	else:
		_failed()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			# To the background (a phone, maybe killed there) or closing: the session ends now.
			in_background = true
			stop()
		NOTIFICATION_APPLICATION_RESUMED:
			# Back: a new session at once.
			in_background = false
			_wait = 0.0
			_check = 0.0


## A withdrawal closes the link immediately, even between two network steps.
func _on_privacy_changed() -> void:
	if not wanted():
		stop()
