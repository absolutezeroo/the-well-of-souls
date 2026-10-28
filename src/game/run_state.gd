class_name RunState
extends RefCounted
## The run in progress: how deep, how well it goes, on what difficulty, which bosses were drawn.
## Saved with the run (see Game._save_run() and RunSave), restored by load_data().

## The end of a record key for the runs won at the bottom of the Well (record_key()).
const BOTTOM_RECORD := "bottom"
## The saved `last_boss` when it was the Nameless Keeper (made at the run's start, no file).
const KEEPER_BOSS := "keeper"

var depth := 1
var kills := 0
var bosses_slain := 0
## The last act's boss fell this run (the rest is endless mode).
var has_won := false
## The run's difficulty, with its ascension levels applied. Never null.
var difficulty: DifficultyDef
## One boss per act for this run, drawn among the act's bosses.
var bosses: Array[BossDef] = []
## Souls already added to the profile (a victory, then a death in endless mode).
var souls_awarded := 0
## Gold picked up this run (for the records).
var run_gold := 0
## Already in the profile's history (a won run is recorded once, when it ends).
var history_recorded := false
## The boss of the last cleared boss floor (its relic, in endless mode: a run won, put away and
## picked up again before "Continue" still gets it). Saved (KEEPER_BOSS: the Nameless Keeper,
## made again from `keeper`).
var last_boss: BossDef
## Perk choices: rerolls (three new cards) and banishes left, and the perks banished for the run.
var rerolls := 0
var banishes := 0
var banished: Array[PerkDef] = []
## A daily run (DailyRun): its day, -1 for a normal run. `daily_official`: the day's first
## attempt, the one whose score counts.
var daily_day := -1
var daily_official := false
## Every floor of the run is built from this (and its depth): a resumed run finds the same floor.
var run_seed := 0
## Local receipt identity, independent of gameplay dice; survives resume and repeated daily seeds.
var journey_id := ""
## In-game time, seconds (RunTimer): counts while playing, menus included, but not in the pause
## menu nor while a floor loads.
var time := 0.0
## The time at the end of each floor (index: depth - 1), for the splits.
var splits: Array[float] = []
## The time when the last boss fell (-1: not won yet). The run's speedrun time.
var finish_time := -1.0
## The ways down taken (FloorRoute): depth reached -> index of the route offered for it.
var routes := {}
## The oath sworn for this run (OathDef), or null.
var oath: OathDef
## On the hidden floor (HiddenFloorDef) right now: it keeps the depth of the boss floor before
## it, so the numbering, the splits and the records don't move. `hidden_done`: been down already
## this run (once a run). Both saved.
var hidden_floor := false
var hidden_done := false
## The bottom of the Well (FinaleDef) waits below the last act's boss in this run: the profile
## had won when the run began (decided once, saved: a run doesn't change course midway).
var finale_open := false
## On the bottom of the Well right now: like the hidden floor, it keeps the depth of the boss
## floor before it. Saved.
var finale := false
## The last form fell and the run is won, but no ending was chosen yet (the app was put away
## meanwhile): the choice comes back first when the run is picked up. Saved.
var ending_due := false
## The Nameless Keeper waiting at the bottom of this run's Well (KeeperSnapshot data, copied from
## Profile.keeper when the run began: a run doesn't change course midway; {} = Tôma and the
## Maw). Never in a daily run (the same race for everyone). Saved.
var keeper := {}
## The boss made of `keeper` (FinaleDef.keeper's build()), null without one. Not saved: made again.
var keeper_boss: NamelessKeeperDef
## Secret rooms opened this run (SecretRoom), for the end of the run.
var secrets_found := 0
## Souls earned on top of the usual ones (the hidden floor's boss), before the difficulty's
## multiplier.
var bonus_souls := 0
## What the run did that a warden's deed may ask about (MarkDeed): "bought", "secret",
## "hidden_floor", "oath", "cursed", "encounter:<id>", "bitten" (the Maw's jaw closed on the
## hero) -> true; and what the Vigil-Keeper reads in a death (RunMarkCondition): "drank" (a
## healing potion), "rolled" (a roll), "threshold_lost" (the trial of the Threshold lost). Set
## by RunRecords (Events.run_marked for a monster's or the Threshold's own); saved.
var marks := {}
## The boss floors whose warden was already met this run ("3", "6h" on the hidden floor, "12f"
## and "12f/the_maw" at the bottom of the Well): a run picked up again on that floor never tells
## its story twice. Saved.
var met_floors: Array[String] = []
## The gameplay statistics' counts so far (RunTelemetry.to_data(), put here as the run is saved:
## Events.run_saving), so a resumed run's end covers the whole run. Opaque to the game; saved.
var telemetry := {}
## The world counters' counts of this run so far, with its key (WorldStats, put here as the run is
## saved: Events.run_saving), so a resumed run only sends what it adds. Opaque to the game; saved.
var world_stats := {}
## What the remote settings change in this run (RemoteConfig), fixed at its start and saved: its
## multipliers are already in `difficulty`; the Dawn Knell's omen and an event's floor event
## boost are read by the floors (Game, World, FloorRoute). Neutral without remote values.
var tuning := RemoteTuning.new()
## The dungeon's rules (what a run's souls are worth). Set by create(); not saved.
var config: DungeonConfig
## The floor a run must reach to count toward the next reset of the tree (SoulTreeDef).
var reset_min_depth := 1
## Picked up from a save (create() was given one), not begun now. Not saved.
var resumed := false
## An aided run (decision 0011): the Souls' Aid was on at some point of it, or its difficulty was
## lowered in the middle (lower_difficulty()). It stays off the online leaderboards and sets no
## record (ranked()); souls, the story and the achievements count. Saved.
var assisted := false
## What the run has drawn (no repeats) and its drought of Rare finds (RunLuck). Saved.
var luck := RunLuck.new()


## A new run, or the saved one (`saved` from RunSave; empty for a new run).
## `day`: a new daily run of that day (DailyRun), on Normal.
static func create(content: ContentDB, saved: Dictionary, rng: RandomNumberGenerator, day: int = -1) -> RunState:
	var run := RunState.new()
	run.config = content.dungeon
	run.resumed = not saved.is_empty()
	if content.soul_tree:
		run.reset_min_depth = content.soul_tree.reset_min_depth
	run.daily_day = int(saved.get("daily_day", day))
	run.daily_official = bool(saved.get("daily_official", false))
	if run.daily_day >= 0 and saved.is_empty():
		run.difficulty = content.default_difficulty
	else:
		run.difficulty = _pick_difficulty(content, saved)
	# The remote settings at the run's start (a resumed run keeps its own), on its difficulty.
	var saved_tuning: Variant = saved.get("remote")
	run.tuning = RemoteTuning.from_data(saved_tuning) if saved_tuning is Dictionary \
		else RemoteTuning.for_run(run.difficulty.id, run.daily_day)
	if run.daily_day >= 0:
		run.tuning = run.tuning.daily_only()  # (a Dawn Knell is the same race for all: its omen only)
	run.difficulty = run.tuning.apply_to(run.difficulty)
	run.run_seed = int(saved["seed"]) if saved.has("seed") else rng.randi()
	run.journey_id = str(saved.get("journey_id", ""))
	if run.journey_id.is_empty():
		if saved.is_empty():
			run.journey_id = Crypto.new().generate_random_bytes(16).hex_encode()
		else:
			run.journey_id = "legacy/" + JSON.stringify(saved, "", true).sha256_text()
	run.depth = int(saved.get("depth", 1))
	run.hidden_floor = bool(saved.get("hidden_floor", false))
	run.hidden_done = bool(saved.get("hidden_done", false))
	var finale_def := content.dungeon.finale
	run.finale_open = bool(saved.get("finale_open", finale_def != null and finale_def.is_open()))
	run.finale = bool(saved.get("finale", false))
	run.ending_due = bool(saved.get("ending_due", false))
	if saved.is_empty():
		if run.finale_open and run.daily_day < 0 and KeeperSnapshot.is_valid(Profile.keeper):
			run.keeper = Profile.keeper.duplicate(true)
	elif KeeperSnapshot.is_valid(saved.get("keeper")):
		run.keeper = saved["keeper"]
	run.build_keeper(content)
	run.secrets_found = int(saved.get("secrets_found", 0))
	run.bonus_souls = int(saved.get("bonus_souls", 0))
	var saved_marks: Variant = saved.get("marks", {})
	if saved_marks is Dictionary:
		for mark_name: Variant in saved_marks:
			run.marks[str(mark_name)] = true
	var saved_met: Variant = saved.get("met_floors", [])
	if saved_met is Array:
		for key: Variant in saved_met:
			run.met_floors.append(str(key))
	run.kills = int(saved.get("kills", 0))
	run.bosses_slain = int(saved.get("bosses_slain", 0))
	run.has_won = bool(saved.get("has_won", false))
	if saved.get("boss_slain", false):
		# Saved after the floor's boss died: on to the next floor (the bottom of the Well, when
		# the last act's boss leads there).
		if run.leads_to_finale():
			run.finale = true
		else:
			run.depth += 1
			run.finale = false
		run.hidden_floor = false
	run.souls_awarded = int(saved.get("souls_awarded", 0))
	run.run_gold = int(saved.get("run_gold", 0))
	run.history_recorded = bool(saved.get("history_recorded", false))
	run.time = float(saved.get("time", 0.0))
	run.assisted = bool(saved.get("assisted", false))
	var saved_telemetry: Variant = saved.get("telemetry", {})
	if saved_telemetry is Dictionary:
		run.telemetry = saved_telemetry
	var saved_world_stats: Variant = saved.get("world_stats", {})
	if saved_world_stats is Dictionary:
		run.world_stats = saved_world_stats
	run.finish_time = float(saved.get("finish_time", -1.0))
	run.luck = RunLuck.from_data(saved.get("luck", {}))
	if saved.has("oath"):
		run.oath = RunSave.load_ref(saved["oath"]) as OathDef
	var taken: Variant = saved.get("routes", {})
	if taken is Dictionary:
		for key: Variant in taken:
			run.routes[int(str(key))] = int(taken[key])
	for split_time: Variant in saved.get("splits", []):
		run.splits.append(float(split_time))
	if saved.has("rerolls"):
		run.rerolls = int(saved.rerolls)
		run.banishes = int(saved.get("banishes", 0))
		for ref: Variant in saved.get("banished", []):
			var perk := RunSave.load_ref(ref) as PerkDef
			if perk:
				run.banished.append(perk)
	else:
		run.rerolls = content.dungeon.base_rerolls + ShrineUpgrades.extra_charges(content, UpgradeDef.Kind.REROLLS)
		run.banishes = content.dungeon.base_banishes + ShrineUpgrades.extra_charges(content, UpgradeDef.Kind.BANISHES)
	if saved.has("bosses"):
		for ref: Variant in saved.bosses:
			run.bosses.append(RunSave.load_ref(ref) as BossDef)
	else:
		for act in content.dungeon.acts:
			var choices := act.all_bosses()
			run.bosses.append(choices[rng.randi_range(0, choices.size() - 1)] if not choices.is_empty() else null)
	var saved_last: Variant = saved.get("last_boss", "")
	if str(saved_last) == KEEPER_BOSS:
		run.last_boss = run.keeper_boss
	else:
		run.last_boss = RunSave.load_ref(saved_last) as BossDef
	return run


## The profile's difficulty (or the saved run's), with its ascension; Normal if locked.
static func _pick_difficulty(content: ContentDB, saved: Dictionary) -> DifficultyDef:
	var picked := content.get_difficulty(StringName(saved.get("difficulty", Profile.difficulty)))
	if picked == null or not Profile.is_unlocked(picked):
		picked = content.default_difficulty
	var ascension := int(saved.get("ascension", Profile.ascension if saved.is_empty() else 0))
	if picked.has_ascensions and ascension > 0:
		picked = AscensionDef.apply_levels(picked, content.ascensions, mini(ascension, Profile.ascension_unlocked))
	return picked


## Souls this run is worth so far (what the shrine gets when it ends).
func souls() -> int:
	var worth := config.souls_for_run(kills, depth, bosses_slain, has_won, difficulty.souls) + bonus_souls_worth(bonus_souls)
	return roundi(worth * oath.souls_scale) if oath and oath.souls_scale != 1.0 else worth  # (a kit's +souls)


## What `amount` bonus souls (the hidden floor's hoard...) are worth at the end of this run: the
## difficulty's souls multiplier on them, as souls() counts them.
func bonus_souls_worth(amount: int) -> int:
	return roundi(amount * difficulty.souls)


## Adds the souls not given yet to the profile; returns them.
func award_souls(won_now: bool, ascension_count: int) -> int:
	var total := souls()
	var earned := total - souls_awarded
	souls_awarded = total
	# A run won then lost in the endless floors ends once: at the win; a run given up before
	# its second floor doesn't count toward the tree's reset.
	var finished := (won_now or not has_won) and depth >= reset_min_depth
	Profile.record_run(earned, depth, won_now, difficulty.id, difficulty.counts_feats, finished)
	if won_now and difficulty.has_ascensions:
		Profile.win_ascension(difficulty.ascension, ascension_count)
	return earned


## What the save keeps of the run (the floor and the hero are added by the game).
func to_data() -> Dictionary:
	return {
		"depth": depth,
		"kills": kills,
		"bosses_slain": bosses_slain,
		"has_won": has_won,
		"souls_awarded": souls_awarded,
		"run_gold": run_gold,
		"history_recorded": history_recorded,
		"bosses": RunSave.refs(bosses),
		"rerolls": rerolls,
		"banishes": banishes,
		"banished": RunSave.refs(banished),
		"daily_day": daily_day,
		"daily_official": daily_official,
		"seed": run_seed,
		"journey_id": journey_id,
		"time": time,
		"splits": splits,
		"finish_time": finish_time,
		"routes": routes,
		"oath": RunSave.ref(oath),
		"hidden_floor": hidden_floor,
		"hidden_done": hidden_done,
		"finale_open": finale_open,
		"finale": finale,
		"ending_due": ending_due,
		"keeper": keeper,
		"secrets_found": secrets_found,
		"bonus_souls": bonus_souls,
		"telemetry": telemetry,
		"world_stats": world_stats,
		"marks": marks,
		"met_floors": met_floors,
		"luck": luck.to_data(),
		"difficulty": String(difficulty.id),
		"ascension": difficulty.ascension,
		"remote": tuning.to_data(),
		"assisted": assisted,
		"last_boss": KEEPER_BOSS if last_boss and last_boss == keeper_boss else RunSave.ref(last_boss),
	}


## Its times and the Dawn Knell's score count as records, and it may go on the online
## leaderboards: not an aided run (assisted).
func ranked() -> bool:
	return not assisted


## The difficulties this run may be lowered to (from the pause menu): the ones before its own
## in `content.difficulties`, gentlest first, and its own without its ascension levels when it
## has some. Each as it is (its ascension 0).
func lower_difficulties(content: ContentDB) -> Array[DifficultyDef]:
	var result: Array[DifficultyDef] = []
	for each in content.difficulties:
		if each.id == difficulty.id:
			if difficulty.ascension > 0:
				result.append(each)
			break
		result.append(each)
	return result


## Lowers the run's difficulty to `lower` (one of lower_difficulties()), for the rest of the run:
## the remote settings it began with apply to it too, and the run becomes aided. False (nothing
## changed) if `lower` isn't lower.
func lower_difficulty(content: ContentDB, lower: DifficultyDef) -> bool:
	if lower == null or not lower_difficulties(content).has(lower):
		return false
	difficulty = tuning.apply_to(lower)
	assisted = true
	return true


## The way down from this floor leads to the bottom of the Well (FinaleDef): the last act's
## floor of the first pass, the way open this run, not won yet, not there yet.
func leads_to_finale() -> bool:
	return finale_open and config.finale != null and config.finale.boss != null and not has_won \
		and not finale and not hidden_floor and config.is_final_floor(depth)


## The last act's boss (or the bottom's last form, when the bottom is open) wins the run.
func wins_with(boss: BossDef) -> bool:
	if has_won or not config.is_final_floor(depth):
		return false
	if goes_to_bottom():
		return finale and boss == bottom_boss().last_form()
	return not finale


## Makes the Nameless Keeper of `keeper` (none without a snapshot, or a finale without him).
func build_keeper(content: ContentDB) -> void:
	var finale_def := content.dungeon.finale
	keeper_boss = null
	if KeeperSnapshot.is_valid(keeper) and finale_def and finale_def.keeper:
		keeper_boss = finale_def.keeper.build(KeeperSnapshot.new(keeper), content)


## Who waits at the bottom of the Well this run: the Nameless Keeper if one waits (his fall is
## the last), else the finale's boss (Tôma, the Maw rising after him).
func bottom_boss() -> BossDef:
	if keeper_boss:
		return keeper_boss
	return config.finale.boss if config.finale else null


## The fight at the bottom is against the Nameless Keeper this run.
func meets_keeper() -> bool:
	return keeper_boss != null


## The split a floor's end is counted under: the bottom of the Well after the last act's.
func split_depth() -> int:
	return depth + 1 if finale else depth


## Something a warden's deed may ask about happened this run (MarkDeed).
func mark(name: String) -> void:
	marks[name] = true


## This floor, as met_floors keeps it ("12f": the bottom of the Well, at the depth before it).
func floor_key() -> String:
	return "%d%s%s" % [depth, "h" if hidden_floor else "", "f" if finale else ""]


## The warden of this floor was met already this run (its story is not told again). `form`: a
## form risen there from a fallen one (BossDef.next_boss), kept apart ("12f/the_maw").
func has_met_here(form: StringName = &"") -> bool:
	return met_floors.has(_meeting_key(form))


func meet_here(form: StringName = &"") -> void:
	if not has_met_here(form):
		met_floors.append(_meeting_key(form))


func _meeting_key(form: StringName) -> String:
	return floor_key() if form == &"" else "%s/%s" % [floor_key(), form]


## The seed of the ways down offered toward floor `floor_depth` (the same all day in a daily run).
func route_seed(floor_depth: int) -> int:
	return FloorRoute.seed_for(DailyRun.seed_of(daily_day) if is_daily() else run_seed, floor_depth)


func is_daily() -> bool:
	return daily_day >= 0


## The floor `depth` is done (the stairs are taken, or its boss was the last): its split.
## Returns the split's time.
func split(floor_depth: int) -> float:
	if splits.size() < floor_depth:
		splits.resize(floor_depth)
		for i in splits.size():
			if splits[i] <= 0.0:
				splits[i] = time  # a floor skipped (debug) takes the same time
	splits[floor_depth - 1] = time
	return time


## The time a speedrunner would quote: the win, or the time so far.
func run_time() -> float:
	return finish_time if finish_time >= 0.0 else time


## What its records are kept under: the difficulty and its ascension ("normal", "nightmare/a3"),
## and BOTTOM_RECORD for a run won at the bottom of the Well, a longer race than a first win
## ("normal/bottom", "nightmare/a3/bottom"). Empty for a daily run (its own race).
func record_key() -> String:
	if is_daily():
		return ""
	var key := String(difficulty.id)
	if difficulty.ascension > 0:
		key += "/a%d" % difficulty.ascension
	if goes_to_bottom():
		key += "/" + BOTTOM_RECORD
	return key


## A record kept for runs won at the bottom of the Well (a key of record_key()).
static func is_bottom_record(key: String) -> bool:
	return key.ends_with("/" + BOTTOM_RECORD)


## This run is won at the bottom of the Well, not on the last act's boss (finale_open).
func goes_to_bottom() -> bool:
	return finale_open and config.finale != null and config.finale.boss != null


## Where the run is: its act's name, or the hidden floor's.
func place_name(content: ContentDB) -> String:
	return tr(place_name_key(content))


## place_name() as its English key (RunFacts keeps keys, translated where shown).
func place_name_key(content: ContentDB) -> String:
	if hidden_floor and content.dungeon.hidden_floor:
		return content.dungeon.hidden_floor.title
	if finale and content.dungeon.finale:
		return content.dungeon.finale.title
	var act := content.dungeon.act_for_depth(depth)
	return act.title if act else "Dungeon"  # i18n


## The run's numbers for the end-of-run screen, as [label, value] pairs (Difficulty, Reached,
## Level, Monsters slain, Bosses slain, Time, the daily score). `time_note` follows the time
## ("New record!"); without it, the record to beat is given for a run not won.
func summary_rows(content: ContentDB, level: int, time_note: String = "") -> Array:
	var time_text := TimeText.of(run_time())
	var record := Profile.best_time(record_key())
	if not time_note.is_empty():
		time_text += "  " + time_note
	elif record > 0.0 and finish_time < 0.0:
		time_text += "  " + tr("(record %s)") % TimeText.of(record)
	var rows: Array = [
		[tr("Difficulty"), difficulty.shown_name()],
		[tr("Reached"), tr("%s, depth %d") % [place_name(content), depth]],
		[tr("Hero level"), str(level)],
		[tr("Monsters slain"), str(kills)],
		[tr("Bosses slain"), str(bosses_slain)],
		[tr("Time"), time_text],
	]
	if assisted:
		rows.append([tr("Records"), tr("None: an aided descent")])
	if secrets_found > 0:
		rows.insert(rows.size() - 1, [tr("Secret rooms found"), str(secrets_found)])
	if is_daily():
		var note := tr("(best %d)") % Profile.daily_best if daily_official else tr("(practice)")
		rows.append([tr("Daily score"), "%d  %s" % [DailyRun.score(self), note]])
	return rows
