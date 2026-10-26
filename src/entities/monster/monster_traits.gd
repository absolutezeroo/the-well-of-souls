class_name MonsterTraits
extends RefCounted
## One monster's composed behaviours and private states. Native traits precede affix traits
## in their saved order. Build only at spawn/ranking: frame hooks read the same cached array.
## Shared behavior resources are immutable; identical resources activate only once per monster.

var active: Array[MonsterTrait] = []
var draws_under := false
var _states: Dictionary[MonsterTrait, RefCounted] = {}
var _monster: Monster


func _init(monster: Monster) -> void:
	_monster = monster


func setup(native: Array[MonsterTrait]) -> void:
	active.clear()
	_states.clear()
	draws_under = false
	add(native)


## Called once for native traits, then once per accepted affix, never from a frame hook.
func add(traits: Array[MonsterTrait]) -> void:
	for behavior in traits:
		if behavior == null or active.has(behavior):
			continue
		active.append(behavior)
		draws_under = draws_under or behavior.draws_under()
		behavior.on_spawn(_monster)


func state(behavior: MonsterTrait) -> RefCounted:
	var values: RefCounted = _states.get(behavior)
	if values == null:
		values = behavior.make_state()
		_states[behavior] = values
	return values


func first(kind: Script) -> MonsterTrait:
	for behavior in active:
		if is_instance_of(behavior, kind):
			return behavior
	return null
