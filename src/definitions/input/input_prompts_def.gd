class_name InputPromptsDef
extends Resource
## How the game shows its controls on each device (data/ui/input_prompts.tres): the controls the
## player is told about (the Controls page's rows, the keys prompts show), the gamepad families'
## button names, short names for keys, and the input device's tuning (InputDevice).

## Every control the player is told about, in the Controls page's order.
@export var actions: Array[ActionPromptDef] = []
## Input actions whose keys and buttons no other control may take (KeyBindings): moving, Pause
## and Fullscreen, so the hero can always move and the game always pause.
@export var reserved_actions: Array[StringName] = []
## The gamepad families; the last one is for pads no family claims.
@export var pads: Array[PadGlyphsDef] = []
## Keys with a word of their own on their caps (physical keycodes), and those words, in the same
## order ("Esc" for Escape; translated where shown). Other keys show their own name
## (OS.get_keycode_string()) in the layout of the player's keyboard.
@export var key_codes := PackedInt32Array()
@export var key_words := PackedStringArray()
## The mouse buttons' words in sentences, by MouseButton index (1: left, 2: right, 3: middle);
## their caps draw a little mouse instead.
@export var mouse_glyphs := PackedStringArray()
## A stick must lean this far (0..1) before it counts as the gamepad being used: a drifting stick
## never takes the prompts away from the keyboard.
@export_range(0.0, 1.0) var stick_deadzone := 0.5
## The mouse must move this far (screen pixels, in one event) to take over from a gamepad.
@export var mouse_threshold := 6.0


func action(id: StringName) -> ActionPromptDef:
	for entry in actions:
		if entry.action == id:
			return entry
	return null


## The family whose `name_hints` match a pad's name (lowercase pieces); the last one otherwise.
func family_for(joy_name: String) -> PadGlyphsDef:
	var lower := joy_name.to_lower()
	for family in pads:
		for hint in family.name_hints:
			if not hint.is_empty() and lower.contains(hint):
				return family
	return pads.back() if not pads.is_empty() else null


func pad(id: StringName) -> PadGlyphsDef:
	for entry in pads:
		if entry.id == id:
			return entry
	return pads.back() if not pads.is_empty() else null


## The mouse button's words in a sentence, translated.
func mouse_glyph(button: int) -> String:
	return TranslationServer.tr(mouse_glyphs[button]) if button >= 0 and button < mouse_glyphs.size() else "?"


## The key's own word ("Esc"), translated; empty if it has none.
func key_word(physical: int) -> String:
	var at := key_codes.find(physical)
	return TranslationServer.tr(key_words[at]) if at >= 0 and at < key_words.size() else ""
