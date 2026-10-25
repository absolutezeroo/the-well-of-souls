class_name GroundStrike
extends Node2D
## A warning on the ground that fills up for `fuse` seconds, then a strike on that spot that
## hurts the source's enemies inside it: a tentacle slamming down, a column of false sunlight, a
## lantern's flame closing in, a maw biting. Never its source's own side. Fizzles if the source
## is gone or dead by then, or if its floor was left. Made by GroundStrikeEffect and traits.

signal landed

var source: Actor
var radius := 40.0
var fuse := 0.8
## Seconds before the warning even shows (strikes in a row).
var delay := 0.0
var damage := 10
var knockback := 200.0
var element: VfxElementDef
## Played on the spot when it lands (a column, a bolt), at the art's size.
var strike: VfxSheetDef
var status: OnHitStatus
## Screen shake when it lands (0: none).
var shake := 0.25
var sound: AudioStream
## A flash of light where it lands (alpha 0: none): a flame lights the dark floor around it.
var glow := Color(0, 0, 0, 0)

var _world: World
var _floor_id := 0
var _time := 0.0
var _view: TelegraphView


## A strike of `source` on `at` (World.spawn_vfx puts it on the ground).
static func create(world: World, from: Actor, at: Vector2, area: float, warning: float, amount: int, push: float, made_of: VfxElementDef = null) -> GroundStrike:
	var node := GroundStrike.new()
	node._world = world
	node._floor_id = world.floor_id
	node.source = from
	node.position = at
	node.radius = area
	node.fuse = maxf(warning, 0.05)
	node.damage = amount
	node.knockback = push
	node.element = made_of
	VfxLayer.apply(node, VfxLayer.Layer.GROUND)
	return node


func _ready() -> void:
	_view = TelegraphView.new()  # on the floor, with its red light
	_view.add_light()
	add_child(_view)


func _process(delta: float) -> void:
	_time += delta
	if _time < delay:
		return
	var fraction := clampf((_time - delay) / fuse, 0.0, 1.0)
	_view.show_shape(TelegraphView.Shape.CIRCLE, radius, 0.0, fraction)
	if fraction >= 1.0:
		_land()


## How far along the warning is (0 when it shows, 1 when it lands).
func progress() -> float:
	return clampf((_time - delay) / fuse, 0.0, 1.0)


func _land() -> void:
	set_process(false)
	queue_free()
	if not is_instance_valid(_world) or _world.floor_id != _floor_id or not _world.is_inside_tree():
		return
	if not is_instance_valid(source) or source.is_dead or source.is_falling or not source.is_inside_tree() or source.world != _world:
		return
	var at := global_position
	Combat.damage_area(_world, source, at, radius, damage, knockback, false, status, element)
	if element:
		Vfx.nova(_world, at, radius, element)
	if strike:
		_world.spawn_vfx(SheetVfx.play(strike, at, Vector2.UP, element))
	if glow.a > 0.0:
		_world.flash_light(at, glow, radius * 2.0)
	Sfx.play_at(sound if sound else Sfx.bank.explosion, at, -6.0)
	if shake > 0.0:
		Events.screen_shake.emit(shake)
	landed.emit()
