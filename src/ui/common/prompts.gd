class_name Prompts
## Tells the player what to press in the words of the device in hand (InputDevice): the key or
## button bound to an action (from the input map, named by data/ui/input_prompts.tres), as a cap
## for PromptGlyph to draw, or "[E]" in a sentence. Sentences come in two versions (DeviceText,
## HintDef.button_text): one for touch, one for keys and gamepads with {action} codes, each
## translated whole and then filled (fill()).

## What a cap looks like: a keyboard key, a round face button, a shoulder or trigger, a stick, a
## mouse (its `button` lit).
enum Shape { KEY, ROUND, SHOULDER, STICK, MOUSE }

const DATA: InputPromptsDef = preload("res://data/ui/input_prompts.tres")

static var _code := RegEx.create_from_string("\\{(\\w+)\\}")


## Keys and gamepads in use (sentences say "Press [E]"); false on touch ("Tap").
static func uses_buttons() -> bool:
	return InputDevice.uses_buttons()


## The sentence for the device in use: `button_text` (with {action} codes) on keys and gamepads
## when there is one, `touch_text` otherwise; translated, then its codes filled.
static func pick(touch_text: String, button_text: String) -> String:
	var text := button_text if uses_buttons() and not button_text.is_empty() else touch_text
	return fill(TranslationServer.tr(text))


## Every {action} code of `text` that names a control (an input action or a prompt of
## input_prompts.tres) becomes its key or button ("[E]", "[RT]", "[✕]"); other codes stay for
## format().
static func fill(text: String) -> String:
	if not text.contains("{"):
		return text
	var result := text
	for found in _code.search_all(text):
		var action := StringName(found.get_string(1))
		if DATA.action(action) != null or InputMap.has_action(action):
			result = result.replace(found.get_string(), inline(action))
	return result


## The action's key or button in a sentence: "[E]", "[Left click]", "[WASD]".
static func inline(action: StringName, kind: int = -1) -> String:
	var cap := glyph(action, kind)
	if cap.is_empty():
		return ""
	return "[%s]" % (DATA.mouse_glyph(cap.button) if cap.shape == Shape.MOUSE else cap.text)


## The cap to draw for `action` on `kind` (InputDevice.Kind; -1: the one in use):
## { shape, text, color, button } or empty (touch, or nothing bound on that device).
static func glyph(action: StringName, kind: int = -1) -> Dictionary:
	if kind < 0:
		kind = InputDevice.kind
	var caps := glyphs(action, kind)
	return caps[0] if not caps.is_empty() else {}


## Every way to do `action` on `kind`, the one prompts show first (the Controls page lists them
## all: "Space", "J", the left mouse button).
static func glyphs(action: StringName, kind: int) -> Array[Dictionary]:
	var entry := DATA.action(action)
	var parts: Array[StringName] = [action]  # an input action no prompt entry names (menu_next_tab)
	if entry:
		parts = entry.actions()
	var result: Array[Dictionary] = []
	if kind == InputDevice.Kind.KEYBOARD:
		var preferred := entry.key if entry and parts.size() == 1 else KEY_NONE
		var per_part: Array = parts.map(func(part: StringName) -> Array: return _keys(part, preferred))
		var sets := 0
		for keys: Array in per_part:
			sets = keys.size() if sets == 0 else mini(sets, keys.size())
		for i in sets:
			var words := PackedStringArray()
			for keys: Array in per_part:
				words.append(key_word(keys[i]))
			var joined := entry != null and entry.joined
			result.append(_cap(Shape.KEY, "".join(words) if joined else " / ".join(words)))
		if entry and entry.mouse != MOUSE_BUTTON_NONE:
			var mouse := _cap(Shape.MOUSE, "")
			mouse.button = entry.mouse
			result.append(mouse)
	elif kind == InputDevice.Kind.GAMEPAD:
		var pad := InputDevice.pad_glyphs()
		var caps: Array[Dictionary] = []
		for part in parts:
			var cap := _pad_cap(part, pad)
			if cap.is_empty():
				return result  # a part the pad can't do
			if not caps.any(func(other: Dictionary) -> bool: return other.text == cap.text):
				caps.append(cap)
		if not caps.is_empty():
			var first: Dictionary = caps[0]
			if caps.size() > 1:
				first.text = " / ".join(caps.map(func(cap: Dictionary) -> String: return cap.text))
				first.shape = Shape.KEY if first.shape == Shape.ROUND else first.shape
			result.append(first)
	return result


## Marks a key bound by its letter (`keycode`: M for the map wherever M is), not by its place
## (`physical_keycode`: the movement keys, Z Q S D on a French keyboard). See _keys().
const LOGICAL := 1 << 30


## The display servers that can name a key in the keyboard's layout
## (keyboard_get_label_from_physical()); the others (Android with a keyboard plugged in, the web,
## headless) print an engine error for each call, so their keys read by their US name.
const LAYOUT_SERVERS: PackedStringArray = ["Windows", "macOS", "X11"]


## A key's word on its cap: its own word in the data ("Esc", ","), else its name in the layout of
## the player's keyboard (the key in W's place reads Z on a French one). A key bound by its
## letter (LOGICAL) reads as itself.
static func key_word(code: int) -> String:
	var word := DATA.key_word(code & ~LOGICAL)
	if not word.is_empty():
		return word
	var shown := code & ~LOGICAL
	if code & LOGICAL == 0 and DisplayServer.get_name() in LAYOUT_SERVERS:
		shown = DisplayServer.keyboard_get_label_from_physical(shown as Key)
		word = DATA.key_word(shown)  # the label may be a sign: "," not "Comma"
		if not word.is_empty():
			return word
	return OS.get_keycode_string(shown as Key)


## The action's keys (physical keycodes, or keycodes | LOGICAL for keys bound by their letter),
## `preferred` first when it is one of them.
static func _keys(action: StringName, preferred: Key) -> Array[int]:
	var keys: Array[int] = []
	if not InputMap.has_action(action):
		return keys
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var code := int(key.physical_keycode) if key.physical_keycode != KEY_NONE else int(key.keycode) | LOGICAL
		var bare := code & ~LOGICAL
		if bare == KEY_KP_ENTER or (bare >= KEY_KP_MULTIPLY and bare <= KEY_KP_9):
			continue  # the keypad's twin of a key already listed (Enter)
		if bare != KEY_NONE and not keys.has(code):
			keys.append(code)
	for wanted: int in [int(preferred), int(preferred) | LOGICAL]:
		if preferred != KEY_NONE and keys.has(wanted):
			keys.erase(wanted)
			keys.push_front(wanted)
	return keys


## The action's first gamepad button or axis as a cap (empty if the pad can't do it).
static func _pad_cap(action: StringName, pad: PadGlyphsDef) -> Dictionary:
	if not InputMap.has_action(action) or pad == null:
		return {}
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			var index := int((event as InputEventJoypadButton).button_index)
			var shape := Shape.KEY
			if index <= JOY_BUTTON_Y or index == JOY_BUTTON_LEFT_STICK or index == JOY_BUTTON_RIGHT_STICK:
				shape = Shape.ROUND
			elif index == JOY_BUTTON_LEFT_SHOULDER or index == JOY_BUTTON_RIGHT_SHOULDER:
				shape = Shape.SHOULDER
			var cap := _cap(shape, pad.button_glyph(index))
			if index <= JOY_BUTTON_Y:
				cap.color = pad.face_color(index)
			return cap
		if event is InputEventJoypadMotion:
			var axis := int((event as InputEventJoypadMotion).axis)
			var stick := axis <= JOY_AXIS_RIGHT_Y
			return _cap(Shape.STICK if stick else Shape.SHOULDER, pad.axis_glyph(axis))
	return {}


static func _cap(shape: Shape, text: String) -> Dictionary:
	return { "shape": shape, "text": text, "color": PromptGlyph.RIM, "button": MOUSE_BUTTON_NONE }
