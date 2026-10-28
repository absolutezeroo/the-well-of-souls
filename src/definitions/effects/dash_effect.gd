class_name DashEffect
extends Effect
## Quick burst of movement.
## Its `element` (Effect.element): what the user turns into for the dash (data/vfx/elements/): it
## vanishes in its element's impact, leaves its pieces along the way (Shadow Step: smoke drawn back
## in; Blink: pale flames) and appears in its impact again. Empty: a plain dash (the roll's own
## afterimages say it).

enum Direction {
	## Where the user is moving, or along the aim when standing still (a roll).
	MOVE,
	## Toward the aim (gap closer).
	AIM,
	## Away from the aim (back step).
	AWAY,
}

@export var direction: Direction = Direction.MOVE
@export var distance: float = 150.0
@export var duration: float = 0.16
@export var invulnerable: bool = true


func apply(user: Actor, aim: Vector2) -> void:
	var dir := aim
	match direction:
		Direction.MOVE:
			if user.get_move_direction() != Vector2.ZERO:
				dir = user.get_move_direction()
		Direction.AWAY:
			dir = -aim
	user.start_dash(dir.normalized() * distance / duration, duration, invulnerable)
	if element:
		_leave_element(user, dir.normalized())


## Where it vanishes, along the way (up to a wall), and where it appears once the dash is over.
func _leave_element(user: Actor, dir: Vector2) -> void:
	var world := user.world
	var start := user.global_position
	var query := PhysicsRayQueryParameters2D.create(start, start + dir * distance, Layers.WORLD)
	var wall := world.get_world_2d().direct_space_state.intersect_ray(query)
	var end := start + dir * distance
	if not wall.is_empty():
		end = start + dir * maxf(start.distance_to(wall.position) - user.radius - 2.0, 0.0)
	var chest := Vector2(0, -user.radius)
	Vfx.pop(world, start + chest, element, 14.0, dir)
	Vfx.trail(world, start, end, element, duration)
	# (Weak references: the timer outlives a freed user or world; see Effect.apply_all().)
	var user_ref: WeakRef = weakref(user)
	var world_ref: WeakRef = weakref(world)
	world.get_tree().create_timer(duration, false).timeout.connect(func() -> void:
		var who := user_ref.get_ref() as Actor
		var where := world_ref.get_ref() as World
		if who and where:
			Vfx.pop(where, who.global_position + chest, element, 14.0, dir))


## In the preview, the line it dashes along (the game warns of none).
func moves_caster() -> bool:
	return true


func show_preview_warning(view: TelegraphView, angle: float, progress: float) -> bool:
	view.show_shape(TelegraphView.Shape.LINE, distance, angle, progress, 0.0, 14.0)
	return true


func play_preview(preview: EffectPreview) -> void:
	var way := -1.0 if direction == Direction.AWAY else 1.0
	preview.lunge(distance * way, duration)
