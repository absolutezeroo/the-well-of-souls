class_name PcTests
extends TestSuite
## The game on a computer and with a gamepad (docs/design/interface.md, "Devices"). Unit part
## (run by the unit suite): the device in use (InputDevice) from keys, gamepad buttons and sticks
## (the dead zone), touches and the mouse; the prompts' words and glyphs per device and gamepad
## family; the input map; the settings; the canvas's scale (PixelGrid). Title part (title
## suite): the title's panels with keys only, and their layout at every screen size. Game part
## (game suite): the HUD per device, the mouse in a fight, pausing, every in-run panel with keys
## and a gamepad, and the HUD's layout at every screen size.

const PixelGridScript := preload("res://src/autoload/pixel_grid.gd")  # its static helpers are called on the script, not the autoload
const SettingsScript := preload("res://src/autoload/settings.gd")

## Screens the layouts must hold at: computers (16:9, 16:10, 21:9, 4:3) and phones.
const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1920, 1080), Vector2i(2560, 1440),
	Vector2i(1280, 800), Vector2i(3440, 1440), Vector2i(1024, 768), Vector2i(2340, 1080), Vector2i(1540, 720),
]


# --- Helpers ------------------------------------------------------------------------------

func _key(code: Key, pressed: bool = true, alt: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.alt_pressed = alt
	Input.parse_input_event(event)


## A key pressed and let go, a frame each.
func _tap_key(code: Key) -> void:
	_key(code, true)
	await _frames(1)
	_key(code, false)
	await _frames(1)


func _pad_button(button: JoyButton, pressed: bool = true) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap_pad(button: JoyButton) -> void:
	_pad_button(button, true)
	await _frames(1)
	_pad_button(button, false)
	await _frames(1)


func _pad_axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _screen_touch(at: Vector2, pressed: bool, emulated: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = pressed
	if emulated:
		event.device = InputEvent.DEVICE_ID_EMULATION
	Input.parse_input_event(event)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func _keys_mode() -> void:
	InputDevice.use(InputDevice.Kind.KEYBOARD)
	InputDevice.navigating = true


## Sets the window to `size` and waits for the layouts to follow.
func _window(size: Vector2i) -> void:
	get_tree().root.size = size
	await _frames(3)


## Back to the test runner's window (headless: 64x64).
func _restore_window(size: Vector2i) -> void:
	get_tree().root.size = size
	await _frames(2)


func _rect_of(node: Node) -> Rect2:
	if node is Control:
		var control := node as Control
		return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
	if node is ActionButton:
		var button := node as ActionButton
		var scale := button.get_global_transform_with_canvas().get_scale().x
		var radius := button.radius * scale
		var center := button.get_global_transform_with_canvas().origin
		return Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	return Rect2()


## Layout problems of `widgets` (name -> node) on the screen: one out of the viewport, two
## overlapping. Empty when the layout holds.
func _layout_problems(widgets: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var screen := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(1.0)
	var rects := {}
	for widget_name: String in widgets:
		var node: Node = widgets[widget_name]
		if node == null or not is_instance_valid(node) or not (node as CanvasItem).is_visible_in_tree():
			continue
		var rect := _rect_of(node)
		if not rect.has_area():
			continue
		rects[widget_name] = rect
		if not screen.encloses(rect):
			problems.append("%s out of the screen (%s in %s)" % [widget_name, rect, screen.size])
	var names: Array = rects.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Rect2 = rects[names[i]]
			var b: Rect2 = rects[names[j]]
			if a.intersects(b) and a.intersection(b).get_area() > 4.0:
				problems.append("%s overlaps %s" % [names[i], names[j]])
	return problems


## Every visible control of a panel inside the screen (a list's rows may scroll out of their
## box: only the box counts).
func _panel_outside(root: Control) -> Array[String]:
	var problems: Array[String] = []
	var screen := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(1.0)
	var nodes: Array[Node] = [root]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		if node is CanvasItem and not (node as CanvasItem).visible:
			continue
		if node is Control:
			var rect := _rect_of(node)
			if rect.has_area() and not screen.encloses(rect):
				problems.append("%s %s" % [root.get_path_to(node), rect])
		if node is ScrollContainer:
			continue
		nodes.append_array(node.get_children())
	return problems


## Keys only: the menu on top holds the focus, the arrows move it inside it (and keep it there,
## wrapping at its edges). `panel`: what was opened (the menu or what holds it).
func _check_keys_reach(panel: Control, what: String, move: bool = true) -> void:
	_keys_mode()
	await _frames(3)
	var top := MenuNav.top_menu()
	check(top != null and (top == panel or panel.is_ancestor_of(top) or top.is_ancestor_of(panel)), "%s: its menu is the one on top" % what)
	if top == null:
		return
	var focus := _focus()
	check(focus != null and top.is_ancestor_of(focus), "%s: the keys start on one of its buttons (%s)" % [what, String(focus.name) if focus else "none"])
	if not move:
		return
	var count := MenuNav.focusables(top).size()
	var seen := {}
	for code: Key in [KEY_DOWN, KEY_DOWN, KEY_RIGHT, KEY_DOWN, KEY_UP, KEY_LEFT, KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT]:
		await _tap_key(code)
		var now := _focus()
		if now == null or not top.is_ancestor_of(now):
			check(false, "%s: the arrows keep the focus inside (lost after %s)" % [what, OS.get_keycode_string(code)])
			return
		seen[now] = true
	check(count < 2 or seen.size() >= 2, "%s: the arrows move between its %d buttons" % [what, count])


# --- Unit ---------------------------------------------------------------------------------

func run_unit() -> void:
	var before := InputDevice.kind
	_test_input_map()
	await _test_device_switching()
	_test_prompts()
	_test_texts_per_device()
	_test_font_glyphs()
	await _test_settings()
	await _test_canvas_scale()
	_test_whole_art_pixels()
	_test_skin_grid()
	_test_round_buttons_whole()
	await _test_menu_nav_unit()
	_test_contrast()
	_test_colour_cues()
	InputDevice.use(before)


## The input map has what the prompts name, and the pause never sits on a fight's button.
func _test_input_map() -> void:
	for entry in Prompts.DATA.actions:
		for action in entry.actions():
			check(InputMap.has_action(action), "the input map has %s (input_prompts.tres)" % action)
		check(not entry.display_name.is_empty(), "%s has a name for the Controls page" % entry.action)
	var events := InputMap.action_get_events(&"pause")
	var keys := events.filter(func(e: InputEvent) -> bool: return e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_ESCAPE)
	var start := events.filter(func(e: InputEvent) -> bool: return e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_START)
	check(not keys.is_empty() and not start.is_empty(), "Escape and Start pause")
	var b_pauses := events.any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_B)
	check(not b_pauses, "a gamepad's B (a skill) never pauses")
	check(InputMap.action_get_events(&"ui_focus_next").is_empty(), "Tab is the bag, not the GUI's next focus")
	for action: StringName in [&"move_up", &"attack", &"skill_1", &"skill_2", &"skill_3", &"skill_4", &"quick_item", &"belt_2", &"belt_3", &"interact", &"offers", &"inventory", &"map", &"pause"]:
		var on_pad := InputMap.action_get_events(action).any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton or e is InputEventJoypadMotion)
		var on_keys := InputMap.action_get_events(action).any(func(e: InputEvent) -> bool: return e is InputEventKey)
		check(on_pad and on_keys, "%s works on keys and on a gamepad" % action)
	# Keys named after what they do (M the map, I the bag, E interact, C the perks) follow the
	# letter wherever the layout puts it (on a French keyboard, M is not in QWERTY's M place: it
	# showed "Comma" and sat on the comma key); keys chosen for their place (move, attack, skills,
	# belt) follow the place (Z Q S D on a French keyboard).
	for action: StringName in [&"map", &"inventory", &"interact", &"offers"]:
		var letters := InputMap.action_get_events(action).filter(func(e: InputEvent) -> bool: return e is InputEventKey and (e as InputEventKey).keycode != KEY_NONE and (e as InputEventKey).physical_keycode == KEY_NONE)
		check(not letters.is_empty(), "%s is bound by its letter, not its place" % action)
	for action: StringName in [&"move_up", &"move_left", &"attack", &"skill_1", &"quick_item"]:
		var places := InputMap.action_get_events(action).filter(func(e: InputEvent) -> bool: return e is InputEventKey and (e as InputEventKey).physical_keycode != KEY_NONE)
		check(not places.is_empty(), "%s is bound by its place on the keyboard" % action)
	check(Prompts.key_word(KEY_M | Prompts.LOGICAL) == "M" and Prompts.key_word(KEY_COMMA) == ",", "a key cap reads its letter or its sign, never a key name like \"Comma\" (%s, %s)" % [Prompts.key_word(KEY_M | Prompts.LOGICAL), Prompts.key_word(KEY_COMMA)])


## The device in use follows the last real input (events reach the game on the next frame).
func _test_device_switching() -> void:
	var changes := [0]
	var count := func() -> void: changes[0] += 1
	InputDevice.changed.connect(count)
	InputDevice.use(InputDevice.Kind.TOUCH)
	_key(KEY_W)
	await _frames(1)
	_key(KEY_W, false)
	await _frames(1)
	check(InputDevice.kind == InputDevice.Kind.KEYBOARD and InputDevice.uses_buttons(), "a key: the keyboard is in use")
	check(changes[0] >= 1, "...and the change is signalled")
	var rest := InputEventMouseMotion.new()
	rest.position = Vector2(10, 10)
	Input.parse_input_event(rest)
	await _frames(1)
	_pad_axis(JOY_AXIS_LEFT_X, 0.3)
	await _frames(1)
	check(InputDevice.kind == InputDevice.Kind.KEYBOARD, "a stick leaning less than its dead zone (drift) changes nothing")
	_pad_axis(JOY_AXIS_LEFT_X, 0.9)
	await _frames(1)
	check(InputDevice.kind == InputDevice.Kind.GAMEPAD, "a stick pushed past its dead zone: the gamepad")
	_pad_axis(JOY_AXIS_LEFT_X, 0.0)
	await _frames(1)
	_key(KEY_SPACE)
	await _frames(1)
	_key(KEY_SPACE, false)
	await _frames(1)
	await _tap_pad(JOY_BUTTON_A)
	check(InputDevice.kind == InputDevice.Kind.GAMEPAD and InputDevice.navigating, "a gamepad button: the gamepad, steering menus")
	var nudge := InputEventMouseMotion.new()
	nudge.relative = Vector2(1, 1)
	nudge.screen_relative = Vector2(1, 1)
	nudge.position = Vector2(11, 11)
	Input.parse_input_event(nudge)
	await _frames(1)
	check(InputDevice.kind == InputDevice.Kind.GAMEPAD, "a nudged mouse (a pixel) doesn't take over from the gamepad")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(30, 0)
	motion.screen_relative = Vector2(30, 0)
	motion.position = Vector2(40, 10)
	Input.parse_input_event(motion)
	await _frames(1)
	check(InputDevice.kind == InputDevice.Kind.KEYBOARD and not InputDevice.navigating, "a mouse moved for real: keyboard and mouse, the focus frame put away")
	_screen_touch(Vector2(100, 100), true, true)
	await _frames(1)
	_screen_touch(Vector2(100, 100), false, true)
	await _frames(1)
	check(InputDevice.kind == InputDevice.Kind.KEYBOARD, "the mouse's emulated touches are not a touch screen")
	_screen_touch(Vector2(100, 100), true)
	await _frames(1)
	_screen_touch(Vector2(100, 100), false)
	await _frames(1)
	check(InputDevice.kind == InputDevice.Kind.TOUCH and InputDevice.uses_touch(), "a real touch: touch")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await _frames(1)
	check(InputDevice.kind == InputDevice.Kind.TOUCH, "a mouse click after a touch keeps the touch buttons (the mouse presses them too)")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(release)
	await _frames(1)
	InputDevice.use(InputDevice.Kind.GAMEPAD, &"playstation")
	InputDevice.pad = 3
	InputDevice._on_joy_connection_changed(3, false)
	check(InputDevice.kind == InputDevice.Kind.KEYBOARD, "the gamepad in use unplugged: back to the keyboard")
	check(InputDevice.family == &"playstation", "...the family kept for its names")
	InputDevice.changed.disconnect(count)
	# The families, from the pads' names.
	var data := Prompts.DATA
	check(data.family_for("Xbox Series X Controller").id == &"xbox" and data.family_for("XInput Gamepad (GLFW)").id == &"xbox", "Xbox pads are Xbox")
	check(data.family_for("PS5 Controller").id == &"playstation" and data.family_for("Sony DualSense Wireless Controller").id == &"playstation" and data.family_for("PS4 Controller").id == &"playstation", "PlayStation pads are PlayStation")
	check(data.family_for("Nintendo Switch Pro Controller").id == &"nintendo", "a Switch pad is Nintendo")
	check(data.family_for("8BitDo Generic USB Gamepad").id == &"generic", "an unknown pad is generic")


## Prompts name the right key or button on each device and family.
func _test_prompts() -> void:
	var keyboard := InputDevice.Kind.KEYBOARD
	check(Prompts.glyph(&"interact", keyboard).text == "E" and Prompts.glyph(&"attack", keyboard).text == "Space", "keyboard prompts: E to use, Space to attack")
	check(Prompts.glyph(&"move", keyboard).text == "WASD", "moving reads WASD (the keyboard's own letters)")
	check(Prompts.glyph(&"pause", keyboard).text == "Esc" and Prompts.glyph(&"skill_1", keyboard).text == "1", "Esc pauses, 1 rolls")
	var attack_all := Prompts.glyphs(&"attack", keyboard)
	check(attack_all.size() == 3 and attack_all[2].shape == Prompts.Shape.MOUSE and attack_all[2].button == MOUSE_BUTTON_LEFT, "the Controls page lists Space, J and the left mouse button for the attack")
	check(not Prompts.glyphs(&"ui_accept", keyboard).any(func(cap: Dictionary) -> bool: return str(cap.text).begins_with("Kp")), "no keypad twins on the Controls page")
	var pad := InputDevice.Kind.GAMEPAD
	InputDevice.use(pad, &"xbox")
	check(Prompts.glyph(&"interact").text == "RT" and Prompts.glyph(&"attack").text == "X" and Prompts.glyph(&"skill_1").text == "A", "Xbox: RT uses, X attacks, A rolls")
	check(Prompts.glyph(&"attack").shape == Prompts.Shape.ROUND and Prompts.glyph(&"interact").shape == Prompts.Shape.SHOULDER and Prompts.glyph(&"move").shape == Prompts.Shape.STICK, "round face buttons, a trigger's shape, a stick")
	check(Prompts.glyph(&"pause").text == "Menu" and Prompts.glyph(&"inventory").text == "View", "Xbox: Menu pauses, View opens the bag")
	InputDevice.use(pad, &"playstation")
	check(Prompts.glyph(&"attack").text == "□" and Prompts.glyph(&"skill_1").text == "✕" and Prompts.glyph(&"interact").text == "R2", "PlayStation: □ attacks, ✕ rolls, R2 uses")
	check(Prompts.glyph(&"ui_cancel").text == "○" and Prompts.glyph(&"menu_tabs").text == "L1 / R1", "PlayStation: ○ goes back, L1 / R1 switch tabs")
	InputDevice.use(pad, &"nintendo")
	check(Prompts.glyph(&"skill_1").text == "B" and Prompts.glyph(&"skill_2").text == "A" and Prompts.glyph(&"interact").text == "ZR", "Nintendo: its letters where its buttons are (B at the bottom), ZR uses")
	InputDevice.use(InputDevice.Kind.TOUCH)
	check(Prompts.glyph(&"interact").is_empty() and Prompts.inline(&"interact").is_empty(), "touch: no key to show")
	check(Prompts.glyph(&"toggle_fullscreen", InputDevice.Kind.GAMEPAD).is_empty(), "nothing bound on a gamepad: no glyph")
	var glyph := PromptGlyph.make(&"interact")
	add_child(glyph)
	check(not glyph.visible, "a prompt's cap hides on touch")
	InputDevice.use(InputDevice.Kind.KEYBOARD)
	check(glyph.visible and glyph.cap().text == "E" and glyph.size.x >= PromptGlyph.HEIGHT, "...and shows the key with the keyboard")
	InputDevice.use(InputDevice.Kind.GAMEPAD, &"xbox")
	check(glyph.visible and glyph.cap().text == "RT", "...the trigger with an Xbox pad")
	glyph.free()


## Sentences in the device's words, codes filled with its keys.
func _test_texts_per_device() -> void:
	InputDevice.use(InputDevice.Kind.TOUCH)
	check(Prompts.pick("Tap to skip", "Press {ui_accept} to skip") == "Tap to skip", "touch: the touch sentence")
	InputDevice.use(InputDevice.Kind.KEYBOARD)
	check(Prompts.pick("Tap to skip", "Press {ui_accept} to skip") == "Press [Enter] to skip", "keyboard: the key in the sentence")
	check(Prompts.pick("Tap to skip", "") == "Tap to skip", "no keys sentence: the touch one serves")
	check(Prompts.fill("{interact} to use {name}") == "[E] to use {name}", "codes that aren't controls stay for format()")
	InputDevice.use(InputDevice.Kind.GAMEPAD, &"playstation")
	check(Prompts.pick("Tap to skip", "Press {ui_accept} to skip") == "Press [✕] to skip", "a PlayStation pad: its cross")
	# The tutorial's hints that name a control say it for keys and gamepads too.
	var tutorial: TutorialDef = CONTENT.tutorial
	for hint in tutorial.hints:
		var touch_words := hint.text.to_lower()
		if touch_words.contains("tap") or touch_words.contains("thumb"):
			check(not hint.button_text.is_empty(), "the %s hint has words for keys and gamepads" % hint.id)
		if not hint.button_text.is_empty():
			check(hint.button_text.length() <= 120, "%s's keys text is short enough for two lines (%d)" % [hint.id, hint.button_text.length()])
			check(not hint.button_text.to_lower().contains("tap"), "%s's keys text never says tap" % hint.id)
	InputDevice.use(InputDevice.Kind.KEYBOARD)
	var move: HintDef = tutorial.hint(&"move")
	check(move.shown_text() == "Walk with [WASD].", "the move hint on a keyboard: %s" % move.shown_text())
	InputDevice.use(InputDevice.Kind.GAMEPAD, &"xbox")
	check(tutorial.hint(&"merchant").shown_text().contains("[RT]"), "the merchant's hint on a gamepad names its trigger")
	InputDevice.use(InputDevice.Kind.TOUCH)
	check(move.shown_text() == tr(move.text), "and on touch, the thumb")
	# Loading tips about a control follow the device too.
	var tips: LoadingTipsDef = load("res://data/ui/loading_tips.tres")
	check(not tips.control_tips.is_empty(), "loading tips about the controls")
	InputDevice.use(InputDevice.Kind.KEYBOARD)
	check(tips.control_tips.all(func(tip: DeviceText) -> bool: return tip.text().contains("[") and not tip.text().to_lower().contains("tap")), "...on a keyboard with its keys")
	InputDevice.use(InputDevice.Kind.TOUCH)
	check(tips.control_tips.all(func(tip: DeviceText) -> bool: return not tip.text().contains("[")), "...on touch with taps")


## The font draws the prompts' glyphs (never a fallback font's).
func _test_font_glyphs() -> void:
	for glyph in ["✕", "○", "□", "△", "←", "↑", "→", "↓"]:
		check(Fonts.MAIN.has_char(glyph.unicode_at(0)), "the pixel font has %s" % glyph)
	for pad in Prompts.DATA.pads:
		for word in pad.button_glyphs + pad.axis_glyphs:
			for i in word.length():
				check(Fonts.MAIN.has_char(word.unicode_at(i)), "the font draws %s's %s" % [pad.id, word])


## Fullscreen and the interface's size are saved, and older settings files get the defaults.
func _test_settings() -> void:
	var path := "user://test_settings_%d.cfg" % OS.get_process_id()
	var saved_path := Settings.path
	var old := ConfigFile.new()
	old.set_value("options", "master_volume", 0.5)
	old.save(path)
	Settings.path = path
	var full := Settings.fullscreen
	var size := Settings.ui_size
	Settings.fullscreen = true
	Settings.ui_size = Settings.UI_SMALL
	Settings.load_settings()
	check(Settings.fullscreen == true and Settings.ui_size == Settings.UI_SMALL, "a settings file from before keeps what it doesn't know")
	Settings.fullscreen = false
	Settings.ui_size = Settings.UI_BIG
	Settings.set_option(&"fullscreen", true)
	Settings.set_option(&"ui_size", Settings.UI_MEDIUM)
	Settings.fullscreen = false
	Settings.ui_size = Settings.UI_BIG
	Settings.load_settings()
	check(Settings.fullscreen and Settings.ui_size == Settings.UI_MEDIUM, "fullscreen and the interface size are saved")
	var bad := ConfigFile.new()
	bad.set_value("options", "ui_size", 9)
	bad.save(path)
	Settings.load_settings()
	check(Settings.ui_size == Settings.UI_SMALL, "an interface size out of range is held to the smallest")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Settings.path = saved_path
	# F11 and Alt+Enter, anywhere.
	Settings.fullscreen = false
	await _tap_key(KEY_F11)
	check(Settings.fullscreen, "F11: fullscreen")
	_key(KEY_ENTER, true, true)
	await _frames(1)
	_key(KEY_ENTER, false, true)
	await _frames(1)
	check(not Settings.fullscreen, "Alt+Enter: back to a window")
	Settings.fullscreen = full
	Settings.ui_size = size
	Settings.apply()


## The canvas's scale goes by whole steps of 0.5 (whole font pixels), the canvas fills the rest of
## the screen at least as big as the layouts' 1280x720, and the camera keeps the floor's framing.
func _test_canvas_scale() -> void:
	check(PixelGridScript.canvas_scale(1.0667, Settings.UI_BIG) == 1.0 and PixelGridScript.canvas_scale(1.5, Settings.UI_BIG) == 1.5, "1366x768 at x1, 1080 lines at x1.5")
	check(PixelGridScript.canvas_scale(2.6875, Settings.UI_BIG) == 2.5 and PixelGridScript.canvas_scale(2.0, Settings.UI_MEDIUM) == 1.5, "x2.5 for a big screen; Medium a step smaller")
	check(PixelGridScript.canvas_scale(1.5, Settings.UI_SMALL) == 1.0 and PixelGridScript.canvas_scale(0.8, Settings.UI_SMALL) == 0.8, "never under x1; a small screen keeps its own scale")
	var before := get_tree().root.size
	for size in SIZES:
		await _window(size)
		var visible := get_viewport().get_visible_rect().size
		var scale := PixelGrid.ui_scale()
		var fit := minf(size.x / 1280.0, size.y / 720.0)
		check(visible.x >= 1279.0 and visible.y >= 719.0, "%s: the canvas is at least 1280x720 (%s)" % [size, visible])
		check(fit < 1.0 or is_equal_approx(fposmod(scale, 0.5), 0.0), "%s: a whole step of scale (x%s)" % [size, scale])
		check(is_equal_approx(visible.x * scale, size.x) or is_equal_approx(visible.y * scale, size.y), "%s: the canvas fills the screen, never stretched" % size)
		var art_pixel := PixelGridScript.ART_PIXEL * PixelGrid.camera_zoom(1.5) * scale
		check(is_equal_approx(art_pixel, PixelGridScript.art_pixel_size(1.5, fit)), "%s: the floor's camera draws an art pixel on %s screen pixels, its framing rounded down to a whole size (%s)" % [size, PixelGridScript.art_pixel_size(1.5, fit), art_pixel])
	Settings.ui_size = Settings.UI_MEDIUM
	await _window(Vector2i(2560, 1440))
	check(is_equal_approx(PixelGrid.ui_scale(), 1.5) and is_equal_approx(PixelGrid.camera_zoom(1.5), 2.0), "Medium on 1440 lines: x1.5, the floor framed as at x2 (6 screen pixels per art pixel)")
	Settings.ui_size = Settings.UI_BIG
	await _restore_window(before)


## Decision 0007: a world camera draws every art pixel on a whole number of screen pixels, its
## designed framing rounded down (the wider view), whatever the window and the interface size.
## The dungeon and the temple (designed at 1.5) and the village (2) on common screens.
func _test_whole_art_pixels() -> void:
	var expected: Array = [
		[Vector2i(1280, 720), 1.5, 3], [Vector2i(1366, 768), 1.5, 3], [Vector2i(1600, 900), 1.5, 3],
		[Vector2i(1920, 1080), 1.5, 4], [Vector2i(2340, 1080), 1.5, 4], [Vector2i(2560, 1440), 1.5, 6],
		[Vector2i(3840, 2160), 1.5, 9], [Vector2i(1280, 800), 1.5, 3], [Vector2i(3440, 1440), 1.5, 6],
		[Vector2i(1024, 768), 1.5, 2], [Vector2i(1920, 1080), 2.0, 6], [Vector2i(2340, 1080), 2.0, 6],
		[Vector2i(1280, 720), 2.0, 4], [Vector2i(1366, 768), 2.0, 4], [Vector2i(1600, 900), 2.0, 5],
	]
	var wrong: Array[String] = []
	for row: Array in expected:
		var size: Vector2i = row[0]
		var designed: float = row[1]
		var fit := minf(size.x / 1280.0, size.y / 720.0)
		for ui_size in [Settings.UI_BIG, Settings.UI_MEDIUM, Settings.UI_SMALL]:
			var scale := PixelGridScript.canvas_scale(fit, ui_size)
			var zoom := PixelGridScript.whole_zoom(designed, fit, scale)
			var pixels := PixelGridScript.ART_PIXEL * zoom * scale
			if not is_equal_approx(pixels, float(row[2])) or zoom * scale > designed * fit + 0.001:
				wrong.append("%s at zoom %s, interface %d: %s" % [size, designed, ui_size, pixels])
	check(wrong.is_empty(), "a world camera draws each art pixel on a whole number of screen pixels, never more than its designed framing (3 at 720 lines, 4 at 1080, 6 at 1440, 9 at 2160; wrong: %s)" % [wrong])


## The UI skin is stored at 2 units per art pixel (every 2x2 block of a texture one colour), so a
## phone's x1.5 canvas draws each art pixel on 3 screen pixels, never 4 and 5 side by side
## (decision 0007, design/interface.md "One skin", Pixels): every texture of assets/ui/rpg/ and
## assets/ui/wood/ and every box the skin builds, whose nine-patch margins count whole art pixels
## (even units), and the ornate border drawn a whole number of art pixels in.
func _test_skin_grid() -> void:
	var wrong: Array[String] = []
	for folder in ["res://assets/ui/rpg/", "res://assets/ui/wood/"]:
		for file in ResourceLoader.list_directory(folder):
			if file.ends_with(".png") and not _in_blocks_of_two((load(folder + file) as Texture2D)):
				wrong.append(file)
	check(wrong.is_empty(), "UI skin: every texture at 2 units per art pixel (2x2 blocks; wrong: %s)" % [wrong])
	var theme := load("res://assets/theme/main_theme.tres") as Theme
	var boxes := {
		"panel": UiSkin.panel(), "inset": UiSkin.inset(), "ribbon": UiSkin.ribbon(), "plaque": UiSkin.plaque(),
		"bar": UiSkin.bar_frame(), "slot frame": UiSkin.slot_frame(10), "note": UiSkin.note_box(),
		"slot": ItemSlot.slot_box(), "rarity frame": ItemSlot.frame_box(UiSkin.GOLD), "ornate": OrnateBoard.ornate_box(),
		"panel container": theme.get_stylebox(&"panel", &"PanelContainer"),
	}
	for state in [&"normal", &"hover", &"pressed", &"disabled"]:
		boxes["button " + state] = theme.get_stylebox(state, &"Button")
		boxes["perk card " + state] = theme.get_stylebox(state, &"PerkCard")
	var odd: Array[String] = []
	for box_name: String in boxes:
		var box := boxes[box_name] as StyleBoxTexture
		if box == null:
			continue
		if not _in_blocks_of_two(box.texture):
			odd.append("%s's art" % box_name)
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			if fposmod(box.get_texture_margin(side), 2.0) > 0.01:
				odd.append("%s's margin %s" % [box_name, box.get_texture_margin(side)])
	check(odd.is_empty(), "UI skin: every nine-patch on the skin's 2-unit art grid, margins of whole art pixels (%s)" % [odd])
	check(is_zero_approx(fposmod(OrnateBoard.INSET, 2.0)), "UI skin: the ornate border lies a whole number of art pixels inside the wood (%s units)" % OrnateBoard.INSET)


## Whether `texture` is made of 2x2 blocks of one colour (transparent pixels all alike).
static func _in_blocks_of_two(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	if image.get_width() % 2 or image.get_height() % 2:
		return false
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var first := image.get_pixel(x, y)
			for k in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var here := image.get_pixel(x + k.x, y + k.y)
				if not here.is_equal_approx(first) and not (here.a == 0.0 and first.a == 0.0):
					return false
	return true


## The HUD's round buttons and the joystick draw their 32-pixel spheres with each art pixel on a
## whole number of screen pixels, as big as the touch circle allows (rounded down like the
## cameras, decision 0007), at every canvas scale and buttons size; the touch circle keeps its
## size (task 431).
func _test_round_buttons_whole() -> void:
	var wrong: Array[String] = []
	for scale: float in [1.0, 1.5, 2.0, 2.5, 3.0]:
		for radius: float in [72.0, 48.0, 44.0, 32.0, 90.0, 60.0, 55.0, 40.0]:
			var per_pixel := PixelGridScript.whole_art_scale(radius * 2.0 / 32.0, scale)
			var screen := per_pixel * scale
			if absf(screen - roundf(screen)) > 0.001 or per_pixel * 32.0 > radius * 2.0 + 0.001 or (per_pixel + 1.0 / scale) * 32.0 <= radius * 2.0:
				wrong.append("radius %s at x%s: %s screen pixels a pixel" % [radius, scale, screen])
	check(wrong.is_empty(), "round buttons: their art on whole screen pixels per art pixel, the biggest that fits the touch circle (%s)" % [wrong])
	check(is_equal_approx(PixelGridScript.whole_art_scale(144.0 / 32.0, 1.5) * 32.0, 128.0) and is_equal_approx(PixelGridScript.whole_art_scale(96.0 / 32.0, 1.5) * 32.0 * 1.5, 128.0), "round buttons on a phone: the attack's sphere 128 units across (6 screen pixels a pixel, not 6.75), a skill's on 128 screen pixels (4 a pixel, not 4.5)")
	var button := ActionButton.new()
	button.radius = 72.0
	var art := button.art_radius()
	var expected := PixelGridScript.whole_art_scale(144.0 / 32.0, PixelGrid.ui_scale()) * 16.0
	check(art <= button.radius and is_equal_approx(art, expected), "round buttons: the attack button draws its sphere at that size on this canvas (%s in %s, expected %s)" % [art, button.radius, expected])
	button.free()


## MenuNav on a little menu: first focus, moving, wrapping, tabs, a slider.
func _test_menu_nav_unit() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var menu := VBoxContainer.new()
	menu.add_to_group(MenuNav.GROUP)
	menu.position = Vector2(100, 100)
	layer.add_child(menu)
	var tabs := HBoxContainer.new()
	tabs.set_meta(MenuNav.NOT_FIRST, true)
	menu.add_child(tabs)
	var pressed := [-1]
	var tab_buttons: Array[Button] = []
	for i in 3:
		var tab := Button.new()
		tab.text = "Tab %d" % i
		tab.toggle_mode = true
		tab.add_to_group(MenuNav.TABS)
		tab.pressed.connect(func() -> void:
			pressed[0] = i
			for other in tab_buttons:
				other.set_pressed_no_signal(other == tab))
		tabs.add_child(tab)
		tab_buttons.append(tab)
	tab_buttons[0].set_pressed_no_signal(true)
	var buttons: Array[Button] = []
	for i in 3:
		var button := Button.new()
		button.text = "Row %d" % i
		button.custom_minimum_size = Vector2(200, 40)
		menu.add_child(button)
		buttons.append(button)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(200, 30)
	slider.max_value = 1.0
	slider.step = 0.1
	menu.add_child(slider)
	_keys_mode()
	await _frames(3)
	check(_focus() == buttons[0], "a menu opening with the keys in use: its first button outside the tabs has the focus")
	await _tap_key(KEY_DOWN)
	check(_focus() == buttons[1], "down: the next row")
	await _tap_key(KEY_S)
	check(_focus() == buttons[2], "S (the move keys) too")
	await _tap_key(KEY_DOWN)
	check(_focus() == slider, "down to the slider")
	var value := slider.value
	await _tap_key(KEY_D)
	check(slider.value > value and _focus() == slider, "right on a slider moves its value")
	await _tap_key(KEY_DOWN)
	check(tabs.is_ancestor_of(_focus()), "down past the last row wraps to the top")
	await _tap_key(KEY_E)
	check(pressed[0] == 1 and tab_buttons[1].button_pressed, "E: the next tab")
	await _tap_key(KEY_Q)
	await _tap_key(KEY_Q)
	check(pressed[0] == 2, "Q twice: the previous tab, wrapping")
	_pad_button(JOY_BUTTON_RIGHT_SHOULDER)
	_pad_button(JOY_BUTTON_RIGHT_SHOULDER, false)
	await _frames(1)
	check(pressed[0] == 0, "RB: the next tab")
	buttons[1].grab_focus()
	_pad_axis(JOY_AXIS_LEFT_Y, 0.9)
	await _frames(1)
	_pad_axis(JOY_AXIS_LEFT_Y, 0.95)
	await _frames(1)
	check(_focus() == buttons[2], "a stick held down moves once, not every frame")
	_pad_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _frames(1)
	_pad_button(JOY_BUTTON_DPAD_UP)
	_pad_button(JOY_BUTTON_DPAD_UP, false)
	await _frames(1)
	check(_focus() == buttons[1], "the D-pad moves")
	var hit := [false]
	buttons[1].pressed.connect(func() -> void: hit[0] = true)
	_pad_button(JOY_BUTTON_A)
	await _frames(1)
	_pad_button(JOY_BUTTON_A, false)
	await _frames(1)
	check(hit[0], "A presses the focused button")
	await _frames(1)
	check(MenuNav.get_child(0).get("target") == buttons[1], "the focus frame is on it")
	InputDevice.use(InputDevice.Kind.TOUCH)
	await _frames(1)
	check(MenuNav.get_child(0).get("target") == null, "never on touch")
	# A second menu over it takes the keys; closed, the focus comes back where it was.
	_keys_mode()
	var over := VBoxContainer.new()
	over.add_to_group(MenuNav.GROUP)
	layer.add_child(over)
	var ok := Button.new()
	ok.text = "OK"
	over.add_child(ok)
	await _frames(2)
	check(_focus() == ok, "a menu over another takes the focus")
	await _tap_key(KEY_UP)
	check(_focus() == ok, "...and keeps it (never to the menu underneath)")
	over.hide()
	await _frames(2)
	check(_focus() == buttons[1], "closed: the focus comes back to the button it was on")
	layer.queue_free()
	await _frames(1)


# --- Title --------------------------------------------------------------------------------

func run_title() -> void:
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(3)
	_keys_mode()
	await _frames(2)
	check(_focus() != null and title.is_ancestor_of(_focus()), "the title with the keys: a button has the focus")
	await _test_title_keys(title)
	await _test_options_keys(title)
	await _test_codex_keys(title)
	await _test_title_layouts(title)
	InputDevice.use(InputDevice.Kind.TOUCH)
	title.queue_free()
	await _frames(2)
	await _test_french_panels()


func _test_title_keys(title: TitleScreen) -> void:
	# Escape on the title itself does nothing (a computer's player never quits by accident).
	await _tap_key(KEY_ESCAPE)
	check(is_instance_valid(title) and title.is_inside_tree(), "Escape on the bare title quits nothing")
	# Play now leaves this scene for Kagari; exercise its keyboard activation with a captured
	# callback, then test the shared difficulty menu independently (it lives at the well).
	var play := title.get_node("%PlayButton") as Button
	play.pressed.disconnect(title.play)
	var entered := [false]
	var capture := func() -> void: entered[0] = true
	play.pressed.connect(capture)
	play.grab_focus()
	await _tap_key(KEY_ENTER)
	check(entered[0] and TitleScreen.VILLAGE_SCENE == VillageHub.SCENE, "Enter activates the village entry button")
	play.pressed.disconnect(capture)
	play.pressed.connect(title.play)
	var difficulty := title.get_node("%DifficultyPanel") as DifficultyPanel
	difficulty.open(CONTENT.difficulties, CONTENT.ascensions)
	await _frames(2)
	check(difficulty.visible, "the well's shared difficulty panel opens")
	await _check_keys_reach(difficulty, "the difficulties")
	await _tap_key(KEY_ESCAPE)
	check(not difficulty.visible, "Escape closes them")
	var shrine := title.get_node("%ShrinePanel") as Control
	(title.get_node("%ShrineButton") as Button).pressed.emit()
	await _frames(2)
	await _check_keys_reach(shrine, "the shrine")
	var node_button := _focus()
	check(node_button is SoulNodeButton or (node_button != null and shrine.is_ancestor_of(node_button)), "the shrine starts on its tree")
	await _tap_key(KEY_ESCAPE)
	check(not shrine.visible, "Escape closes the shrine")
	title.daily_dialog.open(CONTENT, DailyRun.today())
	await _frames(2)
	await _check_keys_reach(title.daily_dialog, "the Dawn Knell's dialog")
	await _tap_key(KEY_ESCAPE)
	check(not title.daily_dialog.visible, "Escape closes it")


## `tab` is the options' tab shown: its button pressed, its page the only one visible.
func _shows_tab(options: OptionsPanel, tab: OptionsPanel.Tab) -> bool:
	if options.current_tab() != tab:
		return false
	for other: int in OptionsPanel.Tab.values():
		var button := options.get_node("%" + OptionsPanel.TAB_NAMES[other] + "Tab") as Button
		if button.button_pressed != (other == tab) or options.page(other as OptionsPanel.Tab).visible != (other == tab):
			return false
	return true


func _test_options_keys(title: TitleScreen) -> void:
	var options := title.get_node("%OptionsPanel") as OptionsPanel
	(title.get_node("%OptionsButton") as Button).pressed.emit()
	await _frames(2)
	await _check_keys_reach(options, "the options")
	var page := options.get_node("%ControlsPage") as ControlsPage
	check(not page.visible and _shows_tab(options, OptionsPanel.Tab.GAMEPLAY), "the options open on Gameplay")
	# E and a gamepad's RB walk the five tabs in order and wrap around; Q and LB walk back.
	var order: Array[OptionsPanel.Tab] = [OptionsPanel.Tab.GRAPHICS, OptionsPanel.Tab.AUDIO, OptionsPanel.Tab.CONTROLS, OptionsPanel.Tab.PRIVACY, OptionsPanel.Tab.GAMEPLAY]
	for tab in order:
		await _tap_key(KEY_E)
		check(_shows_tab(options, tab), "E: the %s tab, alone" % OptionsPanel.TAB_NAMES[tab])
	await _tap_key(KEY_Q)
	check(_shows_tab(options, OptionsPanel.Tab.PRIVACY), "Q: back to the last tab (wraps around)")
	await _tap_key(KEY_E)
	InputDevice.use(InputDevice.Kind.GAMEPAD, &"xbox")
	InputDevice.navigating = true
	for tab in order:
		await _tap_pad(JOY_BUTTON_RIGHT_SHOULDER)
		check(_shows_tab(options, tab), "RB: the %s tab, alone" % OptionsPanel.TAB_NAMES[tab])
	await _tap_pad(JOY_BUTTON_LEFT_SHOULDER)
	check(_shows_tab(options, OptionsPanel.Tab.PRIVACY), "LB: the tab before")
	await _tap_pad(JOY_BUTTON_LEFT_SHOULDER)
	check(page.visible and _shows_tab(options, OptionsPanel.Tab.CONTROLS) and (options.get_node("%ControlsTab") as Button).button_pressed, "LB again: the Controls tab")
	_keys_mode()
	await _frames(1)
	var rows := page.rows_text()
	check(rows.any(func(row: PackedStringArray) -> bool: return row[0] == "Attack (hold to charge)" and row[1].contains("Space")), "the Controls page lists the keys: %s" % [rows.slice(0, 3)])
	await _test_remap(options, page)
	InputDevice.use(InputDevice.Kind.GAMEPAD, &"playstation")
	await _frames(1)
	rows = page.rows_text()
	check(rows.any(func(row: PackedStringArray) -> bool: return row[0] == "Roll" and row[1] == "✕"), "a gamepad picked up: the page names its buttons (✕ rolls)")
	InputDevice.use(InputDevice.Kind.TOUCH)
	await _frames(1)
	rows = page.rows_text()
	check(rows.any(func(row: PackedStringArray) -> bool: return row[0] == "Bag" and row[1] == "The Bag button"), "touch: how it is done by touch")
	_keys_mode()
	await _tap_key(KEY_Q)
	check(not page.visible and _shows_tab(options, OptionsPanel.Tab.AUDIO), "Q: back to the Audio tab")
	# Down to a slider, and change it with the arrows.
	var master := options.get_node("%MasterSlider") as HSlider
	master.grab_focus()
	var volume := Settings.master_volume
	await _tap_key(KEY_LEFT)
	check(Settings.master_volume < volume, "left on a volume turns it down (%s)" % Settings.master_volume)
	await _tap_key(KEY_RIGHT)
	check(is_equal_approx(Settings.master_volume, volume), "right turns it back up")
	options.show_tab(OptionsPanel.Tab.GAMEPLAY)
	await _frames(1)
	var check_button := options.get_node("%RunTimerCheck") as CheckButton
	check_button.grab_focus()
	var timer := Settings.run_timer
	await _tap_key(KEY_ENTER)
	check(Settings.run_timer != timer, "Enter flips a switch")
	await _tap_key(KEY_ENTER)
	check(Settings.run_timer == timer, "...and back")
	var medium := options.get_node("%UiSizeMedium") as Button
	medium.pressed.emit()
	check(Settings.ui_size == Settings.UI_MEDIUM and medium.button_pressed, "the interface size option")
	(options.get_node("%UiSizeBig") as Button).pressed.emit()
	check(Settings.ui_size == Settings.UI_BIG, "...back to big")
	await _tap_key(KEY_ESCAPE)
	check(not options.visible, "Escape closes the options")
	# A gamepad's B too.
	options.open()
	await _frames(1)
	await _tap_pad(JOY_BUTTON_B)
	check(not options.visible, "B closes the options")


## Options > Controls: a fight's control given another key, then a gamepad button; one key does
## one control (a second key taken, a first one swapped), moving and pausing keep theirs, Escape
## gives up without closing the options, the keys are saved and come back, Default puts them back.
func _test_remap(options: OptionsPanel, page: ControlsPage) -> void:
	var keyboard := InputDevice.Kind.KEYBOARD
	var pad := InputDevice.Kind.GAMEPAD
	var attack_button := page.find_child("AttackKeyButton", true, false) as Button
	check(attack_button != null and page.find_child("MoveKeyButton", true, false) == null and page.find_child("PauseKeyButton", true, false) == null, "keys: the fight's controls can change, moving and Pause can't")
	if attack_button == null:
		return
	check(Settings.bindings.is_empty() and Prompts.glyph(&"attack", keyboard).text == "Space", "Attack starts on Space")
	attack_button.pressed.emit()
	await _frames(1)
	check(page.listening() == &"attack" and attack_button.text == "...", "pressed: the page waits for Attack's new key")
	await _tap_key(KEY_F)
	check(page.listening() == &"" and Prompts.glyph(&"attack", keyboard).text == "F" and options.visible, "F pressed: Attack's first key is F, its prompts say so (%s)" % Prompts.glyph(&"attack", keyboard).text)
	var press_f := InputEventKey.new()
	press_f.physical_keycode = KEY_F
	press_f.keycode = KEY_F  # (Use is bound by its letter, Attack by its place: a real F is both)
	check(InputMap.event_is_action(press_f, &"attack") and not InputMap.event_is_action(press_f, &"interact"), "F attacks now, and no longer uses (one key, one control)")
	check(Prompts.glyph(&"interact", keyboard).text == "E", "...Use keeps E")
	var press_j := InputEventKey.new()
	press_j.physical_keycode = KEY_J
	check(InputMap.event_is_action(press_j, &"attack"), "...and Attack keeps its second key, J")
	# Refused: a key that moves the hero; Escape gives up and leaves the options open.
	page.listen(&"attack")
	await _tap_key(KEY_W)
	check(page.listening() == &"attack" and (page.get_child(1) as Label).text.contains("Move") and Prompts.glyph(&"attack", keyboard).text == "F", "W refused (it moves the hero): still waiting (%s)" % (page.get_child(1) as Label).text)
	await _tap_key(KEY_ESCAPE)
	check(page.listening() == &"" and options.visible and Prompts.glyph(&"attack", keyboard).text == "F", "Escape: given up, nothing changed, the options still open")
	# A first key of another control: they swap.
	page.listen(&"skill_1")
	await _tap_key(KEY_2)
	check(Prompts.glyph(&"skill_1", keyboard).text == "2" and Prompts.glyph(&"skill_2", keyboard).text == "1", "Roll given 2: the weapon skill takes Roll's 1 (a swap, %s / %s)" % [Prompts.glyph(&"skill_1", keyboard).text, Prompts.glyph(&"skill_2", keyboard).text])
	# Kept in the settings file, and back from it.
	var kept := Settings.bindings.duplicate(true)
	Settings.path = "user://test_bindings_%d.cfg" % OS.get_process_id()
	Settings.save_settings()
	Settings.set(&"bindings", {})
	Settings.apply()
	check(Prompts.glyph(&"attack", keyboard).text == "Space", "(bindings cleared: Space again)")
	Settings.load_settings()
	Settings.apply()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Settings.path = ""
	check(Settings.bindings == kept and Prompts.glyph(&"attack", keyboard).text == "F" and Prompts.glyph(&"skill_1", keyboard).text == "2", "the keys are saved and come back (%s)" % [Settings.bindings])
	for word: String in ["k:74", "l:77", "b:2", "a:5:1"]:
		check(KeyBindings.serialize(KeyBindings.parse(word)) == word, "kept as words: %s" % word)
	check(KeyBindings.parse("x:3") == null and KeyBindings.parse("b:99") == null and KeyBindings.parse("k") == null, "a word the game can't read is skipped")
	# A gamepad: its own buttons.
	InputDevice.use(pad, &"xbox")
	await _frames(1)
	var y_before: String = Prompts.glyph(&"skill_3", pad).text
	page.listen(&"attack")
	await _tap_pad(JOY_BUTTON_Y)
	check(Prompts.glyph(&"attack", pad).text == y_before and Prompts.glyph(&"skill_3", pad).text == "X" and Prompts.glyph(&"attack", keyboard).text == "F", "pad: Attack given Y, the skill on Y takes X; the keys are untouched (%s, %s)" % [Prompts.glyph(&"attack", pad).text, Prompts.glyph(&"skill_3", pad).text])
	page.listen(&"attack")
	await _tap_pad(JOY_BUTTON_START)
	check(page.listening() == &"" and options.visible, "Start gives up on a pad")
	page.reset_bindings()
	check(Prompts.glyph(&"attack", pad).text == "X" and Prompts.glyph(&"attack", keyboard).text == "F", "Default buttons: the pad's back, the keys still the player's")
	_keys_mode()
	await _frames(1)
	page.reset_bindings()
	check(Settings.bindings.is_empty() and Prompts.glyph(&"attack", keyboard).text == "Space" and Prompts.glyph(&"skill_1", keyboard).text == "1" and InputMap.event_is_action(press_f, &"interact"), "Default keys: every key back (%s)" % [Settings.bindings])


func _test_codex_keys(title: TitleScreen) -> void:
	var codex := title.get_node("%CodexPanel") as CodexPanel
	# Two monsters met (unknown ones can't be opened, nor focused).
	var seen_before := Profile.seen_monsters.duplicate()
	for monster in CONTENT.dungeon.acts[0].monsters.slice(0, 2):
		Profile.mark_seen(monster.id)
	await _test_codex_cards(codex)
	Profile.seen_monsters = seen_before
	await _test_codex_page_focus(codex)


## A monster's page opened with keys: focused before its columns were laid out, its first button
## ("< All monsters") used to sit scrolled just out of its column, its focus frame drawn over the
## codex's tabs (a page long enough to scroll: a monster slain often, in French, 1280x720).
func _test_codex_page_focus(codex: CodexPanel) -> void:
	var monster: MonsterDef = CONTENT.dungeon.acts[0].monsters[0]
	var kills_before: Variant = Profile.kills_by_monster.get(String(monster.id))
	var seen_before := Profile.seen_monsters.duplicate()
	var size_before := get_tree().root.size
	var device_before := InputDevice.kind
	var family_before := InputDevice.family
	var navigating_before := InputDevice.navigating
	Profile.mark_seen(monster.id)
	Profile.kills_by_monster[String(monster.id)] = 12
	await _window(Vector2i(1280, 720))
	Settings.language = "fr"
	Settings.apply()
	_keys_mode()
	codex.open(CONTENT, CodexPanel.Tab.BESTIARY)
	await _frames(2)
	codex.open_monster(monster)
	# (Right away: the list following the focus scrolled then, out of a column not laid out yet.)
	var scrolled: Array = codex.get_node("%MonsterPage").find_children("*", "ScrollContainer", true, false).map(func(scroller: ScrollContainer) -> int: return scroller.scroll_vertical)
	check(scrolled.all(func(at: int) -> bool: return at == 0), "a page opened with keys starts at the top of its columns (%s)" % [scrolled])
	await _frames(3)
	var back := codex.find_child("BackButton", true, false) as Control
	var column := back.get_parent()
	while column and not column is ScrollContainer:
		column = column.get_parent()
	var scroll := column as ScrollContainer
	var box := scroll.get_global_rect()
	check(_focus() == back, "the keys start on its first button (%s)" % _focus())
	check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "a page long enough to scroll (%d in %d)" % [scroll.get_v_scroll_bar().max_value, scroll.size.y])
	check(scroll.scroll_vertical == 0 and box.encloses(back.get_global_rect()), "the page opens at the top of its columns, its first button in sight (scrolled %d)" % scroll.scroll_vertical)
	check(box.grow(MenuNav.FocusFrame.REACH).encloses(MenuNav.frame_area()) and MenuNav.frame_area().has_area(), "its focus frame around it, in its column (%s, column %s)" % [MenuNav.frame_area(), box])
	scroll.scroll_vertical = 400  # a finger or the wheel scrolls the column, the focus stays
	await _frames(2)
	var frame := MenuNav.frame_area()
	check(frame.size == Vector2.ZERO or box.grow(MenuNav.FocusFrame.REACH).encloses(frame), "a focus frame never leaves its column, its button scrolled out (%s, column %s)" % [frame, box])
	codex.back()
	await _frames(1)
	# A warden's page, its chronicle with it: at the top too.
	var boss: BossDef = CONTENT.dungeon.acts[0].boss
	var boss_seen := Profile.seen_monsters.has(String(boss.id))
	Profile.mark_seen(boss.id)
	codex.open_monster(boss)
	await _frames(3)
	var boss_scrolled: Array = codex.get_node("%MonsterPage").find_children("*", "ScrollContainer", true, false).map(func(scroller: ScrollContainer) -> int: return scroller.scroll_vertical)
	check(boss_scrolled.all(func(at: int) -> bool: return at == 0), "a warden's page and its chronicle open with keys at the top (%s)" % [boss_scrolled])
	codex.back()
	if not boss_seen:
		Profile.seen_monsters.erase(String(boss.id))
	codex.hide()
	await _frames(1)
	Settings.language = "en"
	Settings.apply()
	await _restore_window(size_before)
	Profile.seen_monsters = seen_before
	if kills_before == null:
		Profile.kills_by_monster.erase(String(monster.id))
	else:
		Profile.kills_by_monster[String(monster.id)] = kills_before
	InputDevice.use(device_before, family_before)
	InputDevice.navigating = navigating_before


func _test_codex_cards(codex: CodexPanel) -> void:
	codex.open(CONTENT, CodexPanel.Tab.QUESTS)
	await _frames(2)
	await _check_keys_reach(codex, "the codex")
	await _tap_key(KEY_E)
	check((codex.get_node("%BestiaryTab") as Button).button_pressed, "E: the codex's next tab (Bestiary)")
	var cards := codex.bestiary_cards().filter(func(card: CodexCard) -> bool: return not card.disabled)
	check(not cards.is_empty(), "the bestiary's cards")
	if cards.is_empty():
		return
	check(cards.size() >= 2, "several monsters in the bestiary (%d)" % cards.size())
	if cards.size() < 2:
		return
	cards[0].grab_focus()
	await _tap_key(KEY_RIGHT)
	check(_focus() == cards[1], "right: the next monster")
	await _tap_key(KEY_ENTER)
	check(codex.is_page_open(), "Enter: its page")
	check(_focus() != null and (codex.get_node("%MonsterPage") as Control).is_ancestor_of(_focus()), "the keys go to its page")
	await _tap_key(KEY_ESCAPE)
	check(codex.visible and not codex.is_page_open(), "Escape: back to the list")
	await _frames(2)
	check(_focus() == cards[1], "the focus back on the monster it was on")
	await _tap_key(KEY_ESCAPE)
	check(not codex.visible, "Escape again closes the codex")


## The title and its windows fit every screen: nothing out of it.
func _test_title_layouts(title: TitleScreen) -> void:
	var before := get_tree().root.size
	var options := title.get_node("%OptionsPanel") as OptionsPanel
	var codex := title.get_node("%CodexPanel") as CodexPanel
	var shrine := title.get_node("%ShrinePanel") as ShrinePanel
	for size in SIZES:
		await _window(size)
		var outside := _panel_outside(title.get_node("Margin") as Control)
		check(outside.is_empty(), "%s: the title's buttons and records fit (%s)" % [size, ", ".join(outside.slice(0, 3))])
		options.open()
		for tab: int in OptionsPanel.Tab.values():
			options.show_tab(tab as OptionsPanel.Tab)
			await _frames(2)
			outside = _panel_outside(options)
			check(outside.is_empty(), "%s: the options' %s tab fits (%s)" % [size, OptionsPanel.TAB_NAMES[tab], ", ".join(outside.slice(0, 3))])
		options.hide()
		codex.open(CONTENT, CodexPanel.Tab.BESTIARY)
		await _frames(2)
		outside = _panel_outside(codex)
		check(outside.is_empty(), "%s: the codex fits (%s)" % [size, ", ".join(outside.slice(0, 3))])
		codex.hide()
		shrine.open(CONTENT.soul_tree, CONTENT)
		await _frames(2)
		outside = _panel_outside(shrine)
		check(outside.is_empty(), "%s: the shrine fits (%s)" % [size, ", ".join(outside.slice(0, 3))])
		shrine.hide()
	# French runs longer: the options and their Controls page still fit the narrowest canvas.
	Settings.language = "fr"
	Settings.apply()
	var french := (load("res://src/ui/options/options_panel.tscn") as PackedScene).instantiate() as OptionsPanel
	add_child(french)
	for size in [Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(1366, 768)]:
		await _window(size)
		french.open()
		for tab: int in OptionsPanel.Tab.values():
			french.show_tab(tab as OptionsPanel.Tab)
			await _frames(2)
			var outside := _panel_outside(french)
			check(outside.is_empty(), "%s in French: the options' %s tab fits (%s)" % [size, OptionsPanel.TAB_NAMES[tab], ", ".join(outside.slice(0, 3))])
		french.hide()
	french.queue_free()
	Settings.language = "en"
	Settings.apply()
	await _restore_window(before)


## French runs long: in French, on a computer's smallest screen, a phone's two shapes and a big
## window, every in-run panel stays inside the screen with its longest words (the merchant
## saying why it can't sell, the forge taking out the longest rune's name or saying the bag is
## full, the four encounters, the longest fragment, the longest perks...). A game of its own,
## begun in French: the words its menus were built with are French too.
func _test_french_panels() -> void:
	var before := get_tree().root.size
	Settings.language = "fr"
	Settings.apply()
	var game := GAME_SCENE.instantiate() as Game
	game.show_act_cards = false
	add_child(game)
	await _frames(5)
	var world := game.world
	var player := game.player
	player.invincible = true
	await _clear_monsters(world)
	_keys_mode()
	var none: Array[ItemAffixDef] = []
	var katana := load("res://data/items/weapons/katana.tres") as EquipmentDef
	var mail := load("res://data/items/armors/chain_mail.tres") as EquipmentDef
	# The longest names and texts, in French.
	var rune: RuneDef = _longest(CONTENT.runes, func(r: RuneDef) -> String: return tr(r.display_name))
	var fragment: FragmentDef = null
	var fragment_boss: BossDef = null
	for act in CONTENT.dungeon.acts:
		for boss in act.all_bosses():
			if boss.chronicle:
				for piece in boss.chronicle.fragments:
					if fragment == null or _fragment_length(piece) > _fragment_length(fragment):
						fragment = piece
						fragment_boss = boss
	var perks: Array[PerkDef] = []
	perks.assign(CONTENT.perks.filter(func(perk: PerkDef) -> bool: return perk.rarity == PerkDef.Rarity.COMMON))
	perks.sort_custom(func(a: PerkDef, b: PerkDef) -> bool: return (tr(a.display_name) + a.describe()).length() > (tr(b.display_name) + b.describe()).length())
	var long_perks: Array[PerkDef] = []
	long_perks.assign(perks.slice(0, 3))
	var named: MonsterDef = _longest(_all_monsters(), func(m: MonsterDef) -> String: return tr(m.display_name))
	# Every monster known well: its page shows all it has.
	var kills := Profile.kills_by_monster.duplicate()
	for monster in _all_monsters():
		Profile.kills_by_monster[String(monster.id)] = 1000
	# What the panels show: a socketed weapon with that rune, a bag of everything.
	var worn := LootRoller.make(katana, ItemRarity.RARE, none, [rune], 3)
	player.equipment.equip(worn)
	player.inventory.items.clear()
	for item: ItemDef in [LootRoller.make(mail, ItemRarity.EPIC, none, [], 2), rune, load("res://data/items/tomes/tome_fire.tres"), load("res://data/items/consumables/fire_scroll.tres"), load("res://data/items/consumables/haste_draught.tres")]:
		player.inventory.add(item)
	var bag := player.inventory.items.duplicate()
	var merchant := world.spawn_merchant(CONTENT.dungeon.merchant, world.map.world_to_cell(world.find_open_point_near(player.global_position + Vector2(-60, 0), 40.0)))
	var forge := world.spawn_forge(CONTENT.dungeon.forge, world.map.world_to_cell(world.find_open_point_near(player.global_position + Vector2(60, 0), 40.0)))
	var encounters: Array[Encounter] = []
	for def in CONTENT.encounters:
		encounters.append(world.spawn_encounter(def, world.map.world_to_cell(world.find_open_point_near(player.global_position + Vector2(0, 60), 60.0))))
	await _frames(2)
	# _panel_checked is a hook a probe may turn into a coroutine (a screenshot per panel): awaited.
	@warning_ignore_start("redundant_await")
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1540, 720), Vector2i(2340, 1080), Vector2i(2548, 1296)]:
		await _window(size)
		var where := "%s in French" % size
		# The bag, every tab.
		game.open_inventory()
		await _frames(2)
		var outside: Array[String] = []
		for i in InventoryPanel.CATEGORIES.categories.size():
			game.inventory_panel.show_category(i)
			await _frames(2)
			outside.append_array(_panel_outside(game.inventory_panel))
		_panel_fits(where, "the bag, every tab", game.inventory_panel, outside)
		await _panel_checked("bag", size)
		game.inventory_panel.close()
		# The merchant, Buy saying why it can't: gold missing, a full compartment.
		merchant.stock.clear()
		merchant.stock.append({ "item": LootRoller.make(mail, ItemRarity.RARE, none, [], 5), "price": 99999 })
		merchant.stock.append({ "item": LootRoller.make(katana, ItemRarity.RARE, none, [], 5), "price": 1 })
		var weapons := Inventory.CATEGORIES.index_of(worn)
		for n in player.inventory.free_in(weapons):
			player.inventory.force_add(LootRoller.make(katana, ItemRarity.COMMON, none, [], 60 + n))
		game.open_shop(merchant)
		await _frames(2)
		for index in 2:
			game.shop_panel.select_stock(index)
			await _frames(2)
			_panel_fits(where, "the merchant, Buy saying \"%s\"" % (game.shop_panel.get_node("%BuyButton") as Button).text, game.shop_panel)
			await _panel_checked("merchant_%d" % index, size)
		game.shop_panel.close()
		player.inventory.items.assign(bag)
		player.inventory.changed.emit()
		# The forge: taking out the longest rune's name, then with no room in the bag for it.
		game.open_forge(forge)
		await _frames(2)
		game.menus.forge._select_socket(0)
		await _frames(2)
		_panel_fits(where, "the forge, taking out %s" % tr(rune.display_name), game.menus.forge)
		await _panel_checked("forge", size)
		# The runes' compartment full of other runes (one place a kind: copies of their own).
		var runes := Inventory.CATEGORIES.index_of(rune)
		player.inventory.remove(rune)
		for n in player.inventory.free_in(runes):
			var other := CONTENT.runes[n % CONTENT.runes.size()].duplicate() as RuneDef
			other.id = StringName("test_rune_%d" % n)
			player.inventory.force_add(other)
		game.menus.forge.close()
		game.open_forge(forge)
		await _frames(2)
		game.menus.forge._select_socket(0)
		await _frames(2)
		check(not (game.menus.forge.find_child("TakeOutButton", true, false) as Button).text.contains(tr(rune.display_name)), "%s: the forge says the bag has no room for the rune (%s)" % [where, (game.menus.forge.find_child("TakeOutButton", true, false) as Button).text])
		_panel_fits(where, "the forge, no room for the rune", game.menus.forge)
		await _panel_checked("forge_full", size)
		player.inventory.items.assign(bag)
		player.inventory.changed.emit()
		game.menus.forge.close()
		# The four encounters.
		for encounter in encounters:
			game.open_encounter(encounter)
			await _frames(2)
			_panel_fits(where, "the encounter %s" % encounter.def.id, game.encounter_panel)
			await _panel_checked("encounter_%s" % encounter.def.id, size)
			game.encounter_panel.close()
		await _frames(1)
		# The pause, its options (both pages) and its codex (every tab, a warden's page).
		game.open_pause_menu()
		await _frames(2)
		_panel_fits(where, "the pause", game.pause_menu)
		await _panel_checked("pause", size)
		# The feedback form over it, at its tallest (signing offered, the no-service line shown).
		Leaderboards.pseudonym = "Wwwwwwwwwwwwwwww"
		game.pause_menu.feedback.run_info = game.pause_menu.run_info
		game.pause_menu.feedback.open()
		await _frames(2)
		_panel_fits(where, "the feedback form", game.pause_menu.feedback)
		await _panel_checked("feedback", size)
		game.pause_menu.feedback.hide()
		Leaderboards.pseudonym = ""
		var options := game.pause_menu.get_node("%OptionsPanel") as OptionsPanel
		options.open()
		for tab: int in OptionsPanel.Tab.values():
			options.show_tab(tab as OptionsPanel.Tab)
			await _frames(2)
			_panel_fits(where, "the options' %s tab" % OptionsPanel.TAB_NAMES[tab], options)
			await _panel_checked("options_%s" % String(OptionsPanel.TAB_NAMES[tab]).to_lower(), size)
		options.close()
		var codex := game.pause_menu.get_node("%CodexPanel") as CodexPanel
		codex.open(CONTENT, CodexPanel.Tab.QUESTS)
		for tab: int in CodexPanel.Tab.values():
			codex.show_tab(tab)
			await _frames(2)
			_panel_fits(where, "the codex, %s" % CodexPanel.TAB_NAMES[tab], codex)
			await _panel_checked("codex_%s" % CodexPanel.TAB_NAMES[tab], size)
		# The monsters' pages, all known (every text shown): each one on the narrowest screen,
		# the longest name and a warden's chronicle on every screen.
		var pages: Array = codex.bestiary_entries() if size == Vector2i(1280, 720) else [named, fragment_boss]
		var wide: Array[String] = []
		for monster: MonsterDef in pages:
			codex.open_monster(monster)
			await _frames(2)
			for line in _panel_outside(codex):
				wide.append("%s: %s" % [monster.id, line])
			# Its name wraps between words, never inside one.
			var page := codex.get_node("%MonsterPage") as Control
			for label: Label in page.find_children("*", "Label", true, false):
				if label.get_theme_font_size(&"font_size") != Fonts.TITLE or not label.is_visible_in_tree():
					continue
				for word in label.text.replace("-", "- ").split(" ", false):  # (a hyphen may end a line)
					if Fonts.MAIN.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, Fonts.TITLE).x > label.size.x:
						wide.append("%s: the word %s cut in two" % [monster.id, word])
			codex.back()
		_panel_fits(where, "the codex, the monsters' pages", codex, wide)
		codex.open_monster(fragment_boss)
		await _frames(2)
		var chronicle := _find_named(codex, "ChronicleTab") as Button
		if chronicle:
			chronicle.pressed.emit()
			await _frames(2)
		_panel_fits(where, "the codex, %s's chronicle" % tr(fragment_boss.display_name), codex)
		await _panel_checked("codex_chronicle", size)
		codex.back()
		codex.open_monster(named)
		await _frames(2)
		await _panel_checked("codex_page", size)
		codex.back()
		codex.back()
		game.pause_menu.hide()
		get_tree().paused = false
		# The longest fragment.
		game.menus.fragment.open(fragment, fragment_boss, true)
		await _frames(2)
		_panel_fits(where, "the fragment %s" % fragment.resource_path.get_file(), game.menus.fragment)
		await _panel_checked("fragment", size)
		game.menus.fragment.hide()
		# The ending's choice.
		game.menus.ending.open(CONTENT.dungeon.finale)
		await _frames(2)
		_panel_fits(where, "the ending's choice", game.menus.ending)
		await _panel_checked("ending", size)
		game.menus.ending.hide()
		# The perk choice, its three longest perks.
		game.perk_panel.open(tr("Level %d!") % 2, tr("Choose an upgrade"), long_perks, player.perks, 1, 1)
		await get_tree().create_timer(0.6, true).timeout
		_panel_fits(where, "the perk choice", game.perk_panel)
		await _panel_checked("perks", size)
		game.perk_panel.hide()
		get_tree().paused = false
		await _frames(2)
	@warning_ignore_restore("redundant_await")
	await _test_large_text(game, fragment, fragment_boss, named)
	game.queue_free()
	await _frames(2)
	Profile.kills_by_monster = kills
	Settings.language = "en"
	Settings.apply()
	InputDevice.use(InputDevice.Kind.TOUCH)
	await _restore_window(before)


## One panel's check: open, and nothing of it out of the screen (`found`: what was already seen
## outside).
func _panel_fits(where: String, what: String, panel: Control, found: Array[String] = []) -> void:
	var outside := found if not found.is_empty() else _panel_outside(panel)
	check(panel.is_visible_in_tree() and outside.is_empty(), "%s: %s fits the screen (%s)" % [where, what, ", ".join(outside.slice(0, 3)) if panel.is_visible_in_tree() else "not open"])
	if where.contains("2340"):
		var bare := _dim_on_wood(panel)
		check(bare.is_empty(), "%s: %s puts no dim or red words on the bare wood, nor a frame off the skin (%s)" % [where, what, ", ".join(bare.slice(0, 4))])


## The words of `panel` in UiSkin.DIM or BAD drawn straight on the wood (their nearest frame is
## UiSkin.panel(): 1.5 to 2.2:1 there; an inset gives them 4.5:1 and more), and the frames that
## are not the skin's (the theme's own PanelContainer box).
func _dim_on_wood(panel: Control) -> Array[String]:
	var found: Array[String] = []
	for node in panel.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		if control is PanelContainer:
			var box := control.get_theme_stylebox(&"panel") as StyleBoxTexture
			if box and box.texture and not box.texture.resource_path.begins_with(UiSkin.DIR):
				found.append("%s framed by %s" % [control.name, box.texture.resource_path.get_file()])
			continue
		var label := control as Label
		if label == null or label.text.strip_edges().is_empty():
			continue
		var color := label.get_theme_color(&"font_color")
		if not (color.is_equal_approx(UiSkin.DIM) or color.is_equal_approx(UiSkin.BAD)):
			continue
		var parent := label.get_parent()
		while parent and not parent is PanelContainer:
			parent = parent.get_parent()
		if parent == null:
			continue
		var frame := (parent as PanelContainer).get_theme_stylebox(&"panel") as StyleBoxTexture
		if frame and frame.texture == UiSkin.PANEL:
			found.append("'%s'" % label.text.left(30))
	return found


## After each panel checked in French: nothing here (a probe may take a screenshot).
func _panel_checked(_name: String, _size: Vector2i) -> void:
	pass


## Every monster of the bestiary (the acts', the Deeps', the hidden floor's and the bottom's).
func _all_monsters() -> Array[MonsterDef]:
	var result: Array[MonsterDef] = []
	for act in CONTENT.dungeon.acts:
		for monster: MonsterDef in act.monsters + act.all_bosses():
			if monster and not result.has(monster):
				result.append(monster)
	var others: Array[MonsterDef] = CONTENT.abyss_monsters()
	if CONTENT.dungeon.hidden_floor and CONTENT.dungeon.hidden_floor.boss:
		others.append(CONTENT.dungeon.hidden_floor.boss)
	if CONTENT.dungeon.finale:
		for form in CONTENT.dungeon.finale.all_bosses():
			others.append(form)
	for monster in others:
		if not result.has(monster):
			result.append(monster)
	return result


func _find_named(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found := _find_named(child, node_name)
		if found:
			return found
	return null


static func _fragment_length(fragment: FragmentDef) -> int:
	var length := 0
	for line in fragment.lines:
		length += TranslationServer.translate(line).length()
	return length


static func _longest(list: Array, text: Callable) -> Variant:
	var best: Variant = null
	for entry: Variant in list:
		if best == null or (text.call(entry) as String).length() > (text.call(best) as String).length():
			best = entry
	return best


# --- Game ---------------------------------------------------------------------------------

func run_game(game: Game) -> void:
	await _clear_monsters(game.world)
	await _test_hud_devices(game)
	await _test_mouse_fight(game)
	await _test_pause_keys(game)
	await _test_panels_keys(game)
	await _test_hud_layouts(game)
	await _test_touch_targets(game)
	await _test_safe_area(game)
	await _test_menu_targets(game)
	await _test_perk_choice_opens(game)
	InputDevice.use(InputDevice.Kind.TOUCH)
	await _frames(2)


## The touch controls go away on keys and a gamepad (an action bar with their keys instead) and
## come back on the first touch.
func _test_hud_devices(game: Game) -> void:
	var hud := game.hud
	InputDevice.use(InputDevice.Kind.TOUCH)
	await _frames(2)
	check(hud.touch_controls_shown() and not hud.action_bar.visible and (hud.get_node("%Joystick") as Control).visible, "touch: the joystick and the round buttons")
	var bag_key := hud.get_node("%BagButton").find_children("*", "PromptGlyph", true, false)
	check(bag_key.size() == 1 and not (bag_key[0] as Control).visible, "touch: no key on the bag button")
	_key(KEY_D)
	await _frames(2)
	_key(KEY_D, false)
	check(not hud.touch_controls_shown() and not (hud.get_node("%Joystick") as Control).visible and hud.action_bar.visible, "a key: the touch controls are put away for the action bar")
	check((bag_key[0] as Control).visible and (bag_key[0] as PromptGlyph).cap().text == "I", "the bag button shows its key")
	var attack := hud.action_bar.slot_for(&"AttackButton") as ActionBar.Slot
	check(attack != null and attack.glyph().cap().text == "Space", "the attack's slot shows Space")
	var rect := hud.hint_target(&"AttackButton")
	check(rect.has_area() and rect.is_equal_approx(attack.get_global_rect()), "the tutorial points at the attack's slot")
	check(not hud.hint_target(&"Joystick").has_area(), "...and at no joystick")
	# The skills' cooldowns show on the bar too.
	var roll := hud.action_bar.slot_for(&"Skill1Button")
	check(roll != null and roll.visible, "the roll's slot")
	_pad_button(JOY_BUTTON_X)
	await _frames(2)
	_pad_button(JOY_BUTTON_X, false)
	check(InputDevice.uses_gamepad() and hud.action_bar.visible and attack.glyph().cap().text == "X", "a gamepad: the same bar with its buttons (X attacks)")
	# Interact: a thing in reach shows its prompt beside the bar.
	var merchant := game.world.spawn_merchant(CONTENT.dungeon.merchant, game.world.map.world_to_cell(game.world.find_open_point_near(game.player.global_position + Vector2(60, 0), 40.0)))
	game.player.global_position = merchant.global_position + Vector2(0, 26)
	await _frames(4)
	check(hud.action_bar.interact.visible and hud.action_bar.interact.caption() == "Trade", "by the merchant: [RT] Trade beside the bar")
	check(hud.hint_target(&"InteractButton").has_area(), "the tutorial points at it")
	game.player.global_position += Vector2(0, 600)
	await _frames(4)
	merchant.queue_free()
	await _frames(2)
	check(not hud.action_bar.interact.visible, "out of reach: gone")
	var screen := get_viewport().get_visible_rect().size
	_screen_touch(screen * 0.5, true)
	await _frames(1)
	_screen_touch(screen * 0.5, false)
	await _frames(1)
	check(hud.touch_controls_shown() and not hud.action_bar.visible, "the first touch brings the touch controls back")
	# The hint's words follow the device.
	var hint: HintDef = CONTENT.tutorial.hint(&"attack")
	game.hint_box.show_hint(hint, Rect2())
	check(game.hint_box.shown_text() == tr(hint.text), "a hint on touch: its tap words")
	_keys_mode()
	await _frames(1)
	check(game.hint_box.shown_text() == "Press [Space] to strike the closest enemy.", "the keyboard taken up mid-hint: its key (%s)" % game.hint_box.shown_text())
	game.hint_box.hide_hint()


## In a fight the left mouse button attacks and the right one rolls; never over the HUD's buttons,
## never from a touch's mouse.
func _test_mouse_fight(game: Game) -> void:
	_keys_mode()
	await _frames(2)
	var screen := get_viewport().get_visible_rect().size
	var to_window := get_tree().root.get_final_transform()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = to_window * (screen * 0.5 + Vector2(60, 40))
	click.global_position = click.position
	click.pressed = true
	Input.parse_input_event(click)
	await _frames(1)
	check(Input.is_action_pressed(&"attack"), "a left click in the fight attacks")
	click.pressed = false
	Input.parse_input_event(click)
	await _frames(1)
	check(not Input.is_action_pressed(&"attack"), "...let go")
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	Input.parse_input_event(click)
	await _frames(1)
	check(Input.is_action_pressed(&"skill_1"), "a right click rolls")
	click.pressed = false
	Input.parse_input_event(click)
	await _frames(1)
	var touch := click.duplicate() as InputEventMouseButton
	touch.button_index = MOUSE_BUTTON_LEFT
	touch.device = InputEvent.DEVICE_ID_EMULATION
	touch.pressed = true
	Input.parse_input_event(touch)
	await _frames(1)
	check(not Input.is_action_pressed(&"attack"), "a touch's mouse never attacks")
	touch.pressed = false
	Input.parse_input_event(touch)
	var bag := game.hud.get_node("%BagButton") as Button
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = to_window * bag.get_global_rect().get_center()
	click.global_position = click.position
	click.pressed = true
	Input.parse_input_event(click)
	await _frames(1)
	check(not Input.is_action_pressed(&"attack"), "a click on the bag button doesn't attack")
	click.pressed = false
	Input.parse_input_event(click)
	await _frames(2)
	if game.inventory_panel.visible:
		game.inventory_panel.close()
		await _frames(2)


## Escape and Start pause and resume; a gamepad's B in a fight never pauses (it is a skill).
func _test_pause_keys(game: Game) -> void:
	_keys_mode()
	await _tap_key(KEY_ESCAPE)
	check(game.pause_menu.visible and get_tree().paused, "Escape pauses")
	await _frames(2)
	var resume := game.pause_menu.get_node("%ResumeButton") as Button
	check(_focus() == resume, "the pause menu starts on Resume")
	await _check_keys_reach(game.pause_menu, "the pause menu")
	resume.grab_focus()
	await _tap_key(KEY_ENTER)
	await _frames(2)
	check(not game.pause_menu.visible and not get_tree().paused, "Enter on Resume: back to the fight")
	await _tap_pad(JOY_BUTTON_B)
	await _frames(2)
	check(not game.pause_menu.visible and not get_tree().paused, "B in a fight doesn't pause")
	await _tap_pad(JOY_BUTTON_START)
	check(game.pause_menu.visible, "Start pauses")
	# B is skill 2 too: the press that closes the menu stays the menu's.
	game.player.skills.tick(60.0)
	var cast: Array[int] = []
	var on_cast := func(index: int) -> void: cast.append(index)
	game.player.skill_used.connect(on_cast)
	await _tap_pad(JOY_BUTTON_B)
	await _frames(2)
	game.player.skill_used.disconnect(on_cast)
	check(not game.pause_menu.visible and not get_tree().paused, "B closes the pause menu")
	check(cast.is_empty(), "B closing the pause menu casts no skill in the fight (cast: %s)" % [cast])
	# The map key.
	await _tap_key(KEY_M)
	check((game.hud.get_node("%FullMap") as Control).visible, "M: the whole floor's map")
	await _tap_key(KEY_M)
	check(not (game.hud.get_node("%FullMap") as Control).visible, "M again: back")


## Every in-run panel with the keys: it takes the focus, the arrows move in it, Escape closes it
## (the end screens stay: they never close by Back).
func _test_panels_keys(game: Game) -> void:
	var player := game.player
	var world := game.world
	_keys_mode()
	# The bag: the slot the keys stand on is the one picked (Enter uses it: BagTests).
	game.open_inventory()
	await _frames(2)
	_check_opens_at_top(game.inventory_panel, "the bag")
	await _check_keys_reach(game.inventory_panel, "the bag")
	var focused := _focus()
	if focused is ItemSlot:
		check((focused as ItemSlot).selected or (focused as ItemSlot).item == null, "the focused slot is the one picked")
	await _tap_key(KEY_ESCAPE)
	check(not game.inventory_panel.visible, "Escape closes the bag")
	# The shop.
	var merchant := world.spawn_merchant(CONTENT.dungeon.merchant, world.map.world_to_cell(world.find_open_point_near(player.global_position + Vector2(60, 0), 40.0)))
	await _frames(2)
	game.open_shop(merchant)
	await _frames(2)
	_check_opens_at_top(game.shop_panel, "the merchant")
	await _check_keys_reach(game.shop_panel, "the merchant")
	await _tap_key(KEY_ESCAPE)
	check(not game.shop_panel.visible, "Escape closes the merchant")
	merchant.queue_free()
	# The forge.
	var forge := world.spawn_forge(CONTENT.dungeon.forge, world.map.world_to_cell(world.find_open_point_near(player.global_position + Vector2(-60, 0), 40.0)))
	await _frames(2)
	game.open_forge(forge)
	await _frames(2)
	_check_opens_at_top(game.menus.forge, "the forge")
	await _check_keys_reach(game.menus.forge, "the forge")
	await _tap_pad(JOY_BUTTON_B)
	check(not game.menus.forge.visible, "B closes the forge")
	forge.queue_free()
	# An encounter.
	var spring := world.spawn_encounter(load("res://data/encounters/spirit_spring.tres"), world.map.world_to_cell(world.find_open_point_near(player.global_position + Vector2(0, 60), 40.0)))
	await _frames(2)
	game.open_encounter(spring)
	await _frames(2)
	await _check_keys_reach(game.encounter_panel, "an encounter")
	await _tap_key(KEY_ESCAPE)
	check(not game.encounter_panel.visible, "Escape leaves the encounter")
	spring.queue_free()
	# A pact door.
	if world.pact == null and world.arena == null:
		var here: Array[int] = []
		for i in world.map.rooms.size():
			if world.map.rooms[i].grow(1).has_point(world.map.world_to_cell(player.global_position)):
				here.append(i)
		var index := PactRoom.find_room(world.map, world.rng, here, world.config().corridor_width + 3)
		if index >= 0:
			world.spawn_pact(CONTENT.dungeon.pacts[0], world.map.rooms[index], {})
	if world.pact:
		game.open_pact(world.pact)
		await _frames(2)
		await _check_keys_reach(game.menus.pact, "a pact's offer")
		await _tap_key(KEY_ESCAPE)
		check(not game.menus.pact.visible, "Escape closes the pact's offer")
	# A fragment: any key closes it.
	var fragment_def: FragmentDef = null
	for chronicle_boss in CONTENT.dungeon.acts[0].all_bosses():
		if chronicle_boss.chronicle and not chronicle_boss.chronicle.fragments.is_empty():
			fragment_def = chronicle_boss.chronicle.fragments[0]
			break
	if fragment_def:
		game.menus.fragment.open(fragment_def, null)
		get_tree().paused = true
		await _frames(int(FragmentPanel.OPEN_GRACE_FRAMES) + 2)
		await _check_keys_reach(game.menus.fragment, "a fragment", false)
		await _tap_key(KEY_ENTER)
		check(not game.menus.fragment.visible, "a key closes the fragment")
		get_tree().paused = false
	# The perk choice: the first card, Enter takes it.
	var perks_before := player.perks.entries.size()
	game.offers.add(PerkDef.Rarity.COMMON, 3, "Level 2!", "Choose an upgrade", true)
	game.open_offers()
	await _frames(2)
	var first_card := game.perk_panel.get_node("%Cards").get_child(0) as Control
	_keys_mode()
	await _frames(2)
	check(_focus() == first_card, "the perk choice starts on its first card, while the cards still wait")
	await get_tree().create_timer(0.6, true).timeout
	await _check_keys_reach(game.perk_panel, "the perk choice")
	first_card.grab_focus()
	var offered := game.perk_panel.get_offered()
	await _tap_key(KEY_ENTER)
	await _frames(3)
	check(not game.perk_panel.visible, "Enter on a card takes it")
	check(not offered.is_empty() and player.perks.stacks_of(offered[0]) > 0, "...the first card's perk")
	check(player.perks.entries.size() >= perks_before, "the perk is the hero's")
	get_tree().paused = false
	# The perk choice put off with B.
	game.offers.add(PerkDef.Rarity.COMMON, 3, "Level 3!", "Choose an upgrade", true)
	game.open_offers()
	await _frames(2)
	await _tap_pad(JOY_BUTTON_B)
	check(not game.perk_panel.visible and game.offers.size() == 1, "B puts the choice off")
	game.offers.clear()
	get_tree().paused = false
	# The ending's choice and the end screen hold the focus too (they never close by Back).
	if CONTENT.dungeon.finale:
		game.menus.ending.open(CONTENT.dungeon.finale)
		await _frames(2)
		await _check_keys_reach(game.menus.ending, "the ending's choice")
		game.menus.ending.hide()
	game.game_over_panel.show_result("Test")
	await _frames(2)
	await _check_keys_reach(game.game_over_panel, "the end of a run")
	game.game_over_panel.hide()
	get_tree().paused = false
	await _frames(2)


## A window opened with keys starts at the top of its lists: its first button focused before its
## columns were laid out must not have scrolled them (follow_focus) by its own height
## (MonsterPage.scroll_to_top() fixed the codex's monster page).
func _check_opens_at_top(window: Control, what: String) -> void:
	var scrolled: Array[String] = []
	for found in window.find_children("*", "ScrollContainer", true, false):
		var list := found as ScrollContainer
		if list.is_visible_in_tree() and list.scroll_vertical > 0:
			scrolled.append("%s at %d" % [list.name, list.scroll_vertical])
	check(scrolled.is_empty(), "%s opens at the top of its lists with keys (%s)" % [what, ", ".join(scrolled)])


## The HUD fits every screen, on touch and on keys: nothing out of it, nothing over anything.
func _test_hud_layouts(game: Game) -> void:
	var hud := game.hud
	var before := get_tree().root.size
	hud.offers_button.count = 2
	await _frames(1)
	for size in SIZES:
		await _window(size)
		for kind in [InputDevice.Kind.TOUCH, InputDevice.Kind.KEYBOARD]:
			InputDevice.use(kind)
			await _frames(3)
			var widgets := {
				"stats": hud.get_node("%HpBar"), "info": hud.get_node("%InfoLabel"),
				"bag": hud.get_node("%BagButton"), "pause": hud.get_node("%PauseButton"),
				"debug": hud.get_node_or_null("%DebugButton"), "map": hud.get_node("%Minimap"),
				"seal": hud.get_node("%SealLabel"), "timer": hud.get_node("%TimerLabel"),
				"perks": hud.offers_button,
			}
			if kind == InputDevice.Kind.TOUCH:
				for button_name in ["AttackButton", "Skill1Button", "Skill2Button", "Skill3Button", "Skill4Button", "QuickItemButton", "Belt2Button", "Belt3Button"]:
					var button := hud.get_node("%" + button_name) as ActionButton
					button.visible = true  # every one, as with a full kit
					widgets[button_name] = button
			else:
				widgets["action bar"] = hud.action_bar
			var problems := _layout_problems(widgets)
			check(problems.is_empty(), "%s %s: the HUD holds (%s)" % [size, "touch" if kind == InputDevice.Kind.TOUCH else "keys", ", ".join(problems.slice(0, 4))])
		# The in-run panels fit too.
		_keys_mode()
		game.open_inventory()
		await _frames(2)
		var outside := _panel_outside(game.inventory_panel)
		check(outside.is_empty(), "%s: the bag fits (%s)" % [size, ", ".join(outside.slice(0, 3))])
		game.inventory_panel.close()
		game.open_pause_menu()
		await _frames(2)
		outside = _panel_outside(game.pause_menu)
		check(outside.is_empty(), "%s: the pause menu fits (%s)" % [size, ", ".join(outside.slice(0, 3))])
		game.pause_menu.hide()
		get_tree().paused = false
	hud.offers_button.count = 0
	InputDevice.use(InputDevice.Kind.TOUCH)
	await _restore_window(before)


# --- U4: touch targets (docs/design/interface.md "One skin") -------------------------------

## Screens the touch rules are measured at: the S23 (canvas 1560x720 at x1.5), a 1080p screen
## (1280x720 at x1.5) and a 720p one.
const TOUCH_SIZES: Array[Vector2i] = [Vector2i(2340, 1080), Vector2i(1920, 1080), Vector2i(1280, 720)]
## The fight's buttons (at least 96 units) among the HUD's round buttons.
const COMBAT_BUTTONS: Array[String] = ["AttackButton", "Skill1Button", "Skill2Button", "Skill3Button", "Skill4Button"]
const COMBAT_MIN := 96.0


## A touch target in canvas units: a disc {c, r} or a box {rect}.
func _disc_of(button: ActionButton) -> Dictionary:
	var xf := button.get_global_transform_with_canvas()
	return { "c": xf.origin, "r": button.radius * xf.get_scale().x }


func _box_of(control: Control) -> Dictionary:
	return { "rect": control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size) }


func _target_rect(target: Dictionary) -> Rect2:
	if target.has("rect"):
		return target.rect
	return Rect2(target.c - Vector2.ONE * target.r, Vector2.ONE * target.r * 2.0)


## How far apart two touch targets are (negative: they overlap).
func _target_gap(a: Dictionary, b: Dictionary) -> float:
	if a.has("c") and b.has("c"):
		return (a.c as Vector2).distance_to(b.c) - a.r - b.r
	if a.has("c") or b.has("c"):
		var disc: Dictionary = a if a.has("c") else b
		var box: Rect2 = (b if a.has("c") else a).rect
		var nearest: Vector2 = (disc.c as Vector2).clamp(box.position, box.end)
		return nearest.distance_to(disc.c) - disc.r
	var ra: Rect2 = a.rect
	var rb: Rect2 = b.rect
	var dx := maxf(0.0, maxf(ra.position.x - rb.end.x, rb.position.x - ra.end.x))
	var dy := maxf(0.0, maxf(ra.position.y - rb.end.y, rb.position.y - ra.end.y))
	if dx == 0.0 and dy == 0.0:
		var overlap := ra.intersection(rb)
		return -minf(overlap.size.x, overlap.size.y)
	return sqrt(dx * dx + dy * dy)


## The HUD's touch targets on touch, with every round button shown (a full kit, Interact by the
## merchant, perk choices waiting, loot on the ground).
func _hud_targets(hud: Hud) -> Dictionary:
	var targets := {}
	for button_name: String in hud.touch_rects():
		targets[button_name] = _disc_of(hud.get_node("%" + button_name) as ActionButton)
	for control_name in ["BagButton", "PauseButton", "Minimap"]:
		targets[control_name] = _box_of(hud.get_node("%" + control_name) as Control)
	targets["OffersButton"] = _box_of(hud.offers_button)
	if hud.loot_prompt.visible:
		targets["Take"] = _box_of(hud.loot_prompt.take_button())
	return targets


## U4: every touch button at least 64 units (the fight's 96), 16 between any two, none in the
## joystick's zone nor over the HUD's lines, all on the screen, at every buttons size and screen.
func _test_touch_targets(game: Game) -> void:
	var hud := game.hud
	var before := get_tree().root.size
	var size_before := Settings.controls_scale
	InputDevice.use(InputDevice.Kind.TOUCH)
	hud.offers_button.count = 2
	hud.interact_button.caption = "Trade"
	hud.interact_button.show()
	for button_name in COMBAT_BUTTONS + ["QuickItemButton", "Belt2Button", "Belt3Button"]:
		(hud.get_node("%" + button_name) as ActionButton).visible = true
	hud.loot_prompt._refresh_in = 1000.0  # (no pickup under the hero: shown by hand, kept up)
	hud.loot_prompt.show()
	for size in TOUCH_SIZES:
		await _window(size)
		for step: float in Settings.CONTROLS_SIZES:
			Settings.set_option(&"controls_scale", step)
			await _frames(3)
			hud.loot_prompt.place()
			await _frames(1)
			var where := "%s at buttons size %s" % [size, step]
			var targets := _hud_targets(hud)
			var screen := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
			var zone := hud.safe_area.get_global_transform_with_canvas() * hud.stick_zone()
			var small: Array[String] = []
			var outside: Array[String] = []
			var in_zone: Array[String] = []
			for target_name: String in targets:
				var box := _target_rect(targets[target_name])
				var least := COMBAT_MIN if target_name in COMBAT_BUTTONS else MenuWindow.TOUCH_MIN
				if minf(box.size.x, box.size.y) < least - 0.01:
					small.append("%s %s" % [target_name, box.size])
				if not screen.grow(0.5).encloses(box):
					outside.append(target_name)
				if _target_gap(targets[target_name], { "rect": zone }) < MenuWindow.TOUCH_GAP - 0.01:
					in_zone.append(target_name)
			check(small.is_empty(), "%s: the fight's buttons are at least 96 units, everything else to tap 64 (%s)" % [where, ", ".join(small)])
			check(outside.is_empty(), "%s: every button on the screen (%s)" % [where, ", ".join(outside)])
			check(in_zone.is_empty(), "%s: nothing to tap within 16 units of the joystick's zone (%s)" % [where, ", ".join(in_zone)])
			var close: Array[String] = []
			var names := targets.keys()
			for i in names.size():
				for j in range(i + 1, names.size()):
					var gap := _target_gap(targets[names[i]], targets[names[j]])
					if gap < MenuWindow.TOUCH_GAP - 0.01:
						close.append("%s-%s %.1f" % [names[i], names[j], gap])
			check(close.is_empty(), "%s: 16 units between any two things to tap (%s)" % [where, ", ".join(close.slice(0, 6))])
			# The lines under the map, and the loot board, never lie over a round button.
			var covered: Array[String] = []
			var lines := {
				"seal": hud.get_node("%SealLabel"), "timer": hud.get_node("%TimerLabel"),
				"split": hud.get_node("%SplitLabel"), "pact": hud.pact_line, "trial": hud.trial_line,
				"loot board": hud.loot_prompt,
			}
			for line_name: String in lines:
				var line := lines[line_name] as Control
				var line_rect := line.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, line.size)
				for button_name: String in hud.touch_rects():
					if _target_gap({ "rect": line_rect }, targets[button_name]) < 0.0:
						covered.append("%s over %s" % [line_name, button_name])
			check(covered.is_empty(), "%s: no line of the HUD over a round button (%s)" % [where, ", ".join(covered.slice(0, 6))])
			var stats := (hud.get_node("%HpBar") as Control).get_parent() as Control
			var board := hud.loot_prompt.get_global_rect()
			check(not board.intersects(stats.get_global_rect()) and not board.intersects(hud.offers_button.get_global_rect()), "%s: the loot board hides neither the stats nor the perk button (%s)" % [where, board])
			# Sizes and places on even units (whole screen pixels at x1.5).
			var odd: Array[String] = []
			for button_name: String in hud.touch_rects():
				var button := hud.get_node("%" + button_name) as ActionButton
				if fposmod(button.radius * 2.0, 2.0) > 0.01 or fposmod(button.position.x, 2.0) > 0.01 or fposmod(button.position.y, 2.0) > 0.01:
					odd.append(button_name)
			check(odd.is_empty(), "%s: round buttons' sizes and places on even units (%s)" % [where, ", ".join(odd)])
	check(is_equal_approx(SettingsScript.snap_controls_scale(0.7), 1.0) and is_equal_approx(SettingsScript.snap_controls_scale(1.3), 1.25), "a buttons size saved before (0.7 to 1.3) takes the nearest whole step, never under the minimums")
	hud.loot_prompt._refresh_in = 0.0
	hud.loot_prompt.hide()
	hud.interact_button.hide()
	hud.offers_button.count = 0
	Settings.set_option(&"controls_scale", size_before)
	await _restore_window(before)


## The HUD, the joystick and a window keep out of a phone's camera hole: a simulated cutout on
## both sides and at the bottom moves them in.
func _test_safe_area(game: Game) -> void:
	var hud := game.hud
	var before := get_tree().root.size
	InputDevice.use(InputDevice.Kind.TOUCH)
	await _window(Vector2i(2340, 1080))
	SafeArea.simulate(get_tree(), Vector4(120, 0, 90, 30))
	await _frames(3)
	var safe := SafeArea.rect(get_viewport())
	check(safe.position.x == 80.0 and safe.end.x == 1560.0 - 60.0 and safe.end.y == 720.0 - 20.0, "a cutout of 120 / 90 / 30 screen pixels is 80 / 60 / 20 units at x1.5 (%s)" % safe)
	var outside: Array[String] = []
	for target_name: String in _hud_targets(hud):
		if not safe.grow(0.5).encloses(_target_rect(_hud_targets(hud)[target_name])):
			outside.append(target_name)
	for control_name in ["HpBar", "BagButton", "PauseButton", "Minimap"]:
		var control := hud.get_node("%" + control_name) as Control
		if not safe.grow(0.5).encloses(control.get_global_rect()):
			outside.append(control_name)
	check(outside.is_empty(), "a cutout: the HUD stays in the safe area (%s)" % ", ".join(outside))
	var zone := hud.safe_area.get_global_transform_with_canvas() * hud.stick_zone()
	check(zone.position.x >= safe.position.x - 0.5 and zone.end.y <= safe.end.y + 0.5, "a cutout: the joystick starts only in the safe area (%s)" % zone)
	game.open_pause_menu()
	await _frames(2)
	var options := game.pause_menu.get_node("%OptionsPanel") as OptionsPanel
	options.open()
	await _frames(3)
	var board := options.get_node("%CloseButton") as Control
	check(safe.grow(0.5).encloses(board.get_global_rect()), "a cutout: a window's Close stays in the safe area")
	options.close()
	game.pause_menu.hide()
	get_tree().paused = false
	SafeArea.stop_simulating(get_tree())
	await _frames(2)
	check(SafeArea.margins(get_viewport()) == Vector4.ZERO, "no cutout on a computer: the safe area is the window")
	await _restore_window(before)


## What can be tapped in `panel` (shown, taking touches).
func _tappables(panel: Node) -> Array[Control]:
	var found: Array[Control] = []
	for node in panel.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if control is BaseButton or control is LineEdit or (control is Range and not control is ScrollBar and not control is ProgressBar):
			# A list's rows scrolled out of its box can't be touched.
			var scroll := _scroll_of(control)
			if scroll and not scroll.get_global_rect().intersects(control.get_global_rect()):
				continue
			found.append(control)
	return found


## Where `control` can be touched: its box, cut by the list it scrolls in.
func _touch_box(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	var scroll := _scroll_of(control)
	return rect.intersection(scroll.get_global_rect()) if scroll else rect


func _scroll_of(control: Control) -> ScrollContainer:
	var node := control.get_parent()
	while node:
		if node is ScrollContainer:
			return node as ScrollContainer
		node = node.get_parent()
	return null


## Every tappable of `panel` at least 64 units a side and 16 from the next.
func _check_menu_targets(panel: Node, what: String) -> void:
	var items := _tappables(panel)
	var small: Array[String] = []
	var close: Array[String] = []
	for item in items:
		var rect := item.get_global_rect()  # (its whole size: a row half scrolled out is still big enough)
		if rect.size.x < MenuWindow.TOUCH_MIN - 0.01 or rect.size.y < MenuWindow.TOUCH_MIN - 0.01:
			small.append("%s %s" % [item.name, rect.size])
	for i in items.size():
		for j in range(i + 1, items.size()):
			if items[i].is_ancestor_of(items[j]) or items[j].is_ancestor_of(items[i]):
				continue
			var gap := _target_gap({ "rect": _touch_box(items[i]) }, { "rect": _touch_box(items[j]) })
			if gap < MenuWindow.TOUCH_GAP - 0.01:
				close.append("%s-%s %.0f" % [items[i].name, items[j].name, gap])
	check(not items.is_empty() and small.is_empty(), "%s: everything to tap is at least 64x64 (%s)" % [what, ", ".join(small.slice(0, 6))])
	check(close.is_empty(), "%s: 16 units between things to tap (%s)" % [what, ", ".join(close.slice(0, 6))])


## U4 in the menus of a run: the pause menu, every options page, the bag, a village conversation.
func _test_menu_targets(game: Game) -> void:
	var before := get_tree().root.size
	InputDevice.use(InputDevice.Kind.TOUCH)
	for size in [Vector2i(2340, 1080), Vector2i(1280, 720)]:
		await _window(size)
		game.open_pause_menu()
		await _frames(2)
		_check_menu_targets(game.pause_menu, "%s the pause menu" % size)
		var options := game.pause_menu.get_node("%OptionsPanel") as OptionsPanel
		options.open()
		for tab in [OptionsPanel.Tab.GAMEPLAY, OptionsPanel.Tab.GRAPHICS, OptionsPanel.Tab.AUDIO]:
			options.show_tab(tab)
			await _frames(3)
			_check_menu_targets(options, "%s options page %s" % [size, OptionsPanel.TAB_NAMES[tab]])
		options.close()
		game.pause_menu.hide()
		get_tree().paused = false
		await _frames(1)
		game.open_inventory()
		await _frames(3)
		_check_menu_targets(game.inventory_panel, "%s the bag" % size)
		game.inventory_panel.close()
		get_tree().paused = false
		# The merchant and the smith.
		var merchant := game.world.spawn_merchant(CONTENT.dungeon.merchant, game.world.map.world_to_cell(game.world.find_open_point_near(game.player.global_position + Vector2(-60, 0), 40.0)))
		var forge := game.world.spawn_forge(CONTENT.dungeon.forge, game.world.map.world_to_cell(game.world.find_open_point_near(game.player.global_position + Vector2(60, 0), 40.0)))
		await _frames(1)
		game.open_shop(merchant)
		await _frames(3)
		_check_menu_targets(game.shop_panel, "%s the merchant" % size)
		game.shop_panel.close()
		game.open_forge(forge)
		await _frames(3)
		_check_menu_targets(game.menus.forge, "%s the forge" % size)
		game.menus.forge.close()
		get_tree().paused = false
		merchant.queue_free()
		forge.queue_free()
		var talk := VillagePanel.new()
		add_child(talk)
		talk.open("Sayo", "Words.")
		for i in 3:
			talk.choice("A choice %d" % i, &"none")
		await _frames(3)
		_check_menu_targets(talk, "%s a village conversation" % size)
		talk.speak((load("res://data/village/kagari.tres") as Resource).get("residents")[0], "Words.", "Here.")
		await _frames(2)
		var bare := _dim_on_wood(talk)
		check(bare.is_empty(), "%s: a village conversation puts no dim or red words on the bare wood (%s)" % [size, ", ".join(bare)])
		talk.queue_free()
		await _frames(1)
	await _restore_window(before)



## Large text (Settings.large_text, on by default on a phone): the reading text one font step
## bigger (TITLE) everywhere it shows, and every panel holding it still fits the phones' screens
## and the smallest one in French (it scrolls or pages, never shrinks): the shrine's
## conversation (pages of at most three lines), a tutorial hint, the bag's item card, a
## monster's page and a warden's chronicle, the longest fragment, a village conversation.
func _test_large_text(game: Game, fragment: FragmentDef, boss: BossDef, monster: MonsterDef) -> void:
	var large_before := Settings.large_text
	await _test_dialogue_lines()
	Settings.large_text = true
	check(UiSkin.reading_size() == Fonts.TITLE, "Large text: reading text at TITLE, the next whole font step")
	var hints: Array[HintDef] = []
	hints.assign(CONTENT.tutorial.hints)
	var longest_hint: HintDef = _longest(hints, func(hint: HintDef) -> String: return hint.shown_text())
	var pages: Array[String] = []
	for file in DirAccess.get_files_at("res://data/story/dialogue"):
		if file.ends_with(".tres"):
			var def := load("res://data/story/dialogue/" + file) as Resource
			for line: Resource in def.get("lines"):
				for page: String in line.get("lines"):
					pages.append(tr(page))
	pages.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var keeper := load("res://data/story/dialogue/speakers/vigil_keeper.tres") as SpeakerDef
	for size: Vector2i in [Vector2i(2340, 1080), Vector2i(1540, 720), Vector2i(1280, 720)]:
		await _window(size)
		var where := "%s in French, Large text" % size
		# The shrine's conversation: its longest pages, paged at three lines, the box on screen.
		var layer := CanvasLayer.new()
		get_tree().root.add_child(layer)
		var talk := DialogueScreen.new()
		layer.add_child(talk)
		await _frames(1)
		var too_long: Array[String] = []
		for text in pages.slice(0, 6):
			var spoken: Array[Dictionary] = []
			for part in DialogueBox.split_page(text, talk.box.words_width(), Fonts.TITLE):
				spoken.append({ "text": part, "accent": false })
			talk.show()
			talk.box.say_pages(keeper, spoken)
			await _frames(2)
			var label := talk.box.get("_current") as Label
			if label.get_theme_font_size(&"font_size") != Fonts.TITLE or label.get_line_count() > DialogueBox.MAX_LINES:
				too_long.append("%s... (%d lines at %d)" % [text.left(20), label.get_line_count(), label.get_theme_font_size(&"font_size")])
		check(too_long.is_empty(), "%s: the shrine's words at TITLE, at most %d lines a page (%s)" % [where, DialogueBox.MAX_LINES, ", ".join(too_long)])
		_panel_fits(where, "the shrine's conversation", talk)
		layer.queue_free()
		# A tutorial hint, the longest: between the HUD's stats and its map's column when there is
		# room for it (the phones).
		game.hint_box.show_hint(longest_hint, Rect2())
		await _frames(3)
		_panel_fits(where, "the longest hint", game.hint_box)
		if size.x * 720 >= size.y * 1540:
			var hint_board := (game.hint_box.get("_board") as Control).get_global_rect()
			var stats := (game.hud.get_node("%HpBar") as Control).get_parent() as Control
			check(not hint_board.intersects(stats.get_global_rect()) and not hint_board.intersects(game.hud.get_node("%Minimap").get_global_rect()), "%s: the hint hides neither the stats nor the map (%s)" % [where, hint_board])
		game.hint_box.hide_hint()
		# The bag's item card.
		game.open_inventory()
		await _frames(3)
		var details := game.inventory_panel.find_child("ItemDetails", true, false) as Label
		check(details != null and details.get_theme_font_size(&"font_size") == Fonts.TITLE, "%s: an item's details at TITLE" % where)
		_panel_fits(where, "the bag", game.inventory_panel)
		game.inventory_panel.close()
		# A monster's page and a warden's chronicle.
		game.open_pause_menu()
		await _frames(2)
		var codex := game.pause_menu.get_node("%CodexPanel") as CodexPanel
		codex.open(CONTENT, CodexPanel.Tab.BESTIARY)
		codex.open_monster(monster)
		await _frames(2)
		_panel_fits(where, "a monster's page", codex)
		codex.back()
		codex.open_monster(boss)
		await _frames(2)
		var chronicle := _find_named(codex, "ChronicleTab") as Button
		if chronicle:
			chronicle.pressed.emit()
			await _frames(2)
		_panel_fits(where, "a warden's chronicle", codex)
		codex.back()
		codex.back()
		game.pause_menu.hide()
		get_tree().paused = false
		# The longest fragment: it scrolls when it is longer than the screen.
		game.menus.fragment.open(fragment, boss, true)
		await _frames(3)
		_panel_fits(where, "the longest fragment", game.menus.fragment)
		game.menus.fragment.hide()
		# A village conversation with a long reply.
		var village := VillagePanel.new()
		game.hud.add_child(village)
		village.open("Sayo", pages[0])
		await _frames(2)
		check(village.words.get_theme_font_size(&"font_size") == Fonts.TITLE, "%s: the village's words at TITLE" % where)
		_panel_fits(where, "a village conversation", village)
		village.queue_free()
		await _frames(1)
	Settings.large_text = large_before



## The shrine's conversation at BODY in French: at most 60 characters a line (about 58 the
## longest lines) and 3 lines a page, every page of every speaker (design/interface.md, Text).
func _test_dialogue_lines() -> void:
	Settings.large_text = false
	await _window(Vector2i(2340, 1080))
	var talk := DialogueScreen.new()
	var layer := CanvasLayer.new()
	get_tree().root.add_child(layer)
	layer.add_child(talk)
	await _frames(1)
	var width := talk.box.words_width()
	var longest := 0
	var most_lines := 0
	for file in DirAccess.get_files_at("res://data/story/dialogue"):
		if not file.ends_with(".tres"):
			continue
		for line: Resource in (load("res://data/story/dialogue/" + file) as Resource).get("lines"):
			for page: String in line.get("lines"):
				for part in DialogueBox.split_page(tr(page), width, Fonts.BODY):
					var paragraph := TextParagraph.new()
					paragraph.add_string(part, Fonts.MAIN, Fonts.BODY)
					paragraph.width = width
					paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
					most_lines = maxi(most_lines, paragraph.get_line_count())
					for i in paragraph.get_line_count():
						var range_i := paragraph.get_line_range(i)
						longest = maxi(longest, part.substr(range_i.x, range_i.y - range_i.x).strip_edges().length())
	check(longest <= 60 and longest >= 50, "the shrine's words: at most 60 characters a line in French (%d)" % longest)
	check(most_lines <= DialogueBox.MAX_LINES, "the shrine's words: at most %d lines a page (%d)" % [DialogueBox.MAX_LINES, most_lines])
	layer.queue_free()
	await _frames(1)



# --- Contrast and colour (docs/design/interface.md "One skin") ------------------------------

## WCAG relative luminance of `color` (its alpha ignored).
static func _luminance(color: Color) -> float:
	var channels := [color.r, color.g, color.b]
	var linear: Array[float] = []
	for c: float in channels:
		linear.append(c / 12.92 if c <= 0.03928 else pow((c + 0.055) / 1.055, 2.4))
	return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


## The contrast of `front` (blended by its alpha) on `back`.
static func _contrast(front: Color, back: Color) -> float:
	var seen := back.lerp(Color(front, 1.0), front.a)
	var a := _luminance(seen)
	var b := _luminance(back)
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


## The colour in the middle of a skin texture (its fill, where words sit).
static func _fill_of(texture: Texture2D) -> Color:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	return image.get_pixel(floori(image.get_width() * 0.5), floori(image.get_height() * 0.5))


## The skin's colours on its own backgrounds, sampled from the textures: text in the dark insets
## at 4.5:1 or more (UiSkin.TEXT, GOLD, DIM, GOOD, BAD), the buttons' words (4.5:1; disabled
## 3:1), the outline of every label (Fonts.OUTLINE) standing out from the wood and the words from
## it. DIM and BAD fall under 3:1 on the bare wood: they never go there (PcTests' French panels).
func _test_contrast() -> void:
	var inset := _fill_of(UiSkin.INSET)
	var wood := _fill_of(UiSkin.PANEL)
	for pair: Array in [["TEXT", UiSkin.TEXT], ["GOLD", UiSkin.GOLD], ["DIM", UiSkin.DIM], ["GOOD", UiSkin.GOOD], ["BAD", UiSkin.BAD]]:
		var ratio := _contrast(pair[1], inset)
		check(ratio >= 4.5, "contrast: %s on an inset %.2f:1 (4.5 at least)" % [pair[0], ratio])
	var theme := load("res://assets/theme/main_theme.tres") as Theme
	var normal := _fill_of((theme.get_stylebox(&"normal", &"Button") as StyleBoxTexture).texture)
	var hover := _fill_of((theme.get_stylebox(&"hover", &"Button") as StyleBoxTexture).texture)
	var pressed := _fill_of((theme.get_stylebox(&"pressed", &"Button") as StyleBoxTexture).texture)
	var disabled := _fill_of((theme.get_stylebox(&"disabled", &"Button") as StyleBoxTexture).texture)
	var words := theme.get_color(&"font_color", &"Button")
	check(_contrast(words, normal) >= 4.5 and _contrast(theme.get_color(&"font_hover_color", &"Button"), hover) >= 4.5, "contrast: a button's words 4.5:1 (%.2f, hovered %.2f)" % [_contrast(words, normal), _contrast(theme.get_color(&"font_hover_color", &"Button"), hover)])
	check(_contrast(theme.get_color(&"font_pressed_color", &"Button"), pressed) >= 4.5, "contrast: a pressed button's words 4.5:1 (%.2f)" % _contrast(theme.get_color(&"font_pressed_color", &"Button"), pressed))
	check(_contrast(theme.get_color(&"font_disabled_color", &"Button"), disabled) >= 3.0, "contrast: a disabled button's words 3:1 (%.2f)" % _contrast(theme.get_color(&"font_disabled_color", &"Button"), disabled))
	check(_contrast(PauseMenu.GIVE_UP_COLOR, normal) >= 4.5, "contrast: Give up's red words on its button 4.5:1 (%.2f)" % _contrast(PauseMenu.GIVE_UP_COLOR, normal))
	check(_contrast(Fonts.OUTLINE, wood) >= 3.0 and _contrast(UiSkin.TEXT, Fonts.OUTLINE) >= 4.5 and _contrast(UiSkin.GOLD, Fonts.OUTLINE) >= 4.5, "contrast: on the wood, the words' dark outline stands out (%.2f) and the words from it (%.2f, gold %.2f)" % [_contrast(Fonts.OUTLINE, wood), _contrast(UiSkin.TEXT, Fonts.OUTLINE), _contrast(UiSkin.GOLD, Fonts.OUTLINE)])
	check(_contrast(UiSkin.DIM, wood) < 3.0 and _contrast(UiSkin.BAD, wood) < 3.0, "contrast: DIM and BAD are under 3:1 on the bare wood (why they stay off it)")


## Colour is never the only cue: gear's rarity has its pips (Magic 1, Rare 2, Epic 3), every rune
## family its own sign.
func _test_colour_cues() -> void:
	var none: Array[ItemAffixDef] = []
	var mail := load("res://data/items/armors/chain_mail.tres") as EquipmentDef
	var pips: Array[int] = []
	for rarity in [ItemRarity.COMMON, ItemRarity.MAGIC, ItemRarity.RARE, ItemRarity.EPIC]:
		pips.append(ItemSlot.pip_count(LootRoller.make(mail, rarity, none, [], 3)))
	check(pips == [0, 1, 2, 3], "rarity: pips as well as colour (Common, Magic, Rare, Epic: %s)" % [pips])
	var signs := {}
	var missing: Array[String] = []
	for rune: RuneDef in CONTENT.runes:
		if rune.family == null:
			continue
		if not ItemSlot.FAMILY_SIGNS.has(rune.family.id):
			missing.append(String(rune.family.id))
		else:
			signs[rune.family.id] = str(ItemSlot.FAMILY_SIGNS[rune.family.id])
	var shapes := {}
	for shape: String in signs.values():
		shapes[shape] = true
	check(missing.is_empty() and shapes.size() == signs.size() and signs.size() >= 2, "runes: each family its own sign as well as its colour (%d families, missing %s)" % [signs.size(), missing])



## The perk choice comes in within 0.15 s, its board rising on whole UI pixels (even units), its
## cards shown by then (design/interface.md "One skin").
func _test_perk_choice_opens(game: Game) -> void:
	var perks: Array[PerkDef] = []
	perks.assign(CONTENT.perks.slice(0, 3))
	var panel := game.perk_panel
	panel.open(tr("Level %d!") % 2, tr("Choose an upgrade"), perks, game.player.perks)
	var board := panel.get("_dialog") as Control
	var odd: Array[float] = []
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 140:
		if fposmod(board.position.y, 2.0) > 0.01:
			odd.append(board.position.y)
		await get_tree().process_frame
	await get_tree().create_timer(0.03, true).timeout
	var cards_in := true
	for card: Control in panel.get_node("%Cards").get_children():
		cards_in = cards_in and card.modulate.a >= 0.99
	check(odd.is_empty() and is_equal_approx(board.position.y, 0.0) and panel.modulate.a >= 0.99 and cards_in, "the perk choice is in place within 0.15 s, rising on even units (odd: %s)" % [odd])
	panel.hide()
	get_tree().paused = false
	await _frames(2)
