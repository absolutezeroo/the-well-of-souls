class_name LeaderboardsPanel
extends Control
## The Leaderboards page, "The Roll of Souls" (design/progression.md "Online leaderboards"), from
## the title screen and the Dawn Knell's end screen. A MenuWindow: a tab per shown board
## (LeaderboardDef.shown: the Dawn Knell for now) and its periods (today, yesterday), the top of
## the board on the left, the player's place and those around it on the right with the board's
## rule, and the states between: loading, nothing yet, no network (Retry), no leaderboards in
## this build. It only asks Leaderboards (load_board()); it never sends anything itself. The first
## time, it asks whether to publish one's scores, and under which pseudonym (PseudonymDialog);
## not published, the boards aren't even read (the header's button asks again).
## The last tab, "The Well's Toll", shows the world counters (WorldStats): every counter, the
## world's number and the player's own share; read once the player turned an online feature on.
## Reachable as %BoardTabs, %TodayTab, %YesterdayTab, %TopList, %Status, %RetryButton, %MinePanel,
## %MineText, %AroundList, %NameText, %ChangeNameButton, %CloseButton, %NameDialog, %TollTab,
## %TollPanel, %TollList, %TollStatus, %TollNote, %TollRetryButton.

signal closed

## The right column's width.
const SIDE_WIDTH := 430.0
## Rank, name, score columns. The name column holds the longest name with its tag
## ("Clayton#4821": name_max letters, "#" and four digits) at 1280x720 (LeaderboardTests).
const RANK_WIDTH := 56.0
const SCORE_WIDTH := 150.0
## The first three ranks' colors (gold, silver, bronze).
const PODIUM: Array[Color] = [Palette.GOLD, Color(0.82, 0.86, 0.92), Color(0.86, 0.58, 0.36)]
## The player's own line.
const MINE_COLOR := Color(0.65, 0.95, 1.0)
## open()'s id for the Well's Toll tab.
const TOLL := &"toll"
## The Toll's number columns (the world's, the player's).
const TOLL_WORLD_WIDTH := 230.0
const TOLL_MINE_WIDTH := 170.0

var name_dialog: PseudonymDialog

var _window: MenuWindow
var _board: LeaderboardDef
## 0: the current period (today), 1: the one before.
var _back := 0
## Each load's number: an answer for an older one is dropped.
var _load_id := 0
## The boards' tabs (one per shown board, then the Toll's), and the board's two periods.
var _tabs: TabRow
var _periods: TabRow
var _period_tabs: Array[Button] = []
var _board_tabs := {}
var _top_title: Label
var _top_list: VBoxContainer
var _top_scroll: ScrollContainer
var _top_heading: Control
var _status: Label
var _retry: Button
var _mine_text: Label
var _around: VBoxContainer
var _rules: Label
var _name_text: Label
var _change_name: Button
var _mine_panel: Control
var _columns: Control
## The Well's Toll is shown instead of a board.
var _toll_shown := false
var _toll_tab: Button
var _toll_panel: Control
var _toll_list: VBoxContainer
var _toll_status: Label
var _toll_note: Label
var _toll_retry: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()
	Leaderboards.board_loaded.connect(_on_board_loaded)
	name_dialog = PseudonymDialog.new()
	name_dialog.finished.connect(func() -> void:
		_show_name()
		refresh())
	add_child(name_dialog)
	MenuWindow.expose(name_dialog, "NameDialog", self)
	Leaderboards.changed.connect(func() -> void:
		if visible:
			_show_name())
	WorldStats.changed.connect(func() -> void:
		if visible and _toll_shown:
			show_toll())


## Shows the page on `board_id` (empty: the first shown board), today's.
func open(board_id: StringName = &"") -> void:
	var boards := Leaderboards.config.shown_boards()
	_toll_shown = board_id == TOLL
	_board = Leaderboards.config.board(board_id) if board_id != &"" and not _toll_shown else null
	if _board == null and not boards.is_empty():
		_board = boards[0]
	_back = 0
	_show_tabs()
	_show_name()
	show()
	if Leaderboards.needs_name():
		name_dialog.open()
	refresh()


func close() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()
	closed.emit()


## Back (Escape, B, the phone's): the name dialog first, then the page. False if nothing was open.
func back() -> bool:
	if not visible:
		return false
	if name_dialog.visible:
		name_dialog.cancel()  # (its policy page first)
	else:
		close()
	return true


## Loads the board again (and sends what waits first); the Toll's numbers if it is shown.
func refresh() -> void:
	_load_id = 0  # (a board still on its way is not this page's any more)
	_columns.visible = not _toll_shown
	_toll_panel.visible = _toll_shown
	if _toll_shown:
		_show_online(Leaderboards.is_available())
		show_toll()
		WorldStats.refresh()
		return
	_show_online(Leaderboards.is_available())
	if _board == null or not Leaderboards.is_available():
		_show_state(tr("Online leaderboards are not available in this version of the game."), false)
		_show_mine(null)
		return
	if not Leaderboards.shown:
		# Not chosen to publish: the server isn't contacted at all, not even to read.
		_show_state(tr("You chose not to publish your scores, so the online leaderboards are not loaded either. Publish them to see the boards."), false)
		_show_mine(null)
		return
	_show_state(tr("Loading..."), false)
	_show_mine(null, true)
	_load_id = Leaderboards.request_board(_board, _back)


## A board came back: shown if it is the last one asked (an older answer is dropped).
func _on_board_loaded(view: Leaderboards.View, request: int) -> void:
	if request != _load_id or not is_inside_tree():
		return
	show_view(view)


## Fills the page with `view` (Leaderboards.load_board()'s).
func show_view(view: Leaderboards.View) -> void:
	if view.status == BoardBackend.Status.OFFLINE or view.status == BoardBackend.Status.REJECTED:
		_show_state(tr("The leaderboards can't be reached right now. Check your connection, then try again."), true)
		_show_mine(view)
		return
	if view.status != BoardBackend.Status.OK:
		_show_state(tr("Online leaderboards are not available in this version of the game."), false)
		_show_mine(null)
		return
	UiParts.clear(_top_list)
	_top_title.text = tr("The first %d") % Leaderboards.config.top_count
	if view.top.is_empty():
		_show_state(tr("No one is on this board yet.") if _back == 0 else tr("No one was on this board."), false)
	else:
		_status.hide()
		_retry.hide()
		_top_scroll.show()
		_top_heading.show()
		for entry in view.top:
			_top_list.add_child(_row(entry, view.mine != null and entry.alias_id == view.mine.alias_id))
	_show_mine(view)


func _show_state(text: String, can_retry: bool) -> void:
	_status.text = text
	_status.show()
	_retry.visible = can_retry
	_top_scroll.hide()
	_top_heading.hide()
	UiParts.clear(_top_list)


## The right column: the player's place, those around it, or why there is none.
func _show_mine(view: Leaderboards.View, loading := false) -> void:
	UiParts.clear(_around)
	_rules.text = tr(_board.rule) if _board else ""
	if not Leaderboards.shown:
		_mine_text.text = tr("Your scores are not published (Options > Privacy).")
		return
	if loading or view == null:
		_mine_text.text = ""
		return
	if view.status != BoardBackend.Status.OK:
		# Not reached: only what waits is known.
		_mine_text.text = tr("Your score of %s waits to be sent: it goes as soon as the network is back.") % _board.format_score(view.waiting) if view.waiting >= 0.0 else ""
		return
	var text := ""
	if view.mine:
		text = tr("Rank %d - %s") % [view.mine.rank, _board.format_score(view.mine.score)] if view.mine.rank > 0 \
			else tr("Your score: %s (past the first %d)") % [_board.format_score(view.mine.score), Leaderboards.config.top_count * Leaderboards.config.rank_scan_pages]
	elif view.waiting >= 0.0:
		text = tr("Your score of %s waits to be sent: it goes as soon as the network is back.") % _board.format_score(view.waiting)
	else:
		text = tr("You have no score on this board yet.") if _back == 0 else tr("You had no score on this board.")
	if view.mine and view.waiting >= 0.0:
		text += "\n" + tr("A better score waits to be sent.")
	_mine_text.text = text
	if view.mine and view.mine.rank > Leaderboards.config.top_count:
		for entry in view.around:
			_around.add_child(_row(entry, entry.alias_id == view.mine.alias_id, true))


## A build without a server: no name, no periods, no place to show; only why.
func _show_online(on: bool) -> void:
	_name_text.visible = on
	_change_name.visible = on
	_mine_panel.visible = on
	_periods.visible = on and not _toll_shown and _board != null and _board.period != LeaderboardDef.Period.ALL_TIME


func _show_name() -> void:
	if _name_text:
		_name_text.text = tr("You appear as %s") % Leaderboards.tagged_name() if Leaderboards.shown else tr("You don't appear in the leaderboards")
		_change_name.text = tr("Change name") if Leaderboards.shown else tr("Publish my scores")


## The tabs: one per shown board, and the board's two periods (none for an all-time board).
func _show_tabs() -> void:
	var shown := _tabs.buttons.find(_toll_tab) if _toll_shown else (_tabs.buttons.find(_board_tabs[_board.id]) if _board != null and _board_tabs.has(_board.id) else -1)
	_tabs.select(shown)
	var has_periods := not _toll_shown and _board != null and _board.period != LeaderboardDef.Period.ALL_TIME
	var weekly := _board != null and _board.period == LeaderboardDef.Period.WEEKLY
	_period_tabs[0].text = tr("This week") if weekly else tr("Today")
	_period_tabs[1].text = tr("Last week") if weekly else tr("Yesterday")
	_periods.visible = has_periods
	_periods.select(_back)


func _pick_board(board: LeaderboardDef) -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	_toll_shown = false
	_board = board
	_back = 0
	_show_tabs()
	refresh()


func _pick_toll() -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	_toll_shown = true
	_show_tabs()
	refresh()


## The Well's Toll as WorldStats knows it now: every counter with the world's number and the
## player's share, or why there are none (no key, no choice yet, loading, offline).
func show_toll() -> void:
	UiParts.clear(_toll_list)
	_toll_retry.hide()
	var stats := WorldStats.config.enabled_stats()
	var known := stats.any(func(def: WorldStatDef) -> bool: return WorldStats.world_value(def) >= 0.0)
	var why := ""
	if not Leaderboards.is_available():
		why = tr("Online leaderboards are not available in this version of the game.")
	elif not WorldStats.may_read():
		why = tr("The Well's Toll is read from the game's online service. Publish your scores or accept the gameplay statistics (Options > Privacy) to see it.")
	elif not known and (WorldStats.read_status == BoardBackend.Status.OFFLINE or WorldStats.read_status == BoardBackend.Status.REJECTED):
		why = tr("The Well's Toll can't be read right now. Check your connection, then try again.")
		_toll_retry.show()
	elif not known and WorldStats.read_status != BoardBackend.Status.OK:
		why = tr("Loading...")
	_toll_status.text = why
	_toll_status.visible = not why.is_empty()
	_toll_note.text = tr("Every soul's runs add to these numbers when they end. Your share counts from the next run's end.") if WorldStats.may_send() \
		else tr("Your runs are not counted: the Well's Toll counts the runs of players who accept the gameplay statistics (Options > Privacy).")
	_toll_note.visible = WorldStats.may_read()
	if not why.is_empty():
		return
	_toll_list.add_child(_toll_row(tr("The toll"), tr("All souls"), tr("Yours"), UiSkin.GOLD))
	for def in stats:
		var world := WorldStats.world_value(def)
		var mine := WorldStats.my_value(def)
		var row := _toll_row(tr(def.display_name), NumberText.of(int(world)) if world >= 0.0 else "-", NumberText.of(int(mine)) if mine >= 0.0 else "-", UiSkin.TEXT)
		row.name = "Toll_%s" % def.internal_name
		_toll_list.add_child(row)


## A line of the Toll: the counter's name, the world's number, the player's.
func _toll_row(what: String, world: String, mine: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := UiSkin.label(what, Fonts.BODY, color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	var world_label := UiSkin.label(world, Fonts.BODY, color if color == UiSkin.GOLD else UiSkin.TEXT)
	world_label.custom_minimum_size.x = TOLL_WORLD_WIDTH
	world_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(world_label)
	var mine_label := UiSkin.label(mine, Fonts.BODY, color if color == UiSkin.GOLD else MINE_COLOR)
	mine_label.custom_minimum_size.x = TOLL_MINE_WIDTH
	mine_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(mine_label)
	return row


func _pick_period(periods_back: int) -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	_back = periods_back
	_show_tabs()
	refresh()


# --- Building -----------------------------------------------------------------------

func _build() -> void:
	_window = MenuWindow.new(tr("The Roll of Souls"))
	_window.close_requested.connect(close)
	add_child(_window)
	MenuWindow.expose(_window.close_button, "CloseButton", self)
	_name_text = UiSkin.label("", Fonts.BODY, UiSkin.DIM)
	_name_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name_text.clip_text = true
	_name_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_window.header_left.add_child(_name_text)
	MenuWindow.expose(_name_text, "NameText", self)
	var change := MenuWindow.button(tr("Change name"), Fonts.BODY, 48)
	_change_name = change
	change.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	change.set_meta(MenuNav.NOT_FIRST, true)
	change.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		name_dialog.open())
	_window.header_left.add_child(change)
	MenuWindow.expose(change, "ChangeNameButton", self)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_window.body.add_child(row)
	_tabs = TabRow.new()
	_tabs.sound = false  # (the picks click)
	row.add_child(_tabs)
	MenuWindow.expose(_tabs, "BoardTabs", self)
	for board in Leaderboards.config.shown_boards():
		var tab := _tabs.add_tab(tr(board.display_name), "Board_%s" % board.id, self)
		tab.pressed.connect(_pick_board.bind(board))
		_board_tabs[board.id] = tab
	_toll_tab = _tabs.add_tab(tr("The Well's Toll"), "TollTab", self)
	_toll_tab.pressed.connect(_pick_toll)
	# The board's periods: a row of their own, not tabs of the window (Q / E switch boards).
	_periods = TabRow.new(false, false)
	_periods.sound = false
	row.add_child(_periods)
	for periods_back in 2:
		var period := _periods.add_tab(tr("Today"), "TodayTab" if periods_back == 0 else "YesterdayTab", self)
		period.pressed.connect(_pick_period.bind(periods_back))
		_period_tabs.append(period)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	_window.body.add_child(columns)
	_columns = columns
	_build_toll()

	var top: Dictionary = RpgWindow.section(tr("The first %d") % Leaderboards.config.top_count)
	(top.box as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(top.box)
	_top_title = top.title
	var column: VBoxContainer = top.column
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_top_heading = _heading_row()
	column.add_child(_top_heading)
	_top_scroll = UiParts.scroll()
	_top_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_top_scroll)
	_top_list = VBoxContainer.new()
	_top_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_list.add_theme_constant_override("separation", 2)
	_top_scroll.add_child(_top_list)
	MenuWindow.expose(_top_list, "TopList", self)
	_status = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	column.add_child(_status)
	MenuWindow.expose(_status, "Status", self)
	_retry = MenuWindow.button(tr("Try again"), Fonts.BODY, 52)
	_retry.custom_minimum_size.x = 220
	_retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_retry.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		refresh())
	column.add_child(_retry)
	MenuWindow.expose(_retry, "RetryButton", self)

	var side_scroll := UiParts.scroll()
	side_scroll.custom_minimum_size.x = SIDE_WIDTH
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(side_scroll)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	side_scroll.add_child(side)
	var mine: Dictionary = RpgWindow.section(tr("Your place"))
	side.add_child(mine.box)
	_mine_panel = mine.box
	MenuWindow.expose(mine.box, "MinePanel", self)
	_mine_text = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	(mine.column as VBoxContainer).add_child(_mine_text)
	MenuWindow.expose(_mine_text, "MineText", self)
	_around = VBoxContainer.new()
	_around.add_theme_constant_override("separation", 2)
	(mine.column as VBoxContainer).add_child(_around)
	MenuWindow.expose(_around, "AroundList", self)
	var rules: Dictionary = RpgWindow.section(tr("Rules"))
	side.add_child(rules.box)
	_rules = UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	(rules.column as VBoxContainer).add_child(_rules)
	(rules.column as VBoxContainer).add_child(UiSkin.label(tr("Scores no hero could make are removed."), Fonts.BODY, UiSkin.DIM, true))


## The Well's Toll, in place of the board's columns when its tab is picked.
func _build_toll() -> void:
	var toll: Dictionary = RpgWindow.section(tr("The Well's Toll"))
	_toll_panel = toll.box
	_toll_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_toll_panel.hide()
	_window.body.add_child(_toll_panel)
	MenuWindow.expose(_toll_panel, "TollPanel", self)
	var column: VBoxContainer = toll.column
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_toll_note = UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	column.add_child(_toll_note)
	MenuWindow.expose(_toll_note, "TollNote", self)
	var scroll := UiParts.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_toll_list = VBoxContainer.new()
	_toll_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toll_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_toll_list)
	MenuWindow.expose(_toll_list, "TollList", self)
	_toll_status = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	_toll_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toll_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toll_status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_toll_status)
	MenuWindow.expose(_toll_status, "TollStatus", self)
	_toll_retry = MenuWindow.button(tr("Try again"), Fonts.BODY, 52)
	_toll_retry.custom_minimum_size.x = 220
	_toll_retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toll_retry.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		WorldStats.refresh(true))
	_toll_retry.hide()
	column.add_child(_toll_retry)
	MenuWindow.expose(_toll_retry, "TollRetryButton", self)


## Rank, Name, Score over the list.
func _heading_row() -> HBoxContainer:
	var row := _columns_row(tr("Rank"), tr("Name"), tr("Score"), UiSkin.GOLD)
	return row


## A line of the board, the name with its tag (BoardBackend.Entry.shown_name()); the player's
## own stands out. `compact`: the narrow column's (the player's place), on two lines, the name and
## its tag alone on the first so they read whole there too.
func _row(entry: BoardBackend.Entry, mine: bool, compact: bool = false) -> Control:
	var color := MINE_COLOR if mine else (PODIUM[entry.rank - 1] if entry.rank >= 1 and entry.rank <= PODIUM.size() else UiSkin.TEXT)
	var rank := str(entry.rank) if entry.rank > 0 else "-"
	var row: Control
	if compact:
		var lines := VBoxContainer.new()
		lines.add_theme_constant_override("separation", 0)
		lines.add_child(_name_label(entry.shown_name(Leaderboards.config), color))
		lines.add_child(_columns_row(rank, "", _board.format_score(entry.score), color))
		row = lines
	else:
		row = _columns_row(rank, entry.shown_name(Leaderboards.config), _board.format_score(entry.score), color)
	if not mine:
		return row
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiSkin.band(Color(0.65, 0.95, 1.0, 0.14), 4, 0))
	box.add_child(row)
	return box


## A player's name and tag, as a row's "Name" (cut with an ellipsis only past what any name
## takes: the tests check the longest fits).
func _name_label(who: String, color: Color) -> Label:
	var name_label := UiSkin.label(who, Fonts.BODY, color)
	name_label.name = "Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # (a player's name)
	return name_label


func _columns_row(rank: String, who: String, score: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var rank_label := UiSkin.label(rank, Fonts.BODY, color)
	rank_label.custom_minimum_size.x = RANK_WIDTH
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(rank_label)
	row.add_child(_name_label(who, color))
	var score_label := UiSkin.label(score, Fonts.BODY, color)
	score_label.custom_minimum_size.x = SCORE_WIDTH
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(score_label)
	return row
