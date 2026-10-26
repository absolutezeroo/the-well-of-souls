class_name FloorTests
extends TestSuite
## In the game: what floors hold (props, hazards, chests, ambushes, encounters, the merchant,
## loot, curses...), act cards, souls, saving, the belt.


## Lights, props, explosive barrels, traps and the death dissolve.
func _test_world_objects(_game: Game, world: World, player: Player) -> void:
	var torch := player.get_node("Torch") as LightSource
	check(torch.is_lit() and world.lights.level_at(player.global_position) >= torch.level, "the hero carries a torch")
	check(world.lights.ambient_level == world.theme.lighting.ambient_level, "the floor is as dark as its theme")
	check(get_tree().get_nodes_in_group("props").size() > 0, "the floor has props")
	var lanterns := get_tree().get_nodes_in_group("props").filter(func(p: Node) -> bool: return (p as Prop).def == CONTENT.dungeon.room_light)
	check(lanterns.size() >= world.map.rooms.size(), "every room has lanterns (%d)" % lanterns.size())
	var lantern := lanterns[0] as Prop
	check(world.lights.level_at(lantern.global_position) >= lantern.def.light_level, "a lantern lights its tile at its level")
	var flash_at := world.map.cell_to_world(_open_cell_near(world, player.global_position + Vector2(160, 0), 1))
	world.lights.level_at(flash_at)  # the light baked as it was before the flash
	world.flash_light(flash_at, Color.WHITE, 400.0)  # 10 levels above the floor's own light
	await _frames(1)
	check(world.lights.level_at(flash_at) >= mini(LightField.MAX_LEVEL, world.lights.ambient_level + 9), "a flash lights up the place")
	for i in 300:  # (hits on the hero meanwhile may freeze time a moment)
		if get_tree().get_nodes_in_group(LightSource.GROUP).all(func(n: Node) -> bool: return not n is LightFlash):
			break
		await _frames(1)
	check(get_tree().get_nodes_in_group(LightSource.GROUP).all(func(n: Node) -> bool: return not n is LightFlash), "...then fades")

	# A crate in front of the hero breaks under the katana.
	var crate_def: PropDef = load("res://data/props/crate.tres")
	var spot := world.map.world_to_cell(world.find_open_point_near(player.global_position, 40.0))
	var crate := world.spawn_prop(crate_def, spot)
	await _frames(1)
	# The nearest free cell may be a step away: stand right by it (from the side the hero came).
	var side := crate.global_position.direction_to(player.global_position)
	for i in crate_def.hits:
		if not is_instance_valid(crate) or crate.is_broken:
			break
		player.global_position = crate.global_position + side * 34.0
		player._attack_cooldown = 0.0
		player.attack(player.global_position.direction_to(crate.global_position))
		await _frames(4)
	check(not is_instance_valid(crate) or crate.is_broken, "a crate breaks after %d hits" % crate_def.hits)
	await _frames(5)

	# Powder kegs: one explodes, sets off its neighbour, hurts a monster nearby, credits the hero.
	var keg_def: PropDef = load("res://data/props/tnt.tres")
	var base := _open_cell_near(world, player.global_position + Vector2(120, 0), 2)  # room for both kegs and the rat
	var keg := world.spawn_prop(keg_def, base)
	var keg2 := world.spawn_prop(keg_def, base + Vector2i(1, 0))
	var rat := world.spawn_monster(load("res://data/monsters/rat.tres"), world.map.cell_to_world(base) + Vector2(0, 30))
	rat.dormant = true
	await _frames(1)
	var rat_hp := rat.hp
	var spark := HitInfo.new()
	spark.source = player
	keg.take_hit(spark)
	check(not keg.is_broken, "a keg has a fuse")
	# (A hit stop from an earlier blow may slow the first frames down: a little leeway.)
	for i in int(keg_def.fuse_time * 60.0) * 3:
		if not is_instance_valid(keg) or keg.is_broken:
			break
		await _frames(1)
	check(not is_instance_valid(keg) or keg.is_broken, "the keg explodes after its fuse")
	check(not is_instance_valid(rat) or rat.is_dead or rat.hp < rat_hp, "the blast hurts monsters")
	for i in int(keg_def.fuse_time * 60.0) * 3:
		if not is_instance_valid(keg2) or keg2.is_broken:
			break
		await _frames(1)
	check(not is_instance_valid(keg2) or keg2.is_broken, "explosions set off other kegs")
	await _frames(30)
	check(not is_instance_valid(rat), "dead monsters dissolve and disappear")

	# A spike trap hurts whoever stands on it, monsters included.
	var spikes: TrapDef = load("res://data/hazards/spikes.tres")
	var trap_cell := world.map.world_to_cell(world.find_open_point_near(player.global_position, 120.0))
	var trap := world.spawn_trap(spikes, trap_cell)
	var victim := world.spawn_monster(load("res://data/monsters/slime.tres"), world.map.cell_to_world(trap_cell))
	victim.dormant = true
	await _frames(1)
	var victim_hp := victim.hp
	var cycle := spikes.idle_time + spikes.warning_time + 0.2
	var saw_warning := false
	for i in int(cycle * 60.0):
		saw_warning = saw_warning or trap.phase == Trap.Phase.WARNING
		await get_tree().physics_frame
	check(saw_warning, "spikes warn before they strike")
	check(victim.hp < victim_hp, "spikes hurt monsters standing on them")
	trap.queue_free()
	if is_instance_valid(victim):
		victim.queue_free()

	# A pressure plate waits for someone to step on it.
	var plate: TrapDef = load("res://data/hazards/spike_plate.tres")
	var plate_cell := world.map.world_to_cell(world.find_open_point_near(player.global_position, 120.0))
	var plate_trap := world.spawn_trap(plate, plate_cell)
	await _frames(60)
	check(plate_trap.phase == Trap.Phase.IDLE, "a plate stays still while nobody is on it")
	var hp_before := player.hp
	player.base_stats.defense = 0
	player.invalidate_stats()
	player._invulnerable_time = 0.0
	player.global_position = plate_trap.global_position
	await _frames(int((plate.warning_time + 0.1) * 60.0) + 2)
	check(player.hp < hp_before, "stepping on a plate fires its spikes")
	player.hp = player.get_max_hp()
	plate_trap.queue_free()
	await _frames(5)


## Holes, crumbling floor, quicksand, arrow traps, chests, elites, ambushes and how floors use them.
## The smith's forge: runes go into the worn weapon's sockets, come back out for gold.
## The Deeps (Abyss): a fall on a floor takes the hero down while his floor waits out of the tree;
## demons come in waves; the Dawn Breach brings him back by the hole, his Health as it was down
## there, with the dawn's gift if he was quick. A hole down there is the old rule. A second life
## opens the Threshold from the Deeps and brings him back into them. Nothing is saved meanwhile.
func _test_abyss(game: Game, world: World, player: Player) -> void:
	var abyss := game.abyss
	var def := CONTENT.dungeon.abyss
	check(def != null and abyss.def == def, "the floors have their Deeps")
	# The monsters around out of the way (the others stay for the bot's hunt, later).
	for other in world.get_hostiles(Actor.Faction.PLAYER):
		if other.global_position.distance_to(player.global_position) < 700.0:
			other.queue_free()
	await _frames(1)
	player.perks.clear()
	player.hp = player.get_max_hp()
	var xp_saved := player.xp
	player.xp = -1000000  # no level up (and its pause) in the middle of this
	check(abyss.can_take(player), "a fall on a plain floor can take the hero down")
	# Two monsters wait on the floor; one is hurt and burning.
	var skeleton: MonsterDef = load("res://data/monsters/skeleton.tres")
	var watchers: Array[Monster] = []
	for spot in _free_points_away(world, player.global_position, 5, 10, 2):
		var watcher := world.spawn_monster(skeleton, spot)
		watcher.dormant = true
		watchers.append(watcher)
	check(watchers.size() == 2, "two monsters to watch over")
	if watchers.size() < 2:
		return
	await _frames(1)
	watchers[0].hp -= 3
	watchers[0].statuses.apply_dot(&"burn", 1, 0.5, 30.0, player, Palette.FIRE)
	game._save_run()
	var saved := RunSave.read()
	var floor_mode := world.process_mode
	var torch := player.get_node("Torch") as LightSource
	var torch_level := torch.level
	var safe := await _walk_into_hole(world, player)
	var first_hole := player.global_position
	var floor_things := _floor_things(world, false)  # (the dawn's gift falls at his feet)
	var max_hp := player.get_max_hp()
	var hp_before := player.hp
	var landing := { "statuses before": player.statuses.active_ids(), "temperature": player.temperature.value }
	# (His Health as he lands, before the fall's cost. The game, not the hero, in the lambda: the
	# Abyss goes with it, while a hero may be freed before a fall that never came.)
	abyss.opened.connect(func(_def: AbyssDef) -> void: landing.hp = game.player.hp, CONNECT_ONE_SHOT)
	await _frames(int(Actor.FALL_TIME * 60.0) + 4)
	check(abyss.is_open() and not player.is_dead, "the hero falls into the Deeps (%s)" % _fall_state(game, first_hole))
	await get_tree().process_frame
	check(world.process_mode == Node.PROCESS_MODE_DISABLED, "the floor stops where it is")
	var frozen_at: Array[Vector2] = [watchers[0].global_position, watchers[1].global_position]
	var hp_then: Array[int] = [watchers[0].hp, watchers[1].hp]
	var burn_left: float = watchers[0].statuses._dots[0].time_left
	var clock := game.run.time
	check(await _until_deeps(game), "the veil lifts on the Deeps")
	var depths := abyss.depths
	check(depths != null and player.world == depths and depths.is_ancestor_of(player), "the hero is in the Deeps")
	check(not world.is_inside_tree() and game.world == world, "his floor waits, out of the tree")
	check(player.hp < hp_before and hp_before - player.hp <= maxi(1, roundi(max_hp * def.fall_damage)), "the fall costs up to %d%% of his max Health, less his Armor (%d -> %d, %s)" % [roundi(def.fall_damage * 100.0), hp_before, player.hp, landing])
	check(torch.level == def.torch_level and torch.level < torch_level, "his torch burns low down there")
	check(depths.lights.ambient_level == def.lighting.ambient_level and depths.theme == def.theme, "the Deeps have their own dark and look")
	var door := depths.door
	check(door != null and door.is_inside_tree() and depths.map.world_to_cell(door.global_position) == depths.map.stairs_cell, "the Dawn Breach stands in the farthest room")
	check(not depths.way_to_door(player.global_position).is_empty(), "he can walk to it")
	check(depths.lights.level_at(door.global_position) >= def.door_light - 1, "it lights the dark around it")
	check((game.hud.get_node("AbyssHud") as Control).visible and not (game.hud.get_node("%Minimap") as Control).visible, "the HUD shows the Deeps, not the floor's map")
	check((game.hud.get_node("%BagButton") as Control).visible, "the bag still opens down there (a fight like any other)")
	check(not abyss.can_take(player), "no Deeps under the Deeps")
	game._save_run()
	check(RunSave.read() == saved, "nothing is saved in the Deeps")
	# The first wave crawls out of the dark.
	var waves := []
	depths.wave_risen.connect(func(_index: int, risen: Array[Monster]) -> void: waves.append(risen.duplicate()))
	for i in int((def.first_wave + 1.0) * 60.0):
		if not waves.is_empty():
			break
		await _frames(1)
	check(not waves.is_empty() and not (waves[0] as Array).is_empty(), "demons come out of the dark (%d)" % (waves[0] as Array).size() if not waves.is_empty() else "demons come out of the dark")
	if not waves.is_empty():
		var first: Array = waves[0]
		check(first.size() == mini(def.wave_size_for(0, world.depth, CONTENT.dungeon), def.max_alive_for(world.depth, CONTENT.dungeon)), "the first wave is the size the Deeps say")
		check(first.all(func(m: Monster) -> bool: return def.monsters.has(m.def) and m.target == player and not m.summoned), "demons of the Deeps, coming for him (worth their XP)")
		check(first.all(func(m: Monster) -> bool: return m.global_position.distance_to(player.global_position) >= (def.spawn_cells.x - 1) * depths.map.tile_size), "out of the dark, not on top of him")
	check(game.run.time > clock, "the run's clock keeps counting")
	# A hole down there: the old rule (climb out hurt), still in the Deeps. (The waves stop for
	# this: the test is the fall, not the fight.)
	depths.waves_on = false
	for m in depths.get_hostiles(Actor.Faction.PLAYER):
		m.queue_free()
	await _frames(1)
	player.invincible = false
	player.hp = player.get_max_hp()
	var deep_safe := await _walk_into_hole(depths, player)
	var hp_deep := player.hp
	await _frames(int(Actor.FALL_TIME * 60.0) + 6)
	check(player.world == depths and not player.is_falling and player.global_position.distance_to(deep_safe) < 24.0, "a hole in the Deeps: he climbs out of it, still down there (dead %s, falling %s, %d px away)" % [player.is_dead, player.is_falling, roundi(player.global_position.distance_to(deep_safe))])
	check(player.hp < hp_deep, "and it hurts")
	# Out, quick: back by the hole, his Health as it is, a moment of grace and the dawn's gift.
	player.hp = maxi(1, player.hp - 5)
	var hp_out := player.hp
	var gold_before := _gold_on_floor(world)
	var home := {}
	abyss.closed.connect(func(escaped: bool) -> void:
		home.escaped = escaped
		home.at = [watchers[0].global_position, watchers[1].global_position]
		home.hp = [watchers[0].hp, watchers[1].hp]
		home.burn = watchers[0].statuses._dots[0].time_left if watchers[0].statuses.has(&"burn") else -1.0, CONNECT_ONE_SHOT)
	for m in depths.get_hostiles(Actor.Faction.PLAYER):
		m.queue_free()  # (not to be hit on the way to the door)
	await _frames(1)
	check(await _escape_deeps(game) and home.get("escaped", false), "stepping into the Dawn Breach brings him back up")
	check(player.world == world and world.is_inside_tree() and world.process_mode == floor_mode, "back on his floor, and it runs again")
	check(player.global_position.distance_to(safe) < 24.0 and player.get_parent() == world.get_node("Entities"), "at the last safe spot by the hole")
	var fell_in := world.map.world_to_cell(safe) + Vector2i.RIGHT * 2
	check(def.seal_hole and not world.has_pit(fell_in) and world.is_solid_ground(world.map.cell_to_world(fell_in)) and not world.nav.is_blocked(fell_in), "the hole he fell through has closed behind him (no falling straight back in)")
	var sealed_saved: Array = world.spent_data().get("sealed", [])
	check(sealed_saved.has([fell_in.x, fell_in.y]), "the floor's save keeps the hole filled (%s)" % [sealed_saved])
	check(home.get("at", []) == frozen_at and home.get("hp", []) == hp_then, "the floor's monsters as they were (same place, same Health)")
	check(is_equal_approx(float(home.get("burn", -1.0)), burn_left), "their statuses too (%.2f s of burn left)" % float(home.get("burn", -1.0)))
	var floor_changes := _things_diff(floor_things, _floor_things(world, false))
	check(floor_changes.is_empty(), "nothing else came or went on the floor %s" % floor_changes)
	check(player.hp == hp_out, "his Health as he left the Deeps (%d)" % player.hp)
	check(player._invulnerable_time > 0.0, "with a moment of grace")
	check(torch.level == torch_level, "his torch burns as before")
	check(abyss.gifted and _gold_on_floor(world) > gold_before, "out quick: the dawn's gift at his feet")
	check(abyss.depths == null and not (game.hud.get_node("AbyssHud") as Control).visible and (game.hud.get_node("%Minimap") as Control).visible, "the Deeps are gone, the HUD is the floor's again")
	check(Profile.stat_value("abyss_escapes") >= 1, "it counts")
	await _frames(2)
	check(not is_instance_valid(depths), "the Deeps are freed")
	# Slow: no gift.
	await _walk_into_hole(world, player)
	var again_at := player.global_position
	var again := await _until_deeps(game)
	check(again, "down again (%s)" % _fall_state(game, again_at))
	if not again:
		_fill_holes()
		player.xp = xp_saved
		return
	abyss.time_in = def.quick_time_for(world.depth, CONTENT.dungeon) + 1.0
	for m in abyss.depths.get_hostiles(Actor.Faction.PLAYER):
		m.queue_free()
	await _frames(1)
	check(await _escape_deeps(game) and not abyss.gifted, "out slow: no gift")
	# A second life down there: the Threshold takes him from the Deeps and brings him back into them.
	var feather := _perk("phoenix_feather")
	player.perks.add(feather)
	await _walk_into_hole(world, player)
	var hole_at := player.global_position
	var down := await _until_deeps(game)
	check(down, "down again, a feather in hand (%s)" % _fall_state(game, hole_at))
	if not down:
		_fill_holes()
		player.perks.clear()
		player.xp = xp_saved
		return
	depths = abyss.depths
	depths.waves_on = false
	var stood := player.global_position
	_killing_blow(player)
	check(await _until_trial(game), "slain in the Deeps with a second life: the Threshold")
	check(not depths.is_inside_tree() and abyss.is_open() and game.threshold.limbo.is_ancestor_of(player), "the Deeps wait, out of the tree, while he is at the Threshold")
	check(not world.is_inside_tree(), "and his floor still waits")
	check(not abyss.can_take(player), "no Deeps from the Threshold")
	check(not (game.hud.get_node("AbyssHud/AbyssBanner") as Control).visible, "the Threshold's screen, not the Deeps'")
	check(await _win_trial(game), "the trial won")
	await _frames(1)
	check(player.world == depths and depths.is_inside_tree() and player.global_position == stood, "back into the Deeps, where he fell")
	check(abyss.is_searching() and not world.is_inside_tree(), "still down there, the floor still waiting")
	check((game.hud.get_node("AbyssHud/AbyssBanner") as Control).visible and not (game.hud.get_node("%Minimap") as Control).visible, "the Deeps' screen again")
	check(await _escape_deeps(game) and player.world == world and world.is_inside_tree(), "and out of the Deeps after")
	check((game.hud.get_node("%Minimap") as Control).visible and (game.hud.get_node("%BagButton") as Control).visible, "the floor's HUD whole again")
	for watcher in watchers:
		watcher.die(null)
	_fill_holes()
	await _test_sealed_hole_restored(world, player)
	await _test_collapsed_crack_restored(world, player)
	player.perks.clear()
	player.hp = player.get_max_hp()
	player.xp = xp_saved
	player.invincible = false
	await _frames(5)


## A run picked up again rebuilds its floor from the seed: the holes filled in before quitting
## (the Deeps' hole, which may have been cracked floor before it gave way) are filled again.
func _test_sealed_hole_restored(world: World, player: Player) -> void:
	var others: Array[Vector2] = []
	var hole := _open_cell_near(world, player.global_position, 3, others, world.map.tile_size * 3.0)
	others.append(world.map.cell_to_world(hole))
	var cracked := _open_cell_near(world, player.global_position, 3, others, world.map.tile_size * 3.0)
	var pit: PitDef = load("res://data/hazards/pit.tres")
	world.add_pit(hole, pit)
	_dug.append([world, hole])
	var crack := world.spawn_crumbling_floor(pit, cracked)
	world.holes.sealed_cells.clear()
	# As build_floor does on a saved floor (restore_spent): the holes and cracks are there again,
	# then what the save says is filled.
	var saved: Array = JSON.parse_string(JSON.stringify([[hole.x, hole.y], [cracked.x, cracked.y]]))  # (numbers as a save file reads them)
	world.floor_save.restore_sealed(saved)
	await _frames(1)
	check(not world.has_pit(hole) and not world.nav.is_blocked(hole) and world.is_solid_ground(world.map.cell_to_world(hole)), "a hole filled before quitting is filled again on the resumed floor")
	check(not is_instance_valid(crack) and world.holes.cracks.get(cracked) == null, "and the cracked floor it was before it gave way is solid floor")
	check(world.holes.sealed_cells.has(hole) and world.holes.sealed_cells.has(cracked), "kept for the next save too (%s)" % [world.holes.sealed_cells])
	world.floor_save.restore_sealed([[1.5], "x"])  # a damaged entry is skipped
	check(world.holes.sealed_cells.size() == 2, "a damaged entry fills nothing")


## Cracked floor that gave way (and that nobody fell through: no Deeps, no filling) is a hole
## again on the resumed floor, not the crack its seed lays again.
func _test_collapsed_crack_restored(world: World, player: Player) -> void:
	var crumbling: PitDef = load("res://data/hazards/crumbling_floor.tres")
	var others: Array[Vector2] = []
	var gave_way := _open_cell_near(world, player.global_position, 3, others, world.map.tile_size * 3.0)
	others.append(world.map.cell_to_world(gave_way))
	var again := _open_cell_near(world, player.global_position, 3, others, world.map.tile_size * 3.0)
	var first := world.spawn_crumbling_floor(crumbling, gave_way)
	world.holes.collapsed_cells.clear()
	first.collapse()
	_dug.append([world, gave_way])
	var saved_cells: Array = world.spent_data().get("collapsed", [])
	check(saved_cells.has([gave_way.x, gave_way.y]), "the floor's save keeps the cracked floor that gave way (%s)" % [saved_cells])
	# As build_floor does on a saved floor (restore_spent): the crack is laid again from the seed,
	# then what the save says gave way gives way.
	var crack := world.spawn_crumbling_floor(crumbling, again)
	var saved: Array = JSON.parse_string(JSON.stringify([[again.x, again.y], [1.5], "x"]))  # (as a save file reads them; damaged entries)
	world.floor_save.restore_collapsed(saved)
	_dug.append([world, again])
	await _frames(1)
	check(world.has_pit(again) and world.nav.is_blocked(again) and not world.is_solid_ground(world.map.cell_to_world(again)), "cracked floor that gave way before quitting is a hole on the resumed floor")
	check(not is_instance_valid(crack) and world.holes.cracks.get(again) == null, "and its crack is gone")
	check(world.holes.collapsed_cells.has(again), "kept for the next save too (%s)" % [world.holes.collapsed_cells])
	_fill_holes()


## A body put down on the floor never starts inside a wall's or a prop's shape (from inside one
## it may never get out): the monsters a floor puts down, and those put down near a spot later
## (summons, a trapped chest's, a split's, an encounter's: World.find_open_point_near()), even
## from a spot against a wall. On many generated floors; builds them on the game's world.
func _test_bodies_fit(game: Game) -> void:
	var world := game.world
	var player := game.player
	var rat: MonsterDef = load("res://data/monsters/rat.tres")
	var dune_rex: MonsterDef = load("res://data/monsters/dune_rex.tres")
	var monsters := 0
	var inside: Array[String] = []
	var points := 0
	var bad_points: Array[String] = []
	var rng := RandomNumberGenerator.new()
	for n in 12:
		var depth := 1 + n % (CONTENT.dungeon.total_floors() - 1)
		if CONTENT.dungeon.boss_for_depth(depth) != null:
			depth += 1
		world.rng.seed = hash("bodies-%d" % n)
		world.build_floor(depth, CONTENT)
		world.place_player(player)
		player.global_position = Vector2(-100000, -100000)  # far: nothing wakes, nothing moves
		await get_tree().physics_frame
		for monster in world.get_hostiles(Actor.Faction.PLAYER):
			monsters += 1
			if not world.body_fits(monster.global_position, monster.radius):
				inside.append("%s on floor %d at %s" % [monster.def.id, n, monster.global_position])
		var by_wall: Array[Vector2i] = []
		for y in world.map.height:
			for x in world.map.width:
				var cell := Vector2i(x, y)
				if world.is_free_cell(cell) and not world.map.is_floor(cell + Vector2i.UP):
					by_wall.append(cell)
		rng.seed = n
		for k in 30:
			if by_wall.is_empty():
				break
			var spot := world.map.cell_to_world(by_wall[rng.randi_range(0, by_wall.size() - 1)])
			for kind: MonsterDef in [rat, dune_rex]:
				var at := world.find_open_point_near(spot, [24.0, 40.0, 60.0][k % 3], WorldSpace.room_for(kind))
				points += 1
				if not world.is_solid_ground(at) or not world.body_fits(at, kind.radius):
					bad_points.append("%s near %s: %s" % [kind.id, spot, at])
	check(monsters > 100 and inside.is_empty(), "no monster a floor puts down starts inside a wall or a prop (%d monsters on 12 floors; inside: %s)" % [monsters, ", ".join(inside.slice(0, 3))])
	check(points > 300 and bad_points.is_empty(), "a body put down near a spot by a wall fits where it lands (%d points; inside: %s)" % [points, ", ".join(bad_points.slice(0, 3))])
	# And one put down there walks out: a rat by every wall it was put against.
	var stuck: Array[String] = []
	for k in 10:
		var cells: Array[Vector2i] = []
		for y in world.map.height:
			for x in world.map.width:
				if world.is_free_cell(Vector2i(x, y)) and not world.map.is_floor(Vector2i(x, y - 1)):
					cells.append(Vector2i(x, y))
		if cells.is_empty():
			break
		var spot := world.map.cell_to_world(cells[(k * 7919) % cells.size()])
		var rat_body := world.spawn_monster(rat, world.find_open_point_near(spot, 24.0, WorldSpace.room_for(rat)))
		rat_body.dormant = true
		await get_tree().physics_frame
		var start := rat_body.global_position
		var farthest := 0.0
		for way: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			rat_body.global_position = start
			for i in 10:
				rat_body.velocity = way * 60.0
				rat_body.move_and_slide()
			farthest = maxf(farthest, rat_body.global_position.distance_to(start))
		if farthest < 4.0:
			stuck.append(str(start))
		rat_body.queue_free()
	check(stuck.is_empty(), "a rat put down by a wall can walk away (stuck at %s)" % ", ".join(stuck))
	player.global_position = world.map.cell_to_world(world.map.start_cell)
	await _frames(2)


## Where the Deeps don't open: the hidden floor (its rule: climb out, hurt); boss floors are in
## BossTests. Every generated maze has a way to its door, holes or not.
func _test_abyss_rules(game: Game, world: World, player: Player) -> void:
	var abyss := game.abyss
	world.hidden_floor = CONTENT.dungeon.hidden_floor
	check(not abyss.can_take(player), "no Deeps on the hidden floor")
	world.hidden_floor = null
	check(abyss.can_take(player), "but on a plain floor, yes")
	# Many mazes, holes in them: the door can always be reached.
	var depths := (load("res://src/world/abyss_world.tscn") as PackedScene).instantiate() as AbyssWorld
	depths.difficulty = world.difficulty
	depths.boons = world.boons
	depths.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(depths)
	var blocked := []
	var holes := 0
	var wardens := 0
	for seed_value in 40:
		var depth := 1 + seed_value % CONTENT.dungeon.total_floors()
		depths.build_depths(depth, CONTENT, CONTENT.dungeon.abyss, seed_value * 7919 + 13)
		holes += 1 if depths.holes.pits.cells().size() > 0 else 0
		wardens += 1 if depths.warden != null else 0
		if depths.way_to_door().is_empty() or depths.map.start_cell == depths.map.stairs_cell:
			blocked.append(seed_value)
		check(depths.warden == null or CONTENT.dungeon.abyss.has_warden(depth, CONTENT.dungeon), "the warden only from its act on")
	check(blocked.is_empty(), "the Dawn Breach can be reached on every maze (40 seeds; blocked: %s)" % str(blocked))
	check(holes > 10, "most mazes have holes (%d of 40)" % holes)
	check(wardens > 0, "deep acts have the warden at the door (%d of 40)" % wardens)
	depths.queue_free()
	await _frames(2)


## Dying in the Deeps is dying: the run ends down there; a new run leaves them for good.
func _test_abyss_death(game: Game) -> void:
	game.start_run()
	await _frames(5)
	var player := game.player
	var world := game.world
	# A fall cut short by a new floor (the stairs or the debug panel while he drops): he stands
	# at the new floor's start; its old hole doesn't drag him away nor drop him into the Deeps.
	await _walk_into_hole(world, player)
	await _frames(3)
	check(player.is_falling, "the hero is falling into a hole")
	player.invincible = true  # (no knockback from a monster by the start while we wait)
	await game.debug.enter_floor(game.depth)
	_dug.clear()  # (that floor is gone: the hole with it)
	var start := world.map.cell_to_world(world.map.start_cell)
	await _frames(int(Actor.FALL_TIME * 60.0) + 10)
	check(not player.is_falling and not game.abyss.is_open() and player.world == game.world and world.is_inside_tree(), "a fall cut short by a new floor ends there: no Deeps under the new floor (falling %s, Deeps %s)" % [player.is_falling, game.abyss.is_open()])
	check(player.global_position.distance_to(start) < 4.0 and player.rig.scale == Vector2.ONE, "on his feet at the new floor's start (%d px away)" % roundi(player.global_position.distance_to(start)))
	player.invincible = false
	await _walk_into_hole(world, player)
	var hole_at := player.global_position
	var down := await _until_deeps(game)
	check(down, "down into the Deeps (%s)" % _fall_state(game, hole_at))
	if not down:
		_fill_holes()
		return
	var demon := game.abyss.depths.raise_demon()
	_killing_blow(player, demon)
	check(player.is_dead and player.world == game.abyss.depths, "slain in the Deeps (no second life): dead, down there")
	check(player.killed_by == demon.display_name, "of what slew him (%s)" % player.killed_by)
	await _until(func() -> bool: return game.game_over_panel.visible)  # (the end screen comes a moment after the blow, under the hit stop)
	check(game.game_over_panel.visible and not RunSave.exists(), "the run ends")
	game.start_run()
	await _frames(5)
	check(not game.abyss.is_open() and game.world.is_inside_tree() and game.player.world == game.world, "a new run: the Deeps are left behind, the floor is back")


func _test_forge(game: Game, world: World, player: Player) -> void:
	var worn := player.equipment.get_item(EquipmentDef.Slot.WEAPON)
	var ember: RuneDef = load("res://data/runes/ember.tres")
	var spark: RuneDef = load("res://data/runes/spark.tres")
	var bag := player.inventory.items.duplicate()  # an empty bag for the test (the bot's is put back)
	player.inventory.items.clear()
	player.inventory.add(ember)
	player.inventory.add(spark)
	var cell := world.map.world_to_cell(world.find_open_point_near(player.global_position + Vector2(90, 0), 40.0))
	var forge := world.spawn_forge(CONTENT.dungeon.forge, cell)
	await _frames(2)
	player.global_position = forge.global_position + Vector2(0, 30)
	await _frames(3)
	var panel := game.menus.forge
	var interact := game.hud.get_node("%InteractButton") as InteractButton
	check(not panel.visible and not get_tree().paused, "walking up to the smith opens nothing by itself")
	check(interact.visible and interact.caption == "Forge", "the Interact button shows by the smith: %s" % interact.caption)
	check(await _tap_interact(game) and panel.visible and get_tree().paused, "tapping it opens the forge")
	var sockets := worn.socket_count()
	check(sockets >= 1, "a weapon has rune sockets (%d)" % sockets)
	var embers := player.inventory.count_of(ember)  # (the bot may have found some already)
	check(panel.set_rune(ember), "a rune goes into the weapon")
	var worked := player.equipment.get_item(EquipmentDef.Slot.WEAPON)
	check(worked.runes.has(ember) and player.inventory.count_of(ember) == embers - 1, "it is set, and gone from the bag")
	check(worked == worn or worked.base_item == (worn.base_item if worn.is_rolled() else worn), "...in the same weapon (a plain one becomes its own copy)")
	check(worn.is_rolled() or worn.runes.is_empty(), "the plain weapon itself stays bare")
	var burns := false
	for entry in player.perks._gear:
		for passive in entry.granted:
			burns = burns or passive is BurnOnHitPassive
	check(burns, "its power works while worn")
	for i in worked.free_sockets():
		player.inventory.add(spark)
		panel.set_rune(spark)
	check(worked.free_sockets() == 0 and not panel.set_rune(spark), "no rune past the last socket")
	player.gold = 0
	var index := worked.runes.find(ember)
	panel._select_socket(index)
	check(not panel.take_rune(), "taking a rune out costs gold")
	var price := forge.removal_cost()
	player.gold = price + 5
	check(panel.take_rune() and player.inventory.items.has(ember) and not worked.runes.has(ember), "paid: the rune comes back out, intact")
	check(player.gold == 5, "for its price (%d)" % price)
	var saved := LootRoller.from_data(LootRoller.to_data(worked)) as EquipmentDef
	check(saved.runes == worked.runes, "set runes are saved with the weapon")
	panel.close()
	await _frames(2)
	check(not get_tree().paused, "the game goes on when the forge closes")
	player.inventory.items.assign(bag)
	player.inventory.changed.emit()
	forge.queue_free()
	# Runes drop.
	var before := get_tree().get_nodes_in_group("pickups").filter(func(p: Node) -> bool: return (p as ItemPickup).item is RuneDef).size()
	world.drop_rune(player.global_position + Vector2(40, 0))
	await _frames(2)
	var after := get_tree().get_nodes_in_group("pickups").filter(func(p: Node) -> bool: return (p as ItemPickup).item is RuneDef).size()
	check(after == before + 1, "runes drop as pickups")
	for node in get_tree().get_nodes_in_group("pickups"):
		if (node as ItemPickup).item is RuneDef:
			node.queue_free()
	await _frames(1)


## How fights feel: what monsters are made of, chips left behind, the camera's kick, slow motion.
func _test_feel(_game: Game, world: World, player: Player) -> void:
	var rat: MonsterDef = load("res://data/monsters/rat.tres")
	check(rat.material != null and rat.material.sound != null, "monsters are made of something that sounds")
	var chips := world.debris_count()
	var monster := world.spawn_monster(rat, world.map.cell_to_world(_open_cell_near(world, player.global_position + Vector2(60, 0), 1)))
	monster.dormant = true
	await _frames(1)
	var hit := HitInfo.new()
	hit.source = player
	hit.amount = 9999
	hit.knockback = Vector2(200, 0)
	var xp_kept := player.xp
	player.xp = -1000000  # no level up (and its pause) from this kill
	monster.take_hit(hit)
	await _frames(2)
	player.xp = xp_kept
	check(world.debris_count() > chips, "a slain monster leaves chips of itself (%d)" % (world.debris_count() - chips))
	HitStop.reset()
	player.camera.kick(Vector2.RIGHT, 6.0)
	check(player.camera.kick_offset().x > 0.0, "the camera leans with a blow")
	await _frames(30)
	check(player.camera.kick_offset() == Vector2.ZERO, "...and springs back")
	# A hit lands during physics: its freeze must hold on the next frames.
	await get_tree().physics_frame
	HitStop.freeze(0.1)
	await get_tree().process_frame
	await get_tree().process_frame
	check(Engine.time_scale < 1.0, "a freeze asked during physics holds")
	HitStop.reset()
	var wall_point := world.map.cell_to_world(Vector2i.ZERO)
	check(world.is_free_cell(world.map.world_to_cell(world.nearest_free_point(player.global_position))), "after a fall the hero climbs out on free floor")
	check(world.nearest_free_point(wall_point) != wall_point or not world.map.is_floor(Vector2i.ZERO), "...even when the ground gave way")
	# ...and clear of a body standing where he stood (a boss at the hole's edge would push him
	# back in: he fell again and again).
	var stander := world.get_hostiles(player.faction)
	var spot := world.nearest_free_point(player.global_position)
	if not stander.is_empty():
		var body: Actor = stander[0]
		var kept_at := body.global_position
		body.global_position = spot
		var on_spot: Array[Actor] = [body]
		var out := world.nearest_free_point(spot, 12, on_spot, player.radius + 2.0)
		check(out.distance_to(body.global_position) >= body.radius + player.radius + 2.0 and world.is_free_cell(world.map.world_to_cell(out)),
			"after a fall the hero climbs out clear of a body standing on his spot (%.0f px away)" % out.distance_to(body.global_position))
		body.global_position = kept_at
	HitStop.slow(0.2, 0.5)
	check(is_equal_approx(Engine.time_scale, 0.5), "a strong kill slows the world")
	HitStop.reset()
	check(Engine.time_scale == 1.0, "...for a moment")


## The screen pass in the game (docs/vfx.md, "Shaders"): one node reads the screen, the
## distortions of the frame are its stamps, the viewport carries the emissive mask, fewer effects
## drops the heavy passes, and every new effect runs a frame without errors.
func _test_screen_pass(_game: Game, world: World, player: Player) -> void:
	var screen := ScreenEffects.of(get_tree())
	check(screen != null and get_viewport().transparent_bg, "screen pass: there, and the viewport keeps the emissive mask (transparent)")
	var at := player.global_position
	Vfx.explosion(world, at + Vector2(60, 0), 60.0)
	Vfx.nova(world, at + Vector2(-60, 40), 50.0, VfxElementDef.named(&"fire"))
	Vfx.nova(world, at + Vector2(0, 60), 50.0, VfxElementDef.named(&"frost"))
	Vfx.nova(world, at + Vector2(0, -60), 40.0, VfxElementDef.named(&"poison"))
	Vfx.nova(world, at + Vector2(60, -60), 40.0, VfxElementDef.named(&"arcane"))
	Vfx.magic(world, at, Palette.GOLD)
	for path: String in ["smite", "thunder"]:
		var area := (load("res://data/skills/player/%s.tres" % path) as SkillDef).effects[0] as DamageAreaEffect
		world.spawn_vfx(SheetVfx.play(area.strike, at + Vector2(80, 20), Vector2.RIGHT, area.element))
	var flame := (load("res://src/vfx/flame_vfx.tscn") as PackedScene).instantiate() as FlameVfx
	flame.position = at + Vector2(-40, -40)
	world.spawn_vfx(flame)
	await _frames(2)
	var readers := 0
	for node in _all_nodes(get_tree().root):
		var item := node as CanvasItem
		if item and item.visible and item.material is ShaderMaterial and (item.material as ShaderMaterial).shader and (item.material as ShaderMaterial).shader.code.contains("hint_screen_texture"):
			readers += 1
	check(readers == 1, "screen pass: one node reads the screen in a busy frame (%d)" % readers)
	var stamps := screen.stamp_count()
	check(stamps >= 3 and stamps <= DistortionStamp.MAX, "screen pass: heat, cold and a shockwave are stamps of the one pass (%d)" % stamps)
	check(flame.material is ShaderMaterial and (flame.material as ShaderMaterial).shader == FxLook.FLAME, "flames lick (flame tongues)")
	check(flame.get_children().any(func(n: Node) -> bool: return n is GlowHalo) and flame.get_children().any(func(n: Node) -> bool: return n is DistortionStamp), "a brazier's flame glows and the air trembles above it")
	var fewer := Settings.fewer_effects
	Settings.set_option(&"fewer_effects", true)
	await _frames(1)
	var shocks := 0
	for node in get_tree().get_nodes_in_group(DistortionStamp.GROUP):
		if (node as DistortionStamp).kind == DistortionStamp.Kind.SHOCK and (node as DistortionStamp).is_visible_in_tree():
			shocks += 1
	check(screen.stamp_count() <= shocks and float((screen.material as ShaderMaterial).get_shader_parameter("bloom")) == 0.0, "fewer effects: no heat, cold or pull, no glow (shockwaves kept)")
	Settings.set_option(&"fewer_effects", fewer)
	flame.queue_free()
	await _frames(60)


static func _all_nodes(node: Node) -> Array[Node]:
	var found: Array[Node] = [node]
	for child in node.get_children():
		found.append_array(_all_nodes(child))
	return found


func _test_hazards(game: Game, world: World, player: Player) -> void:
	var pit: PitDef = load("res://data/hazards/pit.tres")
	var slime_def: MonsterDef = load("res://data/monsters/slime.tres")
	# Tough hero (hazards still do 1 damage), and the floor's own ambush out of the way.
	var defense_saved := player.base_stats.defense
	player.base_stats.defense = 999
	player.invalidate_stats()
	if world.ambush:
		world.ambush.queue_free()
		world.ambush = null
	player.hp = player.get_max_hp()
	var xp_saved := player.xp
	player.xp = -1000000  # no level up (and its pause) in the middle of this

	# A monster knocked into a hole is gone, and the hero gets the XP.
	var hole := _open_cell_near(world, player.global_position, 3)
	world.add_pit(hole, pit)
	check(world.has_pit(hole) and world.pit_under(world.map.cell_to_world(hole)) == pit, "a hole is a hole")
	check(world.pit_under(world.map.cell_to_world(hole) + Vector2(-14, 0)) == null, "the edge of a hole is forgiven")
	var slime := world.spawn_monster(slime_def, world.map.cell_to_world(hole + Vector2i.LEFT))
	slime.dormant = true
	slime.move_direction = Vector2.RIGHT
	check(slime.steering.avoid_holes(Vector2.RIGHT) != Vector2.RIGHT, "walking monsters don't step into holes")
	slime.move_direction = Vector2.ZERO
	var xp_before := player.xp
	var push := Combat.make_hit(1, 0.0, player)
	push.knockback = Vector2.RIGHT * 700.0
	slime.take_hit(push)
	await _frames(45)
	check(not is_instance_valid(slime) or slime.is_dead, "a monster knocked into a hole falls")
	check(player.xp > xp_before, "the hero gets the XP of what they pushed in")
	var bat := world.spawn_monster(load("res://data/monsters/bat.tres"), world.map.cell_to_world(hole))
	bat.dormant = true
	await _frames(40)
	check(is_instance_valid(bat) and not bat.is_dead and not bat.is_falling, "flying monsters don't fall")
	bat.queue_free()

	# The hero falls too: on a floor, down into the Deeps (Abyss; climbing out hurt is the rule
	# of boss floors, BossTests), hurt, and back up by the hole once out of them.
	var safe := world.map.cell_to_world(hole + Vector2i.LEFT * 2)
	player.global_position = safe
	await _frames(3)
	player._invulnerable_time = 0.0
	var hp_before := player.hp
	player.global_position = world.map.cell_to_world(hole)
	await _frames(3)
	check(player.is_falling, "the hero falls into a hole")
	await _frames(int(Actor.FALL_TIME * 60.0) + 6)
	check(game.abyss.is_open(), "a fall on a floor takes the hero down into the Deeps")
	check(await _until_deeps(game), "he lands in the Deeps")
	check(not player.is_falling and player.world == game.abyss.depths and player.rig.scale == Vector2.ONE, "on his feet, down there")
	check(player.hp < hp_before, "falling hurts")
	check(await _escape_deeps(game), "and he comes back up")
	check(player.world == world and player.global_position.distance_to(safe) < 24.0, "by the hole, where he stood")
	player.global_position = world.map.cell_to_world(hole)
	player.start_dash(Vector2.RIGHT * 10.0, 0.3, true)
	await _frames(5)
	check(not player.is_falling, "rolling carries you over a hole")
	player.global_position = safe
	await _frames(25)

	# Cracked floor gives way under your feet.
	var crumbling: PitDef = load("res://data/hazards/crumbling_floor.tres")
	var cracked := _open_cell_near(world, player.global_position, 2)
	var tile := world.spawn_crumbling_floor(crumbling, cracked)
	check(not world.is_solid_ground(world.map.cell_to_world(cracked)), "cracked floor is no safe ground")
	await _frames(30)
	check(not world.has_pit(cracked), "cracked floor holds while nobody is on it")
	player._invulnerable_time = 0.0
	player.global_position = world.map.cell_to_world(cracked)
	await _frames(int(crumbling.crumble_time * 60.0) + 4)
	check(world.has_pit(cracked) and not is_instance_valid(tile), "cracked floor gives way")
	await _frames(int(Actor.FALL_TIME * 60.0) + 10)
	check(game.abyss.is_open(), "and the hero falls through (into the Deeps)")
	check(await _until_deeps(game) and await _escape_deeps(game), "and back up")
	check(not player.is_falling and world.is_solid_ground(player.global_position), "on solid ground")
	player.hp = player.get_max_hp()
	_fill_holes(world, [hole, cracked] as Array[Vector2i])  # (no later test may fall in by chance)

	# Quicksand slows whoever wades in, then swallows them.
	var sand: QuicksandDef = load("res://data/hazards/quicksand.tres")
	var pool_cell := _open_cell_near(world, player.global_position, 2)
	var pool := world.spawn_quicksand(sand, Rect2i(pool_cell, Vector2i(2, 2)))
	var wader := world.spawn_monster(slime_def, pool.global_position)
	wader.dormant = true
	await _frames(5)
	check(wader.statuses.is_slowed(), "quicksand slows monsters down")
	var wader_hp := wader.hp
	var wading_at := wader.global_position
	for i in int((sand.sink_delay + 0.3) * 60.0):
		if is_instance_valid(wader):
			wader.global_position = wading_at  # (nudged out by a neighbour, it would stop sinking)
		await _frames(1)
	check(not is_instance_valid(wader) or wader.hp < wader_hp, "staying in quicksand hurts")
	var flyer := world.spawn_monster(load("res://data/monsters/bat.tres"), pool.global_position)
	flyer.dormant = true
	await _frames(5)
	check(not flyer.statuses.is_slowed(), "flying monsters skim over quicksand")
	for node: Node in [wader, flyer, pool]:
		if is_instance_valid(node):
			node.queue_free()

	# Arrow traps: the slit is in a wall, a plate shoots arrows across the room. Monsters set them off too.
	var arrows: ArrowTrapDef = load("res://data/hazards/arrow_trap.tres")
	var placed: Trap
	for room in world.map.rooms:
		var before := get_tree().get_nodes_in_group("traps")
		arrows.place(world, room, {})
		for node in get_tree().get_nodes_in_group("traps"):
			if not before.has(node):
				placed = node
		if placed:
			break
	check(placed != null and not world.map.is_floor(placed.launcher_cell) and placed.launcher_direction != Vector2.ZERO, "an arrow trap's slit is in a wall")
	if placed:
		placed.queue_free()
	# Nobody else around to step into the line of fire.
	await _clear_monsters(world)
	var plate_cell := _open_cell_near(world, player.global_position, 3)
	var arrow_trap := world.spawn_trap(arrows, plate_cell)
	arrow_trap.set_launcher(plate_cell + Vector2i.UP * 3, Vector2.DOWN)
	player.global_position = world.map.cell_to_world(plate_cell + Vector2i.RIGHT * 3)  # out of the line of fire
	var target := world.spawn_monster(slime_def, arrow_trap.global_position)
	target.dormant = true
	var target_hp := target.hp
	await _frames(int((arrows.warning_time + 0.2) * 60.0) + 40)
	check(not is_instance_valid(target) or target.hp < target_hp, "monsters on the plate get shot")
	if is_instance_valid(target):
		target.queue_free()
	arrow_trap.queue_free()

	# Chests spill items; trapped ones bite.
	var chest_def: ChestDef = CONTENT.dungeon.chest
	var bag_saved := player.inventory.items.duplicate()
	var chest_cell := _open_cell_near(world, player.global_position, 2)
	var chest := world.spawn_chest(chest_def, chest_cell, false)
	await _frames(2)
	check(not chest.is_open, "a chest stays shut until the hero comes")
	var loot_before := get_tree().get_nodes_in_group("pickups").size()
	# (Whatever the hero carries already: a potion over the carry cap would come as gold.)
	var carry_cap := CONTENT.dungeon.consumable_carry_cap
	CONTENT.dungeon.consumable_carry_cap = 99
	chest.open()
	CONTENT.dungeon.consumable_carry_cap = carry_cap
	await _frames(2)
	check(get_tree().get_nodes_in_group("pickups").size() > loot_before, "a chest gives items")
	var trap_cell := _open_cell_near(world, player.global_position, 2)
	var monsters_before := world.monster_count()
	var trapped := world.spawn_chest(chest_def, trap_cell, true)
	player.global_position = world.map.cell_to_world(trap_cell + Vector2i.DOWN)
	await _frames(4)
	check(trapped.is_open, "walking up to a chest opens it")
	check(trapped.is_open and (trapped._fuse >= 0.0 or world.monster_count() > monsters_before), "a trapped chest springs its trap")
	await _frames(int(chest_def.fuse_time * 60.0) + 5)
	for monster in world.get_hostiles(Actor.Faction.PLAYER):
		if monster.global_position.distance_to(trapped.global_position) < 90.0:
			monster.queue_free()
	player.hp = player.get_max_hp()
	player.inventory.items = bag_saved
	player.inventory.changed.emit()
	await _frames(2)

	# Elites: an affix, more HP, a name, bigger, and their perk works.
	var elite := world.spawn_monster(slime_def, world.map.cell_to_world(_open_cell_near(world, player.global_position, 1)))
	elite.dormant = true
	var base_hp := elite.get_max_hp()
	var base_damage := elite._damage_multiplier
	var vampiric: EliteAffixDef = load("res://data/elites/vampiric.tres")
	elite.make_elite(vampiric, CONTENT.dungeon)
	check(elite.is_elite() and elite.get_max_hp() == roundi(base_hp * CONTENT.dungeon.elite_rank.hp_multiplier_at(world.depth) * vampiric.hp_multiplier), "elites are tougher (the rank's health at this depth)")
	check(is_equal_approx(elite._damage_multiplier, base_damage * CONTENT.dungeon.elite_rank.damage_multiplier), "elites hit harder")
	# Rarer ranks: Epic (2 affixes), Legendary (3), Shiny (other colors, a treasure).
	var ranked: Array[Monster] = []
	for rank in CONTENT.dungeon.rare_ranks:
		var rare := world.spawn_monster(load("res://data/monsters/skeleton.tres"), world.map.cell_to_world(_open_cell_near(world, player.global_position, 1)))
		rare.dormant = true
		world.make_ranked(rare, rank)
		ranked.append(rare)
		var names := {}
		for affix in rare.affixes:
			names[affix] = true
		check(rare.rank == rank and rare.affixes.size() == rank.affixes and names.size() == rank.affixes, "%s: %d different affixes" % [rank.id, rank.affixes])
		check(rare.display_name.begins_with(rank.display_name) and rare.get_max_hp() > base_hp, "%s: its name and toughness (%s)" % [rank.id, rare.display_name])
		if rank.hue_shift > 0.0:
			var look := rare.rig.visual.material as ShaderMaterial
			check(is_equal_approx(float(look.get_shader_parameter("hue_shift")), rank.hue_shift), "a Shiny has other colors")
	var by_id := {}
	for rare in ranked:
		by_id[rare.rank.id] = rare.rank
	check(by_id[&"legendary"].hp_multiplier > by_id[&"epic"].hp_multiplier and by_id[&"legendary"].loot_quality > by_id[&"epic"].loot_quality, "a Legendary is tougher and richer than an Epic")
	var shiny_mob: Monster = ranked.filter(func(m: Monster) -> bool: return m.rank.shimmer)[0]
	Profile.shinies = {}
	var xp_kept := player.xp
	player.xp = -1000000  # no level up (and its pause) from this kill
	var shiny_kill := HitInfo.new()
	shiny_kill.amount = 999999
	shiny_kill.source = player
	shiny_mob.take_hit(shiny_kill)
	await _frames(2)
	check(Profile.has_shiny(&"skeleton"), "a Shiny slain joins the bestiary's collection")
	player.xp = xp_kept
	for rare in ranked:
		if is_instance_valid(rare) and not rare.is_dead:
			rare.queue_free()
	check(elite.display_name.begins_with("Vampiric") and elite.rig.scale.x > 1.0, "elites have a name and are bigger")
	elite.hp = 1
	elite.perks.on_hit_dealt(elite, player, HitInfo.new(), 10)
	check(elite.hp > 1, "vampiric elites heal when they hit")
	var explosive: Monster = world.spawn_monster(slime_def, world.map.cell_to_world(_open_cell_near(world, player.global_position, 2)))
	explosive.dormant = true
	explosive.make_elite(load("res://data/elites/explosive.tres"), CONTENT.dungeon)
	var neighbour := world.spawn_monster(slime_def, explosive.global_position + Vector2(20, 0))
	neighbour.dormant = true
	var neighbour_hp := neighbour.hp
	var items_before := get_tree().get_nodes_in_group("pickups").size()
	var guaranteed_drops: int = explosive.drops.bonus_drops
	explosive.take_hit(Combat.make_secondary_hit(player, 99999))
	await _frames(90)  # its fuse, and the slow motion of a strong kill
	check(not is_instance_valid(neighbour) or neighbour.hp < neighbour_hp, "explosive elites blow up when they die")
	# (The hero may pick some up meanwhile: no fewer items, and a guaranteed drop.)
	check(guaranteed_drops >= 1 and get_tree().get_nodes_in_group("pickups").size() >= items_before, "elites always drop loot")
	if is_instance_valid(elite):
		elite.queue_free()
	if is_instance_valid(neighbour):
		neighbour.queue_free()
	var chances := 0
	for i in 400:
		var rolled := world.spawn_monster(slime_def, world.find_open_point_near(player.global_position, 300.0))
		world.roll_elite(rolled)
		chances += 1 if rolled.is_elite() else 0
		rolled.free()
	check(chances > 0 and chances < 200, "some monsters roll to be elites (%d / 400)" % chances)

	# Ambush: walking in closes the exits, waves come (the last with an elite), clearing opens it.
	var room_index := -1
	for i in range(1, world.map.rooms.size()):
		var r := world.map.rooms[i]
		if r.size.x >= 7 and r.size.y >= 7 and (world.ambush == null or world.ambush.room != r) and not world.map.exit_cells().any(func(c: Vector2i) -> bool: return r.grow(1).has_point(c)):
			room_index = i
			break
	if room_index >= 0:
		var room := world.map.rooms[room_index]
		var started := [0]
		var on_start := func(_r: AmbushRoom) -> void: started[0] += 1
		Events.ambush_started.connect(on_start)
		var ambush := world.spawn_ambush(room)
		var elites_seen := [0]
		var on_kill := func(m: Monster) -> void: elites_seen[0] += 1 if m.is_elite() else 0
		Events.monster_killed.connect(on_kill)
		player.global_position = _solid_point_in(world, room.grow(-2))
		await _frames(3)
		check(ambush.state == AmbushRoom.State.FIGHTING and ambush.is_closed() and started[0] == 1, "walking into an ambush closes the exits")
		check(game.hud._depth_banner.text == "Ambush!", "the HUD announces the ambush")
		for frame in 60 * 20:
			if ambush.state == AmbushRoom.State.CLEARED:
				break
			for monster in world.get_hostiles(Actor.Faction.PLAYER):
				if room.grow(1).has_point(world.map.world_to_cell(monster.global_position)) and not monster.is_falling:
					monster.take_hit(Combat.make_secondary_hit(player, 99999))
			await get_tree().physics_frame
		check(ambush.state == AmbushRoom.State.CLEARED and not ambush.is_closed(), "clearing the waves opens the exits")
		check(elites_seen[0] >= 1, "the last wave is led by an elite")
		var reward := get_tree().get_nodes_in_group("chests").filter(func(c: Node) -> bool: return (c as Chest).def == CONTENT.dungeon.ambush_chest and room.has_point(world.map.world_to_cell(c.global_position)))
		check(reward.size() == 1 and (reward[0] as Chest).def == CONTENT.dungeon.ambush_chest, "a big chest rewards the survivor (%d there, %d chests)" % [reward.size(), get_tree().get_nodes_in_group("chests").size()])
		# Saved cleared (World._ambush_data): a resumed floor's ambush, laid again by the seed, stays
		# cleared, its chest back where it was; walking in sets off no second fight.
		var saved_ambush: Dictionary = JSON.parse_string(JSON.stringify(world.floor_save.ambush_data()))
		var reward_at := world.map.world_to_cell((reward[0] as Chest).global_position) if reward.size() == 1 else Vector2i(-9, -9)
		check(saved_ambush.get("cleared", false) == true, "the floor's save keeps the ambush cleared (%s)" % [saved_ambush])
		for laid: Node in reward:
			laid.free()
		world.spawn_ambush(room)
		world.floor_save.restore_ambush(saved_ambush)
		var again := world.ambush
		var chests_again := get_tree().get_nodes_in_group("chests").filter(func(c: Node) -> bool: return (c as Chest).def == CONTENT.dungeon.ambush_chest and world.map.world_to_cell(c.global_position) == reward_at)
		check(again.state == AmbushRoom.State.CLEARED and not again.is_closed() and chests_again.size() == 1, "resumed, a cleared ambush stays cleared, its chest there again")
		await _frames(3)
		check(again.state == AmbushRoom.State.CLEARED and started[0] == 1, "...and walking in sets off no second fight (no second reward)")
		Events.ambush_started.disconnect(on_start)
		Events.monster_killed.disconnect(on_kill)

	# Real floors: hazards everywhere, but the stairs can always be reached.
	CONTENT.dungeon.merchant_chance = 1.0
	CONTENT.dungeon.encounters_max = 2
	CONTENT.dungeon.encounters_min = 2
	var merchants := 0
	var encounters := 0
	var hazard_total := 0
	for depth in [1, 2, 4, 5, 7, 8]:
		world.build_floor(depth, CONTENT)
		merchants += get_tree().get_nodes_in_group("merchants").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size()
		encounters += get_tree().get_nodes_in_group("encounters").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size()
		var start := world.map.cell_to_world(world.map.start_cell)
		check(not world.find_path(start, world.map.cell_to_world(world.map.stairs_cell)).is_empty(), "depth %d: the stairs can be reached" % depth)
		var count := get_tree().get_nodes_in_group("traps").size() + get_tree().get_nodes_in_group("crumbling_floors").size() \
			+ get_tree().get_nodes_in_group("quicksand").size() + world.holes.pits.cells().size()
		hazard_total += count
	check(hazard_total >= 12, "floors have hazards (%d on 6 floors)" % hazard_total)
	check(merchants >= 4 and encounters >= 6, "floors get merchants and encounters (%d, %d)" % [merchants, encounters])
	CONTENT.dungeon.merchant_chance = 0.0
	CONTENT.dungeon.encounters_max = 0
	CONTENT.dungeon.encounters_min = 0
	world.build_floor(game.depth, CONTENT)
	world.place_player(player)
	player.base_stats.defense = defense_saved
	player.invalidate_stats()
	player.hp = player.get_max_hp()
	player.xp = xp_saved
	await _frames(5)


## A new act begins with its title card, on black, game paused. A tap skips it.
func _test_act_card(game: Game) -> void:
	game.show_act_cards = true
	game.depth = 3  # _descend goes one floor down: the first floor of act II
	game._descend(game.session.capture())
	await _frames(int(game.FADE_TIME * 60.0) + 40)
	var card: ActCard = game.act_card
	var act: ActDef = CONTENT.dungeon.act_for_depth(4)
	check(card.visible and (card.get_node("%Title") as Label).text == act.title, "a new act shows its card")
	check((card.get_node("%Lore") as Label).text == act.lore and get_tree().paused, "with its story, game paused")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	Input.parse_input_event(tap)
	await _frames(int(ActCard.FADE_TIME * 60.0) + 10)
	check(not card.visible and not get_tree().paused, "a tap skips the card")
	game.show_act_cards = false
	await _frames(20)


## Kills set souls free: they fly into the hero's lantern and the HUD counts them.
func _test_souls(game: Game) -> void:
	var world: World = game.world
	var player: Player = game.player
	player.xp = -1000000  # no level up (and its pause) from this kill
	var monster := world.spawn_monster(load("res://data/monsters/slime.tres"), world.find_open_point_near(player.global_position, 100.0))
	monster.dormant = true
	var gathered := [0]
	var on_soul := func() -> void: gathered[0] += 1
	Events.soul_gathered.connect(on_soul)
	monster.take_hit(Combat.make_secondary_hit(player, 99999))
	await _frames(2)
	check(world.get_node("Effects").get_children().any(func(n: Node) -> bool: return n is SoulWisp), "a kill sets a soul free")
	await _frames(90)
	check(gathered[0] >= 1, "the soul reaches the hero's lantern")
	var shown := int((game.hud.get_node("%SoulsLabel") as Label).text.trim_prefix("Souls "))
	# (A kill is a share of a soul, DungeonConfig.souls_per_kill: the HUD shows the run's whole souls.)
	check(game.run.kills >= 1 and shown == game.run_souls(), "the HUD counts the run's souls (%d shown, %d)" % [shown, game.run_souls()])
	Events.soul_gathered.disconnect(on_soul)


## A floor's stairs stay sealed until enough of its monsters are slain; then a light runs to
## them and the minimap shows them.
func _test_stairs_seal(game: Game) -> void:
	await game.debug.enter_floor(2)
	await _frames(3)
	var world: World = game.world
	var player: Player = game.player
	var seal := world.seal
	var monsters := world.monster_count()
	check(seal.is_sealed() and seal.needed == ceili(monsters * CONTENT.dungeon.seal_share), "a new floor's stairs are sealed (%d of %d monsters)" % [seal.needed, monsters])
	var label: Label = game.hud.get_node("%SealLabel")
	check(label.visible and label.text.ends_with("0 / %d" % seal.needed), "the HUD shows what the seal wants (%s)" % label.text)
	var logged: Array[String] = []
	var on_log := func(text: String, _color: Color) -> void: logged.append(text)
	Events.message_logged.connect(on_log)
	var depth := game.depth
	world._blocked_note_at = -10.0  # (the bot may have bumped into them a moment ago: no repeat then)
	player.global_position = world.map.cell_to_world(world.map.stairs_cell)
	await _frames(int(game.FADE_TIME * 60.0) + 12)
	check(game.depth == depth and not game._transitioning, "sealed stairs don't lead down")
	check(logged.any(func(text: String) -> bool: return text.contains("Slay %d more" % seal.needed)), "stepping on them says what is missing (%s)" % str(logged))
	player.global_position = world.map.cell_to_world(world.map.start_cell)
	await _frames(3)

	player.xp = -1000000  # no level up (and its pause) from these kills
	while seal.left() > seal.reveal_left:
		_kill_one(world, player)
		await _frames(1)
	check(seal.reveals_monsters(), "the last kills show the monsters left on the minimap")
	check(label.text.ends_with("%d / %d" % [seal.kills, seal.needed]), "the HUD counts the kills")
	while seal.is_sealed() and world.monster_count() > 0:
		_kill_one(world, player)
		await _frames(1)
	check(not seal.is_sealed(), "enough kills break the seal")
	check(label.text == "Stairs open", "the HUD says the stairs are open")
	check(world.get_node("Effects").get_children().any(func(n: Node) -> bool: return n is GuideWisp), "a guiding light runs to the stairs")
	Events.message_logged.disconnect(on_log)


## A run picked up again rebuilds its floor from the seed: the floor's own monsters slain before
## quitting stay slain (World.spent_data() "slain"), the others come back, the hurt ones with the
## share of their Health they had ("wounded"); what came later and still stands (a summons, a
## trapped chest's, a split) comes back where it stood, its rank, affixes and Health kept
## ("later"). Ends with a fresh run on floor 1 (resume_run makes a new hero: callers fetch
## game.player again).
func _test_slain_stay_dead(game: Game) -> void:
	game.start_run()
	await _frames(5)
	var world: World = game.world
	var player: Player = game.player
	player.invincible = true
	player.xp = -1000000  # no level up (and its pause) from these kills
	var own := world.get_hostiles(Actor.Faction.PLAYER).filter(func(m: Actor) -> bool: return m is Monster and (m as Monster).floor_index >= 0)
	var all_before := world.monster_count()
	check(own.size() == all_before and own.size() >= 4, "every monster a new floor puts down has its number (%d of %d)" % [own.size(), all_before])
	var indexes := own.map(func(m: Actor) -> int: return (m as Monster).floor_index)
	indexes.sort()
	check(indexes == range(own.size()), "numbered in order, once each (%s)" % [indexes])
	var slain: Array[int] = []
	var slain_ids: Array[String] = []
	for monster: Monster in [own[0], own[int(own.size() / 2.0)], own[own.size() - 1]]:
		slain.append(monster.floor_index)
		slain_ids.append(String(monster.def.id))
		monster.take_hit(Combat.make_secondary_hit(player, 99999))
	var rat: MonsterDef = load("res://data/monsters/rat.tres")
	var later := world.spawn_monster(rat, world.find_open_point_near(player.global_position + Vector2(200, 0), 80.0))
	later.take_hit(Combat.make_secondary_hit(player, 99999))
	# One of the floor's own hurt (40% left), one that came later still standing: an elite, hurt.
	var hurt: Monster = own[1]
	for other: Monster in own:
		other.dormant = true  # (nobody moves off or fights until the save: the numbers stay put)
	hurt.hp = roundi(hurt.get_max_hp() * 0.4)
	var hurt_index := hurt.floor_index
	var stayer := world.spawn_monster(rat, world.find_open_point_near(player.global_position + Vector2(-220, 0), 60.0))
	stayer.dormant = true
	world.make_elite(stayer)
	stayer.summoned = true
	stayer.hp = roundi(stayer.get_max_hp() * 0.5)
	var stayer_at := stayer.global_position
	var stayer_affixes: Array = stayer.affixes.map(func(a: EliteAffixDef) -> StringName: return a.id)
	await _frames(2)
	var hurt_share := float(hurt.hp) / hurt.get_max_hp()
	var stayer_share := float(stayer.hp) / stayer.get_max_hp()
	var kills := world.seal.kills
	var before_save := world.spent_data()
	var saved: Array = before_save.get("slain", [])
	# (Summons the floor's own made meanwhile came later too: they come back as well.)
	var later_count := (before_save.get("later", []) as Array).size()
	var wounded_saved: Array = (before_save.get("wounded", []) as Array).filter(func(entry: Array) -> bool: return int(entry[0]) == hurt_index)
	check(later_count >= 1 and wounded_saved.size() == 1 and absf(float(wounded_saved[0][2]) - hurt_share) < 0.01, "the floor's save keeps the hurt one's share of Health and those that came later (%s, %d later)" % [wounded_saved, later_count])
	check(saved.size() == 3 and slain.all(func(i: int) -> bool: return saved.any(func(pair: Array) -> bool: return pair[0] == i)), "the floor's save keeps the floor's monsters slain, not the one that came later (%s)" % [saved])
	game._save_run()
	game.resume_run(RunSave.read())
	await _frames(3)
	world = game.world
	var back: Array[int] = []
	var kinds := {}
	for node in world.get_node("Entities").get_children():
		var monster := node as Monster
		if monster and monster.floor_index >= 0 and not monster.is_queued_for_deletion():
			back.append(monster.floor_index)
			kinds[monster.floor_index] = String(monster.def.id)
	check(not slain.any(func(i: int) -> bool: return back.has(i)), "resumed, the slain don't stand up again (%s among %s)" % [slain, back])
	check(back.size() == all_before - 3 and world.monster_count() == all_before - 3 + later_count, "and the others are all back, with those that came later (%d of %d, %d monsters, %d later)" % [back.size(), all_before - 3, world.monster_count(), later_count])
	var saved_share: float = float(wounded_saved[0][2]) if wounded_saved.size() == 1 else -1.0
	var hurt_back: Array = world.get_node("Entities").get_children().filter(func(n: Node) -> bool: return n is Monster and (n as Monster).floor_index == hurt_index)
	check(hurt_back.size() == 1 and (hurt_back[0] as Monster).hp == clampi(ceili((hurt_back[0] as Monster).get_max_hp() * saved_share), 1, (hurt_back[0] as Monster).get_max_hp()), "a monster hurt before quitting is hurt again (%.0f%% of its Health; %s)" % [100.0 * saved_share, hurt_back.map(func(m: Monster) -> String: return "%s %d/%d" % [m.def.id, m.hp, m.get_max_hp()])])
	var came_back: Array = world.get_node("Entities").get_children().filter(func(n: Node) -> bool: return n is Monster and (n as Monster).floor_index < 0 and (n as Monster).def == rat and (n as Monster).global_position.distance_to(stayer_at) < 40.0)
	var stayer_back: Monster = came_back[0] if came_back.size() == 1 else null
	check(stayer_back != null and stayer_back.global_position.distance_to(stayer_at) < 40.0, "one that came later and still stood is back where it stood (%d found)" % came_back.size())
	if stayer_back:
		check(stayer_back.is_elite() and stayer_back.affixes.map(func(a: EliteAffixDef) -> StringName: return a.id) == stayer_affixes and stayer_back.summoned, "with its rank, its affixes, and called in (it gives nothing)")
		check(absf(float(stayer_back.hp) / stayer_back.get_max_hp() - stayer_share) < 0.02, "and its Health (%.0f%%)" % (100.0 * stayer_share))
	var spent := world.spent_data()
	check((spent.get("later", []) as Array).size() == later_count and (spent.get("wounded", []) as Array).any(func(entry: Array) -> bool: return int(entry[0]) == hurt_index), "kept for the next save too")
	# Damaged or unknown entries are skipped.
	var count_now := world.monster_count()
	world.floor_save.restore_wounded(JSON.parse_string(JSON.stringify([[hurt_index], "x", [1.5, "rat", "a"]])))
	world.floor_save.restore_later(JSON.parse_string(JSON.stringify([{ "def": "res://data/monsters/nothing.tres", "id": "nothing", "at": [0, 0] }, { "def": rat.resource_path, "id": "skeleton", "at": [0, 0] }, { "def": "user://x.tres", "id": "rat", "at": [0, 0] }, "x", { "def": rat.resource_path, "id": "rat" }])))
	check(world.monster_count() == count_now, "a saved monster the game no longer has, of another kind, or damaged, doesn't come back")
	check(world.seal.kills == kills and world.seal.needed == ceili(all_before * CONTENT.dungeon.seal_share), "the seal counts the kills as before, of the whole floor (%d / %d)" % [world.seal.kills, world.seal.needed])
	check(world.floor_save.slain.size() == 3, "the slain kept for the next save too (%s)" % [world.floor_save.slain])
	# A number that came out as another kind of monster (a floor not rebuilt quite the same):
	# that one stays rather than the wrong one going. Damaged entries are skipped.
	var standing: int = back[0]
	var other_kind := "rat" if kinds[standing] != "rat" else "skeleton"
	world.floor_save.restore_slain(JSON.parse_string(JSON.stringify([[standing, other_kind], [1.5], "x", ["a", "rat"]])))
	check(world.monster_count() == all_before - 3 + later_count, "a saved number of another kind takes no monster away (%d)" % world.monster_count())
	game.player.invincible = false


## Two ways down: each stairs leads to a different world of the next floor (FloorRoute), its sign
## says which; the way taken builds the next floor and is kept in the save.
func _test_routes(game: Game) -> void:
	game.run.routes.clear()
	await game.debug.enter_floor(1)
	await _frames(3)
	var world: World = game.world
	var player: Player = game.player
	check(world.next_routes.size() == 2, "floor 1 offers two ways down (%d)" % world.next_routes.size())
	if world.next_routes.size() < 2:
		return
	check(world.next_routes[0].biome != world.next_routes[1].biome, "to two different worlds")
	check(world.map.second_stairs_cell != DungeonMap.NO_CELL and world.stairs_cells.size() == 2, "two stairs on the floor")
	var stairs := world.get_node("Entities").get_children().filter(func(n: Node) -> bool: return n is Stairs)
	check(stairs.size() == 2 and stairs.all(func(n: Node) -> bool: return (n as Stairs).route != null and n.get_children().any(func(c: Node) -> bool: return c is StairsSign)), "each with its sign")
	var again := FloorRoute.offer(CONTENT, 2, game.difficulty, game.run.route_seed(2))
	check(again.size() == 2 and again[1].biome == world.next_routes[1].biome and again[1].curse == world.next_routes[1].curse and again[1].floor_event == world.next_routes[1].floor_event, "the same run offers the same ways")
	var wanted: FloorRoute = world.next_routes[1]
	player.xp = -1000000
	while world.seal.is_sealed() and world.monster_count() > 0:
		_kill_one(world, player)
		await _frames(1)
	await _frames(2)
	player.global_position = world.map.cell_to_world(world.map.second_stairs_cell)
	for i in 600:
		await _frames(1)
		if game.depth == 2 and not game._transitioning:
			break
	check(game.depth == 2 and int(game.run.routes.get(2, -1)) == 1, "the second stairs lead down the second way")
	world = game.world
	check(world.biome == wanted.biome and world.curse == wanted.curse and world.floor_event == wanted.floor_event, "floor 2 is what its sign said (%s)" % wanted.summary())
	check(world.next_routes.is_empty() and world.stairs_cells.size() == 1, "before a boss: one way only")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_data()))
	var back := RunState.create(CONTENT, saved, RandomNumberGenerator.new())
	check(int(back.routes.get(2, -1)) == 1, "the way taken is kept in the save")
	check(game._route_to(2).biome == wanted.biome, "and a resumed run rebuilds the same floor")


## The Tree of Souls in a run: Regeneration, the Cartographer, the Trophy Hunter, the merchant.
func _test_soul_tree_run(game: Game) -> void:
	var saved_levels := Profile.levels.duplicate()
	Profile.levels = { "regeneration": 2, "cartographer": 1, "trophy_hunter": 1, "haggler": 1, "full_stalls": 1 }
	var boons := RunBoons.build(CONTENT)
	game.world.boons = boons
	await game.debug.enter_floor(2)
	await _frames(3)
	var world: World = game.world
	var player: Player = game.player
	check(world.stairs_cells.all(func(c: Vector2i) -> bool: return world.is_explored(c)), "Cartographer: the stairs are on the minimap from the start")
	player.hp = 10
	world.reward_clear()
	check(player.hp == 10 + roundi(player.get_max_hp() * 0.1) or player.hp == player.get_max_hp(), "Regeneration: a floor won heals 10%% at level 2 (%d)" % player.hp)
	var count_gear := func() -> int:
		return world.get_node("Entities").get_children().filter(func(n: Node) -> bool:
			return n is ItemPickup and (n as ItemPickup).item is EquipmentDef and ((n as ItemPickup).item as EquipmentDef).rarity >= ItemRarity.MAGIC).size()
	var before: int = count_gear.call()
	var elite := world.spawn_monster(load("res://data/monsters/rat.tres"), world.find_open_point_near(player.global_position + Vector2(90, 0), 40.0))
	elite.make_elite(CONTENT.elite_affixes[0], CONTENT.dungeon)
	elite.dormant = true
	await _frames(1)
	elite.take_hit(Combat.make_secondary_hit(player, 99999))
	await _frames(3)
	check(count_gear.call() > before, "Trophy Hunter: an elite drops Magic gear")
	var merchant := world.spawn_merchant(CONTENT.dungeon.merchant, world.map.world_to_cell(player.global_position) + Vector2i(3, 0))
	await _frames(1)
	var equipment := merchant.stock.filter(func(e: Dictionary) -> bool: return e.item is EquipmentDef)
	check(equipment.size() == CONTENT.dungeon.merchant.equipment_count + 2, "Full Stalls: two more pieces for sale (%d)" % equipment.size())
	var full_price := CONTENT.dungeon.merchant.buy_price(equipment[0].item, world.depth, world.rules.shop_prices())
	check(int(equipment[0].price) < full_price, "Haggler: lower prices (%d < %d)" % [int(equipment[0].price), full_price])
	merchant.queue_free()
	Profile.levels = saved_levels
	game.world.boons = RunBoons.new()
	await _clear_monsters(world)


## A status shows on the body: flames on a burning monster, its ticks in the fire's color.
func _test_status_looks(game: Game) -> void:
	var world: World = game.world
	# Only the test gives it statuses: in view (a monster off screen sleeps), away from the floor's
	# fires, ponds, sand and traps, and nothing strikes back for a hero hit nearby (thorns, a
	# retaliating perk would reach it).
	var invincible := game.player.invincible
	game.player.invincible = true
	var rat := world.spawn_monster(load("res://data/monsters/rat.tres"), _quiet_point(world, game.player.global_position, 2, 5))
	rat.dormant = true
	rat.base_stats.max_hp = 9999
	rat.invalidate_stats()
	rat.hp = 9999
	rat.statuses.clear()  # (the floor may have slowed it: quicksand, the cold)
	await _frames(2)
	var statuses_of := func() -> String:
		return "dots %s, slows %s" % [rat.statuses._dots.map(func(d: StatusSet.Dot) -> String: return "%s from %s" % [d.id, String(d.source.name) if is_instance_valid(d.source) else "?"]), rat.statuses._slows.keys()]
	check(rat.status_fx != null and not rat.status_fx.visible, "a body with no status shows nothing over it (%s)" % statuses_of.call())
	rat.statuses.apply_slow(0.5, 1.0, StatusSet.GROUND_SLOW)
	check(not rat.statuses.active_ids().has(&"slow"), "sinking in quicksand is no frost to show (%s)" % statuses_of.call())
	rat.statuses.clear()
	var colors: Array[Color] = []
	var on_text := func(text: Node) -> void:
		if text is FloatingText:
			colors.append((text as FloatingText)._color)
	world.get_node("Effects").child_entered_tree.connect(on_text)
	rat.statuses.apply_dot(&"burn", 2, 0.5, 3.0, game.player, Palette.FIRE)
	await _frames(45)
	check(rat.status_fx.visible and rat.status_fx._bits.size() > 0, "a burning monster is on fire (%d flames)" % rat.status_fx._bits.size())
	var burn: StatusLookDef = StatusFx.LOOKS.look(&"burn")
	check(burn != null and StatusFx.LOOKS.look(&"poison") != null and StatusFx.LOOKS.look(&"slow") != null, "burn, poison and frost each have a look")
	check(colors.has(Palette.FIRE), "its burn damage shows in the fire's color")
	world.get_node("Effects").child_entered_tree.disconnect(on_text)
	# The body shader paints the burn on the body itself (no flat orange wash); fewer effects
	# turns it off and the old tint comes back.
	var fewer := Settings.fewer_effects
	Settings.fewer_effects = false
	await _frames(2)
	var body := rat.rig.visual.material as ShaderMaterial
	check(float(body.get_shader_parameter("burn")) > 0.0 and rat.rig.modulate == Color.WHITE, "a burning body is painted by the body shader, not tinted (burn %.2f, modulate %s, telegraph %.2f, %s)" % [float(body.get_shader_parameter("burn")), rat.rig.modulate, rat.telegraph, statuses_of.call()])
	Settings.fewer_effects = true
	await _frames(2)
	check(float(body.get_shader_parameter("burn")) == 0.0 and rat.rig.modulate != Color.WHITE, "with fewer effects the burn is a plain tint")
	Settings.fewer_effects = fewer
	for frame in 180:  # (the last embers live about a second; a brazier nearby may light it again)
		rat.statuses.clear()
		if not rat.status_fx.visible and not rat.status_fx.is_processing():
			break
		await _frames(1)
	check(not rat.status_fx.visible and not rat.status_fx.is_processing(), "the fire out, the flames die down and it sleeps again (%d bits left)" % rat.status_fx._bits.size())
	if not Settings.fewer_effects:
		check(float((rat.rig.visual.material as ShaderMaterial).get_shader_parameter("burn")) == 0.0, "the fire out, the body shader lets go of it")
	rat.queue_free()
	game.player.invincible = invincible
	await _test_element_deaths(game)


## A body dies in the element that killed it: a frost kill freezes it and breaks it into pieces,
## a burn's last tick burns it to ash; it is gone all the same.
func _test_element_deaths(game: Game) -> void:
	var world: World = game.world
	var at := world.find_open_point_near(game.player.global_position + Vector2(-80, 0), 40.0)
	var frozen := world.spawn_monster(load("res://data/monsters/rat.tres"), at)
	frozen.dormant = true
	await _frames(2)
	var shards := []
	var on_vfx := func(node: Node) -> void:
		if node is DeathPiecesVfx:
			shards.append(node)
	world.get_node("Effects").child_entered_tree.connect(on_vfx)
	var hit := Combat.make_secondary_hit(null, 99999)
	hit.element = VfxElementDef.named(&"frost")
	frozen.take_hit(hit)
	var look := frozen.rig.visual.material as ShaderMaterial
	check(int(look.get_shader_parameter("death_style")) == DeathLookDef.Style.SHATTER, "a frost kill freezes the body")
	for i in 120:
		if not is_instance_valid(frozen):
			break
		await _frames(1)
	world.get_node("Effects").child_entered_tree.disconnect(on_vfx)
	check(not is_instance_valid(frozen), "...and it is gone")
	check(shards.size() >= 1, "...broken into pieces of ice")
	var burnt := world.spawn_monster(load("res://data/monsters/rat.tres"), at)
	burnt.dormant = true
	await _frames(2)
	burnt.hp = 1
	burnt.statuses.apply_dot(&"burn", 5, 0.05, 1.0, null, Palette.FIRE)
	for i in 30:
		if burnt.is_dead:
			break
		await _frames(1)
	check(burnt.is_dead and burnt.killing_element() == VfxElementDef.named(&"fire") and int((burnt.rig.visual.material as ShaderMaterial).get_shader_parameter("death_style")) == DeathLookDef.Style.ASH, "burnt to death, it goes to ash")
	for i in 120:
		if not is_instance_valid(burnt):
			break
		await _frames(1)


func _kill_one(world: World, player: Player) -> void:
	for monster: Actor in world.get_hostiles(Actor.Faction.PLAYER):
		if not monster.is_dead:
			monster.take_hit(Combat.make_secondary_hit(player, 99999))
			return


## Pause menu, options, vibrations (no-op here), the minimap and the back button.
func _test_comfort(game: Game) -> void:
	var world: World = game.world
	var hud: Hud = game.hud
	(hud.get_node("%PauseButton") as Button).pressed.emit()
	await _frames(1)
	var pause: PauseMenu = game.pause_menu
	check(pause.visible and get_tree().paused, "the pause button pauses the game")
	# The bestiary from the pause menu: a page and its attack preview run while paused.
	(pause.get_node("%BestiaryButton") as Button).pressed.emit()
	var paused_codex: CodexPanel = pause.get_node("%CodexPanel")
	check(paused_codex.visible, "the bestiary opens from the pause menu")
	Profile.record_kill(&"skeleton")
	paused_codex.open_monster(load("res://data/monsters/skeleton.tres"))
	await _frames(3)
	var preview: AttackPreview = null
	var stack: Array[Node] = [paused_codex]
	while not stack.is_empty() and preview == null:
		var node: Node = stack.pop_back()
		if node is AttackPreview:
			preview = node
		stack.append_array(node.get_children())
	var before_time: float = preview._time if preview else 0.0
	await _frames(20)
	check(preview != null and preview._time > before_time, "the attack preview plays while the game is paused")
	game._back()
	game._back()
	check(not paused_codex.visible and pause.visible, "back closes the page, then the bestiary")
	(pause.get_node("%OptionsButton") as Button).pressed.emit()
	var options: OptionsPanel = pause.get_node("%OptionsPanel")
	check(options.visible, "options open from the pause menu")
	(options.get_node("%MusicSlider") as HSlider).value = 0.5
	check(is_equal_approx(Settings.music_volume, 0.5) and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")) - (linear_to_db(0.5) + Sfx.mix.gain_db(&"Music"))) < 0.01, "the music slider sets the music volume (on top of its trim in the mix)")
	(options.get_node("%CombatSlider") as HSlider).value = 0.5
	var combat_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Combat"))
	check(is_equal_approx(Settings.combat_volume, 0.5) and absf(combat_db - linear_to_db(0.5) - Sfx.mix.gain_db(&"Combat")) < 0.01 and is_equal_approx(Settings.ui_volume, 1.0), "the combat slider sets the combat bus alone")
	Settings.set_option(&"combat_volume", 1.0)
	(options.get_node("%ControlsSlider") as HSlider).value = 1.2
	check(is_equal_approx((hud.get_node("%Controls") as Control).scale.x, 1.2), "the buttons size option scales the controls")
	var battery: CheckButton = options.get_node("%BatteryCheck")
	battery.button_pressed = true
	check(Settings.battery_saver and Engine.max_fps == Settings.SAVER_FPS, "the battery saver caps the frame rate")
	battery.button_pressed = false
	check(Engine.max_fps == Settings.FPS, "and lifts it again")
	(options.get_node("%FewerEffectsCheck") as CheckButton).button_pressed = true
	Vfx.burst(world, Vfx.SPARKLES, game.player.global_position)
	var effects := world.get_node("Effects")
	var burst := effects.get_child(effects.get_child_count() - 1) as CPUParticles2D
	check(Settings.fewer_effects and burst.amount == maxi(1, int((Vfx.SPARKLES.instantiate() as CPUParticles2D).amount / 2.0)), "fewer effects: half the particles")
	(options.get_node("%FewerEffectsCheck") as CheckButton).button_pressed = false
	Settings.vibrate(1.0)  # must not fail on a computer
	game._back()
	check(not options.visible and pause.visible, "back closes the options first")
	var give_up: Button = pause.get_node("%AbandonButton")
	give_up.pressed.emit()
	check(not game.player.is_dead and give_up.text == PauseMenu.CONFIRM_TEXT and pause.is_armed(), "giving up asks to confirm")
	InputDevice.use(InputDevice.Kind.KEYBOARD)
	check(give_up.text == PauseMenu.CONFIRM_TEXT_BUTTONS and pause.is_armed(), "the confirmation follows the device in hand (%s)" % give_up.text)
	InputDevice.use(InputDevice.Kind.TOUCH)
	check(give_up.text == PauseMenu.CONFIRM_TEXT, "...and back")
	game._back()
	await _frames(1)
	check(not pause.visible and not get_tree().paused, "back resumes the game")
	game._back()
	check(pause.visible, "back pauses the game")
	(pause.get_node("%ResumeButton") as Button).pressed.emit()
	await _frames(1)
	Settings.set_option(&"music_volume", 0.8)
	Settings.set_option(&"controls_scale", 1.0)

	# The minimap: the start room is known, walking reveals more, a tap shows the whole floor.
	check(world.is_explored(world.map.world_to_cell(game.player.global_position)), "the hero's surroundings are explored")
	var minimap: Minimap = hud.get_node("%Minimap")
	var full_map: Minimap = hud.get_node("%FullMap")
	check(minimap._texture != null and minimap._image.get_width() == world.map.width, "the minimap draws the floor")
	var seen := Array(world.fog.explored).count(1)
	var far_room := world.map.rooms.filter(func(r: Rect2i) -> bool:
		return not r.grow(1).has_point(world.map.stairs_cell) and not r.has_point(world.map.world_to_cell(game.player.global_position))).back() as Rect2i
	var depth_now: int = game.depth
	game.player.global_position = _solid_point_in(world, far_room.grow(-1))
	await _frames(3)
	check(Array(world.fog.explored).count(1) > seen and world.is_explored(far_room.get_center()), "exploring reveals the map")
	check(game.depth == depth_now, "(still on the same floor)")
	minimap.tapped.emit()
	check(full_map.visible, "tapping the minimap shows the whole floor")
	full_map.tapped.emit()
	check(not full_map.visible, "tapping again closes it")
	game.player.xp = 0


## Room in the bag, in a running game: auto loot (Better only leaves worse gear on the ground and
## shows it with a Take button; By hand leaves all gear; gold and keys always come), a full bag
## says so, a stack never needs a new place, and the bag screen shows stacks and dismantles.
func _test_bag_room(game: Game) -> void:
	var world: World = game.world
	var player: Player = game.player
	await _clear_monsters(world)
	for pickup in get_tree().get_nodes_in_group("pickups"):
		pickup.queue_free()
	await _frames(2)
	var saved_bag := player.inventory.items.duplicate()
	var saved_mode := Settings.auto_loot
	var saved_weapon := player.equipment.get_item(EquipmentDef.Slot.WEAPON)
	player.inventory.items.clear()
	var katana: WeaponDef = load("res://data/items/weapons/katana.tres")
	var sharp: ItemAffixDef = load("res://data/affixes/sharp.tres")
	var bear: ItemAffixDef = load("res://data/affixes/of_the_bear.tres")
	var key: ItemDef = load("res://data/items/keys/bone_key.tres")
	var none: Array[ItemAffixDef] = []
	var no_runes: Array[RuneDef] = []
	var worn := LootRoller.make(katana, ItemRarity.RARE, [sharp, bear] as Array[ItemAffixDef], no_runes, 6)
	player.equipment.equip(worn)
	var prompt: LootPrompt = game.hud.loot_prompt
	var spot := player.global_position

	# Better only: worse gear waits on the ground, shown with Take.
	Settings.auto_loot = Settings.LOOT_BETTER
	var worse := LootRoller.make(katana, ItemRarity.COMMON, none, no_runes, 2)
	var pickup := world.spawn_item(worse, spot)
	await _frames(4)
	check(is_instance_valid(pickup) and not pickup.is_taken() and player.inventory.items.is_empty(), "Better only: worse gear stays on the ground")
	check(prompt.visible and prompt.shown_item() == worse and prompt.find_child("TakeButton", true, false) != null, "walking over it shows it, with a Take button")
	prompt.press_take()
	await _frames(2)
	check(player.inventory.items.has(worse) and (not is_instance_valid(pickup) or pickup.is_taken()), "Take puts it in the bag")
	check(not prompt.visible, "and the board goes away")
	var better := LootRoller.make(katana, ItemRarity.EPIC, none, no_runes, 9)
	pickup = world.spawn_item(better, spot)
	await _frames(4)
	check(player.inventory.items.has(better), "Better only: better gear comes by itself")
	var gold_before := player.gold
	world.spawn_gold(spot + Vector2(20, 0), 5)
	for frame in 150:  # (the coins scatter and bounce before they fly: slower on a busy floor)
		if player.gold > gold_before:
			break
		await _frames(1)
	check(player.gold > gold_before, "gold always flies to the hero")

	# By hand: no gear, but the key.
	Settings.auto_loot = Settings.LOOT_OFF
	pickup = world.spawn_item(LootRoller.make(katana, ItemRarity.EPIC, none, no_runes, 12), spot)
	var key_pickup := world.spawn_item(key, spot)
	await _frames(4)
	check(is_instance_valid(pickup) and not pickup.is_taken(), "By hand: even better gear waits")
	check(player.inventory.items.has(key), "the hidden floor's key is always taken")
	player.inventory.remove(key)
	pickup.queue_free()
	if is_instance_valid(key_pickup):
		key_pickup.queue_free()
	await _frames(2)
	check(not prompt.visible, "a pickup gone: the board goes")

	# All: walking over takes it, and an identical drop joins its stack.
	Settings.auto_loot = Settings.LOOT_ALL
	var twin := LootRoller.make(katana, ItemRarity.COMMON, none, no_runes, 2)
	world.spawn_item(twin, spot)
	await _frames(4)
	check(player.inventory.count_of(worse) == 2 and player.inventory.places_used() == 2, "All: a second identical drop stacks (2 places for 3 items)")

	# A full compartment (the weapons'): it says so, and a stack still fits.
	var weapons := player.inventory.compartment_of(worse)
	for level in range(20, 20 + player.inventory.free_in(weapons)):
		player.inventory.add(LootRoller.make(katana, ItemRarity.COMMON, none, no_runes, level))
	check(player.inventory.is_compartment_full(weapons), "the weapons' compartment is full (%d / %d)" % [player.inventory.places_used_in(weapons), player.inventory.capacity_of(weapons)])
	pickup = world.spawn_item(LootRoller.make(katana, ItemRarity.MAGIC, [sharp] as Array[ItemAffixDef], no_runes, 30), spot)
	await _frames(4)
	check(is_instance_valid(pickup) and not pickup.is_taken(), "a full compartment leaves a new item on the ground")
	var toasts: Array[String] = game.hud._toasts.duplicate()
	toasts.append((game.hud.get_node("%ToastLabel") as Label).text)
	check(toasts.any(func(text: String) -> bool: return text.contains("No room left for weapons")), "and says which compartment (a toast): %s" % [toasts])
	check(prompt.visible and (prompt.find_child("TakeButton", true, false) as Button).text == "Open the bag", "the board offers to open the bag")
	pickup.queue_free()
	world.spawn_item(LootRoller.make(katana, ItemRarity.COMMON, none, no_runes, 2), spot)
	await _frames(4)
	check(player.inventory.count_of(worse) == 3, "but a third of a stack still comes in")

	# The bag screen: places counted by stacks, the count on the slot, dismantling.
	game.inventory_panel.show_category(weapons)
	game.open_inventory()
	await _frames(2)
	var panel: InventoryPanel = game.inventory_panel
	var grid: GridContainer = panel.get_node("%ItemGrid")
	var stack_slot: ItemSlot = null
	for child in grid.get_children():
		if (child as ItemSlot).item == player.inventory.find_like(worse):
			stack_slot = child
	var stacks := InventoryPanel.CATEGORIES.entries_in(panel.category_index(), player.inventory.grouped()).size()
	check(stack_slot != null and stack_slot.count == 3 and grid.get_child_count() == stacks + player.inventory.free_in(weapons), "the stack is one slot with its count (x%d), then the free places" % (stack_slot.count if stack_slot else 0))
	var places_text := (panel.get_node("%CategoryName") as Label).text
	check(places_text == "Weapons  %d / %d" % [player.inventory.places_used_in(weapons), player.inventory.capacity_of(weapons)], "the tab counts its compartment's places: %s" % places_text)
	stack_slot.pressed.emit()
	var dismantle: Button = panel.get_node("%DismantleButton")
	var gold := PlayerPack.DISMANTLE.gold_for(worse)
	check(dismantle.visible and (panel.get_node("%DismantleNote") as Label).text.contains("%d gold" % gold), "the card shows what dismantling gives")
	gold_before = player.gold
	dismantle.pressed.emit()
	check(player.gold == gold_before + gold and player.inventory.count_of(worse) == 2, "a tap breaks one of a common stack down at once, for its gold")
	check(panel._selected_item != null and panel._selected_item.stack_key() == worse.stack_key(), "the rest of the stack stays picked")
	# An epic piece asks first (DismantleRules.confirm_rarity).
	panel.slot_for(better).pressed.emit()
	gold_before = player.gold
	dismantle.pressed.emit()
	check(player.gold == gold_before and player.inventory.items.has(better) and dismantle.text == "Sure?" and (panel.get_node("%DismantleNote") as Label).text.contains("+%d" % PlayerPack.DISMANTLE.gold_for(better)), "on an epic piece a first tap asks again, with the gold")
	panel.slot_for(worse).pressed.emit()
	check(dismantle.text == "Dismantle", "picking another item takes the question back")
	var worse_button: Button = panel.get_node("%DismantleWorseButton")
	var worse_list := player.pack.worse_gear()
	var worse_gold := 0
	for item in worse_list:
		worse_gold += PlayerPack.DISMANTLE.gold_for(item)
	check(not worse_button.disabled and worse_button.text.contains("(%d)" % worse_list.size()), "Dismantle the worse counts them: %s" % worse_button.text)
	worse_button.pressed.emit()
	check(panel.is_confirm_open() and (panel.get_node("%ConfirmDismantleButton") as Button).text.contains("+%d" % worse_gold), "it asks first, with the gold")
	gold_before = player.gold
	(panel.get_node("%ConfirmDismantleButton") as Button).pressed.emit()
	check(player.gold == gold_before + worse_gold and player.pack.worse_gear().is_empty() and not panel.is_confirm_open(), "confirmed: the worse gear is gold")
	check(player.inventory.items.has(better) and player.equipment.get_item(EquipmentDef.Slot.WEAPON) == worn, "the better gear and what is worn stay")
	panel.close()
	await _frames(2)

	Settings.auto_loot = saved_mode
	player.equipment.equip(saved_weapon)
	player.inventory.items.assign(saved_bag)
	for left in get_tree().get_nodes_in_group("pickups"):
		left.queue_free()
	await _frames(2)


## Potions live on the belt, not in the bag. Bosses can't be juggled.
func _test_belt_and_balance(game: Game) -> void:
	var player: Player = game.player
	var world: World = game.world
	var potion: ConsumableDef = load("res://data/items/consumables/health_potion.tres")
	var bomb: ConsumableDef = load("res://data/items/consumables/bomb.tres")
	var haste: ConsumableDef = load("res://data/items/consumables/haste_draught.tres")
	var rage: ConsumableDef = load("res://data/items/consumables/rage_elixir.tres")
	var saved_belt := player.belt.to_data()
	var saved_bag := player.inventory.items.duplicate()
	player.belt.load_data([])
	player.inventory.items.clear()
	for i in Belt.rules.max_stack + 1:
		player.pack.pick_up(potion)
	check(player.belt.count_at(0) == Belt.rules.max_stack and player.belt.count_at(1) == 1, "potions stack on the belt (%d a slot)" % Belt.rules.max_stack)
	check(player.inventory.items.is_empty(), "they take no room in the bag")
	player.pack.pick_up(bomb)
	player.pack.pick_up(haste)
	check(player.belt.item_at(2) == bomb and player.inventory.items.size() == 1 and player.inventory.items[0] == haste, "a full belt sends the rest to the bag")
	await _frames(2)
	var buttons: Array = [game.hud.get_node("%QuickItemButton"), game.hud.get_node("%Belt2Button"), game.hud.get_node("%Belt3Button")]
	check(buttons.all(func(b: ActionButton) -> bool: return b.visible) and (buttons[0] as ActionButton).counter == Belt.rules.max_stack, "one button per belt slot, with its count")
	player.hp = 1
	player.pack.use_belt(0)
	check(player.hp > 1 and player.belt.count_at(0) == Belt.rules.max_stack - 1, "a belt button uses its potion")
	var bombs_before := player.belt.count_of(bomb)
	player.pack.use_belt(2)
	check(player.belt.item_at(2) == null and bombs_before == 1, "the last one empties the slot")
	check(player.pack.move_to_belt(haste) and player.belt.item_at(2) == haste and player.inventory.items.is_empty(), "a consumable moves from the bag to the belt")
	check(player.pack.move_to_bag(2) and player.inventory.items.has(haste), "and back")
	var data := player.save_state()
	var copy := player.belt.to_data()
	player.belt.load_data([])
	player.belt.load_data(JSON.parse_string(JSON.stringify(data.belt)))
	check(player.belt.to_data() == copy, "the belt is saved with the run")
	# The inventory screen shows the belt.
	game.open_inventory()
	var panel: InventoryPanel = game.inventory_panel
	panel._select_belt(0)
	check((panel.get_node("%BeltSlot1") as ItemSlot).count == player.belt.count_at(0) and panel.get_node("%BeltButton").visible, "the bag screen shows the belt")
	panel.close()
	await _frames(1)
	player.pack.pick_up(rage)
	player.belt.load_data(saved_belt)
	player.inventory.items = saved_bag

	# Bosses stand their ground; elites and big monsters resist. (One at a time: they would push
	# each other.)
	var moved := []
	for path in ["res://data/monsters/bosses/king_slime.tres", "res://data/monsters/slime.tres"]:
		var monster := world.spawn_monster(load(path), world.map.cell_to_world(_open_cell_near(world, player.global_position, 3)))
		monster.dormant = true
		await _frames(2)
		var start := monster.global_position
		var shove := Combat.make_secondary_hit(null, 1)
		shove.knockback = Vector2.RIGHT * 600.0
		monster.take_hit(shove)
		await _frames(20)
		moved.append(monster.global_position.distance_to(start))
		if monster.is_boss():
			check(monster.get_max_hp() >= 800, "bosses are tough (%d HP)" % monster.get_max_hp())
		monster.queue_free()
		await _frames(2)
	check(moved[0] < 8.0 and moved[1] > 20.0, "bosses barely move when hit (%.1f vs %.1f)" % moved)
	var slime := world.spawn_monster(load("res://data/monsters/slime.tres"), world.map.cell_to_world(_open_cell_near(world, player.global_position, 3)))
	world.make_elite(slime)
	check(slime.get_knockback_resistance() >= 0.5, "elites resist knockback")
	slime.queue_free()
	await _frames(2)


## Objects keep their distance: an encounter (a statue to pray at, an altar, a spring) has a room
## of its own and nothing within DungeonConfig.encounter_clearance of it; an Ashen Breath oasis
## always lies on floor, never in the rock (it used to, beside a small first room).
func _test_spacing(game: Game) -> void:
	var world: World = game.world
	var config: DungeonConfig = CONTENT.dungeon
	var saved := [config.encounters_min, config.encounters_max]
	var difficulty: DifficultyDef = world.difficulty
	var saved_chance := difficulty.curse_chance
	var saved_curses := CONTENT.curses.duplicate()
	var start_depth: int = game.depth
	config.encounters_min = 4  # crowded floors: where clashes would show
	config.encounters_max = 4
	difficulty.curse_chance = 0.0
	var pairs := 0
	var too_close: Array[String] = []
	for depth in [2, 3, 5, 7, 8, 10]:
		game.depth = depth
		game._enter_floor()
		await _frames(2)
		var map := world.map
		var cells: Array[Vector2i] = []
		var rooms := {}
		for node in get_tree().get_nodes_in_group("encounters"):
			var cell := map.world_to_cell((node as Node2D).global_position)
			for i in map.rooms.size():
				if map.rooms[i].has_point(cell):
					check(not rooms.has(i), "floor %d: one encounter per room (room %d has two)" % [depth, i])
					rooms[i] = true
			cells.append(cell)
		var others: Array[Vector2i] = []
		for node in get_tree().get_nodes_in_group("chests"):
			others.append(map.world_to_cell((node as Node2D).global_position))
		for i in cells.size():
			for j in range(i + 1, cells.size()):
				pairs += 1
				var gap := maxi(absi(cells[i].x - cells[j].x), absi(cells[i].y - cells[j].y))
				if gap <= config.encounter_clearance:
					too_close.append("floor %d: %s / %s" % [depth, cells[i], cells[j]])
			for other in others:
				if maxi(absi(cells[i].x - other.x), absi(cells[i].y - other.y)) <= config.encounter_clearance:
					too_close.append("floor %d: chest %s by %s" % [depth, other, cells[i]])
	check(pairs >= 6, "encounters compared (%d pairs)" % pairs)
	check(too_close.is_empty(), "nothing stands against an encounter: %s" % ", ".join(too_close.slice(0, 4)))
	config.encounters_min = saved[0]
	config.encounters_max = saved[1]

	var ashen: CurseDef = load("res://data/curses/ashen_breath.tres")
	CONTENT.curses = [ashen]
	difficulty.curse_chance = 1.0
	var oases := 0
	var in_rock: Array[String] = []
	for depth in [2, 4, 6, 9, 11]:
		game.depth = depth
		game._enter_floor()
		await _frames(2)
		for node in get_tree().get_nodes_in_group("heat_sources"):
			var source := node as HeatSource
			if source.def != ashen.warm_spot:
				continue
			oases += 1
			for y in range(source.rect.position.y, source.rect.end.y):
				for x in range(source.rect.position.x, source.rect.end.x):
					if not world.map.is_floor(Vector2i(x, y)):
						in_rock.append("floor %d: %s" % [depth, source.rect])
	check(oases >= 5, "Ashen Breath oases checked (%d)" % oases)
	check(in_rock.is_empty(), "every oasis lies on floor, never in a wall: %s" % ", ".join(in_rock.slice(0, 4)))
	CONTENT.curses = saved_curses
	difficulty.curse_chance = saved_chance
	game.depth = start_depth
	game._enter_floor()
	await _frames(2)


## Frozen floors and campfires, scorching ground, dark rooms, and no bag full of potions.
func _test_climate(game: Game) -> void:
	var player: Player = game.player
	var world: World = game.world
	var frostbound: CurseDef = load("res://data/curses/frostbound.tres")
	var ashen: CurseDef = load("res://data/curses/ashen_breath.tres")
	var lanternless: CurseDef = load("res://data/curses/lanternless.tres")
	var campfire: HeatSourceDef = load("res://data/hazards/campfire.tres")
	var oasis: HeatSourceDef = load("res://data/hazards/oasis.tres")
	check(CONTENT.curses.has(frostbound) and CONTENT.curses.has(ashen) and CONTENT.curses.has(lanternless), "three curses: frozen, burning, lightless")
	var start_depth: int = game.depth
	var saved_curses := CONTENT.curses.duplicate()
	var difficulty: DifficultyDef = world.difficulty
	var saved_chance := difficulty.curse_chance

	# The first floor is never cursed.
	difficulty.curse_chance = 1.0
	game.depth = 1
	game._enter_floor()
	await _frames(3)
	check(world.curse == null, "never on the first floor")

	# Frostbound: the whole floor is ice; the cold creeps in, slows, then hurts.
	CONTENT.curses = [frostbound]
	game.depth = 2
	game._enter_floor()
	await _frames(3)
	check(world.curse == frostbound and world.floor_event == null, "a cursed floor (and no floor event with it)")
	var sources := get_tree().get_nodes_in_group("heat_sources")
	var fires := sources.filter(func(f: Node) -> bool: return (f as HeatSource).def == campfire)
	var iced := sources.filter(func(f: Node) -> bool: return (f as HeatSource).def == frostbound.room_look)
	check(iced.size() == world.map.rooms.size(), "ice over every room (%d/%d)" % [iced.size(), world.map.rooms.size()])
	check(fires.size() >= 2 and fires.any(func(f: Node) -> bool: return world.map.rooms[0].grow(3).has_point(world.map.world_to_cell(f.global_position))), "campfires around the floor, one where you arrive (%d)" % fires.size())
	check(fires.size() <= 1 + frostbound.spot_count.y, "but only a few (%d)" % fires.size())
	var decor := (fires[0] as HeatSource).get_children().filter(func(n: Node) -> bool: return n is DecorLayer)
	check(not decor.is_empty() and (decor[0] as DecorLayer).pieces.size() <= campfire.decor_count.y, "logs and stones around the fire, never the same")
	for fire in fires:
		fire.free()
	player.temperature.reset()
	player.hp = player.get_max_hp()
	player._invulnerable_time = 0.0
	player.ward = 0  # a Guardian Ring taken earlier would soak the cold
	for i in 40:
		player.temperature.update(player, 0.5)
	check(player.temperature.value <= -BodyTemperature.LIMIT, "Frostbound chills the hero to the bone (%.0f)" % player.temperature.value)
	check(player.statuses.speed_multiplier() < 0.8, "the cold slows you down")
	check(player.hp < player.get_max_hp(), "freezing hurts")
	await _frames(2)
	check(game.hud._temp_bar.visible and game.hud._temp_bar.fill_color.b > 0.9, "the HUD shows how cold you are")
	check(game.hud._temp_overlay.visible and (game.hud._temp_overlay.material as ShaderMaterial).get_shader_parameter("cold") > 0.9, "frost creeps over the screen")
	var cell := world.map.world_to_cell(player.global_position)
	var fire := world.spawn_heat_source(campfire, Rect2i(cell, campfire.size))
	check(fire.reaches(player), "a campfire reaches the hero next to it")
	for i in 4:
		player.temperature.update(player, 0.5)
	check(player.temperature.value > -BodyTemperature.LIMIT * 0.1, "a campfire warms you back up (%.0f)" % player.temperature.value)
	# Camping by the fire draws monsters in.
	await _clear_monsters(world)
	var watch: CampWatch = fire.get_children().filter(func(n: Node) -> bool: return n is CampWatch)[0]
	var warnings := [false]
	var on_log := func(text: String, _color: Color) -> void: warnings[0] = warnings[0] or text == campfire.camp_warning
	Events.message_logged.connect(on_log)
	watch.camped = campfire.camp_limit * 0.7
	await _frames(2)
	check(warnings[0] and world.monster_count() == 0, "stay too long by the fire: a warning first")
	watch.camped = campfire.camp_limit - 0.01
	await _frames(3)
	var invaders := world.get_hostiles(Actor.Faction.PLAYER)
	check(invaders.size() >= campfire.invasion.x and invaders.all(func(m: Actor) -> bool: return (m as Monster).summoned and (m as Monster).target == player), "then monsters come for the fire (%d), and give nothing" % invaders.size())
	check(watch.camped < 1.0 and watch.waves == 1, "the watch starts over, the next wave bigger")
	Events.message_logged.disconnect(on_log)
	await _clear_monsters(world)
	fire.free()

	# Ashen Breath: it burns; the springs cool you down.
	CONTENT.curses = [ashen]
	game._enter_floor()
	await _frames(3)
	var oases := get_tree().get_nodes_in_group("heat_sources").filter(func(f: Node) -> bool: return (f as HeatSource).def == oasis)
	check(world.curse == ashen and not oases.is_empty(), "Ashen Breath: oases around the floor")
	var sizes := {}
	for spot: HeatSource in oases:
		sizes[spot.rect.size] = true
		check(world.nav.is_blocked(spot.rect.get_center()), "nobody walks on an oasis' water")
	check(oases.all(func(spot: HeatSource) -> bool: return spot.rect.size.x >= oasis.size.x and spot.rect.size.x <= oasis.size_max.x), "oases of different sizes (%d kinds)" % sizes.size())
	for node in get_tree().get_nodes_in_group("heat_sources"):
		node.free()
	player.temperature.reset()
	for i in 40:
		player.temperature.update(player, 0.5)
	check(player.temperature.value >= BodyTemperature.LIMIT, "Ashen Breath heats the hero up (%.0f)" % player.temperature.value)
	cell = world.map.world_to_cell(player.global_position)
	var pool := world.spawn_heat_source(oasis, Rect2i(cell + Vector2i(1, 0), oasis.size))
	check(pool.reaches(player), "the hero on the shore")
	for i in 4:
		player.temperature.update(player, 0.5)
	check(player.temperature.value < BodyTemperature.LIMIT * 0.1, "an oasis cools you down (%.0f)" % player.temperature.value)
	pool.free()

	# Moonless Night: the whole floor in the dark, but around the hero.
	CONTENT.curses = [lanternless]
	game._enter_floor()
	await _frames(3)
	var darks := get_tree().get_nodes_in_group("dark_rooms")
	check(world.curse == lanternless and darks.size() == 1 and (darks[0] as DarkRoom).covers(world.map.cell_to_world(world.map.stairs_cell)) and (darks[0] as DarkRoom).covers(player.global_position), "Moonless Night: the whole floor is dark")
	check((darks[0] as DarkRoom).z_index > 0 and (darks[0] as DarkRoom).material is ShaderMaterial, "the darkness covers the monsters")
	check(world.rules.loot_quality() > 1.0, "braving a curse pays: better loot")

	# The curse card: the sigil, the name, the story, the rule.
	game.curse_card.play(frostbound)
	await _frames(70)
	check(game.curse_card.visible and (game.curse_card.get_node("%Title") as Label).text == frostbound.display_name and (game.curse_card.get_node("%Rule") as Label).text == frostbound.description, "arriving on a cursed floor shows the curse's card")
	game.curse_card._skip = true
	await game.curse_card.finished
	check(not game.curse_card.visible, "a tap skips it")

	# The Blood Moon: its own look (red grade, the moon's glow, beating edges) over the biome.
	var moon: FloorEventDef = load("res://data/floor_events/blood_moon.tres")
	await game.debug.enter_floor(maxi(start_depth, 4), null, moon)
	await _frames(3)
	var screen := get_tree().get_first_node_in_group(&"screen_effects") as ScreenEffects
	var screen_look := screen.material as ShaderMaterial
	check(world.floor_event == moon and (screen_look.get_shader_parameter("moon_color") as Color).a > 0.0 and float(screen_look.get_shader_parameter("vignette_pulse")) > 0.0, "the Blood Moon hangs over the floor")
	var dim := world.lights.ambient_level
	check(world.lights.colors[dim].g < world.theme.lighting.color_of(dim).g * 0.9, "its light is red")
	await game.debug.enter_floor(maxi(start_depth, 4))
	await _frames(3)
	check((screen_look.get_shader_parameter("moon_color") as Color).a == 0.0, "gone on the next floor")

	# A boss at a rare rank: its name, its affixes on the boss bar.
	var legendary: MonsterRankDef = CONTENT.dungeon.rare_ranks.filter(func(r: MonsterRankDef) -> bool: return r.id == &"legendary")[0]
	world.overrides.boss_rank = legendary
	var hall: ArenaDef = load("res://data/arenas/great_hall.tres")
	world.overrides.arena = hall
	await game.debug.enter_floor(CONTENT.dungeon.acts[0].floors)
	await _frames(3)
	var rare_boss := world.arena.boss
	check(rare_boss.rank == legendary and rare_boss.affixes.size() == legendary.affixes and rare_boss.display_name.begins_with("Legendary"), "a boss can come Legendary (%s)" % rare_boss.display_name)
	world.arena.start()
	await _frames(2)
	var bar_name := (game.hud.get_node("%BossName") as Label).text
	check(bar_name.contains(rare_boss.affixes[0].display_name), "the boss bar shows its affixes (%s)" % bar_name)
	# Its arena: the plan's size, its pillars, and a change at the next phase.
	check(world.arena_plan == hall and world.map.boss_room.size == hall.size, "the boss fights in its arena (%s)" % hall.display_name)
	var columns := get_tree().get_nodes_in_group("props").filter(func(p: Node) -> bool: return (p as Prop).def == hall.pillar)
	check(columns.size() == hall.pillars.size(), "pillars stand in it (%d)" % columns.size())
	var cracks_before := world.holes.cracks.size()
	rare_boss.skills.set_skills([] as Array[SkillDef])
	rare_boss.invincible = false
	var to_phase := HitInfo.new()
	to_phase.amount = Combat.hit_for(rare_boss.hp - roundi(rare_boss.get_max_hp() * 0.6), rare_boss.get_stats().defense)
	rare_boss.take_hit(to_phase)
	await _frames(5)
	check(get_tree().get_nodes_in_group("vfx").size() >= 0 and world.arena.shifts_done == 1, "the next phase changes the arena")
	await _frames(int(hall.shifts[0].warning_time * 60.0) + 10)
	check(world.holes.cracks.size() > cracks_before, "after the warning, its edge cracks (%d)" % (world.holes.cracks.size() - cracks_before))

	# Back to a normal floor for the next tests.
	CONTENT.curses = saved_curses
	difficulty.curse_chance = 0.0
	game.depth = start_depth
	game._enter_floor()
	await _frames(3)
	difficulty.curse_chance = saved_chance
	player.temperature.reset()
	player.hp = player.get_max_hp()
	await _frames(2)
	check(not game.hud._temp_bar.visible, "no thermometer when all is fine")
	await _clear_monsters(world)

	# Potions: past a few of the same, they come as gold.
	var potion: ConsumableDef = load("res://data/items/consumables/health_potion.tres")
	var saved_belt := player.belt.to_data()
	var saved_bag := player.inventory.items.duplicate()
	player.belt.load_data([])
	player.inventory.items.clear()
	check(world.spawn_loot(potion, player.global_position + Vector2(40, 0)) != null, "potions drop while you carry few")
	for i in CONTENT.dungeon.consumable_carry_cap:
		player.pack.pick_up(potion)
	var coins_before := get_tree().get_nodes_in_group("gold").size()
	var gold_before := _gold_on_floor(world)
	check(world.spawn_loot(potion, player.global_position + Vector2(40, 0)) == null, "with %d potions on you, more turn into gold" % CONTENT.dungeon.consumable_carry_cap)
	await _frames(2)
	check(_gold_on_floor(world) > gold_before, "the gold is on the floor (%d coins before)" % coins_before)
	for node in world.get_node("Entities").get_children():
		if node is ItemPickup:
			node.queue_free()
	player.belt.load_data(saved_belt)
	player.inventory.items = saved_bag
	await _frames(2)


## Special floors, one boss per act drawn for the run, and the new bosses fighting.
func _test_variety(game: Game) -> void:
	var world: World = game.world
	var player: Player = game.player
	player.xp = -1000000
	check(world.run_bosses.size() == CONTENT.dungeon.acts.size(), "the run drew a boss for every act")
	for i in world.run_bosses.size():
		check(CONTENT.dungeon.acts[i].all_bosses().has(world.run_bosses[i]), "act %d: its boss is one of the act's" % (i + 1))
	game._save_run()
	check((RunSave.read().get("bosses", []) as Array).size() == world.run_bosses.size(), "the drawn bosses are saved with the run")

	# Special floors.
	var chance := CONTENT.dungeon.floor_event_chance
	var events := CONTENT.floor_events
	CONTENT.dungeon.floor_event_chance = 1.0
	world.build_floor(2, CONTENT)
	check(world.floor_event != null, "a floor can be special")
	world.build_floor(3, CONTENT)
	check(world.floor_event == null, "never on boss floors")
	CONTENT.floor_events = [load("res://data/floor_events/treasure_vault.tres")] as Array[FloorEventDef]
	world.build_floor(2, CONTENT)
	var chests := get_tree().get_nodes_in_group("chests").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	check(world.floor_event.id == &"treasure_vault" and chests.size() >= 3, "a treasure vault is full of chests (%d)" % chests.size())
	CONTENT.floor_events = [load("res://data/floor_events/swarm.tres")] as Array[FloorEventDef]
	world.build_floor(2, CONTENT)
	var weakling := world.spawn_monster(load("res://data/monsters/slime.tres"), world.map.cell_to_world(world.map.start_cell))
	check(weakling.get_max_hp() < roundi((load("res://data/monsters/slime.tres") as MonsterDef).stats.max_hp * (1.0 + CONTENT.dungeon.monster_hp_scale_per_depth)), "the swarm is weak")
	CONTENT.floor_events = events
	CONTENT.dungeon.floor_event_chance = chance
	game.depth = 2
	game._enter_floor()
	await _frames(3)

	# The new bosses use their skills and can be beaten.
	var defense := player.base_stats.defense
	player.base_stats.defense = 999
	player.invalidate_stats()
	for id in ["giant_frog", "weeping_spirit", "red_samurai"]:
		# In sight of the hero, at a distance where every skill may be used.
		var boss := world.spawn_monster(load("res://data/monsters/bosses/%s.tres" % id), world.find_open_point_near(player.global_position, 150.0))
		boss.wake_up(player)
		var used := false
		for frame in 60 * 10:
			for i in boss.skills.skills.size():
				used = used or boss.skills.cooldown_ratio(i) > 0.0
			if used:
				break
			await get_tree().physics_frame
		check(used, "%s uses its skills" % id)
		boss.die(player)
		check(boss.is_dead, "%s can be beaten" % id)
		await _frames(30)
	for monster in world.get_hostiles(Actor.Faction.PLAYER):
		monster.queue_free()
	player.base_stats.defense = defense
	player.invalidate_stats()
	player.hp = player.get_max_hp()
	player.xp = 0
	await _frames(3)


## Springs, altars, spirits and statues: costs, choices, outcomes.
func _test_encounters(game: Game) -> void:
	var player: Player = game.player
	var world: World = game.world
	player.xp = -1000000
	check(CONTENT.encounters.size() >= 4, "encounters listed")
	for def in CONTENT.encounters:
		check(def.icon != null and not def.choices.is_empty(), "%s has a sprite and choices" % def.id)
		for choice in def.choices:
			check(not choice.outcomes.is_empty(), "%s: '%s' leads somewhere" % [def.id, choice.label])
	var panel: EncounterPanel = game.encounter_panel

	# The spring: walking up asks, drinking does something, then it is spent.
	var spring := world.spawn_encounter(load("res://data/encounters/spirit_spring.tres"), _open_cell_near(world, player.global_position, 2))
	var interact := game.hud.get_node("%InteractButton") as InteractButton
	player.global_position = spring.global_position + Vector2(0, 160)
	await _frames(3)
	check(not interact.visible, "out of reach: no Interact button")
	player.global_position = spring.global_position + Vector2(0, 40)
	await _frames(3)
	check(not panel.visible and not get_tree().paused, "walking up to an encounter opens nothing by itself")
	check(interact.visible and interact.caption == spring.def.verb and game.interactor.focus != null and game.interactor.focus.get_parent() == spring, "the Interact button names it: %s" % interact.caption)
	for def in CONTENT.encounters:
		check(not def.verb.is_empty() and def.verb != "Approach", "%s has its own word on the button (%s)" % [def.id, def.verb])
	check(await _tap_interact(game) and panel.visible and get_tree().paused, "tapping it asks what to do")
	panel._choose(0)
	check(spring.used and (panel.get_node("%Choices") as Control).get_child_count() == 1, "a choice was made, the spring is spent")
	check((panel.get_node("%Result") as Label).visible and not (panel.get_node("%Result") as Label).text.is_empty(), "what happened is spelled out")
	panel.close()
	await _frames(2)
	check(not get_tree().paused, "closing resumes the game")
	player.global_position = spring.global_position + Vector2(0, 160)
	await _frames(3)
	player.global_position = spring.global_position + Vector2(0, 40)
	await _frames(3)
	check(not interact.visible and not await _tap_interact(game) and not panel.visible, "a spent encounter asks nothing (no button)")
	player.global_position = spring.global_position + Vector2(0, 160)

	# The Keeper's Statue: the empty niche beside it, its inscription under the text (the keeper
	# unnamed: the test profile has not seen the reveal).
	var keeper_statue := world.spawn_encounter(load("res://data/encounters/warden_statue.tres"), _open_cell_near(world, player.global_position, 2))
	game.open_encounter(keeper_statue)
	await _frames(1)
	var niche_label := panel.get_node("%Niche") as Label
	check(niche_label.visible and niche_label.text == tr(keeper_statue.def.niche.text) and not niche_label.text.contains("T\u00f4ma"), "the Keeper's Statue tells of the empty niche beside it, the name scratched away (%s)" % niche_label.text)
	panel.close()
	await _frames(1)
	keeper_statue.queue_free()
	game.open_encounter(spring)
	await _frames(1)
	check(not (panel.get_node("%Niche") as Label).visible, "an encounter without a niche tells of none")
	panel.close()
	await _frames(2)

	# The blood altar: max HP for a relic.
	var max_hp := player.base_stats.max_hp
	var altar := world.spawn_encounter(load("res://data/encounters/blood_altar.tres"), _open_cell_near(world, player.global_position, 2))
	game.open_encounter(altar)
	panel._choose(0)
	check(player.base_stats.max_hp < max_hp, "the altar takes max HP")
	panel.close()
	await _frames(3)
	check(game.perk_panel.visible and (game.perk_panel.get_node("%Title") as Label).text == "Relic", "and gives a relic choice")
	game.perk_panel.choose(0)
	await _frames(2)
	player.base_stats.max_hp = max_hp
	player.invalidate_stats()

	# The grinning spirit wants gold.
	player.gold = 0
	var gambler := world.spawn_encounter(load("res://data/encounters/grinning_spirit.tres"), _open_cell_near(world, player.global_position, 2))
	game.open_encounter(gambler)
	var pay: Button = panel.choice_button(0)
	check(pay.disabled and pay.text.contains("gold"), "no gold, no gamble")
	check((panel.get_node("%Choices") as Control).get_child_count() == 2, "one card per choice")
	var odds := gambler.def.choices[0].chances()
	check(odds.size() == 3 and is_equal_approx(odds[0] + odds[1] + odds[2], 1.0) and is_equal_approx(odds[0], 0.45), "the odds of each outcome are shown (45%)")
	check(gambler.def.choices[0].outcomes[2].summary(player, true).begins_with("Nothing") and gambler.def.choices[0].outcomes[2].is_bad(), "losing the gold is spelled out, in red")
	check(gambler.def.choices[0].cost_text(player, world.depth).contains("gold"), "each choice says what it costs")
	check(gambler.resolve(0, player) == null and not gambler.used, "it can't be forced either")
	panel.close()
	await _frames(2)

	# The statue may call its servants: elites.
	var statue: EncounterDef = load("res://data/encounters/warden_statue.tres")
	var before := world.get_hostiles(Actor.Faction.PLAYER).filter(func(m: Monster) -> bool: return m.is_elite()).size()
	statue.choices[0].outcomes[1].apply(player, player.global_position + Vector2(60, 0))
	await _frames(2)
	var elites := world.get_hostiles(Actor.Faction.PLAYER).filter(func(m: Monster) -> bool: return m.is_elite())
	check(elites.size() == before + 2, "the statue's servants are elites")
	for monster in elites:
		monster.queue_free()
	for node in get_tree().get_nodes_in_group("encounters"):
		node.queue_free()
	player.xp = 0
	player.hp = player.get_max_hp()
	await _frames(3)


## Pact doors (PactRoom): where floors put them, the offer, keeping and breaking a pact, saves.
func _test_pacts(game: Game) -> void:
	var player: Player = game.player
	var config := CONTENT.dungeon
	var chance := config.pact_chance
	var was_invincible := player.invincible
	var max_hp := player.base_stats.max_hp
	config.pact_chance = 1.0
	player.xp = -1000000
	player.invincible = true
	# Where: never the first floor nor a boss floor, one at most, nothing else cut off.
	var with_pact := -1
	var with_pact_drought := 0
	var placed := 0
	for depth in range(1, 40):
		if depth >= 15 and with_pact > 0:
			break  # (past the first floors, only looking for one to play)
		game.depth = depth
		game._enter_floor()
		await _frames(1)
		var floor_world: World = game.world
		var doors := floor_world.get_node("Entities").get_children().filter(func(n: Node) -> bool: return n is PactRoom and not n.is_queued_for_deletion())
		check(doors.size() <= 1, "floor %d: one pact door at most (%d)" % [depth, doors.size()])
		if depth == 1 or config.boss_for_depth(depth) != null:
			check(doors.is_empty() and floor_world.pact == null, "floor %d: no pact door on the first floor nor a boss floor" % depth)
			continue
		if doors.is_empty():
			continue
		placed += 1
		var pact_door := doors[0] as PactRoom
		check(floor_world.pact == pact_door and pact_door.is_closed() and pact_door.is_open_offer(), "floor %d: the pact door is sealed, its pact on offer" % depth)
		check(not floor_world.map.secrets.any(func(plan: SecretRoomPlan) -> bool: return floor_world.map.rooms[plan.host] == pact_door.room), "floor %d: no secret room opens off a pact room (it could stay walled in)" % depth)
		var start := floor_world.map.cell_to_world(floor_world.map.start_cell)
		for cell in floor_world.stairs_cells:
			check(not floor_world.find_path(start, floor_world.map.cell_to_world(cell)).is_empty(), "floor %d: the sealed door never cuts the stairs off" % depth)
		var inside := func(node: Node) -> bool: return pact_door.room.grow(1).has_point(floor_world.map.world_to_cell((node as Node2D).global_position))
		check(not floor_world.get_hostiles(Actor.Faction.PLAYER).any(inside), "floor %d: nobody waits behind the pact door" % depth)
		check(not get_tree().get_nodes_in_group("chests").any(inside) and not get_tree().get_nodes_in_group("encounters").any(inside), "floor %d: no chest nor encounter behind it" % depth)
		check(floor_world.ambush == null or floor_world.ambush.room != pact_door.room, "floor %d: not an ambush room too" % depth)
		if with_pact < 0:
			with_pact = depth
			with_pact_drought = floor_world.forge_drought_at_start
	check(placed >= 1, "pact doors come up on normal floors (%d)" % placed)
	if with_pact < 0:
		config.pact_chance = chance
		return
	game.depth = with_pact
	# The same floor every time below: the smith's forge, which may take a room first, comes back
	# just as often (its chance grows with the floors without it, as a save keeps it): the drought
	# the floor was first made with, not the one the last floor of the loop left.
	var drought := with_pact_drought
	game.world.floors_without_forge = drought
	game._enter_floor()
	check(game.world.pact != null, "floor %d made again (same seed, same forge drought): its pact door again" % with_pact)
	if game.world.pact == null:
		config.pact_chance = chance  # (and the rest of the game suite goes on unharmed)
		player.invincible = was_invincible
		player.xp = 0
		return
	var room := game.world.pact.room
	var def := game.world.pact.def
	game.world.floors_without_forge = drought
	game._enter_floor()
	check(game.world.pact != null and game.world.pact.room == room and game.world.pact.def == def, "the same floor, the same pact door (seeded)")

	# The offer: walking up opens nothing, Interact shows it; leaving changes nothing.
	var world: World = game.world
	var pact := world.pact
	await _clear_monsters(world)
	var panel: PactPanel = game.menus.pact
	var interact := game.hud.get_node("%InteractButton") as InteractButton
	player.global_position = pact.front()
	await _frames(3)
	check(not panel.visible and not get_tree().paused, "walking up to a pact door opens nothing by itself")
	check(interact.visible and interact.caption == "Read the pact", "the Interact button reads the pact: %s" % interact.caption)
	check(await _tap_interact(game) and panel.visible and get_tree().paused, "tapping it shows the pact")
	check((panel.get_node("%Rule") as Label).text == pact.def.rule_text(player), "its rule, in plain words")
	var cost := panel.get_node("%Cost") as Label
	check(cost.text.contains(str(pact.def.max_hp_lost(player))) and cost.get_theme_color("font_color") == UiSkin.BAD, "the cost, in red, before swearing: %s" % cost.text)
	check((panel.get_node("%Reward") as Label).text.contains("relic"), "and the reward")
	panel.close()
	await _frames(2)
	check(not get_tree().paused and pact.is_open_offer() and pact.is_closed(), "leaving changes nothing")
	# (Away on free floor: 200 px straight out may be a wall or a prop, and a hero put down in it
	# is pushed out of it, or held there, rather than taken back to the door.)
	player.global_position = world.nearest_free_point(pact.front() + Vector2(pact.outward) * 200.0)
	await _stand_still(world, player)
	check(not interact.visible, "walking away hides the Interact button")
	player.global_position = pact.front()
	await _frames(3)
	var came_back := await _tap_interact(game)
	check(came_back and panel.visible, "coming back, Interact asks again (button %s: %s, %d px from the door, on the floor %s, deeps %s, menu %s)" % [came_back, interact.caption, roundi(player.global_position.distance_to(pact.front())), player.world == world, game.abyss.is_open(), game.is_menu_open()])

	# Kept: the door opens, seals behind the hero, the waves come; a relic at the end.
	panel.swear()
	await _frames(2)
	check(pact.accepted and not pact.is_closed() and not get_tree().paused, "swearing opens the door")
	player.global_position = world.nearest_free_point(world.map.cell_to_world(pact.room.get_center()))
	await _frames(3)
	check(pact.state == AmbushRoom.State.FIGHTING and pact.is_closed() and pact.rule != null, "walking in seals the door, the rule is watched")
	check(game.hud.pact_line.visible and not game.hud.pact_line.state_text().is_empty(), "the HUD shows the rule's state: %s" % game.hud.pact_line.state_text())
	var base_max := player.base_stats.max_hp
	await _slay_pact_waves(world, player, pact)
	check(pact.outcome == PactRoom.Outcome.KEPT and not pact.is_closed(), "every foe slain, rule kept: the door opens")
	check(player.base_stats.max_hp == base_max, "a kept pact costs nothing")
	check(game.hud.pact_line.state_text() == "Pact kept", "the HUD says so (%s)" % game.hud.pact_line.state_text())
	await _frames(120)
	var offered := game.perk_panel.get_offered()
	check(game.perk_panel.visible and offered.size() == pact.def.relic_choices and offered.all(func(p: PerkDef) -> bool: return p.rarity == PerkDef.Rarity.RARE), "and a choice of relics (%d)" % offered.size())
	check(world.spent_data().get("pact", 0) == 1, "the floor's save knows the pact was sworn")
	game.perk_panel.choose(0)
	await _frames(2)

	# Broken: the cost at once, the fight goes on, no relic.
	game.world.floors_without_forge = drought
	game._enter_floor()
	world = game.world
	pact = world.pact
	pact.def = load("res://data/pacts/untouched.tres")
	await _clear_monsters(world)
	game.open_pact(pact)
	panel.swear()
	await _frames(2)
	player.global_position = world.nearest_free_point(world.map.cell_to_world(pact.room.get_center()))
	await _frames(3)
	check(pact.state == AmbushRoom.State.FIGHTING, "the Untouched's fight begins")
	base_max = player.base_stats.max_hp
	var lost := pact.def.max_hp_lost(player)
	player.hp = player.get_max_hp()
	player.ward = 0  # a relic's frost shell would soak the blow
	player.invincible = false
	var blow := Combat.make_secondary_hit(null, 12)
	blow.unavoidable = true
	player.take_hit(blow)
	player.invincible = true
	check(pact.outcome == PactRoom.Outcome.BROKEN and player.base_stats.max_hp == base_max - lost and lost > 0, "a single hit breaks the Untouched: %d max Health lost at once" % lost)
	check(pact.state == AmbushRoom.State.FIGHTING and pact.is_closed(), "the fight goes on behind the sealed door")
	await _frames(1)
	check(game.hud.pact_line.state_text().contains(str(lost)), "the HUD shows the cost in red (%s)" % game.hud.pact_line.state_text())
	await _slay_pact_waves(world, player, pact)
	check(pact.state == AmbushRoom.State.CLEARED and not pact.is_closed(), "the waves slain, the door opens anyway")
	await _frames(120)
	# (Level ups from the waves may wait behind the perk button: they open nothing.)
	check(not game.perk_panel.visible and not game.offers.to_data(false).any(func(o: Dictionary) -> bool: return int(o.rarity) == PerkDef.Rarity.RARE), "no relic for a broken pact")
	if game.perk_panel.visible:
		game.perk_panel.choose(0)
		await _frames(2)
	game._save_run()
	var saved := RunSave.read()
	check(int(saved.player.base_stats.max_hp) == player.base_stats.max_hp, "the lost max Health is in the run's save")
	check(int(saved.floor.pact) == 1, "...and the sworn pact too")

	# Resumed: a sworn pact is never offered again; an unsworn one is.
	world.restore_spent(saved.floor)
	world.floors_without_forge = drought
	game._enter_floor(true)
	await _frames(2)
	world = game.world
	check(world.pact != null and not world.pact.is_open_offer() and not world.pact.is_closed(), "a resumed run opens the sworn pact's door, spent")
	await _clear_monsters(world)
	player.global_position = world.pact.front()
	await _frames(3)
	check(not panel.visible and (game.interactor.focus == null or game.interactor.focus.get_parent() != world.pact), "and never offers it again (no Interact for it)")
	world.restore_spent({ "pact": 0 })
	world.floors_without_forge = drought
	game._enter_floor(true)
	await _frames(2)
	check(game.world.pact != null and game.world.pact.is_open_offer(), "a pact not sworn before quitting waits again")

	config.pact_chance = chance
	player.invincible = was_invincible
	player.base_stats.max_hp = max_hp
	player.invalidate_stats()
	player.hp = player.get_max_hp()
	player.xp = 0


## Slays a pact room's waves as they come (at most 20 s).
func _slay_pact_waves(world: World, player: Player, pact: PactRoom) -> void:
	for i in 1200:
		if pact.state == AmbushRoom.State.CLEARED:
			return
		_kill_one(world, player)
		await _frames(1)


## Magic, Rare and Epic equipment, gold, and the merchant.
func _test_loot_and_gold(game: Game) -> void:
	var world: World = game.world
	var player: Player = game.player
	player.xp = -1000000
	var katana: WeaponDef = load("res://data/items/weapons/katana.tres")
	var sharp: ItemAffixDef = load("res://data/affixes/sharp.tres")
	var bear: ItemAffixDef = load("res://data/affixes/of_the_bear.tres")
	var burning: ItemAffixDef = load("res://data/affixes/burning.tres")
	var damage_before := katana.damage
	var rare := LootRoller.make(katana, ItemRarity.RARE, [sharp, bear] as Array[ItemAffixDef]) as WeaponDef
	check(rare.display_name == "Sharp Katana of the Bear" and rare.rarity_color() == ItemRarity.COLORS[ItemRarity.RARE], "a rare item has its name and color")
	check(rare.damage > katana.damage and rare.bonuses.attack >= 2 and rare.bonuses.max_hp >= 12, "affixes and rarity make it stronger")
	check(katana.damage == damage_before and katana.base_item == null, "the plain item is untouched")
	check(rare.get_type_label().begins_with("Rare"), "the type says how rare it is")
	var magic := LootRoller.make(katana, ItemRarity.MAGIC, [burning] as Array[ItemAffixDef]) as WeaponDef
	check(magic.on_hit != null and magic.on_hit.burn_damage > 0, "a Burning weapon sets enemies on fire")
	var back := LootRoller.from_data(JSON.parse_string(JSON.stringify(LootRoller.to_data(rare)))) as WeaponDef
	check(back and back.display_name == rare.display_name and back.damage == rare.damage and back.rarity == ItemRarity.RARE, "rolled items survive a save")
	for affix in CONTENT.item_affixes:
		check(affix.bonuses != null or affix.on_hit != null or not affix.passives.is_empty(), "%s does something" % affix.id)
	var low := [0, 0, 0, 0]
	var high := [0, 0, 0, 0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 400:
		low[LootRoller.pick_rarity(1, 1.0, CONTENT.dungeon, rng)] += 1
		high[LootRoller.pick_rarity(9, CONTENT.dungeon.boss_loot_quality, CONTENT.dungeon, rng)] += 1
	check(low[0] > low[1] and low[1] > low[2] and low[2] >= low[3], "better items are rarer (%s)" % str(low))
	check(high[3] > low[3] and high[0] < low[0], "deeper and from bosses, loot gets better (%s)" % str(high))
	var potion: ItemDef = load("res://data/items/consumables/health_potion.tres")
	check(world.roll_item(potion, 10.0) == potion, "potions are never rolled")

	# Gold flies to the hero (no thief around to snatch it).
	await _clear_monsters(world)
	var gold_before := player.gold
	world.spawn_gold(player.global_position + Vector2(30, 0), 10)
	await _frames(60)
	check(player.gold >= gold_before + 10, "coins fly into the hero's purse")
	check((game.hud.get_node("%GoldLabel") as Label).text == "Gold %d" % player.gold, "the HUD shows the gold")
	var elite := world.spawn_monster(load("res://data/monsters/slime.tres"), world.map.cell_to_world(_open_cell_near(world, player.global_position, 1)))
	elite.dormant = true
	world.make_elite(elite)
	elite.take_hit(Combat.make_secondary_hit(player, 99999))
	await _frames(2)
	check(get_tree().get_nodes_in_group("gold").size() > 0, "elites always drop gold")

	# The merchant: buying, selling, the shop opening when walking up.
	var cell := _open_cell_near(world, player.global_position, 2)
	var merchant := world.spawn_merchant(CONTENT.dungeon.merchant, cell)
	world.kept_stock.clear()
	check(merchant.stock.size() >= CONTENT.dungeon.merchant.equipment_count, "the merchant has stock")
	player.gold = 0
	check(not merchant.sell_to(player, 0), "no gold, no deal")
	player.add_gold(9999)
	var bag_before := player.inventory.items.size()
	var bought: ItemDef = merchant.stock[0].item
	var price: int = merchant.stock[0].price
	check(merchant.sell_to(player, 0) and player.inventory.items.has(bought) and player.gold == 9999 - price, "buying puts the item in the bag")
	player.inventory.add(potion)
	var stock_before := merchant.stock.size()
	var gold_now := player.gold
	check(merchant.buy_from(player, potion) and player.gold > gold_now and merchant.stock.size() == stock_before + 1, "selling gives gold back")
	player.global_position = merchant.global_position + Vector2(0, 40)
	await _frames(3)
	var interact := game.hud.get_node("%InteractButton") as InteractButton
	check(not game.shop_panel.visible and not get_tree().paused, "walking up to the merchant opens nothing by itself")
	check(interact.visible and interact.caption == "Trade" and interact.icon != null, "the Interact button shows Trade, with the merchant's face")
	check(await _tap_interact(game) and game.shop_panel.visible and get_tree().paused, "tapping it opens the shop")
	check(game.shop_panel.get_node("%ForSale").get_child_count() == merchant.stock.size(), "the shop lists the stock")

	# The item card: what it is, its price, how it compares with what you wear, why you can't buy.
	var shop: ShopPanel = game.shop_panel
	shop.select_stock(0)
	var buy: Button = shop.get_node("%BuyButton")
	check(buy.visible and not buy.disabled and buy.text.contains(str(merchant.stock[0].price)), "the card's Buy button gives the price")
	check((shop.get_node("%Gold") as Label).text == "Gold %d" % player.gold, "the shop shows your gold")
	var gold_kept := player.gold
	player.gold = 0
	shop.select_stock(0)
	check(buy.disabled and buy.text.contains("Not enough gold"), "too poor: Buy is greyed and says why")
	player.gold = gold_kept
	var equipment_index := merchant.stock.find_custom(func(e: Dictionary) -> bool: return e.item is EquipmentDef)
	if equipment_index >= 0:
		shop.select_stock(equipment_index)
		check((shop.get_node("%Compare") as Control).get_child_count() > 0 or (shop.get_node("%Details") as Label).text != "", "equipment is compared with what you wear")
	var katana_like := WeaponDef.new()
	katana_like.damage = 2
	var better := WeaponDef.new()
	better.damage = 5
	check(ItemCompare.lines(better, katana_like)[0].text == "+3 damage" and ItemCompare.lines(better, katana_like)[0].good, "the comparison says '+3 damage'")
	player.inventory.add(potion)
	shop.select_own(potion)
	var sell: Button = shop.get_node("%SellButton")
	check(sell.visible and sell.text.contains(str(CONTENT.dungeon.merchant.sell_price(potion, world.depth))) and not shop.get_node("%BuyButton").visible, "an item of yours shows what the merchant pays")
	var gold_before_sale := player.gold
	check(shop.sell_selected() and player.gold > gold_before_sale, "Sell sells it")

	# Lock one, reroll the rest (dearer each time); the locked one stays.
	shop.select_stock(0)
	(shop.get_node("%LockButton") as Button).pressed.emit()
	check(merchant.stock[0].locked, "the lock button locks an entry")
	var kept: ItemDef = merchant.stock[0].item
	var kept_price: int = merchant.stock[0].price
	var reroll_price := merchant.reroll_price()
	var gold_before_reroll := player.gold
	var unlocked_before := merchant.stock.slice(1).map(func(e: Dictionary) -> ItemDef: return e.item)
	(game.shop_panel.get_node("%RerollButton") as Button).pressed.emit()
	check(player.gold == gold_before_reroll - reroll_price, "a reroll costs its price (%d)" % reroll_price)
	check(merchant.stock[0].item == kept and merchant.stock.size() > 1, "the locked entry stays, the rest is new")
	check(not merchant.stock.slice(1).all(func(e: Dictionary) -> bool: return unlocked_before.has(e.item)), "new stock after a reroll")
	check(merchant.reroll_price() > reroll_price, "each reroll costs more")
	game._back()
	await _frames(1)
	check(not game.shop_panel.visible and not get_tree().paused, "leaving the shop resumes the game")
	await _frames(3)
	check(interact.visible and not game.shop_panel.visible, "still by the merchant: the shop doesn't come back by itself, the button stays")
	Input.action_press(&"interact")
	await _frames(2)
	Input.action_release(&"interact")
	check(game.shop_panel.visible, "the interact action (E, a trigger) opens it too")
	game._back()
	await _frames(2)
	game._save_run()
	check((RunSave.read().get("kept_stock", []) as Array).size() == 1, "a saved run keeps the locked entry")

	# The locked entry waits at the next merchant, same price.
	await game.debug.enter_floor(game.depth)
	world = game.world
	check(world.kept_stock.size() == 1 and world.kept_stock[0].item == kept, "leaving the floor carries the locked entry")
	var next := world.spawn_merchant(CONTENT.dungeon.merchant, _open_cell_near(world, game.player.global_position, 2))
	check(next.stock[0].item == kept and next.stock[0].price == kept_price and next.stock[0].locked, "the next merchant sells it at the same price")
	check(world.kept_stock.is_empty(), "handed over once")
	# A floor rolled again: one rolled copy of the kept entry goes, an ordinary twin stays.
	var twin_potion: ItemDef = CONTENT.items.filter(func(item: ItemDef) -> bool: return item is ConsumableDef)[0]
	var rolled := [{ "item": twin_potion, "price": 9, "locked": true }, { "item": twin_potion, "price": 9, "locked": false }, { "item": twin_potion, "price": 9, "locked": false }, { "item": kept, "price": 9, "locked": false }]
	Merchant.drop_rolled_twins(rolled, 1)
	check(rolled.size() == 3 and rolled.filter(func(entry: Dictionary) -> bool: return entry.item == twin_potion).size() == 2, "a kept potion drops one rolled potion, not every potion (%d left)" % rolled.size())
	next.queue_free()
	player.inventory.items.resize(bag_before)
	player.xp = 0
	await _frames(5)


## Floor ambience: data per theme, footprints, low health heartbeat and muffled music.
func _test_ambience(game: Game) -> void:
	var world: World = game.world
	var player: Player = game.player
	for theme_id in ["cave", "crypt", "ruins"]:
		var theme: DungeonTheme = load("res://data/dungeon/themes/%s.tres" % theme_id)
		check(theme.ambience != null and theme.ambience.footstep != null and theme.ambience.bed != null, "%s has an ambience" % theme_id)
		check(theme.ambience.one_shots.size() >= 3 and theme.ambience.particles != null, "%s ambience has sounds and particles" % theme_id)
	check(world.theme.ambience != null, "the floor plays its theme ambience")
	var reverb := AudioServer.get_bus_effect(AudioServer.get_bus_index(&"SFX"), 0) as AudioEffectReverb
	check(reverb != null and is_equal_approx(reverb.wet, world.theme.ambience.reverb_wet), "the floor sets the reverb")

	# Walking leaves footprints.
	var prints_before := _count_footprints(world)
	var dir := Vector2.RIGHT
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		if world.map.is_floor(world.map.world_to_cell(player.global_position + d * 48.0)):
			dir = d
			break
	_set_move(dir)
	await _frames(50)
	_set_move(Vector2.ZERO)
	check(_count_footprints(world) > prints_before, "walking leaves footprints")

	# Low health: heartbeat, muffled music. Back to normal when healed.
	var music_bus := AudioServer.get_bus_index(&"Music")
	player.hp = 1
	player.health_changed.emit(player.hp, player.get_max_hp())
	check(game.ambience.is_low_health() and AudioServer.is_bus_effect_enabled(music_bus, 0), "low health muffles the music")
	player.heal(player.get_max_hp())
	check(not game.ambience.is_low_health() and not AudioServer.is_bus_effect_enabled(music_bus, 0), "healing clears the muffle")


## The dev tools (debug builds): open, jump to a cursed floor, god mode, spawn, close.
## Every biome, a few floors each: its look, its scenes (and nobody else's), nothing walled off.
func _test_biomes(game: Game) -> void:
	var depth_before := game.depth
	var world := game.world
	var dungeon := CONTENT.dungeon
	var generic := {}
	for prop in CONTENT.props:
		generic[prop] = true
	generic[dungeon.room_light] = true
	generic[dungeon.cracked_wall] = true  # (a secret room's crack: any floor of any world)
	for a in dungeon.acts.size():
		for biome in dungeon.acts[a].biomes:
			var allowed := generic.duplicate() if biome.props.is_empty() else {dungeon.room_light: true, dungeon.cracked_wall: true}
			for prop in biome.props:
				allowed[prop] = true
			if biome.light:
				allowed[biome.light] = true
			var scene_list: Array[SceneDef] = biome.scenes.duplicate()
			# Its shaped rooms' pillars and its signature rooms' scenes are its own too.
			for prop in biome.pillars:
				allowed[prop] = true
			if biome.pillars.is_empty() and dungeon.pillar:
				allowed[dungeon.pillar] = true
			for shape in biome.room_shapes + biome.set_pieces:
				if shape.pillar:
					allowed[shape.pillar] = true
				scene_list.append_array(shape.scenes)
			for scene in scene_list:
				for k in scene.keys:
					for prop in k.props:
						allowed[prop] = true
			var scenes := 0
			for attempt in 2:
				world.overrides.biome = biome
				await game.debug.enter_floor(dungeon.first_depth(a) + 1)
				world = game.world
				check(world.biome == biome and world.theme == biome.theme, "%s: the whole floor is it" % biome.id)
				for count: int in FloorDresser.last_scenes.values():
					scenes += count
				var strangers := get_tree().get_nodes_in_group("props").filter(func(node: Node) -> bool:
					return not allowed.has((node as Prop).def))
				check(strangers.is_empty(), "%s: nothing from another biome %s" % [biome.id, str(strangers.map(func(n: Node) -> StringName: return (n as Prop).def.id))])
				var cut := _walled_off_cells(world)
				check(cut.is_empty(), "%s: nothing walled off %s" % [biome.id, str(cut.slice(0, 4))])
				check(world.grounds.size() == biome.grounds.size(), "%s: its grounds laid" % biome.id)
				var over_walls := _decor_over_walls(world)
				check(over_walls.is_empty(), "%s: no decor drawn over a wall %s" % [biome.id, str(over_walls.slice(0, 4))])
			check(scenes >= 6, "%s: scenes in its rooms (%d on 2 floors)" % [biome.id, scenes])
	check(world.overrides.biome == null, "a forced biome is used once")
	await _clear_monsters(world)
	for pickup in get_tree().get_nodes_in_group("pickups"):
		pickup.queue_free()  # nothing for the next tests to pick up by chance
	await _frames(1)
	game.depth = depth_before


## The small things: splats on the floor, plants that bend, the HP bar's trail, flames, the air.
func _test_details(game: Game) -> void:
	var depth_before := game.depth
	game.world.overrides.biome = load("res://data/biomes/underground_garden.tres")
	await game.debug.enter_floor(2)
	var world := game.world
	var player := game.player
	await _clear_monsters(world)
	var spot := world.map.cell_to_world(_open_cell_near(world, player.global_position, 2))
	var before := world.splat_count()
	var slime := world.spawn_monster(load("res://data/monsters/slime.tres"), spot)
	slime.dormant = true
	await _frames(1)
	before = world.splat_count()  # (the hero's perks may have hurt it already: drops of slime)
	slime.die(null)
	check(world.splat_count() == before + 1, "a slime leaves a splat where it dies")
	var spirit := world.spawn_monster(load("res://data/monsters/spirit.tres"), spot)
	spirit.dormant = true
	await _frames(1)
	var after_slime := world.splat_count()
	spirit.die(null)
	check(world.splat_count() == after_slime, "a spirit leaves nothing")
	check((load("res://data/monsters/slime.tres") as MonsterDef).splat_color.g > 0.4, "slimes leave green slime, not blood")

	var plants: Array[DecorLayer] = []
	for node in world.get_node("Effects").get_children():
		if node is DecorLayer and (node as DecorLayer).sway:
			plants.append(node as DecorLayer)
	check(not plants.is_empty(), "the garden's plants sway")
	if not plants.is_empty():
		var layer := plants[0]
		var piece: Array = layer.pieces[0]
		player.global_position = DecorLayer._foot(piece) + Vector2(-8, 0)
		await _frames(20)
		check(absf(layer._lean[0]) > 0.1, "a plant bends when the hero walks through it")

	var bar := StatBar.new()
	add_child(bar)
	bar.set_values(100, 100)
	bar.set_values(60, 100)
	check(bar._trail == 100.0, "a hit leaves a pale trail on the bar")
	for i in 90:
		await get_tree().process_frame
	check(bar._trail == 60.0 and not bar.is_processing(), "then the trail drains away")
	bar.queue_free()

	check((load("res://data/props/furniture/brazier.tres") as PropDef).flame != null, "braziers burn")

	# Ranged weapons: a fan of three shurikens doesn't hit three times as hard; they don't glow.
	var shuriken: WeaponDef = load("res://data/items/weapons/shuriken.tres")
	var spec := Combat.spec_from_weapon(player, shuriken)
	check(spec.damage * shuriken.projectile_count <= player.get_power() * 1.5 and spec.glow == 0.0, "shurikens: each one weaker, and no glow")
	check(Combat.spec_from_weapon(player, load("res://data/items/weapons/magic_wand.tres")).glow > 0.0, "magic bolts glow")

	# Supports: a mender heals its hurt allies, a moth wards them.
	await _clear_monsters(world)
	var spot2 := world.map.cell_to_world(_open_cell_near(world, player.global_position + Vector2(200, 0), 3))
	var brute := world.spawn_monster(load("res://data/monsters/rat.tres"), spot2)
	var mender := world.spawn_monster(load("res://data/monsters/moss_heart.tres"), spot2 + Vector2(40, 0))
	await _frames(1)
	brute.dormant = true
	brute.hp = 1
	check(mender.pick_skill(150.0) == 0, "a mender wants to heal a hurt ally")
	mender.skills.skills[0].activate(mender, Vector2.RIGHT)
	check(brute.hp > 1, "and heals it")
	brute.hp = brute.get_max_hp()
	check(mender.pick_skill(150.0) == -1, "nobody hurt: it waits")
	var moth := world.spawn_monster(load("res://data/monsters/soul_moth.tres"), spot2 + Vector2(-40, 0))
	await _frames(1)
	moth.skills.skills[0].activate(moth, Vector2.RIGHT)
	check(brute.ward > 0, "a moth wards its allies")
	var before_hp := brute.hp
	var poke := HitInfo.new()
	poke.amount = Combat.hit_for(1, brute.get_stats().defense)
	brute.take_hit(poke)
	check(brute.hp == before_hp, "the ward soaks up the blow")
	await _clear_monsters(world)

	# Attack effects: a swing draws its arc, a hit its flash, a blast ripples the picture.
	var effects := world.get_node("Effects")
	var count_of := func(kind: Script) -> int: return effects.get_children().filter(func(n: Node) -> bool: return n.get_script() == kind).size()
	player.pack.use_item(load("res://data/items/weapons/katana.tres"))
	player._attack_cooldown = 0.0
	player.attack(Vector2.RIGHT)
	check(count_of.call(SwingVfx) >= 1, "a sword swing draws its arc")
	Vfx.hit(world, player.global_position, Vector2.RIGHT, Color.RED)
	check(count_of.call(ImpactVfx) >= 1, "a hit flashes")
	Vfx.explosion(world, player.global_position + Vector2(200, 0), 60.0)
	check(count_of.call(ShockwaveVfx) >= 1, "a blast ripples the picture")
	# Layers: a standing effect goes among the actors (sorted with them), the others with the
	# effects, a flat one under every actor (VfxLayer, docs/vfx.md).
	var smite_column := ((load("res://data/skills/player/smite.tres") as SkillDef).effects[0] as DamageAreaEffect).strike
	var column := SheetVfx.play(smite_column, player.global_position + Vector2(40, 0))
	world.spawn_vfx(column)
	check(column.get_parent() == world.get_node("Entities"), "a standing effect is sorted with the actors")
	var floor_ring := RingVfx.create(player.global_position, 40.0, Color.RED)
	world.spawn_vfx(floor_ring)
	check(floor_ring.get_parent() == effects and floor_ring.z_index < player.z_index, "a ring on the floor is drawn under the hero")
	column.queue_free()
	floor_ring.queue_free()
	var shroom := world.spawn_monster(load("res://data/monsters/mushroom.tres"), player.global_position + Vector2(80, 0))
	shroom.target = player
	await _frames(1)
	shroom.casting_index = 0
	shroom.get_node("StateMachine").transition_to(&"Cast")
	await _frames(6)
	var warning := shroom.get_node("Under").get_child(0) as TelegraphView
	check(warning != null and warning.visible, "a cast shows its warning zone")
	shroom.queue_free()
	var garden: BiomeDef = load("res://data/biomes/underground_garden.tres")
	check(garden.theme.ambience.particles.resource_path.ends_with("fireflies.tscn"), "fireflies in the garden")
	var air := world.get_node("Effects").get_children().filter(func(n: Node) -> bool: return n is AtmosphereLayer)
	check(air.size() == 1, "the garden has its air (light shafts, leaf shadows)")
	var screen := get_tree().get_first_node_in_group(&"screen_effects") as ScreenEffects
	check(screen != null and is_equal_approx(float((screen.material as ShaderMaterial).get_shader_parameter("grade")), garden.theme.ambience.grade_strength), "the picture takes the biome's colors")
	var biomes_with_air := 0
	for act in CONTENT.dungeon.acts:
		for biome in act.biomes:
			var mood := biome.theme.ambience
			if mood.grade_strength > 0.0 and (mood.rays_color.a > 0.0 or mood.mist_color.a > 0.0 or mood.caustics_color.a > 0.0 or mood.heat_haze > 0.0):
				biomes_with_air += 1
	check(biomes_with_air >= 9, "every biome has its atmosphere (%d)" % biomes_with_air)
	await _clear_monsters(world)
	game.depth = depth_before


## The decor pieces of the floor (grounds' and scenes' little things) whose drawn picture covers
## a wall cell: where they lie, in cells.
func _decor_over_walls(world: World) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for node in world.get_node("Effects").get_children():
		var layer := node as DecorLayer
		if layer == null:
			continue
		for piece: Array in layer.pieces:
			var drawn := FloorDresser.drawn_rect(piece[0])
			var at := layer.to_global(piece[1])
			if not FloorDresser.on_floor(world.map, Rect2(drawn.position + at, drawn.size)):
				found.append(world.map.world_to_cell(at))
	return found


## Free floor cells (not under furniture, water...) the hero can't get to from the start
## (crates and pots in the way don't count: they break).
func _walled_off_cells(world: World) -> Array[Vector2i]:
	var map := world.map
	var breakable := {}
	for node in get_tree().get_nodes_in_group("props"):
		var prop := node as Prop
		if prop.def.is_breakable() and not prop.is_queued_for_deletion():
			for cell in prop.cells():
				breakable[cell] = true
	var open := func(cell: Vector2i) -> bool:
		return map.is_floor(cell) and (not world.nav.is_blocked(cell) or breakable.has(cell))
	var seen := { map.start_cell: true }
	var queue: Array[Vector2i] = [map.start_cell]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + dir
			if open.call(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	var cut: Array[Vector2i] = []
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			if open.call(cell) and not seen.has(cell):
				cut.append(cell)
	if not seen.has(map.stairs_cell):
		cut.push_front(map.stairs_cell)
	return cut


func _test_debug_panel(game: Game) -> void:
	var debug := game.menus.debug
	check(debug != null and game.hud.has_node("DebugButton"), "debug builds have the debug panel and its DBG button")
	if debug == null:
		return
	var depth_before := game.depth
	game.open_debug()
	await _frames(2)
	check(debug.visible and get_tree().paused, "DBG opens the panel, game paused")
	var frostbound: CurseDef = load("res://data/curses/frostbound.tres")
	debug._go(5, frostbound)
	await _frames(5)
	check(not debug.visible and game.depth == 5 and game.world.curse == frostbound and not get_tree().paused, "jump to floor 5, Frostbound")
	debug._go(5)
	await _frames(5)
	check(game.world.curse == null and game.world.floor_event == null, "a plain floor on demand")
	game.open_debug()
	await _frames(1)
	debug._god_button.pressed.emit()
	check(game.player.invincible, "god mode")
	var hp := game.player.hp
	game.player.take_hit(Combat.make_secondary_hit(null, 50))
	check(game.player.hp == hp, "nothing hurts in god mode")
	debug._god_button.pressed.emit()
	var before := game.world.monster_count()
	debug._spawn(true)
	check(game.world.monster_count() == before + 1, "spawn a monster (elite)")
	game.world.reveal_all()
	check(game.world.is_explored(game.world.map.stairs_cell), "reveal the map")
	debug.close()
	await _frames(2)
	check(not debug.visible and not get_tree().paused, "closing resumes the game")
	await _clear_monsters(game.world)
	game.depth = depth_before


## Floors grow with the difficulty; a crowded one keeps the phone's monster cap and the seal's.
func _test_floor_size(game: Game) -> void:
	var world: World = game.world
	var config := CONTENT.dungeon
	var before := world.difficulty
	world.difficulty = CONTENT.get_difficulty(&"easy")
	world.build_floor(2, CONTENT)
	var easy_rooms := world.map.rooms.size()
	var easy_width := world.map.width
	world.difficulty = AscensionDef.apply_levels(CONTENT.get_difficulty(&"nightmare"), CONTENT.ascensions, CONTENT.ascensions.size())
	world.build_floor(8, CONTENT)
	check(world.map.width > easy_width and world.map.rooms.size() > easy_rooms, "Nightmare floors are bigger (%d rooms, Easy %d)" % [world.map.rooms.size(), easy_rooms])
	check(world.monster_count() <= config.max_monsters_per_floor and world.monster_count() >= config.max_monsters_per_floor * 0.6, "crowded, within the cap (%d)" % world.monster_count())
	check(world.seal.needed == config.seal_max, "the seal asks for its most, no more (%d)" % world.seal.needed)
	var chunks := ceili(world.map.width / float(DungeonView.CHUNK)) * ceili(world.map.height / float(DungeonView.CHUNK))
	check(world._view.chunk_count() == chunks, "the map is drawn in chunks the renderer can skip (%d)" % world._view.chunk_count())
	var mist := world._view.mist
	check(mist.visible and mist.get_index() == world._view.get_child_count() - 1 and mist.mask.get_width() == world.map.width + DungeonView.OUTSIDE_MARGIN * 2 and mist.light_field == world.lights and mist.z_index > LightField.Z, "the mist covers the whole map, lit by the floor's light, drawn over it")
	world.build_floor(9, CONTENT)
	check(world.arena != null and world.map.width == config.width, "boss floors keep their size")
	world.difficulty = before
	game.depth = 2
	game._enter_floor()
	await _frames(3)

