class_name VillageWalker
extends CharacterBody2D
## A peaceful surface body: the same movement actions and hero rig, with no run, combat or XP.

const RIG := preload("res://src/entities/rig/actor_rig.tscn")
var def: VillageDef
var hero: PlayerDef
var blocked := false
var rig: ActorRig
var facing := Vector2.UP
var equipment := Equipment.new()


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
	var camera := Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.limit_left = int(def.bounds.position.x)
	camera.limit_top = int(def.bounds.position.y)
	camera.limit_right = int(def.bounds.end.x)
	camera.limit_bottom = int(def.bounds.end.y)
	add_child(camera)


func _physics_process(delta: float) -> void:
	var movement := Vector2.ZERO if blocked else Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = movement * def.move_speed
	if movement != Vector2.ZERO:
		facing = movement
	move_and_slide()
	position = position.clamp(def.bounds.position + Vector2.ONE * hero.radius, def.bounds.end - Vector2.ONE * hero.radius)
	rig.update_state(facing, velocity.length(), false, delta)
