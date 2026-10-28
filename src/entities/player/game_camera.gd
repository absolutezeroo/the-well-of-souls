class_name GameCamera
extends Camera2D
## Follows the player (as its child) and adds screen shake, and kicks: a short push along a
## direction that springs back (the weight of a blow, a shot's recoil), apart from the shake.
## A boss too big for the view makes it lean toward it (lean_toward()).
## Both scale with the Screen shake option.
## Its zoom (the scene's) grows by what PixelGrid's rounding of the canvas's scale took off, so a
## floor fills any screen the same way (PixelGrid.world_zoom()).

const MAX_OFFSET := 10.0
const DECAY := 2.5
## Kicks add up to this many pixels, and come back this fast (per second, exponential).
const MAX_KICK := 10.0
const KICK_RETURN := 18.0

## The view leans this far, at most, toward a boss too big for it (lean_toward()).
const MAX_LEAN := 170.0
## How fast the lean follows (per second, exponential).
const LEAN_RATE := 3.0

var _trauma := 0.0
var _kick := Vector2.ZERO
## The physics frame of the last kick, the kick before that frame's, and that frame's strongest.
var _kick_frame := -1
var _kick_before := Vector2.ZERO
var _frame_kick := 0.0
## A boss too big for the view (BossDef.camera_lean): the view leans toward it, so both it and
## the hero stay on screen. `_lean_at`: its middle, above its feet.
var _lean_target: Node2D
var _lean_share := 0.0
var _lean_height := 0.0
var _lean := Vector2.ZERO
## The zoom set in the scene, before PixelGrid's share.
var _base_zoom := Vector2.ONE


func _ready() -> void:
	# Anything can shake the screen without knowing about the hero (Events.screen_shake).
	Events.screen_shake.connect(shake)
	Events.camera_kick.connect(kick)
	_base_zoom = zoom
	PixelGrid.scale_changed.connect(fit_zoom)
	fit_zoom()


## Also when the debug panel's zoom step changes (DebugCheats.zoom()).
func fit_zoom() -> void:
	zoom = _base_zoom * PixelGrid.world_zoom() * DebugCheats.zoom()


## Pushes the view `pixels` along `direction`; it springs back. One blow striking a crowd kicks
## once: within a physics frame only the strongest push counts, never their sum.
func kick(direction: Vector2, pixels: float) -> void:
	if direction == Vector2.ZERO:
		return
	var frame := Engine.get_physics_frames()
	if frame != _kick_frame:
		_kick_frame = frame
		_kick_before = _kick
		_frame_kick = 0.0
	elif pixels <= _frame_kick:
		return
	_frame_kick = pixels
	_kick = (_kick_before + direction.normalized() * pixels * Settings.screen_shake).limit_length(MAX_KICK)


## The view leans toward `target` (its point `height` above its feet) by `share` of the way
## there, at most MAX_LEAN; null or 0 to stop (it eases back).
func lean_toward(target: Node2D, share: float, height: float = 0.0) -> void:
	_lean_target = target
	_lean_share = share
	_lean_height = height


## Where the kick has the view right now (pixels).
func kick_offset() -> Vector2:
	return _kick


## amount: 0..1. Shakes add up but are capped. (It buzzes nothing: the phone buzzes only for
## what matters, said where it happens: Settings.vibrate().)
func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount * Settings.screen_shake, 1.0)


## The shake's trauma now (0..1; tests).
func trauma() -> float:
	return _trauma


func _process(delta: float) -> void:
	# Real time: a hit stop must not hold the view pushed.
	var real := HitStop.real_delta(delta)
	_kick = _kick * exp(-KICK_RETURN * real)
	if _kick.length() < 0.1:
		_kick = Vector2.ZERO
	var wanted := Vector2.ZERO
	if _lean_share > 0.0 and is_instance_valid(_lean_target) and _lean_target.is_inside_tree():
		var at := _lean_target.global_position + Vector2(0, -_lean_height)
		wanted = ((at - get_parent().global_position) * _lean_share).limit_length(MAX_LEAN)
	_lean = _lean.lerp(wanted, 1.0 - exp(-LEAN_RATE * real))
	var lean := _lean.round()
	if _trauma <= 0.0:
		offset = _kick.round() + lean
		return
	# Real time too: a hit stop must not hold the shake.
	_trauma = maxf(_trauma - DECAY * real, 0.0)
	var strength := _trauma * _trauma
	# Whole art pixels (the world moves by its own pixels, never half of one).
	var jolt := (Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * MAX_OFFSET * strength / PixelDraw.PX).round() * PixelDraw.PX
	offset = jolt + _kick.round() + lean
