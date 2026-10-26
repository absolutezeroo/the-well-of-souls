class_name RegionGoldState
extends RefCounted
## Already-scaled currency left on the ground. Restoration must not apply FloorRules again.

var id := ""
var position := Vector2.ZERO
var amount := 0


func to_data() -> Dictionary:
	return { "id": id, "position": [position.x, position.y], "amount": amount }


static func from_data(value: Variant) -> RegionGoldState:
	if not CampaignFormat.keys(value, ["id", "position", "amount"]) or not value.id is String \
			or value.id.is_empty() or not CampaignFormat.point(value.position) or not CampaignFormat.integer(value.amount, 1):
		return null
	var result := RegionGoldState.new()
	result.id = value.id
	result.position = Vector2(value.position[0], value.position[1])
	result.amount = int(value.amount)
	return result
