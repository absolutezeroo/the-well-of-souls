class_name VillageTests
extends TestSuite
## Surface progression, real dungeon evidence, save failure, input and permanent memorials.

const VILLAGE := preload("res://data/village/kagari.tres")
const HUB := preload("res://src/village/village_hub.tscn")
const ProfileScript := preload("res://src/autoload/profile.gd")


func run_unit() -> void:
	var quest := VILLAGE.quests[0]
	var service := VILLAGE.services[0]
	Profile.reset()
	check(not VillageProgress.discover(quest) and not VillageProgress.hand_in(quest), "evidence and reward need the accepted quest in order")
	check(VillageProgress.accept(quest) and not VillageProgress.accept(quest), "a village quest is accepted once")
	Profile.souls = 100
	check(not VillageProgress.buy(service), "restoration stays locked before the resident wakes")
	var before := Profile.to_data().duplicate(true)
	var path := Profile.save_path
	Profile.save_path = "user://missing_village_directory/profile.json"
	check(not VillageProgress.discover(quest) and Profile.to_data() == before, "failed evidence save leaves all profile fields unchanged")
	Profile.save_path = path
	check(VillageProgress.discover(quest) and not VillageProgress.discover(quest), "evidence is collected once")
	var saved := JSON.parse_string(JSON.stringify(Profile.to_data())) as Dictionary
	Profile.reset()
	check(Profile.from_data(saved) and VillageProgress.stage(quest) == VillageProgress.Step.FOUND, "lantern evidence survives restart and a run ending")
	var souls := Profile.souls
	check(VillageProgress.hand_in(quest) and Profile.souls == souls + quest.reward_souls, "returning to the keeper pays souls and wakes the resident together")
	check(not VillageProgress.hand_in(quest), "returning the evidence again cannot pay twice")
	before = Profile.to_data().duplicate(true)
	Profile.save_path = "user://missing_village_directory/profile.json"
	check(not VillageProgress.buy(service) and Profile.to_data() == before, "failed purchase neither spends souls nor restores a lamp")
	Profile.save_path = path
	souls = Profile.souls
	check(VillageProgress.buy(service) and Profile.souls == souls - service.cost and VillageProgress.restored(service), "one transaction buys the permanent restoration")
	check(not VillageProgress.buy(service), "a restored lamp cannot be sold twice")
	_test_memorials()
	var rng := RandomNumberGenerator.new()
	rng.seed = 79
	var first := RunState.create(CONTENT, {}, rng, DailyRun.today())
	rng.seed = 79
	var second := RunState.create(CONTENT, {}, rng, DailyRun.today())
	check(first.run_seed == second.run_seed and first.journey_id != second.journey_id, "identical daily seeds still have distinct memorial receipt identities")
	var resumed := RunState.create(CONTENT, JSON.parse_string(JSON.stringify(first.to_data())), rng)
	check(resumed.journey_id == first.journey_id, "the receipt identity survives a JSON run save and resume")
	Profile.reset()


func _test_memorials() -> void:
	var take: EndingDef
	var release: EndingDef
	for ending in CONTENT.dungeon.finale.endings:
		if ending.keeper_change == EndingDef.KeeperChange.TAKE: take = ending
		if ending.keeper_change == EndingDef.KeeperChange.FREE: release = ending
	var snapshot := {"version": 1, "level": 12, "date": 1000, "gear": [{"id": "bow", "rarity": 0, "level": 1}], "skills": [], "perks": []}
	check(Profile.finish_ending(take, snapshot, "test/journey/1", true), "taking the keeper's place records a memorial")
	check(Profile.village_memorials.size() == 1 and Profile.village_memorials[0].gear == snapshot.gear, "the memorial keeps the hero's equipment")
	var before := Profile.to_data().duplicate(true)
	check(Profile.finish_ending(take, snapshot, "test/journey/1", true) and Profile.to_data() == before, "replaying the same saved ending duplicates neither statue nor ending stats")
	check(not Profile.finish_ending(release, snapshot, "test/journey/1", true), "a committed ending cannot become a different choice after a crash")
	check(Profile.finish_ending(release, {}, "test/journey/2", true) and Profile.keeper.is_empty() and Profile.village_memorials.size() == 1, "ringing the bell leaves the earlier memorial intact")
	for i in 23:
		Profile.finish_ending(take, snapshot, "test/other/%d" % i, true)
	check(Profile.village_memorials.size() == 24, "memorials are not truncated by the 20-entry run/codex history limit")
	var data := JSON.parse_string(JSON.stringify(Profile.to_data())) as Dictionary
	Profile.reset()
	check(Profile.from_data(data) and Profile.village_memorials.size() == 24, "every memorial survives a profile round trip")
	before = Profile.to_data().duplicate(true)
	var path := Profile.save_path
	Profile.save_path = "user://missing_village_directory/profile.json"
	check(not Profile.finish_ending(take, snapshot, "test/failure", true) and Profile.to_data() == before, "a refused ending write rolls back keeper, statue, receipt and statistics")
	Profile.save_path = path
	data = {"souls": 1, "runs": 1, "keeper": snapshot}
	check(Profile.from_data(data) and Profile.village_memorials.size() == 1, "an older profile brings its current keeper into the village register")
	data = Profile.to_data().duplicate(true)
	data.village_quests = {"ren_ember_box": []}
	check(not ProfileScript.is_valid_data(data), "malformed village progress is rejected before replacing the profile")
	data.village_quests = {"ren_ember_box": 2.5}
	check(not ProfileScript.is_valid_data(data), "fractional quest stages cannot silently become completed objectives")
	data = Profile.to_data().duplicate(true)
	data.village_memorials[0].gear = [{"id": []}]
	check(not ProfileScript.is_valid_data(data), "malformed memorial gear cannot replace a valid profile")


func run_title() -> void:
	Profile.reset()
	var hub := HUB.instantiate() as VillageHub
	add_child(hub)
	await _frames(3)
	check(hub.spots.size() == 7 and hub.walker != null and not hub.walker.blocked, "Kagari opens with a controllable hero, three places and four residents")
	var from := hub.walker.position
	Input.action_press(&"move_right")
	await _frames(8)
	Input.action_release(&"move_right")
	check(hub.walker.position.x > from.x, "the village uses normal movement actions")
	hub.open_well()
	await _frames(2)
	from = hub.walker.position
	Input.action_press(&"move_right")
	await _frames(8)
	Input.action_release(&"move_right")
	check(hub.walker.position == from and hub.walker.blocked, "a village panel stops movement")
	hub.panel.hide()
	hub.walker.position = VILLAGE.residents[0].position + Vector2(0, 25)
	await _frames(3)
	check(hub.interact() and hub.panel.visible, "standing near a resident offers an explicit conversation")
	hub.panel.picked.emit(&"accept", VILLAGE.quests[0])
	check(VillageProgress.stage(VILLAGE.quests[0]) == VillageProgress.Step.ACCEPTED, "the conversation accepts its data-defined quest through gameplay")
	hub.panel.hide()
	VillageProgress.discover(VILLAGE.quests[0])
	hub.interact()
	hub.panel.picked.emit(&"hand_in", VILLAGE.quests[0])
	check(VillageProgress.stage(VILLAGE.quests[0]) == VillageProgress.Step.RETURNED, "the same NPC can receive the evidence and wake a house")
	var roots := 0
	for prop in VILLAGE.props:
		if prop.cleared_by: roots += 1
	check(roots > 0 and hub.view.dressing.get_child_count() == VILLAGE.props.size() - roots + VILLAGE.residents.size() + 4, "returning the quest removes its root props and their collisions")
	hub.panel.hide()
	await _frames(2)
	var file := FileAccess.open(RunSave.path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": RunSave.VERSION, "depth": 2, "player": {"level": 2}}))
	file.close()
	var kept := FileAccess.get_file_as_string(RunSave.path)
	hub.open_well()
	hub.panel.picked.emit(&"normal", null)
	hub.difficulty_panel.choose(CONTENT.difficulties[0])
	check(hub.panel.visible and FileAccess.get_file_as_string(RunSave.path) == kept, "a new descent asks before replacing the existing save")
	hub.queue_free()
	await _frames(2)
	check(FileAccess.get_file_as_string(RunSave.path) == kept, "leaving the village during confirmation keeps the saved descent")
	RunSave.erase()
	Profile.reset()


func run_game(game: Game) -> void:
	var quest := VILLAGE.quests[0]
	VillageProgress.accept(quest)
	await game.debug.enter_floor(quest.floor_depth)
	await _frames(3)
	var found := game.world.find_children("*", "VillageEvidence", true, false)
	check(found.size() == 1, "the accepted village evidence is placed in a real floor-two room")
	if found.is_empty(): return
	var evidence := found[0] as VillageEvidence
	check(game.world.is_solid_ground(evidence.position), "quest evidence is on walkable ground")
	evidence.spot.use(game.player)
	await _frames(2)
	check(VillageProgress.stage(quest) == VillageProgress.Step.FOUND, "interacting in the dungeon saves the evidence in the profile")
	await game.debug.enter_floor(quest.floor_depth)
	await _frames(2)
	check(game.world.find_children("*", "VillageEvidence", true, false).is_empty(), "a collected quest object does not return on floor reconstruction")
	# Do not disturb the native map generation or add anything to the daily race.
	Profile.village_quests[String(quest.id)] = VillageProgress.Step.ACCEPTED
	game.run.daily_day = DailyRun.today()
	await game.debug.enter_floor(quest.floor_depth)
	check(game.world.find_children("*", "VillageEvidence", true, false).is_empty(), "daily descents never contain village quest objects")
