class_name OrnateBoard
extends PanelContainer
## The game's wooden board with its gold ornate border (UiSkin): the one board of every window
## and dialog (RpgWindow full-screen, RpgDialog centred), so both look and change alike. The
## border is drawn inside the wood, INSET units in from its edge.

## How far inside the board's edge the ornate border lies: three of the skin's art pixels (it is
## drawn at 3 units a pixel), so the border's pixels stay in step with the wood's. The one odd
## value kept on purpose (design/interface.md "One skin", Pixels).
const INSET := 9.0
## The border's nine-patch margins (assets/ui/rpg/ornate.png).
const ORNATE_MARGIN := 42

static var _ornate: StyleBoxTexture


func _init() -> void:
	add_theme_stylebox_override("panel", UiSkin.panel())
	draw.connect(_draw_ornate)


## The ornate border's box (shared by every board).
static func ornate_box() -> StyleBoxTexture:
	if _ornate == null:
		_ornate = StyleBoxTexture.new()
		_ornate.texture = UiSkin.ORNATE
		_ornate.modulate_color = UiSkin.ORNATE_TINT
		_ornate.draw_center = false
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			_ornate.set_texture_margin(side, ORNATE_MARGIN)
	return _ornate


func _draw_ornate() -> void:
	draw_style_box(ornate_box(), Rect2(Vector2.ZERO, size).grow(-INSET))
