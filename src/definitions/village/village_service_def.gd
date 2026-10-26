class_name VillageServiceDef
extends Resource
## A one-time restoration sold at the surface; never grants a run an item or statistic.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var cost: int = 0
@export var requires_quest: VillageQuestDef
