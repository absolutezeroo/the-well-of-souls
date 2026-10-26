class_name RegionFloorKind
extends FloorKind
## An authored place uses the existing rendering/collision pipeline, without random population
## or run-depth stairs. Its coordinator owns persistent entities and destination links.

var definition: RegionDef
var entry_id: String


func _init(region: RegionDef, entry: String) -> void:
	definition = region
	entry_id = entry


func pick_biome(_world: World, _content: ContentDB) -> BiomeDef:
	return definition.biome


func generate(_world: World, _content: ContentDB) -> DungeonMap:
	return definition.make_map(entry_id)
