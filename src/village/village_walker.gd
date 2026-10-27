class_name VillageWalker
extends CharacterBody2D
## A peaceful surface body: the same movement actions and hero rig, with no run, combat or XP.

const RIG := preload("res://src/entities/rig/actor_rig.tscn")
## The surface's camera zoom at the layout's scale (PixelGrid.world_zoom() is added on top).
const SURFACE_ZOOM := Vector2(2, 2)
var def: VillageDef
var hero: PlayerDef
var blocked := false
var rig: ActorRig
var facing := Vector2.UP
var equipment := Equipment.new()
var room: VillageInteriorDef
var movement_bounds: Rect2
var camera := Camera2D.new()


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = hero.radius
	collider.shape = shape
	add_child(collider)
	rig = RIG.instantiate() as ActorRig
	add_child(rig)
	rig.setup(hero.frames, hero.frames_offset)
	rig.carries_weapon = true
	for item in hero.starting_equipment:
		equipment.equip(item)
	rig.wear(equipment)
	add_child(camera)
	set_place(null, position)
	PixelGrid.scale_changed.connect(_fit_zoom)


## A doorway moves the existing hero/rig and camera together without recreating equipment.
func set_place(next_room: VillageInteriorDef, at: Vector2) -> void:
	room = next_room
	movement_bounds = room.world_walk_bounds() if room else def.bounds
	var camera_bounds := room.world_bounds() if room else def.bounds
	position = at
	velocity = Vector2.ZERO
	camera.top_level = room != null
	_fit_zoom()
	camera.position = room.offset + room.camera_center if room else Vector2.ZERO
	camera.limit_left = int(camera_bounds.position.x)
	camera.limit_top = int(camera_bounds.position.y)
	camera.limit_right = int(camera_bounds.end.x)
	camera.limit_bottom = int(camera_bounds.end.y)
	camera.reset_smoothing()
	camera.force_update_scroll()


## The authored zoom (the surface's, a room's) grows by what PixelGrid's rounding of the canvas's
## scale took off, as the dungeon's GameCamera does: a room fills any screen the same way.
func _fit_zoom() -> void:
	camera.zoom = (Vector2.ONE * room.camera_zoom if room else SURFACE_ZOOM) * PixelGrid.world_zoom()


func _physics_process(delta: float) -> void:
	var movement := Vector2.ZERO if blocked else Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = movement * def.move_speed
	if movement != Vector2.ZERO:
		facing = movement
	move_and_slide()
	position = position.clamp(movement_bounds.position + Vector2.ONE * hero.radius, movement_bounds.end - Vector2.ONE * hero.radius)
	rig.update_state(facing, velocity.length(), false, delta)
