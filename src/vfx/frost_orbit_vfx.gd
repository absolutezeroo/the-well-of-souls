class_name FrostOrbitVfx
extends Node2D
## The shards of Rime Halo (FrostOrbitPassive) circling their owner: frost's own shot (the
## faceted shard of Ice Shards and the Frost Staff, `VfxElementDef.projectile`), each drawn in
## the row facing the way it travels, on the grid, at the angle the passive keeps in its memory
## (the hits and the look turn together). A child of the owner, so it follows him; in the air
## over the bodies (a shard passes in front of what it cuts). Cosmetic: only made when effects
## are shown (Vfx.shown); it redraws every frame while on screen (it always moves), and goes
## when the passive stops turning it.

var count := 2
var _memory: Dictionary
var _passive: FrostOrbitPassive
var _time := 0.0
## The passive's clock when last seen, and for how long it has stood still: a ring whose perk
## stopped turning it (the run's perks cleared, the hero gone) frees itself.
var _clock := -1.0
var _still := 0.0


func setup(memory: Dictionary, passive: FrostOrbitPassive, shards: int) -> void:
	_memory = memory
	_passive = passive
	count = shards
	VfxLayer.apply(self, VfxLayer.Layer.AIR)
	material = FxLook.sprite(true)  # ice catches the light: its colors stay out of the floor's grading


func _process(delta: float) -> void:
	_time += delta
	var clock: float = _memory.get("_clock", 0.0)
	if clock == _clock:
		_still += delta
		if _still > 0.3:
			_memory.erase("_look")
			queue_free()
			return
	else:
		_clock = clock
		_still = 0.0
	if Vfx.on_screen(self, _passive.orbit + 16.0):
		queue_redraw()


func _draw() -> void:
	var element := _passive.element
	var sheet := element.projectile if element else null
	var angle := FrostOrbitPassive.angle_of(_memory)
	var frame := int(_time * (sheet.fps if sheet else 8.0))
	for i in count:
		var a := angle + TAU * i / count
		var at := Vector2.from_angle(a) * _passive.orbit + Vector2(0.0, -8.0)  # at the body's middle
		var along := Vector2.from_angle(a + PI * 0.5)
		if sheet:
			PixelDraw.sheet(self, sheet, frame, at, along, element)
		else:
			PixelDraw.disc(self, at, 4.0, Palette.FROST)
