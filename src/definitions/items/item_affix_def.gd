class_name ItemAffixDef
extends ContentDef
## A random bonus on found equipment: "Sharp" (+attack), "of the Bear" (+HP), "Burning" (sets
## enemies on fire)... `display_name` is the word added to the item's name.
## Listed in content_db.tres > Item Affixes; `min_depth` and `spawn_weight` as usual.

const WEAPON := 1
const HEAD := 2
const BODY := 4

## Before the name ("Sharp Katana") or after it ("Katana of the Bear").
@export var is_prefix: bool = true
## Which equipment can get it.
@export_flags("Weapon", "Head", "Body") var slots: int = 7
@export var bonuses: StatBlock
## Weapons only: statuses left on what it hits (if the weapon has none of its own).
@export var on_hit: OnHitStatus
## What it does while worn (like a perk's: chain lightning, healing on kill...). Say it in
## `description` (shown on the item); stats describe themselves.
@export var passives: Array[Passive] = []
## Armor: worn, the piece's hem turns into a row of steel points (of Thorns: what hits you up
## close gets hurt). Its elements show by themselves (ItemLook); this is for an affix without one.
@export var worn_teeth: bool = false
## A staple (plain numbers, good in any build) or a build-around (an element's effect: burning,
## freezing, lightning, life drain, echoes): BuildRole. A build-around names its element's family.
@export var role: BuildRole.Role = BuildRole.Role.UNSET
## Its element's family (Inferno for Burning and of Embers, Frost for Frozen and Shattering...),
## as a rune names its own (RuneDef.family): where it belongs in a build. A tag: it wakes nothing.
@export var family: SynergyDef


func fits(item: EquipmentDef) -> bool:
	var flag := WEAPON if item.slot == EquipmentDef.Slot.WEAPON else (HEAD if item.slot == EquipmentDef.Slot.HEAD else BODY)
	if on_hit and not item is WeaponDef:
		return false
	return slots & flag != 0
