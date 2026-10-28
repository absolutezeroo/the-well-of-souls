extends Node
## Player options (autoload "Settings"): volumes, screen shake, vibrations, size of the touch
## controls (whole steps: CONTROLS_SIZES), large text and the text speed (reading), fixed or
## floating joystick, battery saver (30 FPS), fewer effects, screen flashes, tutorial hints, run timer,
## boss stories (full, short, off), on a computer fullscreen or a window (F11, Alt+Enter), the
## interface's size (PixelGrid),
## language (English or French: TranslationServer's locale, see locale/strings.csv), and the
## player's own keys and gamepad buttons (KeyBindings, Options > Controls).
## Saved in user://settings.cfg and applied as soon as they change.

signal changed

const PATH := "user://settings.cfg"
## Each volume and the buses it sets (see Sfx: which sound plays on which bus).
const VOLUME_BUSES := {
	&"master_volume": [&"Master"],
	&"music_volume": [&"Music"],
	&"ui_volume": [&"UI"],
	&"combat_volume": [&"Combat"],
	&"ambience_volume": [&"World", &"Ambience"],
}
## Older settings files have one "sound_volume" for interface, combat and ambience together:
## it is given to each of them.
const OLD_SOUND_KEY := "sound_volume"
const SPLIT_SOUND_KEYS: Array[String] = ["ui_volume", "combat_volume", "ambience_volume"]
const MIN_VIBRATION_GAP_MS := 50
const KEYS: Array[String] = ["master_volume", "music_volume", "ui_volume", "combat_volume", "ambience_volume", "screen_shake", "vibrations", "controls_scale", "large_text", "text_speed", "fixed_joystick", "battery_saver", "fewer_effects", "screen_flashes", "tutorial_hints", "run_timer", "language", "auto_loot", "boss_stories", "fullscreen", "ui_size"]
## Frames per second: normal (0 = no cap), and with the battery saver.
const FPS := 0
const SAVER_FPS := 30
## The game's languages (locale codes, see locale/strings.csv) and their names, each in itself.
const LANGUAGES: Array[String] = ["en", "fr"]
const LANGUAGE_NAMES := { "en": "English", "fr": "Français" }
## Auto loot: walking over an item takes it (all), only gear better than what is worn (and every
## potion, rune, tome, key), or no gear at all (it waits, shown with a Take button). See PlayerPack.wants().
const LOOT_ALL := 0
const LOOT_BETTER := 1
const LOOT_OFF := 2
## Boss stories (Narrative): the full cinematic before a warden's fight when it has something new
## to tell, only its name and a line it remembers, or nothing (its name in a banner).
const STORIES_FULL := 0
const STORIES_SHORT := 1
const STORIES_OFF := 2
## The touch controls' sizes (Options > Graphics): every step keeps the combat buttons at 96 UI
## units or more and everything else at 64 (Hud's layout is drawn for 1.0 and must fit at each
## step on a 1280x720 canvas: PcTests U4). Steps of a quarter keep the layout's positions (on 8s)
## and radii (on 4s) on even units.
const CONTROLS_SIZES: Array[float] = [1.0, 1.25]
## The dialogue's typing (DialogueBox, the village's words, a cinematic's lines): slow, normal,
## fast, or each page written at once. A tap writes a page out at any speed.
const TEXT_SLOW := 0
const TEXT_NORMAL := 1
const TEXT_FAST := 2
const TEXT_INSTANT := 3
## How many times faster than the speaker's own pace each speed types (INSTANT: at once).
const TEXT_SPEED_FACTORS: Array[float] = [0.6, 1.0, 1.8, INF]
## The interface's size (PixelGrid): as big as the screen allows, a step smaller, two steps.
const UI_BIG := 0
const UI_MEDIUM := 1
const UI_SMALL := 2

## Empty = nothing is read or written (tests).
var path := PATH
## 0..1 each (see VOLUME_BUSES).
var master_volume := 1.0
var music_volume := 0.8
var ui_volume := 1.0
var combat_volume := 1.0
var ambience_volume := 1.0
## Multiplies every camera shake (0 = none).
var screen_shake := 1.0
var vibrations := true
## Size of the on-screen joystick and buttons: one of CONTROLS_SIZES.
var controls_scale := 1.0
## Reading text (dialogue, the village's words, hints, the codex's and items' descriptions) one
## font step bigger: Fonts.TITLE instead of Fonts.BODY (UiSkin.reading_size()). On by default on a
## phone, where BODY is about a third of the size the Xbox guidelines ask for (design/interface.md,
## Text).
var large_text := default_large_text()
## TEXT_SLOW .. TEXT_INSTANT.
var text_speed := TEXT_NORMAL
## The joystick stays in its corner (touch it there) instead of appearing under the thumb.
var fixed_joystick := false
## 30 frames per second instead of 60: the phone lasts longer and stays cooler.
var battery_saver := false
## Half the particles (sparks, chunks, dust), no heat haze nor glow: for older phones.
var fewer_effects := false
## Lightning lights the whole screen for one frame (never more than 3 times a second). Off for
## players sensitive to flashes.
var screen_flashes := true
## Tutorial hints (see Tutorial): on until turned off.
var tutorial_hints := true
## The run's time on the HUD, with the splits of each floor (for speedrunners).
var run_timer := true
## "en" or "fr". On first launch, the phone's language (French if it is French, else English).
var language := device_language()
## LOOT_ALL, LOOT_BETTER or LOOT_OFF. "Better only" by default: on a phone, stopping to tap
## every drop mid-fight is a chore, and taking everything fills the bag with worse gear.
var auto_loot := LOOT_BETTER
## STORIES_FULL, STORIES_SHORT or STORIES_OFF. Full by default: the story is told a chapter at a
## time, and only when there is a new one (otherwise two seconds).
var boss_stories := STORIES_FULL
## On a computer: the whole screen instead of a window (F11 or Alt+Enter switch it too).
var fullscreen := false
## UI_BIG, UI_MEDIUM or UI_SMALL: smaller leaves more room on a big monitor (the view of the
## floor stays the same).
var ui_size := UI_BIG
## The controls the player gave other keys or buttons: action -> its events (KeyBindings). Never
## changed in place by the game: set_bindings() puts a new one.
var bindings := {}

var _last_vibration := 0
## Takes F11 and Alt+Enter before anything else (WindowKeys).
var _window_keys := WindowKeys.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply()
	_window_keys.name = "WindowKeys"
	var root := get_tree().root
	root.add_child.call_deferred(_window_keys)
	root.child_entered_tree.connect(_on_root_child_added)


## Changes one option (by name), applies and saves it.
func set_option(key: StringName, value: Variant) -> void:
	set(key, value)
	apply()
	save_settings()
	changed.emit()


## Puts the player's keys and buttons (a new dictionary: KeyBindings), applies and saves them.
func set_bindings(new_bindings: Dictionary) -> void:
	bindings = new_bindings.duplicate(true)
	apply()
	save_settings()
	changed.emit()


## Sets and applies `key` without writing the file: a slider being dragged (heard, seen at once;
## set_option() saves when it is let go).
func preview_option(key: StringName, value: Variant) -> void:
	set(key, value)
	apply()
	changed.emit()


func apply() -> void:
	for key: StringName in VOLUME_BUSES:
		for bus: StringName in VOLUME_BUSES[key]:
			_set_bus_volume(bus, get(key))
	Engine.max_fps = SAVER_FPS if battery_saver else FPS
	if TranslationServer.get_locale() != language:
		TranslationServer.set_locale(language)
	KeyBindings.apply(bindings)
	_apply_window()


## Whether the game runs in a window it can make fullscreen (a computer's, not a phone's).
static func has_window_modes() -> bool:
	return not OS.has_feature("mobile") and not OS.has_feature("web") and DisplayServer.get_name() != "headless"


func _apply_window() -> void:
	if not has_window_modes():
		return
	var mode := DisplayServer.window_get_mode()
	var full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen and not full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## A scene comes in under the root (the title, the game): the window's keys stay after it.
func _on_root_child_added(node: Node) -> void:
	if node != _window_keys:
		_keep_window_keys_last.call_deferred()


func _keep_window_keys_last() -> void:
	var root := get_tree().root
	if _window_keys.get_parent() == root and _window_keys.get_index() != root.get_child_count() - 1:
		root.move_child(_window_keys, -1)


## F11 or Alt+Enter: fullscreen or back to a window, anywhere in the game, paused or not, and
## nothing else. Godot hands a key to the nodes' _input from the last node of the tree up, so this
## node stays the root's last child: it takes the key before a menu's own _input reads Alt+Enter
## as Enter (the bag's Use, the dialogue's next line) or any key as a skip (a card, a fragment).
class WindowKeys extends Node:
	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS


	func _input(event: InputEvent) -> void:
		if event.is_action_pressed(&"toggle_fullscreen", false, true):
			get_viewport().set_input_as_handled()
			Settings.set_option(&"fullscreen", not Settings.fullscreen)


## The node that takes F11 and Alt+Enter (tests: it is the root's last child).
func window_keys() -> Node:
	return _window_keys


## The step of CONTROLS_SIZES nearest `value` (a settings file from before had any size from
## 0.7 to 1.3: smaller than the first step is the first step, never under the touch minimums).
static func snap_controls_scale(value: float) -> float:
	var best := CONTROLS_SIZES[0]
	for step in CONTROLS_SIZES:
		if absf(step - value) < absf(best - value):
			best = step
	return best


## Large text by default on a phone (a computer's screen is read from further, but bigger and
## sharper: BODY already passes there).
static func default_large_text() -> bool:
	return OS.has_feature("mobile")


## How many times the speaker's own typing speed the text speed types (INF: at once).
func text_speed_factor() -> float:
	return TEXT_SPEED_FACTORS[clampi(text_speed, TEXT_SLOW, TEXT_INSTANT)]


## The device's language if the game speaks it, else English.
static func device_language() -> String:
	return "fr" if OS.get_locale_language() == "fr" else "en"


## A short buzz on phones (0..1). Does nothing on computers or when vibrations are off.
func vibrate(strength: float) -> void:
	if not vibrations or not OS.has_feature("mobile"):
		return
	# Many hits in a row make one buzz, not a drone.
	var now := Time.get_ticks_msec()
	if now - _last_vibration < MIN_VIBRATION_GAP_MS:
		return
	_last_vibration = now
	strength = clampf(strength, 0.0, 1.0)
	Input.vibrate_handheld(roundi(lerpf(12.0, 70.0, strength)), lerpf(0.25, 1.0, strength))


func save_settings() -> void:
	if path.is_empty():
		return
	var file := ConfigFile.new()
	for key in KEYS:
		file.set_value("options", key, get(key))
	for action: String in bindings:
		file.set_value("bindings", action, bindings[action])
	# Written beside, then renamed over the old file (as SafeFile does): a write cut short (the app
	# killed) never leaves a half file in its place.
	var temp := path + ".tmp"
	if file.save(temp) != OK or DirAccess.rename_absolute(temp, path) != OK:
		push_warning("Could not save %s" % path)


func load_settings() -> void:
	if path.is_empty():
		return
	var file := ConfigFile.new()
	# (a complete copy left by a save cut short before its rename, when the file itself is missing)
	if file.load(path) != OK and (not FileAccess.file_exists(path + ".tmp") or file.load(path + ".tmp") != OK):
		return
	for key: StringName in VOLUME_BUSES:
		set(key, clampf(float(file.get_value("options", key, get(key))), 0.0, 1.0))
	if file.has_section_key("options", OLD_SOUND_KEY) and not file.has_section_key("options", "combat_volume"):
		var old := clampf(float(file.get_value("options", OLD_SOUND_KEY)), 0.0, 1.0)
		for key in SPLIT_SOUND_KEYS:
			set(key, old)
	screen_shake = float(file.get_value("options", "screen_shake", screen_shake))
	vibrations = bool(file.get_value("options", "vibrations", vibrations))
	controls_scale = snap_controls_scale(float(file.get_value("options", "controls_scale", controls_scale)))
	large_text = bool(file.get_value("options", "large_text", large_text))
	text_speed = clampi(int(file.get_value("options", "text_speed", text_speed)), TEXT_SLOW, TEXT_INSTANT)
	fixed_joystick = bool(file.get_value("options", "fixed_joystick", fixed_joystick))
	battery_saver = bool(file.get_value("options", "battery_saver", battery_saver))
	fewer_effects = bool(file.get_value("options", "fewer_effects", fewer_effects))
	screen_flashes = bool(file.get_value("options", "screen_flashes", screen_flashes))
	tutorial_hints = bool(file.get_value("options", "tutorial_hints", tutorial_hints))
	run_timer = bool(file.get_value("options", "run_timer", run_timer))
	language = str(file.get_value("options", "language", language))
	if not language in LANGUAGES:
		language = device_language()
	auto_loot = clampi(int(file.get_value("options", "auto_loot", auto_loot)), LOOT_ALL, LOOT_OFF)
	boss_stories = clampi(int(file.get_value("options", "boss_stories", boss_stories)), STORIES_FULL, STORIES_OFF)
	fullscreen = bool(file.get_value("options", "fullscreen", fullscreen))
	ui_size = clampi(int(file.get_value("options", "ui_size", ui_size)), UI_BIG, UI_SMALL)
	var kept := {}
	if file.has_section("bindings"):
		for action in file.get_section_keys("bindings"):
			var events: Variant = file.get_value("bindings", action)
			if KeyBindings.is_remappable(StringName(action)) and (events is PackedStringArray or events is Array):
				kept[action] = PackedStringArray(events)
	bindings = kept


## The slider's volume on top of the bus's own gain in the mix (headroom, see SoundMixDef).
func _set_bus_volume(bus_name: StringName, volume: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.001)) + Sfx.mix.gain_db(bus_name))
