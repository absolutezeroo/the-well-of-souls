class_name CaptiveSoulsDef
extends TrialDef
## The Souls of Kagari: villagers Tôma gave to the Well on the moonless night, held in a room by
## chains of tar (CaptiveSoulsTrial). The hero frees each by standing by it (`free_seconds`);
## the Well sends foes to take them back as he starts.

## How many souls wait.
@export_range(1, 8) var souls_min: int = 3
@export_range(1, 8) var souls_max: int = 4
## Seconds standing by a soul to free it (the time stops while he steps away, it is not lost).
@export_range(0.5, 10.0, 0.5) var free_seconds: float = 3.0
## How close he must stand (px).
@export_range(16.0, 96.0, 1.0) var reach: float = 40.0
## Health given back by each soul freed (a share of his max).
@export_range(0.0, 0.5, 0.01) var heal_share: float = 0.06
## What the souls look like: a villager's frame each (a 16x16 picture, facing us).
@export var looks: Array[Texture2D] = []
## The souls' pale colors.
@export var element: VfxElementDef


func plan(world: World, rng: RandomNumberGenerator, excluded: Array[int]) -> Dictionary:
	var map := world.map
	var best := -1
	var best_area := 0
	var order: Array = range(1, map.rooms.size())
	RandomUtils.shuffle(order, rng)
	for i: int in order:
		if excluded.has(i) or not map.plan(i).is_quiet():
			continue
		var area := map.rooms[i].get_area()
		if area > best_area:
			best = i
			best_area = area
	if best < 0:
		return {}
	return { "room": best, "count": rng.randi_range(souls_min, maxi(souls_min, souls_max)), "seed": rng.randi() }


func make(world: World, planned: Dictionary, taken: Dictionary) -> RoomTrial:
	var trial := CaptiveSoulsTrial.new()
	trial.setup_souls(world, self, int(planned.room), int(planned.count), int(planned.seed), taken)
	return trial
