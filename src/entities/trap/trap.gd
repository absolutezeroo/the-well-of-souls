class_name Trap
extends Area2D
## A floor trap built from a TrapDef. Hurts every actor standing on it when it fires,
## monsters included (what firing does is up to the TrapDef: see ArrowTrapDef). See TrapDef for the cycle.

enum Phase { IDLE, WARNING, ACTIVE }

const SIZE := 32.0

var def: TrapDef
var world: World
var phase := Phase.IDLE
## TIMED traps: seconds into the cycle at start, so neighbours can fire in a wave.
var cycle_offset := 0.0
## Arrow traps: the wall cell holding the slit, and where it shoots (zero = no launcher).
var launcher_cell := Vector2i.ZERO
var launcher_direction := Vector2.ZERO

var _timer := 0.0
## Shots of a volley still to come (TrapDef.volley_shot(): an arrow trap's arrows), the seconds
## to the next, and between two.
var _volley_left := 0
var _volley_timer := 0.0
var _volley_interval := 0.0
var _hit_this_time: Array[Actor] = []
var _anim_time := 0.0
## What the last _draw() showed (_draw_key()): redrawn only when it changes.
var _drawn_key := -1


func setup(trap_def: TrapDef, offset: float = 0.0) -> void:
	def = trap_def
	cycle_offset = offset
	collision_layer = 0
	collision_mask = Layers.PLAYER | Layers.MONSTERS
	monitorable = false
	add_to_group("traps")


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SIZE, SIZE) * 0.8
	($CollisionShape2D as CollisionShape2D).shape = shape
	_timer = def.idle_time - fmod(cycle_offset, def.idle_time + def.warning_seconds() + def.active_time)
	if def.trigger == TrapDef.Trigger.STEP:
		_timer = 0.0
	if _timer < 0.0:
		# The offset lands after the idle part: start straight in the warning.
		_enter(Phase.WARNING)


## Wires the trap to an arrow slit in the wall at `cell`, shooting along `direction`.
func set_launcher(cell: Vector2i, direction: Vector2) -> void:
	launcher_cell = cell
	launcher_direction = direction


## Where the arrows start: just out of the wall, on the room's side.
func get_launcher_position() -> Vector2:
	return world.map.cell_to_world(launcher_cell) + launcher_direction * (world.map.tile_size * 0.5 + 8.0)


## `count` more shots, one every `interval` seconds (TrapDef.volley_shot()), on the trap's own
## physics clock: they stop with it (freed, or its floor out of the tree).
func start_volley(count: int, interval: float) -> void:
	_volley_left = maxi(count, 0)
	_volley_interval = interval
	_volley_timer = interval


func _physics_process(delta: float) -> void:
	_anim_time += delta
	if _volley_left > 0:
		_volley_timer -= delta
		if _volley_timer <= 0.0:
			_volley_left -= 1
			_volley_timer = _volley_interval
			def.volley_shot(self)
	match phase:
		Phase.IDLE:
			if def.trigger == TrapDef.Trigger.STEP:
				if _timer > 0.0:
					_timer -= delta  # cooling down after firing
				elif _someone_on_it():
					_enter(Phase.WARNING)
			else:
				_timer -= delta
				if _timer <= 0.0:
					_enter(Phase.WARNING)
		Phase.WARNING:
			_timer -= delta
			if _timer <= 0.0:
				_enter(Phase.ACTIVE)
		Phase.ACTIVE:
			_timer -= delta
			def.while_active(self)
			if _timer <= 0.0:
				_enter(Phase.IDLE)
	var key := _draw_key()
	if key != _drawn_key:
		_drawn_key = key
		queue_redraw()


## What _draw() shows, as a number: the phase, and the warning's shake or the active frame.
func _draw_key() -> int:
	match phase:
		Phase.WARNING:
			return 10 + int(_anim_time * 20.0) % 2
		Phase.ACTIVE:
			return 100 + (mini(int(_anim_time * def.active_fps), def.active_frames - 1) if def.active_sheet else 0)
	return 0


func _enter(next: Phase) -> void:
	phase = next
	_anim_time = 0.0
	match next:
		Phase.IDLE:
			_timer = def.idle_time
		Phase.WARNING:
			_timer = def.warning_seconds()
			# A plate stepped on clicks: the warning's sound (a timed trap's rhythm is its own).
			if def.trigger == TrapDef.Trigger.STEP:
				Sfx.play_warning(global_position)
		Phase.ACTIVE:
			_timer = def.active_time
			_hit_this_time.clear()
			Sfx.play_at(def.sound, global_position, -4.0)
			def.on_fire(self)


func _someone_on_it() -> bool:
	for body in get_overlapping_bodies():
		if body is Actor and not (body as Actor).is_dead:
			return true
	return false


## Hurts every actor standing on the trap (once per activation).
func hurt_overlapping() -> void:
	for body in get_overlapping_bodies():
		var actor := body as Actor
		if actor == null or actor.is_dead or _hit_this_time.has(actor):
			continue
		_hit_this_time.append(actor)
		var hit := Combat.make_secondary_hit(null, def.damage_on(world))
		hit.cause = &"trap"
		hit.knockback = global_position.direction_to(actor.global_position) * def.knockback
		hit.status = def.status
		actor.take_hit(hit)


func _draw() -> void:
	if def == null:
		return
	var half := SIZE * 0.5
	var rect := Rect2(-half, -half, SIZE, SIZE)
	var base := def.base_texture
	if def.pressed_texture and phase != Phase.IDLE:
		base = def.pressed_texture
	if base:
		draw_texture_rect(base, rect, false)
	_draw_launcher()
	if def.active_sheet == null or phase == Phase.IDLE:
		return
	var frames := def.active_frames
	var frame_size := Vector2(def.active_sheet.get_width() / float(frames), def.active_sheet.get_height())
	if phase == Phase.WARNING:
		# The danger peeks out and rattles: its lower third (whole rows), first frame, at the art's
		# own 2x like the active frames, shaking by a whole art pixel.
		var rows := maxf(roundf(frame_size.y * 0.35), 1.0)
		var source := Rect2(0, frame_size.y - rows, frame_size.x, rows)
		var size := source.size * (SIZE / 16.0)
		var shake := Vector2(PixelDraw.PX if int(_anim_time * 20.0) % 2 == 0 else 0.0, 0.0)
		draw_texture_rect_region(def.active_sheet, Rect2(PixelDraw.snap(Vector2(-size.x * 0.5, half - size.y)) + shake, size), source)
	else:
		# Plays once and holds its last frames while active.
		var frame := mini(int(_anim_time * def.active_fps), frames - 1)
		var source := Rect2(frame * frame_size.x, 0, frame_size.x, frame_size.y)
		var size := frame_size * (SIZE / 16.0)
		draw_texture_rect_region(def.active_sheet, Rect2(PixelDraw.snap(Vector2(-size.x * 0.5, half - size.y)), size), source)


## The arrow slit, in its wall.
func _draw_launcher() -> void:
	var arrow_trap := def as ArrowTrapDef
	if arrow_trap == null or arrow_trap.launcher_texture == null or launcher_direction == Vector2.ZERO:
		return
	var center := world.map.cell_to_world(launcher_cell) - global_position
	var shake := Vector2(PixelDraw.PX if int(_anim_time * 20.0) % 2 == 0 else 0.0, 0.0) if phase == Phase.WARNING else Vector2.ZERO  # whole art pixels
	draw_set_transform(center + shake, launcher_direction.angle() - PI * 0.5)
	draw_texture_rect(arrow_trap.launcher_texture, Rect2(-SIZE * 0.5, -SIZE * 0.5, SIZE, SIZE), false)
	draw_set_transform(Vector2.ZERO)
