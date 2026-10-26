class_name VillageView
extends Node2D
## Static surface dressing. Rebuilt only when profile progress changes, never each frame.

var def: VillageDef
var content: ContentDB
var dressing := Node2D.new()
var walker: VillageWalker


func _ready() -> void:
	add_child(dressing)
	dressing.y_sort_enabled = true
	Profile.changed.connect(refresh)
	refresh()


func refresh() -> void:
	for child in dressing.get_children():
		if child != walker:
			dressing.remove_child(child)
			child.queue_free()
	for prop in def.props:
		if prop.cleared_by and VillageProgress.stage(prop.cleared_by) == VillageProgress.Step.RETURNED:
			continue
		var body := Node2D.new()
		body.position = prop.position
		dressing.add_child(body)
		var sprite := Sprite2D.new()
		sprite.texture = prop.texture
		sprite.region_enabled = prop.region.has_area()
		sprite.region_rect = prop.region
		sprite.scale = Vector2.ONE * prop.art_scale
		var picture_size := prop.region.size if prop.region.has_area() else prop.texture.get_size()
		sprite.offset.y = -picture_size.y * 0.5
		sprite.modulate = prop.tint
		if prop.lit_by:
			sprite.modulate = Color(1.3, 1.15, 0.75) if VillageProgress.restored(prop.lit_by) else Color(0.3, 0.35, 0.4)
		body.add_child(sprite)
		if prop.collision.has_area():
			_add_collision(body, prop.collision)
	for resident in def.residents:
		var sprite := Sprite2D.new()
		sprite.texture = resident.speaker.figure
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 0, 16, 16)
		sprite.scale = Vector2(2, 2)
		sprite.offset = Vector2(0, -8)
		sprite.position = resident.position
		var asleep := resident.echo and (resident.wakes_after == null or VillageProgress.stage(resident.wakes_after) != VillageProgress.Step.RETURNED)
		sprite.modulate = Color(0.5, 0.8, 1.0, 0.5) if asleep else Color.WHITE
		dressing.add_child(sprite)
	var memorial := VillageMemorial.new()
	memorial.content = content
	memorial.snapshot = Profile.village_memorials[0] if not Profile.village_memorials.is_empty() else {}
	memorial.position = def.memorial
	dressing.add_child(memorial)
	var well_body := Node2D.new()
	well_body.position = def.well
	dressing.add_child(well_body)
	_add_collision(well_body, Rect2(-34, -22, 68, 44))
	var well_sprite := Sprite2D.new()
	well_sprite.texture = def.well_icon
	well_sprite.scale = Vector2(3, 3)
	well_sprite.position.y = -12
	well_sprite.modulate = Color(0.55, 0.65, 0.72)
	well_body.add_child(well_sprite)
	var altar := Sprite2D.new()
	altar.texture = def.shrine_icon
	altar.scale = Vector2(2, 2)
	altar.position = def.shrine
	dressing.add_child(altar)
	queue_redraw()


func _add_collision(parent: Node2D, rectangle: Rect2) -> void:
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


func _draw() -> void:
	draw_rect(def.bounds, Color("19272b"))
	for y in range(int(def.bounds.position.y), int(def.bounds.end.y), 32):
		for x in range(int(def.bounds.position.x), int(def.bounds.end.x), 32):
			draw_texture_rect_region(def.ground, Rect2(x, y, 32, 32), def.ground_region, Color(0.5, 0.58, 0.57))
	# The worn stone paths meet at the Well. Static drawing stays separate from the walkers.
	for path in def.paths:
		for y in range(int(path.position.y), int(path.end.y), 32):
			for x in range(int(path.position.x), int(path.end.x), 32):
				draw_texture_rect_region(def.path_texture, Rect2(x, y, 32, 32), def.path_region, Color(0.85, 0.9, 0.95))
	for quest in def.quests:
		if VillageProgress.stage(quest) == VillageProgress.Step.RETURNED:
			# The restored house is identified by its resident, not by a quest id in code.
			for resident in def.residents:
				if resident.wakes_after == quest:
					draw_rect(Rect2(resident.position + Vector2(-10, -100), Vector2(20, 24)), Color("eeb65b"))
