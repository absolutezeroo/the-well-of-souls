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
	for monster in spawned:
		if is_instance_valid(monster):
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
