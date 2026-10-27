class_name TitleBackdrop
extends Control
## The title screen's picture, drawn in big pixels: a cave at night, its rock closing in from the
## sides and the top, and on the right the Well itself, a ring of old stones with the souls' light
## rising from its depth. The hero sits on its rim (TitleScreen places him at hero_spot()), the
## Vigil-Keeper stands on its other side (keeper_spot()). Above it, the shrine's lamps in their
## niches of the cave's wall, put out on the moonless night: one more burns again for every share
## of the souls offered to the Tree (`lamps_lit`, set by the TitleScreen).

## Screen pixels per art pixel.
const PIXEL := 4.0
const SKY_TOP := Color(0.055, 0.04, 0.085)
const SKY_BOTTOM := Color(0.13, 0.085, 0.14)
const ROCK := Color(0.07, 0.05, 0.08)
const ROCK_EDGE := Color(0.22, 0.15, 0.2)
const GROUND := Color(0.1, 0.07, 0.1)
const STONE := Color(0.36, 0.3, 0.32)
const STONE_DARK := Color(0.2, 0.16, 0.19)
const STONE_LIGHT := Color(0.52, 0.45, 0.44)
const SOUL := Color(0.55, 0.95, 0.95)
const FLAME := Color(1.0, 0.72, 0.3)
const FLAME_CORE := Color(1.0, 0.93, 0.6)
const LAMP_STONE := Color(0.3, 0.25, 0.27)

## How often the picture is drawn again (it changes by whole art pixels).
const REDRAW_FPS := 12.0

## The picture last drawn (floor(_time * REDRAW_FPS)).
var _frame := -1
## The shrine's lamps, and how many burn.
var lamps := 7
var lamps_lit := 0:
	set(value):
		lamps_lit = clampi(value, 0, lamps)
		queue_redraw()

var _time := 0.0
var _rocks_left := PackedFloat32Array()
var _rocks_right := PackedFloat32Array()
var _ceiling := PackedFloat32Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7  # the same cave every time
	for i in 64:
		_rocks_left.append(rng.randf())
		_rocks_right.append(rng.randf())
		_ceiling.append(rng.randf())


func _process(delta: float) -> void:
	_time += delta
	# Big pixels move a whole art pixel at a time: 12 pictures a second are enough, and the
	# title's whole screen isn't drawn again 60 times a second (docs/performance.md).
	var frame := floori(_time * REDRAW_FPS)
	if frame != _frame:
		_frame = frame
		queue_redraw()


## The middle of the Well's mouth (screen position).
func well_center() -> Vector2:
	return Vector2(size.x * 0.7, size.y * 0.74).snapped(Vector2(PIXEL, PIXEL))


## Half the Well's mouth, across and deep.
func well_radius() -> Vector2:
	return Vector2(clampf(size.x * 0.11, 120.0, 200.0), clampf(size.y * 0.075, 36.0, 60.0)).snapped(Vector2(PIXEL, PIXEL))


## Where the hero sits: on the rim, left of the mouth.
func hero_spot() -> Vector2:
	var center := well_center()
	return center + Vector2(-well_radius().x - 64.0, -6.0)


## Where the Vigil-Keeper stands (her feet): on the ground, right of the mouth.
func keeper_spot() -> Vector2:
	var center := well_center()
	return (center + Vector2(well_radius().x + 62.0, 10.0)).snapped(Vector2(PIXEL, PIXEL))


## The middle of lamp `index`'s niche (screen position).
func lamp_spot(index: int) -> Vector2:
	var center := well_center()
	var spread := well_radius().x * 2.1
	var t := float(index) / maxf(lamps - 1, 1)
	var x := center.x - spread + spread * 2.0 * t
	# A gentle arch over the Well: the middle ones higher.
	var y := center.y - well_radius().y * 3.4 - sin(t * PI) * well_radius().y * 0.9
	return Vector2(x, y).snapped(Vector2(PIXEL, PIXEL))


func _draw() -> void:
	var w := size.x
	var h := size.y
	# The dark of the cave, a little warmer near the ground.
	var bands := 24
	for i in bands:
		var t := float(i) / (bands - 1)
		draw_rect(Rect2(0, h * i / bands, w, h / bands + 1), SKY_TOP.lerp(SKY_BOTTOM, t))
	_draw_beam()
	# The ground.
	var ground_y := well_center().y - well_radius().y * 0.3
	draw_rect(Rect2(0, ground_y, w, h - ground_y), GROUND)
	for i in int(w / (PIXEL * 6)):
		var x := i * PIXEL * 6
		var bump := floorf(_rocks_left[i % 64] * 3.0) * PIXEL
		draw_rect(Rect2(x, ground_y - bump, PIXEL * 6, bump + PIXEL), GROUND)
		draw_rect(Rect2(x, ground_y - bump, PIXEL * 6, PIXEL), ROCK_EDGE)
	_draw_rock_walls()
	_draw_lamps()
	_draw_well()


## The souls' light rising from the Well, faint and slowly breathing.
func _draw_beam() -> void:
	var center := well_center()
	var radius := well_radius()
	var breath := 0.75 + 0.25 * sin(_time * 0.8)
	var steps := 10
	for i in steps:
		var t := float(i) / steps
		var half := radius.x * (0.9 - t * 0.55)
		var top := center.y - (center.y + 40.0) * (1.0 - t)
		draw_rect(Rect2(center.x - half, top, half * 2.0, center.y - top), Color(SOUL, 0.022 * breath))


func _draw_rock_walls() -> void:
	var w := size.x
	var h := size.y
	var step := PIXEL * 8
	var rows := int(h / step) + 1
	# Left and right walls: jagged columns of rock, deeper near the top.
	for i in rows:
		var y := i * step
		var t := 1.0 - float(i) / rows
		var left := (40.0 + 90.0 * t + _rocks_left[i % 64] * 36.0)
		var right := (30.0 + 70.0 * t + _rocks_right[i % 64] * 30.0)
		left = snappedf(left, PIXEL)
		right = snappedf(right, PIXEL)
		draw_rect(Rect2(0, y, left, step), ROCK)
		draw_rect(Rect2(left - PIXEL, y, PIXEL, step), ROCK_EDGE)
		draw_rect(Rect2(w - right, y, right, step), ROCK)
		draw_rect(Rect2(w - right, y, PIXEL, step), ROCK_EDGE)
	# The ceiling: a ragged edge of rock with a few hanging points.
	var columns := int(w / step) + 1
	for i in columns:
		var x := i * step
		var depth := snappedf(24.0 + _ceiling[i % 64] * 40.0, PIXEL)
		draw_rect(Rect2(x, 0, step, depth), ROCK)
		draw_rect(Rect2(x, depth - PIXEL, step, PIXEL), ROCK_EDGE)
		if _ceiling[(i * 7) % 64] > 0.82:
			var drip := snappedf(16.0 + _ceiling[(i * 3) % 64] * 40.0, PIXEL)
			draw_rect(Rect2(x + step * 0.25, depth, step * 0.5, drip), ROCK)
			draw_rect(Rect2(x + step * 0.375, depth + drip, step * 0.25, PIXEL * 2), ROCK)


## A ring of stones round a mouth of light: the back stones, the glowing hole, the front stones.
func _draw_well() -> void:
	var center := well_center()
	var radius := well_radius()
	var breath := 0.8 + 0.2 * sin(_time * 1.3)
	# The hole: dark, with the souls' light deep inside.
	_ellipse(center, radius * 0.92, Color(0.02, 0.02, 0.05))
	for i in 6:
		var t := float(i) / 6.0
		_ellipse(center + Vector2(0, radius.y * 0.1 * t), radius * (0.85 - t * 0.6), Color(SOUL, (0.08 + t * 0.12) * breath))
	# The stones: blocks along the ring, darker at the back, lit from the hole at the front.
	var stones := 22
	for front in [false, true]:
		for i in stones:
			var angle := TAU * i / stones
			var is_front := sin(angle) > 0.0
			if is_front != front:
				continue
			var at := center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
			var block := Vector2(snappedf(radius.x * 0.3, PIXEL), PIXEL * (5 if front else 4))
			var rect := Rect2((at - block * 0.5).snapped(Vector2(PIXEL, PIXEL)), block)
			var base := STONE if front else STONE_DARK
			draw_rect(rect, base)
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, PIXEL)), STONE_LIGHT if front else STONE)
			draw_rect(Rect2(rect.position + Vector2(rect.size.x - PIXEL, 0), Vector2(PIXEL, rect.size.y)), STONE_DARK)
	# The wall of the well under its front rim.
	var wall := Rect2(center.x - radius.x, center.y, radius.x * 2.0, radius.y * 1.2).abs()
	for row in 3:
		for column in 6:
			var offset := (PIXEL * 6 if row % 2 == 1 else 0.0)
			var brick := Rect2(wall.position + Vector2(column * wall.size.x / 6.0 + offset, radius.y * 0.35 + row * PIXEL * 5), Vector2(wall.size.x / 6.0 - PIXEL, PIXEL * 4))
			brick.size.x = minf(brick.size.x, wall.end.x - brick.position.x)
			if brick.size.x > PIXEL:
				draw_rect(Rect2(brick.position.snapped(Vector2(PIXEL, PIXEL)), brick.size.snapped(Vector2(PIXEL, PIXEL))), STONE_DARK if (row + column) % 3 else STONE)


## Each lamp in its niche: a dark arch in the wall, a stone bowl, and, lit, a flame breathing with
## a soft square of light around it (in big pixels like the rest).
func _draw_lamps() -> void:
	for i in lamps:
		var at := lamp_spot(i)
		var niche := Rect2(at + Vector2(-PIXEL * 3, -PIXEL * 5), Vector2(PIXEL * 6, PIXEL * 8))
		draw_rect(niche, ROCK)
		draw_rect(Rect2(niche.position + Vector2(PIXEL, -PIXEL), Vector2(PIXEL * 4, PIXEL)), ROCK)
		draw_rect(Rect2(niche.position + Vector2(0, niche.size.y), Vector2(niche.size.x, PIXEL)), ROCK_EDGE)
		# The bowl.
		draw_rect(Rect2(at + Vector2(-PIXEL * 2, PIXEL), Vector2(PIXEL * 4, PIXEL)), LAMP_STONE)
		draw_rect(Rect2(at + Vector2(-PIXEL, PIXEL * 2), Vector2(PIXEL * 2, PIXEL)), LAMP_STONE)
		if i >= lamps_lit:
			draw_rect(Rect2(at + Vector2(-PIXEL, 0), Vector2(PIXEL * 2, PIXEL)), Color(0.12, 0.1, 0.12))
			continue
		var flicker := 0.75 + 0.25 * sin(_time * 5.0 + i * 1.7)
		draw_rect(Rect2(at + Vector2(-PIXEL * 5, -PIXEL * 6), Vector2(PIXEL * 10, PIXEL * 10)), Color(FLAME, 0.05 * flicker))
		draw_rect(Rect2(at + Vector2(-PIXEL * 3, -PIXEL * 4), Vector2(PIXEL * 6, PIXEL * 7)), Color(FLAME, 0.08 * flicker))
		var tall := 2 if flicker > 0.8 else 1
		draw_rect(Rect2(at + Vector2(-PIXEL, -PIXEL * tall), Vector2(PIXEL * 2, PIXEL * (tall + 1))), FLAME)
		draw_rect(Rect2(at + Vector2(0, -PIXEL * (tall - 1)), Vector2(PIXEL, PIXEL * tall)), FLAME_CORE)


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	# In big pixels: rows of rects, stepped like the rest of the art.
	var rows := int(radius.y * 2.0 / PIXEL)
	for i in rows:
		var y := -radius.y + i * PIXEL + PIXEL * 0.5
		var half := radius.x * sqrt(maxf(0.0, 1.0 - (y * y) / (radius.y * radius.y)))
		half = snappedf(half, PIXEL)
		if half > 0.0:
			draw_rect(Rect2(center.x - half, center.y + y - PIXEL * 0.5, half * 2.0, PIXEL), color)
