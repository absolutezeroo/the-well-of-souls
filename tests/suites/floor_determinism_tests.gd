class_name FloorDeterminismTests
extends TestSuite
## The same seed lays the same floor: a fingerprint of floors built from fixed seeds (every kind
## of floor: plain, cursed by the debug panel, reached by a chosen way, a warden's, the hidden one,
## the bottom of the Well), against the values recorded when the World was split into its parts
## (FloorKind, FloorLedger's restore, HoleField, ActivityManager, WorldSpace). A refactor must
## leave them as they are; a change to content or generation that moves them on purpose records
## the new values (the failure prints them).
##
## The fingerprint: the map's tiles, rooms and exits, the floor's world, twist and arena, every
## monster (kind, cell, rank, affixes, Health), every pickup, prop, chest and pact, the stairs, and
## the floor dice's state once laid (any roll added, dropped or moved shows there).

const WORLD_SCENE := "res://src/world/world.tscn"

## kind -> fingerprint (hash), recorded on main before the split, again when the save block's
## stamp (the game's version) was left out of it (0.3.1), and when the room trials came (plain_d5
## and route hold one). Pestilent adds a weighted affix from depth four (2026-10-25): the
## five affected floors were recorded again. The four further modular affixes (same date)
## change those five again; FLOOR_FORMAT 3 protects older saved floors. Decision 0012 (2026-10-28)
## recorded all twelve again: rooms 3 cells apart and corridors bent around them, monsters by the
## rooms' size, calm rooms, the peak and the release, a chest on every floor, draws without
## repeats, the spring before every boss; FLOOR_FORMAT 4.
## Change only on purpose.
const EXPECTED := {
	"plain_d2": 1003714455,
	"plain_d5": 3019354865,
	"plain_d8": 1375160831,
	"boss_act1": 993257950,
	"boss_act2": 2469845449,
	"forced_curse": 3659472505,
	"forced_plain": 194188831,
	"route": 2643120137,
	"two_ways": 3547954146,
	"resumed": 349901043,
	"hidden": 2614939729,
	"finale": 1063777049,
}


func run_unit() -> void:
	var world := (load(WORLD_SCENE) as PackedScene).instantiate() as World
	world.process_mode = Node.PROCESS_MODE_DISABLED  # nothing moves or rolls between build and print
	add_child(world)
	world.difficulty = CONTENT.difficulties[1]
	var got := {}
	for case: Dictionary in _cases():
		_prepare(world, case)
		world.rng.seed = int(case.seed)
		world.build_floor(int(case.depth), CONTENT, case.get("taken") as FloorRoute)
		var facts := _facts(world)  # (before a frame: the floor's own rolls only)
		await get_tree().process_frame  # loose items and gold are added deferred
		facts += _loose(world)
		if case.get("resume", false):
			# Picked up again: what was used up before quitting stays used up (World.spent_data(),
			# restore_spent()), the rest laid again from the seed.
			_use_some(world)
			var spent := world.spent_data()
			world.restore_spent(JSON.parse_string(JSON.stringify(spent)))  # as a save file reads it
			world.rng.seed = int(case.seed)
			world.build_floor(int(case.depth), CONTENT, case.get("taken") as FloorRoute)
			facts = _facts(world)
			await get_tree().process_frame
			facts += _loose(world) + "\n" + _spent_facts(spent) + "\n" + _spent_facts(world.spent_data())
		else:
			facts += "\n" + _spent_facts(world.spent_data())
		got[case.name] = hash(facts)
		world.hidden_floor = null
		world.finale = null
		world.finale_boss = null
		world.next_routes = []
	var printed := []
	for kind: String in got:
		printed.append("\"%s\": %d," % [kind, got[kind]])
		check(EXPECTED.get(kind, -1) == got[kind], "a %s floor laid from its seed is the same as before (%d)" % [kind, got[kind]])
	if got != EXPECTED:
		print("Floor fingerprints now:\n\t" + "\n\t".join(printed))
	world.clear_floor()
	remove_child(world)
	world.free()


func _cases() -> Array[Dictionary]:
	var dungeon := CONTENT.dungeon
	var hidden_act := 0
	if dungeon.hidden_floor and not dungeon.hidden_floor.key_acts.is_empty():
		hidden_act = dungeon.hidden_floor.key_acts[0]
	var cases: Array[Dictionary] = [
		{ "name": "plain_d2", "depth": 2, "seed": 1234 },
		{ "name": "plain_d5", "depth": 5, "seed": 98765 },
		{ "name": "plain_d8", "depth": 8, "seed": 424242 },
		{ "name": "boss_act1", "depth": dungeon.first_depth(0) + dungeon.acts[0].floors - 1, "seed": 777 },
		{ "name": "boss_act2", "depth": dungeon.first_depth(1) + dungeon.acts[1].floors - 1, "seed": 31337 },
		{ "name": "forced_curse", "depth": 4, "seed": 555, "curse": CONTENT.curses[0] if not CONTENT.curses.is_empty() else null },
		{ "name": "forced_plain", "depth": 4, "seed": 556, "plain": true },
		{ "name": "route", "depth": 5, "seed": 8080, "taken_seed": 99 },
		{ "name": "two_ways", "depth": 2, "seed": 2468, "routes_seed": 13579 },
		{ "name": "resumed", "depth": 2, "seed": 1234, "resume": true },
	]
	if dungeon.hidden_floor:
		cases.append({ "name": "hidden", "depth": dungeon.first_depth(hidden_act) + dungeon.acts[hidden_act].floors - 1, "seed": 4321, "hidden": true })
	if dungeon.finale:
		cases.append({ "name": "finale", "depth": dungeon.total_floors(), "seed": 9001, "finale": true })
	return cases


## The World as the Game sets it before a floor of this kind.
func _prepare(world: World, case: Dictionary) -> void:
	world.next_routes = []
	if case.has("curse"):
		world.overrides.curse = case.curse
		world.overrides.plain = case.curse == null
	if case.get("plain", false):
		world.overrides.plain = true
	if case.has("taken_seed"):
		var ways := FloorRoute.offer(CONTENT, int(case.depth), world.difficulty, int(case.taken_seed))
		case["taken"] = ways[ways.size() - 1] if not ways.is_empty() else null
	if case.has("routes_seed"):
		world.next_routes = FloorRoute.offer(CONTENT, int(case.depth) + 1, world.difficulty, int(case.routes_seed))
	if case.get("hidden", false):
		world.hidden_floor = CONTENT.dungeon.hidden_floor
	if case.get("finale", false):
		world.finale = CONTENT.dungeon.finale
		world.finale_boss = null


## A few things used up on the floor, the ways a save keeps them: a monster slain, one hurt, an
## item taken, a crack given way, a hole filled.
func _use_some(world: World) -> void:
	var monsters: Array[Monster] = []
	for node in world.find_children("*", "", true, false):
		var monster := node as Monster
		if monster and monster.floor_index >= 0 and not monster.is_queued_for_deletion():
			monsters.append(monster)
	if monsters.size() >= 2:
		world._on_monster_killed(monsters[0])
		monsters[1].hp = maxi(1, floori(monsters[1].get_max_hp() / 2.0))
	var used := [false, false]
	for node in world.find_children("*", "", true, false):
		if node is ItemPickup and not used[0]:
			used[0] = true
			world.ledger.spend(FloorLedger.ITEM, node)
		elif node is CrumblingFloor and not used[1]:
			used[1] = true
			var crack := node as CrumblingFloor
			world.crack_collapsed(crack.cell, crack.def)
			world.seal_hole(crack.cell)


static func _id(resource: Resource) -> String:
	if resource == null:
		return "-"
	var id: Variant = resource.get("id")
	return str(id) if id != null and str(id) != "" else resource.resource_path


func _facts(world: World) -> String:
	var map := world.map
	var lines: Array[String] = []
	lines.append("map %dx%d %s" % [map.width, map.height, str(hash(map.tiles))])
	lines.append("rooms %s start %s stairs %s second %s boss %s" % [str(map.rooms), str(map.start_cell), str(map.stairs_cell), str(map.second_stairs_cell), str(map.boss_room)])
	lines.append("biome %s curse %s event %s arena %s" % [_id(world.biome), _id(world.curse), _id(world.floor_event), _id(world.arena_plan)])
	lines.append("stairs %s seal %d" % [str(world.stairs_cells), world.seal.needed])
	lines.append("pits %s" % str(world.map.features.size()))
	var things: Array[String] = []
	for node in world.find_children("*", "", true, false):
		if node.is_queued_for_deletion() or not node is Node2D:
			continue
		var at := map.world_to_cell((node as Node2D).global_position)
		if node is Monster:
			var monster := node as Monster
			var affixes := monster.affixes.map(func(affix: EliteAffixDef) -> String: return String(affix.id))
			things.append("monster %s %s %s %s %d %d" % [_id(monster.def), str(at), _id(monster.rank), str(affixes), monster.get_max_hp(), monster.floor_index])
		elif node is Prop:
			things.append("prop %s %s" % [_id((node as Prop).def), str(at)])
		elif node is Chest:
			things.append("chest %s" % str(at))
		elif node is Trap:
			things.append("trap %s" % str(at))
		elif node is Merchant or node is Forge or node is Encounter or node is PactRoom or node is CrumblingFloor or node is Fragment:
			things.append("%s %s" % [node.get_class() + str(node.get_script().get_global_name()), str(at)])
	things.sort()
	lines.append_array(things)
	lines.append("dice %d" % world.rng.state)
	return "\n".join(lines)


func _loose(world: World) -> String:
	var things: Array[String] = []
	for node in world.find_children("*", "", true, false):
		if node.is_queued_for_deletion():
			continue
		if node is ItemPickup:
			things.append("item %s %s" % [_id((node as ItemPickup).item), str((node as Node2D).position.round())])
		elif node is GoldPickup:
			things.append("gold %s" % str((node as Node2D).position.round()))
	things.sort()
	return "\n" + "\n".join(things)


## The floor's save block in the fingerprint, without its stamp (the game's version: a new
## version number lays the same floors).
func _spent_facts(spent: Dictionary) -> String:
	var copy := spent.duplicate()
	copy.erase("stamp")
	return JSON.stringify(_legacy_references(copy))



## Compare the same saved content across the path-to-id format migration. Keep every field
## in the original fingerprint; only its reference spelling returns to the recorded form.
func _legacy_references(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[key] = _legacy_references(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(_legacy_references(entry))
		return result
	if value is String and value.begins_with("@"):
		var resource := RunSave.load_ref(value)
		return resource.resource_path if resource else value
	return value
