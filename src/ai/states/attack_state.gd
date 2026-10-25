extends State
## Wind-up (telegraphed), strike, then recovery.
## The aim is locked when the wind-up starts, so the player can dodge by moving.

enum Phase { WINDUP, RECOVER }

var _phase := Phase.WINDUP
var _timer := 0.0
var _aim := Vector2.RIGHT


func _init() -> void:
	every_frame = true


func enter() -> void:
	actor.move_direction = Vector2.ZERO
	_aim = actor.global_position.direction_to(actor.target.global_position)
	actor.facing = _aim
	_phase = Phase.WINDUP
	_timer = actor.get_attack_windup()
	if actor.rig:
		actor.rig.play_windup(_aim, _timer)


func exit() -> void:
	actor.telegraph = 0.0


func physics_update(delta: float) -> void:
	_timer -= delta
	match _phase:
		Phase.WINDUP:
			actor.telegraph = 1.0 - clampf(_timer / maxf(actor.get_attack_windup(), 0.001), 0.0, 1.0)
			if _timer <= 0.0:
				actor.telegraph = 0.0
				actor.attack(_aim)
				_phase = Phase.RECOVER
				_timer = actor.def.attack_recovery
		Phase.RECOVER:
			if _timer <= 0.0:
				machine.transition_to(&"Chase")
