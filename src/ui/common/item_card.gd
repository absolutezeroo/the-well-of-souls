class_name ItemCard
extends RefCounted
## The picked item's card, built the one way for the bag and the merchant: its slot, its name in
## its rarity's color and its type beside it; under them, in a box that scrolls, its details and
## how it compares with what is worn (a gold heading, then each change on its line, green when
## it is better, red when worse: ItemCompare). The panel adds its own lines (a price, a hint)
## to `naming` and `top`, and its buttons under the card.

var top: HBoxContainer
var slot: ItemSlot
## The name and type's column (a price can go under them).
var naming: VBoxContainer
var item_name: Label
var item_type: Label
var details_scroll: ScrollContainer
var details: Label
var compare_title: Label
## One label per change against what is worn.
var compare: VBoxContainer


## Builds the card at the end of `column`: a slot of `slot_size`, the names, the details' box.
static func build(column: VBoxContainer, slot_size: float) -> ItemCard:
	var card := ItemCard.new()
	card.top = HBoxContainer.new()
	card.top.add_theme_constant_override("separation", 12)
	column.add_child(card.top)
	card.slot = ItemSlot.new(slot_size)
	card.slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.slot.focus_mode = Control.FOCUS_NONE
	card.top.add_child(card.slot)
	card.naming = VBoxContainer.new()
	card.naming.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.naming.alignment = BoxContainer.ALIGNMENT_CENTER
	card.naming.add_theme_constant_override("separation", 0)
	card.top.add_child(card.naming)
	card.item_name = UiSkin.label("", Fonts.BODY, UiSkin.GOLD, true)
	card.naming.add_child(card.item_name)
	card.item_type = UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	card.naming.add_child(card.item_type)
	card.details_scroll = UiParts.scroll()
	card.details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(card.details_scroll)
	var details_column := VBoxContainer.new()
	details_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_column.add_theme_constant_override("separation", 4)
	card.details_scroll.add_child(details_column)
	card.details = UiSkin.reading_label("")  # (bigger with Large text: the box scrolls)
	card.details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_column.add_child(card.details)
	card.compare_title = UiSkin.label("", Fonts.BODY, UiSkin.GOLD, true)
	card.compare_title.hide()
	details_column.add_child(card.compare_title)
	card.compare = VBoxContainer.new()
	card.compare.add_theme_constant_override("separation", 0)
	details_column.add_child(card.compare)
	return card


## No item picked: a gold title, what to do, and maybe a line in the details.
func show_empty(title: String, hint: String, details_text: String = "") -> void:
	slot.item = null
	item_name.text = title
	item_name.add_theme_color_override("font_color", UiSkin.GOLD)
	item_type.text = hint
	UiSkin.set_reading_style(details)
	details.text = details_text
	clear_compare()


## `item` on the card (`count` in its slot), its details from the top.
func show_item(item: ItemDef, count: int = 1) -> void:
	slot.item = item
	slot.count = count
	item_name.text = tr(item.display_name)
	item_name.add_theme_color_override("font_color", item.rarity_color())
	item_type.text = item.get_type_label()
	UiSkin.set_reading_style(details)
	details.text = item.get_details()
	clear_compare()
	details_scroll.scroll_vertical = 0


## How wearing `equipment` instead of `worn` changes things (nothing when it is what is worn).
func show_compare(equipment: EquipmentDef, worn: EquipmentDef) -> void:
	clear_compare()
	if equipment == null or worn == equipment:
		return
	compare_title.text = ItemCompare.heading(equipment, worn)
	compare_title.show()
	var changes := ItemCompare.lines(equipment, worn)
	if changes.is_empty():
		compare.add_child(UiSkin.label(tr("the same stats"), Fonts.BODY, UiSkin.DIM))
	for change in changes:
		compare.add_child(UiSkin.label(change.text, Fonts.BODY, UiSkin.GOOD if change.good else UiSkin.BAD, true))


## A gold line under the details instead of a comparison (what a consumable bought does).
func show_note(words: String) -> void:
	clear_compare()
	compare_title.text = words
	compare_title.show()


func clear_compare() -> void:
	compare_title.hide()
	UiParts.clear(compare)


## The words of the card's details and comparison (tests).
func text() -> String:
	var lines := PackedStringArray([details.text])
	if compare_title.visible:
		lines.append(compare_title.text)
	for label: Label in compare.get_children():
		lines.append(label.text)
	return "\n".join(lines)
