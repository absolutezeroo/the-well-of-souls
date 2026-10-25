class_name FrenzyTrait
extends MonsterTrait
## Walks faster below a Health threshold. The speed is derived from current Health, so healing
## and a resumed wounded monster cannot leave a stale bonus in the shared stats resource.

@export_range(0.0, 1.0, 0.05) var health_ratio: float = 0.5
@export var speed_multiplier: float = 1.3
@export var element: VfxElementDef
@export var flash_radius: float = 18.0


## Only the transition's visual needs memory; speed always reads current Health.
class FrenzyState:
	extends RefCounted
	var active := false


func make_state() -> RefCounted:
	return FrenzyState.new()


func on_spawn(monster: Monster) -> void:
	monster.trait_state(self)  # allocate once, never in the frame hook


func move_speed_multiplier(monster: Monster) -> float:
	return speed_multiplier if _active(monster) else 1.0


func _active(monster: Monster) -> bool:
	return not monster.is_dead and monster.hp > 0 and monster.hp <= monster.get_max_hp() * health_ratio


func update(monster: Monster, _delta: float) -> void:
	var state := monster.trait_state(self) as FrenzyState
	var active := _active(monster)
	if active and not state.active and element and monster.world:
		Vfx.pop(monster.world, monster.global_position, element, flash_radius, Vector2.UP)
	state.active = active


func describe() -> String:
	return tr("Moves %d%% faster at or below %d%% Health.") % [roundi((speed_multiplier - 1.0) * 100.0), roundi(health_ratio * 100.0)]
