class_name DecorLayer
extends Node2D
## Little pieces of decor drawn at 2x (grass, flowers, logs, stones...): [texture, offset] each.
## Nothing to collide with. Plants (`sway`) move in a light breeze and bend away from whoever
## walks through them, each row of their art moved sideways by whole art pixels (never skewed:
## a skew drew slanted slivers of pixels, decision 0007); everything else is drawn once.

const BEND := 0.55  ## how far a plant leans when someone walks through it (skew)
const REACH := Vector2(18.0, 12.0)  ## how close someone must be to bend it

var pieces: Array = []
## Plants: they sway, and bend when walked through (needs `world`).
var sway := false
var world: World

var _time := 0.0
var _lean := PackedFloat32Array()
## Where its pieces lie (world space), to skip the work off screen.
var _bounds := Rect2()
var _bounds_known := false


func _ready() -> void:
	set_process(sway)


func _process(delta: float) -> void:
	_time += delta
	if _lean.size() != pieces.size():
		_lean.resize(pieces.size())
	if world and is_instance_valid(world):
		if not _bounds_known:
			_bounds_known = true
			_bounds = _pieces_bounds()
		if not world.view_rect().intersects(_bounds):
			return  # off screen: nobody sees it sway
	var actors: Array[Actor] = world.actors_this_frame() if world and is_instance_valid(world) else []
	for i in pieces.size():
		var foot := _foot(pieces[i])
		var push := 0.0
		for actor in actors:
			var offset := foot - actor.global_position
			if absf(offset.x) < REACH.x and absf(offset.y) < REACH.y:
				push += signf(offset.x) * (1.0 - absf(offset.x) / REACH.x) * BEND
		_lean[i] = lerpf(_lean[i], clampf(push, -BEND, BEND), minf(delta * 10.0, 1.0))
	queue_redraw()


func _draw() -> void:
	for i in pieces.size():
		var piece: Array = pieces[i]
		var texture: Texture2D = piece[0]
		var size := texture.get_size() * 2.0
		if not sway:
			draw_texture_rect(texture, Rect2(piece[1] - size * 0.5, size), false)
			continue
		# Leaning from the foot: a breeze (out of step from plant to plant) plus who walks by.
		var foot := _foot(piece)
		var breeze := sin(_time * 1.7 + foot.x * 0.05 + foot.y * 0.031) * 0.08
		var lean := breeze + (_lean[i] if i < _lean.size() else 0.0)
		_draw_leaning(texture, foot, lean)


## `texture` standing on `foot`, leaning by `lean` (its top moved `lean` times its height
## sideways, as a skew would): each row moved by whole art pixels, those nearer the foot less, in
## bands of rows moved alike.
func _draw_leaning(texture: Texture2D, foot: Vector2, lean: float) -> void:
	var rows := texture.get_height()
	var width := texture.get_width() * 2.0
	var row := 0
	while row < rows:
		var shift := row_shift(row, rows, lean)
		var count := 1
		while row + count < rows and row_shift(row + count, rows, lean) == shift:
			count += 1
		var target := Rect2(foot + Vector2(shift * 2.0 - width * 0.5, (row - rows) * 2.0), Vector2(width, count * 2.0))
		draw_texture_rect_region(texture, target, Rect2(0, row, texture.get_width(), count))
		row += count


## How many art pixels row `row` (from the top) of a plant `rows` high moves sideways when it
## leans by `lean`: its middle's height above the foot times the lean, rounded to a whole pixel.
static func row_shift(row: int, rows: int, lean: float) -> int:
	return roundi(-lean * (rows - row - 0.5))


func _pieces_bounds() -> Rect2:
	if pieces.is_empty():
		return Rect2()
	var box := Rect2(to_global(_foot(pieces[0])), Vector2.ZERO)
	for piece: Array in pieces:
		var texture: Texture2D = piece[0]
		box = box.merge(Rect2(to_global(piece[1] - texture.get_size()), texture.get_size() * 2.0))
	return box.grow(32.0)


static func _foot(piece: Array) -> Vector2:
	var texture: Texture2D = piece[0]
	return piece[1] + Vector2(0, texture.get_height())  # the bottom of the piece (drawn at 2x)
