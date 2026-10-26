class_name RegionMonsterState
extends RefCounted
## Exact remaining Health and death tombstone, identity, composition and lasting counters.
## AI windups, temporary statuses and targets restart; no kill/reward is replayed on restore.

var id := ""
var definition: MonsterDef
var position := Vector2.ZERO
var health := 1
var dead := false
var summoned := false
var dormant := false
var rank: MonsterRankDef
var affixes: Array[EliteAffixDef] = []
var trait_data: Array = []
var perk_memory: Dictionary = {}


static func capture(key: String, monster: Monster) -> RegionMonsterState:
	var result := RegionMonsterState.new()
	result.id = key
	result.definition = monster.def
	result.position = monster.global_position
	result.dead = monster.is_dead
	result.health = 0 if result.dead else monster.hp
	result.summoned = monster.summoned
	result.dormant = monster.dormant
	result.rank = monster.rank
	result.affixes = monster.affixes.duplicate()
	result.trait_data = monster.behaviors.persistent_data()
	result.perk_memory = monster.perks.persistent_memory()
	return from_data(result.to_data())


func to_data() -> Dictionary:
	return { "id": id, "definition": RunSave.ref(definition), "position": [position.x, position.y],
		"health": health, "dead": dead, "summoned": summoned, "dormant": dormant,
		"rank": RunSave.ref(rank), "affixes": RunSave.refs(affixes),
		"traits": trait_data.duplicate(true), "memory": perk_memory.duplicate(true) }


## Only fields that require a live actor are applied here, after the composition is built.
func restore(monster: Monster) -> bool:
	monster.summoned = summoned
	monster.dormant = dormant
	if rank:
		monster.make_ranked(rank, affixes)
	if not monster.behaviors.restore_persistent_data(trait_data) or not monster.perks.restore_memory(perk_memory):
		return false
	monster.hp = clampi(health, 1, monster.get_max_hp())
	monster.health_changed.emit(monster.hp, monster.get_max_hp())
	return true


static func from_data(value: Variant) -> RegionMonsterState:
	if not CampaignFormat.keys(value, ["id", "definition", "position", "health", "dead", "summoned", "dormant", "rank", "affixes", "traits", "memory"]) \
			or not value.id is String or value.id.is_empty() or not CampaignFormat.point(value.position) \
			or not CampaignFormat.integer(value.health) or not value.dead is bool or not value.summoned is bool \
			or not value.dormant is bool or not value.affixes is Array or not value.traits is Array \
			or not value.memory is Dictionary or not CampaignFormat.plain(value):
		return null
	var def := CampaignFormat.content_ref(value.definition) as MonsterDef
	var saved_rank := CampaignFormat.content_ref(value.rank) as MonsterRankDef
	if def == null or def is BossDef or value.dead != (value.health == 0) \
			or (value.rank != "" and saved_rank == null) or (saved_rank == null and not value.affixes.is_empty()):
		return null
	var result := RegionMonsterState.new()
	result.id = value.id
	result.definition = def
	result.position = Vector2(value.position[0], value.position[1])
	result.health = int(value.health)
	result.dead = value.dead
	result.summoned = value.summoned
	result.dormant = value.dormant
	result.rank = saved_rank
	for ref: Variant in value.affixes:
		var affix := CampaignFormat.content_ref(ref) as EliteAffixDef
		if affix == null or result.affixes.has(affix):
			return null
		result.affixes.append(affix)
	if saved_rank and result.affixes.size() > saved_rank.affixes:
		return null
	var modules := MonsterTraits.composition(def, result.affixes)
	if not MonsterTraits.accepts_data(modules, value.traits):
		return null
	var known_perks: Dictionary[String, bool] = {}
	for module in modules:
		for perk in module.granted_perks():
			if perk:
				known_perks[String(perk.id)] = true
	for affix in result.affixes:
		if affix.perk:
			known_perks[String(affix.perk.id)] = true
	for key: String in value.memory:
		if key.is_empty() or not known_perks.has(key) or not value.memory[key] is Dictionary:
			return null
	result.trait_data = value.traits.duplicate(true)
	result.perk_memory = value.memory.duplicate(true)
	return result
