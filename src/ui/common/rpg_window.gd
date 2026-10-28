class_name RpgWindow
extends Control
## A big panel in the game's skin (UiSkin): the world dimmed behind, a wooden board with a gold
## ornate border (OrnateBoard, as RpgDialog's), its title on a red ribbon over the top edge, a
## Close button. Put what it shows in `body`. Runs while the game is paused. A menu for keys and
## gamepads (MenuNav): Close shows the Back key or button beside it.
## The header row is [header_left][spacer][header_right][Back's glyph][close_button]: windows
## add to header_left and header_right, never reach into the row by index.
## The board stays in the screen's safe area (SafeArea: a phone's camera hole hides none of it);
## the dim behind covers the whole screen.

signal close_requested

## Room around the board (UI units): the title's ribbon over its top edge stays on the screen,
## and a 720-line screen keeps the most room for finger-sized rows.
const MARGIN := Vector2(54, 28)

## Where the panel's contents go.
var body: VBoxContainer
## Right of the title (gold, counters...), before Close.
var header_right: HBoxContainer
## Left of the header (tabs, a portrait, a line of text...).
var header_left: HBoxContainer
## The header's row itself.
var header: HBoxContainer
## The header's Close button (to rename or relabel).
var close_button: Button

var _title: PanelContainer
var _board: OrnateBoard
## The screen's safe area: the board and its title are inside it.
var _safe := SafeArea.new()
## Between header_left and header_right: takes the room left (MenuWindow gives it to header_left).
var _spacer: Control


func _init(title_text: String = "") -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(MenuNav.GROUP)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = UiSkin.backdrop(0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	add_child(_safe)

	_board = OrnateBoard.new()
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.offset_left = MARGIN.x
	_board.offset_right = -MARGIN.x
	_board.offset_top = MARGIN.y + 10
	_board.offset_bottom = -MARGIN.y + 6
	_safe.add_child(_board)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 14)
	_board.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	header = HBoxContainer.new()
	header.set_meta(MenuNav.NOT_FIRST, true)  # the keys start in the body, not on Close
	header.add_theme_constant_override("separation", MenuWindow.TOUCH_GAP)
	column.add_child(header)
	header_left = HBoxContainer.new()
	header_left.add_theme_constant_override("separation", MenuWindow.TOUCH_GAP)
	header.add_child(header_left)
	# Empty, it takes no place in the row (no gap of its own): shown with its first child.
	header_left.hide()
	header_left.child_entered_tree.connect(_show_header_left)
	_spacer = Control.new()
	_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_spacer)
	header_right = HBoxContainer.new()
	header_right.add_theme_constant_override("separation", MenuWindow.TOUCH_GAP)
	header.add_child(header_right)
	close_button = Button.new()
	close_button.text = tr("Close")
	close_button.custom_minimum_size = Vector2(120, MenuWindow.TOUCH_MIN)
	close_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(PromptGlyph.make(&"ui_cancel"))
	header.add_child(close_button)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	column.add_child(body)

	# The title on its ribbon, straddling the board's top edge.
	_title = UiSkin.title(title_text)
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_safe.add_child(_title)
	_title.resized.connect(_place_title)
	_safe.resized.connect(_place_title)


func _show_header_left(_child: Node) -> void:
	header_left.show()


func set_title(text: String) -> void:
	(_title.get_node(^"Words") as Label).text = text
	_place_title.call_deferred()


func _place_title() -> void:
	_title.position = Vector2(roundf((_safe.size.x - _title.size.x) * 0.5), MARGIN.y - 14)


## A column of the board: a dark inset with a gold heading, its contents below.
static func section(heading: String) -> Dictionary:
	var box := UiSkin.section()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	box.add_child(column)
	var title := UiSkin.label(heading, Fonts.BODY, UiSkin.GOLD)
	column.add_child(title)
	return { "box": box, "column": column, "title": title }
