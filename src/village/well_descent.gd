class_name WellDescent
extends Node
## Owns a short, cancellable cinematic. Completion is emitted exactly once; only its owner
## launches the run. Freeing the village cancels everything without touching RunSave or flags.

signal finished
var walker: VillageWalker
var effect: VillageWellVfx
var def: VillageAtmosphereDef
var well: Vector2
var elapsed := 0.0
var completed := false
var _start: Vector2
var _cover := Control.new()
var _layer := CanvasLayer.new()
var _frame := -1


func _ready() -> void:
	_start = walker.position
	walker.blocked = true
	walker.velocity = Vector2.ZERO
	walker.set_physics_process(false)
	effect.descending = true
	_layer.layer = 90
	add_child(_layer)
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_cover.draw.connect(_draw_cover)
	_layer.add_child(_cover)


func _process(delta: float) -> void:
	advance(minf(delta, 0.1))


## Explicit advancement also permits deterministic frame captures without loading a run.
func advance(delta: float) -> void:
	if completed: return
	elapsed = minf(elapsed + maxf(delta, 0.0), def.duration())
	var approach := clampf(elapsed / def.approach_seconds, 0.0, 1.0)
	var gather := clampf((elapsed - def.approach_seconds) / def.gathering_seconds, 0.0, 1.0)
	var fall := clampf((elapsed - def.approach_seconds - def.gathering_seconds) / def.fall_seconds, 0.0, 1.0)
	walker.position = PixelDraw.snap(_start.lerp(well + Vector2(0, 8), approach))
	walker.rig.update_state(Vector2.UP, 60.0 if approach < 1.0 else 0.0, false, delta)
	walker.rig.position.y = PixelDraw.snap_length(fall * 24.0) if fall > 0.0 else 0.0
	walker.rig.visible = fall < 0.5
	effect.gathering = gather
	var frame := floori(elapsed * def.fps)
	if frame != _frame:
		_frame = frame
		_cover.queue_redraw()
	if elapsed >= def.duration():
		completed = true
		set_process(false)
		_cover.queue_redraw()
		finished.emit()


func _draw_cover() -> void:
	var amount := clampf((elapsed - def.duration() + def.close_seconds) / def.close_seconds, 0.0, 1.0)
	if amount <= 0.0: return
	var area := _cover.size
	if amount >= 1.0:
		_cover.draw_rect(Rect2(Vector2.ZERO, area), def.darkness)
		return
	var center := walker.get_global_transform_with_canvas().origin
	var radius := area.length() * (1.0 - amount)
	# Two opaque rectangles per eight UI pixels form a stepped iris, with no screen texture.
	for y in range(0, ceili(area.y), 8):
		var dy := absf(float(y) + 4.0 - center.y)
		var half := floorf(sqrt(maxf(radius * radius - dy * dy, 0.0)) / 8.0) * 8.0
		var left := clampf(center.x - half, 0.0, area.x)
		var right := clampf(center.x + half, 0.0, area.x)
		_cover.draw_rect(Rect2(0, y, left, 8), def.darkness)
		_cover.draw_rect(Rect2(right, y, area.x - right, 8), def.darkness)
