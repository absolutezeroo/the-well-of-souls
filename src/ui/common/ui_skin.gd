class_name UiSkin
## The look of the game's big panels (bag, forge...): warm wood, dark insets, item slots with a
## frame in the item's rarity, a red ribbon for titles. Kenney's "Pixel UI Pack" and "Fantasy UI
## Borders" (CC0, assets/ui/rpg/), stored at 2 UI units per art pixel like the font and the world's
## art (tools/ui/rescale_skin.py): whole screen pixels at every canvas scale (x1.5 on a phone: 3).
## Every texture margin below counts whole art pixels (even units), so pieces laid over each
## other keep their pixels in step (design/interface.md "One skin", Pixels).

const DIR := "res://assets/ui/rpg/"
const PANEL: Texture2D = preload("res://assets/ui/rpg/panel.png")
const INSET: Texture2D = preload("res://assets/ui/rpg/inset.png")
const SLOT: Texture2D = preload("res://assets/ui/rpg/slot.png")
const FRAME: Texture2D = preload("res://assets/ui/rpg/frame.png")
const RIBBON: Texture2D = preload("res://assets/ui/rpg/ribbon.png")
const PLAQUE: Texture2D = preload("res://assets/ui/rpg/plaque.png")
const ORNATE: Texture2D = preload("res://assets/ui/rpg/ornate.png")
const SOCKET: Texture2D = preload("res://assets/ui/rpg/socket.png")
## The bars' frame (wood widgets of Ninja Adventure's example project).
const BAR: Texture2D = preload("res://assets/ui/wood/nine_path_bg.png")

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
## A list row's band on an inset (band()).
const BAND := Color(0.05, 0.03, 0.02, 0.32)

static var _bar_frame: StyleBoxTexture


## The dim behind a window or dialog, `alpha` thick.
static func backdrop(alpha: float) -> Color:
	return Color(BACKDROP, alpha)


## The big wood panel (an ornate gold border is drawn over it by OrnatePanel). Its edge is 5 art
## pixels.
static func panel() -> StyleBoxTexture:
	return _box(PANEL, 10, 22)


## A dark recess in the wood (lists, details).
static func inset() -> StyleBoxTexture:
	return _box(INSET, 10, 16)


## The red ribbon under a title. Its ends (16 art pixels, their folds and stripes) and its rows
## over and under the middle one (the band's inside, the 9th of its 16 rows) keep their art; in
## between, its columns and that row are all alike and repeat to the title's width and a line's
## height: no pixel stretched, the words inside the band, 48 tall as before.
static func ribbon() -> StyleBoxTexture:
	var box := _box(RIBBON, 0, 0)
	box.texture_margin_left = 32
	box.texture_margin_right = 32
	box.texture_margin_top = 16
	box.texture_margin_bottom = 14
	box.content_margin_left = 48
	box.content_margin_right = 48
	box.content_margin_top = 10  # a BODY line, its capitals on the ribbon's middle, 48 high as the art
	box.content_margin_bottom = 14
	return box


## The HUD's bars' dark wooden frame (Health, experience, a boss: StatBar).
static func bar_frame() -> StyleBoxTexture:
	if _bar_frame == null:
		_bar_frame = StyleBoxTexture.new()
		_bar_frame.texture = BAR
		_bar_frame.set_texture_margin_all(6)
	return _bar_frame


## A slot's wood (ItemSlot's) holding a picture `content` units in from its edge (the shrine's
## upgrades, a rank's icon).
static func slot_frame(content: int) -> StyleBoxTexture:
	var box := _box(SLOT, 10, content)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return box


## A faint band behind a row of a list on an inset: darker so rows read apart (BAND), or a light
## tint for the player's own row. Square (the pixel grid has no rounded corners), no border.
static func band(color: Color = BAND, margin_x := 12, margin_y := 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y
	box.content_margin_bottom = margin_y
	return box


## A small dark recess for a prompt or a note over the game (the inset, tight around its words).
static func note_box(left := 8, right := 12, top := 4, bottom := 4) -> StyleBoxTexture:
	var box := inset()
	box.content_margin_left = left
	box.content_margin_right = right
	box.content_margin_top = top
	box.content_margin_bottom = bottom
	return box


## A colored edge over `rect` of `canvas` (in its _draw or its draw signal): the rarity frame's
## art in `color` (an event's banner, a perk family, the Interact prompt, a chosen card).
static func draw_edge(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	canvas.draw_style_box(ItemSlot.frame_box(color), rect)


## The loading screen's bar: a dark groove with a wooden edge, filled in the souls' pale blue.
static func style_loading_bar(bar: ProgressBar) -> void:
	var under := StyleBoxFlat.new()
	under.bg_color = Color(0.04, 0.03, 0.06)
	under.border_color = Color(0.62, 0.42, 0.22)
	under.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.55, 0.95, 0.95, 0.85)
	fill.set_border_width_all(2)
	fill.border_color = Color(0, 0, 0, 0)
	bar.add_theme_stylebox_override("background", under)
	bar.add_theme_stylebox_override("fill", fill)


## A small plaque (a portrait's frame). Its corners (7 art pixels, rivets in them) stay whole;
## between them its rows and columns are all alike, so it stretches to any size without uneven
## pixels.
static func plaque() -> StyleBoxTexture:
	var box := _box(PLAQUE, 0, 0)
	box.texture_margin_left = 14
	box.texture_margin_right = 14
	box.texture_margin_top = 14
	box.texture_margin_bottom = 14
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
