class_name CampaignFormat
extends RefCounted
## Strict boundaries for campaign snapshots. Refuse unreadable content rather than dropping
## inventory entries. These local checks are not an authoritative online economy validator.

## JSON numbers must round-trip exactly through its double representation.
const MAX_INTEGER := 9007199254740991
const MAX_NESTING := 32


static func integer(value: Variant, minimum: int = 0) -> bool:
	return number(value) and float(value) >= minimum and float(value) <= MAX_INTEGER \
		and float(value) == floorf(float(value))


static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func keys(value: Variant, required: Array[String]) -> bool:
	if not value is Dictionary or value.size() != required.size():
		return false
	for key in required:
		if not value.has(key):
			return false
	return true


## A finite, bounded JSON tree only: no Resource, Node, runtime vector or non-string key.
static func plain(value: Variant, nesting: int = 0) -> bool:
	if nesting > MAX_NESTING:
		return false
	if value == null or value is bool or value is String or value is StringName:
		return true
	if value is int:
		return value >= -MAX_INTEGER and value <= MAX_INTEGER
	if value is float:
		return is_finite(value) and absf(value) <= MAX_INTEGER
	if value is Array:
		for entry: Variant in value:
			if not plain(entry, nesting + 1):
				return false
		return true
	if value is Dictionary:
		for key: Variant in value:
			if not (key is String or key is StringName) or not plain(value[key], nesting + 1):
				return false
		return true
	return false


static func flag_map(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key: Variant in value:
		if not key is String or key.is_empty() or not value[key] is bool:
			return false
	return true


static func point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and number(value[0]) and number(value[1]) \
		and Vector2(value[0], value[1]).is_finite()


static func player_data(value: Variant) -> bool:
	if not keys(value, ["level", "xp", "hp", "base_stats", "equipment", "inventory", "belt", "gold", "perks", "learned_skill"]) \
			or not plain(value):
		return false
	var data: Dictionary = value
	if not integer(data.level, 1) or not integer(data.hp, 1) or not integer(data.xp) or not integer(data.gold):
		return false
	var stats := StatBlock.new().to_dict()
	if not data.base_stats is Dictionary or data.base_stats.size() != stats.size():
		return false
	for key: String in stats:
		var amount: Variant = data.base_stats.get(key)
		if not number(amount) or (stats[key] is int and float(amount) != floorf(float(amount))):
			return false
	if not data.equipment is Dictionary or not data.inventory is Array or not data.perks is Array:
		return false
	for key: String in data.equipment:
		var item := _item(data.equipment[key]) as EquipmentDef
		if item == null or key != str(item.slot):
			return false
	for entry: Variant in data.inventory:
		if _item(entry) == null:
			return false
	if not data.belt is Array or data.belt.size() != Belt.SLOTS:
		return false
	for entry: Variant in data.belt:
		if entry is Dictionary and entry.is_empty():
			continue
		if not keys(entry, ["item", "count"]) or not _reference(entry.item) is ConsumableDef \
				or not integer(entry.count, 1) or entry.count > Belt.rules.max_stack:
			return false
	for entry: Variant in data.perks:
		if not keys(entry, ["perk", "stacks", "memory"]) or not _reference(entry.perk) is PerkDef \
				or not integer(entry.stacks, 1) or not entry.memory is Dictionary:
			return false
	return data.learned_skill == "" or _reference(data.learned_skill) is SkillDef


## Only published stable ids. Legacy paths belong to an explicit future import, not this codec.
static func _reference(value: Variant) -> Resource:
	return RunSave.load_ref(value) if value is String and value.begins_with("@") else null


static func _item(value: Variant) -> ItemDef:
	if value is String:
		return _reference(value) as ItemDef
	if not keys(value, ["base", "rarity", "affixes", "runes", "level"]):
		return null
	var base := _reference(value.base) as EquipmentDef
	if base == null or not integer(value.rarity) or value.rarity > ItemRarity.EPIC \
			or not integer(value.level, 1) or not value.affixes is Array or not value.runes is Array:
		return null
	for ref: Variant in value.affixes:
		if not _reference(ref) is ItemAffixDef:
			return null
	for ref: Variant in value.runes:
		if not _reference(ref) is RuneDef:
			return null
	return base
