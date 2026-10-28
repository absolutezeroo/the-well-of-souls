class_name KillBurstPassive
extends Passive
## Slain enemies burst: a ring of shards flying out of the body and/or a blast around it.
## `condition` limits it to enemies that died burning, slowed... (ANY: every kill).

enum Condition { ANY, BURNING, POISONED, SLOWED }

@export var condition: Condition = Condition.ANY
## Chance per kill (1 = always).
@export_range(0.0, 1.0) var chance: float = 1.0

@export_group("Shards")
## Shards flying out (0 = none), plus `shards_per_stack` for each stack above the first.
@export var shards: int = 0
@export var shards_per_stack: int = 1
## Shard damage = the killer's power x this.
@export var shard_damage: float = 0.5
@export var shard_speed: float = 340.0
@export var shard_distance: float = 220.0
## The shards' color when they have no element.
@export var shard_color: Color = Palette.FROST
## What the shards are (Ice Shards: frost, the same shards as the skill).
@export var shard_element: VfxElementDef
@export var shard_status: OnHitStatus

@export_group("Blast")
## Blast around the body (0 = none).
@export var blast_radius: float = 0.0
## Blast damage = the killer's power x this, per stack.
@export var blast_damage: float = 0.8
@export var blast_status: OnHitStatus
## How hard the blast throws the enemies around (a pack thrown apart leaves a blade swinging at
## air: the Funeral Pyre's, on every kill, pushes little).
@export var blast_knockback: float = 160.0
## What the blast is made of (fire when empty).
@export var blast_element: VfxElementDef
## Unused since the blast takes its element's ramp (kept for old data).
@export var blast_color: Color = Palette.FIRE


func on_kill(owner: Actor, victim: Actor, perk: PerkSet.Entry) -> void:
	if victim.is_falling or randf() >= chance or not _matches(victim):
		return
	var world := owner.world
	var at := victim.global_position
	var count := shards + shards_per_stack * (perk.stacks - 1) if shards > 0 else 0
	if count > 0:
		var spec := ProjectileSpec.new()
		spec.damage = maxi(1, roundi(owner.get_power() * shard_damage))
		spec.speed = shard_speed
		spec.radius = 5.0
		spec.max_distance = shard_distance
		spec.count = count
		spec.spread_degrees = 360.0
		spec.knockback = 80.0
		spec.color = shard_element.color() if shard_element else shard_color
		spec.element = shard_element
		spec.status = shard_status
		spec.glow = 0.8
		spec.secondary = true  # caused by a passive: no on-hit perks (no lifesteal, no chains)
		world.fire_projectiles(owner, Vector2.from_angle(randf() * TAU), spec, at)
	if blast_radius > 0.0:
		var amount := maxi(1, roundi(owner.get_power() * blast_damage * perk.stacks))
		Combat.damage_area(world, owner, at, blast_radius, amount, blast_knockback, true, blast_status, blast_element)
		Vfx.explosion(world, at, blast_radius, blast_element)


func _matches(victim: Actor) -> bool:
	match condition:
		Condition.BURNING:
			return victim.statuses.has(&"burn")
		Condition.POISONED:
			return victim.statuses.has(&"poison")
		Condition.SLOWED:
			return victim.statuses.is_slowed()
	return true


## Shows as its blast's element, else its shards' (ItemLook).
func look_element() -> VfxElementDef:
	return blast_element if blast_element else shard_element
