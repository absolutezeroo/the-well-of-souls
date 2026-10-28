@tool
class_name VillageLayoutHandle
extends Marker2D
## A draggable authoring handle; the layout editor explicitly copies its position to data.

var source: Resource
var field: StringName
var index := -1
var origin := Vector2.ZERO
var collision := Rect2()
## Not a collision: the box an animal wanders in, around its home (blue).
var area := Rect2()


func value() -> Vector2:
	return position - origin


func apply() -> void:
	if index < 0:
		source.set(field, value())
	else:
		var rectangles: Array[Rect2] = source.get(field)
		rectangles[index].position = value()
		source.set(field, rectangles)
	source.emit_changed()


func _draw() -> void:
	if area.has_area():
		draw_rect(area, Color(0.3, 0.6, 0.9), false, 1.0)
	if collision.has_area():
		draw_rect(collision, Color(0.9, 0.3, 0.2, 0.25))
		draw_rect(collision, Color(0.9, 0.5, 0.2), false, 1.0)
