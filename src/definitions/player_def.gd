class_name PlayerDef
extends Resource
## Starting setup and progression of the player character.

@export var display_name: String = "Hero"
@export var frames: SpriteFrames
@export var frames_offset: Vector2 = Vector2(0, -9)
@export var color: Color = Color("4fd1c5")
@export var radius: float = 11.0
@export var base_stats: StatBlock

@export_group("Starting kit")
@export var starting_equipment: Array[EquipmentDef] = []
@export var starting_items: Array[ItemDef] = []
## Skills the hero always has (the roll), on the first buttons. The weapon adds its own
## skills and a tome can teach one more (see Player.SKILL_COUNT).
@export var innate_skills: Array[SkillDef] = []
## Places added to every compartment of the bag (each has its own: BagCategoryDef.capacity in
## data/items/bag_categories.tres). 0: the compartments as they are.
@export_range(0, 40) var bag_bonus: int = 0

@export_group("Charged attack")
## Seconds the attack button must be held before the weapon's charge starts filling: a tap is
## always a plain attack (Player, AttackCharge).
@export_range(0.05, 0.6, 0.01) var charge_delay: float = 0.22
## Tap to charge (Settings.tap_to_charge): two taps within this many seconds start the charge.
@export_range(0.1, 0.6, 0.01) var double_tap_window: float = 0.3
## Played when the charge is full.
@export var charge_full_sound: AudioStream

@export_group("Feel")
## Seconds the hero can't be hurt after a hit (a tick never gives any: HitInfo.is_tick). The
## main number deciding how fast a crowd wears him down (the balance model caps hits on it).
@export_range(0.0, 2.0, 0.05) var hit_invulnerability: float = 0.6
## Seconds the hero can't be hurt after climbing out of a hole.
@export_range(0.0, 3.0, 0.05) var fall_invulnerability: float = 1.0
## A weapon swap starts the new weapon's skills on this cooldown (no free casts by swapping).
@export_range(0.0, 5.0, 0.1) var swap_cooldown: float = 1.5
## Skills and charged attacks aim at the closest enemy within this distance.
@export var skill_aim_range: float = 520.0
## A melee weapon aims at enemies this far beyond its reach (it turns to them, then swings).
@export var melee_aim_assist: float = 70.0
## A press of the attack, the roll or a skill that can't go yet (the weapon still swinging, the
## cooldown about to end) waits this many real seconds for it, a hit stop included: taps in a
## hurry are not lost, the newest press wins, and a press never fires long after it was made
## (docs/design/presentation.md "Feel limits": 0.1-0.15 s). Holding never chains attacks: it
## charges.
@export_range(0.0, 0.5, 0.01) var input_buffer: float = 0.12

@export_group("Leveling")
## Cards in an ordinary upgrade offer (level ups and encounters).
@export_range(1, 8) var perk_choices: int = 3
@export var xp_base: int = 20
@export var xp_growth: float = 1.5
## Added to the base stats on every level up.
@export var level_bonus: StatBlock


func xp_to_next_level(level: int) -> int:
	return roundi(xp_base * pow(xp_growth, level - 1))
