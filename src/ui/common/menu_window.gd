class_name MenuWindow
extends RpgWindow
## An RpgWindow for the menus around a run (shrine, difficulty, options): the same wooden board,
## plus its Close button within reach (`close_button`, to rename or relabel), a place left of the
## header for a line of text (`header_left`), and helpers to build plain, readable rows: big
## on/off switches, dark strips and badges, buttons in the theme.

## Souls (kept between runs): the same pale blue as on the HUD.
const SOULS := Color(0.65, 0.95, 1.0)

const SWITCH_SIZE := Vector2i(60, 30)
## The least height of anything tapped (UI units: about 6 mm on a phone), and the room between
## two things to tap (design/interface.md "One skin": 64 and 16). The button factory holds every
## button to it.
const TOUCH_MIN := 64.0
const TOUCH_GAP := 16

static var _switches := {}


func _init(title_text: String = "") -> void:
	super._init(title_text)
	# A line of text left of the header takes the room (RpgWindow's spacer gives it up).
	header_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spacer.size_flags_horizontal = Control.SIZE_FILL
	header_left.show()


## Makes `node` reachable as %`node_name` from `scene_owner` (tests, other scripts): nodes built
## in code have no owner otherwise.
static func expose(node: Node, node_name: String, scene_owner: Node) -> void:
	node.name = node_name
	node.owner = scene_owner
	node.unique_name_in_owner = true


## A plain button in the game's theme (keys and gamepads reach it: MenuNav), never less than
## TOUCH_MIN tall (a smaller `height` is raised to it: a finger must find it).
static func button(text: String, font_size: int = Fonts.BODY, height: float = TOUCH_MIN) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(0, maxf(height, TOUCH_MIN))
	result.add_theme_font_size_override("font_size", font_size)
	return result


## A thin dark line between rows of a list.
static func separator() -> HSeparator:
	var line := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = Color(0.0, 0.0, 0.0, 0.3)
	style.thickness = 2
	line.add_theme_stylebox_override("separator", style)
	line.add_theme_constant_override("separation", 6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## A dark recess for a line of small things (records, counters), tighter than UiSkin.inset().
static func strip() -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", strip_style())
	return box


static func strip_style() -> StyleBoxTexture:
	var style := UiSkin.inset()
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


## A small dark badge with a gold edge and a label ("Souls to offer").
static func badge(text: String, font_size: int, color: Color) -> PanelContainer:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.1, 0.08, 0.95)
	style.border_color = UiSkin.GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 1
	style.content_margin_bottom = 3
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(UiSkin.label(text, font_size, color))
	return box


## A CheckButton drawn as a big on/off switch with its name in the skin's text style (the
## default icons are too small to see on a phone).
static func style_switch(check: CheckButton, font_size: int = Fonts.BODY) -> void:
	check.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiSkin.set_text_style(check, font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		check.add_theme_color_override(state, UiSkin.TEXT)
	var flat := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		check.add_theme_stylebox_override(state, flat)
	check.add_theme_icon_override("checked", switch_icon(true))
	check.add_theme_icon_override("unchecked", switch_icon(false))
	check.add_theme_icon_override("checked_disabled", switch_icon(true))
	check.add_theme_icon_override("unchecked_disabled", switch_icon(false))


## A pixel on/off switch: a dark track, the knob left (off) or right and gold (on).
static func switch_icon(on: bool) -> Texture2D:
	if _switches.has(on):
		return _switches[on]
	var w := SWITCH_SIZE.x
	var h := SWITCH_SIZE.y
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var edge := Color(0.12, 0.07, 0.05)
	var track := Color(0.55, 0.42, 0.18) if on else Color(0.28, 0.2, 0.16)
	var knob := UiSkin.GOLD if on else Color(0.62, 0.55, 0.5)
	var radius := h * 0.5
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var nearest := Vector2(clampf(p.x, radius, w - radius), radius)
			var d := p.distance_to(nearest)
			if d <= radius - 2.0:
				image.set_pixel(x, y, track)
			elif d <= radius:
				image.set_pixel(x, y, edge)
	var center := Vector2(w - radius if on else radius, radius)
	for y in h:
		for x in w:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d <= radius - 4.0:
				image.set_pixel(x, y, knob)
			elif d <= radius - 2.0:
				image.set_pixel(x, y, edge)
	var texture := ImageTexture.create_from_image(image)
	_switches[on] = texture
	return texture
