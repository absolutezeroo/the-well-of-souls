class_name VillagePanel
extends Control
## Compact Ninja Adventure conversations keep the speaker's world visible. Services use the
## same presenter with more height. Choices only emit requests; progression belongs to the hub.

signal picked(action: StringName, payload: Resource)
const PAPER := Color("fbeee8")
const INK := Color("283a3d")
const SPEECH: Texture2D = preload("res://assets/ui/dialogue/speech.png")
const REPLY: Texture2D = preload("res://assets/ui/dialogue/reply.png")
const FACE: Texture2D = preload("res://assets/ui/dialogue/portrait.png")
var list: VBoxContainer
var words: Label
var close_button: Button
var conversation := false
var card := PanelContainer.new()
var portrait := PixelPortrait.new()
var _heading: Label
var _subtitle: Label
var _face_frame := PanelContainer.new()
var _message := VBoxContainer.new()
var _row := HBoxContainer.new()
var _scroll := UiParts.scroll()


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(MenuNav.GROUP)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Invisible modal shield: the village remains fully visible behind the conversation.
	add_child(card)
	card.add_theme_stylebox_override("panel", _skin(SPEECH, 18))
	card.resized.connect(_place_card)
	card.minimum_size_changed.connect(_layout.call_deferred)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_heading = _paper_label("", Fonts.BODY)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_heading)
	close_button = _button(tr("Close"))
	close_button.custom_minimum_size.x = 120
	close_button.pressed.connect(hide)
	header.add_child(close_button)
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_row.add_theme_constant_override("separation", 24)
	column.add_child(_row)
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.size_flags_stretch_ratio = 1.25
	_message.add_theme_constant_override("separation", 12)
	_row.add_child(_message)
	var speaker_row := HBoxContainer.new()
	speaker_row.add_theme_constant_override("separation", 14)
	_message.add_child(speaker_row)
	_face_frame.add_theme_stylebox_override("panel", _skin(FACE, 6))
	_face_frame.add_child(portrait)
	speaker_row.add_child(_face_frame)
	_subtitle = _paper_label("", Fonts.BODY, true)
	_subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subtitle.custom_minimum_size.x = 200.0
	speaker_row.add_child(_subtitle)
	var speech_scroll := UiParts.scroll()
	speech_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_message.add_child(speech_scroll)
	words = _paper_label("", Fonts.BODY, true)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speech_scroll.add_child(words)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(_scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	_scroll.add_child(list)
	# Existing quest/service rows keep their common text helper, recolored on entry.
	list.child_entered_tree.connect(_style_row)
	resized.connect(_layout)
	hide()


func open(heading: String, message: String) -> void:
	UiParts.clear(list)
	conversation = false
	_heading.text = heading
	words.text = message
	_face_frame.hide()
	_subtitle.hide()
	_scroll.scroll_vertical = 0
	show()
	_layout()
	close_button.grab_focus()


func speak(resident: VillageResidentDef, message: String, activity: String) -> void:
	open(tr(resident.speaker.display_name), message)
	conversation = true
	portrait.texture = resident.speaker.portrait
	portrait.material = resident.appearance
	_face_frame.visible = portrait.texture != null
	_subtitle.text = tr(resident.speaker.title) + "\n" + activity
	_subtitle.show()
	_layout()


func choice(label_text: String, action: StringName, payload: Resource = null, enabled: bool = true) -> Button:
	var button := _button(label_text)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.disabled = not enabled
	button.pressed.connect(func() -> void: picked.emit(action, payload))
	list.add_child(button)
	return button


func _layout() -> void:
	var width := minf(1160.0, size.x - 48.0)
	var height := minf(420.0 if conversation else 510.0, size.y - 72.0)
	card.size = Vector2(width, height)
	_place_card()


func _place_card() -> void:
	card.position = Vector2(roundf((size.x - card.size.x) * 0.5), size.y - card.size.y - 24.0)


func _style_row(node: Node) -> void:
	if node is Label:
		var label := node as Label
		label.add_theme_color_override("font_color", INK)
		label.add_theme_constant_override("outline_size", 0)


static func _paper_label(value: String, font_size: int, wraps: bool = false) -> Label:
	var label := UiSkin.label(value, font_size, INK, wraps)
	label.add_theme_constant_override("outline_size", 0)
	return label


static func _button(value: String) -> Button:
	var button := MenuWindow.button(value, Fonts.BODY, 52)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_stylebox_override("normal", _skin(REPLY, 12))
	button.add_theme_stylebox_override("hover", _skin(REPLY, 12))
	button.add_theme_stylebox_override("pressed", _skin(REPLY, 12))
	button.add_theme_stylebox_override("disabled", _skin(REPLY, 12))
	for state in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
		button.add_theme_color_override(state, PAPER)
	button.add_theme_color_override("font_disabled_color", Color("b6bba6"))
	return button


static func _skin(texture: Texture2D, padding: float) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, 5)
		box.set_expand_margin(side, 0)
		box.set_content_margin(side, padding)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return box
