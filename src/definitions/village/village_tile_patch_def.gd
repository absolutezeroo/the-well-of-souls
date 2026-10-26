class_name VillageTilePatchDef
extends Resource
## A static rectangular patch of repeated atlas tiles, authored in room-local coordinates.

@export var texture: Texture2D
@export var region: Rect2
@export var area: Rect2
@export var art_scale: float = 2.0
@export var tint: Color = Color.WHITE
