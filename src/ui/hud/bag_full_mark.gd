class_name BagFullMark
extends Control
## A small red dot on the HUD's Bag button while a compartment of the bag is full (Inventory:
## each compartment fills on its own). The toast at pickup says it once; this keeps saying it,
## so the player knows to make room before the next fight's loot stays on the ground. Which
## compartment is full is told in the bag itself (its tab's count in red, BagTab).

## One pixel of the UI's art (the 2-unit grid of ItemSlot.draw_fresh()).
const PIXEL := 2.0
## The dot's rows of pixels (a round dot 4 pixels wide), dark rim around it.
const ROWS: Array[int] = [2, 4, 4, 2]
## How far in from the button's top right corner (UI pixels).
const INSET := Vector2(8.0, 8.0)

## A compartment is full (the dot shows).
var full := false:
	set(value):
		if full != value:
			full = value
			visible = value
## The bag it was last asked about (refresh() on its changes).
var _bag: Inventory


func _init() -> void:
	name = "BagFullMark"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(PIXEL * 6, PIXEL * 6)
	visible = false


## Follows `bag` (the hero's, a new one each run): shown whenever one of its compartments is full.
func watch(bag: Inventory) -> void:
	if _bag and _bag.changed.is_connected(refresh):
		_bag.changed.disconnect(refresh)
	_bag = bag
	if _bag:
		_bag.changed.connect(refresh)
	refresh()


## Asks the bag again (its items changed).
func refresh() -> void:
	full = any_full(_bag)


## Whether a compartment of `bag` has no free place left.
static func any_full(bag: Inventory) -> bool:
	if bag == null:
		return false
	for i in bag.compartment_count():
		if bag.is_compartment_full(i):
			return true
	return false


## Placed in the top right corner of the button it marks (called when the button resizes).
func place() -> void:
	var button := get_parent() as Control
	if button:
		position = (Vector2(button.size.x - INSET.x - size.x, INSET.y) / PIXEL).round() * PIXEL


func _enter_tree() -> void:
	var button := get_parent() as Control
	if button and not button.resized.is_connected(place):
		button.resized.connect(place)
	place()


func _draw() -> void:
	for row in ROWS.size():
		var width: int = ROWS[row]
		var x := (6 - width) * 0.5 * PIXEL
		draw_rect(Rect2(x - PIXEL, row * PIXEL + PIXEL, (width + 2) * PIXEL, PIXEL), Fonts.OUTLINE)
	draw_rect(Rect2(PIXEL * 2, 0, PIXEL * 2, PIXEL), Fonts.OUTLINE)
	draw_rect(Rect2(PIXEL * 2, PIXEL * 5, PIXEL * 2, PIXEL), Fonts.OUTLINE)
	for row in ROWS.size():
		var width: int = ROWS[row]
		var x := (6 - width) * 0.5 * PIXEL
		draw_rect(Rect2(x, row * PIXEL + PIXEL, width * PIXEL, PIXEL), UiSkin.BAD)
	# A light facet, top left.
	draw_rect(Rect2(PIXEL * 2, PIXEL * 2, PIXEL, PIXEL), Color(1.0, 0.75, 0.7))
