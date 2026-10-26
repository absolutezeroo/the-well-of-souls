class_name GameSession
extends RefCounted
## Runtime ownership separate from one expedition. Game exposes compatibility getters for
## the existing run and hero. Character persistence and multi-region state are later RPG work;
## these live node references are deliberately never serialized or sent over the network.

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
