class_name VillagePropView
extends Node2D
## The same authored prop/collision renderer is used outside and inside village buildings.
## An animated prop steps its pre-drawn frames (region by region): one property set per frame
## step, skipped off screen, no redraw of anything else (docs/performance.md "Redraw on change").

var def: VillagePropDef
var _sprite: Sprite2D
var _age := 0.0
var _frame := 0


func _ready() -> void:
	position = def.position
	var sprite := Sprite2D.new()
	sprite.texture = def.unlit if def.lit_by and def.unlit and not VillageProgress.restored(def.lit_by) else def.texture
	sprite.region_enabled = def.region.has_area()
	sprite.region_rect = def.region
	sprite.scale = Vector2.ONE * def.art_scale
	var picture_size := def.region.size if def.region.has_area() else def.texture.get_size()
	sprite.offset.y = -picture_size.y * 0.5
	sprite.modulate = def.tint
	add_child(sprite)
	_sprite = sprite
	if def.collision.has_area(): add_collision(self, def.collision)
	var animated := def.frames > 1 and def.region.has_area() and def.frame_time > 0.0
	set_process(animated)
	if animated:
		# Neighbouring flags do not wave in step: a stable phase from the position, no dice.
		_age = fposmod(def.position.x * 0.37 + def.position.y * 0.11, def.frames) * def.frame_time


func _process(delta: float) -> void:
	_age = fposmod(_age + delta, def.frame_time * def.frames)
	var index := mini(int(_age / def.frame_time), def.frames - 1)
	if index == _frame or not Vfx.on_screen(self, def.region.size.y * def.art_scale):
		return
	_frame = index
	_sprite.region_rect = Rect2(def.region.position + Vector2(def.region.size.x * index, 0.0), def.region.size)


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
