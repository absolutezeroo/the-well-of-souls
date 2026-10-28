class_name WeaponDef
extends EquipmentDef
## A weapon. Used by the player and by monsters alike.
## Melee weapons hit everything in an arc; ranged weapons fire projectiles.

enum Kind { MELEE, RANGED }
## Which attack animation the wielder plays (see the WeaponAnimator in actor_rig.tscn).
## A weapon without icon (claws, bites) makes the wielder lunge instead.
enum AttackAnimation { SLASH, THRUST, SMASH, SHOOT }
## Where the hero carries it at rest (ActorRig, docs/vfx.md "The weapon at rest").
enum BackKind {
	## Across the back, on the diagonal: behind the body, in front when he turns his back to us.
	SLUNG,
	## At the belt, on his side (a tome, shurikens, a coiled whip).
	HIP,
}

@export var kind: Kind = Kind.MELEE
@export var damage: int = 4
## Seconds between two attacks.
@export var cooldown: float = 0.45
## Melee: reach beyond the body. Ranged: max projectile travel distance.
@export var reach: float = 36.0
@export var knockback: float = 140.0
@export var attack_animation: AttackAnimation = AttackAnimation.SLASH
## Weapon in hand during the attack: attack_down/up/left/right, frame by frame with the hero's attack.
@export var attack_frames: SpriteFrames
## Slash effect sheet (frames in a row) played in front of the wielder, turned toward the target
## (snapped to 16 directions). Only for blows that draw no swing arc (see shows_arc()).
@export var attack_fx: Texture2D
## Extra rotation of the slash effect, in degrees (depends on how the sheet is drawn).
@export var attack_fx_rotation: float = 0.0

## Skills you get while holding this weapon (2 at most): a staff makes you a mage,
## an axe a warrior... Monsters ignore them (their skills are in their MonsterDef).
@export var skills: Array[SkillDef] = []
## Hold the attack button, let go when full: the hero's charged attack with this weapon
## (data/skills/charged/). Monsters ignore it.
@export var charged: ChargedAttackDef

## Statuses left on whatever this weapon hits (poison fangs, burning claws...).
@export var on_hit: OnHitStatus
## What its blows or shots are made of (data/vfx/elements/): a ranged weapon without a
## projectile texture fires the element's projectile, a claw without an attack_fx strikes with
## the element's claw, and hits flash in the element's language (docs/vfx.md).
@export var element: VfxElementDef

@export_group("At rest")
## The weapon carried while the hero isn't attacking (assets/weapons/back/, made by
## tools/vfx/back_weapons.py): small pixel art at the in-hand size, a slung one drawn along the
## "/" diagonal with the end over the shoulder at the top right, never turned by code. None:
## nothing shows at rest (monsters' weapons).
@export var back_sprite: Texture2D
## Art pixels it is moved by from its kind's place (facing down; mirrored as the hero turns).
@export var back_offset: Vector2 = Vector2.ZERO
@export var back_kind: BackKind = BackKind.SLUNG

@export_group("Melee")
@export_range(10.0, 360.0) var arc_degrees: float = 110.0
## Alpha above 0: the swing draws its arc (SwingVfx; thrusts draw a streak), in the ramp of
## `element` (steel, `physical`, when it has none; an enemy's adds a warning rim). Alpha 0: no
## arc (claws, bites: their sheet is enough). Its color only tints the codex's preview.
@export var trail_color: Color = Color(0.94902, 0.917647, 0.945098, 0.85)
## The blow drawn as a slash of its own (a heavy club's double crescent, a spin) instead of the
## plain arc or the `attack_fx` sheet (data/vfx/slashes/).
@export var slash: SlashDef

@export_group("Sounds")
@export var attack_sound: AudioStream
## Played on the target when this weapon hits (monsters fall back to their own hurt sound).
@export var hit_sound: AudioStream

@export_group("Ranged")
@export var projectile_texture: Texture2D
## Frames in a row of `projectile_texture` (0 = square frames).
@export_range(0, 64) var projectile_frames: int = 0
## Drawn in flight instead of `projectile_texture`: a thing pre-drawn in 16 directions (an
## arrow: data/vfx/sheets/).
@export var projectile_sheet: VfxSheetDef
@export var projectile_speed: float = 460.0
@export var projectile_radius: float = 5.0
@export var projectile_count: int = 1
@export var spread_degrees: float = 0.0
## How many extra enemies a projectile can pass through.
@export var pierce: int = 0
## Each projectile's damage, times the wielder's power: below 1 for weapons that throw several
## at once or hit from afar in safety (a fan of three shurikens must not hit three times as hard).
@export_range(0.1, 2.0, 0.05) var projectile_damage: float = 1.0
## Magic shots glow in their color and burst on impact; 0 for plain things (shurikens, arrows).
@export_range(0.0, 1.0) var projectile_glow: float = 1.0

@export_group("Evolution")
## What the weapon does by itself while worn (an evolved weapon's gift: arrows that split, kills
## that burst...): joined to the wearer's perks like an affix's (PerkSet.set_gear).
@export var carried: Array[Passive] = []
## The weapon this one is the evolution of (null: a weapon of its own). It is made at a forge
## from that weapon, its sockets all holding runes of `evolution_family` while that family is
## awake (WeaponEvolution, docs/design/loot.md "Weapon evolutions"); never found or bought.
@export var evolved_from: WeaponDef
## The family it asks for: awake, and its runes in every socket of the weapon.
@export var evolution_family: SynergyDef
## What the smith says of a weapon that could become this one, while the player has never made
## it (a hint, in quotes; the codex shows "???" with it).
@export_multiline var evolution_hint: String


func _init() -> void:
	slot = Slot.WEAPON


## A melee weapon that sweeps draws its swing's arc (SwingVfx) and no sheet: the arc is how
## steel looks (docs/vfx.md). Claws and bites (no arc, `trail_color` alpha 0) and overhead
## smashes play their `attack_fx` sheet instead. One or the other, never both.
func shows_arc() -> bool:
	if kind != Kind.MELEE:
		return false
	return slash != null or (trail_color.a > 0.0 and attack_animation != AttackAnimation.SMASH)


func get_type_label() -> String:
	var label := tr("Melee weapon") if kind == Kind.MELEE else tr("Ranged weapon")
	return EquipmentDef.rarity_words(rarity, label) if rarity > ItemRarity.COMMON else label


func get_details() -> String:
	var text := tr("%d damage, %.1f hits/s") % [damage, 1.0 / maxf(cooldown, 0.01)]
	if kind == Kind.RANGED and projectile_count > 1:
		text += tr(", %d projectiles") % projectile_count
	if kind == Kind.RANGED and pierce > 0:
		text += tr(", pierces %d") % pierce
	if not skills.is_empty():
		var names := PackedStringArray()
		for skill in skills:
			names.append(tr(skill.display_name))
		text += "\n" + tr("Skills: %s") % ", ".join(names)
	if charged:
		text += "\n" + charged.describe()
	if on_hit and not (base_item and (base_item as WeaponDef).on_hit):
		text += "\n" + on_hit.describe()
	# The item level line first (EquipmentDef), then the weapon's numbers, then the rest.
	var base := super.get_details()
	var level_line := base.get_slice("\n", 0)
	var rest := base.substr(level_line.length() + 1) if base.contains("\n") else ""
	return level_line + "\n" + text + ("\n" + rest if not rest.is_empty() else "")
