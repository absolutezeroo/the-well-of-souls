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
	var room: VillageInteriorDef
	var target_room: VillageInteriorDef
	## A sleeping home's door is no interaction until its resident wakes (set on profile change).
	var enabled := true

var walker: VillageWalker
var view: VillageView
var panel: VillagePanel
var difficulty_panel: DifficultyPanel
var oath_panel: OathPanel
var shrine: ShrinePanel
var daily_dialog: DailyDialog
var cloud_conflict: CloudConflictDialog
var journal: CodexPanel
var spots: Array[Spot] = []
var focus: Spot
var _modals: Array[Control] = []
var _joystick: TouchJoystick
var _touch: ActionButton
var _prompt: Label
var _objective: Label
var _place_label: Label
var _time_label: Label
var _clock_minute := -1
var _hud: Control
var _was_down := true
var _blocked := false
var _leaving := false
var descent: WellDescent
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
	for room in def.interiors:
		_add_spot(room.door, &"enter", tr("Enter %s") % tr(room.display_name), null, null, room)
		_add_spot(room.offset + room.exit, &"exit", tr("Return to Kagari"), null, room)
		if room.has_shrine:
			_add_spot(room.offset + room.shrine, &"shrine", tr("Shrine"), null, room)
	_add_spot(def.memorial, &"memorial", tr("Court of the Nameless"))
	_add_spot(def.noticeboard + Vector2(0, 24), &"journal", tr("Bounty board"))
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


func _add_spot(at: Vector2, action: StringName, label_text: String, resident: VillageResidentDef = null, room: VillageInteriorDef = null, target_room: VillageInteriorDef = null) -> void:
	var spot := Spot.new()
	spot.at = at
	spot.action = action
	spot.label = label_text
	spot.resident = resident
	spot.room = room
	spot.target_room = target_room
	spots.append(spot)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	# The village's HUD in the screen's safe area (a phone's camera hole hides none of it).
	_hud = SafeArea.new()
	layer.add_child(_hud)
	var header := VBoxContainer.new()
	header.position = Vector2(24, 20)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(header)
	_place_label = UiSkin.label(tr(def.display_name), Fonts.TITLE, UiSkin.GOLD)
	header.add_child(_place_label)
	_objective = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	_objective.custom_minimum_size.x = 580
	header.add_child(_objective)
	_time_label = UiSkin.label("", Fonts.BODY, UiSkin.DIM)
	header.add_child(_time_label)
	var menu := MenuWindow.button(tr("Menu"), Fonts.BODY, 52)
	menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu.offset_left = -180
	menu.offset_right = -24
	menu.offset_top = 24
	menu.pressed.connect(_open_menu)
	_hud.add_child(menu)
	var quests := MenuWindow.button(tr("Quests"), Fonts.BODY, 52)
	quests.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	quests.offset_left = -370
	quests.offset_right = -196
	quests.offset_top = 24
	quests.pressed.connect(open_journal)
	_hud.add_child(quests)
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
	journal = preload("res://src/ui/codex/codex_panel.tscn").instantiate() as CodexPanel
	layer.add_child(journal)
	_modals.append(journal)


func _layout() -> void:
	_touch.position = _hud.size - Vector2(115, 135)


func _physics_process(delta: float) -> void:
	var blocked := _leaving
	for modal in _modals:
		blocked = blocked or modal.visible
	if not blocked:
		VillageClock.advance(delta)
	refresh_time()
	walker.blocked = blocked
	for resident in view.residents:
		resident.paused = blocked
		resident.hero = walker
	for animal in view.animals:
		animal.paused = blocked
	if blocked != _blocked:
		_blocked = blocked
		_device_changed()
	var nearest: Spot = null
	var distance := def.interaction_reach * def.interaction_reach
	if not blocked:
		for spot in spots:
			if spot.resident:
				var actor := view.actor_for(spot.resident)
				spot.at = actor.position
				spot.room = actor.room
			if spot.room != walker.room or not spot.enabled: continue
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
	if focus == null or _leaving or focus.room != walker.room or walker.position.distance_to(focus.at) > def.interaction_reach:
		return false
	for modal in _modals:
		if modal.visible:
			return false
	match focus.action:
		&"well": open_well()
		&"shrine": shrine.open(content.soul_tree, content)
		&"enter": enter_room(focus.target_room)
		&"exit": leave_room()
		&"memorial": _open_memorial()
		&"journal": open_journal()
		&"resident":
			_talk(focus.resident)
			if focus.resident.speaker.voice:
				Sfx.play_ui(focus.resident.speaker.voice, focus.resident.speaker.voice_db)
	return true


func enter_room(room: VillageInteriorDef) -> bool:
	if room == null or not def.interiors.has(room) or walker.room != null or not _can_cross() or not VillageProgress.room_open(room):
		return false
	_set_place(room, room.offset + room.spawn)
	return true


func leave_room() -> bool:
	if walker.room == null or not _can_cross(): return false
	_set_place(null, walker.room.return_position)
	return true


func _can_cross() -> bool:
	if _leaving: return false
	for modal in _modals:
		if modal.visible: return false
	return true


func _set_place(room: VillageInteriorDef, at: Vector2) -> void:
	walker.set_place(room, at)
	view.active_room = room
	_place_label.text = tr(room.display_name if room else def.display_name)
	focus = null
	_was_down = true  # A held touch/key cannot immediately interact with the other doorway.
	_clock_minute = -1
	refresh_time()
	_show_prompt()


func _device_changed() -> void:
	_joystick.visible = InputDevice.uses_touch() and not _blocked
	_joystick.fixed = Settings.fixed_joystick
	_show_prompt()


func _show_prompt() -> void:
	_touch.visible = InputDevice.uses_touch() and not _blocked and focus != null
	_prompt.text = Prompts.pick("Tap Interact: %s", "{interact}: %s") % focus.label if focus else "" # i18n


func _refresh() -> void:
	for spot in spots:
		if spot.action == &"enter":
			spot.enabled = VillageProgress.room_open(spot.target_room)
	if focus and not focus.enabled:
		focus = null
		_show_prompt()
	_clock_minute = -1
	refresh_time()
	var lines := PackedStringArray()
	var all_returned := not def.quests.is_empty()
	for quest in def.quests:
		all_returned = all_returned and VillageProgress.stage(quest) == VillageProgress.Step.RETURNED
		match VillageProgress.stage(quest):
			VillageProgress.Step.ACCEPTED: lines.append(tr(quest.objective))
			VillageProgress.Step.FOUND: lines.append(tr(quest.return_text))
	if lines.is_empty():
		for quest in def.quests:
			if VillageProgress.can_accept(quest):
				lines.append(tr(quest.offer_text))
	if lines.is_empty():
		lines.append(tr(def.restored_text if all_returned else def.description))
	if daily_requested:
		lines.append(tr("The daily descent awaits at the Well."))
	_objective.text = "\n".join(lines)
	# A cloud replacement or a transaction refreshes an open resident's choices as well.
	if panel.visible and _resident:
		_talk(_resident)
	if journal.visible:
		journal.open(content, CodexPanel.Tab.QUESTS)


func refresh_time() -> void:
	var minute := floori(Profile.village_seconds * 1440.0 / def.clock.day_seconds)
	if minute == _clock_minute: return
	_clock_minute = minute
	_time_label.text = VillageClock.text(def.clock)
	view.apply_hour(VillageClock.hour(def.clock))


func open_journal() -> void:
	if _leaving: return
	_resident = null
	panel.hide()
	journal.open(content, CodexPanel.Tab.QUESTS)


func _talk(resident: VillageResidentDef, topic: VillageTopicDef = null) -> void:
	_resident = resident
	var actor := view.actor_for(resident)
	panel.speak(resident, tr(topic.reply if topic else VillageProgress.greeting(resident)), tr(actor.activity.display_name) if actor.activity else "")
	if actor.indoors:
		panel.words.text = tr("You knock at the door. A sleepy voice answers.") + "\n" + panel.words.text
	if resident.echo and (resident.wakes_after == null or VillageProgress.stage(resident.wakes_after) != VillageProgress.Step.RETURNED):
		panel.list.add_child(UiSkin.label(tr("A voice caught in the lantern's light."), Fonts.BODY, UiSkin.DIM, true))
	if resident.role == VillageResidentDef.Role.QUEST and resident.quest:
		var quest := resident.quest
		if VillageProgress.stage(quest) != VillageProgress.Step.RETURNED:
			panel.list.add_child(UiSkin.label(tr(quest.title), Fonts.BODY, UiSkin.GOLD))
			panel.list.add_child(UiSkin.label(tr(quest.objective), Fonts.BODY, UiSkin.DIM, true))
			panel.list.add_child(UiSkin.label(tr(quest.reward_text) % quest.reward_souls, Fonts.BODY, UiSkin.DIM, true))
		match VillageProgress.stage(quest):
			VillageProgress.Step.AVAILABLE:
				var available := VillageProgress.can_accept(quest)
				var locked := quest.requires_quest and VillageProgress.stage(quest.requires_quest) != VillageProgress.Step.RETURNED
				panel.choice(tr(quest.locked_text if locked else quest.accept_label), &"accept", quest, available)
			VillageProgress.Step.ACCEPTED: panel.choice(tr(quest.pending_text), &"none", null, false)
			VillageProgress.Step.FOUND: panel.choice(tr(quest.hand_in_label), &"hand_in", quest)
			VillageProgress.Step.RETURNED: pass
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
	for subject in resident.topics:
		if VillageProgress.topic_available(subject):
			panel.choice(tr(subject.prompt), &"topic", subject)


func open_well() -> void:
	_resident = null
	panel.open(tr("The Well"), tr("Choose a descent here. Your village and its memories remain when a run ends."))
	if not RunSave.read().is_empty():
		panel.choice(tr("Resume the descent"), &"resume")
	panel.choice(tr("Descend"), &"normal")
	panel.choice(tr("Daily descent"), &"daily")


func _choose(action: StringName, payload: Resource) -> void:
	if _leaving: return
	match action:
		&"topic":
			var subject := payload as VillageTopicDef
			if _resident and subject and _resident.topics.has(subject) and VillageProgress.topic_available(subject):
				_talk(_resident, subject)
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
			Profile.save_profile()
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
	if _leaving or Loader.busy or Profile.held:
		return
	if not Profile.save_profile():
		panel.open(tr("The Well"), tr("Could not save village progress. Try again."))
		return
	_leaving = true
	walker.blocked = true
	for modal in _modals: modal.hide()
	_hud.hide()
	descent = WellDescent.new()
	descent.walker = walker
	descent.effect = view.well_vfx
	descent.def = def.atmosphere
	descent.well = def.well
	descent.finished.connect(_finish_descent.bind(resume), CONNECT_ONE_SHOT)
	add_child(descent)


func _finish_descent(resume: bool) -> void:
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
	if _leaving: return
	for index in range(_modals.size() - 1, -1, -1):
		if _modals[index].visible:
			if _modals[index] == cloud_conflict:
				return
			if _modals[index] == daily_dialog:
				daily_dialog.back()
			elif _modals[index] == journal:
				journal.back()
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
	elif is_node_ready() and what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		Profile.save_profile()
		if what == NOTIFICATION_APPLICATION_PAUSED or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile")):
			_open_menu()
