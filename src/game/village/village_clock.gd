class_name VillageClock
extends RefCounted
## A shared clock for village and expeditions. Menus/background do not advance it and it does
## not drive UTC bounties, dungeon dice or infestation. Profile's usual atomic writes keep it.

static func advance(seconds: float) -> void:
	if not Profile.held and is_finite(seconds) and seconds > 0.0:
		Profile.village_seconds += seconds


static func hour(def: VillageClockDef) -> float:
	return fposmod(def.start_hour + Profile.village_seconds * 24.0 / def.day_seconds, 24.0)


static func day(def: VillageClockDef) -> int:
	return 1 + floori((def.start_hour + Profile.village_seconds * 24.0 / def.day_seconds) / 24.0)


static func text(def: VillageClockDef) -> String:
	var minute := floori(hour(def) * 60.0)
	return TranslationServer.tr("Day %d · %02d:%02d") % [day(def), int(minute / 60.0), minute % 60]
