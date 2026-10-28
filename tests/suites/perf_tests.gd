class_name PerfTests
extends TestSuite
## The performance work's shortcuts give the answers the plain ways gave (docs/performance.md):
## a cache or a smaller loop must never change what the game decides or shows.


## No game running (from UnitTests).
func run_unit() -> void:
	# Input names by slot, as constants: one per slot, each a real action.
	check(PlayerControls.SKILL_ACTIONS.size() == Player.SKILL_COUNT, "one skill action per skill slot")
	check(PlayerControls.BELT_ACTIONS.size() == Belt.SLOTS, "one belt action per belt slot")
	var missing: Array[String] = []
	for i in PlayerControls.SKILL_ACTIONS.size():
		if PlayerControls.SKILL_ACTIONS[i] != StringName("skill_%d" % (i + 1)) or not InputMap.has_action(PlayerControls.SKILL_ACTIONS[i]):
			missing.append(String(PlayerControls.SKILL_ACTIONS[i]))
	for i in range(1, PlayerControls.BELT_ACTIONS.size()):  # (slot 1 is the quick item's own action)
		if PlayerControls.BELT_ACTIONS[i] != StringName("belt_%d" % (i + 1)) or not InputMap.has_action(PlayerControls.BELT_ACTIONS[i]):
			missing.append(String(PlayerControls.BELT_ACTIONS[i]))
	check(missing.is_empty(), "the skill and belt actions are the project's (wrong: %s)" % ", ".join(missing))
	var four: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	check(GridDirs.FOUR == four, "the grid's four steps keep their order (it decides ties: the same seed, the same floor)")
	_test_body_tops()
	_test_shared_looks()
	_test_idle_ui()
	await _test_pools()
	await _test_quiet_loops()


## The interface's helpers cost nothing at rest: a list's drag helper only runs while a let-go
## list glides, the dialogue's "more" arrow only while shown, and the title's picture is drawn
## again 12 times a second, not 60.
func _test_idle_ui() -> void:
	var list := ScrollContainer.new()
	add_child(list)
	var helper := TouchScroll.attach(list)
	check(not helper.is_processing(), "a list at rest: its drag helper doesn't run")
	list.queue_free()
	var arrow := DialogueBox.MoreArrow.new()
	arrow.visible = false
	add_child(arrow)
	check(not arrow.is_processing(), "the dialogue's hidden arrow doesn't run")
	arrow.show()
	check(arrow.is_processing(), "...shown, it bobs")
	arrow.queue_free()
	check(TitleBackdrop.REDRAW_FPS <= 15.0, "the title's picture is drawn again at most 15 times a second")


## A node done with goes back to its pool (out of the tree at the frame's end) and comes out the
## same node; a full pool frees the rest. A damage number is drawn again only when it shows
## something new (a whole art pixel up, a cut of its fade), not 45 times in its life.
func _test_pools() -> void:
	var pool := NodePool.new()
	pool.limit = 2
	var nodes: Array[Node2D] = []
	for i in 3:
		var node := Node2D.new()
		add_child(node)
		nodes.append(node)
		pool.give(node)
	check(nodes[0].is_inside_tree(), "a node given back stays in the tree until the frame ends")
	await get_tree().process_frame
	check(not nodes[0].is_inside_tree() and not nodes[1].is_inside_tree() and pool.idle_count() == 2 and not is_instance_valid(nodes[2]),
		"then it is out of the tree and kept; one more than the pool holds is freed")
	var back := pool.take()
	check(back == nodes[1] and pool.idle_count() == 1, "the pool hands the same node back")
	pool.clear()
	check(not is_instance_valid(nodes[0]) and pool.idle_count() == 0, "a pool cleared frees what it kept")
	back.free()
	var number := FloatingText.create(Vector2.ZERO, "12", Color.WHITE)
	var keys := 0
	var last := -1
	var t := 0.0
	while t < FloatingText.LIFETIME:
		number._age = t
		var key := number._draw_key()
		if key != last:
			keys += 1
			last = key
		t += 1.0 / 60.0
	check(keys <= 24, "a damage number is drawn again %d times in its %d frames, not every frame" % [keys, roundi(FloatingText.LIFETIME * 60.0)])
	number.free()


## The menus' and the hints' loops at rest: MenuNav keeps the group's menus until one comes or
## goes (no group scan, no dictionary a frame); the tutorial looks around only while a hint of
## the world's cues is still to see; a weapon's aura keeps its list of motes.
func _test_quiet_loops() -> void:
	await get_tree().process_frame
	var menus: Array[Node] = MenuNav._menus
	await get_tree().process_frame
	check(is_same(menus, MenuNav._menus), "MenuNav doesn't scan the menus' group again while none comes or goes")
	var menu := Control.new()
	add_child(menu)
	menu.add_to_group(MenuNav.GROUP)
	await get_tree().process_frame
	check(MenuNav._menus.has(menu) and MenuNav.top_menu() == menu, "...and finds a new one at once")
	var with_it := MenuNav._menus.size()
	menu.free()
	await get_tree().process_frame
	check(MenuNav._menus.size() == with_it - 1 and MenuNav._menus.all(func(n: Node) -> bool: return is_instance_valid(n)), "...and lets a closed one go")
	var tutorial := Tutorial.new()
	tutorial.def = CONTENT.tutorial
	Profile.reset()
	check(tutorial._world_cues_left(), "a new profile: the tutorial looks around for its cues")
	for hint in CONTENT.tutorial.hints:
		Profile.mark_hint(hint.id)
	check(not tutorial._world_cues_left(), "every hint seen: it stops looking (no group scans, no lines of sight)")
	Profile.reset()
	tutorial.free()
	var aura := WeaponAura.new()
	add_child(aura)
	aura.set_elements([load("res://data/vfx/elements/fire.tres") as VfxElementDef])
	aura._emitters = PackedVector2Array([Vector2(1, 1), Vector2(2, 3), Vector2(4, 2)])
	var motes := aura._motes
	for i in 40:
		aura._process(0.1)
	check(is_same(motes, aura._motes) and not aura._motes.is_empty(), "a weapon's aura ages its motes in place (%d alive)" % aura._motes.size())
	aura.free()


## The weapon at rest bobs with the body's art (BodyTops.bob): every frame of the hero measured
## on its sheet's copy, read back once, gives the top row a readback of the frame itself gives.
func _test_body_tops() -> void:
	var frames: SpriteFrames = load("res://data/visuals/hero.tres")
	BodyTops.warm(frames)
	var wrong: Array[String] = []
	var measured := 0
	for animation in frames.get_animation_names():
		for i in frames.get_frame_count(animation):
			var texture := frames.get_frame_texture(animation, i)
			var image := texture.get_image()
			if image == null:
				continue
			if image.is_compressed():
				image.decompress()
			measured += 1
			if BodyTops.top_of(texture) != image.get_used_rect().position.y:
				wrong.append("%s %d" % [animation, i])
	check(measured > 0, "the hero's frames can be measured here (%d)" % measured)
	check(wrong.is_empty(), "each body frame's top measured on its sheet's copy is its own (wrong: %s)" % ", ".join(wrong.slice(0, 5)))


## On the game's floor (from GameTests): the monsters' spacing and the free points.
## Its own rats only, freed after: the floor's monsters stay for the bot's hunt.
func run_in_game(world: World, player: Player) -> void:
	var rat: MonsterDef = load("res://data/monsters/rat.tres")
	var spawned: Array[Monster] = []
	for i in 24:
		var at := world.nearest_free_point(player.global_position + Vector2.from_angle(TAU * i / 24.0) * (60.0 + 6.0 * (i % 5)))
		spawned.append(world.spawn_monster(rat, at))
	await _frames(15)  # (they wake and crowd)
	_check_buckets(world)
	_check_nearest_free_point(world, player)
	await _check_crowd(world, spawned)
	await _check_pools_in_game(world, player)
	for monster in spawned:
		if is_instance_valid(monster):
			monster.queue_free()
	await _frames(2)


## Shots and numbers come from their pools (docs/performance.md "Pools"): fired again, a shot is
## a new one (its hits, its flight); monsters called in come one a frame.
func _check_pools_in_game(world: World, player: Player) -> void:
	var shots := world.get_node("Projectiles")
	var spec := ProjectileSpec.new()
	spec.speed = 600.0
	spec.max_distance = 40.0
	spec.damage = 1
	world.fire_projectiles(player, Vector2.RIGHT, spec)
	world.fire_projectiles(player, Vector2.LEFT, spec)
	await _frames(12)
	var kept := world.spawns.shot_pool.idle_count()
	check(kept >= 2 and shots.get_child_count() == 0, "shots that landed are kept for later, out of the tree (%d kept)" % kept)
	world.fire_projectiles(player, Vector2.UP, spec)
	await _frames(1)
	var again := shots.get_child(0) as Projectile if shots.get_child_count() > 0 else null
	check(world.spawns.shot_pool.idle_count() == kept - 1 and again != null and not again._done and again.visible and again._travelled < spec.max_distance and again._already_hit.is_empty(),
		"a shot fired again comes from the pool, as new")
	await _frames(12)
	for i in 4:
		world.spawn_floating_text(player.head_position(), "7", Color.WHITE)
	await _frames(roundi(FloatingText.LIFETIME * 60.0) + 4)
	var numbers := world.spawns.text_pool.idle_count()
	var effects := world.get_node("Effects").get_child_count()
	world.spawn_floating_text(player.head_position(), "8", Color.WHITE)
	await _frames(1)
	check(numbers >= 4 and world.spawns.text_pool.idle_count() == numbers - 1 and world.get_node("Effects").get_child_count() <= effects + 1,
		"a damage number done goes back to its pool, and the next one comes out of it (%d kept)" % numbers)
	# Called in: one a frame, never a crowd made in one frame.
	var before := world.monster_count()
	var rat: MonsterDef = load("res://data/monsters/rat.tres")
	world.spawns.defer_monsters([rat], 3, player.global_position + Vector2(80, 0), 30.0, player)
	var counts: Array[int] = []
	for i in 4:
		await get_tree().process_frame
		counts.append(world.monster_count() - before)
	check(counts[0] == 1 and counts[1] == 2 and counts[2] == 3 and counts[3] == 3, "monsters called in come one a frame (%s)" % str(counts))
	var summon := SummonEffect.new()
	summon.monsters = [rat]
	summon.count = 3
	summon.max_alive = 999
	before = world.monster_count()
	summon.apply(player, Vector2.RIGHT)
	var at_once := world.monster_count() - before
	await _frames(3)
	check(at_once == 1 and world.monster_count() - before == 3, "a summoner's call: the first at once, the others one a frame (%d, then %d)" % [at_once, world.monster_count() - before])
	for monster in world.get_hostiles(player.faction):
		if (monster as Monster).def == rat and (monster as Monster).global_position.distance_to(player.global_position) < 140.0:
			monster.queue_free()
	await _frames(2)


## Every monster close enough to push another (MonsterSteering.keep_spacing) is among those its grid
## cells hand it, in the awake list's order: the push sums the same floats as over the whole list.
func _check_buckets(world: World) -> void:
	var awake := world.activity.awake
	check(awake.size() >= 10, "a crowd is awake for the spacing check (%d)" % awake.size())
	var missed := 0
	var unsorted := 0
	for entry: Variant in awake:
		if not is_instance_valid(entry):
			continue
		var monster := entry as Monster
		var near := world.activity.buckets.near(awake, monster.global_position, monster.radius + MonsterSteering.SPACING)
		for i in range(1, near.size()):
			if near[i] <= near[i - 1]:
				unsorted += 1
		for j in awake.size():
			var other: Variant = awake[j]
			if not is_instance_valid(other) or other == monster:
				continue
			var limit := monster.radius + (other as Monster).radius + MonsterSteering.SPACING
			if monster.global_position.distance_to((other as Monster).global_position) < limit and not near.has(j):
				missed += 1
	check(missed == 0, "the spacing grid hands every monster all those close enough to push it (%d missed)" % missed)
	check(unsorted == 0, "and in the awake list's order")


## A crowd's per-monster work (docs/performance.md, "A crowd"): the spacing push summed one frame
## in SPACING_EVERY and kept between; a plain monster's overlays drawn again only when what they
## show changes (its health); a body out of view keeps only its timers.
func _check_crowd(world: World, crowd: Array[Monster]) -> void:
	var monster: Monster = null
	for one in crowd:
		if is_instance_valid(one) and not one.is_dead and one.rank == null:
			monster = one
			break
	if monster == null:
		check(false, "a plain monster in the crowd")
		return
	var summed := 0
	var last := monster.steering._push_frame
	for i in MonsterSteering.SPACING_EVERY * 4:
		await get_tree().physics_frame
		if monster.steering._push_frame != last:
			summed += 1
			last = monster.steering._push_frame
	check(summed >= 3 and summed <= 5, "the spacing push is summed one frame in %d (%d times in %d frames)" % [MonsterSteering.SPACING_EVERY, summed, MonsterSteering.SPACING_EVERY * 4])
	var over: MonsterOverlay = monster.get_node("Over")
	var under: MonsterOverlay = monster.get_node("Under")
	await _frames(2)
	check(not over._needs_redraw() and not under._needs_redraw(), "a plain monster's overlays aren't drawn again while nothing they show changes")
	monster.hp -= 1
	check(over._needs_redraw(), "its health bar is, once it is hurt")
	monster.hp += 1
	var at := monster.global_position
	monster.global_position = world.view_rect().position - Vector2(500, 500)
	check(not monster._in_view(), "out of view, its body's look waits")
	monster.global_position = at
	check(monster._in_view(), "back in view, it is kept up again")


## World.nearest_free_point() walks only its rings' cells now: the same cell as the whole square's
## scan in reading order (ties included) for points all over the floor.
func _check_nearest_free_point(world: World, player: Player) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bodies := world.get_actors()
	var differ := 0
	for attempt in 60:
		var point := Vector2(rng.randf() * world.map.width, rng.randf() * world.map.height) * world.map.tile_size
		var room := 10.0 if attempt % 3 == 0 else 0.0
		var clear_of: Array[Actor] = bodies if attempt % 2 == 0 else ([] as Array[Actor])
		if world.nearest_free_point(point, 12, clear_of, room, room) != _square_scan(world, point, 12, clear_of, room, room):
			differ += 1
	check(differ == 0, "the nearest free point is the square scan's (%d of 60 differ)" % differ)
	check(world.nearest_free_point(player.global_position, 0) != Vector2.INF, "a ring of radius 0 is the cell itself")


## nearest_free_point() as it was written first: the whole square at each radius, the ring kept.
func _square_scan(world: World, point: Vector2, max_radius: int, clear_of: Array[Actor], clearance: float, room: float) -> Vector2:
	var map := world.map
	var origin := map.world_to_cell(point)
	for radius in max_radius + 1:
		var best := Vector2i(-1, -1)
		var best_distance := INF
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				if maxi(absi(x - origin.x), absi(y - origin.y)) != radius:
					continue
				var cell := Vector2i(x, y)
				var distance := map.cell_to_world(cell).distance_squared_to(point)
				if distance < best_distance and world.is_free_cell(cell) and not WorldSpace.is_under_body(map.cell_to_world(cell), clear_of, clearance) \
						and (room <= 0.0 or world.body_fits(map.cell_to_world(cell), room)):
					best = cell
					best_distance = distance
		if best != Vector2i(-1, -1):
			return map.cell_to_world(best)
	return point


## A crowd batches (docs/performance.md, "Draw calls"): bodies at rest showing the same wear one
## shared material, a body with something moving on it (a flash, a death) its own with every
## uniform as before, and back to the shared one at rest; a body whose layers follow it never
## shares. Shadows are on their own node one step down.
func _test_shared_looks() -> void:
	var a_node := Node2D.new()
	var b_node := Node2D.new()
	var a := BodyLook.new(_own_material(a_node))
	var b := BodyLook.new(_own_material(b_node))
	var a_own := a.material
	a.set_frame(Rect2(-8, -16, 16, 16))
	b.set_frame(Rect2(-8, -16, 16, 16))
	a.share_on(a_node)
	b.share_on(b_node)
	check(a.is_sharing() and b.is_sharing() and a_node.material == b_node.material and a_node.material != a_own, "two bodies at rest showing the same: one shared material")
	a.set_shared(&"flash_amount", 1.0)
	check(not a.is_sharing() and a_node.material == a_own and a_own.get_shader_parameter(&"flash_amount") == 1.0 and b.is_sharing(), "a flash: that body on its own material, the uniform set there")
	a.set_shared(&"flash_amount", 0.0)
	check(a.is_sharing() and a_node.material == b_node.material, "at rest again: back on the shared one")
	b.set_frame(Rect2(-12, -24, 24, 24))
	check(b.is_sharing() and a_node.material != b_node.material, "another frame: another shared material (what it shows)")
	b.die(load("res://data/vfx/deaths/ash.tres"), null)
	check(not b.is_sharing() and b_node.material == b.material, "a death: its own material")
	var follower := ShaderMaterial.new()
	a.follow(follower)
	a.set_shared(&"flash_amount", 0.0)
	check(not a.is_sharing() and a_node.material == a_own, "layers following it (the hero's): never shared")
	a_node.free()
	b_node.free()
	var actor := Actor.new()
	add_child(actor)
	check(actor.shadow != null and actor.shadow.z_index == -1 and actor.shadow.get_parent() == actor, "an actor's shadow on its own node, one step down (a crowd's shadows batch)")
	actor.free()


func _own_material(node: CanvasItem) -> ShaderMaterial:
	var own := ShaderMaterial.new()
	own.shader = BodyLook.SHADER
	node.material = own
	return own
