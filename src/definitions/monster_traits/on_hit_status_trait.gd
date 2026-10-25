class_name OnHitStatusTrait
extends MonsterTrait
## Reusable status payload for monster hits. The same data can belong to a species or an
## affix; delivery uses the normal hit hook. Secondary hits and ticks cannot refresh themselves.

@export var status: OnHitStatus


func on_hit_player(monster: Monster, player: Player, hit: HitInfo = null) -> void:
	if hit and hit.is_secondary:
		return
	if status:
		status.apply_to(player, monster)


func describe() -> String:
	return status.describe() if status else ""
