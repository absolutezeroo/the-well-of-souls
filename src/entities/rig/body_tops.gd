class_name BodyTops
extends RefCounted
## The top row of the art on each body frame, so what rides the body (the hero's weapon at
## rest: GearLook) bobs with it as it breathes and walks. Measured on a copy of each sheet read
## back from the GPU once while the floor loads (warm()), never mid-fight (a hitch on a phone:
## docs/performance.md, "No GPU readback during play").

## A body frame -> the top row of its art.
static var _tops: Dictionary[Texture2D, int] = {}
## A sheet's pixels, read back from the GPU once (the first frame of it measured): every frame
## cut from it is measured on this copy (_measure()), never by reading the texture back again.
static var _sheets: Dictionary[Texture2D, Image] = {}


## How far the body's art is lowered on the frame `body` shows from its animation's first (art
## pixels): 0 without frames.
static func bob(body: AnimatedSprite2D) -> float:
	var frames := body.sprite_frames
	if frames == null or not frames.has_animation(body.animation) or frames.get_frame_count(body.animation) == 0:
		return 0.0
	return float(top_of(frames.get_frame_texture(body.animation, body.frame)) - top_of(frames.get_frame_texture(body.animation, 0)))


## The top row of the art on `texture` (0 for none).
static func top_of(texture: Texture2D) -> int:
	if texture == null:
		return 0
	if not _tops.has(texture):
		_tops[texture] = _measure(texture)
	return _tops[texture]


## Every frame of `frames` measured now (when a rig gets its body, while the floor loads).
static func warm(frames: SpriteFrames) -> void:
	if frames == null or not Vfx.shown:
		return
	for animation in frames.get_animation_names():
		for i in frames.get_frame_count(animation):
			top_of(frames.get_frame_texture(animation, i))


## The top row of the art on `texture` (AtlasTexture.get_image(): its sheet's pixels in its
## region), measured on its sheet's copy (_sheets).
static func _measure(texture: Texture2D) -> int:
	var atlas := texture as AtlasTexture
	var source: Texture2D = atlas.atlas if atlas and atlas.atlas else texture
	var image: Image = _sheets.get(source)
	if image == null:
		image = source.get_image()
		if image == null:
			return 0
		if image.is_compressed():
			image.decompress()
		_sheets[source] = image
	if atlas == null or source == texture:
		return image.get_used_rect().position.y
	var region := Rect2i(atlas.region).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if region.has_area():
		return image.get_region(region).get_used_rect().position.y
	return 0


## A frame's pixels from the sheet already warmed at loading. Never reads the GPU.
## The caller may read this image, but must not modify the shared sheet.
static func cached_frame_image(texture: Texture2D) -> Image:
	var atlas := texture as AtlasTexture
	var source: Texture2D = atlas.atlas if atlas and atlas.atlas else texture
	var image: Image = _sheets.get(source)
	if image == null:
		return null
	if atlas == null or source == texture:
		return image
	var region := Rect2i(atlas.region).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	return image.get_region(region) if region.has_area() else null
