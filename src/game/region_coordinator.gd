class_name RegionCoordinator
extends Node
## One loaded authored place, one retained hero. Validate/commit the destination snapshot
## before unloading the source. Requests from physics are deferred and carry a region ticket.
## This is a synchronous bounded prototype, not seamless or background sector streaming.

signal region_changed(region: RegionDef)
signal travel_failed(reason: Failure)
enum Failure { NONE, CONFIGURATION, DESTINATION, LAYOUT, STATE, SAVE, SETTLING }

const PLAYER := preload("res://src/entities/player/player.tscn")
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


## Copy the settled live state for an explicit campaign transaction. Callbacks edit only
## this copy; a failed save leaves the live world and the previous snapshot untouched.
func snapshot() -> CampaignState:
	return _capture()


func commit_snapshot(candidate: CampaignState) -> bool:
	if candidate == null or session == null or _busy or not session.world.spawns.is_settled() \
			or candidate.id != session.campaign.id or candidate.revision != session.campaign.revision \
			or candidate.hero == null or candidate.world_state == null \
			or candidate.hero.id != session.campaign.hero.id or candidate.world_state.id != session.campaign.world_state.id \
			or candidate.hero.region_id != current_id or CampaignState.from_data(candidate.to_data()) == null:
		return _fail(Failure.STATE)
	if _save and not _save.commit(candidate):
		return _fail(Failure.SAVE)
	session.attach_campaign(candidate)
	_loot.set_state(candidate.world_state.regions[current_id])
	_population.set_state(candidate.world_state.regions[current_id])
	last_failure = Failure.NONE
	return true


## A refuge rest heals the living hero and renews only dead eligible authored enemies in
## other places. Ground loot, chests, living thieves, unique guardians and quest facts survive.
func rest(region_id: String, entry: String) -> bool:
	if session == null or session.character.is_dead or current_id != region_id:
		return _fail(Failure.CONFIGURATION)
	return _return_to_refuge(region_id, entry, false)


## Called after the death settlement, never from the middle of Actor.die().
func recover(region_id: String, entry: String) -> bool:
	if session == null or not session.character.is_dead:
		return _fail(Failure.CONFIGURATION)
	return _return_to_refuge(region_id, entry, true)


func _return_to_refuge(region_id: String, entry: String, from_death: bool) -> bool:
	var definition := atlas.find(region_id)
	if definition == null or not definition.monsters.is_empty() or not definition.entries.has(entry):
		return _fail(Failure.DESTINATION)
	var candidate := _capture(from_death)
	if candidate == null:
		return false
	if not from_death:
		for saved_region in candidate.world_state.regions.values():
			if saved_region.id == current_id or not saved_region.population_initialized:
				continue
			var region_def := atlas.find(saved_region.id)
			if region_def == null or saved_region.population_stamp != region_def.population_stamp():
				return _fail(Failure.LAYOUT)
			var initial := RegionState.new()
			if not RegionPopulation.initialize(initial, region_def, _content):
				return _fail(Failure.STATE)
			for spawn in region_def.monsters:
				var key := "monster:" + region_def.id + "/" + spawn.id
				if spawn.renew_on_rest and saved_region.monsters.has(key) and saved_region.monsters[key].dead:
					saved_region.monsters[key] = initial.monsters[key]
	var map := definition.make_map(entry)
	if not _prepare(candidate, definition, entry, map.cell_to_world(map.start_cell)):
		return false
	var data := candidate.hero.to_data()
	data.player.hp = session.character.get_max_hp()
	candidate.hero = CharacterState.from_data(data)
	var replacement: Player
	if candidate.hero == null:
		return _fail(Failure.STATE)
	if from_death:
		replacement = PLAYER.instantiate() as Player
		replacement.world = session.world
		replacement.setup(_content.player)
		candidate.hero.restore(replacement)
		replacement.hp = replacement.get_max_hp()
		replacement.position = candidate.hero.position
		candidate.hero.capture(replacement)
	if _save and not _save.commit(candidate):
		if replacement:
			replacement.free()
		return _fail(Failure.SAVE)
	if from_death:
		# Keep the old node alive until listeners bind the replacement. World.clear_floor()
		# must not free it before the HUD has disconnected its old signal subscriptions.
		var previous := session.character
		previous.get_parent().remove_child(previous)
		add_child(previous)
		session.character = replacement
		_activate(candidate, definition, entry)
		previous.queue_free()
	else:
		_activate(candidate, definition, entry)
		session.character.hp = session.character.get_max_hp()
		session.character.health_changed.emit(session.character.hp, session.character.get_max_hp())
	return true


func _capture(from_death: bool = false) -> CampaignState:
	if session == null or current_id.is_empty() or session.campaign == null:
		_fail(Failure.CONFIGURATION)
		return null
	if _busy or not session.world.spawns.is_settled():
		_fail(Failure.SETTLING)
		return null
	var candidate := CampaignState.from_data(session.campaign.to_data())
	if candidate == null or not (candidate.hero.capture_recovery(session.character) if from_death else candidate.hero.capture(session.character)) \
			or not _loot.capture(candidate.world_state.regions[current_id]) \
			or not _population.capture(candidate.world_state.regions[current_id]):
		_fail(Failure.STATE)
		return null
	candidate.world_state.regions[current_id].explored = session.world.fog.explored.duplicate()
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
	if not state.explored.is_empty() and state.explored.size() != map.width * map.height:
		return _fail(Failure.LAYOUT)
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
	hero.camera.make_current()
	hero.camera.reset_smoothing()
	current_id = definition.id
	_loot.bind(candidate.world_state.regions[current_id])
	_population.bind(candidate.world_state.regions[current_id])
	var seen := candidate.world_state.regions[current_id].explored
	if not seen.is_empty():
		world.fog.explored = seen.duplicate()
	for link in definition.links:
		var stairs := STAIRS.instantiate() as Stairs
		stairs.texture = definition.biome.theme.stairs_texture()
		stairs.position = world.map.cell_to_world(link.cell)
		stairs.reached.connect(_portal_reached.bind(link.id, _ticket))
		world.add_entity(stairs)
	world.map_reset.emit()  # exploration and persistent entities now match the rebuilt map
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
