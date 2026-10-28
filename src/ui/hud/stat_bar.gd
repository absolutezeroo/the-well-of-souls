class_name StatBar
extends Control
## Pixel-art bar with a centered text (HP, XP...). When it drops, the lost part stays a moment
## in a pale "trail" that then drains away (you see what that hit cost); when it rises, the bar
## glows briefly.

const TRAIL_DELAY := 0.4
const TRAIL_COLOR := Color(1.0, 0.93, 0.75)
const GLOW_TIME := 0.35

## Changing it redraws at once (the temperature's blink changes it with no new value).
@export var fill_color := Palette.BLOOD:
	set(color):
		if color == fill_color:
			return
		fill_color = color
		queue_redraw()
@export var show_text := true
@export var font_size := Fonts.BODY

var _value := 1.0
var _max_value := 1.0
var _text := ""
var _trail := 1.0
var _trail_delay := 0.0
var _glow := 0.0
var _shown := false  # the first values just show, no trail


func _ready() -> void:
	set_process(false)


func set_values(value: float, max_value: float, text: String = "") -> void:
	if value == _value and maxf(max_value, 0.001) == _max_value and text == _text:
		return
	if not _shown:
		_shown = true
		_trail = value
	elif value < _value and max_value == _max_value:
		_trail = maxf(_trail, _value)  # a trail already draining keeps its start
		_trail_delay = TRAIL_DELAY
		set_process(true)
	elif value > _value:
		_trail = value
		_glow = GLOW_TIME if max_value == _max_value else 0.0
		set_process(_glow > 0.0)
	else:
		_trail = value
	_value = value
	_max_value = maxf(max_value, 0.001)
	_text = text
	queue_redraw()


func _process(delta: float) -> void:
	_glow = maxf(_glow - delta, 0.0)
	if _trail_delay > 0.0:
		_trail_delay -= delta
	elif _trail > _value:
		_trail = move_toward(_trail, _value, _max_value * 0.8 * delta)
	if _trail <= _value and _glow <= 0.0 and _trail_delay <= 0.0:
		_trail = _value
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(UiSkin.bar_frame(), rect)
	var inner := rect.grow(-4.0)
	var ratio := clampf(_value / _max_value, 0.0, 1.0)
	var trail_ratio := clampf(_trail / _max_value, 0.0, 1.0)
	if trail_ratio > ratio:
		draw_rect(Rect2(inner.position + Vector2(inner.size.x * ratio, 0), Vector2(inner.size.x * (trail_ratio - ratio), inner.size.y)), TRAIL_COLOR)
	if ratio > 0.0:
		var fill := Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y))
		draw_rect(fill, fill_color)
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, 2.0)), fill_color.lightened(0.35))
		draw_rect(Rect2(fill.position + Vector2(0, fill.size.y - 2.0), Vector2(fill.size.x, 2.0)), fill_color.darkened(0.3))
		if _glow > 0.0:
			draw_rect(fill, Color(1, 1, 1, 0.45 * _glow / GLOW_TIME))
	if show_text and not _text.is_empty():
		# Centred: the baseline under the middle by half a capital.
		var baseline := size.y * 0.5 + Fonts.half_cap(font_size)
		Fonts.draw(self, Vector2(size.x * 0.5, baseline), _text, font_size, Color.WHITE, 0.5, Palette.INK)
