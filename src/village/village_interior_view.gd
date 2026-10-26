class_name VillageInteriorView
extends Node2D
## A room's static dressing in a separate part of the same surface world. No scene reload.

var def: VillageInteriorDef


func _ready() -> void:
	position = def.offset
	y_sort_enabled = true
	var floor_view := VillageInteriorFloor.new()
	floor_view.def = def
	floor_view.z_index = -1
	add_child(floor_view)
	for rectangle in def.walls:
		VillagePropView.add_collision(self, rectangle)
	for prop in def.props:
		var view := VillagePropView.new()
		view.def = prop
		add_child(view)
