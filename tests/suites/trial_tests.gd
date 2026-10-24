class_name TrialTests
extends TestSuite
## Room trials (TrialDef, RoomTrial; docs/design/dungeon.md "Room trials"). Rules and data
## (run_unit()): every trial's data and words, where a floor may hold one (never with a curse or
## a floor event: one thing of its own a floor; never the first floor nor a boss floor), never
## with a pact door. In the game (run_game()): the Souls of Kagari freed by standing by them, the
## Well's foes at each, the Health given back, the souls paid; the Unbound Seal's lanterns lit,
## its door opening on its hoard; the HUD's line; a resumed floor keeping what was done.


func run_unit() -> void:
	var config := CONTENT.dungeon
	check(config.trials.size() >= 2 and config.trial_chance > 0.0, "the dungeon has its room trials (%d)" % config.trials.size())
	for def in config.trials:
		check(not def.display_name.is_empty() and not def.description.is_empty() and not def.call_line.is_empty() and not def.done_line.is_empty(), "%s: its name, lore, call and end" % def.id)
		check(def.objective.count("%d") == 2, "%s: its objective counts the done and the total" % def.id)
		check(def.min_depth >= 2, "%s: never on the first floor" % def.id)
		check(def.bonus_souls > 0 or def.relic_choices > 0, "%s: it pays something" % def.id)
	var souls := config.trials.filter(func(d: TrialDef) -> bool: return d is CaptiveSoulsDef)
	var seals := config.trials.filter(func(d: TrialDef) -> bool: return d is SealTrialDef)
	check(souls.size() == 1 and (souls[0] as CaptiveSoulsDef).looks.size() >= 2 and (souls[0] as CaptiveSoulsDef).element != null, "the Souls of Kagari: villagers' figures and their pale color")
	check(seals.size() == 1 and (seals[0] as SealTrialDef).chest != null and (seals[0] as SealTrialDef).lantern != null, "the Unbound Seal: its hoard and its lanterns")


func run_game(game: Game) -> void:
	var config := CONTENT.dungeon
	var kept := { "trial_chance": config.trial_chance, "pact_chance": config.pact_chance, "trials": config.trials }
	config.trial_chance = 1.0
	config.pact_chance = 1.0
	await _test_where(game)
	await _test_souls(game)
	config.trials = kept.trials
	await _test_seal(game)
	for key: String in kept:
		config.set(key, kept[key])


## A trial only on a floor with nothing else of its own, past the first, never with a pact door.
func _test_where(game: Game) -> void:
	var world: World = game.world
	var with_trial := 0
	var both := 0
	for depth in [2, 3, 4, 6, 7, 8]:
		await _floor(game, depth)
		world = game.world
		if world.room_trial:
			with_trial += 1
			if world.pact:
				both += 1
	check(with_trial >= 3, "at chance 1, most plain floors hold a trial (%d of 6)" % with_trial)
	check(both == 0, "never a pact door on a floor with a trial")
	var curse: CurseDef = CONTENT.curses[0] if not CONTENT.curses.is_empty() else null
	if curse:
		var cursed := 0
		for depth in [3, 4, 6]:
			await game.debug.enter_floor(depth, curse)
			await _frames(2)
			if game.world.room_trial:
				cursed += 1
		check(cursed == 0, "never on a cursed floor: one thing of its own a floor")
	await game.debug.enter_floor(1)
	await _frames(2)
	check(game.world.room_trial == null, "never on the first floor")


## Floor `depth` as the run lays it (its own twist rolled, as a resumed run rolls it again).
func _floor(game: Game, depth: int) -> void:
	game.run.hidden_floor = false
	game.run.finale = false
	game.depth = depth
	game._enter_floor()
	await _frames(2)


## The trial `kind` laid on a plain floor (a few tries: the Seal needs a dead-end room).
func _lay(game: Game, kind: Script) -> RoomTrial:
	var def: TrialDef = null
	for d in CONTENT.dungeon.trials:
		if d.get_script() == kind:
			def = d
	# (That one alone in the pool, until the test is over: the other one would take the floors
	# it can't, and the resumed floor must roll the same.)
	CONTENT.dungeon.trials = [def] as Array[TrialDef]
	var found: RoomTrial = null
	for depth in [3, 4, 6, 7, 8, 9, 3, 4, 6, 7, 8, 9]:
		await _floor(game, depth)
		var world: World = game.world
		if world.room_trial and world.room_trial.def == def:
			found = world.room_trial
			break
	return found


func _test_souls(game: Game) -> void:
	var trial := await _lay(game, CaptiveSoulsDef) as CaptiveSoulsTrial
	check(trial != null, "a floor holds the Souls of Kagari")
	if trial == null:
		return
	var world: World = game.world
	var player: Player = game.player
	player.invincible = true
	await _clear_monsters(world)
	var def := trial.def as CaptiveSoulsDef
	check(trial.total >= def.souls_min and trial.souls.size() == trial.total, "%d souls held in one room" % trial.total)
	check(game.hud.trial_line.state_text() == "Souls freed: 0 / %d" % trial.total, "the HUD names its objective: %s" % game.hud.trial_line.state_text())
	# Standing by one: the Well sends foes at once, the soul is freed after free_seconds.
	var soul: CaptiveSoul = trial.souls[0]
	player.global_position = soul.global_position + Vector2(0, 12)
	player.hp = player.get_max_hp() - 20
	var hp_before := player.hp
	await _stand_still(world, player)
	check(soul.called and world.monster_count() >= def.foes_at(world.depth), "the Well sends foes to take it back (%d)" % world.monster_count())
	check(not soul.freed and soul.progress > 0.0, "it frees by standing by it")
	for i in ceili(def.free_seconds * 60.0) + 10:
		await get_tree().physics_frame
	check(soul.freed and trial.done == 1, "freed after %.1f s by it" % def.free_seconds)
	check(player.hp > hp_before, "a soul freed gives Health back (%d -> %d)" % [hp_before, player.hp])
	check(game.hud.trial_line.state_text() == "Souls freed: 1 / %d" % trial.total, "the HUD counts it")
	# Saved and picked up: the freed soul stays freed, quietly.
	await _clear_monsters(world)
	game._save_run()
	game.resume_run(RunSave.read())
	await _frames(5)
	world = game.world
	trial = world.room_trial as CaptiveSoulsTrial
	check(trial != null and trial.done == 1 and trial.souls[0].freed and not trial.souls[0].visible, "a resumed floor keeps the soul freed (%s)" % (trial.done if trial else -1))
	if trial == null:
		return
	player = game.player
	player.invincible = true
	await _clear_monsters(world)
	# The rest freed: done, its souls paid to the run.
	var bonus_before := game.run.bonus_souls
	var completed := [false]
	var on_done := func(_t: RoomTrial) -> void: completed[0] = true
	Events.trial_completed.connect(on_done)
	for i in range(1, trial.souls.size()):
		var other: CaptiveSoul = trial.souls[i]
		player.global_position = other.global_position + Vector2(0, 12)
		await _stand_still(world, player)
		for f in ceili(def.free_seconds * 60.0) + 10:
			await get_tree().physics_frame
		await _clear_monsters(world)
	Events.trial_completed.disconnect(on_done)
	check(trial.completed and completed[0], "every soul freed: the trial is done")
	check(game.run.bonus_souls == bonus_before + def.bonus_souls, "its souls go to the run (+%d)" % def.bonus_souls)
	player.invincible = false


func _test_seal(game: Game) -> void:
	var trial := await _lay(game, SealTrialDef) as SealTrial
	check(trial != null, "a floor holds the Unbound Seal")
	if trial == null:
		return
	var world: World = game.world
	var player: Player = game.player
	player.invincible = true
	await _clear_monsters(world)
	var def := trial.def as SealTrialDef
	check(trial.lanterns.size() == def.lanterns and trial.total == def.lanterns, "its %d lanterns, put out, in other rooms" % def.lanterns)
	check(trial.lanterns.all(func(l: SealLantern) -> bool: return not trial.room.has_point(world.map.world_to_cell(l.global_position))), "none behind the sealed door")
	check(trial._gates.is_closed(), "the door is sealed")
	var hoard := world.get_node("Entities").get_children().filter(func(n: Node) -> bool: return n is Chest and trial.room.has_point(world.map.world_to_cell((n as Chest).global_position)))
	check(hoard.size() == 1, "its hoard waits inside")
	# A lantern lit: its point lights, the dark answers.
	trial.lanterns[0]._spot.use(player)
	await _frames(2)
	check(trial.lanterns[0].is_lit and trial.done == 1, "a lantern lit by Interact")
	check(world.monster_count() >= def.foes_at(world.depth), "the dark answers with foes (%d)" % world.monster_count())
	await _clear_monsters(world)
	game._save_run()
	game.resume_run(RunSave.read())
	await _frames(5)
	world = game.world
	trial = world.room_trial as SealTrial
	check(trial != null and trial.done == 1 and trial.lanterns[0].is_lit and trial._gates.is_closed(), "a resumed floor keeps the lantern lit, the door still sealed (%s)" % (str([trial.done, trial.lanterns[0].is_lit, trial._gates.is_closed()]) if trial else "no trial"))
	if trial == null:
		return
	player = game.player
	player.invincible = true
	for i in range(1, trial.lanterns.size()):
		trial.lanterns[i]._spot.use(player)
		await _frames(1)
	await _frames(2)
	check(trial.completed and not trial._gates.is_closed(), "every lantern lit: the seal breaks, the door opens")
	await _clear_monsters(world)
	game._save_run()
	game.resume_run(RunSave.read())
	await _frames(5)
	trial = game.world.room_trial as SealTrial
	check(trial != null and trial.completed and not trial._gates.is_closed(), "resumed, the broken seal stays broken")
	game.player.invincible = false
