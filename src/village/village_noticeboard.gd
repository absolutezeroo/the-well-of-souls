class_name VillageNoticeboard
extends Node2D
## A static wooden noticeboard. The interaction and journal belong to the hub, not this prop.

func _draw() -> void:
	draw_rect(Rect2(-21, -32, 6, 34), Color("513d32"))
	draw_rect(Rect2(15, -32, 6, 34), Color("513d32"))
	draw_rect(Rect2(-29, -58, 58, 42), Color("302c30"))
	draw_rect(Rect2(-26, -55, 52, 36), Color("967047"))
	draw_rect(Rect2(-29, -61, 58, 6), Color("c59659"))
	draw_rect(Rect2(-21, -49, 17, 23), Color("efe2bd"))
	draw_rect(Rect2(3, -47, 18, 25), Color("ddd0a8"))
	draw_rect(Rect2(-18, -43, 11, 2), Color("81654d"))
	draw_rect(Rect2(-18, -38, 8, 2), Color("81654d"))
	draw_rect(Rect2(7, -40, 10, 2), Color("81654d"))
	draw_rect(Rect2(7, -34, 8, 2), Color("81654d"))
