class_name VillageDef
extends Resource
## The small persistent surface hub. Its layout, voices and economy live together in data.

@export var display_name: String
@export var description: String
@export var restored_text: String
@export var bounds: Rect2
@export var spawn: Vector2
@export var well: Vector2
@export var interiors: Array[VillageInteriorDef] = []
@export var noticeboard: Vector2
@export var clock: VillageClockDef
@export var atmosphere: VillageAtmosphereDef
@export var memorial: Vector2
@export var move_speed: float = 160.0
@export var interaction_reach: float = 65.0
@export var well_icon: Texture2D
@export var path_texture: Texture2D
@export var path_region: Rect2
@export var paths: Array[Rect2] = []
@export var ground: Texture2D
@export var ground_region: Rect2
## Worn grass tiles mixed into the plain one so the square does not read as a repeated stamp.
@export var ground_variants: Array[Rect2] = []
@export_range(0.0, 1.0) var ground_variant_chance := 0.25
## Multiplies the ground and paths; the clock's daylight shades the whole village on top of it.
@export var ground_tint := Color.WHITE
## Paths are autotiled from path_texture: the 3x3 patch whose borders fade into the grass
## (top-left tile at path_edges) and the 2x2 inner corners (grass in the shared middle).
@export var path_edges := Vector2(-1, -1)
@export var path_inner_corners := Vector2(-1, -1)
## Rare marks on the paths' middle (twigs, a stone).
@export var path_details: Array[Rect2] = []
## Flat flowers and tufts scattered on the grass, drawn beneath everything that walks.
@export var decor_texture: Texture2D
@export var decor_regions: Array[Rect2] = []
@export_range(0.0, 1.0) var decor_chance := 0.12
@export var residents: Array[VillageResidentDef] = []
@export var quests: Array[VillageQuestDef] = []
@export var services: Array[VillageServiceDef] = []
@export var props: Array[VillagePropDef] = []
