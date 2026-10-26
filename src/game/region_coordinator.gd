class_name RegionCoordinator
extends Node
## One loaded authored place, one retained hero. Validate/commit the destination snapshot
## before unloading the source. Requests from physics are deferred and carry a region ticket.
## This is a synchronous bounded prototype, not seamless or background sector streaming.

signal region_changed(region: RegionDef)
signal travel_failed(reason: Failure)
enum Failure { NONE, CONFIGURATION, DESTINATION, LAYOUT, STATE, SAVE }

const STAIRS := preload("res://src/entities/stairs/stairs.tscn")
var session: GameSession
var atlas: RegionAtlas
var last_failure := Failure.NONE
var current_id := ""
var _content: ContentDB
var _save: CampaignSave
var _loot: RegionLoot
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
	session = context
	atlas = places
	_content = content
	_save = storage
	_loot = RegionLoot.new(context.world)
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
	last_failure = Failure.NONE
	return true


func request_travel(link_id: String) -> void:
	if _ticket:
		_requested.call_deferred(link_id, _ticket)


func _requested(link_id: String, ticket: RefCounted) -> void:
	if ticket == _ticket and is_inside_tree():
		travel(link_id)


func _capture() -> CampaignState:
	if session == null or current_id.is_empty() or session.campaign == null:
		_fail(Failure.CONFIGURATION)
		return null
	var candidate := CampaignState.from_data(session.campaign.to_data())
	if candidate == null or not candidate.hero.capture(session.character) \
			or not _loot.capture(candidate.world_state.regions[current_id]):
		_fail(Failure.STATE)
		return null
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
	for object_state in state.objects.values():
		if not map.is_ground(map.world_to_cell(object_state.position)):
			return _fail(Failure.LAYOUT)
	if not definition.safe_position(map, at, session.character.radius):
		at = map.cell_to_world(map.start_cell)
	if not definition.safe_position(map, at, session.character.radius):
		return _fail(Failure.LAYOUT)
	candidate.hero.region_id = definition.id
	candidate.hero.position = at
	return true


func _activate(candidate: CampaignState, definition: RegionDef, entry: String) -> void:
	_busy = true
	_ticket = RefCounted.new()
	_loot.unbind()
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
