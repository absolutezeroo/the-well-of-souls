class_name State
extends Node
## One behaviour of a monster (idle, chase, attack...). Lives under a StateMachine.

var machine: StateMachine
var actor: Monster
## Thinks every physics frame (a strike's wind-up, a cast: their timing is felt). The others
## (idle, chase: deciding where to go) think every StateMachine.THINK_EVERY frames, with the time
## gone since, and the body keeps walking the way chosen meanwhile.
var every_frame := false


func enter() -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
