extends Node
## Builds many floors from fixed seeds and writes what they hold as JSON lines, for
## tools/levels/floor_report.py (a tool: not exported). The floors' rhythm (docs/design/dungeon.md
## "Pacing") and layout measured over hundreds of floors, before and after a change:
##   godot --headless res://tools/levels/floor_probe.tscn -- <out.jsonl> [seeds=20] [difficulties=0,1,2,3]
##   python3 tools/levels/floor_report.py <out.jsonl> [before.jsonl]
## Every floor of the run (1 to the last act's boss) at each difficulty (its index in
## content_db.tres), `seeds` times. About half a second a floor on the VM.

var _out := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://floors.jsonl"
	var seeds := int(args[1]) if args.size() > 1 else 20
	var difficulties := (args[2] if args.size() > 2 else "0,1,2,3").split(",")
	await get_tree().process_frame
	Profile.save_path = ""
	Profile.reset()
	Settings.path = ""
	Sfx.enabled = false
	var content: ContentDB = load("res://data/content_db.tres")
	var world := (load("res://src/world/world.tscn") as PackedScene).instantiate() as World
	world.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(world)
	var file := FileAccess.open(_out, FileAccess.WRITE)
	for index in difficulties:
		world.difficulty = content.difficulties[int(index)]
		for depth in range(1, content.dungeon.total_floors() + 1):
			for s in seeds:
				world.luck = RunLuck.new()  # each floor as the first of its run: no draws before
				world.rng.seed = hash("audit-%s-%d-%d" % [index, depth, s])
				world.build_floor(depth, content)
				await get_tree().process_frame
				file.store_line(JSON.stringify(_facts(world, depth, int(index), s)))
		print("difficulty ", index, " done")
	file.close()
	world.clear_floor()
	get_tree().quit()


func _facts(world: World, depth: int, difficulty: int, s: int) -> Dictionary:
	var map := world.map
	var rows: Array[String] = []
	for y in map.height:
		var row := ""
		for x in map.width:
			var cell := Vector2i(x, y)
			if not map.is_floor(cell):
				row += "#"
			elif map.pillars.has(cell):
				row += "I"
			elif map.features.get(cell, 0) == DungeonMap.Feature.CHASM:
				row += "C"
			elif map.features.get(cell, 0) == DungeonMap.Feature.POOL:
				row += "P"
			else:
				row += "."
		rows.append(row)
	var rooms := []
	for i in map.rooms.size():
		var plan := map.plan(i)
		var r := map.rooms[i]
		rooms.append({
			"rect": [r.position.x, r.position.y, r.size.x, r.size.y],
			"shape": plan.shape.resource_path.get_file().get_basename() if plan.shape else "",
			"heart": [plan.heart.x, plan.heart.y],
		})
	var ents := []
	for child in world._entities.get_children():
		if not child is Node2D:
			continue
		var c := map.world_to_cell((child as Node2D).global_position)
		var e := {"cls": child.get_class(), "at": [c.x, c.y]}
		var script: Script = child.get_script()
		if script:
			e["cls"] = script.get_global_name()
		var def: Variant = child.get("def")
		if def is Resource and def.get("id") != null:
			e["id"] = str(def.get("id"))
		if child is Monster:
			var m := child as Monster
			e["elite"] = m.is_elite()
			e["radius"] = m.radius
		ents.append(e)
	var pact_room := []
	if world.pact:
		for step: Vector2i in GridDirs.FOUR:
			var room := map.room_at(world.pact.door_cell + step)
			if room > 0:
				pact_room = _rect(map.rooms[room])
				break
	return {
		"diff": difficulty, "depth": depth, "seed": s,
		"biome": world.biome.resource_path.get_file().get_basename() if world.biome else "",
		"w": map.width, "h": map.height,
		"tiles": rows,
		"rooms": rooms,
		"ents": ents,
		"start": [map.start_cell.x, map.start_cell.y],
		"stairs": [map.stairs_cell.x, map.stairs_cell.y],
		"stairs2": [map.second_stairs_cell.x, map.second_stairs_cell.y],
		"boss_room": _rect(map.boss_room),
		"ambush": _rect(world.ambush.room) if world.ambush else [],
		"pact": pact_room,
		"seal": world.seal.needed,
	}


func _rect(r: Rect2i) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]
