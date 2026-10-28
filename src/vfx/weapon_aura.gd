class_name WeaponAura
extends Node2D
## The elements a weapon carries, shown around it (ItemLook.elements): a few motes in each
## element's bits, ramp and motion born on the weapon's own pixels, on the back at rest or in
## the hand while attacking. Fire throws embers that rise, frost sheds chips that fall, poison
## drips, storm sparks fly out, holy glints fall slowly, shadow smoke is drawn in, arcane runes
## orbit, blood drips. The rig's shader paints the weapon's rim in the first element (`imbue`);
## this is the accent. Fewer effects: none.
##
## A child of the rig's Squash (art pixels), drawn right after the weapon it belongs to, so
## motes of a weapon behind the body are hidden by it. Scaled 0.5 so PixelDraw's 2-unit pixels
## are art pixels again; positions are kept in art pixels and drawn on whole ones (docs/vfx.md).

## Motes alive at once for the first element, and for each other one.
const FIRST := 4
const OTHER := 2
## Seconds a mote lives (from, to).
const LIFE := Vector2(0.45, 0.9)
## Motes move in whole art pixels, 12 times a second (the hand-animated pace).
const FPS := 12.0

var elements: Array[VfxElementDef] = []
## Where motes are born: the weapon's opaque pixels, in Squash space (art pixels).
var _emitters: PackedVector2Array = PackedVector2Array()
var _center := Vector2.ZERO
var _motes: Array[Dictionary] = []
## Motes that died, kept to be born again (no new dictionary a step: docs/performance.md).
var _spare: Array[Dictionary] = []
var _clock := 0.0
var _tick := 0.0

static var _pixels := {}  # Texture2D -> its opaque pixels (PackedVector2Array)


func _init() -> void:
	scale = Vector2(0.5, 0.5)
	use_parent_material = false
	name = "WeaponAura"


func set_elements(carried: Array[VfxElementDef]) -> void:
	elements = carried
	_motes.clear()
	set_process(not elements.is_empty())
	queue_redraw()


## The weapon now shown: `texture` with its top-left corner at `corner` (Squash space, art
## pixels), mirrored when `flip`.
func set_source(texture: Texture2D, corner: Vector2, flip: bool) -> void:
	if texture == null:
		_emitters = PackedVector2Array()
		return
	var local := pixels_of(texture)
	var size := texture.get_size()
	var points := PackedVector2Array()
	points.resize(local.size())
	var sum := Vector2.ZERO
	for i in local.size():
		var p := local[i]
		if flip:
			p.x = size.x - 1.0 - p.x
		points[i] = corner + p
		sum += points[i]
	_emitters = points
	_center = sum / maxf(points.size(), 1.0)


## The opaque pixels of `texture` (an AtlasTexture's own region), cached.
static func pixels_of(texture: Texture2D) -> PackedVector2Array:
	if _pixels.has(texture):
		return _pixels[texture]
	var points := PackedVector2Array()
	var image := texture.get_image()
	if image:
		if image.is_compressed():
			image.decompress()
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a > 0.5:
					points.append(Vector2(x, y))
	_pixels[texture] = points
	return points


func _process(delta: float) -> void:
	if not Vfx.shown:
		return  # a simulation: nothing to see (Vfx.shown)
	_clock += delta
	_tick += delta
	if _tick < 1.0 / FPS:
		return
	var step := _tick
	_tick = 0.0
	if not is_visible_in_tree() or _emitters.is_empty() or Settings.fewer_effects:
		if not _motes.is_empty():
			_motes.clear()
			queue_redraw()
		return
	# Aged and moved, the dead ones taken out in place (a filter built a new array each step).
	for i in range(_motes.size() - 1, -1, -1):
		var mote := _motes[i]
		mote.age += step
		_move(mote, step)
		if mote.age >= mote.life:
			_spare.append(mote)
			_motes.remove_at(i)
	for i in elements.size():
		var wanted := FIRST if i == 0 else OTHER
		var alive := 0
		for mote in _motes:
			if mote.element == i:
				alive += 1
		if alive < wanted and randf() < 0.55:
			_spawn(i)
	queue_redraw()


func _spawn(index: int) -> void:
	var element := elements[index]
	var at := _emitters[randi() % _emitters.size()]
	var mote: Dictionary = _spare.pop_back() if not _spare.is_empty() else {}
	mote.element = index
	mote.age = 0.0
	mote.life = randf_range(LIFE.x, LIFE.y)
	mote.pos = at
	mote.vel = Vector2.ZERO
	mote.angle = randf() * TAU
	var away := (at - _center).normalized() if at != _center else Vector2.UP
	match element.motion:
		VfxElementDef.Motion.RISE:
			mote.vel = Vector2(randf_range(-3.0, 3.0), randf_range(-16.0, -10.0))
		VfxElementDef.Motion.FALL:
			mote.vel = Vector2(randf_range(-2.0, 2.0), randf_range(3.0, 7.0))
		VfxElementDef.Motion.SINK:
			mote.vel = Vector2(randf_range(-1.5, 1.5), randf_range(4.0, 8.0))
		VfxElementDef.Motion.DRIFT:
			mote.vel = Vector2(randf_range(-3.0, 3.0), randf_range(-4.0, 0.0))
		VfxElementDef.Motion.OUTWARD:
			mote.vel = away * randf_range(10.0, 18.0)
			mote.life *= 0.5  # sparks: quick
		VfxElementDef.Motion.CONVERGE:
			mote.pos = at + away * 4.0
			mote.vel = -away * 7.0
		VfxElementDef.Motion.ORBIT:
			mote.angle = (at - _center).angle()
	_motes.append(mote)


func _move(mote: Dictionary, step: float) -> void:
	var element := elements[mote.element]
	match element.motion:
		VfxElementDef.Motion.FALL:
			mote.vel.y += 22.0 * step
		VfxElementDef.Motion.RISE:
			mote.vel.x += randf_range(-6.0, 6.0) * step
		VfxElementDef.Motion.ORBIT:
			mote.angle += 5.0 * step
			mote.pos = _center + Vector2(cos(mote.angle) * 6.0, sin(mote.angle) * 3.0)
			return
	mote.pos += mote.vel * step


func _draw() -> void:
	for mote in _motes:
		var element := elements[mote.element]
		var t: float = mote.age / mote.life
		# Up the ramp as it lives (core, then its color, then its edge), dithered out at the end.
		var color := element.shade(0.15 + t * 0.7)
		var cell := Vector2i((mote.pos as Vector2).floor())
		if t > 0.7 and not PixelDraw.dither(cell, (1.0 - t) / 0.3):
			continue
		var core := element.core() if t < 0.3 else Color.TRANSPARENT
		PixelDraw.bit(self, element.bit, Vector2(cell) * PixelDraw.PX, 1, color, Vector2(mote.vel).normalized() if mote.vel != Vector2.ZERO else Vector2.UP, core)
