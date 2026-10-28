class_name FrostOrbitPassive
extends Passive
## Shards of ice circle the owner (Rime Halo, the Frost family): `shards` (+ `shards_per_stack`
## a level above the first) evenly spaced on a ring of `orbit` world units, turning `turns` times
## a second. An enemy body a shard passes through is hurt and chilled (`status`), each enemy at
## most once every `rehit` seconds. It asks the hero to stay close to his foes and circle them,
## where the roll's family perks ask him to pass through. The hits are secondary (no on-hit perks).
## Drawn by a FrostOrbitVfx on the owner (frost's own shot, the shards of Ice Shards).

@export var shards: int = 2
@export var shards_per_stack: int = 1
@export var orbit: float = 44.0
## Turns a second.
@export var turns: float = 0.55
## How close to a shard a body must come to be hit (past its radius).
@export var shard_reach: float = 7.0
## Damage of a shard's hit = the owner's power x this.
@export var damage_multiplier: float = 0.45
@export var rehit: float = 0.6
@export var knockback: float = 70.0
## Left on the enemies hit (a chill).
@export var status: OnHitStatus
## What the shards are (frost).
@export var element: VfxElementDef


func ticks() -> bool:
	return true


## How many shards circle at `stacks` levels.
func shard_count(stacks: int) -> int:
	return shards + shards_per_stack * (maxi(1, stacks) - 1)


## The angle of the first shard (radians), from the owner's clock in `memory`.
static func angle_of(memory: Dictionary) -> float:
	return float(memory.get("_angle", 0.0))


func tick(owner: Actor, delta: float, perk: PerkSet.Entry) -> void:
	var memory := perk.memory
	var clock: float = memory.get("_clock", 0.0) + delta
	memory["_clock"] = clock
	var angle := fposmod(angle_of(memory) + TAU * turns * delta, TAU)
	memory["_angle"] = angle
	var count := shard_count(perk.stacks)
	if Vfx.shown:
		_keep_look(owner, perk, count)
	var world := owner.world
	if world == null or not is_instance_valid(world):
		return
	if not memory.has("_hit"):
		memory["_hit"] = {}
	var hit_at: Dictionary = memory["_hit"]
	var center := owner.global_position
	var outer := orbit + shard_reach
	for actor in world.actors_this_frame():
		if actor.is_dead or actor.faction == owner.faction:
			continue
		var offset := actor.global_position - center
		var reach := outer + actor.radius
		if offset.length_squared() > reach * reach:
			continue
		if not _crossed(offset, actor.radius, angle, count):
			continue
		var id := actor.get_instance_id()
		if clock - float(hit_at.get(id, -INF)) < rehit:
			continue
		if hit_at.size() > 24:
			hit_at.clear()  # old ones forgotten (the bodies that left)
		hit_at[id] = clock
		var hit := Combat.make_secondary_hit(owner, maxi(1, roundi(owner.get_power() * damage_multiplier)))
		hit.status = status
		hit.element = element
		hit.origin = center
		hit.knockback = offset.normalized() * knockback
		actor.take_hit(hit)


## Whether a shard is within reach of a body at `offset` from the owner.
func _crossed(offset: Vector2, body: float, angle: float, count: int) -> bool:
	var reach := shard_reach + body
	var reach_squared := reach * reach
	for i in count:
		var shard := Vector2.from_angle(angle + TAU * i / count) * orbit
		if offset.distance_squared_to(shard) <= reach_squared:
			return true
	return false


## The shards' look on the owner (made once, kept while it lives; cosmetic).
func _keep_look(owner: Actor, perk: PerkSet.Entry, count: int) -> void:
	var look: Variant = perk.memory.get("_look")
	if is_instance_valid(look) and look is FrostOrbitVfx:
		(look as FrostOrbitVfx).count = count
		return
	var orbit_look := FrostOrbitVfx.new()
	orbit_look.setup(perk.memory, self, count)
	owner.add_child(orbit_look)
	perk.memory["_look"] = orbit_look


## Shows as the element of its shards (ItemLook).
func look_element() -> VfxElementDef:
	return element
