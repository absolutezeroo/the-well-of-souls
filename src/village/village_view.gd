class_name VillageView
extends Node2D
## Static surface dressing. Rebuilt only when profile progress changes, never each frame.

var def: VillageDef
var content: ContentDB
var dressing := Node2D.new()
var walker: VillageWalker
var residents: Array[VillageResident] = []
var _resident_by_def: Dictionary[VillageResidentDef, VillageResident] = {}
var navigation := VillageNavigation.new()
var daylight := CanvasModulate.new()
var well_vfx := VillageWellVfx.new()
var active_room: VillageInteriorDef
var _keep_clear: Array[Rect2] = []


func _ready() -> void:
	add_child(dressing)
	add_child(daylight)
	dressing.y_sort_enabled = true
	well_vfx.def = def.atmosphere
	well_vfx.position = def.well + Vector2(0, -12)
	add_child(well_vfx)
	Profile.changed.connect(refresh)
	refresh()


func refresh() -> void:
	well_vfx.lamps.clear()
	for prop in def.props:
		if prop.lit_by and VillageProgress.restored(prop.lit_by):
			well_vfx.lamps.append(prop.position - well_vfx.position)
	navigation.rebuild(def)
	_keep_clear = _clear_spots()
	for child in dressing.get_children():
		if child != walker and not child is VillageResident:
			dressing.remove_child(child)
			child.queue_free()
	for prop in def.props:
		if prop.cleared_by and VillageProgress.stage(prop.cleared_by) == VillageProgress.Step.RETURNED:
			continue
		var body := VillagePropView.new()
		body.def = prop
		dressing.add_child(body)
	for interior in def.interiors:
		var room_view := VillageInteriorView.new()
		room_view.def = interior
		dressing.add_child(room_view)
	for resident in def.residents:
		if _resident_by_def.has(resident):
			_resident_by_def[resident].refresh_progress()
			_resident_by_def[resident].apply_hour(VillageClock.hour(def.clock), false, true)
			continue
		var actor := VillageResident.new()
		actor.def = resident
		actor.position = resident.position
		actor.hero = walker
		actor.navigation = navigation
		dressing.add_child(actor)
		actor.apply_hour(VillageClock.hour(def.clock), true)
		residents.append(actor)
		_resident_by_def[resident] = actor
	var memorial := VillageMemorial.new()
	memorial.content = content
	memorial.snapshot = Profile.village_memorials[0] if not Profile.village_memorials.is_empty() else {}
	memorial.position = def.memorial
	dressing.add_child(memorial)
	var well_body := Node2D.new()
	well_body.position = def.well
	dressing.add_child(well_body)
	VillagePropView.add_collision(well_body, Rect2(-34, -22, 68, 44))
	var well_sprite := Sprite2D.new()
	well_sprite.texture = def.well_icon
	well_sprite.scale = Vector2(3, 3)
	well_sprite.position.y = -12
	well_sprite.modulate = Color(0.55, 0.65, 0.72)
	well_body.add_child(well_sprite)
	var board := VillageNoticeboard.new()
	board.position = def.noticeboard
	dressing.add_child(board)
	VillagePropView.add_collision(board, Rect2(-24, -12, 48, 12))
	queue_redraw()


func apply_hour(hour: float) -> void:
	well_vfx.visible = active_room == null
	daylight.color = active_room.light if active_room else def.clock.daylight.sample(hour / 24.0)
	for resident in residents:
		resident.apply_hour(hour)


func actor_for(resident: VillageResidentDef) -> VillageResident:
	return _resident_by_def.get(resident)


func _draw() -> void:
	VillageGround.draw(self, def, _keep_clear)
	for quest in def.quests:
		if VillageProgress.stage(quest) == VillageProgress.Step.RETURNED:
			# The restored house is identified by its resident, not by a quest id in code.
			for resident in def.residents:
				if resident.wakes_after == quest:
					draw_rect(Rect2(resident.position + Vector2(-10, -100), Vector2(20, 24)), Color("eeb65b"))


## Flowers stay off the props, the Well, the board and the memorial so nothing grows through them.
func _clear_spots() -> Array[Rect2]:
	var spots: Array[Rect2] = []
	for prop in def.props:
		var size := (prop.region.size if prop.region.has_area() else Vector2(16, 16)) * prop.art_scale
		spots.append(Rect2(prop.position - Vector2(size.x * 0.5, size.y), size).grow(4))
	for spot in [def.well, def.noticeboard, def.memorial, def.spawn]:
		spots.append(Rect2(spot - Vector2(40, 48), Vector2(80, 64)))
	return spots
