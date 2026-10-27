class_name LeaderboardTests
extends TestSuite
## The online leaderboards (Leaderboards, design/progression.md "Online leaderboards"), with a
## fake server in memory (FakeBoardBackend): never the network. run_unit(): the boards' data,
## the pseudonym filter, what is queued and sent (and what never is), the queue kept across a
## restart, the tags ("Clayton#4821"). run_title(): the Leaderboards page, with and without a
## server, and the longest name with its tag fitting its rows.

## The tag of the id "abc", worked out once outside the game (Python's hashlib: the salted id's
## SHA-256, its first 12 hex digits modulo 10000): every player's tag would change if tag_of()
## ever gave another.
const FIXED_TAG := "2882"

var _fake: FakeBoardBackend


func run_unit() -> void:
	_test_defs()
	_test_pseudonyms()
	_test_summary_checks()
	await _test_queue()
	await _test_run_end_event()
	await _test_load_board()
	await _test_tags()
	_restore()


func run_title() -> void:
	await _test_page_unavailable()
	await _test_page_with_server()
	await _test_tag_layout()
	_restore()


## Back to the tests' usual: an offline backend, no file.
func _restore() -> void:
	Leaderboards.use_for_tests()
	if is_instance_valid(_fake):
		_fake = null


## A fresh fake server, and the service on it with no file; `opted_in`: the player chose to
## publish their scores (nothing is sent or read before).
func _use_fake(opted_in := true) -> FakeBoardBackend:
	_fake = FakeBoardBackend.new()
	Leaderboards.use_for_tests(_fake)
	if opted_in:
		Leaderboards.set_shown(true)
	return _fake


func _daily() -> LeaderboardDef:
	return Leaderboards.config.board(&"daily_challenge")


## A Dawn Knell's official attempt that ended on floor 4 (today's).
func _summary(official := true) -> RunSummary:
	var summary := RunSummary.new()
	summary.version = "test"
	summary.daily_day = DailyRun.today()
	summary.daily_official = official
	summary.difficulty = &"normal"
	summary.depth = 4
	summary.kills = 50
	summary.bosses = 1
	summary.gold = 100
	summary.time = 300.0
	summary.weapon = &"katana"
	summary.score = summary.expected_daily_score()
	return summary


func _test_defs() -> void:
	var config := Leaderboards.config
	check(config != null and not config.boards.is_empty(), "the leaderboards' data loads (data/leaderboards/leaderboards.tres)")
	var ids := {}
	var talo := {}
	for board in config.boards:
		check(board.problems().is_empty(), "%s is a valid board: %s" % [board.id, board.problems()])
		check(not ids.has(board.id) and not talo.has(board.talo_name), "%s: its id and Talo name are its own" % board.id)
		ids[board.id] = true
		talo[board.talo_name] = true
	var daily := _daily()
	check(daily != null and daily.shown and daily.submits and daily.score == LeaderboardDef.Score.DAILY_SCORE \
		and daily.period == LeaderboardDef.Period.DAILY and daily.higher_first, "the Dawn Knell's board: shown, daily, points, highest first")
	check(config.shown_boards().size() >= 1, "the page has a tab")
	for difficulty in [&"easy", &"normal", &"hard"]:
		var depth := config.board(StringName("depth_%s" % difficulty))
		var fastest := config.board(StringName("fastest_win_%s" % difficulty))
		check(depth != null and fastest != null and depth.difficulty == difficulty and not fastest.higher_first, "the deepest and the fastest win on %s are prepared as data" % difficulty)
	check(config.board(&"vigil") != null and not config.board(&"vigil").submits, "La Veille's board is prepared, nothing sent to it yet")
	check(config.top_count <= 50 and config.retry_seconds > 0.0 and config.name_min >= 2 and config.name_max <= 24, "the page's and the queue's numbers")
	# The access key: packed into the builds from a file that is never committed.
	var ignored := FileAccess.get_file_as_string("res://.gitignore")
	check(ignored.contains("/online/talo.cfg"), "the access key's file is ignored (never committed)")
	var presets := ConfigFile.new()
	presets.load("res://export_presets.cfg")
	for section in presets.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			check(str(presets.get_value(section, "include_filter", "")).contains("online/talo.cfg"), "%s packs the access key's file" % presets.get_value(section, "name"))
		elif section.ends_with(".options") and presets.has_section_key(section, "permissions/vibrate"):
			check(presets.get_value(section, "permissions/internet", false) == true, "%s may reach the network" % section)
	check(not str(ProjectSettings.get_setting("application/config/version", "")).is_empty(), "the game's version is set (sent with every entry)")


func _test_pseudonyms() -> void:
	var config := Leaderboards.config
	var ok := PlayerName.Problem.NONE
	check(PlayerName.problem("Kagari", config) == ok and PlayerName.problem("Héloïse d'Ombre", config) == ok, "a plain name, accents and an apostrophe are fine")
	check(PlayerName.problem("ab", config) == PlayerName.Problem.TOO_SHORT, "too short")
	check(PlayerName.problem("a".repeat(config.name_max + 1), config) == PlayerName.Problem.TOO_LONG, "too long")
	check(PlayerName.problem("a<b>c", config) == PlayerName.Problem.BAD_CHARACTERS and PlayerName.problem("名前です", config) == PlayerName.Problem.BAD_CHARACTERS, "only the letters the font draws")
	check(PlayerName.problem("1234", config) == PlayerName.Problem.NO_LETTER, "at least a letter")
	check(PlayerName.problem("Sh1t lord", config) == PlayerName.Problem.REFUSED and PlayerName.problem("MÉRDE", config) == PlayerName.Problem.REFUSED, "a refused word, whatever its case, accents or digits")
	check(PlayerName.problem("pd 42", config) == PlayerName.Problem.REFUSED and PlayerName.problem("Spidey", config) == ok, "a short word only as a whole word")
	check(PlayerName.tidy("  Le   Rônin ") == "Le Rônin", "spaces tidied")
	check(PlayerName.readable("名前", config) == "??" and PlayerName.readable("x".repeat(40), config).length() == config.name_max, "a name from the server is drawn safely")
	var default := PlayerName.default_for(config)
	check(PlayerName.problem(default, config) == ok, "the default name passes (%s)" % default)
	# The tags: four digits from the online id, the same for the same id, the "#" the game's only.
	var tag := PlayerName.tag_of("3f9a0c1d2e4b5a6978c0d1e2f3a4b5c6")
	check(tag.length() == PlayerName.TAG_DIGITS and tag.is_valid_int() and tag == PlayerName.tag_of("3f9a0c1d2e4b5a6978c0d1e2f3a4b5c6"), "a tag is four digits, the same for the same id (%s)" % tag)
	check(PlayerName.tag_of("3f9a0c1d2e4b5a6978c0d1e2f3a4b5c7") != tag and PlayerName.tag_of("").is_empty(), "another id, another tag; no id, no tag")
	# A fixed id's tag, written here: a change to the hash would re-tag every player.
	check(PlayerName.tag_of("abc") == FIXED_TAG, "the tag's hash never changes (abc: %s)" % PlayerName.tag_of("abc"))
	var tags := {}
	for i in 200:
		tags[PlayerName.tag_of("device-%d" % i)] = true
	check(tags.size() >= 190, "tags spread over 0000-9999 (%d different of 200)" % tags.size())
	check(PlayerName.problem("Clayton#4821", config) == PlayerName.Problem.TAG_SIGN and PlayerName.problem("#Cla", config) == PlayerName.Problem.TAG_SIGN, "a # is refused in a name (the game adds the tag)")
	check(not PlayerName.explain(PlayerName.Problem.TAG_SIGN, config).is_empty(), "...and the player is told why")
	check(PlayerName.readable("Clayton#4821", config) == "Clayton4821" and PlayerName.readable("##", config) == "?", "a # in a name from the server is taken out (no tag of its own)")
	check(PlayerName.tagged("Clayton", "4821") == "Clayton#4821" and PlayerName.tagged("Clayton", "") == "Clayton", "a name and its tag")
	check(Fonts.MAIN.has_char(PlayerName.TAG_SIGN.unicode_at(0)), "the font draws the #")


func _test_summary_checks() -> void:
	var config := Leaderboards.config
	var summary := _summary()
	check(summary.check(config).is_empty(), "a real run passes the checks (%s)" % summary.check(config))
	summary.score += 1
	check(not summary.check(config).is_empty(), "a score its numbers don't make is refused")
	summary = _summary()
	summary.time = 2.0
	check(summary.check(config) == "too fast", "a run too fast is refused")
	summary = _summary()
	summary.kills = 99999
	summary.score = summary.expected_daily_score()
	check(not summary.check(config).is_empty(), "too many kills is refused")
	summary = _summary()
	summary.bosses = 9
	summary.score = summary.expected_daily_score()
	check(not summary.check(config).is_empty(), "more bosses than floors is refused")
	var props := _summary().props()
	for key in ["v", "diff", "depth", "kills", "time", "weapon", "seed", "relic"]:
		check(props.has(key), "the entry carries the run's %s" % key)


func _test_queue() -> void:
	# Before the player chose to publish: nothing is queued, sent or even read.
	var undecided := _use_fake(false)
	check(not Leaderboards.shown and Leaderboards.needs_name(), "publishing is off until the player chooses (and the choice is asked)")
	check(Leaderboards.record(_summary()) == 0 and Leaderboards.queue.is_empty(), "undecided: an official Dawn Knell is not queued")
	await Leaderboards.flush()
	var unread: Leaderboards.View = await Leaderboards.load_board(_daily())
	check(undecided.calls == 0 and unread.status == BoardBackend.Status.UNAVAILABLE and OnlineSession.device_id.is_empty(), "undecided: the server is never called, not even to read a board, and no id is made (%d calls)" % undecided.calls)
	var fake := _use_fake()
	fake.online = false
	var board := _daily()
	var summary := _summary()
	check(Leaderboards.record(summary) == 1 and Leaderboards.queue.size() == 1, "an official Dawn Knell is queued")
	await _frames(1)
	var item: Dictionary = Leaderboards.queue[0] if not Leaderboards.queue.is_empty() else {}
	check(float(item.get("score", -1)) == summary.score and item.get("board") == String(board.id), "...with its score (%s)" % item.get("score"))
	var props: Dictionary = item.get("props", {})
	check(props.get("day") == str(DailyRun.today()) and props.get("kills") == "50" and props.get("name") == Leaderboards.display_name(), "...its day, the run's numbers and the name as props")
	check(fake.sent.is_empty() and Leaderboards.queue.size() == 1, "no network: it waits")
	# The same day's run going on (a win, then the endless floors): one entry, the better score.
	var later := _summary()
	later.kills = 80
	later.score = later.expected_daily_score()
	Leaderboards.record(later)
	await _frames(1)
	check(Leaderboards.queue.size() == 1 and float(Leaderboards.queue[0].score) == later.score, "one score a day: the better one kept")
	check(Leaderboards.record(_summary(false)) == 0, "a practice attempt is never queued")
	var cheat := _summary()
	cheat.debug = true
	check(Leaderboards.record(cheat) == 0, "a debug run is never queued")
	var normal := _summary()
	normal.daily_day = -1
	normal.daily_official = false
	check(Leaderboards.record(normal) == 0, "a normal run goes on no board yet (the others aren't sent to)")
	var impossible := _summary()
	impossible.score = 999999
	check(Leaderboards.record(impossible) == 0 and not Leaderboards.last_rejection.is_empty(), "an impossible run is never queued (%s)" % Leaderboards.last_rejection)
	check(Leaderboards.queue.size() == 1, "...and the queue still holds one score")

	# A restart: the queue and the device's id are read back from their files (the device's id
	# is the OnlineSession's).
	var file := "user://test_leaderboards_%d.json" % OS.get_process_id()
	var session_file := "user://test_online_%d.json" % OS.get_process_id()
	Leaderboards.path = file
	OnlineSession.path = session_file
	Leaderboards.save_state()
	OnlineSession.save_state()
	var device := OnlineSession.device_id
	Leaderboards.load_state()
	OnlineSession.load_state()
	check(Leaderboards.queue.size() == 1 and OnlineSession.device_id == device and not device.is_empty(), "the queue and the device's id survive a restart")
	Leaderboards.path = ""
	OnlineSession.path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(session_file))

	# The network is back: sent once, the queue empties, the default name goes with it.
	fake.online = true
	await Leaderboards.flush()
	check(Leaderboards.queue.is_empty() and fake.sent.size() == 1, "back online, the score is sent once and the queue empties (%d sent)" % fake.sent.size())
	check(not fake.sent.is_empty() and float(fake.sent[0].score) == later.score and fake.sent[0].period == str(DailyRun.today()), "...the day's best score, for its day")
	check(fake.names.values().has(Leaderboards.display_name()), "...under the player's name")
	await Leaderboards.flush()
	check(fake.sent.size() == 1, "nothing is sent twice")

	# Yesterday's score that couldn't be sent in time: its board is closed, it is dropped.
	Leaderboards.queue.append({ "board": String(board.id), "period": str(DailyRun.today() - 1), "score": 10.0, "props": {}, "at": 0 })
	await Leaderboards.flush()
	check(Leaderboards.queue.is_empty() and fake.sent.size() == 1, "a past day's score is dropped, not sent to today's board")

	# Opted out: nothing is queued or sent.
	Leaderboards.set_shown(false)
	check(Leaderboards.record(_summary()) == 0, "opted out: nothing is queued")
	await Leaderboards.flush()
	check(fake.sent.size() == 1, "...nor sent")
	Leaderboards.set_shown(true)

	# A refused name keeps the old one.
	check(Leaderboards.set_pseudonym("fuck") == PlayerName.Problem.REFUSED and Leaderboards.pseudonym.is_empty(), "a refused pseudonym isn't kept")
	check(Leaderboards.set_pseudonym("  Le Rônin ") == PlayerName.Problem.NONE and Leaderboards.display_name() == "Le Rônin" and Leaderboards.name_chosen, "a good one is, tidied")
	await Leaderboards.flush()
	check(fake.names.values().has("Le Rônin"), "...and the server is told")

	# No access key in the build: offline, nothing queued, nothing fails.
	Leaderboards.use_for_tests()
	check(not Leaderboards.is_available() and not Leaderboards.needs_name(), "no key: no leaderboards")
	check(Leaderboards.record(_summary()) == 0 and Leaderboards.queue.is_empty(), "...and nothing is queued")
	var view: Leaderboards.View = await Leaderboards.load_board(board)
	check(view.status == BoardBackend.Status.UNAVAILABLE, "...the board answers unavailable")


## The end of a real run reaches the queue through Events.run_ended (RunRecords.report_end()).
func _test_run_end_event() -> void:
	var fake := _use_fake()
	fake.online = false
	var day := DailyRun.today()
	var rng := RandomNumberGenerator.new()
	var run := RunState.create(CONTENT, {}, rng, day)
	run.daily_official = true
	run.depth = 2
	run.kills = 12
	run.time = 120.0
	var player := (load("res://src/entities/player/player.tscn") as PackedScene).instantiate() as Player
	player.process_mode = Node.PROCESS_MODE_DISABLED  # (no floor under it)
	add_child(player)
	player.setup(CONTENT.player)
	var records := RunRecords.new()
	records.content = CONTENT
	add_child(records)
	records.bind(run, player)
	records.report_end()
	await _frames(1)
	check(Leaderboards.queue.size() == 1 and float(Leaderboards.queue[0].score) == DailyRun.score(run), "a Dawn Knell's end is queued through Events.run_ended (%d)" % Leaderboards.queue.size())
	run.daily_official = false
	Leaderboards.queue.clear()
	records.report_end()
	check(Leaderboards.queue.is_empty(), "...a practice one isn't")
	run.daily_official = true
	DebugCheats.debug_run = true
	records.report_end()
	DebugCheats.debug_run = false
	check(Leaderboards.queue.is_empty(), "...nor a debug run")
	records.queue_free()
	player.queue_free()
	await _frames(1)


## The page's view: the top, the player's place past it, the lines around.
func _test_load_board() -> void:
	var fake := _use_fake()
	var board := _daily()
	var today := board.period_key()
	fake.fill(board, today, 60, 2000.0, 20.0, PackedStringArray(["Akane", "Basho", "Chiyo"]))
	Leaderboards.keep_default_name()
	var summary := _summary()  # 50 kills, floor 4, a boss, 100 gold: 310 points, rank 86 of 61
	Leaderboards.record(summary)
	await Leaderboards.flush()
	var view: Leaderboards.View = await Leaderboards.load_board(board)
	check(view.status == BoardBackend.Status.OK and view.top.size() == Leaderboards.config.top_count and view.total == 61, "the top 50 of 61 (%d, %d)" % [view.top.size(), view.total])
	check(view.mine != null and view.mine.rank == 61, "the player's place past the top (%s)" % (view.mine.rank if view.mine else -1))
	check(view.around.size() >= 2 and view.around.any(func(e: BoardBackend.Entry) -> bool: return view.mine and e.alias_id == view.mine.alias_id), "...with the lines around it")
	var yesterday: Leaderboards.View = await Leaderboards.load_board(board, 1)
	check(yesterday.status == BoardBackend.Status.OK and yesterday.top.is_empty() and yesterday.mine == null, "yesterday's board is its own (empty here)")
	fake.online = false
	var offline: Leaderboards.View = await Leaderboards.load_board(board)
	check(offline.status == BoardBackend.Status.OFFLINE, "no network: the page is told so")
	# A page asks by request_board() and listens to board_loaded (freed meanwhile, it is simply
	# not called: no coroutine of it resumed).
	fake.online = true
	var answers: Array = []
	var listen := func(answer: Leaderboards.View, request: int) -> void: answers.append([answer, request])
	Leaderboards.board_loaded.connect(listen)
	var first := Leaderboards.request_board(board)
	var second := Leaderboards.request_board(board, 1)
	for i in 120:
		if answers.size() >= 2:
			break
		await _frames(1)
	Leaderboards.board_loaded.disconnect(listen)
	var numbers := answers.map(func(pair: Array) -> int: return pair[1])
	check(second == first + 1 and numbers.has(first) and numbers.has(second) and answers.all(func(pair: Array) -> bool: return (pair[0] as Leaderboards.View).status == BoardBackend.Status.OK), "each board asked answers with its own number (%s, asked %d and %d)" % [numbers, first, second])


## The tags on the boards: the same name on two devices, two tags; one device keeps its tag
## (before the choice, after it, across a restart); an entry from before the tags gets one from
## its alias; a typed "#4821" fakes nobody's.
func _test_tags() -> void:
	var fake := _use_fake(false)
	var board := _daily()
	var preview := Leaderboards.tag()
	check(preview.length() == 4 and OnlineSession.device_id.is_empty(), "before the choice the question can show the tag, and no id is kept (%s)" % preview)
	check(Leaderboards.tag() == preview and Leaderboards.tagged_name() == "%s#%s" % [Leaderboards.display_name(), preview], "...always the same one")
	Leaderboards.set_shown(true)
	check(Leaderboards.tag() == preview and PlayerName.tag_of(OnlineSession.device_id) == preview, "published, the device's id is the one the tag came from: the tag stays")
	check(Leaderboards.set_pseudonym("Clayton") == PlayerName.Problem.NONE, "the first device is Clayton")
	Leaderboards.record(_summary())
	await Leaderboards.flush()
	var first_tag := Leaderboards.tag()
	var first_alias := fake.alias_id()
	var sent_name := str(fake.sent.back().props.get("name", "#")) if not fake.sent.is_empty() else "#"
	check(fake.names.get(first_alias) == "Clayton" and sent_name == "Clayton", "the name goes without its tag (the tag is worked out where it is shown)")
	# A restart: the same device, the same tag.
	var session_file := "user://test_online_tags_%d.json" % OS.get_process_id()
	OnlineSession.path = session_file
	OnlineSession.save_state()
	OnlineSession.load_state()
	check(Leaderboards.tag() == first_tag, "the same device keeps its tag across a restart (%s)" % Leaderboards.tag())
	OnlineSession.path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(session_file))
	# A second device on the same server, under the same name.
	Leaderboards.use_for_tests(fake)
	Leaderboards.set_shown(true)
	Leaderboards.set_pseudonym("Clayton")
	var second := _summary()
	second.kills = 60
	second.score = second.expected_daily_score()
	Leaderboards.record(second)
	await Leaderboards.flush()
	var second_tag := Leaderboards.tag()
	check(second_tag != first_tag and fake.alias_id() != first_alias, "the same name on two devices: two tags (%s, %s)" % [first_tag, second_tag])
	# An entry from before the tags typing someone's tag in its name, one without an identifier.
	var lines: Array = fake.boards[board.talo_name][board.period_key()]
	lines.append({ "alias": 777001, "name": "Clayton#%s" % first_tag, "score": 1.0, "props": { "name": "Clayton#%s" % first_tag } })
	fake.identifiers[777001] = "an-old-device"
	lines.append({ "alias": 777002, "name": "Ancien", "score": 0.5, "props": { "name": "Ancien" } })
	var view: Leaderboards.View = await Leaderboards.load_board(board)
	var shown := view.top.map(func(e: BoardBackend.Entry) -> String: return e.shown_name(Leaderboards.config))
	check(shown.has("Clayton#%s" % first_tag) and shown.has("Clayton#%s" % second_tag), "the board shows both Claytons, each with its tag (%s)" % [shown])
	check(view.mine != null and view.mine.shown_name(Leaderboards.config) == Leaderboards.tagged_name(), "the player's own line shows the tag the player is told (%s)" % (view.mine.shown_name(Leaderboards.config) if view.mine else "none"))
	check(shown.has("Clayton%s#%s" % [first_tag, PlayerName.tag_of("an-old-device")]) and shown.count("Clayton#%s" % first_tag) == 1, "a name typed with someone's tag shows its own, after the # taken out")
	check(shown.has("Ancien#%s" % PlayerName.tag_of("alias:777002")), "an entry without an identifier still gets a tag, from its alias")


func _test_page_unavailable() -> void:
	Leaderboards.use_for_tests()
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(2)
	var button := title.get_node("%LeaderboardsButton") as Button
	check(button.is_visible_in_tree(), "the title screen has a Leaderboards button")
	button.pressed.emit()
	await _frames(3)
	var page := title.leaderboards
	check(page.visible and not page.name_dialog.visible, "it opens the page, no name asked without a server")
	var status := page.get_node("%Status") as Label
	check(status.visible and status.text == tr("Online leaderboards are not available in this version of the game."), "no key: the page says the leaderboards are unavailable (%s)" % status.text)
	check(not (page.get_node("%RetryButton") as Control).visible, "...with nothing to retry")
	check(title.back() and not page.visible, "Back closes it")
	title.queue_free()
	await _frames(2)


func _test_page_with_server() -> void:
	var fake := _use_fake(false)
	var board := _daily()
	fake.fill(board, board.period_key(), 55, 2400.0, 30.0, PackedStringArray(["Akane", "Basho", "Chiyo", "Daigo"]))
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(2)
	var page := title.leaderboards
	(title.get_node("%LeaderboardsButton") as Button).pressed.emit()
	await _frames(3)
	check(page.name_dialog.visible, "the first time, the page asks whether to publish, and the name")
	check(fake.calls == 0, "nothing is asked of the server before the choice (%d calls)" % fake.calls)
	var choice := page.name_dialog
	check((choice.get_node("%DeclineButton") as Control).size.is_equal_approx((choice.get_node("%ConfirmButton") as Control).size), "Don't publish and Publish are the same size")
	var edit := page.name_dialog.get_node("%NameEdit") as LineEdit
	edit.text = "shit"
	(page.name_dialog.get_node("%ConfirmButton") as Button).pressed.emit()
	check(page.name_dialog.visible and not (page.name_dialog.get_node("%NameError") as Label).text.is_empty(), "a refused name says why and stays")
	edit.text = "Kagari"
	(page.name_dialog.get_node("%ConfirmButton") as Button).pressed.emit()
	await _frames(4)
	check(not page.name_dialog.visible and Leaderboards.display_name() == "Kagari", "a good one is taken")
	check((page.get_node("%NameText") as Label).text.contains("Kagari"), "the page says the name shown")
	var list := page.get_node("%TopList") as VBoxContainer
	check(list.get_child_count() == Leaderboards.config.top_count, "the top 50 is listed (%d)" % list.get_child_count())
	check((page.get_node("%MineText") as Label).text == tr("You have no score on this board yet."), "no score yet: said so")
	check(_off_grid_texts(page).is_empty(), "the page's texts are on the font's grid: %s" % [_off_grid_texts(page)])
	var screen := get_viewport().get_visible_rect()
	var top_scroll := list.get_parent() as Control
	check(screen.encloses(top_scroll.get_global_rect()), "the list's box stays on the screen")
	for label: Label in page.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and not label.text.is_empty() and not top_scroll.is_ancestor_of(label):
			check(screen.encloses(label.get_global_rect().grow(-1.0)), "%s stays on the screen" % label.text.left(30))
	(page.get_node("%YesterdayTab") as Button).pressed.emit()
	await _frames(3)
	check((page.get_node("%Status") as Label).visible and list.get_child_count() == 0, "yesterday: nobody, said so")
	fake.online = false
	(page.get_node("%TodayTab") as Button).pressed.emit()
	await _frames(3)
	check((page.get_node("%RetryButton") as Control).visible, "no network: Retry")
	fake.online = true
	(page.get_node("%RetryButton") as Button).pressed.emit()
	await _frames(3)
	check(list.get_child_count() > 0 and not (page.get_node("%RetryButton") as Control).visible, "Retry loads it")
	page.close()
	title.queue_free()
	await _frames(2)


## The longest name a player may have, with its tag, reads whole in every row (the top, the
## player's place) and in the question, in English and French, on a phone (2340x1080, 2548x1296)
## and a 1280x720 window.
func _test_tag_layout() -> void:
	var fake := _use_fake()
	var board := _daily()
	var longest := "W".repeat(Leaderboards.config.name_max)
	fake.fill(board, board.period_key(), 58, 9000.0, 10.0, PackedStringArray([longest, "M".repeat(Leaderboards.config.name_max)]))
	Leaderboards.set_pseudonym(longest)
	Leaderboards.record(_summary())  # (past the top: the player's place and the lines around it)
	await Leaderboards.flush()
	var before := get_tree().root.size
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(2)
	var page := title.leaderboards
	for language: String in ["en", "fr"]:
		Settings.language = language
		Settings.apply()
		for screen: Vector2i in [Vector2i(2340, 1080), Vector2i(2548, 1296), Vector2i(1280, 720), Vector2i(1024, 768)]:
			get_tree().root.size = screen
			(title.get_node("%LeaderboardsButton") as Button).pressed.emit()
			await _frames(4)
			var cut: Array[String] = []
			var rows := 0
			for list_name in ["TopList", "AroundList"]:
				for row: Node in (page.get_node("%" + list_name) as Control).get_children():
					var label := row.find_child("Name", true, false) as Label
					rows += 1
					if label == null:
						cut.append("a row without its name")
					elif not label.text.contains("#") or Fonts.width(label.text, Fonts.BODY) > label.size.x + 0.5:
						cut.append("%s %.0f/%.0f" % [label.text, Fonts.width(label.text, Fonts.BODY), label.size.x])
			check(rows > Leaderboards.config.top_count and cut.is_empty(), "%s %s: the longest name and its tag read whole in every row (%d rows): %s" % [language, screen, rows, cut.slice(0, 3)])
			var view_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(1.0)
			var name_text := page.get_node("%NameText") as Label
			check(name_text.text.contains("#" + Leaderboards.tag()) and view_rect.encloses(name_text.get_global_rect()), "%s %s: the page says the name with its tag, on screen" % [language, screen])
			page.name_dialog.open()
			await _frames(3)
			var preview := page.name_dialog.get_node("%NamePreview") as Label
			var dialog_rect := (page.name_dialog.get_node("%ConfirmButton") as Control).get_global_rect().merge(preview.get_global_rect())
			check(preview.text.contains(Leaderboards.tagged_name()) and view_rect.encloses(dialog_rect), "%s %s: the question shows the name with its tag, and fits (%s)" % [language, screen, preview.text])
			(page.name_dialog.get_node("%NameEdit") as LineEdit).text = "Clay#1"
			(page.name_dialog.get_node("%ConfirmButton") as Button).pressed.emit()
			check(page.name_dialog.visible and (page.name_dialog.get_node("%NameError") as Label).text == PlayerName.explain(PlayerName.Problem.TAG_SIGN, Leaderboards.config), "%s %s: a # typed is refused, saying why" % [language, screen])
			page.name_dialog.cancel()
			page.close()
			await _frames(1)
	Settings.language = "en"
	Settings.apply()
	get_tree().root.size = before
	title.queue_free()
	await _frames(2)
