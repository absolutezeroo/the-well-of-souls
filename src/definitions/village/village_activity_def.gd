class_name VillageActivityDef
extends Resource
## One appointment in a resident's day. Indoors currently means behind its authored doorway;
## room scenes can take over that destination when the village's building assets are supplied.

@export_range(0, 23.99) var start_hour: float = 0.0
@export var display_name: String
@export var destination: Vector2
@export var indoors: bool = false
