class_name FirstSteps
extends Node
## The first runs' gentle start (decision 0010, FirstStepsDef, design/dungeon.md "First steps").
## On the first floor of a profile's first runs (never a Dawn Knell, the same floors for all):
## - the room the hero starts in shelters him (World.shelters(), asked by Monster.notice_target()):
##   no monster notices him there until he has walked FirstStepsDef.move_distance and swung once,
##   so a new player can look around and read the first hint without being hit;
## - the nearest room holding monsters keeps a single one, its kind made slow and plainly
##   telegraphed (make_monster()), dying in 2 or 3 blows of the starting katana: the first fight.
## Owned by the Game, which sets it for each floor (begin_floor()); the World holds it while it
## is on (World.first_steps) and its floor kind lets it lay the first monster (lay()), the same
## way from the same seed, so a run picked up on that floor finds it again.

## Off in the tests (tests/run_tests.gd): the fights they stage on the first floor would wait
## for the hero to move and strike. Their own tests of it turn it on.
static var enabled := true

## The rules on this floor (null: an ordinary floor).
var def: FirstStepsDef
var player: Player
var world: World
## The room he started in (cells), once the floor is laid.
var room := Rect2i()
var _walked := 0.0
var _struck := false
var _last_position := Vector2.INF


## The rules for the floor `run` is about to enter: on floor FirstStepsDef.depth of one of the
## profile's first FirstStepsDef.runs runs (Profile.runs counts the run as it begins), not a Dawn
## Knell, not the hidden floor nor the bottom of the Well. Null otherwise.
static func wanted(content: ContentDB, run: RunState) -> FirstStepsDef:
	var rules := content.first_steps if content else null
	if not enabled or rules == null or rules.monster == null or run == null or run.is_daily() \
			or run.hidden_floor or run.finale:
		return null
	return rules if run.depth == rules.depth and Profile.runs <= rules.runs else null


## The first monster: its kind (FirstStepsDef.monster: its look, sounds, bestiary page and kills
## are the kind's) with the gentle numbers of `rules`.
static func make_monster(rules: FirstStepsDef) -> MonsterDef:
	var made := rules.monster.duplicate() as MonsterDef
	if rules.stats:
		made.stats = rules.stats
	made.attack_windup = rules.attack_windup
	made.attack_recovery = rules.attack_recovery
	made.detect_radius = rules.detect_radius
	return made


## A floor is about to be built: on (`rules`) or off (null) for it, with the hero and the world.
func begin_floor(rules: FirstStepsDef, hero: Player, floor_world: World) -> void:
	if player and is_instance_valid(player) and player.attacked.is_connected(_on_attacked):
		player.attacked.disconnect(_on_attacked)
	def = rules
	player = hero
	world = floor_world
	room = Rect2i()
	_walked = 0.0
	_struck = false
	_last_position = Vector2.INF
	if world:
		world.first_steps = self if def else null
	if def and player:
		player.attacked.connect(_on_attacked)


## Lays the first monster (called by the floor kind once the floor's monsters are placed): the
## nearest room holding monsters, in the order the rooms are chained from the start, keeps one
## of the gentle kind where its monster nearest the start stood (with its number in the seed's
## order: Monster.floor_index, so a save finds it again), the others leave.
func lay(floor_world: World) -> void:
	if def == null or floor_world.map == null or floor_world.map.rooms.size() < 2:
		return
	var map := floor_world.map
	room = map.rooms[0]
	var by_room := {}
	for node in floor_world.get_tree().get_nodes_in_group("monsters"):
		var monster := node as Monster
		if monster == null or monster.world != floor_world or monster.floor_index < 0 or monster.is_queued_for_deletion():
			continue
		var index := map.room_at(map.world_to_cell(monster.global_position))
		if index >= 1:
			if not by_room.has(index):
				by_room[index] = []
			(by_room[index] as Array).append(monster)
	if by_room.is_empty():
		return
	var first: int = by_room.keys().min()
	var start := map.cell_to_world(map.start_cell)
	var kept: Monster = null
	for monster: Monster in by_room[first]:
		if kept == null or monster.global_position.distance_to(start) < kept.global_position.distance_to(start):
			kept = monster
	var at := kept.global_position
	var number := kept.floor_index
	for monster: Monster in by_room[first]:
		monster.get_parent().remove_child(monster)
		monster.queue_free()
	var gentle := floor_world.spawn_monster(make_monster(def), at)
	gentle.floor_index = number


## The hero is in his first room and hasn't both walked and struck yet.
func shelters(actor: Actor) -> bool:
	if def == null or actor != player or not room.has_area() or is_lifted():
		return false
	return room.has_point(world.map.world_to_cell(actor.global_position))


## He has walked and struck: the shelter is over for this floor.
func is_lifted() -> bool:
	return def == null or (_walked >= def.move_distance and _struck)


func _physics_process(_delta: float) -> void:
	if def == null or player == null or not is_instance_valid(player) or is_lifted():
		return
	var at := player.global_position
	if _last_position != Vector2.INF and not player.is_dashing():
		_walked += minf(at.distance_to(_last_position), 40.0)  # (a fall or a teleport is no walk)
	_last_position = at


func _on_attacked() -> void:
	_struck = true
