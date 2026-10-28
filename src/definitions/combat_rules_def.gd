class_name CombatRulesDef
extends Resource
## The game's core combat numbers (`data/combat/combat_rules.tres`, read through `Combat.RULES`):
## how hard a critical hit lands, how much a hit varies, how armor bites, how far a skill's
## cooldown can be cut. The most important balance numbers in the game, in data so a balance
## pass never touches code (docs/balance.md).

## A critical hit's damage multiplier, before the attacker's own bonus (Actor.crit_damage_bonus:
## the Oath of the Edge, perks).
@export_range(1.0, 4.0, 0.05) var crit_multiplier: float = 1.75
## Every hit (not a side effect's: Combat.make_secondary_hit) deals its amount times a random
## factor within 1 - this and 1 + this.
@export_range(0.0, 0.5, 0.01) var damage_variance: float = 0.15
## Armor with diminishing returns: a hit of A against D armor deals A x A / (A + this x D)
## (Combat.mitigate). 1: about D points off a much bigger hit, half of a hit the armor's size,
## never harmless.
@export_range(0.1, 4.0, 0.05) var armor_weight: float = 1.0
## Cooldown reduction (StatBlock.cooldown_reduction) counts up to this share (SkillSet): past it,
## more is wasted.
@export_range(0.0, 0.9, 0.05) var max_cooldown_reduction: float = 0.5
## How hard a delayed blast (a skull's fuse, a bomb's: Combat.delayed_blast) pushes what it hits.
@export var delayed_blast_knockback: float = 260.0

@export_group("Fairness contract (docs/decisions/0008)")
## A monster's attack that hurts winds up at least this long (seconds), after every multiplier
## (the difficulty, an ascension, a boss's phases): harder modes shorten nothing under it.
@export_range(0.1, 2.0, 0.05) var min_monster_windup: float = 0.4
## A boss's attack that hurts, the same (its blows are heavier).
@export_range(0.1, 2.0, 0.05) var min_boss_windup: float = 0.5
## Shockwaves, delayed and posthumous blasts, traps and fused explosives warn at least this long.
@export_range(0.1, 2.0, 0.05) var min_blast_warning: float = 0.4
## The share of what a floor adds to a monster's wind-up or cast that comes off the wait before its
## next blow or that skill (Monster.keep_attack_tempo(), keep_skill_tempo()): 1, its rhythm stays
## what its data, the difficulty and its phase make it, only its warning is longer. The challenge
## of a fast monster, a boss's last phase or Nightmare stays in its tempo, not in a warning too
## short to read (decision 0008; balance log, 28 Oct 2026). Never below its recovery.
@export_range(0.0, 1.0, 0.05) var floor_tempo_kept: float = 1.0


## How long a wind-up of `seconds` (every multiplier already in) really lasts: never under the
## floor of a monster's (`boss`: a boss's) attack (Monster.windup_for(), the one place it is
## asked).
func monster_windup(seconds: float, boss: bool) -> float:
	return maxf(seconds, min_boss_windup if boss else min_monster_windup)


## How long the warning of a shockwave, a blast's fuse or a trap's click really lasts.
func blast_warning(seconds: float) -> float:
	return maxf(seconds, min_blast_warning)
