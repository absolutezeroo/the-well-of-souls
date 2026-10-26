class_name DeathSpawnTrait
extends MonsterTrait
## Monsters come out when it dies (a giant slime splitting in two...). Not down a hole.

@export var monsters: Array[MonsterDef] = []
@export_range(1, 8) var count: int = 2


func on_died(monster: Monster, _killer: Actor, fell: bool, _rewards: bool) -> void:
	if fell or monsters.is_empty():
		return
	monster.world.spawns.defer_monsters(monsters, count, monster.global_position, 24.0, monster.target)


func describe() -> String:
	return tr("Splits when it dies.")
