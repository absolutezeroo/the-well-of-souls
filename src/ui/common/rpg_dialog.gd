class_name RpgDialog
extends Control
## A smaller panel in the game's skin (UiSkin), centred and as big as what it holds: the world
## dimmed behind, a wooden board with a gold ornate border, its title on a red ribbon over the
## top edge. No Close button (the panel using it puts its own buttons in `body`). For the
## pause menu, encounters, perk choices and the end of a run; RpgWindow is the full-screen one
## (both on an OrnateBoard).
## A menu for keys and gamepads (MenuNav).

## Where the dialog's contents go.
var body: VBoxContainer
## The words on the ribbon.
var title_label: Label

var _board: OrnateBoard
var _ribbon: PanelContainer


## `width`: the board's minimum width (0: as wide as its contents).
func _init(title_text: String = "", width: float = 0.0, dim_alpha: float = 0.72) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(MenuNav.GROUP)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = UiSkin.backdrop(dim_alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 14  # room for the ribbon above the board
	add_child(center)

	_board = OrnateBoard.new()  # the same board as RpgWindow's
	_board.custom_minimum_size.x = width
	center.add_child(_board)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 22)
	_board.add_child(margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)

	_ribbon = UiSkin.title(title_text)
	title_label = _ribbon.get_node(^"Words") as Label
	add_child(_ribbon)
	_ribbon.resized.connect(_place_ribbon)
	_board.item_rect_changed.connect(_place_ribbon)
	resized.connect(_place_ribbon)


func set_title(text: String, color: Color = UiSkin.TEXT) -> void:
	title_label.text = text
	title_label.add_theme_color_override("font_color", color)
	_place_ribbon.call_deferred()


## The board's least width (0: as wide as its contents).
func set_board_width(width: float) -> void:
	_board.custom_minimum_size.x = width


## The board's size on screen (tests, layout checks).
func board_rect() -> Rect2:
	return _board.get_global_rect()


func _place_ribbon() -> void:
	if not is_inside_tree():
		return
	var top := _board.get_global_rect().position.y - get_global_rect().position.y
	_ribbon.position = Vector2((size.x - _ribbon.size.x) * 0.5, top - 24)
