class_name EliteAffixDef
extends ContentDef
## What makes an elite monster special: "Swift", "Vampiric", "Explosive"...
## `display_name` goes before the monster's name ("Vampiric Skeleton"), `color` is its glow.
## Every elite is also tougher, bigger and worth more (DungeonConfig > Elites).

## Stats and passives the monster gets: a perk, just like the hero's.
@export var perk: PerkDef
## On top of the elite HP bonus every elite gets.
@export var hp_multiplier: float = 1.0
## Optional reusable behaviours, applied after this affix's perk. Never mutated at runtime.
@export var traits: Array[MonsterTrait] = []

@export_group("Compatibility")
@export var allow_bosses: bool = true
## 0 means no upper depth limit; min_depth is inherited from ContentDef.
@export_range(0, 99) var max_depth: int = 0
## All required tags must belong to MonsterDef.tags; any excluded tag rejects the affix.
@export var required_tags: Array[StringName] = []
@export var excluded_tags: Array[StringName] = []
@export var excluded_monsters: Array[StringName] = []
## Stable affix ids. Exclusion works both ways even if only one resource declares it.
@export var excludes: Array[StringName] = []


## Used by random selection and by manual/restored applications, in saved affix order.
func fits(monster: MonsterDef, depth: int, chosen: Array[EliteAffixDef]) -> bool:
	if monster == null or depth < min_depth or (max_depth > 0 and depth > max_depth):
		return false
	if (not allow_bosses and monster is BossDef) or excluded_monsters.has(monster.id):
		return false
	for tag in required_tags:
		if not monster.tags.has(tag):
			return false
	for tag in excluded_tags:
		if monster.tags.has(tag):
			return false
	for other in chosen:
		if other and (other == self or other.id == id or excludes.has(other.id) or other.excludes.has(id)):
			return false
	return true
