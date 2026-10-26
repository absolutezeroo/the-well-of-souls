class_name RegionState
extends RefCounted
## Persistent region facts and loose items; no map nodes. Authored geometry has an explicit
## stamp and revision. Monster, NPC and destructible-state persistence is later work.

var id := ""
var layout_version := 1
var facts: Dictionary[String, bool] = {}
## First-entry spawns happen once; an empty object map after collection must stay empty.
var initialized := false
var layout_stamp := ""
var objects: Dictionary[String, RegionObjectState] = {}


func to_data() -> Dictionary:
	var saved_objects := {}
	for key in objects:
		if objects[key] == null:
			return {}
		saved_objects[key] = objects[key].to_data()
	return { "id": id, "layout_version": layout_version, "facts": facts.duplicate(),
		"initialized": initialized, "layout_stamp": layout_stamp, "objects": saved_objects }


static func from_data(value: Variant) -> RegionState:
	if not CampaignFormat.keys(value, ["id", "layout_version", "facts", "initialized", "layout_stamp", "objects"]) or not value.id is String \
			or value.id.is_empty() or not CampaignFormat.integer(value.layout_version, 1) \
			or not CampaignFormat.flag_map(value.facts) or not value.initialized is bool \
			or not value.layout_stamp is String or not value.objects is Dictionary:
		return null
	var result := RegionState.new()
	result.id = value.id
	result.layout_version = int(value.layout_version)
	result.facts.assign(value.facts)
	result.initialized = value.initialized
	result.layout_stamp = value.layout_stamp
	if (result.initialized and result.layout_stamp.length() != 64) \
			or (not result.initialized and (not value.objects.is_empty() or not result.layout_stamp.is_empty())):
		return null
	for key: Variant in value.objects:
		var object_state := RegionObjectState.from_data(value.objects[key])
		if not key is String or object_state == null or object_state.id != key:
			return null
		result.objects[key] = object_state
	return result
