class_name CaptiveSoul
extends Node2D
## One of Kagari's souls held in the Well (CaptiveSoulsTrial): a villager's figure, pale and
## see-through, bobbing a pixel, held to the floor by three chains of tar; while the hero stands
## by it a ring fills round its feet (`progress`). Freed, it rises out of its chains and fades.
## Drawn by hand on the art's grid (whole art pixels, dithered fades: docs/vfx.md); redrawn at
## 12 fps on screen only.

const FPS := 12.0
## The ring's radius at its feet (px), and the chains' anchors around it.
const RING := 16.0
const ANCHORS: Array[Vector2] = [Vector2(-16, 8), Vector2(15, 6), Vector2(-2, 12)]
const TAR := Color(0.09, 0.07, 0.1)
const TAR_SHINE := Color(0.32, 0.27, 0.36)

var look: Texture2D
var element: VfxElementDef
## Its place in its trial's list (the save keeps freed ones by it).
var index := 0
## 0..1: how far it is freed.
var progress := 0.0
## The hero stands by it now (its ring shows).
var held := false
## The Well sent foes for it already.
var called := false
var freed := false

var _time := 0.0
var _drawn_key := -1
## 0..1 while it rises once freed.
var _rise := -1.0
var _light: LightSource


func setup(soul_look: Texture2D, soul_element: VfxElementDef, at_index: int) -> void:
	look = soul_look
	element = soul_element
	index = at_index
	name = "CaptiveSoul_%d" % at_index
	y_sort_enabled = true
	_light = LightSource.new()
	_light.color = element.core() if element else Color(0.8, 0.9, 1.0)
	_light.level = 8
	_light.relative = true
	_light.position = Vector2(0, -12)
	add_child(_light)
	# Its pale glow behind it: the soul shines a little in the dark (GlowHalo, in its element).
	GlowHalo.attach(self, element, 9.0, Vector2(0, -16))


## Freed: it rises and fades (`quiet`: a resumed floor's, gone at once).
func set_free(quiet: bool) -> void:
	if freed:
		return
	freed = true
	held = false
	progress = 1.0
	if quiet:
		_rise = 1.0
		visible = false
		_light.queue_free()
		return
	_rise = 0.0
	var tween := create_tween()
	tween.tween_property(self, "_rise", 1.0, 1.4)
	tween.tween_callback(func() -> void: visible = false)
	_light.level = 12


func _process(delta: float) -> void:
	_time += delta
	if not visible or not Vfx.on_screen(self, 48.0):
		return
	var key := floori(_time * FPS) * 64 + roundi(progress * 24.0) + (1000000 if held else 0)
	if key != _drawn_key:
		_drawn_key = key
		queue_redraw()


func _draw() -> void:
	var px := PixelDraw.PX
	var bob := px if fmod(_time, 1.6) < 0.8 else 0.0
	var rise := maxf(_rise, 0.0)
	var body := Vector2(0, -16 - bob - rise * 40.0)
	var pale := element.shade(0.0) if element else Color(0.85, 0.95, 1.0)
	var mid := element.shade(0.5) if element else Color(0.6, 0.7, 0.85)
	# The chains of tar, from its middle to the floor (broken once freed).
	if not freed:
		for anchor in ANCHORS:
			PixelDraw.line(self, body + Vector2(0, 10), anchor, TAR, 1)
			PixelDraw.pixel(self, anchor, TAR_SHINE)
		PixelDraw.disc(self, Vector2(0, 4), 10.0, Color(TAR, 0.7), 0.7, 0.4)
	# The ring filling round its feet while the hero frees it.
	if held or (progress > 0.0 and not freed):
		PixelDraw.ring(self, Vector2(0, 4), RING, Color(mid, 1.0), 1, 0.45, 0.45)
		if progress > 0.0:
			PixelDraw.arc(self, Vector2(0, 4), RING, -PI / 2.0, -PI / 2.0 + TAU * progress, Color(pale, 1.0), 2, 0.45)
	# The soul: the villager's figure at the art's 2x, washed pale, see-through (dithered away
	# as it rises).
	if look:
		var fade := 1.0 - rise
		var size := look.get_size() * 2.0
		var rect := Rect2(PixelDraw.snap(body - size * 0.5), size)
		draw_texture_rect(look, rect, false, Color(pale.r * 1.25, pale.g * 1.25, pale.b * 1.3, 0.72 * fade))
	# A few motes of it drifting up.
	for i in 3:
		var t := fmod(_time * 0.6 + i * 0.33, 1.0)
		var at := body + Vector2((i - 1) * 6.0 + sin(_time * 2.0 + i) * 2.0, -8.0 - t * 18.0)
		if PixelDraw.dither(PixelDraw.cell_of(at), 1.0 - t):
			PixelDraw.pixel(self, at, pale)
