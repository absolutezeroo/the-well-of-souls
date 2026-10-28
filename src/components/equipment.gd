class_name Equipment
extends RefCounted
## What an actor is wearing: one item per EquipmentDef.Slot.

signal changed

var _slots: Dictionary[EquipmentDef.Slot, EquipmentDef] = {}


func get_item(slot: EquipmentDef.Slot) -> EquipmentDef:
	return _slots.get(slot)


## Equips the item and returns whatever was in that slot before (or null).
func equip(item: EquipmentDef) -> EquipmentDef:
	var previous: EquipmentDef = _slots.get(item.slot)
	_slots[item.slot] = item
	changed.emit()
	return previous


func unequip(slot: EquipmentDef.Slot) -> EquipmentDef:
	var previous: EquipmentDef = _slots.get(slot)
	_slots.erase(slot)
	if previous:
		changed.emit()
	return previous


## The affixes of everything worn (rolled gear).
func affixes() -> Array[ItemAffixDef]:
	var result: Array[ItemAffixDef] = []
	for item: EquipmentDef in _slots.values():
		result.append_array(item.affixes)
	return result


## The runes set in everything worn (the weapon's).
func runes() -> Array[RuneDef]:
	var result: Array[RuneDef] = []
	for item: EquipmentDef in _slots.values():
		result.append_array(item.runes)
	return result


## The worn weapon, when it does something by itself (WeaponDef.carried: an evolved weapon).
func carried() -> Array[WeaponDef]:
	var result: Array[WeaponDef] = []
	for item: EquipmentDef in _slots.values():
		if item is WeaponDef and not (item as WeaponDef).carried.is_empty():
			result.append(item as WeaponDef)
	return result


## Something worn changed in place (a rune set or taken out at the forge).
func refresh() -> void:
	changed.emit()


func total_bonuses() -> StatBlock:
	var total := StatBlock.new()
	for item: EquipmentDef in _slots.values():
		if item.bonuses:
			total = total.plus(item.bonuses)
		for rune in item.runes:
			if rune and rune.bonuses:
				total = total.plus(rune.bonuses)
	return total
