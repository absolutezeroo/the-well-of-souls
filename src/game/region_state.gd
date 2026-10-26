class_name RegionState
extends RefCounted
## Persistent region facts; no map nodes. Layout revisions are explicit and never reset facts
## merely because the game's build changed. Full layout/loot/monster persistence is later work.

var id := ""
var layout_version := 1
var facts: Dictionary[String, bool] = {}


func to_data() -> Dictionary:
	return { "id": id, "layout_version": layout_version, "facts": facts.duplicate() }


static func from_data(value: Variant) -> RegionState:
	if not CampaignFormat.keys(value, ["id", "layout_version", "facts"]) or not value.id is String \
			or value.id.is_empty() or not CampaignFormat.integer(value.layout_version, 1) \
			or not CampaignFormat.flag_map(value.facts):
		return null
	var result := RegionState.new()
	result.id = value.id
	result.layout_version = int(value.layout_version)
	result.facts.assign(value.facts)
	return result
