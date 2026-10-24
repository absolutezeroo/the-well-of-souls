class_name PlateauMist
extends Node2D
## Volumetric mist over the plateau above the walls (and all around the map), lit by the floor's
## light: lamps by a wall glow in it, the hero's torch too; away from them it stays dark, with
## lighter wisps on top. Thin at the rim (the cliff's edge stays readable), thick further in, and
## a volume: seen from the south like the rest of the art, it rises up the screen, hides a little
## of the room behind a wall, and its layers lean with the camera.
##
## Each frame, the shader (plateau_mist.gdshader) raymarches it into a small viewport over the
## view, one pixel per art pixel (cheap: about 500x240 pixels), laid over the world above the
## light. Its inputs: the mask (mask_image(), one pixel per cell, soft edges) and the LightField's
## texture. Colors and thickness: DungeonTheme > Mist. Fewer effects (Options): half the slices.

const SHADER := preload("res://src/dungeon/plateau_mist.gdshader")
## How thick the mist is 1, 2 and 3+ cells away from the floor or a cliff face.
const THICKNESS: Array[float] = [0.0, 0.25, 0.65, 1.0]
## World pixels per mist pixel (the art is drawn at 2x).
const PIXEL := 2.0
## Over the light (LightField.Z) and whoever walks, under sparks and big effects.
const Z := 4
## Slices of the ray through the mist (and with Fewer effects).
const SLICES := 6
const FEW_SLICES := 3
## The mist's height, in world pixels (how far up the screen it rises over a wall).
const HEIGHT := 28.0

## The light it shows (set by the World once the floor is lit).
var light_field: LightField
## The thickness per cell (for tests and tools).
var mask: Image

var _viewport := SubViewport.new()
var _canvas := ColorRect.new()
var _material := ShaderMaterial.new()
var _view := Rect2()


func _init() -> void:
	z_as_relative = false
	z_index = Z
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_material.shader = SHADER
	_canvas.material = _material
	_viewport.disable_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.size = Vector2i(8, 8)
	_viewport.add_child(_canvas)
	add_child(_viewport)
	_material.set_shader_parameter("pixel", PIXEL)
	_material.set_shader_parameter("height", HEIGHT)


## `margin`: cells of plateau drawn around the map (DungeonView.OUTSIDE_MARGIN).
func setup(map: DungeonMap, theme: DungeonTheme, margin: int) -> void:
	visible = theme != null and theme.mist_density > 0.0
	if not visible:
		return
	_material.set_shader_parameter("deep_color", theme.mist_deep)
	_material.set_shader_parameter("wisp_color", theme.mist_wisp)
	_material.set_shader_parameter("density", theme.mist_density)
	mask = mask_image(map, margin)
	_material.set_shader_parameter("mask", ImageTexture.create_from_image(mask))
	_material.set_shader_parameter("mask_origin", Vector2.ONE * -margin * map.tile_size)
	_material.set_shader_parameter("mask_size", Vector2(mask.get_size()) * map.tile_size)


## The floor's light, once it is set up for this floor.
func bind_light(field: LightField) -> void:
	light_field = field
	_material.set_shader_parameter("light", field.light_texture())
	_material.set_shader_parameter("light_origin", field.global_position)
	_material.set_shader_parameter("light_size", field.light_area().size)
	_material.set_shader_parameter("outside_light", field.colors[field.ambient_level] if not field.colors.is_empty() else Color(0.3, 0.3, 0.35))


func _process(_delta: float) -> void:
	if not visible or not is_inside_tree():
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var half := get_viewport().get_visible_rect().size / camera.zoom * 0.5
	var centre := camera.get_screen_center_position()
	# Snapped to the mist's pixels (no shimmer as the camera moves), a pixel of margin all round.
	var origin := ((centre - half) / PIXEL).floor() * PIXEL - Vector2.ONE * PIXEL
	var size := Vector2i(((half * 2.0) / PIXEL).ceil()) + Vector2i(3, 3)
	if _viewport.size != size:
		_viewport.size = size
		_canvas.size = Vector2(size)
	_material.set_shader_parameter("view_origin", origin)
	_material.set_shader_parameter("view_pixels", Vector2(size))
	_material.set_shader_parameter("camera", centre)
	_material.set_shader_parameter("slices", FEW_SLICES if Settings.fewer_effects else SLICES)
	var view := Rect2(origin, Vector2(size) * PIXEL)
	if view != _view:
		_view = view
		queue_redraw()


func _draw() -> void:
	if _view.has_area():
		draw_texture_rect(_viewport.get_texture(), Rect2(to_local(_view.position), _view.size), false)


## The mist's thickness per cell (red): 0 on the floor and the cliff faces (both their cells), more with each cell
## away from them, full outside the map.
static func mask_image(map: DungeonMap, margin: int) -> Image:
	var w := map.width
	var h := map.height
	var depth := PackedInt32Array()
	depth.resize(w * h)
	depth.fill(THICKNESS.size() - 1)
	var queue := PackedInt32Array()
	for y in h:
		for x in w:
			var i := y * w + x
			# The floor and both cells of the cliff face (its foot, its top: DungeonView).
			var low := map.tiles[i] == DungeonMap.Tile.FLOOR or (y + 1 < h and map.tiles[i + w] == DungeonMap.Tile.FLOOR) \
				or (y + 2 < h and map.tiles[i + w * 2] == DungeonMap.Tile.FLOOR)
			if low:
				depth[i] = 0
				queue.append(i)
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var next_depth := depth[i] + 1
		if next_depth >= THICKNESS.size() - 1:
			continue
		var x := i % w
		var y := int(i / float(w))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nx := x + dx
				var ny := y + dy
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var n := ny * w + nx
				if depth[n] > next_depth:
					depth[n] = next_depth
					queue.append(n)
	var image := Image.create_empty(w + margin * 2, h + margin * 2, false, Image.FORMAT_L8)
	image.fill(Color(1, 1, 1))
	for y in h:
		for x in w:
			var thickness: float = THICKNESS[depth[y * w + x]]
			image.set_pixel(x + margin, y + margin, Color(thickness, thickness, thickness))
	return image
