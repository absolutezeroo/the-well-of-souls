class_name SafeArea
extends Control
## The part of the screen nothing hides (a phone's camera hole or notch, its rounded corners):
## a full-screen Control whose edges stand in by the display's unobscured area
## (DisplayServer.get_display_safe_area()), in the canvas's units (screen pixels / PixelGrid's
## scale), rounded up to even units. Whatever is anchored inside it is anchored to the safe
## area: the HUD, the village's HUD, RpgWindow's board, the touch joystick's zone
## (design/interface.md "One skin"). On a computer the window is the whole safe area.
## Tests simulate a cutout with `simulate()`.

const GROUP := &"safe_area"

## A simulated cutout (tests): screen pixels hidden on the left, top, right and bottom. Null:
## the display's own.
static var _simulated: Variant = null


func _init() -> void:
	name = "Safe"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_to_group(GROUP)


func _ready() -> void:
	get_viewport().size_changed.connect(refresh)
	PixelGrid.scale_changed.connect(refresh)
	refresh()


## Puts the edges where the safe area's are now.
func refresh() -> void:
	if not is_inside_tree():
		return
	var insets := margins(get_viewport())
	offset_left = insets.x
	offset_top = insets.y
	offset_right = -insets.z
	offset_bottom = -insets.w


## How far in from the left, top, right and bottom edges of `viewport`'s canvas the safe area is
## (canvas units, even, never negative).
static func margins(viewport: Viewport) -> Vector4:
	var pixels := _hidden_pixels(viewport)
	var ui_scale: float = PixelGrid.ui_scale() if PixelGrid.ui_scale() > 0.0 else 1.0
	var result := Vector4.ZERO
	for i in 4:
		result[i] = ceilf(maxf(pixels[i], 0.0) / ui_scale / 2.0) * 2.0
	return result


## The safe area of `viewport`'s canvas (canvas units): the whole visible rect but its margins.
static func rect(viewport: Viewport) -> Rect2:
	var whole := viewport.get_visible_rect()
	var m := margins(viewport)
	return Rect2(whole.position + Vector2(m.x, m.y), whole.size - Vector2(m.x + m.z, m.y + m.w))


## Screen pixels hidden on each side (left, top, right, bottom).
static func _hidden_pixels(viewport: Viewport) -> Vector4:
	if _simulated != null:
		return _simulated
	# A computer's window, or the headless tests: nothing hidden (its safe area is the desktop's
	# work area, which says nothing about a window).
	if not OS.has_feature("mobile") or viewport == null:
		return Vector4.ZERO
	var window := viewport.get_window()
	if window == null:
		return Vector4.ZERO
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var screen := Rect2(Vector2.ZERO, Vector2(window.size))
	if not safe.has_area() or not screen.has_area():
		return Vector4.ZERO
	return Vector4(safe.position.x - screen.position.x, safe.position.y - screen.position.y,
			screen.end.x - safe.end.x, screen.end.y - safe.end.y)


## Simulates a cutout hiding `pixels` screen pixels on the left, top, right and bottom (tests);
## every SafeArea follows at once. Vector4.ZERO is no cutout; stop() goes back to the display.
static func simulate(tree: SceneTree, pixels: Vector4) -> void:
	_simulated = pixels
	tree.call_group(GROUP, &"refresh")


## Back to the display's own safe area (after simulate()).
static func stop_simulating(tree: SceneTree) -> void:
	_simulated = null
	tree.call_group(GROUP, &"refresh")
