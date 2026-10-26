class_name RegionProof
extends Node2D
## Standalone, non-canon region proof. Empty checkpoint_path means memory only. Tests provide
## isolated paths; the current run/profile are never imported, saved or erased by this scene.

const PLAYER := preload("res://src/entities/player/player.tscn")
@export var atlas: RegionAtlas
@export var content: ContentDB
@export var checkpoint_path := ""
var session := GameSession.new()
var started := false
@onready var world: World = $World
@onready var coordinator: RegionCoordinator = $Coordinator
@onready var _title: Label = $Overlay/Title
@onready var _hint: Label = $Overlay/Hint
@onready var _joystick: TouchJoystick = $Overlay/Joystick


func _ready() -> void:
	_hint.text = tr("Walk onto the stairs to change region.")
	InputDevice.changed.connect(_input_changed)
	_input_changed()
	if atlas == null or not atlas.valid() or content == null:
		_failed()
		return
	var hero := PLAYER.instantiate() as Player
	hero.world = world
	hero.setup(content.player)
	session.world = world
	session.character = hero
	var store: CampaignSave
	var snapshot: CampaignState
	if not checkpoint_path.is_empty():
		store = CampaignSave.new(checkpoint_path)
		snapshot = store.load_state()
		if snapshot == null and store.last_failure != CampaignSave.Failure.MISSING:
			hero.free()
			_failed()
			return
	if snapshot == null:
		snapshot = CampaignState.create(hero, atlas.start_region)
	coordinator.region_changed.connect(_region_changed)
	started = session.attach_campaign(snapshot) and coordinator.configure(session, atlas, content, store) and coordinator.start()
	if not started:
		if hero.get_parent() == null:
			hero.free()
		_failed()


func _region_changed(region: RegionDef) -> void:
	_title.text = tr(region.display_name)


func _input_changed() -> void:
	_joystick.visible = InputDevice.uses_touch()
	_joystick.fixed = Settings.fixed_joystick
	_joystick.max_distance = TouchJoystick.BASE_DISTANCE * Settings.controls_scale


func _failed() -> void:
	_title.text = tr("The region proof could not start.")


func _exit_tree() -> void:
	session.close()
