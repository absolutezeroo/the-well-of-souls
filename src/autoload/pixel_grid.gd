extends Node
## Keeps text and pixel art whole on any screen (autoload "PixelGrid"): it picks the scale of the
## canvas, and shifts it a quarter of a screen pixel.
##
## The scale. The UI is laid out at 1280x720 and stretched (canvas_items, expand): Godot alone
## would scale it by min(width / 1280, height / 720), any number (x1.07 on 1366x768, x1.25 on
## 1600x900), where a BODY letter's pixel covers an uneven number of screen pixels and letters
## look cut. Here the scale is that number rounded down to a step of 0.5 (x1 on 720 to 1079
## lines, x1.5 on 1080, x2 on 1440, x3 on 2160: whole font pixels), and the canvas grows to fill
## the screen (1366x768 lays out at 1366x768, 3440x1440 at 1720x720). A screen too small for
## x1 (1024x768: x0.8) keeps Godot's scale; nothing whole fits. Settings.ui_size takes one or two
## steps off (never under x1): more room on a big monitor. The floor's framing doesn't change
## with it: the world's cameras ask camera_zoom() (GameCamera, VillageWalker).
##
## The world's pixels. A camera's zoom is chosen so that one art pixel (2 world units) covers a
## whole number of screen pixels: the framing the camera was designed at (its zoom at 1280x720)
## rounded down to the nearest whole size, the wider view (decision 0007). At 1080 lines the
## dungeon (designed at 1.5) is drawn 4 screen pixels to an art pixel, not 4.5: columns of 4 and
## 5 would alternate and shimmer as the view scrolls. 3 at 720 lines, 6 at 1440, 9 at 2160.
##
## The shift. On a phone the UI is stretched x1.5 (1080 lines for the 720 the layouts use): an odd
## position in the UI's units falls on a half screen pixel. There, every screen pixel samples a
## texture exactly on the edge between two of its pixels and picks one or the other by rounding
## luck: letters get a column or a row doubled, or lost. A quarter-pixel shift takes both whole
## and half positions off those edges (docs/design/interface.md, Text).
##
## The phone's keyboard. On Android it shrinks the window to the strip above it (2340x1080 to
## about 2340x480): read as a new screen, that would scale the UI down to x0.67 while typing. Such
## a resize (SoftKeyboard.is_keyboard_resize()) keeps the scale of the window before it, and
## SoftKeyboard shows the field in the strip; the window's size back, all is as before.

## The canvas's scale changed (a new window size, the interface size option).
signal scale_changed

## How far, in screen pixels.
const SHIFT := 0.25
## The scale goes by these steps (whole font pixels at BODY: 2 UI units a font pixel).
const STEP := 0.5
## World units in one art pixel (pack art is drawn at scale 2: docs/art-bible.md).
const ART_PIXEL := 2.0

## Godot's own scale for this window (expand), and the one used.
var _fit := 1.0
var _scale := 1.0
## The window's size the last time no keyboard had shrunk it.
var _settled := Vector2i.ZERO


func _ready() -> void:
	get_tree().root.size_changed.connect(_apply)
	Settings.changed.connect(_apply)
	_apply()


## The canvas's scale for a window Godot would scale by `fit`, at interface size `ui_size`
## (Settings.UI_*).
static func canvas_scale(fit: float, ui_size: int) -> float:
	if fit < 1.0:
		return fit
	var whole := floorf(fit / STEP + 0.001) * STEP
	return maxf(1.0, whole - STEP * ui_size)


## Screen pixels per art pixel for a camera designed at zoom `designed` (its framing at the
## layouts' 1280x720) on a window Godot would scale by `fit`: the designed size rounded down to a
## whole number (the wider view); 0 on a window too small for even one (a test's 64x64 window).
static func art_pixel_size(designed: float, fit: float) -> int:
	return floori(ART_PIXEL * designed * fit + 0.001)


## The camera zoom drawing art_pixel_size() screen pixels per art pixel under a canvas scaled by
## `scale` (canvas_scale()); the designed framing itself where not one whole pixel fits.
static func whole_zoom(designed: float, fit: float, scale: float) -> float:
	var pixels := art_pixel_size(designed, fit)
	if pixels < 1:
		return designed * fit / scale
	return pixels / (ART_PIXEL * scale)


## This window's zoom for a world camera designed at `designed` (GameCamera, VillageWalker):
## every art pixel on a whole number of screen pixels, whatever the window and the interface size.
func camera_zoom(designed: float) -> float:
	return whole_zoom(designed, _fit, _scale) if _scale > 0.0 else designed


## The scale in use (screen pixels per UI unit).
func ui_scale() -> float:
	return _scale


## The UI's own pictures (the HUD's round buttons, an item's icon in its slot, a monster in the
## codex) follow the same rule as the cameras: drawn at most `most` UI units per art pixel, each
## art pixel on a whole number of screen pixels under a canvas scaled by `scale`, rounded down
## (at x1.5 a 32-pixel button 144 units across is drawn on 192 screen pixels, 6 a pixel, not 216
## at 6.75). Below one screen pixel a pixel, `most` itself. In UI units per art pixel.
static func whole_art_scale(most: float, scale: float) -> float:
	var pixels := floorf(most * scale + 0.001)
	return pixels / scale if pixels >= 1.0 else most


## whole_art_scale() on this window's canvas.
func art_scale(most: float) -> float:
	return whole_art_scale(most, _scale if _scale > 0.0 else 1.0)


## The window's size without the phone's keyboard (its size now when the keyboard is not up).
func settled_size() -> Vector2i:
	return _settled


func _apply() -> void:
	var root := get_tree().root
	var base := Vector2(root.content_scale_size)
	if base.x <= 0.0 or base.y <= 0.0 or root.size.x <= 0 or root.size.y <= 0:
		return
	var fit := minf(root.size.x / base.x, root.size.y / base.y)
	if SoftKeyboard.is_keyboard_resize(root.size, _settled):
		# The keyboard's strip: the same scale as before it (Godot's own fit is the strip's).
		_set_factor(root, _scale / fit)
		return
	_settled = root.size
	var target := canvas_scale(fit, Settings.ui_size)
	var factor := target / fit
	var changed := not is_equal_approx(_fit, fit) or not is_equal_approx(_scale, target)
	_fit = fit
	_scale = target
	_set_factor(root, factor)
	if changed:
		scale_changed.emit()


## Godot's scale times `factor` is the canvas's; the quarter-pixel shift follows it.
func _set_factor(root: Window, factor: float) -> void:
	if not is_equal_approx(root.content_scale_factor, factor):
		root.content_scale_factor = factor
	if DisplayServer.get_name() != "headless":
		var stretch := root.get_stretch_transform().get_scale().x
		if stretch > 0.0:
			root.global_canvas_transform = Transform2D(0.0, Vector2.ONE * SHIFT / stretch)
