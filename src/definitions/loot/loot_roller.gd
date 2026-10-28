class_name LootRoller
## Turns found equipment into copies of the floor's item level (ItemLevelRules), Magic, Rare or
## Epic ones with random affixes. Rarity chances grow with depth (DungeonConfig > Loot) and with
## the source: a boss or an elite drops better than a crate (`quality`). Consumables and tomes
## are never rolled.

const LEVELS: ItemLevelRules = preload("res://data/items/item_levels.tres")


## `item` at the level of `depth` (itself on floor 1 if Common), or a better rolled copy of it.
## `min_rarity`: never below it (the Trophy Hunter node's Magic). `luck`: a find the run's
## bad-luck protection counts (its drought raises the odds of Rare and Epic, a Rare or better ends
## it: RunLuck.rare_drought); null for the merchant's stock and what a floor's seed lays.
static func roll(item: ItemDef, depth: int, quality: float, config: DungeonConfig, affixes: Array[ItemAffixDef], rng: RandomNumberGenerator, min_rarity: int = ItemRarity.COMMON, luck: RunLuck = null) -> ItemDef:
	var equipment := item as EquipmentDef
	if equipment == null or equipment.is_rolled():
		return item
	var level := maxi(depth, 1)
	var rarity := maxi(pick_rarity(depth, quality, config, rng, luck.rare_drought if luck else 0), min_rarity)
	if luck:
		luck.found_equipment(rarity)
	if rarity == ItemRarity.COMMON:
		return item if level <= 1 else make(equipment, rarity, [], [], level)
	var fitting := affixes.filter(func(affix: ItemAffixDef) -> bool: return affix.fits(equipment) and affix.min_depth <= depth)
	var picked: Array[ItemAffixDef] = []
	for i in ItemRarity.AFFIX_COUNT[rarity]:
		var weights := PackedInt32Array()
		for affix: ItemAffixDef in fitting:
			weights.append(0 if picked.has(affix) else affix.spawn_weight)
		var affix: ItemAffixDef = RandomUtils.pick_weighted(fitting, weights, rng)
		if affix == null:
			break
		picked.append(affix)
	return make(equipment, rarity, picked, [], level)


## `drought`: finds since the last Rare or better (RunLuck.rare_drought, the pity).
static func pick_rarity(depth: int, quality: float, config: DungeonConfig, rng: RandomNumberGenerator, drought: int = 0) -> int:
	var weights := rarity_weights(depth, quality, config, drought)
	var pick := rng.randf() * _total(weights)
	for rarity in weights.size():
		pick -= weights[rarity]
		if pick < 0.0:
			return rarity
	return ItemRarity.COMMON


## The weight of each rarity (ItemRarity order: Common, Magic, Rare, Epic) for equipment found at
## `depth` from a source of `quality` (DungeonConfig > Loot): what pick_rarity() rolls on, and
## what anything telling the odds (an encounter, the balance tools) reads, so they never disagree.
## `drought`: finds since the last Rare or better; past DungeonConfig.pity_after, Rare and Epic
## grow by pity_growth for each one more (decision 0012: bad luck doesn't last).
static func rarity_weights(depth: int, quality: float, config: DungeonConfig, drought: int = 0) -> PackedFloat64Array:
	var levels := depth - 1
	var pity := pity_scale(drought, config)
	return PackedFloat64Array([
		config.common_weight,
		(config.magic_weight + config.magic_weight_per_depth * levels) * quality,
		(config.rare_weight + config.rare_weight_per_depth * levels) * quality * pity,
		(config.epic_weight + config.epic_weight_per_depth * levels) * quality * pity,
	])


## What `drought` finds without a Rare or better multiply the Rare and Epic weights by (1: none).
static func pity_scale(drought: int, config: DungeonConfig) -> float:
	if config.pity_after <= 0 or drought < config.pity_after:
		return 1.0
	return 1.0 + config.pity_growth * (drought - config.pity_after + 1)


## The chance that equipment found at `depth` from a source of `quality` is Rare or better
## (pick_rarity()'s own odds).
static func rare_or_better_chance(depth: int, quality: float, config: DungeonConfig) -> float:
	var weights := rarity_weights(depth, quality, config)
	return (weights[ItemRarity.RARE] + weights[ItemRarity.EPIC]) / _total(weights)


static func _total(weights: PackedFloat64Array) -> float:
	var total := 0.0
	for weight in weights:
		total += weight
	return total


## A copy of `base` with that rarity, those affixes and runes, at item `level` (also how saved
## items come back, and how a plain weapon becomes its own copy when a rune goes in).
static func make(base: EquipmentDef, rarity: int, affixes: Array[ItemAffixDef], runes: Array[RuneDef] = [], level: int = 1) -> EquipmentDef:
	var item := base.duplicate() as EquipmentDef
	item.base_item = base
	item.rarity = rarity
	item.affixes = affixes
	item.runes = runes.duplicate()  # its own list, never the plain item's
	item.item_level = maxi(level, 1)
	var power := ItemRarity.POWER[rarity]
	var total := StatBlock.new()
	if base.bonuses:
		total = total.plus(base.bonuses).scaled(power)
	# At most one prefix and one suffix in the name; more affixes still count.
	var prefix := ""
	var suffix := ""
	for affix in affixes:
		if affix.bonuses:
			total = total.plus(affix.bonuses)
		if affix.is_prefix and prefix.is_empty():
			prefix = affix.display_name
		elif not affix.is_prefix and suffix.is_empty():
			suffix = affix.display_name
	var health := LEVELS.armor_health(base.slot, item.item_level) if base.slot != EquipmentDef.Slot.WEAPON else 0
	if health > 0:
		total.max_hp += health
	item.bonuses = total
	item.display_name = rolled_name(base.display_name, prefix, suffix)
	var weapon := item as WeaponDef
	if weapon:
		var base_damage := (base as WeaponDef).damage
		# Better than common: at least one more damage. A common copy (a rune set in a plain weapon) keeps it.
		weapon.damage = base_damage if rarity == ItemRarity.COMMON else maxi(base_damage + 1, roundi(base_damage * power))
		weapon.damage += LEVELS.weapon_damage(base as WeaponDef, item.item_level)
		if weapon.on_hit == null:
			for affix in affixes:
				if affix.on_hit:
					weapon.on_hit = affix.on_hit
					break
	return item


# --- Saving -------------------------------------------------------------------

## "Sharp Katana of the Bear", in the player's language ("Katana Affûté de l'Ours", "Hache
## Affûtée"): the words go where the language puts them, the adjective agrees with the item
## (Grammar). Rolled names are made when the item is (and again when a saved run is loaded).
static func rolled_name(base_name: String, prefix: String, suffix: String) -> String:
	var words := {
		"item": TranslationServer.tr(base_name),
		"prefix": Grammar.adjective(prefix, base_name),
		"suffix": TranslationServer.tr(suffix),
	}
	if not prefix.is_empty() and not suffix.is_empty():
		return TranslationServer.tr("{prefix} {item} {suffix}").format(words)
	if not prefix.is_empty():
		return TranslationServer.tr("{prefix} {item}").format(words)
	if not suffix.is_empty():
		return TranslationServer.tr("{item} {suffix}").format(words)
	return words.item


## Plain items save as stable ids; rolled items keep base/affix/rune ids and rarity/level.
static func to_data(item: ItemDef) -> Variant:
	var equipment := item as EquipmentDef
	if equipment and equipment.is_rolled():
		return { "base": RunSave.ref(equipment.base_item), "rarity": equipment.rarity, "affixes": RunSave.refs(equipment.affixes), "runes": RunSave.refs(equipment.runes), "level": equipment.item_level }
	return RunSave.ref(item)


static func from_data(data: Variant) -> ItemDef:
	if data is Dictionary:
		var base := RunSave.load_ref(data.get("base")) as EquipmentDef
		if base == null:
			return null
		var affixes: Array[ItemAffixDef] = []
		for ref: Variant in data.get("affixes", []):
			var affix := RunSave.load_ref(ref) as ItemAffixDef
			if affix:
				affixes.append(affix)
		var runes: Array[RuneDef] = []
		for ref: Variant in data.get("runes", []):
			var rune := RunSave.load_ref(ref) as RuneDef
			if rune:
				runes.append(rune)
		return make(base, clampi(int(data.get("rarity", 1)), ItemRarity.COMMON, ItemRarity.EPIC), affixes, runes, maxi(int(data.get("level", 1)), 1))
	return RunSave.load_ref(data) as ItemDef
