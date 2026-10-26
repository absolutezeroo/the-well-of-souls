class_name CampaignTests
extends TestSuite
## Campaign schema, coherent filesystem checkpoints and the real PlayerSave bridge. No test
## path is a production save; interruption tests keep both domains in the same generation.


class InterruptedStore:
	extends CampaignSave
	var stop_at := -1

	func _checkpoint(step: CommitStep) -> bool:
		return step != stop_at


func run_unit() -> void:
	var hero := (load("res://src/entities/player/player.tscn") as PackedScene).instantiate() as Player
	hero.setup(CONTENT.player)
	_rich_gear(hero)
	var state := CampaignState.create(hero, "test:region_a")
	check(state != null, "a real PlayerSave can seed an explicit prototype campaign")
	if state:
		_test_schema(state)
		_test_store(state)
		_test_interruptions(state)
	hero.free()


func _test_schema(state: CampaignState) -> void:
	check(PersistentId.valid(state.id, "campaign") and PersistentId.valid(state.hero.id, "character")
		and PersistentId.valid(state.world_state.id, "world") and state.hero.id != PersistentId.create("character"),
		"campaign, world and character get distinct durable scoped identities")
	var region := RegionState.new()
	region.id = "test:region_b"
	state.world_state.regions[region.id] = region
	state.world_state.regions["test:region_a"].facts["chest:shared"] = true
	state.hero.claimed_rewards["chest:personal"] = true
	var data := state.to_data()
	var parsed := JSON.new()
	check(parsed.parse(JSON.stringify(data)) == OK, "campaign snapshots contain JSON values only")
	var copy := CampaignState.from_data(parsed.data)
	check(copy != null and copy.id == state.id and copy.hero.id == state.hero.id
		and copy.world_state.regions.size() == 2 and copy.hero.claimed_rewards["chest:personal"]
		and copy.world_state.regions["test:region_a"].facts["chest:shared"],
		"round-trip preserves identities, two regions and distinct personal/shared rights")
	(data.hero.player as Dictionary).gold = 999
	(data.world.regions["test:region_a"].facts as Dictionary).clear()
	check(state.hero.to_data().player.gold != 999 and copy.world_state.regions["test:region_a"].facts.size() == 1,
		"serialized snapshots do not alias the live character or region maps")
	for damage in ["owner", "position", "gold", "field", "inventory", "belt", "perk", "stats", "revision", "region"]:
		var bad := state.to_data()
		match damage:
			"owner": bad.hero.world_id = PersistentId.create("world")
			"position": bad.hero.position = [0, INF]
			"gold": bad.hero.player.gold = -1
			"field": bad["account_password"] = "never copied"
			"inventory": bad.hero.player.inventory = ["@item:missing"]
			"belt": bad.hero.player.belt = [{ "item": "@missing", "count": 2 }, {}, {}]
			"perk": bad.hero.player.perks = [{ "perk": "@missing", "stacks": 1, "memory": {} }]
			"stats": bad.hero.player.base_stats.max_hp = "damaged"
			"revision": bad.revision = 1.5
			"region": bad.hero.region_id = "test:missing"
		check(CampaignState.from_data(bad) == null, "invalid campaign refuses whole snapshot: " + damage)
	var nested: Variant = true
	for i in CampaignFormat.MAX_NESTING + 2:
		nested = [nested]
	var runtime_node := Node.new()
	check(not CampaignFormat.plain(nested) and not CampaignFormat.plain(runtime_node),
		"runtime objects and excessively nested payloads are not serializable campaign state")
	runtime_node.free()
	var kept := state.content_version
	state.content_version = "another-content-build"
	check(CampaignState.from_data(state.to_data()) != null,
		"a content build change does not silently regenerate or erase persistent region facts")
	state.content_version = kept


func _test_store(template: CampaignState) -> void:
	var test_path := _path("store")
	_clean(test_path)
	var store := CampaignSave.new(test_path)
	check(store.load_state() == null and store.last_failure == CampaignSave.Failure.MISSING,
		"a missing campaign is explicit, never an implicit new character")
	var state := CampaignState.from_data(template.to_data())
	check(store.commit(state) and state.revision == 1, "first complete campaign commits once")
	var stale := store.load_state()
	state.world_state.facts["quest:paid"] = true
	state.hero.claimed_rewards["quest:paid"] = true
	check(store.commit(state) and state.revision == 2, "personal reward claim and world fact share a committed revision")
	check(not store.commit(stale) and store.last_failure == CampaignSave.Failure.CONFLICT,
		"an old in-memory revision cannot overwrite a newer campaign")
	var stranger := CampaignState.from_data(state.to_data())
	stranger.hero.id = PersistentId.create("character")
	check(not store.commit(stranger) and store.last_failure == CampaignSave.Failure.CONFLICT,
		"matching revision cannot substitute a different character")
	var main_before := FileAccess.get_file_as_bytes(test_path)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(test_path + ".bak.tmp"))
	check(not store.commit(state) and store.last_failure == CampaignSave.Failure.IO
		and FileAccess.get_file_as_bytes(test_path) == main_before and state.revision == 2,
		"failed backup write leaves the main and caller revision unchanged")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + ".bak.tmp"))
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(test_path + ".lock"))
	check(not store.commit(state) and store.last_failure == CampaignSave.Failure.BUSY,
		"a second writer or crashed writer's lock blocks publication")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + ".lock"))
	# A valid temp snapshot is uncommitted; never prefer it over the published checkpoint.
	SafeFile.write_json(test_path + ".tmp", SafeFile.read_json(test_path + ".bak"))
	check(store.load_state().revision == 2, "an uncommitted temporary generation is ignored")
	var missing_content := state.to_data()
	missing_content.hero.player.inventory = ["@missing:equipment"]
	SafeFile.write_json(test_path, _envelope(missing_content))
	check(store.load_state() == null and store.last_failure == CampaignSave.Failure.INCOMPATIBLE,
		"unknown content cannot silently drop an item or load an older backup")
	SafeFile.write_json(test_path, _envelope(state.to_data()))
	var wrong_hash := _envelope(state.to_data())
	wrong_hash.payload += " "
	SafeFile.write_json(test_path, wrong_hash)
	check(store.load_state().revision == 1 and store.recovered,
		"parseable bytes with the wrong checksum recover the complete previous checkpoint")
	_write_text(test_path, "{broken")
	var recovered := store.load_state()
	check(recovered != null and recovered.revision == 1 and store.recovered,
		"truncated main recovers the previous complete checkpoint with visible recovery status")
	check(store.commit(recovered) and store.load_state().revision == 2,
		"repairing the main preserves the good backup instead of copying damaged bytes over it")
	var future: Dictionary = SafeFile.read_json(test_path)
	future.version = CampaignSave.VERSION + 1
	SafeFile.write_json(test_path, future)
	var unchanged := FileAccess.get_file_as_bytes(test_path)
	check(store.load_state() == null and store.last_failure == CampaignSave.Failure.INCOMPATIBLE,
		"a future version never falls back to an older character from the backup")
	check(not store.commit(recovered) and FileAccess.get_file_as_bytes(test_path) == unchanged,
		"an incompatible campaign is never overwritten")
	_clean(test_path)
	SafeFile.write_json(test_path + ".tmp", future)
	check(store.load_state() == null and store.last_failure == CampaignSave.Failure.MISSING,
		"a first write interrupted before publication is not a committed campaign")
	_clean(test_path)
	var disabled := CampaignSave.new()
	check(not disabled.commit(state) and disabled.last_failure == CampaignSave.Failure.DISABLED,
		"no implicit save path can touch a player's campaign")


func _test_interruptions(template: CampaignState) -> void:
	for step in CampaignSave.CommitStep.values():
		var test_path := _path("interruption_%d" % step)
		_clean(test_path)
		var initial := InterruptedStore.new(test_path)
		initial.stop_at = step
		var fresh := CampaignState.from_data(template.to_data())
		check(not initial.commit(fresh), "first publication can stop at boundary %d" % step)
		var first_read := CampaignSave.new(test_path)
		var first_state := first_read.load_state()
		check((first_state != null and first_state.revision == 1) if step == CampaignSave.CommitStep.AFTER_PUBLISH
			else (first_state == null and first_read.last_failure == CampaignSave.Failure.MISSING),
			"first interrupted publication is either fully committed or absent at boundary %d" % step)
		_clean(test_path)
		var store := InterruptedStore.new(test_path)
		var before := CampaignState.from_data(template.to_data())
		check(store.commit(before), "baseline checkpoint for interruption %d" % step)
		var next := store.load_state()
		var data := next.hero.to_data()
		data.player.gold += 37
		next.hero = CharacterState.from_data(data)
		next.hero.claimed_rewards["chest:paid"] = true
		next.world_state.regions["test:region_a"].facts["chest:paid"] = true
		store.stop_at = step
		check(not store.commit(next) and store.last_failure == CampaignSave.Failure.INTERRUPTED,
			"publication can stop at boundary %d" % step)
		var resumed := CampaignSave.new(test_path).load_state()
		var published: bool = step == CampaignSave.CommitStep.AFTER_PUBLISH
		check(resumed != null and resumed.revision == (2 if published else 1)
			and resumed.hero.to_data().player.gold == before.hero.to_data().player.gold + (37 if published else 0)
			and resumed.hero.claimed_rewards.get("chest:paid", false) == published
			and resumed.world_state.regions["test:region_a"].facts.get("chest:paid", false) == published,
			"interruption %d restores both reward and world fact together, never half a transaction" % step)
		if published:
			store.stop_at = -1
			check(not store.commit(next) and store.last_failure == CampaignSave.Failure.CONFLICT,
				"lost acknowledgement cannot replay an already committed reward")
		_clean(test_path)


func run_game(game: Game) -> void:
	var player := game.player
	player.invincible = true
	player.gold = 123
	_rich_gear(player)
	var state := CampaignState.create(player, "test:region_a")
	check(state != null and game.session.attach_campaign(state), "the running session explicitly binds a durable campaign")
	if state == null:
		return
	var region := RegionState.new()
	region.id = "test:region_b"
	state.world_state.regions[region.id] = region
	state.world_state.regions["test:region_a"].facts["chest:first"] = true
	state.hero.claimed_rewards["quest:first"] = true
	player.gold = 86
	check(game.session.capture_character(), "session captures its live hero without copying Profile or account settings")
	state.hero.region_id = region.id
	state.world_state.regions[region.id].facts["gate:open"] = true
	state.hero.region_id = "test:region_a"
	var test_path := _path("game")
	_clean(test_path)

	var store := CampaignSave.new(test_path)
	check(store.commit(state), "the live hero and visited-region facts commit together")
	var read_back := CampaignSave.new(test_path).load_state()
	player.gold = 1
	player.inventory.items.clear()
	var restored := read_back != null and read_back.hero.restore(player)
	# JSON parses all numbers as doubles: 1 and 1.0 encode the same saved count. Compare
	# complete parsed trees, not their formatting; no field or numeric value is omitted.
	var actual: Variant = JSON.parse_string(JSON.stringify(player.save_state()))
	var expected: Variant = JSON.parse_string(JSON.stringify(state.hero.to_data().player))
	check(restored and player.gold == 86
		and actual == expected,
		"a loaded campaign restores the real hero's complete PlayerSave payload")
	var entry := player.perks.get_entry(CONTENT.perks[0])
	check(entry != null and entry.memory.get(&"used", 0) == 1 and not entry.memory.has("_until"),
		"durable StringName-keyed passive counters survive, transient frame clocks do not")
	check(read_back.world_state.regions["test:region_a"].facts["chest:first"]
		and read_back.world_state.regions[region.id].facts["gate:open"] and read_back.hero.region_id == "test:region_a",
		"A then B then A survives restart in the durable region-fact model")
	game.session.leave_expedition()
	check(game.session.campaign == state and game.session.character == player,
		"leaving an expedition retains both durable campaign and live hero")
	game.start_run()
	check(game.session.campaign == null, "starting the legacy mode never imports or overwrites the campaign")
	check(CampaignSave.new(test_path).load_state().id == state.id,
		"legacy restart leaves the separately saved campaign intact")
	_clean(test_path)


## Exercise rolled gear, runes, perks and StringName passive-memory keys, not only an empty kit.
func _rich_gear(player: Player) -> void:
	var base := player.get_weapon()
	if base and not CONTENT.item_affixes.is_empty() and not CONTENT.runes.is_empty():
		var affixes: Array[ItemAffixDef] = [CONTENT.item_affixes[0]]
		var runes: Array[RuneDef] = [CONTENT.runes[0]]
		var rolled := LootRoller.make(base, ItemRarity.RARE, affixes, runes, 7)
		player.equipment.equip(rolled)
		player.inventory.force_add(rolled)
	if not CONTENT.perks.is_empty():
		player.perks.add(CONTENT.perks[0])
		player.perks.get_entry(CONTENT.perks[0]).memory[&"used"] = 1
		player.perks.get_entry(CONTENT.perks[0]).memory["_until"] = 123


func _envelope(data: Dictionary) -> Dictionary:
	var payload := JSON.stringify(data)
	return { "format": CampaignSave.FORMAT, "version": CampaignSave.VERSION,
		"payload": payload, "sha256": payload.sha256_text() }

func _path(label_name: String) -> String:
	return "user://test_campaign_%d_%s.json" % [OS.get_process_id(), label_name]


func _clean(test_path: String) -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		if FileAccess.file_exists(test_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + suffix))
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(test_path + ".lock")):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + ".lock"))


func _write_text(test_path: String, text: String) -> void:
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
