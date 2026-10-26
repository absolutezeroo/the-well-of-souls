extends Node
## Reproducible desktop render review in an isolated user folder. Never opens real saves.
## Run with -- --locale=fr (or en); writes its captures under user://village_review/.

const HUB := preload("res://src/village/village_hub.tscn")


func _ready() -> void:
	Profile.save_path = ""
	Profile.reset()
	Privacy.ask_on_title = false
	var language := "fr"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--locale="):
			language = argument.trim_prefix("--locale=")
	TranslationServer.set_locale(language)
	InputDevice.use(InputDevice.Kind.KEYBOARD)
	DirAccess.make_dir_recursive_absolute("user://village_review")
	language += "_%d" % get_tree().root.size.x
	var hub := HUB.instantiate() as VillageHub
	add_child(hub)
	for i in 6:
		await get_tree().process_frame
	hub.walker.position = Vector2(480, 325)
	await _capture("square_" + language)
	hub.walker.position = hub.view.actor_for(hub.def.residents[0]).position + Vector2(0, 25)
	for i in 3:
		await get_tree().physics_frame
	hub.interact()
	await _capture("quest_" + language)
	hub.panel.picked.emit(&"accept", hub.def.quests[0])
	hub.panel.hide()
	VillageProgress.discover(hub.def.quests[0])
	VillageProgress.hand_in(hub.def.quests[0])
	VillageProgress.buy(hub.def.services[0])
	VillageProgress.buy(hub.def.services[1])
	var snapshot := {"version": 1, "date": 1793000000, "level": 18,
		"gear": [{"id": "bow", "rarity": 0, "level": 1}], "skills": [], "perks": []}
	Profile.take_keeper(snapshot)
	hub.walker.position = Vector2(650, 385)
	await _capture("restored_" + language)
	hub.walker.position = hub.def.memorial + Vector2(0, 25)
	for i in 3:
		await get_tree().physics_frame
	hub.interact()
	await _capture("memorial_" + language)
	hub.panel.hide()
	hub.walker.position = hub.view.actor_for(hub.def.residents[1]).position + Vector2(0, 25)
	for i in 3:
		await get_tree().physics_frame
	hub.interact()
	await _capture("sayo_quest_" + language)
	hub.panel.picked.emit(&"topic", hub.def.residents[1].topics[0])
	await _capture("sayo_question_" + language)
	hub.panel.picked.emit(&"accept", hub.def.quests[1])
	VillageProgress.discover(hub.def.quests[1])
	hub.panel.picked.emit(&"hand_in", hub.def.quests[1])
	await _capture("sayo_awake_" + language)
	hub.panel.hide()
	await _capture("west_restored_" + language)
	hub.open_journal()
	await _capture("journal_" + language)
	hub.journal.hide()
	Profile.village_seconds = hub.def.clock.day_seconds * 14.0 / 24.0
	hub.refresh_time()
	hub.walker.position = Vector2(480, 420)
	await _capture("night_" + language)
	get_tree().quit()


func _capture(file_name: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://village_review/%s.png" % file_name)
	print("Village review: ", ProjectSettings.globalize_path("user://village_review/%s.png" % file_name))
