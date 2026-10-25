class_name ItemPickup
extends Area2D
## An item lying on the floor. Walking over it picks it up, if auto loot wants it
## (Settings.auto_loot, PlayerPack.wants()); else, or when the bag has no room, it stays and the HUD
## shows it with a Take button while the hero stands on it (Events.loot_offered, LootPrompt).
## Its rarity shows on the floor (LootShine; a rim and a glint on the icon), a rune its element.

## Picked up by the hero (the World keeps it for the floor's save: FloorLedger).
signal taken(pickup: ItemPickup)

const PICKUP_RADIUS := 14.0

var item: ItemDef
## Dropped items wait until the player walks away before they can be picked up again.
var _armed := true
var _taken := false
## Shown on the HUD (walked over, left on the ground).
var _offered := false
var _time := 0.0
var _glint_seed := 0.0
## What it shows, worked out once (setup()): the rim's color, the glint's rest and element.
var _shine := Color.TRANSPARENT
var _glint_period := 0.0
var _glint_element: VfxElementDef
## What the last _draw() showed (the bob's pixel, the glow's beat, the glint's front): drawn again
## only when one changed (docs/performance.md, "Redraw on change"; a floor of loot redrew every
## piece every frame).
var _drawn_key := -1


func setup(item_def: ItemDef, armed: bool = true) -> void:
	item = item_def
	_armed = armed
	_time = randf() * TAU
	collision_layer = Layers.PICKUPS
	collision_mask = Layers.PLAYER
	add_to_group("pickups")
	var shape := CircleShape2D.new()
	shape.radius = PICKUP_RADIUS
	($CollisionShape2D as CollisionShape2D).shape = shape
	# Its rarity on the floor: a pulse, an aura, a pillar of light (LootShine).
	_glint_seed = randf() * 4.0
	if ItemRarity.of(item) > ItemRarity.COMMON:
		LootShine.dress(self, ItemLook.rarity_look(item), Vector2(0, -4))
	_shine = _shine_color()
	var look := ItemLook.rarity_look(item)
	_glint_period = look.glint_every if look else 0.0
	_glint_element = look.element if look else null
	if item is RuneDef:
		_glint_period = 2.0
		_glint_element = ItemLook.rune_element(item as RuneDef)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	_time += delta
	if not Vfx.on_screen(self, 24.0):
		_drawn_key = -1  # (off screen, nothing to draw: drawn again as it comes back)
		return
	var key := _draw_key()
	if key != _drawn_key:
		_drawn_key = key
		queue_redraw()


## What _draw() would show now, as one number: the bob's pixel row, the glow's beat, the glint's
## front (64 when resting).
func _draw_key() -> int:
	var bob := roundi(PixelDraw.snap(Vector2(0, sin(_time * 3.0) * 2.0 - 4.0)).y) + 16  # (as _draw() places it)
	var glow := 1 if sin(_time * 4.0) > 0.0 else 0
	return (bob * 2 + glow) * 128 + _glint_front() + 3


## The glint's front this frame (64: resting, nothing drawn).
func _glint_front() -> int:
	if _glint_period <= 0.0 or _glint_element == null or item == null or item.icon == null:
		return 64
	var sweep := 36.0 / 30.0
	var front := floori(fmod(_time + _glint_seed, sweep + _glint_period) * 30.0) - 3
	return front if front <= 33 else 64


func _on_body_entered(body: Node2D) -> void:
	if _taken or not _armed or not body is Player:
		return
	var player := body as Player
	if player.is_dead:
		return
	if player.pack.wants(item, Settings.auto_loot) and take(player):
		return
	_offered = true
	Events.loot_offered.emit(self)


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_armed = true
		_left()


## Picks it up (walked over, or the Take button). False if the hero has no room for it.
func take(player: Player) -> bool:
	if _taken or player == null or player.is_dead or not player.pack.pick_up(item):
		return false
	_taken = true
	_left()
	taken.emit(self)
	queue_free()
	return true


func is_taken() -> bool:
	return _taken


func _left() -> void:
	if _offered:
		_offered = false
		Events.loot_left.emit(self)


func _exit_tree() -> void:
	_left()


func _draw() -> void:
	if item == null:
		return
	var bob := PixelDraw.snap(Vector2(0, sin(_time * 3.0) * 2.0 - 4.0))
	PixelDraw.disc(self, Vector2(0, 8), 9.0, Color(0, 0, 0, 0.3), 1.0, 0.4)
	var rarity := ItemRarity.of(item)
	if rarity == ItemRarity.COMMON and not item is EquipmentDef and not item is RuneDef:
		# Potions, tomes, keys: a soft stepped glow in their own color, as before.
		var glow := item.color
		glow.a = 0.22 if sin(_time * 4.0) > 0.0 else 0.14
		PixelDraw.disc(self, bob, 14.0, glow)
	if item.icon == null:
		Fonts.draw(self, bob + Vector2(0, 4), item.glyph, Fonts.BODY, item.color, 0.5, Color.TRANSPARENT)
		return
	# Small item sprites at 2x like the rest of the art; bigger UI-style icons at 1x.
	var icon_scale := Actor.SPRITE_SCALE if maxf(item.icon.get_width(), item.icon.get_height()) <= 18.0 else 1.0
	var size := item.icon.get_size() * icon_scale
	var corner := PixelDraw.snap(bob - size * 0.5)
	if _shine.a > 0.0:
		# The rarity's (or a rune's element's) rim: one art pixel round the icon's silhouette
		# (plain rects: they batch with the shadow's; a texture there drew more calls).
		for p in rim_of(item.icon):
			draw_rect(Rect2(corner + p * icon_scale, Vector2.ONE * icon_scale), _shine)
	draw_texture_rect(item.icon, Rect2(corner, size), false, item.icon_tint)
	_draw_glint(corner, icon_scale)


## The rim round the icon: its rarity's color (Magic and better), a rune's element; none for
## plain things.
func _shine_color() -> Color:
	if item is RuneDef:
		var element := ItemLook.rune_element(item as RuneDef)
		return element.color() if element else item.rarity_color()
	var look := ItemLook.rarity_look(item)
	if look == null or ItemRarity.of(item) == ItemRarity.COMMON:
		return Color.TRANSPARENT
	return look.element.color()


## A glint running over the icon, then `glint_every` seconds of rest: a band two pixels wide, on the
## diagonal, in the rarity's core (a rune's element), over the icon's own pixels only.
func _draw_glint(corner: Vector2, icon_scale: float) -> void:
	# The sweep crosses a 16-pixel icon in about a second (30 steps a second), then waits its rest.
	var front := _glint_front()
	if front > 33:
		return
	var element := _glint_element
	for p in WeaponAura.pixels_of(item.icon):
		var d := int(p.x) + int(p.y)
		if d == front or d == front - 1:
			draw_rect(Rect2(corner + p * icon_scale, Vector2.ONE * icon_scale), element.shade(0.0 if d == front else 0.25))


static var _rims := {}  # Texture2D -> the transparent pixels touching its silhouette


## The transparent pixels of `texture` touching its silhouette (4-neighbours): where a rim one art
## pixel wide goes (loot's rarity, a rune's element, a fragment's glow: Fragment).
static func rim_of(texture: Texture2D) -> PackedVector2Array:
	if _rims.has(texture):
		return _rims[texture]
	var solid := {}
	for p in WeaponAura.pixels_of(texture):
		solid[Vector2i(p)] = true
	var rim := PackedVector2Array()
	var seen := {}
	for cell: Vector2i in solid:
		for side: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := cell + side
			if not solid.has(next) and not seen.has(next):
				seen[next] = true
				rim.append(Vector2(next))
	_rims[texture] = rim
	return rim
