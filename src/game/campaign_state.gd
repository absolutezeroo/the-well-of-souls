class_name CampaignState
extends RefCounted
## One coherent solo campaign snapshot. Revision advances only on a committed save; node and
## account references never belong here. The legacy run is not implicitly imported.

var id := ""
var revision := 0
var content_version := ""
var hero: CharacterState
var world_state: CampaignWorldState


## Explicit prototype capture, not a migration or an automatic title-screen action.
static func create(player: Player, region_id: String) -> CampaignState:
	if region_id.is_empty():
		return null
	var result := CampaignState.new()
	result.id = PersistentId.create("campaign")
	result.content_version = str(ProjectSettings.get_setting("application/config/version", ""))
	result.world_state = CampaignWorldState.new()
	result.world_state.id = PersistentId.create("world")
	var region := RegionState.new()
	region.id = region_id
	result.world_state.regions[region.id] = region
	result.hero = CharacterState.new()
	result.hero.id = PersistentId.create("character")
	result.hero.world_id = result.world_state.id
	result.hero.region_id = region_id
	if not result.hero.capture(player):
		return null
	return from_data(result.to_data())


func to_data() -> Dictionary:
	if hero == null or world_state == null:
		return {}
	return { "id": id, "revision": revision, "content_version": content_version,
		"hero": hero.to_data(), "world": world_state.to_data() }


static func from_data(value: Variant) -> CampaignState:
	if not CampaignFormat.keys(value, ["id", "revision", "content_version", "hero", "world"]) \
			or not PersistentId.valid(value.id, "campaign") or not CampaignFormat.integer(value.revision) \
			or not value.content_version is String or value.content_version.is_empty():
		return null
	var hero_state := CharacterState.from_data(value.hero)
	var world_snapshot := CampaignWorldState.from_data(value.world)
	if hero_state == null or world_snapshot == null or hero_state.world_id != world_snapshot.id \
			or not world_snapshot.regions.has(hero_state.region_id):
		return null
	var result := CampaignState.new()
	result.id = value.id
	result.revision = int(value.revision)
	result.content_version = value.content_version
	result.hero = hero_state
	result.world_state = world_snapshot
	return result
