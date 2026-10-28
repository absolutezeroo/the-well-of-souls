class_name Minimap
extends Control
## The explored part of the floor, as a little map: rooms and corridors seen so far, holes,
## stairs (violet while sealed, shown even unexplored once open), unopened chests, a running
## ambush, a pact door once seen (its room outlined during the fight), the boss, the hero, and
## the last monsters the seal still wants (StairsSeal).
## The explored cells live in an image (one pixel per cell) updated as the hero discovers them.
## `whole_floor` shows the entire floor fitted to the control (the big map) instead of a window
## around the hero.

signal tapped

const FLOOR_COLOR := Color(0.85, 0.79, 0.68, 0.75)
const HOLE_COLOR := Color(0.08, 0.06, 0.09, 0.9)
## Deep water (a shaped room's pool).
const WATER_COLOR := Color(0.32, 0.55, 0.72, 0.85)
const BACKGROUND := Color(0.06, 0.04, 0.08, 0.6)
const BIG_MAP_BACKGROUND := Color(0.06, 0.04, 0.08, 0.92)
const BORDER := Color(Palette.GOLD, 0.5)
const HERO_COLOR := Color(1, 1, 1)
const STAIRS_COLOR := Palette.GOLD
const CHEST_COLOR := Color(1, 0.65, 0.2)
const DANGER_COLOR := Color(1, 0.3, 0.3)
const PACT_COLOR := Color(0.95, 0.2, 0.3)
const SPENT_COLOR := Color(0.55, 0.5, 0.5)
const REDRAW_INTERVAL := 0.1
## How long a tap's pressed frame shows (seconds).
const PRESS_TIME := 0.15

@export var whole_floor := false
## Pixels per cell around the hero (the small map).
@export var cell_pixels := 4.0

var _world: World
var _image: Image
var _texture: ImageTexture
var _redraw_timer := 0.0
## A tap's pressed look: 1 as the finger lands, fading out in PRESS_TIME (a gold frame).
var _press := 0.0:
	set(value):
		_press = value
		queue_redraw()
var _press_tween: Tween


func bind_world(world: World) -> void:
	if _world == world:
		return
	# (One World lives per Game today; another bound later must not leave this one calling in.)
	if is_instance_valid(_world):
		if _world.map_reset.is_connected(_rebuild):
			_world.map_reset.disconnect(_rebuild)
		if _world.cells_changed.is_connected(_update_cells):
			_world.cells_changed.disconnect(_update_cells)
	_world = world
	world.map_reset.connect(_rebuild)
	world.cells_changed.connect(_update_cells)
	_rebuild()


func _rebuild() -> void:
	if _world == null or _world.map == null:
		return
	var map := _world.map
	_image = Image.create_empty(map.width, map.height, false, Image.FORMAT_RGBA8)
	for y in map.height:
		for x in map.width:
			_paint(Vector2i(x, y))
	_texture = ImageTexture.create_from_image(_image)
	queue_redraw()


func _update_cells(cells: Array[Vector2i]) -> void:
	if _image == null or _image.get_width() != _world.map.width:
		_rebuild()
		return
	for cell in cells:
		_paint(cell)
	_texture.update(_image)


func _paint(cell: Vector2i) -> void:
	var color := Color.TRANSPARENT
	if _world.is_explored(cell) and _world.map.is_floor(cell):
		color = HOLE_COLOR if _world.has_pit(cell) else (WATER_COLOR if _world.is_pool(cell) else FLOOR_COLOR)
	_image.set_pixelv(cell, color)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_INTERVAL
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_show_press()
		tapped.emit()


## Where cell (0, 0) is drawn and how big a cell is.
func _layout() -> Array:
	var map := _world.map
	if whole_floor:
		var factor := minf(size.x / map.width, size.y / map.height)
		var origin := (size - Vector2(map.width, map.height) * factor) * 0.5
		return [origin, factor]
	var hero := _world.player.global_position / map.tile_size if _world.player else Vector2(map.start_cell)
	return [size * 0.5 - hero * cell_pixels, cell_pixels]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BIG_MAP_BACKGROUND if whole_floor else BACKGROUND)
	if _world and _texture and _world.map:
		var layout := _layout()
		var origin: Vector2 = layout[0]
		var factor: float = layout[1]
		var map := _world.map
		# Only what fits in the control (no drawing outside it).
		var view := Rect2(-origin / factor, size / factor).intersection(Rect2(0, 0, map.width, map.height))
		if view.has_area():
			draw_texture_rect_region(_texture, Rect2(origin + view.position * factor, view.size * factor), view)
		_draw_markers(origin, factor)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER, false, 2.0)
	if _press > 0.0:
		draw_rect(Rect2(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0), Color(Palette.GOLD, _press), false, 4.0)


## Pressed: a bright gold frame inside the border, gone in PRESS_TIME.
func _show_press() -> void:
	if _press_tween:
		_press_tween.kill()
	_press = 1.0
	_press_tween = create_tween()
	_press_tween.tween_property(self, "_press", 0.0, PRESS_TIME)


func _draw_markers(origin: Vector2, factor: float) -> void:
	var map := _world.map
	var dot := maxf(factor * 0.9, 3.0)
	var sealed := _world.seal.is_sealed()
	for cell in _world.stairs_cells:
		if _world.is_explored(cell) or not sealed:
			_marker(origin + (Vector2(cell) + Vector2(0.5, 0.5)) * factor, dot * 1.4, Palette.SEAL if sealed else STAIRS_COLOR)
	if _world.seal.reveals_monsters():
		for monster in _world.get_hostiles(Actor.Faction.PLAYER):
			_marker(origin + monster.global_position / map.tile_size * factor, dot * 0.8, DANGER_COLOR)
	for node in get_tree().get_nodes_in_group("chests"):
		var chest := node as Chest
		var cell := map.world_to_cell(chest.global_position)
		if not chest.is_open and _world.is_explored(cell):
			_marker(origin + chest.global_position / map.tile_size * factor, dot, CHEST_COLOR)
	if _world.ambush and _world.ambush.state == AmbushRoom.State.FIGHTING:
		var room := _world.ambush.room
		_draw_clipped_outline(Rect2(origin + Vector2(room.position) * factor, Vector2(room.size) * factor), DANGER_COLOR)
	var pact := _world.pact
	if pact and is_instance_valid(pact):
		if pact.state == AmbushRoom.State.FIGHTING:
			_draw_clipped_outline(Rect2(origin + Vector2(pact.room.position) * factor, Vector2(pact.room.size) * factor), PACT_COLOR)
		elif pact.seen:
			var door := origin + (Vector2(pact.door_cell) + Vector2(0.5, 0.5)) * factor
			_marker(door, dot * 1.6, PACT_COLOR if pact.is_open_offer() else SPENT_COLOR)
	# The room trial's things still to do, once seen: souls held, lanterns out, the sealed door.
	var trial := _world.room_trial
	if trial and is_instance_valid(trial) and not trial.completed:
		var mark := trial.def.color
		if trial is CaptiveSoulsTrial:
			for soul in (trial as CaptiveSoulsTrial).souls:
				if not soul.freed and _world.is_explored(map.world_to_cell(soul.global_position)):
					_marker(origin + soul.global_position / map.tile_size * factor, dot * 1.2, mark)
		elif trial is SealTrial:
			var seal := trial as SealTrial
			for lantern in seal.lanterns:
				if not lantern.is_lit and _world.is_explored(map.world_to_cell(lantern.global_position)):
					_marker(origin + lantern.global_position / map.tile_size * factor, dot * 1.2, mark)
			if _world.is_explored(seal.door_cell):
				_marker(origin + (Vector2(seal.door_cell) + Vector2(0.5, 0.5)) * factor, dot * 1.6, mark)
	if _world.arena and _world.arena.boss and not _world.arena.boss.is_dead and _world.arena.is_started:
		_marker(origin + _world.arena.boss.global_position / map.tile_size * factor, dot * 1.6, DANGER_COLOR)
	if _world.player:
		_marker(origin + _world.player.global_position / map.tile_size * factor, dot * 1.2, HERO_COLOR)


func _marker(at: Vector2, size_px: float, color: Color) -> void:
	var rect := Rect2(at - Vector2.ONE * size_px * 0.5, Vector2.ONE * size_px)
	if Rect2(Vector2.ZERO, size).encloses(rect):
		draw_rect(rect.grow(1.0), Color(0, 0, 0, 0.7))
		draw_rect(rect, color)


func _draw_clipped_outline(rect: Rect2, color: Color) -> void:
	var clipped := rect.intersection(Rect2(Vector2.ZERO, size))
	if clipped.has_area():
		draw_rect(clipped, Color(color, 0.15))
		draw_rect(clipped, color, false, 2.0)
