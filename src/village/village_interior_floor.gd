class_name VillageInteriorFloor
extends Node2D
## Static room tiles: record drawing commands once, independent of walkers and daylight.

var def: VillageInteriorDef


func _draw() -> void:
	draw_rect(def.bounds, def.backdrop)
	for patch in def.tiles:
		var step := patch.region.size * patch.art_scale
		for y in range(int(patch.area.position.y), int(patch.area.end.y), int(step.y)):
			for x in range(int(patch.area.position.x), int(patch.area.end.x), int(step.x)):
				draw_texture_rect_region(patch.texture, Rect2(Vector2(x, y), step), patch.region, patch.tint)
