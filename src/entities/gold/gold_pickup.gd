class_name GoldPickup
extends Node2D
## A few coins on the floor. They hop out, then fly to the hero once they are close enough.
## Checked by distance every frame (no physics): there are only a few at a time.

## Picked up by the hero (the World keeps it for the floor's save: FloorLedger).
signal collected(pickup: GoldPickup)

const TEXTURE: Texture2D = preload("res://assets/items/gold_coin.png")
const MAGNET_DISTANCE := 90.0
const PICKUP_DISTANCE := 14.0
const MAX_SPEED := 620.0

var amount := 1

var _world: World
var _velocity := Vector2.ZERO
var _height := 0.0
var _height_speed := 0.0
var _attracted := false
var _time := 0.0
var _collected := false


static func create(at: Vector2, coins: int, world: World) -> GoldPickup:
	var pickup := GoldPickup.new()
	pickup.amount = coins
	pickup._world = world
	pickup.position = at
	pickup._velocity = Vector2.from_angle(randf() * TAU) * randf_range(30.0, 90.0)
	pickup._height_speed = randf_range(110.0, 170.0)
	pickup._time = randf() * TAU
	pickup.add_to_group("gold")
	return pickup


func _physics_process(delta: float) -> void:
	_time += delta
	var player := _world.player if is_instance_valid(_world) else null
	# The hop out of the body.
	if _height_speed != 0.0 or _height > 0.0:
		_height_speed -= 520.0 * delta
		_height = maxf(_height + _height_speed * delta, 0.0)
		if _height <= 0.0 and _height_speed < 0.0:
			_height_speed = 0.0
		position += _velocity * delta
		_velocity = _velocity.move_toward(Vector2.ZERO, 160.0 * delta)
	elif player and not player.is_dead:
		var distance := global_position.distance_to(player.global_position)
		_attracted = _attracted or distance < MAGNET_DISTANCE
		if _attracted:
			_velocity = _velocity.move_toward(global_position.direction_to(player.global_position) * MAX_SPEED, 1800.0 * delta)
			position += _velocity * delta
			if distance < PICKUP_DISTANCE:
				_collect(player)
				return
	if Vfx.on_screen(self, 16.0 + _height):
		queue_redraw()  # (its glint and hop move every frame: off screen, nothing to draw)


func _collect(player: Player) -> void:
	take(player)


func is_collected() -> bool:
	return _collected


## One successful transfer, even if called twice before the queued node is freed.
func take(player: Player) -> bool:
	if _collected or player == null or player.is_dead:
		return false
	_collected = true
	var settlement := _world.spawns if is_instance_valid(_world) else null
	if settlement:
		settlement.begin_settlement()
	player.add_gold(amount)
	collected.emit(self)
	Sfx.play_world(Sfx.bank.coin, global_position, -6.0)
	queue_free()
	if settlement:
		settlement.end_settlement()
	return true


func _draw() -> void:
	var size := TEXTURE.get_size() * 2.0
	PixelDraw.disc(self, Vector2(0, 5), 5.0, Color(0, 0, 0, 0.3), 1.0, 0.4)
	# A glint every now and then.
	var glint := 1.0 + 0.5 * maxf(sin(_time * 3.0), 0.0) ** 8
	var at := PixelDraw.snap(Vector2(0, -_height - 2.0 + sin(_time * 4.0)))
	draw_texture_rect(TEXTURE, Rect2(at - size * 0.5, size), false, Color(glint, glint, glint))
	if amount > 4:
		draw_texture_rect(TEXTURE, Rect2(at - size * 0.5 + Vector2(5, 3), size), false)
