class_name DeathPiecesVfx
extends Node2D
## What flies off a dying body (DeathFx), on the art's grid, in its element's ramp:
## - shards: the frozen body broken along cracks into pieces of its own art (painted in the ice
##   as the body shader froze it, each piece lit on its top left and dark on its bottom right),
##   thrown out, falling to the floor, lying a moment, then gone piece by piece (dithered);
## - motes: the element's bits rising off the body while it goes (embers off a burning front,
##   motes of light, pale wisps), going down the ramp and dithering out.

## Art pixels per shard, about (a 16x16 body breaks into a dozen).
const SHARD_AREA := 18
const GRAVITY := 520.0

class Piece:
	var region := Rect2()  # in the atlas (texels), shards only
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var floor_y := 0.0
	var born := 0.0
	var life := 1.0
	var size := 1
	var landed := false

## One immutable atlas and its pieces, shared by every death showing the same frame.
class Fragments:
	var texture: Texture2D
	var regions: Array[Rect2] = []
	var corners: Array[Vector2] = []
	var size := Vector2.ZERO

static var _fragments: Dictionary[String, Fragments] = {}
static var _warmed: Dictionary[SpriteFrames, bool] = {}
static var _content_warmed: Dictionary[ContentDB, bool] = {}

var element: VfxElementDef
var _texture: Texture2D
var _texel := 2.0
var _pieces: Array[Piece] = []
var _age := 0.0
var _life := 1.2
var _shards := false
var _look: DeathLookDef
var _height := 30.0


## The body of `rig`, frozen in `of_element`'s ramp, broken into pieces flying from its feet.
static func shards(rig: ActorRig, of_element: VfxElementDef, fewer: bool = false) -> DeathPiecesVfx:
	var vfx := DeathPiecesVfx.new()
	vfx.element = of_element
	vfx._shards = true
	vfx.position = PixelDraw.snap(rig.global_position)
	# Flying, and ice that keeps its color in a torch's warm light: over the floor's light.
	VfxLayer.apply(vfx, VfxLayer.Layer.AIR)
	vfx._texel = PixelDraw.PX * absf(rig.scale.x)
	var frame := rig.current_frame()
	if frame:
		vfx._break(frame, rig.body.offset - frame.get_size() / 2.0, fewer)
	return vfx


## `count` bits of `of_element` rising off `rig`'s body over its death (`look`'s timing).
static func motes(rig: ActorRig, of_element: VfxElementDef, look: DeathLookDef, count: int) -> DeathPiecesVfx:
	var vfx := DeathPiecesVfx.new()
	vfx.element = of_element
	vfx._look = look
	vfx.position = PixelDraw.snap(rig.global_position)
	VfxLayer.apply(vfx, VfxLayer.Layer.AIR)
	var frame := rig.current_frame()
	var size := frame.get_size() if frame else Vector2(16, 16)
	var texel := PixelDraw.PX * absf(rig.scale.x)
	vfx._height = size.y * texel
	var width := size.x * texel * 0.6
	for i in count:
		var piece := Piece.new()
		var t := (i + randf()) / count * 0.85
		piece.born = look.delay + look.duration * t
		# Off the front for a death that eats the body from the feet up (ash, light), anywhere
		# on it otherwise.
		var height := clampf(t * 1.3 - 0.1, 0.05, 0.95) if look.style in [DeathLookDef.Style.ASH, DeathLookDef.Style.ASCEND] else randf_range(0.2, 0.9)
		piece.position = Vector2(randf_range(-width, width) * 0.5, -height * vfx._height)
		piece.velocity = Vector2(randf_range(-10.0, 10.0), -randf_range(26.0, 52.0))
		piece.life = randf_range(0.45, 0.75)
		piece.size = 2 if randf() < 0.35 else 1
		vfx._pieces.append(piece)
	vfx._life = look.delay + look.duration + 0.8
	return vfx


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	for piece in _pieces:
		if _shards:
			if piece.landed:
				continue
			piece.velocity.y += GRAVITY * delta
			piece.position += piece.velocity * delta
			if piece.velocity.y > 0.0 and piece.position.y >= piece.floor_y:
				piece.position.y = piece.floor_y
				if piece.velocity.y > 140.0:
					piece.velocity = Vector2(piece.velocity.x * 0.4, -piece.velocity.y * 0.3)  # one small bounce
				else:
					piece.landed = true
		elif _age >= piece.born:
			piece.velocity.x += sin(_age * 9.0 + piece.born * 40.0) * 30.0 * delta
			piece.position += piece.velocity * delta
	queue_redraw()


func _draw() -> void:
	for piece in _pieces:
		var t := (_age - piece.born) / piece.life
		if t < 0.0 or t >= 1.0:
			continue
		var at := PixelDraw.snap(piece.position)
		if _shards:
			# Whole pieces lie a while, then go one by one (each its own dither threshold).
			if not PixelDraw.dither(PixelDraw.cell_of(at), 1.0 - maxf(t - 0.55, 0.0) / 0.45):
				continue
			draw_texture_rect_region(_texture, Rect2(at, piece.region.size * _texel), piece.region)
		else:
			if not PixelDraw.dither(PixelDraw.cell_of(at), 1.0 - maxf(t - 0.6, 0.0) / 0.4):
				continue
			var color := element.shade(0.1 + t * 0.8) if not element.id == &"shadow" else element.shade(1.0 - t * 0.7)
			PixelDraw.bit(self, element.bit, at, piece.size if t < 0.5 else 1, color, piece.velocity, element.core() if t < 0.2 else Color.TRANSPARENT)


## Breaks `frame` (drawn with its top left at `corner`, in art pixels from the feet) into
## pieces: a few seeds, each art pixel to the nearest, packed side by side in one texture.
func _break(frame: Texture2D, corner: Vector2, fewer: bool) -> void:
	var key := _key(frame, element, fewer)
	var fragments: Fragments = _fragments.get(key)
	if fragments == null:
		# Custom art/elements can use the CPU copy too; no GPU readback during play.
		fragments = _bake(frame, element, fewer)
		_fragments[key] = fragments
	_texture = fragments.texture
	var center := fragments.size * Vector2(0.5, 0.55)
	for i in fragments.regions.size():
		var piece := Piece.new()
		piece.region = fragments.regions[i]
		piece.position = (corner + fragments.corners[i]) * _texel
		var out := fragments.corners[i] + piece.region.size * 0.5 - center
		var direction := out.normalized() if out.length() > 0.5 else Vector2.from_angle(randf() * TAU)
		piece.velocity = direction * randf_range(50.0, 120.0) + Vector2(0, -randf_range(60.0, 140.0))
		piece.floor_y = randf_range(-6.0, 6.0) - piece.region.size.y * _texel * 0.5
		piece.life = randf_range(0.8, 1.1)
		_pieces.append(piece)
	_life = 1.2


## The floor loads every kind that may appear later, including summons and boss forms.
static func warm_content(content: ContentDB) -> void:
	if not Vfx.shown or _content_warmed.has(content):
		return
	_content_warmed[content] = true
	var kinds := content.all_monsters()
	kinds.append_array(content.abyss_monsters())
	for act in content.dungeon.acts:
		kinds.append(act.boss)
		kinds.append_array(act.other_bosses)
	if content.dungeon.finale:
		kinds.append(content.dungeon.finale.boss)
	for kind in kinds:
		var seen: Array[MonsterDef] = []
		while kind and not seen.has(kind):
			seen.append(kind)
			warm(kind.frames)
			kind = (kind as BossDef).next_boss if kind is BossDef else null
	warm(content.player.frames)


## Death poses are baked once, in both effect densities, with private cosmetic dice.
## Without a death animation the current pose falls over, so every pose can shatter.
static func warm(frames: SpriteFrames) -> void:
	if frames == null or not Vfx.shown or _warmed.has(frames):
		return
	_warmed[frames] = true
	var has_death := false
	for animation in frames.get_animation_names():
		if String(animation).begins_with("dead"):
			has_death = true
	var frost := VfxElementDef.named(&"frost")
	for animation in frames.get_animation_names():
		if has_death and not String(animation).begins_with("dead"):
			continue
		for i in frames.get_frame_count(animation):
			var frame := frames.get_frame_texture(animation, i)
			if frame == null:
				continue
			BodyTops.top_of(frame)
			for fewer: bool in [false, true]:
				var key := _key(frame, frost, fewer)
				if not _fragments.has(key):
					_fragments[key] = _bake(frame, frost, fewer)


static func _key(frame: Texture2D, made_of: VfxElementDef, fewer: bool) -> String:
	return "%d/%d/%s" % [frame.get_instance_id(), made_of.get_instance_id(), fewer]


static func _bake(frame: Texture2D, made_of: VfxElementDef, fewer: bool) -> Fragments:
	var result := Fragments.new()
	var image := BodyTops.cached_frame_image(frame)
	if image == null or image.is_empty():
		return result
	var size := image.get_size()
	var opaque := 0
	for y in size.y:
		for x in size.x:
			if image.get_pixel(x, y).a >= 0.5:
				opaque += 1
	if opaque == 0:
		return result
	var seeds: Array[Vector2] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%s/%s" % [frame.resource_path, size, fewer])
	for i in clampi(int(opaque / float(SHARD_AREA * (2 if fewer else 1))), 3, 24):
		seeds.append(Vector2(rng.randf() * size.x, rng.randf() * size.y))
	# Which piece each art pixel falls in (stretched a little: ice breaks in slabs).
	var owners := PackedInt32Array()
	owners.resize(size.x * size.y)
	var boxes: Array[Rect2i] = []
	boxes.resize(seeds.size())
	var used := PackedByteArray()
	used.resize(seeds.size())
	for y in size.y:
		for x in size.x:
			var i := y * size.x + x
			owners[i] = -1
			if image.get_pixel(x, y).a < 0.5:
				continue
			var best := 0
			var best_d := INF
			for s in seeds.size():
				var d := (Vector2(x + 0.5, y + 0.5) - seeds[s]) * Vector2(1.0, 1.4)
				if d.length_squared() < best_d:
					best_d = d.length_squared()
					best = s
			owners[i] = best
			var cell := Rect2i(x, y, 1, 1)
			boxes[best] = cell if used[best] == 0 else boxes[best].merge(cell)
			used[best] = 1
	# One texture: each piece in its own slot, side by side, a column of space between.
	var width := 0
	for s in seeds.size():
		if used[s]:
			width += boxes[s].size.x + 1
	var atlas := Image.create(maxi(width, 1), size.y, false, Image.FORMAT_RGBA8)
	var x0 := 0
	result.size = Vector2(size)
	for s in seeds.size():
		if not used[s]:
			continue
		var box := boxes[s]
		for y in range(box.position.y, box.end.y):
			for x in range(box.position.x, box.end.x):
				if owners[y * size.x + x] != s:
					continue
				atlas.set_pixel(x0 + x - box.position.x, y, _ice(image, owners, size, x, y, s, made_of))
		result.regions.append(Rect2(x0, box.position.y, box.size.x, box.size.y))
		result.corners.append(Vector2(box.position))
		x0 += box.size.x + 1
	result.texture = ImageTexture.create_from_image(atlas)
	return result


## The ice color of art pixel (x, y) of piece `s`: the frozen body's step for its brightness
## (as flash.gdshader's freeze), lit on the piece's top left edge, dark on its bottom right.
static func _ice(image: Image, owners: PackedInt32Array, size: Vector2i, x: int, y: int, s: int, made_of: VfxElementDef) -> Color:
	var source := image.get_pixel(x, y)
	var luma := source.r * 0.299 + source.g * 0.587 + source.b * 0.114
	var step := 0 if luma > 0.72 else (1 if luma > 0.5 else (2 if luma > 0.32 else (3 if luma > 0.17 else 4)))
	step = clampi(step - 1, 0, 3)
	if not _inside(owners, size, x, y - 1, s) or not _inside(owners, size, x - 1, y, s):
		step = 0
	elif not _inside(owners, size, x, y + 1, s) or not _inside(owners, size, x + 1, y, s):
		step = 4
	return made_of.shade(step / 4.0)


static func _inside(owners: PackedInt32Array, size: Vector2i, x: int, y: int, piece: int) -> bool:
	return x >= 0 and y >= 0 and x < size.x and y < size.y and owners[y * size.x + x] == piece
