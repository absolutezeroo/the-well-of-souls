class_name DungeonTheme
extends Resource
## Look and music of a floor. Tiles are referenced by index in their atlas
## (left to right, top to bottom, starting at 0; 16x16 tiles).
##
## Walls use a "cliff" tileset: the top of the walls is a plateau with a rim, and the two wall
## cells right above the floor show a cliff face: its top (the plateau's rim and the face's
## upper part) over its bottom (the face's foot), two tiles of the same face that join. A wall
## one cell thick (floor right above it) shows the plateau's short edge (`wall_bottom`).

@export var tint: Color = Color.WHITE
## How the floor is lit: its own light, and the colors of the light as it fades (LightField).
@export var lighting: LightingDef
@export var music: AudioStream
## Footsteps, echo, background sounds, particles, fog.
@export var ambience: AmbienceDef

@export_group("Floor")
@export var floor_atlas: Texture2D
@export var floor_tiles: PackedInt32Array = []
@export var decor_atlas: Texture2D
@export var decor_tiles: PackedInt32Array = []
@export_range(0.0, 1.0) var decor_chance: float = 0.05

@export_group("Walls")
@export var wall_atlas: Texture2D
## Flat color of the plateau (wall tops far from the floor and everything outside the map).
@export var wall_top_color: Color = Color(1.0, 0.8, 0.55)
## Plateau edges, by side that touches the floor.
@export var wall_top_left: int = 101
@export var wall_top: int = 102
@export var wall_top_right: int = 103
@export var wall_left: int = 121
@export var wall_center: int = 122
@export var wall_right: int = 123
## The plateau's short edge (rim + a lip of cliff): a wall one cell thick, floor above and below.
@export var wall_bottom_left: int = 141
@export var wall_bottom: int = 142
@export var wall_bottom_right: int = 143
## Plateau corner touching the floor only diagonally (inner corners).
@export var inner_top_left: int = 160
@export var inner_top_right: int = 161
@export var inner_bottom_left: int = 180
@export var inner_bottom_right: int = 181
## Both top or both bottom diagonals.
@export var inner_top: int = 182
@export var inner_bottom: int = 183
## The cliff face's top (the plateau's rim, the face going down): the wall two cells above the
## floor. Left and right ends, middle, and one cell wide.
@export var face_top_left: int = 104
@export var face_top: int = 105
@export var face_top_right: int = 106
@export var face_top_single: int = 111
## The cliff face's foot (wall with floor right below it), joining the top above it.
@export var face_left: int = 144
@export var face: int = 145
@export var face_right: int = 146
## Cliff face only one cell wide (the tileset's narrow face, outlined both sides; the column
## beside the plain face is a stretch of face shaded on one side, not an end).
@export var face_single: int = 151

@export_group("Mist")
## The mist over the plateau above the walls (PlateauMist): its dark depths, its lighter wisps,
## and how thick it gets (0: none, the plateau's flat color).
@export var mist_deep: Color = Color(0.08, 0.06, 0.12)
@export var mist_wisp: Color = Color(0.55, 0.55, 0.65)
@export_range(0.0, 1.0) var mist_density: float = 0.85

@export_group("Objects")
## 16x16 sheet holding the stairs and the gate spikes.
@export var props_atlas: Texture2D
@export var stairs_tile: int = 17
## Spikes that close the exits of a boss arena.
@export var gate_tile: int = 16


static func region(atlas: Texture2D, index: int) -> Rect2:
	var columns := int(atlas.get_width() / 16.0)
	return Rect2((index % columns) * 16, int(index / float(columns)) * 16, 16, 16)


func stairs_texture() -> AtlasTexture:
	return _prop(stairs_tile)


func gate_texture() -> AtlasTexture:
	return _prop(gate_tile)


func _prop(index: int) -> AtlasTexture:
	if props_atlas == null:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = props_atlas
	texture.region = region(props_atlas, index)
	return texture


## Stable pseudo-random pick for a cell, so redraws never shuffle the decor.
static func pick(tiles: PackedInt32Array, cell: Vector2i, salt: int = 0) -> int:
	if tiles.is_empty():
		return -1
	return tiles[absi(hash(Vector3i(cell.x, cell.y, salt))) % tiles.size()]


static func chance(cell: Vector2i, probability: float, salt: int = 0) -> bool:
	return float(absi(hash(Vector3i(cell.x, cell.y, salt + 7))) % 10000) / 10000.0 < probability
