class_name Player
extends Actor
## The hero: his gear, bag and belt, XP, gold and the falls he climbs out of. Composed of
## focused parts: `controls` (PlayerControls: the input, the aim, the attack button and its
## charge), `pack` (PlayerPack: what he does with the bag, the belt and his gear), and
## PlayerSave (his part of a saved run).

signal xp_changed(xp: int, xp_needed: int, level: int)
## Emitted once per level gained (the game then offers a perk).
signal leveled_up(level: int)
## The hero lost HP (screen effects listen to this).
signal damaged(amount: int)
## The skill buttons changed (new weapon, new spell learned).
signal skills_changed
signal gold_changed(gold: int)
# Emitted by his parts (PlayerControls, PlayerPack: the buttons and the bag), not by this script.
@warning_ignore_start("unused_signal")
## A potion (or another consumable) was used, from the bag or the belt.
signal consumable_used(item: ItemDef)
## A swing or a shot of the weapon (the tutorial listens).
signal attacked
## A skill button worked (index: Player slot, 0 the roll).
signal skill_used(index: int)
## Gear from the bag was broken down (gold already added): the bag shows the gold flying.
signal dismantled(items: Array[ItemDef], gold: int)
## An item was dropped from the bag on the floor (the gameplay statistics count it).
signal item_dropped(item: ItemDef)
## Holding the attack button: the charge started filling, then it is full (ChargeVfx, the HUD).
signal charge_started
signal charge_full
@warning_ignore_restore("unused_signal")
## The weapon's charged attack was unleashed (the tutorial listens).
signal charged_attack(attack: ChargedAttackDef)

## Where the weapon is in the hero's hand: this far above his center (his chest, on the rig's
## 2x art) and this far out toward the aim. His shots leave from there (docs/vfx.md 2b).
const HAND_LIFT := 6.0
const HAND_REACH := 8.0
## Skill buttons: innate skills (the roll), then the weapon's skills, then the learned spell.
## Slots without a skill stay empty (null), so a skill never jumps to another button.
const WEAPON_SKILL_SLOTS := 2
const SKILL_COUNT := 4
const STEP_INTERVAL := 0.3

## PlayerDef's own defaults, for a hero not set up yet (tuning()).
static var _defaults := PlayerDef.new()

## His aura (wear_aura()), or null.
var aura: AuraVfx
## Physics frame of the last damage taken (-1: none). For the bestiary challenges.
var last_hurt_frame := -1
var def: PlayerDef
var inventory: Inventory
## Potions, bombs, scrolls: stacked in their own slots, out of the bag.
var belt := Belt.new()
var level := 1
var xp := 0
## Skill taught by the last tome read (last skill button).
var learned_skill: SkillDef
## Coins found during this run (spent at the merchant).
var gold := 0
## What killed him (the monster's kind, and whether it was an elite), for the Vigil-Keeper's
## tale (RunFacts). Null: no monster (a trap, a fall...), or alive.
var killer_def: MonsterDef
var killer_was_elite := false
## Cold floors and hot ground (see BodyTemperature).
var temperature := BodyTemperature.new()
## The share of each hit the Souls' Aid takes away (AssistDef; the Game sets it from the profile,
## 0 without it), after Armor: the one place the aid touches the damage path (_incoming_damage).
var aid := 0.0
## Holding the attack button: the weapon's charged attack (AttackCharge, ChargedAttackDef).
var charge := AttackCharge.new()
## The input, the aim and the attack button (PlayerControls).
var controls := PlayerControls.new(self)
## The bag, the belt and the gear in his hands (PlayerPack).
var pack := PlayerPack.new(self)

var _step_timer := 0.0
var _left_foot := false
## Where the hero climbs back out after falling into a hole: the last solid ground stood on.
var _safe_position := Vector2.ZERO

@onready var camera: GameCamera = $Camera
## The charge's gauge at his feet and the glow in his hand.
var charge_vfx: ChargeVfx


func _ready() -> void:
	super._ready()
	charge_vfx = ChargeVfx.attach(self)


## The aura he wears (the Wardrobe, AuraDef; null: none), for the look alone: at his feet, behind
## him (AuraVfx). Worn again replaces the one before.
func wear_aura(def_worn: AuraDef) -> void:
	if aura and is_instance_valid(aura):
		aura.queue_free()
	aura = AuraVfx.make(def_worn, head_height - 4.0, radius)
	if aura:
		aura.wear_on(self, Vector2(0, _feet_y()))


func _notification(what: int) -> void:
	if what == NOTIFICATION_UNPAUSED:
		controls.mute_presses()


## Its def's feel numbers (i-frames, aim ranges...); the defaults of PlayerDef before setup().
func tuning() -> PlayerDef:
	return def if def else _defaults


func setup(player_def: PlayerDef) -> void:
	def = player_def
	faction = Faction.PLAYER
	free_on_death = false
	display_name = tr(def.display_name)
	body_color = def.color
	frames = def.frames
	frames_offset = def.frames_offset
	set_body_radius(def.radius)
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.MONSTERS | Layers.WATER

	base_stats = def.base_stats.duplicate()
	inventory = Inventory.new(Inventory.CATEGORIES.categories[0].capacity, Inventory.CATEGORIES)
	inventory.extra_places = def.bag_bonus
	for item in def.starting_equipment:
		equipment.equip(item)
	for item in def.starting_items:
		pack.store(item)
	rebuild_skills(0.0)
	equipment.changed.connect(rebuild_skills.bind(def.swap_cooldown))
	equipment.changed.connect(charge.cancel)  # a weapon swap loses the charge
	equipment.changed.connect(func() -> void: perks.set_gear(equipment.affixes(), equipment.runes()))
	perks.set_gear(equipment.affixes(), equipment.runes())
	invalidate_stats()
	hp = get_max_hp()


## The hero's healing from hits and kills shares one budget (DungeonConfig > Sustain).
func _sustain_rules() -> SustainRules:
	return world.rules.config.sustain if world and world.rules and world.rules.config else null


func xp_to_next_level() -> int:
	return def.xp_to_next_level(level)


# --- Input (PlayerControls) ----------------------------------------------------

func _think(delta: float) -> void:
	controls.sample()
	controls.read_move(delta)
	_update_footsteps(delta)
	controls.act(delta)


## The charge was full and the button let go: the weapon's charged attack toward the closest
## enemy (or straight ahead). The weapon swings again after its usual cooldown.
func unleash(weapon: WeaponDef, charged: ChargedAttackDef) -> void:
	if is_dead or is_falling:
		return
	var aim := get_aim_direction(tuning().skill_aim_range)
	facing = aim
	controls.hold_aim()
	_attack_cooldown = get_attack_cooldown(weapon)
	if rig:
		# The pose (and a sheet the weapon plays) the way a melee blow is struck (Blow); the
		# charged attack's own effects turn to it themselves (`follows_facing`).
		rig.play_attack(weapon, Blow.of_weapon(global_position, aim, weapon).facing, maxf(_attack_cooldown, 0.3))
	charged.release(self, weapon, aim)
	_on_attacked(weapon)
	camera.shake(0.3)
	charged_attack.emit(charged)


## Where the weapon is in the hand when striking toward `aim`.
func hand_point(aim: Vector2) -> Vector2:
	return global_position + Vector2(0, -HAND_LIFT) + aim.normalized() * HAND_REACH


## His shots leave from the weapon in his hand, not from his feet (World.fire_projectiles
## starts them a few units further along).
func shot_origin(direction: Vector2) -> Vector2:
	return hand_point(direction)


## Rolling (or any dash) loses the charge.
func start_dash(dash_velocity: Vector2, duration: float, invulnerable: bool, element: VfxElementDef = null) -> void:
	charge.cancel()
	super.start_dash(dash_velocity, duration, invulnerable, element)


## Slower while charging (the charged attack's `move_speed_scale`). Faster with the debug panel's
## speed step.
func get_move_speed() -> float:
	var speed := super.get_move_speed() * DebugCheats.speed_factor()
	var weapon := get_weapon()
	if charge.is_charging() and weapon and weapon.charged:
		speed = maxf(speed * weapon.charged.move_speed_scale, 20.0)
	return speed


func _update_footsteps(delta: float) -> void:
	var walking := controls.move_direction
	if walking.length() < 0.3 or is_dashing():
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = STEP_INTERVAL
		var ambience := world.theme.ambience if world.theme else null
		var step_sound := ambience.footstep if ambience and ambience.footstep else Sfx.bank.footstep
		Sfx.play_world(step_sound, global_position, -10.0)
		var feet := global_position + Vector2(0, _feet_y())
		Vfx.dust(world, feet, 0.6)
		if ambience and ambience.footprint_color.a > 0.0:
			# Left, right, left... on each side of the path.
			_left_foot = not _left_foot
			var side := walking.orthogonal().normalized() * (3.0 if _left_foot else -3.0)
			world.spawn_vfx(FootprintVfx.create(feet + side, walking, ambience.footprint_color))


func _get_desired_velocity() -> Vector2:
	return controls.move_direction * get_move_speed()


func get_move_direction() -> Vector2:
	return controls.move_direction


## Direction to the closest visible enemy in range, or the current facing (PlayerControls).
func get_aim_direction(max_range: float) -> Vector2:
	return controls.aim_direction(max_range)


## Skill button `index` (0: the roll), as if pressed (PlayerControls.use_skill()).
func use_skill(index: int) -> void:
	controls.use_skill(index)


# --- Skills ------------------------------------------------------------------

## Innate skills + the weapon's skills + the learned spell, each in its own slot.
func rebuild_skills(new_skill_cooldown: float) -> void:
	var list: Array[SkillDef] = []
	list.append_array(def.innate_skills)
	var weapon := get_weapon()
	for i in WEAPON_SKILL_SLOTS:
		list.append(weapon.skills[i] if weapon and i < weapon.skills.size() else null)
	list.append(learned_skill)
	list.resize(mini(list.size(), SKILL_COUNT))
	skills.replace(list, new_skill_cooldown)
	skills_changed.emit()


## Puts a skill in the learned slot (replacing the previous one).
func learn_skill(skill: SkillDef) -> void:
	learned_skill = skill
	rebuild_skills(0.0)
	Events.log_message(tr("Learned %s!") % tr(skill.display_name), skill.color)
	Vfx.magic(world, global_position, skill.color)
	Sfx.play_ui(Sfx.bank.level_up)


# --- Progression -------------------------------------------------------------

func gain_xp(amount: int) -> void:
	if is_dead or hp <= 0:
		return  # a kill landing after the hero's own death (a projectile, a burn...)
	xp += amount
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		if def.level_bonus:
			base_stats = base_stats.plus(def.level_bonus)
		invalidate_stats()
		hp = get_max_hp()
		health_changed.emit(hp, get_max_hp())
		Events.log_message(tr("Level up! You are now level %d") % level, Palette.GOLD)
		# A moment in the world, never a pause: the perk choice waits behind the HUD's button.
		world.spawn_floating_text(head_position() + Vector2(0, -10), tr("LEVEL UP"), Palette.GOLD)
		Vfx.magic(world, global_position, Palette.GOLD)
		LevelUpVfx.attach(self)
		Sfx.play_ui(Sfx.bank.level_up)
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_to_next_level(), level)


# --- Gold -------------------------------------------------------------------

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


## Returns false (and spends nothing) if there is not enough.
func spend_gold(amount: int) -> bool:
	if amount > gold:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


# --- Saving -----------------------------------------------------------------

## Everything about the hero a saved run needs (see RunSave, PlayerSave).
func save_state() -> Dictionary:
	return PlayerSave.to_data(self)


## Puts the hero back as saved (after setup()).
func load_state(data: Dictionary) -> void:
	PlayerSave.restore(self, data)


# --- Holes ------------------------------------------------------------------

## Call after moving the hero to a new floor.
func reset_safe_position() -> void:
	_safe_position = global_position


func _check_ground() -> void:
	super._check_ground()
	if is_grounded() and world.is_solid_ground(global_position):
		_safe_position = global_position


## Down into the Deeps when they can take him (Abyss: a floor's hole); otherwise (a boss floor,
## the hidden floor, the Deeps themselves) climbs back out where the hero last stood safely, hurt.
func _on_fell(pit: PitDef) -> void:
	if is_dead:
		return  # killed during the fall: the body stays down there
	# Where the hero stood may have given way since (a boss arena opening up), or a body may stand
	# there now (a boss at the edge of the hole): the nearest free floor clear of them then, or
	# he would fall again and again (pushed back into the hole by the body he climbed out under:
	# four falls in 1.5 s in a balance fight, 2026-10-23).
	var bodies := world.get_hostiles(faction)
	if not world.is_solid_ground(_safe_position) or WorldSpace.is_under_body(_safe_position, bodies, radius + 2.0):
		_safe_position = world.nearest_free_point(_safe_position, 12, bodies, radius + 2.0)
	var abyss := Abyss.of(self)
	if abyss and abyss.can_take(self):
		abyss.open(self, _safe_position, global_position)
		return
	global_position = _safe_position
	_recover_from_fall()
	Vfx.puff(world, global_position)
	Events.log_message(tr("You fell into a hole!"), Palette.DANGER)
	take_fall(pit.fall_damage)


## Hurt by a fall: `share` of max Health, named "a fall" if it kills; then a moment of grace.
func take_fall(share: float) -> void:
	_invulnerable_time = 0.0
	killed_by = tr("a fall")  # if this is what kills the hero
	var hit := Combat.make_secondary_hit(null, maxi(1, roundi(get_max_hp() * share)))
	hit.cause = &"fall"
	take_hit(hit)
	if not is_dead:
		killed_by = ""
		_invulnerable_time = tuning().fall_invulnerability


## On his feet again after a fall that took him somewhere else (the Deeps, and back up).
func stand_up() -> void:
	cancel_fall()


## Nothing hurts the hero for `seconds` (he blinks): back from the Threshold among monsters frozen
## mid-swing.
func shield_for(seconds: float) -> void:
	_invulnerable_time = maxf(_invulnerable_time, seconds)


## Abandoning the run (pause menu): dead now, no perk or relic can save it.
func give_up() -> void:
	if is_dead:
		return
	killed_by = tr("giving up")
	death_cause = &"giving_up"
	hp = 0
	health_changed.emit(hp, get_max_hp())
	die(null)


# --- Hooks -------------------------------------------------------------------

## A shot pushes the view back a little, a swing forward.
func _on_attacked(weapon: WeaponDef) -> void:
	if weapon.kind == WeaponDef.Kind.MELEE:
		camera.kick(facing, 1.5)
	else:
		camera.kick(-facing, 3.0)


## After Armor (Combat.mitigate()), before a ward soaks what is left: the Souls' Aid's share taken
## away, never a hit turned into nothing.
func _incoming_damage(_hit: HitInfo, damage: int) -> int:
	if aid <= 0.0 or damage <= 0:
		return damage
	return maxi(1, roundi(damage * (1.0 - aid)))


func _on_damaged(hit: HitInfo, damage: int) -> void:
	if damage > 0:
		last_hurt_frame = Engine.get_physics_frames()
	damaged.emit(damage)
	if is_instance_valid(hit.source) and hit.source is Monster:
		(hit.source as Monster).on_hit_player(self, hit)
	if hit.is_tick:
		return
	_invulnerable_time = tuning().hit_invulnerability
	if damage > 0 and world.rng.randf() < 0.6:
		world.add_splat(global_position + Vector2(0, 3), VfxElementDef.named(&"blood").mark, 0.35, hit.knockback.normalized())
	HitStop.freeze(0.08)
	camera.shake(clampf(float(damage) / get_max_hp() * 3.0, 0.25, 0.8))
	if hit.knockback != Vector2.ZERO:
		camera.kick(hit.knockback.normalized(), 7.0)


func _on_died(killer: Actor) -> void:
	# A shot whose shooter fell before it landed still says who loosed it (its last hit's source).
	var who: Actor = killer
	if who == null and last_hit and is_instance_valid(last_hit.source) and last_hit.source != self:
		who = last_hit.source
	if killer_def == null and who is Monster:
		killer_def = (who as Monster).def
		killer_was_elite = (who as Monster).is_elite()
	Events.log_message(tr("Your soul slips into the Well."), Palette.DANGER)
	if aura and is_instance_valid(aura):
		aura.hide()  # (the soul gone, its light with it)
	camera.shake(1.0)
	Vfx.death(world, global_position, def.color)


func _hurt_sound(_hit: HitInfo) -> AudioStream:
	return Sfx.bank.player_hurt


func _death_sound() -> AudioStream:
	return Sfx.bank.player_death


func _hit_spark_color(_hit: HitInfo) -> Color:
	return Palette.BLOOD


func _tick_timers(delta: float) -> void:
	super._tick_timers(delta)
	temperature.update(self, delta)


func _shows_gear() -> bool:
	return true


## His hits and shots wear what his weapon carries (Actor.strikes_in_carried_elements()).
func strikes_in_carried_elements() -> bool:
	return true


func _body_modulate() -> Color:
	var color := super._body_modulate() * temperature.tint()
	# Blink while invulnerable after a hit (but not during a dash).
	if _invulnerable_time > 0.0 and not is_dashing() and not is_dead:
		if int(_invulnerable_time * 20.0) % 2 == 0:
			color.a = 0.35
	if is_dashing():
		color = Color(1.6, 1.6, 1.8, 0.7)
	return color
