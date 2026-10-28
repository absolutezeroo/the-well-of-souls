class_name UiSkin
## The look of the game's big panels (bag, forge...): warm wood, dark insets, item slots with a
## frame in the item's rarity, a red ribbon for titles. Pixel art at the UI's scale (x3), from
## Kenney's "Pixel UI Pack" and "Fantasy UI Borders" (CC0, assets/ui/rpg/).

const DIR := "res://assets/ui/rpg/"
const PANEL: Texture2D = preload("res://assets/ui/rpg/panel.png")
const INSET: Texture2D = preload("res://assets/ui/rpg/inset.png")
const SLOT: Texture2D = preload("res://assets/ui/rpg/slot.png")
const FRAME: Texture2D = preload("res://assets/ui/rpg/frame.png")
const RIBBON: Texture2D = preload("res://assets/ui/rpg/ribbon.png")
const PLAQUE: Texture2D = preload("res://assets/ui/rpg/plaque.png")
const ORNATE: Texture2D = preload("res://assets/ui/rpg/ornate.png")
const SOCKET: Texture2D = preload("res://assets/ui/rpg/socket.png")

## Text on the wood: light, gold titles, dim notes. The one place the interface's colors are
## named (gold is the game's Palette.GOLD): panels use these, never their own copies.
const TEXT := Color(1.0, 0.95, 0.85)
const GOLD := Palette.GOLD
const DIM := Color(1.0, 0.92, 0.8, 0.7)
## A gain, a loss (comparisons, encounter outcomes, a pact holding or broken).
const GOOD := Color(0.45, 1.0, 0.4)
const BAD := Color(1.0, 0.4, 0.32)
## The near-black violet laid over the game behind a window (see backdrop()).
const BACKDROP := Color(0.03, 0.02, 0.05)
const ORNATE_TINT := Color(1.0, 0.8, 0.45, 0.9)


## The dim behind a window or dialog, `alpha` thick.
static func backdrop(alpha: float) -> Color:
	return Color(BACKDROP, alpha)


## The big wood panel (an ornate gold border is drawn over it by OrnatePanel).
static func panel() -> StyleBoxTexture:
	return _box(PANEL, 15, 22)


## A dark recess in the wood (lists, details).
static func inset() -> StyleBoxTexture:
	return _box(INSET, 15, 16)


## The red ribbon under a title.
static func ribbon() -> StyleBoxTexture:
	var box := _box(RIBBON, 0, 0)
	box.texture_margin_left = 39
	box.texture_margin_right = 39
	box.texture_margin_top = 18
	box.texture_margin_bottom = 18
	box.content_margin_left = 48
	box.content_margin_right = 48
	box.content_margin_top = 10  # a BODY line, its capitals on the ribbon's middle, 48 high as the art
	box.content_margin_bottom = 14
	return box


## A small plaque (counts, gold).
static func plaque() -> StyleBoxTexture:
	var box := _box(PLAQUE, 0, 0)
	box.texture_margin_left = 15
	box.texture_margin_right = 15
	box.texture_margin_top = 15
	box.texture_margin_bottom = 15
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


## A label in the skin's text style, with a dark outline (readable on wood and in any color).
## `font_size`: one of the Fonts sizes (Fonts.BODY for anything read, Fonts.TITLE...), so its
## letters keep whole pixels (Fonts); the outline is one font pixel.
static func label(text: String, font_size: int = Fonts.BODY, color: Color = TEXT, wraps := false) -> Label:
	var result := Label.new()
	result.text = text
	set_text_style(result, font_size)
	result.add_theme_color_override("font_color", color)
	if wraps:
		result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result


## Gives `control` (a Label, a Button...) the font size `font_size` and the dark outline of one
## font pixel that goes with it.
static func set_text_style(control: Control, font_size: int) -> void:
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_constant_override("outline_size", Fonts.outline_size(font_size))
	control.add_theme_color_override("font_outline_color", Fonts.OUTLINE)


## The size of reading text (dialogue, the village's words, hints, the codex's and items'
## descriptions): BODY, or a whole font step bigger (TITLE) with Settings.large_text. Panels
## showing it scroll or page rather than shrink it (design/interface.md, Text).
static func reading_size() -> int:
	return Fonts.TITLE if Settings.large_text else Fonts.BODY


## A label of reading text (reading_size()), wrapping, in `color`.
static func reading_label(text: String, color: Color = TEXT) -> Label:
	return label(text, reading_size(), color, true)


## Gives `words` the reading size in use (a label built before the option changed).
static func set_reading_style(words: Control) -> void:
	set_text_style(words, reading_size())


## Words typed letter by letter keep the places they will have once whole: a word never starts
## on one line and jumps to the next as it is typed (Label.VC_CHARS_AFTER_SHAPING).
static func typed(words: Label) -> Label:
	words.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	return words


## A title on the red ribbon.
static func title(text: String) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", ribbon())
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words := label(text, Fonts.BODY, TEXT)
	words.name = "Words"  # (RpgWindow.set_title, RpgDialog.title_label)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(words)
	return box


## A PanelContainer drawn as a dark inset.
static func section() -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", inset())
	return box


static func _box(texture: Texture2D, margin: int, content: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.texture_margin_left = margin
	box.texture_margin_top = margin
	box.texture_margin_right = margin
	box.texture_margin_bottom = margin
	box.content_margin_left = content
	box.content_margin_top = content
	box.content_margin_right = content
	box.content_margin_bottom = content
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return box
