class_name WyrmBody
extends Node2D
## The body of a WyrmTrait monster: segments following the trail of the head, wings flapping on
## its sides, a tail at the end. Drawn behind the head in world space (top level). The hero
## touching a segment is burned and thrown back (the head is the only part that can be hurt).
## On the art's grid like every body (decision 0007): the wings flap by whole rows of their art
## (rows left out, never squashed), the tail turns by quarter turns only, the coils bob by a
## whole art pixel.

## Art pixels are drawn this big, like the actors' rigs.
const ART_SCALE := 2.0
## Trail points are this far apart.
const TRAIL_STEP := 4.0
const FADE_TIME := 0.6
## How far from a segment's centre the coils burn (half a segment's art), before the hero's radius.
const TOUCH_RADIUS := 14.0 * ART_SCALE * 0.5

var _monster: Monster
var _shape: WyrmTrait
## Head positions, newest first.
var _trail: Array[Vector2] = []
var _time := 0.0
## Where each segment is (head side first), then the tail.
var _points: Array[Vector2] = []


func setup(monster: Monster, shape: WyrmTrait) -> void:
	_monster = monster
	_shape = shape
	top_level = true
	show_behind_parent = true
	z_index = -1


func _ready() -> void:
	global_position = Vector2.ZERO
	# Laid out straight behind the head (up) until it moves.
	var length := _shape.spacing * (_shape.segment_count + 2)
	var at := _monster.global_position
	var steps := ceili(length / TRAIL_STEP) + 1
	for i in steps:
		_trail.append(at + Vector2(0, -TRAIL_STEP * i))
	_place()


func _physics_process(delta: float) -> void:
	_time += delta
	if _monster.is_dead:
		modulate.a = maxf(modulate.a - delta / FADE_TIME, 0.0)
		queue_redraw()
		return
	var head := _monster.global_position
	if head.distance_to(_trail[0]) >= TRAIL_STEP:
		_trail.push_front(head)
		var keep := ceili(_shape.spacing * (_shape.segment_count + 2) / TRAIL_STEP) + 4
		if _trail.size() > keep:
			_trail.resize(keep)
	else:
		_trail[0] = head
	_place()
	_touch()
	queue_redraw()


## Where the burning segments are now (head side first, then the tail): what a player watching
## the fight steps away from (the balance bots read it too).
func segment_points() -> Array[Vector2]:
	return _points


## Segment i sits `spacing * (i + 1)` along the trail.
func _place() -> void:
	_points.clear()
	for i in _shape.segment_count + 1:
		_points.append(_along(_shape.spacing * (i + 1)))


func _along(distance: float) -> Vector2:
	var walked := 0.0
	for i in range(1, _trail.size()):
		var step := _trail[i - 1].distance_to(_trail[i])
		if walked + step >= distance:
			return _trail[i - 1].lerp(_trail[i], (distance - walked) / maxf(step, 0.001))
		walked += step
	return _trail.back()


## The hero touching a segment.
func _touch() -> void:
	var player := _monster.world.player if _monster.world else null
	if player == null or player.is_dead or _monster.dormant:
		return
	var reach := TOUCH_RADIUS + player.radius
	for point in _points:
		if point.distance_to(player.global_position) <= reach:
			var amount := _monster.world.rules.dungeon_damage(_shape.contact_damage) if _monster.world.rules else roundi(_shape.contact_damage)
			var hit := Combat.make_secondary_hit(_monster, amount)
			hit.knockback = point.direction_to(player.global_position) * _shape.contact_knockback
			hit.origin = point
			player.take_hit(hit)
			return


func _draw() -> void:
	if _points.is_empty():
		return
	var tint := _monster.rig.modulate if _monster.rig else Color.WHITE
	# The tail and the body, back to front.
	for i in range(_points.size() - 1, -1, -1):
		var at := _points[i]
		var ahead := _points[i - 1] if i > 0 else _monster.global_position
		var texture: Texture2D = _shape.tail if i == _points.size() - 1 else _segment(i)
		if texture == null:
			continue
		# The tail points back along the body, to the nearest quarter turn (a turn between them
		# would draw its pixels askew).
		var angle := tail_turn(at, ahead) if i == _points.size() - 1 else 0.0
		var bob := roundf(sin(_time * 6.0 - i * 0.8) * 0.75) * ART_SCALE
		_draw_texture(texture, at + Vector2(0, bob), angle, tint, false)
	# The wings, on the head's sides, flapping.
	if _shape.wing:
		var head := _monster.global_position + Vector2(0, -18)
		var flap := 0.8 + 0.2 * sin(_time * 7.0)
		var side := _shape.wing.get_width() * ART_SCALE * 0.42
		_draw_wing(head + Vector2(side, -6), flap, tint, false)
		_draw_wing(head + Vector2(-side, -6), flap, tint, true)


func _segment(index: int) -> Texture2D:
	if _shape.segments.is_empty():
		return null
	return _shape.segments[index % _shape.segments.size()]


func _draw_texture(texture: Texture2D, at: Vector2, angle: float, tint: Color, flip: bool) -> void:
	var size := texture.get_size() * ART_SCALE
	draw_set_transform(at, angle, Vector2(-1.0 if flip else 1.0, 1.0))
	draw_texture_rect(texture, Rect2(-size * 0.5, size), false, tint)
	draw_set_transform(Vector2.ZERO)


## The wing folded to `flap` of its height: that many of its art's rows, evenly picked (whole
## rows at the art's scale, the others left out), its root (bottom left of the art) at the
## shoulder.
func _draw_wing(at: Vector2, flap: float, tint: Color, flip: bool) -> void:
	var wing := _shape.wing
	var rows := wing.get_height()
	var shown := clampi(roundi(rows * flap), 1, rows)
	var width := wing.get_width() * ART_SCALE
	var top := -roundf(shown * 0.8) * ART_SCALE
	draw_set_transform(at, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	var start := 0
	while start < shown:
		# A band of consecutive rows of the art, drawn in one go.
		var source := _wing_row(start, shown, rows)
		var count := 1
		while start + count < shown and _wing_row(start + count, shown, rows) == source + count:
			count += 1
		var target := Rect2(Vector2(-width * 0.3, top + start * ART_SCALE), Vector2(width, count * ART_SCALE))
		draw_texture_rect_region(wing, target, Rect2(0, source, wing.get_width(), count), tint)
		start += count
	draw_set_transform(Vector2.ZERO)


## How the tail at `at` is turned to point back from the segment at `ahead`: the nearest
## quarter turn (its pixels stay whole and square).
static func tail_turn(at: Vector2, ahead: Vector2) -> float:
	return snappedf((ahead - at).angle() + PI * 0.5, PI * 0.5)


## The art's row shown as row `row` of a wing folded to `shown` of its `rows`.
static func _wing_row(row: int, shown: int, rows: int) -> int:
	return mini(floori((row + 0.5) * rows / float(shown)), rows - 1)
