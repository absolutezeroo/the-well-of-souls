class_name TextCue
extends Control
## A number that changed (souls gathered, the seal broken, a second of the Threshold's last ten,
## gold in the bag) says so with pixel corner brackets flashing round its words and fading, while
## the words themselves stay still: nothing to read swells, shakes or blinks
## (design/interface.md "One skin"). Added under the label by ping(), drawn on the UI's 2-unit grid.

## The UI's pixel (bracket strokes, their offset from the words).
const PX := 2.0
## Each bracket's arm (UI units).
const ARM := 8.0

var color := Color.WHITE
var _tween: Tween


func _init() -> void:
	name = "TextCue"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0


## Flashes brackets in `color` round `label`'s words, fading over `time` seconds (a new flash
## replaces the last one).
static func ping(label: Label, flash_color: Color, time := 0.35) -> void:
	var cue := label.get_node_or_null(^"TextCue") as TextCue
	if cue == null:
		cue = TextCue.new()
		label.add_child(cue)
	cue.flash(flash_color, time)


func flash(flash_color: Color, time: float) -> void:
	color = flash_color
	if _tween:
		_tween.kill()
	modulate.a = 1.0
	queue_redraw()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, maxf(time, 0.05))


## The words' box in the label (its text's width at its font size, where its alignment puts it).
func _words_rect() -> Rect2:
	var label := get_parent() as Label
	if label == null:
		return Rect2()
	var font_size := label.get_theme_font_size(&"font_size")
	var width := minf(Fonts.width(label.text, font_size), label.size.x)
	var x := 0.0
	if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x = label.size.x - width
	elif label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x = (label.size.x - width) * 0.5
	return Rect2(Vector2(x, 0.0), Vector2(width, label.size.y))


func _draw() -> void:
	var box := _words_rect()
	if not box.has_area():
		return
	box = box.grow(PX * 2.0)
	box.position = (box.position / PX).floor() * PX
	box.size = (box.size / PX).ceil() * PX
	var corners := [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]
	for i in 4:
		var corner: Vector2 = corners[i]
		var sx := 1.0 if i == 0 or i == 3 else -1.0
		var sy := 1.0 if i < 2 else -1.0
		var h := Rect2(corner, Vector2(ARM * sx, PX * sy)).abs()
		var v := Rect2(corner, Vector2(PX * sx, ARM * sy)).abs()
		for part: Rect2 in [h, v]:
			draw_rect(part.grow(PX), Fonts.OUTLINE)
		for part: Rect2 in [h, v]:
			draw_rect(part, color)
