class_name UiParts
## Small pieces shared by the in-run panels (shop, encounters, pause, end of run, perk choice),
## on top of UiSkin (whose colors they use: UiSkin.GOOD / BAD): buttons, a touch-friendly scroll,
## emptying a container.


## A plain button (the game's default look: MenuWindow.button, the one factory) doing `action`;
## keys and gamepads reach it (MenuNav). At least MenuWindow.TOUCH_MIN on each side.
static func button(words: String, action: Callable, min_size := Vector2(0, MenuWindow.TOUCH_MIN), font_size := Fonts.BODY) -> Button:
	var result := MenuWindow.button(words, font_size, min_size.y)
	result.custom_minimum_size = Vector2(maxf(min_size.x, MenuWindow.TOUCH_MIN), maxf(min_size.y, MenuWindow.TOUCH_MIN))
	if action.is_valid():
		result.pressed.connect(action)
	return result


## Fills a two-column GridContainer with stat lines: [name, value] or [name, value, color]
## (the name dim on the left, the value right-aligned). What was in it goes.
static func stat_rows(grid: GridContainer, rows: Array) -> void:
	clear(grid)
	for row: Array in rows:
		grid.add_child(UiSkin.label(str(row[0]), Fonts.BODY, UiSkin.DIM))
		var value := UiSkin.label(str(row[1]), Fonts.BODY, row[2] if row.size() > 2 else UiSkin.TEXT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(value)


## A list that scrolls one way, with drag-to-scroll for phones (TouchScroll).
static func scroll(vertical := true) -> ScrollContainer:
	var result := ScrollContainer.new()
	if vertical:
		result.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	else:
		result.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.attach(result)
	return result


## A line of a list: a dash, then the words wrapped beside it (the dash is layout, never glued
## to a translated sentence).
static func bullet(words: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var dash := UiSkin.label("-", Fonts.BODY, color)
	dash.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(dash)
	var label := UiSkin.label(words, Fonts.BODY, color, true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


## Frees everything in `container` (out of the tree at once, so counts are right).
static func clear(container: Node) -> void:
	for child in container.get_children():
		if child is TouchScroll:
			continue
		container.remove_child(child)
		child.queue_free()


## A label in the skin that wraps, at a fixed width (so it knows its height in a centred box).
static func text(words: String, font_size: int, color: Color, width: float) -> Label:
	var label := UiSkin.label(words, font_size, color, true)
	label.custom_minimum_size.x = width
	return label
