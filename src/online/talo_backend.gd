class_name TaloBackend
extends BoardBackend
## The online leaderboards and the gameplay statistics on Talo (https://trytalo.com), through its
## REST API with HTTPRequest (docs/online.md says why not its Godot plugin). Its endpoints:
## identify a player, set its name (a player prop, the game's "display name prop key"), add an
## entry, list entries, send events, and the world counters (add to a game stat, read them all,
## read the player's own). Nothing private ever goes in a player prop: Talo's API
## shows them to anyone reading a board.
##
## The access key is never in git: it is read from the environment (TALO_ACCESS_KEY) or from
## res://online/talo.cfg, a file git ignores, packed into the builds by the presets'
## include_filter (online/talo.cfg.example shows its form). Without one the game is offline.

const LeaderboardsScript := preload("res://src/autoload/leaderboards.gd")  # its static helpers are called on the script, not the autoload

const KEY_FILE := "res://online/talo.cfg"
const KEY_ENV := "TALO_ACCESS_KEY"
const DEFAULT_URL := "https://api.trytalo.com"
## Players are identified by a random id made on the device, under this service name.
const SERVICE := "device"
## The player prop holding the pseudonym (set it as the game's display name prop key).
const NAME_PROP := "name"
## Seconds a request may take.
const TIMEOUT := 15.0

## The server's answer to the last send_events(): a list of errors per event (empty lists: all taken).
var last_event_errors: Array = []
## A debug build's data: Talo keeps it apart in the dashboard as dev data (X-Talo-Dev-Build), and
## shows its own entries back. Set by OnlineSession from its release_mode.
var dev_build := OS.is_debug_build()

var _key := ""
var _url := DEFAULT_URL
var _alias_id := 0
var _player_id := ""


## Reads the key (read_key()) unless one is given (a smoke test with its own).
func _init(key: String = "", url: String = "") -> void:
	name = "Talo"
	if key.is_empty():
		var found := read_key()
		key = found.key
		url = found.url if url.is_empty() else url
	_key = key.strip_edges()
	_url = (url if not url.is_empty() else DEFAULT_URL).trim_suffix("/")


## {key, url} from the environment or KEY_FILE (empty key: none). Never printed anywhere.
static func read_key(path: String = KEY_FILE) -> Dictionary:
	var key := OS.get_environment(KEY_ENV).strip_edges()
	var url := ""
	if key.is_empty() and FileAccess.file_exists(path):
		var file := ConfigFile.new()
		if file.load(path) == OK:
			key = str(file.get_value("talo", "access_key", "")).strip_edges()
			url = str(file.get_value("talo", "api_url", ""))
	return { "key": key, "url": url }


func is_configured() -> bool:
	return not _key.is_empty()


func alias_id() -> int:
	return _alias_id


func player_id() -> String:
	return _player_id


func forget() -> void:
	_alias_id = 0
	_player_id = ""


## POST /v1/events (the X-Talo-Alias header names the player). The server answers 200 with an
## error list per event: an event it refused (a prop too long...) is never resent.
func send_events(events: Array[Dictionary]) -> Status:
	if _alias_id == 0:
		return Status.OFFLINE
	var list: Array = []
	for event in events:
		var props: Array = []
		var event_props: Dictionary = event.get("props", {})
		for key: String in event_props:
			props.append({ "key": key, "value": str(event_props[key]) })
		list.append({ "name": str(event.get("name", "")), "props": props, "timestamp": int(event.get("timestamp", 0)) })
	var answer := await _request(HTTPClient.METHOD_POST, "/v1/events", { "events": list })
	last_event_errors = []
	if answer.status == Status.OK and answer.body is Dictionary and (answer.body as Dictionary).get("errors") is Array:
		last_event_errors = (answer.body as Dictionary).errors
	return answer.status


## POST /v1/game-feedback/categories/{internalName} {comment, props} with the X-Talo-Alias
## header. 400 (a prop refused): REJECTED, never resent. 404 (the category isn't in the dashboard
## yet): OFFLINE, the message waits until it is made rather than being lost. An "anonymised"
## category (set in the dashboard) hides the player in what the dashboard shows.
func send_feedback(internal_name: String, comment: String, props: Dictionary) -> Status:
	if _alias_id == 0:
		return Status.OFFLINE
	var list: Array = []
	for key: String in props:
		list.append({ "key": key, "value": str(props[key]) })
	var answer := await _request(HTTPClient.METHOD_POST, "/v1/game-feedback/categories/%s" % internal_name.uri_encode(), { "comment": comment, "props": list })
	return Status.OFFLINE if int(answer.code) == 404 else answer.status


## PUT /v1/game-stats/{internalName} {change} with the X-Talo-Alias header. The server answers
## 400 for a change past the stat's maxChange or too soon after the last (minTimeBetweenUpdates):
## REJECTED, never resent as it is.
func add_to_stat(internal_name: String, change: int) -> Status:
	if _alias_id == 0:
		return Status.OFFLINE
	var answer := await _request(HTTPClient.METHOD_PUT, "/v1/game-stats/%s" % internal_name.uri_encode(), { "change": change })
	return answer.status


## GET /v1/game-stats: every stat of the game, with its globalValue (a global one's world total).
func fetch_world_stats() -> BoardBackend.StatValues:
	var answer := await _request(HTTPClient.METHOD_GET, "/v1/game-stats")
	return _stat_values(answer, "stats", func(item: Dictionary) -> Array:
		return [str(item.get("internalName", "")), item.get("globalValue", 0.0)] if bool(item.get("global", false)) else [])


## GET /v1/game-stats/player-stats: the player's own value of each stat they added to.
func fetch_my_stats() -> BoardBackend.StatValues:
	if _alias_id == 0:
		var none := BoardBackend.StatValues.new()
		none.status = Status.OFFLINE
		return none
	var answer := await _request(HTTPClient.METHOD_GET, "/v1/game-stats/player-stats")
	return _stat_values(answer, "playerStats", func(item: Dictionary) -> Array:
		var stat: Variant = item.get("stat")
		return [str((stat as Dictionary).get("internalName", "")), item.get("value", 0.0)] if stat is Dictionary else [])


## The answer's list `key` read by `pick` (an item -> [internal name, value], or [] to skip it).
static func _stat_values(answer: Dictionary, key: String, pick: Callable) -> BoardBackend.StatValues:
	var result := BoardBackend.StatValues.new()
	result.status = answer.status
	if answer.status != Status.OK:
		return result
	var list: Variant = (answer.body as Dictionary).get(key) if answer.body is Dictionary else null
	if not list is Array:
		result.status = Status.REJECTED
		return result
	for item: Variant in list:
		if not item is Dictionary:
			continue
		var pair: Array = pick.call(item)
		if pair.size() == 2 and not str(pair[0]).is_empty():
			result.values[str(pair[0])] = float(pair[1]) if (pair[1] is float or pair[1] is int) else 0.0
	return result


## GET /v1/game-config (the key's read:gameConfig scope): the game's live config, {config: [{key,
## value}]}. Sent without the player's headers: reading the settings identifies no one.
func fetch_config() -> BoardBackend.ConfigValues:
	var answer := await _request(HTTPClient.METHOD_GET, "/v1/game-config", null, true)
	var result := BoardBackend.ConfigValues.new()
	result.status = answer.status
	if answer.status != Status.OK:
		return result
	var list: Variant = (answer.body as Dictionary).get("config") if answer.body is Dictionary else null
	if not list is Array:
		result.status = Status.REJECTED
		return result
	for item: Variant in list:
		if item is Dictionary and (item as Dictionary).get("key") is String:
			var value: Variant = (item as Dictionary).get("value")
			result.values[str((item as Dictionary).key)] = str(value) if value != null else ""
	return result


func identify(device_id: String) -> Status:
	var answer := await _request(HTTPClient.METHOD_GET, "/v1/players/identify?service=%s&identifier=%s" % [SERVICE, device_id.uri_encode()])
	if answer.status != Status.OK:
		return answer.status
	var alias: Variant = (answer.body as Dictionary).get("alias") if answer.body is Dictionary else null
	if not alias is Dictionary or not (alias as Dictionary).get("player") is Dictionary:
		return Status.REJECTED
	_alias_id = int((alias as Dictionary).get("id", 0))
	_player_id = str(((alias as Dictionary).player as Dictionary).get("id", ""))
	return Status.OK if _alias_id > 0 and not _player_id.is_empty() else Status.REJECTED


## The live connection's ticket (POST /v1/socket-tickets: valid five minutes, once) and the
## player's socket token (POST /v1/players/socket-token: a new one each time, valid an hour).
## The ticket carries the dev build flag, so a debug build's sessions are dev data too.
func live_access() -> BoardBackend.LiveAccess:
	var access := BoardBackend.LiveAccess.new()
	if _alias_id <= 0:
		access.status = Status.REJECTED
		return access
	var ticket := await _request(HTTPClient.METHOD_POST, "/v1/socket-tickets", {})
	var ticket_text := str((ticket.body as Dictionary).get("ticket", "")) if ticket.body is Dictionary else ""
	if ticket.status != Status.OK or ticket_text.is_empty():
		access.status = ticket.status if ticket.status != Status.OK else Status.REJECTED
		return access
	var token := await _request(HTTPClient.METHOD_POST, "/v1/players/socket-token", {})
	var token_text := str((token.body as Dictionary).get("socketToken", "")) if token.body is Dictionary else ""
	if token.status != Status.OK or token_text.is_empty():
		access.status = token.status if token.status != Status.OK else Status.REJECTED
		return access
	access.status = Status.OK
	access.url = socket_url() + "/?ticket=" + ticket_text.uri_encode()
	access.token = token_text
	return access


## The live connection's server: the API's address on WebSocket (https -> wss).
func socket_url() -> String:
	if _url.begins_with("https://"):
		return "wss://" + _url.trim_prefix("https://")
	if _url.begins_with("http://"):
		return "ws://" + _url.trim_prefix("http://")
	return _url


func set_pseudonym(pseudonym: String) -> Status:
	if _player_id.is_empty():
		return Status.OFFLINE
	var answer := await _request(HTTPClient.METHOD_PATCH, "/v1/players/%s" % _player_id.uri_encode(), {
		"props": [{ "key": NAME_PROP, "value": pseudonym }],
	})
	return answer.status


func submit(board: LeaderboardDef, score: float, _period_key: String, props: Dictionary) -> BoardBackend.Sent:
	var sent := BoardBackend.Sent.new()
	if _alias_id == 0:
		sent.status = Status.OFFLINE
		return sent
	var list: Array = []
	for key: String in props:
		list.append({ "key": key, "value": str(props[key]) })
	var answer := await _request(HTTPClient.METHOD_POST, "/v1/leaderboards/%s/entries" % board.talo_name.uri_encode(), {
		"score": score,
		"props": list,
	})
	sent.status = answer.status
	if answer.status == Status.OK and answer.body is Dictionary and (answer.body as Dictionary).get("entry") is Dictionary:
		sent.rank = int(((answer.body as Dictionary).entry as Dictionary).get("position", -1)) + 1
	return sent


func fetch(board: LeaderboardDef, period_key: String, past: bool, page: int) -> BoardBackend.Page:
	return await _list(board, period_key, past, "page=%d" % page)


func fetch_mine(board: LeaderboardDef, period_key: String, past: bool) -> BoardBackend.Page:
	if _alias_id == 0:
		var none := BoardBackend.Page.new()
		none.status = Status.OFFLINE
		return none
	var mine := await _list(board, period_key, past, "page=0&aliasId=%d" % _alias_id)
	# The server ranks the player among every entry it keeps: archived ones are every past day's.
	mine.ranks_reliable = not past
	return mine


func _list(board: LeaderboardDef, period_key: String, past: bool, query: String) -> BoardBackend.Page:
	var path := "/v1/leaderboards/%s/entries?%s" % [board.talo_name.uri_encode(), query]
	if past:
		path += "&withDeleted=1"
	if not period_key.is_empty():
		path += "&propKey=%s&propValue=%s" % [LeaderboardsScript.period_prop(board), period_key.uri_encode()]
	var answer := await _request(HTTPClient.METHOD_GET, path)
	var page := BoardBackend.Page.new()
	page.status = answer.status
	if answer.status != Status.OK or not answer.body is Dictionary:
		if answer.status == Status.OK:
			page.status = Status.REJECTED
		return page
	var body := answer.body as Dictionary
	page.total = int(body.get("count", 0))
	page.last_page = bool(body.get("isLastPage", true))
	var entries: Variant = body.get("entries", [])
	if entries is Array:
		for data: Variant in entries:
			if data is Dictionary:
				page.entries.append(_entry(data))
	return page


## A line of a board from the server's entry.
static func _entry(data: Dictionary) -> BoardBackend.Entry:
	var entry := BoardBackend.Entry.new()
	entry.rank = int(data.get("position", 0)) + 1
	entry.score = float(data.get("score", 0.0))
	var props_list: Variant = data.get("props", [])
	if props_list is Array:
		for prop: Variant in props_list:
			if prop is Dictionary:
				entry.props[str((prop as Dictionary).get("key", ""))] = str((prop as Dictionary).get("value", ""))
	var alias: Variant = data.get("playerAlias", {})
	if alias is Dictionary:
		entry.alias_id = int((alias as Dictionary).get("id", 0))
		entry.identifier = str((alias as Dictionary).get("identifier", ""))
		var shown := str((alias as Dictionary).get("displayName", ""))
		# No display name prop key in the dashboard: Talo shows the device id; the entry's own
		# copy of the name then.
		if shown.is_empty() or shown == str((alias as Dictionary).get("identifier", "")):
			shown = str(entry.props.get(NAME_PROP, ""))
		entry.name = shown
	return entry


## One request: {status, code, body (parsed JSON or null)}. `anonymous`: without the identified
## player's headers (the remote settings' read).
func _request(method: HTTPClient.Method, path: String, body: Variant = null, anonymous: bool = false) -> Dictionary:
	var headers := PackedStringArray([
		"Authorization: Bearer %s" % _key,
		"Content-Type: application/json",
		"Accept: application/json",
		# A build from the editor (debug) is development data: kept apart in the dashboard, and
		# it sees its own entries.
		"X-Talo-Dev-Build: %s" % ("1" if dev_build else "0"),
		"X-Talo-Include-Dev-Data: %s" % ("1" if dev_build else "0"),
	])
	if _alias_id > 0 and not anonymous:
		headers.append("X-Talo-Alias: %d" % _alias_id)
		headers.append("X-Talo-Player: %s" % _player_id)
	var result: Array = await _send(method, _url + path, headers, JSON.stringify(body) if body != null else "")
	return answer_of(int(result[0]), int(result[1]), result[2] as PackedByteArray)


## The HTTP exchange itself: [HTTPRequest.Result, response code, body bytes]. The tests replace
## it (a subclass answering canned Talo bodies: TaloContractTests), so everything else here runs
## as it does against the real server.
func _send(method: HTTPClient.Method, url: String, headers: PackedStringArray, body: String) -> Array:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	http.accept_gzip = true
	add_child(http)
	var error := http.request(url, headers, method, body)
	if error != OK:
		http.queue_free()
		return [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray()]
	var result: Array = await http.request_completed
	http.queue_free()
	return [result[0], result[1], result[3]]


## What an answer means: {status, code, body}. No answer, a 429 (too many requests) or a 5xx:
## OFFLINE (try again later); another 4xx: REJECTED (never resent as it is). The body is parsed
## without a word in the log when it isn't JSON (a captive portal's or a proxy's page): null.
static func answer_of(result: int, code: int, bytes: PackedByteArray) -> Dictionary:
	var status := Status.OK
	if result != HTTPRequest.RESULT_SUCCESS or code == 0 or code == 429 or code >= 500:
		status = Status.OFFLINE
	elif code >= 400:
		status = Status.REJECTED
	return { "status": status, "code": code, "body": parse_body(bytes) }


## `bytes` as JSON, or null (empty, or not JSON: JSON.parse_string() would print an engine error).
static func parse_body(bytes: PackedByteArray) -> Variant:
	if bytes.is_empty():
		return null
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		return null
	return json.data
