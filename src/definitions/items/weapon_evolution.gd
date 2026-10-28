class_name WeaponEvolution
## Weapon evolutions (docs/design/loot.md "Weapon evolutions"; Vampire Survivors' model, a weapon
## at its fullest plus the matching passive): a weapon whose sockets all hold runes of a family,
## worn while that family is awake (three of its perks), can be tempered at a forge into its
## evolved form (a WeaponDef with `evolved_from`): a new behaviour of its attack, its charged
## attack or what it does by itself (WeaponDef.carried). The runes melt into the steel (its
## sockets are free again); its rarity, affixes and item level are kept. The evolved weapons are
## in ContentDB > Items with no spawn weight: never found, never sold, never a start.


## The evolved form `weapon` (plain or rolled) could become, or null.
static func of(content: ContentDB, weapon: EquipmentDef) -> WeaponDef:
	var base := base_of(weapon)
	if base == null or content == null:
		return null
	for item in content.items:
		if item is WeaponDef and (item as WeaponDef).evolved_from == base:
			return item as WeaponDef
	return null


## Every evolved weapon of the content, in its order.
static func all(content: ContentDB) -> Array[WeaponDef]:
	var result: Array[WeaponDef] = []
	for item in content.items:
		if item is WeaponDef and (item as WeaponDef).evolved_from != null:
			result.append(item as WeaponDef)
	return result


## The plain weapon a copy was rolled from (itself when plain).
static func base_of(weapon: EquipmentDef) -> WeaponDef:
	if weapon == null:
		return null
	if weapon.base_item is WeaponDef:
		return weapon.base_item as WeaponDef
	return weapon as WeaponDef


## Runes of `family` set in `weapon`, and its sockets.
static func family_runes(weapon: EquipmentDef, family: SynergyDef) -> int:
	return weapon.runes.filter(func(rune: RuneDef) -> bool: return rune != null and rune.family == family).size()


## `weapon` (whose form `into` is) can be tempered now: every socket holds a rune of the family,
## and the family is awake on `perks`.
static func is_ready(weapon: EquipmentDef, into: WeaponDef, perks: PerkSet) -> bool:
	if weapon == null or into == null or into.evolution_family == null or base_of(weapon) != into.evolved_from:
		return false
	var sockets := weapon.socket_count()
	return sockets > 0 and family_runes(weapon, into.evolution_family) == sockets and perks.is_awake(into.evolution_family)


## What is still missing, in a sentence (empty when ready).
static func missing(weapon: EquipmentDef, into: WeaponDef, perks: PerkSet) -> String:
	var family := TranslationServer.tr(into.evolution_family.display_name)
	var have := family_runes(weapon, into.evolution_family)
	var sockets := weapon.socket_count()
	var runes_full := have == sockets and sockets > 0
	var awake := perks.is_awake(into.evolution_family)
	if not runes_full and not awake:
		return TranslationServer.tr("Fill its sockets with {family} runes ({have} of {sockets}) and wake the {family} family.").format({ "family": family, "have": have, "sockets": sockets })
	if not runes_full:
		return TranslationServer.tr("Fill its sockets with {family} runes ({have} of {sockets}).").format({ "family": family, "have": have, "sockets": sockets })
	if not awake:
		return TranslationServer.tr("Wake the {family} family (3 of its perks).").format({ "family": family })
	return ""


## The evolved copy of `weapon`: `into`, with its rarity, affixes and item level; the runes are
## spent (melted into it), its sockets free.
static func evolve(weapon: EquipmentDef, into: WeaponDef) -> EquipmentDef:
	return LootRoller.make(into, weapon.rarity, weapon.affixes.duplicate(), [], weapon.item_level)
