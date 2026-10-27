class_name KeyBindings
## The player's own keys and gamepad buttons (Options > Controls): which controls may be moved
## (ActionPromptDef.remappable), what changing one does to the input map, and how the changes are
## kept (Settings.bindings). The input map of project.godot stays the default: a changed action
## keeps its whole list of events in the settings ("k:74" a key by its place, "l:77" a key by its
## letter, "b:2" a gamepad button, "a:5:1" a trigger or stick pushed one way), applied over the
## default at start and whenever the settings are applied.
##
## One key (or button) does one control: giving a control a key another control already has as
## its first moves that control's first key over to it (a swap: nothing is left without a key);
## a second key of another control (J for Attack) is taken from it. Keys of the reserved controls
## (InputPromptsDef.reserved_actions: moving, Pause, Fullscreen) are refused, so the hero can
## always move and the game always pause.

const PROMPTS: InputPromptsDef = preload("res://data/ui/input_prompts.tres")

## Why set() refused a key or a button (OK: it was set).
enum Result { OK, RESERVED, NOT_REMAPPABLE, WRONG_DEVICE }


## The controls the player may change, in the Controls page's order.
static func remappable() -> Array[ActionPromptDef]:
	var found: Array[ActionPromptDef] = []
	for entry in PROMPTS.actions:
		if entry.remappable and entry.parts.is_empty():
			found.append(entry)
	return found


static func is_remappable(action: StringName) -> bool:
	var entry := PROMPTS.action(action)
	return entry != null and entry.remappable and entry.parts.is_empty()


## The input map back to project.godot's for every changeable control, then `bindings` (Settings)
## over it: { action: PackedStringArray of events }. Unknown actions and events are skipped (a
## control no longer changeable, a settings file edited by hand).
static func apply(bindings: Dictionary) -> void:
	for entry in remappable():
		var events: Array[InputEvent] = default_events(entry.action)
		var saved: Variant = bindings.get(String(entry.action))
		if saved is PackedStringArray or saved is Array:
			var parsed: Array[InputEvent] = []
			for text: Variant in saved:
				var event := parse(str(text))
				if event:
					parsed.append(event)
			events = parsed
		_set_events(entry.action, events)


## The control's events in project.godot (its defaults).
static func default_events(action: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	var setting: Variant = ProjectSettings.get_setting("input/%s" % action)
	if setting is Dictionary:
		for event: Variant in (setting as Dictionary).get("events", []):
			if event is InputEvent:
				events.append((event as InputEvent).duplicate())
	return events


## The first key (keyboard) or button (gamepad) of `action`: the one its prompts show and the
## Controls page changes. Null if it has none on that device.
static func first_event(action: StringName, kind: int) -> InputEvent:
	var preferred := KEY_NONE
	var entry := PROMPTS.action(action)
	if entry and not _is_changed(action):
		preferred = entry.key
	var first: InputEvent = null
	if not InputMap.has_action(action):
		return null
	for event in InputMap.action_get_events(action):
		if not _of_kind(event, kind):
			continue
		if first == null:
			first = event
		if preferred != KEY_NONE and event is InputEventKey and _key_code(event as InputEventKey) & ~Prompts.LOGICAL == preferred:
			return event
	return first


## The key Prompts puts first for `entry`: its data's (`key`) while the player hasn't changed the
## control, else none (the player's first key is already first in the input map).
static func preferred_key(entry: ActionPromptDef) -> Key:
	if entry == null or _is_changed(entry.action):
		return KEY_NONE
	return entry.key


## Gives `action` the key or button of `pressed` as its first on that device, in `bindings`
## (changed in place: Settings saves it). Returns why not, or OK.
static func set_first(bindings: Dictionary, action: StringName, pressed: InputEvent, kind: int) -> Result:
	if not is_remappable(action):
		return Result.NOT_REMAPPABLE
	var wanted := bindable(pressed, kind)
	if wanted == null:
		return Result.WRONG_DEVICE
	if reserved_by(wanted) != &"":
		return Result.RESERVED
	var old_first := first_event(action, kind)
	if old_first and same(old_first, wanted):
		return Result.OK
	# What it had: its first on this device replaced by the new one (put first: prompts show it),
	# the new one taken out of its other keys.
	var events: Array[InputEvent] = []
	events.append(wanted)
	for event in InputMap.action_get_events(action):
		if event == old_first or same(event, wanted):
			continue
		events.append(event)
	_store(bindings, action, events)
	# Every other control giving up the key: its first goes over to the old first (a swap), a
	# second one is just dropped.
	for entry in remappable():
		if entry.action == action:
			continue
		var others := InputMap.action_get_events(entry.action)
		if not others.any(func(event: InputEvent) -> bool: return same(event, wanted)):
			continue
		var their_first := first_event(entry.action, kind)
		var kept: Array[InputEvent] = []
		for event in others:
			if not same(event, wanted):
				kept.append(event)
			elif event == their_first and old_first and not kept.any(func(e: InputEvent) -> bool: return same(e, old_first)):
				kept.push_front(old_first.duplicate())
		_store(bindings, entry.action, kept)
	return Result.OK


## Back to project.godot's keys (KEYBOARD) or buttons (GAMEPAD) for every control; the other
## device's changes are kept.
static func reset(bindings: Dictionary, kind: int) -> void:
	for entry in remappable():
		var key := String(entry.action)
		if not bindings.has(key):
			continue
		var events: Array[InputEvent] = []
		for event in InputMap.action_get_events(entry.action):
			if not _of_kind(event, kind):
				events.append(event)
		for event in default_events(entry.action):
			if _of_kind(event, kind):
				events.append(event)
		_store(bindings, entry.action, events)


## The control (reserved_actions) that owns `event`'s key or button, or &"".
static func reserved_by(event: InputEvent) -> StringName:
	for action in PROMPTS.reserved_actions:
		if not InputMap.has_action(action):
			continue
		for other in InputMap.action_get_events(action):
			if same(other, event):
				return action
	return &""


## `pressed` as an event of the input map for `kind`, or null: a key without modifiers (keys are
## kept by their place, like the game's own), a gamepad button, a trigger or stick pushed past
## half way.
static func bindable(pressed: InputEvent, kind: int) -> InputEvent:
	if kind == InputDevice.Kind.KEYBOARD and pressed is InputEventKey:
		var key := pressed as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if code == KEY_NONE or code in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK]:
			return null
		var made := InputEventKey.new()
		made.physical_keycode = code
		return made
	if kind == InputDevice.Kind.GAMEPAD and pressed is InputEventJoypadButton:
		var button := InputEventJoypadButton.new()
		button.button_index = (pressed as InputEventJoypadButton).button_index
		return button
	if kind == InputDevice.Kind.GAMEPAD and pressed is InputEventJoypadMotion:
		var motion := pressed as InputEventJoypadMotion
		if absf(motion.axis_value) < 0.5:
			return null
		var made := InputEventJoypadMotion.new()
		made.axis = motion.axis
		made.axis_value = signf(motion.axis_value)
		return made
	return null


## The same key (by place or by letter, the way each is bound), button, or axis pushed the same way.
static func same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return _key_code(a as InputEventKey) & ~Prompts.LOGICAL == _key_code(b as InputEventKey) & ~Prompts.LOGICAL
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		var ma := a as InputEventJoypadMotion
		var mb := b as InputEventJoypadMotion
		return ma.axis == mb.axis and signf(ma.axis_value) == signf(mb.axis_value)
	return false


## An event as kept in the settings ("k:74", "l:77", "b:2", "a:5:1"); empty for anything else.
static func serialize(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.physical_keycode != KEY_NONE:
			return "k:%d" % key.physical_keycode
		return "l:%d" % key.keycode if key.keycode != KEY_NONE else ""
	if event is InputEventJoypadButton:
		return "b:%d" % (event as InputEventJoypadButton).button_index
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return "a:%d:%d" % [motion.axis, int(signf(motion.axis_value))]
	return ""


## The event a settings' word stands for (null if it is none).
static func parse(text: String) -> InputEvent:
	var parts := text.split(":")
	if parts.size() < 2 or not parts[1].is_valid_int():
		return null
	var value := int(parts[1])
	match parts[0]:
		"k":
			var key := InputEventKey.new()
			key.physical_keycode = value as Key
			return key if value > 0 else null
		"l":
			var letter := InputEventKey.new()
			letter.keycode = value as Key
			return letter if value > 0 else null
		"b":
			var button := InputEventJoypadButton.new()
			button.button_index = value as JoyButton
			return button if value >= 0 and value < JOY_BUTTON_SDL_MAX else null
		"a":
			if parts.size() < 3 or not parts[2].is_valid_int() or value < 0 or value >= JOY_AXIS_SDL_MAX:
				return null
			var motion := InputEventJoypadMotion.new()
			motion.axis = value as JoyAxis
			motion.axis_value = 1.0 if int(parts[2]) >= 0 else -1.0
			return motion
	return null


## Whether the player changed `action` (it has its own events in the settings).
static func _is_changed(action: StringName) -> bool:
	return Settings.bindings.has(String(action))


## `events` as the control's list in `bindings` (dropped when it is the default again), and in
## the input map now.
static func _store(bindings: Dictionary, action: StringName, events: Array[InputEvent]) -> void:
	var words := PackedStringArray()
	for event in events:
		var word := serialize(event)
		if not word.is_empty() and not words.has(word):
			words.append(word)
	var defaults := PackedStringArray()
	for event in default_events(action):
		defaults.append(serialize(event))
	var sorted_words := words.duplicate()
	sorted_words.sort()
	defaults.sort()
	if sorted_words == defaults:  # (the order only says which key comes first: the default's again)
		bindings.erase(String(action))
	else:
		bindings[String(action)] = words
	_set_events(action, events)


static func _set_events(action: StringName, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for event in events:
		InputMap.action_add_event(action, event)


static func _of_kind(event: InputEvent, kind: int) -> bool:
	if kind == InputDevice.Kind.KEYBOARD:
		return event is InputEventKey
	if kind == InputDevice.Kind.GAMEPAD:
		return event is InputEventJoypadButton or event is InputEventJoypadMotion
	return false


## A key's code as Prompts reads it: its place, or its letter | Prompts.LOGICAL.
static func _key_code(key: InputEventKey) -> int:
	return int(key.physical_keycode) if key.physical_keycode != KEY_NONE else int(key.keycode) | Prompts.LOGICAL
