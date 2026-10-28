class_name FuseMark
extends Node2D
## The warning of a blast to come: a boss's shockwave, a skull's burst after its death, a bomb's
## fuse. The red circle every threat on the floor shares (TelegraphView), as wide as the blast,
## filling up for the whole fuse and flashing just before it lands, then gone; it follows its
## source when it has one (a boss stomps where it stands when the fuse ends, not where it was).
## Made by Combat.shockwave() and Combat.delayed_blast() (docs/decisions/0008: the ground mark
## covers the real area and lasts until the hit).

var _view: TelegraphView
var _radius := 40.0
var _fuse := 0.4
var _time := 0.0
## What it follows (weak: the boss may be freed first); null: it stays where it was put.
var _follow: WeakRef


static func create(at: Vector2, radius: float, fuse: float, follow: Node2D = null) -> FuseMark:
	var mark := FuseMark.new()
	mark.position = at
	mark._radius = radius
	mark._fuse = maxf(fuse, 0.05)
	mark._follow = weakref(follow) if follow else null
	VfxLayer.apply(mark, VfxLayer.Layer.GROUND)  # on the floor, under whoever stands in it
	return mark


func _ready() -> void:
	_view = TelegraphView.new()  # with its red light: it reads in a dark room
	_view.add_light()
	add_child(_view)
	_show()


func _notification(what: int) -> void:
	# Its floor waits out of the tree (the Threshold): the blast fizzles there, so does its mark.
	if what == NOTIFICATION_EXIT_TREE:
		queue_free()


func _process(delta: float) -> void:
	_time += delta
	if _time >= _fuse or _source_gone():
		queue_free()  # landed, or its boss fell first (its blast fizzles: no mark of nothing)
		return
	_show()


## It followed a source that is no more (freed, or a body slain).
func _source_gone() -> bool:
	if _follow == null:
		return false
	var source := _follow.get_ref() as Node2D
	return source == null or (source is Actor and (source as Actor).is_dead)


## How far along the fuse is (0 when it shows, 1 when the blast lands).
func progress() -> float:
	return clampf(_time / _fuse, 0.0, 1.0)


func _show() -> void:
	var source := _follow.get_ref() as Node2D if _follow else null
	if source and source.is_inside_tree():
		global_position = source.global_position
	_view.show_shape(TelegraphView.Shape.CIRCLE, _radius, 0.0, progress())
