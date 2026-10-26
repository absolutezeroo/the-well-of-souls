class_name CampaignDef
extends Resource
## The solo RPG's starting place, safe return and permanent progression catalog.
## Campaigns never inherit a daily seed, shrine bonuses or account/cloud state.

@export var atlas: RegionAtlas
@export var refuge_region: String
@export var refuge_entry: String
@export var talents: Array[PerkDef] = []
@export var quests: Array[CampaignQuestDef] = []
@export var supplies: Array[CampaignSupplyDef] = []
@export var keeper_cell := Vector2i(12, 9)
@export var rest_cell := Vector2i(10, 8)
@export var autosave_seconds := 30.0


func valid() -> bool:
	if atlas == null or not atlas.valid() or autosave_seconds <= 0.0:
		return false
	var refuge := atlas.find(refuge_region)
	if refuge == null or not refuge.entries.has(refuge_entry) or not refuge.monsters.is_empty():
		return false
	var ids: Dictionary[String, bool] = {}
	for talent in talents:
		if talent == null or talent.rarity != PerkDef.Rarity.COMMON or ids.has(String(talent.id)) or RunSave.ref(talent).is_empty():
			return false
		ids[String(talent.id)] = true
	ids.clear()
	for quest in quests:
		if quest == null or ids.has(quest.id) or not quest.valid(atlas):
			return false
		ids[quest.id] = true
	ids.clear()
	for supply in supplies:
		if supply == null or supply.id.is_empty() or ids.has(supply.id) or supply.item == null \
				or supply.price < 0 or not CampaignFormat.item_data(LootRoller.to_data(supply.item)):
			return false
		ids[supply.id] = true
	var refuge_map := refuge.make_map(refuge_entry)
	return refuge_map.is_ground(keeper_cell) and refuge_map.is_ground(rest_cell)
