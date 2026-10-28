class_name EmberTrailPassive
extends Passive
## Rolling leaves a trail of embers on the floor (EmberTrail): for `life` seconds, enemies whose
## body touches it catch fire (`status`) and take a little damage every `pulse`. The roll leaves
## something behind, so rolling through and around a pack, then fighting at the trail's edge,
## becomes the way to play it (Cinder Wake, the Inferno family).

## Seconds each ember burns.
@export var life: float = 3.0
## Seconds between two burns of the enemies in it.
@export var pulse: float = 0.5
## How far from an ember an enemy's body still burns (world units, past its radius).
@export var reach: float = 12.0
## Damage of each burn = the owner's power x this, per stack (a secondary hit: no on-hit perks).
@export var damage_multiplier: float = 0.15
## Left on the enemies it burns (flames).
@export var status: OnHitStatus
## What it is made of (fire): its hits' flash, its flames.
@export var element: VfxElementDef


func on_dash(owner: Actor, perk: PerkSet.Entry) -> void:
	if owner.world == null or not is_instance_valid(owner.world):
		return
	var trail := EmberTrail.new()
	trail.setup(owner, self, perk.stacks)
	owner.world.spawn_vfx(trail)  # (not cosmetic: it burns in a simulation too)


## Shows as the element it burns with (ItemLook).
func look_element() -> VfxElementDef:
	return element
