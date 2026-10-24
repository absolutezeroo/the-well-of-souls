class_name WeakPointTrait
extends MonsterTrait
## A body that can only be hurt while it opens (the Maw: its jaw, with Tôma inside). Closed,
## every blow glances off whole (a clang off its mask, sparks, "Immune": no damage, no status, no
## streak toward the shockwave) and it uses its skills; now and then it opens (`open_animation`,
## then `open_pose` held) and for `open_times` seconds every hit lands. While open it uses no
## skill: it draws the hero in toward its mouth (`pull_speed`) and bites whoever comes too
## close (a warning on the ground, then the bite). Later boss phases shorten the closed time
## (`closed_times`, by phase). It may be rooted (never walks), glow (a light of its own in a dark
## arena) and stand in a pool drawn on the ground under it.

enum Stage { CLOSED, OPENING, OPEN, CLOSING }

@export_group("Rhythm")
## Seconds it stays closed, by boss phase (index: phases gone through; the last value holds).
@export var closed_times: PackedFloat32Array = PackedFloat32Array([7.0, 6.0, 5.0])
## Seconds it stays open, by boss phase. A roar into a new phase doesn't count against them.
@export var open_times: PackedFloat32Array = PackedFloat32Array([3.5])
## Seconds the opening and the closing take (blows still glance off meanwhile).
@export var opening_time: float = 0.75
@export var closing_time: float = 0.4
## Played once to open (its last frame is the open look) and backwards to close.
@export var open_animation: StringName = &"attack"
## Held while open.
@export var open_pose: StringName = &"open"

@export_group("Closed")
## Floating over it when a blow glances off (translated where shown).
@export var immune_text: String = "No effect"
@export var immune_color: Color = Color(0.95, 0.93, 0.86)
## The clang (null: the body's material's sound, higher).
@export var immune_sound: AudioStream
## The jaw snapping shut on the bite (null: the monster's hurt sound).
@export var bite_sound: AudioStream

@export_group("Open")
## The ground in front of its mouth, from its feet (world units): pulled toward, bitten there.
@export var mouth_offset: Vector2 = Vector2(0, 30)
## The hero within this distance of the mouth is drawn toward it, `pull_speed` units a second
## (the hero runs at 170: he can always walk out).
@export var pull_radius: float = 420.0
@export var pull_speed: float = 55.0
## A bite on the hero within `bite_radius` of the mouth: a warning for `bite_windup`, then
## `bite_power` x its power, thrown back. Not again before `bite_cooldown`. A bite that hurts
## him marks the run `bite_mark` (Events.run_marked: a deed may ask for a run never bitten).
@export var bite_radius: float = 72.0
@export var bite_windup: float = 0.55
@export_range(0.0, 5.0, 0.05) var bite_power: float = 1.5
@export var bite_knockback: float = 460.0
@export var bite_cooldown: float = 1.3
@export var bite_element: VfxElementDef
@export var bite_mark: String = "bitten"

@export_group("Body")
## Never walks (the AI still turns and casts).
@export var rooted: bool = true
## A light of its own, level 0-15 (0: none), and brighter by `open_glow` while open.
@export_range(0, 15) var glow_level: int = 0
@export_range(0, 6) var open_glow: int = 2
@export var glow_color: Color = Color(1.0, 0.8, 0.45)
## Its body shines of its own (the false sun's gold): drawn over the floor's light and the mist
## over the walls, so the dark arena never dulls it, with a halo of `halo_element` behind it
## (null: none; GlowHalo).
@export var lit_from_within: bool = false
@export var halo_element: VfxElementDef
@export var halo_size: float = 50.0
@export var halo_offset: Vector2 = Vector2(0, -150)
## The halo a step up its ramp (GlowHalo.bright): the false sun's light, reading round the mask.
@export var halo_bright: bool = false
## The pool it rises from, on the ground under it (alpha 0: none): its size and where.
@export var pool_color: Color = Color(0, 0, 0, 0)
@export var pool_rim: Color = Color(0.3, 0.26, 0.32)
@export var pool_size: Vector2 = Vector2(150, 34)
@export var pool_offset: Vector2 = Vector2(0, 6)

## The pool's pixels, made once per look (a pool is drawn every frame).
static var _pools := {}


## One weak point's values (Monster.trait_state()).
class WeakPointState:
	extends RefCounted
	var stage := Stage.CLOSED
	## Seconds left in the stage it is in.
	var timer := 0.0
	var bite_cooldown := 0.0
	## The bite under way (its warning on the ground), null or freed when none.
	var bite: GroundStrike
	## When the last blow glanced off (s, Time): a volley of shots clangs once.
	var clang_at := -10.0
	## Its own light (glow_level), null without.
	var light: LightSource
	## The hero is drawn over it (he stands in front of its lower body).
	var hero_over := false


func make_state() -> RefCounted:
	return WeakPointState.new()


func _state(monster: Monster) -> WeakPointState:
	return monster.trait_state(self) as WeakPointState


func on_spawn(monster: Monster) -> void:
	var state := _state(monster)
	state.stage = Stage.CLOSED
	state.timer = _by_phase(closed_times, 0)
	state.bite_cooldown = 0.0
	state.bite = null
	state.clang_at = -10.0
	if glow_level > 0:
		var light := LightSource.new()
		light.color = glow_color
		light.level = glow_level
		light.position = mouth_offset + Vector2(0, -60)
		monster.add_child(light)
		state.light = light
	if lit_from_within:
		# Its body is made once it enters the world (setup comes first): lit then.
		if monster.rig:
			_light_from_within(monster)
		else:
			monster.ready.connect(_light_from_within.bind(monster), CONNECT_ONE_SHOT)


## Its body shines of its own (`lit_from_within`): over the floor's light (LightField.Z) and the
## mist over the walls it rises from (PlateauMist.Z), its own colors, under the effects in the
## air (drawn after the actors); its halo behind it.
func _light_from_within(monster: Monster) -> void:
	if monster.rig:
		monster.rig.z_as_relative = false
		monster.rig.z_index = PlateauMist.Z + 1
		var halo := GlowHalo.attach(monster, halo_element, halo_size, halo_offset, GlowHalo.Pulse.BREATHE)
		if halo:
			halo.bright = halo_bright
			halo.z_as_relative = false
			halo.z_index = PlateauMist.Z + 1
			monster.move_child(halo, monster.rig.get_index())  # behind the body, never over it


## A body lit from within is drawn over every actor (over the floor's light and the mist): the
## hero standing in front of its lower body (its tentacles in the tar, the pool's reach) is drawn
## over it while he is there, so he is never hidden behind it (docs/vfx.md 2b: the hero first).
func _keep_hero_in_front(monster: Monster) -> void:
	var hero := monster.world.player if monster.world else null
	if hero == null or monster.rig == null:
		return
	var state := _state(monster)
	var away := hero.global_position - monster.global_position
	var front := not monster.is_dead and away.y > -PixelDraw.PX * 4.0 and away.y < pool_offset.y + pool_size.y and absf(away.x) < pool_size.x * 0.5 + 16.0
	if front == state.hero_over:
		return
	state.hero_over = front
	if front:
		hero.z_as_relative = false
		hero.z_index = monster.rig.z_index + 1
		if not monster.tree_exiting.is_connected(_release_hero):
			monster.tree_exiting.connect(_release_hero.bind(monster), CONNECT_ONE_SHOT)
	else:
		_release_hero(monster)


## Fallen: the hero is drawn among the actors again; the halo goes out once its mask has
## crumbled (its dead animation), leaving no sun behind what stays of it.
func on_died(monster: Monster, _killer: Actor, _fell: bool, _rewards: bool) -> void:
	if not lit_from_within:
		return
	_release_hero(monster)
	var crumbling := monster.rig.animation_length(&"dead") if monster.rig else 0.0
	for child in monster.get_children():
		if child is GlowHalo:
			var halo_ref: WeakRef = weakref(child)  # (the timer outlives a freed body: see Effect.apply_all())
			monster.get_tree().create_timer(maxf(crumbling, 0.1), false).timeout.connect(func() -> void:
				var halo := halo_ref.get_ref() as GlowHalo
				if halo:
					halo.queue_free())


## The hero drawn among the actors again (he left its front, it died or left the world).
func _release_hero(monster: Monster) -> void:
	_state(monster).hero_over = false
	var hero := monster.world.player if monster.world else null
	if hero and is_instance_valid(hero):
		hero.z_as_relative = true
		hero.z_index = 0


## Which stage it is in (CLOSED, OPENING, OPEN, CLOSING).
func stage_of(monster: Monster) -> Stage:
	return _state(monster).stage


## Open: hits land.
func is_open(monster: Monster) -> bool:
	return stage_of(monster) == Stage.OPEN


## Seconds left in the stage it is in.
func time_left(monster: Monster) -> float:
	return _state(monster).timer


## Opens now (tests, a scripted moment).
func open_now(monster: Monster) -> void:
	_set_stage(monster, Stage.OPENING)


func update(monster: Monster, delta: float) -> void:
	var state := _state(monster)
	if lit_from_within:
		_keep_hero_in_front(monster)
	if monster.dormant:
		return
	state.bite_cooldown = maxf(state.bite_cooldown - delta, 0.0)
	var stage := state.stage
	# A roar into a new phase (untouchable a moment) doesn't eat the open window.
	if not (stage == Stage.OPEN and monster.invincible):
		state.timer = state.timer - delta
	match stage:
		Stage.CLOSED:
			# Never in the middle of a cast: the skill goes off first.
			if state.timer <= 0.0 and monster.casting_index < 0 and monster.target != null:
				_set_stage(monster, Stage.OPENING)
		Stage.OPENING:
			if state.timer <= 0.0:
				_set_stage(monster, Stage.OPEN)
		Stage.OPEN:
			_pull(monster, delta)
			_try_bite(monster)
			if state.timer <= 0.0 and not _biting(monster):
				_set_stage(monster, Stage.CLOSING)
		Stage.CLOSING:
			if state.timer <= 0.0:
				_set_stage(monster, Stage.CLOSED)


func _set_stage(monster: Monster, stage: Stage) -> void:
	var state := _state(monster)
	state.stage = stage
	var rig := monster.rig
	var phase := monster.phase_index()
	match stage:
		Stage.OPENING:
			state.timer = opening_time
			if rig:
				var frames := rig.body.sprite_frames
				var length := float(frames.get_frame_count(open_animation)) / maxf(frames.get_animation_speed(open_animation), 0.1) if frames and frames.has_animation(open_animation) else opening_time
				rig.hold_pose(open_animation, maxf(length / maxf(opening_time, 0.05), 0.1))
			Sfx.play_at(Sfx.bank.boss_roar, monster.global_position, -4.0, 0.8)
			Events.screen_shake.emit(0.35)
		Stage.OPEN:
			state.timer = _by_phase(open_times, phase)
			if rig:
				rig.hold_pose(open_pose)
			_glow(monster, glow_level + open_glow)
		Stage.CLOSING:
			state.timer = closing_time
			if rig:
				var frames := rig.body.sprite_frames
				var length := float(frames.get_frame_count(open_animation)) / maxf(frames.get_animation_speed(open_animation), 0.1) if frames and frames.has_animation(open_animation) else closing_time
				rig.hold_pose(open_animation, maxf(length / maxf(closing_time, 0.05), 0.1), true)
			_glow(monster, glow_level)
			Sfx.play_world(Sfx.bank.gate, monster.global_position, -4.0, 0.7)
		Stage.CLOSED:
			state.timer = _by_phase(closed_times, phase)
			if rig:
				rig.release_pose()


func _glow(monster: Monster, level: int) -> void:
	var light := _state(monster).light
	if light and is_instance_valid(light):
		light.level = clampi(level, 0, LightField.MAX_LEVEL)


func _by_phase(values: PackedFloat32Array, phase: int) -> float:
	if values.is_empty():
		return 1.0
	return values[clampi(phase, 0, values.size() - 1)]


## Where its mouth meets the ground (world).
func mouth_of(monster: Monster) -> Vector2:
	return monster.global_position + mouth_offset


## While open: the hero is drawn toward its mouth (slower than he walks; rolling still carries
## him), stopping short of its body.
func _pull(monster: Monster, delta: float) -> void:
	var hero := monster.world.player if monster.world else null
	if hero == null or hero.is_dead or hero.is_falling or pull_speed <= 0.0:
		return
	var mouth := mouth_of(monster)
	var away := hero.global_position - mouth
	var distance := away.length()
	if distance > pull_radius or distance < bite_radius * 0.5:
		return
	hero.move_and_collide(-away / distance * pull_speed * delta)


func _biting(monster: Monster) -> bool:
	var bite: Variant = _state(monster).bite  # (a Variant: it may have been freed)
	return bite != null and is_instance_valid(bite)


## The hero too close to the open mouth: a warning on the ground, then the bite.
func _try_bite(monster: Monster) -> void:
	var state := _state(monster)
	if _biting(monster) or state.bite_cooldown > 0.0 or monster.invincible:
		return
	var hero := monster.world.player
	if hero == null or hero.is_dead:
		return
	var mouth := mouth_of(monster)
	if hero.global_position.distance_to(mouth) > bite_radius + hero.radius:
		return
	var damage := maxi(1, roundi(monster.get_power() * bite_power))
	var bite := GroundStrike.create(monster.world, monster, mouth, bite_radius, bite_windup * monster.get_telegraph_scale(), damage, bite_knockback, bite_element)
	bite.shake = 0.5
	bite.sound = bite_sound if bite_sound else monster.def.hurt_sound
	# A method with weak references, not a lambda holding them (conventions.md).
	bite.landed.connect(_on_bite_landed.bind(weakref(hero), weakref(monster), mouth))
	monster.world.spawn_vfx(bite)
	state.bite = bite
	state.bite_cooldown = bite_cooldown + bite_windup


## The bite lands: a hero hurt by it this very frame marks the run; the claw shows on the mouth.
func _on_bite_landed(hero_ref: WeakRef, monster_ref: WeakRef, mouth: Vector2) -> void:
	var hero := hero_ref.get_ref() as Player
	var monster := monster_ref.get_ref() as Monster
	if hero and hero.last_hurt_frame == Engine.get_physics_frames() and not bite_mark.is_empty():
		Events.run_marked.emit(bite_mark)
	if monster and bite_element and bite_element.claw:
		monster.world.spawn_vfx(SheetVfx.play(bite_element.claw, mouth + Vector2(0, -20), Vector2.DOWN, bite_element))


func steer(monster: Monster, direction: Vector2) -> Vector2:
	if rooted:
		monster.move_direction = Vector2.ZERO  # standing still is not being stuck
		return Vector2.ZERO
	return direction


## Its blows are its own (the bite, its skills): no weapon swings.
func can_attack(_monster: Monster) -> bool:
	return false


## Skills only while closed (and not on its way to opening).
func can_cast(monster: Monster) -> bool:
	var state := _state(monster)
	return state.stage == Stage.CLOSED and state.timer > 0.5


## Closed (or opening, or closing): the blow glances off whole.
func deflects(monster: Monster, hit: HitInfo) -> bool:
	if is_open(monster):
		return false
	if hit.is_tick:
		return true  # a burn or poison ticking: nothing to show
	var state := _state(monster)
	var now := Time.get_ticks_msec() * 0.001
	if now - state.clang_at < 0.18:
		return true  # a volley of shots: one clang
	state.clang_at = now
	var world := monster.world
	var from := Vector2.DOWN
	if hit.origin != Vector2.INF:
		from = monster.global_position.direction_to(hit.origin)
	elif is_instance_valid(hit.source):
		from = monster.global_position.direction_to(hit.source.global_position)
	var at := monster.global_position + mouth_offset * 0.5 + from * monster.radius * 0.6
	Vfx.hit(world, at, from, immune_color, false, null, monster.def.material)
	if immune_sound:
		Sfx.play_at(immune_sound, at, -2.0, 1.2)
	elif monster.def.material and monster.def.material.sound:
		Sfx.play_at(monster.def.material.sound, at, -2.0, 1.35)
	Sfx.play_at(Sfx.bank.projectile_impact, at, -4.0, 1.4)
	# Over its jaw, where the blows land (its head is far up the screen, under the banners).
	world.spawn_floating_text(monster.global_position + Vector2(0, -monster.radius), tr(immune_text), immune_color)
	return true


## The pool it rises from (ground layer, under every body): a flat, ragged puddle of art pixels
## (its edge wavers, tar drips out of it), its far rim catching the light.
func draws_under() -> bool:
	return true


func draw_under(_monster: Monster, canvas: CanvasItem) -> void:
	if pool_color.a <= 0.0:
		return
	var texture := _pool_texture()
	var size := texture.get_size() * PixelDraw.PX
	canvas.draw_texture_rect(texture, Rect2(PixelDraw.snap(pool_offset - size * 0.5), size), false)


func _pool_texture() -> Texture2D:
	var key := [pool_color, pool_rim, pool_size]
	if _pools.has(key):
		return _pools[key]
	var cells := Vector2i(maxi(8, roundi(pool_size.x / PixelDraw.PX)), maxi(4, roundi(pool_size.y / PixelDraw.PX)))
	var image := Image.create(cells.x, cells.y, false, Image.FORMAT_RGBA8)
	var half := Vector2(cells) * 0.5
	var body := Color(pool_color, 1.0)
	var depth := Color(pool_color.r * 0.6, pool_color.g * 0.6, pool_color.b * 0.6, 1.0)
	# The main puddle (its edge wavering by angle), and a few drips around it.
	var blobs: Array[Vector3] = [Vector3(0.0, 0.0, 0.78), Vector3(-0.62, 0.25, 0.3), Vector3(0.58, 0.3, 0.34), Vector3(0.2, 0.55, 0.22), Vector3(-0.3, -0.45, 0.2)]
	for y in cells.y:
		for x in cells.x:
			var at := (Vector2(x, y) + Vector2(0.5, 0.5) - half) / half
			var inside := 0.0  # how deep in the tar (1: the middle of a blob)
			for blob in blobs:
				var from := (at - Vector2(blob.x, blob.y)) / blob.z
				var angle := from.angle()
				var edge := 1.0 + 0.12 * sin(angle * 3.0 + 1.0) + 0.08 * sin(angle * 5.0 + 2.3) + 0.05 * sin(angle * 9.0)
				inside = maxf(inside, 1.0 - from.length() / edge)
			if inside <= 0.0:
				continue
			var color := body
			var cell := Vector2i(x, y)
			if inside < 0.12:
				color = pool_rim if at.y < 0.05 else depth  # the far rim catches the light
			elif inside > 0.45 and PixelDraw.dither(cell, clampf((inside - 0.45) * 2.0, 0.0, 1.0)):
				color = depth  # deeper in the middle
			elif at.y < -0.1 and inside > 0.2 and inside < 0.4 and (x * 7 + y * 3) % 23 == 0:
				color = pool_rim  # a glint on the tar
			image.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(image)
	_pools[key] = texture
	return texture


func describe() -> String:
	return tr("Only its open mouth can be hurt.")
