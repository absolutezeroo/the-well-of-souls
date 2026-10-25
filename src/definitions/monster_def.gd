class_name MonsterDef
extends ContentDef
## Everything that makes a monster type: stats, weapon, skills, behaviour and rewards.

@export var stats: StatBlock
## Monsters attack with a regular weapon, just like the player.
@export var weapon: WeaponDef
@export var skills: Array[SkillDef] = []

@export_group("Body")
@export var radius: float = 12.0
## Animations: idle_/walk_/attack_/hit_ + down, up, left, right, and "dead". Missing ones fall back.
@export var frames: SpriteFrames
## Moves the sprite so its feet stand on the actor's position (art pixels).
@export var frames_offset: Vector2 = Vector2(0, -7)
## Height of the sprite above the feet, in world pixels (for damage numbers and emotes).
@export var head_height: float = 34.0
## Flies over holes and quicksand (bats, ghosts...).
@export var flies: bool = false
## What it leaves on the floor when hit or killed (blood, slime, ink...). Alpha 0: nothing
## (spirits, flames, skulls). Blood is the blood element's mark (its ramp's darkest step).
@export var splat_color: Color = Color(0.352941, 0.039216, 0.117647, 0.85)
## What it is made of: how hits on it sound, its sparks, the chips it leaves when it dies.
@export var material: ImpactMaterialDef
## How much of the knockback it ignores: 0 = pushed around freely, 1 = never moves.
## Bosses stand their ground, so no weapon can keep them away from you.
@export_range(0.0, 1.0, 0.05) var knockback_resistance: float = 0.0
## Shows its gear as the hero does (ActorRig.carries_weapon): its weapon at rest on its back, the
## trims of its rarities, the elements it carries (the Nameless Keeper, in the hero's own gear).
@export var shows_gear: bool = false

## Special ways it fights: a shield, stealing gold, bursting or splitting when it dies...
## (see src/definitions/monster_traits/).
@export var traits: Array[MonsterTrait] = []
## Affix compatibility labels, independent of the sprite and the monster's stable id.
@export var tags: Array[StringName] = []

@export_group("Behaviour")
## Distance at which the monster notices the player (needs line of sight).
@export var detect_radius: float = 260.0
## Chasing, it sees this many times further (Monster.chase_detect_radius()), and gives up after
## this many seconds without seeing its target (back to wandering).
@export_range(1.0, 4.0, 0.05) var chase_sight_multiplier: float = 1.6
@export_range(0.5, 20.0, 0.5) var chase_give_up_after: float = 4.0
## Share of its move speed it wanders at, before it notices anyone.
@export_range(0.0, 1.0, 0.05) var wander_speed: float = 0.35
## Telegraph time before each attack: the player's window to dodge.
@export var attack_windup: float = 0.35
## Pause after attacking.
@export var attack_recovery: float = 0.3
## How its body warns while it winds up or casts (the red area on the ground warns either way):
## TINT glows the whole body red (most monsters); RIM draws a red rim round its silhouette
## instead, for a body whose own colors must keep reading (the Maw's gold mask).
enum CastWarning { TINT, RIM }
@export var cast_warning: CastWarning = CastWarning.TINT
## Ranged monsters back off when the player is closer than this. 0 = always close in.
@export var keep_distance: float = 0.0

@export_group("Sounds")
## Leave empty to use the defaults from the SoundBank.
@export var hurt_sound: AudioStream
@export var death_sound: AudioStream

@export_group("Rewards")
@export var xp_reward: int = 5
## Its own bestiary challenges, on top of the common ones (BestiaryRules).
@export var challenges: Array[HuntChallenge] = []
@export var loot: LootTable
## Where its loot, runes and gold land, from its feet (world units): in front of a huge body
## that stays where it fell (the Maw: past its jaw and its pool), never under it. Zero: around
## its feet.
@export var loot_offset: Vector2 = Vector2.ZERO
