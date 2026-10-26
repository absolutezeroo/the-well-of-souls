class_name CampaignProgress
extends RefCounted
## Permanent talents and quest payments. Edit a copied checkpoint, publish it, then apply the
## acknowledged change to the live hero. No random offers, run currency or Profile writes.

const PLAYER := preload("res://src/entities/player/player.tscn")
var coordinator: RegionCoordinator
var definition: CampaignDef


func _init(regions: RegionCoordinator, campaign_def: CampaignDef) -> void:
	coordinator = regions
	definition = campaign_def


func points() -> int:
	var spent := 0
	for key in coordinator.session.campaign.hero.claimed_rewards:
		if key.begins_with("talent:") and coordinator.session.campaign.hero.claimed_rewards[key]:
			spent += 1
	return maxi(0, coordinator.session.character.level - 1 - spent)


func learn(talent: PerkDef) -> bool:
	var hero := coordinator.session.character
	if hero.is_dead or points() <= 0 or not definition.talents.has(talent) or not hero.perks.can_take(talent):
		return false
	var candidate := coordinator.snapshot()
	if candidate == null:
		return false
	var data := candidate.hero.to_data()
	var found := false
	for perk: Dictionary in data.player.perks:
		if perk.perk == RunSave.ref(talent):
			perk.stacks = int(perk.stacks) + 1
			found = true
	if not found:
		data.player.perks.append({ "perk": RunSave.ref(talent), "stacks": 1, "memory": {} })
	var claim := "talent:%s:%d" % [talent.id, hero.perks.stacks_of(talent) + 1]
	data.claimed_rewards[claim] = true
	candidate.hero = CharacterState.from_data(data)
	if not coordinator.commit_snapshot(candidate):
		return false
	hero.world.spawns.begin_settlement()
	hero.perks.add(talent)
	hero.world.spawns.end_settlement()
	return true


func accepted(quest: CampaignQuestDef) -> bool:
	return coordinator.session.campaign.world_state.facts.get("quest:" + quest.id + ":accepted", false)


func paid(quest: CampaignQuestDef) -> bool:
	return coordinator.session.campaign.hero.claimed_rewards.get("quest:" + quest.id, false)


## Accept and turn in only at the refuge. The same personal claim and gold transfer are
## committed together; retrying a completed payment cannot create a second reward.
func advance(quest: CampaignQuestDef) -> bool:
	if not definition.quests.has(quest) or coordinator.current_id != definition.refuge_region \
			or coordinator.session.character.is_dead or paid(quest):
		return false
	var candidate := coordinator.snapshot()
	if candidate == null:
		return false
	var reward := 0
	if not accepted(quest):
		candidate.world_state.facts["quest:" + quest.id + ":accepted"] = true
	elif quest.completed(candidate):
		candidate.hero.claimed_rewards["quest:" + quest.id] = true
		var data := candidate.hero.to_data()
		reward = quest.reward_gold
		data.player.gold = int(data.player.gold) + reward
		candidate.hero = CharacterState.from_data(data)
	else:
		return false
	if not coordinator.commit_snapshot(candidate):
		return false
	if reward > 0:
		var hero := coordinator.session.character
		hero.world.spawns.begin_settlement()
		hero.add_gold(reward)
		hero.world.spawns.end_settlement()
	return true


func purchased(supply: CampaignSupplyDef) -> bool:
	return coordinator.session.campaign.hero.claimed_rewards.get("supply:" + supply.id, false)


func purchase(supply: CampaignSupplyDef) -> bool:
	var hero := coordinator.session.character
	if not definition.supplies.has(supply) or purchased(supply) or hero.is_dead \
			or coordinator.current_id != definition.refuge_region or hero.gold < supply.price or not hero.pack.can_store(supply.item):
		return false
	var candidate := coordinator.snapshot()
	if candidate == null:
		return false
	# A detached model uses the existing pack/belt capacities and item codec, without live
	# transfer signals or VFX before publication. Failed purchases leave the live pack intact.
	var model := PLAYER.instantiate() as Player
	model.setup(hero.def)
	candidate.hero.restore(model)
	model.position = candidate.hero.position
	var stored := model.pack.store(supply.item)
	model.gold -= supply.price
	var captured := stored and candidate.hero.capture(model)
	model.free()
	if not captured:
		return false
	candidate.hero.claimed_rewards["supply:" + supply.id] = true
	if not coordinator.commit_snapshot(candidate):
		return false
	hero.world.spawns.begin_settlement()
	hero.spend_gold(supply.price)
	hero.pack.store(supply.item)
	hero.world.spawns.end_settlement()
	return true
