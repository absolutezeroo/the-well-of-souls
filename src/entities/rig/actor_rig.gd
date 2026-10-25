class_name ActorRig
extends Node2D
## Visual body of an actor, animated frame by frame like a classic 2D RPG.
##
##   Rig (this, at the actor's feet)
##   └── Visual        body shader (flash.gdshader: hit flash, statuses, elite rim, deaths; driven
##       │             by `look`, a BodyLook), scaled 2x (units inside = art pixels)
##       └── Squash    squash & stretch on hits, lunges
##           ├── Body       AnimatedSprite2D: idle_/walk_/attack_/hit_/dash_ + down/up/left/right, dead,
##           │              and for bosses cast (telegraphed skills) and intro (wakes up)
##           ├── BodyArmor  AnimatedSprite2D: worn body armor, same animation and frame as Body
##           ├── Helmet     AnimatedSprite2D: worn helmet, same animation and frame as Body
##           ├── Weapon     AnimatedSprite2D: the weapon in hand, attack_<dir>, synced frame by frame
##           ├── WeaponBack Sprite2D: the hero's weapon at rest (WeaponDef.back_sprite), added in code
##           └── WeaponAura the elements his weapon carries (WeaponAura), right after the weapon shown
##
## Sprites are drawn per direction (no mirroring, no free rotation): the weapon sits in the hand
## of each attack frame and is drawn behind the body when facing up, exactly like in Zelda-likes.
## Armor layers (paper doll) copy the body's animation and frame every frame, so they can never drift.
## The hero (`carries_weapon`) shows his weapon at rest, slung on his back or at his hip, behind
## the body but in front when he turns his back to us; his gear above Common and a weapon
## carrying an element wear their own copies of the body shader (`trim`, `imbue`) that follow the
## body's (BodyLook.follow): docs/vfx.md, "Rarity and runes" and "The weapon at rest".
## Slash effects are separate sprite sheets played in front of the actor.
## The Actor only says what happens; the rig decides how it looks: it picks what the body plays
## (RigAnimations: the turned names, their lengths) and keeps the layers on its frame, while the
## gear's own looks and the weapon at rest are composed by its GearLook (`gear`), bobbing with
## the body's art (BodyTops).

const DIRECTIONS: Array[StringName] = [&"down", &"up", &"left", &"right"]
const SQUASH_TIME := 0.12
const FLASH_TIME := 0.1
const HURT_TIME := 0.25
const CHEST_HEIGHT := 14.0  # world pixels above the feet
const FX_DISTANCE := 16.0

var direction: StringName = &"down"
## Within the view (its actor says, each physics frame: Actor._in_view()); out of it the rig
## keeps only its timers.
var on_view := true
var _attacking := false
var _winding_up := false
var _dead := false
## Holding a pose (hold_pose()): idle and walk wait until it is released.
var _held := false
## Casts held in a looping pose so far (play_cast()): only the last one's timer ends it.
var _cast_holds := 0
var _flash := 0.0
var _squash := 0.0
var _hurt := 0.0
var _weapon_def: WeaponDef
## A ghost's washed-out look (the spectres of the Threshold): the body blended this much toward
## `pallor_color` for good, under the hit flash.
var pallor := 0.0
var pallor_color := Color.WHITE
## What the body shader paints on it (statuses, an elite's rim, its death).
var look: BodyLook
## Shows the weapon at rest and the gear's rarity and elements (the hero; monsters don't).
var carries_weapon := false:
	set(value):
		carries_weapon = value
		if value and is_node_ready():
			BodyTops.warm(body.sprite_frames)
## The worn pieces' looks and the weapon at rest (GearLook).
var gear := GearLook.new(self)

## Holding the weapon ready while the hero charges (show_charge): not on his back meanwhile.
var _charging := false
@onready var visual: Node2D = $Visual
@onready var squash_node: Node2D = $Visual/Squash
@onready var body: AnimatedSprite2D = $Visual/Squash/Body
@onready var weapon: AnimatedSprite2D = $Visual/Squash/Weapon
@onready var body_armor: AnimatedSprite2D = $Visual/Squash/BodyArmor
@onready var helmet: AnimatedSprite2D = $Visual/Squash/Helmet
## The armor layers (_sync_layers(), every frame: one array, not one per frame).
@onready var _layers: Array[AnimatedSprite2D] = [body_armor, helmet]


func _ready() -> void:
	body.animation_finished.connect(_on_body_animation_finished)
	weapon.visible = false
	look = BodyLook.new(visual.material as ShaderMaterial)
	body.frame_changed.connect(_fit_frame)
	body.animation_changed.connect(_fit_frame)
	weapon.frame_changed.connect(_fit_weapon_frame)


func setup(frames: SpriteFrames, offset: Vector2) -> void:
	body.sprite_frames = frames
	DeathPiecesVfx.warm(frames)
	for sprite: AnimatedSprite2D in [body, body_armor, helmet, weapon]:
		sprite.offset = offset
	_play(&"idle")
	_fit_frame()
	if carries_weapon:
		BodyTops.warm(frames)


## Shows (or hides, with null frames) the armor worn on `slot` (HEAD or BODY); above Common the
## piece wears its rarity's trim (RarityLookDef.trim, a glint sweeping across an Epic one), the
## first of `elements` it carries glitters on that trim (ItemLook.elements: an affix of Echoes
## is arcane), and with `teeth` its hem is a row of steel points (ItemLook.toothed: of Thorns).
func set_wear(slot: EquipmentDef.Slot, frames: SpriteFrames, color: Color, rarity: int = ItemRarity.COMMON, elements: Array[VfxElementDef] = [], teeth: bool = false) -> void:
	var layer := helmet if slot == EquipmentDef.Slot.HEAD else body_armor
	layer.sprite_frames = frames
	layer.self_modulate = color
	layer.visible = frames != null
	var carried: VfxElementDef = elements[0] if frames and not elements.is_empty() else null
	gear.dress_wear(slot, layer, frames != null, rarity, carried, teeth and frames != null)
	_sync_layers()


## Dresses the rig in what `equipment` holds: the weapon (in hand, and at rest for a rig that
## `carries_weapon`), the armor worn with its rarity and the elements it carries. The Actor's
## rig and the bag's portrait of the hero (HeroPortrait) both come here, so they never differ.
func wear(equipment: Equipment) -> void:
	set_weapon(equipment.get_item(EquipmentDef.Slot.WEAPON) as WeaponDef)
	for slot: EquipmentDef.Slot in [EquipmentDef.Slot.HEAD, EquipmentDef.Slot.BODY]:
		var armor := equipment.get_item(slot) as ArmorDef
		if armor and armor.wear_frames:
			if carries_weapon:
				set_wear(slot, armor.wear_frames, armor.wear_color, armor.rarity, ItemLook.elements(armor), ItemLook.toothed(armor))
			else:
				set_wear(slot, armor.wear_frames, armor.wear_color, armor.rarity)
		else:
			set_wear(slot, null, Color.WHITE)


## The weapon in hand (and for the hero at rest: its sprite on his back, its rarity's trim and
## the elements it carries).
func set_weapon(def: WeaponDef) -> void:
	_weapon_def = def
	if not _attacking:
		weapon.visible = false
	if carries_weapon:
		_dress_weapon()


## The pose for `vector`: the nearest of the four directions (Blow.cardinal, so a melee blow is
## always drawn the way the body strikes).
static func direction_name(vector: Vector2) -> StringName:
	var way := Blow.cardinal(vector)
	if way.x != 0.0:
		return &"right" if way.x > 0.0 else &"left"
	return &"down" if way.y > 0.0 else &"up"


## Called every frame by the actor.
func update_state(facing: Vector2, speed: float, dashing: bool, delta: float) -> void:
	_hurt = maxf(_hurt - delta, 0.0)
	if _dead or _attacking or _winding_up or _held or body.sprite_frames == null:
		return
	if facing != Vector2.ZERO:
		direction = direction_name(facing)
	if dashing and _play(&"dash"):
		return
	if _hurt > 0.0 and _play(&"hit"):
		return
	if speed > 20.0:
		if not _play(&"walk"):
			_play(&"idle")
	elif not _play(&"idle"):
		_play(&"walk", 0.4)


## Attack toward `aim`, fitted into `duration` seconds. A melee blow comes here already turned to
## the pose's direction (Blow), so its sheet or claw is drawn the way the body strikes.
func play_attack(def: WeaponDef, aim: Vector2, duration: float) -> void:
	if _dead or body.sprite_frames == null:
		return
	direction = direction_name(aim)
	_winding_up = false
	_attacking = true
	var animation := _animation_for(&"attack")
	var speed := 1.0
	if animation != &"":
		speed = maxf(1.0, _length(body.sprite_frames, animation) / maxf(duration, 0.05))
		body.stop()
		body.play(animation, speed)
	else:
		_lunge(aim)
		get_tree().create_timer(0.25, false).timeout.connect(_end_attack)

	if def and def.attack_frames and def.attack_frames.has_animation(StringName("attack_" + direction)):
		weapon.sprite_frames = def.attack_frames
		weapon.visible = true
		weapon.stop()
		weapon.play(StringName("attack_" + direction), speed)
		# Behind the body when facing up (we see the back), in front otherwise.
		squash_node.move_child(weapon, 0 if direction == &"up" else squash_node.get_child_count() - 1)
		_fit_weapon_frame()
	_update_back()
	# The sheet effect, unless the swing draws its own arc (see Vfx.swing: a weapon shows one
	# or the other, WeaponDef.shows_arc()). A creature's blow without a sheet of its own strikes
	# with its element's claw (Frost Fang: claws of ice). A shot has neither: the shot leaves
	# the hand and nothing else covers the shooter (a staff of frost doesn't claw).
	if def and def.kind == WeaponDef.Kind.MELEE and not def.shows_arc():
		if def.attack_fx:
			# A blow all around (a body slam's ring) is round: drawn as it is, never turned.
			var round_blow := def.arc_degrees >= 359.0
			_spawn_fx(def.attack_fx, Vector2.ZERO if round_blow else aim, 0.0 if round_blow else deg_to_rad(def.attack_fx_rotation), def.element)
		elif def.element and def.element.claw:
			var at := Vector2(0, -CHEST_HEIGHT) + aim.normalized() * FX_DISTANCE
			add_child(SheetVfx.play(def.element.claw, at, aim, def.element))


## Charging the weapon's charged attack (`def`; null: not any more): the weapon held ready in
## the hand, on the last frame of its attack toward the way the body faces (the blade down at
## his side, in his hand: the first frame raises it high over his head, where it floats when
## held), behind the body facing up, while the body walks or stands as usual. An attack under
## way keeps its frames.
func show_charge(def: WeaponDef) -> void:
	if _attacking or _dead:
		return
	var shown := def != null and def.attack_frames != null and def.attack_frames.has_animation(StringName("attack_" + direction))
	if shown != _charging:
		_charging = shown
		if not shown:
			weapon.visible = false
		_update_back()  # in his hand, not on his back
	if not shown:
		return
	var animation := StringName("attack_" + direction)
	if weapon.sprite_frames != def.attack_frames or weapon.animation != animation or not weapon.visible:
		weapon.sprite_frames = def.attack_frames
		weapon.animation = animation
		weapon.frame = def.attack_frames.get_frame_count(animation) - 1
		weapon.pause()
		weapon.visible = true
		squash_node.move_child(weapon, 0 if direction == &"up" else squash_node.get_child_count() - 1)
		_fit_weapon_frame()
		_update_back()


## Telegraph before a monster attack: its "windup" animation fitted to `duration` if it has one,
## else hold the attack pose and tremble.
func play_windup(aim: Vector2, duration: float) -> void:
	if _dead or body.sprite_frames == null:
		return
	direction = direction_name(aim)
	_winding_up = true
	var windup := _animation_for(&"windup")
	if windup != &"":
		# A wind-up of its own (a swordsman drawing his blade), fitted to the telegraph.
		body.stop()
		body.play(windup, maxf(0.1, _length(body.sprite_frames, windup) / maxf(duration, 0.05)))
		return
	if _play(&"attack", 1.0, true):
		body.pause()
	var tween := create_tween()
	var steps := maxi(2, int(duration / 0.05))
	for i in steps:
		tween.tween_property(body, "position", Vector2(-1.0 if i % 2 == 0 else 1.0, 0.0), 0.05)
	tween.tween_property(body, "position", Vector2.ZERO, 0.02)
	tween.tween_callback(func() -> void: _winding_up = false)


## Telegraph before a monster skill: its `base` animation ("cast" unless the skill says,
## SkillDef.cast_animation) fitted to `duration`, else "cast", else the wind-up pose. A looping
## `base` (a pose: the Nameless Keeper's idle, NamelessKeeperDef.cast_pose) plays at its own
## pace and is held for `duration` (it would never finish), facing the aim.
func play_cast(aim: Vector2, duration: float, base: StringName = &"cast") -> void:
	if _dead or body.sprite_frames == null:
		return
	direction = direction_name(aim)
	var animation := _animation_for(base)
	if animation == &"" and base != &"cast":
		animation = _animation_for(&"cast")
	if animation == &"":
		play_windup(aim, duration)
		return
	_winding_up = true
	body.stop()
	if body.sprite_frames.get_animation_loop(animation):
		body.play(animation)
		_cast_holds += 1
		var held := _cast_holds
		var hold := create_tween()
		hold.tween_interval(maxf(duration, 0.05))
		hold.tween_callback(func() -> void:
			if held == _cast_holds:
				_winding_up = false)  # (not a later cast's)
		return
	body.play(animation, maxf(0.1, _length(body.sprite_frames, animation) / maxf(duration, 0.05)))


## A pose the body keeps until release_pose() (a maw held open): `base` played once from its
## start (backwards with `backwards`), then held on its last frame; idle, walk and hits wait.
## False if the frames have no such animation.
func hold_pose(base: StringName, speed: float = 1.0, backwards: bool = false) -> bool:
	var animation := _animation_for(base)
	if _dead or animation == &"":
		return false
	_held = true
	body.stop()
	if backwards:
		body.play_backwards(animation)
		body.speed_scale = speed
	else:
		body.play(animation, speed)
	return true


## Back to idle and walk after hold_pose().
func release_pose() -> void:
	_held = false
	body.speed_scale = 1.0


## A boss waking up in its arena ("intro" animation, if it has one).
func play_intro() -> void:
	if _dead or body.sprite_frames == null or _animation_for(&"intro") == &"":
		return
	_winding_up = true
	_play(&"intro", 1.0, true)


## How long animation `base` lasts, in seconds (0: the actor has none). A cinematic waits for it.
func animation_length(base: StringName) -> float:
	if body.sprite_frames == null:
		return 0.0
	var animation := _animation_for(base)
	return _length(body.sprite_frames, animation) if animation != &"" else 0.0


## Plays a one-shot animation by its name (a cinematic step: a warden's "intro").
func play_named(base: StringName) -> void:
	if base == &"intro":
		play_intro()
	elif not _dead:
		_play(base, 1.0, true)


## Hit (by `element`: a storm hit crackles over the body).
func play_hurt(element: VfxElementDef = null) -> void:
	look.hit(element)
	_flash = FLASH_TIME
	_squash = SQUASH_TIME
	_hurt = HURT_TIME


func play_death() -> void:
	_dead = true
	_held = false
	body.speed_scale = 1.0
	_attacking = false
	weapon.visible = false
	_update_back()
	if not _play(&"dead", 1.0, true):
		# No death frames: fall over.
		var tween := create_tween()
		tween.tween_property(squash_node, "rotation", -PI / 2.0, 0.25)


## Goes as `death` says in `element`'s ramp (the body shader's death), then `finished` is
## called (monster deaths; what flies off it: DeathFx).
func dissolve(death: DeathLookDef, element: VfxElementDef, finished: Callable) -> void:
	look.die(death, element)
	var tween := create_tween()
	tween.tween_interval(death.delay)
	tween.tween_method(look.set_dying, 0.0, 1.0, death.duration)
	tween.tween_callback(finished)


## Texture and transform of what the body shows right now (for afterimages).
func current_frame() -> Texture2D:
	if body.sprite_frames == null or body.animation == &"":
		return null
	return body.sprite_frames.get_frame_texture(body.animation, body.frame)


func _process(delta: float) -> void:
	if not Vfx.shown:
		return  # a simulation: nothing to see (Vfx.shown)
	_flash = maxf(_flash - delta, 0.0)
	_squash = maxf(_squash - delta, 0.0)
	if not on_view:
		return  # (its owner says it is out of view: nothing to keep up there)
	var t := _squash / SQUASH_TIME
	squash_node.scale = Vector2(1.0 + 0.25 * t, 1.0 - 0.2 * t)
	look.set_shared(&"flash_amount", 1.0 if _flash > 0.0 else pallor)
	if pallor > 0.0:
		look.set_shared(&"flash_color", Color.WHITE if _flash > 0.0 else pallor_color)
	_sync_layers()
	if carries_weapon:
		if gear.fewer_changed():
			_dress_weapon()
			gear.retrim_wear()
		_update_back()


## Armor layers show the same animation and frame as the body (hidden if they don't have it).
func _sync_layers() -> void:
	var layered := false
	for layer in _layers:
		if layer.sprite_frames == null:
			continue
		var shown := layer.sprite_frames.has_animation(body.animation)
		layer.visible = shown
		layered = layered or shown
		if shown:
			if layer.animation != body.animation:
				layer.animation = body.animation
			layer.frame = body.frame
	look.layered = layered


## The shader's idea of the body's frame (its quad in the sprite's local space, art pixels), so
## its heights, edges and deaths are measured on the frame shown, never reading the next frame
## of the sheet.
func _fit_frame() -> void:
	if body.sprite_frames == null or not body.sprite_frames.has_animation(body.animation):
		return
	var texture := body.sprite_frames.get_frame_texture(body.animation, body.frame)
	if texture == null:
		return
	var size := texture.get_size()
	var corner := body.offset - (size / 2.0 if body.centered else Vector2.ZERO)
	look.set_frame(Rect2(corner, size))


# --- Helpers -----------------------------------------------------------------

## "walk" -> "walk_left" if it exists, else "walk", else "" (RigAnimations.pick()).
func _animation_for(base: StringName) -> StringName:
	return RigAnimations.pick(body.sprite_frames, base, direction)


func _play(base: StringName, speed: float = 1.0, restart: bool = false) -> bool:
	var animation := _animation_for(base)
	if animation == &"":
		return false
	if restart or body.animation != animation or not body.is_playing():
		body.play(animation, speed)
	return true


static func _length(frames: SpriteFrames, animation: StringName) -> float:
	return RigAnimations.length(frames, animation)


func _lunge(aim: Vector2) -> void:
	var forward := aim.normalized() * 5.0
	var tween := create_tween()
	tween.tween_property(squash_node, "position", -forward * 0.4, 0.06)
	tween.tween_property(squash_node, "position", forward, 0.06)
	tween.tween_property(squash_node, "position", Vector2.ZERO, 0.12)


func _spawn_fx(sheet: Texture2D, aim: Vector2, extra_rotation: float, element: VfxElementDef = null) -> void:
	var at := Vector2(0, -CHEST_HEIGHT) + aim.normalized() * FX_DISTANCE
	add_child(SheetVfx.create(sheet, at, aim.angle() + extra_rotation, 2.0, 18.0).in_element(element))


func _end_attack() -> void:
	_attacking = false
	weapon.visible = false
	_update_back()


func _on_body_animation_finished() -> void:
	var animation := String(body.animation)
	if animation.begins_with("attack") and _attacking:
		_end_attack()
	elif _winding_up:
		_winding_up = false  # a cast (whichever animation it plays) or an intro is over


# --- The hero's gear: the weapon at rest, rarity, elements (GearLook) ---------------------------

## Whether the weapon at rest shows now (not while it is in hand, nor once dead).
func shows_back_weapon() -> bool:
	return gear.shows_back_weapon()


## The weapon at rest (null for a rig that carries none), and the motes of its elements.
func back_weapon() -> Sprite2D:
	return gear.back_weapon()


func weapon_aura() -> WeaponAura:
	return gear.weapon_aura()


## The material the weapon wears (in hand and at rest), null before the hero carries one.
func weapon_material() -> ShaderMaterial:
	return gear.weapon_material()


## The material of a worn piece's layer (HEAD or BODY), null while it shares the body's.
func wear_material(slot: EquipmentDef.Slot) -> ShaderMaterial:
	return gear.wear_material(slot)


func _dress_weapon() -> void:
	gear.dress_weapon(_weapon_def)
	_update_back()


## The weapon at rest placed for the facing and the body's frame, or hidden while the weapon is in
## hand, while winding up or charging, and once dead.
func _update_back() -> void:
	gear.update_back(carries_weapon and not _attacking and not _winding_up and not _charging and not _dead and body.visible)


func _fit_weapon_frame() -> void:
	gear.fit_weapon_frame()
