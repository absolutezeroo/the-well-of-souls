class_name HintBox
extends Control
## A tutorial hint on screen (see Tutorial): a small wooden board at the top, its title in gold,
## what to do in one line, an OK button; when the hint is about a control of the HUD, a ring
## pulses around that control and an arrow points at it. The board is as wide as its line (a
## short hint, a small board), up to MAX_TEXT: every hint's line fits that in English and French
## on every device (tutorial tests), a longer one (a long key name) wraps.

signal dismissed

## The line's width (UI units) the board grows to before it wraps: one line at 1280x720 and on a
## phone, the board clear of the minimap; and the least it takes (a short hint stays a board).
const MAX_TEXT := 640.0
const MIN_TEXT := 280.0
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
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	_title = UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_title)
	_text = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	_text.custom_minimum_size.x = MIN_TEXT  # (fitted to each hint's line: _fit())
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_text)
	var ok := Button.new()
	ok.text = tr("OK")
	ok.focus_mode = Control.FOCUS_NONE
	ok.custom_minimum_size = Vector2(72, 48)
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
	_text.text = hint.shown_text()
	_fit()
	target = at
	_time = 0.0
	show()
	_place.call_deferred()
	if _tween:
		_tween.kill()
	_board.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_board, "modulate:a", 1.0, 0.2)
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


## The text as wide as its line (or its title), within MIN_TEXT and MAX_TEXT.
func _fit() -> void:
	var line := Fonts.MAIN.get_string_size(_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fonts.BODY).x
	var heading := Fonts.MAIN.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fonts.BODY).x
	_text.custom_minimum_size.x = clampf(ceilf(maxf(line, heading)) + 2.0, MIN_TEXT, MAX_TEXT)


func _place() -> void:
	_board.size = _board.get_combined_minimum_size()
	var x := (size.x - _board.size.x) * 0.5
	if x < CLEAR_LEFT:
		x = maxf(x, minf(CLEAR_LEFT, size.x - CLEAR_RIGHT - _board.size.x))
	_board.position = Vector2(roundf(x), TOP_UNDER_BOSS_BAR if lowered else TOP)


func _process(delta: float) -> void:
	if visible and target.has_area():
		_time += delta
		queue_redraw()


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
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	draw_arc(center, radius + pulse * 6.0, 0.0, TAU, 48, Color(RING_COLOR, 0.35 + 0.45 * pulse), 4.0)
	draw_arc(center, radius + 14.0 + pulse * 6.0, 0.0, TAU, 48, Color(RING_COLOR, 0.15 * pulse), 2.0)
	var from := (size * 0.5 - center)
	var direction := from.normalized() if from.length() > 1.0 else Vector2.UP
	var tip := center + direction * (radius + 16.0 + pulse * 10.0)
	var side := direction.orthogonal() * 16.0
	var back := tip + direction * 26.0
	var shadow := Vector2(2, 3)
	draw_colored_polygon(PackedVector2Array([tip + shadow, back + side + shadow, back - side + shadow]), Color(0.1, 0.05, 0.03, 0.8))
	draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), RING_COLOR)
	draw_line(back, back + direction * 22.0, RING_COLOR, 7.0)
