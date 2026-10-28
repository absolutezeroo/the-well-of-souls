class_name BagTab
extends Button
## A tab of the bag (BagCategoryDef: a compartment): its pictogram in the middle, how many items
## it holds in the corner when any (red when the compartment is full), and a small gold gem when something new waits in it. The open tab is pressed (a ButtonGroup) and its name
## is written under the row (InventoryPanel). Tapped or clicked; Q / E and LB / RB switch tabs
## (MenuNav, group "menu_tabs"), so it never takes the focus itself.

## A finger's size (MenuWindow.TOUCH_MIN).
const SIZE := Vector2(64, 64)

var category: BagCategoryDef
var count := 0:
	set(value):
		count = value
		queue_redraw()
## Its compartment has no free place (the count turns red).
var full := false:
	set(value):
		full = value
		queue_redraw()
## Something in it the player hasn't seen yet.
var fresh := false:
	set(value):
		fresh = value
		queue_redraw()


func _init(for_category: BagCategoryDef) -> void:
	category = for_category
	custom_minimum_size = SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	# Drawn as a wooden slot like the bag's (ItemSlot), not as an orange button.
	var none := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, none)
	tooltip_text = tr(category.display_name)
	name = "%sTab" % String(category.id).to_pascal_case()
	add_to_group(MenuNav.TABS)


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	var dim := count == 0 and not button_pressed
	draw_style_box(ItemSlot.slot_box(), area)
	if is_hovered() and not button_pressed:
		draw_rect(area.grow(-ItemSlot.RIM), Color(1, 0.9, 0.6, 0.08))
	if button_pressed:
		draw_rect(area.grow(-ItemSlot.RIM), Color(UiSkin.GOLD, 0.14))
		draw_style_box(ItemSlot.frame_box(UiSkin.GOLD), area.grow(-ItemSlot.PX))
	if category.icon:
		# The compartment's pictogram (assets/ui/placeholders/: a sign, not an item of the game),
		# in the middle of the slot.
		var tint := UiSkin.GOLD if button_pressed else (UiSkin.DIM if dim else UiSkin.TEXT)
		draw_texture_rect(category.icon, ItemSlot.centered_icon(category.icon, area.grow(-8), 0.9), false, tint)
	if count > 0:
		var color := UiSkin.BAD if full else (UiSkin.GOLD if button_pressed else UiSkin.TEXT)
		Fonts.draw(self, Vector2(size.x - 4, size.y - 4), str(count), Fonts.SMALL, color, 1.0)
	if fresh:
		ItemSlot.draw_fresh(self, Vector2(size.x - 6, 6))
