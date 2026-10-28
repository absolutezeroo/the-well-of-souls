class_name ThresholdHud
extends HudEventCard
## The trial of the Threshold on screen (see Threshold): its name and rule across the screen when
## the hero arrives (HudEventCard), then at the top a big countdown and the spectres slain so
## far. The countdown turns red in its last seconds, brackets flashing round it each second. Built in code; the Hud shows it
## while the trial is on.

## Seconds left when the countdown turns red.
const URGENT := 10.0
const PANEL_COLOR := Color(0.03, 0.04, 0.1, 0.72)

var threshold: Threshold

var _kills_label: Label
var _time_label: Label
var _last_second := -1


func _ready() -> void:
	_init_card_hud(Color(0.01, 0.02, 0.06))
	_build_counters()
	_build_card("ThresholdCard")
	hide()


func _build_counters() -> void:
	var row := _build_banner("ThresholdCounters", PANEL_COLOR)
	_kills_label = _label(Fonts.TITLE)
	_kills_label.name = "ThresholdKills"
	row.add_child(_kills_label)
	_time_label = _label(Fonts.HUGE)
	_time_label.name = "ThresholdTime"
	_time_label.custom_minimum_size.x = 110.0
	row.add_child(_time_label)


## The trial begins: its name and rule across the screen, the counters at the top.
func open(trial: ThresholdDef, needed: int) -> void:
	var color := trial.color
	set_banner_color(color)
	_kills_label.add_theme_color_override("font_color", color)
	var rule := tr("Slay %d spectre before the knell") if needed == 1 else tr("Slay %d spectres before the knell")
	_last_second = -1
	set_progress(0, needed)
	_refresh_time()
	_show_card(tr(trial.display_name), rule % needed, color)


## The countdown and kills panel ("ThresholdCounters").
func counters() -> Control:
	return _banner


func set_progress(kills: int, needed: int) -> void:
	_kills_label.text = tr("Slain %d / %d") % [kills, needed]
	if kills > 0:
		_pop(_kills_label, 0.3)


func _process(_delta: float) -> void:
	if visible:
		_refresh_time()


func _refresh_time() -> void:
	if threshold == null:
		return
	var seconds := ceili(threshold.time_left)
	if seconds == _last_second:
		return
	_last_second = seconds
	_time_label.text = tr("%d s") % seconds
	var urgent := threshold.time_left <= URGENT
	_time_label.add_theme_color_override("font_color", Palette.DANGER if urgent else Color(0.95, 0.97, 1.0))
	if urgent and threshold.is_fighting() and seconds > 0:
		# Each second of the last ten flashes brackets round the count (it stays still).
		_pop(_time_label, 0.4)
