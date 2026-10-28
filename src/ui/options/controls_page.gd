class_name ControlsPage
extends VBoxContainer
## Options > Controls: what does what on the device in use. The controls of
## data/ui/input_prompts.tres in two columns, each with its keys and mouse buttons (PromptGlyph
## caps, every binding of the input map), its gamepad buttons in the pad's own names, or how it
## is done by touch. Picking up another device turns the page to it.
## On keys and gamepads the fight's controls (ActionPromptDef.remappable) are buttons: pressed,
## the page waits for the new key or button (Escape, or Start on a pad, gives up) and KeyBindings
## gives it (Settings.bindings). "Default keys" / "Default buttons" puts that device's back.

const ROW_HEIGHT := 32.0
## The narrowest a control's name gets before it wraps (UI units).
const NAME_WIDTH := 200.0

var _heading: Label
var _note: Label
var _columns: HBoxContainer
## Puts back the default keys or buttons of the device shown (hidden on touch).
var _reset: Button
## The control waiting for its new key or button (&"": none), and its button.
var _listening: StringName = &""
var _listening_button: Button
## The device the page waits on (InputDevice.Kind).
var _listening_kind := -1
## Why the last key was refused (empty: none), said in the note.
var _refusal := ""


func _init() -> void:
	add_theme_constant_override("separation", 8)
	_heading = UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
	add_child(_heading)
	_note = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)  # (on the wood: never dim)
	add_child(_note)
	var box := UiSkin.section()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(box)
	var scroll := UiParts.scroll()
	box.add_child(scroll)
	_columns = HBoxContainer.new()
	_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.add_theme_constant_override("separation", 28)
	scroll.add_child(_columns)
	_reset = MenuWindow.button("", Fonts.BODY, 44)
	_reset.name = "ResetBindingsButton"
	_reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	_reset.pressed.connect(reset_bindings)
	add_child(_reset)


func _ready() -> void:
	InputDevice.changed.connect(func() -> void:
		# (Another pad of the same kind, or the very press awaited, waking its family: still waiting.)
		if is_visible_in_tree() and not (_listening != &"" and InputDevice.kind == _listening_kind):
			refresh())


## Fills the page for the device in use (and stops waiting for a key).
func refresh() -> void:
	_listening = &""
	_listening_button = null
	var kind := InputDevice.kind
	match kind:
		InputDevice.Kind.GAMEPAD:
			var pad := InputDevice.pad_glyphs()
			_heading.text = tr("Gamepad: %s") % tr(pad.brand) if pad else tr("Gamepad")
		InputDevice.Kind.KEYBOARD:
			_heading.text = tr("Keyboard and mouse")
		_:
			_heading.text = tr("Touch")
	_show_note()
	_reset.visible = kind != InputDevice.Kind.TOUCH
	_reset.text = tr("Default buttons") if kind == InputDevice.Kind.GAMEPAD else tr("Default keys")
	UiParts.clear(_columns)
	var rows: Array[Array] = []
	for entry in Prompts.DATA.actions:
		if not entry.listed:
			continue
		if kind == InputDevice.Kind.TOUCH:
			if not entry.touch_text.is_empty():
				rows.append([entry, [] as Array[Dictionary]])
		else:
			var caps := Prompts.glyphs(entry.action, kind)
			if not caps.is_empty():
				rows.append([entry, caps])
	var half := ceili(rows.size() / 2.0)
	for part in [rows.slice(0, half), rows.slice(half)]:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 4)
		_columns.add_child(grid)
		for row: Array in part:
			_add_row(grid, row[0], row[1], kind)


## The control waiting for its new key or button (&"": none).
func listening() -> StringName:
	return _listening


## Waits for the next key (keyboard) or button (gamepad) to give `action` (its button pressed).
func listen(action: StringName) -> void:
	if not KeyBindings.is_remappable(action) or InputDevice.uses_touch():
		return
	_listening = action
	_listening_kind = InputDevice.kind
	_refusal = ""
	_listening_button = find_child(_button_name(action), true, false) as Button
	_show_note()


## Gives the control waited for the key or button of `event` (a press of the device shown);
## true if the event was the page's (taken, refused or the giving up).
func take(event: InputEvent) -> bool:
	if _listening == &"":
		return false
	var kind := InputDevice.kind
	var give_up := (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE) \
		or (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START)
	if give_up:
		_stop(_listening)
		return true
	var wanted := KeyBindings.bindable(event, kind)
	if wanted == null:
		return false
	var bindings := Settings.bindings.duplicate(true)
	var action := _listening
	var result := KeyBindings.set_first(bindings, action, wanted, kind)
	if result == KeyBindings.Result.RESERVED:
		var owner_entry := Prompts.DATA.action(KeyBindings.reserved_by(wanted))
		var what := tr(owner_entry.display_name) if owner_entry else tr("Move")
		_refusal = tr("That one is kept for: %s. Pick another.") % what
		_show_note()
		return true
	Settings.set_bindings(bindings)
	_stop(action)
	return true


## Back to the defaults of the device shown.
func reset_bindings() -> void:
	var bindings := Settings.bindings.duplicate(true)
	KeyBindings.reset(bindings, InputDevice.kind)
	Settings.set_bindings(bindings)
	refresh()


func _input(event: InputEvent) -> void:
	if _listening == &"" or not is_visible_in_tree():
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if not event.is_pressed():
		# The release of the key that chose the control (Enter, A) waits with it.
		if event is InputEventKey or event is InputEventJoypadButton:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		_stop(_listening)  # a click or a touch elsewhere gives up
		return
	if take(event):
		get_viewport().set_input_as_handled()


## Stops waiting; the page shows the control's keys again, its button focused.
func _stop(action: StringName) -> void:
	refresh()
	var button := find_child(_button_name(action), true, false) as Button
	if button and InputDevice.uses_buttons():
		button.grab_focus()


func _show_note() -> void:
	if _listening != &"":
		var entry := Prompts.DATA.action(_listening)
		var words := tr("Press the new button for %s. Start: keep it as it is.") if InputDevice.uses_gamepad() else tr("Press the new key for %s. Escape: keep it as it is.")
		_note.text = (_refusal + "\n" if not _refusal.is_empty() else "") + words % tr(entry.display_name)
		_note.add_theme_color_override("font_color", UiSkin.GOLD)
		if _listening_button:
			_listening_button.text = "..."
			for child in _listening_button.get_children():
				(child as CanvasItem).visible = false
		return
	_note.remove_theme_color_override("font_color")
	_note.add_theme_color_override("font_color", UiSkin.TEXT)
	if InputDevice.uses_touch():
		_note.text = tr("The controls of the device in hand. Pick up another (a key, a gamepad, a touch) and this page follows.")
	else:
		_note.text = tr("The controls of the device in hand. Choose a fight's control to give it another key or button.")


static func _button_name(action: StringName) -> String:
	return "%sKeyButton" % String(action).to_pascal_case()


## The rows shown (tests): [the control's words, what does it] per row.
func rows_text() -> Array[PackedStringArray]:
	var found: Array[PackedStringArray] = []
	for grid in _columns.get_children():
		var cells := grid.get_children()
		for i in range(0, cells.size() - 1, 2):
			var how := cells[i + 1]
			if how is Button and how.get_child_count() > 0:
				how = how.get_child(0)  # a control that can change: its caps in the button
			var words := PackedStringArray()
			if how is Label:
				words.append((how as Label).text)
			else:
				for cap in how.get_children():
					var shown := (cap as PromptGlyph).cap() if cap is PromptGlyph else {}
					if not shown.is_empty():
						words.append(Prompts.DATA.mouse_glyph(shown.button) if shown.shape == Prompts.Shape.MOUSE else str(shown.text))
			found.append(PackedStringArray([(cells[i] as Label).text, " ".join(words)]))
	return found


func _add_row(grid: GridContainer, entry: ActionPromptDef, caps: Array[Dictionary], kind: int) -> void:
	# Wrapped: a long French name takes two lines rather than pushing the page off a 720-line screen.
	var name_label := UiSkin.label(tr(entry.display_name), Fonts.BODY, UiSkin.TEXT, true)
	name_label.custom_minimum_size = Vector2(NAME_WIDTH, ROW_HEIGHT)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name_label)
	if caps.is_empty():
		var how := UiSkin.label(tr(entry.touch_text), Fonts.BODY, UiSkin.DIM, true)
		how.custom_minimum_size.x = 260
		grid.add_child(how)
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_END
	for cap in caps:
		var glyph := PromptGlyph.new()
		glyph.fixed = cap
		row.add_child(glyph)
	if not (entry.remappable and entry.parts.is_empty() and kind != InputDevice.Kind.TOUCH):
		grid.add_child(row)
		return
	# A control that can change: its caps in a button (pressed: wait for the new key).
	var button := Button.new()
	button.name = _button_name(entry.action)
	button.custom_minimum_size = Vector2(0.0, ROW_HEIGHT + 4.0)
	row.minimum_size_changed.connect(func() -> void: button.custom_minimum_size.x = row.get_combined_minimum_size().x + 20.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.tooltip_text = tr("Change")
	button.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		listen(entry.action))
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	grid.add_child(button)
