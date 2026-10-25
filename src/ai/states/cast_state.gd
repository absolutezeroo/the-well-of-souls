extends State
## Telegraphed skill: the monster stops, glows and shows the area, then the skill goes off.
## The aim is locked when the cast starts, so the player can get out of the way.

var _timer := 0.0
var _cast_time := 0.0
var _aim := Vector2.RIGHT


func _init() -> void:
	every_frame = true


func enter() -> void:
	var skill := actor.casting_skill()
	if skill == null or actor.target == null:
		actor.casting_index = -1  # physics_update switches back to Chase
		return
	actor.move_direction = Vector2.ZERO
	_aim = actor.global_position.direction_to(actor.target.global_position)
	actor.facing = _aim
	_cast_time = skill.cast_time * actor.get_telegraph_scale()
	_timer = _cast_time
	if actor.rig:
		actor.rig.play_cast(_aim, _cast_time, skill.cast_animation)


func exit() -> void:
	actor.telegraph = 0.0


func physics_update(delta: float) -> void:
	if actor.casting_index < 0:
		# Interrupted (a boss changing phase swaps its skills).
		machine.transition_to(&"Chase")
		return
	_timer -= delta
	actor.telegraph = 1.0 - clampf(_timer / maxf(_cast_time, 0.001), 0.0, 1.0)
	if _timer <= 0.0:
		var index := actor.casting_index
		actor.casting_index = -1
		actor.skills.try_use(index, actor, _aim)
		machine.transition_to(&"Chase")
