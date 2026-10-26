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
	_test_sequence()
	_test_conversations()
	_test_calendar()
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


func _test_sequence() -> void:
	Profile.reset()
	var first := VILLAGE.quests[0]
	var second := VILLAGE.quests[1]
	var before := Profile.to_data().duplicate(true)
	check(not VillageProgress.can_accept(second) and not VillageProgress.accept(second) and Profile.to_data() == before, "a prerequisite cannot be bypassed by calling accept outside the panel")
	VillageProgress.accept(first)
	VillageProgress.discover(first)
	check(not VillageProgress.accept(second), "finding the prerequisite evidence alone does not unlock its follow-up")
	VillageProgress.hand_in(first)
	var old_profile := JSON.parse_string(JSON.stringify(Profile.to_data())) as Dictionary
	Profile.reset()
	check(Profile.from_data(old_profile) and VillageProgress.can_accept(second) and VillageProgress.stage(second) == VillageProgress.Step.AVAILABLE, "an existing completed first quest unlocks the new quest without auto-accepting it")
	Profile.held = true
	check(not VillageProgress.accept(second), "a cloud conflict cannot accept the next quest")
	Profile.held = false
	var path := Profile.save_path
	before = Profile.to_data().duplicate(true)
	Profile.save_path = "user://missing_village_directory/profile.json"
	check(not VillageProgress.accept(second) and Profile.to_data() == before, "failed acceptance preserves the completed predecessor and the available follow-up")
	Profile.save_path = path
	check(VillageProgress.accept(second) and not VillageProgress.accept(second), "the unlocked follow-up still requires one explicit acceptance")
	VillageProgress.discover(second)
	before = Profile.to_data().duplicate(true)
	Profile.save_path = "user://missing_village_directory/profile.json"
	check(not VillageProgress.hand_in(second) and Profile.to_data() == before, "failed hand-in leaves the second rescue and its reward uncommitted")
	Profile.save_path = path
	var souls := Profile.souls
	check(VillageProgress.hand_in(second) and Profile.souls == souls + second.reward_souls and not VillageProgress.hand_in(second), "the second rescue pays exactly once")
	old_profile = JSON.parse_string(JSON.stringify(Profile.to_data())) as Dictionary
	Profile.reset()
	check(Profile.from_data(old_profile) and VillageProgress.stage(first) == VillageProgress.Step.RETURNED and VillageProgress.stage(second) == VillageProgress.Step.RETURNED, "both independent infestation fronts stay cleared after a profile reload")
	var ids: Array[StringName] = []
	for quest in VILLAGE.quests:
		check(not quest.id.is_empty() and not ids.has(quest.id), "village quests have unique stable ids")
		ids.append(quest.id)
		var seen: Array[VillageQuestDef] = [quest]
		var prior := quest.requires_quest
		var valid := true
		while prior:
			if seen.has(prior) or not VILLAGE.quests.has(prior):
				valid = false
				break
			seen.append(prior)
			prior = prior.requires_quest
		check(valid, "quest prerequisites are registered and have no cycles")
	Profile.reset()


func _test_conversations() -> void:
	Profile.reset()
	var resident := VILLAGE.residents[0]
	check(VillageProgress.greeting(resident) == resident.text, "the keeper begins with her request rather than a completed-rescue line")
	VillageProgress.accept(resident.quest)
	check(VillageProgress.greeting(resident) == resident.accepted_text, "an accepted request gets its own reminder and concern")
	VillageProgress.discover(resident.quest)
	check(VillageProgress.greeting(resident) == resident.found_text, "a recovered object is recognised before being handed in")
	VillageProgress.hand_in(resident.quest)
	check(VillageProgress.greeting(resident) == resident.used_text, "the keeper reacts to the actual return")
	var sayo := VILLAGE.residents[1]
	var after_topic := sayo.topics.back() as VillageTopicDef
	check(not VillageProgress.topic_available(after_topic), "Sayo cannot discuss her plans as an awakened resident before her rescue")
	VillageProgress.accept(sayo.quest)
	VillageProgress.discover(sayo.quest)
	VillageProgress.hand_in(sayo.quest)
	check(VillageProgress.topic_available(after_topic) and not VillageProgress.topic_available(sayo.topics[0]), "waking Sayo opens her plans and retires the forgotten-verse question")
	check(VillageProgress.greeting(resident) == resident.reactions[0].reply, "the keeper reacts to both rescued neighbours rather than sending the player to an already completed rescue")
	var language := TranslationServer.get_locale()
	TranslationServer.set_locale("fr")
	for person in VILLAGE.residents:
		for reaction in person.reactions:
			check(not reaction.reply.is_empty() and reaction.min_stage <= reaction.max_stage, "a reactive greeting has a reply and ordered visibility interval")
		for subject in person.topics:
			check(not subject.prompt.is_empty() and not subject.reply.is_empty() and subject.min_stage <= subject.max_stage, "a conversation topic has a real question, reply and ordered visibility interval")
		for bark in person.ambient_before + person.ambient_after:
			check(bark.length() <= 120 and tr(bark) != bark, "a proximity line is short and translated into French")
	TranslationServer.set_locale(language)
	Profile.reset()


func _test_calendar() -> void:
	Profile.reset()
	check(is_equal_approx(VillageClock.hour(VILLAGE.clock), 8.0) and VillageClock.day(VILLAGE.clock) == 1, "an old profile starts on Kagari's first morning")
	var daily := QuestBoard.current(CONTENT.quests, QuestDef.Period.DAILY, 1700000000)
	VillageClock.advance(VILLAGE.clock.day_seconds)
	check(is_equal_approx(VillageClock.hour(VILLAGE.clock), 8.0) and VillageClock.day(VILLAGE.clock) == 2, "one authored day rolls the clock and increments the day")
	check(QuestBoard.current(CONTENT.quests, QuestDef.Period.DAILY, 1700000000) == daily, "fictional days never reroll real daily bounties")
	var saved := JSON.parse_string(JSON.stringify(Profile.to_data())) as Dictionary
	Profile.reset()
	check(Profile.from_data(saved) and VillageClock.day(VILLAGE.clock) == 2, "village time survives the existing profile round trip")
	Profile.held = true
	var before := Profile.village_seconds
	VillageClock.advance(40.0)
	check(Profile.village_seconds == before, "a held cloud profile cannot advance village time")
	Profile.held = false
	VillageClock.advance(-1.0)
	check(Profile.village_seconds == before, "negative time cannot rewind a day")
	saved.village_seconds = -1
	check(not ProfileScript.is_valid_data(saved), "negative saved village time is rejected before profile replacement")
	for restored in [false, true]:
		Profile.reset()
		if restored:
			for quest in VILLAGE.quests:
				VillageProgress.accept(quest)
				VillageProgress.discover(quest)
				VillageProgress.hand_in(quest)
		var navigation := VillageNavigation.new()
		navigation.rebuild(VILLAGE)
		for person in VILLAGE.residents:
			check(not person.schedule.is_empty() and person.schedule[0].start_hour == 0.0, "every resident's schedule covers midnight")
			var previous_hour := -1.0
			var previous_point := person.position
			for appointment in person.schedule:
				check(appointment.start_hour > previous_hour and appointment.start_hour < 24.0, "appointments are strictly ordered within a day")
				check(not navigation.path(previous_point, appointment.destination).is_empty(), "%s %s to %s: each appointment has a walkable route (restored=%s)" % [person.speaker.display_name, previous_point, appointment.destination, restored])
				previous_hour = appointment.start_hour
				previous_point = appointment.destination
			check(person.activity_at(23.99) == person.schedule.back() and person.activity_at(0.0) == person.schedule[0], "schedules choose the correct activity on either side of midnight")
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
	check(hub.spots.size() == 8 and hub.walker != null and not hub.walker.blocked, "Kagari opens with a controllable hero, four places and four residents")
	var sleeper := hub.view.actor_for(VILLAGE.residents[2])
	var sleeper_position := sleeper.position
	await _frames(300)
	check(sleeper.asleep and sleeper.position == sleeper_position, "an unrecovered lantern echo never starts its living patrol")
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
	var menu_time := Profile.village_seconds
	await _frames(5)
	check(Profile.village_seconds == menu_time, "reading a village menu pauses its day/night clock")
	hub.panel.hide()
	hub.walker.position = hub.view.actor_for(VILLAGE.residents[1]).position + Vector2(0, 25)
	await _frames(3)
	hub.interact()
	var locked_choice := _choice(hub, VILLAGE.quests[1].locked_text)
	check(locked_choice != null and locked_choice.disabled, "Sayo explains her prerequisite with a disabled choice before Ren wakes")
	hub.panel.hide()
	hub.walker.position = hub.view.actor_for(VILLAGE.residents[0]).position + Vector2(0, 25)
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
		if prop.cleared_by == VILLAGE.quests[0]: roots += 1
	check(roots > 0 and hub.view.dressing.get_child_count() == VILLAGE.props.size() - roots + VILLAGE.residents.size() + 5, "returning the quest removes its root props and their collisions")
	var first_count := hub.view.dressing.get_child_count()
	hub.panel.hide()
	hub.walker.position = hub.view.actor_for(VILLAGE.residents[1]).position + Vector2(0, 25)
	await _frames(3)
	hub.interact()
	var next_choice := _choice(hub, VILLAGE.quests[1].accept_label)
	check(next_choice != null and not next_choice.disabled, "Ren's return opens Sayo's next quest in the real conversation")
	if next_choice: next_choice.pressed.emit()
	VillageProgress.discover(VILLAGE.quests[1])
	var return_choice := _choice(hub, VILLAGE.quests[1].hand_in_label)
	check(return_choice != null and not return_choice.disabled, "Sayo offers to receive her recovered verse")
	if return_choice: return_choice.pressed.emit()
	var west_roots := 0
	for prop in VILLAGE.props:
		if prop.cleared_by == VILLAGE.quests[1]: west_roots += 1
	check(west_roots > 0 and hub.view.dressing.get_child_count() == first_count - west_roots, "the second hand-in removes only the remaining western roots and collisions")
	check(VILLAGE.residents[1].wakes_after == VILLAGE.quests[1] and hub.panel.words.text == tr(VILLAGE.residents[1].used_text), "Sayo's waking condition and conversation follow her own completed quest")
	var subject := VILLAGE.residents[1].topics.back() as VillageTopicDef
	var question := _choice(hub, subject.prompt)
	check(question != null, "an awakened resident offers a follow-up question")
	var conversation_save := Profile.to_data().duplicate(true)
	if question: question.pressed.emit()
	check(hub.panel.words.text == tr(subject.reply) and Profile.to_data() == conversation_save, "asking a question shows its reply without paying a reward or changing progression")
	hub.panel.hide()
	hub.walker.position = Vector2(480, 550)
	var ren := hub.view.actor_for(VILLAGE.residents[2])
	var start := ren.position
	await _frames(300)
	check(not ren.asleep and ren.position.distance_to(start) > 5.0, "a rescued lantern-mender leaves his door to tend his route")
	hub.walker.position = ren.position + Vector2(0, 25)
	await _frames(3)
	check(ren.bubble.visible and not hub.panel.visible, "approaching a resident can show a short line without opening a modal")
	check(hub.focus != null and hub.focus.resident == ren.def and hub.interact(), "the interaction target follows the moving resident")
	start = ren.position
	await _frames(20)
	check(ren.position == start and not ren.bubble.visible, "a conversation stops the routine and hides overlapping ambient speech")
	check(VillageProgress.buy(VILLAGE.services[0]) and hub.view.actor_for(ren.def) == ren and ren.position == start, "buying a lamp refreshes the village without replacing or teleporting its people")
	hub.panel.hide()
	hub.open_journal()
	var journal_profile := Profile.to_data().duplicate(true)
	await _frames(3)
	check(hub.journal.visible and hub.walker.blocked and Profile.to_data() == journal_profile, "the journal is directly accessible and reading it neither accepts nor rewards quests")
	hub.journal.hide()
	# The clock changes the appointment, not the resident's position. Travel remains physical.
	start = ren.position
	Profile.village_seconds = VILLAGE.clock.day_seconds * (20.0 - VILLAGE.clock.start_hour) / 24.0
	hub.refresh_time()
	check(ren.activity.indoors and ren.position == start, "evening assigns home rest without teleporting a travelling resident")
	check(hub.view.daylight.color != Color.WHITE, "the village's world tint follows the time of day")

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
	# A scene loaded at night derives its offscreen routine from the saved clock.
	var night := HUB.instantiate() as VillageHub
	add_child(night)
	await _frames(2)
	check(night.view.actor_for(VILLAGE.residents[2]).indoors and not night.view.actor_for(VILLAGE.residents[2]).visible, "a loaded nighttime village places Ren behind his home doorway")
	# Exercise real physics along a whole restored day, including the long market/home trips.
	# Hold the clock only, so the authored appointments cannot change during each journey.
	night.set_physics_process(false)
	for hour: float in [0.0, 6.0, 8.0, 9.0, 12.0, 14.0, 16.0, 18.0, 20.0, 22.0]:
		for person in VILLAGE.residents:
			var actor := night.view.actor_for(person)
			actor.paused = false
			actor.apply_hour(hour)
		await _frames(1200)
		for person in VILLAGE.residents:
			var actor := night.view.actor_for(person)
			check(actor.position.distance_to(actor.activity.destination) <= 3.0, "%s reaches the %.0f h appointment through real collisions" % [person.speaker.display_name, hour])
			check(actor.indoors == actor.activity.indoors, "arriving at a doorway applies that appointment's indoor state")
	var older := Profile.to_data().duplicate(true)
	older.village_quests = {}
	var returning_echo := night.view.actor_for(VILLAGE.residents[2])
	returning_echo.position = Vector2(285, 465)
	check(Profile.from_data(older) and returning_echo.asleep and returning_echo.position == returning_echo.def.position, "loading an older profile returns a travelling resident's echo to its original doorway")
	night.queue_free()
	await _frames(2)
	RunSave.erase()
	Profile.reset()


func run_game(game: Game) -> void:
	game.open_pause_menu()
	var paused_time := Profile.village_seconds
	await _frames(5)
	check(Profile.village_seconds == paused_time, "the dungeon pause freezes village time despite Game processing while paused")
	game.menus.pause.back()
	await _frames(5)
	check(Profile.village_seconds > paused_time, "active dungeon play advances the shared village clock")
	var quest := VILLAGE.quests[0]
	var second := VILLAGE.quests[1]
	await game.debug.enter_floor(second.floor_depth)
	check(game.world.find_children("*", "VillageEvidence", true, false).is_empty(), "the locked second quest adds no evidence to the dungeon")
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
	game.run.daily_day = -1
	VillageProgress.discover(quest)
	VillageProgress.hand_in(quest)
	VillageProgress.accept(second)
	await game.debug.enter_floor(second.floor_depth)
	await _frames(2)
	found = game.world.find_children("*", "VillageEvidence", true, false)
	check(found.size() == 1 and (found[0] as VillageEvidence).quest == second, "the accepted second quest places its own evidence on its authored floor")
	if found.is_empty(): return
	evidence = found[0] as VillageEvidence
	check(game.world.is_solid_ground(evidence.position), "the last verse is reachable on solid ground")
	evidence.spot.use(game.player)
	await _frames(2)
	check(VillageProgress.stage(second) == VillageProgress.Step.FOUND and VillageProgress.stage(quest) == VillageProgress.Step.RETURNED, "recovering the verse preserves the first rescue")
	await game.debug.enter_floor(second.floor_depth)
	check(game.world.find_children("*", "VillageEvidence", true, false).is_empty(), "the recovered verse does not duplicate on floor reconstruction")


func _choice(hub: VillageHub, key: String) -> Button:
	for node in hub.panel.list.get_children():
		if node is Button and (node as Button).text == tr(key):
			return node as Button
	return null
