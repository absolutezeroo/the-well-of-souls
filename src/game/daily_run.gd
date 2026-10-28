class_name DailyRun
## The daily run: one run a day that is the same for that whole day (UTC), offline. Same
## floors (each floor's generation is seeded from the day and the depth), the same starting
## weapon and relic, on Normal difficulty. The first attempt of the day is the official one:
## its score is kept (Profile.daily_*), with the best ever and the days in a row; later ones
## that day are practice. Scored in points, so a run cut short by a phone call still counts.

const POINTS_PER_KILL := 1
const POINTS_PER_FLOOR := 30
const POINTS_PER_BOSS := 150
const POINTS_FOR_VICTORY := 1000
## Gold picked up, divided by this.
const GOLD_PER_POINT := 5


## Today's day number (UTC), as the daily quests count them: days since 1970-01-01 00:00 UTC
## from the system's Unix time, which no time zone changes. Everything of a Dawn Knell (its seeds,
## weapon, relic, omen and board key) comes from this number, so a player in Tokyo and one in Paris
## play the same run at the same instant. `now`: Unix seconds (-1: the system clock).
static func today(now: int = -1) -> int:
	return QuestBoard.day_index(now)


static func seed_of(day: int) -> int:
	return hash("well-of-souls-daily-%d" % day)


## Floor `depth` of day `day` is built from this seed.
static func floor_seed(day: int, depth: int) -> int:
	return hash("well-of-souls-daily-%d-floor-%d" % [day, depth])


## The weapon everyone starts that day with (among the weapons that can be found).
static func weapon(content: ContentDB, day: int) -> WeaponDef:
	var choices := content.items.filter(func(item: ItemDef) -> bool: return item is WeaponDef and not content.locked_items.has(item))
	return _pick(choices, day, 1) as WeaponDef


## The relic everyone starts that day with.
static func relic(content: ContentDB, day: int) -> PerkDef:
	var choices := content.perks.filter(func(perk: PerkDef) -> bool: return perk.rarity == PerkDef.Rarity.RARE and not perk.twist)  # a plain relic: the day is the same for everyone, not a twist
	return _pick(choices, day, 2) as PerkDef


## The day's omen, set from afar (RemoteConfig.omen_for(): the remote settings' daily_omen for that
## date): the curse or floor event every normal floor of that Dawn Knell carries. Null on other
## days, which roll their floors as usual.
static func omen(content: ContentDB, day: int) -> ContentDef:
	return twist(content, RemoteTuning.omen_of_day(day))


## The curse or floor event of id `id` (null: none, or unknown).
static func twist(content: ContentDB, id: StringName) -> ContentDef:
	if id == &"":
		return null
	for curse in content.curses:
		if curse and curse.id == id:
			return curse
	for event in content.floor_events:
		if event and event.id == id:
			return event
	return null


static func _pick(choices: Array, day: int, salt: int) -> Variant:
	if choices.is_empty():
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_of(day) + salt
	return choices[rng.randi_range(0, choices.size() - 1)]


## The run's score so far.
static func score(run: RunState) -> int:
	return run.kills * POINTS_PER_KILL + (run.depth - 1) * POINTS_PER_FLOOR \
		+ run.bosses_slain * POINTS_PER_BOSS + (POINTS_FOR_VICTORY if run.has_won else 0) \
		+ int(run.run_gold / float(GOLD_PER_POINT))


## "Katana + Phoenix Feather": what the day gives.
static func describe(content: ContentDB, day: int) -> String:
	var start_weapon := weapon(content, day)
	var start_relic := relic(content, day)
	return "%s + %s" % [TranslationServer.tr(start_weapon.display_name) if start_weapon else "?", TranslationServer.tr(start_relic.display_name) if start_relic else "?"]
