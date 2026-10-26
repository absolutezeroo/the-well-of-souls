class_name VillageDef
extends Resource
## The small persistent surface hub. Its layout, voices and economy live together in data.

@export var display_name: String
@export var description: String
@export var restored_text: String
@export var bounds: Rect2
@export var spawn: Vector2
@export var well: Vector2
@export var shrine: Vector2
@export var memorial: Vector2
@export var move_speed: float = 160.0
@export var interaction_reach: float = 65.0
@export var well_icon: Texture2D
@export var shrine_icon: Texture2D
@export var path_texture: Texture2D
@export var path_region: Rect2
@export var paths: Array[Rect2] = []
@export var ground: Texture2D
@export var ground_region: Rect2
@export var residents: Array[VillageResidentDef] = []
@export var quests: Array[VillageQuestDef] = []
@export var services: Array[VillageServiceDef] = []
@export var props: Array[VillagePropDef] = []
