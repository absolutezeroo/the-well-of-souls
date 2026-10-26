class_name VillageProgress
extends RefCounted
## Transactions share the profile's atomic file with souls, quests and restoration flags.
## No UI or expedition mutates these dictionaries directly. A refused write publishes nothing.

enum Step { AVAILABLE, ACCEPTED, FOUND, RETURNED }

static func stage(quest: VillageQuestDef) -> Step:
	return int(Profile.village_quests.get(String(quest.id), Step.AVAILABLE)) as Step


static func accept(quest: VillageQuestDef) -> bool:
	return _advance(quest, Step.AVAILABLE, Step.ACCEPTED)


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
