class_name RegionAtlas
extends Resource
## Authored registry and validated destination graph. Adding a place changes data, not Game.

@export var start_region: String
@export var start_entry: String
@export var regions: Array[RegionDef] = []


func find(region_id: String) -> RegionDef:
	for region in regions:
		if region and region.id == region_id:
			return region
	return null


func valid() -> bool:
	var seen: Dictionary[String, bool] = {}
	for region in regions:
		if region == null or not region.valid() or seen.has(region.id):
			return false
		seen[region.id] = true
	var start := find(start_region)
	if start == null or not start.entries.has(start_entry):
		return false
	for region in regions:
		for link in region.links:
			var destination := find(link.destination)
			if destination == null or not destination.entries.has(link.entry):
				return false
	return true
