class_name VillageNavigation
extends RefCounted
## A small surface-only grid, rebuilt when static progress changes. Paths are allocated only
## for a new appointment or changed obstacles, never for every frame or every resident.

const CELL := 16.0
const CLEARANCE := 7.0
var grid := AStarGrid2D.new()
var origin: Vector2
var rooms: Dictionary[VillageInteriorDef, VillageNavigation] = {}


func rebuild(def: VillageDef) -> void:
	_setup(def.bounds)
	rooms.clear()
	for room in def.interiors:
		var inside := VillageNavigation.new()
		inside._setup(room.world_walk_bounds())
		for wall in room.walls:
			inside._block(Rect2(room.offset + wall.position, wall.size))
		for prop in room.props:
			if prop.collision.has_area():
				inside._block(Rect2(room.offset + prop.position + prop.collision.position, prop.collision.size))
		rooms[room] = inside
	for prop in def.props:
		if prop.collision.has_area() and VillageProgress.prop_present(prop):
			_block(Rect2(prop.position + prop.collision.position, prop.collision.size))
	_block(Rect2(def.well + Vector2(-34, -22), Vector2(68, 44)))
	_block(Rect2(def.noticeboard + Vector2(-24, -12), Vector2(48, 12)))


func _setup(bounds: Rect2) -> void:
	origin = bounds.position
	grid.region = Rect2i(Vector2i.ZERO, Vector2i(ceili(bounds.size.x / CELL), ceili(bounds.size.y / CELL)))
	grid.cell_size = Vector2.ONE * CELL
	grid.offset = origin + Vector2.ONE * CELL * 0.5
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()


func path(from: Vector2, to: Vector2, room: VillageInteriorDef = null) -> PackedVector2Array:
	if room:
		return rooms[room].path(from, to) if rooms.has(room) else PackedVector2Array()
	var first := _cell(from)
	var last := _cell(to)
	if not grid.is_in_boundsv(first) or not grid.is_in_boundsv(last) or grid.is_point_solid(first) or grid.is_point_solid(last):
		return PackedVector2Array()
	var points := grid.get_point_path(first, last)
	if not points.is_empty():
		points.append(to)
	return points


func _cell(at: Vector2) -> Vector2i:
	return Vector2i(((at - origin) / CELL).floor())


func _block(rectangle: Rect2) -> void:
	var area := rectangle.grow(CLEARANCE + CELL * 0.5)
	for y in range(grid.region.position.y, grid.region.end.y):
		for x in range(grid.region.position.x, grid.region.end.x):
			var cell := Vector2i(x, y)
			if area.has_point(grid.get_point_position(cell)):
				grid.set_point_solid(cell)
