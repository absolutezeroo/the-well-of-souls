class_name LocalPlayerInput
extends PlayerCommandSource
## The sole Input adapter for a locally controlled hero's movement and combat. Keyboard,
## gamepad and touch still press the same actions. No frame arrays or action-name formatting.


func sample() -> PlayerCommand:
	_sample.movement = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_sample.attack_pressed = Input.is_action_just_pressed("attack")
	_sample.attack_held = Input.is_action_pressed("attack")
	_sample.quick_item_pressed = Input.is_action_just_pressed("quick_item")
	_sample.skills_pressed = 0
	_sample.belt_pressed = 0
	for i in PlayerCommand.SKILL_ACTIONS.size():
		if Input.is_action_just_pressed(PlayerCommand.SKILL_ACTIONS[i]):
			_sample.skills_pressed |= 1 << i
	for i in range(1, PlayerCommand.BELT_ACTIONS.size()):
		if Input.is_action_just_pressed(PlayerCommand.BELT_ACTIONS[i]):
			_sample.belt_pressed |= 1 << i
	return _sample
