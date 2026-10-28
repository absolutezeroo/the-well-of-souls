class_name TelegraphView
extends Node2D
## Draws a monster's attack warning with telegraph.gdshader: an area, a cone, a line, or the
## lanes of a fan or a ring of shots, filling up as the attack comes. Hidden when there is
## nothing to warn about. Never turned: the shader points the shape and keeps its pixels on the
## world's grid.

enum Shape { CIRCLE, CONE, LINE, LANES }

const SHADER := preload("res://assets/shaders/telegraph.gdshader")
## The narrowest lane of a shot (a small shot's path still reads); a bigger shot's lane is as
## wide as the shot (show_shots()).
const LANE_WIDTH := 8.0
## The danger colors every threat on the floor shares (telegraph.gdshader's `color` and its
## edge's light; CellWarning): the red, and the pale red its rim turns as the hit comes.
const DANGER := Color(1.0, 0.22, 0.2)
const DANGER_EDGE := Color(1.0, 0.85, 0.8)
## The most lanes the shader cuts at walls one by one (telegraph.gdshader's lane_reach).
const MAX_LANES := 32

## What _draw() covers (the shader cuts the shape out of it): a square round the monster, or
## just the box of a line, so a long shot's lane doesn't shade a whole screen for nothing.
var _area := Rect2(-60.0, -60.0, 120.0, 120.0)
## Shots' lanes end at the first wall in their way, as the shots do (a warning in the world:
## MonsterOverlay, ShotsMark; the bestiary's preview has no walls). Roadmap task 419.
var clip_to_walls := false
## The reach of each lane last shown (lane_reaches()), and what it was worked out for: the walls
## are asked once per wind-up, again only if the caster or its aim moves.
var _reaches := PackedFloat32Array()
var _reaches_for := []
var _look: ShaderMaterial
## Its red light on the floor: a warning flat under the actors still reads in a dark room.
var _light: LightSource


func _init() -> void:
	_look = ShaderMaterial.new()
	_look.shader = SHADER
	_look.set_shader_parameter("color", DANGER)
	material = _look
	visible = false
	# On the floor, under whoever stands in it (docs/vfx.md, "Layers").
	VfxLayer.apply(self, VfxLayer.Layer.GROUND)


## A red light on the floor while it shows (a monster's warning in the world; the codex's
## preview has no floor light to add to).
func add_light() -> void:
	_light = LightSource.new()
	_light.color = Color(1.0, 0.3, 0.24)
	_light.level = 3
	_light.relative = true
	_light.moves = true
	add_child(_light)


## `angle`: where it points (cones and lines). `progress`: 0 when it starts, 1 when it lands.
func show_shape(shape: Shape, radius: float, angle: float, progress: float, half_angle: float = 0.0, width: float = 10.0) -> void:
	visible = true
	if shape == Shape.LINE:
		var tip := Vector2.from_angle(angle) * radius
		_area = Rect2(Vector2.ZERO, Vector2.ZERO).expand(tip).grow(width * 0.5 + 4.0)
	else:
		_area = Rect2(-Vector2.ONE * (radius + 4.0), Vector2.ONE * (radius + 4.0) * 2.0)
	_look.set_shader_parameter("shape", shape)
	_look.set_shader_parameter("radius", radius)
	_look.set_shader_parameter("aim", angle)
	_look.set_shader_parameter("half_angle", half_angle)
	_look.set_shader_parameter("line_width", width)
	_look.set_shader_parameter("progress", progress)
	queue_redraw()


## The lanes of `lanes` shots fanned over `spread_degrees` (360: a ring) around `angle`,
## starting `inner` out from the caster; `reaches`: each lane's own length (empty: `radius`).
func show_lanes(radius: float, angle: float, progress: float, lanes: int, spread_degrees: float, inner: float = 0.0, width: float = LANE_WIDTH, reaches := PackedFloat32Array()) -> void:
	_look.set_shader_parameter("clip_count", mini(reaches.size(), MAX_LANES))
	if not reaches.is_empty():
		var padded := reaches.duplicate()
		padded.resize(MAX_LANES)  # (the shader's array is always that long)
		_look.set_shader_parameter("lane_reach", padded)
	_look.set_shader_parameter("lanes", maxi(lanes, 1))
	_look.set_shader_parameter("spread", deg_to_rad(spread_degrees) if spread_degrees < 360.0 else TAU)
	_look.set_shader_parameter("inner", inner)
	show_shape(Shape.LANES, radius, angle, progress, 0.0, width)


## The path of `count` shots of `shot_radius` fanned over `spread_degrees` (360: a ring) toward
## `angle`, as far as they fly (`length`, never shortened): one line, or the lanes of a fan or a
## ring starting `inner` out, each as wide as the shot (LANE_WIDTH at least). The mark is the
## real area (docs/decisions/0008); a ring's lanes show its gaps.
func show_shots(length: float, angle: float, progress: float, count: int, spread_degrees: float, shot_radius: float, inner: float = 0.0) -> void:
	var width := maxf(LANE_WIDTH, shot_radius * 2.0)
	var single := count <= 1 or spread_degrees <= 0.0
	var reaches := lane_reaches(length, angle, 1 if single else count, 0.0 if single else spread_degrees) if clip_to_walls else PackedFloat32Array()
	if single:
		_look.set_shader_parameter("clip_count", 0)
		show_shape(Shape.LINE, reaches[0] if not reaches.is_empty() else length, angle, progress, 0.0, width)
	else:
		show_lanes(length, angle, progress, count, spread_degrees, inner, width, reaches)


## How far each lane of `count` shots fanned over `spread_degrees` toward
## `angle` goes before a wall stops it, `length` at most: lane k as the shader counts it (from the
## fan's first, or the ring's aim). Asked of the world's walls (Layers.WORLD, what stops a shot)
## from where it stands; worked out again only when where or which way changed.
func lane_reaches(length: float, angle: float, count: int, spread_degrees: float) -> PackedFloat32Array:
	if not is_inside_tree():
		return PackedFloat32Array()
	var key := [global_position.snapped(Vector2.ONE * 2.0), snappedf(angle, 0.01), length, count, spread_degrees]
	if key == _reaches_for:
		return _reaches
	_reaches_for = key
	_reaches = PackedFloat32Array()
	var space := get_world_2d().direct_space_state
	var lanes := mini(maxi(count, 1), MAX_LANES)
	for k in lanes:
		var lane := angle
		if spread_degrees >= 360.0:
			lane = angle + TAU / count * k
		elif count > 1:
			lane = angle - deg_to_rad(spread_degrees) * 0.5 + deg_to_rad(spread_degrees) / (count - 1) * k
		var way := Vector2.from_angle(lane)
		var query := PhysicsRayQueryParameters2D.create(global_position, global_position + way * length, Layers.WORLD)
		var hit := space.intersect_ray(query)
		# (To the wall's face: the shot's front gets there, not past it.)
		_reaches.append(length if hit.is_empty() else global_position.distance_to(hit.position))
	return _reaches


## The size of what it last showed (tests): the shape's reach and the area it covers.
func area() -> Rect2:
	return _area


## The warning of `skill` cast toward `angle` by a body of `body_radius`: its own radius when it
## has one, else what its first effect shows (Effect.show_warning(): the lanes of its shots, the
## line of its dash, the circle of its area). Returns false
## (and hides) for a skill with nothing to warn about (a summon, a heal). `position` is moved to
## an area pushed forward along the aim.
func show_skill(skill: SkillDef, angle: float, progress: float, body_radius: float = 0.0) -> bool:
	position = Vector2.ZERO
	if skill.telegraph_radius > 0.0:
		show_shape(Shape.CIRCLE, skill.telegraph_radius, angle, progress)
		return true
	var first: Effect = skill.effects[0] if not skill.effects.is_empty() else null
	if first and first.show_warning(self, angle, progress, body_radius):
		return true
	visible = false
	return false


func _draw() -> void:
	draw_rect(_area, Color.WHITE)
