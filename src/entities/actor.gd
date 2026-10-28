class_name Actor
extends CharacterBody2D
## Base class for everything that moves and fights: the player and monsters.
## Handles stats, health, attacking, knockback, dashing, perks, statuses and falls.
## Subclasses decide where to go (_get_desired_velocity) and what to do (_think).
## How it looks is the job of the ActorRig child ("Rig"): this script only tells it what happens.
## Composed of components that each keep one thing: Equipment, SkillSet, PerkSet, StatusSet,
## SustainMeter, TimedBonuses (src/components/); what a blow taken shows is HitFeedback's, its
## ward's look WardVfx's and a body drawn without a sprite BodySketch's (src/vfx/).

signal health_changed(current: int, maximum: int)
signal stats_changed
signal died(actor: Actor)
## HP actually restored by heal(), and who did it (see heal_source). A measuring hook for the
## balance tools (tools/balance/), so they can tell a Leech rune's healing from Vampirism's or a
## potion's; the HuntTracker counts the hero's heals during a boss fight (UnhealedDeed). Changes
## nothing.
signal healed(amount: int, source: StringName)

## What is acting right now ("perk:vampirism", "rune:leech_rune", "skill:smite", "item:health_potion"...),
## set for the length of a call by PerkSet, SkillSet and ConsumableDef; empty otherwise. Read only by
## heal() to fill the `healed` signal (balance tools) and stamped on the hits made meanwhile
## (HitInfo.via: the gameplay statistics). Never affects gameplay.
static var heal_source: StringName = &""


## Runs `action` with heal_source set to `tag`, then puts back what was there (a skill inside a
## perk's call...). Effects that come later (Effect.delay, a fuse) carry the tag they were set
## off under through here, so their hits and heals are credited to the right source.
static func with_source(tag: StringName, action: Callable) -> void:
	var outer := heal_source
	heal_source = tag
	action.call()
	heal_source = outer

enum Faction { PLAYER, MONSTER }

const KNOCKBACK_FRICTION := 1400.0
const FLASH_TIME := 0.1
## Pixel art is 16x16 and drawn at 2x.
const SPRITE_SCALE := 2.0
const AFTERIMAGE_INTERVAL := 0.03
## Seconds of falling into a hole before it counts.
const FALL_TIME := 0.5

var faction: Faction = Faction.MONSTER
## Debug god mode (DebugPanel): nothing hurts.
var invincible := false
## Multiplies every heal (the Blood Pact node: more Health, weaker heals).
var healing_scale := 1.0
## Added to the critical hit multiplier (an oath: Combat.make_hit()).
var crit_damage_bonus := 0.0
## How fast skill cooldowns run (a boss in a later phase: faster).
var cooldown_speed := 1.0
## The last hit taken (how it was finished: a crit...). Null before any.
var last_hit: HitInfo
## A ward (AllyEffect): damage soaked up before HP, for a while.
var ward := 0
var _ward_time := 0.0
var world: World
var display_name := "Actor"
## Animations of the body (see ActorRig). Without frames, a simple shape is drawn.
var frames: SpriteFrames
var frames_offset := Vector2(0, -8)
## Height of the sprite above the feet, in world pixels (damage numbers start there).
var head_height := 34.0
## Fallback drawing when there is no sprite.
var glyph := ""
var body_color := Color.WHITE
var radius := 12.0
## Monsters disappear when they die; the player stays on screen for the game over.
var free_on_death := true
## Flying actors (bats, ghosts...) don't fall into holes or wade in quicksand.
var flies := false
## Dropping into a hole (see fall()).
var is_falling := false
## The fall's slide and shrink, then _on_fell() (killed by cancel_fall()).
var _fall_tween: Tween
## Who hit this actor last: credited if it falls into a hole.
var last_attacker: Actor
## What killed it, for the run history ("Skeleton", "a fall"...). Empty while alive.
var killed_by := ""
## How it died, in words the dialogue's conditions know (RunFacts.CAUSES: "monster", "trap",
## "fall", "burn"...). Empty while alive; may be set just before dying (giving up).
var death_cause: StringName = &""

var base_stats := StatBlock.new()
var equipment := Equipment.new()
var skills := SkillSet.new()
var perks := PerkSet.new()
var statuses := StatusSet.new()
## Its shadow on the floor (ActorShadow: drawn one step down, so a crowd's shadows batch).
var shadow: ActorShadow
## Draws the statuses on the body (StatusFx).
var status_fx: StatusFx
## Healing from "per hit" and "per kill" perks (see sustain_heal()).
var sustain := SustainMeter.new()
## Stat bonuses for a while (elixirs, war cries...: add_timed_bonus()).
var timed_bonuses := TimedBonuses.new()
var hp := 1
var facing := Vector2.RIGHT
var is_dead := false

var _stats_cache: StatBlock
var _attack_cooldown := 0.0
var _invulnerable_time := 0.0
var _knockback := Vector2.ZERO
var _dash_velocity := Vector2.ZERO
var _dash_time := 0.0
var _flash_time := 0.0
## What the last _draw() showed (_redraw_if_changed()): a ward on the body, the shadow's size.
var _drawn_ward := false
var _drawn_radius := -1.0
var _afterimage_timer := 0.0
## What the current dash is made of: its afterimages take its color (steel when null).
var _dash_element: VfxElementDef

## Visual body (sprite, hand, weapon, animations). Null for actors without sprite.
@onready var rig: ActorRig = get_node_or_null("Rig")


func _init() -> void:
	motion_mode = MOTION_MODE_FLOATING
	equipment.changed.connect(invalidate_stats)
	perks.changed.connect(invalidate_stats)


func _ready() -> void:
	# Its shadow, one step down in the draw order (ActorShadow: a crowd's shadows batch).
	shadow = ActorShadow.new()
	add_child(shadow)
	move_child(shadow, 0)
	shadow.fit(_feet_y(), radius)
	# What its statuses look like (flames, bubbles, frost), drawn over the body.
	status_fx = StatusFx.new(self)
	add_child(status_fx)
	status_fx.visible = false
	status_fx.set_process(false)
	if rig == null:
		return
	rig.visible = frames != null
	rig.position = Vector2(0, _feet_y())
	rig.setup(frames, frames_offset)
	_refresh_look()
	equipment.changed.connect(_refresh_look)


## Weapon in hand and worn armor, from the equipment.
func _refresh_look() -> void:
	rig.carries_weapon = _shows_gear()
	rig.wear(equipment)


# --- Stats -------------------------------------------------------------------

func get_stats() -> StatBlock:
	if _stats_cache == null:
		_stats_cache = timed_bonuses.add_to(base_stats.plus(equipment.total_bonuses()).plus(perks.total_bonuses()))
	return _stats_cache


## Call whenever base stats, equipment or buffs change.
func invalidate_stats() -> void:
	_stats_cache = null
	hp = mini(hp, get_max_hp())
	stats_changed.emit()
	health_changed.emit(hp, get_max_hp())


func get_max_hp() -> int:
	return maxi(1, get_stats().max_hp)


## 0 = pushed by every hit, 1 = immovable (see MonsterDef.knockback_resistance).
func get_knockback_resistance() -> float:
	return 0.0


func get_move_speed() -> float:
	return maxf(get_stats().move_speed * statuses.speed_multiplier(), 20.0)


func get_weapon() -> WeaponDef:
	return equipment.get_item(EquipmentDef.Slot.WEAPON) as WeaponDef


## Base damage of skills: power boosted by skill power.
func get_skill_power() -> float:
	return get_power() * maxf(1.0 + get_stats().skill_power, 0.1)


## Seconds between two attacks with `weapon`, after attack speed bonuses.
func get_attack_cooldown(weapon: WeaponDef) -> float:
	return weapon.cooldown / maxf(1.0 + get_stats().attack_speed, 0.25)


## Base damage of this actor's attacks: weapon damage + attack stat.
func get_power() -> int:
	var weapon := get_weapon()
	return (weapon.damage if weapon else 1) + get_stats().attack


## The same bonus again (a second elixir, a war cry recast) refreshes it instead of stacking.
func add_timed_bonus(bonus: StatBlock, duration: float) -> void:
	if timed_bonuses.add(bonus, duration):
		invalidate_stats()


func set_body_radius(value: float) -> void:
	radius = value
	var shape := CircleShape2D.new()
	shape.radius = value
	($CollisionShape2D as CollisionShape2D).shape = shape


func is_hostile_to(other: Actor) -> bool:
	return other != null and other.faction != faction


# --- Actions -----------------------------------------------------------------

func can_attack() -> bool:
	return not is_dead and not is_falling and _attack_cooldown <= 0.0 and get_weapon() != null


func attack(direction: Vector2) -> bool:
	if not can_attack():
		return false
	var weapon := get_weapon()
	if direction != Vector2.ZERO:
		facing = direction.normalized()
	_attack_cooldown = get_attack_cooldown(weapon)
	Sfx.play_at(weapon.attack_sound, global_position)
	# A melee blow is struck in the body's four directions, its arc and sheet drawn that way and
	# its zone swept to the exact aim (Blow); a shot flies at the exact aim.
	var blow := Blow.of_weapon(global_position, facing, weapon)
	if rig:
		rig.play_attack(weapon, blow.facing, _attack_cooldown)
	Vfx.swing(self, blow.facing, weapon, minf(_attack_cooldown * 0.45, 0.15))
	if weapon.kind == WeaponDef.Kind.MELEE:
		Combat.melee_strike(self, blow, weapon)
	else:
		world.fire_projectiles(self, facing, Combat.spec_from_weapon(self, weapon), shot_origin(facing))
	_on_attacked(weapon)
	return true


## Where its shots toward `direction` start (World.fire_projectiles' `from`); INF: its center.
func shot_origin(_direction: Vector2) -> Vector2:
	return Vector2.INF


## After an attack goes out (the hero's camera recoils).
func _on_attacked(_weapon: WeaponDef) -> void:
	pass


func start_dash(dash_velocity: Vector2, duration: float, invulnerable: bool, element: VfxElementDef = null) -> void:
	_dash_velocity = dash_velocity
	_dash_time = duration
	_afterimage_timer = 0.0
	_dash_element = element
	Vfx.dust(world, global_position + Vector2(0, _feet_y()), 1.4)
	if invulnerable:
		_invulnerable_time = maxf(_invulnerable_time, duration + 0.05)
	perks.on_dash(self)


func is_dashing() -> bool:
	return _dash_time > 0.0


## Direction the actor is currently trying to move in (zero when standing still).
func get_move_direction() -> Vector2:
	return Vector2.ZERO


# --- Health ------------------------------------------------------------------

func take_hit(hit: HitInfo) -> void:
	if is_dead or invincible or (_invulnerable_time > 0.0 and not hit.unavoidable):
		if not is_dead and not invincible and is_dashing():
			Events.hit_dodged.emit(self, hit)  # (the gameplay statistics: rolls that saved a hit)
		return
	# Perks of the attacker can change the hit (direct hits only, see HitInfo.is_secondary).
	var attacker := hit.source if is_instance_valid(hit.source) and not hit.is_secondary else null
	if attacker:
		attacker.perks.modify_outgoing_hit(attacker, self, hit)
	last_hit = hit
	var damage := _incoming_damage(hit, Combat.mitigate(hit.amount, get_stats().defense))
	damage = DebugCheats.scale_damage(hit, self, damage)  # the debug panel's damage and armor steps
	if ward > 0 and damage > 0:
		var soaked := mini(ward, damage)
		ward -= soaked
		damage -= soaked
		if ward <= 0:
			Vfx.pop(world, global_position + Vector2(0, -radius), VfxElementDef.named(&"spirit"), 16.0, Vector2.UP)  # it breaks
	hp = maxi(hp - damage, 0)
	_knockback += hit.knockback * (1.0 - get_knockback_resistance())
	_flash_time = FLASH_TIME
	if rig:
		rig.play_hurt(hit.element)
	HitFeedback.play(self, hit, damage, _hit_spark_color(hit), _hurt_sound(hit) if not hit.is_secondary else null, _impact_material())
	health_changed.emit(hp, get_max_hp())
	Events.actor_damaged.emit(self, hit, damage)
	if is_instance_valid(hit.source) and hit.source != self:
		last_attacker = hit.source
	if hit.status:
		# Credited to whoever caused it, secondary hits too (a burn from a blast kills for the hero).
		hit.status.apply_to(self, hit.source if is_instance_valid(hit.source) else null)
	# Lethal or not is decided by this hit alone: side effects below (thorns killing the attacker,
	# a level up, a heal on kill) must not pull the actor back from 0 HP.
	var lethal := hp <= 0
	if attacker:
		attacker.perks.on_hit_dealt(attacker, self, hit, damage)
	_on_damaged(hit, damage)
	perks.on_damaged(self, hit, damage)
	if lethal and not is_dead:
		hp = 0
		if not perks.prevent_death(self):
			die(hit.source)


## A ward soaking up `amount` damage for `duration` seconds (a new one replaces a weaker one).
func add_ward(amount: int, duration: float) -> void:
	ward = maxi(ward, amount)
	_ward_time = maxf(_ward_time, duration)


## Returns how much was actually healed.
func heal(amount: int) -> int:
	if is_dead:
		return 0
	var before := hp
	if healing_scale != 1.0 and amount > 0:
		amount = maxi(1, roundi(amount * healing_scale))
	hp = mini(hp + amount, get_max_hp())
	health_changed.emit(hp, get_max_hp())
	if hp > before:
		healed.emit(hp - before, heal_source)  # balance tools and deeds (see `healed`)
	return hp - before


## Healing from a "per hit", "per kill" or "per skill" perk (lifesteal, heal on kill, the Blood
## family...): fractions add up and are paid in whole points, and the hero's are limited by
## SustainRules (one budget for all of them). Returns how much was actually healed.
func sustain_heal(amount: float) -> int:
	if is_dead:
		return 0
	var max_hp := get_max_hp()
	var now := float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second
	var boss_fight := world != null and world.is_boss_fight()
	var whole := sustain.take(amount, max_hp, max_hp - hp, now, _sustain_rules(), boss_fight)
	return heal(whole) if whole > 0 else 0


## Limits on sustain_heal() (null: none, only whole points).
func _sustain_rules() -> SustainRules:
	return null


## Killing this actor may feed "on kill" heals (Vampirism, the Blood family...).
func can_heal_killer() -> bool:
	return true


func die(killer: Actor) -> void:
	if is_dead:
		return
	is_dead = true
	if killed_by.is_empty():  # a cause may be set just before (a fall, giving up)
		killed_by = _death_cause(killer)
	if death_cause == &"":
		death_cause = cause_of_death(killer)
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	Sfx.play_at(_death_sound(), global_position)
	if rig:
		rig.play_death()
		rig.modulate = _body_modulate()
	var valid_killer := killer if is_instance_valid(killer) else null
	perks.on_died(self)
	_on_died(valid_killer)
	if valid_killer:
		valid_killer.perks.on_kill(valid_killer, self)  # still burning, slowed...: perks may care
	statuses.clear()
	died.emit(self)
	if free_on_death:
		if rig and rig.visible:
			# In the element of the blow that killed it: ash, shards, a puddle... (DeathFx).
			DeathFx.play(self, killing_element(), queue_free)
		else:
			var tween := create_tween()
			tween.tween_property(self, "modulate:a", 0.0, 0.25)
			tween.tween_callback(queue_free)
	queue_redraw()


## What the blow that killed it was made of (a burn's ticks: fire), null for a plain one or a
## death without a blow (DeathLookDef: ash, shards, a puddle...).
func killing_element() -> VfxElementDef:
	return last_hit.element if last_hit and hp <= 0 else null


# --- Holes ------------------------------------------------------------------

## Standing on the floor: can fall into holes, sink in quicksand, set off cracked floor.
func is_grounded() -> bool:
	return not flies and not is_dashing() and not is_falling and not is_dead


## Drops into the hole under the actor; _on_fell() decides what happens next.
func fall(pit: PitDef) -> void:
	if is_falling or is_dead:
		return
	is_falling = true
	velocity = Vector2.ZERO
	_knockback = Vector2.ZERO
	_dash_time = 0.0
	Sfx.play_world(Sfx.bank.fall, global_position)
	var into := world.map.cell_to_world(world.map.world_to_cell(global_position))
	_fall_tween = create_tween().set_parallel()
	_fall_tween.tween_property(self, "global_position", global_position.lerp(into, 0.6), FALL_TIME)
	if rig:
		_fall_tween.tween_property(rig, "scale", Vector2.ZERO, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_fall_tween.tween_property(rig, "rotation", TAU * 0.75, FALL_TIME)
	_fall_tween.chain().tween_callback(_on_fell.bind(pit))
	queue_redraw()


## A fall cut short: the actor was taken somewhere else meanwhile (a new floor, the Deeps and
## back). The hole it was dropping into is no longer under it: no landing (_on_fell()), no
## slide toward the old hole, on its feet where it was put.
func cancel_fall() -> void:
	if _fall_tween:
		_fall_tween.kill()
		_fall_tween = null
	if is_falling:
		_recover_from_fall()


## Back on solid ground after a fall (the player climbing out).
func _recover_from_fall() -> void:
	is_falling = false
	_fall_tween = null
	if rig:
		rig.scale = Vector2.ONE
		rig.rotation = 0.0
	queue_redraw()


func _check_ground() -> void:
	if not is_grounded():
		return
	var pit := world.pit_under(global_position)
	if pit:
		fall(pit)


# --- Hooks for subclasses ----------------------------------------------------

## How a blow from `killer` (null: none) would kill it now, in RunFacts.CAUSES' words.
func cause_of_death(killer: Actor) -> StringName:
	if is_falling:
		return &"fall"
	if last_hit and last_hit.cause != &"":
		return last_hit.cause
	if is_instance_valid(killer) and killer != self:
		return &"monster"
	return &"unknown"


func _death_cause(killer: Actor) -> String:
	if is_falling:
		return tr("a fall")
	if is_instance_valid(killer):
		return killer.display_name
	return tr("the dungeon")


## The fall is over: the actor is at the bottom of `pit`.
func _on_fell(_pit: PitDef) -> void:
	die(last_attacker if is_instance_valid(last_attacker) else null)


func _think(_delta: float) -> void:
	pass


func _get_desired_velocity() -> Vector2:
	return Vector2.ZERO


func _on_damaged(_hit: HitInfo, _damage: int) -> void:
	pass


## Last say on the damage of a hit, after armor (a shield blocking it...).
func _incoming_damage(_hit: HitInfo, damage: int) -> int:
	return damage


func _on_died(_killer: Actor) -> void:
	pass


func _hurt_sound(hit: HitInfo) -> AudioStream:
	return hit.sound


## What it is made of (the sound under its cry, its sparks), or null.
func _impact_material() -> ImpactMaterialDef:
	return null


func _death_sound() -> AudioStream:
	return null


## Its sparks when hit (HitFeedback.spark_color(): gold on a crit, else its material's).
func _hit_spark_color(hit: HitInfo) -> Color:
	return HitFeedback.spark_color(hit, _impact_material())


# --- Frame update ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if is_dead or is_falling:
		return
	_tick_timers(delta)
	if is_dead:
		return
	_think(delta)
	if is_dead:
		return

	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = _dash_velocity
		_afterimage_timer -= delta
		if _afterimage_timer <= 0.0 and rig and rig.visible and rig.current_frame():
			_afterimage_timer = AFTERIMAGE_INTERVAL
			world.spawn_vfx(AfterimageVfx.from_body(rig, _dash_element))
	else:
		velocity = _get_desired_velocity() + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
	move_and_slide()
	_check_ground()
	if rig:
		# Out of view, the body's look waits (a crowd's pose, tint and statuses are script work
		# each frame: docs/performance.md, "A crowd"); it is brought up to date as it comes back.
		rig.on_view = _in_view()
		if rig.on_view:
			rig.update_state(facing, velocity.length(), is_dashing(), delta)
			rig.modulate = _body_modulate()
			rig.look.show_statuses(statuses, delta, _shader_shows_statuses())
	_redraw_if_changed()


## Whether its body can be seen (Monster: within the view, with a margin); the hero always.
func _in_view() -> bool:
	return true


## The shadow is drawn in the actor's own space (it moves with the node): only a body drawn by
## hand (no sprite: it flashes, turns, tints), a ward on the body (it shimmers), or a shadow of
## another size needs a new _draw() (docs/performance.md, "Redraw on change").
func _redraw_if_changed() -> void:
	if frames == null or _ward_on_body() or _drawn_ward or radius != _drawn_radius:
		queue_redraw()


func _ward_on_body() -> bool:
	return ward > 0 and _draws_ward_on_body()


func _tick_timers(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_invulnerable_time = maxf(_invulnerable_time - delta, 0.0)
	_flash_time = maxf(_flash_time - delta, 0.0)
	skills.tick(delta * cooldown_speed)
	if perks.has_ticking():
		perks.tick(self, delta)  # passives acting over time (a ring of ice, a trail of embers)
	if ward > 0:
		_ward_time -= delta
		if _ward_time <= 0.0:
			ward = 0
	if not statuses.is_empty():
		statuses.tick(self, delta)
		if status_fx:
			status_fx.wake()
	if timed_bonuses.tick(delta):
		invalidate_stats()


# --- Drawing -----------------------------------------------------------------

## Point above the actor's head, in world space (for damage numbers, labels...).
func head_position() -> Vector2:
	if frames:
		return global_position + Vector2(0, _feet_y() - head_height)
	return global_position + Vector2(0, -radius - 6.0)


## Collision is a circle at the actor's feet; the sprite stands on it.
func _feet_y() -> float:
	return radius * 0.7 + 1.0


## Tint of the whole body: death, blinking, telegraph glow... (the hit flash is a shader in the rig).
func _body_modulate() -> Color:
	if is_dead:
		return Color(0.45, 0.4, 0.4, 1.0)
	if not statuses.is_empty() and not _shader_shows_statuses():
		# Burning, poisoned, chilled... with fewer effects (or no sprite): tinted a steady 45%
		# toward the status's color. Otherwise the body shader paints them (BodyLook).
		# Quicksand and sand: no tint.
		var tint := statuses.tint()
		if tint.a > 0.0:
			return Color.WHITE.lerp(Color(tint, 1.0), 0.45)
	return Color.WHITE


## The body shader paints the statuses (heat, rime, a poison wave...): a body with a sprite, and
## the full effects on (Settings.fewer_effects: the flat tint instead).
func _shader_shows_statuses() -> bool:
	return rig != null and rig.visible and not Settings.fewer_effects


## Its hits land in the elements its weapon carries (its runes and affixes: ItemLook), and its
## shots wear them: the hero's, whose gear is loot. A monster's weapon strikes as written
## (Combat.melee_strike(), Combat.spec_from_weapon()).
func strikes_in_carried_elements() -> bool:
	return false


## The rig shows the weapon at rest and the gear's rarity and elements (ActorRig.carries_weapon):
## the hero's, whose gear is loot; monsters' weapons are their claws and fists.
func _shows_gear() -> bool:
	return false


func _draw() -> void:
	_drawn_ward = false
	_drawn_radius = radius
	if shadow:
		shadow.visible = not is_falling
		shadow.fit(_feet_y(), radius)
	if is_falling:
		return
	if frames == null:
		var color := Color.WHITE if _flash_time > 0.0 else body_color * _body_modulate()
		BodySketch.draw(self, radius, color, facing, glyph)
	if _ward_on_body():
		_drawn_ward = true
		draw_ward(self)


## Its ward is drawn with its body (`_draw`); false for one that draws it elsewhere (a monster's
## overlay draws it over the body: MonsterOverlay).
func _draws_ward_on_body() -> bool:
	return true


## The shimmering bubble of its ward, drawn on `canvas` (centred on the actor; monsters draw it
## over their body, see MonsterOverlay): WardVfx.
func draw_ward(canvas: CanvasItem) -> void:
	WardVfx.draw(canvas, radius)
