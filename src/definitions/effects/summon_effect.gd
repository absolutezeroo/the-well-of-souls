class_name SummonEffect
extends Effect
## Calls monsters next to the user. They join the user's fight right away: the first at once,
## the others one a frame after it (WorldSpawner.defer_monsters(): one heavy instantiation a frame
## at most, docs/performance.md).
## Its `element` (Effect.element): what they rise out of (data/vfx/elements/): its impact and a
## small ring of its pieces where each appears (spirits: a hollow ring and pale flames). Empty: a
## puff of smoke.

@export var monsters: Array[MonsterDef] = []
@export var count: int = 2
## Distance from the user where they appear.
@export var radius: float = 70.0
## Nothing is summoned once the floor holds this many monsters.
@export var max_alive: int = 8


func apply(user: Actor, _aim: Vector2) -> void:
	if monsters.is_empty() or count <= 0 or user.world.monster_count() >= max_alive:
		return
	var target: Actor = (user as Monster).target if user is Monster else null
	var batch := user.world.spawns.defer_monsters(monsters, count, user.global_position, radius, target)
	batch.summoned = true
	batch.element = element
	batch.max_alive = max_alive
	# The first answers the call at once (the rest from the next frames).
	batch.count -= 1
	user.world.spawns.spawn_from(batch)


func play_preview(preview: EffectPreview) -> void:
	preview.summon(self)
