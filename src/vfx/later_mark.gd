class_name LaterMark
extends Node2D
## The warning of a later blow of a monster's cast (an effect with a `delay`: a fierce ring's
## second burst between the gaps of the first, a second arc of flame, a second volley): its own
## mark (Effect.show_warning(), the lanes cut at walls), shown from the cast's start until that
## blow lands, filling up over the whole time. The cast's own warning (MonsterOverlay) shows the
## first blow only and is gone when the cast lets go; without this, the later blow came with
## nothing drawn (roadmap task 416; docs/decisions/0008: the mark covers the real area and lasts
## until the hit). It follows its caster; gone if the cast is cut short or the caster falls.
## Not for a cast that carries its caster (a leap, a rush): its later blows land where the body
## will be, which a mark following it would show in the wrong place before it moves.

var _view: TelegraphView
var _effect: Effect
var _caster: WeakRef
var _skill: SkillDef
var _angle := 0.0
var _body_radius := 0.0
## The cast's length and the whole time to the blow (cast + its delay), and the time gone.
var _cast := 0.0
var _total := 0.4
var _time := 0.0


## The marks of `skill`'s later blows, cast by `caster` toward `angle` over `cast_time` seconds
## (the floor already in: Monster.skill_cast_time()): one per later effect that shows a warning;
## none for a cast that moves its caster. Added to the caster's world (World.spawn_vfx: nothing in
## a simulation).
static func mark_later_blows(caster: Monster, skill: SkillDef, angle: float, cast_time: float) -> void:
	if skill == null or caster.world == null or skill.effects.any(func(e: Effect) -> bool: return e != null and e.moves_caster()):
		return
	for later in later_effects(skill):
		var mark := LaterMark.new()
		mark._effect = later
		mark._caster = weakref(caster)
		mark._skill = skill
		mark._angle = angle
		mark._body_radius = caster.radius
		mark._cast = cast_time
		mark._total = cast_time + later.delay
		mark.position = caster.global_position
		VfxLayer.apply(mark, VfxLayer.Layer.GROUND)  # on the floor, under whoever stands in it
		caster.world.spawn_vfx(mark)


## The effects of `skill` that come after its first blow and warn (a delay, something to show).
static func later_effects(skill: SkillDef) -> Array[Effect]:
	var result: Array[Effect] = []
	for each in skill.effects:
		if each and each.delay > 0.0 and each.hurts():
			result.append(each)
	return result


func _ready() -> void:
	_view = TelegraphView.new()  # with its red light: it reads in a dark room
	_view.add_light()
	_view.clip_to_walls = true
	add_child(_view)
	_show()


func _notification(what: int) -> void:
	# Its floor waits out of the tree (the Threshold): the cast is gone with it.
	if what == NOTIFICATION_EXIT_TREE:
		queue_free()


func _process(delta: float) -> void:
	_time += delta
	if _time >= _total or _cut_short():
		queue_free()
		return
	_show()


## The caster fell or vanished, or its cast was cut short (a boss changing phase).
func _cut_short() -> bool:
	var caster := _caster.get_ref() as Monster if _caster else null
	if caster == null or caster.is_dead or caster.is_falling:
		return true
	return _time < _cast - 0.05 and caster.casting_skill() != _skill


## How far along to the blow it is (0 when the cast starts, 1 when it lands).
func progress() -> float:
	return clampf(_time / _total, 0.0, 1.0)


## The effect it warns of (tests).
func warned_effect() -> Effect:
	return _effect


## Its view (tests: the lanes and their reach).
func view() -> TelegraphView:
	return _view


func _show() -> void:
	var caster := _caster.get_ref() as Node2D if _caster else null
	if caster and caster.is_inside_tree():
		global_position = caster.global_position
	_effect.show_warning(_view, _angle, progress(), _body_radius)
