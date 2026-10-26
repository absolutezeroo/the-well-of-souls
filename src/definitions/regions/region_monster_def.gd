class_name RegionMonsterDef
extends Resource
## One authored enemy. It remains dead until a future explicit renewal policy resets it.

@export var id: String
@export var cell: Vector2i
@export var monster: MonsterDef
@export var rank: MonsterRankDef
@export var affixes: Array[EliteAffixDef] = []
