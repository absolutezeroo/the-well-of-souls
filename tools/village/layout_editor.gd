@tool
extends Node2D
## A save-free static preview of VillageDef with draggable handles. Runtime Profile, physics
## and autoloads never run here. Only Apply writes resources; Reload discards unapplied moves.

@export var village: VillageDef
@export_tool_button("Reload from village data", "Reload") var reload_action: Callable = rebuild
@export_tool_button("Apply positions to village data", "Save") var apply_action: Callable = save_layout
var handles: Array[VillageLayoutHandle] = []
var _preview: Node2D
var _pending_files: Dictionary[String, Resource] = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		rebuild.call_deferred()
	else:
		push_warning("Open this scene in the 2D editor. Play village_hub.tscn to test the village.")


func rebuild() -> void:
	if village == null: return
	handles.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_preview = Node2D.new()
	_preview.name = "Layout"
	add_child(_preview)
	_preview.owner = self
	for field: StringName in [&"spawn", &"well", &"noticeboard", &"memorial"]:
		var point := _point(village, field, String(field).capitalize())
		if field == &"well": _sprite(point, village.well_icon, Rect2(), 3.0, Vector2(0, -12), Color(0.55, 0.65, 0.72))
	for i in village.paths.size():
		var path := _point(village, &"paths", "Path_%02d" % i, Vector2.ZERO, i)
		path.collision = Rect2(Vector2.ZERO, village.paths[i].size)
	for i in village.props.size():
		_prop(village.props[i], "Prop_%02d" % i)
	for resident in village.residents:
		var point := _point(resident, &"position", "Home_" + String(resident.id))
		_sprite(point, resident.speaker.figure, Rect2(0, 0, 16, 16), 2.0, Vector2(0, -16))
		for i in resident.schedule.size():
			var activity := resident.schedule[i]
			_point(activity, &"destination", "%s_%02dh_%d" % [resident.id, activity.start_hour, i], activity.room.offset if activity.room else Vector2.ZERO)
	for room in village.interiors:
		for field: StringName in [&"door", &"return_position"]:
			_point(room, field, String(room.id) + "_" + String(field))
		for field: StringName in [&"spawn", &"exit", &"shrine", &"camera_center"]:
			_point(room, field, String(room.id) + "_" + String(field), room.offset)
		for i in room.props.size():
			_prop(room.props[i], "%s_Prop_%02d" % [room.id, i], room.offset)
	queue_redraw()


func _point(source: Resource, field: StringName, label: String, origin: Vector2 = Vector2.ZERO, index: int = -1) -> VillageLayoutHandle:
	var handle := VillageLayoutHandle.new()
	handle.name = label
	handle.source = source
	handle.field = field
	handle.index = index
	handle.origin = origin
	handle.position = origin + (source.get(field) if index < 0 else (source.get(field) as Array)[index].position)
	_preview.add_child(handle)
	handle.owner = self
	handles.append(handle)
	return handle


func _prop(prop: VillagePropDef, label: String, origin: Vector2 = Vector2.ZERO) -> void:
	var point := _point(prop, &"position", label, origin)
	point.collision = prop.collision
	var picture := prop.region.size if prop.region.has_area() else prop.texture.get_size()
	_sprite(point, prop.texture, prop.region, prop.art_scale, Vector2(0, -picture.y * prop.art_scale * 0.5), prop.tint)


func _sprite(parent: Node2D, texture: Texture2D, region: Rect2, art_scale: float, at: Vector2, tint: Color = Color.WHITE) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = region.has_area()
	sprite.region_rect = region
	sprite.position = at
	sprite.scale = Vector2.ONE * art_scale
	sprite.modulate = tint
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sprite)


## Applies only moved handles, then saves each owning .tres once (including external schedules).
## A no-op never rewrites data. A failure is reported and the handles stay available to retry.
func save_layout() -> void:
	var moved: Array[VillageLayoutHandle] = []
	for handle in handles:
		var previous: Vector2 = handle.source.get(handle.field) if handle.index < 0 else (handle.source.get(handle.field) as Array)[handle.index].position
		if previous == handle.value(): continue
		var path := handle.source.resource_path.get_slice("::", 0)
		if path.is_empty() or not path.begins_with("res://data/village/"):
			push_error("Village layout: save this resource under data/village before moving it: " + path)
			return
		_pending_files[path] = load(path)
		moved.append(handle)
	for handle in moved:
		handle.apply()
	for path in _pending_files:
		var error := VillageLayoutWriter.save(_pending_files[path], path)
		if error != OK:
			push_error("Village layout: could not save %s (%s). Keep the editor open and retry." % [path, error_string(error)])
			return
	print("Village layout: saved %d resource files. Run village_hub.tscn to test paths and doors." % _pending_files.size())
	_pending_files.clear()
	queue_redraw()


func _draw() -> void:
	if village == null: return
	VillageGround.draw(self, village)
	for room in village.interiors:
		draw_rect(Rect2(room.offset + room.bounds.position, room.bounds.size), room.backdrop)
		for patch in room.tiles:
			_tiles(patch.texture, patch.region, Rect2(room.offset + patch.area.position, patch.area.size), patch.region.size * patch.art_scale, patch.tint)
		for wall in room.walls:
			draw_rect(Rect2(room.offset + wall.position, wall.size), Color(0.8, 0.2, 0.2, 0.25))


func _tiles(texture: Texture2D, region: Rect2, area: Rect2, step: Vector2, tint: Color) -> void:
	if texture == null or step.x <= 0 or step.y <= 0: return
	for y in range(int(area.position.y), int(area.end.y), int(step.y)):
		for x in range(int(area.position.x), int(area.end.x), int(step.x)):
			draw_texture_rect_region(texture, Rect2(Vector2(x, y), step), region, tint)
