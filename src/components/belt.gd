class_name Belt
extends RefCounted
## Potions, bombs and scrolls: a few slots outside the bag, each holding a stack of one kind,
## each with its own button on screen. They don't take room in the bag.

signal changed

const SLOTS := 3
static var rules: BeltRules = preload("res://data/items/belt_rules.tres")

## A slot's stack: one kind of consumable and how many (none: an empty slot).
class Slot:
	var item: ConsumableDef
	var count := 0

	func is_empty() -> bool:
		return item == null


## One entry per slot, an empty one holding no item.
var slots: Array[Slot] = []


func _init() -> void:
	for i in SLOTS:
		slots.append(Slot.new())


func item_at(index: int) -> ConsumableDef:
	return slots[index].item if index >= 0 and index < SLOTS else null


func count_at(index: int) -> int:
	return slots[index].count if index >= 0 and index < SLOTS else 0


func count_of(item: ItemDef) -> int:
	var total := 0
	for slot in slots:
		if slot.item == item and not slot.is_empty():
			total += slot.count
	return total


## True if `item` would fit (on its stack, or in an empty slot).
func can_add(item: ItemDef) -> bool:
	return _slot_for(item) >= 0


## Puts `item` on its stack, or in the first empty slot. False if it doesn't fit.
func add(item: ItemDef) -> bool:
	var index := _slot_for(item)
	if index < 0:
		return false
	var slot := slots[index]
	if slot.is_empty():
		slot.item = item as ConsumableDef
		slot.count = 1
	else:
		slot.count += 1
	changed.emit()
	return true


## Takes one item from slot `index` (null if empty).
func take(index: int) -> ConsumableDef:
	var item := item_at(index)
	if item == null:
		return null
	var slot := slots[index]
	slot.count -= 1
	if slot.count <= 0:
		_empty(slot)
	changed.emit()
	return item


## Takes one `item` from wherever it is. False if there is none.
func remove(item: ItemDef) -> bool:
	for i in SLOTS:
		if item_at(i) == item:
			take(i)
			return true
	return false


func is_empty() -> bool:
	return slots.all(func(slot: Slot) -> bool: return slot.is_empty())


func _slot_for(item: ItemDef) -> int:
	if not item is ConsumableDef:
		return -1
	for i in SLOTS:
		if item_at(i) == item and count_at(i) < rules.max_stack:
			return i
	for i in SLOTS:
		if slots[i].is_empty():
			return i
	return -1


static func _empty(slot: Slot) -> void:
	slot.item = null
	slot.count = 0


# --- Saving -------------------------------------------------------------------

## For save files: one entry per slot, { item, count } or {} for an empty one (the format
## saves always had).
func to_data() -> Array:
	return slots.map(func(slot: Slot) -> Dictionary:
		return {} if slot.is_empty() else { "item": RunSave.ref(slot.item), "count": slot.count })


func load_data(data: Array) -> void:
	for i in SLOTS:
		var slot := slots[i]
		_empty(slot)
		if i >= data.size() or not data[i] is Dictionary or (data[i] as Dictionary).is_empty():
			continue
		var item := RunSave.load_ref(data[i].get("item")) as ConsumableDef
		if item:
			slot.item = item
			slot.count = clampi(int(data[i].get("count", 1)), 1, rules.max_stack)
	changed.emit()
