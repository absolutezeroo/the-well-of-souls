class_name StateMachine
extends Node
## Runs one State at a time. Every child State node is a possible state,
## reachable by its node name: transition_to(&"Chase").

## Idle and chase think every this many physics frames (each monster on its own beat), with the
## time gone since: a crowd's AI is a big share of its cost (docs/performance.md, "A crowd"),
## and a decision of where to walk 1/30 s later is not felt. Strikes and casts think every frame
## (State.every_frame), bosses too.
const THINK_EVERY := 2

@export var initial_state: State

var current: State
## Time gone since this machine last thought.
var _waiting := 0.0


func _ready() -> void:
	var monster := owner as Monster
	for child in get_children():
		if child is State:
			child.machine = self
			child.actor = monster
	current = initial_state
	if current:
		current.enter()


## Thinks nothing while the debug panel's No AI is on (Monster.ai_frozen()): the state waits as it
## was, and goes on once it is off.
func _physics_process(delta: float) -> void:
	if current and not current.actor.is_dead and not current.actor.is_falling and not current.actor.ai_frozen():
		_waiting += delta
		if current.every_frame or current.actor.is_boss() \
				or (Engine.get_physics_frames() + current.actor.get_instance_id()) % THINK_EVERY == 0:
			var gone := _waiting
			_waiting = 0.0
			current.physics_update(gone)
	else:
		_waiting = 0.0


func transition_to(state_name: StringName) -> void:
	var next := get_node_or_null(NodePath(state_name)) as State
	if next == null:
		push_error("Unknown state: %s" % state_name)
		return
	if current:
		current.exit()
	current = next
	_waiting = 0.0
	current.enter()
