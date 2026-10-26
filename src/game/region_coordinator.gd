class_name RegionCoordinator
extends Node
## One loaded authored place, one retained hero. Validate/commit the destination snapshot
## before unloading the source. Requests from physics are deferred and carry a region ticket.
## This is a synchronous bounded prototype, not seamless or background sector streaming.

signal region_changed(region: RegionDef)
signal travel_failed(reason: Failure)
enum Failure { NONE, CONFIGURATION, DESTINATION, LAYOUT, STATE, SAVE, SETTLING }

const STAIRS := preload("res://src/entities/stairs/stairs.tscn")
var session: GameSession
var atlas: RegionAtlas
var last_failure := Failure.NONE
var current_id := ""
var _content: ContentDB
var _save: CampaignSave
var _loot: RegionLoot
var _population: RegionPopulation
var _ticket: RefCounted
var _busy := false


func configure(context: GameSession, places: RegionAtlas, content: ContentDB, storage: CampaignSave = null) -> bool:
	if context == null or context.expedition != null or context.campaign == null \
			or not is_instance_valid(context.world) or not context.world.is_node_ready() \
			or not is_instance_valid(context.character) or context.character.is_dead \
			or context.world.global_transform != Transform2D.IDENTITY or places == null or not places.valid() \
			or content == null or CampaignState.from_data(context.campaign.to_data()) == null:
		return _fail(Failure.CONFIGURATION)
	if _loot:
		_loot.close()
	if _population:
		_population.close()
	session = context
	atlas = places
	_content = content
	_save = storage
	_loot = RegionLoot.new(context.world)
	_population = RegionPopulation.new(context.world)
	_ticket = null
	current_id = ""
	return true


func start() -> bool:
	if session == null or not current_id.is_empty():
		return _fail(Failure.CONFIGURATION)
	var candidate := CampaignState.from_data(session.campaign.to_data())
	if candidate == null:
		return _fail(Failure.STATE)
	var definition := atlas.find(candidate.hero.region_id)
	if definition == null:
		return _fail(Failure.DESTINATION)
	var entry: String = atlas.start_entry if definition.id == atlas.start_region else definition.entries.keys()[0]
	if not _prepare(candidate, definition, entry, candidate.hero.position):
		return false
	if not candidate.hero.restore(session.character):
		return _fail(Failure.STATE)
	_activate(candidate, definition, entry)
	return true


## The saved position is replaced by the destination's explicit entry. No healing or
## floor-start passive reward is granted merely by crossing a region boundary.
func travel(link_id: String) -> bool:
	if session == null or _busy or current_id.is_empty() or session.character.is_dead:
		return _fail(Failure.CONFIGURATION)
	var origin := atlas.find(current_id)
	if origin == null or not origin.valid():
		return _fail(Failure.DESTINATION)
	var selected: RegionLinkDef
	for link in origin.links:
		if link.id == link_id:
			selected = link
	if selected == null:
		return _fail(Failure.DESTINATION)
	var destination := atlas.find(selected.destination)
	if destination == null or not destination.valid() or not destination.entries.has(selected.entry):
		return _fail(Failure.DESTINATION)
	var candidate := _capture()
	if candidate == null:
		return false
	var map := destination.make_map(selected.entry)
	if not _prepare(candidate, destination, selected.entry, map.cell_to_world(map.start_cell)):
		return false
	if _save and not _save.commit(candidate):
		return _fail(Failure.SAVE)
	_activate(candidate, destination, selected.entry)
	return true


func checkpoint() -> bool:
	var candidate := _capture()
	if candidate == null:
		return false
	if _save == null or not _save.commit(candidate):
		return _fail(Failure.SAVE)
	# Rebind the tracker to the newly committed owner without spawning duplicate pickups.
	session.campaign.revision = candidate.revision
	session.campaign.hero = candidate.hero
	session.campaign.world_state.regions[current_id] = candidate.world_state.regions[current_id]
	_loot.set_state(session.campaign.world_state.regions[current_id])
	_population.set_state(session.campaign.world_state.regions[current_id])
	last_failure = Failure.NONE
	return true


func request_travel(link_id: String) -> void:
	if _ticket:
		_requested.call_deferred(link_id, _ticket)


func _requested(link_id: String, ticket: RefCounted) -> void:
	if ticket == _ticket and is_inside_tree():
		if not session.world.spawns.is_settled():
			var retry := _requested.bind(link_id, ticket)
			if not get_tree().process_frame.is_connected(retry):
				get_tree().process_frame.connect(retry, CONNECT_ONE_SHOT)
			return
		travel(link_id)


func _capture() -> CampaignState:
	if session == null or current_id.is_empty() or session.campaign == null:
		_fail(Failure.CONFIGURATION)
		return null
	if _busy or not session.world.spawns.is_settled():
		_fail(Failure.SETTLING)
		return null
	var candidate := CampaignState.from_data(session.campaign.to_data())
	if candidate == null or not candidate.hero.capture(session.character) \
			or not _loot.capture(candidate.world_state.regions[current_id]) \
			or not _population.capture(candidate.world_state.regions[current_id]):
		_fail(Failure.STATE)
		return null
	_normalize_loot(candidate.world_state.regions[current_id], atlas.find(current_id))
	return candidate


func _prepare(candidate: CampaignState, definition: RegionDef, entry: String, at: Vector2) -> bool:
	if not definition.valid() or not definition.entries.has(entry):
		return _fail(Failure.DESTINATION)
	var state: RegionState = candidate.world_state.regions.get(definition.id)
	if state == null:
		state = RegionState.new()
		state.id = definition.id
		candidate.world_state.regions[state.id] = state
	if state.initialized:
		if state.layout_version != definition.layout_version or state.layout_stamp != definition.stamp():
			return _fail(Failure.LAYOUT)
	else:
		state.layout_version = definition.layout_version
		state.layout_stamp = definition.stamp()
		state.initialized = true
		for spawn in definition.items:
			var object_state := RegionObjectState.create("authored:" + definition.id + "/" + spawn.id, spawn.item,
				(Vector2(spawn.cell) + Vector2(0.5, 0.5)) * definition.tile_size)
			state.objects[object_state.id] = object_state
	var map := definition.make_map(entry)
	if not state.population_initialized:
		if not RegionPopulation.initialize(state, definition, _content):
			return _fail(Failure.STATE)
	elif state.population_stamp != definition.population_stamp():
		return _fail(Failure.LAYOUT)
	_normalize_loot(state, definition)
	for chest in state.chests.values():
		if not map.is_ground(chest.cell):
			return _fail(Failure.LAYOUT)
	for monster in state.monsters.values():
		if not monster.dead and not map.is_ground(map.world_to_cell(monster.position)):
			return _fail(Failure.LAYOUT)
		var accepted: Array[EliteAffixDef] = []
		for affix in monster.affixes:
			if not affix.fits(monster.definition, definition.combat_depth, accepted):
				return _fail(Failure.STATE)
			accepted.append(affix)
	if not _arrival_free(definition, map, state, at):
		at = _nearest_arrival(definition, map, state, map.cell_to_world(map.start_cell))
	if not _arrival_free(definition, map, state, at):
		return _fail(Failure.LAYOUT)
	candidate.hero.region_id = definition.id
	candidate.hero.position = at
	return true


func _normalize_loot(state: RegionState, definition: RegionDef) -> void:
	var map := definition.make_map(definition.entries.keys()[0])
	for item in state.objects.values():
		if not map.is_ground(map.world_to_cell(item.position)):
			item.position = definition.nearest_ground(map, item.position)
	for coin in state.gold.values():
		if not map.is_ground(map.world_to_cell(coin.position)):
			coin.position = definition.nearest_ground(map, coin.position)


func _arrival_free(definition: RegionDef, map: DungeonMap, state: RegionState, at: Vector2) -> bool:
	var radius := session.character.radius
	if not definition.safe_position(map, at, radius):
		return false
	for chest in state.chests.values():
		if at.distance_to(map.cell_to_world(chest.cell)) < radius + Chest.SIZE:
			return false
	for monster in state.monsters.values():
		# A conservative bound includes any rank's larger collision body.
		var room: float = monster.definition.radius * (maxf(1.0, monster.rank.scale) if monster.rank else 1.0)
		if not monster.dead and at.distance_to(monster.position) < radius + room:
			return false
	return true


func _nearest_arrival(definition: RegionDef, map: DungeonMap, state: RegionState, desired: Vector2) -> Vector2:
	var best := Vector2.INF
	var distance := INF
	for y in map.height:
		for x in map.width:
			var candidate := map.cell_to_world(Vector2i(x, y))
			if _arrival_free(definition, map, state, candidate) and desired.distance_squared_to(candidate) < distance:
				best = candidate
				distance = desired.distance_squared_to(candidate)
	return best


func _activate(candidate: CampaignState, definition: RegionDef, entry: String) -> void:
	_busy = true
	_ticket = RefCounted.new()
	_loot.unbind()
	_population.unbind()
	session.attach_campaign(candidate)
	var world := session.world
	var hero := session.character
	world.player = hero  # build_floor keeps this very node
	world.difficulty = _content.default_difficulty
	world.rng.seed = definition.visual_seed
	world.build_floor(definition.combat_depth, _content, null, RegionFloorKind.new(definition, entry))
	world.attach_player(hero)
	hero.stand_up()
	hero.stop_motion()
	hero.controls.cancel_actions()
	hero.controls.mute_presses()
	hero.global_position = candidate.hero.position
	hero.reset_safe_position()
	hero.camera.reset_smoothing()
	current_id = definition.id
	_loot.bind(candidate.world_state.regions[current_id])
	_population.bind(candidate.world_state.regions[current_id])
	for link in definition.links:
		var stairs := STAIRS.instantiate() as Stairs
		stairs.texture = definition.biome.theme.stairs_texture()
		stairs.position = world.map.cell_to_world(link.cell)
		stairs.reached.connect(_portal_reached.bind(link.id, _ticket))
		world.add_entity(stairs)
	last_failure = Failure.NONE
	_busy = false
	region_changed.emit(definition)


func _portal_reached(link_id: String, ticket: RefCounted) -> void:
	if ticket == _ticket:
		request_travel(link_id)


func _fail(reason: Failure) -> bool:
	last_failure = reason
	travel_failed.emit(reason)
	return false


func _exit_tree() -> void:
	_ticket = null
	if _loot:
		_loot.close()
	if _population:
		_population.close()
