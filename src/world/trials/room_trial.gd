class_name RoomTrial
extends Node2D
## A room trial running on a floor (TrialDef, docs/design/dungeon.md "Room trials"): its steps
## done out of its total, the foes the Well sends at each step, and its end. The HUD's line
## (TrialLine) and the Game (its reward) listen to Events: trial_progressed, trial_completed.
## A kind (CaptiveSoulsTrial, SealTrial) lays its things, says when a step is done (`_step()`),
## and what its save keeps and gives back (save_data(), restore()): a resumed floor finds the
## steps done as they were, quietly (no foes, no reward again).

var def: TrialDef
var total := 0
var done := 0
var completed := false

var _world: World


## A generator of its own (seeded from the floor's): rolling for it leaves the rest of the floor
## as it was, and the same seed (a daily run) gives the same trial.
static func floor_rng(rng: RandomNumberGenerator) -> RandomNumberGenerator:
	var own := RandomNumberGenerator.new()
	own.seed = hash("%d-trial" % rng.seed)
	return own


## The trial of this floor, if it gets one: TrialDef.plan()'s answer with "trial" (the def), or
## {}. Only a normal floor past the first with no other event (no curse, no floor event: one
## thing of its own a floor), at `DungeonConfig.trial_chance`; `excluded`: rooms given away.
static func plan(world: World, config: DungeonConfig, depth: int, excluded: Array[int]) -> Dictionary:
	if depth <= 1 or config.boss_for_depth(depth) != null or config.trials.is_empty() \
			or world.curse != null or world.floor_event != null or world.hidden_floor != null or world.finale != null:
		return {}
	var rng := floor_rng(world.rng)
	if rng.randf() >= config.trial_chance:
		return {}
	# One drawn by weight; one that finds no room here (the Seal needs a dead-end room) gives
	# its place to another.
	var pool := config.trials.duplicate()
	while not pool.is_empty():
		var picked := ContentDB.pick_from(pool, depth, rng) as TrialDef
		if picked == null:
			return {}
		var planned := picked.plan(world, rng, excluded)
		if not planned.is_empty():
			planned["trial"] = picked
			return planned
		pool.erase(picked)
	return {}


func setup_trial(world: World, trial: TrialDef, steps: int) -> void:
	_world = world
	def = trial
	total = steps
	name = "Trial"
	add_to_group("room_trials")


## Its line under the minimap ("Souls freed: 2 / 4").
func objective_text() -> String:
	return tr(def.objective) % [done, total]


## A step done at `at` (a soul freed, a lantern lit): counted, the HUD told; the last one ends it.
func _step(at: Vector2) -> void:
	if completed:
		return
	done += 1
	Events.trial_progressed.emit(self)
	if done >= total:
		completed = true
		_world.flash_light(at, def.color, 260.0)
		Events.screen_shake.emit(0.3)
		Sfx.play_ui(Sfx.bank.boss_defeated, -4.0)
		if not def.done_line.is_empty():
			Events.log_message(tr(def.done_line), def.color)
		_on_completed()
		Events.trial_completed.emit(self)


## What the kind does once the last step is done (the seal breaks...).
func _on_completed() -> void:
	pass


## The Well's answer to a step begun at `at`: foes around it, a few steps away.
func _send_foes(at: Vector2) -> void:
	var count := def.foes_at(_world.depth)
	for i in count:
		var kind := _world.pick_monster()
		if kind == null:
			continue
		var point := _world.find_open_point_near(at, 70.0 + 12.0 * i, WorldSpace.room_for(kind))
		var monster := _world.spawn_monster(kind, point)
		monster.target = _world.player
		Vfx.puff(_world, monster.global_position)


## What a floor's save keeps of it (FloorSave "trial").
func save_data() -> Dictionary:
	return { "id": String(def.id), "done": done }


## A resumed floor: what was done before quitting is done again, quietly (`saved`: save_data()
## as a save file reads it; another trial's or a damaged one: nothing).
func restore(_saved: Dictionary) -> void:
	pass
