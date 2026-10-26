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
## A press of the attack button not yet turned into a swing (PlayerDef.attack_buffer).
var _attack_buffer := 0.0
## The game just came out of a pause: the press that closed the menu (a gamepad's B closes and
## is skill 2 too) belongs to the menu, so the first frame after it reads no new press.
var _presses_muted := false


func _init(player: Player) -> void:
	_player = player


## One source per controller. Changing it cancels buffered attacks, never unleashes a charge.
func set_source(source: PlayerCommandSource) -> void:
	_source = source if source else PlayerCommandSource.new()
	cancel_actions()


## Region relocation cancels pending attacks while retaining this controller's producer.
func cancel_actions() -> void:
	_command.clear()
	move_direction = Vector2.ZERO
	aim_hold = 0.0
	_attack_buffer = 0.0
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
	update_attack(delta, fresh)

	for i in mini(player.skills.skills.size(), SKILL_ACTIONS.size()):  # (one per skill slot: Player.SKILL_COUNT)
		if fresh and player.skills.skills[i] and (_command.skills_pressed & (1 << i)) != 0:
			use_skill(i)

	if fresh and _command.quick_item_pressed:
		player.pack.use_quick_item()
	for i in range(1, Belt.SLOTS):
		if fresh and (_command.belt_pressed & (1 << i)) != 0:
			player.pack.use_belt(i)


## The attack button: a tap swings (or shoots) once, aimed at the closest enemy; holding it
## no longer repeats the swing, it charges the weapon's charged attack (AttackCharge), unleashed
## when the button is let go with the charge full (docs/design/interface.md). `fresh` false:
## a press seen now closed a menu, it doesn't swing (held on, it charges).
func update_attack(delta: float, fresh: bool = true) -> void:
	var player := _player
	var charge := player.charge
	var weapon := player.get_weapon()
	var charged := weapon.charged if weapon else null
	_attack_buffer = maxf(_attack_buffer - delta, 0.0)
	if fresh and _command.attack_pressed:
		_attack_buffer = player.tuning().attack_buffer
		charge.press()
	if player.is_falling:
		charge.cancel()  # a fall loses the charge (a roll or a dash: start_dash)
	if _command.attack_held:
		if charged:
			match charge.hold(delta, player.def.charge_delay, charged.charge_time):
				AttackCharge.State.CHARGING:
					player.charge_started.emit()
				AttackCharge.State.FULL:
					Sfx.play_at(player.def.charge_full_sound, player.global_position)
					player.charge_full.emit()
	elif charge.state != AttackCharge.State.IDLE:
		if charge.release() and charged and weapon:
			player.unleash(weapon, charged)
	if charge.is_charging():
		_attack_buffer = 0.0
		# Winding up toward the closest enemy; with none in sight, the way he walks.
		var target := aim_target(player.tuning().skill_aim_range)
		if target:
			player.facing = player.global_position.direction_to(target.global_position)
		elif move_direction != Vector2.ZERO:
			player.facing = move_direction.normalized()
		hold_aim()
	if player.rig:
		player.rig.show_charge(weapon if charge.is_charging() else null)
	if _attack_buffer > 0.0 and player.can_attack():
		_attack_buffer = 0.0
		if player.attack(aim_direction(_auto_aim_range())):
			player.attacked.emit()
		hold_aim()


## Skill button `index` (0: the roll), aimed at the closest enemy in a skill's range.
func use_skill(index: int) -> void:
	var player := _player
	var aim := aim_direction(player.tuning().skill_aim_range)
	if player.skills.try_use(index, player, aim):
		player.charge.cancel()  # a skill (the roll first) loses the charge
		player.facing = aim
		hold_aim()
		player.skill_used.emit(index)


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
