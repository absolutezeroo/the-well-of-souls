class_name FloorRoute
extends RefCounted
## One way down: what the next floor will be if the hero takes these stairs. Normal floors end
## on two stairs (and a boss arena opens two once the boss falls), each leading to a different
## world of the next act floor, maybe cursed (harder, better loot) or with an event. A sign over
## each stairs tells which. Floors before a boss have one way only: the boss's arena.
##
## The offer is fixed by the run's seed (same seed, same choice; a saved run gets it back), and
## the floor itself is still built from its own seed (see Game._enter_floor()).

var biome: BiomeDef
var curse: CurseDef
var floor_event: FloorEventDef


## The ways down to floor `depth` (empty: no choice there, the floor rolls its own world).
## `tuning`: the run's remote settings (RunState.tuning): a running event's floor event comes
## more often, and the Dawn Knell's omen is on every way (after the usual rolls: the rest of the
## offer stays the same). `luck`: the curses and events the run drew on floors above `below`
## come after the others (RunLuck.draw(): no repeats while others remain), and the two ways
## don't share one either.
static func offer(content: ContentDB, depth: int, difficulty: DifficultyDef, offer_seed: int, tuning: RemoteTuning = null, luck: RunLuck = null, below: int = 0) -> Array[FloorRoute]:
	var result: Array[FloorRoute] = []
	var config := content.dungeon
	if config.route_count < 2 or depth <= 1 or config.boss_for_depth(depth) != null:
		return result
	var act := config.act_for_depth(depth)
	if act == null:
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = offer_seed
	var worlds: Array = act.biomes.filter(func(b: BiomeDef) -> bool: return b != null and b.min_depth <= depth)
	if worlds.is_empty():
		return result
	var curse_chance := curse_chance_of(difficulty)
	var omen := omen_of(content, tuning)
	var drawn := luck.copy() if luck else null  # (what a way draws, the next one leaves)
	for i in config.route_count:
		var route := FloorRoute.new()
		# A different world for each way while there are some left.
		var left: Array = worlds.filter(func(b: BiomeDef) -> bool: return not result.any(func(r: FloorRoute) -> bool: return r.biome == b))
		route.biome = ContentDB.pick_from(left if not left.is_empty() else worlds, depth, rng) as BiomeDef
		var rolled := roll_twist(content, depth, rng, difficulty, tuning, drawn, below)
		route.curse = rolled.curse
		route.floor_event = rolled.floor_event
		# The second way is often the bold one: a twist if it rolled none.
		if i > 0 and route.is_plain() and rng.randf() < config.route_twist_chance:
			var curse_share := curse_chance / maxf(curse_chance + config.floor_event_chance, 0.01)
			if rng.randf() < curse_share:
				route.curse = pick_curse(content, depth, rng, drawn, below)
			if route.curse == null:
				route.floor_event = pick_event(content, depth, rng, tuning, drawn, below)
		if drawn:
			drawn.record(RunLuck.CURSE, route.curse, below - 1)
			drawn.record(RunLuck.EVENT, route.floor_event, below - 1)
		if omen:
			route.curse = omen as CurseDef
			route.floor_event = omen as FloorEventDef
		result.append(route)
	return result


## The twist of a floor at `depth`, rolled on `rng`: a curse with the difficulty's chance, else
## maybe an event (DungeonConfig.floor_event_chance). The one roll for a way down (offer()) and a
## floor rolling its own (World.build_floor()). A route holding only the twist (no world).
## `luck`, `below`: the run's draws above `below` come last (RunLuck.draw()).
static func roll_twist(content: ContentDB, depth: int, rng: RandomNumberGenerator, difficulty: DifficultyDef, tuning: RemoteTuning = null, luck: RunLuck = null, below: int = 0) -> FloorRoute:
	var twist_only := FloorRoute.new()
	if rng.randf() < curse_chance_of(difficulty):
		twist_only.curse = pick_curse(content, depth, rng, luck, below)
	if twist_only.curse == null and rng.randf() < content.dungeon.floor_event_chance:
		twist_only.floor_event = pick_event(content, depth, rng, tuning, luck, below)
	return twist_only


## A curse for a floor at `depth`, by spawn weight, those the run drew least first (`luck`).
static func pick_curse(content: ContentDB, depth: int, rng: RandomNumberGenerator, luck: RunLuck = null, below: int = 0) -> CurseDef:
	if luck:
		return luck.draw(RunLuck.CURSE, content.curses, depth, below, rng) as CurseDef
	return ContentDB.pick_from(content.curses, depth, rng) as CurseDef


## Chance for a floor to be cursed on this difficulty (none without one).
static func curse_chance_of(difficulty: DifficultyDef) -> float:
	return difficulty.curse_chance if difficulty else 0.0


## The Dawn Knell's omen (the remote settings' twist on every normal floor), or null.
static func omen_of(content: ContentDB, tuning: RemoteTuning) -> ContentDef:
	return DailyRun.twist(content, tuning.omen) if tuning else null


## A floor event for a floor at `depth`, by spawn weight, a running remote event's one boosted
## (`tuning`, the run's RemoteTuning), those the run drew least first (`luck`).
static func pick_event(content: ContentDB, depth: int, rng: RandomNumberGenerator, tuning: RemoteTuning = null, luck: RunLuck = null, below: int = 0) -> FloorEventDef:
	var boost: Dictionary = tuning.event_boost if tuning else {}
	if luck:
		return luck.draw(RunLuck.EVENT, content.floor_events, depth, below, rng, boost) as FloorEventDef
	return ContentDB.pick_from(content.floor_events, depth, rng, boost) as FloorEventDef


## The seed of the offer leading to floor `depth` in a run of seed `run_seed`.
static func seed_for(run_seed: int, depth: int) -> int:
	return hash("well-of-souls-routes-%d-%d" % [run_seed, depth])


func is_plain() -> bool:
	return curse == null and floor_event == null


## The sign over its stairs: the world's name.
func title() -> String:
	return tr(biome.display_name) if biome else tr("The depths")


## The second line of the sign: the curse or event and what it means, or "".
func twist() -> String:
	if curse:
		return tr("%s - better loot") % tr(curse.display_name)
	if floor_event:
		return tr(floor_event.display_name)
	return ""


func twist_color() -> Color:
	if curse:
		return curse.color
	if floor_event:
		return floor_event.color
	return Color.WHITE


## For the log: "the Drowned Caverns, cursed: Frostbound".
func summary() -> String:
	if curse:
		return tr("%s (cursed: %s)") % [title(), tr(curse.display_name)]
	if floor_event:
		return tr("{route} ({event})").format({ "route": title(), "event": tr(floor_event.display_name) })
	return title()
