class_name DebugTests
extends TestSuite
## The debug panel's tools (DebugPanel, DebugCheats, DebugGallery): the cheats' rules and their
## hooks, the debug run that keeps nothing, the gallery's floors and halls, the panel itself.
## run_unit() from the unit suite, run_game() on the game suite's game.


func run_unit() -> void:
	_test_cheat_rules()
	_test_gallery_data()


## Off by default; each step does what it says, to whom it says, and nothing else.
func _test_cheat_rules() -> void:
	DebugCheats.reset()
	var hero := (load("res://src/entities/player/player.tscn") as PackedScene).instantiate() as Player
	var monster := (load("res://src/entities/monster/monster.tscn") as PackedScene).instantiate() as Monster
	monster.hp = 100
	var from_hero := Combat.make_secondary_hit(hero, 10)
	var from_monster := Combat.make_secondary_hit(monster, 10)
	check(DebugCheats.summary() == "" and not DebugCheats.debug_run and not DebugCheats.invisible and not DebugCheats.no_ai \
		and not DebugCheats.no_cooldowns and not DebugCheats.show_shapes and not DebugCheats.show_stats \
		and not DebugCheats.full_light and not DebugCheats.reveal_maps, "every cheat is off by default")
	check(DebugCheats.scale_damage(from_hero, monster, 10) == 10 and DebugCheats.scale_damage(from_monster, hero, 10) == 10 \
		and DebugCheats.speed_factor() == 1.0 and DebugCheats.time_scale() == 1.0 and DebugCheats.zoom() == 1.0 \
		and DebugCheats.cooldown(hero, 3.0) == 3.0 and DebugCheats.can_be_noticed(hero) and not DebugCheats.ai_frozen(),
		"off, the hooks change nothing")
	DebugCheats.set_full_light(true)
	check(DebugCheats.full_light and not DebugCheats.debug_run, "full light alone is no debug run")
	DebugCheats.set_full_light(false)
	DebugCheats.set_damage_step(DebugCheats.DAMAGE_STEPS.find(5.0))
	check(DebugCheats.scale_damage(from_hero, monster, 10) == 50 and DebugCheats.scale_damage(from_monster, hero, 10) == 10 \
		and DebugCheats.scale_damage(Combat.make_secondary_hit(monster, 10), monster, 10) == 10, "damage x5: the hero's blows only")
	DebugCheats.set_damage_step(DebugCheats.DAMAGE_STEPS.find(DebugCheats.ONE_SHOT))
	monster.ward = 7
	check(DebugCheats.scale_damage(from_hero, monster, 3) == 107, "one-shot: all of its Health and ward")
	monster.ward = 0
	DebugCheats.set_armor_step(DebugCheats.ARMOR_STEPS.find(0.25))
	check(DebugCheats.scale_damage(from_monster, hero, 20) == 5 and DebugCheats.scale_damage(from_monster, hero, 1) == 1, "armor step: a quarter of the blows taken, never less than 1")
	DebugCheats.set_speed_step(DebugCheats.SPEED_STEPS.find(2.0))
	DebugCheats.set_no_cooldowns(true)
	check(DebugCheats.speed_factor() == 2.0 and DebugCheats.cooldown(hero, 3.0) == 0.0 and DebugCheats.cooldown(monster, 3.0) == 3.0, "speed x2, no cooldowns for the hero alone")
	DebugCheats.set_invisible(true)
	check(not DebugCheats.can_be_noticed(hero) and DebugCheats.can_be_noticed(monster), "invisible: only the hero goes unnoticed")
	check(DebugCheats.debug_run and Profile.held, "a cheat makes a debug run: the profile is held")
	check(DebugCheats.summary().contains("invisible") and DebugCheats.summary().contains("damage one-shot"), "the overlay names the cheats on: %s" % DebugCheats.summary())
	check(DebugCheats.next_step(DebugCheats.SPEED_STEPS.size() - 1, DebugCheats.SPEED_STEPS) == 0, "steps wrap to x1")
	DebugCheats.reset()
	check(DebugCheats.summary() == "" and not DebugCheats.debug_run and not Profile.held and DebugCheats.scale_damage(from_hero, monster, 10) == 10, "reset: everything off, the profile free again")
	DebugCheats.set_time_step(DebugCheats.TIME_STEPS.find(0.5))
	check(not DebugCheats.debug_run, "the game's speed alone is no debug run")
	HitStop.reset()
	check(is_equal_approx(Engine.time_scale, 0.5), "game speed x0.5 is the world's time scale")
	DebugCheats.reset()
	HitStop.reset()
	check(Engine.time_scale == 1.0, "back to x1")
	hero.free()
	monster.free()


## Every biome, every monster in some scope, halls that hold their monsters, biome copies that
## force a shape without touching the biome.
func _test_gallery_data() -> void:
	var dungeon := CONTENT.dungeon
	var biomes := DebugGallery.biomes(CONTENT)
	var act_biomes := 0
	for act in dungeon.acts:
		for biome in act.biomes:
			if biomes.has(biome):
				act_biomes += 1
	check(act_biomes >= 9 and biomes.has(dungeon.hidden_floor.biome) and biomes.has(dungeon.finale.biome), "the gallery lists every biome (%d), the hidden floor's and the Well's bottom's" % biomes.size())
	var scopes := DebugGallery.scopes(CONTENT)
	var everything: Array[MonsterDef] = scopes.back().monsters
	var missing: Array[String] = []
	var wanted: Array[MonsterDef] = CONTENT.all_monsters()
	wanted.append_array(CONTENT.abyss_monsters())
	for act in dungeon.acts:
		wanted.append_array(act.all_bosses())
	wanted.append(dungeon.finale.boss)
	wanted.append_array(dungeon.hidden_floor.monsters)
	wanted.append(dungeon.hidden_floor.boss)
	for def in wanted:
		if def and not everything.has(def):
			missing.append(String(def.id))
	check(missing.is_empty(), "the gallery's Everything holds every monster and boss (%d; missing %s)" % [everything.size(), missing])
	var boss_floors: Array[String] = []
	for scope in scopes:
		if dungeon.boss_for_depth(scope.depth):
			boss_floors.append(scope.name)
	check(boss_floors.is_empty(), "every gallery is built on a floor without a boss (%s)" % [boss_floors])
	# The halls: every body on floor, none on another.
	var bad: Array[String] = []
	for scope in scopes:
		var hall := DebugGallery.hall(dungeon, scope.monsters)
		var hall_map: DungeonMap = hall.map
		var spots: Array[Vector2] = hall.spots
		if spots.size() != scope.monsters.size() or not hall_map.is_floor(hall_map.start_cell) or not hall_map.is_floor(hall_map.stairs_cell):
			bad.append("%s: %d spots" % [scope.name, spots.size()])
			continue
		for i in spots.size():
			var radius := scope.monsters[i].radius
			for corner in [Vector2(-radius, -radius), Vector2(radius, radius)]:
				if not hall_map.is_floor(hall_map.world_to_cell(spots[i] + corner)):
					bad.append("%s: %s off the floor" % [scope.name, scope.monsters[i].id])
			for j in range(i + 1, spots.size()):
				if spots[i].distance_to(spots[j]) < radius + scope.monsters[j].radius + 8.0:
					bad.append("%s: %s on %s" % [scope.name, scope.monsters[i].id, scope.monsters[j].id])
	check(bad.is_empty(), "the gallery halls hold their monsters apart, on the floor (%s)" % [bad.slice(0, 4)])
	# A forced shape, a forced signature room: the copy's, never the biome's.
	var biome: BiomeDef = dungeon.acts[0].biomes[0]
	var shape: RoomShapeDef = biome.room_shapes[0]
	var shapes_before := biome.room_shapes.duplicate()
	var copy := DebugGallery.variant(biome, shape, null, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var map := DungeonGenerator.generate(dungeon, rng, 1.0, 1.0, copy, 2)
	var shaped := 0
	var others := 0
	for i in range(1, map.rooms.size()):
		if map.plan(i).shape and map.plan(i).shape.id == shape.id:
			shaped += 1
		else:
			others += 1
	check(shaped >= 2 and others == 0 and biome.room_shapes == shapes_before and copy.ceiling == null and biome.ceiling != null,
		"a forced shape: every room but the first is %s (%d), the biome untouched, no ceiling on the copy" % [shape.id, shaped])
	var piece: RoomShapeDef = biome.set_pieces[0]
	copy = DebugGallery.variant(biome, piece, null, true)
	map = DungeonGenerator.generate(dungeon, rng, 1.0, 1.0, copy, 2)
	var pieces := 0
	for i in map.rooms.size():
		if map.plan(i).is_set_piece():
			pieces += 1
	check(pieces == 1 and copy.ceiling == biome.ceiling, "a forced signature room: there on the floor, the biome's own ceiling kept")


func run_game(game: Game) -> void:
	var depth_before := game.depth
	var player := game.player
	var debug := game.menus.debug
	if debug == null:
		return
	# The panel's god mode before this made a debug run (DebugTests asks for a clean slate).
	check(DebugCheats.debug_run, "the panel's god mode makes a debug run")
	DebugCheats.reset()
	player.invincible = false
	await _test_panel(game, debug)
	await _test_no_ai(game)
	await _test_invisible(game)
	await _test_hero_cheats(game)
	_test_debug_run(game)
	await _test_world_tools(game, debug)
	await _test_pockets(game, debug)
	await _test_gallery(game, debug)
	if debug.visible:
		debug.close()
	DebugCheats.reset()
	HitStop.reset()
	game.player.camera.fit_zoom()
	await game.debug.enter_floor(depth_before)
	await _clear_monsters(game.world)
	game.player.invincible = false


## Six tabs that fit the screen, reached with the tab keys; the toggles say their state.
func _test_panel(game: Game, debug: DebugPanel) -> void:
	game.open_debug()
	await _frames(2)
	check(debug.visible and debug.tab_count() == 6 and debug.tab_index() == 0, "the panel opens on its first tab, of six")
	check(debug.find_child("WorldTab", true, false).get_parent() is TabRow, "its tabs are a TabRow, like every window's")
	var too_big: Array[String] = []
	for i in debug._pages.size():
		debug.show_tab(i)
		await _frames(1)
		var page := debug._pages[i] as ScrollContainer
		var inside: Control = page.get_children().filter(func(child: Node) -> bool: return child is VBoxContainer)[0]
		if inside.size.x > page.size.x + 1.0 or inside.get_combined_minimum_size().y > page.size.y + 1.0:
			too_big.append("%s %s in %s" % [page.name, inside.get_combined_minimum_size(), page.size])
	check(too_big.is_empty(), "every tab fits the screen without scrolling (%s)" % [too_big])
	debug.show_tab(0)
	check(MenuNav.top_menu() == debug and MenuNav.focusables(debug).size() > 20, "keys and gamepads reach the panel's buttons (MenuNav)")
	MenuNav.switch_tab(debug, 1)
	check(debug.tab_index() == 1, "the tab keys switch its tabs")
	MenuNav.switch_tab(debug, -2)
	check(debug.tab_index() == 5, "and wrap round")
	var invisible := debug.find_child("Invisible", true, false) as Button
	invisible.pressed.emit()
	check(DebugCheats.invisible and invisible.text == "Invisible: ON" and invisible.button_pressed, "a toggle says it is on")
	invisible.pressed.emit()
	var damage := debug.find_child("Damage", true, false) as Button
	damage.pressed.emit()
	check(DebugCheats.damage_step == 1 and damage.text == "Damage x2", "a step says its value: %s" % damage.text)
	DebugCheats.reset()
	debug.close()
	await _frames(2)
	check(not get_tree().paused, "closed, the game goes on")


## No AI: monsters (a boss too) stand, strike nothing, cast nothing; off, they come again.
func _test_no_ai(game: Game) -> void:
	var world := game.world
	var player := game.player
	await _clear_monsters(world)
	# Away from traps, quicksand and fires: only the monsters could move them or hurt the hero.
	player.global_position = _quiet_point(world, player.global_position)
	await _stand_still(world, player)
	var skeleton: MonsterDef = load("res://data/monsters/skeleton.tres")
	var boss_def: BossDef = CONTENT.dungeon.acts[0].boss
	DebugCheats.set_no_ai(true)
	var near := world.spawn_monster(skeleton, world.find_open_point_near(player.global_position + Vector2(40, 0), 20.0))
	var boss := world.spawn_monster(boss_def, world.find_open_point_near(player.global_position + Vector2(-120, 0), 60.0, boss_def.radius))
	near.target = player
	boss.target = player
	var at := [near.global_position, boss.global_position]
	var hp := player.hp
	await _frames(120)
	check(near.global_position.distance_to(at[0]) < 2.0 and boss.global_position.distance_to(at[1]) < 2.0 and player.hp == hp \
		and near.telegraph == 0.0 and boss.telegraph == 0.0,
		"No AI: a monster and a boss beside the hero stand still and strike nothing for two seconds")
	for i in 6:
		boss.take_hit(Combat.make_secondary_hit(player, 1))
		player._invulnerable_time = 0.0
	await _frames(30)
	check(player.hp == hp and boss.brain.shockwave_cooldown == 0.0, "No AI: a boss hit again and again throws no shockwave")
	DebugCheats.set_no_ai(false)
	await _frames(120)
	check(near.global_position.distance_to(at[0]) > 2.0 or player.hp < hp or near.telegraph > 0.0 or near._attack_cooldown > 0.0, "No AI off: the monster comes again")
	DebugCheats.reset()
	await _clear_monsters(world)


## Invisible: in sight, struck, or sent by an ambush, a monster never keeps after the hero.
func _test_invisible(game: Game) -> void:
	var world := game.world
	var player := game.player
	# The monster in his sight for sure: a clear lane from a quiet spot (a point 60 px off picked
	# blindly can be behind a wall or a pillar from where he stands, and then it never sees him).
	var lane := _clear_lane(world, _quiet_point(world, player.global_position), 120.0)
	if lane.is_empty():
		return
	player.global_position = lane[0]
	await _stand_still(world, player)
	var skeleton: MonsterDef = load("res://data/monsters/skeleton.tres")
	DebugCheats.set_invisible(true)
	var monster := world.spawn_monster(skeleton, player.global_position + (lane[1] as Vector2) * 60.0)
	check(world.has_line_of_sight(monster.global_position, player.global_position) and monster.global_position.distance_to(player.global_position) < monster.detect_radius(),
		"set up: the monster stands in the hero's sight, within its reach")
	# Its blows on the hero, counted (not his Health: a blow cast before, by a monster of the last
	# test cleared since, may still land; slime rain did, with --seed=77).
	var struck := [0]
	var count_blow := func(actor: Actor, hit: HitInfo, _damage: int) -> void:
		if actor == player and hit.source == monster:
			struck[0] += 1
	Events.actor_damaged.connect(count_blow)
	await _frames(90)
	check(monster.target == null and struck[0] == 0, "invisible: a monster in sight never notices the hero")
	monster.target = player  # an ambush, a chest, a camp's watch send it after him
	monster.take_hit(Combat.make_secondary_hit(player, 1))  # and so does a blow
	await _frames(30)
	check(monster.target == null and struck[0] == 0, "invisible: sent after him or struck, it forgets him")
	Events.actor_damaged.disconnect(count_blow)
	# Back in his sight (the blow's push, or its wandering while he was unseen, may have taken it
	# behind a pillar: --seed=286597).
	monster.global_position = player.global_position + (lane[1] as Vector2) * 60.0
	monster.velocity = Vector2.ZERO
	DebugCheats.set_invisible(false)
	await _frames(60)
	check(monster.target == player, "visible again: it notices him (%d px, in sight %s, awake %s)" % [monster.global_position.distance_to(player.global_position), world.has_line_of_sight(monster.global_position, player.global_position), monster.is_awake])
	DebugCheats.reset()
	await _clear_monsters(world)


## The damage and armor steps through the real damage pipeline, speed, cooldowns, zoom.
func _test_hero_cheats(game: Game) -> void:
	var world := game.world
	var player := game.player
	var skeleton: MonsterDef = load("res://data/monsters/skeleton.tres")
	DebugCheats.set_no_ai(true)
	var monster := world.spawn_monster(skeleton, world.find_open_point_near(player.global_position + Vector2(80, 0), 20.0))
	monster.base_stats.max_hp = 100000
	monster.invalidate_stats()
	monster.hp = monster.get_max_hp()
	var before := monster.hp
	monster.take_hit(Combat.make_secondary_hit(player, 20))
	var plain := before - monster.hp
	DebugCheats.set_damage_step(DebugCheats.DAMAGE_STEPS.find(10.0))
	before = monster.hp
	monster.take_hit(Combat.make_secondary_hit(player, 20))
	check(plain > 0 and before - monster.hp == plain * 10, "damage x10 in a real hit (%d, then %d)" % [plain, before - monster.hp])
	DebugCheats.set_damage_step(DebugCheats.DAMAGE_STEPS.find(DebugCheats.ONE_SHOT))
	monster.take_hit(Combat.make_secondary_hit(player, 1))
	check(monster.is_dead, "one-shot kills whatever its Health")
	player.invincible = false
	player._invulnerable_time = 0.0
	player.heal(player.get_max_hp())
	player.ward = 0  # (a ward from an earlier test's perk or rune would soak the blow)
	var hp := player.hp
	player.take_hit(Combat.make_secondary_hit(null, 40))
	var taken := hp - player.hp
	DebugCheats.set_armor_step(DebugCheats.ARMOR_STEPS.find(0.25))
	player._invulnerable_time = 0.0
	player.heal(player.get_max_hp())
	player.ward = 0
	hp = player.hp
	player.take_hit(Combat.make_secondary_hit(null, 40))
	check(taken > 0 and hp - player.hp == maxi(1, roundi(taken * 0.25)), "armor step x0.25 in a real hit (%d, then %d; dead %s, invulnerable %s)" % [taken, hp - player.hp, player.is_dead, player._invulnerable_time])
	player.heal(player.get_max_hp())
	var speed := player.get_move_speed()
	DebugCheats.set_speed_step(DebugCheats.SPEED_STEPS.find(2.0))
	check(is_equal_approx(player.get_move_speed(), speed * 2.0), "speed x2")
	var slot := -1
	for i in player.skills.skills.size():
		if player.skills.skills[i] != null and player.skills.skills[i].cooldown > 0.0:
			slot = i
			break
	check(slot >= 0, "the hero has a skill with a cooldown")
	if slot >= 0:
		DebugCheats.set_no_cooldowns(true)
		player.skills.reset_cooldown(player.skills.skills[slot])
		check(player.skills.try_use(slot, player, Vector2.RIGHT) and player.skills.is_ready(slot), "no cooldowns: a skill is ready again at once")
		DebugCheats.set_no_cooldowns(false)
		await _frames(30)
		player.skills.reset_cooldown(player.skills.skills[slot])
		player.skills.try_use(slot, player, Vector2.RIGHT)
		# (An echo perk the hero picked up earlier may leave it ready once; a cast an echo made
		# ready never echoes: SkillEchoPassive.)
		player.skills.try_use(slot, player, Vector2.RIGHT)
		check(not player.skills.is_ready(slot), "and off, its cooldown runs again")
	var zoom := player.camera.zoom
	DebugCheats.set_zoom_step(DebugCheats.ZOOM_STEPS.find(0.5))
	player.camera.fit_zoom()
	check(player.camera.zoom.is_equal_approx(zoom * 0.5), "zoom x0.5: twice as much floor on screen")
	DebugCheats.reset()
	player.camera.fit_zoom()
	await _frames(20)
	await _clear_monsters(world)


## A debug run: the run's save stays as it was.
func _test_debug_run(game: Game) -> void:
	game._save_run()
	var saved := RunSave.read()
	DebugCheats.set_invisible(true)
	game.player.add_gold(123)
	game._save_run()
	check(not saved.is_empty() and RunSave.read() == saved and Profile.held, "a debug run is never saved, the profile held")
	check(not game.debug.reload(), "nor saved and picked up again")
	DebugCheats.reset()
	game._save_run()
	check(RunSave.read() != saved and not Profile.held, "a real run again: saved")


## The World and Tools tabs' tools: full light (a view), the maps revealed on every floor, an
## encounter and a fragment placed beside the hero, the boss room, the warden's story again.
func _test_world_tools(game: Game, debug: DebugPanel) -> void:
	DebugCheats.reset()
	game.open_debug()
	await _frames(1)
	var level := game.world.lights.ambient_level
	var light := debug.find_child("FullLight", true, false) as Button
	light.pressed.emit()
	check(DebugCheats.full_light and game.world.lights.ambient_level == LightField.MAX_LEVEL and not DebugCheats.debug_run,
		"full light: the floor at its brightest (%d, was %d), not a debug run" % [game.world.lights.ambient_level, level])
	light.pressed.emit()
	check(not DebugCheats.full_light and game.world.lights.ambient_level == level, "full light off: the floor's own light again")
	var reveal := debug.find_child("RevealMaps", true, false) as Button
	reveal.pressed.emit()
	check(DebugCheats.reveal_maps and reveal.text == "Reveal maps: ON" and game.world.is_explored(game.world.map.stairs_cell) and DebugCheats.debug_run,
		"Reveal maps: this floor's map seen at once, a debug run")
	var encounters := _count(game.world, Encounter)
	debug._encounter_index = 0
	debug._place_encounter()
	check(_count(game.world, Encounter) == encounters + 1, "an encounter placed beside the hero on demand")
	var fragments := _count(game.world, Fragment)
	check(debug._fragments().size() >= CONTENT.dungeon.acts.size(), "the Fragment row lists the wardens' fragments (%d)" % debug._fragments().size())
	debug._fragment_index = debug._fragments().size() - 1
	debug._place_fragment()
	check(_count(game.world, Fragment) == fragments + 1, "a fragment of the past placed beside the hero on demand")
	debug.close()
	await _frames(1)
	DebugCheats.set_no_ai(true)
	await game.debug.enter_floor(debug._next_boss_depth())
	await _frames(2)
	var world := game.world
	check(world.is_explored(world.map.start_cell) and world.is_explored(world.map.boss_room.get_center()), "Reveal maps: the next floor's map is seen as it begins")
	check(world.arena != null and game.debug.boss_story_ready(), "the next boss floor, its warden standing")
	if world.arena == null:
		return
	debug._to_boss_room()
	await _frames(3)
	var cell := world.map.world_to_cell(game.player.global_position)
	var near := world.map.boss_room.grow(4).has_point(cell) and not world.map.boss_room.grow(-1).has_point(cell)
	check(near and not world.arena.is_started, "Boss room: the hero at its doorway (%s, the room %s), the fight not begun" % [cell, world.map.boss_room])
	# (Met on this floor already or not: an earlier test may have fought at this depth.)
	var boss_def := world.arena.boss.def as BossDef
	var meetings := Narrative.meetings(boss_def)
	check(game.debug.boss_story() and game.run.has_met_here() and Narrative.meetings(boss_def) == meetings + 1,
		"Boss story: the warden is met again on demand (%d meetings, then %d)" % [meetings, Narrative.meetings(boss_def)])
	await _frames(2)
	DebugCheats.reset()


## Places reached without dying or falling: the trial of the Threshold opened at once (no feather
## spent), then the Deeps' Dawn Breach a few steps away, and through it home.
func _test_pockets(game: Game, debug: DebugPanel) -> void:
	DebugCheats.reset()
	await game.debug.enter_floor(1)
	await _frames(2)
	var player := game.player
	player.invincible = true
	game.open_debug()
	await _frames(1)
	var trial_button := _button_named(debug, "Threshold trial")
	var breach_button := _button_named(debug, "Dawn Breach")
	check(trial_button != null and breach_button != null, "the World tab's Places: Threshold trial and Dawn Breach")
	if trial_button == null or breach_button == null:
		return
	var feather := game.player.perks.entries.size()
	trial_button.pressed.emit()
	check(await _until_trial(game), "Threshold trial: the trial opens, nobody died")
	check(not player.is_dead and player.perks.entries.size() == feather and DebugCheats.debug_run, "...the hero alive, no perk given or spent, a debug run")
	game.threshold.abort()
	await _frames(2)
	check(not game.threshold.is_open() and player.world == game.world, "...and aborted, back on the floor")
	game.open_debug()
	await _frames(1)
	breach_button.pressed.emit()
	check(await _until(func() -> bool: return game.abyss.is_searching() and player.world == game.abyss.depths, 6.0), "Dawn Breach: down into the Deeps")
	await _frames(2)
	var depths := game.abyss.depths
	var door := depths.map.cell_to_world(depths.map.stairs_cell) if depths else Vector2.INF
	check(depths != null and player.global_position.distance_to(door) < 6.0 * depths.config().tile_size, "...the hero a few steps from the Dawn Breach (%d px)" % player.global_position.distance_to(door))
	if depths:
		player.global_position = door
	check(await _until(func() -> bool: return not game.abyss.is_open(), 8.0), "...stepping into it brings him home")
	player.invincible = false
	await game.debug.enter_floor(1)
	await _frames(2)
	DebugCheats.reset()


## The debug panel's button that says `words` (null if none).
func _button_named(debug: DebugPanel, words: String) -> Button:
	for found in debug.find_children("*", "Button", true, false):
		if (found as Button).text == words:
			return found as Button
	return null


## Cheats on before the game suite starts a new run (a new run frees the hero the suite holds,
## so the suite starts it itself: then check_new_run()).
func arm_for_new_run() -> void:
	DebugCheats.set_invisible(true)
	DebugCheats.set_no_ai(true)
	DebugCheats.set_damage_step(2)
	DebugCheats.set_full_light(true)
	DebugCheats.set_reveal_maps(true)
	DebugCheats.set_time_step(1)


## A new run begun after arm_for_new_run(): every cheat off, the profile free, the clock at its speed.
func check_new_run() -> void:
	check(DebugCheats.summary() == "" and not DebugCheats.debug_run and not Profile.held and is_equal_approx(Engine.time_scale, 1.0),
		"a new run plays the real rules: every cheat off (%s), the profile free" % DebugCheats.summary())


## How many of `kind` stand on `world`'s floor.
func _count(world: World, kind: Variant) -> int:
	var found := 0
	for node in world.find_children("*", "", true, false):
		if is_instance_of(node, kind) and not node.is_queued_for_deletion():
			found += 1
	return found


## A biome's floor with a forced shape and no ceiling; every scope's monster gallery.
func _test_gallery(game: Game, debug: DebugPanel) -> void:
	game.open_debug()
	await _frames(1)
	var biome: BiomeDef = CONTENT.dungeon.acts[1].biomes[0]
	debug._biome_index = debug._biomes.find(biome)
	debug._fill_shapes()
	var shape: RoomShapeDef = biome.room_shapes[0]
	debug._shape = shape
	debug._ceiling_index = -2
	await debug.build_biome_floor()
	await _frames(3)
	var world := game.world
	var shaped := 0
	for i in range(1, world.map.rooms.size()):
		if world.map.plan(i).shape and world.map.plan(i).shape.id == shape.id:
			shaped += 1
	check(not debug.visible and world.theme == biome.theme and shaped == world.map.rooms.size() - 1 and world.ceiling == null \
		and world.is_explored(world.map.stairs_cell) and DebugCheats.debug_run,
		"a biome's floor: its look, every room but the first a %s (%d), no ceiling, the map revealed, a debug run" % [shape.id, shaped])
	# Every biome of the list builds a floor of its own look, with its own ceiling.
	var unbuilt: Array[String] = []
	debug._shape = null
	debug._ceiling_index = -1
	for index in debug._biomes.size():
		var each := debug._biomes[index]
		debug._biome_index = index
		await debug.build_biome_floor()
		await _frames(1)
		world = game.world
		var ceiling_ok := (world.ceiling != null) == (each.ceiling != null and Vfx.shown)
		if world.theme != each.theme or world.map.rooms.size() < 2 or not ceiling_ok or world.arena != null:
			unbuilt.append("%s (%d rooms, ceiling %s)" % [each.display_name, world.map.rooms.size(), world.ceiling != null])
	check(unbuilt.is_empty(), "every biome of the gallery builds a plain floor of its own look and ceiling (%d; wrong %s)" % [debug._biomes.size(), unbuilt])
	var wrong: Array[String] = []
	for index in debug._scopes.size():
		var scope := debug._scopes[index]
		debug._scope_index = index
		await debug.build_monster_gallery()
		await _frames(2)
		world = game.world
		var spots := {}
		var tagged := 0
		for monster in world.get_hostiles(Actor.Faction.PLAYER):
			spots[monster] = monster.global_position
			if monster.get_children().any(func(child: Node) -> bool: return child is DebugGallery.NameTag):
				tagged += 1
		var found: Array[MonsterDef] = []
		for monster: Monster in spots:
			found.append(monster.def)
		var hp := game.player.hp
		await _frames(60)
		var moved := 0
		for monster: Monster in spots:
			if is_instance_valid(monster) and monster.global_position.distance_to(spots[monster]) > 3.0:
				moved += 1
		var absent := scope.monsters.filter(func(def: MonsterDef) -> bool: return not found.has(def))
		if spots.size() != scope.monsters.size() or not absent.is_empty() or tagged != spots.size() or moved > 0 or game.player.hp != hp:
			wrong.append("%s: %d of %d, missing %s, %d named, %d moved" % [scope.name, spots.size(), scope.monsters.size(), absent.map(func(d: MonsterDef) -> StringName: return d.id), tagged, moved])
	check(wrong.is_empty() and DebugCheats.no_ai and DebugCheats.invisible, "every monster gallery holds all its monsters, named, standing still, the hero unharmed (%s)" % [wrong])
