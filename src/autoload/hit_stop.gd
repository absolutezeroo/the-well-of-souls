extends Node
## Hit stop (autoload "HitStop"): freezes the game for a few frames on impacts,
## which makes hits feel much heavier. Calls overlap: the longest freeze wins.
## Also slow motion (`slow`): a strong kill slows the world for a moment. A freeze asked first
## wins over it (the killing blow's stop, then its slow); none is asked during it.
## Between them the world runs at the debug panel's game speed (DebugCheats.time_scale(), 1 but
## in debug builds).
##
## Hits land during physics, after this frame's delta was already scaled by the time scale in
## effect when the frame began: real time is the delta divided by *that* scale (`real_delta`),
## never by the one just set. That scale is read when the frame begins (its first physics step,
## before anything there can change it), so it holds for every node asking during the frame, not
## only for this one.

const FROZEN_TIME_SCALE := 0.05

var enabled := true
var _remaining := 0.0
var _slow_remaining := 0.0
var _slow_scale := 1.0
## The time scale this frame's deltas were scaled with (the one in effect when it began).
var _applied_scale := 1.0
## The time scale seen at this frame's first physics step (-1: no step yet this frame).
var _scale_at_first_step := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100  # before everyone who asks for real_delta()
	# (Connected first, autoloads being ready before the game: this runs before any other
	# listener of the step, or anything a step does, can change the time scale.)
	get_tree().physics_frame.connect(_on_physics_frame)


## Real seconds behind a `delta` of this frame (whatever the hit stop or slow motion), asked in
## _process or in _physics_process (there the frame's scale is the one its first physics step
## saw: _process has not run yet to keep it, and the last frame's would be wrong on the first
## and the last frames of a freeze).
func real_delta(delta: float) -> float:
	var scale := _scale_at_first_step if _scale_at_first_step >= 0.0 else _applied_scale
	return delta / maxf(scale, 0.001)


## Freezes for `duration` real seconds: calls overlap (the longest wins, never their sum), and
## none freezes while a slow runs (Celeste's guard: a stop inside a slow reads as a stutter).
func freeze(duration: float) -> void:
	if not enabled or duration <= 0.0 or is_slowed():
		return
	_remaining = maxf(_remaining, duration)
	Engine.time_scale = FROZEN_TIME_SCALE


## A slow runs (and no freeze over it).
func is_slowed() -> bool:
	return _slow_remaining > 0.0 and _remaining <= 0.0


## A freeze holds the world.
func is_frozen() -> bool:
	return _remaining > 0.0


## The world runs at `time_scale` for `duration` real seconds.
func slow(duration: float, time_scale: float) -> void:
	if not enabled or duration <= 0.0:
		return
	_slow_scale = minf(_slow_scale, time_scale) if _slow_remaining > 0.0 else time_scale
	_slow_remaining = maxf(_slow_remaining, duration)
	if _remaining <= 0.0:
		Engine.time_scale = _slow_scale


func reset() -> void:
	_remaining = 0.0
	_slow_remaining = 0.0
	_slow_scale = 1.0
	Engine.time_scale = DebugCheats.time_scale()
	# (Not _applied_scale: this frame's deltas were scaled already. The next frame starts at 1.)


func _on_physics_frame() -> void:
	if _scale_at_first_step < 0.0:
		_scale_at_first_step = Engine.time_scale


func _process(delta: float) -> void:
	# The scale this frame began with: seen at its first physics step, or now when it had none
	# (then nothing ran before this, the first process callback, to change it).
	_applied_scale = _scale_at_first_step if _scale_at_first_step >= 0.0 else Engine.time_scale
	_scale_at_first_step = -1.0
	var real := real_delta(delta)
	if _remaining > 0.0:
		_remaining -= real
		if _remaining <= 0.0:
			_remaining = 0.0
			Engine.time_scale = _slow_scale if _slow_remaining > 0.0 else DebugCheats.time_scale()
	elif _slow_remaining > 0.0:
		_slow_remaining -= real
		if _slow_remaining <= 0.0:
			_slow_remaining = 0.0
			_slow_scale = 1.0
			Engine.time_scale = DebugCheats.time_scale()
