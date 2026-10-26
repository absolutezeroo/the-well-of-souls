class_name RegionTests
extends TestSuite
## Authored maps, retained actor, transactional region departure and persistent loose items.
## Tests load the standalone proof scene, never an existing player's campaign or run.

const PROOF := preload("res://tools/rpg/region_proof.tscn")
const ATLAS: RegionAtlas = preload("res://data/regions/proof/atlas.tres")
const POTION: ItemDef = preload("res://data/items/consumables/health_potion.tres")


func run_unit() -> void:
	check(ATLAS.valid(), "the data atlas has reachable entries, items and valid destination links")
	var region := ATLAS.regions[0].duplicate() as RegionDef
	region.rows = PackedStringArray(["###", "#.", "###"])
	check(not region.valid(), "unequal row lengths are rejected before building a scene")
	region = ATLAS.regions[0].duplicate() as RegionDef
	region.entries = { "bad": Vector2i.ZERO }
	check(not region.valid(), "entries in a wall cannot be loaded")
	region = ATLAS.regions[0].duplicate() as RegionDef
	region.entries = { "bad": region.links[0].cell }
	check(not region.valid(), "an arrival cannot trigger an immediate return portal")
	var atlas := ATLAS.duplicate() as RegionAtlas
	atlas.regions = [ATLAS.regions[0], ATLAS.regions[0]]
	check(not atlas.valid(), "duplicate region identities cannot alias one persistent region")
	atlas = ATLAS.duplicate() as RegionAtlas
	atlas.regions = [ATLAS.regions[0]]
	check(not atlas.valid(), "a missing destination is rejected in the data graph")
	var map := ATLAS.regions[0].make_map(ATLAS.start_entry)
	check(ATLAS.regions[0].safe_position(map, map.cell_to_world(map.start_cell), CONTENT.player.radius),
		"a validated entry leaves room for the actual hero's body")
	var object_state := RegionObjectState.create(PersistentId.create("object"), POTION, Vector2(80, 80))
	var encoded := object_state.to_data()
	check(RegionObjectState.from_data(encoded).id == object_state.id,
		"loose items keep their instance identity and exact serialized content")
	encoded.item = "@missing:item"
	check(RegionObjectState.from_data(encoded) == null, "unavailable persistent loot is refused, never silently dropped")


func run_world() -> void:
	var path := "user://test_regions_%d.json" % OS.get_process_id()
	_clean(path)
	var proof := PROOF.instantiate() as RegionProof
	proof.checkpoint_path = path
	add_child(proof)
	await _frames(3)
	check(proof.started, "standalone region proof starts with the production World pipeline")
	if not proof.started:
		proof.free()
		_clean(path)
		return
	var coordinator := proof.coordinator
	var hero := proof.session.character
	var character_id := proof.session.campaign.hero.id
	var first_tiles := proof.world.map.tiles.duplicate()
	var pickups := _pickups(proof.world)
	check(pickups.size() == 1, "the first visit places the region's authored item once")
	check(pickups[0].take(hero), "a successfully collected region item enters the real hero's pack")
	await _frames(2)
	var before := hero.save_state()
	hero.hp = maxi(1, hero.hp - 3)
	var health := hero.hp
	hero.start_dash(Vector2.RIGHT * 200.0, 0.8, true)
	check(coordinator.travel("to_hall"), "region departure commits the hero and source before unloading")
	check(proof.session.character == hero and proof.session.campaign.hero.id == character_id
		and hero.hp == health and hero.gold == int(before.gold) and not hero.is_dashing(),
		"region travel retains the same hero and progression, stops old motion and grants no heal")
	await _frames(3)
	check(coordinator.current_id == "proof:hall" and proof.world.map.tiles != first_tiles,
		"the second region is a different loaded collision/render map")
	check(proof.world.is_solid_ground(hero.global_position), "the destination places the hero on safe ground")
	check(_pickups(proof.world).size() == 1, "the second region has its own item ledger")
	check(coordinator.travel("to_courtyard"), "the return passage loads the first place")
	await _frames(3)
	check(proof.world.map.tiles == first_tiles and _pickups(proof.world).is_empty(),
		"A/B/A keeps identical authored geometry and never respawns a collected item")
	# A real rolled dynamic drop must persist too, not just its base resource or a seed number.
	var base := hero.get_weapon()
	var affixes: Array[ItemAffixDef] = [CONTENT.item_affixes[0]]
	var runes: Array[RuneDef] = [CONTENT.runes[0]]
	var rolled := LootRoller.make(base, ItemRarity.RARE, affixes, runes, 7)
	var drop_at := proof.world.map.cell_to_world(Vector2i(5, 9))
	proof.world.spawn_item(rolled, drop_at)
	check(coordinator.checkpoint(), "a just-created deferred drop is included in a coherent checkpoint")
	await _frames(2)
	var objects := proof.session.campaign.world_state.regions["proof:courtyard"].objects
	check(objects.size() == 1, "dynamic ground loot owns a durable instance id")
	var dropped_id: String = objects.keys()[0]
	check(coordinator.travel("to_hall"), "leaving persists uncollected dynamic loot")
	await _frames(2)
	check(coordinator.travel("to_courtyard"), "revisiting restores the dynamic drop")
	await _frames(3)
	pickups = _pickups(proof.world)
	check(pickups.size() == 1 and pickups[0].global_position == drop_at
		and JSON.stringify(LootRoller.to_data(pickups[0].item)) == JSON.stringify(LootRoller.to_data(rolled))
		and proof.session.campaign.world_state.regions["proof:courtyard"].objects.has(dropped_id),
		"rolled item identity, affixes, rarity, level and position survive an actual revisit")
	# Failed publication must leave the loaded place and live actor available, not half travel.
	var floor_id := proof.world.floor_id
	var position_before := hero.global_position
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".lock"))
	check(not coordinator.travel("to_hall") and coordinator.last_failure == RegionCoordinator.Failure.SAVE
		and proof.world.floor_id == floor_id and coordinator.current_id == "proof:courtyard"
		and hero.global_position == position_before and _pickups(proof.world).size() == 1,
		"a blocked save aborts travel before clearing the source or replacing its hero")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".lock"))
	var changed_atlas := ATLAS.duplicate() as RegionAtlas
	var changed_hall := ATLAS.regions[1].duplicate() as RegionDef
	changed_hall.layout_version += 1
	changed_atlas.regions = [ATLAS.regions[0], changed_hall]
	coordinator.atlas = changed_atlas
	check(not coordinator.travel("to_hall") and coordinator.last_failure == RegionCoordinator.Failure.LAYOUT
		and proof.world.floor_id == floor_id and _pickups(proof.world).size() == 1,
		"changed region geometry requires migration instead of silently resetting saved objects")
	coordinator.atlas = ATLAS
	# Two requests made in one old region: only its first successful transition may execute.
	coordinator.request_travel("to_hall")
	coordinator.request_travel("to_hall")
	await _frames(4)
	check(coordinator.current_id == "proof:hall" and proof.world.floor_id == floor_id + 1,
		"a queued request from an unloaded region cannot cause a second transition")
	# Deferred insertion from the old region must not land in the new region's Entities.
	var stale_drop: WeakRef = weakref(proof.world.spawn_item(POTION, proof.world.map.cell_to_world(Vector2i(12, 12))))
	check(coordinator.travel("to_courtyard"), "a pending old-region drop is captured before departure")
	await _frames(3)
	check(stale_drop.get_ref() == null and _pickups(proof.world).size() == 1,
		"deferred pickups from an old floor never appear in the destination")
	check(coordinator.checkpoint(), "the active region can checkpoint without duplicating loaded items")
	var saved_id := proof.session.campaign.id
	proof.free()
	await _frames(2)
	proof = PROOF.instantiate() as RegionProof
	proof.checkpoint_path = path
	add_child(proof)
	await _frames(3)
	check(proof.started and proof.session.campaign.id == saved_id and proof.session.campaign.hero.id == character_id,
		"a fresh scene resumes the same durable campaign and character")
	check(proof.coordinator.current_id == "proof:courtyard" and _pickups(proof.world).size() == 1,
		"restart restores current place and loose loot without the collected authored item")
	check(proof.coordinator.travel("to_hall"), "the other place remains reachable after restart")
	await _frames(3)
	check(_pickups(proof.world).size() == 2, "the other region retains both its authored item and the deferred dynamic drop")
	await _test_portal(proof)
	_test_old_schema(proof, path + ".v1")
	proof.free()
	await _frames(2)
	_clean(path)


func _test_portal(proof: RegionProof) -> void:
	var hero := proof.session.character
	var region := proof.atlas.find("proof:hall")
	hero.global_position = proof.world.map.cell_to_world(region.links[0].cell)
	await _frames(8)
	check(proof.coordinator.current_id == "proof:courtyard",
		"walking onto a real exit trigger requests travel safely outside the physics callback")
	var current := proof.world.floor_id
	await _frames(8)
	check(proof.world.floor_id == current and proof.world.is_solid_ground(hero.global_position),
		"arrival stays clear of the return trigger and does not bounce between regions")


func _test_old_schema(proof: RegionProof, path: String) -> void:
	_clean(path)
	var data := proof.session.campaign.to_data()
	for key: String in data.world.regions:
		var region: Dictionary = data.world.regions[key]
		region.erase("initialized")
		region.erase("layout_stamp")
		region.erase("objects")
		for field in ["population_initialized", "population_stamp", "gold", "monsters", "chests", "explored"]:
			region.erase(field)
	(data.world.facts as Dictionary)["old:quest"] = true
	var payload := JSON.stringify(data)
	SafeFile.write_json(path, { "format": CampaignSave.FORMAT, "version": 1,
		"payload": payload, "sha256": payload.sha256_text() })
	var original := FileAccess.get_file_as_bytes(path)
	var store := CampaignSave.new(path)
	var restored := store.load_state()
	check(restored != null and restored.world_state.facts.get("old:quest", false)
		and not restored.world_state.regions["proof:courtyard"].initialized,
		"campaign v1 gains empty object ledgers while retaining all old world facts")
	check(FileAccess.get_file_as_bytes(path) == original, "migration on read never overwrites the original checkpoint")
	check(store.commit(restored) and int((SafeFile.read_json(path) as Dictionary).version) == CampaignSave.VERSION,
		"the next explicit commit publishes the current campaign schema")
	_clean(path)


func _pickups(world: World) -> Array[ItemPickup]:
	var result: Array[ItemPickup] = []
	for node in get_tree().get_nodes_in_group("pickups"):
		if world.is_ancestor_of(node) and not (node as ItemPickup).is_taken() and not node.is_queued_for_deletion():
			result.append(node as ItemPickup)
	return result


func _clean(path: String) -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
