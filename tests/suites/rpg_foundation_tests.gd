class_name RpgFoundationTests
extends TestSuite
## First RPG foundations exercised through the existing game: independent command producers
## and session lifetime. The world, rewards and persistence still follow the legacy run mode.


func run_unit() -> void:
	_test_command_buffers()
	_test_session_lifetime()
	_test_local_adapter()


func _test_command_buffers() -> void:
	var source := BufferedPlayerInput.new()
	var other := BufferedPlayerInput.new()
	var command := PlayerCommand.new()
	command.movement = Vector2(3, 4)
	command.attack_pressed = true
	command.attack_held = true
	command.skills_pressed = 1
	source.submit(command)
	command.movement = Vector2.LEFT
	command.attack_pressed = false
	var sampled := source.sample()
	check(is_equal_approx(sampled.movement.length(), 1.0) and sampled.movement.x > 0,
		"submitted movement is bounded and independent of later caller edits")
	check(sampled.attack_pressed and sampled.attack_held and sampled.skills_pressed == 1,
		"a command preserves its held state and its one-shot intentions")
	var reused := source.sample()
	check(reused == sampled and not reused.attack_pressed and reused.skills_pressed == 0
		and reused.attack_held and reused.movement.x > 0,
		"sampling reuses a buffer, consumes presses once and keeps held movement/attack")
	check(other.sample().movement == Vector2.ZERO and not other.sample().attack_held,
		"command sources never share another controller's held state")
	command.clear()
	command.skills_pressed = 1
	source.submit(command)
	command.skills_pressed = 2
	command.quick_item_pressed = true
	source.submit(command)
	check(source.sample().skills_pressed == 3 and sampled.quick_item_pressed,
		"several updates before a step preserve all presses instead of losing an earlier one")
	command.movement = Vector2(INF, NAN)
	command.skills_pressed = 1 << 20
	command.belt_pressed = -1
	source.submit(command)
	sampled = source.sample()
	check(sampled.movement == Vector2.ZERO and sampled.skills_pressed == 0 and sampled.belt_pressed == 0,
		"non-finite movement, unknown slots and negative slot masks cannot become actions")
	command.clear()
	command.attack_held = true
	command.movement = Vector2.RIGHT
	source.submit(command)
	source.reset()
	check(source.sample().movement == Vector2.ZERO and not source.sample().attack_held,
		"reset stops held movement and attack when a producer is detached")


func _test_session_lifetime() -> void:
	var one := GameSession.new()
	var two := GameSession.new()
	var hero := (load("res://src/entities/player/player.tscn") as PackedScene).instantiate() as Player
	var world := World.new()
	one.character = hero
	one.enter_expedition(RunState.new(), world)
	two.enter_expedition(RunState.new(), world)
	var ticket := one.capture()
	check(one.is_current(ticket) and not two.is_current(ticket) and one.generation == two.generation,
		"session tickets distinguish owners even when generation numbers match")
	one.leave_expedition()
	check(one.character == hero and one.expedition == null and not one.is_current(ticket),
		"leaving an expedition invalidates its work without destroying the character")
	one.enter_expedition(RunState.new(), world)
	check(one.character == hero and not one.is_current(ticket) and one.is_current(one.capture()),
		"a new expedition can retain a hero while old continuations stay invalid")
	ticket = one.capture()
	one.close()
	check(not one.is_current(ticket) and not one.is_current(null) and one.character == hero,
		"closing invalidates work while exit listeners can still inspect the character")
	hero.free()
	world.free()


func _test_local_adapter() -> void:
	var local := LocalPlayerInput.new()
	Input.action_press("move_right")
	Input.action_press("attack")
	var command := local.sample()
	check(command.movement.x > 0.0 and command.attack_held, "local input still turns the shared actions into intentions")
	Input.action_release("move_right")
	Input.action_release("attack")
	check(local.sample() == command and command.movement == Vector2.ZERO and not command.attack_held,
		"local input reuses its frame and does not latch released controls")


func run_game(game: Game) -> void:
	await _clear_monsters(game.world)
	var first := game.player
	var second := (load("res://src/entities/player/player.tscn") as PackedScene).instantiate() as Player
	second.world = game.world
	second.setup(CONTENT.player)
	(second.get_node("Camera") as GameCamera).enabled = false
	second.position = first.global_position + Vector2(90, 0)
	game.world.add_entity(second)
	first.process_mode = Node.PROCESS_MODE_DISABLED
	second.process_mode = Node.PROCESS_MODE_DISABLED
	var input_one := BufferedPlayerInput.new()
	var input_two := BufferedPlayerInput.new()
	first.controls.set_source(input_one)
	second.controls.set_source(input_two)
	first._think(1.0 / 60.0)
	second._think(1.0 / 60.0)  # consume any unpause edge before starting the test
	var attacks := [0, 0]
	var skills := [0, 0]
	first.attacked.connect(func() -> void: attacks[0] += 1)
	second.attacked.connect(func() -> void: attacks[1] += 1)
	first.skill_used.connect(func(_slot: int) -> void: skills[0] += 1)
	second.skill_used.connect(func(_slot: int) -> void: skills[1] += 1)
	var command := PlayerCommand.new()
	command.movement = Vector2.RIGHT
	command.attack_pressed = true
	input_one.submit(command)
	command.clear()
	command.movement = Vector2.UP
	input_two.submit(command)
	first._think(1.0 / 60.0)
	second._think(1.0 / 60.0)
	check(first.get_move_direction() == Vector2.RIGHT and second.get_move_direction() == Vector2.UP,
		"two live heroes execute independent movement intentions")
	check(attacks == [1, 0], "only the hero whose producer pressed attack swings")
	Input.action_press("attack")
	Input.action_press("move_left")
	first._attack_cooldown = 0.0
	second._attack_cooldown = 0.0
	first._think(1.0 / 60.0)
	second._think(1.0 / 60.0)
	Input.action_release("attack")
	Input.action_release("move_left")
	check(attacks == [1, 0] and first.get_move_direction() == Vector2.RIGHT and second.get_move_direction() == Vector2.UP,
		"global keyboard actions cannot leak into heroes using independent producers")
	command.skills_pressed = 1  # the innate roll is slot zero
	input_two.submit(command)
	second._think(1.0 / 60.0)
	check(skills == [0, 1], "a skill intention belongs to its own hero")
	input_two.submit(command)
	second._think(1.0 / 60.0)
	check(skills == [0, 1], "repeated intentions cannot bypass the existing skill cooldown")
	command.clear()
	command.attack_pressed = true
	command.attack_held = true
	command.skills_pressed = 1
	first.controls.mute_presses()
	input_one.submit(command)
	first._think(1.0 / 60.0)
	check(attacks == [1, 0] and skills == [0, 1], "closing a menu still mutes one-shot actions in the command path")
	first.controls.set_source(null)
	first._think(1.0 / 60.0)
	check(first.get_move_direction() == Vector2.ZERO and first.charge.state == AttackCharge.State.IDLE,
		"detaching a source stops movement and cancels charging without firing")
	second.free()
	first.controls.set_source(LocalPlayerInput.new())
	first.process_mode = Node.PROCESS_MODE_INHERIT
	await _test_stale_continuations(game)


func _test_stale_continuations(game: Game) -> void:
	check(game.session.character == game.player and game.session.expedition == game.run and game.session.world == game.world,
		"the real Game's compatibility views belong to its session")
	var old := game.session.capture()
	game.player.give_up()  # the old death screen is awaiting its timer
	game.start_run()
	game.player.invincible = true
	check(not game.session.is_current(old) and game.session.is_current(game.session.capture()),
		"restarting the real Game invalidates the previous expedition")
	await _frames(100)
	check(not game.game_over_panel.visible and game.end_facts == null and not game.player.is_dead,
		"an old death timer cannot show a game-over screen over the restarted expedition")
	old = game.session.capture()
	game._on_stairs_reached()  # scheduled descent, before it can begin
	game.start_run()
	game.player.invincible = true
	await _frames(3)
	check(game.depth == 1 and not game.session.is_current(old) and not game.is_menu_open(),
		"a descent scheduled by an old expedition cannot advance the new one")
	game._on_stairs_reached()
	await _frames(3)  # the old fade has now started, rather than just being scheduled
	game.start_run()
	game.player.invincible = true
	await _frames(35)
	var fade := game.get_node("Fade/Black") as ColorRect
	check(game.depth == 1 and is_zero_approx(fade.color.a) and not game.is_menu_open(),
		"an in-progress old fade cannot darken or pause the restarted expedition")
