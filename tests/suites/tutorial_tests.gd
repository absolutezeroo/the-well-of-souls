class_name TutorialTests
extends TestSuite
## The tutorial (TutorialDef, Tutorial, HintBox): its data, the first steps of a first run played
## with the real controls, the contextual hints, menus, options and the profile.


func run() -> void:
	_test_data()
	_test_profile()
	await _test_options()
	Settings.tutorial_hints = true
	Profile.reset_hints()
	# No chest, merchant or forge hint popping up in the middle of the first steps.
	var near := CONTENT.tutorial.near_distance
	CONTENT.tutorial.near_distance = -1.0
	# Nor an ambush, a strange or cursed floor (their hints would cut in).
	var ambush_chance := CONTENT.dungeon.ambush_chance
	var event_chance := CONTENT.dungeon.floor_event_chance
	var pact_chance := CONTENT.dungeon.pact_chance
	var trial_chance := CONTENT.dungeon.trial_chance
	CONTENT.dungeon.ambush_chance = 0.0
	CONTENT.dungeon.floor_event_chance = 0.0
	CONTENT.dungeon.pact_chance = 0.0
	CONTENT.dungeon.trial_chance = 0.0
	var curse_chances := {}
	for difficulty in CONTENT.difficulties:
		curse_chances[difficulty] = difficulty.curse_chance
		difficulty.curse_chance = 0.0
	var game := GAME_SCENE.instantiate() as Game
	game.show_act_cards = false
	add_child(game)
	# The floor's monsters go before they ever look around: one spotting the hero in the first
	# frames would put its "attack" hint in line ahead of the first steps (which bring their own
	# monster when they want one).
	for monster in game.world.get_hostiles(Actor.Faction.PLAYER):
		monster.process_mode = Node.PROCESS_MODE_DISABLED
		monster.queue_free()
	await _frames(5)
	_test_targets(game)
	await _test_first_steps(game)
	await _test_hints(game)
	await _test_menus_and_off(game)
	_set_move(Vector2.ZERO)
	game.queue_free()
	await _frames(10)
	Settings.tutorial_hints = false
	Profile.reset_hints()
	CONTENT.tutorial.near_distance = near
	CONTENT.dungeon.ambush_chance = ambush_chance
	CONTENT.dungeon.floor_event_chance = event_chance
	CONTENT.dungeon.pact_chance = pact_chance
	CONTENT.dungeon.trial_chance = trial_chance
	for difficulty in curse_chances:
		difficulty.curse_chance = curse_chances[difficulty]


func _test_data() -> void:
	var tutorial := CONTENT.tutorial
	check(tutorial != null and tutorial.hints.size() >= 15, "the tutorial has its hints")
	var ids := {}
	for hint in tutorial.hints:
		check(not ids.has(hint.id), "hint id %s is unique" % hint.id)
		ids[hint.id] = true
		check(not hint.title.is_empty() and hint.text.length() > 20, "%s has a title and a text" % hint.id)
		check(hint.cue == &"" or Tutorial.CUES.has(hint.cue), "%s: known cue %s" % [hint.id, hint.cue])
		check(hint.cue != &"" or hint.after != &"", "%s: shown by a cue or after another hint" % hint.id)
		check(hint.done_when == &"" or Tutorial.ACTIONS.has(hint.done_when), "%s: known action %s" % [hint.id, hint.done_when])
		check(hint.only_if == &"" or Tutorial.CONDITIONS.has(hint.only_if), "%s: known condition %s" % [hint.id, hint.only_if])
		check(hint.duration > 0.0 or hint.done_when != &"", "%s goes away on its own or once done" % hint.id)
		check(hint.text.length() <= 120, "%s is short enough for two lines (%d)" % [hint.id, hint.text.length()])
	for hint in tutorial.hints:
		check(hint.after == &"" or ids.has(hint.after), "%s comes after a hint that exists (%s)" % [hint.id, hint.after])
	check(tutorial.hint(&"move") != null and tutorial.hint(&"move").cue == &"run_start", "the first step is moving, at the start of a run")
	var pact := tutorial.hint(&"pact")
	check(pact != null and pact.cue == &"pact_near" and pact.duration > 0.0, "a pact door, first seen, gets a short hint")
	var french := TranslationServer.get_translation_object("fr")
	check(pact != null and french != null and String(french.get_message(pact.text)).length() <= 120, "...short in French too")
	check(tutorial.hint(&"nope") == null, "no hint for an unknown id")


func _test_profile() -> void:
	Profile.reset_hints()
	check(not Profile.has_seen_hint(&"move"), "a fresh profile has seen no hint")
	Profile.mark_hint(&"move")
	check(Profile.has_seen_hint(&"move"), "a hint is marked as seen")
	var path := "user://test_profile_%d.json" % OS.get_process_id()
	Profile.save_path = path
	Profile.save_profile()
	Profile.hints_seen = {}
	Profile.load_profile()
	check(Profile.has_seen_hint(&"move"), "seen hints are saved with the profile")
	Profile.save_path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Profile.reset_hints()
	check(Profile.hints_seen.is_empty(), "the tutorial can start over")


func _test_options() -> void:
	var panel := (load("res://src/ui/options/options_panel.tscn") as PackedScene).instantiate() as OptionsPanel
	add_child(panel)
	await _frames(1)
	Settings.tutorial_hints = false
	Profile.mark_hint(&"move")
	panel.open()
	var check_button := panel.get_node("%TutorialCheck") as CheckButton
	check(not check_button.button_pressed, "the options show the hints off")
	(panel.get_node("%ReplayTutorialButton") as Button).pressed.emit()
	check(not Profile.has_seen_hint(&"move") and Settings.tutorial_hints, "Replay tutorial: every hint again, hints on")
	check(check_button.button_pressed, "the check follows")
	check_button.toggled.emit(false)
	check(not Settings.tutorial_hints, "the check turns hints off")
	panel.queue_free()
	await _frames(1)


## Every control a hint points at is on the HUD (when shown).
func _test_targets(game: Game) -> void:
	for hint in CONTENT.tutorial.hints:
		if hint.target == &"" or String(hint.cue).begins_with("menu_"):
			continue  # (title-screen hints point at the title's controls: see the title tests)
		check(game.hud.get_node_or_null("%" + String(hint.target)) != null, "%s points at a HUD control (%s)" % [hint.id, hint.target])
	for node_name in [&"Joystick", &"AttackButton", &"Skill1Button", &"BagButton", &"Minimap", &"SealLabel", &"SoulsLabel"]:
		var rect := game.hud.hint_target(node_name)
		var screen := Rect2(Vector2.ZERO, game.hud.get_viewport().get_visible_rect().size)
		check(rect.has_area() and screen.encloses(rect.grow(-2)), "%s is found on screen (%s)" % [node_name, rect])
	check(not game.hud.hint_target(&"Skill4Button").has_area(), "a hidden button can't be pointed at")
	check(not game.hud.hint_target(&"Nothing").has_area(), "nor a missing one")


## A first run: move, the seal, then attack, roll and the weapon's skills, with the real controls.
func _test_first_steps(game: Game) -> void:
	var tutorial := game.tutorial
	game.player.invincible = true  # no low-health hint from a stray hit or a trap
	await _clear_monsters(game.world)
	check(tutorial.current == null, "no hint over the floor's banner")
	for i in 180:
		if tutorial.current:
			break
		await _frames(1)
	check(tutorial.current != null and tutorial.current.id == &"move", "a first run starts with the move step")
	check(game.hint_box.visible and game.hint_box.shown_text() == tutorial.current.text, "the hint is on screen")
	check(game.hint_box.target.has_area(), "it points at the joystick")
	await _frames(200)
	check(tutorial.current != null and tutorial.current.id == &"move", "it stays until the hero walks")
	var directions := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	for i in 12:
		if tutorial.current == null or tutorial.current.id != &"move":
			break
		_set_move(directions[i % 4])
		await _frames(30)
	_set_move(Vector2.ZERO)
	check(Profile.has_seen_hint(&"move"), "walking ends the move step")
	check(tutorial.current == null and not game.hint_box.visible, "and its hint goes")
	await _frames(int(CONTENT.tutorial.gap * 60) + 10)
	if game.world.seal.is_sealed():
		check(tutorial.current != null and tutorial.current.id == &"seal", "then the sealed stairs (got %s; %s)" % [String(tutorial.current.id) if tutorial.current else "none", _floor_stir(game)])
		check(game.hint_box.target.has_area(), "pointing at the seal's count")
		game.hint_box.dismissed.emit()  # tapped
		check(Profile.has_seen_hint(&"seal") and tutorial.current == null, "a tap closes a hint for good")

	# A monster sees the hero: attack.
	var rat := game.world.spawn_monster(load("res://data/monsters/rat.tres"), game.player.global_position + Vector2(400, 0))
	rat.set_physics_process(false)
	Events.monster_noticed.emit(rat)
	await _frames(int(CONTENT.tutorial.gap * 60) + 10)
	check(tutorial.current != null and tutorial.current.id == &"attack", "a monster in sight: the attack step (got %s)" % (String(tutorial.current.id) if tutorial.current else "none"))
	_set_action(&"attack", true)
	await _frames(10)
	_set_action(&"attack", false)
	check(Profile.has_seen_hint(&"attack"), "attacking ends it")
	await _frames(int(CONTENT.tutorial.gap * 60) + 10)
	check(tutorial.current != null and tutorial.current.id == &"roll", "then the roll")
	await _press(&"skill_1")
	check(Profile.has_seen_hint(&"roll"), "rolling ends it")
	await _frames(int(CONTENT.tutorial.gap * 60) + 30)
	check(tutorial.current != null and tutorial.current.id == &"weapon_skills", "then the weapon's skills")
	await _press(&"skill_2")
	check(Profile.has_seen_hint(&"weapon_skills"), "using one ends it")
	await _frames(int(CONTENT.tutorial.gap * 60) + 30)
	check(tutorial.current != null and tutorial.current.id == &"charge", "then the charged attack (got %s)" % (String(tutorial.current.id) if tutorial.current else "none"))
	check(game.hint_box.target.has_area(), "pointing at the attack button")
	_set_action(&"attack", true)
	await _frames(int((game.player.def.charge_delay + game.player.get_weapon().charged.charge_time) * 60.0) + 10)
	_set_action(&"attack", false)
	await _frames(3)
	check(Profile.has_seen_hint(&"charge"), "unleashing a charged attack ends it")
	rat.queue_free()
	game.player.invincible = false
	await _frames(int(CONTENT.tutorial.gap * 60) + 10)


## Waits for the hint `id`: another hint of this floor may have its say first (a chest, a crack or
## the merchant in reach, a rune picked up on the way, the cold...). Each one up is dismissed in
## turn, for up to `attempts` gaps. Returns the hints that came before it.
func _until_hint(tutorial: Tutorial, id: StringName, gap: int, attempts: int = 6) -> Array[StringName]:
	var before: Array[StringName] = []
	for attempt in attempts:
		await _frames(gap)
		if tutorial.current != null and tutorial.current.id == id:
			break
		before.append(tutorial.current.id if tutorial.current else &"none")
		tutorial.dismiss()
	return before


## Who is about on the floor (for a failed check's message): the monsters, and how long the
## hero has camped by each fire.
func _floor_stir(game: Game) -> String:
	var monsters := game.world.get_hostiles(Actor.Faction.PLAYER).map(func(m: Actor) -> String: return "%s%s %d px" % [m.name, " (summoned)" if (m as Monster).summoned else "", roundi(m.global_position.distance_to(game.player.global_position))])
	var camped: Array[String] = []
	for source in get_tree().get_nodes_in_group("heat_sources"):
		for child in source.get_children():
			if child is CampWatch:
				camped.append("%.1f s (%d waves)" % [(child as CampWatch).camped, (child as CampWatch).waves])
	return "monsters %s, camped %s" % [monsters, camped]


func _press(action: StringName) -> void:
	_set_action(action, true)
	await _frames(2)
	_set_action(action, false)
	await _frames(2)


## Hints that come up the first time something happens, once ever.
func _test_hints(game: Game) -> void:
	var tutorial := game.tutorial
	var player := game.player
	var gap := int(CONTENT.tutorial.gap * 60) + 10
	tutorial.dismiss()
	await _frames(gap)
	tutorial.dismiss()  # (the souls hint, if the rat counted as slain)
	await _frames(gap)

	# Low health, a potion on the belt: drink it.
	check(not player.belt.is_empty(), "the hero starts with potions on the belt")
	player.hp = 1
	await _frames(gap)
	check(tutorial.current != null and tutorial.current.id == &"potion", "low health: the potion hint")
	check(game.hint_box.target.has_area(), "pointing at the belt")
	player.pack.use_belt(0)
	check(Profile.has_seen_hint(&"potion"), "drinking ends it")
	player.hp = player.get_max_hp()
	player.hp = 1
	await _frames(gap)
	check(tutorial.current == null or tutorial.current.id != &"potion", "a hint never comes back")
	player.hp = player.get_max_hp()

	# New gear in the bag: open the bag.
	player.inventory.add(load("res://data/items/armors/iron_helm.tres"))
	await _frames(gap)
	check(tutorial.current != null and tutorial.current.id == &"gear", "gear in the bag: the bag hint")
	game.open_inventory()
	check(Profile.has_seen_hint(&"gear"), "opening the bag ends it")
	game.inventory_panel.close()
	await _frames(gap)

	# An elite.
	var elite := game.world.spawn_monster(load("res://data/monsters/rat.tres"), player.global_position + Vector2(400, 0))
	elite.set_physics_process(false)
	game.world.make_elite(elite)
	Events.monster_noticed.emit(elite)
	await _frames(gap)
	check(tutorial.current != null and tutorial.current.id == &"elite", "an elite: its hint")
	check(not game.hint_box.target.has_area(), "no control to point at")
	await _frames(int(tutorial.current.duration * 60) + 5)
	# Its time over, nobody tapped it: gone, but not seen yet (it comes back on a later floor once:
	# FirstRunTests.run_hints()).
	check(tutorial.current == null and not Profile.has_seen_hint(&"elite"), "it goes on its own, unread: not seen yet")
	Profile.mark_hint(&"elite")  # (its return is not looked at here)
	elite.queue_free()

	# Several at once: one at a time, the most important first. (A level up: its choice waits.)
	player.gain_xp(player.xp_to_next_level())
	tutorial.cue(&"boss_started")
	await _frames(gap)
	check(tutorial.current != null and tutorial.current.id == &"boss", "the boss hint goes first")
	tutorial.dismiss()
	await _frames(gap)
	check(tutorial.current != null and tutorial.current.id == &"perks", "then the next one: a perk waits")
	var offers_button := game.hud.get_node("%OffersButton") as OffersButton
	check(game.hint_box.target.has_area() and game.hint_box.target.has_point(offers_button.get_global_rect().get_center()), "the perks hint points at the perk button")
	check(await _tap_offers(game) and game.perk_panel.visible, "tapping the button opens the choice")
	check(tutorial.current == null and Profile.has_seen_hint(&"perks"), "...and that ends the hint")
	game.perk_panel.choose(0)
	await _frames(2)

	# A cracked wall in sight (a secret room behind it): once, a word about it.
	for seen in [&"chest", &"merchant", &"forge", &"encounter"]:
		Profile.mark_hint(seen)  # (only the crack's hint is looked at here)
	# In sight for sure: the hero stands where nothing (a wall, a prop) stands between him and the
	# crack 90 px up the screen (seen from where he was, one was there now and then).
	await _stand_still(game.world, player)
	var spots: Array[Vector2] = [player.global_position]
	spots.append_array(_free_points_away(game.world, player.global_position, 1, 8, 30))
	for spot in spots:
		if _clear_ray(game.world, spot, spot + Vector2(0, -90)) and _body_fits(game.world, spot, player.radius):
			player.global_position = spot
			break
	await _frames(2)
	var crack := (load("res://src/entities/prop/cracked_wall.tscn") as PackedScene).instantiate() as CrackedWall
	crack.world = game.world
	crack.setup(CONTENT.dungeon.cracked_wall)
	crack.position = player.global_position + Vector2(0, -90)
	game.world.add_entity(crack)
	CONTENT.tutorial.near_distance = 220.0
	var before_crack := await _until_hint(tutorial, &"cracked_wall", gap)
	var crack_shown := tutorial.current != null and tutorial.current.id == &"cracked_wall"
	check(crack_shown, "a cracked wall nearby: its hint (before it: %s, near %s, seen %s, hero %s at %s, crack at %s, hp %d, same world %s, sight %s)" % [before_crack, tutorial._near(&"cracked_walls"), Profile.has_seen_hint(&"cracked_wall"), player.name, player.global_position, crack.sight_point() if crack.has_method(&"sight_point") else crack.global_position, player.hp, player.world == game.world, game.world.has_line_of_sight(player.global_position, crack.sight_point() if crack.has_method(&"sight_point") else crack.global_position)])
	CONTENT.tutorial.near_distance = -1.0
	tutorial.dismiss()
	crack.queue_free()
	await _frames(gap)

	# The merchant in sight (solid, he doesn't hide himself): walk up and tap Interact. The hint's
	# ring finds the Interact button once he is in reach, and tapping it ends the hint.
	# (In sight for sure, with free floor in front of him: a random point near the hero may sit
	# behind a corner, or be the hero's own spot when none was found.)
	Profile.hints_seen.erase("merchant")
	var merchant_at := game.world.find_open_point_near(player.global_position, 150.0)
	for point in _free_points_away(game.world, player.global_position, 3, 5, 12):
		var front := game.world.map.world_to_cell(point + Vector2(0, 36))
		if game.world.has_line_of_sight(player.global_position, point) and game.world.is_free_cell(front):
			merchant_at = point
			break
	var merchant := game.world.spawn_merchant(CONTENT.dungeon.merchant, game.world.map.world_to_cell(merchant_at))
	CONTENT.tutorial.near_distance = 220.0
	var before_merchant := await _until_hint(tutorial, &"merchant", gap)
	check(tutorial.current != null and tutorial.current.id == &"merchant", "a merchant in sight: his hint (before it: %s, %d px away, in sight %s)" % [before_merchant, roundi(merchant.global_position.distance_to(player.global_position)), game.world.has_line_of_sight(player.global_position, merchant.global_position)])
	CONTENT.tutorial.near_distance = -1.0
	player.global_position = merchant.global_position + Vector2(0, 36)
	await _frames(3)
	var interact := game.hud.get_node("%InteractButton") as InteractButton
	check(game.hint_box.target.has_point(interact.global_position), "by him, it points at the Interact button")
	check(await _tap_interact(game) and game.shop_panel.visible and tutorial.current == null and Profile.has_seen_hint(&"merchant"), "tapping it opens the shop and ends the hint")
	game.shop_panel.close()
	await _frames(2)
	merchant.queue_free()
	await _frames(gap)

	# Under the boss bar when it shows.
	game.hud._boss_bar.show()
	tutorial.cue(&"ambush")
	await _frames(gap)
	check(game.hint_box.lowered, "a hint moves down under the boss bar")
	tutorial.dismiss()
	game.hud._boss_bar.hide_now()

	# A pact door in sight (a room of this floor sealed for the test): its hint.
	var world := game.world
	var index := PactRoom.find_room(world.map, world.rng, [], CONTENT.dungeon.corridor_width + 3)
	if index < 0:
		# No room the floor can spare: any room with one opening on one side will do for a hint.
		for i in range(world.map.rooms.size() - 1, 0, -1):
			var door := PactRoom.door_of(world.map, world.map.rooms[i])
			if not door.is_empty() and PactRoom._one_side(world.map.rooms[i], door):
				index = i
				break
	if index > 0:
		var pact := world.spawn_pact(CONTENT.dungeon.pacts[0], world.map.rooms[index], {})
		# The floor was dressed before this door came: clear what stands in front of it (a real
		# pact door keeps its front free, FloorPopulator reserves it).
		for prop in world.get_node("Entities").get_children():
			if prop is Prop and (prop as Prop).global_position.distance_to(pact.front()) < world.map.tile_size * 2.0:
				world.set_cell_blocked(world.map.world_to_cell((prop as Prop).global_position), false)
				prop.free()
		var near := CONTENT.tutorial.near_distance
		CONTENT.tutorial.near_distance = 200.0
		player.global_position = world.nearest_free_point(pact.front())  # (the front may sit on rock when no dead end was found)
		var others := await _until_hint(tutorial, &"pact", gap, 8)
		var shown := tutorial.current != null and tutorial.current.id == &"pact"
		check(shown, "a pact door in sight: its hint (before it: %s; blocked %s, near %s, queue %s, waiting %s, seen %s, menu %s, banner %s)" % [others, tutorial.is_blocked.call(), tutorial._near(&"pact_doors"), tutorial._queue, tutorial._waiting, Profile.has_seen_hint(&"pact"), game.is_menu_open(), game.hud.is_banner_showing()] + " hero %s hp %d same world %s, sigils %s" % [player.global_position, player.hp, player.world == game.world, get_tree().get_nodes_in_group(&"pact_doors").map(func(n: Node2D) -> String: return "%s d=%d los=%s" % [n.global_position, roundi(n.global_position.distance_to(player.global_position)), game.world.has_line_of_sight(player.global_position, n.global_position)])])
		check(shown and game.hint_box.target.has_area() and game.hint_box.target.has_point((game.hud.get_node("%InteractButton") as Node2D).global_position), "by the stele, it points at the Interact button")
		check(not game.menus.pact.visible, "...and the pact itself waits for the button")
		tutorial.dismiss()
		CONTENT.tutorial.near_distance = near
		pact.set_spent()
		pact.queue_free()
		world.pact = null
		await _frames(gap)
	await _frames(gap)

	# The first trial of the Threshold: its hint once its name and rule are gone, at the countdown.
	await _clear_monsters(game.world)
	player.perks.add(_perk("phoenix_feather"))
	_killing_blow(player)
	check(await _until_trial(game), "a second life opens the Threshold")
	await _frames(30)
	check(tutorial.current == null or tutorial.current.id != &"threshold", "its hint waits for the trial's name to go")
	for i in 400:
		if tutorial.current and tutorial.current.id == &"threshold":
			break
		await _frames(1)
	check(tutorial.current != null and tutorial.current.id == &"threshold", "then the Threshold's hint")
	check(game.hint_box.target.has_area(), "pointing at the countdown")
	tutorial.dismiss()
	check(await _win_trial(game), "back from the trial")
	player.perks.clear()
	player.hp = player.get_max_hp()
	await _frames(gap)
	tutorial.dismiss()  # (the souls hint, if the spectres' souls were the first gathered)
	await _frames(gap)

	# The first fall into the Deeps: its hint once their name and rule are gone, at the way out.
	await _clear_monsters(game.world)
	player.invincible = true
	await _walk_into_hole(game.world, player)
	check(await _until_deeps(game), "a fall takes the hero into the Deeps")
	game.abyss.depths.waves_on = false
	await _frames(30)
	check(tutorial.current == null or tutorial.current.id != &"abyss", "its hint waits for the Deeps' name to go")
	for i in 400:
		if tutorial.current and tutorial.current.id == &"abyss":
			break
		await _frames(1)
	check(tutorial.current != null and tutorial.current.id == &"abyss", "then the Deeps' hint")
	check(game.hint_box.target.has_area(), "pointing at the way out's name")
	tutorial.dismiss()
	check(await _escape_deeps(game), "back up from the Deeps")
	_fill_holes()
	player.invincible = false
	player.hp = player.get_max_hp()
	await _frames(gap)
	tutorial.dismiss()
	await _frames(gap)


## Never over a menu; turned off in the options, they all go.
func _test_menus_and_off(game: Game) -> void:
	var tutorial := game.tutorial
	var gap := int(CONTENT.tutorial.gap * 60) + 10
	game.open_pause_menu()
	tutorial.cue(&"cursed_floor")
	await get_tree().create_timer(gap / 60.0).timeout
	check(tutorial.current == null, "no hint while a menu is open")
	game.pause_menu.resume_requested.emit()
	await _frames(gap)
	check(tutorial.current != null and tutorial.current.id == &"cursed_floor", "it shows once the menu is closed")
	Settings.set_option(&"tutorial_hints", false)
	check(tutorial.current == null and not game.hint_box.visible, "hints off: the one on screen goes")
	check(not Profile.has_seen_hint(&"cursed_floor"), "unread, it isn't counted as seen")
	tutorial.cue(&"event_floor")
	await _frames(gap)
	check(tutorial.current == null, "hints off: none come up")
	# The hero dies with a hint on screen: it goes.
	Settings.set_option(&"tutorial_hints", true)
	tutorial.cue(&"cursed_floor")
	await _frames(gap)
	check(tutorial.current != null, "hints on again")
	tutorial._on_died(game.player)  # (what the hero's death signal calls)
	check(tutorial.current == null and not game.hint_box.visible, "the hero dies: the hint goes")
