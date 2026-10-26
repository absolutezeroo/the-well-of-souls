class_name PlayerCommand
extends RefCounted
## One physics step's intentions, separate from Input and gameplay. Reused buffers belong to
## one controller; callers copy scalar fields instead of keeping a source's mutable buffer.
## This is a local simulation contract, not a trusted network message or server validator.

const SKILL_ACTIONS: Array[StringName] = [&"skill_1", &"skill_2", &"skill_3", &"skill_4"]
const BELT_ACTIONS: Array[StringName] = [&"belt_1", &"belt_2", &"belt_3"]
## GDScript cannot evaluate Array.size() as a const expression. Cached once, read-only.
static var _skill_mask: int = (1 << SKILL_ACTIONS.size()) - 1
static var _belt_mask: int = (1 << BELT_ACTIONS.size()) - 1

var movement := Vector2.ZERO
var attack_pressed := false
var attack_held := false
var quick_item_pressed := false
## Bits by slot. A press is an edge, consumed once, unlike attack_held and movement.
var skills_pressed := 0
var belt_pressed := 0


func clear_presses() -> void:
	attack_pressed = false
	quick_item_pressed = false
	skills_pressed = 0
	belt_pressed = 0


func clear() -> void:
	movement = Vector2.ZERO
	attack_held = false
	clear_presses()


## Null is an idle command. Bounds are independent of how the command was produced.
func copy_from(command: PlayerCommand) -> void:
	if command == null:
		clear()
		return
	movement = command.movement.limit_length() if command.movement.is_finite() else Vector2.ZERO
	attack_pressed = command.attack_pressed
	attack_held = command.attack_held
	quick_item_pressed = command.quick_item_pressed
	skills_pressed = (command.skills_pressed & _skill_mask) if command.skills_pressed >= 0 else 0
	belt_pressed = (command.belt_pressed & _belt_mask) if command.belt_pressed >= 0 else 0
