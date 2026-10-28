class_name EmberTrail
extends Node2D
## The embers a roll leaves behind (EmberTrailPassive, Cinder Wake): an ember dropped every
## SPACING world units along the roller's path while he rolls, each burning `life` seconds. Every
## `pulse`, the roller's enemies whose body touches an ember catch fire and take the trail's
## damage as a secondary hit (HitInfo.is_secondary: no on-hit perks, so nothing loops). Drawn as
## the fire kit's small flames on the floor (fire_flicker, the brazier's and the burning body's),
## out of step, sinking to embers in their last moments and going out oldest first.
## On the floor (VfxLayer.GROUND): under every body, never over the hero's feet (docs/vfx.md 2b),
## with a light of its own, since the floor's light dims the ground layer.

const FLICKER: Texture2D = preload("res://assets/fx/fire/fire_flicker.png")
const FRAMES := 12
const FPS := 10.0
## World units between two embers along the roll.
const SPACING := 14.0
## Its last seconds an ember sinks: only the bottom of its flame shows.
const SINK := 0.6

var _source: Actor
var _faction: Actor.Faction = Actor.Faction.PLAYER
var _def: EmberTrailPassive
var _stacks := 1
var _world: World
var _floor_id := 0
## Embers, in the World's space (the node lies at the trail's start), and when each was dropped.
var _points := PackedVector2Array()
var _born := PackedFloat32Array()
var _age := 0.0
var _pulse_left := 0.0
## Still dropping embers (its roller is still rolling).
var _laying := true
var _frame := -1
var _drawn := 0
var _light: LightSource


## A trail behind `source`'s roll, burning as `def` says, `stacks` levels of it.
func setup(source: Actor, def: EmberTrailPassive, stacks: int) -> void:
	_source = source
	_faction = source.faction
	_def = def
	_stacks = maxi(1, stacks)
	_world = source.world
	_floor_id = _world.floor_id
	position = source.global_position
	_drop(source.global_position)
	_pulse_left = def.pulse * 0.5  # the first burn soon after the roll starts
	VfxLayer.apply(self, VfxLayer.Layer.GROUND)
	if Vfx.shown:
		material = FxLook.flame(def.element)
		_light = LightSource.new()
		_light.color = def.element.core() if def.element else Palette.FIRE
		_light.relative = true
		_light.moves = true
		_light.level = 6
		add_child(_light)


## Embers lying where something landed (a shot of the Ashen Codex: ShotEmbersPassive), not left
## by a roll: `count` of them around `at`, burning as `def` says.
func lay_at(source: Actor, def: EmberTrailPassive, at: Vector2, count: int = 3) -> void:
	setup(source, def, 1)
	_points.clear()
	_born.clear()
	position = at
	for i in count:
		_drop(at + Vector2.from_angle(TAU * i / maxi(count, 1) + 0.4) * (SPACING * 0.6 if count > 1 else 0.0))
	_laying = false
	if _light:
		_light.position = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_world) or _world.floor_id != _floor_id:
		queue_free()  # its floor was left
		return
	_age += delta
	if _laying:
		if is_instance_valid(_source) and not _source.is_dead and _source.is_dashing() and _age < 1.5:
			if _source.global_position.distance_to(_points[_points.size() - 1]) >= SPACING:
				_drop(_source.global_position)
		else:
			_laying = false
			if is_instance_valid(_source) and _source.global_position.distance_to(_points[_points.size() - 1]) >= SPACING * 0.5:
				_drop(_source.global_position)
			if _light:
				_light.position = _points[floori(_points.size() / 2.0)] - position  # its middle
	# The oldest embers go out.
	var gone := 0
	while gone < _born.size() and _age - _born[gone] >= _def.life:
		gone += 1
	if gone > 0:
		_points = _points.slice(gone)
		_born = _born.slice(gone)
	if _points.is_empty():
		queue_free()
		return
	_pulse_left -= delta
	if _pulse_left <= 0.0:
		_pulse_left += _def.pulse
		_burn()
	if Vfx.shown:
		var frame := int(_age * FPS)
		if frame != _frame or _points.size() != _drawn:
			_frame = frame
			if Vfx.on_screen(self, SPACING * _points.size() + 32.0):
				queue_redraw()


func _drop(at: Vector2) -> void:
	_points.append(at)
	_born.append(_age)


## The roller's enemies touching an ember: set on fire, and hurt a little.
func _burn() -> void:
	if not is_instance_valid(_source):
		return
	var amount := maxi(1, roundi(_source.get_power() * _def.damage_multiplier * _stacks))
	for actor in _world.actors_this_frame():
		if actor.is_dead or actor.faction == _faction or not _touches(actor):
			continue
		var hit := Combat.make_secondary_hit(_source, amount)
		hit.status = _def.status
		hit.element = _def.element
		hit.cause = &"burn"
		actor.take_hit(hit)


func _touches(actor: Actor) -> bool:
	var reach := _def.reach + actor.radius
	var reach_squared := reach * reach
	var at := actor.global_position
	for point in _points:
		if at.distance_squared_to(point) <= reach_squared:
			return true
	return false


func _draw() -> void:
	_drawn = _points.size()
	var cell := Vector2(int(FLICKER.get_width() / float(FRAMES)), FLICKER.get_height())
	var size := cell * PixelDraw.PX
	for i in _points.size():
		var left := _def.life - (_age - _born[i])
		var frame := (_frame + i * 5) % FRAMES
		var base := PixelDraw.snap(_points[i] - position + Vector2(0.0, 6.0))
		if left > SINK:
			draw_texture_rect_region(FLICKER, Rect2(base - Vector2(size.x * 0.5, size.y), size), Rect2(Vector2(frame * cell.x, 0), cell))
		else:
			# Sinking: the bottom third of its flame, the embers.
			var low := floorf(cell.y / 3.0)
			draw_texture_rect_region(FLICKER, Rect2(base - Vector2(size.x * 0.5, low * PixelDraw.PX), Vector2(size.x, low * PixelDraw.PX)), Rect2(Vector2(frame * cell.x, cell.y - low), Vector2(cell.x, low)))
