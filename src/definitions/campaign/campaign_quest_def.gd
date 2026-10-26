class_name CampaignQuestDef
extends Resource
## A campaign objective with an explicit shared-world completion condition and personal payout.
## New objective behaviours can override completed(), without branches in the campaign UI.

@export var id: String
@export var display_name: String
@export_multiline var description: String
@export var region_id: String
@export var defeated_spawns: PackedStringArray
@export var reward_gold := 0


func completed(state: CampaignState) -> bool:
	var region: RegionState = state.world_state.regions.get(region_id)
	if region == null or not region.initialized:
		return false
	for spawn_id in defeated_spawns:
		var monster: RegionMonsterState = region.monsters.get("monster:" + region_id + "/" + spawn_id)
		if monster == null or not monster.dead:
			return false
	return true


func valid(atlas: RegionAtlas) -> bool:
	var region := atlas.find(region_id)
	if id.is_empty() or display_name.is_empty() or region == null or reward_gold < 0:
		return false
	for spawn_id in defeated_spawns:
		var found := false
		for spawn in region.monsters:
			found = found or spawn.id == spawn_id
		if not found:
			return false
	return true
