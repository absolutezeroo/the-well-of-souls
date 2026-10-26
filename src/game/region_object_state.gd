class_name RegionObjectState
extends RefCounted
## Stable identity and exact serialized item of a pickup left in a region. The item is not
## rerolled on revisit. Inventory instance identities and other entity kinds remain later work.

var id := ""
var position := Vector2.ZERO
var _item_data: Variant


static func create(object_id: String, item_def: ItemDef, at: Vector2) -> RegionObjectState:
	return from_data({ "id": object_id, "position": [at.x, at.y], "item": LootRoller.to_data(item_def) })


func item() -> ItemDef:
	return LootRoller.from_data(_item_data)


func to_data() -> Dictionary:
	var saved: Variant = _item_data.duplicate(true) if _item_data is Dictionary else _item_data
	return { "id": id, "position": [position.x, position.y], "item": saved }


static func from_data(value: Variant) -> RegionObjectState:
	if not CampaignFormat.keys(value, ["id", "position", "item"]) or not value.id is String \
			or value.id.is_empty() or not CampaignFormat.point(value.position) or not CampaignFormat.item_data(value.item):
		return null
	var result := RegionObjectState.new()
	result.id = value.id
	result.position = Vector2(value.position[0], value.position[1])
	result._item_data = value.item.duplicate(true) if value.item is Dictionary else value.item
	return result
