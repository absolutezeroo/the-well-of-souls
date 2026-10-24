class_name CinematicView
extends Control
## What a cinematic shows over the frozen world (CinematicDirector): two black bars sliding in,
## a name and its title in the top one, lines written in the bottom one, which grows to hold
## them (a chapter's title over them, "New" beside it, then the subject's words, then the lines). A tap anywhere, a key or a button says
## so (`tapped`); the director decides what it does. Built in code, on its own CanvasLayer
## above the HUD; the pixel font at Fonts sizes only.

## A tap, a key, a gamepad button.
signal tapped

## Room around the text in the bottom bar, and the widest the text may be (UI pixels).
const TEXT_MARGIN := Vector2(40, 18)
const TEXT_MAX_WIDTH := 1000.0
## The bottom bar's height follows its text at this speed (UI pixels a second).
const GROW_SPEED := 900.0
const BAR_COLOR := Color(0.02, 0.012, 0.03)

var _top: ColorRect
var _bottom: ColorRect
var _name_box: VBoxContainer
var _name: Label
var _title: Label
var _text_box: VBoxContainer
## The subject's own words, under the chapter's title, over the lines.
var _speech: Label
var _heading_row: HBoxContainer
var _heading: Label
var _new_mark: PanelContainer
var _lines: VBoxContainer
var _skip: Label
## 0..1: how far the bars are in; their height when in (UI pixels).
var _shown := 0.0
var _bar_height := 0.0
var _bottom_height := 0.0
var _bars_tween: Tween
var _text_tween: Tween
## Taps, clicks, keys and buttons, read the one way (TapGate: the wheel skips nothing, one finger
## is one tap).
var _gate := TapGate.new()


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func open() -> void:
	_shown = 0.0
	_bottom_height = 0.0
	_clear_now()
	_skip.modulate.a = 0.0
	show()
	_layout()


func close() -> void:
	if _bars_tween:
		_bars_tween.kill()
	if _text_tween:
		_text_tween.kill()
	hide()


## Slides the bars in (`on`) or out over `time` seconds; `height`: each bar's share of the screen.
func set_letterbox(on: bool, time: float, height: float) -> void:
	_bar_height = roundf(size.y * height)
	if _bars_tween:
		_bars_tween.kill()
	_bars_tween = create_tween()
	_bars_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if on else Tween.EASE_IN)
	_bars_tween.tween_property(self, "_shown", 1.0 if on else 0.0, maxf(time, 0.01))
	_bars_tween.parallel().tween_property(_skip, "modulate:a", 1.0 if on else 0.0, maxf(time, 0.01))
	if not on:
		clear_text(time * 0.6)


func show_name(text: String, title: String, name_color: Color, title_color: Color) -> void:
	_name.text = text
	_name.add_theme_color_override("font_color", name_color)
	_title.text = title
	_title.add_theme_color_override("font_color", title_color)
	_title.visible = not title.is_empty()
	_name_box.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_name_box, "modulate:a", 1.0, 0.3)


## A new block of text: its heading (a chapter's title; "" for none) and the "New" mark.
func begin_text(heading: String, is_new: bool) -> void:
	for child in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	_speech.text = ""
	_speech.hide()
	_heading.text = heading
	_heading_row.visible = not heading.is_empty()
	_new_mark.visible = is_new and not heading.is_empty()
	_text_box.modulate.a = 1.0


## A line under the others, empty-looking until the director writes it out.
func add_line(text: String, color: Color) -> Label:
	var label := UiSkin.label(text, Fonts.BODY, color, true)
	label.custom_minimum_size.x = _text_width()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.visible_characters = 0
	_lines.add_child(label)
	return label


## The subject's words, under the heading, empty-looking until the director writes them out.
func set_speech(text: String, color: Color) -> Label:
	_speech.text = text
	_speech.add_theme_color_override("font_color", color)
	_speech.custom_minimum_size.x = _text_width()
	_speech.visible_characters = 0
	_speech.show()
	return _speech


## The name and the lines fade out.
func clear_text(time: float) -> void:
	if _text_tween:
		_text_tween.kill()
	_text_tween = create_tween().set_parallel()
	_text_tween.tween_property(_text_box, "modulate:a", 0.0, maxf(time, 0.01))
	_text_tween.tween_property(_name_box, "modulate:a", 0.0, maxf(time, 0.01))


## The lines written so far (tests, screenshots).
func lines_text() -> PackedStringArray:
	var result := PackedStringArray()
	for label: Label in _lines.get_children():
		result.append(label.text)
	return result


## The subject's words on screen ("" for none).
func speech_text() -> String:
	return _speech.text if _speech.visible else ""


## The lines (and words) fully written and shown so far (tests).
func written_lines() -> PackedStringArray:
	var result := PackedStringArray()
	var labels: Array[Node] = [_speech]
	labels.append_array(_lines.get_children())
	for label: Label in labels:
		if label.visible and not label.text.is_empty() and label.modulate.a > 0.5 \
				and (label.visible_characters < 0 or label.visible_characters >= label.get_total_character_count()):
			result.append(label.text)
	return result


func heading_text() -> String:
	return _heading.text if _heading_row.visible else ""


func is_new_shown() -> bool:
	return _new_mark.visible


func name_text() -> String:
	return _name.text


## The bottom bar on screen (tests: the text fits in it).
func text_rect() -> Rect2:
	return _text_box.get_global_rect()


func bottom_bar_rect() -> Rect2:
	return _bottom.get_global_rect()


func _clear_now() -> void:
	for child in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	_heading_row.visible = false
	_speech.hide()
	_name.text = ""
	_title.text = ""
	_name_box.modulate.a = 0.0
	_text_box.modulate.a = 1.0


func _process(delta: float) -> void:
	if not visible:
		return
	# Under the text, room for the skip hint in the corner too: a long last line runs under it.
	var under := maxf(TEXT_MARGIN.y, _skip.size.y + 6.0)
	var wanted := maxf(_bar_height, _text_box.get_combined_minimum_size().y + TEXT_MARGIN.y + under) if _shown > 0.0 else 0.0
	_bottom_height = move_toward(_bottom_height, wanted, GROW_SPEED * delta) if _bottom_height > 0.0 else wanted
	_layout()


func _layout() -> void:
	var top := roundf(_bar_height * _shown)
	_top.position = Vector2.ZERO
	_top.size = Vector2(size.x, top)
	var bottom := roundf(_bottom_height * _shown)
	_bottom.position = Vector2(0, size.y - bottom)
	_bottom.size = Vector2(size.x, bottom)
	var name_size := _name_box.get_combined_minimum_size()
	_name_box.size = Vector2(size.x, name_size.y)
	_name_box.position = Vector2(0, roundf(maxf((top - name_size.y) * 0.5, top - name_size.y - 4.0)))
	var text_size := _text_box.get_combined_minimum_size()
	_text_box.size = Vector2(_text_width(), text_size.y)
	_text_box.position = Vector2(roundf((size.x - _text_width()) * 0.5), roundf(size.y - bottom + TEXT_MARGIN.y))
	_skip.position = Vector2(size.x - _skip.size.x - 16.0, size.y - _skip.size.y - 6.0)


func _text_width() -> float:
	return minf(TEXT_MAX_WIDTH, maxf(size.x - TEXT_MARGIN.x * 2.0, 200.0))


## Touches and clicks on the view (it covers the screen).
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventMouseButton):
		return
	var read := _gate.read(event)
	if read != TapGate.IGNORE:
		accept_event()
	if read == TapGate.TAKE:
		tapped.emit()


## Keys and gamepad buttons, wherever the focus is.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	var read := _gate.read(event, visible)
	if read != TapGate.IGNORE:
		get_viewport().set_input_as_handled()
	if read == TapGate.TAKE:
		tapped.emit()


func _build() -> void:
	_top = ColorRect.new()
	_top.color = BAR_COLOR
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)
	_bottom = ColorRect.new()
	_bottom.color = BAR_COLOR
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bottom)

	_name_box = VBoxContainer.new()
	_name_box.add_theme_constant_override("separation", 0)
	_name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_box)
	_name = UiSkin.label("", Fonts.TITLE)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_box.add_child(_name)
	_title = UiSkin.label("", Fonts.BODY)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_box.add_child(_title)

	_text_box = VBoxContainer.new()
	_text_box.add_theme_constant_override("separation", 6)
	_text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text_box)
	# The chapter's title first, then the subject's words, then the lines: a title between the
	# words and the story read as the warden's name cutting the dialogue in two.
	_heading_row = HBoxContainer.new()
	_heading_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_heading_row.add_theme_constant_override("separation", 10)
	_text_box.add_child(_heading_row)
	_heading = UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
	_heading_row.add_child(_heading)
	_new_mark = MenuWindow.badge(tr("New"), Fonts.SMALL, UiSkin.GOLD)
	_new_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_heading_row.add_child(_new_mark)
	_speech = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	_speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speech.hide()
	_text_box.add_child(_speech)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 4)
	_text_box.add_child(_lines)

	_skip = UiSkin.label("", Fonts.SMALL, UiSkin.DIM)
	_skip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_skip)
	_say_skip()
	InputDevice.changed.connect(_say_skip)


## How to skip, in the words of the device in hand (any tap, key or button does it).
func _say_skip() -> void:
	_skip.text = Prompts.pick("Tap to skip", "Press {ui_accept} to skip")  # i18n
	_skip.size = Vector2.ZERO
