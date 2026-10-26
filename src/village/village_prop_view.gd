class_name VillagePropView
extends Node2D
## The same authored prop/collision renderer is used outside and inside village buildings.

var def: VillagePropDef


func _ready() -> void:
	position = def.position
	var sprite := Sprite2D.new()
	sprite.texture = def.texture
	sprite.region_enabled = def.region.has_area()
	sprite.region_rect = def.region
	sprite.scale = Vector2.ONE * def.art_scale
	var picture_size := def.region.size if def.region.has_area() else def.texture.get_size()
	sprite.offset.y = -picture_size.y * 0.5
	sprite.modulate = def.tint
	if def.lit_by:
		sprite.modulate = Color(1.3, 1.15, 0.75) if VillageProgress.restored(def.lit_by) else Color(0.3, 0.35, 0.4)
	add_child(sprite)
	if def.collision.has_area(): add_collision(self, def.collision)


static func add_collision(parent: Node2D, rectangle: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rectangle.size
	collider.shape = shape
	collider.position = rectangle.get_center()
	body.add_child(collider)
	parent.add_child(body)
