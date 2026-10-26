class_name VillageHub
extends Node2D
## Kagari between expeditions: walking, contextual services and safe launch/resume at the Well.
## The hub has no live RunState. Its menu requests go through VillageProgress or run launchers.

const SCENE := "res://src/village/village_hub.tscn"
const GAME_SCENE := "res://src/game/game.tscn"
const TITLE_SCENE := "res://src/ui/title/title_screen.tscn"
## A title-screen daily request still requires walking to the Well to begin.
static var daily_requested := false

@export var content: ContentDB
@export var def: VillageDef

## Fixed interaction registry: no group scans or temporary arrays while walking.
class Spot extends RefCounted:
	var at: Vector2
	var action: StringName
	var label: String
	var resident: VillageResidentDef

var walker: VillageWalker
var view: VillageView
var panel: VillagePanel
var difficulty_panel: DifficultyPanel
var oath_panel: OathPanel
var shrine: ShrinePanel
var daily_dialog: DailyDialog
var cloud_conflict: CloudConflictDialog
var spots: Array[Spot] = []
var focus: Spot
var _modals: Array[Control] = []
var _joystick: TouchJoystick
var _touch: ActionButton
var _prompt: Label
var _objective: Label
var _hud: Control
var _was_down := true
var _blocked := false
var _leaving := false
var _new_daily := false
var _memorial_index := 0
var _resident: VillageResidentDef


func _ready() -> void:
	get_tree().paused = false
	Game.resume_requested = false
	Game.daily_requested = false
	Sfx.bank = content.sounds
	Sfx.play_music(Sfx.bank.title_music)
	QuestBoard.pay_finished(content.quests)
	view = VillageView.new()
	view.def = def
	view.content = content
	add_child(view)
	walker = VillageWalker.new()
	walker.def = def
	walker.hero = content.player
	walker.position = def.spawn
	view.walker = walker
	view.dressing.add_child(walker)
	_add_spot(def.well + Vector2(0, 34), &"well", tr("The Well"))
	_add_spot(def.shrine, &"shrine", tr("Shrine"))
	_add_spot(def.memorial, &"memorial", tr("Court of the Nameless"))
	for resident in def.residents:
		_add_spot(resident.position, &"resident", tr(resident.speaker.display_name), resident)
	_build_ui()
	Profile.changed.connect(_refresh)
	InputDevice.changed.connect(_device_changed)
	CloudSave.conflict_found.connect(_ask_cloud_conflict)
	if CloudSave.state == CloudSave.Step.CONFLICT:
		_ask_cloud_conflict.call_deferred()
	_refresh()
	_device_changed()


func _add_spot(at: Vector2, action: StringName, label_text: String, resident: VillageResidentDef = null) -> void:
	var spot := Spot.new()
	spot.at = at
	spot.action = action
	spot.label = label_text
	spot.resident = resident
	spots.append(spot)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	var header := VBoxContainer.new()
	header.position = Vector2(24, 20)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(header)
	header.add_child(UiSkin.label(tr(def.display_name), Fonts.TITLE, UiSkin.GOLD))
	_objective = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	_objective.custom_minimum_size.x = 580
	header.add_child(_objective)
	var menu := MenuWindow.button(tr("Menu"), Fonts.BODY, 52)
	menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu.offset_left = -180
	menu.offset_right = -24
	menu.offset_top = 24
	menu.pressed.connect(_open_menu)
	_hud.add_child(menu)
	_joystick = TouchJoystick.new()
	_joystick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(_joystick)
	_prompt = UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -50
	_prompt.offset_bottom = -20
	_hud.add_child(_prompt)
	_touch = ActionButton.new()
	_touch.action = &"interact"
	_touch.label = "!"
	_hud.add_child(_touch)
	_hud.resized.connect(_layout)
	_layout.call_deferred()
	panel = VillagePanel.new()
	layer.add_child(panel)
	panel.picked.connect(_choose)
	_modals.append(panel)
	difficulty_panel = DifficultyPanel.new()
	layer.add_child(difficulty_panel)
	difficulty_panel.chosen.connect(_difficulty_chosen)
	_modals.append(difficulty_panel)
	oath_panel = OathPanel.new()
	layer.add_child(oath_panel)
	oath_panel.started.connect(_prepare_launch)
	_modals.append(oath_panel)
	shrine = ShrinePanel.new()
	layer.add_child(shrine)
	_modals.append(shrine)
	daily_dialog = DailyDialog.new()
	layer.add_child(daily_dialog)
	daily_dialog.hide()
	daily_dialog.accepted.connect(_daily_accepted)
	_modals.append(daily_dialog)
	cloud_conflict = CloudConflictDialog.new()
	layer.add_child(cloud_conflict)
	_modals.append(cloud_conflict)


func _layout() -> void:
	_touch.position = _hud.size - Vector2(115, 135)


func _physics_process(_delta: float) -> void:
	var blocked := _leaving
	for modal in _modals:
		blocked = blocked or modal.visible
	walker.blocked = blocked
	if blocked != _blocked:
		_blocked = blocked
		_device_changed()
	var nearest: Spot = null
	var distance := def.interaction_reach * def.interaction_reach
	if not blocked:
		for spot in spots:
			var candidate := walker.position.distance_squared_to(spot.at)
			if candidate <= distance:
				nearest = spot
				distance = candidate
	if nearest != focus:
		focus = nearest
		_show_prompt()
	var down := Input.is_action_pressed(&"interact")
	if down and not _was_down and not blocked:
		interact()
	_was_down = down


func interact() -> bool:
	if focus == null or _leaving or walker.position.distance_to(focus.at) > def.interaction_reach:
		return false
	for modal in _modals:
		if modal.visible:
			return false
	match focus.action:
		&"well": open_well()
		&"shrine": shrine.open(content.soul_tree, content)
		&"memorial": _open_memorial()
		&"resident": _talk(focus.resident)
	return true


func _device_changed() -> void:
	_joystick.visible = InputDevice.uses_touch() and not _blocked
	_joystick.fixed = Settings.fixed_joystick
	_show_prompt()


func _show_prompt() -> void:
	_touch.visible = InputDevice.uses_touch() and not _blocked and focus != null
	_prompt.text = Prompts.pick("Tap Interact: %s", "{interact}: %s") % focus.label if focus else "" # i18n


func _refresh() -> void:
	var lines := PackedStringArray()
	for quest in def.quests:
		match VillageProgress.stage(quest):
			VillageProgress.Step.ACCEPTED: lines.append(tr(quest.objective))
			VillageProgress.Step.FOUND: lines.append(tr(quest.return_text))
	if lines.is_empty():
		lines.append(tr(def.description))
	if daily_requested:
		lines.append(tr("The daily descent awaits at the Well."))
	_objective.text = "\n".join(lines)
	# A cloud replacement or a transaction refreshes an open resident's choices as well.
	if panel.visible and _resident:
		_talk(_resident)


func _talk(resident: VillageResidentDef) -> void:
	_resident = resident
	var returned := resident.quest and VillageProgress.stage(resident.quest) == VillageProgress.Step.RETURNED
	panel.open(tr(resident.speaker.display_name), tr(resident.used_text if returned else resident.text))
	var portrait_row := HBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", 16)
	panel.list.add_child(portrait_row)
	panel.list.move_child(portrait_row, 0)
	var portrait := PixelPortrait.new()
	portrait.texture = resident.speaker.portrait
	portrait_row.add_child(portrait)
	var details := VBoxContainer.new()
	portrait_row.add_child(details)
	details.add_child(UiSkin.label(tr(resident.speaker.title), Fonts.BODY, UiSkin.GOLD))
	if resident.echo and (resident.wakes_after == null or VillageProgress.stage(resident.wakes_after) != VillageProgress.Step.RETURNED):
		details.add_child(UiSkin.label(tr("A voice caught in the lantern's light."), Fonts.BODY, UiSkin.DIM))
	if resident.role == VillageResidentDef.Role.QUEST and resident.quest:
		var quest := resident.quest
		panel.list.add_child(UiSkin.label(tr(quest.title), Fonts.TITLE, UiSkin.GOLD))
		panel.list.add_child(UiSkin.label(tr(quest.description), Fonts.BODY, UiSkin.TEXT, true))
		panel.list.add_child(UiSkin.label(tr(quest.objective), Fonts.BODY, UiSkin.TEXT, true))
		panel.list.add_child(UiSkin.label(tr("Reward: %d souls and a waking home.") % quest.reward_souls, Fonts.BODY, UiSkin.GOLD, true))
		match VillageProgress.stage(quest):
			VillageProgress.Step.AVAILABLE: panel.choice(tr(quest.accept_label), &"accept", quest)
			VillageProgress.Step.ACCEPTED: panel.choice(tr(quest.pending_text), &"none", null, false)
			VillageProgress.Step.FOUND: panel.choice(tr(quest.hand_in_label), &"hand_in", quest)
			VillageProgress.Step.RETURNED: panel.list.add_child(UiSkin.label(tr(quest.done_line), Fonts.BODY, UiSkin.GOLD, true))
	elif resident.role == VillageResidentDef.Role.MERCHANT:
		panel.list.add_child(UiSkin.label(tr("Souls: %d") % Profile.souls, Fonts.TITLE, UiSkin.GOLD))
		for service in def.services:
			panel.list.add_child(UiSkin.label(tr(service.description), Fonts.BODY, UiSkin.TEXT, true))
			var label_text := tr("%s — %d souls") % [tr(service.display_name), service.cost]
			if VillageProgress.restored(service):
				label_text = tr("%s — restored") % tr(service.display_name)
			elif service.requires_quest and VillageProgress.stage(service.requires_quest) != VillageProgress.Step.RETURNED:
				label_text = tr("%s — complete %s first") % [tr(service.display_name), tr(service.requires_quest.title)]
			panel.choice(label_text, &"buy", service, VillageProgress.can_buy(service))


func open_well() -> void:
	_resident = null
	panel.open(tr("The Well"), tr("Choose a descent here. Your village and its memories remain when a run ends."))
	if not RunSave.read().is_empty():
		panel.choice(tr("Resume the descent"), &"resume")
	panel.choice(tr("Descend"), &"normal")
	panel.choice(tr("Daily Descent"), &"daily")


func _choose(action: StringName, payload: Resource) -> void:
	match action:
		&"accept", &"hand_in", &"buy":
			var ok := false
			if action == &"accept": ok = VillageProgress.accept(payload as VillageQuestDef)
			elif action == &"hand_in": ok = VillageProgress.hand_in(payload as VillageQuestDef)
			else: ok = VillageProgress.buy(payload as VillageServiceDef)
			if not ok:
				panel.words.text = tr("Could not save village progress. Try again.")
		&"resume": _launch(true)
		&"normal":
			_new_daily = false
			panel.hide()
			difficulty_panel.open(content.difficulties, content.ascensions)
		&"daily":
			panel.hide()
			daily_dialog.open(content, DailyRun.today())
		&"replace": _launch(false)
		&"previous":
			_memorial_index += 1
			_open_memorial()
		&"next":
			_memorial_index -= 1
			_open_memorial()
		&"title":
			_leaving = true
			Loader.go(TITLE_SCENE)


func _difficulty_chosen(_difficulty: DifficultyDef) -> void:
	if OathPanel.has_choices(content):
		oath_panel.open(content)
	else:
		_prepare_launch()


func _daily_accepted() -> void:
	_new_daily = true
	_prepare_launch()


func _prepare_launch() -> void:
	if not RunSave.read().is_empty():
		panel.open(tr("A descent is already saved"), tr("Starting another descent replaces the saved run. You can resume it instead."))
		panel.choice(tr("Resume the descent"), &"resume")
		panel.choice(tr("Replace the saved descent"), &"replace")
		return
	_launch(false)


func _launch(resume: bool) -> void:
	if _leaving:
		return
	_leaving = true
	daily_requested = false
	Game.resume_requested = resume
	Game.daily_requested = _new_daily and not resume
	Loader.go(GAME_SCENE)


func _open_memorial() -> void:
	_resident = null
	var count := Profile.village_memorials.size()
	if count == 0:
		panel.open(tr("Court of the Nameless"), tr("This stone waits for a hero who chooses to hold the seal. Each such sacrifice will be remembered here."))
		return
	_memorial_index = clampi(_memorial_index, 0, count - 1)
	var snapshot: Dictionary = Profile.village_memorials[_memorial_index]
	var keeper := KeeperSnapshot.new(snapshot)
	var date_text := Time.get_date_string_from_unix_time(keeper.date())
	panel.open(tr("Memorial %d of %d") % [_memorial_index + 1, count], tr("A hero held the seal. Level %d · %s") % [keeper.level(), date_text])
	var stage := Control.new()
	stage.custom_minimum_size.y = 180
	panel.list.add_child(stage)
	var statue := VillageMemorial.new()
	statue.snapshot = snapshot
	statue.content = content
	statue.position = Vector2(120, 150)
	statue.scale = Vector2(3, 3)
	stage.add_child(statue)
	for item in keeper.gear(content):
		panel.list.add_child(UiSkin.label(tr(item.display_name), Fonts.BODY, UiSkin.TEXT))
	panel.choice(tr("Older memorial"), &"previous", null, _memorial_index < count - 1)
	panel.choice(tr("Newer memorial"), &"next", null, _memorial_index > 0)


func _open_menu() -> void:
	if _leaving:
		return
	_resident = null
	panel.open(tr("Kagari"), tr("Village progress is saved after each discovery, purchase and quest. Options and records are on the title screen."))
	panel.choice(tr("Title screen"), &"title")


func _ask_cloud_conflict() -> void:
	if is_inside_tree() and not _leaving:
		cloud_conflict.open()


func _back() -> void:
	for index in range(_modals.size() - 1, -1, -1):
		if _modals[index].visible:
			if _modals[index] == cloud_conflict:
				return
			if _modals[index] == daily_dialog:
				daily_dialog.back()
			else:
				_modals[index].hide()
			return
	_open_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED and is_node_ready():
		_open_menu()
