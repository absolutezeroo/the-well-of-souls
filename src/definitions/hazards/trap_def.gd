class_name TrapDef
extends HazardDef
## A floor trap that hurts anyone on it (player and monsters alike: lure them in!).
## Cycle: idle > warning (the danger peeks out) > active (hurts) > idle again.

enum Trigger {
	## Runs on its own timer. Traps placed together share a rhythm.
	TIMED,
	## Waits until someone steps on it, then warns and fires.
	STEP,
}

@export var trigger: Trigger = Trigger.TIMED
## Drawn all the time (holes in the floor, a vent, a pressure plate...).
@export var base_texture: Texture2D
## Drawn while armed with STEP traps once pressed (e.g. the pressed plate). Optional.
@export var pressed_texture: Texture2D
## Frames in a row: the danger itself (spikes, flames). Played during the active phase.
@export var active_sheet: Texture2D
@export_range(1, 64) var active_frames: int = 1
@export var active_fps: float = 12.0

@export_group("Timing")
@export var idle_time: float = 1.6
@export var warning_time: float = 0.45
@export var active_time: float = 0.7

@export_group("Damage")
## Damage on each actor caught, once per activation. Grows with depth (DungeonConfig).
@export var damage: int = 6
## Statuses left on whoever is caught (burn, poison, slow...).
@export var status: OnHitStatus
@export var knockback: float = 120.0
@export var sound: AudioStream


## How long it really warns: `warning_time`, never under the fairness floor of a trap
## (CombatRulesDef.blast_warning(), docs/decisions/0008). Trap asks here, the one place.
func warning_seconds() -> float:
	return Combat.RULES.blast_warning(warning_time)


## Damage of one activation on this floor (depth and difficulty included).
func damage_on(world: World) -> int:
	return world.rules.dungeon_damage(damage)


## The trap goes off (start of the active phase).
func on_fire(_trap: Trap) -> void:
	pass


## One more shot of a volley it started (Trap.start_volley()), on the trap's own clock.
func volley_shot(_trap: Trap) -> void:
	pass


## Every physics frame of the active phase: hurts whoever stands on it.
func while_active(trap: Trap) -> void:
	trap.hurt_overlapping()


## TIMED traps form a row across the room firing in a wave, STEP ones are scattered plates.
func place(world: World, room: Rect2i, taken: Dictionary) -> void:
	var rng := world.rng
	var cells := inner_cells(world, room, taken)
	if cells.is_empty():
		return
	if trigger == Trigger.TIMED:
		var step := Vector2i.RIGHT if rng.randf() < 0.5 else Vector2i.DOWN
		var origin: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		for i in rng.randi_range(3, 5):
			var cell := origin + step * i
			if not cells.has(cell):
				break
			world.spawn_trap(self, cell, i * 0.25)
			taken[cell] = true
	else:
		for i in rng.randi_range(2, 3):
			var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
			if not taken.has(cell):
				world.spawn_trap(self, cell)
				taken[cell] = true
