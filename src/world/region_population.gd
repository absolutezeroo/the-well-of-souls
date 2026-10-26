class_name RegionPopulation
extends RefCounted
## Per-region chest/monster ownership. Dead enemies stay tombstones; restore never calls die
## or open. Runtime children/summons are tracked through the same factories as authored spawns.

const MONSTER := preload("res://src/entities/monster/monster.tscn")
var _world: World
var _state: RegionState
var _generation := -1
var _restoring := false
var _valid := true
var _monsters: Dictionary[String, Monster] = {}
var _chests: Dictionary[String, Chest] = {}


func _init(world: World) -> void:
	_world = world
	world.monster_created.connect(_monster_created)
	world.chest_created.connect(_chest_created)


## Off-tree setup uses the very same Monster/FloorRules code to compute initial Health and
## composition. No live destination actors exist before the source checkpoint commits.
static func initialize(state: RegionState, region: RegionDef, content: ContentDB) -> bool:
	var scratch := World.new()
	scratch.depth = region.combat_depth
	scratch.rules = FloorRules.make(content.dungeon, content.default_difficulty, null, region.combat_depth)
	var valid := true
	for spawn in region.monsters:
		var monster := MONSTER.instantiate() as Monster
		monster.world = scratch
		monster.setup(spawn.monster, region.combat_depth, content.dungeon)
		monster.position = (Vector2(spawn.cell) + Vector2(0.5, 0.5)) * region.tile_size
		if spawn.rank:
			monster.make_ranked(spawn.rank, spawn.affixes)
		var saved := RegionMonsterState.capture("monster:" + region.id + "/" + spawn.id, monster)
		monster.free()
		if saved == null:
			valid = false
			break
		state.monsters[saved.id] = saved
	scratch.free()
	if not valid:
		return false
	for spawn in region.chests:
		var saved := RegionChestState.new()
		saved.id = "chest:" + region.id + "/" + spawn.id
		saved.definition = spawn.chest
		saved.cell = spawn.cell
		saved.trapped = spawn.trapped
		state.chests[saved.id] = saved
	state.population_initialized = true
	state.population_stamp = region.population_stamp()
	return true


func bind(state: RegionState) -> void:
	unbind()
	_state = state
	_generation = _world.floor_id
	_restoring = true
	for key in state.chests:
		var saved := state.chests[key]
		var chest := _world.spawn_chest(saved.definition, saved.cell, saved.trapped)
		chest.restore_opened(saved.opened, saved.fuse)
		_register_chest(key, chest)
	for key in state.monsters:
		var saved := state.monsters[key]
		if saved.dead:
			continue
		var monster := _world.spawn_monster(saved.definition, saved.position)
		if not saved.restore(monster):
			_valid = false
		_register_monster(key, monster)
	_restoring = false


func set_state(state: RegionState) -> void:
	_state = state


func capture(destination: RegionState) -> bool:
	if not _valid or _state == null or _world.floor_id != _generation:
		return false
	for key in _monsters:
		var monster := _monsters[key]
		if not is_instance_valid(monster):
			return false
		var saved := RegionMonsterState.capture(key, monster)
		if saved == null:
			return false
		destination.monsters[key] = saved
	for key in _chests:
		if not is_instance_valid(_chests[key]):
			return false
		destination.chests[key] = _snapshot_chest(key, _chests[key])
	return true


func unbind() -> void:
	for key in _monsters:
		var monster := _monsters[key]
		var callback := _died.bind(key, _generation)
		if is_instance_valid(monster) and monster.died.is_connected(callback):
			monster.died.disconnect(callback)
	for key in _chests:
		var chest := _chests[key]
		var callback := _opened.bind(key, _generation)
		if is_instance_valid(chest) and chest.opened.is_connected(callback):
			chest.opened.disconnect(callback)
	_monsters.clear()
	_chests.clear()
	_state = null
	_valid = true


func close() -> void:
	unbind()
	if is_instance_valid(_world):
		if _world.monster_created.is_connected(_monster_created):
			_world.monster_created.disconnect(_monster_created)
		if _world.chest_created.is_connected(_chest_created):
			_world.chest_created.disconnect(_chest_created)


func _monster_created(monster: Monster) -> void:
	if _restoring or _state == null:
		return
	var key := PersistentId.create("monster")
	var saved := RegionMonsterState.capture(key, monster)
	if saved == null:
		_valid = false
		return
	_state.monsters[key] = saved
	_register_monster(key, monster)


func _chest_created(chest: Chest) -> void:
	if _restoring or _state == null:
		return
	var key := PersistentId.create("chest")
	_state.chests[key] = _snapshot_chest(key, chest)
	_register_chest(key, chest)


func _register_monster(key: String, monster: Monster) -> void:
	_monsters[key] = monster
	monster.died.connect(_died.bind(key, _generation))


func _register_chest(key: String, chest: Chest) -> void:
	_chests[key] = chest
	chest.opened.connect(_opened.bind(key, _generation))


func _snapshot_chest(key: String, chest: Chest) -> RegionChestState:
	var saved := RegionChestState.new()
	saved.id = key
	saved.definition = chest.def
	saved.cell = _world.map.world_to_cell(chest.global_position)
	saved.opened = chest.is_open
	saved.trapped = chest.trapped
	saved.fuse = chest.trap_time_left()
	return saved


func _died(actor: Actor, key: String, generation: int) -> void:
	if _state == null or _world.floor_id != generation or generation != _generation:
		return
	var saved := RegionMonsterState.capture(key, actor as Monster)
	if saved == null:
		_valid = false
		return
	# Only authored enemies need death tombstones to suppress their initial spawn. A runtime
	# summon/offspring has no initial spawn to suppress; keep no unbounded dead-summon history.
	if key.begins_with("monster:"):
		_state.monsters[key] = saved
	else:
		_state.monsters.erase(key)
	_monsters.erase(key)


func _opened(chest: Chest, key: String, generation: int) -> void:
	if _state != null and _world.floor_id == generation and generation == _generation:
		_state.chests[key] = _snapshot_chest(key, chest)
