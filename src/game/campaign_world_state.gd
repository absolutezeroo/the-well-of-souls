class_name CampaignWorldState
extends RefCounted
## Campaign-owned facts and independently keyed regions, separate from a runtime World scene.

var id := ""
var facts: Dictionary[String, bool] = {}
var regions: Dictionary[String, RegionState] = {}


func to_data() -> Dictionary:
	var saved_regions := {}
	for key in regions:
		if regions[key] == null:
			return {}
		saved_regions[key] = regions[key].to_data()
	return { "id": id, "facts": facts.duplicate(), "regions": saved_regions }


static func from_data(value: Variant) -> CampaignWorldState:
	if not CampaignFormat.keys(value, ["id", "facts", "regions"]) or not PersistentId.valid(value.id, "world") \
			or not CampaignFormat.flag_map(value.facts) or not value.regions is Dictionary:
		return null
	var result := CampaignWorldState.new()
	result.id = value.id
	result.facts.assign(value.facts)
	for key: Variant in value.regions:
		if not key is String:
			return null
		var region := RegionState.from_data(value.regions[key])
		if region == null or region.id != key:
			return null
		result.regions[key] = region
	return result
