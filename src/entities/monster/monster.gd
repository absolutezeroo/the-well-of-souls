class_name Monster
extends Actor
## A monster built from a MonsterDef (or a BossDef). Its behaviour lives in the StateMachine child
## (res://src/ai/), which steers it through `move_direction`, `attack()` and skills.

## A boss reached its next phase (1: the second phase, 2: the third...). Its arena may change.
signal phase_entered(index: int)


var def: MonsterDef
var target: Actor
## Set by the AI states every frame (length 0..1).
var move_direction := Vector2.ZERO
## 0..1 while winding up an attack or a skill; drawn as a warning for the player.
var telegraph := 0.0
## Skill being cast (see the Cast state), -1 when none.
var casting_index := -1
## A dormant monster ignores the player (a boss waiting in its arena). See wake_up().
var dormant := false
## Physics frame when it first spotted the hero (-1: never). For the bestiary challenges.
var noticed_frame := -1
## Elites and rarer (see make_ranked()): the rank (Elite, Epic, Legendary, Shiny) and the
## affixes that make them special; `elite` is the first affix (null for a Shiny).
var rank: MonsterRankDef
var affixes: Array[EliteAffixDef] = []
var elite: EliteAffixDef
## Its place among the floor's own monsters (FloorPopulator puts them down in an order the
## floor's seed decides): the same number is the same monster on the floor rebuilt for a resumed
## run, so a slain one stays slain and a hurt one hurt (World.spent_data() "slain", "wounded"; the
## hidden floor numbers its own too). -1: came later (summons, ambush and Deeps waves, encounters,
## the debug panel; World.spent_data() "later" keeps those still standing).
var floor_index := -1

## How far outside the view a monster's body still keeps its look up to date (px).
const VIEW_MARGIN := 96.0
## Big monsters shake the floor when they walk.
const HEAVY_RADIUS := 14.0
const HEAVY_STEP_INTERVAL := 0.45
## The rim a body that warns by its rim wears while it winds up (TelegraphView's red).
const WARNING_RIM := Color(1.0, 0.22, 0.2)

var _step_timer := 0.0
var _windup_multiplier := 1.0
var _damage_multiplier := 1.0
## The depth it was set up for (rank health grows with it: MonsterRankDef.hp_multiplier_at()).
var _depth := 1
## Called in by another monster (SummonEffect): gives no XP, loot or gold.
var summoned := false
## A rim warning on (MonsterDef.CastWarning.RIM), and the rim it had before.
var _warning_rim := false
var _rim_before := Color.TRANSPARENT
## Native and affix behaviours, composed once; active is a read-only cached view for hooks.
var behaviors := MonsterTraits.new(self)
var _under: MonsterOverlay
var _over: MonsterOverlay
## Fell into a hole: no loot, no burst, nothing comes out.
var _fell := false

## Off screen and far from the hero, a monster sleeps: no AI, no animation (see World).
var is_awake := true
## A boss's phases, shockwave and intro (BossBrain); null for every other monster.
var brain: BossBrain
var _detect_multiplier := 1.0
## Its body's way about the floor: clear walks, sight, being stuck, spacing (MonsterSteering).
var steering := MonsterSteering.new(self)
## What it pays when slain (MonsterDrops).
var drops := MonsterDrops.new(self)


func setup(monster_def: MonsterDef, depth: int, config: DungeonConfig) -> void:
	def = monster_def
	_depth = depth
	faction = Faction.MONSTER
	display_name = tr(def.display_name)
	glyph = def.glyph
	body_color = def.color
	frames = def.frames
	frames_offset = def.frames_offset
	head_height = def.head_height
	# Bosses never fall: their arena opening into pits must not swallow them.
	flies = def.flies or def is BossDef
	set_body_radius(def.radius)
	collision_layer = Layers.MONSTERS
	# Walls, water and the hero stop it; other monsters don't (no body-to-body physics: a crowd's
	# heaviest cost, docs/performance.md "A crowd"). They keep apart by steering instead
	# (MonsterSteering: the spacing push, walking or standing).
	collision_mask = Layers.WORLD | Layers.PLAYER | (0 if def.flies else Layers.WATER)
	add_to_group("monsters")

	# Depth, difficulty and the floor's event (see FloorRules).
	var rules := world.rules if world and world.rules else FloorRules.make(config, null, null, depth)
	base_stats = rules.scale_monster(def.stats, def is BossDef)
	_damage_multiplier = rules.monster_damage(def is BossDef)
	_windup_multiplier = rules.telegraph_time()
	_detect_multiplier = rules.detect_range()
	if def is BossDef:
		brain = BossBrain.new(self, def as BossDef)
		free_on_death = not (def as BossDef).body_stays
	if def.weapon:
		equipment.equip(def.weapon)
	skills.set_skills(def.skills)
	invalidate_stats()
	hp = get_max_hp()
	behaviors.setup(def.traits)


func _ready() -> void:
	super._ready()
	if rig:
		# At rest it wears the material every body like it shares (a crowd batches: BodyLook).
		rig.look.share_on(rig.visual)
	# Warnings and auras under the body, name and health bar over it (the shadow over them).
	_under = MonsterOverlay.create(self, MonsterOverlay.Layer.UNDER)
	add_child(_under)
	move_child(_under, 0)
	_over = MonsterOverlay.create(self, MonsterOverlay.Layer.OVER)
	add_child(_over)


## Turns the monster into an elite (the dungeon's elite rank with this one affix).
## Call after it was added to the world.
func make_elite(affix: EliteAffixDef, config: DungeonConfig) -> void:
	var list: Array[EliteAffixDef] = []
	if affix:
		list.append(affix)
	make_ranked(config.elite_rank, list)


## Raises the monster to `new_rank` with `new_affixes` (their perks): more HP, bigger, more XP,
## better loot, its aura and name. A boss keeps its size and gets its rank's boss HP.
func make_ranked(new_rank: MonsterRankDef, new_affixes: Array[EliteAffixDef]) -> void:
	if new_rank == null or rank != null:
		return  # ranking is a spawn-time operation; repeated calls must not stack rewards/stats
	var accepted: Array[EliteAffixDef] = []
	for affix in new_affixes:
		if accepted.size() >= new_rank.affixes:
			break
		if affix and affix.fits(def, _depth, accepted):
			accepted.append(affix)
	rank = new_rank
	affixes = accepted
	elite = affixes[0] if not affixes.is_empty() else null
	var hp_factor := rank.boss_hp_multiplier if is_boss() else rank.hp_multiplier_at(_depth)
	if not is_boss():
		_damage_multiplier *= rank.damage_multiplier
	for affix in affixes:
		if affix.perk:
			perks.add(affix.perk)
		behaviors.add(affix.traits)
		if not is_boss():
			hp_factor *= affix.hp_multiplier
	if rank.show_in_name:
		display_name = tr("{rank} {monster}").format({ "rank": tr(rank.display_name), "monster": tr(def.display_name) })
	elif elite:
		display_name = tr("{affix} {monster}").format({ "affix": Grammar.adjective(elite.display_name, def.display_name), "monster": tr(def.display_name) })
	base_stats.max_hp = roundi(base_stats.max_hp * hp_factor)
	invalidate_stats()
	hp = get_max_hp()
	if not is_boss():
		head_height *= rank.scale
		set_body_radius(radius * lerpf(1.0, rank.scale, 0.5))
		if rig:
			rig.position = Vector2(0, _feet_y())
			rig.scale = Vector2.ONE * rank.scale
		drops.xp_multiplier = rank.xp_multiplier
	drops.bonus_drops = rank.bonus_drops
	if rig and (rank.hue_shift > 0.0 or rank.shimmer):
		rig.look.set_shared(&"hue_shift", rank.hue_shift)
		rig.look.set_shared(&"shimmer", 1.0 if rank.shimmer else 0.0)
	if rig:
		rig.look.outline = rank_color()  # a rim of its color around the body (BodyLook)


func is_elite() -> bool:
	return rank != null


## The rank's color (a plain elite: its affix's).
func rank_color() -> Color:
	if rank == null:
		return Color.WHITE
	if not rank.show_in_name and elite:
		return elite.color
	return rank.color


## "Vampiric, Swift" (an Epic or Legendary shows its affixes under its name).
func affix_names() -> String:
	var names := PackedStringArray()
	for affix in affixes:
		names.append(Grammar.adjective(affix.display_name, def.display_name))
	return ", ".join(names)


func get_knockback_resistance() -> float:
	var resistance := def.knockback_resistance
	if rank:
		resistance = maxf(resistance, rank.knockback_resistance)
	return resistance


func can_attack() -> bool:
	if _in_intro():
		return false
	for monster_trait in behaviors.active:
		if not monster_trait.can_attack(self):
			return false
	return super.can_attack()


## The monster's attack or skill hurt the hero (thieves grab gold...).
func on_hit_player(player: Player, hit: HitInfo = null) -> void:
	for monster_trait in behaviors.active:
		monster_trait.on_hit_player(self, player, hit)


func _incoming_damage(hit: HitInfo, damage: int) -> int:
	for monster_trait in behaviors.active:
		damage = monster_trait.incoming_damage(self, hit, damage)
	# A kind the hero has mastered in the bestiary takes a bit more from them.
	var rules := world.bestiary_rules() if world else null
	if rules and hit.source is Player and damage > 0:
		damage = roundi(damage * Bestiary.damage_multiplier(def, rules))
	return damage


## The first trait of type `kind` (a GuardTrait, a ThiefTrait...), or null.
func get_trait(kind: Script) -> MonsterTrait:
	return behaviors.first(kind)


## Per-monster values of a trait (a trait resource is shared by every monster of its kind): the
## trait's own State, made the first time it is asked (MonsterTrait.make_state()).
func trait_state(source_trait: MonsterTrait) -> RefCounted:
	return behaviors.state(source_trait)


## Went down a hole (rather than being slain).
func has_fallen() -> bool:
	return _fell


## Attacks and skills hit harder (or softer) with the difficulty.
func get_power() -> int:
	return maxi(1, roundi(super.get_power() * _damage_multiplier))


func get_move_speed() -> float:
	var speed := super.get_move_speed()
	for behavior in behaviors.active:
		speed *= behavior.move_speed_multiplier(self)
	return speed


## Wind-ups and casts last longer on easy, shorter on hard (and in late boss phases).
func get_telegraph_scale() -> float:
	return _windup_multiplier


## Its wind-ups and casts last `factor` times as long from now on (a boss phase: BossBrain).
func scale_telegraph(factor: float) -> void:
	_windup_multiplier *= factor


## A boss entered its phase `index` (BossBrain): its arena may change (phase_entered).
func announce_phase(index: int) -> void:
	phase_entered.emit(index)


## A boss still playing an intro it waits out (BossBrain.in_intro()): it neither moves nor strikes.
func _in_intro() -> bool:
	return brain != null and brain.in_intro()


func is_boss() -> bool:
	return def is BossDef


## The boss phases it went through (0: still in its first). See BossDef.phases.
func phase_index() -> int:
	return brain.phases_done if brain else 0


## Summons and a boss's adds feed no "on kill" heals: a boss calling its brood must not become
## a health fountain.
func can_heal_killer() -> bool:
	return not summoned and (is_boss() or world == null or not world.is_boss_fight())


## Ends dormancy and goes straight for `new_target`. `intro`: plays its waking animation (not
## when a cinematic just showed it).
func wake_up(new_target: Actor, intro := true) -> void:
	dormant = false
	target = new_target
	_noticed(new_target)
	if rig and intro:
		rig.play_intro()
		if brain:
			brain.on_intro(rig.animation_length(&"intro"))


## Returns true if the monster has (or just acquired) a target to fight. Every way a monster
## comes after the hero (sight, a hit, an ambush, a boss waking) goes through here each frame: an
## invisible hero (DebugCheats) is forgotten at once.
func notice_target() -> bool:
	if dormant:
		return false
	if target != null and is_instance_valid(target) and not target.is_dead and DebugCheats.can_be_noticed(target) and not world.shelters(target):
		return true
	target = null
	var player := world.player
	if player and not player.is_dead and DebugCheats.can_be_noticed(player) and not world.shelters(player) and can_see(player, detect_radius()):
		target = player
		_noticed(player)
		return true
	return false


## The hero is spotted: the bestiary page opens, and "not hurt since it saw you" starts.
func _noticed(other: Actor) -> void:
	if other is Player and noticed_frame < 0:
		noticed_frame = Engine.get_physics_frames()
		Profile.mark_seen(def.id)
		Events.monster_noticed.emit(self)


## The run's difficulty changed in the middle of the floor (lowered from the pause menu: World):
## its Health, blows, speed, wind-ups and sight follow `after` as a share of `before` (an elite's
## rank or a boss phase keep their own), its Health keeping its share.
func follow_rules(before: FloorRules, after: FloorRules) -> void:
	var boss := def is BossDef
	var share := float(hp) / maxf(float(get_max_hp()), 1.0)
	base_stats = base_stats.duplicate()
	base_stats.max_hp = maxi(1, roundi(base_stats.max_hp * after.monster_hp(boss) / maxf(before.monster_hp(boss), 0.01)))
	base_stats.move_speed *= after.monster_speed() / maxf(before.monster_speed(), 0.01)
	_damage_multiplier *= after.monster_damage(boss) / maxf(before.monster_damage(boss), 0.01)
	_windup_multiplier *= after.telegraph_time() / maxf(before.telegraph_time(), 0.01)
	_detect_multiplier *= after.detect_range() / maxf(before.detect_range(), 0.01)
	invalidate_stats()
	hp = clampi(roundi(get_max_hp() * share), 1, get_max_hp())
	health_changed.emit(hp, get_max_hp())


## How far it spots the hero: its kind's reach, times the difficulty's.
func detect_radius() -> float:
	return def.detect_radius * _detect_multiplier


## How far it sees while it chases (MonsterDef.chase_sight_multiplier times detect_radius()).
func chase_detect_radius() -> float:
	return detect_radius() * def.chase_sight_multiplier


## Sleeps (off screen, far from the hero) or wakes up. A sleeping monster keeps its body (shots
## still hit it) but thinks, moves and animates no more.
func set_awake(awake: bool) -> void:
	if awake == is_awake:
		return
	is_awake = awake
	process_mode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED
	steering.reset_progress()


## Hit while asleep (a stray shot, a fire): it wakes up to answer.
func take_hit(hit: HitInfo) -> void:
	set_awake(true)
	if not is_dead:
		for monster_trait in behaviors.active:
			if monster_trait.deflects(self, hit):
				return  # turned away whole (a closed maw): the trait shows it
	super.take_hit(hit)


## Walking but getting nowhere (a corner, a crowd, a pond's edge): the AI goes around.
func is_stuck() -> bool:
	return steering.is_stuck()


## Can its body walk straight to `point` (MonsterSteering.has_clear_walk()).
func has_clear_walk(point: Vector2) -> bool:
	return steering.has_clear_walk(point)


## Within `max_distance` and in sight (MonsterSteering.can_see(): a cached ray).
func can_see(other: Actor, max_distance: float) -> bool:
	return steering.can_see(other, max_distance)


## Distance from which the weapon can hit the target.
func attack_range(other: Actor) -> float:
	var weapon := get_weapon()
	if weapon == null:
		return 0.0
	if weapon.kind == WeaponDef.Kind.MELEE:
		return radius + weapon.reach + other.radius - 4.0
	return weapon.reach * 0.9


## Index of the first ready skill whose AI conditions match, or -1.
func pick_skill(distance: float) -> int:
	if _in_intro():
		return -1
	for monster_trait in behaviors.active:
		if not monster_trait.can_cast(self):
			return -1
	for i in skills.skills.size():
		var skill := skills.skills[i]
		if skill == null or not skills.is_ready(i):
			continue
		if distance < skill.ai_min_range or distance > skill.ai_max_range:
			continue
		if float(hp) / get_max_hp() > skill.ai_below_hp_ratio:
			continue
		if skill.ai_ally_need != SkillDef.AllyNeed.NONE and not _allies_need(skill):
			continue
		return i
	return -1


## A support's skill: is there an ally (not itself) to help?
func _allies_need(skill: SkillDef) -> bool:
	for ally in AllyEffect.allies_of(self, skill.ai_ally_radius, false):
		if skill.ai_ally_need == SkillDef.AllyNeed.ALLY_NEAR:
			return true
		if float(ally.hp) / ally.get_max_hp() < skill.ai_ally_hurt_ratio:
			return true
	return false


func casting_skill() -> SkillDef:
	return skills.skills[casting_index] if casting_index >= 0 and casting_index < skills.skills.size() else null


## Telegraph time before attacking (shorter in later boss phases).
func get_attack_windup() -> float:
	return def.attack_windup * _windup_multiplier


## The debug panel's No AI: it stands where it is (its StateMachine thinks no more, its traits
## steer nothing, no shockwave answers the hero's blows). Knockback still moves it.
func ai_frozen() -> bool:
	return DebugCheats.ai_frozen()


func _get_desired_velocity() -> Vector2:
	if ai_frozen():
		move_direction = Vector2.ZERO
		telegraph = 0.0
		return Vector2.ZERO
	_update_heavy_steps()
	var direction := move_direction if not _in_intro() else Vector2.ZERO
	var delta := get_physics_process_delta_time()
	for monster_trait in behaviors.active:
		monster_trait.update(self, delta)
		direction = monster_trait.steer(self, direction)
	if direction != Vector2.ZERO and not is_boss():
		direction = steering.keep_spacing(direction)
	elif direction == Vector2.ZERO and not is_boss():
		# Standing (waiting, striking): it eases out of the others it overlaps, slowly.
		direction = steering.stand_apart()
	if direction != Vector2.ZERO and not flies:
		direction = steering.avoid_holes(direction)
	return direction * get_move_speed()


func _physics_process(delta: float) -> void:
	if rig and def.cast_warning == MonsterDef.CastWarning.RIM:
		_show_cast_rim()  # before the body's look is drawn this frame (Actor)
	super._physics_process(delta)
	steering.track_progress(delta)


## Within the view, with a margin for its sprite and a step or two (World.view_rect(): once a
## frame), or no world to ask.
func _in_view() -> bool:
	return world == null or world.view_rect(VIEW_MARGIN).has_point(global_position)


func _update_heavy_steps() -> void:
	if radius < HEAVY_RADIUS or move_direction.length() < 0.3:
		return
	_step_timer -= get_physics_process_delta_time()
	if _step_timer > 0.0:
		return
	_step_timer = HEAVY_STEP_INTERVAL
	Sfx.play_world(Sfx.bank.footstep, global_position, -6.0, 0.55)
	Vfx.dust(world, global_position + Vector2(0, _feet_y()), 1.2)
	if world.player and world.player.global_position.distance_to(global_position) < 260.0:
		Events.screen_shake.emit(0.15 if not is_boss() else 0.3)


func get_move_direction() -> Vector2:
	return move_direction


func _on_damaged(hit: HitInfo, _damage: int) -> void:
	# Getting hit always makes a monster aggressive, even from out of sight.
	if hit.source and is_hostile_to(hit.source):
		target = hit.source
	if hit.source is Player and not hit.is_secondary:
		HitStop.freeze(0.07 if hit.is_crit else 0.035)
		Settings.vibrate(0.15 if hit.is_crit else 0.05)
		# The blow lands: the camera leans into it.
		var push := hit.knockback.normalized() if hit.knockback != Vector2.ZERO else hit.source.global_position.direction_to(global_position)
		Events.camera_kick.emit(push, 6.0 if hit.is_crit else 3.5)
	if dormant and hit.source:
		wake_up(hit.source)
	if brain:
		brain.update_phase()
	if _damage > 0 and not hit.is_tick and world.rng.randf() < 0.45:
		world.add_splat(global_position + Vector2(world.rng.randf_range(-6, 6), world.rng.randf_range(-3, 5)), def.splat_color, 0.35, hit.knockback.normalized())
	if brain and not hit.is_tick and hit.source and is_hostile_to(hit.source):
		brain.count_hit()
	for behavior in behaviors.active:
		behavior.on_damaged(self, hit, _damage)


func _tick_timers(delta: float) -> void:
	super._tick_timers(delta)
	if brain:
		brain.tick(delta)


func _impact_material() -> ImpactMaterialDef:
	return def.material


func _hurt_sound(hit: HitInfo) -> AudioStream:
	if hit.sound:
		return hit.sound
	return def.hurt_sound if def.hurt_sound else Sfx.bank.monster_hurt


func _death_sound() -> AudioStream:
	return def.death_sound if def.death_sound else Sfx.bank.monster_death


## Gone for good, nothing drops (the XP still goes to whoever pushed it).
func _on_fell(pit: PitDef) -> void:
	_fell = true
	super._on_fell(pit)


func _on_died(killer: Actor) -> void:
	Events.monster_killed.emit(self)
	_free_souls()
	var fell := _fell or is_falling
	for monster_trait in behaviors.active:
		monster_trait.on_died(self, killer, fell, not summoned)
	if fell:
		if not summoned:  # summons pay nothing, even pushed into a hole
			drops.pay_xp(killer)
		world.spawn_floating_text(global_position, tr("Fell!"), Palette.GOLD)
		return
	if is_boss() and free_on_death:
		Vfx.boss_death(world, global_position + Vector2(0, -head_height * 0.5), radius * 1.5)
		HitStop.freeze(0.25)
	elif is_boss():
		HitStop.freeze(0.25)  # a body that stays plays its own death (BossDef.body_stays)
		Events.screen_shake.emit(0.6)
	else:
		Vfx.death(world, global_position, def.color, DeathLookDef.of(killing_element()))
		if killer is Player:
			_kill_punch()
	world.add_splat(global_position, def.splat_color, clampf(radius / 11.0, 0.8, 2.2))
	if def.material:
		var away := last_hit.knockback.normalized() if last_hit and last_hit.knockback != Vector2.ZERO else Vector2.ZERO
		world.add_debris(global_position, def.material, clampf(radius / 11.0, 0.8, 2.5), away)
	if summoned:
		return  # called in by another monster: no rewards, or a summoner could be farmed forever
	drops.pay_all(killer)


## Killing blow: a heavier stop; the strong ones (elites and up) slow the world a moment.
func _kill_punch() -> void:
	if rank:
		HitStop.freeze(0.08)
		HitStop.slow(0.35, 0.35)
		Events.screen_shake.emit(0.3)
	else:
		HitStop.freeze(0.05)


## Where what it drops lands (MonsterDrops.origin()).
func loot_origin() -> Vector2:
	return drops.origin()


## The souls it fed on fly back to the hero's lantern (bosses hold many).
func _free_souls() -> void:
	if world.player == null or world.player.is_dead:
		return
	for i in (def as BossDef).soul_wisps if is_boss() else 1:
		world.spawn_vfx(SoulWisp.create(global_position + Vector2(randf_range(-8.0, 8.0), -radius), world.player))


## Its ward is drawn over its body by its overlay (MonsterOverlay), not with the body.
func _draws_ward_on_body() -> bool:
	return false


## Its gear shows as the hero's does (MonsterDef.shows_gear: the Nameless Keeper).
func _shows_gear() -> bool:
	return def != null and def.shows_gear


## Glows red while winding up an attack, so the player sees it coming.
func _body_modulate() -> Color:
	if is_dead and not free_on_death:
		return Color.WHITE  # a body the story keeps (BossDef.body_stays): its own colors
	var color := super._body_modulate() * (brain.tint if brain else Color.WHITE)
	if telegraph > 0.0 and _flash_time <= 0.0 and def.cast_warning == MonsterDef.CastWarning.TINT:
		color = color.lerp(Color(2.0, 0.7, 0.7), telegraph)
	return color


## A body that warns by its rim (MonsterDef.CastWarning.RIM): the telegraph's red round its
## silhouette while it winds up or casts, a step brighter in the second half; then its own rim
## again (a rank's color, or none).
func _show_cast_rim() -> void:
	var warning := telegraph > 0.0 and not is_dead
	if warning and not _warning_rim:
		_rim_before = rig.look.outline
	_warning_rim = warning
	rig.look.outline_beat = not warning  # one art pixel: on a big body a beat reads as a screen door
	if warning:
		rig.look.outline = WARNING_RIM if telegraph >= 0.5 else WARNING_RIM.darkened(0.35)
	elif rig.look.outline != _rim_before:
		rig.look.outline = _rim_before
