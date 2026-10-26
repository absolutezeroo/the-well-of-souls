class_name VillageMemorial
extends Node2D
## One frozen, stone-coloured hero, wearing the saved gear through the normal paper doll rig.
## The court and register use this same view; there is no actor or per-frame update behind it.

const RIG := preload("res://src/entities/rig/actor_rig.tscn")
const STONE := preload("res://assets/shaders/memorial.gdshader")
var snapshot: Dictionary
var content: ContentDB
var rig: ActorRig


func _ready() -> void:
	if snapshot.is_empty():
		return
	rig = RIG.instantiate() as ActorRig
	add_child(rig)
	rig.position.y = -12
	rig.setup(content.player.frames, content.player.frames_offset)
	rig.carries_weapon = true
	var equipment := Equipment.new()
	for item in KeeperSnapshot.new(snapshot).gear(content):
		equipment.equip(item)
	rig.wear(equipment)
	rig.update_state(Vector2.DOWN, 0.0, false, 0.0)
	var stone := ShaderMaterial.new()
	stone.shader = STONE
	rig.material = stone
	# Static pose and plain materials also stop rune shimmer and rarity animations on stone.
	for node in rig.find_children("*", "CanvasItem", true, false):
		var canvas := node as CanvasItem
		canvas.material = null
		canvas.use_parent_material = true
		if node is AnimatedSprite2D:
			(node as AnimatedSprite2D).pause()
		elif node is WeaponAura:
			canvas.hide()
	rig.process_mode = Node.PROCESS_MODE_DISABLED


func _draw() -> void:
	draw_rect(Rect2(-23, -9, 46, 20), Color("252b32"))
	draw_rect(Rect2(-20, -12, 40, 15), Color("77817f"))
	draw_rect(Rect2(-25, 7, 50, 6), Color("47514e"))
