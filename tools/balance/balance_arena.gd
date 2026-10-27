class_name BalanceArena
extends Node
## The measured half of the balance tools: real fights in the real Game scene, headless, with a
## bot at the controls (BalanceBot), on the BalanceLab.
## - run_bosses(): every boss (alternates included) x the builds of its act x difficulty x bot,
##   plus every boss rank (Epic, Legendary, Shiny) with the expected build: the act's boss floor
##   of a run whose boss is that one; the bot walks into the arena and fights until someone dies
##   or `timeout` game seconds pass.
## - run_weapons(): every weapon (Common, on the act's expected build otherwise) against every
##   boss, kite bot, Normal.
## - run_packs(): rooms of each act's monsters on its last normal floor: three of each kind, mixed
##   rooms by spawn weight, and rooms with an Elite (each affix) / Epic / Legendary / Shiny.
## - run_bottom() (`--keeper=<weapon ids>`): the bottom of the Well, the Nameless Keeper built from
##   a sample hero of each weapon (BalanceContent.keeper_snapshot()), and Tôma alone for scale,
##   against the last act's expected build, each difficulty and bot.
## Every fight starts from the same seeds (`seed_value`): the same command gives the same numbers.

## Frames the hero may spend in a world of his own (the Deeps, the Threshold) mid-fight.
const AWAY_LIMIT := 60 * 120
## Frames allowed to walk from the floor's start into the arena.
const APPROACH_LIMIT := 60 * 40
## Game seconds a room gets before it counts as a timeout.
const PACK_TIMEOUT := 60.0
## Mixed rooms measured per act, difficulty and bot.
const MIXED_ROOMS := 3

var lab: BalanceLab
var content: ContentDB
var targets: BalanceTargets
var all_builds: Array[BalanceBuildDef] = []
var builds: Array[BalanceBuildDef] = []
## Every difficulty asked for (the curve: expected builds vs every boss).
var difficulties: Array[DifficultyDef] = []
## Difficulties for everything else (ranks, other builds, weapons, packs): Normal and Hard
## when asked for, else the first asked.
var core: Array[DifficultyDef] = []
var bosses: Array[BossDef] = []
var bots: PackedStringArray = ["face_tank", "kite"]
var seed_value := 1
## Every build against every boss (default: each build against the bosses of its own act).
var all_pairs := false
## Small subset (the opt-in test suite).
var quick := false
## Game seconds before a boss fight is called a timeout.
var timeout := 240.0
## Print a line per fight.
var verbose := true
## Boss fights: plain bosses only (no ranked fights).
var plain_only := false
## Units of work (BalanceJobs): each fight and room is one, kept in the cache and shared
## between worker processes. A plain one (no cache, one process) when none is given.
var jobs := BalanceJobs.new()
## The Nameless Keeper's sample heroes' weapons (run_bottom(); empty: no bottom fights).
var keeper_weapons: PackedStringArray = []
## Weapon arena: only these weapons (ids; empty: all).
var weapon_ids: PackedStringArray = []
## Packs: only these acts (empty: all).
var acts: Array[int] = []


func core_difficulties() -> Array[DifficultyDef]:
	var result: Array[DifficultyDef] = []
	for d in difficulties:
		if ["normal", "hard"].has(BalanceContent.key(d)):
			result.append(d)
	if result.is_empty() and not difficulties.is_empty():
		result.append(difficulties[0])
	return result


# --- Boss fights -------------------------------------------------------------------------

## The fights to run: [{ boss, build, difficulty, bot, rank }].
func boss_matrix() -> Array:
	var result: Array = []
	var ranks := BalanceContent.boss_ranks(content)
	var boss_list := bosses
	if quick:
		boss_list = bosses.slice(0, 1)  # the first act's main boss, its act's builds
	for boss in boss_list:
		var act := BalanceContent.act_of_boss(content, boss)
		var expected := BalanceBuild.expected(all_builds, act)
		for build in builds:
			var own := build.act == act
			if not own and not all_pairs:
				continue
			var is_expected := build == expected
			var difficulty_list: Array[DifficultyDef] = difficulties if is_expected else core
			if quick:
				difficulty_list = core.slice(0, 1)
			for difficulty in difficulty_list:
				for bot in bots:
					result.append({ "boss": boss, "build": build, "difficulty": difficulty, "bot": bot, "rank": null })
			if is_expected and not quick and not plain_only:
				for rank in ranks:
					for difficulty in core:
						for bot in bots:
							result.append({ "boss": boss, "build": build, "difficulty": difficulty, "bot": bot, "rank": rank })
	return result


func run_bosses() -> BalanceReport:
	var report := BalanceReport.new()
	report.title = "Balance arena"
	var started := Time.get_ticks_msec()
	var matrix := boss_matrix()  # (before the chances are zeroed: the boss ranks are those with a chance)
	lab.override_chances()
	var fights: Array = []
	print("balance arena: %d boss fights" % matrix.size())
	var index := 0
	for f: Dictionary in matrix:
		index += 1
		var result: Variant = await jobs.unit(fight_id(f.boss, f.build, f.difficulty, f.bot, f.rank), fight_roots(f.boss, f.build, f.difficulty),
			func() -> Dictionary: return await fight_boss(f.boss, f.build, f.difficulty, f.bot, f.rank))
		if result == null:
			continue  # another worker's
		fights.append(result)
		if verbose and jobs.measuring:
			print("  [%d/%d] %s" % [index, matrix.size(), fight_line(result)])
	lab.restore_chances()
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	report.notes.append("Arena: %d boss fights in %.0f s of real time (seed %d, timeout %.0f game s, hit stop off; times are game seconds)." % [fights.size(), seconds, seed_value, timeout])
	report.timings["arena"] = seconds
	report.data["fights"] = fights
	_boss_report(report, fights)
	return report


# --- The bottom of the Well ---------------------------------------------------------------

## The bottom's fights: Tôma alone (weapon "") then a Keeper per weapon of `keeper_weapons`, x the
## difficulties x the bots, with the last act's expected build: [{ weapon, keeper, build,
## difficulty, bot }].
func bottom_matrix() -> Array:
	var result: Array = []
	var build := BalanceBuild.expected(all_builds, content.dungeon.acts.size())
	if build == null:
		return result
	var weapons := PackedStringArray([""])
	weapons.append_array(keeper_weapons)
	for weapon in weapons:
		var snapshot := BalanceContent.keeper_snapshot(content, weapon) if not weapon.is_empty() else {}
		if not weapon.is_empty() and snapshot.is_empty():
			push_warning("balance arena: no weapon '%s' for a Nameless Keeper" % weapon)
			continue
		for difficulty in difficulties:
			for bot in bots:
				result.append({ "weapon": weapon, "keeper": snapshot, "build": build, "difficulty": difficulty, "bot": bot })
	return result


func run_bottom() -> BalanceReport:
	var report := BalanceReport.new()
	report.title = "Balance arena: the bottom of the Well"
	var started := Time.get_ticks_msec()
	var matrix := bottom_matrix()
	lab.override_chances()
	var fights: Array = []
	print("balance arena: %d fights at the bottom of the Well" % matrix.size())
	var index := 0
	var finale := content.dungeon.finale
	for f: Dictionary in matrix:
		index += 1
		var boss: BossDef = finale.keeper if not str(f.weapon).is_empty() else finale.boss
		var label := "keeper:%s" % f.weapon if not str(f.weapon).is_empty() else "toma"
		var unit := "bottom|%s|%s|%s|%s|%.0f" % [label, BalanceJobs.build_id(f.build), BalanceContent.key(f.difficulty), f.bot, timeout]
		var roots := PackedStringArray([finale.resource_path, boss.resource_path, "res://data/arenas/", content.dungeon.acts[content.dungeon.acts.size() - 1].resource_path])
		roots.append_array(BalanceJobs.build_roots(f.build, content))
		roots.append_array(difficulty_roots(f.difficulty))
		var result: Variant = await jobs.unit(unit, roots,
			func() -> Dictionary: return await fight_boss(boss, f.build, f.difficulty, f.bot, null, 0, [] as Array[ItemDef], false, { "keeper": f.keeper, "label": label }))
		if result == null:
			continue  # another worker's
		fights.append(result)
		if verbose and jobs.measuring:
			print("  [%d/%d] %s" % [index, matrix.size(), fight_line(result)])
	lab.restore_chances()
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	report.notes.append("Bottom of the Well: %d fights in %.0f s of real time (seed %d, timeout %.0f game s; the Keepers' sample heroes: BalanceContent.keeper_snapshot)." % [fights.size(), seconds, seed_value, timeout])
	report.timings["bottom"] = seconds
	report.data["fights"] = fights
	_boss_report(report, fights)
	return report


## A fight's unit id (BalanceJobs): everything that makes it this fight.
func fight_id(boss: BossDef, build: BalanceBuildDef, difficulty: DifficultyDef, bot_name: String, rank: MonsterRankDef = null) -> String:
	return "boss|%s|%s|%s|%s|%s|%.0f" % [boss.id, BalanceJobs.build_id(build), BalanceContent.key(difficulty), bot_name, String(rank.id) if rank else "plain", timeout]


## What a boss fight depends on: the boss, its act (its monsters, its places), the arenas, the
## build and the difficulty.
func fight_roots(boss: BossDef, build: BalanceBuildDef, difficulty: DifficultyDef) -> PackedStringArray:
	var act := BalanceContent.act_of_boss(content, boss)
	var roots := PackedStringArray([boss.resource_path, "res://data/arenas/"])
	if act >= 1:
		roots.append(content.dungeon.acts[act - 1].resource_path)
	roots.append_array(BalanceJobs.build_roots(build, content))
	roots.append_array(difficulty_roots(difficulty))
	return roots


## A difficulty's files (an ascension is a copy made at run time: its base and the ascensions).
static func difficulty_roots(difficulty: DifficultyDef) -> PackedStringArray:
	if difficulty == null:
		return PackedStringArray()
	if not difficulty.resource_path.is_empty():
		return PackedStringArray([difficulty.resource_path])
	return PackedStringArray(["res://data/difficulties/%s.tres" % difficulty.id, "res://data/ascension/"])


## One fight. Returns what happened (see the keys at the end). `start_hp`: the hero's Health
## when the fight starts (the gauntlet: what the floor left him; 0: full). `belt`: what he
## carries on his belt when `set_belt` (the gauntlet: the potions left; else as the build has it).
## `bottom` (run_bottom()): the bottom of the Well instead, { keeper: a snapshot ({}: Tôma),
## label }: the run saved there with that Keeper waiting (or none).
func fight_boss(boss: BossDef, build: BalanceBuildDef, difficulty: DifficultyDef, bot_name: String, rank: MonsterRankDef = null, start_hp: int = 0,
		belt: Array[ItemDef] = [], set_belt: bool = false, bottom: Dictionary = {}) -> Dictionary:
	var act := BalanceContent.act_of_boss(content, boss)
	var depth := BalanceContent.boss_depth(content, act) if bottom.is_empty() else content.dungeon.total_floors()
	if not bottom.is_empty():
		act = content.dungeon.acts.size()
	var at_bottom := { "finale_open": true, "finale": true, "keeper": bottom.get("keeper", {}) }
	var game := await lab.start_game(depth, difficulty, boss if bottom.is_empty() else null, true, rank, -1, false, {} if bottom.is_empty() else at_bottom)
	var result := { "boss": String(boss.id) if bottom.is_empty() else str(bottom.get("label", boss.id)), "act": act, "build": build.name, "tags": build.tags,
		"build_act": build.act, "difficulty": BalanceContent.key(difficulty), "bot": bot_name, "depth": depth,
		"rank": String(rank.id) if rank else "plain", "weapon": String(build.weapon.id) if build.weapon else "" }
	var world := game.world
	if world.arena == null or world.arena.boss == null:
		result["result"] = "error"
		result["error"] = "no boss arena on depth %d" % depth
		await lab.end_game(game)
		return result
	var player := game.player
	BalanceBuild.apply(build, player, content, difficulty)
	player.perks.on_floor_started(player)  # floor-start perks (a ward) as on arrival
	player.xp = -1000000  # the build keeps its level: no level up (and no perk menu) mid-fight
	if set_belt:
		BalanceGauntlet.empty_belt(player)
		for item in belt:
			player.pack.store(item)
	if start_hp > 0:
		player.hp = clampi(start_hp, 1, player.get_max_hp())
		player.health_changed.emit(player.hp, player.get_max_hp())
	var boss_actor := world.arena.boss
	result["affixes"] = boss_actor.affix_names()
	var lives_before := lives_used(player)
	var fight_log := FightLog.new(player, boss_actor)
	var bot := BalanceBot.create(bot_name, player, world, boss_actor)
	var frames := 0
	var away_frames := 0
	var fight_frames := 0
	var limit := roundi(timeout * BalanceLab.FPS)
	var outcome := "timeout"
	while true:
		await get_tree().physics_frame
		frames += 1
		lab.unpause(game)
		if player.is_dead:
			outcome = "loss"
			break
		if boss_actor.is_dead:
			outcome = "win"
			break
		if not world.is_inside_tree():
			# In a world of his own for a while (the Deeps after a fall, the Threshold's trial):
			# the boss waits frozen, the bot plays there; lost there for good, the fight is lost.
			away_frames += 1
			fight_log.away = is_instance_valid(player.world) and player.world is ThresholdWorld
			if away_frames > AWAY_LIMIT:
				outcome = "loss"
				result["error"] = "lost in the Deeps or the Threshold"
				break
			bot.step()
			continue
		fight_log.away = false
		if world.arena.is_started:
			fight_frames += 1
			fight_log.frame()
			if fight_frames >= limit:
				break
		elif frames > APPROACH_LIMIT:
			outcome = "error"
			result["error"] = "never reached the arena"
			break
		bot.step()
	BalanceBot.release_all()
	fight_log.frame()
	result.merge(fight_log.summary(fight_frames / BalanceLab.FPS))
	if FightLog.log_hits:
		result["hit_log"] = fight_log.hit_log
		var plan: ArenaDef = world.arena._plan if is_instance_valid(world) and world.arena else null
		print("    hits (%s, %s, %s, arena %s):\n      %s" % [boss.id, build.name, bot_name, String(plan.id) if plan else "-", "\n      ".join(PackedStringArray(fight_log.hit_log))])
	result["result"] = outcome
	result["hero_max_hp"] = player.get_max_hp()
	result["boss_max_hp"] = boss_actor.get_max_hp()
	result["boss_hp_left"] = maxi(boss_actor.hp, 0)
	result["boss_hp_left_share"] = maxi(boss_actor.hp, 0) / maxf(boss_actor.get_max_hp(), 1.0)
	result["rolls"] = bot.rolls
	result["skills_used"] = bot.skills_used
	result["drinks"] = bot.drinks
	result["away_time"] = away_frames / BalanceLab.FPS
	# Second lives spent in this fight: deaths the hero came back from (the Threshold's trial).
	result["lives_used"] = lives_used(player) - lives_before
	# Time to kill, measured or (lost, timed out) projected from the damage dealt so far.
	var dealt_share: float = 1.0 - float(result.boss_hp_left_share)
	result["ttk_projected"] = float(result.time) / maxf(dealt_share, 0.01) if outcome != "win" else float(result.time)
	await lab.end_game(game)
	return result


## Second lives (CheatDeathPassive: Phoenix Feather, Second Chance) the hero has spent this run.
static func lives_used(player: Player) -> int:
	var used := 0
	for entry in player.perks.entries:
		used += int(entry.memory.get(&"used", 0))
	return used


## The face-tank test's verdict (targets.facetank_second_life_is_loss): a win only counts when
## the hero never died; a win on a second life is the boss killing him once, a loss.
static func facetank_won(r: Dictionary, goals: BalanceTargets) -> bool:
	if r.get("result") != "win":
		return false
	return int(r.get("lives_used", 0)) == 0 or not goals.facetank_second_life_is_loss


## Healing in the fight as a share of the damage taken, for the heal share targets: a second
## life's heal is not sustain and is left out (targets.facetank_second_life_is_loss).
static func sustain_share(r: Dictionary) -> float:
	return float(r.get("heal_share_sustain", r.get("heal_share", 0.0)))


static func fight_line(r: Dictionary) -> String:
	return "%s%s | %s | %s | %s: %s in %.1f s, phase %d, boss %d%% left, hero min %d%%, taken %d (%d hits; %s), healed %d (%s), dps %.1f, rolls %d" % [
		r.boss, "" if r.get("rank", "plain") == "plain" else " (%s %s)" % [r.rank, r.get("affixes", "")], r.build, r.difficulty, r.bot,
		str(r.get("result", "?")).to_upper(), r.get("time", 0.0), r.get("phases", 0),
		roundi(100.0 * r.get("boss_hp_left_share", 0.0)), roundi(r.get("min_hp_share", 0.0) * 100.0),
		r.get("damage_taken", 0), r.get("hits_taken", 0), BalanceLab.sources_text(r.get("taken_by", {})), r.get("healed", 0), BalanceLab.sources_text(r.get("heal_sources", {})),
		r.get("dps", 0.0), r.get("rolls", 0)] + (", second life used %d" % r.lives_used if int(r.get("lives_used", 0)) > 0 else "") \
		+ (", falls %d thrown / %d walked" % [r.falls_pushed, r.falls_walked] if int(r.get("falls_pushed", 0)) + int(r.get("falls_walked", 0)) > 0 else "")


func _boss_report(report: BalanceReport, fights: Array) -> void:
	var rows: Array = []
	for r: Dictionary in fights:
		rows.append([r.boss, r.get("rank", "plain"), r.get("affixes", ""), r.build, r.difficulty, r.bot, str(r.get("result", "?")).to_upper(),
			r.get("time", 0.0), r.get("ttk_projected", 0.0), r.get("phases", 0), BalanceReport.pct(r.get("boss_hp_left_share", 0.0)), r.get("dps", 0.0),
			r.get("damage_taken", 0), r.get("hits_taken", 0), r.get("healed", 0), BalanceReport.pct(r.get("heal_share", 0.0)),
			BalanceLab.sources_text(r.get("heal_sources", {})), BalanceReport.pct(r.get("min_hp_share", 0.0))])
		_check_fight(report, r)
	report.table("boss_arena", "Bosses", "Boss fights on the engine (every boss x builds of its act x difficulty x bot, ranks with the expected build). TTK proj. = time / share of the boss' health taken",
		PackedStringArray(["Boss", "Rank", "Affixes", "Build", "Difficulty", "Bot", "Result", "Time s", "TTK proj. s", "Phase", "Boss HP left", "Hero DPS",
			"Taken", "Hits", "Healed", "Heal/taken", "Heal sources", "Hero min HP"]), rows)
	# Summary: expected build, plain rank, per boss and difficulty.
	var summary: Array = []
	var keys: Array = difficulties.map(func(d: DifficultyDef) -> String: return BalanceContent.key(d))
	for boss in bosses:
		var expected := BalanceBuild.expected(all_builds, BalanceContent.act_of_boss(content, boss))
		if expected == null:
			continue
		var row := [String(boss.id), expected.name]
		for d_key: String in keys:
			var cell := PackedStringArray()
			for bot in bots:
				for r: Dictionary in fights:
					if r.boss == String(boss.id) and r.build == expected.name and r.difficulty == d_key and r.bot == bot and r.get("rank", "plain") == "plain":
						cell.append("%s %s %.0fs" % [{ "kite": "K", "face_tank": "F", "player": "P" }.get(bot, bot), "W" if r.result == "win" else ("L" if r.result == "loss" else "T"), r.time])
			row.append(" / ".join(cell) if not cell.is_empty() else "-")
		summary.append(row)
	var columns := PackedStringArray(["Boss", "Build"])
	columns.append_array(PackedStringArray(keys))
	report.table("boss_arena_summary", "Bosses", "Expected build vs every boss on every difficulty (engine). K = kite bot, F = face-tank bot; W win, L loss, T timeout; game seconds",
		columns, summary)


func _check_fight(report: BalanceReport, r: Dictionary) -> void:
	var subject := "%s vs %s%s (%s, %s)" % [r.build, "" if r.get("rank", "plain") == "plain" else r.rank + " ", r.boss, r.difficulty, r.bot]
	if r.get("result") == "error":
		report.flag(BalanceReport.ERROR, "arena: error", subject, str(r.get("error", "?")), "a fight", "the fight could not be measured")
		return
	var tags: PackedStringArray = r.tags
	var own: bool = r.build_act == r.act
	var plain: bool = r.get("rank", "plain") == "plain"
	var must_lose := false
	for tag in targets.facetank_must_lose_tags:
		must_lose = must_lose or tags.has(tag)
	if r.bot == "face_tank" and must_lose and own and plain \
			and BalanceContent.rank_of(r.difficulty) >= BalanceContent.rank_of(String(targets.facetank_must_lose_from)) and facetank_won(r, targets):
		report.flag(BalanceReport.ERROR, "arena: face-tank wins", subject, "won in %.0f s, %d%% health at worst" % [r.time, roundi(r.min_hp_share * 100.0)],
			"must die from %s" % targets.facetank_must_lose_from, "healed %d of %d taken (%s)" % [r.healed, r.damage_taken, BalanceLab.sources_text(r.heal_sources)])
	var share_max := -1.0
	if tags.has("expected"):
		share_max = targets.heal_share_max_expected
	elif tags.has("degenerate") or tags.has("family"):
		share_max = targets.heal_share_max_degenerate
	var felt: bool = r.damage_taken >= targets.heal_share_min_taken * float(r.get("hero_max_hp", 1))
	if share_max >= 0.0 and own and plain and r.damage_taken > 0 and felt and sustain_share(r) > share_max:
		report.flag(BalanceReport.ERROR, "arena: heal share", subject, BalanceReport.pct(sustain_share(r)), "<= %s" % BalanceReport.pct(share_max),
			"healed %d of %d taken (%s)" % [r.healed, r.damage_taken, BalanceLab.sources_text(r.heal_sources)])
	if tags.has("expected") and own and r.bot == "kite":
		if plain and targets.kite_should_win_on.has(r.difficulty) and r.result != "win":
			report.flag(BalanceReport.WARN, "arena: kite loses", subject, "%s (boss at %d%%)" % [r.result, roundi(100.0 * r.boss_hp_left_share)],
				"wins on %s" % ", ".join(targets.kite_should_win_on), "the boss could not be beaten by keeping range and rolling")
		if r.difficulty == "normal":
			var ttk: float = r.ttk_projected
			var top := targets.boss_ttk_max if plain else targets.ranked_boss_ttk_max
			if ttk < targets.boss_ttk_min or ttk > top:
				report.flag(BalanceReport.WARN, "arena: boss TTK" if plain else "arena: ranked boss TTK", subject, BalanceReport.secs(ttk), "%d-%d s" % [targets.boss_ttk_min, top],
					"the expected build's fight %s (%s)" % ["is too short" if ttk < targets.boss_ttk_min else "is too long", "measured" if r.result == "win" else "projected from %d%% dealt" % roundi(100.0 * (1.0 - r.boss_hp_left_share))])


# --- Weapons vs bosses -----------------------------------------------------------------------

func run_weapons() -> BalanceReport:
	var report := BalanceReport.new()
	report.title = "Balance weapons arena"
	var started := Time.get_ticks_msec()
	lab.override_chances()
	var normal := BalanceContent.difficulty(content, "normal")
	var weapons := BalanceContent.weapons()
	if not weapon_ids.is_empty():
		weapons = weapons.filter(func(w: WeaponDef) -> bool: return weapon_ids.has(String(w.id)))
	var boss_list := bosses
	if quick:
		weapons = weapons.slice(0, 3)
		boss_list = bosses.slice(0, 1)
	var fights: Array = []
	var total := weapons.size() * boss_list.size()
	print("balance weapons arena: %d fights" % total)
	for weapon in weapons:
		for boss in boss_list:
			var act := BalanceContent.act_of_boss(content, boss)
			var expected := BalanceBuild.expected(all_builds, act)
			if expected == null:
				continue
			var build := BalanceBuild.variant(expected, content, "weapon", String(weapon.id), 0, weapon)
			build.name = "%s+%s" % [expected.name, weapon.id]
			var result: Variant = await jobs.unit("weapon|" + fight_id(boss, build, normal, "kite"), fight_roots(boss, build, normal),
				func() -> Dictionary: return await fight_boss(boss, build, normal, "kite"))
			if result == null:
				continue
			var r: Dictionary = result
			r["weapon"] = String(weapon.id)
			fights.append(r)
			if verbose and jobs.measuring:
				print("  [%d/%d] %s" % [fights.size(), total, fight_line(r)])
	lab.restore_chances()
	var rows: Array = []
	var columns := PackedStringArray(["Weapon", "Wins", "Win share", "Avg TTK proj. s"])
	for boss in boss_list:
		columns.append(String(boss.id))
	for weapon in weapons:
		var row := [String(weapon.id)]
		var wins := 0
		var count := 0
		var ttks: Array = []
		var cells := []
		for boss in boss_list:
			for r: Dictionary in fights:
				if r.weapon == String(weapon.id) and r.boss == String(boss.id):
					count += 1
					if r.result == "win":
						wins += 1
					ttks.append(r.ttk_projected)
					cells.append("%s %.0fs" % ["W" if r.result == "win" else ("L" if r.result == "loss" else "T"), r.ttk_projected])
		var share := wins / maxf(count, 1.0)
		row.append_array([wins, BalanceReport.pct(share), BalanceContent.mean(ttks)])
		row.append_array(cells)
		rows.append(row)
		if share < targets.weapon_boss_win_share_min:
			report.flag(BalanceReport.WARN, "arena: weapon", "%s (Common, expected builds, kite, normal)" % weapon.id, "wins %d of %d" % [wins, count],
				">= %s of the bosses" % BalanceReport.pct(targets.weapon_boss_win_share_min), "the weapon loses to most bosses")
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	report.notes.append("Weapons arena: %d fights in %.0f s of real time." % [fights.size(), seconds])
	report.timings["weapons"] = seconds
	report.data["weapon_fights"] = fights
	report.table("weapon_arena", "Weapons", "Each weapon (Common, on the act's expected build otherwise) vs every boss, kite bot, Normal (engine). W win, L loss, T timeout; TTK projected from the damage dealt",
		columns, rows)
	return report


# --- Packs --------------------------------------------------------------------------------

func run_packs() -> BalanceReport:
	var report := BalanceReport.new()
	report.title = "Balance pack"
	var started := Time.get_ticks_msec()
	lab.override_chances()
	var results: Array = []
	var kind_rows: Array = []
	var room_rows: Array = []
	var rank_rows: Array = []
	var act_list: Array = range(1, content.dungeon.acts.size() + 1)
	if not acts.is_empty():
		act_list = act_list.filter(func(a: int) -> bool: return acts.has(a))
	if quick:
		act_list = [act_list[0]] if not act_list.is_empty() else []
	for act: int in act_list:
		var expected := BalanceBuild.expected(all_builds, act)
		if expected == null:
			continue
		var depth := BalanceContent.boss_depth(content, act) - 1
		var act_builds := builds.filter(func(b: BalanceBuildDef) -> bool: return b.act == act)
		for difficulty in core:
			var d_key := BalanceContent.key(difficulty)
			var s := lab.session(depth, difficulty)
			# Three of each kind (kite), the act's whole list.
			if expected in act_builds:
				var kinds: Array = content.dungeon.acts[act - 1].monsters.duplicate()
				if quick:
					kinds = kinds.slice(0, 3)
				for monster: MonsterDef in kinds:
					if monster == null:
						continue
					var foes := [{ "def": monster }, { "def": monster }, { "def": monster }]
					var got: Variant = await room(s, act, expected, foes, "kite", PACK_TIMEOUT, seed_value)
					if got == null:
						continue
					var r: Dictionary = got
					var kind_ttk := BalanceContent.mean(r.ttk_by_kind.get(String(monster.id), []))
					r.merge({ "act": act, "difficulty": d_key, "build": expected.name, "bot": "kite", "room": "3 x %s" % monster.id, "kind": String(monster.id), "kind_ttk": kind_ttk })
					results.append(r)
					kind_rows.append([act, String(monster.id), d_key, r.result, kind_ttk, r.clear_time, BalanceReport.pct(r.taken / float(r.hero_max_hp)), r.hits])
					if d_key == "normal" and monster.spawn_weight > 0 and kind_ttk >= 0.0 and (kind_ttk < targets.common_ttk_min or kind_ttk > targets.common_ttk_max):
						report.flag(BalanceReport.WARN, "pack: monster TTK", "%s vs %s (normal, depth %d)" % [expected.name, monster.id, depth], BalanceReport.secs(kind_ttk),
							"%.1f-%.1f s" % [targets.common_ttk_min, targets.common_ttk_max], "measured: first hurt to death, 3 at once, kite bot")
			# Mixed rooms by spawn weight: every build of the act, both bots.
			var size := lab.room_size(depth, difficulty)
			for build in act_builds:
				for bot in bots:
					var rooms := MIXED_ROOMS if not quick else 1
					var clear: Array = []
					var taken: Array = []
					var healed: Array = []
					var sources := {}
					var outcomes := PackedStringArray()
					for i in rooms:
						var foes := lab.roll_room(act, depth, size, seed_value * 1000 + act * 10 + i)
						var got: Variant = await room(s, act, build, foes, bot, PACK_TIMEOUT, seed_value + i)
						if got == null:
							continue
						var r: Dictionary = got
						r.merge({ "act": act, "difficulty": d_key, "build": build.name, "tags": build.tags, "bot": bot, "room": "mixed %d" % size })
						results.append(r)
						clear.append(r.clear_time)
						taken.append(r.taken / float(r.hero_max_hp))
						healed.append(r.healed / maxf(r.clear_time, 0.01))
						outcomes.append(r.result)
						for k: String in r.heal_sources:
							sources[k] = int(sources.get(k, 0)) + int(r.heal_sources[k])
					var mean_taken := BalanceContent.mean(taken)
					room_rows.append([act, build.name, d_key, bot, size, ", ".join(outcomes), BalanceContent.mean(clear), BalanceReport.pct(mean_taken),
						BalanceContent.mean(healed), BalanceLab.sources_text(sources)])
					if build == expected and d_key == "normal" and bot == "kite":
						if mean_taken > targets.pack_damage_share_max:
							report.flag(BalanceReport.WARN, "pack: damage taken", "%s (normal, kite, %d monsters)" % [build.name, size], BalanceReport.pct(mean_taken),
								"<= %s" % BalanceReport.pct(targets.pack_damage_share_max), "average per room, as a share of max health")
						if BalanceContent.mean(clear) > targets.pack_clear_max:
							report.flag(BalanceReport.WARN, "pack: clear time", "%s (normal, kite, %d monsters)" % [build.name, size], BalanceReport.secs(BalanceContent.mean(clear)),
								"<= %.0f s" % targets.pack_clear_max, "average room clear time")
						if outcomes.has("died"):
							report.flag(BalanceReport.WARN, "pack: death", "%s (normal, kite, %d monsters)" % [build.name, size], ", ".join(outcomes),
								"no death", "the expected build died clearing a room while playing well")
			# Ranked rooms: one Elite (each affix), Epic, Legendary, Shiny + 2 commons.
			if expected in act_builds:
				var variants: Array = []
				for rank in BalanceContent.ranks(content):
					if rank.affixes == 1:
						for affix in content.elite_affixes:
							variants.append({ "rank": rank, "affixes": [affix], "label": "%s %s" % [rank.id, affix.id] })
					else:
						variants.append({ "rank": rank, "affixes": [], "label": String(rank.id) })
				if quick:
					variants = variants.slice(0, 2)
				var commons := lab.roll_room(act, depth, 3, seed_value * 7 + act)
				for v: Dictionary in variants:
					for bot in bots:
						var foes: Array = [{ "def": commons[0].def, "rank": v.rank, "affixes": v.affixes }, commons[1], commons[2]]
						var got: Variant = await room(s, act, expected, foes, bot, PACK_TIMEOUT, seed_value)
						if got == null:
							continue
						var r: Dictionary = got
						var ranked_ttk: float = r.foe_ttks[0]
						r.merge({ "act": act, "difficulty": d_key, "build": expected.name, "bot": bot, "room": v.label, "ranked_ttk": ranked_ttk })
						results.append(r)
						rank_rows.append([act, v.label, String(commons[0].def.id), r.foes[0].max_hp, r.foes[0].defense, d_key, bot, r.result, ranked_ttk, r.clear_time,
							BalanceReport.pct(r.taken / float(r.hero_max_hp)), r.healed])
						var wanted: Variant = targets.rank_ttk.get(String((v.rank as MonsterRankDef).id))
						if d_key == "normal" and bot == "kite" and wanted != null and ranked_ttk >= 0.0 and (ranked_ttk < (wanted as Vector2).x or ranked_ttk > (wanted as Vector2).y):
							report.flag(BalanceReport.WARN, "pack: %s TTK" % (v.rank as MonsterRankDef).id, "%s vs %s %s (normal, depth %d)" % [expected.name, v.label, commons[0].def.id, depth],
								BalanceReport.secs(ranked_ttk), "%.0f-%.0f s" % [(wanted as Vector2).x, (wanted as Vector2).y], "measured: first hurt to death")
			await lab.close(s)
			if verbose:
				print("  packs: act %d %s done (%d measures)" % [act, d_key, results.size()])
	lab.restore_chances()
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	report.notes.append("Packs: %d rooms in %.0f s of real time (seed %d)." % [results.size(), seconds, seed_value])
	report.timings["pack"] = seconds
	report.data["packs"] = results
	report.table("pack_kinds", "Monsters", "Every monster kind of each act, three at once vs the act's expected build, kite bot (engine): time from first hurt to death",
		PackedStringArray(["Act", "Monster", "Difficulty", "Result", "TTK s", "Clear s", "Taken (share of max HP)", "Hits taken"]), kind_rows)
	report.table("pack_rooms", "Monsters", "Mixed rooms of each act's monsters (spawn weights, room size of the depth and difficulty) vs every build of the act (engine, %d rooms each)" % MIXED_ROOMS,
		PackedStringArray(["Act", "Build", "Difficulty", "Bot", "Monsters", "Results", "Clear s", "Taken per room", "Healed /s", "Heal sources"]), room_rows)
	report.table("pack_ranks", "Monsters", "Rooms with one ranked monster (Elite with each affix, Epic, Legendary, Shiny) + 2 commons vs the act's expected build (engine)",
		PackedStringArray(["Act", "Ranked", "Kind", "Its HP", "Its armor", "Difficulty", "Bot", "Result", "Ranked TTK s", "Clear s", "Taken", "Healed"]), rank_rows)
	return report


## A room (BalanceLab.pack) as a unit of work: kept in the cache, dealt to a worker.
func room(s: Dictionary, act: int, build: BalanceBuildDef, foes: Array, bot_name: String, limit: float, measure_seed: int) -> Variant:
	var id := "pack|%d|%d|%s|%s|%s|%s|%d|%.0f" % [act, s.depth, BalanceContent.key(s.difficulty), BalanceJobs.build_id(build), bot_name,
		foes_id(foes), measure_seed, limit]
	var roots := PackedStringArray([content.dungeon.acts[act - 1].resource_path])
	roots.append_array(BalanceJobs.build_roots(build, content))
	roots.append_array(difficulty_roots(s.difficulty))
	for foe: Dictionary in foes:
		roots.append((foe.def as MonsterDef).resource_path)
		for a: EliteAffixDef in foe.get("affixes", []):
			roots.append(a.resource_path)
	return await jobs.unit(id, roots, func() -> Dictionary: return await lab.pack(s, build, foes, bot_name, limit, measure_seed))


## "slime+elite:burning,rat,rat": a room's foes for its unit id.
static func foes_id(foes: Array) -> String:
	var parts := PackedStringArray()
	for foe: Dictionary in foes:
		var text := String((foe.def as MonsterDef).id)
		if foe.get("rank"):
			text += "+%s" % (foe.rank as MonsterRankDef).id
			var affixes := PackedStringArray()
			for a: EliteAffixDef in foe.get("affixes", []):
				affixes.append(String(a.id))
			if not affixes.is_empty():
				text += ":" + ":".join(affixes)
		parts.append(text)
	return ",".join(parts)


## What a boss fight did, frame by frame: damage both ways, heals by source, phases, the lowest HP.
class FightLog:
	## Health that came back without a heal() (a second life), in `heal_sources`.
	const REVIVE := "other (revive)"
	## A fall starting this many frames after a blow is the blow's doing (a push lasts ~0.3 s).
	const FALL_AFTER_BLOW := 45
	## Describe every hit taken (`--hits`): the fights' `hit_log`, printed after each fight.
	static var log_hits := false
	var player: Player
	var boss: Monster
	var dealt := 0
	var taken := 0
	var hits_taken := 0
	var tick_damage := 0
	var healed_by := {}
	var phases := 0
	var min_hp := 0
	var summons_killed := 0
	## Falls into a hole: thrown in (a blow landed within FALL_AFTER_BLOW frames, or its push was
	## still carrying him) or walked in (the bots should never: a player sees the holes).
	var falls_pushed := 0
	var falls_walked := 0
	## Damage taken by kind (ticks, shockwave, melee, shots, skill, adds, blasts): where a bot
	## gets hurt.
	var taken_by := {}
	## The hero is at the Threshold (a second life's trial): what he takes and heals there is
	## not the boss fight's (the trial's spectres, its own rules). The Deeps after a fall are:
	## the fight threw him there.
	var away := false
	## Every hit taken, described (`--hits`): what it was, how hard it pushed, where the hero
	## stood (near a hole?), and the falls with the blow that caused them.
	var hit_log: Array = []
	var _expected_hp := 0
	var _boss_hp := 0
	var _frames := 0
	## The skill the boss is casting, the last one it let go and the frame it did (what a hit
	## that lands after the cast came from).
	var _casting := ""
	var _last_cast := ""
	var _last_cast_frame := -1000
	var _falling := false
	var _fall_pushed := false
	var _fall_text := ""
	## The hero's push, roll and speed on the frame before (what a fall started from).
	var _before: Array = [0.0, false, 0.0]
	var _last_hit_text := ""
	var _last_hit_frame := -1000

	func _init(hero: Player, boss_actor: Monster) -> void:
		player = hero
		boss = boss_actor
		min_hp = player.hp
		_expected_hp = player.hp
		_boss_hp = boss.hp
		player.healed.connect(_on_healed)
		player.damaged.connect(_on_damaged)
		boss.health_changed.connect(_on_boss_health)
		boss.phase_entered.connect(func(index: int) -> void: phases = maxi(phases, index))
		Events.monster_killed.connect(_on_killed)

	func _on_healed(amount: int, source: StringName) -> void:
		if away:
			_expected_hp += amount
			return
		var key := String(source) if not String(source).is_empty() else "unattributed"
		healed_by[key] = int(healed_by.get(key, 0)) + amount
		_expected_hp += amount

	func _on_damaged(amount: int) -> void:
		if amount <= 0:
			return
		if away:
			_expected_hp -= amount
			return
		taken += amount
		_expected_hp -= amount
		var hit := player.last_hit
		if hit and hit.is_tick:
			tick_damage += amount
		else:
			hits_taken += 1
		var kind := _kind(hit)
		taken_by[kind] = int(taken_by.get(kind, 0)) + amount
		if kind == "falls":
			# Thrown in (a blow or its push still carrying him as he went over), or walked in.
			if _fall_pushed:
				falls_pushed += 1
			else:
				falls_walked += 1
		if log_hits and not (hit and hit.is_tick):
			_log_hit(hit, kind, amount)
		if kind != "falls" and not (hit and hit.is_tick):
			_last_hit_frame = _frames

	## One line of `hit_log`: "t 41.2 p3 skill quake_fierce +0.50s 26 (12%) push 380 slowed - dist 140 edge".
	func _log_hit(hit: HitInfo, kind: String, amount: int) -> void:
		var what := kind
		if kind == "falls" or (hit and hit.cause == &"fall"):
			what = "FALL (%s) after [%s]" % [_fall_text, _last_hit_text] if _frames - _last_hit_frame <= 90 else "FALL (%s)" % _fall_text
		elif (kind == "skill" or kind == "shots") and not _casting.is_empty() and boss.casting_skill() == null:
			what = "%s %s +0.00s" % [kind, _casting]  # let go this very frame
		elif kind == "skill" or kind == "shots":
			what = "%s %s +%.2fs" % [kind, _last_cast, (_frames - _last_cast_frame) / BalanceLab.FPS]
		elif kind == "melee":
			what = "melee (weapon)"
		var push := hit.knockback.length() if hit else 0.0
		var here := player.global_position
		var edge := false
		if is_instance_valid(player.world) and player.world.map:
			for i in 8:
				if not player.world.is_solid_ground(here + Vector2.from_angle(i * TAU / 8.0) * 48.0):
					edge = true
		var slowed := player.statuses.speed_multiplier() < 0.99
		var machine := boss.get_node_or_null("StateMachine") as StateMachine if is_instance_valid(boss) else null
		var state := String(machine.current.name) if machine and machine.current else "?"
		var text := "t %.1f p%d %s %d (%d%%) push %.0f%s dist %.0f%s [boss %s]" % [_frames / BalanceLab.FPS, phases + 1, what, amount,
			roundi(100.0 * amount / maxf(player.get_max_hp(), 1.0)), push, " slowed" if slowed else "",
			here.distance_to(boss.global_position) if is_instance_valid(boss) else -1.0, " EDGE" if edge else "", state]
		hit_log.append(text)
		if not what.begins_with("FALL"):
			_last_hit_text = text

	func _kind(hit: HitInfo) -> String:
		if hit == null:
			return "other"
		if hit.is_tick:
			return "ticks"
		if not is_instance_valid(hit.source):
			return "falls" if player.killed_by == "a fall" else "traps"
		if hit.source != boss:
			return "adds"
		if hit.is_secondary:
			# A shockwave (too many hits, a phase's roar), a blast, or the boss' body itself
			# (a wyrm's burning coils: WyrmBody).
			match hit.cause:
				&"shockwave": return "shockwave"
				&"blast": return "blasts"
			return "body"
		if hit.origin != Vector2.INF and hit.origin.distance_to(boss.global_position) > boss.radius + 60.0:
			return "shots"
		var machine := boss.get_node_or_null("StateMachine") as StateMachine
		if machine and machine.current and String(machine.current.name) == "Attack":
			return "melee"
		return "skill"

	func _on_boss_health(current: int, _maximum: int) -> void:
		if current < _boss_hp:
			dealt += _boss_hp - current
		_boss_hp = current

	func _on_killed(monster: Monster) -> void:
		if monster != boss:
			summons_killed += 1

	## Called every frame: health that came back by another way than heal() (a level up, a
	## Phoenix Feather) is counted as "other".
	func frame() -> void:
		if not is_instance_valid(player):
			return
		_frames += 1
		if player.is_falling and not _falling:
			_fall_pushed = _before[0] > 1.0 or _frames - _last_hit_frame <= FALL_AFTER_BLOW
			# What took him over the edge: a push still carrying him, a roll, his own steps.
			_fall_text = "falls: the frame before, push %.0f, %s, speed %.0f; last blow %.1f s ago" % [_before[0],
				"rolling" if _before[1] else "walking", _before[2], (_frames - _last_hit_frame) / BalanceLab.FPS]
		_falling = player.is_falling
		_before = [player._knockback.length(), player.is_dashing(), player.velocity.length()]
		if is_instance_valid(boss):
			var skill := boss.casting_skill()
			if skill:
				_casting = String(skill.id)
			elif not _casting.is_empty():
				_last_cast = _casting
				_last_cast_frame = _frames
				_casting = ""
		if player.hp > maxi(_expected_hp, 0):
			healed_by[REVIVE] = int(healed_by.get(REVIVE, 0)) + player.hp - maxi(_expected_hp, 0)
		_expected_hp = player.hp
		min_hp = mini(min_hp, player.hp)

	func summary(seconds: float) -> Dictionary:
		if Events.monster_killed.is_connected(_on_killed):
			Events.monster_killed.disconnect(_on_killed)
		var healed := 0
		for value: int in healed_by.values():
			healed += value
		var revived: int = healed_by.get(REVIVE, 0)
		return {
			"time": seconds, "phases": phases + 1, "damage_dealt": dealt, "dps": dealt / maxf(seconds, 0.01),
			"damage_taken": taken, "hits_taken": hits_taken, "tick_damage": tick_damage, "healed": healed,
			"heal_sources": healed_by.duplicate(), "heal_share": healed / maxf(taken, 1.0),
			"heal_share_sustain": (healed - revived) / maxf(taken, 1.0),
			"min_hp": min_hp, "min_hp_share": min_hp / float(maxi(player.get_max_hp(), 1)),
			"summons_killed": summons_killed, "taken_by": taken_by.duplicate(),
			"falls_pushed": falls_pushed, "falls_walked": falls_walked,
		}
