class_name Chest
extends StaticBody2D
## A chest built from a ChestDef. Opens when the hero touches it.

signal opened(chest: Chest)

const SIZE := 32.0
## The hero opens it from this close.
const OPEN_DISTANCE := 36.0

var def: ChestDef
var world: World
var trapped := false
var is_open := false

var _rattle := 0.0
var _next_rattle := 3.0
var _fuse := -1.0


func setup(chest_def: ChestDef, floor_world: World, is_trapped: bool) -> void:
	def = chest_def
	world = floor_world
	trapped = is_trapped
	collision_layer = Layers.WORLD
	collision_mask = 0
	_next_rattle = randf_range(1.5, 4.0)
	add_to_group("chests")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(SIZE * 0.75, SIZE * 0.5)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, SIZE * 0.15)
	add_child(collision)


func _physics_process(delta: float) -> void:
	if _fuse >= 0.0:
		_fuse -= delta
		queue_redraw()
		if _fuse < 0.0:
			_fuse = -1.0  # a completed fuse has one canonical durable value
			_explode()
		return
	if is_open:
		return
	if trapped:
		# The tell: a little shake every few seconds.
		_rattle = maxf(_rattle - delta, 0.0)
		_next_rattle -= delta
		if _next_rattle <= 0.0:
			_next_rattle = randf_range(2.5, 5.0)
			_rattle = 0.25
		queue_redraw()
	var player := world.player
	if player and not player.is_dead and player.global_position.distance_to(global_position) <= OPEN_DISTANCE:
		open()


## Already opened before the run was saved: shows open, gives nothing.
func set_spent() -> void:
	is_open = true
	queue_redraw()


func open() -> void:
	if is_open:
		return
	world.spawns.begin_settlement()
	is_open = true
	queue_redraw()
	opened.emit(self)
	Events.stat_counted.emit("chests", 1)
	world.spawn_gold(global_position + Vector2(0, 14), world.rng.randi_range(def.gold.x, def.gold.y) + roundi(world.depth * def.gold_per_depth))
	if trapped:
		_spring()
		_drop_items(1)
	else:
		Sfx.play_world(def.open_sound, global_position)
		Vfx.sparkles(world, global_position, Palette.GOLD)
		_drop_items(world.rng.randi_range(def.items_min, def.items_max))
	world.spawns.end_settlement()


func trap_time_left() -> float:
	return _fuse if _fuse >= 0.0 else -1.0


## Restore an opened chest quietly; its pending fuse resumes but its rewards are not replayed.
func restore_opened(opened_before: bool, seconds: float) -> void:
	is_open = opened_before
	_fuse = seconds
	queue_redraw()


func _spring() -> void:
	Sfx.play_at(def.trap_sound, global_position)
	Vfx.alert(world, global_position + Vector2(0, -SIZE * 0.6))
	world.spawn_floating_text(global_position + Vector2(0, -SIZE * 0.5), tr("Trap!"), Palette.DANGER)
	var can_explode := def.explosion_radius > 0.0
	var can_spawn := def.trap_monsters > 0
	if can_explode and (not can_spawn or world.rng.randf() < 0.5):
		_fuse = def.fuse_time
		world.spawn_vfx(RingVfx.create(global_position, def.explosion_radius, Color(1.0, 0.3, 0.2, 0.8)))
	elif can_spawn:
		world.spawns.defer_monsters([], def.trap_monsters, global_position, 40.0, world.player)


func _explode() -> void:
	world.spawns.begin_settlement()
	var damage := world.rules.dungeon_damage(def.explosion_damage)
	# The chest bursts apart (splinters, grit and dust), not a fireball.
	Vfx.explosion(world, global_position, def.explosion_radius, VfxElementDef.named(&"earth"), false)
	Combat.blast(world, global_position, def.explosion_radius, damage, 340.0)
	world.spawns.end_settlement()


func _drop_items(count: int) -> void:
	# Spill towards the hero (that side is free: they stand there).
	var toward := Vector2.DOWN
	if world.player:
		toward = global_position.direction_to(world.player.global_position)
	for i in count:
		var item := world.pick_random_item()
		if item:
			var angle := toward.angle() + (i - (count - 1) * 0.5) * 0.6
			world.spawn_loot(item, global_position + Vector2.from_angle(angle) * 26.0, def.loot_quality)
	world.drop_rune(global_position + Vector2.from_angle(toward.angle() + PI * 0.5) * 24.0, world.config().chest_rune_chance)


func _draw() -> void:
	if def == null or def.icon == null:
		return
	var half := SIZE * 0.5
	var offset := Vector2.ZERO
	if _rattle > 0.0:
		offset.x = sin(_rattle * 90.0) * 1.5
	var color := def.icon_tint
	if _fuse >= 0.0:
		var blink := int(_fuse * 14.0) % 2 == 0
		color = Color(2.0, 0.8, 0.6) if blink else color
		offset.x += randf_range(-1.5, 1.5)
	PixelDraw.disc(self, Vector2(0, half - 4.0), half * 0.75, Color(0, 0, 0, 0.3), 1.0, 0.35)
	offset = PixelDraw.snap(offset)  # it rattles by whole art pixels
	var frame := 1 if is_open else 0
	var frame_size := float(def.icon.get_height())
	draw_texture_rect_region(def.icon, Rect2(Vector2(-half, -half) + offset, Vector2(SIZE, SIZE)), Rect2(frame * frame_size, 0, frame_size, frame_size), color)
