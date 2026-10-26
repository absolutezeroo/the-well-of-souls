class_name WorldSpawner
extends RefCounted
## Creates floor entities and projectiles in their owning layers, using the World's rules
## and dice. The World keeps its public factory methods as delegates; no extra group scans.

const MONSTER_SCENE := preload("res://src/entities/monster/monster.tscn")
const PICKUP_SCENE := preload("res://src/entities/pickup/item_pickup.tscn")
const PROJECTILE_SCENE := preload("res://src/entities/projectile/projectile.tscn")
const PROP_SCENE := preload("res://src/entities/prop/prop.tscn")
const TRAP_SCENE := preload("res://src/entities/trap/trap.tscn")
const FLASH_SCENE := preload("res://src/vfx/light_flash.tscn")

var _world: World
var _entities: Node2D
var _projectiles: Node2D
var _effects: Node2D

## A typed deferred batch. Holds weak targets, never captured actor nodes in lambdas.
class SpawnBatch:
	extends RefCounted
	var kinds: Array[MonsterDef] = []
	var count := 0
	var at := Vector2.ZERO
	var radius := 0.0
	var target: WeakRef
	var generation := 0


func _init(world: World, entities: Node2D, projectiles: Node2D, effects: Node2D) -> void:
	_world = world
	_entities = entities
	_projectiles = projectiles
	_effects = effects


func spawn_monster(def: MonsterDef, at: Vector2) -> Monster:
	var monster := MONSTER_SCENE.instantiate() as Monster
	monster.world = _world
	monster.setup(def, _world.depth, _world.content_db().dungeon)
	monster.position = at
	_entities.add_child(monster)
	return monster


func defer_monsters(kinds: Array[MonsterDef], count: int, at: Vector2, radius: float, target: Actor) -> void:
	var batch := SpawnBatch.new()
	batch.kinds = kinds.duplicate()
	batch.count = count
	batch.at = at
	batch.radius = radius
	batch.target = weakref(target)
	batch.generation = _world.floor_id
	_spawn_batch.call_deferred(batch)


func _spawn_batch(batch: SpawnBatch) -> void:
	if is_instance_valid(_world) and _world.floor_id == batch.generation:
		for i in batch.count:
			var kind: MonsterDef = batch.kinds.pick_random() if not batch.kinds.is_empty() else _world.pick_monster()
			if kind == null:
				break
			var monster := spawn_monster(kind, _world.find_open_point_near(batch.at, batch.radius, WorldSpace.room_for(kind)))
			monster.target = batch.target.get_ref() as Actor if batch.target else null
			Vfx.puff(_world, monster.global_position)


func spawn_loot(item: ItemDef, at: Vector2, quality: float = 1.0) -> ItemPickup:
	# (Never while the floor is laid: what the seed lays must not hang on the hero's bag, or a
	# resumed floor would come out otherwise.)
	if item is ConsumableDef and _world.player and not _world.ledger.numbering and _world.player.pack.carried_count(item) >= _world.config().consumable_carry_cap:
		spawn_gold(at, maxi(_world.config().consumable_gold_min, roundi(item.value * _world.config().consumable_gold_share)))
		return null
	return spawn_item(roll_item(item, _world.rules.drop_quality(quality)), at)


func roll_item(item: ItemDef, quality: float = 1.0) -> ItemDef:
	return LootRoller.roll(item, _world.depth, quality, _world.config(), _world.content_db().item_affixes, _world.rng)


func spawn_gold(at: Vector2, amount: int) -> void:
	amount = _world.rules.floor_gold(amount)
	if amount <= 0:
		return
	var piles := clampi(ceili(amount / _world.config().gold_per_pile), 1, _world.config().gold_max_piles)
	for i in piles:
		var share := floori(float(amount) / piles) + (1 if i < amount % piles else 0)
		if share <= 0:
			continue
		spawn_gold_pile(at, share)


func spawn_gold_pile(at: Vector2, amount: int) -> GoldPickup:
	var coin := GoldPickup.create(at, amount, _world)
	if _world.ledger.lay(FloorLedger.GOLD, coin, str(amount)) >= 0:
		coin.collected.connect(func(pile: GoldPickup) -> void: _world.ledger.spend(FloorLedger.GOLD, pile))
	_add_pickup.call_deferred(coin, _world.floor_id)
	return coin


func spawn_encounter(def: EncounterDef, cell: Vector2i) -> Encounter:
	var encounter := Encounter.new()
	encounter.setup(def, _world)
	place_on_cell(encounter, cell)
	_world.ledger.lay(FloorLedger.ENCOUNTER, encounter, String(def.id))
	return encounter


func spawn_fragment(def: FragmentDef, boss: BossDef, cell: Vector2i) -> Fragment:
	var piece := Fragment.new()
	piece.setup(def, boss)
	place_on_cell(piece, cell, false)
	_world.fragment = piece
	return piece


func spawn_forge(def: ForgeDef, cell: Vector2i) -> Forge:
	var forge := Forge.new()
	forge.setup(def, _world)
	place_on_cell(forge, cell)
	return forge


func pick_rune() -> RuneDef:
	return _world.content_db().pick_rune(_world.depth, _world.rng) if _world.content_db() else null


func drop_rune(at: Vector2, chance: float = 1.0) -> void:
	if chance < 1.0 and _world.rng.randf() >= chance:
		return
	var rune := pick_rune()
	if rune:
		spawn_item(rune, at)


func spawn_merchant(def: ShopDef, cell: Vector2i) -> Merchant:
	var merchant := Merchant.new()
	merchant.setup(def, _world)
	place_on_cell(merchant, cell)
	return merchant


## Placement and path blocking happen in the same order as adding a floor entity.
func place_on_cell(node: Node2D, cell: Vector2i, blocks: bool = true) -> void:
	node.position = _world.map.cell_to_world(cell)
	_entities.add_child(node)
	if blocks:
		_world.set_cell_blocked(cell, true)


func spawn_item(item: ItemDef, at: Vector2, armed: bool = true) -> ItemPickup:
	var pickup := PICKUP_SCENE.instantiate() as ItemPickup
	pickup.setup(item, armed)
	pickup.position = at
	if _world.ledger.lay(FloorLedger.ITEM, pickup, String(item.id)) >= 0:
		pickup.taken.connect(func(gone: ItemPickup) -> void: _world.ledger.spend(FloorLedger.ITEM, gone))
	_add_pickup.call_deferred(pickup, _world.floor_id)  # may be called from physics callbacks
	return pickup


## A floor may have changed before a deferred drop reaches the tree.
func _add_pickup(pickup: Node2D, generation: int) -> void:
	if not is_instance_valid(pickup):
		return
	if not is_instance_valid(_world) or not is_instance_valid(_entities) or _world.floor_id != generation:
		pickup.free()
		return
	_entities.add_child(pickup)


func fire_projectiles(shooter: Actor, direction: Vector2, spec: ProjectileSpec, from: Vector2 = Vector2.INF) -> void:
	if not spec.secondary:  # shards and rings fired by passives get no extra projectiles
		shooter.perks.modify_projectiles(shooter, spec)
	for i in spec.count:
		var angle := 0.0
		if spec.spread_degrees >= 360.0:
			angle = 360.0 * i / spec.count
		elif spec.count > 1:
			angle = lerpf(-spec.spread_degrees * 0.5, spec.spread_degrees * 0.5, float(i) / (spec.count - 1))
		var shot_direction := direction.rotated(deg_to_rad(angle))
		var projectile := PROJECTILE_SCENE.instantiate() as Projectile
		projectile.setup(shooter, shot_direction, spec)
		if from == Vector2.INF:
			projectile.position = shooter.global_position + shot_direction * (shooter.radius * 0.5)
		else:
			projectile.position = from + shot_direction * 6.0
		_projectiles.add_child.call_deferred(projectile)


func spawn_prop(def: PropDef, cell: Vector2i) -> Prop:
	var prop := PROP_SCENE.instantiate() as Prop
	prop.world = _world
	prop.setup(def)
	place_on_cell(prop, cell)
	if _world.ledger.lay(FloorLedger.PROP, prop, String(def.id)) >= 0:
		prop.broken.connect(func(gone: Prop) -> void: _world.ledger.spend(FloorLedger.PROP, gone))
	if def.footprint != Vector2i.ONE:
		prop.position += (Vector2(def.footprint) - Vector2.ONE) * _world.map.tile_size * 0.5
		for y in def.footprint.y:
			for x in def.footprint.x:
				_world.set_cell_blocked(cell + Vector2i(x, y), true)
	return prop


func spawn_floor_patch(tiles: Texture2D, region: Rect2i, cells: Rect2i) -> FloorPatch:
	var patch := FloorPatch.new()
	patch.setup(tiles, region, _world, cells)
	_effects.add_child(patch)
	return patch


func spawn_trap(def: TrapDef, cell: Vector2i, cycle_offset: float = 0.0) -> Trap:
	var trap := TRAP_SCENE.instantiate() as Trap
	trap.world = _world
	trap.setup(def, cycle_offset)
	place_on_cell(trap, cell, false)
	return trap


func roll_elite(monster: Monster) -> void:
	for rank in _world.config().rare_ranks:
		if rank and _world.rng.randf() < _world.rules.rank_chance(rank):
			make_ranked(monster, rank)
			return
	if _world.rng.randf() < _world.rules.elite_chance():
		make_elite(monster)


func roll_boss_rank(boss: Monster) -> void:
	var forced := _world.overrides.take_boss_rank()
	if forced:
		make_ranked(boss, forced)
		return
	for rank in _world.config().rare_ranks:
		if rank and _world.rng.randf() < _world.rules.boss_rank_chance(rank):
			make_ranked(boss, rank)
			return


func make_elite(monster: Monster) -> void:
	make_ranked(monster, _world.config().elite_rank)


func make_ranked(monster: Monster, rank: MonsterRankDef) -> void:
	if monster.rank != null:
		return
	var picked: Array[EliteAffixDef] = []
	for attempt in rank.affixes * 6:
		if picked.size() >= rank.affixes:
			break
		var affix := _world.content_db().pick_affix(_world.depth, _world.rng)
		if affix and affix.fits(monster.def, _world.depth, picked):
			picked.append(affix)
	monster.make_ranked(rank, picked)


func spawn_chest(def: ChestDef, cell: Vector2i, trapped: bool) -> Chest:
	var chest := Chest.new()
	chest.setup(def, _world, trapped)
	place_on_cell(chest, cell)
	chest.opened.connect(func(_chest: Chest) -> void: _world.floor_save.opened_chests.append(cell))
	return chest


func spawn_ambush(room: Rect2i) -> AmbushRoom:
	_world.ambush = AmbushRoom.new()
	_entities.add_child(_world.ambush)
	_world.ambush.setup(_world, room)
	return _world.ambush


func spawn_trial(planned: Dictionary, taken: Dictionary) -> RoomTrial:
	var def := planned.get("trial") as TrialDef
	if def == null:
		return null
	_world.room_trial = def.make(_world, planned, taken)
	if _world.room_trial:
		_entities.add_child(_world.room_trial)
	return _world.room_trial


func spawn_pact(def: PactDef, room: Rect2i, taken: Dictionary) -> PactRoom:
	_world.pact = PactRoom.new()
	_entities.add_child(_world.pact)
	_world.pact.setup_pact(_world, room, def, _world.config().pact_light, taken)
	return _world.pact


func spawn_crumbling_floor(def: PitDef, cell: Vector2i) -> CrumblingFloor:
	var tile := CrumblingFloor.new()
	tile.setup(def, _world, cell)
	_effects.add_child(tile)
	_world.holes.add_crack(cell, tile)
	return tile


func spawn_quicksand(def: QuicksandDef, rect: Rect2i) -> Quicksand:
	var pool := Quicksand.new()
	pool.setup(def, _world, rect)
	_effects.add_child(pool)
	return pool


func fire_trap_projectile(from: Vector2, direction: Vector2, spec: ProjectileSpec) -> void:
	var projectile := PROJECTILE_SCENE.instantiate() as Projectile
	projectile.setup_trap(_world, direction, spec)
	projectile.position = from
	_projectiles.add_child.call_deferred(projectile)


func flash_light(at: Vector2, color: Color, size: float) -> void:
	if not Vfx.shown:
		return
	var flash := FLASH_SCENE.instantiate() as LightFlash
	flash.position = at
	flash.setup(color, size)
	_effects.add_child(flash)
