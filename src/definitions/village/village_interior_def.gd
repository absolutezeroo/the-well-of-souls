class_name VillageInteriorDef
extends Resource
## A peaceful room reached from a village doorway. Coordinates are local except offset/door.
## Rooms share the surface clock, walker and profile; entering never loads or changes a run.

@export var id: StringName
@export var display_name: String
@export var offset: Vector2
@export var bounds: Rect2
@export var walk_bounds: Rect2
@export var camera_center: Vector2
@export var camera_zoom: float = 1.5
@export var door: Vector2
@export var return_position: Vector2
@export var spawn: Vector2
@export var exit: Vector2
@export var shrine: Vector2
@export var has_shrine: bool = false
@export var light: Color = Color.WHITE
@export var backdrop: Color = Color("191c22")
@export var tiles: Array[VillageTilePatchDef] = []
@export var walls: Array[Rect2] = []
@export var props: Array[VillagePropDef] = []


func world_bounds() -> Rect2:
	return Rect2(offset + bounds.position, bounds.size)


func world_walk_bounds() -> Rect2:
	return Rect2(offset + walk_bounds.position, walk_bounds.size)
