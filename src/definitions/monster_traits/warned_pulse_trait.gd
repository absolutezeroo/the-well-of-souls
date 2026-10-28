class_name WarnedPulseTrait
extends MonsterTrait
## Places a fixed warning beneath an engaged monster, then strikes that spot. One reusable
## behaviour handles periodic pulses and hit-count ripostes. GroundStrike owns the warning and
## cancels the strike if its source dies, falls out of the world or leaves its floor.

## Seconds of engagement before each pulse; 0 disables the periodic trigger.
@export var interval: float = 0.0
## Direct hostile hits required; 0 disables the damage trigger. Hits during cooldown are ignored.
@export var hits_required: int = 0
## Seconds after the warning ends before another can begin.
@export var cooldown: float = 5.0
@export var fuse: float = 0.9
@export var radius: float = 48.0
@export var trigger_range: float = 180.0
## Scaled exactly once by FloorRules, like dungeon traps and death bursts.
@export var damage: int = 6
@export var knockback: float = 180.0
@export var shake: float = 0.15
@export var element: VfxElementDef
@export var status: OnHitStatus


## One owner's counters and pending strike; never retained on the shared resource.
class PulseState:
	extends RefCounted
	var remaining := 0.0
	var cooldown := 0.0
	var hits := 0
	var pending: GroundStrike


func make_state() -> RefCounted:
	return PulseState.new()


func on_spawn(monster: Monster) -> void:
	var state := monster.trait_state(self) as PulseState
	state.remaining = interval


func update(monster: Monster, delta: float) -> void:
	var state := monster.trait_state(self) as PulseState
	state.cooldown = maxf(0.0, state.cooldown - delta)
	if interval <= 0.0 or not _engaged(monster):
		return
	state.remaining = maxf(0.0, state.remaining - delta)
	if state.remaining <= 0.0:
		_start(monster, state)


func on_damaged(monster: Monster, hit: HitInfo, amount: int) -> void:
	if hits_required <= 0 or amount <= 0 or hit.is_secondary or hit.is_tick:
		return
	if not is_instance_valid(hit.source) or not monster.is_hostile_to(hit.source) or not _engaged(monster):
		return
	var state := monster.trait_state(self) as PulseState
	if state.cooldown > 0.0 or is_instance_valid(state.pending):
		return
	state.hits = mini(state.hits + 1, hits_required)
	if state.hits >= hits_required:
		_start(monster, state)


func _engaged(monster: Monster) -> bool:
	return monster.world != null and monster.is_inside_tree() and not monster.is_dead and monster.hp > 0 \
		and not monster.dormant and not monster.is_falling and not monster.ai_frozen() \
		and is_instance_valid(monster.target) and not monster.target.is_dead and monster.is_hostile_to(monster.target)


func _start(monster: Monster, state: PulseState) -> void:
	if state.cooldown > 0.0 or is_instance_valid(state.pending):
		return
	if not monster.can_see(monster.target, trigger_range):
		return
	var warning := monster.windup_for(fuse)  # the difficulty's and phases' share, never under the floor
	var pulse := GroundStrike.create(monster.world, monster, monster.global_position, radius, warning,
		monster.world.rules.dungeon_damage(damage), knockback, element)
	pulse.status = status
	pulse.shake = shake
	monster.world.spawn_vfx(pulse)
	state.pending = pulse
	state.cooldown = cooldown + warning
	state.remaining = interval
	state.hits = 0


func on_died(monster: Monster, _killer: Actor, _fell: bool, _rewards: bool) -> void:
	var state := monster.trait_state(self) as PulseState
	if is_instance_valid(state.pending):
		state.pending.queue_free()
	state.pending = null


func describe() -> String:
	if hits_required > 0:
		return tr("Warns before a riposte after %d direct hits. Cooldown: %g s.") % [hits_required, cooldown]
	return tr("Warns before a pulse every %g s in combat.") % interval
