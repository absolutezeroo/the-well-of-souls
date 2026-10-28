class_name FloorSave
extends RefCounted
## The floor's part of the run's save, owned by the World (World.floor_save; asked through
## World.spent_data() and World.restore_spent()). A resumed run rebuilds the floor from its seed,
## so the save keeps only what the hero changed on it: chests opened, the merchant's stock, the
## secret rooms, the pact, the fragment, the seal's kills, holes filled and cracks given way
## (HoleField), the floor's own monsters slain or hurt, those that came later, the ambush (cleared,
## or how far its fight went), what came later and lies on the ground (a monster's or a chest's
## loot, gold, what the hero dropped: left_behind()), and what the FloorLedger counts (items,
## gold, props, encounters used up). After the rebuild, apply() lays all that back on the new
## floor, quietly (no sound, no drop, no kill counted).
##
## The format is the save file's (RunSave.FLOOR_FORMAT): every field is read as a save file may
## hold it, and a damaged one is skipped, never a script error.

## Cells of the chests opened on this floor.
var opened_chests: Array[Vector2i] = []
## Items bought from this floor's merchant (saved form).
var bought: Array = []
## The floor's own monsters slain on it (Monster.floor_index), each saved as [floor_index, id]: a
## resumed run rebuilds the floor from its seed and leaves these out. The id is a guard: a
## monster whose number came out as another kind (a floor not rebuilt quite the same) stays.
var slain: Array = []

var _world: World
## The World's Entities node: where the floor's monsters, chests and pickups stand.
var _entities: Node
## Set before rebuilding a saved floor (World.restore_spent()), used once by apply().
var _to_restore := {}
## Cells of the chests opened before quitting, as the save gave them (apply()): a chest that
## comes later on the rebuilt floor (the hidden floor's hoard) is opened already if its cell is in.
var restored_chest_cells: Array[Vector2i] = []


func _init(world: World, entities: Node) -> void:
	_world = world
	_entities = entities


## A new floor: nothing taken from it yet.
func reset() -> void:
	opened_chests.clear()
	bought.clear()
	slain.clear()
	restored_chest_cells.clear()


## One of the floor's own monsters fell (Monster.floor_index): kept slain for the save.
func count_slain(monster: Monster) -> void:
	if monster.floor_index >= 0:
		slain.append([monster.floor_index, String(monster.def.id)])


## What was taken from this floor, for a save file. `stamp`: the build that laid it
## (RunSave.floor_stamp(): another build may lay the same seed otherwise).
func to_data() -> Dictionary:
	var world := _world
	var merchant := world.floor_merchant()
	var data := {
		"stamp": RunSave.floor_stamp(),
		"chests": opened_chests.map(func(cell: Vector2i) -> Array: return [cell.x, cell.y]),
		"bought": bought.duplicate(),
		"merchant": merchant.save_data() if merchant else {},
		"secrets": SecretRoom.states(world.secrets),
		"pact": world.pact.save_code() if world.pact else 0,
		"fragment": world.fragment_taken,
		"seal_kills": world.seal.kills,
		"sealed": world.holes.sealed_cells.map(func(cell: Vector2i) -> Array: return [cell.x, cell.y]),
		"collapsed": world.holes.collapsed_cells.map(func(cell: Vector2i) -> Array: return [cell.x, cell.y]),
		"slain": slain.duplicate(true),
		"spent": world.ledger.to_data(),
		"ambush": ambush_data(),
		"wounded": wounded_spawns(),
		"later": later_monsters(),
		"left": left_behind(),
	}
	if world.room_trial and is_instance_valid(world.room_trial):
		data["trial"] = world.room_trial.save_data()  # (only on a floor with one: the others' saves as they were)
	if arena_cleared():
		data["arena_cleared"] = true
	return data


## The warden of this floor fell before quitting (not the bottom of the Well's: its ending
## follows at once): the run picks up in his cleared arena, the hidden way open again if the key
## is still in the bag (what he dropped still lies there: left_behind(), as everywhere).
func arena_cleared() -> bool:
	var world := _world
	return world.arena != null and is_instance_valid(world.arena) and world.arena.is_defeated and world.finale == null


## What came later and still lies on the floor, anywhere on it (a monster's or a warden's loot, a
## chest's or a crate's, gold, what the hero put down from his bag): [kind, data, x, y] with kind
## "item" (data: LootRoller.to_data()) or "gold" (data: the coins). Without it, loot left on the
## ground was gone when the run was picked up (roadmap task 199). What the seed laid is the
## ledger's: laid again on the rebuilt floor, not kept twice.
func left_behind() -> Array:
	var world := _world
	var result: Array = []
	for node in _entities.get_children():
		var pickup := node as ItemPickup
		if pickup and pickup.item and not pickup.is_taken() and not world.ledger.is_laid(FloorLedger.ITEM, pickup):
			result.append(["item", LootRoller.to_data(pickup.item), roundi(pickup.global_position.x), roundi(pickup.global_position.y)])
		var coins := node as GoldPickup
		if coins and coins.amount > 0 and not coins.is_queued_for_deletion() and not world.ledger.is_laid(FloorLedger.GOLD, coins):
			result.append(["gold", coins.amount, roundi(coins.global_position.x), roundi(coins.global_position.y)])
	return result


## What lay there lies there again (`saved`: to_data()'s "left"); a damaged entry, or an item the
## game no longer has, is skipped.
func restore_left(saved: Array) -> void:
	var world := _world
	for entry: Variant in saved:
		if not (entry is Array and (entry as Array).size() == 4) or not _coordinate(entry[2]) or not _coordinate(entry[3]):
			continue
		var at := Vector2(float(entry[2]), float(entry[3]))
		if not world.is_solid_ground(at):
			at = world.nearest_free_point(at)
		match str(entry[0]):
			"item":
				var item := LootRoller.from_data(entry[1])
				if item:
					world.spawn_item(item, at)
			"gold":
				var coins := int(entry[1]) if (entry[1] is float or entry[1] is int) else 0
				if coins > 0:
					_entities.add_child(GoldPickup.create(at, coins, world))


## The next floor built is the saved one again: what was taken from it stays taken. `data`:
## to_data() as a save file reads it (RunSave.floor_of(); anything else restores nothing).
func restore(data: Variant) -> void:
	_to_restore = data if data is Dictionary else {}


## Lays what restore() was given on the floor just built (once; nothing if none was given).
func apply() -> void:
	if _to_restore.is_empty():
		return
	var world := _world
	var data := _to_restore
	_to_restore = {}
	SecretRoom.restore(world.secrets, _array(data, "secrets"))  # (its chest, if opened, is in "chests")
	world.seal.restore(_number(data, "seal_kills"))  # the kills already made on this floor
	restore_slain(_array(data, "slain"))  # (after the seal took its count from the whole floor)
	restore_wounded(_array(data, "wounded"))  # (older saves have none: all at full Health)
	restore_later(_array(data, "later"))
	world.ledger.restore(data.get("spent", {}), _take_back)
	restore_ambush(data.get("ambush", {}))  # (before the chests: its chest may be opened)
	var cells := saved_cells(_array(data, "chests"))
	restored_chest_cells = cells
	if data.get("arena_cleared", false) == true and world.arena:
		world.arena.clear_quietly()
	restore_left(_array(data, "left"))  # (saves before 28 Oct 2026 kept it only for a cleared arena)
	for node in _entities.get_children():
		var chest := node as Chest
		if chest and cells.has(world.map.world_to_cell(chest.global_position)):
			chest.set_spent()
			opened_chests.append(world.map.world_to_cell(chest.global_position))
	var merchant := world.floor_merchant()
	var restocked := merchant != null and merchant.load_data(data.get("merchant", {}))
	for saved_item: Variant in _array(data, "bought"):
		if restocked:
			bought.append(saved_item)  # (the stock came back as it was: nothing to take out)
		elif merchant and merchant.forget_sold(saved_item):
			bought.append(saved_item)  # (older saves: the seed's stock, less what was bought)
	if data.get("fragment", false) == true and world.fragment and is_instance_valid(world.fragment):
		world.fragment_taken = true
		world.fragment.take()  # read before quitting: not laid again
	if world.pact and _number(data, "pact") > 0:
		world.pact.set_spent()  # sworn before quitting: never offered again
	var saved_trial: Variant = data.get("trial", {})
	if world.room_trial and saved_trial is Dictionary:
		world.room_trial.restore(saved_trial)  # its steps done before quitting, done again quietly
	restore_collapsed(_array(data, "collapsed"))  # (older saves have none)
	restore_sealed(_array(data, "sealed"))  # after: a crack the hero fell through was filled


## A thing the seed laid, used up before quitting (FloorLedger.restore()): gone again, quietly.
func _take_back(kind: String, node: Object) -> void:
	match kind:
		FloorLedger.PROP:
			(node as Prop).take_away()  # (nothing dropped: it was, before quitting)
		FloorLedger.ENCOUNTER:
			(node as Encounter).used = true
			(node as Encounter).queue_redraw()
		_:
			_discard(node as Node)


## Takes `node` off the floor at once, even one still waiting to be added (World.spawn_item()
## adds its pickups deferred): it never shows nor is picked up.
static func _discard(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	if node.is_inside_tree():
		node.queue_free()
	else:
		node.tree_entered.connect(node.queue_free, CONNECT_ONE_SHOT)


## What the save keeps of the floor's ambush: its room (a guard), cleared or not, its chest's cell;
## a fight under way, how far it went (AmbushRoom.progress_data(): the waves still to come, the
## wave's monsters still to face).
func ambush_data() -> Dictionary:
	var ambush := _world.ambush
	if ambush == null or not is_instance_valid(ambush):
		return {}
	var data := {
		"room": [ambush.room.position.x, ambush.room.position.y, ambush.room.size.x, ambush.room.size.y],
		"cleared": ambush.state == AmbushRoom.State.CLEARED,
		"chest": [ambush.reward_cell.x, ambush.reward_cell.y],
	}
	if ambush.state == AmbushRoom.State.FIGHTING or ambush.is_resuming():
		data.merge(ambush.progress_data())
	return data


## An ambush cleared before quitting stays cleared (its waves don't come back), its chest where it
## was put down. One under way waits for the hero again and goes on where it was when he walks
## back in: the waves beaten stay beaten, the wave under way brings only its monsters still
## standing (roadmap task 198: quitting no longer started its waves over, kills and gold again).
## A saved room that isn't this floor's ambush restores nothing.
func restore_ambush(saved: Variant) -> void:
	var ambush := _world.ambush
	if not saved is Dictionary or ambush == null:
		return
	var room: Variant = (saved as Dictionary).get("room", [])
	if not room is Array or (room as Array).size() != 4 \
			or not (room as Array).all(func(n: Variant) -> bool: return n is float or n is int) \
			or Rect2i(int(room[0]), int(room[1]), int(room[2]), int(room[3])) != ambush.room:
		return
	if (saved as Dictionary).get("cleared", false) == true:
		var chest := saved_cells([(saved as Dictionary).get("chest")])
		ambush.restore_cleared(chest[0] if not chest.is_empty() else DungeonMap.NO_CELL)
	elif (saved as Dictionary).has("waves_left"):
		ambush.restore_progress(_number(saved, "waves_left"), _array(saved, "wave"))


## `key` of `data` if it is an array, else empty (a damaged save).
static func _array(data: Dictionary, key: String) -> Array:
	var value: Variant = data.get(key, [])
	return value if value is Array else []


## `key` of `data` if it is a number, else 0 (a damaged save).
static func _number(data: Dictionary, key: String) -> int:
	var value: Variant = data.get(key, 0)
	return int(value) if value is float or value is int else 0


## Holes filled in before quitting stay filled: `saved` is to_data()'s "sealed".
func restore_sealed(saved: Array) -> void:
	_world.holes.restore_sealed(saved_cells(saved))


## Cracked floor that gave way before quitting is a hole again, without a sound: `saved` is
## to_data()'s "collapsed".
func restore_collapsed(saved: Array) -> void:
	_world.holes.restore_collapsed(saved_cells(saved))


## The floor's own monsters slain before quitting stay slain: `saved` is to_data()'s "slain"
## ([floor_index, id] pairs). They are taken off the rebuilt floor at once, with nothing dropped
## and no kill counted (the seal's count is saved on its own).
func restore_slain(saved: Array) -> void:
	var gone := {}
	for pair: Variant in saved:
		if pair is Array and (pair as Array).size() == 2 and (pair[0] is float or pair[0] is int):
			gone[int(pair[0])] = str(pair[1])
	if gone.is_empty():
		return
	for node in _entities.get_children():
		var monster := node as Monster
		if monster == null or monster.floor_index < 0 or not gone.has(monster.floor_index):
			continue
		if String(monster.def.id) != gone[monster.floor_index]:
			continue  # not the same monster: better one too many than one missing
		slain.append([monster.floor_index, String(monster.def.id)])
		_entities.remove_child(monster)
		monster.queue_free()


## The floor's own monsters still standing but hurt, each saved as [floor_index, id, the share of
## its Health it has left]: a resumed run rebuilds them at full Health from the seed (where the
## seed put them, as it was rolled: rank and all), then gives each its share back.
func wounded_spawns() -> Array:
	var result: Array = []
	for node in _entities.get_children():
		var monster := node as Monster
		if monster and monster.floor_index >= 0 and not monster.is_dead and monster.hp < monster.get_max_hp():
			result.append([monster.floor_index, String(monster.def.id), snappedf(float(monster.hp) / monster.get_max_hp(), 0.001)])
	return result


## Hurt before quitting, hurt again: `saved` is to_data()'s "wounded" (the same number and kind,
## as for the slain); a damaged entry is skipped.
func restore_wounded(saved: Array) -> void:
	var shares := {}
	for entry: Variant in saved:
		if entry is Array and (entry as Array).size() == 3 and (entry[0] is float or entry[0] is int) and (entry[2] is float or entry[2] is int):
			shares[int(entry[0])] = [str(entry[1]), clampf(float(entry[2]), 0.0, 1.0)]
	if shares.is_empty():
		return
	for node in _entities.get_children():
		var monster := node as Monster
		if monster and monster.floor_index >= 0 and shares.has(monster.floor_index) and String(monster.def.id) == shares[monster.floor_index][0]:
			_set_health_share(monster, shares[monster.floor_index][1])


## Monsters that came after the floor was built and still stand (a summons, an encounter's, a
## trapped chest's, a campfire's waves, what a slain one split into): { def (its file), id, at,
## health (share left), rank, affixes, summoned }, put back where they stood on a resumed run.
## Not a boss, not the wave of an ambush under way nor anything in a warden's arena while he
## stands (both fights start over on a resumed run), not one falling.
func later_monsters() -> Array:
	var world := _world
	var result: Array = []
	for node in _entities.get_children():
		var monster := node as Monster
		if monster == null or monster.floor_index >= 0 or monster.is_dead or monster.is_falling or monster.def is BossDef \
				or monster.def.resource_path.is_empty():
			continue
		if world.ambush and is_instance_valid(world.ambush) and world.ambush.holds(monster):
			continue
		if world.arena and not world.arena.is_defeated and world.map.boss_room.has_point(world.map.world_to_cell(monster.global_position)):
			continue
		var entry := monster_entry(monster)
		entry["at"] = [roundi(monster.global_position.x), roundi(monster.global_position.y)]
		entry["summoned"] = monster.summoned
		result.append(entry)
	return result


## Those that came later stand where they stood again: `saved` is to_data()'s "later". A kind,
## rank or affix the game no longer has, or a damaged entry, is skipped (it doesn't come back).
func restore_later(saved: Array) -> void:
	var world := _world
	for entry: Variant in saved:
		if not entry is Dictionary:
			continue
		var data := entry as Dictionary
		var at: Variant = data.get("at")
		if not (at is Array and (at as Array).size() == 2):
			continue
		if not _coordinate(at[0]) or not _coordinate(at[1]):
			continue
		var def := entry_def(data)
		if def == null:
			continue
		var point := Vector2(float(at[0]), float(at[1]))
		var room := WorldSpace.room_for(def)
		if not (world.is_solid_ground(point) and world.body_fits(point, room)):
			point = world.nearest_free_point(point, 12, world.get_actors(), room, room)
		var monster := world.spawn_monster(def, point)
		monster.summoned = bool(data.get("summoned", false))
		restore_monster(world, monster, data)


## A monster as the save keeps one that came later or waits in an ambush's wave: its kind (its
## file and id), its rank and affixes, the share of its Health it has left (restore_monster()).
static func monster_entry(monster: Monster) -> Dictionary:
	return {
		"def": RunSave.ref(monster.def), "id": String(monster.def.id),
		"health": snappedf(float(monster.hp) / monster.get_max_hp(), 0.001),
		"rank": String(monster.rank.id) if monster.rank else "",
		"affixes": monster.affixes.map(func(affix: EliteAffixDef) -> String: return String(affix.id)),
	}


## The kind saved in `entry` (monster_entry()): null when the game no longer has it, or the entry
## is damaged.
static func entry_def(entry: Variant) -> MonsterDef:
	if not entry is Dictionary:
		return null
	var def := RunSave.load_ref(str((entry as Dictionary).get("def", ""))) as MonsterDef
	if def == null or def is BossDef or String(def.id) != str((entry as Dictionary).get("id", "")):
		return null
	return def


## `monster`, just spawned, gets back the rank, affixes and Health share of `entry`
## (monster_entry()); a rank or an affix the game no longer has is left out.
static func restore_monster(world: World, monster: Monster, entry: Dictionary) -> void:
	var config := world.config()
	var ranks: Array[MonsterRankDef] = [config.elite_rank]
	ranks.append_array(config.rare_ranks)
	var rank_id := str(entry.get("rank", ""))
	var rank: MonsterRankDef = null
	for candidate in ranks:
		if candidate and String(candidate.id) == rank_id:
			rank = candidate
	if rank:
		var affixes: Array[EliteAffixDef] = []
		var saved_affixes: Variant = entry.get("affixes", [])
		for affix_id: Variant in saved_affixes if saved_affixes is Array else []:
			for affix in world.content_db().elite_affixes:
				if affix and String(affix.id) == str(affix_id):
					affixes.append(affix)
		monster.make_ranked(rank, affixes)
	var share: Variant = entry.get("health", 1.0)
	_set_health_share(monster, float(share) if (share is float or share is int) else 1.0)


## `monster` at `share` of its Health (one at least), its bar told.
static func _set_health_share(monster: Monster, share: float) -> void:
	monster.hp = clampi(ceili(monster.get_max_hp() * clampf(share, 0.0, 1.0)), 1, monster.get_max_hp())
	monster.health_changed.emit(monster.hp, monster.get_max_hp())


## Cells saved as [x, y] pairs (numbers as a save file reads them); a damaged entry is skipped.
static func saved_cells(saved: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for pair: Variant in saved:
		if pair is Array and (pair as Array).size() == 2 and (pair as Array).all(func(n: Variant) -> bool: return n is float or n is int):
			cells.append(Vector2i(int(pair[0]), int(pair[1])))
	return cells


## Coordinates from JSON must be finite numbers before a Vector2 is built.
static func _coordinate(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
