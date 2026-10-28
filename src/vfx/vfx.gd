class_name Vfx
## One-line helpers to spawn visual effects, so gameplay code stays readable:
##     Vfx.hit(world, position, direction, Color.WHITE)

const HIT_SPARKS: PackedScene = preload("res://src/vfx/particles/hit_sparks.tscn")
const DEATH_CHUNKS: PackedScene = preload("res://src/vfx/particles/death_chunks.tscn")
const SMOKE: PackedScene = preload("res://src/vfx/particles/smoke.tscn")
const DUST: PackedScene = preload("res://src/vfx/particles/dust.tscn")
const FIRE: PackedScene = preload("res://src/vfx/particles/fire.tscn")
const SPARKLES: PackedScene = preload("res://src/vfx/particles/sparkles.tscn")
const SMOKE_SHEET: Texture2D = preload("res://assets/fx/smoke.png")
const SIGIL: VfxSheetDef = preload("res://data/vfx/sheets/holy_sigil.tres")
## The cross a critical hit cuts (cutx.png, painted in the blow's element).
const CRIT_CROSS: VfxSheetDef = preload("res://data/vfx/sheets/crit_cross.tres")
const ALERT_EMOTE: Texture2D = preload("res://assets/ui/emotes/emote22.png")

## False when the game runs as a simulation, nothing watching (the balance tools, BalanceLab):
## what only shows something is not made or not updated (effects, floating numbers, splats,
## light flashes, the bodies' looks, the camera's shake). Gameplay never reads any of it, so a
## fight goes the same, only faster to simulate. True in the game and the tests.
static var shown := true


## Whether what `item` draws within `reach` px of its origin can be on screen (the viewport, plus
## World.view_rect()'s usual 96 px margin). Something animated off screen needs no redraw: it is
## drawn again the frame it comes back into view (docs/performance.md, "Redraw on change").
static func on_screen(item: CanvasItem, reach: float = 0.0) -> bool:
	if not item.is_inside_tree():
		return false
	var to_screen := item.get_global_transform_with_canvas()
	return item.get_viewport_rect().grow((reach + 96.0) * to_screen.get_scale().x).has_point(to_screen.origin)


## An effect that is only seen (sparks, arcs, sheets, numbers, rings...): skipped when nothing
## is shown (`shown` off). Warnings that something reads (CellWarning) and the dungeon's own
## layers are not.
static func is_cosmetic(node: Node) -> bool:
	return node is CPUParticles2D or node is ImpactVfx or node is SheetVfx or node is RingVfx or node is BeamVfx \
		or node is SwingVfx or node is SwingMatter or node is FloatingText or node is BloodDrainVfx or node is AfterimageVfx \
		or node is FootprintVfx or node is DeathPiecesVfx or node is BlastVfx or node is ComposedVfx or node is ShockwaveVfx \
		or node is EmoteVfx or node is LightFlash or node is FuseMark or node is LaterMark


## Particles of `scene` at `at`: sparks, chunks, smoke and fire in the air (over the actors);
## dust (DUST) rises from the floor, sorted with the actors (VfxLayer).
static func burst(world: World, scene: PackedScene, at: Vector2, color: Color = Color.WHITE, direction: Vector2 = Vector2.ZERO, size: float = 1.0) -> void:
	var particles := scene.instantiate() as CPUParticles2D
	if Settings.fewer_effects:
		particles.amount = maxi(1, int(particles.amount / 2.0))
	particles.position = at
	if scene == DUST:
		VfxLayer.apply(particles, VfxLayer.Layer.STANDING)
	else:
		particles.z_index = LightField.Z + 2  # sparks shine on their own, over the floor's light
		VfxLayer.apply(particles, VfxLayer.Layer.AIR)
	particles.color = color
	if direction != Vector2.ZERO:
		particles.direction = direction
	if not is_equal_approx(size, 1.0):
		# Bigger by whole times only, so the particles stay whole art pixels (pixel_particles).
		var times := maxf(roundf(size), 1.0)
		particles.scale_amount_min *= times
		particles.scale_amount_max *= times
		particles.initial_velocity_min *= size
		particles.initial_velocity_max *= size
	world.spawn_vfx(particles)


## A flash and sparks flying away from an impact (bigger for a critical hit): the bits of what
## the target is made of (`material`: blood drops, bone chips, sparks off armor...; else sparks
## in `color`), the flash in the hitting `element`'s language (ImpactVfx). A critical hit also
## cuts a cross over the target, in the blow's element (steel for a plain blade).
static func hit(world: World, at: Vector2, direction: Vector2, color: Color = Color.WHITE, big: bool = false, element: VfxElementDef = null, material: ImpactMaterialDef = null) -> void:
	if material:
		world.spawn_vfx(ImpactVfx.sparks(at, direction, material.sparks_element(), big))
	else:
		burst(world, HIT_SPARKS, at, color, direction)
	world.spawn_vfx(ImpactVfx.create(at, direction, color, big, element))
	if big:
		world.spawn_vfx(SheetVfx.play(CRIT_CROSS, at, direction, element if element else VfxElementDef.named(&"physical")))


## The arc of a melee swing (or the streak of a thrust), at the weapon's reach, in its element
## (the hero's: what it carries, ItemLook; steel when none); an enemy's carries the warning rim.
static func swing(attacker: Actor, aim: Vector2, weapon: WeaponDef, duration: float) -> void:
	var hero := attacker is Player
	# The hero's blade swings in what it carries (a katana with an Ember Rune, in fire: ItemLook),
	# a second element adding its bits.
	var element := ItemLook.swing_element(weapon, hero)
	var second := ItemLook.second_element(weapon, hero)
	if not weapon.shows_arc():
		# Claws and bites play their sheet; the hero's overhead smash lands on the floor.
		if hero and weapon.kind == WeaponDef.Kind.MELEE and weapon.attack_animation == WeaponDef.AttackAnimation.SMASH:
			smash(attacker.world, attacker.global_position + aim * (attacker.radius + weapon.reach * 0.8), aim, element, second)
		return
	var reach := attacker.radius + weapon.reach
	var at := attacker.global_position + Vector2(0, -6)
	var danger := attacker.faction != Actor.Faction.PLAYER
	if weapon.slash:
		SwingVfx.slash(attacker.world, weapon.slash, at, aim, reach, element, danger, second, weapon.arc_degrees < 359.0)
		return
	var thrust := weapon.attack_animation == WeaponDef.AttackAnimation.THRUST
	attacker.world.spawn_vfx(SwingVfx.create(at, aim, reach, weapon.arc_degrees, thrust, element, duration, danger, second))


## An overhead blow landing on the floor at `at` (the War Hammer): steel kicks up dust and a few
## sparks; an element bursts there in its own matter (its impact: fire's tongues, frost's
## shards, storm's forks...) and sheds its bits, a `second` one a few of its own.
static func smash(world: World, at: Vector2, aim: Vector2, element: VfxElementDef, second: VfxElementDef = null) -> void:
	dust(world, at + Vector2(0, 4), 1.0)
	# North of the hero (we see his back) it lands behind him, sorted by where it lands
	# (docs/vfx.md 2b); toward us, over him like any blow.
	var layer := VfxLayer.Layer.STANDING if VfxLayer.goes_behind(aim) else VfxLayer.Layer.AIR
	if not SwingMatter.sheds(element):
		world.spawn_vfx(VfxLayer.apply(ImpactVfx.sparks(at, -aim, VfxElementDef.named(&"physical")), layer))
		return
	if element.impact:
		world.spawn_vfx(SheetVfx.play(element.impact, at + Vector2(0, -4), Vector2.UP, element).on_layer(layer))
	else:
		world.spawn_vfx(VfxLayer.apply(BlastVfx.create(at + Vector2(0, -4), 14.0, element), layer))
	if element.emissive:
		world.flash_light(at, element.color(), 70.0)
	var matter := SwingMatter.create(at, aim, 12.0, 8.0, PI * 1.6, false, 0.0, 0.05, 0.0, element, second)
	if matter:
		world.spawn_vfx(VfxLayer.apply(matter, layer))


## A shot of `element` landing (an ice shard cracking, a fireball bursting): the element's
## impact sheet, or a burst in its ramp when its kit has none. `direction`: where it flew.
static func pop(world: World, at: Vector2, element: VfxElementDef, radius: float = 14.0, direction: Vector2 = Vector2.RIGHT) -> void:
	if element.impact:
		world.spawn_vfx(SheetVfx.play(element.impact, at, direction, element))
	else:
		world.spawn_vfx(BlastVfx.create(at, radius, element))
	if element.impact_mark > 0.0 and element.mark.a > 0.0:
		world.add_splat(at, element.mark, element.impact_mark, direction)  # a puddle, a stain
	if element.emissive:
		world.flash_light(at, element.color(), radius * 5.0)
	if element.impact_sound:
		Sfx.play_at(element.impact_sound, at, -6.0)


## A nova of `element` filling `radius` around `at` (Frost Nova, a cold wave): its pieces
## composed around the ring (ComposedVfx), or a ring in its ramp.
static func nova(world: World, at: Vector2, radius: float, element: VfxElementDef) -> void:
	if element and element.pool:
		world.spawn_vfx(GasPoolVfx.create(at, radius, element))  # poison: one pool of gas
		if element.pool_sound:
			Sfx.play_at(element.pool_sound, at, -4.0)
	else:
		world.spawn_vfx(ComposedVfx.ring(at, radius, element))
	if element and element.emissive:
		world.flash_light(at, element.color(), radius * 2.0)


## `element` riding an area drawn in another (a Frost Nova from a staff carrying an Ember Rune:
## SkillDef.effects_for): a sparse ring of its pieces inside the area's edge, or a small pool of
## its gas (poison), never a second whole nova over the first.
static func riding(world: World, at: Vector2, radius: float, element: VfxElementDef) -> void:
	if element == null:
		return
	if element.pool:
		world.spawn_vfx(GasPoolVfx.create(at, radius * 0.45, element))
	elif element.piece:
		world.spawn_vfx(ComposedVfx.ring(at, radius * 0.6, element, false))
	else:
		pop(world, at, element, radius * 0.4, Vector2.UP)


## A sweep of `element` across the front half of a circle (`radius` around `at`, facing
## `facing`): Flame Arc's wall of fire licks, one side to the other. A ring when it has no piece.
static func arc(world: World, at: Vector2, radius: float, facing: Vector2, element: VfxElementDef) -> void:
	world.spawn_vfx(ComposedVfx.arc(at, radius, facing, element))
	if element and element.emissive:
		world.flash_light(at, element.color(), radius * 2.0)


## `element` left along a line (a dash through ice): its pieces one after the other.
static func trail(world: World, from: Vector2, to: Vector2, element: VfxElementDef, duration: float = 0.15) -> void:
	var line := ComposedVfx.line(from, to, element, duration)
	if line:
		world.spawn_vfx(line)


## A ripple running through the picture around a blast.
static func shockwave(world: World, at: Vector2, reach: float, strength: float = 6.0) -> void:
	world.spawn_vfx(ShockwaveVfx.create(at, reach, strength))


## Chunks in the monster's color plus a puff of smoke: a plain blow's death (an element's own
## death, `look`, may have its pieces instead: DeathFx).
static func death(world: World, at: Vector2, color: Color, look: DeathLookDef = null) -> void:
	if look and not look.chunks:
		return
	burst(world, DEATH_CHUNKS, at, color)
	world.spawn_vfx(SheetVfx.create(SMOKE_SHEET, at + Vector2(0, -12), 0.0, 2.0, 14.0))


## Puff of smoke (something appears or vanishes).
static func puff(world: World, at: Vector2) -> void:
	world.spawn_vfx(SheetVfx.create(SMOKE_SHEET, at + Vector2(0, -12), 0.0, 2.0, 14.0))


## A chain of explosions over a big body, for boss deaths.
static func boss_death(world: World, at: Vector2, size: float) -> void:
	for i in 6:
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(0.0, size)
		var delay := 0.12 * i
		var world_ref: WeakRef = weakref(world)  # (the timer outlives a freed world: see Effect.apply_all())
		world.get_tree().create_timer(delay, false).timeout.connect(func() -> void:
			var where := world_ref.get_ref() as World
			if where:
				explosion(where, at + offset, 50.0 + 12.0 * i))


## A blast of `element` (fire when none: barrels, bombs): its explosion sheet (a ball of fire,
## the ground erupting) or a burst in its ramp, a ripple through the picture, its mark on the
## floor (a scorch, disturbed earth). `pieces` off: no ring of its pieces at the edge (a boss's
## stomp is dust and rubble, not a ring of rock spikes).
static func explosion(world: World, at: Vector2, radius: float, element: VfxElementDef = null, pieces: bool = true) -> void:
	if element == null:
		element = VfxElementDef.named(&"fire")
	var size := clampf(radius / 80.0, 0.6, 1.6)
	if element.mark.a > 0.0:
		world.add_splat(at, element.mark, clampf(radius / 45.0, 0.8, 2.5))
	if element.emissive:
		world.flash_light(at, element.shade(0.5), radius * 3.0)
	if element.blast:
		# Its own explosion sheet at 2x (its smoke, embers, chunks and dust are drawn in it);
		# a blast wider than the sheet gets a ring of its pieces at the edge, never a stretch.
		world.spawn_vfx(SheetVfx.play(element.blast, at, Vector2.RIGHT, element))
		var reach := element.blast.frame_size().x * element.blast.texel * 0.5
		if pieces and element.piece and radius > reach * 1.2:
			world.spawn_vfx(ComposedVfx.ring(at, radius, element, false))
	else:
		world.spawn_vfx(BlastVfx.create(at, radius * 1.05, element))
		if element.id == &"fire":
			burst(world, FIRE, at, Color.WHITE, Vector2.ZERO, size * 0.7)
			burst(world, SMOKE, at, Color.WHITE, Vector2.ZERO, size)
		else:
			burst(world, DEATH_CHUNKS, at, element.color(), Vector2.ZERO, size)
			if element.residue.a > 0.0:
				burst(world, DUST, at, Color(element.residue, 1.0), Vector2.ZERO, size * 1.6)
	shockwave(world, at, radius * 1.4, clampf(radius / 12.0, 4.0, 9.0))
	Sfx.play_at(Sfx.bank.explosion, at)
	if world.player and world.player.global_position.distance_to(at) < 600.0:
		Events.screen_shake.emit(0.45 * size)


static func sparkles(world: World, at: Vector2, color: Color) -> void:
	burst(world, SPARKLES, at, color)


## A sigil of light on the ground (heals, buffs, a skill learned, a level up, a boss's room
## sealing): holy's ring drawing itself, rays rising, glints (data/vfx/sheets/holy_sigil.tres).
## In `element`'s ramp when given, holy's for the gold of rewards, else a ramp of `color`'s hue
## (the green of a potion, a buff's own color).
static func magic(world: World, at: Vector2, color: Color, element: VfxElementDef = null) -> void:
	var look := element
	if look == null:
		look = VfxElementDef.named(&"holy") if color.is_equal_approx(Palette.GOLD) else VfxElementDef.or_color(null, color)
	world.spawn_vfx(SheetVfx.play(SIGIL, at, Vector2.RIGHT, look))
	world.flash_light(at, look.color(), 200.0)


## "!" bubble above a monster that just noticed the player.
static func alert(world: World, at: Vector2) -> void:
	world.spawn_vfx(EmoteVfx.create(ALERT_EMOTE, at))


static func dust(world: World, at: Vector2, size: float = 1.0) -> void:
	burst(world, DUST, at, Color.WHITE, Vector2.ZERO, size)


## Dust kicked up along a rush from `from` to `to` (a charge, a leap): puffs at the feet, one
## after the other over `duration` seconds.
static func dust_trail(world: World, from: Vector2, to: Vector2, duration: float) -> void:
	var count := clampi(roundi(from.distance_to(to) / 40.0), 1, 6)
	for i in count:
		var t := (i + 0.5) / count
		var at := from.lerp(to, t) + Vector2(0, 8)
		var world_ref: WeakRef = weakref(world)  # (the timer outlives a freed world: see Effect.apply_all())
		world.get_tree().create_timer(duration * t, false).timeout.connect(func() -> void:
			var where := world_ref.get_ref() as World
			if where:
				dust(where, at, 1.0))
