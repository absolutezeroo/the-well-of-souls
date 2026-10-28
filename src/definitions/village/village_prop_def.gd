class_name VillagePropDef
extends Resource
## An authored atlas prop and its independent ground collision, optionally restored by play.

@export var texture: Texture2D
@export var region: Rect2
@export var position: Vector2
@export var art_scale: float = 2.0
## Stays white: no tint on Kagari's props, its mood is light (decision 0009, unit.village).
@export var tint: Color = Color.WHITE
@export var collision: Rect2
@export var cleared_by: VillageQuestDef
@export var lit_by: VillageServiceDef
## What a lamp shows until `lit_by` is restored: the pack's own unlit piece (never the lit one
## darkened by a multiply: decision 0009).
@export var unlit: Texture2D
