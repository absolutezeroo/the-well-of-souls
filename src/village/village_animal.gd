class_name VillageAnimal
extends CharacterBody2D
## One of Kagari's animals keeping its place: it waits, picks a spot of its place to walk to and
## goes there around the static collisions, then waits again; outside its hours it goes home and
## stays. Its own seeded generator, never the dungeon's dice. A path is made only for a new walk
## (every few seconds), nothing is allocated per frame; frames change at their authored rate.

## A walk that cannot end (its spot walled in since a profile refresh) is given up after this.
const GIVE_UP_SECONDS := 20.0
var def: VillageAnimalDef
var navigation: VillageNavigation
var paused := false
var awake := true
var sprite := Sprite2D.new()
var _rng := RandomNumberGenerator.new()
var _path := PackedVector2Array()
var _waypoint := 0
var _wait := 0.0
var _walked := 0.0
var _clock := 0.0
var _frame := -1
var _walking := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	sprite.texture = def.texture
	sprite.region_enabled = true
	sprite.region_rect = def.idle_frames[0] if not def.idle_frames.is_empty() else Rect2(0, 0, 16, 16)
	sprite.scale = Vector2.ONE * def.art_scale
	sprite.offset = Vector2(0, -8)
	add_child(sprite)
	_rng.seed = hash(String(def.id))
	_wait = _rng.randf_range(0.0, def.pause.y)


## The village clock's hour: awake it wanders, asleep it walks home and stays there.
func apply_hour(hour: float) -> void:
	var now := def.awake_at(hour)
	if now == awake:
		return
	awake = now
	if not awake:
		_walk_to(def.home)


func _physics_process(delta: float) -> void:
	velocity = Vector2.ZERO
	if not paused:
		if _waypoint < _path.size():
			_walked += delta
			var target := _path[_waypoint]
			if position.distance_squared_to(target) <= 4.0:
				_waypoint += 1
			elif _walked > GIVE_UP_SECONDS:
				_path.clear()
			else:
				velocity = position.direction_to(target) * minf(def.walk_speed, position.distance_to(target) / maxf(delta, 0.001))
		elif awake:
			_wait -= delta
			if _wait <= 0.0:
				_wait = _rng.randf_range(def.pause.x, def.pause.y)
				_walk_to(def.home + Vector2(_rng.randf_range(-def.roam.x, def.roam.x), _rng.randf_range(-def.roam.y, def.roam.y)).round())
	if velocity != Vector2.ZERO:
		move_and_slide()
	_animate(delta, velocity != Vector2.ZERO)


func _walk_to(target: Vector2) -> void:
	_path = navigation.path(position, target) if navigation else PackedVector2Array()
	_waypoint = 1 if _path.size() > 1 else 0
	_walked = 0.0


func _animate(delta: float, moving: bool) -> void:
	if moving != _walking:
		_walking = moving
		_clock = 0.0
		_frame = -1
	_clock += delta
	var frames := def.walk_frames if moving and not def.walk_frames.is_empty() else def.idle_frames
	if frames.is_empty(): return
	var interval := def.walk_frame_time if moving else def.idle_frame_time
	var index := int(_clock / maxf(interval, 0.05)) % frames.size()
	if index != _frame:
		_frame = index
		sprite.region_rect = frames[index]
	if moving and absf(velocity.x) > 0.5:
		# The pack draws animals facing right; the mirror is a pre-drawn direction, not a turn.
		sprite.flip_h = velocity.x < 0.0
