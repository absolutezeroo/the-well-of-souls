class_name SplitShotPassive
extends Passive
## A shot that strikes an enemy splits (Riven Glyph, the Arcane family): `count` smaller
## bolts (`count_per_stack` more a level above the first) fly on from the far side of the body,
## fanned around the shot's way, each dealing `damage_share` of the hit. Only a direct shot splits
## (HitInfo.shot: arrows, bolts, stars, thrown kunai; an exploding shot's blast is no shot); the bolts are
## secondary (ProjectileSpec.secondary): they never split again, trigger no on-hit perk and get
## no extra projectiles. A crowd behind the first enemy is where it pays; a lone boss takes only
## the first hit. At most `max_per_frame` splits in one physics frame (a ring of sixteen stars
## landing at once must not throw out forty-eight bolts).

## Bolts at level 1 (an odd number sends one straight on, at the enemy behind).
@export var count: int = 3
@export var count_per_stack: int = 2
## Each bolt's damage = the hit's (before armor) x this.
@export_range(0.1, 1.0, 0.05) var damage_share: float = 0.3
## Degrees between the outermost bolts.
@export var spread_degrees: float = 50.0
@export var speed: float = 380.0
@export var distance: float = 150.0
@export var max_per_frame: int = 4
## What the bolts are made of (arcane): their look in flight and where they land.
@export var element: VfxElementDef


func on_hit_dealt(owner: Actor, target: Actor, hit: HitInfo, _damage: int, perk: PerkSet.Entry) -> void:
	if hit.is_secondary or hit.shot == Vector2.ZERO or target == null or owner.world == null:
		return
	var frame := Engine.get_physics_frames()
	if perk.memory.get("_frame", -1) != frame:
		perk.memory["_frame"] = frame
		perk.memory["_splits"] = 0
	if int(perk.memory["_splits"]) >= max_per_frame:
		return
	perk.memory["_splits"] = int(perk.memory["_splits"]) + 1
	var spec := ProjectileSpec.new()
	spec.damage = maxi(1, roundi(hit.amount * damage_share))
	spec.speed = speed
	spec.radius = 4.0
	spec.max_distance = distance
	spec.count = count + count_per_stack * (perk.stacks - 1)
	spec.spread_degrees = spread_degrees
	spec.knockback = 60.0
	spec.element = element
	spec.color = element.color() if element else Color.WHITE
	spec.glow = 0.6
	spec.secondary = true
	# From just past the far side of the body: the bolts never strike the enemy that split them.
	var from := target.global_position + hit.shot * (target.radius + 4.0)
	owner.world.fire_projectiles(owner, hit.shot, spec, from)


## Shows as the element it splits into (ItemLook).
func look_element() -> VfxElementDef:
	return element
