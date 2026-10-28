class_name SaveTests
extends TestSuite
## In the game: a run put away and picked up again (RunSave, World.spent_data()). The things a
## floor's seed lays and the hero used up stay used up (items taken, props broken, encounters
## used, an ambush cleared, the merchant's stock), on normal floors and on the hidden floor; a
## floor saved by another build is laid fresh (the hero and the run kept); an old save is migrated;
## a damaged one never stops the game. Played by GameTests on its game.


func run_game(game: Game) -> void:
	var config := CONTENT.dungeon
	var kept := {
		"merchant_chance": config.merchant_chance, "encounters_min": config.encounters_min,
		"encounters_max": config.encounters_max, "ambush_chance": config.ambush_chance,
	}
	config.merchant_chance = 1.0
	config.encounters_min = 1
	config.encounters_max = 2
	config.ambush_chance = 1.0
	await _test_floor_kept(game)
	for key: String in kept:
		config.set(key, kept[key])
	await _test_hidden_floor_kept(game)
	await _test_cleared_arena(game)
	await _test_other_build(game)
	await _test_old_and_damaged_saves(game)


## The things of a world's own floor (not the Threshold's, the Deeps').
func _of(world: World, group: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for node in get_tree().get_nodes_in_group(group):
		if world.is_ancestor_of(node) and not node.is_queued_for_deletion():
			result.append(node)
	return result


## A floor with a merchant, an encounter, an ambush, items lying around and props, built by its
## seed at some depth (the chances are raised by run_game()).
func _full_floor(game: Game) -> bool:
	for target in range(2, 12):
		game.depth = target
		game._enter_floor()
		await _frames(3)
		var world := game.world
		if world.ambush and world.floor_merchant() and not _of(world, &"encounters").is_empty() \
				and not _of(world, &"pickups").is_empty() and not world.get_breakable_props().is_empty():
			return true
	return false


func _test_floor_kept(game: Game) -> void:
	game.start_run()
	await _frames(3)
	var player: Player = game.player
	player.invincible = true
	player.xp = -1000000  # no level up (and its choice) from the kills below
	check(await _full_floor(game), "a floor with a merchant, an encounter, an ambush, items and props (depth %d)" % game.depth)
	var world: World = game.world
	player = game.player
	player.gold = 99999
	var pickups_before := _of(world, &"pickups").size()
	var props_before := world.get_breakable_props().size()

	# An item lying around, taken.
	var pickup := _of(world, &"pickups")[0] as ItemPickup
	var item_at := pickup.global_position
	check(pickup.take(player), "the hero takes an item lying on the floor")
	# A prop broken (not a keg: its blast would break others).
	var prop: Prop = null
	for candidate in world.get_breakable_props():
		if not candidate.def.is_explosive():
			prop = candidate
			break
	var prop_cells: Array[Vector2i] = prop.cells() if prop else []
	var hit := HitInfo.new()
	hit.source = player
	for i in (prop.def.hits if prop else 0):
		prop.take_hit(hit)
	check(prop != null and prop.is_broken, "a prop broken")
	# An encounter used.
	var encounter := _of(world, &"encounters")[0] as Encounter
	var encounter_at := encounter.global_position
	for choice in encounter.def.choices.size():
		if encounter.used:
			break
		encounter.resolve(choice, player)
	check(encounter.used, "an encounter used")
	# The ambush, cleared.
	var ambush := world.ambush
	ambush.start()
	for i in 60 * 60:
		if ambush.state == AmbushRoom.State.CLEARED:
			break
		# A gift of the encounter, or a level up, may have opened the perk choice: the game waits
		# behind it (paused) and so would the ambush's waves.
		if game.perk_panel.visible:
			game.perk_panel.choose(0)
		for monster: Variant in ambush._wave:  # (its waves, wherever they stand)
			if is_instance_valid(monster) and not (monster as Monster).is_dead:
				(monster as Monster).take_hit(Combat.make_secondary_hit(player, 99999))
		await _frames(1)
	check(ambush.state == AmbushRoom.State.CLEARED and ambush.reward_cell != DungeonMap.NO_CELL, "the ambush cleared, its chest put down (%s, %d waves left)" % [ambush.state, ambush.waves_left])
	var chest_cell := ambush.reward_cell
	# The merchant: an entry locked, one bought, the rest rerolled.
	var merchant := world.floor_merchant()
	merchant.toggle_lock(0)
	var locked_key := Merchant._key(LootRoller.to_data(merchant.stock[0].item))
	check(merchant.sell_to(player, merchant.stock.size() - 1) and merchant.reroll(player), "bought from the merchant, then rerolled")
	var stock_before := _stock_keys(merchant)
	await _frames(2)

	# What came later lies there again too (task 199: the ambush's and the encounter's drops).
	var later := _later_items(world)
	game._save_run()
	game.resume_run(RunSave.read())
	await _frames(5)
	world = game.world
	player = game.player
	check(_of(world, &"pickups").size() == pickups_before - 1 + later, "resumed, the item taken isn't lying there again, what came later is (%d of %d, %d came later)" % [_of(world, &"pickups").size(), pickups_before, later])
	check(not _of(world, &"pickups").any(func(n: Node) -> bool: return (n as Node2D).global_position.distance_to(item_at) < 1.0), "...not where it lay")
	check(world.get_breakable_props().size() == props_before - 1, "the prop broken stays broken (%d of %d)" % [world.get_breakable_props().size(), props_before])
	check(prop_cells.all(func(cell: Vector2i) -> bool: return not world.nav.is_blocked(cell)), "...its cells free")
	var back_encounter := _of(world, &"encounters").filter(func(n: Node) -> bool: return (n as Node2D).global_position == encounter_at)
	check(back_encounter.size() == 1 and (back_encounter[0] as Encounter).used, "the encounter used stays used")
	check(world.ambush != null and world.ambush.state == AmbushRoom.State.CLEARED, "the ambush cleared stays cleared (no waves again)")
	var chests := _chests_at(world, chest_cell)
	check(chests.size() == 1 and not chests[0].is_open, "its chest is back where it was put down, still closed")
	if chests.is_empty():
		return
	merchant = world.floor_merchant()
	check(merchant != null and _stock_keys(merchant) == stock_before and merchant.rerolls_done == 1, "the merchant's stock as it was: rerolled, less what was bought, the rerolls paid")
	# (Locked ones: the reroll may well roll the same plain item again, unlocked, beside it.)
	check(merchant.stock.filter(func(e: Dictionary) -> bool: return e.get("locked", false) == true and Merchant._key(LootRoller.to_data(e.item)) == locked_key).size() == 1, "the entry locked there is in it once")
	check(world.kept_stock.is_empty(), "and not waiting for the next merchant too")
	check(world.ledger.spent_count(FloorLedger.ITEM) == 1 and world.ledger.spent_count(FloorLedger.PROP) >= 1 and world.ledger.spent_count(FloorLedger.ENCOUNTER) == 1, "kept for the next save too")

	# A save from before the stock was kept: the seed's stock again, the entry locked there once
	# (kept, and not rolled a second time beside it).
	var older := RunSave.read()
	(older.floor as Dictionary).erase("merchant")
	game.resume_run(older)
	await _frames(5)
	world = game.world
	merchant = world.floor_merchant()
	check(merchant != null and merchant.stock.filter(func(e: Dictionary) -> bool: return e.get("locked", false) == true and Merchant._key(LootRoller.to_data(e.item)) == locked_key).size() == 1, "an older save: the entry locked there is in the merchant's stock once")
	chests = _chests_at(world, chest_cell)
	if chests.is_empty():
		return

	# Its chest opened, then put away again: open.
	chests[0].open()
	await _frames(2)
	later = _later_items(world)
	game._save_run()
	game.resume_run(RunSave.read())
	await _frames(5)
	world = game.world
	chests = _chests_at(world, chest_cell)
	check(chests.size() == 1 and chests[0].is_open, "the ambush's chest opened stays opened")
	check(_of(world, &"pickups").size() == pickups_before - 1 + later and world.get_breakable_props().size() == props_before - 1, "a second resume keeps it all as it was (%d of %d, %d came later)" % [_of(world, &"pickups").size(), pickups_before, later])
	game.player.invincible = false
	game.player.xp = 0


static func _stock_keys(merchant: Merchant) -> Array[String]:
	var keys: Array[String] = []
	for entry in merchant.stock:
		keys.append("%s/%d/%s" % [Merchant._key(LootRoller.to_data(entry.item)), entry.price, entry.get("locked", false)])
	return keys


func _chests_at(world: World, cell: Vector2i) -> Array[Chest]:
	var result: Array[Chest] = []
	for node in world.get_node("Entities").get_children():
		if node is Chest and not node.is_queued_for_deletion() and world.map.world_to_cell((node as Chest).global_position) == cell:
			result.append(node as Chest)
	return result


## The hidden floor is laid from its seed too (a boss floor): its monsters slain before quitting
## stay slain.
func _test_hidden_floor_kept(game: Game) -> void:
	game.start_run()
	await _frames(3)
	if CONTENT.dungeon.hidden_floor == null:
		return
	await game.debug.enter_hidden()
	await _frames(3)
	var world: World = game.world
	var player: Player = game.player
	player.invincible = true
	player.xp = -1000000
	var own := world.get_hostiles(Actor.Faction.PLAYER).filter(func(m: Actor) -> bool: return m is Monster and (m as Monster).floor_index >= 0)
	var all_before := world.monster_count()
	check(world.hidden_floor != null and own.size() >= 2 and own.size() == all_before - 1, "the hidden floor's monsters have their numbers, all but its boss (%d of %d)" % [own.size(), all_before])
	if own.size() < 2:
		return
	var slain: Array[int] = [(own[0] as Monster).floor_index, (own[own.size() - 1] as Monster).floor_index]
	for monster: Actor in [own[0], own[own.size() - 1]]:
		monster.take_hit(Combat.make_secondary_hit(player, 99999))
	await _frames(2)
	game._save_run()
	game.resume_run(RunSave.read())
	await _frames(5)
	world = game.world
	var back := world.get_hostiles(Actor.Faction.PLAYER).filter(func(m: Actor) -> bool: return m is Monster and (m as Monster).floor_index >= 0) \
		.map(func(m: Actor) -> int: return (m as Monster).floor_index)
	check(game.run.hidden_floor and world.hidden_floor != null, "resumed on the hidden floor")
	check(not slain.any(func(i: int) -> bool: return back.has(i)) and back.size() == own.size() - 2, "its monsters slain stay slain, the others are back (%s, slain %s)" % [back, slain])
	check(world.arena != null and is_instance_valid(world.arena.boss), "its warden waits as before")
	game.player.invincible = false


## A run saved after a warden fell picks up in his cleared arena (not on the next floor): the
## warden gone, the stairs there, the hidden way open again with the key still in the bag, what
## he dropped still lying there, nothing given twice. Below, the hidden floor's hoard waits again,
## open if it was opened.
func _test_cleared_arena(game: Game) -> void:
	var hidden_def := CONTENT.dungeon.hidden_floor
	game.start_run()
	await _frames(3)
	var dungeon := CONTENT.dungeon
	var act := clampi(hidden_def.key_acts[0] if hidden_def and not hidden_def.key_acts.is_empty() else 0, 0, dungeon.acts.size() - 1)
	var depth := dungeon.first_depth(act) + dungeon.acts[act].floors - 1
	await game.debug.enter_floor(depth)
	await _frames(3)
	var world: World = game.world
	var player: Player = game.player
	player.invincible = true
	if hidden_def and hidden_def.key:
		player.inventory.add(hidden_def.key)
	# (In a corner: off the spots the hidden way may open on, or he would step in at once.)
	player.global_position = world.nearest_free_point(world.map.cell_to_world(world.map.boss_room.position + Vector2i(2, 2)))
	await _frames(3)
	var hit := HitInfo.new()
	hit.amount = 999999
	world.arena.boss.take_hit(hit)
	await _frames(6)
	_take_offers(game)
	check(world.arena.is_defeated, "the warden of floor %d falls" % depth)
	var loot := world.spawn_item(load("res://data/items/weapons/hammer.tres") as ItemDef, world.map.cell_to_world(world.map.boss_room.get_center() + Vector2i(5, -3)))
	world.spawn_gold(world.map.cell_to_world(world.map.boss_room.get_center() + Vector2i(-5, -3)), 30)
	await _frames(2)
	var gold_left := 0
	for coins: Node in _of(world, &"gold"):
		gold_left += (coins as GoldPickup).amount
	var way_open := game.hidden.way != null and is_instance_valid(game.hidden.way)
	var loot_id := loot.item.id
	var lying := _lying(world, loot_id)
	var bosses := game.run.bosses_slain
	var bag := player.inventory.items.size()
	game._save_run()
	var saved := RunSave.read()
	check(not bool(saved.get("boss_slain", true)) and bool(saved.floor.get("arena_cleared", false)), "the save keeps the cleared arena")
	game.resume_run(saved)
	await _frames(6)
	_take_offers(game)
	world = game.world
	player = game.player
	check(game.depth == depth and not game.run.hidden_floor and world.arena != null and world.arena.is_defeated and world.arena.boss == null, "picked up in the cleared arena of floor %d, the warden gone" % depth)
	check(world.monster_count() == 0 and not world.is_boss_fight(), "no warden to fight again")
	check(world.get_node("Entities").get_children().any(func(n: Node) -> bool: return n is Stairs), "its stairs are there")
	check(game.run.bosses_slain == bosses and player.inventory.items.size() == bag, "nothing counted or given twice (%d bosses, %d in the bag)" % [game.run.bosses_slain, player.inventory.items.size()])
	if hidden_def and hidden_def.key:
		check(way_open and game.hidden.way != null and is_instance_valid(game.hidden.way) and hidden_def.carries_key(player), "the hidden way is open again, the key still in the bag")
	var gold_back := 0
	for coins: Node in _of(world, &"gold"):
		gold_back += (coins as GoldPickup).amount
	check(_lying(world, loot_id) == lying and lying.y >= 1 and gold_back == gold_left and gold_left > 0, "what he dropped still lies there (%s items and hammers of %s, %d of %d gold)" % [_lying(world, loot_id), lying, gold_back, gold_left])
	# Below: the hidden boss fell, its hoard opened, then saved: the hoard waits, open.
	if hidden_def and hidden_def.chest:
		await game.debug.enter_hidden()
		await _frames(3)
		world = game.world
		world.arena.boss.take_hit(hit)
		await _frames(6)
		_take_offers(game)
		var hoards := world.get_node("Entities").get_children().filter(func(n: Node) -> bool: return n is Chest and (n as Chest).def == hidden_def.chest)
		check(hoards.size() == 1, "the hidden boss leaves its hoard")
		(hoards[0] as Chest).open()
		await _frames(2)
		game._save_run()
		game.resume_run(RunSave.read())
		await _frames(6)
		_take_offers(game)
		world = game.world
		hoards = world.get_node("Entities").get_children().filter(func(n: Node) -> bool: return n is Chest and (n as Chest).def == hidden_def.chest)
		check(game.run.hidden_floor and world.arena.is_defeated and hoards.size() == 1 and (hoards[0] as Chest).is_open, "picked up below, the hoard stands there again, open as it was left")
	game.player.invincible = false


## Put away in the middle of things (roadmap tasks 198 and 199): an ambush under way goes on where
## it was when the hero walks back in (the waves beaten stay beaten, the wave under way brings only
## what still stood, at the Health it had: nothing to farm by quitting), and loot that came later
## and lay on the ground (a drop, coins, what the hero put down) lies there again, once.
func run_resume_leftovers(game: Game) -> void:
	var config := CONTENT.dungeon
	var kept_chance := config.ambush_chance
	var kept_waves := config.ambush_waves
	config.ambush_chance = 1.0
	config.ambush_waves = maxi(config.ambush_waves, 3)
	game.start_run()
	await _frames(3)
	var player: Player = game.player
	player.invincible = true
	player.xp = -1000000  # no level up (and its choice) from the kills below
	var world: World = game.world
	for target in range(2, 12):
		if world.ambush:
			break
		game.depth = target
		game._enter_floor()
		await _frames(3)
		world = game.world
	var ambush := world.ambush
	check(ambush != null, "a floor with an ambush (depth %d)" % game.depth)
	if ambush == null:
		config.ambush_chance = kept_chance
		config.ambush_waves = kept_waves
		return
	# The first wave beaten, the second come in: one of it slain, one hurt.
	ambush.start()
	var waves := ambush.waves_left + 1
	for i in 60 * 30:
		if ambush.waves_left < waves - 1 and ambush._to_spawn.is_empty() and not ambush._wave.is_empty():
			break
		if ambush._to_spawn.is_empty():
			for monster: Variant in ambush._wave:
				if is_instance_valid(monster) and not (monster as Monster).is_dead:
					(monster as Monster).take_hit(Combat.make_secondary_hit(player, 99999))
		await _frames(1)
	var standing := ambush._wave.filter(func(m: Variant) -> bool: return is_instance_valid(m) and not (m as Monster).is_dead)
	check(ambush.state == AmbushRoom.State.FIGHTING and ambush.waves_left == waves - 2 and standing.size() >= 2, "the ambush's second wave stands (%d waves left, %d monsters)" % [ambush.waves_left, standing.size()])
	if standing.size() < 2:
		config.ambush_chance = kept_chance
		config.ambush_waves = kept_waves
		return
	(standing[0] as Monster).take_hit(Combat.make_secondary_hit(player, 99999))
	var hurt := standing[1] as Monster
	hurt.hp = maxi(1, floori(hurt.get_max_hp() / 3.0))
	await _frames(2)
	var hurt_share := float(hurt.hp) / hurt.get_max_hp()  # (as saved: a moss heart may have mended it a little)
	var waves_left := ambush.waves_left
	var still := standing.size() - 1
	# Loot that came later: a drop and coins lying on the floor, away from the ambush.
	# (In a room far from where the hero comes back, and from the ambush: nothing picks it up.)
	var spot := world.map.cell_to_world(world.map.start_cell)
	for room in world.map.rooms:
		var center := world.map.cell_to_world(room.get_center())
		if not room.intersects(ambush.room) and center.distance_to(world.map.cell_to_world(world.map.start_cell)) > spot.distance_to(world.map.cell_to_world(world.map.start_cell)):
			spot = center
	spot = world.nearest_free_point(spot)
	player.global_position = world.nearest_free_point(world.map.cell_to_world(ambush.room.get_center()))
	var drop_id := (load("res://data/items/weapons/hammer.tres") as ItemDef).id
	world.spawn_item(load("res://data/items/weapons/hammer.tres") as ItemDef, spot)
	world.spawn_gold(spot + Vector2(0, 32), 23)
	await _frames(2)
	var hammers := _lying(world, drop_id).y
	var coins_before := 0
	for coins: Node in _of(world, &"gold"):
		coins_before += (coins as GoldPickup).amount
	var kills := game.run.kills

	game._save_run()
	game.resume_run(RunSave.read())
	await _frames(5)
	world = game.world
	player = game.player
	player.invincible = true
	player.xp = -1000000
	ambush = world.ambush
	check(ambush != null and ambush.state == AmbushRoom.State.WAITING, "resumed, the ambush waits for the hero again")
	var coins_back := 0
	for coins: Node in _of(world, &"gold"):
		coins_back += (coins as GoldPickup).amount
	check(_lying(world, drop_id).y == hammers and hammers >= 1, "the drop left on the ground lies there again (%d of %d)" % [_lying(world, drop_id).y, hammers])
	check(coins_back == coins_before and coins_before >= 23, "...and the coins (%d of %d)" % [coins_back, coins_before])
	# Saved again at once and picked up again: still once, not twice.
	game._save_run()
	game.resume_run(RunSave.read())
	await _frames(5)
	world = game.world
	player = game.player
	player.invincible = true
	player.xp = -1000000
	ambush = world.ambush
	check(_lying(world, drop_id).y == hammers, "saved again, it lies there once (%d of %d)" % [_lying(world, drop_id).y, hammers])
	if ambush == null:
		config.ambush_chance = kept_chance
		config.ambush_waves = kept_waves
		return
	ambush.start()
	for i in 60 * 10:
		if ambush._to_spawn.is_empty() and ambush._wave.size() >= still:
			break
		await _frames(1)
	var back := ambush._wave.filter(func(m: Variant) -> bool: return is_instance_valid(m) and not (m as Monster).is_dead)
	check(ambush.waves_left == waves_left, "walked in again, the waves beaten stay beaten (%d left, %d before quitting)" % [ambush.waves_left, waves_left])
	check(back.size() == still, "the wave under way brings only what still stood (%d of %d)" % [back.size(), still])
	var shares := back.map(func(m: Variant) -> float: return snappedf(float((m as Monster).hp) / (m as Monster).get_max_hp(), 0.01))
	check(shares.any(func(share: float) -> bool: return share < 0.9 and absf(share - hurt_share) < 0.1), "...the hurt one about as hurt as it was (%s, %.2f)" % [shares, hurt_share])
	check(game.run.kills == kills, "no kill counted twice (%d)" % game.run.kills)
	config.ambush_chance = kept_chance
	config.ambush_waves = kept_waves
	game.player.invincible = false


## How many items that came later (not laid by the floor's seed) lie on `world`'s floor: what a
## save keeps in "left" (FloorSave.left_behind()).
func _later_items(world: World) -> int:
	return world.floor_save.left_behind().filter(func(entry: Array) -> bool: return entry[0] == "item").size()


## How many items lie on `world`'s floor, and how many of them are `id`.
func _lying(world: World, id: StringName) -> Vector2i:
	var items := world.get_node("Entities").get_children().filter(func(n: Node) -> bool: return n is ItemPickup and (n as ItemPickup).item != null and not (n as ItemPickup).is_taken())
	return Vector2i(items.size(), items.filter(func(n: Node) -> bool: return (n as ItemPickup).item.id == id).size())


func _take_offers(game: Game) -> void:
	for i in 4:
		if game.perk_panel.visible:
			game.perk_panel.choose(0)


## A floor saved by another build (a game update in between) may come out otherwise from the
## same seed: it is laid fresh, said in a note, while the hero and the run come back whole.
func _test_other_build(game: Game) -> void:
	game.start_run()
	await _frames(3)
	game.depth = 2
	game._enter_floor()
	await _frames(3)
	var world: World = game.world
	var player: Player = game.player
	check(world.arena == null and world.monster_count() > 0, "a normal floor (%d monsters)" % world.monster_count())
	player.invincible = true
	player.xp = -1000000
	var monsters_before := world.monster_count()
	var pickups_before := _of(world, &"pickups").size()
	for pickup in _of(world, &"pickups").slice(0, 1):
		(pickup as ItemPickup).take(player)
	world.get_hostiles(Actor.Faction.PLAYER)[0].take_hit(Combat.make_secondary_hit(player, 99999))
	await _frames(2)
	player.gold = 321
	player.level = 4
	game._save_run()
	var saved := RunSave.read()
	saved.floor.stamp = "0.0.1/1"  # as an older build would have written it
	RunSave.write(saved)
	game.resume_run(RunSave.read())
	await _frames(5)
	world = game.world
	var note := tr("The Well has shifted since you left: this floor is laid anew.")
	check((game.hud.get_node("%ToastLabel") as Label).text == note or game.hud._toasts.has(note), "a note says the floor is laid anew")
	check(game.depth == 2 and game.player.gold == 321 and game.player.level == 4, "the run and the hero come back whole")
	check(world.monster_count() == monsters_before and _of(world, &"pickups").size() == pickups_before and world.seal.kills == 0, "the floor is laid fresh: its monsters, its items, its seal (%d/%d monsters, %d/%d items)" % [world.monster_count(), monsters_before, _of(world, &"pickups").size(), pickups_before])
	check(world.ledger.spent_count(FloorLedger.ITEM) == 0 and world.floor_save.slain.is_empty(), "nothing of the old floor kept for the next save")
	game.player.invincible = false


## A save of the first version comes back (migrated); damaged fields never stop the game.
func _test_old_and_damaged_saves(game: Game) -> void:
	game.start_run()
	await _frames(3)
	game.depth = 2
	game._enter_floor()
	await _frames(3)
	game.player.gold = 77
	game._save_run()
	var data: Dictionary = SafeFile.read_json(RunSave.path)
	data.version = 1
	(data.floor as Dictionary).erase("stamp")
	(data.floor as Dictionary).erase("spent")
	SafeFile.write_json(RunSave.path, data)
	var old := RunSave.read()
	check(not old.is_empty() and int(old.version) == RunSave.VERSION, "a version 1 save is read, migrated")
	game.resume_run(old)
	await _frames(5)
	check(game.depth == 2 and game.player != null and game.player.gold == 77, "its run comes back")

	# Damaged everywhere the game reads (a hand-edited file, a disk gone bad): the game goes on.
	data = SafeFile.read_json(RunSave.path)
	data.kept_stock = "x"
	data.routes = [1]
	data.splits = { "a": 1 }
	data.marks = 3
	data.player.perks = [1, "x", { "perk": 3, "stacks": "a" }]
	data.player.equipment = []
	data.player.base_stats = { "max_hp": [1] }
	data.offers = "x"
	data.floor = { "stamp": RunSave.floor_stamp(), "chests": 5, "spent": "x", "merchant": 3, "ambush": [1], "slain": { "a": 1 }, "secrets": "x", "sealed": [[1]], "bought": 4 }
	SafeFile.write_json(RunSave.path, data)
	var damaged := RunSave.read()
	check(not damaged.is_empty(), "a damaged save is still a run")
	game.resume_run(damaged)
	await _frames(5)
	check(game.depth == 2 and game.player != null and not game.player.is_dead and game.world.map != null, "picked up again: the hero on his floor")
	# The floor's restore checks its own data too (it may be handed anything).
	game.world.restore_spent({
		"chests": [[1], "x", [1, "a"]], "spent": { "items": "x", "props": [[0]], "gold": [["a", 1]] },
		"merchant": { "stock": [1, { "item": 3, "price": "x" }], "rerolls": "x" }, "ambush": { "cleared": true, "room": "x" },
		"bought": [1], "secrets": [1, [2]], "slain": [[1]], "seal_kills": 2.5, "pact": "x", "collapsed": "x", "sealed": [["a", "b"]],
	})
	game._enter_floor(true)
	await _frames(3)
	check(game.world.map != null and game.player.world == game.world, "a floor restored from damaged data is built all the same")
	game.world.restore_spent("x")
	game._enter_floor(true)
	await _frames(3)
	check(game.world.map != null, "and from no data at all")
