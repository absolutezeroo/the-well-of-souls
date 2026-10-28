class_name FeelTests
extends TestSuite
## The feel limits (docs/design/presentation.md "Feel limits"), checked after the audit of
## 2026-10-28: no freeze inside a slow; one kick per blow; a shake on whole art pixels decaying
## in real time; the hurt vignette among the screen's flashes. On a game: one input buffer of
## 0.12 s for the attack, the roll and the skills, counted in real time, the newest press winning;
## the charged attack without holding (decision 0011); the phone buzzing only for what matters;
## one damage number per body in a crowd.


func run_unit() -> void:
	await _test_no_freeze_in_slow()
	await _test_camera()
	_test_vignette()


func run_game(game: Game) -> void:
	await _test_input_buffer(game)
	await _test_tap_to_charge(game)
	await _test_haptics_and_numbers(game)


# --- Unit ----------------------------------------------------------------------

## A freeze never comes inside a slow (Celeste's guard); a freeze asked first still holds, then
## the slow (a killing blow).
func _test_no_freeze_in_slow() -> void:
	HitStop.reset()
	HitStop.slow(0.3, 0.4)
	HitStop.freeze(0.1)
	check(is_equal_approx(Engine.time_scale, 0.4) and not HitStop.is_frozen(), "feel: no freeze during a slow")
	HitStop.reset()
	HitStop.freeze(0.08)
	HitStop.slow(0.3, 0.4)
	check(HitStop.is_frozen() and Engine.time_scale < 0.4, "feel: a killing blow's stop holds, its slow comes after")
	HitStop.reset()
	await get_tree().process_frame


## One blow on a crowd kicks the view once (the strongest push of the frame, not their sum); the
## shake moves the view by whole art pixels and fades in real time, a hit stop or not; a shake
## never buzzes the phone.
func _test_camera() -> void:
	var holder := Node2D.new()
	var camera := GameCamera.new()
	holder.add_child(camera)
	add_child(holder)
	var shake_kept := Settings.screen_shake
	Settings.screen_shake = 1.0
	await get_tree().physics_frame
	for i in 5:
		camera.kick(Vector2.RIGHT, 3.5)
	camera.kick(Vector2.RIGHT, 6.0)
	check(is_equal_approx(camera.kick_offset().length(), 6.0), "feel: a blow on six bodies kicks the view once, as its strongest (%.1f px)" % camera.kick_offset().length())
	await get_tree().physics_frame
	camera.kick(Vector2.RIGHT, 3.5)
	check(camera.kick_offset().length() > 6.0, "feel: the next frame's blow kicks again")
	var buzzes := Settings.buzzes
	camera.shake(1.0)
	check(Settings.buzzes == buzzes, "feel: a shake never buzzes the phone by itself")
	var whole := true
	for i in 10:
		camera._process(1.0 / 60.0)
		var jolt := camera.offset - camera.kick_offset().round()
		whole = whole and is_equal_approx(fmod(absf(jolt.x), PixelDraw.PX), 0.0) and is_equal_approx(fmod(absf(jolt.y), PixelDraw.PX), 0.0)
	check(whole, "feel: the shake moves the view by whole art pixels")
	# Under a freeze the world's delta is a twentieth: the shake still fades by the clock.
	camera.shake(1.0)
	var trauma := camera.trauma()
	HitStop.freeze(0.3)
	await _frames(12)
	check(camera.trauma() < trauma - GameCamera.DECAY * 0.1, "feel: the shake fades in real time during a hit stop (%.2f -> %.2f)" % [trauma, camera.trauma()])
	HitStop.reset()
	Settings.screen_shake = shake_kept
	holder.free()


## The red edges when hurt are a screen flash: off with Screen flashes, at most three a second
## with the lightning's (a burn's ticks merge into one).
func _test_vignette() -> void:
	var vignette := DamageVignette.new()
	var flashes_kept := Settings.screen_flashes
	Settings.screen_flashes = true
	ScreenEffects._last_flash_ms = -100000
	vignette.on_health_changed(100, 100)
	vignette.on_health_changed(90, 100)
	vignette.on_health_changed(85, 100)
	vignette.on_health_changed(80, 100)
	check(vignette.flashes == 1, "feel: hurt three times at once, the edges flash once (%d)" % vignette.flashes)
	ScreenEffects._last_flash_ms = -100000
	Settings.screen_flashes = false
	vignette.on_health_changed(70, 100)
	check(vignette.flashes == 1, "feel: no red flash with Screen flashes off")
	Settings.screen_flashes = flashes_kept
	vignette.free()


# --- Game ----------------------------------------------------------------------

## One buffer of 0.12 s for the attack, the roll and the skills (PlayerDef.input_buffer), counted
## in real time: a press while the weapon still swings is carried out when it can be, but not
## long after; through a hit stop it neither is lost nor waits for ever; the newest press wins.
func _test_input_buffer(game: Game) -> void:
	var player := game.player
	var world := game.world
	player.xp = -1000000
	await _clear_monsters(world)
	check(is_equal_approx(player.tuning().input_buffer, 0.12), "input: the buffer is 0.12 s")
	var attacks := [0]
	var rolls := [0]
	var count_attack := func() -> void: attacks[0] += 1
	var count_skill := func(index: int) -> void:
		if index == 0:
			rolls[0] += 1
	player.attacked.connect(count_attack)
	player.skill_used.connect(count_skill)
	var press := func(action: StringName) -> void:
		_set_action(action, true)
		await _frames(2)
		_set_action(action, false)
	# A press while the weapon still swings: carried out when it can.
	player._attack_cooldown = 0.08
	await press.call(&"attack")
	check(attacks[0] == 0 and player.controls.buffered_press() == PlayerControls.ATTACK_PRESS, "input: a press while the weapon swings waits in the buffer")
	await _frames(6)
	check(attacks[0] == 1, "input: ...and swings as soon as it can (%d)" % attacks[0])
	# Too early: the buffer forgets it.
	await _frames(30)
	player._attack_cooldown = 0.3
	await press.call(&"attack")
	await _frames(30)
	check(attacks[0] == 1 and player.controls.buffered_press() == PlayerControls.NO_PRESS, "input: a press long before the weapon is ready is forgotten after 0.12 s")
	# Through a hit stop: the buffer counts real seconds.
	await _frames(30)
	player._attack_cooldown = 0.02
	HitStop.freeze(0.06)
	await press.call(&"attack")
	await _frames(8)
	check(attacks[0] == 2, "input: a press during a hit stop is carried out after it")
	await _frames(30)
	player._attack_cooldown = 0.2
	HitStop.freeze(0.1)
	await press.call(&"attack")
	await _frames(25)
	check(attacks[0] == 2, "input: a hit stop doesn't stretch the buffer (it counts real seconds)")
	HitStop.reset()
	# The roll: pressed just before it is ready, it rolls when it is.
	await _frames(30)
	player.skills._cooldowns[0] = 0.05
	await press.call(&"skill_1")
	await _frames(8)
	check(rolls[0] == 1, "input: a roll pressed just before it is ready goes when it is (%d)" % rolls[0])
	await _frames(70)
	player.skills._cooldowns[0] = 0.3
	await press.call(&"skill_1")
	await _frames(30)
	check(rolls[0] == 1, "input: a roll pressed long before it is ready is forgotten")
	# The newest press wins: an attack waiting, then a roll: the roll, and no attack after.
	await _frames(70)
	player.skills._cooldowns[0] = 0.0
	player._attack_cooldown = 0.08
	await press.call(&"attack")
	await press.call(&"skill_1")
	await _frames(20)
	check(rolls[0] == 2 and attacks[0] == 2, "input: the newest press wins (a roll pressed after an attack waiting: the roll alone)")
	player.attacked.disconnect(count_attack)
	player.skill_used.disconnect(count_skill)
	await _frames(40)


## Tap to charge (decision 0011): a double tap starts the charge, it fills with the button up,
## the next tap unleashes it once full (a tap before that waits for it); a roll cancels it; off,
## a double tap is two attacks.
func _test_tap_to_charge(game: Game) -> void:
	var player := game.player
	var katana: WeaponDef = load("res://data/items/weapons/katana.tres")
	player.equipment.equip(katana)
	var unleashed := [0]
	var count_charged := func(_attack: ChargedAttackDef) -> void: unleashed[0] += 1
	player.charged_attack.connect(count_charged)
	var tap := func() -> void:
		_set_action(&"attack", true)
		await _frames(2)
		_set_action(&"attack", false)
		await _frames(2)
	var kept := Settings.tap_to_charge
	Settings.tap_to_charge = false
	await _frames(40)
	await tap.call()
	await tap.call()
	await _frames(10)
	check(not player.charge.is_charging(), "charge: without the option a double tap never charges")
	Settings.tap_to_charge = true
	await _frames(40)
	await tap.call()
	await tap.call()
	await _frames(4)
	check(player.charge.is_charging() and not Input.is_action_pressed(&"attack"), "charge: with Tap to charge a double tap charges, the button up")
	await _frames(30)
	check(player.charge.is_charging() and player.controls.aim_hold > 0.0, "charge: while it charges he keeps facing his aim (the closest enemy)")
	var filled: bool = await _until_full(player)
	check(filled and unleashed[0] == 0, "charge: ...it fills by itself and waits")
	await _frames(20)
	await tap.call()
	await _frames(4)
	check(unleashed[0] == 1 and not player.charge.is_charging(), "charge: a tap unleashes it (%d)" % unleashed[0])
	# A tap before it is full: unleashed once it is.
	await _frames(40)
	await tap.call()
	await tap.call()
	await tap.call()
	check(player.charge.is_charging() and not player.charge.is_full() and unleashed[0] == 1, "charge: a tap before it is full waits for it")
	await _frames(90)
	check(unleashed[0] == 2, "charge: ...then it goes off")
	# A roll cancels it.
	await _frames(40)
	await tap.call()
	await tap.call()
	player.skills._cooldowns[0] = 0.0
	player.use_skill(0)
	await _frames(90)
	check(not player.charge.is_charging() and unleashed[0] == 2, "charge: a roll cancels a charge without holding")
	Settings.tap_to_charge = kept
	player.charged_attack.disconnect(count_charged)
	await _frames(40)


func _until_full(player: Player) -> bool:
	for i in 120:
		if player.charge.is_full():
			return true
		await _frames(1)
	return player.charge.is_full()


## The phone buzzes for a crit and for the hero hurt, never for an ordinary hit, a big shake or a
## boss's step; one damage number per body takes a crowd's blows (summed).
func _test_haptics_and_numbers(game: Game) -> void:
	var player := game.player
	var world := game.world
	player.xp = -1000000
	await _clear_monsters(world)
	var vibrations_kept := Settings.vibrations
	Settings.vibrations = true
	var target := world.spawn_monster(load("res://data/monsters/slime.tres"), player.global_position + Vector2(50, 0))
	target.dormant = true
	target.base_stats.max_hp = 100000
	target.invalidate_stats()
	target.hp = 100000
	await _frames(2)
	var blow := func(crit: bool) -> void:
		var hit := HitInfo.new()
		hit.source = player
		hit.amount = 10
		hit.is_crit = crit
		target.take_hit(hit)
	OS.delay_msec(Settings.MIN_VIBRATION_GAP_MS + 10)
	var buzzes := Settings.buzzes
	blow.call(false)
	Events.screen_shake.emit(0.9)
	check(Settings.buzzes == buzzes, "haptics: an ordinary hit and a big shake don't buzz")
	OS.delay_msec(Settings.MIN_VIBRATION_GAP_MS + 10)
	blow.call(true)
	check(Settings.buzzes == buzzes + 1, "haptics: a crit buzzes")
	OS.delay_msec(Settings.MIN_VIBRATION_GAP_MS + 10)
	player.take_hit(Combat.make_secondary_hit(target, 1))
	check(Settings.buzzes == buzzes + 2, "haptics: the hero hurt buzzes")
	Settings.vibrations = vibrations_kept
	# Damage numbers: three blows at once, one number with their sum.
	HitFeedback._numbers.clear()
	await _frames(60)
	var before := _numbers_over(world)
	var hp_before := target.hp
	for i in 3:
		blow.call(false)
	await _frames(1)
	var fresh: Array[FloatingText] = []
	for number in _numbers_over(world):
		if not before.has(number):
			fresh.append(number)
	check(fresh.size() == 1, "numbers: three blows on one body at once show one number (%d)" % fresh.size())
	check(fresh.size() == 1 and fresh[0].shown_text() == str(hp_before - target.hp), "numbers: ...their sum (%s for %d)" % [fresh[0].shown_text() if not fresh.is_empty() else "-", hp_before - target.hp])
	target.queue_free()
	await _frames(40)


func _numbers_over(world: World) -> Array[FloatingText]:
	var found: Array[FloatingText] = []
	for node in _all_under(world):
		if node is FloatingText and not node.is_queued_for_deletion():
			found.append(node)
	return found


static func _all_under(node: Node) -> Array[Node]:
	var found: Array[Node] = [node]
	for child in node.get_children():
		found.append_array(_all_under(child))
	return found
