class_name BodyLook
extends RefCounted
## What the body shader (assets/shaders/flash.gdshader, on the rig's Visual node) paints on a
## body, in the elements' ramps: statuses (a burn's heat crawling up the rim, rime creeping in,
## a poison wave on each tick, a haunt's pale flicker, a storm hit's crackle), an elite's rim,
## and the death in the killing element (DeathFx). The rig owns one per body (its material is
## its own); it only sets a uniform when its value changes. A body with no layers following it
## (a monster) wears, while nothing moves on it (no status, flash, crackle nor death), a material
## shared by every body showing the same (`_pool`: its frame, its rim): a crowd's sprites then
## batch into a few draw calls instead of one each, since the renderer can't batch two different
## materials (docs/performance.md, "Draw calls"); it is back on its own the moment something does. StatusFx's particles are the accent;
## this is the base. With Settings.fewer_effects the statuses and the rim are off (the body takes
## the old flat tint instead, Actor._body_modulate) and only the deaths stay (one pass, no
## neighbour reads but the frozen edge). docs/vfx.md, "Shaders on bodies".

const LOOKS: StatusLookSet = preload("res://data/vfx/status_looks.tres")
const SHADER: Shader = preload("res://assets/shaders/flash.gdshader")
## Seconds a burn takes to catch the whole lower rim (in three steps).
const CATCH_TIME := 0.24
## Seconds the rime takes to creep in to its full depth.
const RIME_TIME := 1.2
## Seconds a poison tick's wave takes to rise up the body.
const WAVE_TIME := 0.5
## A storm hit's crackle, frame by frame at 60 fps: two frames on, two off, a second strike,
## a gap, the afterglow (docs/vfx.md: storm flickers, 1-3 frames on).
const CRACKLE := [true, true, false, false, true, false, false, false, true, true]
## Ramp steps per element in the ramp texture (core to edge).
const STEPS := 5

## Every element's ramp, a row each (shared by every body's material).
static var _ramps: ImageTexture
static var _image: Image
static var _rows := {}  # VfxElementDef -> row
static var _looks := {}  # status id -> StatusLookDef (or null)

## The body's own material: every uniform is set here (worn while something moves on the body).
var material: ShaderMaterial
## Other layers' materials that follow this one (the hero's armor layers and weapon have their
## own, for their trim: ActorRig): every uniform set here is set there too, but the frame for
## the ones that show frames of their own (the weapon).
var _followers: Array[ShaderMaterial] = []
var _own_frames: Array[bool] = []
## The elite rim's color (transparent: none).
var outline := Color.TRANSPARENT
## The rim's second ring dithered on the beat (a rank's); off: one art pixel only (a warning).
var outline_beat := true
## Armor layers are on: the rim and the crackle stay on the sprite's own pixels.
var layered := false
var _set := {}
var _ages := {}  # status id -> seconds it has been on
var _age_ids: Array[StringName] = []
var _crackle := -1  # frame of the current crackle, -1: none
var _crackle_row := 0
var _dying := false
## Nothing is on the body and the shader knows it (for this rim and these layers): nothing to do
## until a status, a hit or a change comes.
var _quiet := false
## What the shader was last told of the rim and the layers (no array built every frame to compare):
## `_told` false until it was told once.
var _told := false
var _told_enabled := false
var _told_outline := Color.TRANSPARENT
var _told_layered := false
var _told_beat := true
## A body at rest: these uniforms at these values (nothing moves on it), the others either fixed
## by the frame and the rim (the pool's key) or unread at these values (the rows, the flash's color).
const AT_REST := {
	&"burn": 0.0, &"chill": 0.0, &"frozen": 0.0, &"poison": 0.0, &"poison_wave": 2.0, &"haunt": 0.0,
	&"crackle": 0.0, &"flash_amount": 0.0, &"dissolve": 0.0, &"death_style": 0,
}
## The uniforms that tell bodies at rest apart (the pool's key).
const KEYED: Array[StringName] = [&"frame_rect", &"outline_color", &"outline_beat", &"outer_rim", &"hue_shift", &"shimmer"]

## The shared materials of bodies at rest, by what they show (KEYED's values as text).
static var _pool := {}
## The node wearing the material (the rig's Visual) when this body may share; null: never shares.
var _wearer: CanvasItem
var _sharing := false


func _init(look: ShaderMaterial) -> void:
	material = look
	material.set_shader_parameter("ramps", ramps())


## The ramp texture: one row per element (VfxElementDef.all(), then any other met), STEPS
## columns from core to edge, each an exact ramp color (`shade`, never a blend).
static func ramps() -> ImageTexture:
	if _ramps == null:
		var all := VfxElementDef.all()
		_image = Image.create(STEPS, maxi(all.size(), 1) + 8, false, Image.FORMAT_RGBA8)
		for element in all:
			_paint_row(element)
		_ramps = ImageTexture.create_from_image(_image)
	return _ramps


## The row of `element` in the ramp texture (added on first use: content made from a color).
static func row(element: VfxElementDef) -> int:
	ramps()
	if element == null:
		return 0
	if not _rows.has(element):
		if _rows.size() >= _image.get_height():
			return 0
		_paint_row(element)
		_ramps.update(_image)
	return _rows[element]


static func _paint_row(element: VfxElementDef) -> void:
	var y := _rows.size()
	_rows[element] = y
	for x in STEPS:
		# Rounded to 8 bits here (set_pixel truncates: 239.99 would become 239, off the ramp).
		var color := element.shade(float(x) / (STEPS - 1))
		_image.set_pixel(x, y, Color8(roundi(color.r * 255.0), roundi(color.g * 255.0), roundi(color.b * 255.0)))


## Draws the body shader once with its busy path on (statuses, a death), under the floor where
## nobody sees it, while a floor is being set up: the Compatibility renderer compiles a shader
## the first time it draws it, and that is a hitch nobody should feel at the first burning
## monster. Every body's material shares this one shader (one program, uniforms only).
static func warm_up(parent: Node2D) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = ramps()
	var look_material := ShaderMaterial.new()
	look_material.shader = SHADER
	look_material.set_shader_parameter(&"ramps", ramps())
	for name: StringName in [&"burn", &"chill", &"poison", &"dissolve"]:
		look_material.set_shader_parameter(name, 0.5)
	sprite.material = look_material
	sprite.z_as_relative = false
	sprite.z_index = RenderingServer.CANVAS_ITEM_Z_MIN
	parent.add_child(sprite)
	# In view (a culled item is never drawn, never compiled), then gone.
	var place := func() -> void:
		var camera := sprite.get_viewport().get_camera_2d() if sprite.is_inside_tree() else null
		if camera:
			sprite.global_position = camera.get_screen_center_position()
	place.call_deferred()
	parent.get_tree().create_timer(0.2, true, false, true).timeout.connect(sprite.queue_free)


## Every physics frame: the body's statuses as the shader draws them (all off when `enabled` is
## false: fewer effects, a body without frames).
func show_statuses(statuses: StatusSet, delta: float, enabled: bool) -> void:
	if _dying:
		return
	var calm := (not enabled or statuses.is_empty()) and _crackle < 0
	var same := _told and enabled == _told_enabled and outline == _told_outline and layered == _told_layered \
		and outline_beat == _told_beat
	if calm and _quiet and same:
		return
	var burn := 0.0
	var chill := 0.0
	var frozen := 0.0
	var poison := 0.0
	var wave := 2.0
	var haunt := 0.0
	var active := statuses.active_ids()
	var i := _age_ids.size() - 1
	while i >= 0:
		if not enabled or not active.has(_age_ids[i]):
			_ages.erase(_age_ids[i])
			_age_ids.remove_at(i)
		i -= 1
	if enabled and not statuses.is_empty():
		for id in active:
			if not _looks.has(id):
				_looks[id] = LOOKS.look(id)
			var look: StatusLookDef = _looks[id]
			if look == null or look.body == StatusLookDef.Body.NONE or look.element == null:
				continue
			var age: float = _ages.get(id, 0.0) + delta
			if not _ages.has(id):
				_age_ids.append(id)
			_ages[id] = age
			var on_row := row(look.element)
			match look.body:
				StatusLookDef.Body.HEAT:
					burn = ceilf(clampf(age / CATCH_TIME, 0.01, 1.0) * 3.0) / 3.0
					_param(&"burn_row", on_row)
				StatusLookDef.Body.RIME:
					chill = clampf(floorf(age / RIME_TIME * 4.0) / 4.0, 0.05, 1.0)
					frozen = 1.0 if statuses.slow_of(id) >= look.heavy_at else 0.0
					_param(&"chill_row", on_row)
				StatusLookDef.Body.WAVE:
					poison = 1.0
					var since := statuses.since_tick(id)
					wave = since / WAVE_TIME if since >= 0.0 and since < WAVE_TIME else 2.0
					_param(&"poison_row", on_row)
				StatusLookDef.Body.FLICKER:
					haunt = 1.0
					_param(&"haunt_row", on_row)
	var crackling := false
	if _crackle >= 0:
		crackling = enabled and CRACKLE[_crackle]
		_crackle += 1
		if _crackle >= CRACKLE.size():
			_crackle = -1
	# _param compares the scalar with its last value, with no comparison array.
	_param(&"burn", burn)
	_param(&"chill", chill)
	_param(&"frozen", frozen)
	_param(&"poison", poison)
	_param(&"poison_wave", wave)
	_param(&"haunt", haunt)
	_param(&"crackle", 1.0 if crackling else 0.0)
	_param(&"crackle_row", _crackle_row)
	if not same:
		_param(&"outline_color", outline if enabled else Color.TRANSPARENT)
		_param(&"outline_beat", outline_beat)
		_param(&"outer_rim", not layered)
	_quiet = calm
	_told = true
	_told_enabled = enabled
	_told_outline = outline
	_told_layered = layered
	_told_beat = outline_beat


## The body's frame now shown (its quad in the sprite's local space, art pixels).
func set_frame(rect: Rect2) -> void:
	_param(&"frame_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))


## A hit of `element` landed: storm crackles over the body a few frames.
func hit(element: VfxElementDef) -> void:
	if element and element.crackles and not _dying:
		_crackle = 0
		_crackle_row = row(element)


## The body starts dying as `look` in `element`'s ramp: statuses and rim off, the death's style.
func die(look: DeathLookDef, element: VfxElementDef) -> void:
	_dying = true
	for name: StringName in [&"burn", &"chill", &"frozen", &"poison", &"haunt", &"crackle"]:
		_param(name, 0.0)
	_param(&"outline_color", Color.TRANSPARENT)
	_param(&"death_style", int(look.style))
	_param(&"death_row", row(element))
	if _wearer:
		_wear()


## How far the death has gone (0..1).
func set_dying(progress: float) -> void:
	_param(&"dissolve", progress)


## `other` (a layer's own material, the same shader) wears what this body wears from now on:
## flash, statuses, deaths; its own frame when `own_frame` (a weapon's frames aren't the body's).
func follow(other: ShaderMaterial, own_frame: bool = false) -> void:
	if other == null or _followers.has(other):
		return
	if _wearer:
		_wearer.material = material  # (layers follow: its own from now on)
		_wearer = null
		_sharing = false
	other.set_shader_parameter(&"ramps", ramps())
	for name: StringName in _set:
		if not (own_frame and name == &"frame_rect"):
			other.set_shader_parameter(name, _set[name])
	_followers.append(other)
	_own_frames.append(own_frame)


## Sets a uniform on the body and the layers that follow it (the rig's hit flash).
func set_shared(name: StringName, value: Variant) -> void:
	_param(name, value)


func _param(name: StringName, value: Variant) -> void:
	if _set.get(name) != value:
		_set[name] = value
		material.set_shader_parameter(name, value)
		for i in _followers.size():
			if not (_own_frames[i] and name == &"frame_rect"):
				_followers[i].set_shader_parameter(name, value)
		if _wearer:
			_wear()


## This body may wear a shared material while at rest, on `wearer` (the rig's Visual): a body
## with no layers following it.
func share_on(wearer: CanvasItem) -> void:
	_wearer = wearer if _followers.is_empty() else null
	if _wearer:
		_wear()


## Whether this body wears a shared material now (the tests).
func is_sharing() -> bool:
	return _sharing


## At rest: the pool's material for what it shows; else its own.
func _wear() -> void:
	var rest := not _dying and _followers.is_empty()
	if rest:
		for name: StringName in AT_REST:
			if _set.has(name) and _set[name] != AT_REST[name]:
				rest = false
				break
	if rest:
		var key := "%s|%s|%s|%s|%s|%s" % [_set.get(&"frame_rect"), _set.get(&"outline_color"), _set.get(&"outline_beat"), _set.get(&"outer_rim"), _set.get(&"hue_shift"), _set.get(&"shimmer")]
		var shared: ShaderMaterial = _pool.get(key)
		if shared == null:
			shared = ShaderMaterial.new()
			shared.shader = material.shader
			shared.set_shader_parameter(&"ramps", ramps())
			for name: StringName in AT_REST:
				shared.set_shader_parameter(name, AT_REST[name])
			for name: StringName in KEYED:
				if _set.has(name):
					shared.set_shader_parameter(name, _set[name])
			_pool[key] = shared
		if _wearer.material != shared:
			_wearer.material = shared
		_sharing = true
	else:
		if _wearer.material != material:
			_wearer.material = material
		_sharing = false
