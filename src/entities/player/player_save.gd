class_name PlayerSave
extends RefCounted
## The hero's part of a saved run (RunSave; Player.save_state() and load_state() come here):
## his level, Health, stats, gear, bag, belt, gold, perks and learned skill, in the save's
## format (unchanged since it lived in Player). A charge is never saved.


## Everything about `player` a saved run needs.
static func to_data(player: Player) -> Dictionary:
	var gear := {}
	for slot: EquipmentDef.Slot in EquipmentDef.Slot.values():
		var item := player.equipment.get_item(slot)
		if item:
			gear[str(slot)] = LootRoller.to_data(item)
	return {
		"level": player.level,
		"xp": player.xp,
		"hp": player.hp,
		"base_stats": player.base_stats.to_dict(),
		"equipment": gear,
		"inventory": player.inventory.items.map(LootRoller.to_data),
		"belt": player.belt.to_data(),
		"gold": player.gold,
		"perks": player.perks.to_data(),
		"learned_skill": RunSave.ref(player.learned_skill),
	}


## Puts `player` back as saved in `data` (after his setup()).
static func restore(player: Player, data: Dictionary) -> void:
	player.level = int(data.get("level", 1))
	player.xp = int(data.get("xp", 0))
	player.base_stats = StatBlock.from_dict(data.get("base_stats", {}))
	var equipment := player.equipment
	for slot: EquipmentDef.Slot in EquipmentDef.Slot.values():
		equipment.unequip(slot)
	var gear: Dictionary = data.get("equipment", {})
	for key: String in gear:
		var item := LootRoller.from_data(gear[key]) as EquipmentDef
		if item:
			equipment.equip(item)
	player.inventory.items.clear()
	player.gold = int(data.get("gold", 0))
	# One list, as saves always kept it: each item goes back to its compartment, even past its
	# places (a save from the single 16-place bag, a compartment made smaller): nothing is lost.
	for saved_item: Variant in data.get("inventory", []):
		var item := LootRoller.from_data(saved_item)
		if item:
			player.inventory.force_add(item)
	player.inventory.changed.emit()  # (an empty bag too: whoever shows it asks again)
	player.belt.load_data(data.get("belt", []))
	player.perks.load_data(data.get("perks", []))
	player.learned_skill = RunSave.load_ref(data.get("learned_skill")) as SkillDef
	player.charge.reset()  # a charge is never saved: back from a save, the button starts afresh
	player.rebuild_skills(0.0)
	player.invalidate_stats()
	player.hp = clampi(int(data.get("hp", player.get_max_hp())), 1, player.get_max_hp())
	player.health_changed.emit(player.hp, player.get_max_hp())
	player.xp_changed.emit(player.xp, player.xp_to_next_level(), player.level)
	player.gold_changed.emit(player.gold)
