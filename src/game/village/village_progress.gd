class_name VillageProgress
extends RefCounted
## Transactions share the profile's atomic file with souls, quests and restoration flags.
## No UI or expedition mutates these dictionaries directly. A refused write publishes nothing.

enum Step { AVAILABLE, ACCEPTED, FOUND, RETURNED }


static func topic_available(topic: VillageTopicDef) -> bool:
	return (topic.quest == null or (stage(topic.quest) >= topic.min_stage and stage(topic.quest) <= topic.max_stage)) \
		and (topic.after_quest == null or stage(topic.after_quest) == Step.RETURNED)


static func greeting(resident: VillageResidentDef) -> String:
	for reaction in resident.reactions:
		if topic_available(reaction):
			return reaction.reply
	if resident.quest:
		match stage(resident.quest):
			Step.ACCEPTED:
				if not resident.accepted_text.is_empty(): return resident.accepted_text
			Step.FOUND:
				if not resident.found_text.is_empty(): return resident.found_text
			Step.RETURNED: return resident.used_text
	return resident.text

static func stage(quest: VillageQuestDef) -> Step:
	return int(Profile.village_quests.get(String(quest.id), Step.AVAILABLE)) as Step


static func accept(quest: VillageQuestDef) -> bool:
	if not can_accept(quest):
		return false
	return _advance(quest, Step.AVAILABLE, Step.ACCEPTED)


static func can_accept(quest: VillageQuestDef) -> bool:
	return quest != null and not Profile.held and stage(quest) == Step.AVAILABLE \
		and (quest.requires_quest == null or stage(quest.requires_quest) == Step.RETURNED)


static func discover(quest: VillageQuestDef) -> bool:
	return _advance(quest, Step.ACCEPTED, Step.FOUND)


static func hand_in(quest: VillageQuestDef) -> bool:
	return _advance(quest, Step.FOUND, Step.RETURNED)


static func _advance(quest: VillageQuestDef, expected: Step, next: Step) -> bool:
	if quest == null or stage(quest) != expected or Profile.held:
		return false
	var data := Profile.to_data().duplicate(true)
	data.village_quests[String(quest.id)] = next
	if next == Step.RETURNED:
		data.souls = int(data.souls) + quest.reward_souls
	return Profile.from_data(data)


## Whether a prop stands now: a sleeping home's roots and overgrown facade go when its quest is
## returned, the woken facade comes with it.
static func prop_present(prop: VillagePropDef) -> bool:
	return (prop.cleared_by == null or stage(prop.cleared_by) != Step.RETURNED) \
		and (prop.shown_after == null or stage(prop.shown_after) == Step.RETURNED)


static func room_open(room: VillageInteriorDef) -> bool:
	return room.opens_after == null or stage(room.opens_after) == Step.RETURNED


static func restored(service: VillageServiceDef) -> bool:
	return Profile.village_services.has(String(service.id))


static func can_buy(service: VillageServiceDef) -> bool:
	return service != null and not Profile.held and not restored(service) and service.cost >= 0 \
		and Profile.souls >= service.cost \
		and (service.requires_quest == null or stage(service.requires_quest) == Step.RETURNED)


static func buy(service: VillageServiceDef) -> bool:
	if not can_buy(service):
		return false
	var data := Profile.to_data().duplicate(true)
	data.souls = int(data.souls) - service.cost
	data.village_services[String(service.id)] = 1
	return Profile.from_data(data)
