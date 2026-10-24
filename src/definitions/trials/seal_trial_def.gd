class_name SealTrialDef
extends TrialDef
## The Unbound Seal: a side room shut by a seal drawn on the floor before its door, a star with a
## lantern at each point, put out; the lanterns themselves stand in other rooms of the floor
## (SealTrial). Each one lit relights a point (the dark answers with foes); all lit, the seal
## breaks and the room's hoard is the hero's. Tôma undid the seal's knots; here the hero ties
## them back, one flame at a time.

## Lanterns to light (the star's points).
@export_range(2, 7) var lanterns: int = 5
## The hoard waiting inside.
@export var chest: ChestDef
## The lanterns' prop (lit: its light; out: dark).
@export var lantern: PropDef


func plan(world: World, rng: RandomNumberGenerator, excluded: Array[int]) -> Dictionary:
	var map := world.map
	var index := PactRoom.find_room(map, rng, excluded, world.config().corridor_width + 3)
	if index < 0:
		return {}
	# The lanterns: one a room, never in the sealed one nor the first; every other room in a
	# rolled order (a room may have no free spot: SealTrial takes the next one).
	var rooms: Array[int] = []
	var order: Array = range(1, map.rooms.size())
	RandomUtils.shuffle(order, rng)
	for i: int in order:
		if i != index and not excluded.has(i):
			rooms.append(i)
	if rooms.size() < lanterns:
		return {}
	return { "room": index, "lantern_rooms": rooms }


func make(world: World, planned: Dictionary, taken: Dictionary) -> RoomTrial:
	var trial := SealTrial.new()
	trial.setup_seal(world, self, int(planned.room), planned.lantern_rooms, taken)
	return trial
