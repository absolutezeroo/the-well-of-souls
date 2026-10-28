class_name ShotEmbersPassive
extends EmberTrailPassive
## What a shot lands on burns (the Ashen Codex, an evolved Ember Tome): a direct shot that strikes
## an enemy leaves a few embers on the floor there (EmberTrail.lay_at), burning as Cinder Wake's
## do. At most `max_per_frame` patches a frame (a fan of three embers lands at once). A roll
## leaves nothing (on_dash is not this one's).

@export var embers: int = 3
@export var max_per_frame: int = 1


func on_dash(_owner: Actor, _perk: PerkSet.Entry) -> void:
	pass


func on_hit_dealt(owner: Actor, target: Actor, hit: HitInfo, _damage: int, perk: PerkSet.Entry) -> void:
	if hit.is_secondary or hit.shot == Vector2.ZERO or target == null or owner.world == null:
		return
	var frame := Engine.get_physics_frames()
	if perk.memory.get("_frame", -1) != frame:
		perk.memory["_frame"] = frame
		perk.memory["_laid"] = 0
	if int(perk.memory["_laid"]) >= max_per_frame:
		return
	perk.memory["_laid"] = int(perk.memory["_laid"]) + 1
	var patch := EmberTrail.new()
	patch.lay_at(owner, self, target.global_position, embers)
	owner.world.spawn_vfx(patch)
