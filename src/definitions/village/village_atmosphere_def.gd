class_name VillageAtmosphereDef
extends Resource
## Bounded ambient souls and the Well's one-shot descent, authored independently of progression.

@export var element: VfxElementDef
@export var lamp_element: VfxElementDef
@export var lamp_offset := Vector2(0, -28)
@export_range(1, 20) var fps: int = 12
@export_range(0, 24) var ambient_count: int = 9
@export var ambient_radius: float = 60.0
@export var ambient_height: float = 48.0
@export var ambient_period: float = 4.0
@export_range(1, 40) var descent_count: int = 24
@export var descent_radius: float = 92.0
@export var approach_seconds: float = 0.45
@export var gathering_seconds: float = 0.8
@export var fall_seconds: float = 0.4
@export var close_seconds: float = 0.55
@export var darkness: Color = Color("120c1e")


func duration() -> float:
	return approach_seconds + gathering_seconds + fall_seconds + close_seconds
