class_name OffersButton
extends Button
## The HUD's perk button: shown while perk choices wait (a level up, a choice put off), with a
## slow golden glow and how many wait on a badge. A level up no longer opens anything by itself:
## the player taps this when the fight allows (Game.open_offers()).

const SIZE := 76.0
const GOLD := Palette.GOLD

## Choices waiting (0: hidden).
var count := 0:
	set(value):
		var more := value > count
		count = value
		visible = count > 0
		if more and is_inside_tree():
			_pop()
		queue_redraw()

var _time := 0.0
var _tween: Tween


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	pivot_offset = Vector2(SIZE, SIZE) * 0.5
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	visible = false


func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()


## A new choice: the button swells and settles.
func _pop() -> void:
	if _tween:
		_tween.kill()
	scale = Vector2.ONE * 1.35
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var center := size * 0.5
	var radius := size.x * 0.5 - 6.0
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	# The glow: soft rings of gold breathing around it.
	for i in 3:
		draw_circle(center, radius + 4.0 + i * 5.0 + pulse * 4.0, Color(GOLD, (0.16 - i * 0.045) * (0.55 + 0.45 * pulse)))
	var base := Vector2(radius, radius) * 2.0
	draw_texture_rect(ActionButton.BASE_PRESSED if is_pressed() else ActionButton.BASE, Rect2(center - base * 0.5, base), false, Color(1.0, 0.86, 0.55, 0.95))
	draw_arc(center, radius, 0.0, TAU, 40, Color(GOLD, 0.6 + 0.4 * pulse), 2.5, true)
	_draw_star(center + (Vector2(0, 2) if is_pressed() else Vector2.ZERO), radius * 0.62, pulse)
	# How many wait.
	var badge := center + Vector2(radius * 0.72, -radius * 0.72)
	draw_circle(badge, 14.0, Color("7a1f2b"))
	draw_circle(badge, 14.0, GOLD, false, 2.0, true)
	var words := str(count)
	Fonts.draw(self, badge + Vector2(0, Fonts.half_cap(Fonts.BODY)), words, Fonts.BODY, Color.WHITE, 0.5, Color.TRANSPARENT)
	# What it is, under it.
	var caption := tr("Perks")
	Fonts.draw(self, Vector2(center.x, size.y + Fonts.cap_height(Fonts.BODY)), caption, Fonts.BODY, GOLD, 0.5, Color.BLACK)


## A four-pointed star rising out of the wood: a perk waits.
func _draw_star(at: Vector2, reach: float, pulse: float) -> void:
	var points := PackedVector2Array()
	for i in 8:
		var angle := -PI * 0.5 + TAU * i / 8.0
		var length := reach if i % 2 == 0 else reach * 0.32
		points.append(at + Vector2.from_angle(angle) * length)
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(2, 3))
	draw_colored_polygon(shadow, Color(0.1, 0.05, 0.03, 0.7))
	draw_colored_polygon(points, GOLD.lightened(0.15 * pulse))
	var inner := PackedVector2Array()
	for point in points:
		inner.append(at + (point - at) * 0.45)
	draw_colored_polygon(inner, Color(1.0, 0.97, 0.85))
