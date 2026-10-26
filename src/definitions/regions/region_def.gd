class_name RegionDef
extends Resource
## Fixed region geometry in data, reusing DungeonMap and biome art. No procedural regeneration
## on revisits. This first layout supports walls and floor; other ground/actors come later.

const MAX_SIDE := 128
@export var id: String
@export var display_name: String
@export var layout_version := 1
@export var biome: BiomeDef
@export var tile_size := 32
@export var combat_depth := 1
@export var visual_seed := 1
## Equal-length rows: # wall, . floor. Outer border must be wall.
@export var rows: PackedStringArray
@export var entries: Dictionary[String, Vector2i] = {}
@export var links: Array[RegionLinkDef] = []
@export var items: Array[RegionItemDef] = []


func make_map(entry_id: String) -> DungeonMap:
	var map := DungeonMap.new(rows[0].length(), rows.size(), tile_size)
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == ".":
				map.set_floor(Vector2i(x, y))
	map.start_cell = entries[entry_id]
	map.stairs_cell = map.start_cell
	return map


## Geometry and authored spawns must match before old positions can be applied. Visual biome
## tweaks do not invalidate a region; changing its geometry requires an explicit migration.
func stamp() -> String:
	var points := {}
	for key in entries:
		points[key] = [entries[key].x, entries[key].y]
	var spawns: Array = []
	for item in items:
		spawns.append([item.id, item.cell.x, item.cell.y, RunSave.ref(item.item)])
	return JSON.stringify([id, layout_version, tile_size, rows, points, spawns]).sha256_text()


func valid() -> bool:
	if id.is_empty() or display_name.is_empty() or biome == null or biome.theme == null \
			or layout_version < 1 or tile_size < 1 or combat_depth < 1 \
			or rows.size() < 3 or rows.size() > MAX_SIDE or entries.is_empty():
		return false
	var width := rows[0].length()
	if width < 3 or width > MAX_SIDE:
		return false
	for y in rows.size():
		if rows[y].length() != width:
			return false
		for x in width:
			if not rows[y][x] in "#." or ((x == 0 or y == 0 or x == width - 1 or y == rows.size() - 1) and rows[y][x] != "#"):
				return false
	var map := make_map(entries.keys()[0])
	var reachable: Dictionary[Vector2i, bool] = {}
	var pending: Array[Vector2i] = [map.start_cell]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		if reachable.has(cell) or not map.is_ground(cell):
			continue
		reachable[cell] = true
		for direction in GridDirs.FOUR:
			pending.append(cell + direction)
	for key in entries:
		if key.is_empty() or not reachable.has(entries[key]):
			return false
	var identifiers: Dictionary[String, bool] = {}
	for link in links:
		if link == null or link.id.is_empty() or identifiers.has(link.id) or not reachable.has(link.cell):
			return false
		identifiers[link.id] = true
		for cell in entries.values():
			if Vector2(cell - link.cell).length() < 2.0:
				return false  # never spawn inside an exit's trigger and bounce straight back
	identifiers.clear()
	for item in items:
		if item == null or item.id.is_empty() or identifiers.has(item.id) or not reachable.has(item.cell) \
				or item.item == null or not CampaignFormat.item_data(LootRoller.to_data(item.item)):
			return false
		identifiers[item.id] = true
	return true


## A conservative circle-to-tile clearance check, also rejects a restored exit-trigger position.
func safe_position(map: DungeonMap, point: Vector2, radius: float) -> bool:
	if not point.is_finite() or radius <= 0.0 or radius >= tile_size * 0.5:
		return false
	for dx in GridDirs.SIGNS:
		for dy in GridDirs.SIGNS:
			if not map.is_ground(map.world_to_cell(point + Vector2(dx, dy) * radius)):
				return false
	for link in links:
		if point.distance_to(map.cell_to_world(link.cell)) < radius + Stairs.SIZE:
			return false
	return true
