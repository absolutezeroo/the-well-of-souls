class_name Combat
## Shared combat rules. Every damage number in the game goes through here.

## The core numbers: crit, variance, armor, the cooldown cap (data/combat/combat_rules.tres).
const RULES: CombatRulesDef = preload("res://data/combat/combat_rules.tres")
## How far a prop is reached past its middle (crates, pots: a blow touching their side breaks them).
const PROP_REACH := Prop.SIZE * 0.4

## Rolls outside any floor (a hit with no world: tools, a few tests).
static var _loose := RandomNumberGenerator.new()


## A hit of about `base_amount` (the variance), maybe a critical one. Its rolls come from the
## floor's combat dice (World.combat_rng: the same seed, the same fight), `rng` when given (a shot
## whose shooter is gone), else from loose dice.
static func make_hit(base_amount: int, crit_chance: float, source: Actor, rng: RandomNumberGenerator = null) -> HitInfo:
	var dice := rng if rng else dice_of(source)
	var hit := HitInfo.new()
	hit.source = source
	var amount := float(base_amount) * dice.randf_range(1.0 - RULES.damage_variance, 1.0 + RULES.damage_variance)
	if dice.randf() < crit_chance:
		hit.is_crit = true
		amount *= RULES.crit_multiplier + (source.crit_damage_bonus if source else 0.0)
	hit.amount = maxi(1, roundi(amount))
	return hit


## The dice an actor's hits roll with: its floor's (World.combat_rng), else loose ones.
static func dice_of(source: Actor) -> RandomNumberGenerator:
	if source and is_instance_valid(source) and source.world and is_instance_valid(source.world):
		return source.world.combat_rng
	return _loose


static func make_hit_from(attacker: Actor, base_amount: int) -> HitInfo:
	return make_hit(base_amount, attacker.get_stats().crit_chance, attacker)


## Damage from a side effect (burn, thorns...): no crit, no variance, no on-hit perks.
static func make_secondary_hit(source: Actor, amount: int) -> HitInfo:
	var hit := HitInfo.new()
	hit.source = source
	hit.amount = maxi(1, amount)
	hit.is_secondary = true
	return hit


## A damage-over-time tick (see HitInfo.is_tick).
static func make_tick(source: Actor, amount: int) -> HitInfo:
	var hit := make_secondary_hit(source, amount)
	hit.is_tick = true
	return hit


## Armor with diminishing returns: a hit of A against D armor deals A x A / (A + W x D), W being
## CombatRulesDef.armor_weight (1). Against a hit much bigger than the armor it is close to
## removing D points (35 vs 5: 30.6); against a hit about the armor's size it halves it (20 vs 20:
## 10); it never makes a hit harmless (20 vs 36: 7, where "D points off" gave 1). At least 1.
## Negative armor (a curse) adds its points instead.
static func mitigate(amount: int, defense: int) -> int:
	if defense <= 0 or amount <= 0:
		return maxi(1, amount - defense)
	return maxi(1, roundi(float(amount) * amount / (amount + RULES.armor_weight * defense)))


## The smallest hit that deals at least `damage` through `defense` armor (mitigate's inverse).
static func hit_for(damage: int, defense: int) -> int:
	var amount := maxi(damage, 1)
	while mitigate(amount, defense) < damage:
		amount += 1
	return amount


## Hits every enemy of the attacker inside the arc of `blow` (drawn toward its facing, swept to
## its exact aim: Blow).
static func melee_strike(attacker: Actor, blow: Blow, weapon: WeaponDef) -> void:
	var world := attacker.world
	var reach := attacker.radius + weapon.reach
	var half_arc := deg_to_rad(weapon.arc_degrees) * 0.5

	for target in world.get_hostiles(attacker.faction):
		var to_target := target.global_position - attacker.global_position
		var distance := to_target.length()
		if distance > reach + target.radius:
			continue
		# Targets pressed against the attacker are always hit, whatever the angle.
		var touching := distance <= attacker.radius + target.radius + 4.0
		if not touching and not blow.in_arc(target.global_position, half_arc):
			continue
		if not world.has_line_of_sight(attacker.global_position, target.global_position):
			continue
		var hit := make_hit_from(attacker, attacker.get_power())
		hit.knockback = to_target.normalized() * weapon.knockback
		hit.origin = attacker.global_position
		hit.sound = weapon.hit_sound
		hit.status = weapon.on_hit
		# The hero's hits land in what the weapon carries for sure (docs/vfx.md, "Elemental
		# attacks"); a rune that works by chance says so itself (BurnOnHitPassive).
		hit.element = ItemLook.hit_element(weapon) if attacker.strikes_in_carried_elements() else weapon.element
		target.take_hit(hit)

	# Crates, pots, barrels in the arc break too.
	var from := attacker.global_position
	break_props(world, attacker, func(prop: Prop) -> bool:
		return prop.global_position.distance_to(from) <= reach + PROP_REACH and blow.in_arc(prop.global_position, half_arc + 0.3))


## Hits every enemy of the attacker inside a circle. `secondary`: see HitInfo.is_secondary.
## `element`: what the blow is made of (its hits flash in its language).
static func damage_area(world: World, attacker: Actor, center: Vector2, radius: float, base_amount: int, knockback: float, secondary: bool = false, status: OnHitStatus = null, element: VfxElementDef = null) -> void:
	for target in world.get_hostiles(attacker.faction):
		_hit_in_circle(attacker, target, center, radius, base_amount, knockback, secondary, status, element)
	hit_props(world, attacker, center, radius)


## A circle `offset` out along `blow` (a charged crescent, a hammer's slam ahead): drawn toward
## its facing, it hits whatever the circle covers swept from there to the exact aim (Blow).
static func damage_blow_area(world: World, attacker: Actor, blow: Blow, offset: float, radius: float, base_amount: int, knockback: float, status: OnHitStatus = null, element: VfxElementDef = null) -> void:
	for target in world.get_hostiles(attacker.faction):
		var center := blow.origin + blow.toward(target.global_position) * offset
		_hit_in_circle(attacker, target, center, radius, base_amount, knockback, false, status, element)
	break_props(world, attacker, func(prop: Prop) -> bool:
		return prop.global_position.distance_to(blow.origin + blow.toward(prop.global_position) * offset) <= radius + PROP_REACH)


static func _hit_in_circle(attacker: Actor, target: Actor, center: Vector2, radius: float, base_amount: int, knockback: float, secondary: bool, status: OnHitStatus, element: VfxElementDef) -> void:
	var offset := target.global_position - center
	if offset.length() > radius + target.radius:
		return
	var hit := make_hit_from(attacker, base_amount)
	hit.knockback = offset.normalized() * knockback
	hit.origin = attacker.global_position if is_instance_valid(attacker) else center
	hit.is_secondary = secondary
	hit.status = status
	hit.element = element
	target.take_hit(hit)


## Hits every enemy of the attacker close to the segment from `from` to `to` (dash strikes).
static func damage_segment(world: World, attacker: Actor, from: Vector2, to: Vector2, width: float, base_amount: int, knockback: float, status: OnHitStatus = null, element: VfxElementDef = null) -> void:
	var direction := from.direction_to(to) if from != to else Vector2.RIGHT
	for target in world.get_hostiles(attacker.faction):
		var closest := Geometry2D.get_closest_point_to_segment(target.global_position, from, to)
		if closest.distance_to(target.global_position) > width + target.radius:
			continue
		var hit := make_hit_from(attacker, base_amount)
		hit.knockback = direction.orthogonal() * signf(direction.cross(target.global_position - from)) * knockback
		hit.origin = from
		hit.status = status
		hit.element = element
		target.take_hit(hit)
	break_props(world, attacker, func(prop: Prop) -> bool:
		return Geometry2D.get_closest_point_to_segment(prop.global_position, from, to).distance_to(prop.global_position) <= width + PROP_REACH)


## A thrust `distance` long along `blow` without moving (the lance's long thrust), stopping short
## of walls: drawn toward its facing, it cuts whatever the segment covers swept from there to the
## exact aim (Blow).
static func damage_blow_segment(world: World, attacker: Actor, blow: Blow, distance: float, width: float, base_amount: int, knockback: float, status: OnHitStatus = null, element: VfxElementDef = null) -> void:
	for target in world.get_hostiles(attacker.faction):
		var direction := blow.toward(target.global_position)
		var to := blow.origin + direction * clear_length(world, blow.origin, direction, distance, attacker.radius)
		var closest := Geometry2D.get_closest_point_to_segment(target.global_position, blow.origin, to)
		if closest.distance_to(target.global_position) > width + target.radius:
			continue
		var hit := make_hit_from(attacker, base_amount)
		hit.knockback = direction.orthogonal() * signf(direction.cross(target.global_position - blow.origin)) * knockback
		hit.origin = blow.origin
		hit.status = status
		hit.element = element
		target.take_hit(hit)
	break_props(world, attacker, func(prop: Prop) -> bool:
		var direction := blow.toward(prop.global_position)
		var to := blow.origin + direction * clear_length(world, blow.origin, direction, distance, attacker.radius)
		return Geometry2D.get_closest_point_to_segment(prop.global_position, blow.origin, to).distance_to(prop.global_position) <= width + PROP_REACH)


## How far from `from` along `direction` (up to `distance`) before a wall, keeping `margin` off it.
static func clear_length(world: World, from: Vector2, direction: Vector2, distance: float, margin: float) -> float:
	var query := PhysicsRayQueryParameters2D.create(from, from + direction * distance, Layers.WORLD)
	var wall := world.get_world_2d().direct_space_state.intersect_ray(query)
	if wall.is_empty():
		return distance
	return maxf(from.distance_to(wall.position) - margin - 2.0, 0.0)


## Breaks the props inside a circle.
static func hit_props(world: World, source: Actor, center: Vector2, radius: float) -> void:
	break_props(world, source, func(prop: Prop) -> bool: return prop.global_position.distance_to(center) <= radius + PROP_REACH)


## Strikes every breakable prop for which `reached` (Prop -> bool) says yes, once, in `source`'s
## name. A prop counts blows, not damage (Prop.take_hit), so the hit carries none: every blow,
## a weapon's swing as a blast's, breaks it the same.
static func break_props(world: World, source: Actor, reached: Callable) -> void:
	for prop in world.get_breakable_props():
		if reached.call(prop):
			var hit := HitInfo.new()
			hit.source = source
			prop.take_hit(hit)


## An explosion that hurts everyone around, friend or foe, and breaks props
## (explosive barrels set each other off). `source` gets the credit for kills.
static func blast(world: World, center: Vector2, radius: float, amount: int, knockback: float, source: Actor = null, status: OnHitStatus = null) -> void:
	for target in world.get_actors():
		var offset := target.global_position - center
		if offset.length() > radius + target.radius:
			continue
		var hit := make_secondary_hit(source, amount)
		hit.knockback = offset.normalized() * knockback
		hit.status = status
		hit.cause = &"blast"
		target.take_hit(hit)
	hit_props(world, source, center, radius)


## A warning on the ground around `source` (FuseMark: the blast's whole area, filling up until it
## lands, following `source` while it moves) and its sound, then after `fuse` seconds (never
## under the fairness floor: CombatRulesDef.blast_warning()) a blast that hurts and pushes away
## its enemies only (a boss throwing the hero off).
static func shockwave(world: World, source: Actor, radius: float, amount: int, knockback: float, fuse: float) -> void:
	fuse = RULES.blast_warning(fuse)
	world.spawn_vfx(FuseMark.create(source.global_position, radius, fuse, source))
	Sfx.play_warning(source.global_position)
	var floor_id := world.floor_id
	# (Weak references: the timer outlives a freed world or boss; see Effect.apply_all().)
	var world_ref: WeakRef = weakref(world)
	var source_ref: WeakRef = weakref(source)
	world.get_tree().create_timer(fuse, false).timeout.connect(func() -> void:
		var home := world_ref.get_ref() as World
		var boss := source_ref.get_ref() as Actor
		if home == null or home.floor_id != floor_id or boss == null or boss.is_dead:
			return
		if not home.is_inside_tree():
			return  # its floor waits out of the tree (the hero is at the Threshold): it fizzles
		var center := boss.global_position
		# A stomp: the ground bursts in dust and rubble whatever the boss is made of.
		Vfx.explosion(home, center, radius, VfxElementDef.named(&"earth"), false)
		Events.screen_shake.emit(0.5)
		for target in home.get_hostiles(boss.faction):
			var offset := target.global_position - center
			if offset.length() > radius + target.radius:
				continue
			var hit := make_secondary_hit(boss, amount)
			hit.knockback = (offset.normalized() if offset != Vector2.ZERO else Vector2.DOWN) * knockback
			hit.cause = &"shockwave"  # a boss answering a hero who struck too often (RunFacts)
			target.take_hit(hit)
		hit_props(home, boss, center, radius))


## A warning on the ground (FuseMark: the blast's whole area, until it lands) and its sound,
## then after `fuse` seconds (never under the fairness floor: CombatRulesDef.blast_warning()) a
## blast (see blast()). `fx`: a sheet of square frames to play instead of the usual explosion;
## `element`: its nova instead (a frost skull bursting into a ring of ice).
static func delayed_blast(world: World, center: Vector2, radius: float, amount: int, fuse: float, fx: Texture2D = null, status: OnHitStatus = null, element: VfxElementDef = null) -> void:
	fuse = RULES.blast_warning(fuse)
	world.spawn_vfx(FuseMark.create(center, radius, fuse))
	Sfx.play_warning(center)
	var floor_id := world.floor_id
	var via := Actor.heal_source  # who set it off: its hits are credited to it (HitInfo.via)
	var world_ref: WeakRef = weakref(world)  # (the timer outlives a freed world: see Effect.apply_all())
	world.get_tree().create_timer(fuse, false).timeout.connect(func() -> void:
		var home := world_ref.get_ref() as World
		if home == null or home.floor_id != floor_id:
			return  # the hero took the stairs meanwhile
		if not home.is_inside_tree():
			return  # its floor waits out of the tree (the hero is at the Threshold): it fizzles
		if element:
			Vfx.nova(home, center, radius, element)
			Sfx.play_at(Sfx.bank.explosion, center, -4.0)
		elif fx:
			home.spawn_vfx(SheetVfx.create(fx, center, 0.0, radius * 2.0 / fx.get_height()))
			Sfx.play_at(Sfx.bank.explosion, center, -4.0)
		else:
			Vfx.explosion(home, center, radius)
		Actor.with_source(via, func() -> void:
			blast(home, center, radius, amount, RULES.delayed_blast_knockback, null, status)))


static func spec_from_weapon(attacker: Actor, weapon: WeaponDef) -> ProjectileSpec:
	var spec := ProjectileSpec.new()
	spec.damage = maxi(1, roundi(attacker.get_power() * weapon.projectile_damage))
	spec.glow = weapon.projectile_glow
	spec.speed = weapon.projectile_speed
	spec.radius = weapon.projectile_radius
	spec.max_distance = weapon.reach
	spec.count = weapon.projectile_count
	spec.spread_degrees = weapon.spread_degrees
	spec.pierce = weapon.pierce
	spec.knockback = weapon.knockback
	spec.color = weapon.element.color() if weapon.element else weapon.color
	spec.texture = weapon.projectile_texture
	spec.texture_frames = weapon.projectile_frames
	spec.sheet = weapon.projectile_sheet
	spec.element = weapon.element
	spec.status = weapon.on_hit
	var carried := attacker.strikes_in_carried_elements()
	if carried and weapon.element == null:
		# A plain thing (an arrow, a star) from a weapon carrying an element flies in it (flames
		# riding an arrow, an ember trail) and lands in it when the hit is elemental for sure.
		spec.look_element = ItemLook.swing_element(weapon, true)
		spec.second_element = ItemLook.second_element(weapon, true)
		spec.hit_element = ItemLook.hit_element(weapon)
	elif carried:
		# A magic shot (the Spark Wand's) stays itself; another element the weapon carries (an
		# Ember Rune) rides its back. Its hits land in its own element.
		spec.look_element = ItemLook.second_element(weapon, true)
	return spec
