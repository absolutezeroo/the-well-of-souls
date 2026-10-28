class_name ShrineUpgrades
## What the shrine's upgrades (bought with souls, see UpgradeDef and Profile) do to a run.


## Items the shrine unlocked: they can be found in the dungeon.
static func unlocked_items(content: ContentDB) -> Array[ItemDef]:
	var items: Array[ItemDef] = []
	for upgrade in content.upgrades:
		if upgrade.kind == UpgradeDef.Kind.UNLOCK and Profile.level_of(upgrade) > 0:
			items.append_array(upgrade.items)
	return items


## The weapons the Armory lets the hero start with: those its level opened (UpgradeDef
## `armory_weapons`, in data order), minus the ones still locked in ContentDB. Empty: no Armory.
static func armory_weapons(content: ContentDB) -> Array[WeaponDef]:
	var unlocked := unlocked_items(content)
	var result: Array[WeaponDef] = []
	for upgrade in content.upgrades:
		if upgrade.kind != UpgradeDef.Kind.RULES or not upgrade.armory:
			continue
		for weapon in upgrade.armory_weapons.slice(0, upgrade.armory_count(Profile.level_of(upgrade))):
			if weapon and not result.has(weapon) and (not content.locked_items.has(weapon) or unlocked.has(weapon)):
				result.append(weapon)
	return result


## Rerolls (`kind` REROLLS) or banishes (BANISHES) the shrine adds to every run.
static func extra_charges(content: ContentDB, kind: UpgradeDef.Kind) -> int:
	var total := 0
	for upgrade in content.upgrades:
		if upgrade.kind == kind:
			total += Profile.level_of(upgrade)
	return total


## A new hero: stats, starting items and perks from the shrine, the oath sworn (OathDef) and the
## weapon picked (the Armory node: only one its level opened), then the difficulty's max HP.
static func apply_to(player: Player, content: ContentDB, difficulty: DifficultyDef, oath: OathDef = null, picked_weapon: WeaponDef = null) -> void:
	var hp_scale := 1.0
	for upgrade in content.upgrades:
		var level := Profile.level_of(upgrade)
		if level <= 0:
			continue
		match upgrade.kind:
			UpgradeDef.Kind.STATS:
				if upgrade.bonuses:
					player.base_stats = player.base_stats.plus(upgrade.bonuses.times(level))
			UpgradeDef.Kind.STARTING_ITEMS:
				for i in level:
					for item in upgrade.items:
						player.pack.store(item)
			UpgradeDef.Kind.STARTING_PERK:
				if upgrade.perk:
					player.perks.add(upgrade.perk)
			UpgradeDef.Kind.RULES:
				hp_scale *= upgrade.max_hp_scale
			UpgradeDef.Kind.RANDOM_STARTING_ITEM:
				var choices := upgrade.items.filter(func(item: ItemDef) -> bool: return item != null and content.is_available(item))
				if not choices.is_empty():
					player.pack.store(choices[randi() % choices.size()])
	var weapon: WeaponDef = null
	if picked_weapon and armory_weapons(content).has(picked_weapon):
		weapon = picked_weapon
	if oath:
		if oath.bonuses:
			player.base_stats = player.base_stats.plus(oath.bonuses)
		hp_scale *= oath.max_hp_scale
		player.base_stats.move_speed *= oath.move_speed_scale
		if oath.starting_weapon:
			weapon = oath.starting_weapon
		for perk in oath.starting_perks:  # (a kit's twist)
			if perk:
				player.perks.add(perk)
	if weapon:
		player.equipment.equip(weapon)
	if hp_scale != 1.0:
		player.base_stats.max_hp = roundi(player.base_stats.max_hp * hp_scale)
	if difficulty.hero_max_hp != 1.0:
		player.base_stats.max_hp = roundi(player.base_stats.max_hp * difficulty.hero_max_hp)
	player.invalidate_stats()
	player.hp = player.get_max_hp()
