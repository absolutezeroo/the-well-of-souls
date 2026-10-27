class_name DebugShapes
extends Node2D
## Draws what the rules see over the floor, in debug builds (DebugPanel's Tools tab,
## DebugCheats.show_shapes): every body on screen (its collision circle), the hero's weapon reach,
## each monster's attack range (red) and how far it notices the hero (dim), and a line to its
## target; the areas that hurt or catch (every Area2D's collision shapes: traps, shots, pickups'
## reach; orange) and the ground strikes waiting to land (a boss's delayed spells: magenta).
## In the world's coordinates (a child of the Game, under the camera); only reads.

const BODY := Color(0.4, 1.0, 0.5, 0.9)
const REACH := Color(1.0, 0.85, 0.3, 0.8)
const ATTACK := Color(1.0, 0.3, 0.25, 0.85)
const SIGHT := Color(0.6, 0.75, 1.0, 0.35)
const TARGET := Color(1.0, 0.3, 0.25, 0.5)
## An area's shape (a trap, a shot, a hazard's reach).
const AREA := Color(1.0, 0.6, 0.15, 0.8)
## A ground strike's circle, before it lands.
const STRIKE := Color(1.0, 0.3, 0.9, 0.85)

var game: Game


func _init() -> void:
	name = "DebugShapes"
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX - 1
	hide()


func _process(_delta: float) -> void:
	visible = DebugCheats.show_shapes
	if visible:
		queue_redraw()


func _draw() -> void:
	var world := game.player.world if game and game.player and is_instance_valid(game.player.world) else null
	if world == null or not world.is_inside_tree():
		return
	var view := world.view_rect()
	for actor in world.get_actors():
		if not is_instance_valid(actor) or actor.is_dead or not view.has_point(actor.global_position):
			continue
		var at := actor.global_position
		draw_arc(at, actor.radius, 0.0, TAU, 24, BODY, 1.0)
		var weapon := actor.get_weapon()
		if actor is Monster:
			var monster := actor as Monster
			draw_arc(at, monster.detect_radius(), 0.0, TAU, 64, SIGHT, 1.0)
			if weapon:
				var reach := monster.attack_range(game.player) if game.player else weapon.reach
				draw_arc(at, reach, 0.0, TAU, 32, ATTACK, 1.0)
			if is_instance_valid(monster.target):
				draw_line(at, monster.target.global_position, TARGET, 1.0)
		elif weapon:
			draw_arc(at, actor.radius + weapon.reach, 0.0, TAU, 32, REACH, 1.0)
	for found in world.find_children("*", "Area2D", true, false):
		var area := found as Area2D
		if area.is_queued_for_deletion() or not area.is_visible_in_tree() or not view.grow(64.0).has_point(area.global_position):
			continue
		for child in area.get_children():
			var holder := child as CollisionShape2D
			if holder and holder.shape and not holder.disabled:
				_draw_shape(holder.shape, holder.global_transform, AREA)
	for found in world.find_children("*", "GroundStrike", true, false):
		var strike := found as GroundStrike
		if view.grow(strike.radius).has_point(strike.global_position):
			draw_arc(strike.global_position, strike.radius, 0.0, TAU, 32, STRIKE, 1.0)


## A collision shape's outline at `where` (world coordinates): circles, rectangles, capsules,
## segments; others as a small cross.
func _draw_shape(shape: Shape2D, where: Transform2D, color: Color) -> void:
	draw_set_transform_matrix(where)
	if shape is CircleShape2D:
		draw_arc(Vector2.ZERO, (shape as CircleShape2D).radius, 0.0, TAU, 24, color, 1.0)
	elif shape is RectangleShape2D:
		var extent := (shape as RectangleShape2D).size
		draw_rect(Rect2(-extent * 0.5, extent), color, false, 1.0)
	elif shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var half := maxf(capsule.height * 0.5 - capsule.radius, 0.0)
		draw_arc(Vector2(0, -half), capsule.radius, PI, TAU, 12, color, 1.0)
		draw_arc(Vector2(0, half), capsule.radius, 0.0, PI, 12, color, 1.0)
		draw_line(Vector2(-capsule.radius, -half), Vector2(-capsule.radius, half), color, 1.0)
		draw_line(Vector2(capsule.radius, -half), Vector2(capsule.radius, half), color, 1.0)
	elif shape is SegmentShape2D:
		draw_line((shape as SegmentShape2D).a, (shape as SegmentShape2D).b, color, 1.0)
	else:
		draw_line(Vector2(-4, 0), Vector2(4, 0), color, 1.0)
		draw_line(Vector2(0, -4), Vector2(0, 4), color, 1.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)
