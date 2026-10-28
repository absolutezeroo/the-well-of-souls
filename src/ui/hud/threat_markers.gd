class_name ThreatMarkers
extends Control
## Arrows at the screen's edge pointing at threats out of sight (docs/decisions/0008: an attack
## about to come from off screen gets an edge marker): an awake monster winding up an attack or a
## cast (Monster.telegraph), an enemy shot flying toward the hero (Projectile.threatens()).
## Chevrons in the telegraph's danger red with a dark rim, cut in whole art pixels at the nearest
## of 16 directions like the Deeps' arrow (AbyssHud: never a turned sprite): a darker red while a
## wind-up begins, the telegraph's own red once it is half done (and for a shot on its way). Drawn over the whole HUD (behind nothing),
## at most MAX_MARKERS, the nearest first. The HUD keeps it (Hud.bind_player()); it reads the
## world and drives nothing.

const MAX_MARKERS := 6
## The arrows' tips stay this far inside the screen's edges (screen pixels).
const EDGE_MARGIN := 30.0
## A shot further than this from the view (world units) is not worth an arrow yet.
const SHOT_RANGE := 500.0

var player: Player

## What was drawn: per marker its tip (screen pixels, on the arrow's grid) and its direction (one
## of 16), and whether it is urgent (the full red).
var _drawn := PackedVector3Array()
var _drawn_urgent := PackedByteArray()
## Found this frame (kept between frames: no allocation per frame).
var _found := PackedVector3Array()  # x, y: the threat's point on screen; z: its squared distance
var _found_urgent := PackedByteArray()
## The chevron's cells (offsets from the tip, in screen pixels) and whether each is rim (1) or
## body (0), per direction: worked out once each.
static var _masks := {}


func _init() -> void:
	name = "ThreatMarkers"
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	z_index = 50  # over every other part of the HUD


func _process(_delta: float) -> void:
	scan()


## Looks for the threats out of sight and redraws the arrows when they changed.
func scan() -> void:
	_found.clear()
	_found_urgent.clear()
	var world := player.world if is_instance_valid(player) and not player.is_dead else null
	if world != null and world.is_inside_tree() and is_visible_in_tree():
		var view := world.view_rect(0.0)
		var canvas := player.get_canvas_transform()
		var hero := player.global_position
		for actor in world.actors_this_frame():
			var monster := actor as Monster
			if monster == null or monster.is_dead or not monster.is_awake or monster.telegraph <= 0.0:
				continue
			if not monster.is_hostile_to(player) or view.has_point(monster.global_position):
				continue
			_add(canvas * monster.global_position, hero.distance_squared_to(monster.global_position), monster.telegraph >= 0.5)
		var shots := world.projectile_layer()
		var near := view.grow(SHOT_RANGE)
		for i in shots.get_child_count() if shots else 0:
			var shot := shots.get_child(i) as Projectile
			if shot == null or view.has_point(shot.global_position) or not near.has_point(shot.global_position):
				continue
			if shot.threatens(player):
				_add(canvas * shot.global_position, hero.distance_squared_to(shot.global_position), true)
	_place()


## The arrows showing now (tests): how many.
func count() -> int:
	return _drawn.size()


## The direction (radians, one of 16) of arrow `index` (tests).
func direction_of(index: int) -> float:
	return _drawn[index].z


## Where arrow `index`'s tip is, in the HUD's pixels (tests).
func tip_of(index: int) -> Vector2:
	return Vector2(_drawn[index].x, _drawn[index].y)


func _add(at: Vector2, distance: float, urgent: bool) -> void:
	_found.append(Vector3(at.x, at.y, distance))
	_found_urgent.append(1 if urgent else 0)


## The nearest threats' arrows on the edge of the screen; redrawn only when they changed.
func _place() -> void:
	if _found.is_empty():
		if not _drawn.is_empty():  # (most frames: nothing to point at, nothing made)
			_drawn.clear()
			_drawn_urgent.clear()
			queue_redraw()
		return
	var shown := PackedVector3Array()
	var urgent := PackedByteArray()
	var taken := PackedByteArray()
	taken.resize(_found.size())
	var area := get_rect().grow(-EDGE_MARGIN)
	var middle := area.get_center()
	var half := area.size * 0.5
	for n in mini(MAX_MARKERS, _found.size()):
		var best := -1
		for i in _found.size():
			if taken[i] == 0 and (best < 0 or _found[i].z < _found[best].z):
				best = i
		taken[best] = 1
		var way := Vector2(_found[best].x, _found[best].y) - middle
		if way == Vector2.ZERO or half.x <= 0.0 or half.y <= 0.0:
			continue
		var angle := snappedf(way.angle(), TAU / 16.0)
		# Where the line from the middle toward it leaves the area: the tip, on the arrow's grid.
		var reach := minf(half.x / maxf(absf(way.x), 0.001), half.y / maxf(absf(way.y), 0.001))
		var tip := ((middle + way * reach) / AbyssHud.ARROW_PX).floor() * AbyssHud.ARROW_PX
		shown.append(Vector3(tip.x, tip.y, angle))
		urgent.append(_found_urgent[best])
	if shown == _drawn and urgent == _drawn_urgent:
		return
	_drawn = shown
	_drawn_urgent = urgent
	queue_redraw()


func _draw() -> void:
	var red := TelegraphView.DANGER
	var early := TelegraphView.DANGER.darkened(0.35)
	for i in _drawn.size():
		var tip := Vector2(_drawn[i].x, _drawn[i].y)
		var mask := _mask(_drawn[i].z)
		var cells: PackedVector2Array = mask[0]
		var rims: PackedByteArray = mask[1]
		var body := red if _drawn_urgent[i] == 1 else early
		for c in cells.size():
			draw_rect(Rect2(tip + cells[c], Vector2.ONE * AbyssHud.ARROW_PX), Palette.INK if rims[c] == 1 else body)


## The chevron pointing along `angle`, its tip at (0, 0): [cells, rim flags], made once per
## direction.
static func _mask(angle: float) -> Array:
	var key := roundi(angle / (TAU / 16.0))
	if _masks.has(key):
		return _masks[key]
	var cells := PackedVector2Array()
	var rims := PackedByteArray()
	var px := AbyssHud.ARROW_PX
	for dy in range(-14, 15):
		for dx in range(-14, 15):
			var local := (Vector2(dx, dy) + Vector2.ONE * 0.5).rotated(-angle)
			var inside := _inside(local)
			if not inside and not _inside(local + Vector2(1, 0)) and not _inside(local + Vector2(-1, 0)) \
					and not _inside(local + Vector2(0, 1)) and not _inside(local + Vector2(0, -1)):
				continue
			cells.append(Vector2(dx, dy) * px)
			rims.append(0 if inside else 1)
	_masks[key] = [cells, rims]
	return _masks[key]


## In the arrowhead (local art pixels, the tip at 0 pointing along +x): a wedge 11 pixels long
## with a notch cut from behind, a little smaller than the Deeps' (several may show).
static func _inside(local: Vector2) -> bool:
	var depth := -local.x
	if depth < -0.5 or depth > 11.0 or absf(local.y) > depth * 0.6 + 0.5:
		return false
	return not (depth > 7.0 and absf(local.y) < (depth - 7.0) * 1.2)
