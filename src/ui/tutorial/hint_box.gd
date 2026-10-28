class_name HintBox
extends Control
## A tutorial hint on screen (see Tutorial): a small wooden board at the top, its title in gold
## and what to do in one line in a dark inset, an OK button; when the hint is about a control of
## the HUD, a ring pulses around that control and an arrow points at it. The board is as wide as
## its line (a short hint, a small board), up to MAX_TEXT: every hint's line fits that in English
## and French on every device (tutorial tests), a longer one (a long key name) wraps. The line is
## reading text (UiSkin.reading_size()): with Large text it may grow to the room between the HUD's
## stats and its map's column (Hud.top_room(), at most LARGE_WIDTH), then wraps.

signal dismissed

## The line's width (UI units) the board grows to before it wraps: one line at 1280x720 and on a
## phone, the board clear of the minimap; and the least it takes (a short hint stays a board).
const MAX_TEXT := 640.0
const MIN_TEXT := 280.0
## The board's widest with Large text (TITLE words: a hint stays a few lines).
const LARGE_WIDTH := 880.0
## The board's room around the line (its wood, the OK button and the inset's margins).
const SIDE_ROOM := 172.0
## The HUD's top corners the board keeps clear of when there is room (hud.tscn: the bars and the
## run's line on the left, to 436; the bag, pause and minimap in the last 236 on the right): on a
## phone's wide screen it sits between them, on a 1280-wide one it hugs the right column (the
## Health numbers stay in sight).
const CLEAR_LEFT := 452.0
const CLEAR_RIGHT := 244.0
const TOP := 12.0
## Lower, when the boss bar takes the top of the screen.
const TOP_UNDER_BOSS_BAR := 84.0
const RING_COLOR := Color(1.0, 0.85, 0.35)

## The control pointed at (screen rect); empty: none.
var target := Rect2()
## The room at the top between the HUD's stats and its map's column (Hud.top_room(), set by the
## game): a hint with Large text, wider, stays in it when it can.
var top_room := Callable()
## Pushed down under the boss bar (the Hud says when).
var lowered := false:
	set(value):
		lowered = value
		_place()

var _board: PanelContainer
var _title: Label
var _text: Label
var _time := 0.0
var _tween: Tween
var _hint: HintDef
## Reads the taps on the board (its keys are the OK button's: Keys.NONE).
var _tap := TapGate.new(TapGate.Keys.NONE)
## The ring's pulse as last drawn, in steps (PULSE_STEPS): redrawn when it moved a step.
var _drawn_pulse := -1
## The arrow's triangle and its shadow, filled in place (no array built every draw).
var _arrow := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _arrow_shadow := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])

## The ring's pulse is drawn again this many times over its swing (not every frame).
const PULSE_STEPS := 12


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board = PanelContainer.new()
	var style := UiSkin.panel()
	style.content_margin_left = 20
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_board.add_theme_stylebox_override("panel", style)
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.gui_input.connect(_on_board_input)
	add_child(_board)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_board.add_child(row)
	var recess := UiSkin.section()
	recess.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recess.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(recess)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recess.add_child(column)
	_title = UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_title)
	_text = UiSkin.reading_label("")
	_text.custom_minimum_size.x = MIN_TEXT  # (fitted to each hint's line: _fit())
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_text)
	var ok := Button.new()
	ok.text = tr("OK")
	ok.focus_mode = Control.FOCUS_NONE
	ok.custom_minimum_size = Vector2(72, MenuWindow.TOUCH_MIN)
	ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func() -> void: dismissed.emit())
	row.add_child(ok)
	hide()


func _ready() -> void:
	resized.connect(_place)
	# Picking up a gamepad mid-hint: its words follow ("Tap" / "Press [A]").
	InputDevice.changed.connect(func() -> void:
		if visible and _hint:
			_text.text = _hint.shown_text()
			_fit()
			_place.call_deferred())


## `at`: the control it is about (screen rect), or an empty rect.
func show_hint(hint: HintDef, at: Rect2) -> void:
	_hint = hint
	_title.text = tr(hint.title)
	UiSkin.set_reading_style(_text)
	_text.text = hint.shown_text()
	_fit()
	_board.size = Vector2.ZERO  # (shrinks to the new words before _place)
	target = at
	_time = 0.0
	show()
	_place.call_deferred()
	if _tween:
		_tween.kill()
	_board.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_board, "modulate:a", 1.0, 0.15)
	Sfx.play_ui(Sfx.bank.ui_open, -8.0)
	queue_redraw()


## The control moved, showed up or went away (an empty rect: no ring).
func set_target(at: Rect2) -> void:
	if at != target:
		target = at
		queue_redraw()


func hide_hint() -> void:
	if _tween:
		_tween.kill()
	hide()
	target = Rect2()


func shown_text() -> String:
	return _text.text


## The board on screen (tests: its line fits on one).
func board_rect() -> Rect2:
	return _board.get_global_rect()


## Lines the hint's text takes (tests).
func text_lines() -> int:
	return _text.get_line_count()


## The text as wide as its line (or its title), within MIN_TEXT and the widest it may be: MAX_TEXT,
## or with Large text the room at the top (at most LARGE_WIDTH for the board).
func _fit() -> void:
	var line := Fonts.MAIN.get_string_size(_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiSkin.reading_size()).x
	var heading := Fonts.MAIN.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fonts.BODY).x
	_text.custom_minimum_size.x = clampf(ceilf(maxf(line, heading)) + 2.0, MIN_TEXT, _widest_text())


func _widest_text() -> float:
	if UiSkin.reading_size() <= Fonts.BODY:
		return MAX_TEXT
	var room := _room()
	var board := clampf(room.y - room.x, MAX_TEXT + SIDE_ROOM, LARGE_WIDTH) if room.y > room.x else LARGE_WIDTH
	return board - SIDE_ROOM


## The top's room (from x, to x) in this box's units; empty without the HUD.
func _room() -> Vector2:
	if not top_room.is_valid():
		return Vector2.ZERO
	return (top_room.call() as Vector2) - Vector2.ONE * get_global_rect().position.x


func _place() -> void:
	_board.size = _board.get_combined_minimum_size()
	var x := (size.x - _board.size.x) * 0.5
	var room := _room()
	if room.y - room.x >= _board.size.x:
		x = room.x + (room.y - room.x - _board.size.x) * 0.5  # between the stats and the map's column
	elif x < CLEAR_LEFT:
		x = maxf(x, minf(CLEAR_LEFT, size.x - CLEAR_RIGHT - _board.size.x))
	_board.position = Vector2(roundf(x * 0.5) * 2.0, TOP_UNDER_BOSS_BAR if lowered else TOP)


func _process(delta: float) -> void:
	if visible and target.has_area():
		_time += delta
		var step := roundi(_pulse() * PULSE_STEPS)
		if step != _drawn_pulse:
			_drawn_pulse = step
			queue_redraw()


func _pulse() -> float:
	return 0.5 + 0.5 * sin(_time * 5.0)


## A tap on the board dismisses the hint, read through the TapGate (keys are the OK button's):
## never the wheel, and the touch and the click a phone makes of it are one tap, not two (the
## second would dismiss the next hint, shown at once in its place).
func _on_board_input(event: InputEvent) -> void:
	var read := _tap.read(event, visible)
	if read == TapGate.IGNORE:
		return
	accept_event()
	if read == TapGate.TAKE:
		dismissed.emit()


## The ring around the control and the arrow pointing at it, from the middle of the screen.
func _draw() -> void:
	if not target.has_area():
		return
	var center := target.get_center()
	var radius := maxf(target.size.x, target.size.y) * 0.5 + 10.0
	var pulse := _pulse()
	draw_arc(center, radius + pulse * 6.0, 0.0, TAU, 48, Color(RING_COLOR, 0.35 + 0.45 * pulse), 4.0)
	draw_arc(center, radius + 14.0 + pulse * 6.0, 0.0, TAU, 48, Color(RING_COLOR, 0.15 * pulse), 2.0)
	var from := (size * 0.5 - center)
	var direction := from.normalized() if from.length() > 1.0 else Vector2.UP
	var tip := center + direction * (radius + 16.0 + pulse * 10.0)
	var side := direction.orthogonal() * 16.0
	var back := tip + direction * 26.0
	var shadow := Vector2(2, 3)
	_arrow[0] = tip
	_arrow[1] = back + side
	_arrow[2] = back - side
	for i in 3:
		_arrow_shadow[i] = _arrow[i] + shadow
	draw_colored_polygon(_arrow_shadow, Color(0.1, 0.05, 0.03, 0.8))
	draw_colored_polygon(_arrow, RING_COLOR)
	draw_line(back, back + direction * 22.0, RING_COLOR, 7.0)
