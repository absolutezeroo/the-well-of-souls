class_name VillageWellVfx
extends Node2D
## A fixed, deterministic flock of spirit motes. No gameplay RNG, particles, lights or per-frame
## collections. Re-records drawing at the authored rate, only when visible outside.

var def: VillageAtmosphereDef
var lamps := PackedVector2Array()
var descending := false
var gathering := 0.0
var _age := 0.0
var _frame := -1


func _ready() -> void:
	z_index = 6


func _process(delta: float) -> void:
	if not visible or def == null: return
	_age += delta
	var frame := floori(_age * def.fps)
	if frame != _frame:
		_frame = frame
		queue_redraw()


func _draw() -> void:
	if def == null: return
	var time := float(_frame) / def.fps
	var count := def.descent_count if descending else def.ambient_count
	if Settings.fewer_effects: count = mini(count, 4)
	if def.lamp_element and not Settings.fewer_effects:
		for i in lamps.size():
			var flicker := (_frame + i * 3) % 4
			PixelDraw.bit(self, VfxElementDef.Bit.TEARDROP, lamps[i] + def.lamp_offset, 2, def.lamp_element.color())
			PixelDraw.pixel(self, lamps[i] + def.lamp_offset - Vector2(0, flicker * 2), def.lamp_element.core())
	var radius := def.descent_radius if descending else def.ambient_radius
	for i in count:
		var salt := float(i) / maxi(count, 1)
		var phase := fposmod(time / def.ambient_period + salt, 1.0)
		var angle := salt * TAU + time * (2.4 if descending else 0.35)
		var reach := radius * (1.0 - phase) * (1.0 - gathering * 0.75)
		var at := Vector2(cos(angle) * reach, sin(angle) * reach * 0.35 - def.ambient_height * sin(phase * PI))
		# A tapering, broken tail leads toward the Well; dim ambient edges never dominate a body.
		var color := def.element.color() if descending else def.element.shade(0.65)
		PixelDraw.bit(self, VfxElementDef.Bit.MOTE, at, 2 if descending else 1, color)
		if descending and not Settings.fewer_effects:
			for tail in 4:
				var behind := at + Vector2(cos(angle - 0.5), sin(angle - 0.5) * 0.4) * (tail + 1) * 4.0
				PixelDraw.pixel(self, behind, def.element.shade(float(tail + 1) / 4.0))
	if descending:
		PixelDraw.ring(self, Vector2.ZERO, 22.0 + gathering * 18.0, def.element.edge(), 2, 1.0, 0.4)
		PixelDraw.ring(self, Vector2(0, -4), 20.0, def.element.color(), 1, 1.0, 0.4)
		if not Settings.fewer_effects:
			# A broken column of soul light, never a white flash or a smooth translucent gradient.
			for row in 16:
				if (row + _frame) % 4 == 0: continue
				var width := PixelDraw.snap_length(4.0 + (16 - row) * gathering)
				draw_rect(Rect2(Vector2(-width * 0.5, -row * 4.0), Vector2(width, 2)), def.element.shade(float(row) / 16.0))
