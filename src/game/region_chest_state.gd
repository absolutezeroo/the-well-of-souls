class_name RegionChestState
extends RefCounted
## Open state and pending trap, without re-opening the chest or replaying its rewards.

var id := ""
var definition: ChestDef
var cell := Vector2i.ZERO
var opened := false
var trapped := false
var fuse := -1.0


func to_data() -> Dictionary:
	return { "id": id, "definition": RunSave.ref(definition), "cell": [cell.x, cell.y],
		"opened": opened, "trapped": trapped, "fuse": fuse }


static func from_data(value: Variant) -> RegionChestState:
	if not CampaignFormat.keys(value, ["id", "definition", "cell", "opened", "trapped", "fuse"]) \
			or not value.id is String or value.id.is_empty() or not CampaignFormat.point(value.cell) \
			or not CampaignFormat.integer(value.cell[0]) or not CampaignFormat.integer(value.cell[1]) \
			or not value.opened is bool or not value.trapped is bool or not CampaignFormat.number(value.fuse):
		return null
	var def := CampaignFormat.content_ref(value.definition) as ChestDef
	if def == null or (value.fuse != -1.0 and (value.fuse < 0.0 or not value.opened or not value.trapped)):
		return null
	var result := RegionChestState.new()
	result.id = value.id
	result.definition = def
	result.cell = Vector2i(value.cell[0], value.cell[1])
	result.opened = value.opened
	result.trapped = value.trapped
	result.fuse = float(value.fuse)
	return result
