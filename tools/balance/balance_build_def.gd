class_name BalanceBuildDef
extends Resource
## A hero as the balance tools test it: level, gear, runes, perks and shrine upgrades, all as data
## (data/balance/builds/*.tres). The model (BalanceModel) and the arena (BalanceArena) put it on a
## real Player with BalanceBuild.apply() and measure what it does against each boss.
## Ids are the content's own (`PerkDef.id`, `RuneDef.id`, `ItemAffixDef.id`, `UpgradeDef.id`);
## an unknown id is reported by BalanceBuild.problems() and by the balance test suite.

## Short unique name, used on the command line (--build=expected_a1) and in the reports.
@export var name: String = ""
## Why the build looks like this: where its level, gear and perks come from.
@export_multiline var description: String = ""
## "baseline" (a fresh hero), "expected" (what an average player has at that act's boss),
## "degenerate" (one thing stacked as hard as the game allows), "kit" (the expected build sworn
## to a starting kit, measured against it). Targets differ by tag.
@export var tags: PackedStringArray = []
## The act whose bosses (and monsters) this build is measured against (1-4).
@export_range(1, 4) var act: int = 1
## Hero level (each level above 1 adds PlayerDef.level_bonus, as a level up does).
@export_range(1, 40) var level: int = 1
## Item level of all its gear (ItemLevelRules): 0 = found on the floor before its act's boss
## (BalanceContent.boss_depth - 1), the usual case; 1 = plain floor-1 gear.
@export_range(0, 60) var item_level: int = 0

@export_group("Weapon")
## The plain weapon (data/items/weapons/...).
@export var weapon: WeaponDef
## ItemRarity: 0 Common, 1 Magic, 2 Rare, 3 Epic (more damage, more affixes, more rune sockets).
@export_range(0, 3) var weapon_rarity: int = 0
## The weapon's own item level when above 0 (1: the weapon a run starts with); 0: item_level.
@export_range(0, 60) var weapon_item_level: int = 0
## ItemAffixDef ids on the weapon ("sharp", "swift", "vampiric"...).
@export var weapon_affixes: PackedStringArray = []
## RuneDef ids set in its sockets ("leech_rune" twice = two Leech runes). At most its sockets
## (ItemRarity.SOCKETS: Common and Magic 1, Rare 2, Epic 3); extra ones are reported and dropped.
@export var runes: PackedStringArray = []

@export_group("Armor")
## Worn armor pieces (head and body).
@export var armors: Array[ArmorDef] = []
## Rarity of each piece, in the same order (missing = Common).
@export var armor_rarities: PackedInt32Array = []
## Affixes of each piece, in the same order, as "id,id" ("fortified,of_thorns"; missing = none).
@export var armor_affixes: PackedStringArray = []

@export_group("Perks and shrine")
## PerkDef id -> stacks ({"vampirism": 3, "strength": 1}). Relics too.
@export var perks: Dictionary = {}
## UpgradeDef id -> level bought at the shrine ({"vitality": 2, "might": 1}).
@export var upgrades: Dictionary = {}
## A spell taught by a tome (the 4th skill button), or none.
@export var learned_skill: SkillDef
## An oath or starting kit sworn (OathDef): its stats, its starting perks and its healing, as
## ShrineUpgrades.apply_to() and RunBoons give them (the weapon is the build's own: set it to the
## oath's). The kits are measured against the default start this way (balance-log 2026-10-28).
@export var oath: OathDef


## Not saved: set by the lab when it adds one thing to a build (BalanceBuild.variant()).
## Runes beyond the weapon's sockets are kept (a rune measured alone needs a socket).
var ignore_sockets := false
## Families woken without their perks (a family's bonus measured alone).
var extra_families: Array[SynergyDef] = []
## Families kept asleep even with their pieces (the build measured without a family's bonus).
var suppress_families: Array[SynergyDef] = []
## Timed bonuses on the hero for the whole measure (an encounter's buff): [StatBlock, seconds].
var buffs: Array = []
## Max health lost for the run (Blood Altar), as a share of the base max health.
var max_hp_cost := 0.0


func has_tag(tag: String) -> bool:
	return tags.has(tag)
