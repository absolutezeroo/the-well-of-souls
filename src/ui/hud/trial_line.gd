class_name TrialLine
extends VBoxContainer
## Under the minimap, while the floor holds a room trial (RoomTrial): its name and its objective
## ("Souls freed: 2 / 4"), in the trial's color; green once done, then gone after a moment. The
## floor's call is a banner as the floor begins; each step a toast, the end a banner. Where the
## pact's line goes (a floor never has both). Listens to Events only.

const KEEP_SHOWN := 4.0

## Where the toasts and the banner go.
var hud: Hud

var _trial: RoomTrial
var _name: Label
var _state: Label
var _hide_in := -1.0


func _ready() -> void:
	name = "TrialLine"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -420.0
	offset_right = -16.0
	offset_top = 300.0
	offset_bottom = 360.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_theme_constant_override("separation", 0)
	_name = _label()
	_name.name = "TrialName"
	_state = _label()
	_state.name = "TrialState"
	hide()
	Events.floor_entered.connect(_on_floor)
	Events.trial_progressed.connect(_on_progressed)
	Events.trial_completed.connect(_on_completed)


## The objective as shown (tests).
func state_text() -> String:
	return _state.text if visible else ""


func _label() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", Fonts.BODY)
	label.add_theme_constant_override("outline_size", Fonts.outline_size(Fonts.BODY))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(label)
	return label


## Shows `world`'s trial (a floor beginning; the debug panel laying one).
func watch(world: World) -> void:
	_on_floor(world)


func _on_floor(world: World) -> void:
	_trial = world.room_trial if world and is_instance_valid(world.room_trial) else null
	_hide_in = -1.0
	if _trial == null or _trial.completed:
		hide()
		return
	_name.text = tr(_trial.def.display_name)
	_name.add_theme_color_override("font_color", _trial.def.color.lightened(0.2))
	_refresh()
	show()
	if hud:
		hud.show_banner(tr(_trial.def.display_name), _trial.def.color.lightened(0.2))
	if not _trial.def.call_line.is_empty():
		Events.log_message(tr(_trial.def.call_line), _trial.def.color)


func _on_progressed(trial: RoomTrial) -> void:
	if trial != _trial:
		return
	_refresh()
	if hud and not trial.completed:
		hud.toast(trial.objective_text())


func _on_completed(trial: RoomTrial) -> void:
	if trial != _trial:
		return
	_refresh()
	_hide_in = KEEP_SHOWN
	if hud:
		hud.show_banner(tr("Trial done"), UiSkin.GOOD)


func _process(delta: float) -> void:
	if not visible:
		return
	if _trial == null or not is_instance_valid(_trial):
		hide()
		return
	if _hide_in >= 0.0:
		_hide_in -= delta
		if _hide_in < 0.0:
			hide()


func _refresh() -> void:
	if _trial == null or not is_instance_valid(_trial):
		return
	_state.text = _trial.objective_text()
	_state.add_theme_color_override("font_color", UiSkin.GOOD if _trial.completed else Palette.GOLD)
