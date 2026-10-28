class_name TabRow
extends HBoxContainer
## A row of tabs, the one way every window makes them (the options, the codex, the bag, the
## debug panel, the leaderboards): toggle buttons of one size, the one shown pressed (pressing
## it again keeps it pressed), a click when another is picked, `picked(index)` for the window
## to show it. In a menu the tabs join MenuNav's group "menu_tabs" (Q / E, LB / RB switch them,
## wrapping) and the tab keys' cap stands before them (design/interface.md, Devices).

signal picked(index: int)

## Every tab's least size (a long name makes its tab wider), and the room between two: a
## finger's (MenuWindow.TOUCH_MIN, TOUCH_GAP).
const SIZE := Vector2(112, 64)
const SEPARATION := 16

var buttons: Array[Button] = []
## Click when the player picks another tab (off where the window plays its own).
var sound := true
## The tabs answer Q / E and LB / RB (MenuNav.TABS); off for a row of sub-tabs.
var menu_tabs := true
var _current := -1


## `glyph`: the tab keys' cap before the tabs (with keys and gamepads only, PromptGlyph).
func _init(glyph: bool = true, in_menu_tabs: bool = true) -> void:
	menu_tabs = in_menu_tabs
	add_theme_constant_override("separation", SEPARATION)
	if glyph and in_menu_tabs:
		var keys := PromptGlyph.make(&"menu_tabs")
		keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(keys)


## A tab with words. `node_name` and `scene_owner`: reachable as %node_name (MenuWindow.expose).
func add_tab(words: String, node_name: String = "", scene_owner: Node = null, width: float = SIZE.x) -> Button:
	var button := MenuWindow.button(words, Fonts.BODY, SIZE.y)
	button.custom_minimum_size.x = width
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_button(button)
	if not node_name.is_empty():
		if scene_owner:
			MenuWindow.expose(button, node_name, scene_owner)
		else:
			button.name = node_name
	return button


## A tab drawn its own way (the bag's compartments: BagTab), added to the row.
func add_button(button: Button) -> Button:
	var index := buttons.size()
	button.toggle_mode = true
	if menu_tabs:
		button.add_to_group(MenuNav.TABS)
	button.pressed.connect(_on_pressed.bind(index))
	if button.get_parent() == null:
		add_child(button)
	buttons.append(button)
	return button


## Shows `index` pressed, the others not (no signal).
func select(index: int) -> void:
	_current = index
	for i in buttons.size():
		buttons[i].set_pressed_no_signal(i == index)


## The tab shown (-1 before any).
func current() -> int:
	return _current


func _on_pressed(index: int) -> void:
	if sound and index != _current:
		Sfx.play_ui(Sfx.bank.ui_click)
	select(index)
	picked.emit(index)
