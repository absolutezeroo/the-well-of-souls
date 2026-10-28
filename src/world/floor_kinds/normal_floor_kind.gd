class_name NormalFloorKind
extends FloorKind
## A floor of the dungeon with no warden: a generated map (the floor's size from the difficulty),
## its own twist rolled (a curse, or an event, from the second floor on; the Dawn Knell's omen
## over it), stairs sealed until enough of its monsters fall, and everything FloorPopulator lays.


func twist(world: World, content: ContentDB) -> FloorRoute:
	if world.depth <= 1:
		return null
	var rolled := FloorRoute.roll_twist(content, world.depth, world.rng, world.difficulty, world.tuning, world.luck, world.depth + 1)
	# The Dawn Knell's omen (remote settings) on every normal floor, after the usual rolls.
	var omen := FloorRoute.omen_of(content, world.tuning)
	if omen:
		rolled.curse = omen as CurseDef
		rolled.floor_event = omen as FloorEventDef
	return rolled


## The debug gallery's map if one is forced (FloorOverrides.map), else a generated one.
func generate(world: World, content: ContentDB) -> DungeonMap:
	if world.overrides.map:
		return world.overrides.map
	var difficulty := world.difficulty
	return DungeonGenerator.generate(content.dungeon, world.rng, difficulty.floor_size if difficulty else 1.0, difficulty.rooms if difficulty else 1.0, world.biome, world.depth)


func lay(world: World, content: ContentDB) -> void:
	var exits := world.spawn_exits()
	FloorPopulator.populate(world, content, world.depth)
	world.secrets = SecretRoom.spawn_all(world)
	world.seal.reset(world.monster_count(), content.dungeon.seal_share, content.dungeon.seal_reveal_left, content.dungeon.seal_max)
	world.seal_exits(exits)
