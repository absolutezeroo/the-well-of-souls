class_name RegionMonsterDef
extends Resource
## One authored enemy. Only eligible dead enemies renew at an explicit refuge rest.

@export var id: String
@export var cell: Vector2i
@export var monster: MonsterDef
## Unique objective guardians opt out; loading and death never renew an enemy.
@export var renew_on_rest := true
@export var rank: MonsterRankDef
@export var affixes: Array[EliteAffixDef] = []
