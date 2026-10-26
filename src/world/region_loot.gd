class_name RegionLoot
extends RefCounted
## Tracks pickups at creation, including deferred drops, and removes only successfully taken
## items. One active region; disconnected before unload. No registry scan in a frame loop.

var _world: World
var _state: RegionState
var _pickups: Dictionary[String, ItemPickup] = {}
var _generation := -1
var _restoring := false
var _valid := true


func _init(world: World) -> void:
	_world = world
	world.item_created.connect(_created)


func bind(state: RegionState) -> void:
	unbind()
	_state = state
	_generation = _world.floor_id
	_restoring = true
	for key in state.objects:
		var object_state := state.objects[key]
		var pickup := _world.spawn_item(object_state.item(), object_state.position)
		_register(key, pickup)
	_restoring = false


func unbind() -> void:
	for key in _pickups:
		var pickup := _pickups[key]
		var callback := _taken.bind(key, _generation)
		if is_instance_valid(pickup) and pickup.taken.is_connected(callback):
			pickup.taken.disconnect(callback)
	_pickups.clear()
	_state = null
	_valid = true


func close() -> void:
	unbind()
	if is_instance_valid(_world) and _world.item_created.is_connected(_created):
		_world.item_created.disconnect(_created)


## A successful checkpoint swaps the snapshot owner, not the already loaded pickup nodes.
func set_state(state: RegionState) -> void:
	_state = state


## Copies current positions/item data into a candidate snapshot before a common commit.
func capture(destination: RegionState) -> bool:
	if not _valid or _state == null or _world.floor_id != _generation:
		return false
	for key in _pickups:
		var pickup := _pickups[key]
		if not is_instance_valid(pickup):
			return false  # untracked destruction must not silently erase a player's item
		if pickup.is_taken():
			destination.objects.erase(key)
			continue
		var object_state := RegionObjectState.create(key, pickup.item, pickup.global_position)
		if object_state == null:
			return false
		destination.objects[key] = object_state
	return true


func _created(pickup: ItemPickup) -> void:
	if _restoring or _state == null:
		return
	if _world.floor_id != _generation:
		_valid = false
		return
	var key := PersistentId.create("object")
	var object_state := RegionObjectState.create(key, pickup.item, pickup.position)
	if object_state == null:
		_valid = false
		return
	_state.objects[key] = object_state
	_register(key, pickup)


func _register(key: String, pickup: ItemPickup) -> void:
	_pickups[key] = pickup
	pickup.taken.connect(_taken.bind(key, _generation))


func _taken(_pickup: ItemPickup, key: String, generation: int) -> void:
	if _state == null or generation != _generation or _world.floor_id != generation:
		return
	_state.objects.erase(key)
	_pickups.erase(key)
