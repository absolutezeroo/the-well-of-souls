class_name PlayerControls
extends RefCounted
## Executes a hero's intentions (Player.controls): samples its own command source each step,
## walks, aims at the closest
## enemy in sight, turns the attack button into swings, a charge and its unleashing
## (AttackCharge, Player.unleash()), and presses the skill and belt buttons. The Player acts;
## this decides when and toward where. LocalPlayerInput is the Input adapter; other producers
## do not read global actions. Skill costs and cooldowns still belong to gameplay components.

## Keep facing the aim direction this long after attacking.
const AIM_HOLD_TIME := 0.35
## What waits in the input buffer: nothing, the attack, or else a skill slot (0: the roll).
const NO_PRESS := -2
const ATTACK_PRESS := -1
## The skill and belt buttons' input actions, by slot (read every frame: no name formatted).
const SKILL_ACTIONS: Array[StringName] = PlayerCommand.SKILL_ACTIONS
const BELT_ACTIONS: Array[StringName] = PlayerCommand.BELT_ACTIONS

## Where the stick or the keys push him this frame (length 0..1).
var move_direction := Vector2.ZERO
## Seconds he keeps facing his last aim, whatever way he walks.
var aim_hold := 0.0

var _player: Player
var _source: PlayerCommandSource = LocalPlayerInput.new()
## Controller-owned snapshot; neither a source nor another hero can edit it during execution.
var _command := PlayerCommand.new()
## The newest press not yet carried out (ATTACK_PRESS, a skill slot, NO_PRESS) and the real
## seconds it still waits (PlayerDef.input_buffer): one buffer for the attack, the roll and the
## skills, the newest press taking the place of an older one, used up when carried out.
var _buffered := NO_PRESS
var _buffer_left := 0.0
## Tap to charge (Settings.tap_to_charge): the charge goes on with the button up (a double tap
## started it, or the hold that started it was let go early), the next tap unleashes it once it
## is full, and the real seconds since the last plain tap (a second within
## PlayerDef.double_tap_window starts a charge).
var _latched := false
var _release_queued := false
var _since_tap := INF
## The game just came out of a pause: the press that closed the menu (a gamepad's B closes and
## is skill 2 too) belongs to the menu, so the first frame after it reads no new press.
var _presses_muted := false


func _init(player: Player) -> void:
	_player = player


## One source per controller. Changing it cancels buffered attacks, never unleashes a charge.
func set_source(source: PlayerCommandSource) -> void:
	_source = source if source else PlayerCommandSource.new()
	_command.clear()
	move_direction = Vector2.ZERO
	aim_hold = 0.0
	_buffered = NO_PRESS
	_buffer_left = 0.0
	_unlatch()
	_player.charge.cancel()


## Once per physics step, before movement and actions consume the same snapshot.
func sample() -> void:
	_command.copy_from(_source.sample())


## The next frame reads no new press (the game was just unpaused: see _presses_muted).
func mute_presses() -> void:
	_presses_muted = true


## Keeps facing the aim a moment (an attack, a skill, a charge).
func hold_aim() -> void:
	aim_hold = AIM_HOLD_TIME


## The stick or the keys: where he walks, and faces when no aim holds him.
func read_move(delta: float) -> void:
	aim_hold = maxf(aim_hold - delta, 0.0)
	move_direction = _command.movement
	if move_direction != Vector2.ZERO and aim_hold <= 0.0:
		_player.facing = move_direction.normalized()


## The buttons: the attack (and its charge), the skills, the belt.
func act(delta: float) -> void:
	var player := _player
	var fresh := not _presses_muted  # (a press that closed a menu: see _presses_muted)
	_presses_muted = false
	# The buffer counts real seconds: a hit stop neither eats a press nor stretches its wait.
	var real := HitStop.real_delta(delta)
	_buffer_left = maxf(_buffer_left - real, 0.0)
	if _buffer_left <= 0.0:
		_buffered = NO_PRESS
	_since_tap += real
	update_attack(delta, fresh)

	for i in mini(player.skills.skills.size(), SKILL_ACTIONS.size()):  # (one per skill slot: Player.SKILL_COUNT)
		if fresh and player.skills.skills[i] and (_command.skills_pressed & (1 << i)) != 0:
			_buffer_press(i)
	# A skill (the roll first) waiting in the buffer goes as soon as it is ready.
	if _buffered >= 0 and player.skills.is_ready(_buffered):
		use_skill(_buffered)

	if fresh and _command.quick_item_pressed:
		player.pack.use_quick_item()
	for i in range(1, Belt.SLOTS):
		if fresh and (_command.belt_pressed & (1 << i)) != 0:
			player.pack.use_belt(i)


## The attack button: a tap swings (or shoots) once, aimed at the closest enemy; holding it
## no longer repeats the swing, it charges the weapon's charged attack (AttackCharge), unleashed
## when the button is let go with the charge full (docs/design/interface.md). With Tap to charge
## (Settings.tap_to_charge, decision 0011: an alternative to holding) a double tap starts the
## charge too, a charge let go early keeps filling, and a tap unleashes it once full. `fresh`
## false: a press seen now closed a menu, it doesn't swing (held on, it charges).
func update_attack(delta: float, fresh: bool = true) -> void:
	var player := _player
	var charge := player.charge
	var weapon := player.get_weapon()
	var charged := weapon.charged if weapon else null
	var tap_mode := Settings.tap_to_charge and charged != null
	if _latched and (not tap_mode or not charge.is_charging()):
		_unlatch()  # cancelled meanwhile (a roll, a swap, a fall), or the option turned off
	var skip_delay := false
	if fresh and _command.attack_pressed:
		if tap_mode and _latched:
			_release_queued = true  # unleashed as soon as it is full
			_since_tap = INF
		elif tap_mode and _since_tap <= player.def.double_tap_window:
			# The second tap of a double tap: no swing, the charge starts and fills by itself.
			_latched = true
			skip_delay = true
			_since_tap = INF
			charge.press()
		else:
			_buffer_press(ATTACK_PRESS)
			_since_tap = 0.0
			charge.press()
	if player.is_falling:
		charge.cancel()  # a fall loses the charge (a roll or a dash: start_dash)
	# Tap to charge: a charge let go before it is full keeps filling (never wasted).
	if tap_mode and not _latched and not _command.attack_held and charge.state == AttackCharge.State.CHARGING:
		_latched = true
	if _command.attack_held or _latched:
		if charged:
			match charge.hold(delta, 0.0 if skip_delay else player.def.charge_delay, charged.charge_time):
				AttackCharge.State.CHARGING:
					player.charge_started.emit()
				AttackCharge.State.FULL:
					Sfx.play_at(player.def.charge_full_sound, player.global_position)
					player.charge_full.emit()
		if _latched and _release_queued and charge.is_full():
			_unlatch()
			if charge.release() and weapon:
				player.unleash(weapon, charged)
	elif charge.state != AttackCharge.State.IDLE:
		if charge.release() and charged and weapon:
			player.unleash(weapon, charged)
	if charge.is_charging() and _buffered == ATTACK_PRESS:
		_buffered = NO_PRESS
		# Winding up toward the closest enemy; with none in sight, the way he walks.
		var target := aim_target(player.tuning().skill_aim_range)
		if target:
			player.facing = player.global_position.direction_to(target.global_position)
		elif move_direction != Vector2.ZERO:
			player.facing = move_direction.normalized()
		hold_aim()
	if player.rig:
		player.rig.show_charge(weapon if charge.is_charging() else null)
	if _buffered == ATTACK_PRESS and player.can_attack():
		_buffered = NO_PRESS
		if player.attack(aim_direction(_auto_aim_range())):
			player.attacked.emit()
		hold_aim()


## Skill button `index` (0: the roll), aimed at the closest enemy in a skill's range. Returns
## whether it went off (then any older press waiting in the buffer is dropped: the newest wins).
func use_skill(index: int) -> bool:
	var player := _player
	var aim := aim_direction(player.tuning().skill_aim_range)
	if not player.skills.try_use(index, player, aim):
		return false
	_buffered = NO_PRESS
	_unlatch()
	player.charge.cancel()  # a skill (the roll first) loses the charge
	player.facing = aim
	hold_aim()
	player.skill_used.emit(index)
	return true


## A press of the attack (ATTACK_PRESS) or of skill slot `press`: the newest press, it takes the
## buffer's place for PlayerDef.input_buffer real seconds (carried out at once when it can be).
func _buffer_press(press: int) -> void:
	_buffered = press
	_buffer_left = _player.tuning().input_buffer


## What waits in the input buffer (ATTACK_PRESS, a skill slot, NO_PRESS; tests).
func buffered_press() -> int:
	return _buffered


## Tap to charge: the charge no longer goes on by itself.
func _unlatch() -> void:
	_latched = false
	_release_queued = false


## Direction to the closest visible enemy in range, or the current facing.
func aim_direction(max_range: float) -> Vector2:
	var target := aim_target(max_range)
	if target:
		return _player.global_position.direction_to(target.global_position)
	return _player.facing


## The closest enemy in sight within `max_range` (from its body's edge), or null.
func aim_target(max_range: float) -> Actor:
	var player := _player
	var best: Actor = null
	var best_distance := max_range
	for enemy in player.world.get_hostiles(player.faction):
		var distance := player.global_position.distance_to(enemy.global_position) - enemy.radius
		if distance < best_distance and player.world.has_line_of_sight(player.global_position, enemy.global_position):
			best = enemy
			best_distance = distance
	return best


## How far a swing looks for someone to turn to: a blade's reach and its aim assist, a shot's range.
func _auto_aim_range() -> float:
	var player := _player
	var weapon := player.get_weapon()
	if weapon == null:
		return 0.0
	if weapon.kind == WeaponDef.Kind.MELEE:
		return player.radius + weapon.reach + player.tuning().melee_aim_assist
	return weapon.reach
