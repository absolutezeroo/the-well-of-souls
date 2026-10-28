class_name Prop
extends StaticBody2D
## A crate, pot, explosive barrel or lantern built from a PropDef.
## Breakable props take hits from weapons, projectiles and explosions (see Combat).

signal broken(prop: Prop)

const SIZE := 32.0
const SHAKE_TIME := 0.15

## Debris made from each PropDef's color (see _chips).
static var _CHIPS := {}

var def: PropDef
var world: World
var is_broken := false

var _hits_left := 1
var _shake := 0.0
var _fuse := -1.0
## Who broke it: explosions are credited to them (XP for kills).
var _breaker: Actor

@onready var _light: LightSource = $Light


func setup(prop_def: PropDef) -> void:
	def = prop_def
	_hits_left = def.hits
	collision_layer = Layers.WORLD
	collision_mask = 0
	add_to_group("props")


func _ready() -> void:
	var shape := RectangleShape2D.new()
	var foot := Vector2(def.footprint)
	shape.size = Vector2(SIZE * (foot.x - 0.25), SIZE * (foot.y - 0.4))
	($CollisionShape2D as CollisionShape2D).shape = shape
	($CollisionShape2D as CollisionShape2D).position = Vector2(0, SIZE * 0.1)
	if def.flame:
		var flame := def.flame.instantiate() as Node2D
		flame.position = Vector2(0, SIZE * Vector2(def.footprint).y * 0.5) + def.flame_offset
		flame.z_index = LightField.Z + 1  # a flame is its own light
		add_child(flame)
	_light.visible = def.light_level > 0
	_light.color = def.light_color
	_light.level = def.light_level


func take_hit(hit: HitInfo) -> void:
	if is_broken or not def.is_breakable() or _fuse >= 0.0:
		return
	_hits_left -= 1
	_shake = SHAKE_TIME
	Vfx.burst(world, Vfx.HIT_SPARKS, global_position, def.debris_color)
	if _hits_left > 0:
		Sfx.play_world(def.break_sound, global_position, -6.0)
		return
	_breaker = hit.source if is_instance_valid(hit.source) else null
	if def.is_explosive():
		_fuse = def.fuse_time
	else:
		_break()


func _process(delta: float) -> void:
	_shake = maxf(_shake - delta, 0.0)
	if _fuse >= 0.0:
		_fuse -= delta
		if _fuse < 0.0:
			_explode()
	if _shake > 0.0 or _fuse >= 0.0:
		queue_redraw()


func _break() -> void:
	if is_broken:
		return
	is_broken = true
	collision_layer = 0
	for cell in cells():
		world.set_cell_blocked(cell, false)
	Sfx.play_world(def.break_sound, global_position)
	Vfx.burst(world, Vfx.DEATH_CHUNKS, global_position, def.debris_color)
	# It breaks into grit and dust (the earth's impact), not a puff of magic smoke.
	var dust := VfxElementDef.named(&"earth")
	world.spawn_vfx(SheetVfx.play(dust.impact, global_position + Vector2(0, 6), Vector2.RIGHT, dust))
	world.add_debris(global_position + Vector2(0, 6), _chips(), 0.8)
	if def.loot:
		for item in def.loot.roll(world.rng, world.rules.loot_chance()):
			world.spawn_loot(item, global_position)
		if world.rng.randf() < world.config().prop_gold_chance:
			var config := world.config()
			world.spawn_gold(global_position, world.rng.randi_range(config.prop_gold.x, config.prop_gold.y) + floori(world.depth * config.prop_gold_per_depth))
	broken.emit(self)
	queue_free()


## Gone without a sound, nothing dropped (a resumed floor: it was broken before quitting). Its
## cells are free again.
func take_away() -> void:
	if is_broken:
		return
	is_broken = true
	collision_layer = 0
	for cell in cells():
		world.set_cell_blocked(cell, false)
	queue_free()


func _explode() -> void:
	var at := global_position
	var damage := def.explosion_damage + world.depth
	_break()
	Vfx.explosion(world, at, def.explosion_radius)
	# Whoever broke it may be gone by now (a monster that died during the fuse).
	var source: Actor = _breaker if is_instance_valid(_breaker) else null
	Combat.blast(world, at, def.explosion_radius, damage, 360.0, source)


func _draw() -> void:
	if def == null or def.icon == null:
		return
	var offset := Vector2.ZERO
	if _shake > 0.0:
		offset.x = sin(_shake * 120.0) * 2.0
	var color := Color.WHITE
	if _fuse >= 0.0:
		# Blinking faster and faster before the blast.
		var blink := int(_fuse * (8.0 + 30.0 * (1.0 - _fuse / maxf(def.fuse_time, 0.01)))) % 2 == 0
		color = Color(2.0, 0.8, 0.6) if blink else Color.WHITE
		offset.x += randf_range(-1.5, 1.5)
	var foot := Vector2(def.footprint) * SIZE
	var size := def.icon.get_size() * 2.0
	# Shadow, then the sprite standing on the bottom of its footprint.
	PixelDraw.disc(self, Vector2(0, foot.y * 0.5 - 3.0), foot.x * 0.35, Color(0, 0, 0, 0.3), 1.0, 0.35)
	offset = PixelDraw.snap(offset)  # it shakes by whole art pixels
	var top_left := Vector2(-size.x * 0.5, foot.y * 0.5 - size.y)
	draw_texture_rect(def.icon, Rect2(top_left + offset, size), false, color * def.icon_tint)


## The cells it stands on.
func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var top_left := world.map.world_to_cell(global_position - (Vector2(def.footprint) - Vector2.ONE) * SIZE * 0.5)
	for y in def.footprint.y:
		for x in def.footprint.x:
			result.append(top_left + Vector2i(x, y))
	return result


## Its pieces, in its debris color (shared by every prop of this kind).
func _chips() -> ImpactMaterialDef:
	if not _CHIPS.has(def):
		var chips := ImpactMaterialDef.new()
		var color := Color(def.debris_color, 1.0)
		chips.debris_colors = PackedColorArray([color, color.darkened(0.25), color.lightened(0.2)])
		chips.debris_count = 7
		_CHIPS[def] = chips
	return _CHIPS[def]
