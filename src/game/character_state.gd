class_name CharacterState
extends RefCounted
## A durable character snapshot, independent of a live Player or dungeon. The player block
## is disk data in the existing PlayerSave format, copied at capture/restore boundaries.

var id := ""
var world_id := ""
var region_id := ""
var position := Vector2.ZERO
## Personal reward rights are separate from the world's shared facts.
var claimed_rewards: Dictionary[String, bool] = {}
var _player_data: Dictionary = {}


func capture(player: Player) -> bool:
	if not is_instance_valid(player) or player.is_dead or not player.global_position.is_finite():
		return false
	var data := player.save_state()
	if not CampaignFormat.player_data(data):
		return false
	_player_data = data.duplicate(true)
	position = player.global_position
	return true


## Death recovery captures the current inventory/XP, never an older living checkpoint.
## Only the dedicated recovery path may normalize zero Health into a living saved record.
func capture_recovery(player: Player) -> bool:
	if not is_instance_valid(player) or not player.is_dead or not player.global_position.is_finite():
		return false
	var data := player.save_state()
	data.hp = player.get_max_hp()
	if not CampaignFormat.player_data(data):
		return false
	_player_data = data.duplicate(true)
	position = player.global_position
	return true


## Caller owns region loading and safe placement; this restores the hero's gameplay data only.
func restore(player: Player) -> bool:
	if not is_instance_valid(player) or player.is_dead or not CampaignFormat.player_data(_player_data):
		return false
	player.load_state(_player_data.duplicate(true))
	return true


func to_data() -> Dictionary:
	return { "id": id, "world_id": world_id, "region_id": region_id,
		"position": [position.x, position.y], "claimed_rewards": claimed_rewards.duplicate(),
		"player": _player_data.duplicate(true) }


static func from_data(value: Variant) -> CharacterState:
	if not CampaignFormat.keys(value, ["id", "world_id", "region_id", "position", "claimed_rewards", "player"]):
		return null
	if not PersistentId.valid(value.id, "character") or not PersistentId.valid(value.world_id, "world") \
			or not value.region_id is String or value.region_id.is_empty() \
			or not CampaignFormat.point(value.position) or not CampaignFormat.flag_map(value.claimed_rewards) \
			or not CampaignFormat.player_data(value.player):
		return null
	var result := CharacterState.new()
	result.id = value.id
	result.world_id = value.world_id
	result.region_id = value.region_id
	result.position = Vector2(value.position[0], value.position[1])
	result.claimed_rewards.assign(value.claimed_rewards)
	result._player_data = value.player.duplicate(true)
	return result
