class_name CaptiveSoulsTrial
extends RoomTrial
## The Souls of Kagari (CaptiveSoulsDef): pale villagers held by chains of tar in one big room
## of the floor (CaptiveSoul). The hero frees each by standing by it for `free_seconds` (stepping
## away stops the count, it is not lost); the first moment he stands by one, the Well sends foes
## to take it back. Each soul freed rises and gives him back a little Health; all freed, the
## trial is done (its reward: the Game, on Events.trial_completed).

var souls: Array[CaptiveSoul] = []
var room_index := -1


## `count` souls in room `index`, put down from `seed` (their own dice), clear of what `taken`
## holds (and claiming their cells).
func setup_souls(world: World, trial: CaptiveSoulsDef, index: int, count: int, seed_value: int, taken: Dictionary) -> void:
	room_index = index
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var room := world.map.rooms[index]
	var cells: Array[Vector2i] = []
	for attempt in 80:
		if cells.size() >= count:
			break
		var cell := world.map.random_cell_in(room.grow(-1), rng)
		if taken.has(cell) or not RoomSpace.is_free(world, cell) \
				or cells.any(func(other: Vector2i) -> bool: return (other - cell).length_squared() < 9):
			continue
		cells.append(cell)
		FloorPopulator._reserve_around(taken, cell, 1)
	setup_trial(world, trial, cells.size())
	for i in cells.size():
		var soul := CaptiveSoul.new()
		var look: Texture2D = trial.looks[i % trial.looks.size()] if not trial.looks.is_empty() else null
		soul.setup(look, trial.element, i)
		soul.position = world.map.cell_to_world(cells[i])
		world.add_entity(soul)
		souls.append(soul)


func _physics_process(delta: float) -> void:
	if completed or _world == null:
		return
	var player := _world.player
	if player == null or player.is_dead or player.world != _world:
		return
	var by := _soul_by(player.global_position)
	for soul in souls:
		soul.held = soul == by
	if by == null:
		return
	if not by.called:
		by.called = true  # the Well wants it back
		_send_foes(by.global_position)
	by.progress += delta / def.free_seconds if def is CaptiveSoulsDef else 1.0
	if by.progress >= 1.0:
		_free(by, player)


## The soul not yet freed the hero stands by, or null.
func _soul_by(at: Vector2) -> CaptiveSoul:
	var reach := (def as CaptiveSoulsDef).reach
	for soul in souls:
		if not soul.freed and soul.global_position.distance_to(at) <= reach:
			return soul
	return null


func _free(soul: CaptiveSoul, player: Player) -> void:
	soul.set_free(false)
	var heal := roundi(player.get_max_hp() * (def as CaptiveSoulsDef).heal_share)
	if heal > 0:
		var healed := player.heal(heal)
		if healed > 0:
			_world.spawn_floating_text(player.head_position(), "+%d" % healed, Palette.HEAL)
	var element := (def as CaptiveSoulsDef).element
	if element:
		Vfx.nova(_world, soul.global_position, 30.0, element)
	_world.flash_light(soul.global_position, def.color, 140.0)
	Sfx.play_world(Sfx.bank.gate, soul.global_position)
	_step(soul.global_position)


func save_data() -> Dictionary:
	var freed: Array = []
	for soul in souls:
		if soul.freed:
			freed.append(soul.index)
	var data := super.save_data()
	data["freed"] = freed
	return data


func restore(saved: Dictionary) -> void:
	if str(saved.get("id", "")) != String(def.id):
		return
	var freed: Variant = saved.get("freed", [])
	if not freed is Array:
		return
	for entry: Variant in freed:
		var i := int(entry) if (entry is int or entry is float) else -1
		if i >= 0 and i < souls.size() and not souls[i].freed:
			souls[i].set_free(true)
			done += 1
	completed = done >= total and total > 0
