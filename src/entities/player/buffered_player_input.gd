class_name BufferedPlayerInput
extends PlayerCommandSource
## An independent command producer for tools and the future remote-input adapter. Held state
## keeps its latest value; presses accumulate until sampled, then are consumed exactly once.
## No transport, authentication, sequencing or timeout policy is implemented here.

var _pending := PlayerCommand.new()
var _incoming := PlayerCommand.new()


## Copies the caller's buffer: later edits cannot change an already submitted intention.
func submit(command: PlayerCommand) -> void:
	_incoming.copy_from(command)
	_pending.movement = _incoming.movement
	_pending.attack_held = _incoming.attack_held
	_pending.attack_pressed = _pending.attack_pressed or _incoming.attack_pressed
	_pending.quick_item_pressed = _pending.quick_item_pressed or _incoming.quick_item_pressed
	_pending.skills_pressed |= _incoming.skills_pressed
	_pending.belt_pressed |= _incoming.belt_pressed


func sample() -> PlayerCommand:
	_sample.copy_from(_pending)
	_pending.clear_presses()
	return _sample


## Stops held movement/attack too (a producer detached, or a simulated disconnection).
func reset() -> void:
	_pending.clear()
	_sample.clear()
	_incoming.clear()
