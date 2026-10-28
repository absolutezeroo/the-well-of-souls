class_name RunSummary
extends RefCounted
## What the online leaderboards know of a run that ended (RunRecords makes it, Events.run_ended
## carries it to the Leaderboards autoload): its numbers, sent with each entry as its props so a
## suspicious score can be read in the dashboard, and checked here first (check()): a run no
## hero could have played is never sent. Plain data, no node.

## The game's version (application/config/version).
var version := ""
## The daily run's day (DailyRun.today()), -1 for a normal run; the day's first attempt or not.
var daily_day := -1
var daily_official := false
## The run's seed (a daily run's floors come from its day).
var run_seed := 0
## Difficulty id (easy, normal, hard, nightmare) and ascension level.
var difficulty: StringName = &""
var ascension := 0
var depth := 1
var kills := 0
var bosses := 0
var gold := 0
var won := false
## In-game seconds (RunState.time), and the win's (-1: not won).
var time := 0.0
var finish_time := -1.0
## The weapon in hand at the end, and the daily run's relic (ids).
var weapon: StringName = &""
var relic: StringName = &""
## The Dawn Knell's points (DailyRun.score()), 0 for a normal run.
var score := 0
## Nights the seal was held (La Veille, not in the game yet): 0.
var nights := 0
## A debug run (DebugCheats.debug_run): never sent anywhere.
var debug := false
## An aided run (RunState.assisted: the Souls' Aid, or its difficulty lowered midway): never sent
## to a leaderboard.
var assisted := false


## The summary of `run` as it ends, with its hero.
static func of(run: RunState, player: Player, content: ContentDB) -> RunSummary:
	var summary := RunSummary.new()
	summary.version = str(ProjectSettings.get_setting("application/config/version", ""))
	summary.daily_day = run.daily_day
	summary.daily_official = run.daily_official
	summary.run_seed = run.run_seed
	summary.difficulty = run.difficulty.id if run.difficulty else &""
	summary.ascension = run.difficulty.ascension if run.difficulty else 0
	summary.depth = run.depth
	summary.kills = run.kills
	summary.bosses = run.bosses_slain
	summary.gold = run.run_gold
	summary.won = run.has_won
	summary.time = run.time
	summary.finish_time = run.finish_time
	if player:
		var held := player.get_weapon()
		summary.weapon = held.id if held else &""
	if run.is_daily():
		var start_relic := DailyRun.relic(content, run.daily_day)
		summary.relic = start_relic.id if start_relic else &""
		summary.score = DailyRun.score(run)
	summary.debug = DebugCheats.debug_run
	summary.assisted = run.assisted
	return summary


## Why it can't be sent (empty: it can). Only what no real run does: a score that isn't what its
## numbers make, a run faster than `config` allows, more kills, bosses or gold than floors hold.
func check(config: LeaderboardsConfig) -> String:
	if depth < 1 or kills < 0 or bosses < 0 or gold < 0 or time < 0.0 or score < 0:
		return "negative numbers"
	if bosses > depth:
		return "more bosses than floors"
	if kills > config.max_kills_per_floor * depth:
		return "too many kills"
	if gold > config.max_gold_per_floor * depth:
		return "too much gold"
	if time < config.min_seconds_per_floor * (depth - 1):
		return "too fast"
	if won and (finish_time <= 0.0 or finish_time > time + 0.01):
		return "a win without its time"
	if daily_day >= 0 and score != expected_daily_score():
		return "the score isn't the run's"
	return ""


## The Dawn Knell's points its numbers make (DailyRun's rule).
func expected_daily_score() -> int:
	return kills * DailyRun.POINTS_PER_KILL + (depth - 1) * DailyRun.POINTS_PER_FLOOR \
		+ bosses * DailyRun.POINTS_PER_BOSS + (DailyRun.POINTS_FOR_VICTORY if won else 0) \
		+ int(gold / float(DailyRun.GOLD_PER_POINT))


## The entry's props (strings, as Talo keeps them): the run in short, read in the dashboard.
## (The board's period, "day" or "week", is added by the Leaderboards autoload.)
func props() -> Dictionary:
	var result := {
		"v": version,
		"diff": String(difficulty),
		"asc": str(ascension),
		"depth": str(depth),
		"kills": str(kills),
		"bosses": str(bosses),
		"gold": str(gold),
		"won": "1" if won else "0",
		"time": "%.1f" % time,
		"weapon": String(weapon),
		"seed": str(run_seed),
	}
	if daily_day >= 0:
		result["relic"] = String(relic)
	return result
