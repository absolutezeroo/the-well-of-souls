class_name ScreenEffects
extends ColorRect
## Full-screen post-process over the world (see assets/shaders/screen.gdshader): the one shader
## that reads the screen, so the screen is copied once a frame. It works in the game's pixel grid
## (one art pixel = 2 world units), and it does every distortion of space at once from the
## DistortionStamps on screen (heat above fire, cold through a frost nova, shadow pulling in, a
## blast's shockwave). kick() shakes the colors apart for a moment on big impacts; flash() lights
## the whole picture for one frame (lightning).
##
## While it lives the game's viewport is transparent: effects write the emissive mask in their
## alpha (fx.gdshaderinc) and anything opaque drawn over them later puts it back to 1.

const ART_PIXEL := 2.0
const KICK_FADE := 6.0  # art pixels lost per second
## No more than this many flashes a second (photosensitive players: never more than 3).
const MAX_FLASHES_PER_SECOND := 3.0

var _aberration := 0.0
var _mood_bloom := 0.0
## When the last flash of the screen was let through (real milliseconds), whoever made it: the
## lightning here, the hurt vignette in the HUD (DamageVignette). Shared, so together they stay
## under MAX_FLASHES_PER_SECOND.
static var _last_flash_ms := -100000
var _flash_frame := -1
var _was_transparent := false
var _positions := PackedVector4Array()
var _infos := PackedVector4Array()


func _ready() -> void:
	add_to_group(&"screen_effects")
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	_was_transparent = get_viewport().transparent_bg
	get_viewport().transparent_bg = true
	_positions.resize(DistortionStamp.MAX)
	_infos.resize(DistortionStamp.MAX)
	Settings.changed.connect(_apply_settings)
	ShaderWarmup.run(self)


func _exit_tree() -> void:
	get_viewport().transparent_bg = _was_transparent


## The screen pass of this tree (null outside the game).
static func of(tree: SceneTree) -> ScreenEffects:
	return tree.get_first_node_in_group(&"screen_effects") as ScreenEffects if tree else null


## The floor's look: grading, saturation, contrast, bloom, heat haze (null: neutral).
func set_mood(def: AmbienceDef) -> void:
	var shader := material as ShaderMaterial
	var neutral := AmbienceDef.new() if def == null else def
	shader.set_shader_parameter("shadow_tint", neutral.grade_shadows)
	shader.set_shader_parameter("highlight_tint", neutral.grade_highlights)
	shader.set_shader_parameter("grade", neutral.grade_strength)
	shader.set_shader_parameter("saturation", neutral.saturation)
	shader.set_shader_parameter("contrast", neutral.contrast)
	shader.set_shader_parameter("haze", neutral.heat_haze)
	shader.set_shader_parameter("vignette_color", neutral.vignette_color)
	shader.set_shader_parameter("vignette_pulse", neutral.vignette_pulse)
	shader.set_shader_parameter("moon_color", neutral.moon_color)
	_mood_bloom = neutral.bloom
	_apply_settings()


func kick(strength: float = 1.0) -> void:
	_aberration = maxf(_aberration, 2.0 * strength)


## The whole picture lit for one frame (a bolt of lightning), at most three times a second, and
## never when the player turned flashes off.
func flash(tint: Color, strength: float = 0.5) -> bool:
	if not take_flash():
		return false
	_flash_frame = Engine.get_process_frames()
	(material as ShaderMaterial).set_shader_parameter("flash", Color(tint, strength))
	return true


## Whether a flash over a large part of the screen may go now (the Screen flashes option on,
## and not more than MAX_FLASHES_PER_SECOND, whoever flashes: lightning, the hurt vignette);
## true takes the turn. Real time: a hit stop doesn't bunch flashes.
static func take_flash() -> bool:
	if not Settings.screen_flashes:
		return false
	var now := Time.get_ticks_msec()
	if now - _last_flash_ms < roundi(1000.0 / MAX_FLASHES_PER_SECOND):
		return false
	_last_flash_ms = now
	return true


## True during the frame of a flash.
func is_flashing() -> bool:
	return _flash_frame >= 0


func _apply_settings() -> void:
	# Fewer effects: no glow (four more reads of the screen per pixel).
	(material as ShaderMaterial).set_shader_parameter("bloom", 0.0 if Settings.fewer_effects else _mood_bloom)


func _process(delta: float) -> void:
	if not Vfx.shown:
		return  # a simulation: nothing to see (Vfx.shown)
	var shader := material as ShaderMaterial
	var view := get_viewport().get_canvas_transform().affine_inverse()
	var screen_size := get_viewport_rect().size
	var origin := view * Vector2.ZERO
	var world_size := view.basis_xform(screen_size)
	shader.set_shader_parameter("view_origin", origin)
	shader.set_shader_parameter("view_size", world_size)
	shader.set_shader_parameter("art_pixel", Vector2.ONE * ART_PIXEL / world_size)
	if _aberration > 0.0:
		_aberration = maxf(_aberration - KICK_FADE * delta, 0.0)
		shader.set_shader_parameter("aberration", _aberration)
	if _flash_frame >= 0 and Engine.get_process_frames() > _flash_frame:
		_flash_frame = -1
		shader.set_shader_parameter("flash", Color(0, 0, 0, 0))
	_gather_stamps(Rect2(origin, world_size))


## The stamps on screen, shockwaves first, then the nearest to the middle, at most MAX.
func _gather_stamps(view: Rect2) -> void:
	var found: Array[DistortionStamp] = []
	for node in get_tree().get_nodes_in_group(DistortionStamp.GROUP):
		var stamp := node as DistortionStamp
		if stamp == null or not stamp.is_visible_in_tree():
			continue
		if Settings.fewer_effects and stamp.kind != DistortionStamp.Kind.SHOCK:
			continue
		if view.grow(stamp.extent()).has_point(stamp.global_position):
			found.append(stamp)
	if found.size() > DistortionStamp.MAX:
		var centre := view.get_center()
		found.sort_custom(func(a: DistortionStamp, b: DistortionStamp) -> bool:
			var a_shock := a.kind == DistortionStamp.Kind.SHOCK
			if a_shock != (b.kind == DistortionStamp.Kind.SHOCK):
				return a_shock
			return a.global_position.distance_squared_to(centre) < b.global_position.distance_squared_to(centre))
		found.resize(DistortionStamp.MAX)
	for i in found.size():
		var packed := found[i].packed()
		_positions[i] = packed[0]
		_infos[i] = packed[1]
	var shader := material as ShaderMaterial
	shader.set_shader_parameter("stamp_count", found.size())
	if not found.is_empty():
		shader.set_shader_parameter("stamps", _positions)
		shader.set_shader_parameter("stamp_info", _infos)


## Stamps the screen pass reads this frame (tests).
func stamp_count() -> int:
	return int((material as ShaderMaterial).get_shader_parameter("stamp_count"))
