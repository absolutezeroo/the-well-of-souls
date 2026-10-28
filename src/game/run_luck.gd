class_name RunLuck
extends RefCounted
## The run's engineered luck (decision 0012, docs/design/pillars.md "Luck is engineered"):
## - **no repeats**: floor events, curses, encounters, pacts and trials are drawn among those the
##   run has drawn least (draw()): each comes once before any comes twice;
## - **bad-luck protection**: equipment found since the last Rare or better (`rare_drought`) makes
##   the next one likelier to be Rare or Epic (LootRoller, DungeonConfig > Loot: pity).
## Kept in RunState, shared by the World (World.luck) and saved with the run ("luck").
##
## A floor is laid again from its seed when a run is picked up, so its draws must come out the
## same: a floor's own draws see only what the floors above it drew (and what it drew itself so
## far), never what came later; forget() clears a floor's draws before it is laid again.

const CURSE := "curse"
const EVENT := "event"
const ENCOUNTER := "encounter"
const PACT := "pact"
const TRIAL := "trial"

## kind -> { id -> Array of the depths it was drawn on }.
var drawn := {}
## Equipment found since the last Rare or better (what the pity counts).
var rare_drought := 0


## A ContentDef of `pool` allowed at `depth` (min_depth, spawn_weight), among those of `kind`
## drawn least on floors above `below` (deeper floors' draws don't count), by spawn weight; null
## if none. `boost`: as ContentDB.pick_from(). Not recorded: the caller records what it keeps.
func draw(kind: String, pool: Array, depth: int, below: int, rng: RandomNumberGenerator, boost: Dictionary = {}) -> ContentDef:
	var fresh: Array = []
	var least := -1
	for def: ContentDef in pool:
		if def == null or def.min_depth > depth or def.spawn_weight <= 0:
			continue
		var times := times_drawn(kind, String(def.id), below)
		if least < 0 or times < least:
			least = times
			fresh.clear()
		if times == least:
			fresh.append(def)
	return ContentDB.pick_from(fresh, depth, rng, boost)


## Times `id` of `kind` was drawn on floors above `below`.
func times_drawn(kind: String, id: String, below: int) -> int:
	var depths: Array = (drawn.get(kind, {}) as Dictionary).get(id, [])
	var count := 0
	for at: Variant in depths:
		if int(at) < below:
			count += 1
	return count


## `def` of `kind` drawn on the floor at `depth` (null: nothing).
func record(kind: String, def: ContentDef, depth: int) -> void:
	if def == null:
		return
	if not drawn.has(kind):
		drawn[kind] = {}
	var ids: Dictionary = drawn[kind]
	var id := String(def.id)
	if not ids.has(id):
		ids[id] = []
	(ids[id] as Array).append(depth)


## The floor at `depth` is laid (again): what it drew before is drawn again.
func forget(depth: int) -> void:
	for kind: String in drawn:
		var ids: Dictionary = drawn[kind]
		for id: String in ids.keys():
			var depths: Array = ids[id]
			while depths.has(depth):
				depths.erase(depth)
			if depths.is_empty():
				ids.erase(id)


## A copy to draw on without changing this one (FloorRoute.offer(): what one way draws, the
## other leaves).
func copy() -> RunLuck:
	var other := RunLuck.new()
	other.drawn = drawn.duplicate(true)
	other.rare_drought = rare_drought
	return other


## A piece of equipment found: Rare or better ends the drought, anything else lengthens it.
func found_equipment(rarity: int) -> void:
	rare_drought = 0 if rarity >= ItemRarity.RARE else rare_drought + 1


func to_data() -> Dictionary:
	return { "drawn": drawn.duplicate(true), "rare_drought": rare_drought }


## From a save (anything damaged is skipped: an older save has none of it).
static func from_data(data: Variant) -> RunLuck:
	var luck := RunLuck.new()
	if not data is Dictionary:
		return luck
	luck.rare_drought = maxi(int((data as Dictionary).get("rare_drought", 0)), 0)
	var saved: Variant = (data as Dictionary).get("drawn", {})
	if not saved is Dictionary:
		return luck
	for kind: Variant in saved:
		var ids: Variant = saved[kind]
		if not ids is Dictionary:
			continue
		var kept := {}
		for id: Variant in ids:
			var depths: Variant = ids[id]
			if not depths is Array:
				continue
			var at: Array = []
			for depth: Variant in depths:
				if depth is int or depth is float:
					at.append(int(depth))
			if not at.is_empty():
				kept[str(id)] = at
		luck.drawn[str(kind)] = kept
	return luck
