class_name BalanceBuild
extends RefCounted
## Turns a BalanceBuildDef (data) into a real hero: the same Player, Equipment, PerkSet and
## LootRoller code the game uses, so the stats the tools measure are the game's own.
## Used by the model (a Player that never enters a world) and by the arena (the run's hero).

const BUILDS_DIR := "res://data/balance/builds/"
const TARGETS_PATH := "res://data/balance/targets.tres"
const PLAYER_SCENE := "res://src/entities/player/player.tscn"


## Every build in data/balance/builds/, sorted by act then name.
static func load_all(dir: String = BUILDS_DIR) -> Array[BalanceBuildDef]:
	var result: Array[BalanceBuildDef] = []
	for file in DirAccess.get_files_at(dir):
		var path := dir.path_join(file.trim_suffix(".remap"))
		if not path.ends_with(".tres"):
			continue
		var build := load(path) as BalanceBuildDef
		if build:
			if build.name.is_empty():
				build.name = path.get_file().get_basename()
			result.append(build)
	result.sort_custom(func(a: BalanceBuildDef, b: BalanceBuildDef) -> bool:
		return a.name < b.name if a.act == b.act else a.act < b.act)
	return result


static func load_targets(path: String = TARGETS_PATH) -> BalanceTargets:
	var targets := load(path) as BalanceTargets
	return targets if targets else BalanceTargets.new()


## Builds whose name is in `names` (all of them when empty).
static func select(all: Array[BalanceBuildDef], names: PackedStringArray) -> Array[BalanceBuildDef]:
	if names.is_empty():
		return all
	return all.filter(func(b: BalanceBuildDef) -> bool: return names.has(b.name))


static func find(all: Array[BalanceBuildDef], build_name: String) -> BalanceBuildDef:
	for build in all:
		if build.name == build_name:
			return build
	return null


## The act's expected build (tag "expected"), or null.
## The hero an average player has on the normal floor `depth`: on an act's first floor what he
## brings in (the previous act's expected build; a fresh hero, `baseline`, in act I), on its
## later floors the act's expected build (he is close to its boss). The curve's heroes.
static func hero_at(all: Array[BalanceBuildDef], content: ContentDB, depth: int) -> BalanceBuildDef:
	var act := content.dungeon.act_index(depth) + 1
	if content.dungeon.floor_in_act(depth) > 1:
		return expected(all, act)
	return find(all, "baseline") if act <= 1 else expected(all, act - 1)


## `build` with the weapon a run starts with (the baseline's), Common, item level 1, nothing on
## it; null when `build` is the baseline itself.
static func with_starter_weapon(all: Array[BalanceBuildDef], content: ContentDB, build: BalanceBuildDef) -> BalanceBuildDef:
	var base := find(all, "baseline")
	if base == null or base.weapon == null or build == null or build == base:
		return null
	var copy := variant(build, content, "weapon", String(base.weapon.id), 0, base.weapon)
	copy.weapon_item_level = 1
	copy.name = build.name + "+starter_weapon"
	return copy


static func expected(all: Array[BalanceBuildDef], act: int) -> BalanceBuildDef:
	for build in all:
		if build.act == act and build.has_tag("expected"):
			return build
	return null


## A copy of `build` with one more thing, as the lab measures it ("add it alone"):
## kind "perk" (id, level = its stacks: replaces the build's own stacks), "family" (its bonus
## alone), "rune" (one more, socket or not), "affix" (on the weapon, else the first armor it
## fits), "upgrade" (shrine level `level`), "buff" (`extra`: a StatBlock for the whole fight),
## "max_hp_cost" (`extra`: share of the base max health lost), "weapon" (`extra`: WeaponDef,
## level = rarity). Returns null when the thing doesn't exist or can't go on this build.
static func variant(build: BalanceBuildDef, content: ContentDB, kind: String, id: String, level: int = 1, extra: Variant = null) -> BalanceBuildDef:
	var copy := build.duplicate() as BalanceBuildDef
	copy.perks = build.perks.duplicate()
	copy.upgrades = build.upgrades.duplicate()
	copy.runes = build.runes.duplicate()
	copy.weapon_affixes = build.weapon_affixes.duplicate()
	copy.armor_affixes = build.armor_affixes.duplicate()
	copy.armor_rarities = build.armor_rarities.duplicate()
	copy.armors = build.armors.duplicate()
	copy.extra_families = build.extra_families.duplicate()
	copy.suppress_families = build.suppress_families.duplicate()
	copy.buffs = build.buffs.duplicate()
	copy.max_hp_cost = build.max_hp_cost
	copy.ignore_sockets = true
	match kind:
		"perk":
			var p := BalanceContent.perk(id)
			if p == null:
				return null
			if level <= 0:
				copy.perks.erase(id)  # the build without it
			else:
				copy.perks[id] = clampi(int(build.perks.get(id, 0)) + level, 1, p.max_stacks)
		"no_family":
			for synergy in content.synergies:
				if String(synergy.id) == id:
					copy.suppress_families.append(synergy)
					return copy
			return null
		"family":
			for synergy in content.synergies:
				if String(synergy.id) == id:
					copy.extra_families.append(synergy)
					return copy
			return null
		"rune":
			if rune(content, id) == null:
				return null
			copy.runes.append(id)
		"affix":
			var a := affix(content, id)
			if a == null:
				return null
			if a.slots & ItemAffixDef.WEAPON:
				copy.weapon_affixes.append(id)
				return copy
			for i in copy.armors.size():
				var flag := ItemAffixDef.HEAD if copy.armors[i].slot == EquipmentDef.Slot.HEAD else ItemAffixDef.BODY
				if a.slots & flag and a.on_hit == null:
					while copy.armor_affixes.size() <= i:
						copy.armor_affixes.append("")
					copy.armor_affixes[i] = (copy.armor_affixes[i] + "," + id) if not copy.armor_affixes[i].is_empty() else id
					return copy
			return null
		"upgrade":
			var u := upgrade(content, id)
			if u == null:
				return null
			copy.upgrades[id] = clampi(level, 0, u.max_level)
		"buff":
			copy.buffs.append([extra, 3600.0])
		"max_hp_cost":
			copy.max_hp_cost += float(extra)
		"weapon":
			copy.weapon = extra as WeaponDef
			copy.weapon_rarity = clampi(level, 0, 3)
			copy.weapon_affixes = PackedStringArray()
			copy.runes = PackedStringArray()
			copy.ignore_sockets = false
		_:
			return null
	return copy


# --- Content lookups ------------------------------------------------------------

static func perk(content: ContentDB, id: String) -> PerkDef:
	for p in content.perks:
		if p and String(p.id) == id:
			return p
	return null


static func rune(content: ContentDB, id: String) -> RuneDef:
	for r in content.runes:
		if r and String(r.id) == id:
			return r
	return null


static func affix(content: ContentDB, id: String) -> ItemAffixDef:
	for a in content.item_affixes:
		if a and String(a.id) == id:
			return a
	return null


static func upgrade(content: ContentDB, id: String) -> UpgradeDef:
	for u in content.upgrades:
		if u and String(u.id) == id:
			return u
	return null


## What is wrong with a build's data (unknown ids, too many runes...). Empty when it is sound.
static func problems(build: BalanceBuildDef, content: ContentDB) -> PackedStringArray:
	var result := PackedStringArray()
	if build.weapon == null:
		result.append("%s: no weapon" % build.name)
	for id in build.weapon_affixes:
		if affix(content, id) == null:
			result.append("%s: unknown weapon affix '%s'" % [build.name, id])
	for id in build.runes:
		if rune(content, id) == null:
			result.append("%s: unknown rune '%s'" % [build.name, id])
	if build.runes.size() > ItemRarity.SOCKETS[clampi(build.weapon_rarity, 0, 3)] and not build.ignore_sockets:
		result.append("%s: %d runes but a %s weapon has %d socket(s)" % [build.name, build.runes.size(), ItemRarity.NAMES[build.weapon_rarity], ItemRarity.SOCKETS[build.weapon_rarity]])
	if build.weapon_affixes.size() > ItemRarity.AFFIX_COUNT[clampi(build.weapon_rarity, 0, 3)]:
		result.append("%s: more weapon affixes than a %s item rolls" % [build.name, ItemRarity.NAMES[build.weapon_rarity]])
	for i in build.armor_affixes.size():
		for id in _split(build.armor_affixes[i]):
			if affix(content, id) == null:
				result.append("%s: unknown armor affix '%s'" % [build.name, id])
	for id: Variant in build.perks:
		var p := perk(content, String(id))
		if p == null:
			result.append("%s: unknown perk '%s'" % [build.name, id])
		elif int(build.perks[id]) > p.max_stacks:
			result.append("%s: %s x%d but it stops at %d" % [build.name, id, int(build.perks[id]), p.max_stacks])
	for id: Variant in build.upgrades:
		var u := upgrade(content, String(id))
		if u == null:
			result.append("%s: unknown upgrade '%s'" % [build.name, id])
		elif int(build.upgrades[id]) > u.max_level:
			result.append("%s: upgrade %s level %d above its max %d" % [build.name, id, int(build.upgrades[id]), u.max_level])
	return result


static func _split(text: String) -> PackedStringArray:
	var result := PackedStringArray()
	for part in text.split(",", false):
		if not part.strip_edges().is_empty():
			result.append(part.strip_edges())
	return result


# --- Gear ------------------------------------------------------------------------

## The build's weapon as the game would make it (a rolled copy when it has a rarity or runes).
static func make_weapon(build: BalanceBuildDef, content: ContentDB) -> WeaponDef:
	if build.weapon == null:
		return null
	var affixes: Array[ItemAffixDef] = []
	for id in build.weapon_affixes:
		var a := affix(content, id)
		if a:
			affixes.append(a)
	var runes: Array[RuneDef] = []
	var sockets: int = ItemRarity.SOCKETS[clampi(build.weapon_rarity, 0, 3)]
	for id in build.runes:
		var r := rune(content, id)
		if r and (runes.size() < sockets or build.ignore_sockets):
			runes.append(r)
	var level := build.weapon_item_level if build.weapon_item_level > 0 else gear_level(build, content)
	if build.weapon_rarity <= ItemRarity.COMMON and affixes.is_empty() and runes.is_empty() and level <= 1:
		return build.weapon
	return LootRoller.make(build.weapon, clampi(build.weapon_rarity, 0, 3), affixes, runes, level) as WeaponDef


## The item level of the build's gear (BalanceBuildDef.item_level; 0 = the floor before its boss).
static func gear_level(build: BalanceBuildDef, content: ContentDB) -> int:
	if build.item_level > 0:
		return build.item_level
	return maxi(BalanceContent.boss_depth(content, build.act) - 1, 1)


static func make_armors(build: BalanceBuildDef, content: ContentDB) -> Array[ArmorDef]:
	var result: Array[ArmorDef] = []
	for i in build.armors.size():
		var base := build.armors[i]
		if base == null:
			continue
		var rarity := build.armor_rarities[i] if i < build.armor_rarities.size() else 0
		var affixes: Array[ItemAffixDef] = []
		if i < build.armor_affixes.size():
			for id in _split(build.armor_affixes[i]):
				var a := affix(content, id)
				if a:
					affixes.append(a)
		var level := gear_level(build, content)
		if rarity <= ItemRarity.COMMON and affixes.is_empty() and level <= 1:
			result.append(base)
		else:
			result.append(LootRoller.make(base, clampi(rarity, 0, 3), affixes, [], level) as ArmorDef)
	return result


# --- The hero ---------------------------------------------------------------------

## Puts the build on `player` (already set up with PlayerDef): base stats, shrine upgrades as
## ShrineUpgrades.apply_to() does, the level ups, gear, perks and the learned spell. Full HP,
## skills ready. `difficulty`: its hero_max_hp counts, like at the start of a run.
static func apply(build: BalanceBuildDef, player: Player, content: ContentDB, difficulty: DifficultyDef = null) -> void:
	var def := content.player
	player.perks.clear()
	player.base_stats = def.base_stats.duplicate()
	for id: Variant in build.upgrades:
		var u := upgrade(content, String(id))
		var level := int(build.upgrades[id])
		if u == null or level <= 0:
			continue
		match u.kind:
			UpgradeDef.Kind.STATS:
				if u.bonuses:
					player.base_stats = player.base_stats.plus(u.bonuses.times(level))
			UpgradeDef.Kind.STARTING_PERK:
				if u.perk:
					player.perks.add(u.perk)
			UpgradeDef.Kind.STARTING_ITEMS:
				for k in level:
					for item in u.items:
						player.pack.store(item)
	var oath := build.oath
	if oath:
		if oath.bonuses:
			player.base_stats = player.base_stats.plus(oath.bonuses)
		player.base_stats.max_hp = roundi(player.base_stats.max_hp * oath.max_hp_scale)
		player.base_stats.move_speed *= oath.move_speed_scale
	player.healing_scale = oath.healing_scale if oath else 1.0
	player.crit_damage_bonus = oath.crit_damage_bonus if oath else 0.0
	if difficulty and difficulty.hero_max_hp != 1.0:
		player.base_stats.max_hp = roundi(player.base_stats.max_hp * difficulty.hero_max_hp)
	for i in maxi(build.level - 1, 0):
		if def.level_bonus:
			player.base_stats = player.base_stats.plus(def.level_bonus)
	if build.max_hp_cost > 0.0:  # an altar's price, as EncounterChoice.max_hp_lost() takes it
		player.base_stats.max_hp -= roundi(player.base_stats.max_hp * build.max_hp_cost)
	player.level = maxi(build.level, 1)
	player.xp = 0

	for slot: EquipmentDef.Slot in EquipmentDef.Slot.values():
		player.equipment.unequip(slot)
	var weapon := make_weapon(build, content)
	if weapon:
		player.equipment.equip(weapon)
	for armor in make_armors(build, content):
		player.equipment.equip(armor)

	for id: Variant in build.perks:
		var p := perk(content, String(id))
		if p == null:
			continue
		for i in clampi(int(build.perks[id]), 0, p.max_stacks):
			player.perks.add(p)
	if oath:
		for p in oath.starting_perks:  # (a kit's twist)
			if p and player.perks.can_take(p):
				player.perks.add(p)
	if not build.suppress_families.is_empty():
		# The build without a family's bonus (the lab measures what the bonus is worth). Tools only.
		player.perks._awake.assign(player.perks._awake.filter(func(entry: PerkSet.Entry) -> bool: return not build.suppress_families.has(entry.synergy)))
		player.perks._rebuild_all()
	if not build.extra_families.is_empty():
		# A family's bonus without its perks (the lab measures it alone): woken by hand, as
		# PerkSet._refresh_synergies() does. Tools only.
		for synergy in build.extra_families:
			if not player.perks.is_awake(synergy):
				var entry := PerkSet.Entry.new()
				entry.synergy = synergy
				entry.granted = synergy.passives
				player.perks._awake.append(entry)
		player.perks._rebuild_all()
	player.timed_bonuses.clear()
	for buff: Array in build.buffs:
		player.add_timed_bonus(buff[0], buff[1])
	player.learned_skill = build.learned_skill
	# Skills ready, as after a long walk to the boss (an equip puts new skills on a short cooldown).
	var none: Array[SkillDef] = []
	player.skills.set_skills(none)
	player.rebuild_skills(0.0)
	player.invalidate_stats()
	player.hp = player.get_max_hp()
	player.health_changed.emit(player.hp, player.get_max_hp())


## A Player with the build on, outside any world (for the model: stats and perks only).
## Free it with free() when done.
static func make_player(build: BalanceBuildDef, content: ContentDB, difficulty: DifficultyDef = null) -> Player:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.setup(content.player)
	apply(build, player, content, difficulty)
	return player
