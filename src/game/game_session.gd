class_name GameSession
extends RefCounted
## One run's runtime ownership. Opaque tickets prevent an old death, descent or fade from
## acting on a restarted run; references here are never serialized or sent online.

var expedition: RunState
var character: Player
var world: World
## A new expedition or a closed session invalidates continuations of the previous one.
var generation := 0
var _open := false
var _ticket: Ticket


## Opaque identity, distinct even when two sessions have the same generation number.
class Ticket:
	extends RefCounted


## Keeps the character reference; replacing it is an explicit legacy-run decision in Game.
func enter_expedition(next: RunState, scene: World) -> void:
	generation += 1
	_open = true
	_ticket = Ticket.new()
	expedition = next
	world = scene


## Leaving a dungeon need not destroy its hero. The next expedition gets its own generation.
func leave_expedition() -> void:
	generation += 1
	expedition = null
	_ticket = null


func capture() -> Ticket:
	return _ticket


func is_current(ticket: Ticket) -> bool:
	return _open and expedition != null and ticket != null and ticket == _ticket


## Invalidate async work before scene teardown; retain references for existing exit listeners.
func close() -> void:
	generation += 1
	_open = false
	_ticket = null
