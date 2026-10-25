class_name ActorShadow
extends Node2D
## The shadow under a body (Actor), on a node of its own one step down in the draw order
## (z_index -1, with the floor's markings): every shadow of a crowd is then drawn in one run, one
## batch, instead of a shadow between every two sprites breaking the sprites' batches (a crowd of
## the same monster drew one call per body: docs/performance.md, "Draw calls"). Drawn in its
## own space (it moves with the body): redrawn only when its size changes.

var _feet_y := 0.0
var _radius := 0.0


func _init() -> void:
	name = "Shadow"
	z_index = -1


## Its place and size (the body's feet and radius): redrawn only if they changed.
func fit(feet_y: float, radius: float) -> void:
	if is_equal_approx(feet_y, _feet_y) and is_equal_approx(radius, _radius):
		return
	_feet_y = feet_y
	_radius = radius
	queue_redraw()


func _draw() -> void:
	if _radius > 0.0:
		BodySketch.shadow(self, _feet_y, _radius)
