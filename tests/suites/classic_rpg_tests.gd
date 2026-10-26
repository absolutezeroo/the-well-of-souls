class_name ClassicRpgTests
extends TestSuite
## Public RPG lifecycle: permanent progress, transactional talents/quests, explicit renewal,
## death recovery and disk restart. Every file belongs to this test process.

const RUNTIME := preload("res://src/game/campaign_runtime.tscn")
const SCREEN := preload("res://src/ui/campaign/campaign_screen.tscn")
const DEFINITION: CampaignDef = preload("res://data/campaign/campaign.tres")


func run_unit() -> void:
	check(DEFINITION.valid(), "the playable campaign has a safe refuge, connected places and valid objectives")
	check(DEFINITION.atlas.regions.size() == 4, "the campaign includes its refuge, passage and two combat destinations")
	var changed := DEFINITION.duplicate() as CampaignDef
	changed.refuge_region = "campaign:cave"
	check(not changed.valid(), "a combat region cannot become a safe death-return refuge")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://src/ui/campaign/campaign_screen.tscn",
		"the application's default player flow is the persistent RPG")
	for region in DEFINITION.atlas.regions:
		check(region.valid(), "each campaign place validates its reachable graph and fixed content")
	var invalid := RegionState.new().to_data()
	invalid.explored = "ff"
	check(RegionState.from_data(invalid) == null, "exploration refuses non-boolean bytes instead of loading corrupt visibility")
	var path := "user://test_classic_lock_%d.json" % OS.get_process_id()
	var store := CampaignSave.new(path)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".lock"))
	var occupied := FileAccess.open(path + ".lock/occupied", FileAccess.WRITE)
	occupied.store_string("keep")
	occupied.close()
	check(not store.release_abandoned_lock() and FileAccess.file_exists(path + ".lock/occupied"),
		"explicit recovery never removes a nonempty save lock or its contents")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".lock/occupied"))
	check(store.release_abandoned_lock() and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path + ".lock")),
		"explicit recovery can release an abandoned empty lock")


func run_world() -> void:
	var path := "user://test_classic_%d.json" % OS.get_process_id()
	_clean(path)
	var game := RUNTIME.instantiate() as CampaignRuntime
	add_child(game)
	check(game.begin(path, false), "a new campaign starts and publishes an actual coherent checkpoint")
	if not game.started:
		game.free()
		_clean(path)
		return
	await _frames(2)
	var hero := game.session.character
	hero.controls.set_source(null)
	var identity := game.session.campaign.hero.id
	var quest := DEFINITION.quests[0]
	check(game.regions.current_id == DEFINITION.refuge_region and _monsters(game.world).is_empty(), "new heroes begin safely at the refuge")
	check(game.progress.advance(quest) and game.progress.accepted(quest), "a request is explicitly accepted and persisted at the refuge")
	hero.gain_xp(hero.xp_to_next_level())
	check(game.progress.points() == 1, "each level gives a permanent unspent talent point without random cards")
	var talent := DEFINITION.talents[0]
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".lock"))
	check(not game.progress.learn(talent) and game.progress.points() == 1 and hero.perks.stacks_of(talent) == 0,
		"failed publication spends no point and applies no talent")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".lock"))
	check(game.progress.learn(talent) and game.progress.points() == 0 and hero.perks.stacks_of(talent) == 1,
		"a chosen talent and its point expenditure commit together")
	check(not game.progress.learn(talent), "one point cannot buy two talent stacks")
	check(game.regions.travel("to_path"), "the refuge opens onto the persistent passage")
	await _frames(2)
	_freeze(game.world)
	game.world.fog.reveal_rect(Rect2i(20, 15, 1, 1))
	var common := _monsters(game.world)[0]
	common.hp = 0
	common.die(hero)
	await _frames(3)
	check(not game.rest(), "rest cannot remotely reset a combat place")
	check(game.regions.travel("to_cave"), "the first dungeon is reached by its explicit passage")
	await _frames(2)
	_freeze(game.world)
	var guardian: Monster
	for enemy in _monsters(game.world):
		if enemy.def.id == &"big_slime":
			guardian = enemy
	check(guardian != null, "the objective guardian exists in the authored dungeon")
	if guardian:
		guardian.hp = 0
		guardian.die(hero)
	await _frames(4)
	check(game.regions.travel("to_path"), "leaving captures a unique guardian's death and offspring")
	await _frames(2)
	_freeze(game.world)
	check(game.world.fog.is_explored(Vector2i(20, 15)), "discovered map cells survive A/B/A region travel")
	check(game.regions.travel("to_refuge"), "the refuge stays reachable after completing a dungeon objective")
	await _frames(2)
	check(quest.completed(game.session.campaign), "objective completion comes from durable world state")
	var gold_before := hero.gold
	check(game.progress.advance(quest) and game.progress.paid(quest) and hero.gold == gold_before + quest.reward_gold,
		"turning in publishes the personal reward claim and exact payment together")
	check(not game.progress.advance(quest) and hero.gold == gold_before + quest.reward_gold, "repeated turn-in cannot pay twice")
	hero.hp = maxi(1, hero.hp - 5)
	var retained_gold := hero.gold
	var retained_level := hero.level
	var supply := DEFINITION.supplies[0]
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".lock"))
	check(not game.progress.purchase(supply) and hero.gold == retained_gold and not game.progress.purchased(supply),
		"a failed supply purchase spends no gold and creates no stock claim")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".lock"))
	check(game.progress.purchase(supply) and hero.gold == retained_gold - supply.price and game.progress.purchased(supply),
		"a supply's inventory transfer, price and finite-stock claim publish together")
	check(not game.progress.purchase(supply), "repeating a purchase cannot duplicate a claimed supply")
	retained_gold = hero.gold
	var wounded := hero.hp
	var old_floor := game.world.floor_id
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".lock"))
	check(not game.rest() and hero.hp == wounded and game.world.floor_id == old_floor,
		"a refused rest does not heal or rebuild the refuge before publication")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".lock"))
	check(game.rest() and hero.hp == hero.get_max_hp(), "an explicit refuge rest restores Health")
	var path_state := game.session.campaign.world_state.regions["campaign:path"]
	var alive := true
	for record in path_state.monsters.values():
		alive = alive and not record.dead
	check(alive, "rest renews defeated common authored enemies in inactive places")
	check(quest.completed(game.session.campaign) and game.progress.paid(quest), "rest never renews unique guardians or quest rewards")
	check(game.regions.travel("to_path"), "combat resumes after explicit renewal")
	await _frames(2)
	_freeze(game.world)
	hero.add_gold(7)
	var data_before := hero.save_state()
	hero.hp = 0
	hero.die(null)
	await _frames(6)
	var returned := game.session.character
	check(returned != hero and not returned.is_dead and returned.hp == returned.get_max_hp()
		and game.regions.current_id == DEFINITION.refuge_region, "death creates a living hero at the safe refuge without restarting the campaign")
	check(game.session.campaign.hero.id == identity and returned.gold == retained_gold + 7 and returned.level == retained_level,
		"death retains the current character identity, level and gold earned since the last checkpoint")
	check(returned.perks.stacks_of(talent) == 1 and game.progress.points() == returned.level - retained_level,
		"death retains selected talents and unspent points")
	var after := returned.save_state()
	for key: String in ["inventory", "belt", "equipment", "xp"]:
		check(JSON.parse_string(JSON.stringify(after[key])) == JSON.parse_string(JSON.stringify(data_before[key])), "death preserves the actual current inventory, equipment, belt and XP")
	check(game.save(), "the recovered campaign is independently saveable")
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".lock"))
	returned.add_gold(3)
	var retry_gold := returned.gold
	returned.hp = 0
	returned.die(null)
	await _frames(4)
	check(game.session.character == returned and returned.is_dead and returned.gold == retry_gold,
		"failed recovery keeps the actual dead hero and unsaved wealth in memory for retry")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".lock"))
	check(game.recover() and game.session.character.gold == retry_gold, "retry recovers the current progress without loading an older checkpoint")
	check(game.progress.purchased(supply), "rest and death never refill the finite supply stock")
	_test_v3(game, path + ".v3")
	game.free()
	await _frames(2)
	game = RUNTIME.instantiate() as CampaignRuntime
	add_child(game)
	check(game.begin(path, true), "a new runtime resumes the campaign from disk")
	check(game.session.campaign.hero.id == identity and game.progress.paid(quest)
		and game.session.character.perks.stacks_of(talent) == 1, "disk restart retains identity, quest payouts and permanent talents")
	var refused := RUNTIME.instantiate() as CampaignRuntime
	add_child(refused)
	check(not refused.begin(path, false), "Begin never overwrites an existing campaign")
	refused.free()
	game.free()
	await _frames(2)
	await _shell(path)
	_clean(path)


func _test_v3(game: CampaignRuntime, path: String) -> void:
	var data := game.session.campaign.to_data()
	for region: Dictionary in data.world.regions.values():
		region.erase("explored")
	var payload := JSON.stringify(data)
	SafeFile.write_json(path, { "format": CampaignSave.FORMAT, "version": 3, "payload": payload, "sha256": payload.sha256_text() })
	var before := FileAccess.get_file_as_bytes(path)
	var store := CampaignSave.new(path)
	var loaded := store.load_state()
	check(loaded != null and loaded.hero.id == game.session.campaign.hero.id
		and loaded.world_state.regions["campaign:path"].monsters.size() == game.session.campaign.world_state.regions["campaign:path"].monsters.size(),
		"v3 migration preserves hero and populated world while adding empty exploration")
	check(FileAccess.get_file_as_bytes(path) == before, "reading the v3 campaign never rewrites its source file")
	_clean(path)


func _shell(path: String) -> void:
	var shell := SCREEN.instantiate() as CampaignScreen
	shell.checkpoint_path = path
	add_child(shell)
	await _frames(2)
	check(shell.panel.visible and shell.runtime == null and get_tree().paused, "the public launcher waits for an explicit campaign choice")
	shell.begin_campaign(true)
	await _frames(3)
	check(shell.runtime != null and shell.runtime.started and shell.hud.visible and not get_tree().paused,
		"the actual default screen can resume into the playable RPG with the full combat HUD")
	shell.options.open()
	await _frames(1)
	check(not (shell.options.get_node("%ReplayTutorialButton") as Control).is_visible_in_tree()
		and not (shell.options.get_node("%RunTimerCheck") as Control).is_visible_in_tree(),
		"campaign options hide obsolete run and tutorial controls, including their whole rows")
	shell.options.close()
	check(_off_grid_texts(shell).is_empty(), "the campaign UI keeps whole pixel-grid font sizes")
	shell.free()
	get_tree().paused = false
	await _frames(2)


func _freeze(world: World) -> void:
	for monster in _monsters(world):
		monster.set_physics_process(false)


func _monsters(world: World) -> Array[Monster]:
	var result: Array[Monster] = []
	for node in get_tree().get_nodes_in_group("monsters"):
		if world.is_ancestor_of(node) and not (node as Monster).is_dead:
			result.append(node as Monster)
	return result


func _clean(path: String) -> void:
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".lock"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
