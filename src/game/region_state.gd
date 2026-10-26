class_name RegionState
extends RefCounted
## Persistent region facts, loot, enemies and chests; no map nodes. Geometry and population
## have explicit stamps. Exploration is a bounded byte-per-cell map; NPC/door activities are separate.

var id := ""
var layout_version := 1
var facts: Dictionary[String, bool] = {}
var explored := PackedByteArray()
## First-entry spawns happen once; an empty object map after collection must stay empty.
var initialized := false
var layout_stamp := ""
var objects: Dictionary[String, RegionObjectState] = {}
var gold: Dictionary[String, RegionGoldState] = {}
var monsters: Dictionary[String, RegionMonsterState] = {}
var chests: Dictionary[String, RegionChestState] = {}
## Added separately from geometry so a v2 region can adopt its first population explicitly.
var population_initialized := false
var population_stamp := ""


func to_data() -> Dictionary:
	var saved_objects := {}
	for key in objects:
		if objects[key] == null:
			return {}
		saved_objects[key] = objects[key].to_data()
	var saved_gold := {}
	for key in gold:
		if gold[key] == null:
			return {}
		saved_gold[key] = gold[key].to_data()
	var saved_monsters := {}
	for key in monsters:
		if monsters[key] == null:
			return {}
		saved_monsters[key] = monsters[key].to_data()
	var saved_chests := {}
	for key in chests:
		if chests[key] == null:
			return {}
		saved_chests[key] = chests[key].to_data()
	return { "id": id, "layout_version": layout_version, "facts": facts.duplicate(), "explored": explored.hex_encode(),
		"initialized": initialized, "layout_stamp": layout_stamp, "objects": saved_objects,
		"gold": saved_gold, "monsters": saved_monsters, "chests": saved_chests,
		"population_initialized": population_initialized, "population_stamp": population_stamp }


static func from_data(value: Variant) -> RegionState:
	if not CampaignFormat.keys(value, ["id", "layout_version", "facts", "explored", "initialized", "layout_stamp", "objects", "gold", "monsters", "chests", "population_initialized", "population_stamp"]) or not value.id is String \
			or value.id.is_empty() or not CampaignFormat.integer(value.layout_version, 1) \
			or not CampaignFormat.flag_map(value.facts) or not _valid_exploration(value.explored) or not value.initialized is bool \
			or not value.layout_stamp is String or not value.objects is Dictionary \
			or not value.gold is Dictionary or not value.monsters is Dictionary or not value.chests is Dictionary \
			or not value.population_initialized is bool or not value.population_stamp is String:
		return null
	var result := RegionState.new()
	result.id = value.id
	result.layout_version = int(value.layout_version)
	result.facts.assign(value.facts)
	result.explored = value.explored.hex_decode()
	result.initialized = value.initialized
	result.layout_stamp = value.layout_stamp
	if (result.initialized and result.layout_stamp.length() != 64) \
			or (not result.initialized and (not value.objects.is_empty() or not result.explored.is_empty() or not result.layout_stamp.is_empty())):
		return null
	for key: Variant in value.objects:
		var object_state := RegionObjectState.from_data(value.objects[key])
		if not key is String or object_state == null or object_state.id != key:
			return null
		result.objects[key] = object_state
	for key: Variant in value.gold:
		var coin := RegionGoldState.from_data(value.gold[key])
		if not key is String or coin == null or key != coin.id:
			return null
		result.gold[key] = coin
	for key: Variant in value.monsters:
		var monster := RegionMonsterState.from_data(value.monsters[key])
		if not key is String or monster == null or key != monster.id:
			return null
		result.monsters[key] = monster
	for key: Variant in value.chests:
		var chest := RegionChestState.from_data(value.chests[key])
		if not key is String or chest == null or key != chest.id:
			return null
		result.chests[key] = chest
	result.population_initialized = value.population_initialized
	result.population_stamp = value.population_stamp
	if (result.population_initialized and (not result.initialized or result.population_stamp.length() != 64)) \
			or (not result.population_initialized and (not result.population_stamp.is_empty() \
			or not result.monsters.is_empty() or not result.chests.is_empty() or not result.gold.is_empty())):
		return null
	return result


static func _valid_exploration(value: Variant) -> bool:
	if not value is String or value.length() > RegionDef.MAX_SIDE * RegionDef.MAX_SIDE * 2 or value.length() % 2 != 0:
		return false
	for i in range(0, value.length(), 2):
		if value.substr(i, 2) != "00" and value.substr(i, 2) != "01":
			return false
	return true
