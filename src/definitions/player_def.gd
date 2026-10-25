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
## A press of the attack button while the weapon is still swinging waits this long for it (taps
## in a hurry are not lost; holding never chains attacks: it charges).
@export_range(0.0, 1.0, 0.05) var attack_buffer: float = 0.3

@export_group("Leveling")
## Cards in an ordinary upgrade offer (level ups and encounters).
@export_range(1, 8) var perk_choices: int = 3
@export var xp_base: int = 20
@export var xp_growth: float = 1.5
## Added to the base stats on every level up.
@export var level_bonus: StatBlock


func xp_to_next_level(level: int) -> int:
	return roundi(xp_base * pow(xp_growth, level - 1))
