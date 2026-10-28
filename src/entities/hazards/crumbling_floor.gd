class_name CrumblingFloor
extends Node2D
## A cracked floor cell (PitDef with a crumble time). Holds until someone walks on it,
## shakes for a moment, then gives way and becomes a hole.

enum State { SOLID, CRACKING }

## The cell darkens to the cracks' own dark as it gives way.
const SINKING := Color("141012")

var def: PitDef
var world: World
var cell: Vector2i
var state := State.SOLID

var _time_left := 0.0


func setup(pit_def: PitDef, floor_world: World, at_cell: Vector2i) -> void:
	def = pit_def
	world = floor_world
	cell = at_cell
	position = world.map.cell_to_world(cell)
	z_index = -9
	add_to_group("crumbling_floors")


func _physics_process(delta: float) -> void:
	if state == State.CRACKING:
		_time_left -= delta
		queue_redraw()
		if _time_left <= 0.0:
			collapse()


## Someone stands on it (World checks the actors' cells): it starts to give way.
func step_on() -> void:
	if state != State.SOLID:
		return
	state = State.CRACKING
	_time_left = def.crumble_time
	Sfx.play_world(def.crack_sound, global_position, -4.0)
	Vfx.dust(world, global_position, 0.8)


## Gives way now: the cell becomes a hole (whoever stands on it falls). `quiet`: no sound or
## dust (a resumed floor where it gave way before quitting, World.spent_data()).
func collapse(quiet: bool = false) -> void:
	if not is_inside_tree():
		return
	world.crack_collapsed(cell, def)
	queue_free()
	if quiet:
		return
	Sfx.play_world(def.crumble_sound, global_position)
	Vfx.burst(world, Vfx.DEATH_CHUNKS, global_position, def.debris_color)
	Vfx.dust(world, global_position, 1.5)


## Its cracks drawn whole and opaque (alpha 1-bit, docs/art-bible.md "Palette"): a danger stands
## out from the floor at rest (it was drawn at 55 % before). Giving way, they jolt by whole art
## pixels and the cell darkens by dithering, never by a see-through veil.
func _draw() -> void:
	if def.crack_texture == null:
		return
	var half := world.map.tile_size * 0.5
	var offset := Vector2.ZERO
	if state == State.CRACKING:
		var t := 1.0 - _time_left / maxf(def.crumble_time, 0.01)
		offset = PixelDraw.snap(Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0)) * (1.0 + 2.0 * t))
		# The cell darkens as the floor sinks.
		var cells := roundi(half * 2.0 / PixelDraw.PX)
		var corner := PixelDraw.cell_of(Vector2(-half, -half))
		for y in cells:
			for x in cells:
				var at := corner + Vector2i(x, y)
				if PixelDraw.dither(at, 0.35 * t):
					PixelDraw.cell(self, at, SINKING)
	draw_texture_rect(def.crack_texture, Rect2(Vector2(-half, -half) + offset, Vector2(half, half) * 2.0), false)
