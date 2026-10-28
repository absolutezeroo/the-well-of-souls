class_name World
extends Node2D
## Everything that exists on the current floor: map, walls, actors, items, projectiles, effects.
## Also the gateway other systems use to spawn things and query the level.

## The hero took a way down: `route` is its index in `next_routes` (0 when there is no choice).
signal stairs_reached(route: int)
## A new floor was built (the explored map starts over).
signal map_reset
## Cells the hero discovered, or whose look changed (a floor that gave way...). For the minimap.
signal cells_changed(cells: Array[Vector2i])
## The hero walked into one of the floor's signature rooms for the first time (RoomShapeDef with
## `set_piece`): the Game names it.
signal set_piece_entered(shape: RoomShapeDef)

const STAIRS_SCENE := preload("res://src/entities/stairs/stairs.tscn")
## Room a body put down on the floor needs around it (find_open_point_near(), WorldSpace).
const BODY_ROOM := WorldSpace.BODY_ROOM

## Goes up with every floor built: delayed effects started on an old floor are dropped.
var floor_id := 0
var map: DungeonMap
var theme: DungeonTheme
var player: Player
var depth := 1
var rng := RandomNumberGenerator.new()
## The floor's combat dice: damage variance and crits (Combat.make_hit). Seeded from the floor's
## own seed when it is built, apart from `rng`, so the fights are the same for the same seed and
## inputs (a daily run, a balance measure) and a hit never shifts what the floor rolls next.
var combat_rng := RandomNumberGenerator.new()
## Difficulty of the run (set by the game before building floors).
var difficulty: DifficultyDef:
	set(value):
		difficulty = value
		if rules:
			rules = FloorRules.make(rules.config, value, floor_event, depth, curse)
## Boss floors only: the arena and its boss (null on normal floors), and its plan (ArenaDef).
var arena: BossArena
var arena_plan: ArenaDef
## The run's remote settings (RunState.tuning, set by the Game at the run's start): a running
## event's boosted floor event and the Dawn Knell's omen. Null: none.
var tuning: RemoteTuning
## What makes this floor special (null on most floors).
var floor_event: FloorEventDef
## The Well's curse on this whole floor (null on most floors).
var curse: CurseDef
## The world this floor belongs to (a mossy cave, a crypt, desert ruins...): its look, its
## grounds, scenes and decor (FloorDresser). `theme` is its theme.
var biome: BiomeDef
## The grounds laid on this floor (sand, moss...): GroundLayerDef -> cells (Dictionary).
var grounds := {}
## Difficulty, event and depth combined: ask it how hard and rewarding this floor is.
var rules: FloorRules
## Debug: what the next floor gets instead of rolling it (its twist, biome, map, arena, boss
## rank), each used once.
var overrides := FloorOverrides.new()
## The floors built from now on leave out their monsters and loose items, the last things a
## floor places (FloorPopulator): everything else lands where it would. For the balance tools,
## which spawn their own fights on a floor's ground and would only clear these away.
var unpeopled := false
## The ways down from this floor (FloorRoute), set by the Game before the floor is built.
## Two or more: each stairs leads to one, its sign says where. Empty: one stairs, no choice.
var next_routes: Array[FloorRoute] = []
## The way the hero took to this floor (null: none to choose, or the first floor).
var route: FloorRoute
## The run's rules from the Tree of Souls and its oath (RunBoons), set by the Game.
var boons := RunBoons.new():
	set(value):
		boons = value
		if rules:
			rules.boons = value  # the floor's drops and gold ask its rules (FloorRules.boons)

## The run's engineered luck (RunLuck: no repeats, bad-luck protection on drops), set by the Game;
## a floor's draws record into it as it is laid.
var luck := RunLuck.new()
## The floor's light color and brightness (its difficulty, curse and event): relight().
var _light_tint := Color.WHITE
## The boss of each act for this run (an act may have several; the game draws one per run).
## Empty or null entries: the act's main boss.
var run_bosses: Array[BossDef] = []
## The floor's ambush room, if it has one.
var ambush: AmbushRoom
## Tells a warden's story when the hero walks into its arena, before it wakes (the Game's
## BossMeeting; null: the fight starts at once). Not owned by the World.
var storyteller: Storyteller
## The floor's pact door, if it has one.
var pact: PactRoom
## The floor's room trial (RoomTrial: the Souls of Kagari, the Unbound Seal...), if it has one.
var room_trial: RoomTrial
## The fragment lying on this floor (FragmentPlacer), if any; `fragment_taken`: read already
## (saved with the floor: a run picked up again doesn't lay another).
var fragment: Fragment
var fragment_taken := false
## Merchant stock the hero locked and didn't buy: { item, price, locked } entries waiting for the
## next merchant (see Merchant). Lives as long as the run.
var kept_stock: Array[Dictionary] = []
## Floors in a row without the smith's forge (each makes the next more likely).
var floors_without_forge := 0
## The same, when this floor began (what a save keeps: a resumed run makes the floor again).
var forge_drought_at_start := 0
## What the hero used up of the things the floor's seed laid (items lying around, gold, props,
## encounters), kept for the save the same way (FloorLedger).
var ledger := FloorLedger.new()
## Where the stairs are (boss floors get theirs when the boss dies).
var stairs_cells: Array[Vector2i] = []
## Normal floors: the stairs open once enough of the floor's monsters are slain.
var seal := StairsSeal.new()
## The rooms hidden behind cracked walls on this floor (SecretRoom), in the map's order.
var secrets: Array[SecretRoom] = []
## The run already went down the hidden floor (HiddenFloorDef): no more keys. Set by the Game.
var hidden_floor_done := false
## Set by the Game before building the hidden floor (its look, monsters and boss); null otherwise.
var hidden_floor: HiddenFloorDef
## Set by the Game before building the bottom of the Well (its look, arena and boss); null
## otherwise.
var finale: FinaleDef
## Who waits there this run (RunState.bottom_boss(): the Nameless Keeper when one waits); null:
## the finale's own boss. Set by the Game with `finale`.
var finale_boss: BossDef
## Where walking monsters can go (pathfinding, blocked cells).
var nav := NavGrid.new()
## What hangs over the rooms (null: nothing, a boss arena, a simulation).
var ceiling: CeilingLayer
## The floor's signature rooms (room index -> named already).
var _set_pieces := {}
## What the hero has seen (the minimap).
var fog := FogOfWar.new()

var _content: ContentDB
## What lies on the floor, by kind (asked every frame: no group scans).
var _heat_sources: Array[HeatSource] = []
var _splats: SplatLayer
var _dark_rooms: Array[DarkRoom] = []
## When the hero was last told the stairs are sealed (seconds).
var _blocked_note_at := -10.0
## Who thinks this moment and who sleeps (off screen and far from the hero).
var activity := ActivityManager.new(self)
## Questions about the floor's space: free cells, where a body fits, line of sight (asked
## through the World's methods of the same names).
var space := WorldSpace.new(self)

@onready var _view: DungeonView = $DungeonView
@onready var _walls: StaticBody2D = $Walls
@onready var _entities: Node2D = $Entities
@onready var _projectiles: Node2D = $Projectiles
@onready var _effects: Node2D = $Effects
## The floor's light, in steps (lamps, torch, glowing shots, flashes).
@onready var lights: LightField = $Lights
## The floor's holes and cracked floor, and those filled or given way (for the save).
@onready var holes := HoleField.new(self, $Pits as PitLayer)
## The floor's part of the run's save: what the hero changed on it, laid back on a rebuilt floor.
@onready var floor_save := FloorSave.new(self, _entities)
## Owns creation and placement of entities and projectiles. World remains the public gateway.
@onready var spawns := WorldSpawner.new(self, _entities, _projectiles, _effects)


# --- Floor lifecycle ---------------------------------------------------------

func _ready() -> void:
	Events.monster_killed.connect(_on_monster_killed)
	Events.encounter_used.connect(func(encounter: Encounter) -> void: ledger.spend(FloorLedger.ENCOUNTER, encounter))
	seal.broken.connect(_on_seal_broken)
	BodyLook.warm_up(self)  # the body shader compiled while loading, not at the first burn


## Builds floor `new_depth` on the floor's dice (`rng`, seeded by the Game): what every floor
## shares here, always in this order; what its kind does (its boss, twist, world, arena, map, what
## lies on it) by its FloorKind, chosen from the run's state. `taken`: the way down the hero chose
## to get here (its world, curse or event), or null.
func build_floor(new_depth: int, content: ContentDB, taken: FloorRoute = null) -> void:
	clear_floor()
	route = taken
	floor_id += 1
	depth = new_depth
	combat_rng.seed = hash("%d-combat" % rng.seed)
	floor_save.reset()
	holes.forget()
	ledger.reset()
	ledger.numbering = true  # (until the floor is laid: what comes later is never laid again)
	forge_drought_at_start = floors_without_forge
	_content = content
	DeathPiecesVfx.warm_content(content)
	var kind := FloorKind.choose(self, content, taken)
	luck.forget(new_depth)  # (laid again from its seed: its draws come out the same)
	var twist := kind.twist(self, content)
	curse = twist.curse if twist else null
	floor_event = twist.floor_event if twist else null
	luck.record(RunLuck.CURSE, curse, depth)
	luck.record(RunLuck.EVENT, floor_event, depth)
	# The world first: its rooms take its shapes (BiomeDef.room_shapes).
	biome = kind.pick_biome(self, content)
	arena_plan = kind.pick_arena(self, content)
	map = kind.generate(self, content)
	overrides.map = null
	theme = biome.theme if biome else null
	rules = FloorRules.make(content.dungeon, difficulty, floor_event, depth, curse)
	rules.boons = boons
	_light_tint = rules.ambient_light()
	_view.show_map(map, theme)
	relight()
	_view.mist.bind_light(lights)
	holes.setup(map.tile_size)
	fog.reset(map)
	stairs_cells.clear()
	WallBuilder.build(map, _walls)
	nav.build(map)
	RoomFeatures.lay(self)  # the shaped rooms' chasms, pools and pillars
	kind.lay(self, content)
	ledger.numbering = false
	# Every kind of floor: the hidden floor's rooms are laid from the seed too.
	floor_save.apply()
	if not kind.has_boss() and boons.cartographer:
		reveal_landmarks()
	lay_ceiling()
	_set_pieces.clear()
	for i in map.rooms.size():
		if map.plan(i).is_set_piece():
			_set_pieces[i] = false
	map_reset.emit()


## What hangs over this floor's rooms (BiomeDef.ceiling, CeilingLayer), never over a boss arena
## (the fight stays clear). Nothing in a simulation (Vfx.shown off: the balance tools).
func lay_ceiling() -> void:
	ceiling = null
	if biome == null or biome.ceiling == null or not Vfx.shown:
		return
	ceiling = CeilingLayer.new()
	_effects.add_child(ceiling)
	ceiling.build(self, biome.ceiling, map.boss_room)


## Removes everything from the floor except the player.
func clear_floor() -> void:
	for merchant: Merchant in get_tree().get_nodes_in_group("merchants"):
		if merchant.world_of() == self:
			kept_stock.append_array(merchant.locked_entries())
			merchant.remove_from_group("merchants")  # counted once
	arena = null
	ambush = null
	secrets.clear()
	pact = null
	room_trial = null
	ceiling = null
	fragment = null
	fragment_taken = false
	activity.clear()
	grounds.clear()
	_heat_sources.clear()
	_dark_rooms.clear()
	if holes:
		holes.clear()
	for layer: Node in [_entities, _projectiles, _effects, _walls]:
		for child in layer.get_children():
			if child != player:
				layer.remove_child(child)
				child.queue_free()


func place_player(new_player: Player) -> void:
	player = new_player
	player.world = self
	if player.get_parent() == null:
		_entities.add_child(player)
	# A fall begun on the last floor ends here: its hole is gone (it would slide him toward it,
	# then drop him into the Deeps from this floor).
	player.stand_up()
	player.global_position = map.cell_to_world(map.start_cell)
	player.temperature.reset()
	player.reset_safe_position()
	player.perks.on_floor_started(player)
	player.camera.reset_smoothing()


# --- Spawning ----------------------------------------------------------------

## The bestiary's rules (mastered kinds take more damage), or null.
func bestiary_rules() -> BestiaryRules:
	return _content.bestiary if _content else null


## (Awake until the next look at who sleeps: see ActivityManager.)
func spawn_monster(def: MonsterDef, at: Vector2) -> Monster:
	return spawns.spawn_monster(def, at)


## Found loot: equipment may come out Magic, Rare or Epic (see LootRoller). `quality` above 1
## for better sources (elites, chests, bosses).
## A consumable the hero already carries plenty of comes as gold instead
## (DungeonConfig.consumable_carry_cap): then this returns null.
func spawn_loot(item: ItemDef, at: Vector2, quality: float = 1.0) -> ItemPickup:
	return spawns.spawn_loot(item, at, quality)


## `item`, or a better rolled copy of it if it is equipment.
func roll_item(item: ItemDef, quality: float = 1.0) -> ItemDef:
	return spawns.roll_item(item, quality)


## Coins on the floor, split in a few piles that fly to the hero when close.
func spawn_gold(at: Vector2, amount: int) -> void:
	spawns.spawn_gold(at, amount)


func spawn_encounter(def: EncounterDef, cell: Vector2i) -> Encounter:
	return spawns.spawn_encounter(def, cell)


## A fragment of `boss`'s past lying on `cell` (it doesn't block the way).
func spawn_fragment(def: FragmentDef, boss: BossDef, cell: Vector2i) -> Fragment:
	return spawns.spawn_fragment(def, boss, cell)


func spawn_forge(def: ForgeDef, cell: Vector2i) -> Forge:
	return spawns.spawn_forge(def, cell)


## A rune for this floor (null if none).
func pick_rune() -> RuneDef:
	return spawns.pick_rune()


## Drops a rune at `at` (`chance`: 1 = always).
func drop_rune(at: Vector2, chance: float = 1.0) -> void:
	spawns.drop_rune(at, chance)


func spawn_merchant(def: ShopDef, cell: Vector2i) -> Merchant:
	return spawns.spawn_merchant(def, cell)


## The locked stock waiting for the next merchant, plus what is locked at this floor's
## merchant (for save files: a saved run rebuilds its floor).
func locked_stock() -> Array[Dictionary]:
	var result := kept_stock.duplicate()
	for merchant: Merchant in get_tree().get_nodes_in_group("merchants"):
		if merchant.world_of() == self:
			result.append_array(merchant.locked_entries())
	return result


## Adds `node` among the floor's things (cleared with the floor).
func add_entity(node: Node2D) -> void:
	_entities.add_child(node)


## Rock that becomes floor (a secret room breaking open): drawn, lit, walked and pathed again.
func open_cells(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	var area := Rect2i(cells[0], Vector2i.ONE)
	for cell in cells:
		map.set_floor(cell)
		area = area.expand(cell).expand(cell + Vector2i.ONE)
	for child in _walls.get_children():
		_walls.remove_child(child)
		child.queue_free()
	WallBuilder.build(map, _walls)
	for cell in cells:
		nav.set_blocked(cell, false)
	_view.refresh(area)
	lights.refresh_walls()
	cells_changed.emit(cells)


## Puts `node` on `cell` among the entities; it blocks the cell for pathfinding unless told not to.
func _place_on_cell(node: Node2D, cell: Vector2i, blocks: bool = true) -> void:
	spawns.place_on_cell(node, cell, blocks)


func spawn_item(item: ItemDef, at: Vector2, armed: bool = true) -> ItemPickup:
	return spawns.spawn_item(item, at, armed)


## Fires a volley. Spread is spread evenly; 360 degrees makes a full ring.
## The shooter's perks can change the volley first (extra projectiles...).
## `from`: where it starts (the shooter by default; shards bursting out of a body...).
func fire_projectiles(shooter: Actor, direction: Vector2, spec: ProjectileSpec, from: Vector2 = Vector2.INF) -> void:
	spawns.fire_projectiles(shooter, direction, spec, from)


## Props stand on a cell (the top-left one of a bigger footprint) and block it until they break.
func spawn_prop(def: PropDef, cell: Vector2i) -> Prop:
	return spawns.spawn_prop(def, cell)


## A framed floor (3x3 tiles in `region` of `tiles`) over `cells`: a carpet, a mosaic...
func spawn_floor_patch(tiles: Texture2D, region: Rect2i, cells: Rect2i) -> FloorPatch:
	return spawns.spawn_floor_patch(tiles, region, cells)


func spawn_trap(def: TrapDef, cell: Vector2i, cycle_offset: float = 0.0) -> Trap:
	return spawns.spawn_trap(def, cell, cycle_offset)


## Monsters roll to be elites with the floor's chance (DungeonConfig > Elites, the difficulty).
## Maybe raises a freshly spawned monster's rank: the rare ranks first (Shiny, Legendary,
## Epic: DungeonConfig.rare_ranks), then the plain elite.
func roll_elite(monster: Monster) -> void:
	spawns.roll_elite(monster)


## A boss may come at a rare rank too (a Legendary Vampiric King Slime...). The debug panel's
## (FloorOverrides.boss_rank) wins once.
func roll_boss_rank(boss: Monster) -> void:
	spawns.roll_boss_rank(boss)


func make_elite(monster: Monster) -> void:
	spawns.make_elite(monster)


## `rank` with as many different affixes as it asks for.
func make_ranked(monster: Monster, rank: MonsterRankDef) -> void:
	spawns.make_ranked(monster, rank)


func spawn_chest(def: ChestDef, cell: Vector2i, trapped: bool) -> Chest:
	return spawns.spawn_chest(def, cell, trapped)


## What was taken from this floor, for a save file (FloorSave.to_data()).
func spent_data() -> Dictionary:
	return floor_save.to_data()


## The next floor built is the saved one again: what was taken from it stays taken. `data`:
## spent_data() as a save file reads it (RunSave.floor_of(); anything else restores nothing).
func restore_spent(data: Variant) -> void:
	floor_save.restore(data)


## This floor's merchant, if one waits here.
func floor_merchant() -> Merchant:
	for merchant: Merchant in get_tree().get_nodes_in_group("merchants"):
		if merchant.world_of() == self:
			return merchant
	return null


func spawn_ambush(room: Rect2i) -> AmbushRoom:
	return spawns.spawn_ambush(room)


## The room trial `planned` (RoomTrial.plan()) laid on this floor; `taken`: cells claimed.
func spawn_trial(planned: Dictionary, taken: Dictionary) -> RoomTrial:
	return spawns.spawn_trial(planned, taken)


## A pact door on `room` (PactRoom): sealed at once, candles inside by the door (pact_light).
func spawn_pact(def: PactDef, room: Rect2i, taken: Dictionary) -> PactRoom:
	return spawns.spawn_pact(def, room, taken)


func spawn_crumbling_floor(def: PitDef, cell: Vector2i) -> CrumblingFloor:
	return spawns.spawn_crumbling_floor(def, cell)


func forget_crack(cell: Vector2i) -> void:
	holes.forget_crack(cell)


## Cracked floor at `cell` gave way (CrumblingFloor.collapse()): a hole now, kept for the save.
func crack_collapsed(cell: Vector2i, def: PitDef) -> void:
	holes.crack_collapsed(cell, def)


func spawn_heat_source(def: HeatSourceDef, rect: Rect2i) -> HeatSource:
	var source := HeatSource.new()
	source.setup(def, self, rect)
	_effects.add_child(source)
	_heat_sources.append(source)
	return source


## The floor's campfires, springs and hot or frozen ground (see BodyTemperature).
## Asked by every body every frame (BodyTemperature): filtered only when one is gone.
func get_heat_sources() -> Array[HeatSource]:
	if _heat_sources.any(_is_gone):
		_heat_sources = _heat_sources.filter(func(source: Variant) -> bool: return not _is_gone(source))
	return _heat_sources


## A node freed or about to be (the floor's lists drop it).
static func _is_gone(node: Variant) -> bool:
	return not is_instance_valid(node) or (node as Node).is_queued_for_deletion()


func has_heat_source_in(def: HeatSourceDef, room: Rect2i) -> bool:
	return get_heat_sources().any(func(source: HeatSource) -> bool: return source.def == def and source.rect == room)


func spawn_dark_room(def: DarkRoomDef, room: Rect2i) -> DarkRoom:
	var dark := DarkRoom.new()
	dark.setup(def, self, room)
	_effects.add_child(dark)
	_dark_rooms.append(dark)
	return dark


func is_dark_room(room: Rect2i) -> bool:
	if _dark_rooms.any(_is_gone):
		_dark_rooms = _dark_rooms.filter(func(dark: Variant) -> bool: return not _is_gone(dark))
	for dark in _dark_rooms:
		if dark.room == room:
			return true
	return false


func spawn_quicksand(def: QuicksandDef, rect: Rect2i) -> Quicksand:
	return spawns.spawn_quicksand(def, rect)


## A shot from the dungeon itself (arrow traps): it hurts players and monsters alike.
func fire_trap_projectile(from: Vector2, direction: Vector2, spec: ProjectileSpec) -> void:
	spawns.fire_trap_projectile(from, direction, spec)


## A short burst of light (explosions...).
func flash_light(at: Vector2, color: Color, size: float) -> void:
	spawns.flash_light(at, color, size)


# --- The stairs' seal -------------------------------------------------------

func _on_monster_killed(monster: Monster) -> void:
	if monster.world == self:
		seal.add_kill()
		floor_save.count_slain(monster)


## The way down opens, and a guiding light shows it.
func _on_seal_broken() -> void:
	var stairs_at := map.cell_to_world(map.stairs_cell)
	Sfx.play_world(Sfx.bank.gate, player.global_position if player else stairs_at)
	if stairs_cells.size() >= 2 and next_routes.size() >= 2:
		Events.log_message(tr("The seal shatters: two ways down. %s, or %s.") % [next_routes[0].summary(), next_routes[1].summary()], Palette.GOLD)
	else:
		Events.log_message(tr("The seal shatters. The way down lies open."), Palette.GOLD)
	for cell in stairs_cells:
		flash_light(map.cell_to_world(cell), Palette.GOLD, 220.0)
	if player:
		for cell in stairs_cells:
			var path := find_path(player.global_position, map.cell_to_world(cell))
			if not path.is_empty():
				spawn_vfx(GuideWisp.create(player.global_position + Vector2(0, -18), path))
	reward_clear()


## The floor is won (its stairs open, or its boss fell): the Regeneration node heals the hero.
func reward_clear() -> void:
	if player == null or player.is_dead or boons.heal_on_clear <= 0.0:
		return
	var healed := player.heal(roundi(player.get_max_hp() * boons.heal_on_clear))
	if healed > 0:
		spawn_floating_text(player.head_position(), "+%d" % healed, Palette.HEAL)


## Elites and up drop a Magic (or better) piece of equipment (the Trophy Hunter node).
func drop_trophy(at: Vector2) -> void:
	for i in 20:
		var item := pick_random_item() as EquipmentDef
		if item:
			spawn_item(LootRoller.roll(item, depth, rules.drop_quality(), config(), _content.item_affixes, rng, ItemRarity.MAGIC, luck), at)
			return


## The floor's stairs open with its seal; stepped on sealed, they say what is missing.
func seal_exits(exits: Array[Stairs]) -> void:
	for stairs in exits:
		stairs.bind_seal(seal)
		stairs.blocked.connect(_on_stairs_blocked)


## The hero stepped on sealed stairs: say what is missing (not every frame).
func _on_stairs_blocked() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _blocked_note_at < 2.0:
		return
	_blocked_note_at = now
	Sfx.play_ui(Sfx.bank.ui_close, -4.0)
	var sealed := tr("Sealed. Slay %d more monster to open the stairs.") if seal.left() == 1 else tr("Sealed. Slay %d more monsters to open the stairs.")
	Events.log_message(sealed % seal.left(), Palette.SEAL)


## The floor's way down, or two when `next_routes` offers a choice (each with its sign).
func spawn_exits() -> Array[Stairs]:
	var result: Array[Stairs] = []
	var choice := next_routes.size() >= 2 and map.second_stairs_cell != DungeonMap.NO_CELL
	# A lone way is named on its sign too (the way down to the bottom of the Well).
	var lone := next_routes.size() == 1
	result.append(spawn_stairs(map.stairs_cell, 0, next_routes[0] if choice or lone else null))
	if choice:
		result.append(spawn_stairs(map.second_stairs_cell, 1, next_routes[1]))
	return result


## Stairs at `cell`; `index` and `way`: the route they lead to (null: no sign).
func spawn_stairs(cell: Vector2i, index: int = 0, way: FloorRoute = null) -> Stairs:
	var stairs := STAIRS_SCENE.instantiate() as Stairs
	if theme:
		stairs.texture = theme.stairs_texture()
	stairs.position = map.cell_to_world(cell)
	stairs.route = way
	stairs.reached.connect(func() -> void: stairs_reached.emit(index))
	stairs_cells.append(cell)
	stairs.z_index = -1
	_entities.add_child(stairs)
	return stairs


## Adds an effect where its layer says (VfxLayer): a standing one among the actors, sorted with
## them by its base; the others with the effects (their z puts them under or over the actors).
func spawn_vfx(node: Node2D) -> void:
	if not Vfx.shown and Vfx.is_cosmetic(node):
		node.queue_free()  # a simulation: nothing to see (Vfx.shown)
		return
	if VfxLayer.of(node) == VfxLayer.Layer.STANDING:
		_entities.add_child(node)
	else:
		_effects.add_child(node)


## Blood, slime, ink... on the floor (SplatLayer). Nothing over walls or holes.
func add_splat(at: Vector2, color: Color, size: float = 1.0, direction: Vector2 = Vector2.ZERO) -> void:
	if not Vfx.shown or color.a <= 0.0 or not is_solid_ground(at):
		return
	_splat_layer().add(at, color, size, direction, rng)


## Chips of what a monster was made of, left where it died for the whole floor.
func add_debris(at: Vector2, matter: ImpactMaterialDef, size: float = 1.0, direction: Vector2 = Vector2.ZERO) -> void:
	if not Vfx.shown or not is_solid_ground(at):
		return
	_splat_layer().add_debris(at, matter, size, direction, rng, is_solid_ground)


func _splat_layer() -> SplatLayer:
	if _splats == null or not is_instance_valid(_splats) or _splats.is_queued_for_deletion():
		_splats = SplatLayer.new()
		_effects.add_child(_splats)
	return _splats


## Chips flung on this floor so far.
func debris_count() -> int:
	return _splats.chip_count() if _splats and is_instance_valid(_splats) and not _splats.is_queued_for_deletion() else 0


func splat_count() -> int:
	return _splats.count() if _splats and is_instance_valid(_splats) and not _splats.is_queued_for_deletion() else 0


func spawn_floating_text(at: Vector2, text: String, color: Color) -> void:
	if not Vfx.shown:
		return
	spawns.floating_text(at, text, color)  # (from its pool: WorldSpawner.text_pool)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and spawns:
		spawns.free_pools()  # the shots and numbers kept for later go with the World


# --- Holes ------------------------------------------------------------------

## Makes `cell` a hole: anyone standing on it falls, monsters path around it (HoleField).
func add_pit(cell: Vector2i, def: PitDef) -> void:
	holes.add_pit(cell, def)


## Makes every one of `cells` a hole of `def` at once (a shaped room's chasm): one redraw of the map.
func add_pits(cells: Array[Vector2i], def: PitDef) -> void:
	holes.add_pits(cells, def)


## Deep water over `cells` (a shaped room's pool, RoomFeatures): drawn in `look`, nobody walks in it.
func spawn_pool(cells: Dictionary, look: GroundLayerDef, bounds: Rect2i) -> WaterPool:
	var pool := WaterPool.new()
	_effects.add_child(pool)
	pool.setup(self, cells, look, bounds)
	return pool


## Fills the hole `cell` belongs to (every hole cell joined to it): solid floor again, kept for
## the floor's save. Returns the cells filled (none if `cell` is no hole).
func seal_hole(cell: Vector2i) -> Array[Vector2i]:
	return holes.seal_hole(cell)


## Deep water of a shaped room's pool on `cell` (RoomFeatures): nobody walks there.
func is_pool(cell: Vector2i) -> bool:
	return map.feature_at(cell) == DungeonMap.Feature.POOL


func has_pit(cell: Vector2i) -> bool:
	return holes.has_pit(cell)


## The hole under `point`, if it is well inside one (a few pixels of edge are forgiven).
func pit_under(point: Vector2) -> PitDef:
	return holes.pit_under(point)


## Floor that can't give way: no wall, no hole, no cracked floor (where the hero climbs out
## after a fall).
func is_solid_ground(point: Vector2) -> bool:
	return space.is_solid_ground(point)


## Solid ground nothing stands on (no wall, hole, crack, chest, encounter, prop...).
func is_free_cell(cell: Vector2i) -> bool:
	return space.is_free_cell(cell)


## The centre of the free cell nearest to `point` (WorldSpace.nearest_free_point()).
func nearest_free_point(point: Vector2, max_radius: int = 12, clear_of: Array[Actor] = [], clearance: float = 0.0, room: float = 0.0) -> Vector2:
	return space.nearest_free_point(point, max_radius, clear_of, clearance, room)


# --- Exploration -------------------------------------------------------------

func is_explored(cell: Vector2i) -> bool:
	return fog.is_explored(cell)


## Lights the floor: its biome's lighting under its tint, or, with the debug panel's Full light
## (DebugCheats.full_light), all of it at its brightest. Again when that toggle changes.
func relight() -> void:
	if map == null:
		return
	if DebugCheats.full_light:
		lights.setup(map, null)
	else:
		lights.setup(map, theme.lighting if theme else null, _light_tint)


## The whole floor on the map (debug).
func reveal_all() -> void:
	cells_changed.emit(fog.reveal_all())


## The Cartographer node: the stairs, the merchant and the forge on the minimap from the start.
func reveal_landmarks() -> void:
	var spots: Array[Vector2i] = stairs_cells.duplicate()
	for group in ["merchants", "forges"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			if node is Node2D and is_ancestor_of(node):
				spots.append(map.world_to_cell((node as Node2D).global_position))
	var revealed: Array[Vector2i] = []
	for spot in spots:
		revealed.append_array(fog.reveal_rect(Rect2i(spot - Vector2i(2, 2), Vector2i(5, 5))))
	if not revealed.is_empty():
		cells_changed.emit(revealed)


## Reveals the room the hero stands in (all of it) and a few cells around them.
func reveal_around(point: Vector2) -> void:
	var revealed := fog.reveal_around(point)
	if not revealed.is_empty():
		cells_changed.emit(revealed)


func _physics_process(delta: float) -> void:
	if player and map and not player.is_dead:
		reveal_around(player.global_position)
		if not _set_pieces.is_empty():
			_name_set_piece(player.global_position)
	holes.step_on_cracks()
	activity.tick(delta)


## The hero at `point`: a signature room he walks into for the first time is named.
func _name_set_piece(point: Vector2) -> void:
	var cell := map.world_to_cell(point)
	var room := map.room_at(cell)
	if _set_pieces.get(room, true) or not map.plan(room).has_cell(cell):
		return
	_set_pieces[room] = true
	set_piece_entered.emit(map.plan(room).shape)


# --- Queries -----------------------------------------------------------------

func config() -> DungeonConfig:
	return _content.dungeon


## Everything the game holds (runes, items...): for content placed by data (SecretRewardDef).
func content_db() -> ContentDB:
	return _content


## A monster of the current act (ambushes, trapped chests).
func pick_monster() -> MonsterDef:
	return _content.pick_monster(depth, rng)


## A random item that can be found on this floor (chests, elite drops).
func pick_random_item() -> ItemDef:
	return _content.pick_item(depth, rng)


## A boss fight is on: the arena's boss is awake and alive (healing from hits and kills is
## slower, its adds feed no heals: see SustainRules, Monster.can_heal_killer()).
func is_boss_fight() -> bool:
	return is_instance_valid(arena) and arena.is_started and is_instance_valid(arena.boss) and not arena.boss.is_dead


## Living actors that are enemies of `faction`.
func get_hostiles(faction: Actor.Faction) -> Array[Actor]:
	var result: Array[Actor] = []
	if faction == Actor.Faction.PLAYER:
		for node in get_tree().get_nodes_in_group("monsters"):
			var monster := node as Actor
			if monster and not monster.is_dead and monster.is_inside_tree():
				result.append(monster)
	elif player and not player.is_dead:
		result.append(player)
	return result


## Every living actor, whatever its side (traps and explosions hurt everyone).
func get_actors() -> Array[Actor]:
	var result: Array[Actor] = get_hostiles(Actor.Faction.PLAYER)
	if player and not player.is_dead:
		result.append(player)
	return result


## get_actors(), worked out once per frame for everyone who asks (plants, quicksand...).
## Read only: the same array is handed to everyone.
func actors_this_frame() -> Array[Actor]:
	return space.actors_this_frame()


## The part of the world on screen (with a margin), once per frame: what lies outside needn't
## be redrawn.
func view_rect(margin: float = 96.0) -> Rect2:
	return space.view_rect(margin)


## Props that can still be broken.
func get_breakable_props() -> Array[Prop]:
	var result: Array[Prop] = []
	for node in get_tree().get_nodes_in_group("props"):
		var prop := node as Prop
		if prop and not prop.is_broken and prop.def.is_breakable() and prop.is_inside_tree():
			result.append(prop)
	return result


## Marks a cell as an obstacle (or free again) for monster pathfinding.
func set_cell_blocked(cell: Vector2i, blocked: bool) -> void:
	nav.set_blocked(cell, blocked)


## `exclude`: bodies the ray goes through (the thing looked at, solid itself: the merchant...).
func has_line_of_sight(from: Vector2, to: Vector2, exclude: Array[RID] = []) -> bool:
	return space.has_line_of_sight(from, to, exclude)


## Path between two world positions, as a list of cell centres (empty if unreachable).
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	return nav.find_path(from, to)


## A walkable point about `distance` away from `center` where a body of `room` px fits
## (WorldSpace.find_open_point_near()). Rolls on the floor's dice.
func find_open_point_near(center: Vector2, distance: float, room: float = BODY_ROOM) -> Vector2:
	return space.find_open_point_near(center, distance, room)


## Nothing that stops a body (walls, props, chests, ponds...) within `radius` of `point`.
func body_fits(point: Vector2, radius: float = BODY_ROOM) -> bool:
	return space.body_fits(point, radius)


func monster_count() -> int:
	return get_hostiles(Actor.Faction.PLAYER).size()
