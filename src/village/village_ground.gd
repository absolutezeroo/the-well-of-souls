class_name VillageGround
extends RefCounted
## Draws the village floor: grass with worn variants, autotiled dirt paths and scattered flowers.
## Shared by the hub and the layout editor so both show the same ground. Every choice is a
## stable hash of the cell, so the square looks the same on every visit and every redraw.

const CELL := 32
const TILE := 16
const SALT_GRASS := 17
const SALT_DECOR := 53
const SALT_PATH := 91


static func draw(canvas: CanvasItem, def: VillageDef, keep_clear: Array[Rect2] = []) -> void:
	canvas.draw_rect(def.bounds, Color("19272b"))
	var paths := path_cells(def)
	var first := Vector2i((def.bounds.position / CELL).floor())
	var last := Vector2i((def.bounds.end / CELL).ceil())
	for y in range(first.y, last.y):
		for x in range(first.x, last.x):
			var cell := Vector2i(x, y)
			var at := Rect2(Vector2(cell * CELL), Vector2.ONE * CELL)
			if paths.has(cell):
				_draw_region(canvas, def.path_texture, at, _path_region(def, paths, cell), def.ground_tint)
				continue
			_draw_region(canvas, def.ground, at, _grass_region(def, cell), def.ground_tint)
			if def.decor_texture and not def.decor_regions.is_empty() and _roll(cell, SALT_DECOR) < def.decor_chance \
					and not keep_clear.any(func(r: Rect2) -> bool: return r.intersects(at)):
				var pick := def.decor_regions[_pick(cell, SALT_DECOR, def.decor_regions.size())]
				_draw_region(canvas, def.decor_texture, at, pick, def.ground_tint)


## The 32-pixel cells covered by the authored path rectangles (their union, on the grid).
static func path_cells(def: VillageDef) -> Dictionary[Vector2i, bool]:
	var cells: Dictionary[Vector2i, bool] = {}
	for path in def.paths:
		var first := Vector2i((path.position / CELL).round())
		var last := Vector2i((path.end / CELL).round())
		for y in range(first.y, maxi(last.y, first.y + 1)):
			for x in range(first.x, maxi(last.x, first.x + 1)):
				cells[Vector2i(x, y)] = true
	return cells


static func _grass_region(def: VillageDef, cell: Vector2i) -> Rect2:
	if def.ground_variants.is_empty() or _roll(cell, SALT_GRASS) >= def.ground_variant_chance:
		return def.ground_region
	return def.ground_variants[_pick(cell, SALT_GRASS, def.ground_variants.size())]


static func _path_region(def: VillageDef, paths: Dictionary[Vector2i, bool], cell: Vector2i) -> Rect2:
	if def.path_edges.x < 0:
		return def.path_region
	var n := paths.has(cell + Vector2i.UP)
	var s := paths.has(cell + Vector2i.DOWN)
	var w := paths.has(cell + Vector2i.LEFT)
	var e := paths.has(cell + Vector2i.RIGHT)
	var column := 1 if w and e else (0 if not w else 2)
	var row := 1 if n and s else (0 if not n else 2)
	if column == 1 and row == 1:
		if def.path_inner_corners.x >= 0:
			# Grass touching only by a corner: the inner corner whose grass faces that diagonal.
			var corner := Vector2i(-1, -1)
			if not paths.has(cell + Vector2i(1, 1)): corner = Vector2i(0, 0)
			elif not paths.has(cell + Vector2i(-1, 1)): corner = Vector2i(1, 0)
			elif not paths.has(cell + Vector2i(1, -1)): corner = Vector2i(0, 1)
			elif not paths.has(cell + Vector2i(-1, -1)): corner = Vector2i(1, 1)
			if corner.x >= 0:
				return Rect2(def.path_inner_corners + Vector2(corner * TILE), Vector2.ONE * TILE)
		if not def.path_details.is_empty() and _roll(cell, SALT_PATH) < 0.08:
			return def.path_details[_pick(cell, SALT_PATH, def.path_details.size())]
	return Rect2(def.path_edges + Vector2(column, row) * TILE, Vector2.ONE * TILE)


static func _draw_region(canvas: CanvasItem, texture: Texture2D, at: Rect2, region: Rect2, tint: Color) -> void:
	if texture:
		canvas.draw_texture_rect_region(texture, at, region, tint)


## A stable number in [0, 1) for a cell: no RandomNumberGenerator, so nothing reseeds or drifts.
static func _roll(cell: Vector2i, salt: int) -> float:
	return float(_hash(cell, salt) % 10007) / 10007.0


static func _pick(cell: Vector2i, salt: int, count: int) -> int:
	return int(_hash(cell, salt * 7 + 3) % count)


static func _hash(cell: Vector2i, salt: int) -> int:
	var h := (cell.x * 73856093) ^ (cell.y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff
