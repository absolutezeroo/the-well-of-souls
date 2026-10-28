class_name PropDef
extends ContentDef
## An object standing in the dungeon: crates and pots to break, explosive barrels, lanterns,
## furniture of themed rooms... `icon` is its sprite (drawn at 2x, standing on the bottom of its
## footprint). Props block movement, sight and projectiles.

## Cells it stands on (a bookshelf 2x2, a long table 3x1...): all blocked.
@export var footprint: Vector2i = Vector2i.ONE
## Hits needed to break it. 0 = unbreakable.
@export_range(0, 20) var hits: int = 1
@export var loot: LootTable
## Color of the debris when it breaks.
@export var debris_color: Color = Color(0.75, 0.5, 0.3)
@export var break_sound: AudioStream

@export_group("Explosion")
## Greater than 0: blows up when broken, hurting everyone around (and breaking other props).
@export var explosion_radius: float = 0.0
@export var explosion_damage: int = 0
## Seconds of blinking between the hit and the blast: time to run.
@export var fuse_time: float = 0.5

@export_group("Light")
## Light given off (LightField): level 12 lights its tile 12, the next ones 11... 0 = none.
@export_range(0, 15) var light_level: int = 0
@export var light_color: Color = Color(1, 0.85, 0.6)
## Flames rising from it (braziers, candles): a looping scene, drawn at its own size (a smaller
## flame is a smaller scene, never a scaled one: decision 0007), and where on the sprite (from
## its foot).
@export var flame: PackedScene
@export var flame_offset: Vector2 = Vector2(0, -24)


func is_breakable() -> bool:
	return hits > 0


func is_explosive() -> bool:
	return explosion_radius > 0.0
