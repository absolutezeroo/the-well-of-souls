class_name PyreKillPassive
extends KillBurstPassive
## Every kill a pyre (Funeral Pyre, a relic that bends a rule, the Inferno family): every enemy
## the owner slays explodes (KillBurstPassive's blast, whatever killed it), and the blast burns
## the owner too when he stands in it: `self_damage` of his max Health, as a tick that never
## deals the last blow (a relic's own cost leaves 1 Health: docs/design/builds.md "Rule-bending
## relics"). Rolling through it (invulnerable) or striking from its edge spares him: a melee
## build learns to step back from what it kills, a ranged one shrugs.

@export_range(0.0, 0.3, 0.01) var self_damage: float = 0.06


func on_kill(owner: Actor, victim: Actor, perk: PerkSet.Entry) -> void:
	if victim.is_falling:
		return
	var at := victim.global_position
	super.on_kill(owner, victim, perk)
	if blast_radius <= 0.0 or owner.is_dead:
		return
	var reach := blast_radius + owner.radius
	if owner.global_position.distance_squared_to(at) > reach * reach:
		return
	Passive.pay_health(owner, self_damage, &"blast", blast_element, false)  # (a roll's invulnerability spares him)
