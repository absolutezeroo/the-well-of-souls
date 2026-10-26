class_name RegionChestDef
extends Resource
## An authored chest. Trap selection is explicit, never rerolled on a revisit.

@export var id: String
@export var cell: Vector2i
@export var chest: ChestDef
@export var trapped := false
