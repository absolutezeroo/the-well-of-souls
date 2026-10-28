class_name DialogueScreen
extends Control
## A conversation over the screen (the Vigil-Keeper at the shrine): the screen dimmed a little,
## a wooden board (OrnateBoard) low in the middle holding a DialogueBox (PAGED: the words in its
## dark inset, about 58 characters a line at BODY), a tap anywhere, Enter or A going on page by page,
## Back (Escape, B, the phone's back button: the screen's own back()) closing it at once. When the
## last page is read on, it closes. A menu for keys and gamepads (MenuNav): what was focused
## under it gets the focus back. Built in code.

signal closed

## The board's width: the words get about 58 characters a line in French at BODY (at most 60:
## design/interface.md, Text).
const WIDTH := 932.0
## Between the board's edge and the box (inside its ornate border).
const BOARD_MARGIN := 18
## Room left under the board (the screen's bottom edge).
const BOTTOM := 36.0

var box: DialogueBox

var _dim: ColorRect
var _board: OrnateBoard


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group(MenuNav.GROUP)
	hide()
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = UiSkin.backdrop(0.45)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)
	_board = OrnateBoard.new()
	_board.name = "Board"
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, BOARD_MARGIN)
	_board.add_child(margin)
	box = DialogueBox.new(DialogueBox.Mode.PAGED, WIDTH - _board_room())
	box.name = "DialogueBox"
	box.focus_mode = Control.FOCUS_ALL
	box.finished.connect(close)
	margin.add_child(box)
	resized.connect(_place)
	_board.resized.connect(_place)
	# A page of more or fewer lines: the board follows (grows up from the bottom, or shrinks).
	_board.minimum_size_changed.connect(_place, CONNECT_DEFERRED)


## Says `spoken` (one or more lines, Dialogues.Spoken) over the screen.
func open(spoken: Array[Dialogues.Spoken]) -> void:
	show()
	box.say(spoken)
	_place.call_deferred()
	if InputDevice.uses_buttons():
		box.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()
	closed.emit()


func _place() -> void:
	var width := minf(WIDTH, size.x - 48.0)
	box.custom_minimum_size.x = width - _board_room()
	_board.size = Vector2(width, _board.get_combined_minimum_size().y)
	_board.position = Vector2(roundf((size.x - width) * 0.5), roundf(size.y - _board.size.y - BOTTOM))


## What the board keeps around the box on its sides (its wood's margins and BOARD_MARGIN).
func _board_room() -> float:
	var wood := _board.get_theme_stylebox(&"panel")
	return wood.get_margin(SIDE_LEFT) + wood.get_margin(SIDE_RIGHT) + BOARD_MARGIN * 2.0


func _on_dim_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and box.press(event):
		_dim.accept_event()
