class_name MonsterRankDef
extends Resource
## How rare a monster comes: Elite (one affix), Epic (two), Legendary (three), Shiny (no affix,
## different colors, a treasure)... Rarer ranks are tougher and pay more. Bosses roll for the
## rare ranks too (`boss_chance`): a Legendary Vampiric King Slime. See World.roll_elite().

@export var id: StringName
@export var display_name: String
## Its aura, its name over the monster.
@export var color: Color = Color.WHITE
## Shown before the monster's name ("Legendary Skeleton"). Off for plain elites ("Vampiric Skeleton").
@export var show_in_name: bool = true
## Elite affixes it gets (EliteAffixDef: Swift, Vampiric...), all different.
@export_range(0, 4) var affixes: int = 1

@export_group("Toughness")
@export var hp_multiplier: float = 2.5
## Added to `hp_multiplier` for each depth below the first: the hero's power grows faster than
## the monsters' depth scaling, so a ranked monster deeper down needs more health to stay a duel.
@export var hp_multiplier_per_depth: float = 0.0
## Multiplies its attacks and skills (not bosses: they keep their own damage).
@export var damage_multiplier: float = 1.0
## Its body is this much wider (collision, reach, shadow, aura): a gameplay size only. The art
## stays at scale 2 (decision 0007: never 1.25); the rank shows by its rim, aura and name.
@export var radius_multiplier: float = 1.125
## At least this much knockback resistance.
@export_range(0.0, 1.0) var knockback_resistance: float = 0.5

@export_group("Rewards")
@export var xp_multiplier: int = 3
## Quality of what it drops (1 = a common monster; see LootRoller).
@export var loot_quality: float = 2.5
## Random items dropped on top of its loot.
@export_range(0, 6) var bonus_drops: int = 1
@export var gold_multiplier: float = 4.0

@export_group("Chance")
## Chance for a monster spawned at `min_depth` or deeper, plus `chance_per_depth` per floor, at
## most `max_chance` (times the difficulty's elite chance).
@export_range(0.0, 1.0) var chance: float = 0.0
@export_range(0.0, 0.1) var chance_per_depth: float = 0.0
@export_range(0.0, 1.0) var max_chance: float = 0.5
@export var min_depth: int = 1

@export_group("Bosses")
## Chance for a boss to come at this rank (0: never).
@export_range(0.0, 1.0) var boss_chance: float = 0.0
@export var boss_hp_multiplier: float = 1.0
## More relics to choose from when it falls.
@export_range(0, 3) var extra_relics: int = 0

@export_group("Look")
## Turns its colors around the color wheel (0: no change; 0.5: the opposite colors).
@export_range(0.0, 1.0) var hue_shift: float = 0.0
## A gleam sweeping across its body, and sparkles around it.
@export var shimmer: bool = false
## Rings of its aura at its feet.
@export_range(0, 3) var aura_rings: int = 1


## Health multiplier of a (non-boss) monster of this rank spawned at `depth`.
func hp_multiplier_at(depth: int) -> float:
	return hp_multiplier + hp_multiplier_per_depth * maxi(depth - 1, 0)


func chance_at(depth: int) -> float:
	if depth < min_depth:
		return 0.0
	return minf(chance + chance_per_depth * (depth - min_depth), max_chance)
