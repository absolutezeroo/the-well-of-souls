class_name VillageActivityDef
extends Resource
## One appointment in a resident's day. Destination is local to room, or on the village square.
## Indoors hides ordinary rest behind a doorway where no enterable room has been authored yet.

@export_range(0, 23.99) var start_hour: float = 0.0
@export var display_name: String
@export var destination: Vector2
@export var room: VillageInteriorDef
@export var indoors: bool = false
