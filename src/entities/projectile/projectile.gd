class_name Projectile
extends Area2D
## A moving shot. Hits the first enemy of its shooter (or several with pierce),
## stops on walls, and optionally explodes. Shots from traps have no shooter and hit everyone.

var _world: World
var _shooter: Actor
var _faction: Actor.Faction
## Trap shots: no side, hurt players and monsters alike.
var _hits_everyone := false
var _crit_chance := 0.0
var _spec: ProjectileSpec
## What fired it (Actor.heal_source when it was fired: "skill:fireball"...), stamped on its hits
## (HitInfo.via: the gameplay statistics).
var _via: StringName = &""
var _direction := Vector2.RIGHT
var _travelled := 0.0
var _pierce_left := 0
var _already_hit: Array[Actor] = []
var _done := false
var _trail: Array[Vector2] = []  # recent global positions, newest last
## How it looks in flight (its sprite or its element's shot); null: a dot.
var _sheet: VfxSheetDef
## Its element, or one made from its color (old content).
var _element: VfxElementDef
## The element it flies in without being made of it (an arrow from a bow with an Ember Rune:
## flames riding it, embers trailing; ProjectileSpec.look_element), and a second one's bits.
var _rides: VfxElementDef
var _second: VfxElementDef
var _age := 0.0
## Its sheet's first frame, picked at random: a ring of twelve sparks doesn't flicker in step.
var _phase := 0

const TRAIL_LENGTH := 6
## Light of a glowing shot, above the floor's own (LightSource.relative).
const GLOW_LEVEL := 3
## The hero's shot going north (we see his back) is drawn behind every body for this many
## world units, the length of his body, then over them like any shot: it never covers him
## (docs/vfx.md 2b).
const BEHIND_SHOOTER := 30.0

## World units of flight left behind the shooter's body (0: drawn over the bodies).
var _behind_left := 0.0
## Where it goes when it lands (WorldSpawner.shot_pool, docs/performance.md "Pools"): taken out
## of the tree and fired again later, set up anew (_reset()); null: freed.
var pool: NodePool


func setup(shooter: Actor, direction: Vector2, spec: ProjectileSpec) -> void:
	_reset()
	_via = Actor.heal_source
	_world = shooter.world
	_shooter = shooter
	_faction = shooter.faction
	_crit_chance = shooter.get_stats().crit_chance
	_configure(direction, spec)
	if shooter is Player and VfxLayer.goes_behind(direction):
		_behind_left = BEHIND_SHOOTER
		z_index = VfxLayer.GROUND_Z  # under the bodies (his own first) while it clears him
	collision_mask = Layers.WORLD | (Layers.MONSTERS if _faction == Actor.Faction.PLAYER else Layers.PLAYER)


## Flying toward `target` and able to hurt it (an enemy's shot, a trap's arrow): the HUD points
## at it while it is out of sight (ThreatMarkers).
func threatens(target: Actor) -> bool:
	if _done or target == null:
		return false
	if not _hits_everyone and _faction == target.faction:
		return false
	return _direction.dot(target.global_position - global_position) > 0.0


## A shot fired by the dungeon itself (arrow traps): hits players and monsters.
func setup_trap(world: World, direction: Vector2, spec: ProjectileSpec) -> void:
	_reset()
	_world = world
	_hits_everyone = true
	_configure(direction, spec)
	collision_mask = Layers.WORLD | Layers.MONSTERS | Layers.PLAYER


## A shot fired again from the pool: as a new one (its flight, its hits, its looks gone).
func _reset() -> void:
	_shooter = null
	_hits_everyone = false
	_crit_chance = 0.0
	_via = &""
	_travelled = 0.0
	_age = 0.0
	_done = false
	_already_hit.clear()
	_trail.clear()
	_behind_left = 0.0
	_sheet = null
	_rides = null
	_second = null
	_phase = 0
	z_index = 0
	visible = true
	set_physics_process(true)
	for child in get_children():
		if child is GlowHalo or child is DistortionStamp:
			remove_child(child)
			child.queue_free()


func _configure(direction: Vector2, spec: ProjectileSpec) -> void:
	_spec = spec
	_direction = direction.normalized()
	_pierce_left = spec.pierce
	collision_layer = 0
	var holder := $CollisionShape2D as CollisionShape2D
	var shape := holder.shape as CircleShape2D
	if shape == null:
		shape = CircleShape2D.new()
		holder.shape = shape
	shape.radius = spec.radius
	# Its look: its own drawn sheet or sprite, else its element's shot, else a dot in its color.
	if spec.sheet:
		_sheet = spec.sheet
	elif spec.texture:
		_sheet = VfxSheetDef.from_texture(spec.texture, spec.texture_frames)
	elif spec.element and spec.element.projectile:
		_sheet = spec.element.projectile
	_element = VfxElementDef.or_color(spec.element, spec.color)
	_rides = spec.look_element if SwingMatter.sheds(spec.look_element) else null
	_second = spec.second_element if SwingMatter.sheds(spec.second_element) else null
	if _sheet:
		_phase = randi() % maxi(_sheet.frame_count(), 1)
	# Magic shots light up the dark in their color (not a boss's whole ring: too many lights);
	# plain things (shurikens, arrows) and matter (blood, water) don't shine at all.
	var shines := spec.glow > 0.0 and (spec.element == null or spec.element.emissive)
	var glow_element: VfxElementDef = null
	if _rides and _rides.emissive and spec.element == null:
		# An arrow of fire lights its way and wears a halo of its flames (a magic shot keeps
		# its own light and halo).
		shines = true
		glow_element = _rides
	var glow := $Glow as LightSource
	glow.visible = shines and (spec.count <= 3 or spec.explosion_radius > 0.0)
	glow.color = (glow_element if glow_element else _element).color()
	glow.level = maxi(1, roundi(GLOW_LEVEL * spec.glow))
	# A glow halo around a few shots' cores (GlowHalo: dithered rings of added light, its light
	# on the floor is the Glow above): never around each of a boss's sixteen shards, it would fog
	# the screen; a charged shot (`halo`) always has one, wider. A storm spark flickers.
	# (A thing riding an element has no halo: its matter on it is its light; a checker round an
	# arrow reads as a blur.)
	if shines and (spec.count <= 3 or spec.halo) and glow_element == null:
		var halo_element := glow_element if glow_element else _element
		var storm := halo_element.bit == VfxElementDef.Bit.FORK
		var core := maxf(spec.radius, 5.0) * (1.4 if spec.halo else 1.0)
		GlowHalo.attach(self, halo_element, core, Vector2.ZERO, GlowHalo.Pulse.FLICKER if storm else GlowHalo.Pulse.BREATHE)
	# Shadow and arcane bend the picture toward them (the screen pass keeps the nearest few).
	DistortionStamp.of_element(self, spec.element, maxf(spec.radius, 5.0) * 3.0, 1.0)
	# Drawn on the grid; a shining shot keeps its colors out of the floor's grading.
	material = FxLook.sprite(shines or (spec.element != null and spec.element.emissive))


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	var step := _spec.speed * delta
	_trail.append(global_position)
	if _trail.size() > TRAIL_LENGTH:
		_trail.pop_front()
	position += _direction * step
	# (Its trail reaches back to the oldest point kept; off screen, nothing to draw.)
	if Vfx.on_screen(self, global_position.distance_to(_trail[0]) + _spec.radius + 32.0):
		queue_redraw()
	_travelled += step
	if _behind_left > 0.0:
		_behind_left -= step
		if _behind_left <= 0.0:
			z_index = 0  # clear of the hero: over the bodies like any shot
	if _travelled >= _spec.max_distance:
		_finish()


func _on_body_entered(body: Node2D) -> void:
	if _done:
		return
	if not body is Actor:
		# A wall or a prop
		if body is Prop:
			var prop_hit := HitInfo.new()  # a prop counts blows, not damage (Combat.break_props)
			prop_hit.source = _shooter if is_instance_valid(_shooter) else null
			(body as Prop).take_hit(prop_hit)
		Vfx.hit(_world, global_position, -_direction, _element.color(), false, _spec.element)
		Sfx.play_at(Sfx.bank.projectile_impact, global_position, -4.0)
		_burst()
		_finish()
		return
	var target := body as Actor
	if (target.faction == _faction and not _hits_everyone) or target.is_dead or _already_hit.has(target):
		return
	_already_hit.append(target)
	if _spec.explosion_radius > 0.0:
		_finish()
		return
	var struck := _make_hit(_shooter if is_instance_valid(_shooter) else null, _direction * _spec.knockback)
	struck.shot = _direction  # (its blast's hits, below, are a blast's, not the shot's)
	target.take_hit(struck)
	if _pierce_left > 0:
		_pierce_left -= 1
	else:
		_burst()
		_finish()


## A magic shot bursts where it lands, in its element's language (exploding ones have their
## own big blast).
func _burst() -> void:
	if _spec.glow > 0.0 and _spec.explosion_radius <= 0.0:
		Vfx.pop(_world, global_position, _element, clampf(_spec.radius * 2.2, 10.0, 22.0), _direction)


func _finish() -> void:
	if _done:
		return
	_done = true
	if _spec.explosion_radius > 0.0:
		_explode()
	elif _travelled >= _spec.max_distance and _spec.glow > 0.0:
		# Out of range: it breaks up into a few of its bits instead of vanishing.
		_world.spawn_vfx(ImpactVfx.create(global_position, _direction, _element.color(), false, _element if _spec.element else null))
	elif _travelled >= _spec.max_distance and _rides:
		_world.spawn_vfx(ImpactVfx.sparks(global_position, _direction, _rides))  # its flames go out
	set_physics_process(false)
	visible = false
	if pool:
		pool.give(self)  # out of the tree at the frame's end, fired again later
	else:
		queue_free()


func _explode() -> void:
	if _spec.nova_burst and _spec.element:
		Vfx.nova(_world, global_position, _spec.explosion_radius, _spec.element)
		Vfx.pop(_world, global_position, _spec.element, 20.0, _direction)
		Sfx.play_at(Sfx.bank.explosion, global_position, -6.0)
	else:
		Vfx.explosion(_world, global_position, _spec.explosion_radius, _spec.element)
	var source: Actor = _shooter if is_instance_valid(_shooter) else null
	Combat.hit_props(_world, source, global_position, _spec.explosion_radius)
	for target in _world.get_actors() if _hits_everyone else _world.get_hostiles(_faction):
		var offset := target.global_position - global_position
		if offset.length() <= _spec.explosion_radius + target.radius:
			target.take_hit(_make_hit(source, offset.normalized() * _spec.knockback))


## One of its hits (on contact or in its blast), pushing `knockback`. Its rolls come from its
## floor's combat dice (World.combat_rng), the shooter gone or not.
func _make_hit(source: Actor, knockback: Vector2) -> HitInfo:
	var hit := Combat.make_hit(_spec.damage, _crit_chance, source, _world.combat_rng)
	hit.knockback = knockback
	hit.status = _spec.status
	hit.element = _spec.element if _spec.element else _spec.hit_element
	hit.is_secondary = _spec.secondary
	hit.via = _via
	return hit


func _draw() -> void:
	if _spec == null:
		return
	# A streak of its element's bits behind magic shots, on the grid, going down its ramp
	# and dithering out (plain things just fly).
	# Every other position, so it reads as motes left behind, not a line.
	if _spec.glow > 0.0:
		for i in range(_trail.size() - 1, -1, -2):
			var t := float(i + 1) / (_trail.size() + 1)  # 1 = newest
			var local := _trail[i] - global_position
			if not PixelDraw.dither(PixelDraw.cell_of(local), t):
				continue
			var size := 2 if t > 0.6 and _spec.radius >= 6.0 else 1
			# Another element the weapon carries: every other bit of a magic shot's trail is the
			# one riding it (a frost shard trailing embers), a few of a second one's.
			var other: VfxElementDef = _rides if _rides and _spec.element and int(i / 2.0) % 2 == 0 else (_second if _second and i % 3 == 0 else null)
			if other:
				PixelDraw.bit(self, other.bit, local + _drift(other, t, i), size, other.shade(1.0 - t * 0.75), Vector2.UP if other.motion == VfxElementDef.Motion.RISE else -_direction)
				continue
			PixelDraw.bit(self, VfxElementDef.Bit.SQUARE if _spec.element == null else _element.bit, local, size, _element.shade(1.0 - t * 0.75), -_direction)
	if _rides and _spec.element == null:
		_draw_riding()
	if _sheet:
		PixelDraw.sheet(self, _sheet, int(_age * _sheet.fps) + _phase, Vector2.ZERO, _direction, _element)
		if _rides:
			_draw_riding_front()
		return
	# No sprite: a stepped dot, its edge, its body, a bright heart.
	var r := PixelDraw.snap_length(_spec.radius)
	PixelDraw.disc(self, Vector2.ZERO, r + PixelDraw.PX, _element.edge())
	PixelDraw.disc(self, Vector2.ZERO, r, _element.color())
	PixelDraw.disc(self, Vector2.ZERO, maxf(r * 0.5, PixelDraw.PX), _element.core())
	if _rides:
		_draw_riding_front()


## A plain thing flying in an element (ProjectileSpec.look_element): a trail of its bits left
## behind (fire's embers rising off the path, frost's chips falling, poison's drips, storm's
## forks), every other position so it reads as bits, not a line; a second element's every
## third one. Behind the sheet.
func _draw_riding() -> void:
	var step := int(_age * 12.0)  # bits come and go at 12 fps
	for i in range(_trail.size() - 1, -1, -2):
		var t := float(i + 1) / (_trail.size() + 1)  # 1 = newest
		var element := _second if _second and (int(i / 2.0) + step) % 3 == 0 else _rides
		var local := _trail[i] - global_position
		var at := local + _drift(element, t, i)
		if not PixelDraw.dither(PixelDraw.cell_of(at), t):
			continue
		var direction := Vector2.UP if element.motion == VfxElementDef.Motion.RISE else -_direction
		PixelDraw.bit(self, element.bit, at, 2 if t > 0.7 and element.bit != VfxElementDef.Bit.TEARDROP else 1, element.shade(0.2 + (1.0 - t) * 0.8), direction)


## How a bit of `element` left `t` ago (1 = newest) has drifted: fire's rise, frost's fall,
## storm's fly out to the sides.
func _drift(element: VfxElementDef, t: float, i: int) -> Vector2:
	match element.motion:
		VfxElementDef.Motion.RISE:
			return Vector2(0, -(1.0 - t) * 8.0)
		VfxElementDef.Motion.FALL, VfxElementDef.Motion.SINK:
			return Vector2(0, (1.0 - t) * 6.0)
		VfxElementDef.Motion.OUTWARD:
			return _direction.orthogonal() * (4.0 if (i + int(_age * 12.0)) % 2 == 0 else -4.0) * (1.0 - t)
	return Vector2.ZERO


## Over the sheet: the element's matter riding the thing along its back half, redrawn at 12
## fps: fire's licks climbing off the shaft (a white-hot foot, red tips), frost's rime crusting
## it with a glint, poison dripping under it, storm's sparks crackling on and off, blood
## dripping, holy's glints; whole art pixels, its ramp only.
func _draw_riding_front() -> void:
	var step := int(_age * 12.0)
	var back := -_direction
	var across := _direction.orthogonal()
	# A magic shot carries it on its back, behind its glowing core (a plain thing, along it).
	var start := -4.0 if _spec.element == null else maxf(_spec.radius, 4.0)
	for k in 4:
		var foot := PixelDraw.snap(back * (5.0 * k + start) + across * (PixelDraw.PX if (step + k) % 2 == 0 else 0.0))
		var flicker := (step * 7 + k * 3) % 5  # each lick its own height, changing 12 times a second
		match _rides.motion:
			VfxElementDef.Motion.RISE:
				# A lick: a column of 3-5 pixels up from the shaft, white-hot at its foot, red at
				# its tip, the tip curling a pixel aside; the first ones the tallest.
				var tall := 4 + flicker % 3 - (2 if k == 3 else 0)
				for y in tall:
					var t := float(y) / maxf(tall - 1, 1.0)
					var curl := PixelDraw.PX * (1.0 if flicker % 2 == 0 else -1.0) if y == tall - 1 else 0.0
					var color := _rides.shade(t * 0.95)
					PixelDraw.pixel(self, foot + Vector2(curl, -PixelDraw.PX * y), color)
					if y < int(tall / 2.0):
						PixelDraw.pixel(self, foot + Vector2(PixelDraw.PX, -PixelDraw.PX * y), _rides.shade(minf(t * 0.95 + 0.25, 1.0)))  # a wider foot
			VfxElementDef.Motion.FALL, VfxElementDef.Motion.SINK:
				if _rides.bit == VfxElementDef.Bit.DIAMOND:
					# Rime crusting the shaft: a lit chip on it, a shard of ice under it now and then.
					PixelDraw.bit(self, _rides.bit, foot + Vector2(0, -PixelDraw.PX), 2, _rides.shade(0.3), Vector2.from_angle(k * 1.7), _rides.core())
					if flicker == k % 5:
						PixelDraw.pixel(self, foot + Vector2(0, PixelDraw.PX * 2.0), _rides.shade(0.6))
				else:
					# Drips hanging under it (poison, blood), each its own length.
					var hang := 1 + flicker % 3
					for y in hang:
						PixelDraw.pixel(self, foot + Vector2(0, PixelDraw.PX * (y + 1)), _rides.shade(0.2 + float(y) / hang * 0.7))
			_:
				if _rides.bit == VfxElementDef.Bit.FORK and (step + k) % 3 == 2:
					continue  # storm flickers
				var side := 1.0 if (k + step) % 2 == 0 else -1.0
				PixelDraw.bit(self, _rides.bit, foot + across * PixelDraw.PX * 2.0 * side, 2, _rides.shade(0.15 + k * 0.2), across * side, _rides.core())
