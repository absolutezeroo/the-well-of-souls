class_name FirstStepsDef
extends Resource
## The first runs' gentle start (decision 0010, design/dungeon.md "First steps"): on floor `depth`
## of a profile's first `runs` runs (never a Dawn Knell), monsters leave the hero alone while he
## stands in the room he starts in, until he has walked `move_distance` and swung once; and the
## nearest room with monsters holds a single `monster` instead, made slow and plainly telegraphed
## by the numbers below (FirstSteps.make_monster()): it dies in 2 or 3 blows of the starting
## katana (first_run tests).

## The profile's first runs (Profile.runs, counted as a run begins) that start gently.
@export_range(0, 20) var runs := 3
## The floor they start gently on.
@export_range(1, 10) var depth := 1
## Pixels the hero must walk (and one swing) before the monsters see him in his first room.
@export var move_distance := 110.0
## The first monster met: its kind (look, sounds, bestiary page and kill count are the kind's)...
@export var monster: MonsterDef
## ...and what it is here instead of the kind's: its Health, Armor and speed,
@export var stats: StatBlock
## its wind-up and recovery (seconds: slow and plainly shown),
@export var attack_windup := 0.8
@export var attack_recovery := 0.6
## and how far it spots the hero.
@export var detect_radius := 200.0
