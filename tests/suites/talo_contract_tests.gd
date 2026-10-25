class_name TaloContractTests
extends TestSuite
## TaloBackend against canned Talo answers (a transport in memory replacing its HTTP exchange,
## TaloBackend._send()): never the network. run_unit(): what an HTTP status means (429 and 5xx:
## try later; other 4xx: refused), bodies that aren't JSON (a captive portal's page) read without
## an engine error, identify's parsing, the feedback's 404 rule, the stats' and config's lists,
## a board line's name, the live session's ticket and token, the headers (dev build, the player), the period's query, the key's file.


## A TaloBackend whose requests are answered from `answers` (the first whose path part is in the
## URL wins) and recorded in `requests`.
class FakeTalo:
	extends TaloBackend
	## [url part, code, body text] in the order they are tried.
	var answers: Array = []
	## Every request: {method, url, headers, body}.
	var requests: Array[Dictionary] = []
	## The HTTPRequest result every answer has (RESULT_SUCCESS: an answer came).
	var result := HTTPRequest.RESULT_SUCCESS

	func _init() -> void:
		super("test-key", "https://talo.test/")

	func answer(url_part: String, code: int, body: String) -> void:
		answers.push_front([url_part, code, body])

	func _send(method: HTTPClient.Method, url: String, headers: PackedStringArray, body: String) -> Array:
		requests.append({ "method": method, "url": url, "headers": headers, "body": body })
		for item: Array in answers:
			if url.contains(str(item[0])):
				return [result, int(item[1]), str(item[2]).to_utf8_buffer()]
		return [result, 404, PackedByteArray()]


func run_unit() -> void:
	_test_status_mapping()
	_test_bodies()
	await _test_identify()
	await _test_feedback_rule()
	await _test_events_and_stats()
	await _test_config()
	await _test_boards()
	await _test_live()
	_test_key_file()


func _talo() -> FakeTalo:
	var talo := FakeTalo.new()
	talo.dev_build = false
	return talo


func _header(request: Dictionary, prefix: String) -> String:
	for line: String in request.headers:
		if line.begins_with(prefix):
			return line
	return ""


func _identified() -> FakeTalo:
	var talo := _talo()
	talo.answer("/v1/players/identify", 200, JSON.stringify({ "alias": { "id": 7, "identifier": "dev", "player": { "id": "p-1" } } }))
	return talo


func _test_status_mapping() -> void:
	var ok := HTTPRequest.RESULT_SUCCESS
	var cases := [
		[ok, 200, BoardBackend.Status.OK], [ok, 201, BoardBackend.Status.OK], [ok, 0, BoardBackend.Status.OFFLINE],
		[ok, 429, BoardBackend.Status.OFFLINE], [ok, 500, BoardBackend.Status.OFFLINE], [ok, 503, BoardBackend.Status.OFFLINE],
		[ok, 400, BoardBackend.Status.REJECTED], [ok, 401, BoardBackend.Status.REJECTED], [ok, 403, BoardBackend.Status.REJECTED],
		[ok, 404, BoardBackend.Status.REJECTED], [HTTPRequest.RESULT_CANT_CONNECT, 0, BoardBackend.Status.OFFLINE],
		[HTTPRequest.RESULT_TIMEOUT, 0, BoardBackend.Status.OFFLINE], [HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR, 0, BoardBackend.Status.OFFLINE],
	]
	var wrong := PackedStringArray()
	for item: Array in cases:
		var answer := TaloBackend.answer_of(int(item[0]), int(item[1]), PackedByteArray())
		if answer.status != item[2] or int(answer.code) != int(item[1]):
			wrong.append("%s/%s -> %s" % [item[0], item[1], answer.status])
	check(wrong.is_empty(), "Talo's statuses: 429, 5xx and no answer are OFFLINE (try later), another 4xx REJECTED, 2xx OK (%s)" % [wrong])


func _test_bodies() -> void:
	check(TaloBackend.parse_body(PackedByteArray()) == null, "an empty body is null")
	check(TaloBackend.parse_body("<html><body>Sign in to the Wi-Fi</body></html>".to_utf8_buffer()) == null, "a captive portal's page is null (read without an engine error)")
	check(TaloBackend.parse_body("{\"a\": 1".to_utf8_buffer()) == null, "a body cut short is null")
	var parsed: Variant = TaloBackend.parse_body("{\"a\": [1, 2]}".to_utf8_buffer())
	check(parsed is Dictionary and (parsed as Dictionary).a.size() == 2, "a JSON body is read")


func _test_identify() -> void:
	var talo := _identified()
	check(await talo.identify("dev/1") == BoardBackend.Status.OK and talo.alias_id() == 7 and talo.player_id() == "p-1", "identify: the alias and its player read")
	var request: Dictionary = talo.requests[0]
	check(str(request.url).begins_with("https://talo.test/v1/players/identify?service=device&identifier=dev%2F1"), "identify: the device's id under the 'device' service, escaped (%s)" % request.url)
	check(_header(request, "Authorization:") == "Authorization: Bearer test-key" and _header(request, "X-Talo-Dev-Build:") == "X-Talo-Dev-Build: 0", "the key goes as a bearer; a release build's data is not dev data")
	check(_header(request, "X-Talo-Alias:").is_empty(), "...and no player before one is identified")
	talo.free()
	talo = _talo()
	talo.answer("/v1/players/identify", 200, "<html>Welcome to the airport Wi-Fi</html>")
	check(await talo.identify("dev") == BoardBackend.Status.REJECTED and talo.alias_id() == 0, "identify: a 200 that isn't Talo's answer (a captive portal) is refused, nothing kept")
	talo.answers.clear()
	talo.answer("/v1/players/identify", 200, JSON.stringify({ "alias": { "id": 0, "player": { "id": "" } } }))
	check(await talo.identify("dev") == BoardBackend.Status.REJECTED, "identify: an alias without ids is refused")
	talo.answers.clear()
	talo.answer("/v1/players/identify", 503, "")
	check(await talo.identify("dev") == BoardBackend.Status.OFFLINE, "identify: the server down is OFFLINE")
	talo.answers.clear()
	talo.answer("/v1/players/identify", 401, "{\"message\": \"bad key\"}")
	check(await talo.identify("dev") == BoardBackend.Status.REJECTED, "identify: a bad key is REJECTED")
	talo.dev_build = true
	await talo.identify("dev")
	check(_header(talo.requests.back(), "X-Talo-Dev-Build:") == "X-Talo-Dev-Build: 1", "a debug build's data is dev data")
	talo.free()


func _test_feedback_rule() -> void:
	var talo := _talo()
	check(await talo.send_feedback("bug", "x", {}) == BoardBackend.Status.OFFLINE and talo.requests.is_empty(), "feedback: no player yet, nothing sent (OFFLINE)")
	talo.free()
	talo = _identified()
	await talo.identify("dev")
	talo.answer("/v1/game-feedback/categories/bug", 404, "{\"message\": \"Feedback category not found\"}")
	check(await talo.send_feedback("bug", "The door.", { "v": "0.3" }) == BoardBackend.Status.OFFLINE, "feedback: a category not made yet in the dashboard (404) waits (OFFLINE), never lost")
	var request: Dictionary = talo.requests.back()
	check(_header(request, "X-Talo-Alias:") == "X-Talo-Alias: 7" and _header(request, "X-Talo-Player:") == "X-Talo-Player: p-1", "feedback: sent as the identified player")
	var body: Variant = JSON.parse_string(str(request.body))
	check(body is Dictionary and (body as Dictionary).comment == "The door." and (body as Dictionary).props == [{ "key": "v", "value": "0.3" }], "feedback: the words and the props as Talo takes them")
	talo.answers.clear()
	talo.answer("/v1/game-feedback/categories/bug", 400, "{\"errors\": {}}")
	check(await talo.send_feedback("bug", "x", {}) == BoardBackend.Status.REJECTED, "feedback: a refused message (400) is REJECTED, never resent")
	talo.answers.clear()
	talo.answer("/v1/game-feedback/categories/bug", 200, "{}")
	check(await talo.send_feedback("bug", "x", {}) == BoardBackend.Status.OK, "feedback: taken")
	talo.free()


func _test_events_and_stats() -> void:
	var talo := _identified()
	await talo.identify("dev")
	talo.answer("/v1/events", 200, JSON.stringify({ "events": [], "errors": [[], ["prop too long"]] }))
	var events: Array[Dictionary] = [{ "name": "run_end", "props": { "depth": 4 }, "timestamp": 1000 }]
	check(await talo.send_events(events) == BoardBackend.Status.OK and talo.last_event_errors.size() == 2, "events: sent, the server's errors per event kept")
	var sent: Variant = JSON.parse_string(str(talo.requests.back().body))
	check(sent is Dictionary and (sent as Dictionary).events[0].props == [{ "key": "depth", "value": "4" }] and int((sent as Dictionary).events[0].timestamp) == 1000, "events: props as strings, the timestamp kept")
	talo.answer("/v1/game-stats/demons-slain", 400, "{\"message\": \"maxChange\"}")
	check(await talo.add_to_stat("demons-slain", 999999) == BoardBackend.Status.REJECTED, "a counter change past its max is REJECTED")
	talo.answer("/v1/game-stats/player-stats", 200, JSON.stringify({ "playerStats": [{ "stat": { "internalName": "demons-slain" }, "value": 12 }, { "stat": null, "value": 3 }, "junk"] }))
	var mine := await talo.fetch_my_stats()
	check(mine.status == BoardBackend.Status.OK and mine.values == { "demons-slain": 12.0 }, "the player's stats: each counter's value, odd items skipped (%s)" % [mine.values])
	talo.answer("/v1/game-stats", 200, JSON.stringify({ "stats": [{ "internalName": "demons-slain", "global": true, "globalValue": 1284302 }, { "internalName": "own", "global": false, "globalValue": 5 }, { "internalName": "odd", "global": true, "globalValue": "x" }] }))
	var world := await talo.fetch_world_stats()
	check(world.status == BoardBackend.Status.OK and world.values == { "demons-slain": 1284302.0, "odd": 0.0 }, "the world's stats: the global ones only, a value that isn't a number as 0 (%s)" % [world.values])
	talo.answers.clear()
	talo.answer("/v1/game-stats", 200, "{\"something\": []}")
	check((await talo.fetch_world_stats()).status == BoardBackend.Status.REJECTED, "the world's stats: an answer without its list is REJECTED")
	talo.answer("/v1/game-stats", 502, "<html>Bad gateway</html>")
	check((await talo.fetch_world_stats()).status == BoardBackend.Status.OFFLINE, "the world's stats: a proxy's error page is OFFLINE")
	talo.free()
	var none := _talo()
	check((await none.fetch_my_stats()).status == BoardBackend.Status.OFFLINE and none.requests.is_empty(), "the player's stats: no player, no call")
	none.free()


func _test_config() -> void:
	var talo := _identified()
	await talo.identify("dev")
	talo.answer("/v1/game-config", 200, JSON.stringify({ "config": [{ "key": "motd_en", "value": "Hi" }, { "key": "empty", "value": null }, { "key": 5, "value": "x" }, "junk"] }))
	var config := await talo.fetch_config()
	check(config.status == BoardBackend.Status.OK and config.values == { "motd_en": "Hi", "empty": "" }, "the config: key -> text, a null value as \"\", odd items skipped (%s)" % [config.values])
	check(_header(talo.requests.back(), "X-Talo-Alias:").is_empty() and _header(talo.requests.back(), "X-Talo-Player:").is_empty(), "the config is read without the player (it identifies no one)")
	talo.free()


func _test_boards() -> void:
	var board := Leaderboards.config.board(&"daily_challenge")
	var talo := _identified()
	await talo.identify("dev")
	talo.answer("/entries?page=", 200, JSON.stringify({ "count": 3, "isLastPage": false, "entries": [
		{ "position": 0, "score": 900, "props": [{ "key": "name", "value": "Kagari" }], "playerAlias": { "id": 7, "identifier": "dev", "displayName": "dev" } },
		{ "position": 1, "score": 800, "props": [{ "key": "name", "value": "Old" }], "playerAlias": { "id": 8, "identifier": "x", "displayName": "Sera" } },
		{ "position": 2, "score": 700, "props": [{ "key": "name", "value": "Copy" }], "playerAlias": { "id": 9, "identifier": "y", "displayName": "" } },
	] }))
	var page := await talo.fetch(board, "20390", true, 0)
	check(page.status == BoardBackend.Status.OK and page.total == 3 and not page.last_page and page.entries.size() == 3, "a board's page read: its count and its lines")
	check(page.entries[0].rank == 1 and page.entries[0].alias_id == 7 and page.entries[0].score == 900.0, "a line: its rank from 1, its player, its score")
	check(page.entries[0].name == "Kagari" and page.entries[1].name == "Sera" and page.entries[2].name == "Copy", "a line's name: Talo's display name, or the entry's own copy when Talo shows the device id or nothing")
	check(page.entries[0].identifier == "dev" and page.entries[1].identifier == "x" and page.entries[0].tag() == PlayerName.tag_of("dev"), "a line's player: its alias's identifier (the device id), its tag from it")
	check(page.entries[0].shown_name(Leaderboards.config) == "Kagari#" + PlayerName.tag_of("dev") and page.entries[1].shown_name(Leaderboards.config) == "Sera#" + PlayerName.tag_of("x"), "a line drawn: the name with its tag")
	var url := str(talo.requests.back().url)
	check(url.contains("withDeleted=1") and url.contains("propKey=%s&propValue=20390" % TaloBackend.LeaderboardsScript.period_prop(board)), "a past day is asked with the archived entries, by its period prop (%s)" % url)
	var mine := await talo.fetch_mine(board, "20390", true)
	check(not mine.ranks_reliable and str(talo.requests.back().url).contains("aliasId=7"), "the player's own line of a past day: its rank isn't the day's (found from the pages)")
	talo.answer("/entries", 200, JSON.stringify({ "entry": { "position": 4 } }))
	var sent := await talo.submit(board, 500.0, "20390", { "name": "Kagari" })
	check(sent.status == BoardBackend.Status.OK and sent.rank == 5, "a score sent: its place on the board")
	talo.answers.clear()
	talo.answer("/entries", 200, "[]")
	check((await talo.fetch(board, "", false, 0)).status == BoardBackend.Status.REJECTED, "a board's answer that isn't an object is REJECTED")
	talo.free()


func _test_key_file() -> void:
	if not OS.get_environment(TaloBackend.KEY_ENV).is_empty():
		return  # (a key in the environment wins over the file: nothing to check here)
	var file := "user://test_talo_%d.cfg" % OS.get_process_id()
	var config := ConfigFile.new()
	config.set_value("talo", "access_key", "  abc  ")
	config.set_value("talo", "api_url", "https://example.test")
	config.save(file)
	var found := TaloBackend.read_key(file)
	check(found.key == "abc" and found.url == "https://example.test", "the key's file: the key trimmed, the address")
	check(str(TaloBackend.read_key("user://no_such_key_%d.cfg" % OS.get_process_id()).key).is_empty(), "no key file: no key (offline)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))


## The live session (Presence): nothing before a player, then a ticket and a fresh socket token,
## the API's address on WebSocket with the ticket; a refusal or the server down at either step.
func _test_live() -> void:
	var talo := _identified()
	check((await talo.live_access()).status == BoardBackend.Status.REJECTED and talo.requests.is_empty(), "live: nothing asked before the player is identified")
	await talo.identify("dev")
	talo.answer("/v1/socket-tickets", 200, JSON.stringify({ "ticket": "6c6e f3" }))
	talo.answer("/v1/players/socket-token", 200, JSON.stringify({ "socketToken": "tok-1" }))
	var access: BoardBackend.LiveAccess = await talo.live_access()
	check(access.status == BoardBackend.Status.OK and access.url == "wss://talo.test/?ticket=6c6e%20f3" and access.token == "tok-1", "live: the ticket in the WebSocket address, the token kept (%s)" % access.url)
	var asked := talo.requests.slice(1).map(func(r: Dictionary) -> String: return str(r.url))
	check(asked.size() == 2 and str(asked[0]).ends_with("/v1/socket-tickets") and str(asked[1]).ends_with("/v1/players/socket-token") and talo.requests.slice(1).all(func(r: Dictionary) -> bool: return r.method == HTTPClient.METHOD_POST and _header(r, "X-Talo-Alias:") == "X-Talo-Alias: 7"), "live: a ticket then the player's token, both POST, for that player")
	talo.answer("/v1/players/socket-token", 403, "")
	check((await talo.live_access()).status == BoardBackend.Status.REJECTED, "live: a token refused (the key's scopes) is REJECTED")
	talo.answer("/v1/socket-tickets", 503, "")
	check((await talo.live_access()).status == BoardBackend.Status.OFFLINE, "live: the server down is OFFLINE")
	talo.answer("/v1/socket-tickets", 200, "<html>portal</html>")
	check((await talo.live_access()).status == BoardBackend.Status.REJECTED, "live: a ticket that isn't Talo's answer is refused")
	talo.free()
	var local := TaloBackend.new("k", "http://localhost:3000/")
	var hosted := TaloBackend.new("k")
	check(local.socket_url() == "ws://localhost:3000" and hosted.socket_url() == "wss://api.trytalo.com", "live: https goes wss, http goes ws")
	local.free()
	hosted.free()
