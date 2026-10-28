class_name HudEventCard
extends Control
## What a place with a rule of its own shows over the HUD (the trial of the Threshold, the
## Deeps): its name and rule across the screen for a moment (the card), and a banner panel at
## the top centre edged in its color, for the counters it keeps. ThresholdHud and AbyssHud
## extend it; a new trial would too. Built in code; the Hud shows it while the place holds the
## hero.

## How long the name and rule stay up, between their fade in and out (seconds).
const CARD_TIME := 2.6
const CARD_FADE_IN := 0.35
const CARD_FADE_OUT := 0.6
## The card's width (UI pixels) and how far under the screen's top it stands.
const CARD_HALF_WIDTH := 420.0
const CARD_TOP := 104.0

var _banner: PanelContainer
var _card: VBoxContainer
var _title: Label
var _rule: Label
var _card_tween: Tween
## The name and rule are up (from the start of their fade in to the end of their fade out).
var _card_on := false
## The color under the labels' outline (a near-black of the place's own hue).
var _outline := Color(0.01, 0.02, 0.06)


func _init_card_hud(outline: Color) -> void:
	_outline = outline
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE


## The banner at the top centre (`panel_color` behind, its edge set by set_banner_color()):
## returns the row its labels go in.
func _build_banner(node_name: String, panel_color: Color) -> HBoxContainer:
	_banner = PanelContainer.new()
	_banner.name = node_name
	_banner.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = panel_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 2
	style.content_margin_bottom = 4
	_banner.add_theme_stylebox_override("panel", style)
	_banner.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_banner.grow_horizontal = GROW_DIRECTION_BOTH
	_banner.offset_top = 10.0
	add_child(_banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = MOUSE_FILTER_IGNORE
	_banner.add_child(row)
	return row


## The name (HUGE) over the rule (TITLE, wrapping), hidden until _show_card().
func _build_card(node_name: String) -> void:
	_card = VBoxContainer.new()
	_card.name = node_name
	_card.mouse_filter = MOUSE_FILTER_IGNORE
	_card.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	_card.grow_horizontal = GROW_DIRECTION_BOTH
	_card.offset_left = -CARD_HALF_WIDTH
	_card.offset_right = CARD_HALF_WIDTH
	_card.offset_top = CARD_TOP
	_card.add_theme_constant_override("separation", 2)
	add_child(_card)
	_title = _label(Fonts.HUGE)
	_card.add_child(_title)
	_rule = _label(Fonts.TITLE)
	_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(_rule)
	_card.modulate.a = 0.0


## A centred label on the grid's sizes, with the place's outline.
func _label(font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", _outline)
	label.add_theme_constant_override("outline_size", Fonts.outline_size(font_size))
	return label


## The banner's edge in the place's color.
func set_banner_color(color: Color) -> void:
	(_banner.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(color, 0.8)


## The name and rule across the screen: in, CARD_TIME, out.
func _show_card(title_text: String, rule_text: String, color: Color) -> void:
	_title.add_theme_color_override("font_color", color)
	_title.text = title_text
	_rule.text = rule_text
	show()
	if _card_tween:
		_card_tween.kill()
	_card.modulate.a = 0.0
	_card_on = true
	_card_tween = create_tween()
	_card_tween.tween_property(_card, "modulate:a", 1.0, CARD_FADE_IN)
	_card_tween.tween_interval(CARD_TIME)
	_card_tween.tween_property(_card, "modulate:a", 0.0, CARD_FADE_OUT)
	_card_tween.tween_callback(_card_gone)


func _card_gone() -> void:
	_card_on = false


func close() -> void:
	if _card_tween:
		_card_tween.kill()
	_card.modulate.a = 0.0
	_card_on = false
	hide()


## The name and rule are on screen (hints wait for them).
func is_card_showing() -> bool:
	return visible and _card_on


## `label` says it changed: brackets flash round its words for `time` seconds, in its color (its
## words never swell: nothing to read moves, design/interface.md "One skin").
func _pop(label: Label, time: float) -> void:
	TextCue.ping(label, label.get_theme_color(&"font_color"), time)
