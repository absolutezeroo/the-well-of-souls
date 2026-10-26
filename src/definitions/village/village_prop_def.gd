class_name VillagePropDef
extends Resource
## An authored atlas prop and its independent ground collision, optionally restored by play.

@export var texture: Texture2D
@export var region: Rect2
@export var position: Vector2
@export var art_scale: float = 2.0
@export var tint: Color = Color.WHITE
@export var collision: Rect2
@export var cleared_by: VillageQuestDef
@export var lit_by: VillageServiceDef
