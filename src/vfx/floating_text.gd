class_name FloatingText
extends Node2D
## Rising, fading text: damage numbers, heals, level ups. On the grid (docs/vfx.md): it starts
## on a whole art pixel, rises by whole art pixels, and fades in FADE_STEPS cuts (never a smooth
## alpha gradient: the pixel font's letters have no in-between).

const LIFETIME := 0.75
const RISE := 28.0
## The share of its life it shows at twice its size, before settling.
const POP_TIME := 0.08
## The fade's cuts (the letters at 2/3, then 1/3, then gone), over the second half of its life.
const FADE_STEPS := 3
## How far a number may land beside the hit, so numbers in a row don't stack (art pixels).
const JITTER_PX := 3

var _text := ""
var _color := Color.WHITE
var _age := 0.0
## Where it goes when its life is over (WorldSpawner's pool, docs/performance.md "Pools"); null:
## freed.
var pool: NodePool
## What the last _draw() showed (_draw_key()): drawn again only when it changes.
var _drawn := -1
## Seconds left of a second pop (a number that just took another hit: HitFeedback).
var _repop := 0.0


static func create(at: Vector2, text: String, color: Color) -> FloatingText:
	var vfx := FloatingText.new()
	vfx.restart(at, text, color)
	vfx.z_index = 10
	return vfx


## Shown again from the start, at `at` (a new one, or one from the pool).
func restart(at: Vector2, text: String, color: Color) -> void:
	position = PixelDraw.snap(at) + Vector2(randi_range(-JITTER_PX, JITTER_PX) * PixelDraw.PX, 0.0)
	_text = text
	_color = color
	_age = 0.0
	_repop = 0.0
	_drawn = -1
	set_process(true)
	queue_redraw()


## Its text changed while it shows (drawn again at once).
func set_text(text: String) -> void:
	_text = text
	queue_redraw()


## What it shows.
func shown_text() -> String:
	return _text


## Shows `new_text` instead from now on, popping again (a damage number taking another hit).
func retext(new_text: String) -> void:
	_repop = LIFETIME * POP_TIME
	set_text(new_text)


func _process(delta: float) -> void:
	_age += delta
	_repop = maxf(_repop - delta, 0.0)
	if _age >= LIFETIME:
		set_process(false)
		if pool:
			pool.give(self)
		else:
			queue_free()
		return
	var key := _draw_key()
	if key != _drawn:
		_drawn = key
		queue_redraw()


## What _draw() shows as one number: the rise in whole art pixels, the fade's cut, the pop.
func _draw_key() -> int:
	var t := _age / LIFETIME
	var rise := roundi(RISE * ease(t, 0.5) / PixelDraw.PX)
	var cut := ceili((1.0 - maxf(t - 0.5, 0.0) * 2.0) * FADE_STEPS)
	return rise * 64 + cut * 2 + (1 if t < POP_TIME or _repop > 0.0 else 0)


func _draw() -> void:
	var t := _age / LIFETIME
	var color := _color
	color.a = ceilf((1.0 - maxf(t - 0.5, 0.0) * 2.0) * FADE_STEPS) / FADE_STEPS
	# Pops in at twice the size, then settles: whole sizes, so its pixels stay whole (Fonts).
	var font_size := Fonts.TITLE if t < POP_TIME or _repop > 0.0 else Fonts.BODY
	var rise := roundf(RISE * ease(t, 0.5) / PixelDraw.PX) * PixelDraw.PX
	Fonts.draw(self, Vector2(0, -rise), _text, font_size, color, 0.5, Color(Palette.INK, color.a))
