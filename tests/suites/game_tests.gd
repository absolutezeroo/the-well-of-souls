class_name GameTests
extends TestSuite
## The real game, played, in tests that each begin on a fresh Game (test_cases(): the runner runs any
## of them alone, `--test=game.<name>`, or shares them between processes): a bot plays a run
## (kills, level ups, stairs, the bag, death and restart), the daily run, saving and resuming, a
## mortal run deeper, then the other game suites' parts (CombatTests, FloorTests, LevelTests,
## SecretTests, BossTests, FinaleTests, CoreTests, DebugTests, SaveTests, PcTests, BagTests,
## StoryTests, DialogueTests). Every Game is set up the same way (_new_game()): no merchant,
## encounter, ambush, curse or special floor popping up (they have their own tests), no act
## cards, the gameplay statistics accepted on a fake server.

## The helper suites the tests borrow from (made before the first test, freed with this suite).
var combat: CombatTests
var floor_suite: FloorTests
var boss: BossTests
var secrets: SecretTests
var finale: FinaleTests
var levels: LevelTests
## The gameplay statistics accepted on a fake server, in every test (the run's end is checked).
var privacy: PrivacyTests
## The content's chances as they were (the game suite turns them off, before_cases()).
var _kept_chances := {}
var _curse_chances := {}
## The suites borrowed for one test (_borrow()), freed with its game.
var _borrowed: Array[Node] = []


func test_cases() -> Array:
	return [
		["rpg_foundations", _on_sturdy_game(func(game: Game) -> void: await (_borrow(RpgFoundationTests.new()) as RpgFoundationTests).run_game(game))],
		["modifiers", _on_sturdy_game(func(game: Game) -> void: await (_borrow(ModifierTests.new()) as ModifierTests).run_game(game))],
		["spawn", _on_game(_test_spawn)],
		["projectiles", _on_game(func(game: Game) -> void: await combat._test_projectiles(game.world, game.player))],
		["perks", _on_game(func(game: Game) -> void: await combat._test_perks_in_game(game, game.world, game.player))],
		["threshold", _on_game(func(game: Game) -> void: await combat._test_threshold(game, game.world, game.player))],
		["synergies", _on_game(func(game: Game) -> void: await combat._test_synergies_in_game(game, game.world, game.player))],
		["sustain", _on_game(func(game: Game) -> void: await combat._test_sustain_in_game(game.world, game.player))],
		["world_objects", _on_game(func(game: Game) -> void: await floor_suite._test_world_objects(game, game.world, game.player))],
		["hazards", _on_game(func(game: Game) -> void: await floor_suite._test_hazards(game, game.world, game.player))],
		["abyss", _on_game(func(game: Game) -> void: await floor_suite._test_abyss(game, game.world, game.player))],
		["abyss_rules", _on_game(func(game: Game) -> void: await floor_suite._test_abyss_rules(game, game.world, game.player))],
		["forge", _on_game(func(game: Game) -> void: await floor_suite._test_forge(game, game.world, game.player))],
		["feel", _on_game(func(game: Game) -> void: await floor_suite._test_feel(game, game.world, game.player))],
		["screen_pass", _on_game(func(game: Game) -> void: await floor_suite._test_screen_pass(game, game.world, game.player))],
		["skills", _on_game(func(game: Game) -> void: await combat._test_skills(game, game.world, game.player))],
		["bestiary", _on_game(func(game: Game) -> void: await combat._test_bestiary(game.world, game.player))],
		["difficulty", _on_game(func(game: Game) -> void: await combat._test_difficulty_in_game(game, game.world, game.player))],
		["perf", _on_game(func(game: Game) -> void: await (_borrow(PerfTests.new()) as PerfTests).run_in_game(game.world, game.player))],
		["trials", _on_game(func(game: Game) -> void: await (_borrow(TrialTests.new()) as TrialTests).run_game(game))],
		["animations", _on_game(_test_animations)],
		["armor_look", _on_game(_test_armor_look)],
		["inventory_screen", _on_game(_test_inventory_screen)],
		["touch_controls", _on_game(_test_touch_controls)],
		["run_timer", _on_game(_test_run_timer)],
		["run", _on_game(_test_run)],
		["ambience", _on_sturdy_game(func(game: Game) -> void: await floor_suite._test_ambience(game))],
		["act_card", _on_sturdy_game(func(game: Game) -> void: await floor_suite._test_act_card(game))],
		["souls", _on_sturdy_game(func(game: Game) -> void: await floor_suite._test_souls(game))],
		["comfort", _on_sturdy_game(func(game: Game) -> void: await floor_suite._test_comfort(game))],
		["loot_and_gold", _on_sturdy_game(func(game: Game) -> void: await floor_suite._test_loot_and_gold(game))],
		["bag_room", _on_sturdy_game(func(game: Game) -> void: await floor_suite._test_bag_room(game))],
		["weapon_kits", _on_sturdy_game(func(game: Game) -> void: await combat._test_weapon_kits(game))],
		["charged_attacks", _on_sturdy_game(func(game: Game) -> void: await combat._test_charged_attacks(game))],
		["four_directions", _on_sturdy_game(func(game: Game) -> void: await combat._test_four_directions(game))],
		["own_effects", _on_sturdy_game(func(game: Game) -> void: await combat._test_own_effects(game))],
		["elemental_attacks", _on_sturdy_game(func(game: Game) -> void: await combat._test_elemental_attacks(game))],
		["encounters", _on_sturdy_game(func(game: Game) -> void: await floor_suite._test_encounters(game))],
		["pacts", _on_sturdy_game(func(game: Game) -> void: await floor_suite._test_pacts(game))],
		["variety", _on_sturdy_game(func(game: Game) -> void: await floor_suite._test_variety(game))],
		["floor_size", _on_sturdy_game(func(game: Game) -> void: await floor_suite._test_floor_size(game))],
		["routes", _on_sturdy_game(func(game: Game) -> void: await floor_suite._test_routes(game))],
		["soul_tree_run", _on_sturdy_game(func(game: Game) -> void: await floor_suite._test_soul_tree_run(game))],
		["status_looks", _on_sturdy_game(func(game: Game) -> void: await floor_suite._test_status_looks(game))],
		["biomes", _on_sturdy_game(func(game: Game) -> void: await floor_suite._test_biomes(game))],
		["levels", _on_sturdy_game(func(game: Game) -> void: await levels.run_game(game))],
		["details", _on_sturdy_game(func(game: Game) -> void: await floor_suite._test_details(game))],
		["belt_and_balance", _on_sturdy_game(func(game: Game) -> void: await floor_suite._test_belt_and_balance(game))],
		["monster_behaviours", _on_sturdy_game(func(game: Game) -> void: await combat._test_monster_behaviours(game))],
		["ai_movement", _on_sturdy_game(func(game: Game) -> void: await combat._test_ai_movement(game))],
		["climate", _on_sturdy_game(func(game: Game) -> void: await floor_suite._test_climate(game))],
		["spacing", _on_sturdy_game(func(game: Game) -> void: await floor_suite._test_spacing(game))],
		["review_fixes", _on_sturdy_game(func(game: Game) -> void: await combat._test_review_fixes(game))],
		["core", _on_sturdy_game(func(game: Game) -> void: await (_borrow(CoreTests.new()) as CoreTests).run_game(game))],
		["debug_panel", _on_sturdy_game(_test_debug_tools)],
		["secret_rooms", _on_sturdy_game(func(game: Game) -> void: await secrets._test_secret_rooms(game))],
		["hidden_floor", _on_sturdy_game(func(game: Game) -> void: await secrets._test_hidden_floor(game))],
		["boss_fight", _on_sturdy_game(func(game: Game) -> void: await boss._test_boss_fight(game))],
		["bodies_fit", _on_sturdy_game(func(game: Game) -> void: await floor_suite._test_bodies_fit(game))],
		["daily_run", _on_game(_test_daily_run)],
		["finale", _on_game(func(game: Game) -> void: await finale._test_finale(game))],
		["finale_story", _on_game(func(game: Game) -> void: await finale._test_finale_story(game))],
		["nameless_keeper", _on_game(func(game: Game) -> void: await finale._test_nameless_keeper(game))],
		["save_and_resume", _on_game(_test_save_and_resume)],
		["mortal_run", _on_game(_test_mortal_run)],
		["saves", _on_game(func(game: Game) -> void: await (_borrow(SaveTests.new()) as SaveTests).run_game(game))],
		["threshold_lost", _on_game(func(game: Game) -> void: await combat._test_threshold_lost(game))],
		["abyss_death", _on_game(func(game: Game) -> void: await floor_suite._test_abyss_death(game))],
		["pc", _on_game(func(game: Game) -> void: await (_borrow(PcTests.new()) as PcTests).run_game(game), true)],
		["bag", _on_game(func(game: Game) -> void: await (_borrow(BagTests.new()) as BagTests).run_bag_game(game), true)],
		["story", _on_game(func(game: Game) -> void: await (_borrow(StoryTests.new()) as StoryTests).run_game(game), true)],
		["dialogue", _on_game(func(game: Game) -> void: await (_borrow(DialogueTests.new()) as DialogueTests).run_game(game), true)],
	]


func before_cases() -> void:
	combat = CombatTests.new()
	floor_suite = FloorTests.new()
	boss = BossTests.new()
	secrets = SecretTests.new()
	finale = FinaleTests.new()
	levels = LevelTests.new()
	privacy = PrivacyTests.new()
	for suite: Node in [combat, floor_suite, boss, secrets, finale, levels, privacy]:
		add_child(suite)
	# No merchant, encounter, ambush, pact, trial or special floor popping up in the middle of other tests (they have their own).
	var dungeon := CONTENT.dungeon
	for key: String in ["merchant_chance", "encounters_max", "ambush_chance", "floor_event_chance", "pact_chance", "trial_chance"]:
		_kept_chances[key] = dungeon.get(key)
		dungeon.set(key, 0)
	# No curses either (they have their own test).
	for difficulty in CONTENT.difficulties:
		_curse_chances[difficulty] = difficulty.curse_chance
		difficulty.curse_chance = 0.0


func after_cases() -> void:
	for key: String in _kept_chances:
		CONTENT.dungeon.set(key, _kept_chances[key])
	for difficulty: DifficultyDef in _curse_chances:
		difficulty.curse_chance = _curse_chances[difficulty]
	await _frames(2)


## A test on a fresh Game: made as every game test's (_new_game()), `body` played on it, then
## freed with the suites it borrowed. `texts_on_grid`: afterwards, every text of the HUD and the
## in-run panels it opened is on the font's grid.
func _on_game(body: Callable, texts_on_grid: bool = false) -> Callable:
	return func() -> void:
		var game := await _new_game()
		await body.call(game)
		if texts_on_grid and is_instance_valid(game):
			var off_grid := _off_grid_texts(game)
			check(off_grid.is_empty(), "every text of the HUD and the in-run panels is on the font's grid (Fonts.SIZES, a one-pixel outline): %s" % ", ".join(off_grid.slice(0, 6)))
		await _drop_game(game)


## A test on a fresh Game whose hero shrugs off the floor's blows (Armor 999): the floors' and
## the weapons' tests, which a stray blow, a trap or a fire must not end (they ran after a
## god-mode bot run when the suite was one game, and some of them need it).
func _on_sturdy_game(body: Callable) -> Callable:
	return _on_game(func(game: Game) -> void:
		game.player.base_stats.defense = 999
		game.player.invalidate_stats()
		await body.call(game))


## The game every game test begins on: a new Game (its first run on floor 1), no act cards (tested
## on their own, see _test_act_card), the gameplay statistics accepted on a fake server.
func _new_game() -> Game:
	privacy.consent_on_fake()
	var game := GAME_SCENE.instantiate() as Game
	game.show_act_cards = false
	add_child(game)
	await _frames(5)
	return game


## `suite` in the tree for the test going on (freed with its game).
func _borrow(suite: TestSuite) -> TestSuite:
	add_child(suite)
	_borrowed.append(suite)
	return suite


func _drop_game(game: Game) -> void:
	_set_move(Vector2.ZERO)
	if is_instance_valid(game):
		game.queue_free()
	for suite in _borrowed:
		if is_instance_valid(suite):
			suite.queue_free()
	_borrowed.clear()
	await _frames(2)


## The first run: the hero on the floor, monsters, a weapon.
func _test_spawn(game: Game) -> void:
	var world: World = game.world
	var player: Player = game.player
	check(player != null and player.world == world, "player spawned in world")
	check(world.monster_count() > 0, "monsters spawned (%d)" % world.monster_count())
	check(player.get_weapon() != null, "player starts with a weapon")


## Animations: frame-by-frame attack in the aimed direction, weapon in hand synced with the body.
func _test_animations(game: Game) -> void:
	var world: World = game.world
	var player: Player = game.player
	var rig := player.rig
	check(rig != null and rig.visible, "player has a visible rig")
	player._invulnerable_time = 2.0  # a monster's hit would play the hurt animation
	player._attack_cooldown = 0.0
	player.attack(Vector2.LEFT)
	check(rig.direction == &"left", "the rig turns toward the attack")
	check(rig.body.animation == &"attack_left", "the body plays attack_left (got %s)" % rig.body.animation)
	check(rig.weapon.visible and rig.weapon.animation == &"attack_left", "the katana is drawn in hand, synced")
	await _frames(40)
	check(not rig.weapon.visible, "the weapon is put away after the attack")
	check(String(rig.body.animation).begins_with("idle") or String(rig.body.animation).begins_with("walk"), "back to idle/walk (%s)" % rig.body.animation)
	player._attack_cooldown = 0.0
	player.attack(Vector2.UP)
	check(rig.weapon.get_index() < rig.body.get_index(), "facing up: weapon drawn behind the body")
	await _frames(40)
	var rat := world.spawn_monster(load("res://data/monsters/rat.tres"), player.global_position + Vector2(200, 0))
	await _frames(1)
	check(rat.rig.body.animation.begins_with("idle") or rat.rig.body.animation.begins_with("walk"), "monsters animate")
	rat.attack(Vector2.LEFT)
	check(not rat.rig.weapon.visible, "a bite shows no weapon sprite")
	rat.queue_free()
	var spear: WeaponDef = load("res://data/items/weapons/lance.tres")
	player.inventory.add(spear)
	player.pack.use_item(spear)
	player._attack_cooldown = 0.0
	player.attack(Vector2.RIGHT)
	check(rig.weapon.visible and rig.weapon.animation == &"attack_right", "the lance has baked attack frames")
	player.pack.use_item(load("res://data/items/weapons/katana.tres"))
	await _frames(30)


## Armor is drawn on the hero (paper doll), frame by frame with the body.
func _test_armor_look(game: Game) -> void:
	var player: Player = game.player
	var rig := player.rig
	for armor_id in ["leather_cap", "iron_helm", "leather_armor", "chain_mail", "plate_armor", "shadow_cloak"]:
		var worn: ArmorDef = load("res://data/items/armors/%s.tres" % armor_id)
		check(worn.wear_frames != null, "%s has a worn look" % armor_id)
		for animation in rig.body.sprite_frames.get_animation_names():
			check(worn.wear_frames.has_animation(animation), "%s covers %s" % [armor_id, animation])
	var helm: ArmorDef = load("res://data/items/armors/iron_helm.tres")
	var mail: ArmorDef = load("res://data/items/armors/chain_mail.tres")
	player.equipment.equip(helm)
	player.equipment.equip(mail)
	check(rig.helmet.visible and rig.body_armor.visible, "worn armor is visible")
	check(rig.helmet.self_modulate == helm.wear_color, "the helmet takes the armor's color")
	player._invulnerable_time = 1.0  # a hit mid-walk would play the hurt animation
	_set_move(Vector2.LEFT)
	await _frames(13)
	check(rig.body_armor.animation == rig.body.animation and rig.body_armor.frame == rig.body.frame, "body armor follows the walk frame by frame")
	check(rig.helmet.animation == rig.body.animation and rig.helmet.frame == rig.body.frame, "helmet follows the walk frame by frame")
	_set_move(Vector2.ZERO)
	player._attack_cooldown = 0.0
	player.attack(Vector2.UP)
	await _frames(3)
	check(rig.helmet.animation == &"attack_up" and rig.helmet.frame == rig.body.frame, "armor follows the attack")
	check(rig.weapon.get_index() < rig.body_armor.get_index(), "facing up: weapon behind the armor too")
	await _frames(40)
	player.equipment.unequip(EquipmentDef.Slot.HEAD)
	player.equipment.unequip(EquipmentDef.Slot.BODY)
	check(not rig.helmet.visible and not rig.body_armor.visible, "removed armor disappears")


## The inventory screen opens, lists items, uses them, pauses, and closes.
func _test_inventory_screen(game: Game) -> void:
	var player: Player = game.player
	var cap: ItemDef = load("res://data/items/armors/leather_cap.tres")
	while not player.inventory.can_add(cap):
		player.inventory.items.pop_back()  # (loot picked up on the way may have filled it)
	player.inventory.add(cap)
	var armor := player.inventory.compartment_of(cap)
	game.inventory_panel.show_category(armor)
	game.open_inventory()
	await _frames(2)
	check(get_tree().paused, "inventory pauses the game")
	var grid: GridContainer = game.inventory_panel.get_node("%ItemGrid")
	var cap_slot: ItemSlot = null
	for child in grid.get_children():
		if (child as ItemSlot).item and (child as ItemSlot).item.id == cap.id:  # (or a cap picked up on the way)
			cap_slot = child
	# A stack takes one place: the tab's stacks, then its compartment's free places.
	var stacks := Inventory.CATEGORIES.entries_in(armor, player.inventory.grouped()).size()
	var free := player.inventory.free_in(armor)
	check(grid.get_child_count() == stacks + free and cap_slot != null, "inventory shows the tab's stacks and the free places as slots (%d = %d + %d)" % [grid.get_child_count(), stacks, free])
	cap_slot.pressed.emit()
	(game.inventory_panel.get_node("%UseButton") as Button).pressed.emit()
	check(player.equipment.get_item(EquipmentDef.Slot.HEAD) != null, "equip from the inventory screen")
	game.inventory_panel.close()
	await _frames(2)
	check(not get_tree().paused, "closing the inventory resumes the game")


## Touch controls feed the same input actions as keyboard and gamepad.
func _test_touch_controls(game: Game) -> void:
	var screen := get_viewport().get_visible_rect().size
	_touch(0, Vector2(200, screen.y - 200), true)
	_drag(0, Vector2(290, screen.y - 200))
	await _frames(2)
	check(Input.get_vector("move_left", "move_right", "move_up", "move_down").x > 0.5, "joystick drag moves right")
	var attack_button: ActionButton = game.hud.get_node("%AttackButton")
	_touch(1, attack_button.global_position, true)
	await _frames(2)
	check(Input.is_action_pressed("attack"), "attack button presses attack (while moving: multi-touch)")
	_touch(1, attack_button.global_position, false)
	_touch(0, Vector2(290, screen.y - 200), false)
	await _frames(2)
	check(not Input.is_action_pressed("attack"), "attack released")
	check(Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO, "joystick released")

	# Fixed joystick (an option): it starts only when touched in its corner.
	Settings.set_option(&"fixed_joystick", true)
	var stick: TouchJoystick = game.hud.get_node("%Joystick")
	check(stick.fixed, "the fixed joystick option reaches the HUD")
	var corner := stick.get_global_transform_with_canvas() * stick.home()
	_touch(0, corner + Vector2(0, -260), true)
	await _frames(2)
	check(Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO, "fixed: a touch away from its corner does nothing")
	_touch(0, corner + Vector2(0, -260), false)
	_touch(0, corner + Vector2(70, 0), true)
	await _frames(2)
	check(Input.get_vector("move_left", "move_right", "move_up", "move_down").x > 0.5, "fixed: a touch on it pushes that way at once")
	_touch(0, corner + Vector2(70, 0), false)
	await _frames(2)
	Settings.set_option(&"fixed_joystick", false)
	var bag: Button = game.hud.get_node("%BagButton")
	_touch(0, bag.get_global_rect().get_center(), true)
	await _frames(1)
	_touch(0, bag.get_global_rect().get_center(), false)
	await _frames(2)
	check(game.inventory_panel.visible, "tapping the bag button opens the inventory")
	game.inventory_panel.close()
	await _frames(2)


## A run played: every consumable and the gear's round trip, a bot hunting for a while (god
## mode), the sealed stairs, the bag's new marks of the run, death and what it records (with the
## run's own potions, blows and kills), then restarts: shrine upgrades, difficulties, Nightmare +9,
## the debug panel's cheats gone.
func _test_run(game: Game) -> void:
	var world: World = game.world
	var player: Player = game.player
	var kills := [0]
	var depth_changes := [0]
	var on_kill := func(_m: Monster) -> void: kills[0] += 1
	var on_depth := func(_d: int) -> void: depth_changes[0] += 1
	Events.monster_killed.connect(on_kill)
	Events.depth_changed.connect(on_depth)
	var debug_tools := _borrow(DebugTests.new()) as DebugTests
	# Every consumable must work without errors.
	player.hp = 10
	for item in CONTENT.items:
		if item is ConsumableDef:
			player.inventory.add(item)
			player.pack.use_item(item)
	check(player.hp > 10, "potions heal")
	await _frames(30)

	# Equip / unequip / drop round trip.
	var bow: WeaponDef = load("res://data/items/weapons/magic_wand.tres")
	check(player.pack.pick_up(bow), "pick up a bow")
	player.pack.use_item(bow)
	check(player.get_weapon() == bow, "bow equipped")
	check(player.inventory.items.size() > 0, "old weapon went to the bag")
	player.pack.unequip(EquipmentDef.Slot.WEAPON)
	check(player.get_weapon() == null, "weapon unequipped")
	player.pack.use_item(load("res://data/items/weapons/katana.tres"))
	check(player.get_weapon() != null, "re-equipped a weapon")
	var count := player.inventory.items.size()
	player.pack.drop_item(bow)
	check(player.inventory.items.size() == count - 1, "dropped item left the bag")
	await _frames(5)

	# Play: hunt monsters for a while (god mode so the run lasts).
	player.base_stats.defense = 999
	player.invalidate_stats()
	await _bot_play(game, 60 * 40)
	print("bot: %d kills, level %d, depth %d" % [kills[0], player.level, game.depth])
	check(kills[0] >= 3, "bot killed monsters (%d)" % kills[0])
	check(player.level > 1, "player gained levels")

	# Sealed stairs first; then, open, they take you deeper.
	await floor_suite._test_stairs_seal(game)
	world = game.world
	var depth_before: int = game.depth
	player.global_position = world.map.cell_to_world(world.map.stairs_cell)
	await _frames(int(game.FADE_TIME * 60.0) + 12)  # the depth changes once the screen is black
	check(game.depth == depth_before + 1, "stairs lead to the next depth")
	check(game.run.splits.size() == depth_before and game.run.splits[depth_before - 1] > 0.0, "the floor's split is taken (%s)" % [game.run.splits])
	check(game.hud.split_text().begins_with("Floor %d" % depth_before), "and shown: %s" % game.hud.split_text())
	check(game._fade.color.a > 0.0, "taking the stairs fades to black")
	await _frames(60)
	check(depth_changes[0] >= 1, "depth_changed emitted")
	check(world.monster_count() > 0, "new floor populated")
	check(not get_tree().paused and game._fade.color.a < 0.05, "the fade clears on the new floor")
	# The bag's new marks and its tab belong to the run: seen now, a rune is new in the next one.
	var rune: RuneDef = load("res://data/runes/ember.tres")
	var bag_panel := game.inventory_panel
	var rune_tab := Inventory.CATEGORIES.index_of(rune)
	player.inventory.add(rune)
	game.open_inventory()
	await _frames(2)
	bag_panel.show_category(rune_tab)
	await _frames(1)
	check(bag_panel.category_index() == rune_tab and rune_tab != 0, "the bag open on the rune's tab (%d)" % bag_panel.category_index())
	bag_panel.close()  # (what was shown is seen once the bag closes)
	await _frames(2)
	bag_panel.open(player)
	await _frames(2)
	check(not bag_panel.tab(rune_tab).fresh, "the rune seen: no longer new in this run")
	bag_panel.close()
	await _frames(2)

	# Death and restart (without perks: a Phoenix Feather from the boss would save the hero).
	var souls_before_death := Profile.souls
	player.perks.clear()
	player.base_stats.defense = 0
	player.invalidate_stats()
	var hit := HitInfo.new()
	hit.amount = 99999
	player._invulnerable_time = 0.0
	player.take_hit(hit)
	check(player.is_dead, "player can die")
	check(not game.threshold.is_open(), "no second life, no Threshold")
	check(await _until(func() -> bool: return game.game_over_panel.visible), "game over screen shown")
	privacy.game_summary(player)  # what the run's end sent (and the tests' usual again)
	check(not RunSave.exists(), "dying ends the saved run")
	check(not Profile.history.is_empty() and not str(Profile.history[0].cause).is_empty(), "the run goes to the history, with what ended it")
	check(Profile.stat_value("kills") > 0 and Profile.stat_value("species") > 0, "kills count in the bestiary")
	check(Profile.is_achieved(&"first_blood"), "first kill, first achievement")
	var end_text := game.game_over_panel.shown_text()
	check(Profile.souls >= souls_before_death and end_text.contains("souls") and end_text.contains("Shrine"), "the end of a run shows its souls and what they are for")
	check(end_text.contains("Monsters slain") and end_text.contains("Time"), "and the run's numbers")
	check(game.game_over_panel.voice().is_visible_in_tree() and end_text.contains("The Vigil-Keeper"), "and the Vigil-Keeper tells how it ended (DialogueTests: what she says; with nothing to say, a line of the story)")
	# Shrine upgrades apply to the next run.
	Profile.levels = { "vitality": 2, "provisions": 1, "second_chance": 1, "paladin_oath": 1 }
	Profile.difficulty = &"easy"
	game.start_run()
	await _frames(5)
	check(bag_panel.category_index() == 0, "a restart opens the bag on its first tab again, not the last run's")
	game.player.inventory.add(rune)
	bag_panel.open(game.player)  # (the panel itself: whatever else the new run opens first)
	await _frames(2)
	check(bag_panel.tab(rune_tab).fresh, "and what the last run had seen is new in this one")
	bag_panel.close()
	await _frames(2)
	check(game.difficulty.id == &"easy" and game.world.difficulty == game.difficulty, "the run uses the chosen difficulty")
	check((game.hud.get_node("%InfoLabel") as Label).text.contains("Pilgrim"), "the HUD shows the difficulty")
	Profile.difficulty = &"nightmare"
	game.start_run()
	await _frames(3)
	check(game.difficulty == CONTENT.default_difficulty, "a locked difficulty falls back to Normal")
	var base_hp: int = game.player.get_max_hp()
	Profile.wins = { "hard": 1, "nightmare": 1 }
	Profile.ascension_unlocked = 9
	Profile.ascension = 9
	game.start_run()
	await _frames(3)
	check(game.difficulty.ascension == 9 and game.world.difficulty.shown_name() == "Nightmare +9", "a run on Nightmare +9")
	check(game.player.get_max_hp() < base_hp, "Frail: less max HP")
	var merchant: Merchant = game.world.spawn_merchant(CONTENT.dungeon.merchant, game.world.map.start_cell + Vector2i(3, 0))
	var potion_price: int = CONTENT.dungeon.merchant.buy_price(load("res://data/items/consumables/health_potion.tres"), game.depth)
	merchant._add(load("res://data/items/consumables/health_potion.tres"))
	check(merchant.stock.back().price > potion_price, "Thin Purse: higher prices")
	merchant.queue_free()
	game._save_run()
	check(int(RunSave.read().get("ascension", 0)) == 9, "the saved run keeps its ascension")
	Profile.wins = {}
	Profile.ascension_unlocked = 0
	Profile.ascension = 0
	Profile.difficulty = &"normal"
	debug_tools.arm_for_new_run()  # (the debug panel's cheats end with the run)
	game.start_run()
	await _frames(3)
	debug_tools.check_new_run()
	check(game.player != player and not game.player.is_dead, "restart creates a fresh player")
	check(game.player.get_max_hp() == CONTENT.player.base_stats.max_hp + 2 * _upgrade("vitality").bonuses.max_hp, "Vitality raises max HP")
	var potion_def: ConsumableDef = load("res://data/items/consumables/health_potion.tres")
	check(game.player.belt.count_of(potion_def) + game.player.inventory.count_of(potion_def) == CONTENT.player.starting_items.size() + 1, "Provisions add a potion")
	check(game.player.perks.stacks_of(load("res://data/perks/relics/phoenix_feather.tres")) == 1, "Second Chance gives a Phoenix Feather")
	check(CONTENT.unlocked_items.has(load("res://data/items/weapons/templar_sword.tres")), "Templar's Vow unlocks the Templar Sword")
	Profile.reset()
	check(game.depth == 1, "restart goes back to depth 1")
	Events.monster_killed.disconnect(on_kill)
	Events.depth_changed.disconnect(on_depth)


## The daily run: the same floors, weapon and relic all day; the first attempt counts.
func _test_daily_run(game: Game) -> void:
	var day := DailyRun.today()
	game.start_run(true)
	await _frames(3)
	check(game.run.is_daily() and game.run.daily_official and Profile.daily_played(day), "today's daily run is the official attempt")
	check(game.difficulty == CONTENT.default_difficulty, "on Normal")
	check(game.player.get_weapon() == DailyRun.weapon(CONTENT, day) and game.player.perks.stacks_of(DailyRun.relic(CONTENT, day)) == 1, "with the day's weapon and relic")
	var rooms := game.world.map.rooms.duplicate()
	game._enter_floor()
	await _frames(2)
	check(game.world.map.rooms == rooms, "the same floor every time that day")
	game.run.kills = 10
	game.depth = 3
	game.run.depth = 3
	game._award_souls(false)
	check(Profile.daily_score == DailyRun.score(game.run) and Profile.daily_best == Profile.daily_score and Profile.daily_score >= 10 + 2 * DailyRun.POINTS_PER_FLOOR, "its score is kept (%d)" % Profile.daily_score)
	game.start_run(true)
	await _frames(3)
	check(game.run.is_daily() and not game.run.daily_official, "a second daily run that day is practice")
	game._save_run()
	check(int(RunSave.read().get("daily_day", -1)) == day, "a saved daily run stays a daily run")
	game.start_run()
	await _frames(3)
	check(not game.run.is_daily(), "Play starts a normal run")
	Profile.reset()


## The run in progress is saved, and picked up again as it was.
func _test_save_and_resume(game: Game) -> void:
	check(RunSave.exists(), "the run in progress is saved")
	var hero: Player = game.player
	var wand: ItemDef = load("res://data/items/weapons/magic_wand.tres")
	var frenzy := _perk("frenzy")
	# Perk choices wait across floors, and are saved with the run (the one on screen with its cards).
	hero.gain_xp(hero.xp_to_next_level())
	hero.gain_xp(hero.xp_to_next_level())
	await _frames(2)
	check(game.pending_offers() == 2 and not game.perk_panel.visible, "two level ups: two choices wait")
	game.depth = 4
	game._enter_floor()
	await _frames(3)
	check(game.pending_offers() == 2 and (game.hud.get_node("%OffersButton") as OffersButton).count == 2, "they wait across floors")
	check(game.open_offers(), "the perk button opens them")
	var on_screen := game.perk_panel.get_offered().duplicate()
	hero.level = 3
	hero.xp = 7
	hero.inventory.add(wand)
	hero.perks.add(frenzy)
	var weapon_before := hero.get_weapon()
	game.depth = 5
	game.kills = 12
	game._save_run()
	var saved := RunSave.read()
	check(int(saved.get("depth", 0)) == 5 and int(saved.player.level) == 3, "the save holds the run")
	game.resume_run(saved)
	await _frames(5)
	var back: Player = game.player
	check(back != hero and game.depth == 5 and game.kills == 12 and game.world.depth == 5, "resuming goes back to the same depth")
	check(back.level == 3 and back.xp == 7 and back.perks.stacks_of(frenzy) == 1, "the hero comes back as saved")
	check(back.inventory.count_of(wand) >= 1 and back.get_weapon() == weapon_before, "with their gear")
	check(not game.perk_panel.visible and not get_tree().paused, "a resumed run opens no perk choice by itself")
	check(game.pending_offers() == 2 and (game.hud.get_node("%OffersButton") as OffersButton).count == 2, "the waiting choices survive save and resume, behind the perk button")
	check(await _tap_offers(game) and game.perk_panel.visible and game.perk_panel.get_offered() == on_screen, "the choice that was on screen comes back with its cards")
	game.perk_panel.choose(0)
	await _frames(2)
	check(game.perk_panel.visible, "then the other one")
	game.perk_panel.choose(0)
	await _frames(2)
	check(not get_tree().paused and game.pending_offers() == 0, "both taken, back to the game")
	# The seal's kills on this floor survive a save (they used to start over at 0).
	var seal: StairsSeal = game.world.seal
	check(seal.needed >= 3, "a sealed floor to count on (%d kills asked)" % seal.needed)
	seal.add_kill()
	seal.add_kill()
	game._save_run()
	game.resume_run(RunSave.read())
	await _frames(5)
	check(game.world.seal.kills == 2 and game.world.seal.is_sealed(), "the seal's kills on the floor come back with the run (%d / %d)" % [game.world.seal.kills, game.world.seal.needed])
	game.world.seal.kills = 0
	game.world.seal.add_kill()
	game.world.seal.break_now()
	game._save_run()
	var logged: Array[String] = []
	var on_log := func(text: String, _color: Color) -> void: logged.append(text)
	Events.message_logged.connect(on_log)
	var hero_on_floor: Array[bool] = []
	var on_reset := func() -> void: hero_on_floor.append(game.world.player != null)
	game.world.map_reset.connect(on_reset)
	game.resume_run(RunSave.read())
	await _frames(5)
	Events.message_logged.disconnect(on_log)
	game.world.map_reset.disconnect(on_reset)
	check(not hero_on_floor.is_empty() and not hero_on_floor[0], "while a run's first floor is laid, the last hero isn't on it")
	check(not game.world.seal.is_sealed(), "a seal broken before quitting stays broken")
	check(not logged.any(func(text: String) -> bool: return text.begins_with("The seal shatters")) and not game.world.get_node("Effects").get_children().any(func(n: Node) -> bool: return n is GuideWisp), "...quietly: no fanfare, no guiding light again (%s)" % [logged])
	check(game.world.player == game.player, "the floor's hero is the new one")


## A second bot run on a fresh character at higher depths, mortal this time; the slain stay dead.
func _test_mortal_run(game: Game) -> void:
	# Monsters must be able to hurt a player who just stands there.
	var victim: Player = game.player
	var hp_before := victim.hp
	var skeleton: MonsterDef = load("res://data/monsters/skeleton.tres")
	game.world.spawn_monster(skeleton, victim.global_position + Vector2(40, 0))
	await _frames(60 * 4)
	check(victim.hp < hp_before, "monsters damage the player")

	game.depth = 4
	game._enter_floor()
	await _bot_play(game, 60 * 20)
	print("bot (depth 4, mortal): hp %d/%d, dead=%s" % [game.player.hp, game.player.get_max_hp(), game.player.is_dead])
	await floor_suite._test_slain_stay_dead(game)


## The debug panel (FloorTests' part leaves its god mode on: DebugTests asks for a clean slate).
func _test_debug_tools(game: Game) -> void:
	await floor_suite._test_debug_panel(game)
	await (_borrow(DebugTests.new()) as DebugTests).run_game(game)


## The run's clock: counts in play and in the bag, not in the pause menu; on the HUD.
func _test_run_timer(game: Game) -> void:
	var game_run := game.run
	var start := game_run.time
	await _frames(60)
	check(game_run.time - start > 0.9 and game_run.time - start < 1.2, "the clock counts real seconds (%.2f)" % (game_run.time - start))
	game.open_pause_menu()
	var paused := game_run.time
	await _frames(60)
	check(is_equal_approx(game_run.time, paused), "it stops in the pause menu")
	game.pause_menu.resume_requested.emit()
	await _frames(2)
	game.open_inventory()
	var in_bag := game_run.time
	await _frames(30)
	check(game_run.time > in_bag + 0.4, "it runs in the bag (deciding is part of the run)")
	game.inventory_panel.close()
	HitStop.slow(1.0, 0.25)
	var slow := game_run.time
	await _frames(30)
	check(game_run.time - slow > 0.4 and game_run.time - slow < 0.6, "slow motion doesn't slow the clock (%.2f)" % (game_run.time - slow))
	HitStop.reset()
	# A blow lands during physics and freezes the world: the clock neither jumps nor stalls. (It
	# used to add up to a quarter of a second at each hit stop: that frame's delta, scaled at 1,
	# divided by the freeze's scale. Each frame is 1/60 s here, frozen or not.)
	await _frames(2)
	var before_freeze := game_run.time
	await get_tree().physics_frame
	HitStop.freeze(0.1)
	await _frames(30)
	check(absf(game_run.time - before_freeze - 0.5) < 0.04, "a hit stop doesn't change the clock (%.2f s in 30 frames)" % (game_run.time - before_freeze))
	HitStop.reset()
	var label := game.hud.get_node("%TimerLabel") as Label
	await _frames(1)
	check(label.visible and label.text == TimeText.of(game_run.time, 1), "the time is under the map: %s" % label.text)
	Settings.set_option(&"run_timer", false)
	await _frames(1)
	check(not label.visible, "the run timer can be hidden")
	Settings.set_option(&"run_timer", true)

