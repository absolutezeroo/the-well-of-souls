class_name AmbushRoom
extends Node2D
## A room that looks quiet... until the hero walks in: spikes close the exits and monsters
## pour in, wave after wave (the last one led by an elite). Clear them all and the way opens,
## with a big chest as a reward. See DungeonConfig > Ambushes. PactRoom builds on it (its
## waves, its gates) through the hooks below (_wants_start(), _wave_count(), _wave_size(),
## _spawns_elite()).


enum State { WAITING, FIGHTING, CLEARED }

# Its rhythm (seconds between two monsters showing up, before the next wave, how far from the
# hero they appear) is the dungeon's: DungeonConfig > Ambushes.

var state := State.WAITING
var room: Rect2i
var waves_left := 0
## Where its reward chest was put down when it was cleared (DungeonMap.NO_CELL: not yet, or
## none): saved with the floor, so a resumed floor puts the chest back there, wherever the hero
## stands (World.spent_data() "ambush").
var reward_cell := DungeonMap.NO_CELL

var _world: World
var _gates: RoomGates
var _to_spawn: Array[MonsterDef] = []
## Beside each of _to_spawn, what a resumed fight saved of that monster (FloorSave.monster_entry():
## its rank, its Health); {} for a new one.
var _to_spawn_saved: Array[Dictionary] = []
var _wave: Array[Monster] = []
## A fight under way when the run was saved (restore_progress()): the waves still to come after
## the one under way (-1: none saved), and that wave's monsters still to face.
var _resume_waves_left := -1
var _resume_wave: Array = []
var _spawn_timer := 0.0
var _pause_timer := 0.0
var _elite_in_wave := false


func setup(world: World, ambush_room: Rect2i) -> void:
	_world = world
	room = ambush_room
	_gates = RoomGates.new()
	add_child(_gates)
	_gates.setup(world, room)


func is_closed() -> bool:
	return _gates.is_closed()


func get_gate_cells() -> Array[Vector2i]:
	return _gates.get_cells()


func start() -> void:
	if state != State.WAITING:
		return
	_begin_fight()
	Events.ambush_started.emit(self)


## The exits close and the first wave comes (or, on a resumed floor, the wave that was under way).
func _begin_fight() -> void:
	state = State.FIGHTING
	waves_left = _wave_count()
	_gates.close()
	Sfx.play_world(Sfx.bank.ambush, _world.player.global_position)
	Events.screen_shake.emit(0.6)
	if _resume_waves_left >= 0:
		_resume_fight()
	else:
		_queue_wave()


func _wave_count() -> int:
	return _world.config().ambush_waves


func _wave_size() -> int:
	return _world.rules.ambush_wave_size()


## Whether the monster about to come is an elite (the last wave is led by one).
func _spawns_elite() -> bool:
	if _elite_in_wave:
		_elite_in_wave = false
		return true
	return false


## The hero walked in: on solid ground only (a roll ending in a hole would put them back
## outside the gates).
func _wants_start() -> bool:
	var player := _world.player
	return player != null and player.is_grounded() and room.grow(-1).has_point(_world.map.world_to_cell(player.global_position))


func _physics_process(delta: float) -> void:
	match state:
		State.WAITING:
			if _wants_start():
				start()
		State.FIGHTING:
			if not _to_spawn.is_empty():
				_spawn_timer -= delta
				if _spawn_timer <= 0.0:
					_spawn_timer = _world.config().ambush_spawn_interval
					_spawn_one(_to_spawn.pop_back(), _to_spawn_saved.pop_back() if not _to_spawn_saved.is_empty() else {})
			elif _is_wave_dead():
				if waves_left <= 0:
					_finish()
					return
				_pause_timer -= delta
				if _pause_timer <= 0.0:
					_queue_wave()
			else:
				_pause_timer = _world.config().ambush_wave_pause


## Every monster of the wave is dead (most are already freed: they dissolve when they die).
func _is_wave_dead() -> bool:
	for monster: Variant in _wave:
		if is_instance_valid(monster) and not (monster as Monster).is_dead:
			return false
	return true


func _queue_wave() -> void:
	waves_left -= 1
	_wave.clear()
	_elite_in_wave = waves_left == 0  # the last wave is led by an elite
	for i in _wave_size():
		var def := _world.pick_monster()
		if def:
			_to_spawn.append(def)
			_to_spawn_saved.append({})
	_spawn_timer = 0.0


## `saved`: what a resumed fight kept of this monster (its rank and Health), {} for a new one.
func _spawn_one(def: MonsterDef, saved: Dictionary = {}) -> void:
	var monster := _world.spawn_monster(def, _spawn_point())
	if not saved.is_empty():
		FloorSave.restore_monster(_world, monster, saved)
		if saved.get("lead", false) == true:
			_world.make_elite(monster)
	elif _spawns_elite():
		_world.make_elite(monster)
	monster.target = _world.player
	Vfx.puff(_world, monster.global_position)
	_wave.append(monster)


func _spawn_point() -> Vector2:
	var player_position := _world.player.global_position
	var point := _world.map.cell_to_world(_world.map.random_cell_in(room, _world.rng))
	for attempt in 10:
		if point.distance_to(player_position) >= _world.config().ambush_min_spawn_distance and _world.is_solid_ground(point) \
				and not _world.nav.is_blocked(_world.map.world_to_cell(point)):  # furniture, water
			break
		point = _world.map.cell_to_world(_world.map.random_cell_in(room, _world.rng))
	# Ten misses (a round room's corners are rock): the nearest free cell, never inside the rock.
	if not _world.is_free_cell(_world.map.world_to_cell(point)):
		point = _world.nearest_free_point(point)
	return point


## Free solid ground near the middle of the room, not under the hero.
func _reward_cell() -> Vector2i:
	var center := room.get_center()
	var hero := _world.map.world_to_cell(_world.player.global_position) if _world.player else Vector2i(-99, -99)
	for radius in range(0, maxi(room.size.x, room.size.y)):
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				var cell := Vector2i(x, y)
				if maxi(absi(x - center.x), absi(y - center.y)) != radius or not room.grow(-1).has_point(cell):
					continue
				if (cell - hero).length_squared() > 2 and _world.is_free_cell(cell):
					return cell
	return center


func _finish() -> void:
	state = State.CLEARED
	_gates.open()
	var chest_def := _world.config().ambush_chest
	if chest_def:
		var cell := _reward_cell()
		reward_cell = cell
		Vfx.magic(_world, _world.map.cell_to_world(cell), Palette.GOLD)
		_world.spawn_chest(chest_def, cell, false)
	Events.ambush_cleared.emit(self)


## `monster` is one of the waves it is sending (an ambush under way).
func holds(monster: Monster) -> bool:
	return state == State.FIGHTING and _wave.has(monster)


## How far its fight went, for the floor's save (FloorSave.ambush_data(), while FIGHTING or still
## to go on after a resume: is_resuming()): the
## waves still to come after the one under way, and that wave's monsters still to face, those
## standing (FloorSave.monster_entry(): rank, Health) and those not come yet (the one that will
## lead the last wave as an elite marked "lead"). The slain ones are not in it: picked up again, the fight never hands
## out the same kills twice.
func progress_data() -> Dictionary:
	if state == State.WAITING:
		# Resumed, not walked into yet: what was saved, still to come (saved again as it was).
		return { "waves_left": _resume_waves_left, "wave": _resume_wave.duplicate(true) } if is_resuming() else {}
	var wave: Array = []
	for monster: Variant in _wave:
		if is_instance_valid(monster) and not (monster as Monster).is_dead and not (monster as Monster).def.resource_path.is_empty():
			wave.append(FloorSave.monster_entry(monster as Monster))
	for i in range(_to_spawn.size() - 1, -1, -1):  # (in the order they come: popped from the back)
		var saved := _to_spawn_saved[i] if i < _to_spawn_saved.size() else {}
		if not saved.is_empty():
			wave.append(saved)
			continue
		var entry := { "def": RunSave.ref(_to_spawn[i]), "id": String(_to_spawn[i].id), "health": 1.0, "rank": "", "affixes": [] }
		if _elite_in_wave and i == _to_spawn.size() - 1:
			entry["lead"] = true  # the next to come leads the last wave (_spawns_elite()): an elite
		wave.append(entry)
	return { "waves_left": waves_left, "wave": wave }


## A fight saved under way waits to go on (restore_progress()): the hero hasn't walked back in.
func is_resuming() -> bool:
	return state == State.WAITING and _resume_waves_left >= 0


## A resumed floor: its fight was under way when the run was saved (progress_data() as a save file
## reads it). It waits for the hero to walk in again, then goes on from there (_resume_fight()).
func restore_progress(saved_waves_left: int, wave: Array) -> void:
	if state != State.WAITING:
		return
	_resume_waves_left = maxi(saved_waves_left, 0)
	_resume_wave = wave.duplicate(true)


## The fight saved goes on: the wave under way with only what was still to face, then the waves
## that were still to come. A kind the game no longer has is left out; an elite keeps its rank and
## affixes, the one still to lead the last wave comes as an elite.
func _resume_fight() -> void:
	waves_left = _resume_waves_left
	_resume_waves_left = -1
	_wave.clear()
	_to_spawn.clear()
	_to_spawn_saved.clear()
	_elite_in_wave = false
	for i in range(_resume_wave.size() - 1, -1, -1):  # the first saved comes first
		var entry: Variant = _resume_wave[i]
		var def := FloorSave.entry_def(entry)
		if def:
			_to_spawn.append(def)
			_to_spawn_saved.append(entry as Dictionary)
	_resume_wave.clear()
	_spawn_timer = 0.0


## A resumed floor: it was cleared before quitting. It stays quiet, its chest back where it was
## put down (`cell`; NO_CELL: none). Whether the chest was opened is the floor's chests' business.
func restore_cleared(cell: Vector2i) -> void:
	if state != State.WAITING:
		return
	state = State.CLEARED
	var chest_def := _world.config().ambush_chest
	if chest_def and cell != DungeonMap.NO_CELL and _world.map.is_floor(cell):
		reward_cell = cell
		_world.spawn_chest(chest_def, cell, false)
