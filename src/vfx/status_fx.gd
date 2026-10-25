class_name StatusFx
extends Node2D
## What a body's statuses look like (StatusLookDef, data/vfx/status_looks.tres), in each one's
## element: small flames licking up a burning monster and embers, poison bubbles and a sinking
## haze, rime growing on a chilled one's edges with ice chips and cold mist falling at its feet,
## a burst and a sound when a status takes hold. Drawn by hand (no nodes per particle), over the
## body, on the body's own pixel grid (its origin sits where the rig's 2x sprites do), only
## while something is on it or a particle still lives. No soft glow: the body's tint says it
## (Actor._body_modulate). Actor owns one.

const LOOKS: StatusLookSet = preload("res://data/vfx/status_looks.tres")
## Particles at most per body (a pack on fire stays cheap).
const MAX_PARTICLES := 24
## Where a bubble's pixels fly when it pops (a const: drawn every frame, no array built).
const BUBBLE_POP: Array[Vector2] = [Vector2(-4, -4), Vector2(4, -4), Vector2(-4, 4), Vector2(4, 4)]

enum Kind { SHEET, MOTE, BURST, MIST, CRUST }

class Bit:
	var look: StatusLookDef
	var kind := Kind.SHEET
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var age := 0.0
	var life := 0.5
	var size := 1
	var flip := false
	## A mote's kind (a burning body's ember, a breaking crust's chip...).
	var mote := StatusLookDef.Mote.NONE

var actor: Actor
var _bits: Array[Bit] = []
var _active: Array[StringName] = []
var _spawn := {}  # status -> [particle timer, mote timer, mist timer]
var _time := 0.0
## The cold mist and hazes at the feet: on the floor, under every body (VfxLayer.GROUND), while
## the crust, flames and bubbles are on the body (sorted with it).
var _feet: Node2D


func _init(owner_actor: Actor) -> void:
	actor = owner_actor
	set_physics_process(false)
	_feet = Node2D.new()
	VfxLayer.apply(_feet, VfxLayer.Layer.GROUND)
	_feet.draw.connect(_draw_mist)
	add_child(_feet)


func _ready() -> void:
	# On the sprites' grid: the rig stands its 2x art on this point.
	if actor.rig:
		position = actor.rig.position


func _process(delta: float) -> void:
	if not Vfx.shown:
		return  # a simulation: nothing to see (Vfx.shown)
	if actor == null or not is_instance_valid(actor):
		return
	_time += delta
	var now := actor.statuses.active_ids()
	if now != _active:
		for status in _active:
			if not now.has(status):
				_end(status)
		for status in now:
			var look := LOOKS.look(status)
			if look != null and not _active.has(status):
				_start(look)
		_active.assign(now)
	for status in _active:
		var look := LOOKS.look(status)
		if look:
			_feed(look, delta)
	var i := 0
	while i < _bits.size():
		var bit := _bits[i]
		bit.age += delta
		bit.position += bit.velocity * delta
		match bit.kind:
			Kind.MOTE:
				if bit.mote == StatusLookDef.Mote.EMBER:
					bit.velocity.x += sin(_time * 9.0 + bit.size * 7.0) * 30.0 * delta
				elif bit.mote == StatusLookDef.Mote.CHIP:
					bit.velocity.y += 90.0 * delta  # falls faster and faster
			Kind.MIST:
				bit.velocity *= 1.0 - 2.0 * delta  # spreads, then hangs
		if bit.age >= bit.life and bit.kind != Kind.CRUST:
			_bits.remove_at(i)
		else:
			i += 1
	visible = not _bits.is_empty() or not _active.is_empty()
	if not visible:
		set_process(false)  # asleep until a status lands again (wake())
	queue_redraw()
	_feet.queue_redraw()


## A status is on the body: show it.
func wake() -> void:
	if not is_processing():
		set_process(true)


## The body's middle and its size, in this node's space.
func _body() -> Rect2:
	var height := actor.head_height if actor.frames else actor.radius * 2.0
	var width := actor.radius * 1.6
	var feet := actor.radius * 0.7
	return Rect2(Vector2(-width * 0.5, feet - height) - position, Vector2(width, height))


func _start(look: StatusLookDef) -> void:
	_spawn[look.status] = [0.0, 0.0, 0.0]
	var body := _body()
	if _bits.size() < MAX_PARTICLES:
		var bit := Bit.new()
		bit.look = look
		bit.kind = Kind.BURST
		bit.position = body.get_center()
		bit.life = look.burst_time
		_bits.append(bit)
	# Rime takes hold on the edges: on both sides, at different heights, a piece on the head.
	for i in look.crust_count:
		var bit := Bit.new()
		bit.look = look
		bit.kind = Kind.CRUST
		var left := i % 2 == 0
		bit.flip = left
		var height := body.position.y + body.size.y * (0.2 + 0.65 * fposmod(i * 0.37 + randf() * 0.2, 1.0))
		bit.position = Vector2(body.position.x + (2.0 if left else body.size.x - 2.0), height)
		if i == look.crust_count - 1 and look.crust_count > 2:
			bit.position = Vector2(randf_range(-4.0, 4.0), body.position.y + 4.0)  # one on top
		bit.age = -0.05 * i  # they grow one after the other
		bit.life = INF
		_bits.append(bit)
	if look.sound and actor.world:
		Sfx.play_at(look.sound, actor.global_position, look.sound_db)


## A status is gone: what clung to the body breaks into chips that fall.
func _end(status: StringName) -> void:
	var i := 0
	while i < _bits.size():
		var bit := _bits[i]
		if bit.kind == Kind.CRUST and bit.look.status == status:
			_bits.remove_at(i)
			for piece in 2:
				_mote(bit.look, bit.position + Vector2(randf_range(-2.0, 2.0), 0.0), StatusLookDef.Mote.CHIP)
		else:
			i += 1


func _feed(look: StatusLookDef, delta: float) -> void:
	var timers: Array = _spawn[look.status]
	var body := _body()
	if look.particle and look.particle_rate > 0.0:
		timers[0] -= delta
		while timers[0] <= 0.0:
			timers[0] += 1.0 / look.particle_rate
			if _bits.size() >= MAX_PARTICLES:
				break
			var bit := Bit.new()
			bit.look = look
			bit.position = Vector2(randf_range(body.position.x, body.end.x), randf_range(body.position.y + body.size.y * 0.25, body.end.y))
			if look.particle_rise < 0.0:
				bit.position.y = randf_range(body.position.y - 4.0, body.position.y + body.size.y * 0.4)
			bit.velocity = Vector2(randf_range(-4.0, 4.0), -look.particle_rise)
			bit.life = look.particle_life * randf_range(0.8, 1.2)
			_bits.append(bit)
	if look.mote != StatusLookDef.Mote.NONE and look.mote_rate > 0.0:
		timers[1] -= delta
		while timers[1] <= 0.0:
			timers[1] += 1.0 / look.mote_rate
			if _bits.size() >= MAX_PARTICLES:
				break
			var from := Vector2(randf_range(body.position.x, body.end.x), randf_range(body.position.y + body.size.y * 0.3, body.end.y))
			_mote(look, from, look.mote)
	if look.mist_rate > 0.0 and look.element and look.element.residue.a > 0.0:
		timers[2] -= delta
		while timers[2] <= 0.0:
			timers[2] += 1.0 / look.mist_rate
			if _bits.size() >= MAX_PARTICLES:
				break
			var mist := Bit.new()
			mist.look = look
			mist.kind = Kind.MIST
			# Breathed out at the feet, drifting sideways and settling.
			mist.position = Vector2(randf_range(body.position.x - 2.0, body.end.x + 2.0), body.end.y - randf_range(0.0, 6.0))
			mist.velocity = Vector2(randf_range(-22.0, 22.0), randf_range(2.0, 8.0))
			mist.life = randf_range(0.5, 0.8)
			mist.size = 2 if randf() < 0.3 else 1
			_bits.append(mist)
	_spawn[look.status] = timers


func _mote(look: StatusLookDef, from: Vector2, kind: StatusLookDef.Mote) -> void:
	if _bits.size() >= MAX_PARTICLES:
		return
	var mote := Bit.new()
	mote.look = look
	mote.kind = Kind.MOTE
	mote.mote = kind
	mote.position = from
	match kind:
		StatusLookDef.Mote.EMBER:
			mote.velocity = Vector2(randf_range(-6.0, 6.0), -randf_range(28.0, 46.0))
			mote.life = randf_range(0.5, 0.9)
			mote.size = 1 if randf() < 0.6 else 2
		StatusLookDef.Mote.CHIP:
			mote.velocity = Vector2(randf_range(-10.0, 10.0), randf_range(-12.0, 4.0))
			mote.life = randf_range(0.35, 0.55)
			mote.size = 1 if randf() < 0.7 else 2
		_:
			mote.velocity = Vector2(randf_range(-4.0, 4.0), -randf_range(10.0, 18.0))
			mote.life = randf_range(0.5, 0.8)
			mote.size = 1
	_bits.append(mote)


func _draw() -> void:
	for bit in _bits:
		var t := clampf(bit.age / bit.life, 0.0, 0.999)
		var look := bit.look
		match bit.kind:
			Kind.SHEET:
				# The sheet's own frames, then its last cells dither away.
				if PixelDraw.dither(PixelDraw.cell_of(bit.position), 1.0 - maxf(t - 0.75, 0.0) / 0.25):
					_draw_frame(look.particle, look.particle_frames, t, bit.position, look.texel, look.particle_tint)
			Kind.BURST:
				if look.burst:
					_draw_frame(look.burst, look.burst_frames, t, bit.position, look.texel, look.burst_tint)
				elif look.element:
					_draw_burst(look.element, bit.position, t)
			Kind.CRUST:
				if bit.age >= 0.0 and look.crust:
					# Grows over its frames once, then holds the last one.
					var frame := mini(int(bit.age * 14.0), look.crust_frames - 1)
					_draw_frame(look.crust, look.crust_frames, -1.0, bit.position, look.texel, Color.WHITE, frame, bit.flip)
			Kind.MOTE:
				_draw_mote(bit, t)


## The mist bits, on the feet's node (under every body).
func _draw_mist() -> void:
	for bit in _bits:
		if bit.kind != Kind.MIST:
			continue
		var t := clampf(bit.age / bit.life, 0.0, 0.999)
		if PixelDraw.dither(PixelDraw.cell_of(bit.position), 1.0 - t):
			PixelDraw.pixel(_feet, bit.position, Color(bit.look.element.residue, 1.0) if t < 0.5 else bit.look.element.shade(0.75), bit.size)


func _draw_mote(bit: Bit, t: float) -> void:
	var look := bit.look
	var kind := bit.mote
	match kind:
		StatusLookDef.Mote.BUBBLE:
			# A bubble: a ring of one pixel that swells then pops into a few pixels.
			var color := look.mote_shade(0.2)
			if t < 0.85:
				PixelDraw.bit(self, VfxElementDef.Bit.RING, bit.position, 1, color, Vector2.UP, look.mote_shade(0.0))
			else:
				for offset in BUBBLE_POP:
					PixelDraw.pixel(self, bit.position + offset, color)
		_:
			# A chip or an ember: the element's bit, going down its ramp, the last third dithered.
			if not PixelDraw.dither(PixelDraw.cell_of(bit.position), 1.0 - maxf(t - 0.66, 0.0) / 0.34):
				return
			var shape := look.element.bit if look.element and kind == StatusLookDef.Mote.CHIP else VfxElementDef.Bit.SQUARE
			PixelDraw.bit(self, shape, bit.position, bit.size, look.mote_shade(t), bit.velocity, look.mote_shade(0.0) if t < 0.2 else Color.TRANSPARENT)


## A status's burst without a sheet: its element's bits flying out of the body and settling.
func _draw_burst(element: VfxElementDef, at: Vector2, t: float) -> void:
	for i in 6:
		var direction := Vector2.from_angle(TAU * i / 6.0 + 0.4)
		var where := at + direction * (6.0 + 18.0 * t) + Vector2(0, 30.0 * t * t)
		if PixelDraw.dither(PixelDraw.cell_of(where), 1.0 - t):
			PixelDraw.bit(self, element.bit, where, 2 if t < 0.4 else 1, element.shade(t), direction)


## A frame of `sheet` (frames in a row) at `texel` world units per texel, centered on `at`:
## the frame at `t` of its life, or `frame` when given.
func _draw_frame(sheet: Texture2D, frames: int, t: float, at: Vector2, texel: int, tint: Color, frame: int = -1, flip: bool = false) -> void:
	if sheet == null:
		return
	var width := int(sheet.get_width() / float(maxi(frames, 1)))
	if frame < 0:
		frame = mini(int(t * frames), frames - 1)
	var source := Rect2(frame * width, 0, width, sheet.get_height())
	var size := Vector2(width, sheet.get_height()) * texel
	if flip:
		draw_set_transform(PixelDraw.snap(at), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect_region(sheet, Rect2(PixelDraw.snap(-size * 0.5), size), source, Color(tint, 1.0))
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect_region(sheet, Rect2(PixelDraw.snap(at - size * 0.5), size), source, Color(tint, 1.0))
