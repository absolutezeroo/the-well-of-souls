class_name ActionPromptDef
extends Resource
## One control as the player is told about it: a row of the Controls page (Options) and the key or
## button its prompts show (Prompts). The bindings themselves are the input map's
## (project.godot > Input Map): this only says which one to show and what it is called.

## The input action ("attack"), or a name for several shown together (`parts`: "move").
@export var action: StringName
## The Controls page's word for it ("Attack").
@export var display_name := ""
## Actions shown as one (move: up, left, down, right: "WASD", "L stick"). Empty: `action` alone.
@export var parts: Array[StringName] = []
## The parts' keys written as one word ("WASD", "ZQSD" on a French keyboard) rather than one
## after the other ("Q / E").
@export var joined := false
## The key its prompts show (a physical key); none: the action's first key in the input map.
@export var key: Key = KEY_NONE
## Also done with this mouse button in a fight (MouseControls), listed on the Controls page.
@export var mouse: MouseButton = MOUSE_BUTTON_NONE
## How it is done by touch, for the Controls page on a phone ("The big red button").
@export var touch_text := ""
## Listed on the Controls page (some prompts, like a menu's accept, are only for sentences).
@export var listed := true
## The player may give it another key or gamepad button on the Controls page (KeyBindings).
## Only single actions (no `parts`); the menu's own keys and the reserved ones never.
@export var remappable := false


## The input actions behind it.
func actions() -> Array[StringName]:
	if parts.is_empty():
		return [action]
	return parts
