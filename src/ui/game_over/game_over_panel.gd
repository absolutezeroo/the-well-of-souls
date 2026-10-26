class_name GameOverPanel
extends Control
## End of a run, in the game's skin (RpgDialog): death, or victory over the last boss (then you
## may keep going: endless mode). How it ended (the Vigil-Keeper telling it and giving advice, in
## a DialogueBox typing beside everything else; else a line of the story), the run's numbers
## (time, depth, kills...), the souls it earned and what souls are for, then what to do next.
## After a Dawn Knell, a Leaderboards button by the run's numbers opens the online page
## (LeaderboardsPanel) over it.

signal restart_requested
signal continue_requested
signal title_requested

const DEATH_COLOR := Color(1, 0.88, 0.82)
const VICTORY_COLOR := Color(1, 0.86, 0.45)
const WIDTH := 880.0

var _dialog: RpgDialog
var _summary: Label
## The Vigil-Keeper's words (STACKED: never holding the buttons back).
var _voice: DialogueBox
var _columns: HBoxContainer
var _stats: GridContainer
var _souls_earned: Label
var _souls_total: Label
## What souls are for, in full; in a line while the Vigil-Keeper speaks (the screen keeps its
## height on a 720-line phone).
var _souls_note: Label
var _souls_short: Label
var _continue_note: Label
var _continue_button: Button
var _restart_button: Button
var _boards_button: Button
## Built nodes reachable as %Name once the panel is built.
var _named := ExposedNodes.new()
## The online leaderboards' page, opened from the end of a Dawn Knell.
var leaderboards: LeaderboardsPanel

## The next end shows the Leaderboards button (the Game sets it for a daily run).
var show_leaderboards := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()


## The whole end of a run. `rows`: [label, value] pairs (RunState.summary_rows()). `title`:
## instead of the usual one (an ending's, chosen at the bottom of the Well).
## `spoken`: what the Vigil-Keeper says of it (Dialogues.Spoken: the tale, then the advice).
func show_end(victory: bool, story: String, rows: Array, souls_earned: int, souls_total: int, title: String = "", spoken: Array[Dialogues.Spoken] = []) -> void:
	if title.is_empty():
		title = tr("Victory Achieved") if victory else tr("The Well claims you")
	_show(title, VICTORY_COLOR if victory else DEATH_COLOR, story, victory)
	_voice.visible = not spoken.is_empty()
	_souls_note.visible = spoken.is_empty()
	_souls_short.visible = not spoken.is_empty()
	if not spoken.is_empty():
		_voice.say(spoken)
	var lines: Array = []
	for row: Array in rows:
		lines.append([str(row[0]), str(row[1]), UiSkin.GOLD if str(row[1]).contains(tr("New record!")) else UiSkin.TEXT])
	UiParts.stat_rows(_stats, lines)
	_souls_earned.text = tr("+%d souls") % souls_earned
	_souls_total.text = tr("You now have %d souls.") % souls_total
	_boards_button.visible = show_leaderboards
	_columns.show()


## Just a text, a death (tests: the panel without a run behind it).
func show_result(summary: String) -> void:
	_show(tr("The Well claims you"), DEATH_COLOR, summary, false)
	_voice.hide()
	_columns.hide()


## The Vigil-Keeper's box (tests).
func voice() -> DialogueBox:
	return _voice


## Every word on the screen, top to bottom (tests); the Vigil-Keeper's whole, typed or not.
func shown_text() -> String:
	var parts := PackedStringArray()
	var stack: Array[Node] = [_dialog]
	while not stack.is_empty():
		var node: Node = stack.pop_front()
		if node == _voice:
			if _voice.is_visible_in_tree():
				parts.append(_voice.shown_text())
			continue
		if node is Label and (node as Label).is_visible_in_tree():
			parts.append((node as Label).text)
		elif node is Button and (node as Button).is_visible_in_tree():
			parts.append((node as Button).text)
		stack.append_array(node.get_children())
	return "\n".join(parts)


func _show(title: String, color: Color, summary: String, can_continue: bool) -> void:
	_dialog.set_title(title, color)
	_summary.text = summary
	_summary.visible = not summary.is_empty()
	_continue_button.visible = can_continue
	_continue_note.visible = can_continue
	_restart_button.text = tr("Return to village")
	show()


func _build() -> void:
	_dialog = RpgDialog.new(tr("The Well claims you"), WIDTH, 0.82)
	add_child(_dialog)
	_dialog.title_label.name = "Title"
	_named.add(_dialog.title_label)
	_summary = UiParts.text("", Fonts.BODY, UiSkin.TEXT, WIDTH - 60)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.name = "Summary"
	_named.add(_summary)
	_dialog.body.add_child(_summary)
	_voice = DialogueBox.new(DialogueBox.Mode.STACKED, WIDTH - 60)
	_voice.name = "Voice"
	_voice.hide()
	_named.add(_voice)
	_dialog.body.add_child(_voice)

	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 14)
	_dialog.body.add_child(_columns)
	var run: Dictionary = RpgWindow.section(tr("This run"))
	(run.box as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.add_child(run.box)
	# The heading and, after a Dawn Knell, the Leaderboards button on its line.
	var heading := HBoxContainer.new()
	(run.column as VBoxContainer).add_child(heading)
	(run.column as VBoxContainer).move_child(heading, 0)
	(run.title as Label).reparent(heading)
	(run.title as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(run.title as Label).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_boards_button = UiParts.button(tr("Leaderboards"), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		leaderboards.open(), Vector2(180, 40), Fonts.BODY)
	_boards_button.name = "LeaderboardsButton"
	_boards_button.hide()
	_named.add(_boards_button)
	heading.add_child(_boards_button)
	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 20)
	_stats.add_theme_constant_override("v_separation", 2)
	_stats.name = "Stats"
	_named.add(_stats)
	run.column.add_child(_stats)
	var souls: Dictionary = RpgWindow.section(tr("Souls"))
	(souls.box as Control).custom_minimum_size.x = 400
	_columns.add_child(souls.box)
	_souls_earned = UiSkin.label("", Fonts.TITLE, UiSkin.GOLD)
	_souls_earned.name = "SoulsEarned"
	_named.add(_souls_earned)
	souls.column.add_child(_souls_earned)
	_souls_total = UiSkin.label("", Fonts.BODY, UiSkin.TEXT)
	souls.column.add_child(_souls_total)
	_souls_note = UiParts.text(tr("Souls are kept between runs. Spend them at the Shrine (title screen) on upgrades that make every next run stronger."), Fonts.BODY, UiSkin.DIM, 360)
	souls.column.add_child(_souls_note)
	_souls_short = UiParts.text(tr("Kept between runs: spend them at the Shrine."), Fonts.BODY, UiSkin.DIM, 360)
	_souls_short.hide()
	souls.column.add_child(_souls_short)
	souls.column.add_child(UiParts.text(tr("Gold was only for this run."), Fonts.BODY, UiSkin.DIM, 360))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	_dialog.body.add_child(buttons)
	_continue_button = UiParts.button(tr("Keep going (endless)"), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		hide()
		continue_requested.emit(), Vector2(260, 58), Fonts.BODY)
	_continue_button.name = "ContinueButton"
	_named.add(_continue_button)
	buttons.add_child(_continue_button)
	_restart_button = UiParts.button(tr("Return to village"), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		restart_requested.emit(), Vector2(240, 58), Fonts.BODY)
	_restart_button.name = "RestartButton"
	_named.add(_restart_button)
	buttons.add_child(_restart_button)
	var title_button := UiParts.button(tr("Title screen"), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		title_requested.emit(), Vector2(240, 58), Fonts.BODY)
	title_button.name = "TitleButton"
	_named.add(title_button)
	buttons.add_child(title_button)
	_continue_note = UiParts.text(tr("Keep going: endless floors, harder and harder. Your win is already counted."), Fonts.BODY, UiSkin.DIM, WIDTH - 60)
	_continue_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog.body.add_child(_continue_note)
	_named.expose_to(self)
	leaderboards = LeaderboardsPanel.new()
	leaderboards.name = "LeaderboardsPanel"
	add_child(leaderboards)
	leaderboards.closed.connect(func() -> void:
		if InputDevice.uses_buttons():
			_boards_button.grab_focus())


## Back over the end screen: closes the leaderboards' page if it is open (true), else nothing.
func back() -> bool:
	return leaderboards != null and leaderboards.back()
