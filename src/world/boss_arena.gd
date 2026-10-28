class_name BossArena
extends Node2D
## The boss room of a boss floor. The boss sleeps in the middle; when the player walks in,
## spikes close the exits (RoomGates) and the fight starts. When the boss dies the spikes go down
## and the stairs appear where it stood.
## Its plan (ArenaDef) gives it a shape and pillars, and changes it as the boss enters its next
## phases (ArenaShiftDef): the cells blink red, then crumble, open into pits or grow spikes.
## A boss with a next form (BossDef.next_boss) doesn't end the fight when it falls: the arena
## darkens and shakes, the next form rises where it waits (BossDef.arena_anchor) and takes the
## fallen body, the storyteller meets it (its name, a line), and the fight goes on with it
## (Events.boss_rising, then boss_started). Only the last form's death opens the arena.

## How far from the hero and the boss a change keeps clear (cells).
const KEEP_CLEAR := 1

var boss: Monster
var is_started := false
var is_defeated := false
## Changes already made (one per phase).
var shifts_done := 0
## Between a form's fall and the next one's rise.
var is_rising := false
## Forms in this arena's fight (BossDef.forms()).
var _forms := 1

var _world: World
var _room: Rect2i
var _gates: RoomGates
var _plan: ArenaDef


func setup(world: World, boss_def: BossDef, plan: ArenaDef = null) -> void:
	_world = world
	_plan = plan
	_room = world.map.boss_room
	_gates = RoomGates.new()
	add_child(_gates)
	_gates.setup(world, _room)

	_forms = boss_def.forms().size()
	boss = _spawn_form(boss_def)
	if boss_def.rolls_rank():
		world.roll_boss_rank(boss)  # (a fight of several forms stays as written)
	_place_pillars()


## A run saved after the warden fell picks up here (FloorSave "arena_cleared"): the warden the
## seed laid again is taken away unseen, and the arena stands open with its stairs. Nothing is
## given again (no relic, no heal, no souls, no feat: they were, before quitting).
func clear_quietly() -> void:
	if is_instance_valid(boss):
		boss.queue_free()
	boss = null
	is_started = true
	is_defeated = true
	_gates.open(true)
	_world.spawn_exits()


## A form of the boss, asleep where it waits in the arena.
func _spawn_form(def: BossDef) -> Monster:
	var cell := _room.position + Vector2i(roundi(def.arena_anchor.x * (_room.size.x - 1)), roundi(def.arena_anchor.y * (_room.size.y - 1)))
	if def.arena_anchor == Vector2(0.5, 0.5):
		cell = _room.get_center()
	var at := _world.map.cell_to_world(cell) if _world.is_free_cell(cell) else _world.nearest_free_point(_world.map.cell_to_world(cell))
	var form := _world.spawn_monster(def, at)
	form.dormant = true
	form.facing = Vector2.DOWN
	form.died.connect(_on_boss_died)
	form.phase_entered.connect(_on_phase_entered)
	return form


## The plan's pillars, where the floor is (never in the middle, where the boss stands).
func _place_pillars() -> void:
	if _plan == null or _plan.pillar == null:
		return
	var center := _room.get_center()
	for at in _plan.pillars:
		var cell := _room.position + Vector2i(roundi(at.x * (_room.size.x - 1)), roundi(at.y * (_room.size.y - 1)))
		if _world.map.is_floor(cell) and (cell - center).length() > 3.5:
			_world.spawn_prop(_plan.pillar, cell)


## The arena's floor cells (no pillar, no hole), for its changes.
func floor_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(_room.position.y, _room.end.y):
		for x in range(_room.position.x, _room.end.x):
			var cell := Vector2i(x, y)
			if _world.map.is_floor(cell) and not _world.nav.is_blocked(cell) and not _world.has_pit(cell):
				result.append(cell)
	return result


func _on_phase_entered(index: int) -> void:
	if _forms > 1:
		return  # a fight of several forms keeps its arena as it is (the phases' indexes restart)
	if _plan == null or index - 1 >= _plan.shifts.size() or index <= shifts_done:
		return
	shifts_done = index
	shift(_plan.shifts[index - 1])


## Changes the arena: a warning on the cells, then they become what the change says.
func shift(change: ArenaShiftDef) -> void:
	var keep: Array[Vector2i] = [_room.get_center()]
	for actor: Actor in [_world.player, boss]:
		if actor and is_instance_valid(actor):
			keep.append(_world.map.world_to_cell(actor.global_position))
	var ground := {}
	for y in range(_room.position.y, _room.end.y):
		for x in range(_room.position.x, _room.end.x):
			if _world.map.is_floor(Vector2i(x, y)):
				ground[Vector2i(x, y)] = true
	var cells := change.pick_cells(floor_cells(), _room, keep, KEEP_CLEAR, _world.rng, ground)
	if cells.is_empty():
		return
	if not change.message.is_empty():
		Events.log_message(tr(change.message), Palette.DANGER)
		_world.spawn_floating_text(boss.head_position() + Vector2(0, -28), tr(change.message).to_upper(), Palette.DANGER)
	var warning := CellWarning.create(cells, _world.map.tile_size, change.warning_time)
	_world.spawn_vfx(warning)
	var floor_id := _world.floor_id
	await get_tree().create_timer(change.warning_time, false).timeout
	if is_instance_valid(_world) and not is_inside_tree():
		await tree_entered  # the floor waits out of the tree (the hero is at the Threshold): so does the change
	if not is_instance_valid(_world) or _world.floor_id != floor_id:
		return
	Events.screen_shake.emit(0.5)
	Sfx.play_at(Sfx.bank.explosion if change.becomes != ArenaShiftDef.Becomes.SPIKES else Sfx.bank.ambush, _world.map.cell_to_world(_room.get_center()), -6.0)
	var cycle := 0.0
	for cell in cells:
		match change.becomes:
			ArenaShiftDef.Becomes.PIT:
				if change.pit:
					_world.add_pit(cell, change.pit)
			ArenaShiftDef.Becomes.CRUMBLE:
				if change.pit:
					_world.spawn_crumbling_floor(change.pit, cell)
			ArenaShiftDef.Becomes.SPIKES:
				if change.trap:
					_world.spawn_trap(change.trap, cell, cycle)
					cycle += 0.08


## Cells just outside the room that are floor: the openings to close.
func get_gate_cells() -> Array[Vector2i]:
	return _gates.get_cells()


func is_closed() -> bool:
	return _gates.is_closed()


## The hero walked in: the exits close, the World's storyteller tells the warden's story (a
## cinematic over the frozen world, or nothing), then it wakes and the fight begins.
func start() -> void:
	if is_started or boss == null or boss.is_dead:
		return
	is_started = true
	# Shut in together only: a boss woken from the doorway (a bow shot...) and lured out
	# must not end up locked outside its own room.
	if _is_inside(boss.global_position) and _is_inside(_world.player.global_position):
		_gates.close()
	var woke_on_screen := false
	if _world.storyteller:
		@warning_ignore("redundant_await")  # a coroutine in BossMeeting (the base Storyteller answers at once)
		woke_on_screen = await _world.storyteller.meet(boss)
		if not is_instance_valid(boss) or boss.is_dead or not is_instance_valid(_world) or _world.player == null:
			return
	boss.wake_up(_world.player, not woke_on_screen)
	Sfx.play_at(Sfx.bank.boss_roar, boss.global_position)
	Events.screen_shake.emit(0.8)
	Events.boss_started.emit(boss)


## The fight starts once the player is well inside the room (checked every frame: simple and exact).
func _physics_process(_delta: float) -> void:
	if is_started or _world == null:
		return
	var player := _world.player
	if player == null or player.is_dead:
		return
	if _is_inside(player.global_position) or (boss and not boss.dormant):
		start()


func _is_inside(point: Vector2) -> bool:
	return _room.grow(-1).has_point(_world.map.world_to_cell(point))


func _on_boss_died(actor: Actor) -> void:
	var fallen := actor as Monster
	var def := fallen.def as BossDef if fallen else null
	if def and def.next_boss and not is_rising:
		_rise(fallen, def)
		return
	is_defeated = true
	if def and def.body_stays and def.settle_offset != Vector2.ZERO:
		_settle(fallen, def)
	_finish.call_deferred()


## `fallen` is down; its next form rises in the arena, takes its body, and the fight goes on.
func _rise(fallen: Monster, def: BossDef) -> void:
	is_rising = true
	var next := def.next_boss
	var floor_id := _world.floor_id
	await get_tree().create_timer(def.rise_time * 0.4, false).timeout
	if not await _still_here(floor_id):
		return
	# The next form rises out of the ground where it waits.
	var risen := _spawn_form(next)
	var rest := risen.rig.position if risen.rig else Vector2.ZERO
	if risen.rig:
		risen.rig.position = rest + Vector2(0, 90)
		risen.rig.modulate.a = 0.0
		var rising := risen.create_tween().set_parallel()
		rising.tween_property(risen.rig, "position", rest, def.rise_time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rising.tween_property(risen.rig, "modulate:a", 1.0, def.rise_time * 0.3)
	Events.boss_rising.emit(fallen, risen, def.rise_time * 0.6)
	Events.screen_shake.emit(0.9)
	Sfx.play_at(Sfx.bank.boss_roar, risen.global_position)
	Vfx.nova(_world, risen.global_position, 90.0, VfxElementDef.named(&"shadow"))
	# It takes the fallen body: drawn into its mouth, gone.
	if is_instance_valid(fallen):
		var mouth := risen.global_position + Vector2(0, -risen.def.head_height * 0.35)
		var taken := fallen.create_tween().set_parallel()
		taken.tween_property(fallen, "global_position", mouth, def.rise_time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if fallen.rig and fallen.rig.look:
			# Drawn in on its own pixels (an implosion in the shadow's ramp), never shrunk nor
			# faded by alpha (decision 0007).
			fallen.rig.look.vanish(DeathLookDef.Style.IMPLODE, VfxElementDef.named(&"shadow"))
			taken.tween_method(fallen.rig.look.set_vanishing, 0.0, 1.0, def.rise_time * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		taken.chain().tween_callback(fallen.queue_free)
	await get_tree().create_timer(def.rise_time * 0.6, false).timeout
	if not await _still_here(floor_id):
		return
	boss = risen
	# Risen, it is met: the storyteller may tell its story now (a cinematic: its name, a line).
	var woke_on_screen := false
	if _world.storyteller and _world.player and not _world.player.is_dead:
		@warning_ignore("redundant_await")  # a coroutine in BossMeeting (the base Storyteller answers at once)
		woke_on_screen = await _world.storyteller.meet(risen, true)
		if not is_instance_valid(risen) or risen.is_dead or not is_instance_valid(_world) or _world.player == null:
			return
	is_rising = false
	if _world.player and not _world.player.is_dead:
		risen.wake_up(_world.player, not woke_on_screen)
	Events.boss_started.emit(risen)


## The floor is still this one (it may wait out of the tree while the hero is at the Threshold).
func _still_here(floor_id: int) -> bool:
	if is_instance_valid(_world) and not is_inside_tree():
		await tree_entered
	return is_instance_valid(_world) and _world.floor_id == floor_id


## A body that stays (BossDef.body_stays) settles once its death is played (the Maw's last frame
## leaves Tôma standing in its empty mouth: set down on the ground).
func _settle(fallen: Monster, def: BossDef) -> void:
	if fallen.rig == null:
		return
	var frames := fallen.rig.body.sprite_frames
	var length := 1.0
	if frames and frames.has_animation(&"dead"):
		length = frames.get_frame_count(&"dead") / maxf(frames.get_animation_speed(&"dead"), 0.1)
	var tween := fallen.create_tween()
	tween.tween_interval(length + 0.2)
	tween.tween_property(fallen.rig, "position", fallen.rig.position + def.settle_offset, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _finish() -> void:
	_gates.open()
	_world.spawn_exits()
	_world.reward_clear()
	Vfx.magic(_world, _world.map.cell_to_world(_room.get_center()), Palette.GOLD)
	Events.boss_defeated.emit(boss)
