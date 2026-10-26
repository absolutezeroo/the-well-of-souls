class_name FloorKind
extends RefCounted
## What kind of floor World.build_floor() lays, and its own steps: whether a warden waits there,
## its twist (curse or event), its world (biome), its arena, how its map is generated and what is
## laid on it. One subclass per kind (NormalFloorKind, RouteFloorKind, BossFloorKind,
## HiddenFloorKind, FinaleFloorKind; ForcedFloorKind wraps any of them for a debug twist), chosen
## from the run's state by choose(): a new kind of floor is a new subclass, never another branch
## in the World. The World does what every floor shares (its look, walls, paths, the save's
## restore) between these steps, always in the same order, so a seed lays the same floor.
##
## The steps run in this order, each on the floor's dice (World.rng) as the one before left them:
## twist(), pick_biome(), pick_arena(), generate(), then (once the walls and paths are up) lay().


## The kind of the floor being built at `world.depth` (the World's hidden_floor and finale are set
## by the Game before). `taken`: the way down the hero chose to get here, or null.
static func choose(world: World, content: ContentDB, taken: FloorRoute) -> FloorKind:
	var kind: FloorKind
	var act_boss := content.dungeon.boss_for_depth(world.depth)
	if world.finale:
		kind = FinaleFloorKind.new(world.finale, world.finale_boss)
	elif world.hidden_floor:
		kind = HiddenFloorKind.new(world.hidden_floor)
	elif act_boss:
		kind = BossFloorKind.new(BossFloorKind.run_boss(world, content, act_boss))
	elif taken:
		kind = RouteFloorKind.new(taken)
	else:
		kind = NormalFloorKind.new()
	if world.overrides.has_twist():
		kind = ForcedFloorKind.new(kind, world.overrides.take_twist())
	return kind


## The warden fought on this floor (null: none, the floor has stairs and a seal).
func boss() -> BossDef:
	return null


func has_boss() -> bool:
	return boss() != null


## The floor's curse and event, as a way holding only them (null: neither).
func twist(_world: World, _content: ContentDB) -> FloorRoute:
	return null


## The floor's world: the debug one if forced, else the kind's own (_own_biome()), else one of its
## act's.
func pick_biome(world: World, content: ContentDB) -> BiomeDef:
	var forced := world.overrides.take_biome()
	if forced:
		return forced
	var own := _own_biome()
	if own:
		return own
	var act := content.dungeon.act_for_depth(world.depth)
	return act.pick_biome(world.depth, has_boss(), world.rng) if act else null


## The world this kind always is, after a forced one (null: its act draws one).
func _own_biome() -> BiomeDef:
	return null


## The arena the warden waits in (null: none, or a plain room).
func pick_arena(_world: World, _content: ContentDB) -> ArenaDef:
	return null


## The floor's map, in `world.biome` (already picked).
func generate(_world: World, _content: ContentDB) -> DungeonMap:
	return null


## What the floor holds, once its walls, paths and shaped rooms are up: its stairs or its arena,
## monsters, loot, secrets, the seal.
func lay(_world: World, _content: ContentDB) -> void:
	pass
