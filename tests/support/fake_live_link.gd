class_name FakeLiveLink
extends LiveLink
## Talo's live connection in memory (Presence's tests; FakeBoardBackend.open_live()): opens on
## the first poll unless the server is down, says "v1.connected", takes the player's identify with
## the token its server gave, and keeps the sessions on that server (FakeBoardBackend.live_*).

var server: FakeBoardBackend
var url := ""
## Every text the game sent.
var sent: Array[String] = []

var _state: LiveLink.LinkState = LiveLink.LinkState.CLOSED
var _inbox: Array[String] = []
var _live := false


func _init(on: FakeBoardBackend) -> void:
	server = on


func open(to_url: String) -> Error:
	url = to_url
	_state = LiveLink.LinkState.CONNECTING
	return OK


func poll() -> void:
	if _state == LiveLink.LinkState.CONNECTING and server.online and server.live_answers:
		_state = LiveLink.LinkState.OPEN
		_inbox.append(JSON.stringify({ "res": "v1.connected", "data": {} }))


func state() -> LiveLink.LinkState:
	return _state


func receive() -> String:
	return _inbox.pop_front() if not _inbox.is_empty() else ""


func send(text: String) -> Error:
	sent.append(text)
	var message: Variant = JSON.parse_string(text)
	if not message is Dictionary or str((message as Dictionary).get("req", "")) != "v1.players.identify":
		return OK
	var data: Dictionary = (message as Dictionary).get("data", {})
	if str(data.get("socketToken", "")) != server.live_token or int(data.get("playerAliasId", 0)) != server.alias_id():
		_inbox.append(JSON.stringify({ "res": "v1.error", "data": { "errorCode": "INVALID_SOCKET_TOKEN" } }))
		return OK
	_live = true
	server.live_started += 1
	server.live_online = true
	_inbox.append(JSON.stringify({ "res": "v1.players.identify.success", "data": {} }))
	return OK


func close() -> void:
	drop()


## The connection gone (closed by the game, or lost: the network): the session ends on the server.
func drop() -> void:
	if _state == LiveLink.LinkState.CLOSED:
		return
	_state = LiveLink.LinkState.CLOSED
	if _live:
		_live = false
		server.live_ended += 1
		server.live_online = false
