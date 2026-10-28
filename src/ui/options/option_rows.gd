class_name OptionRows
## The rows the Options window is made of, built one way for every page (OptionsPanel,
## PrivacyPage): a page of columns that scroll on their own, a section with its gold heading, a
## setting's name over what it does, a choice of a few buttons, a slider with its value, an on/off
## switch whose name flips it too. Each control is made reachable as %Name from `scene_owner`
## (the window: tests and other scripts find it there).

## A slider's length beside its words, and its height: the strip a finger grabs (UI units, at
## least MenuWindow.TOUCH_MIN).
const SLIDER_WIDTH := 180.0
const SLIDER_HEIGHT := 64.0
## Room between two rows of a section (two things to tap: MenuWindow.TOUCH_GAP), and between a
## choice's words and its buttons.
const ROW_GAP := MenuWindow.TOUCH_GAP
const WORDS_GAP := 4
## The smallest move of a slider under a finger or the mouse (smooth; every range and key step
## is a multiple of it, so a value set in code stays exact).
const FINE_STEP := 0.01
## A slider's meta: the label showing its value.
const VALUE_META := &"value_label"


## A page of settings in `body`: columns side by side (each scrolls on its own).
static func page(body: VBoxContainer) -> HBoxContainer:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	body.add_child(columns)
	return columns


## A column of a page, scrolling if the screen is short.
static func column(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var result := VBoxContainer.new()
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_constant_override("separation", 8)
	scroll.add_child(result)
	return result


## A dark inset with a gold heading in `parent`: returns where its rows go.
static func section(parent: VBoxContainer, heading: String) -> VBoxContainer:
	var box: Dictionary = RpgWindow.section(heading)
	parent.add_child(box.box)
	(box.column as VBoxContainer).add_theme_constant_override("separation", ROW_GAP)
	return box.column


## A setting's name over what it does (the helper line is the child "Note": note_of()).
static func words(title: String, helper: String) -> VBoxContainer:
	var result := VBoxContainer.new()
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_constant_override("separation", 0)
	# Both wrap: a long name in French (beside three buttons) must not push the window past a
	# 1280-wide screen.
	result.add_child(UiSkin.label(title, Fonts.BODY, UiSkin.TEXT, true))
	var note := UiSkin.label(helper, Fonts.BODY, UiSkin.DIM, true)
	note.name = "Note"
	result.add_child(note)
	return result


## The helper line of words().
static func note_of(name_and_note: VBoxContainer) -> Label:
	return name_and_note.get_node(^"Note") as Label


## A choice of a few: its name and what it does (`title` empty: only that line), then a row of
## toggle buttons sharing the column's width, one per [value, text, node name] of `entries`.
## Returns value -> button (the caller keeps the one in use pressed). `note_name`: the helper
## line reachable by that name (for words that change later).
static func choice(scene_owner: Node, parent: VBoxContainer, title: String, helper: String, entries: Array, note_name := "") -> Dictionary:
	# Its words and its buttons together (the section keeps ROW_GAP between rows).
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", WORDS_GAP)
	parent.add_child(group)
	if title.is_empty():
		group.add_child(UiSkin.label(helper, Fonts.BODY, UiSkin.DIM, true))
	else:
		var name_and_note := words(title, helper)
		group.add_child(name_and_note)
		if not note_name.is_empty():
			MenuWindow.expose(note_of(name_and_note), note_name, scene_owner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", MenuWindow.TOUCH_GAP)
	group.add_child(row)
	var buttons := {}
	for entry: Array in entries:
		var button := MenuWindow.button(entry[1], Fonts.BODY, MenuWindow.TOUCH_MIN)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
		buttons[entry[0]] = button
		MenuWindow.expose(button, entry[2], scene_owner)
	return buttons


## A slider: its name and what it does, the slider, its value (the label in its VALUE_META).
## `step`: what a key or a gamepad moves it by; a finger or the mouse moves it smoothly (by
## FINE_STEP) and a tap on its track jumps there. A finger-sized strip (SLIDER_HEIGHT) that keeps
## its drags from the column's touch scrolling (TouchScroll). `wide`: the slider takes as much
## room as the words (a page of one column, where a short one would sit far from its name).
static func slider(scene_owner: Node, parent: VBoxContainer, title: String, helper: String, low: float, high: float, step: float, node_name: String, wide := false) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	row.add_child(words(title, helper))
	var result := HSlider.new()
	result.min_value = low
	result.max_value = high
	result.step = FINE_STEP
	result.set_meta(MenuNav.KEY_STEP, step)
	result.scrollable = false  # (the wheel scrolls the column, never changes a value by surprise)
	result.custom_minimum_size = Vector2(SLIDER_WIDTH, SLIDER_HEIGHT)
	result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if wide:
		result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(result)
	var value := UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
	value.custom_minimum_size.x = 76  # ("100 %": every slider of a page the same length)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value)
	result.set_meta(VALUE_META, value)
	MenuWindow.expose(result, node_name, scene_owner)
	return result


## An on/off option: its name and what it does, the switch on the right. Tapping the name
## flips it too.
static func check(scene_owner: Node, parent: VBoxContainer, title: String, helper: String, node_name: String) -> CheckButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var name_and_note := words(title, helper)
	name_and_note.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(name_and_note)
	var result := CheckButton.new()
	# The switch's drawing is smaller; its touch area a finger's.
	result.custom_minimum_size = Vector2(maxf(MenuWindow.SWITCH_SIZE.x + 8, MenuWindow.TOUCH_MIN), MenuWindow.TOUCH_MIN)
	result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	MenuWindow.style_switch(result)
	row.add_child(result)
	name_and_note.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed \
				and Rect2(Vector2.ZERO, name_and_note.size).has_point(click.position):
			result.button_pressed = not result.button_pressed)
	MenuWindow.expose(result, node_name, scene_owner)
	return result
