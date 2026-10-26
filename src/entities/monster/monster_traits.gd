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


## Disk records are ordered like the composition; a changed module kind/order is refused,
## never interpreted as another module's counters. No allocation in frame hooks.
func persistent_data() -> Array:
	var result: Array = []
	for behavior in active:
		result.append({ "kind": (behavior.get_script() as Script).get_global_name(),
			"data": behavior.persistent_data(_monster) })
	return result


static func composition(definition: MonsterDef, affixes: Array[EliteAffixDef]) -> Array[MonsterTrait]:
	var result: Array[MonsterTrait] = []
	var all: Array[MonsterTrait] = definition.traits.duplicate()
	for affix in affixes:
		all.append_array(affix.traits)
	for behavior in all:
		if behavior and not result.has(behavior):
			result.append(behavior)
	return result


static func accepts_data(modules: Array[MonsterTrait], saved: Array) -> bool:
	if modules.size() != saved.size():
		return false
	for i in modules.size():
		var row: Variant = saved[i]
		if not row is Dictionary or row.size() != 2 or not row.has("kind") or not row.get("data") is Dictionary \
				or row.kind != (modules[i].get_script() as Script).get_global_name() \
				or not modules[i].accepts_persistent_data(row.data):
			return false
	return true


func restore_persistent_data(saved: Array) -> bool:
	if not accepts_data(active, saved):
		return false
	for i in active.size():
		active[i].restore_persistent_data(_monster, saved[i].data)
	return true
