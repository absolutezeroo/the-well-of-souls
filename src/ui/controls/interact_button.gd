class_name InteractButton
extends ActionButton
## The contextual Interact button (input action "interact"): it shows only while the hero stands
## by something to use (Interactable: the merchant, the forge, an encounter, a pact's stele),
## with that thing's picture and what tapping does under it ("Trade", "Pray"...).

## What tapping does, translated (under the button).
var caption := "":
	set(value):
		if value != caption:
			caption = value
			queue_redraw()

var _tween: Tween


func _init() -> void:
	action = "interact"
	radius = 44.0
	visible = false


## Shows it for `target` (null: hides it). It fades in fast (0.12 s), so the eye catches it
## without its words swelling.
func show_for(target: Interactable) -> void:
	if target == null:
		if _tween:
			_tween.kill()
		hide()
		return
	icon = target.icon
	icon_tint = target.icon_tint
	color = target.color
	caption = tr(target.verb)
	label = caption.left(1)
	if visible:
		return
	show()
	if _tween:
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.12)


func _draw() -> void:
	super._draw()
	if caption.is_empty():
		return
	# The verb on a dark plaque under the button.
	var text_width := Fonts.width(caption, Fonts.BODY)
	var plaque := Rect2(Vector2(-text_width * 0.5 - 10.0, radius + 4.0), Vector2(text_width + 20.0, 28.0))
	draw_rect(plaque, Color(0.1, 0.06, 0.07, 0.85))
	draw_rect(plaque, Color(color, 0.9), false, 2.0)
	Fonts.draw(self, Vector2(0, plaque.get_center().y + Fonts.half_cap(Fonts.BODY)), caption, Fonts.BODY, Color.WHITE, 0.5, Color.BLACK)
