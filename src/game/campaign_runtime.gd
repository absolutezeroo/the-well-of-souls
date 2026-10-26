class_name CampaignRuntime
extends Node
## The public solo campaign's lifecycle. The shell supplies storage explicitly, while tests
## use isolated paths. All autosaves and death recovery wait for native reward settlements.

signal journal_requested
signal changed
signal save_failed(reason: CampaignSave.Failure)
signal recovered_from_backup
signal returned_to_refuge

const PLAYER := preload("res://src/entities/player/player.tscn")
@export var content: ContentDB
@export var definition: CampaignDef
var session := GameSession.new()
var storage: CampaignSave
var progress: CampaignProgress
var started := false
var _autosave_left := 0.0
var _recovering := false
var interactor: Interactor
@onready var world: World = $World
@onready var regions: RegionCoordinator = $Regions


func begin(path: String, resume: bool) -> bool:
	if started or path.is_empty() or content == null or definition == null or not definition.valid():
		return false
	storage = CampaignSave.new(path)
	var state := storage.load_state()
	var backup := storage.recovered
	if (resume and state == null) or (not resume and (state != null or storage.last_failure != CampaignSave.Failure.MISSING)):
		return false
	var hero := PLAYER.instantiate() as Player
	hero.world = world
	hero.setup(content.player)
	session.world = world
	session.character = hero
	if state == null:
		var start := definition.atlas.find(definition.atlas.start_region)
		hero.position = start.make_map(definition.atlas.start_entry).cell_to_world(start.entries[definition.atlas.start_entry])
		state = CampaignState.create(hero, start.id)
	if not session.attach_campaign(state) or not regions.configure(session, definition.atlas, content, storage) or not regions.start():
		if hero.get_parent() == null:
			hero.free()
		return false
	if not regions.checkpoint():
		return false
	progress = CampaignProgress.new(regions, definition)
	regions.region_changed.connect(_place_changed)
	interactor = Interactor.new()
	add_child(interactor)
	_bind_hero()
	_build_refuge()
	started = true
	_autosave_left = definition.autosave_seconds
	if backup:
		recovered_from_backup.emit()
	return true


func save() -> bool:
	if not started or session.character.is_dead or _recovering:
		return false
	if not regions.checkpoint():
		if regions.last_failure != RegionCoordinator.Failure.SETTLING:
			save_failed.emit(storage.last_failure)
		return false
	_autosave_left = definition.autosave_seconds
	return true


func rest() -> bool:
	if not started or _recovering or regions.current_id != definition.refuge_region:
		return false
	if not regions.rest(definition.refuge_region, definition.refuge_entry):
		save_failed.emit(storage.last_failure)
		return false
	changed.emit()
	return true


## Recovery stays explicitly retryable after an I/O failure; it never reloads an older hero
## or erases the campaign. The shell freezes the world and offers Retry until it succeeds.
func recover() -> bool:
	if not started or not session.character.is_dead or not world.spawns.is_settled():
		return false
	if not regions.recover(definition.refuge_region, definition.refuge_entry):
		save_failed.emit(storage.last_failure)
		return false
	_recovering = false
	_autosave_left = definition.autosave_seconds
	returned_to_refuge.emit()
	return true


func _bind_hero() -> void:
	var hero := session.character
	if interactor:
		interactor.player = hero
	if not hero.died.is_connected(_died):
		hero.died.connect(_died)
		hero.leveled_up.connect(_level_changed)


func _place_changed(_region: RegionDef) -> void:
	_bind_hero()
	_build_refuge()
	changed.emit()


func _build_refuge() -> void:
	if regions.current_id != definition.refuge_region:
		return
	var keeper := Interactable.new()
	keeper.position = world.map.cell_to_world(definition.keeper_cell)
	keeper.verb = "Speak"  # i18n
	var image := Sprite2D.new()
	image.texture = content.narrative.shrine_speaker.figure
	image.region_enabled = true
	image.region_rect = Rect2(0, 0, 16, 16)
	image.scale = Vector2(2, 2)
	image.position.y = -12
	keeper.add_child(image)
	keeper.used.connect(_keeper_used)
	world.add_entity(keeper)
	var resting := Interactable.new()
	resting.position = world.map.cell_to_world(definition.rest_cell)
	resting.verb = "Rest"  # i18n
	var lamp := Sprite2D.new()
	lamp.texture = load("res://assets/props/lantern.png")
	lamp.region_enabled = true
	lamp.region_rect = Rect2(0, 0, 16, 16)
	lamp.scale = Vector2(2, 2)
	lamp.position.y = -12
	resting.add_child(lamp)
	resting.used.connect(_rest_used)
	world.add_entity(resting)


func _keeper_used(_hero: Player) -> void:
	journal_requested.emit()


func _rest_used(_hero: Player) -> void:
	# Interaction runs during physics: defer any region rebuild outside the physics flush.
	rest.call_deferred()


func _level_changed(_level: int) -> void:
	changed.emit()


func _died(_hero: Actor) -> void:
	_recovering = true
	# Actor.die() still owns a settlement while it emits. Wait without capturing a Node in
	# a lambda, and invalidate the continuation automatically when this runtime is freed.
	_recover_when_settled.call_deferred()


func _recover_when_settled() -> void:
	if not is_inside_tree() or not _recovering:
		return
	if not world.spawns.is_settled():
		get_tree().process_frame.connect(_recover_when_settled, CONNECT_ONE_SHOT)
		return
	recover()


func _process(delta: float) -> void:
	if not started or _recovering or session.character.is_dead or get_tree().paused:
		return
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		_autosave_left = definition.autosave_seconds
		save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and started:
		if session.character.is_dead:
			recover()
		else:
			save()


func _exit_tree() -> void:
	session.close()
