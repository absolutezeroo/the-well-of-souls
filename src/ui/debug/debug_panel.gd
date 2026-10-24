class_name DebugPanel
extends RpgWindow
## Dev tools, only in debug builds (running from the editor, debug exports). Opened from the HUD's
## DBG button (or F1); the game pauses. Built in code: nothing to maintain in a scene.
##
## Six tabs (tapped, clicked, or switched with Q / E and LB / RB like the bag's: MenuNav), each a
## column of rows, a row's name on its left and its buttons after it:
## - **World**: jump to any floor (with a curse or an event), the special places (the next boss,
##   the hidden floor, the Deeps, the bottom of the Well), to the stairs, the boss room, the next
##   room, the maps revealed, pacts, any encounter or fragment of the past placed beside the
##   hero, the floor's warden telling its story.
## - **Hero**: the cheats (god mode, invisible, damage and armor steps, speed, no cooldowns: they
##   last the run, DebugCheats), heal, gold, levels, death, any item, rune, tome, perk or relic.
## - **Monsters**: No AI, spawn any monster or boss at any rank, kill all, put all asleep.
## - **Gallery**: a floor of any biome (its room shapes, its signature room, any ceiling) and the
##   monster gallery (DebugGallery).
## - **Tools**: the game's speed, the camera's zoom, full light, the bodies and reaches drawn
##   (DebugShapes), the frame rate and counts (DebugOverlay), saving and picking the run up again.
## - **Remote**: the remote settings (RemoteConfig) in use, last read and simulated; any key set to
##   a sample value as if the server sent it; read now, apply now.
## A toggle says its state ("Invisible: ON"), a step its value ("Damage x5"); both stay pressed
## while on. The panel only calls the Game, the World and DebugCheats: the rules stay theirs.
## Whatever it does to the run makes it a debug run (DebugCheats.mark_run(): nothing kept); the
## Tools tab's views don't.

signal closed

const BUTTON_SIZE := Vector2(118, 44)
## Room for a row's name on its left.
const HEADING_WIDTH := 132.0

var _game: Game
var _depth := 1
var _monster_index := 0
var _monsters: Array[MonsterDef] = []
var _room_index := 0

var _depth_label: Label
var _monster_label: Label
var _god_button: Button
var _status: Label
## The tabs and their pages, in order.
var _tabs: TabRow
var _pages: Array[Control] = []
## Called on every refresh: each toggle and step button sets its own text and pressed state.
var _refreshers: Array[Callable] = []
## The same for the Gallery's room shapes (made again for each biome).
var _shape_refreshers: Array[Callable] = []

# The Gallery tab's picks.
var _biomes: Array[BiomeDef] = []
var _biome_index := 0
var _shape: RoomShapeDef
## -1: the biome's own ceiling, -2: none, else an index in _ceilings.
var _ceiling_index := -1
var _ceilings: Array[CeilingDef] = []
var _scopes: Array[DebugGallery.Scope] = []
var _scope_index := 0
var _shape_row: HFlowContainer

# The Hero tab's Give row.
var _give_lists: Array[Array] = []  # [category name, Array of ItemDef / PerkDef]
var _give_category := 0
var _give_index := 0
var _give_label: Label

# The World tab's Encounter and Fragment rows.
var _encounter_index := 0
## The aura the "Next aura" button put on (-1: none).
var _aura_index := -1
var _fragment_index := 0
## Every fragment of the past, with its warden: [FragmentDef, BossDef].
var _fragment_list: Array[Array] = []

# The Remote tab's picks: a key of the allow-list, one of its sample values.
var _remote_index := 0
var _remote_value := 0

var _overlay: DebugOverlay
var _shapes: DebugShapes


## Debug builds only: everywhere else there is no debug panel at all.
static func is_available() -> bool:
	return OS.is_debug_build()


func _init() -> void:
	super("Debug")
	hide()
	close_requested.connect(close)


func open(game: Game) -> void:
	_game = game
	if _tabs == null:
		# Built on first use: the curses, events and monsters come from the game's content.
		_build_tabs()
	_bind_views()
	_depth = game.depth
	_status.text = ""
	_refresh()
	show()


func close() -> void:
	hide()
	closed.emit()


## The tab shown now (0: World...).
func tab_index() -> int:
	for i in _pages.size():
		if _pages[i].visible:
			return i
	return 0


func show_tab(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
	_tabs.select(index)


## How many tabs (tests).
func tab_count() -> int:
	return _tabs.buttons.size() if _tabs else 0


# --- Tabs ---------------------------------------------------------------------------------

## The tabs in the window's header, beside Close (the pages get the height); what an action did
## under the pages.
func _build_tabs() -> void:
	_tabs = TabRow.new()
	header_right.add_child(_tabs)
	_tabs.picked.connect(show_tab)
	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(pages)
	_status = UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
	body.add_child(_status)
	var builders: Array[Array] = [
		["World", _build_world], ["Hero", _build_hero], ["Monsters", _build_monsters],
		["Gallery", _build_gallery], ["Tools", _build_tools], ["Remote", _build_remote],
	]
	for entry: Array in builders:
		_tabs.add_tab(entry[0], "%sTab" % entry[0])  # (a dev tool: English only)
		var scroll := UiParts.scroll()
		scroll.name = "%sPage" % entry[0]
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pages.add_child(scroll)
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 4)
		scroll.add_child(column)
		_pages.append(scroll)
		(entry[1] as Callable).call(column)
	show_tab(0)


func _bind_views() -> void:
	if _overlay == null:
		_overlay = DebugOverlay.new()
		get_parent().add_child(_overlay)
		_shapes = DebugShapes.new()
		_game.add_child(_shapes)
	_overlay.game = _game
	_shapes.game = _game


# --- World ---------------------------------------------------------------------------------

func _build_world(page: VBoxContainer) -> void:
	var floor_row := _row(page, "Floor")
	floor_row.add_child(_button("-", func() -> void: _set_depth(_depth - 1), Vector2(54, 44)))
	_depth_label = _label("")
	_depth_label.custom_minimum_size.x = 96
	_depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_row.add_child(_depth_label)
	floor_row.add_child(_button("+", func() -> void: _set_depth(_depth + 1), Vector2(54, 44)))
	floor_row.add_child(_button("Go there", func() -> void: _go(_depth)))
	floor_row.add_child(_button("Next floor", func() -> void: _go(_game.depth + 1)))
	floor_row.add_child(_button("Rebuild floor", func() -> void: _go(_game.depth)))

	var places := _row(page, "Places")
	places.add_child(_button("Next boss", func() -> void: _go(_next_boss_depth())))
	if _game_content().dungeon.hidden_floor:
		places.add_child(_button("Hidden floor", func() -> void:
			DebugCheats.mark_run()
			close()
			_game.debug.enter_hidden()))
	if _game_content().dungeon.abyss:
		places.add_child(_button("The Deeps", _enter_deeps))
	if _game_content().dungeon.finale:
		places.add_child(_button("The Well's bottom", func() -> void:
			DebugCheats.mark_run()
			close()
			_game.debug.enter_finale()))
		if _game_content().dungeon.finale.keeper:
			places.add_child(_button("Nameless Keeper", func() -> void:
				DebugCheats.mark_run()
				close()
				_game.debug.enter_finale(true)))

	var move := _row(page, "Move")
	move.add_child(_button("Stairs", func() -> void: _act(func() -> void:
		var world := _game.world
		if not world.stairs_cells.is_empty():
			_teleport(world.map.cell_to_world(world.stairs_cells[0]) + Vector2(0, 40))
		, "To the stairs")))
	move.add_child(_button("Boss room", _to_boss_room))
	move.add_child(_button("Next room", _next_room))
	move.add_child(_button("Break seal", func() -> void: _act(func() -> void: _game.world.seal.break_now(), "Stairs open")))
	_toggle(move, "Reveal maps", func() -> bool: return DebugCheats.reveal_maps, func(on: bool) -> void:
		DebugCheats.set_reveal_maps(on)
		if on:
			_game.world.reveal_all())

	var story := _row(page, "Encounter")
	_picker(story, func() -> int: return _game_content().encounters.size(), func() -> int: return _encounter_index,
		func(index: int) -> void: _encounter_index = index,
		func() -> String: return _game_content().encounters[_encounter_index].display_name if not _game_content().encounters.is_empty() else "-")
	story.add_child(_button("Place", _place_encounter))
	story.add_child(_button("Boss story", _boss_story))
	var fragments := _row(page, "Fragment")
	_picker(fragments, func() -> int: return _fragments().size(), func() -> int: return _fragment_index,
		func(index: int) -> void: _fragment_index = index, _fragment_text)
	fragments.add_child(_button("Place", _place_fragment))

	var curses := _row(page, "Curse")
	curses.add_child(_button("None", func() -> void: _go(_game.depth, null, null, true)))
	for curse in _game_content().curses:
		curses.add_child(_button(curse.display_name, func() -> void: _go(maxi(_game.depth, 2), curse)))
	var events := _row(page, "Event")
	for event in _game_content().floor_events:
		events.add_child(_button(event.display_name, func() -> void: _go(maxi(_game.depth, 2), null, event)))
	var pacts := _row(page, "Pact door")
	for pact_def in _game_content().dungeon.pacts:
		pacts.add_child(_button(pact_def.id.capitalize(), _debug_pact.bind(pact_def)))
	var trials := _row(page, "Room trial")
	for trial_def in _game_content().dungeon.trials:
		trials.add_child(_button(trial_def.id.capitalize(), _debug_trial.bind(trial_def)))


# --- Hero ----------------------------------------------------------------------------------

func _build_hero(page: VBoxContainer) -> void:
	var cheats := _row(page, "Cheats")
	_god_button = _toggle(cheats, "God mode", func() -> bool: return _game.player.invincible, func(on: bool) -> void:
		_game.player.invincible = on
		if on:
			DebugCheats.mark_run())
	_toggle(cheats, "Invisible", func() -> bool: return DebugCheats.invisible, DebugCheats.set_invisible)
	_toggle(cheats, "No cooldowns", func() -> bool: return DebugCheats.no_cooldowns, DebugCheats.set_no_cooldowns)
	var steps := _row(page, "Steps")
	_stepper(steps, "Damage", DebugCheats.DAMAGE_STEPS, func() -> int: return DebugCheats.damage_step, DebugCheats.set_damage_step)
	_stepper(steps, "Taken", DebugCheats.ARMOR_STEPS, func() -> int: return DebugCheats.armor_step, DebugCheats.set_armor_step)
	_stepper(steps, "Speed", DebugCheats.SPEED_STEPS, func() -> int: return DebugCheats.speed_step, DebugCheats.set_speed_step)

	var body_row := _row(page, "Body")
	body_row.add_child(_button("Full heal", func() -> void: _act(func() -> void:
		_game.player.heal(_game.player.get_max_hp())
		_game.player.statuses.clear(), "Healed")))
	body_row.add_child(_button("+500 gold", func() -> void: _act(func() -> void: _game.player.add_gold(500), "+500 gold")))
	body_row.add_child(_button("Level up", func() -> void: _act(func() -> void:
		_game.player.gain_xp(_game.player.xp_to_next_level() - _game.player.xp), "Level up")))
	body_row.add_child(_button("Kill hero", _kill_hero))
	# Every aura on the hero in turn, locked or not, for this run's look only (not a debug run:
	# it changes nothing, and the Wardrobe's choice stays as it was).
	var looks := _row(page, "Aura")
	looks.add_child(_button("Next aura", _next_aura))
	var heat := _row(page, "Temperature")
	heat.add_child(_button("Freezing", func() -> void: _act(func() -> void: _game.player.temperature.value = -90.0, "Cold")))
	heat.add_child(_button("Burning", func() -> void: _act(func() -> void: _game.player.temperature.value = 90.0, "Hot")))
	heat.add_child(_button("Normal", func() -> void: _act(func() -> void: _game.player.temperature.reset(), "Normal")))

	var bag := _row(page, "Bag")
	bag.add_child(_button("Epic weapon", func() -> void: _act(_give_epic_weapon, "Epic weapon in the bag")))
	bag.add_child(_button("All consumables", func() -> void: _act(func() -> void:
		for item in _game_content().items:
			if item is ConsumableDef:
				_game.player.pack.store(item), "Consumables added")))
	bag.add_child(_button("Every rune", func() -> void: _act(func() -> void:
		for rune in _game_content().runes:
			_game.player.inventory.add(rune), "Runes in the bag")))
	bag.add_child(_button("Forge here", func() -> void: _act(func() -> void:
		var world: World = _game.world
		var cell := world.map.world_to_cell(world.find_open_point_near(_game.player.global_position + Vector2(70, 0), 40.0))
		world.spawn_forge(_game_content().dungeon.forge, cell), "The smith is here")))

	var give := _row(page, "Give")
	give.add_child(_button("Kind", func() -> void: _cycle_give(1, 0)))
	give.add_child(_button("<", func() -> void: _cycle_give(0, -1), Vector2(54, 44)))
	_give_label = _label("")
	_give_label.custom_minimum_size.x = 300
	_give_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_give_label.clip_text = true
	give.add_child(_give_label)
	give.add_child(_button(">", func() -> void: _cycle_give(0, 1), Vector2(54, 44)))
	give.add_child(_button("Give", _give))


# --- Monsters ------------------------------------------------------------------------------

func _build_monsters(page: VBoxContainer) -> void:
	var brain := _row(page, "Brains")
	_toggle(brain, "No AI", func() -> bool: return DebugCheats.no_ai, DebugCheats.set_no_ai)
	brain.add_child(_button("Kill all", func() -> void: _act(func() -> void:
		for monster in _game.world.get_hostiles(Actor.Faction.PLAYER):
			monster.die(_game.player), "All dead")))
	brain.add_child(_button("All asleep", func() -> void: _act(func() -> void:
		for monster in _game.world.get_hostiles(Actor.Faction.PLAYER):
			(monster as Monster).dormant = true
			(monster as Monster).target = null, "Asleep (hit them to wake them)")))

	var row := _row(page, "Monster")
	row.add_child(_button("<", func() -> void: _cycle_monster(-1), Vector2(54, 44)))
	_monster_label = _label("")
	_monster_label.custom_minimum_size.x = 260
	_monster_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_monster_label)
	row.add_child(_button(">", func() -> void: _cycle_monster(1), Vector2(54, 44)))
	row.add_child(_button("Spawn", func() -> void: _act(func() -> void: _spawn(false), "Spawned")))
	row.add_child(_button("Spawn elite", func() -> void: _act(func() -> void: _spawn(true), "Elite spawned")))
	# The rare ranks: spawn one of the chosen monster, or make the next boss one.
	var ranks := _row(page, "Spawn rank")
	for rank in _game_content().dungeon.rare_ranks:
		ranks.add_child(_button(rank.display_name, func() -> void: _act(func() -> void: _spawn_ranked(rank), "%s spawned" % rank.display_name)))
	var bosses := _row(page, "Next boss")
	for rank in _game_content().dungeon.rare_ranks:
		bosses.add_child(_button(rank.display_name, func() -> void: _act(func() -> void: _game.world.overrides.boss_rank = rank, "The next boss: %s" % rank.display_name)))


# --- Gallery -------------------------------------------------------------------------------

func _build_gallery(page: VBoxContainer) -> void:
	var content := _game_content()
	_biomes = DebugGallery.biomes(content)
	_ceilings = DebugGallery.ceilings(content)
	_scopes = DebugGallery.scopes(content)
	var biome_row := _row(page, "Biome")
	for i in _biomes.size():
		_choice(biome_row, _biomes[i].display_name, func() -> bool: return _biome_index == i, func() -> void:
			_biome_index = i
			_shape = null
			_fill_shapes())
	_shape_row = _row(page, "Rooms")
	_fill_shapes()
	var ceiling_row := _row(page, "Ceiling")
	_choice(ceiling_row, "Its own", func() -> bool: return _ceiling_index == -1, func() -> void: _ceiling_index = -1)
	_choice(ceiling_row, "None", func() -> bool: return _ceiling_index == -2, func() -> void: _ceiling_index = -2)
	for i in _ceilings.size():
		_choice(ceiling_row, _ceilings[i].resource_path.get_file().get_basename().capitalize(), func() -> bool: return _ceiling_index == i, func() -> void: _ceiling_index = i)
	ceiling_row.add_child(_action_button("Build this floor", build_biome_floor))
	var scope_row := _row(page, "Monsters of")
	for i in _scopes.size():
		_choice(scope_row, _scopes[i].name, func() -> bool: return _scope_index == i, func() -> void: _scope_index = i)
	scope_row.add_child(_action_button("Monster gallery", build_monster_gallery))
	var note := _label("Both make a debug run: nothing is saved or recorded. The monster gallery turns No AI, Invisible and Full light on.")
	page.add_child(_note(note))


## The chosen biome's shapes: "As usual", then each room shape and signature room.
func _fill_shapes() -> void:
	if _shape_row == null:
		return
	for child in _shape_row.get_children():
		_shape_row.remove_child(child)
		child.queue_free()
	_shape_refreshers.clear()
	_choice(_shape_row, "As usual", func() -> bool: return _shape == null, func() -> void: _shape = null, _shape_refreshers)
	var biome := _biomes[_biome_index]
	for shape in DebugGallery.shapes_of(biome):
		# A signature room is marked with a star.
		var text := ("* %s" if biome.set_pieces.has(shape) else "%s") % shape.display_name
		_choice(_shape_row, text, func() -> bool: return _shape == shape, func() -> void: _shape = shape, _shape_refreshers)
	_refresh()


## The chosen biome as a plain floor of its act, with the chosen rooms and ceiling, its map
## revealed. A debug run.
func build_biome_floor() -> void:
	var biome := _biomes[_biome_index]
	var ceiling := _ceilings[_ceiling_index] if _ceiling_index >= 0 else null
	DebugCheats.mark_run()
	close()
	_game.world.overrides.biome = DebugGallery.variant(biome, _shape, ceiling, _ceiling_index == -1)
	await _game.debug.enter_floor(DebugGallery.depth_for(_game_content(), biome), null, null, true)
	_game.world.reveal_all()


## The chosen scope's monsters in rows in a hall of the chosen biome, No AI and the hero
## invisible. A debug run.
func build_monster_gallery() -> void:
	var scope := _scopes[_scope_index]
	var biome := _biomes[_biome_index]
	var ceiling := _ceilings[_ceiling_index] if _ceiling_index >= 0 else null
	var hall := DebugGallery.hall(_game_content().dungeon, scope.monsters)
	DebugCheats.mark_run()
	DebugCheats.set_no_ai(true)
	DebugCheats.set_invisible(true)
	DebugCheats.set_full_light(true)
	close()
	_game.world.overrides.map = hall.map
	_game.world.overrides.biome = DebugGallery.variant(biome, null, ceiling, _ceiling_index == -1)
	await _game.debug.enter_floor(scope.depth, null, null, true)
	_game.world.reveal_all()
	var spots: Array[Vector2] = hall.spots
	DebugGallery.fill(_game.world, scope.monsters, spots)


# --- Tools ---------------------------------------------------------------------------------

func _build_tools(page: VBoxContainer) -> void:
	var time := _row(page, "Time")
	_stepper(time, "Game speed", DebugCheats.TIME_STEPS, func() -> int: return DebugCheats.time_step, DebugCheats.set_time_step)
	var view := _row(page, "View")
	_stepper(view, "Zoom", DebugCheats.ZOOM_STEPS, func() -> int: return DebugCheats.zoom_step, func(step: int) -> void:
		DebugCheats.set_zoom_step(step)
		_game.player.camera.fit_zoom())
	_toggle(view, "Full light", func() -> bool: return DebugCheats.full_light, func(on: bool) -> void:
		DebugCheats.set_full_light(on)
		_game.world.relight())
	_toggle(view, "Bodies & reach", func() -> bool: return DebugCheats.show_shapes, func(on: bool) -> void: DebugCheats.show_shapes = on)
	_toggle(view, "Frame rate", func() -> bool: return DebugCheats.show_stats, func(on: bool) -> void:
		DebugCheats.show_stats = on
		_overlay.refresh())
	var run := _row(page, "Run")
	run.add_child(_button("Save & reload", func() -> void:
		if _game.debug.reload():
			_status.text = "Saved and picked up again"
		else:
			_status.text = "Not saved: a debug run, the Deeps or the Threshold"))
	var note := _label("Game speed takes effect when the panel closes. Speed, zoom and the views last the run; they don't make a debug run.")
	page.add_child(_note(note))


# --- Remote --------------------------------------------------------------------------------

## The remote settings (RemoteConfig): every key with its value in use, the one last read and a
## simulated one; any key set to a sample value as if the server had it (checked the same way,
## applied at the next safe point); read again, apply now.
func _build_remote(page: VBoxContainer) -> void:
	var read := _row(page, "Server")
	read.add_child(_button("Read now", func() -> void:
		_status.text = "Reading..."
		await RemoteConfig.fetch(true)
		_status.text = "Read: %s" % BoardBackend.Status.keys()[RemoteConfig.status] if RemoteConfig.may_fetch() else "Not read: no key, or no online choice made"
		_refresh(), Vector2(150, 44)))
	read.add_child(_button("Apply now", func() -> void:
		RemoteConfig.apply()
		_status.text = "Applied: the next run (or the title) uses them; this run keeps its own"
		_refresh(), Vector2(150, 44)))
	read.add_child(_button("Clear simulated", func() -> void:
		RemoteConfig.clear_simulations()
		_status.text = "Simulated values cleared"
		_refresh(), Vector2(190, 44)))
	var keys := RemoteConfig.config.keys
	var pick := _row(page, "Key")
	_picker(pick, func() -> int: return keys.size(), func() -> int: return _remote_index, func(i: int) -> void:
		_remote_index = i
		_remote_value = 0, func() -> String: return keys[_remote_index].key if not keys.is_empty() else "-")
	var simulate := _row(page, "Simulate")
	_picker(simulate, func() -> int: return _remote_samples().size(), func() -> int: return _remote_value,
		func(i: int) -> void: _remote_value = i, _remote_sample_text, 420.0)
	simulate.add_child(_action_button("Simulate", func() -> void:
		var def := keys[_remote_index]
		var sample: String = _remote_samples()[_remote_value]
		RemoteConfig.simulate(def.key, sample)
		_status.text = "%s simulated: applies at the next safe point (Apply now, the title, a new run)" % def.key
		_refresh()))
	var list := _label("")
	list.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiSkin.set_text_style(list, Fonts.SMALL)
	page.add_child(list)
	_refreshers.append(func() -> void:
		var lines := PackedStringArray()
		lines.append("Status %s, read %s, %s" % [BoardBackend.Status.keys()[RemoteConfig.status],
			Time.get_datetime_string_from_unix_time(RemoteConfig.fetched_at) + " UTC" if RemoteConfig.fetched_at > 0 else "never",
			"GATED (another game version)" if RemoteConfig.gated else "for this version"])
		lines.append("key: in use / last read / simulated")
		for def in keys:
			var simulated := str(RemoteConfig.simulated.get(def.key, ""))
			lines.append("%s: %s / %s%s" % [def.key, RemoteConfig.shown_value(def, RemoteConfig.active), RemoteConfig.shown_value(def, RemoteConfig.latest),
				" / \"%s\"" % simulated if not simulated.is_empty() else ""])
		for line in RemoteConfig.ignored:
			lines.append("ignored %s" % line)
		lines.append("Kill switches: scores %s, statistics %s" % ["OFF" if RemoteConfig.scores_off() else "on", "OFF" if RemoteConfig.statistics_off() else "on"])
		list.text = "\n".join(lines))
	page.add_child(_note(_label("A run keeps the values it started with (saved with it). Simulated values are checked like the server's: an out-of-bounds one shows under \"ignored\".")))


## The sample picked, as the Simulate row shows it.
func _remote_sample_text() -> String:
	var samples := _remote_samples()
	var sample := samples[mini(_remote_value, samples.size() - 1)]
	return "\"%s\"" % sample.left(40) if not sample.is_empty() else "(unset: the game's own)"


## Sample values for the key picked in the Remote tab (as the server would send them; "" unsets).
func _remote_samples() -> PackedStringArray:
	var keys := RemoteConfig.config.keys
	if keys.is_empty():
		return PackedStringArray([""])
	var def := keys[_remote_index]
	var samples := PackedStringArray([""])
	match def.kind:
		RemoteKeyDef.Kind.NUMBER:
			for number in [def.min_number, def.default_number, (def.min_number + def.max_number) / 2.0, def.max_number, def.max_number * 2.0]:
				samples.append(str(snappedf(number, 0.01)))
		RemoteKeyDef.Kind.FLAG:
			samples.append_array(["true", "false"])
		RemoteKeyDef.Kind.TEXT:
			if def.hook == RemoteKeyDef.Hook.EVENT_NAME:
				samples.append("Nuit des Âmes" if def.language == "fr" else "Night of Souls")
			else:
				samples.append("Le Puits s'agite : la nuit des âmes commence ce soir." if def.language == "fr" else "The Well stirs: the night of souls begins tonight.")
			samples.append("x".repeat(def.max_length + 1))
		RemoteKeyDef.Kind.CONTENT_ID:
			for event in _game_content().floor_events:
				samples.append(String(event.id))
			if def.pool == RemoteKeyDef.Pool.CURSES_AND_EVENTS:
				for curse in _game_content().curses:
					samples.append(String(curse.id))
			samples.append("no_such_thing")
		RemoteKeyDef.Kind.DATE:
			var now := int(Time.get_unix_time_from_system())
			for days in [0, 2, -1]:
				samples.append(Time.get_date_string_from_unix_time(now + days * 86400))
		RemoteKeyDef.Kind.VERSION:
			samples.append_array([str(ProjectSettings.get_setting("application/config/version", "0")), "0.0.1", "99.0.0"])
	return samples


# --- Actions -------------------------------------------------------------------------------

## Builds floor `depth` (with that curse or event, or a plain one), then closes the panel.
func _go(depth: int, curse: CurseDef = null, event: FloorEventDef = null, plain: bool = false) -> void:
	DebugCheats.mark_run()
	close()
	_game.debug.enter_floor(maxi(depth, 1), curse, event, plain)


## Runs `action` and says it happened (the panel stays open). Whatever the panel does to the run
## makes it a debug run (DebugCheats.mark_run()): only the views (the Tools tab) don't.
## The next aura of the game on the hero (after the last: none).
func _next_aura() -> void:
	var auras := _game_content().cosmetics_of(CosmeticDef.Slot.AURA)
	_aura_index = _aura_index + 1 if _aura_index + 1 < auras.size() else -1
	var aura: AuraDef = auras[_aura_index] as AuraDef if _aura_index >= 0 else null
	_game.player.wear_aura(aura)
	_status.text = "Aura: %s" % (aura.display_name if aura else "none")


func _act(action: Callable, message: String) -> void:
	DebugCheats.mark_run()
	action.call()
	_status.text = message
	_refresh()


## Seals a dead-end room of this floor (not the hero's) behind a pact door, shown on the map.
func _debug_pact(pact_def: PactDef) -> void:
	var world: World = _game.world
	if world.pact or world.arena:
		_status.text = "This floor already has a pact door, or is a boss floor"
		return
	var here: Array[int] = []
	for i in world.map.rooms.size():
		if world.map.rooms[i].grow(1).has_point(world.map.world_to_cell(_game.player.global_position)):
			here.append(i)
	var index := PactRoom.find_room(world.map, world.rng, here, world.config().corridor_width + 3)
	if index < 0:
		_status.text = "No dead-end room on this floor"
		return
	DebugCheats.mark_run()
	var pact := world.spawn_pact(pact_def, world.map.rooms[index], {})
	pact.seen = true
	world.cells_changed.emit(world.fog.reveal_rect(pact.room.grow(1)))
	_status.text = "%s: see the map" % pact_def.display_name


## `trial_def` on this floor (not a boss floor, nor one with a pact door or a trial already):
## laid as a floor would lay it, away from the hero's room, its line shown.
func _debug_trial(trial_def: TrialDef) -> void:
	var world: World = _game.world
	if world.pact or world.arena or world.room_trial:
		_status.text = "This floor already has a trial or a pact door, or is a boss floor"
		return
	var here: Array[int] = [0]
	for i in world.map.rooms.size():
		if world.map.rooms[i].grow(1).has_point(world.map.world_to_cell(_game.player.global_position)):
			here.append(i)
	var planned := trial_def.plan(world, world.rng, here)
	if planned.is_empty():
		_status.text = "No room for it on this floor"
		return
	DebugCheats.mark_run()
	planned["trial"] = trial_def
	world.spawn_trial(planned, {})
	_game.hud.trial_line.watch(world)
	_status.text = "%s: see the map" % trial_def.display_name


## Down into the Deeps from here, as if the hero had fallen into a hole (not from a boss floor,
## the hidden floor or the Threshold: Abyss.can_take()).
func _enter_deeps() -> void:
	var player := _game.player
	if not _game.abyss.can_take(player):
		_status.text = "No Deeps from here"
		return
	DebugCheats.mark_run()
	close()
	_game.abyss.open(player, player.global_position)


## The hero to the middle of the next room of the map (the arena too, on a boss floor).
func _next_room() -> void:
	var world := _game.world
	if world.map.rooms.is_empty():
		return
	_room_index = posmod(_room_index + 1, world.map.rooms.size())
	DebugCheats.mark_run()
	_teleport(world.nearest_free_point(world.map.cell_to_world(world.map.heart(_room_index))))
	_status.text = "Room %d of %d" % [_room_index + 1, world.map.rooms.size()]


## A killing blow nothing turns away (god mode off first): the end of the run, or the Threshold
## with a second life.
func _kill_hero() -> void:
	var player := _game.player
	DebugCheats.mark_run()
	player.invincible = false
	player._invulnerable_time = 0.0
	player.hp = 1
	var hit := HitInfo.new()
	hit.amount = 999999
	hit.unavoidable = true
	close()
	player.take_hit(hit)


## The hero to `point` at once, the camera with him.
func _teleport(point: Vector2) -> void:
	_game.player.global_position = point
	_game.player.velocity = Vector2.ZERO
	_game.player.camera.reset_smoothing()


## The hero to the doorway of this floor's boss room (the warden wakes as he walks in), or to the
## middle of the gallery's hall.
func _to_boss_room() -> void:
	var world := _game.world
	var room := world.map.boss_room
	if room.size == Vector2i.ZERO:
		_status.text = "No boss room on this floor: try Next boss"
		return
	DebugCheats.mark_run()
	# Just outside one of its doorways (walking in starts the fight); in the middle of a room
	# without doors (the gallery's hall).
	var middle := world.map.cell_to_world(room.get_center())
	var target := middle
	var gates: Array[Vector2i] = world.arena.get_gate_cells() if world.arena else [] as Array[Vector2i]
	if not gates.is_empty():
		var gate := world.map.cell_to_world(gates[0])
		target = gate + (gate - middle).normalized() * world.map.tile_size * 1.5
	_teleport(world.nearest_free_point(target))
	_status.text = "Before the boss room"
	_refresh()


## The picked encounter beside the hero (walk up to it to open it).
func _place_encounter() -> void:
	var encounters := _game_content().encounters
	if encounters.is_empty():
		return
	var world := _game.world
	var def := encounters[_encounter_index]
	var cell := world.map.world_to_cell(world.find_open_point_near(_game.player.global_position + Vector2(0, -90), 50.0))
	DebugCheats.mark_run()
	world.spawn_encounter(def, cell)
	_status.text = "%s placed: walk up to it" % def.display_name


## The picked fragment of the past beside the hero (walk up to it to read it).
func _place_fragment() -> void:
	var list := _fragments()
	if list.is_empty():
		return
	var world := _game.world
	var pick: Array = list[_fragment_index]
	var cell := world.map.world_to_cell(world.find_open_point_near(_game.player.global_position + Vector2(0, 90), 50.0))
	DebugCheats.mark_run()
	world.spawn_fragment(pick[0], pick[1], cell)
	_status.text = "Fragment placed: walk up to it"


## The warden of this floor tells its story again (GameDebug.boss_story()).
func _boss_story() -> void:
	if not _game.debug.boss_story_ready():
		_status.text = "No warden standing on this floor: try Next boss"
		return
	close()
	_game.debug.boss_story()


## Every fragment of the past, each with its warden (the acts' bosses, the hidden floor's, the
## bottom of the Well's forms): what the Fragment row steps through.
func _fragments() -> Array[Array]:
	if not _fragment_list.is_empty():
		return _fragment_list
	var dungeon := _game_content().dungeon
	var bosses: Array[BossDef] = []
	for act in dungeon.acts:
		for boss in act.all_bosses():
			bosses.append(boss)
	if dungeon.hidden_floor and dungeon.hidden_floor.boss:
		bosses.append(dungeon.hidden_floor.boss)
	if dungeon.finale and dungeon.finale.boss:
		bosses.append_array(dungeon.finale.boss.forms())
	var seen := {}
	for boss in bosses:
		if boss == null or seen.has(boss) or boss.chronicle == null:
			continue
		seen[boss] = true
		for fragment in boss.chronicle.fragments:
			if fragment:
				_fragment_list.append([fragment, boss])
	return _fragment_list


func _fragment_text() -> String:
	var list := _fragments()
	if list.is_empty():
		return "-"
	var pick: Array = list[_fragment_index]
	return "%s: %s" % [(pick[1] as BossDef).display_name, (pick[0] as FragmentDef).title]


func _set_depth(depth: int) -> void:
	_depth = clampi(depth, 1, 99)
	_refresh()


func _next_boss_depth() -> int:
	var config := _game_content().dungeon
	for depth in range(_game.depth, _game.depth + 50):
		if config.boss_for_depth(depth):
			return depth
	return _game.depth


func _cycle_monster(step: int) -> void:
	var all := _all_monsters()
	if not all.is_empty():
		_monster_index = posmod(_monster_index + step, all.size())
	_refresh()


func _spawn(elite: bool) -> void:
	var all := _all_monsters()
	if all.is_empty():
		return
	var world := _game.world
	var at := world.find_open_point_near(_game.player.global_position, 90.0)
	var monster := world.spawn_monster(all[_monster_index], at)
	if elite:
		world.make_elite(monster)


func _spawn_ranked(rank: MonsterRankDef) -> void:
	var all := _all_monsters()
	if all.is_empty():
		return
	var world := _game.world
	var monster := world.spawn_monster(all[_monster_index], world.find_open_point_near(_game.player.global_position, 90.0))
	world.make_ranked(monster, rank)


func _give_epic_weapon() -> void:
	var weapons: Array[ItemDef] = []
	for item in _game_content().items:
		if item is WeaponDef:
			weapons.append(item)
	if weapons.is_empty():
		return
	var rolled := _game.world.roll_item(weapons.pick_random(), 50.0)
	_game.player.inventory.add(rolled)


## The Give row's lists: weapons, armor, consumables, tomes, runes, keys, perks, relics.
func _giveables() -> Array[Array]:
	if not _give_lists.is_empty():
		return _give_lists
	var content := _game_content()
	var items: Array[ItemDef] = content.items.duplicate()
	for item in content.locked_items + content.runes:
		if item and not items.has(item):
			items.append(item)
	var hidden_def := content.dungeon.hidden_floor
	if hidden_def and hidden_def.key and not items.has(hidden_def.key):
		items.append(hidden_def.key)
	var kinds := [
		["Weapon", func(thing: Resource) -> bool: return thing is WeaponDef],
		["Armor", func(thing: Resource) -> bool: return thing is EquipmentDef and not thing is WeaponDef],
		["Consumable", func(thing: Resource) -> bool: return thing is ConsumableDef],
		["Tome", func(thing: Resource) -> bool: return thing is SkillTomeDef],
		["Rune", func(thing: Resource) -> bool: return thing is RuneDef],
		["Key", func(thing: Resource) -> bool: return thing is KeyItemDef],
	]
	for kind: Array in kinds:
		var list: Array = items.filter(kind[1])
		if not list.is_empty():
			_give_lists.append([kind[0], list])
	for rarity: Array in [[PerkDef.Rarity.COMMON, "Perk"], [PerkDef.Rarity.RARE, "Relic"]]:
		var perks: Array = content.perks.filter(func(perk: PerkDef) -> bool: return perk and perk.rarity == rarity[0])
		if not perks.is_empty():
			_give_lists.append([rarity[1], perks])
	return _give_lists


func _cycle_give(kind_step: int, step: int) -> void:
	var lists := _giveables()
	if lists.is_empty():
		return
	if kind_step != 0:
		_give_category = posmod(_give_category + kind_step, lists.size())
		_give_index = 0
	var list: Array = lists[_give_category][1]
	_give_index = posmod(_give_index + step, list.size())
	_refresh()


## The picked thing to the hero: worn or put in the bag (on the ground beside him when it is
## full), a perk or relic taken.
func _give() -> void:
	var lists := _giveables()
	if lists.is_empty():
		return
	var thing: Resource = lists[_give_category][1][_give_index]
	var player := _game.player
	DebugCheats.mark_run()
	if thing is PerkDef:
		var perk := thing as PerkDef
		if not player.perks.can_take(perk):
			_status.text = "Already at its most"
			return
		player.perks.add(perk)
		_status.text = "%s taken" % tr(perk.display_name)
		return
	var item := thing as ItemDef
	if not player.pack.pick_up(item):
		_game.world.spawn_item(item, _game.world.find_open_point_near(player.global_position, 40.0))
	_status.text = "%s given" % tr(item.display_name)


## Every monster of the game, then every boss (the gallery's Everything: the acts', the hidden
## floor's, the Deeps', the bottom of the Well's).
func _all_monsters() -> Array[MonsterDef]:
	if _monsters.is_empty():
		var scopes := DebugGallery.scopes(_game_content())
		_monsters = scopes.back().monsters.duplicate()
	return _monsters


func _refresh() -> void:
	if _game == null or _depth_label == null:
		return
	_depth_label.text = "Depth %d" % _depth
	var all := _all_monsters()
	_monster_label.text = all[_monster_index].display_name if not all.is_empty() else "-"
	var lists := _giveables()
	if not lists.is_empty():
		var list: Array = lists[_give_category][1]
		var thing: Resource = list[_give_index]
		_give_label.text = "%s: %s (%d/%d)" % [lists[_give_category][0], thing.get("display_name"), _give_index + 1, list.size()]
	for refresher in _refreshers + _shape_refreshers:
		refresher.call()


func _game_content() -> ContentDB:
	return _game.content


# --- Widgets -------------------------------------------------------------------------------

## A row of `page`: its name on the left (none when empty), its buttons after it, wrapping
## under one another (never under the name).
func _row(page: Control, heading: String) -> HFlowContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	page.add_child(line)
	var label := _label(heading)
	label.custom_minimum_size.x = HEADING_WIDTH
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.add_theme_color_override("font_color", UiSkin.GOLD)
	line.add_child(label)
	var row := HFlowContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 4)
	line.add_child(row)
	return row


func _button(text: String, action: Callable, min_size := BUTTON_SIZE) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", Fonts.BODY)
	button.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		action.call())
	return button


## A row's last button, the one that does what the row's choices set up ("> Build this floor").
func _action_button(text: String, action: Callable) -> Button:
	var button := _button("> %s" % text, action, Vector2(200, 44))
	button.name = text.to_pascal_case()
	return button


## An on / off button: "Name: ON" and pressed while on.
func _toggle(row: Control, text: String, is_on: Callable, set_on: Callable) -> Button:
	var button := _button(text, func() -> void:
		set_on.call(not is_on.call())
		_refresh())
	button.toggle_mode = true
	button.name = text.to_pascal_case().replace("&", "")
	_refreshers.append(func() -> void:
		var on: bool = is_on.call()
		button.text = "%s: %s" % [text, "ON" if on else "off"]
		button.set_pressed_no_signal(on))
	row.add_child(button)
	return button


## A button that steps through `steps` (wrapping): "Name x5", pressed while not on the first.
func _stepper(row: Control, text: String, steps: Array[float], current: Callable, set_step: Callable) -> Button:
	var button := _button(text, func() -> void:
		set_step.call(DebugCheats.next_step(current.call(), steps))
		_refresh())
	button.toggle_mode = true
	button.name = text.to_pascal_case()
	_refreshers.append(func() -> void:
		var step: int = current.call()
		button.text = "%s %s" % [text, DebugCheats.step_text(steps, step)]
		button.set_pressed_no_signal(step > 0))
	row.add_child(button)
	return button


## One of a row's choices: pressed while it is the one picked. `refreshers`: the list that keeps it
## up to date (null: the panel's).
func _choice(row: Control, text: String, is_picked: Callable, pick: Callable, refreshers: Variant = null) -> Button:
	var button := _button(text, func() -> void:
		pick.call()
		_refresh())
	button.toggle_mode = true
	var list: Array[Callable] = refreshers if refreshers != null else _refreshers
	list.append(func() -> void: button.set_pressed_no_signal(is_picked.call()))
	row.add_child(button)
	return button


## "<", the one picked, ">": steps through `count` things (wrapping). `index` and `set_index` read
## and write the pick, `text` names it.
func _picker(row: Control, count: Callable, index: Callable, set_index: Callable, text: Callable, width := 520.0) -> void:
	row.add_child(_button("<", func() -> void:
		set_index.call(posmod(int(index.call()) - 1, maxi(int(count.call()), 1)))
		_refresh(), Vector2(54, 44)))
	var label := _label("")
	label.custom_minimum_size.x = width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	row.add_child(label)
	row.add_child(_button(">", func() -> void:
		set_index.call(posmod(int(index.call()) + 1, maxi(int(count.call()), 1)))
		_refresh(), Vector2(54, 44)))
	_refreshers.append(func() -> void: label.text = text.call())


## `label` as a dim note under a tab's rows.
func _note(label: Label) -> Label:
	UiSkin.set_text_style(label, Fonts.BODY)
	label.add_theme_color_override("font_color", UiSkin.DIM)
	return label


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size.y = BUTTON_SIZE.y
	label.add_theme_font_size_override("font_size", Fonts.BODY)
	return label
