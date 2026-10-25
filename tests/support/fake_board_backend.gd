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
## The custom statuses received, in order (set_presence_status()).
var live_statuses: PackedStringArray = []
## live_access() calls (each asks a ticket and a token).
var live_asks := 0

## The accounts (Talo player auth), by name: {password, email, alias, player, token, deleted}.
## One session per account, like Talo's: a sign-in elsewhere ends the other's token.
var accounts := {}
## The online saves, by account player id: [{id, name, content}].
var saves_by_player := {}
## Reset codes sent: email -> code.
var reset_codes := {}
## Account calls received (each also counts in `calls`).
var account_calls := 0
## Game saves refused (the key's scope missing: 403).
var saves_refused := false

var _alias := 0
var _next_id := 100


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


func set_presence_status(text: String) -> Status:
	if not await _answers():
		return Status.OFFLINE
	if _alias == 0:
		return Status.REJECTED
	live_statuses.append(text)
	return Status.OK


# --- Accounts and online saves (Talo's rules, in memory) ------------------------------------

func _new_session(account: Dictionary) -> BoardBackend.AccountAuth:
	_next_id += 1
	account.token = "session-%d" % _next_id
	var auth := BoardBackend.AccountAuth.new()
	auth.alias_id = int(account.alias)
	auth.player_id = str(account.player)
	auth.token = account.token
	auth.identifier = str(account.name)
	auth.email = str(account.email)
	return auth


func _refused(error: String) -> BoardBackend.AccountAnswer:
	var answer := BoardBackend.AccountAnswer.new()
	answer.status = Status.REJECTED
	answer.error = error
	return answer


func _account_answers() -> bool:
	account_calls += 1
	return await _answers()


## The account an auth stands for, if its session is still the account's ({} none).
func _session_of(auth: BoardBackend.AccountAuth) -> Dictionary:
	for account: Dictionary in accounts.values():
		if account.player == auth.player_id and int(account.alias) == auth.alias_id and not account.get("deleted", false):
			return account if account.token == auth.token else { "stale": true }
	return {}


func account_register(identifier: String, password: String, email: String) -> BoardBackend.AccountAnswer:
	if not await _account_answers():
		var offline := BoardBackend.AccountAnswer.new()
		offline.status = Status.OFFLINE
		return offline
	if accounts.has(identifier.to_lower()):
		return _refused("IDENTIFIER_TAKEN")
	for account: Dictionary in accounts.values():
		if not email.is_empty() and account.email == email:
			return _refused("EMAIL_TAKEN")
	_next_id += 1
	var account := { "name": identifier, "password": password, "email": email, "alias": _next_id, "player": "account-%d" % _next_id, "token": "" }
	accounts[identifier.to_lower()] = account
	var answer := BoardBackend.AccountAnswer.new()
	answer.status = Status.OK
	answer.auth = _new_session(account)
	return answer


func account_login(identifier: String, password: String) -> BoardBackend.AccountAnswer:
	if not await _account_answers():
		var offline := BoardBackend.AccountAnswer.new()
		offline.status = Status.OFFLINE
		return offline
	var account: Dictionary = accounts.get(identifier.to_lower(), {})
	if account.is_empty() or account.get("deleted", false) or account.password != password:
		return _refused("INVALID_CREDENTIALS")
	var answer := BoardBackend.AccountAnswer.new()
	answer.status = Status.OK
	answer.auth = _new_session(account)
	return answer


func account_logout(auth: BoardBackend.AccountAuth) -> Status:
	if not await _account_answers():
		return Status.OFFLINE
	var account := _session_of(auth)
	if account.is_empty() or account.has("stale"):
		return Status.REJECTED
	account.token = ""
	return Status.OK


func account_forgot_password(email: String) -> Status:
	if not await _account_answers():
		return Status.OFFLINE
	for account: Dictionary in accounts.values():
		if account.email == email:
			reset_codes[email] = "%06d" % (absi(hash(email)) % 1000000)
	return Status.OK


func account_reset_password(code: String, password: String) -> BoardBackend.AccountAnswer:
	if not await _account_answers():
		var offline := BoardBackend.AccountAnswer.new()
		offline.status = Status.OFFLINE
		return offline
	for email: String in reset_codes:
		if reset_codes[email] == code:
			for account: Dictionary in accounts.values():
				if account.email == email:
					account.password = password
					account.token = ""
			reset_codes.erase(email)
			var answer := BoardBackend.AccountAnswer.new()
			answer.status = Status.OK
			return answer
	return _refused("PASSWORD_RESET_CODE_INVALID")


func account_change_password(auth: BoardBackend.AccountAuth, current: String, new_password: String) -> BoardBackend.AccountAnswer:
	if not await _account_answers():
		var offline := BoardBackend.AccountAnswer.new()
		offline.status = Status.OFFLINE
		return offline
	var account := _session_of(auth)
	if account.is_empty() or account.has("stale"):
		return _refused("INVALID_SESSION")
	if account.password != current:
		return _refused("INVALID_CREDENTIALS")
	if new_password == current:
		return _refused("NEW_PASSWORD_MATCHES_CURRENT_PASSWORD")
	account.password = new_password
	var answer := BoardBackend.AccountAnswer.new()
	answer.status = Status.OK
	return answer


func account_delete(auth: BoardBackend.AccountAuth, password: String) -> BoardBackend.AccountAnswer:
	if not await _account_answers():
		var offline := BoardBackend.AccountAnswer.new()
		offline.status = Status.OFFLINE
		return offline
	var account := _session_of(auth)
	if account.is_empty() or account.has("stale"):
		return _refused("INVALID_SESSION")
	if account.password != password:
		return _refused("INVALID_CREDENTIALS")
	account.deleted = true
	account.token = ""
	var answer := BoardBackend.AccountAnswer.new()
	answer.status = Status.OK
	return answer


## A save call's account, or the refusal to answer.
func _save_session(auth: BoardBackend.AccountAuth) -> BoardBackend.SaveAnswer:
	var refused := BoardBackend.SaveAnswer.new()
	refused.status = Status.REJECTED
	var account := _session_of(auth)
	if account.is_empty() or account.has("stale"):
		refused.error = "INVALID_SESSION"
		return refused
	if saves_refused:
		return refused
	return null


static func _slot(item: Dictionary) -> BoardBackend.CloudSlot:
	var slot := BoardBackend.CloudSlot.new()
	slot.id = int(item.id)
	slot.name = str(item.name)
	slot.content = JSON.parse_string(JSON.stringify(item.content))  # (as the server gives it back: numbers as floats)
	return slot


func saves_list(auth: BoardBackend.AccountAuth) -> BoardBackend.SaveAnswer:
	if not await _account_answers():
		var offline := BoardBackend.SaveAnswer.new()
		offline.status = Status.OFFLINE
		return offline
	var refused := _save_session(auth)
	if refused:
		return refused
	var answer := BoardBackend.SaveAnswer.new()
	answer.status = Status.OK
	for item: Dictionary in saves_by_player.get(auth.player_id, []):
		answer.saves.append(_slot(item))
	return answer


func save_create(auth: BoardBackend.AccountAuth, save_name: String, content: Dictionary) -> BoardBackend.SaveAnswer:
	if not await _account_answers():
		var offline := BoardBackend.SaveAnswer.new()
		offline.status = Status.OFFLINE
		return offline
	var refused := _save_session(auth)
	if refused:
		return refused
	_next_id += 1
	var item := { "id": _next_id, "name": save_name, "content": JSON.parse_string(JSON.stringify(content)) }
	if not saves_by_player.has(auth.player_id):
		saves_by_player[auth.player_id] = []
	(saves_by_player[auth.player_id] as Array).append(item)
	var answer := BoardBackend.SaveAnswer.new()
	answer.status = Status.OK
	answer.slot = _slot(item)
	return answer


func save_update(auth: BoardBackend.AccountAuth, id: int, content: Dictionary) -> BoardBackend.SaveAnswer:
	if not await _account_answers():
		var offline := BoardBackend.SaveAnswer.new()
		offline.status = Status.OFFLINE
		return offline
	var refused := _save_session(auth)
	if refused:
		return refused
	for item: Dictionary in saves_by_player.get(auth.player_id, []):
		if int(item.id) == id:
			item.content = JSON.parse_string(JSON.stringify(content))
			var answer := BoardBackend.SaveAnswer.new()
			answer.status = Status.OK
			answer.slot = _slot(item)
			return answer
	var missing := BoardBackend.SaveAnswer.new()
	missing.status = Status.REJECTED
	return missing


func save_delete(auth: BoardBackend.AccountAuth, id: int) -> Status:
	if not await _account_answers():
		return Status.OFFLINE
	if _save_session(auth):
		return Status.REJECTED
	var list: Array = saves_by_player.get(auth.player_id, [])
	for item: Dictionary in list:
		if int(item.id) == id:
			list.erase(item)
			return Status.OK
	return Status.REJECTED


## The online profile of `account_name`'s save as another device would leave it (the tests
## play the other device): its content with `rev` and that profile.
func put_online(account_name: String, rev: int, profile: Dictionary) -> void:
	var account: Dictionary = accounts[account_name.to_lower()]
	var content := { "rev": rev, "saved_at": 1_800_000_000, "platform": "Windows", "version": "test", "profile": profile }
	var list: Array = saves_by_player.get(account.player, [])
	saves_by_player[account.player] = list
	for item: Dictionary in list:
		if item.name == "profile":
			item.content = JSON.parse_string(JSON.stringify(content))
			return
	_next_id += 1
	list.append({ "id": _next_id, "name": "profile", "content": JSON.parse_string(JSON.stringify(content)) })


## The online save's content for `account_name` ({} none).
func online_profile(account_name: String) -> Dictionary:
	var account: Dictionary = accounts.get(account_name.to_lower(), {})
	for item: Dictionary in saves_by_player.get(account.get("player", ""), []):
		if item.name == "profile":
			return item.content
	return {}
