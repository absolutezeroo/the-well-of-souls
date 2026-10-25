class_name FakeBoardBackend
extends BoardBackend
## A leaderboard server in memory for the tests and the page's screenshots: no network. It acts
## like the Talo boards the game uses (one entry per player and period, kept only if better,
## ranks counted in the period asked for), keeps game stats like Talo's global ones (`world`,
## `player_stats`, `max_change`: the world counters) and can be switched off (`online`) to test
## the queues.

## Answers at all (false: every call is OFFLINE, like a phone without network).
var online := true
## Has an access key (false: like a build without one).
var configured := true
## Every score sent: {board, score, period, props}.
var sent: Array[Dictionary] = []
## Board talo_name -> period -> [{alias, name, score, props}].
var boards := {}
## alias id -> name (set_pseudonym()).
var names := {}
## alias id -> its identifier (the device id it was identified with; the tags come from it, as
## from Talo's `playerAlias.identifier`). An alias missing here has none (an entry without one).
var identifiers := {}
## Seconds each answer takes (the page's loading state in a screenshot).
var delay := 0.0
## Every call made to the server (none may be made before the player chose: Privacy's rule).
var calls := 0
## Every gameplay statistics event received: {name, props, timestamp}.
var events: Array[Dictionary] = []

## The world counters: internal name -> the world's value (global stats; a name missing is a stat
## the server doesn't have: refused).
var world := {}
## Every counter update received: {stat, change, alias}.
var stat_updates: Array[Dictionary] = []
## Each player's own totals: alias id -> {internal name -> value}.
var player_stats := {}
## A counter's max change (Talo's maxChange): internal name -> int; past it, refused.
var max_change := {}

## The game's live config (Talo's game config): key -> value text (the remote settings).
var config := {}
## Reads of the config (each also counts in `calls`).
var config_reads := 0

## The live sessions (Presence): the server opens connections (false: they never open, like a
## firewall), the token it gave last, the sessions started and ended, the player shown online,
## every connection made (the last one: the test can drop it).
var live_answers := true
var live_token := ""
var live_started := 0
var live_ended := 0
var live_online := false
var live_links: Array[FakeLiveLink] = []
## live_access() calls (each asks a ticket and a token).
var live_asks := 0

var _alias := 0


func fetch_config() -> BoardBackend.ConfigValues:
	var result := BoardBackend.ConfigValues.new()
	config_reads += 1
	if not await _answers():
		result.status = Status.OFFLINE
		return result
	result.status = Status.OK
	result.values = config.duplicate()
	return result


func add_to_stat(internal_name: String, change: int) -> Status:
	if not await _answers():
		return Status.OFFLINE
	if _alias == 0 or not world.has(internal_name) or absi(change) > int(max_change.get(internal_name, 1 << 40)):
		return Status.REJECTED
	stat_updates.append({ "stat": internal_name, "change": change, "alias": _alias })
	world[internal_name] = float(world[internal_name]) + change
	var mine: Dictionary = player_stats.get(_alias, {})
	mine[internal_name] = float(mine.get(internal_name, 0.0)) + change
	player_stats[_alias] = mine
	return Status.OK


func fetch_world_stats() -> BoardBackend.StatValues:
	var result := BoardBackend.StatValues.new()
	if not await _answers():
		result.status = Status.OFFLINE
		return result
	result.status = Status.OK
	result.values = world.duplicate()
	return result


func fetch_my_stats() -> BoardBackend.StatValues:
	var result := BoardBackend.StatValues.new()
	if not await _answers():
		result.status = Status.OFFLINE
		return result
	result.status = Status.OK if _alias > 0 else Status.REJECTED
	result.values = (player_stats.get(_alias, {}) as Dictionary).duplicate()
	return result


func is_configured() -> bool:
	return configured


func alias_id() -> int:
	return _alias


func player_id() -> String:
	return "player-%d" % _alias if _alias > 0 else ""


func forget() -> void:
	_alias = 0


func send_events(list: Array[Dictionary]) -> Status:
	if not await _answers():
		return Status.OFFLINE
	if _alias == 0:
		return Status.REJECTED
	events.append_array(list)
	return Status.OK


## identify() calls received (one at a time for every service: OnlineSession.identity()).
var identifies := 0
## identify() is refused (a bad key, a captive portal's page): REJECTED.
var refuse_identify := false


func identify(device_id: String) -> Status:
	identifies += 1
	if not await _answers():
		return Status.OFFLINE
	if refuse_identify:
		return Status.REJECTED
	_alias = absi(hash(device_id)) % 100000 + 1
	identifiers[_alias] = device_id
	return Status.OK


func set_pseudonym(pseudonym: String) -> Status:
	if not await _answers():
		return Status.OFFLINE
	names[_alias] = pseudonym
	return Status.OK


func submit(board: LeaderboardDef, score: float, period_key: String, props: Dictionary) -> BoardBackend.Sent:
	var result := BoardBackend.Sent.new()
	if not await _answers():
		result.status = Status.OFFLINE
		return result
	sent.append({ "board": board.talo_name, "score": score, "period": period_key, "props": props })
	var list := _list(board, period_key)
	var found := false
	for line: Dictionary in list:
		if line.alias == _alias:
			found = true
			if (score > line.score) if board.higher_first else (score < line.score):
				line.score = score
				line.props = props
	if not found:
		list.append({ "alias": _alias, "name": str(props.get("name", "")), "score": score, "props": props })
	result.status = Status.OK
	for entry in _ranked(board, period_key):
		if entry.alias_id == _alias:
			result.rank = entry.rank
	return result


func fetch(board: LeaderboardDef, period_key: String, _past: bool, page: int) -> BoardBackend.Page:
	var result := BoardBackend.Page.new()
	if not await _answers():
		result.status = Status.OFFLINE
		return result
	var ranked := _ranked(board, period_key)
	result.status = Status.OK
	result.total = ranked.size()
	result.entries.assign(ranked.slice(page * PAGE_SIZE, (page + 1) * PAGE_SIZE))
	result.last_page = (page + 1) * PAGE_SIZE >= ranked.size()
	return result


func fetch_mine(board: LeaderboardDef, period_key: String, _past: bool) -> BoardBackend.Page:
	var result := BoardBackend.Page.new()
	if not await _answers():
		result.status = Status.OFFLINE
		return result
	result.status = Status.OK
	for entry in _ranked(board, period_key):
		if entry.alias_id == _alias:
			result.entries.append(entry)
	return result


## `count` other players on `board` for `period_key`, scores falling from `best` (screenshots,
## tests). `names_from`: their names, in turn. Each is its own device (an identifier of its own:
## its own tag).
func fill(board: LeaderboardDef, period_key: String, count: int, best: float, step: float, names_from: PackedStringArray) -> void:
	var list := _list(board, period_key)
	for i in count:
		var alias_name := names_from[i % names_from.size()]
		if i >= names_from.size():
			alias_name += " %d" % (int(i / float(names_from.size())) + 1)
		list.append({ "alias": 900000 + i, "name": alias_name, "score": best - i * step, "props": {} })
		identifiers[900000 + i] = "fake-device-%d" % i


## Every feedback message received: {category, comment, props, alias}.
var feedback: Array[Dictionary] = []
## The feedback categories the server has (Talo's internal names; another one is refused).
var feedback_categories := PackedStringArray(["bug", "idea", "other"])


func send_feedback(internal_name: String, comment: String, props: Dictionary) -> Status:
	if not await _answers():
		return Status.OFFLINE
	if _alias == 0 or not feedback_categories.has(internal_name):
		return Status.REJECTED
	feedback.append({ "category": internal_name, "comment": comment, "props": props.duplicate(), "alias": _alias })
	return Status.OK


func _answers() -> bool:
	calls += 1
	if delay > 0.0:
		await get_tree().create_timer(delay, true, false, true).timeout
	return online


func _list(board: LeaderboardDef, period_key: String) -> Array:
	if not boards.has(board.talo_name):
		boards[board.talo_name] = {}
	var periods: Dictionary = boards[board.talo_name]
	if not periods.has(period_key):
		periods[period_key] = []
	return periods[period_key]


func _ranked(board: LeaderboardDef, period_key: String) -> Array[BoardBackend.Entry]:
	var list := _list(board, period_key).duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.score > b.score if board.higher_first else a.score < b.score)
	var result: Array[BoardBackend.Entry] = []
	for i in list.size():
		var line: Dictionary = list[i]
		var entry := BoardBackend.Entry.new()
		entry.rank = i + 1
		entry.alias_id = line.alias
		entry.identifier = str(identifiers.get(line.alias, ""))
		entry.name = names.get(line.alias, line.name)
		entry.score = line.score
		entry.props = line.props
		result.append(entry)
	return result


func live_access() -> BoardBackend.LiveAccess:
	live_asks += 1
	var access := BoardBackend.LiveAccess.new()
	if not await _answers():
		access.status = Status.OFFLINE
		return access
	if _alias == 0:
		access.status = Status.REJECTED
		return access
	live_token = "token-%d" % live_asks
	access.status = Status.OK
	access.url = "wss://talo.test/?ticket=ticket-%d" % live_asks
	access.token = live_token
	return access


func open_live() -> LiveLink:
	var link := FakeLiveLink.new(self)
	live_links.append(link)
	return link
