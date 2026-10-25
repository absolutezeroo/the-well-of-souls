class_name ModifierTests
extends TestSuite
## Composition, compatibility and persistence of affix behaviours. Every test uses isolated
## monsters/resources; shared definitions must keep their native traits and stats untouched.

class RecordingTrait:
	extends MonsterTrait
	class Values:
		extends RefCounted
		var spawns := 0
		var hits := 0
	var digit := 1
	var blocks := false

	func make_state() -> RefCounted:
		return Values.new()

	func on_spawn(monster: Monster) -> void:
		(monster.trait_state(self) as Values).spawns += 1

	func incoming_damage(monster: Monster, _hit: HitInfo, amount: int) -> int:
		(monster.trait_state(self) as Values).hits += 1
		return amount * 10 + digit

	func can_attack(_monster: Monster) -> bool:
		return not blocks


func run_unit() -> void:
	_test_composition()
	_test_compatibility()
	_test_new_modifiers()
	var pestilent := load("res://data/elites/pestilent.tres") as EliteAffixDef
	check(CONTENT.elite_affixes.has(pestilent) and pestilent.traits.size() == 2 and pestilent.perk == null,
		"Pestilent is composed from registered behaviours without a special Monster branch")
	check(pestilent.traits[0] is OnHitStatusTrait and pestilent.traits[1] is DeathBurstTrait
		and (pestilent.traits[1] as DeathBurstTrait).fuse >= 0.6, "Pestilent combines poison hits with a warned delayed toxic burst")
	var boss := CONTENT.dungeon.acts[0].boss
	check(not pestilent.fits(boss, 6, []) and not pestilent.fits(CONTENT.all_monsters()[0], 3, []),
		"Pestilent starts at depth four and never applies to bosses")


func _test_composition() -> void:
	var native := RecordingTrait.new()
	var second := RecordingTrait.new()
	second.digit = 2
	var third := RecordingTrait.new()
	third.digit = 3
	third.blocks = true
	var def := CONTENT.all_monsters()[0].duplicate() as MonsterDef
	def.traits = [native]
	var a := EliteAffixDef.new()
	a.id = &"test_first"
	a.traits = [second, native]  # the native behaviour shared again activates only once
	var b := EliteAffixDef.new()
	b.id = &"test_second"
	b.traits = [third, second]
	var rank := MonsterRankDef.new()
	rank.affixes = 2
	var one := (load("res://src/entities/monster/monster.tscn") as PackedScene).instantiate() as Monster
	var two := (load("res://src/entities/monster/monster.tscn") as PackedScene).instantiate() as Monster
	one.setup(def, 4, CONTENT.dungeon)
	two.setup(def, 4, CONTENT.dungeon)
	one.make_ranked(rank, [a, b])
	two.make_ranked(rank, [a, b])
	check(one.behaviors.active == [native, second, third] and def.traits == [native]
		and a.traits == [second, native], "native traits precede affix traits, without mutating shared definitions")
	check((one.trait_state(native) as RecordingTrait.Values).spawns == 1
		and (one.trait_state(second) as RecordingTrait.Values).spawns == 1, "shared behaviour resources activate once per monster")
	check(one._incoming_damage(HitInfo.new(), 0) == 123, "damage hooks run in deterministic native-then-affix order")
	check((one.trait_state(second) as RecordingTrait.Values).hits == 1
		and (two.trait_state(second) as RecordingTrait.Values).hits == 0, "the same affix resource has independent state on each monster")
	check(not one.can_attack() and one.get_trait(RecordingTrait) == native, "affix attack hooks and trait lookup use the combined behaviours")
	var health := one.get_max_hp()
	one.make_ranked(rank, [a, b])
	check(one.get_max_hp() == health and one.behaviors.active.size() == 3
		and (one.trait_state(second) as RecordingTrait.Values).spawns == 1, "repeated ranking never stacks stats, rewards or behaviour activation")
	one.free()
	two.free()


func _test_compatibility() -> void:
	var def := CONTENT.all_monsters()[0].duplicate() as MonsterDef
	def.tags = [&"living", &"grounded"]
	var a := EliteAffixDef.new()
	a.id = &"first"
	a.min_depth = 3
	a.max_depth = 6
	a.required_tags = [&"living"]
	a.excluded_tags = [&"spirit"]
	check(a.fits(def, 4, []) and not a.fits(def, 2, []) and not a.fits(def, 7, []), "modifier depth bounds are data driven")
	def.tags.append(&"spirit")
	check(not a.fits(def, 4, []), "an excluded tag rejects the modifier")
	def.tags = [&"grounded"]
	check(not a.fits(def, 4, []), "every required tag must be present")
	def.tags.append(&"living")
	var b := EliteAffixDef.new()
	b.id = &"second"
	b.excludes = [&"first"]
	check(not a.fits(def, 4, [b]) and not b.fits(def, 4, [a]), "one-sided exclusions reject the combination in either selection order")
	check(not a.fits(def, 4, [a]), "a modifier cannot be applied twice")
	a.excluded_monsters = [def.id]
	check(not a.fits(def, 4, []), "a specific monster can opt out through data")


func run_game(game: Game) -> void:
	await game.debug.enter_floor(4)
	await _frames(3)
	var world := game.world
	await _clear_monsters(world)
	var player := game.player
	var affix := load("res://data/elites/pestilent.tres") as EliteAffixDef
	var monster := world.spawn_monster(load("res://data/monsters/rat.tres"), player.global_position + Vector2(90, 0))
	monster.make_ranked(CONTENT.dungeon.elite_rank, [affix])
	monster.process_mode = Node.PROCESS_MODE_DISABLED
	check(monster.affixes == [affix] and monster.get_trait(OnHitStatusTrait) != null
		and monster.get_trait(DeathBurstTrait) != null, "a spawned Pestilent monster receives both behaviours")
	player.statuses.clear()
	monster.on_hit_player(player)
	check(player.statuses.has(&"poison"), "the composable hit behaviour delivers its poison payload")
	for i in 5:
		player.statuses.tick(player, 1.0)
	check(not player.statuses.has(&"poison"), "poison ticks never reapply the affix and extend its own duration forever")
	player.statuses.clear()
	monster.hp = maxi(1, floori(monster.get_max_hp() * 0.5))
	var saved := world.floor_save.later_monsters()
	check(saved.size() == 1 and saved[0].affixes == ["pestilent"], "later monsters save the modifier's stable id")
	monster.free()
	world.floor_save.restore_later(JSON.parse_string(JSON.stringify(saved)))
	var found: Monster
	for actor in world.get_actors():
		if actor is Monster and (actor as Monster).affixes.has(affix):
			found = actor as Monster
			break
	check(found != null and found.get_trait(OnHitStatusTrait) != null and found.get_trait(DeathBurstTrait) != null
		and found.hp < found.get_max_hp(), "resuming restores the same modifier behaviours and remaining Health")
	if found == null:
		return
	found.process_mode = Node.PROCESS_MODE_DISABLED
	var burst := found.get_trait(DeathBurstTrait) as DeathBurstTrait
	player.global_position = world.nearest_free_point(found.global_position)
	player.invincible = false
	player.hp = player.get_max_hp()
	player._invulnerable_time = 0.0
	# Invoke the module hook directly, keeping loot/rank randomness out of the fuse regression.
	burst.on_died(found, null, false, true)
	check(not player.statuses.has(&"poison"), "a toxic death warns before its payload lands")
	await _frames(ceili(burst.fuse * 60.0) + 5)
	check(player.statuses.has(&"poison"), "the delayed toxic burst applies poison after its warning")
	player.statuses.clear()
	burst.on_died(found, null, true, true)
	await _frames(ceili(burst.fuse * 60.0) + 5)
	check(not player.statuses.has(&"poison"), "falling into a hole never releases the modifier's toxic burst")
	await _test_new_combat(game)


func _test_new_modifiers() -> void:
	var def := load("res://data/monsters/rat.tres") as MonsterDef
	for key in ["glacial", "frenzied", "vengeful", "unstable"]:
		var affix := load("res://data/elites/%s.tres" % key) as EliteAffixDef
		check(CONTENT.elite_affixes.has(affix) and not affix.traits.is_empty(), "%s is registered with reusable behaviours" % key)
		check(not affix.fits(CONTENT.dungeon.acts[0].boss, 8, [])
			and not affix.fits(def, affix.min_depth - 1, []), "%s respects its depth gate and boss exclusion" % key)
		for other in CONTENT.elite_affixes:
			check(affix.fits(def, 8, [other]) == other.fits(def, 8, [affix]), "%s compatibility is symmetric with %s" % [key, other.id])
	var frenzy_affix := load("res://data/elites/frenzied.tres") as EliteAffixDef
	var one := (load("res://src/entities/monster/monster.tscn") as PackedScene).instantiate() as Monster
	var two := (load("res://src/entities/monster/monster.tscn") as PackedScene).instantiate() as Monster
	one.setup(def, 5, CONTENT.dungeon)
	two.setup(def, 5, CONTENT.dungeon)
	one.make_ranked(CONTENT.dungeon.elite_rank, [frenzy_affix])
	two.make_ranked(CONTENT.dungeon.elite_rank, [frenzy_affix])
	var speed := one.get_move_speed()
	one.hp = floori(one.get_max_hp() * 0.5)
	check(is_equal_approx(one.get_move_speed(), speed * 1.3) and is_equal_approx(two.get_move_speed(), speed),
		"Frenzied changes only the wounded owner's walking speed at the inclusive threshold")
	var slow := OnHitStatus.new()
	slow.slow = 0.25
	slow.apply_to(one, null)
	check(is_equal_approx(one.get_move_speed(), speed * 1.3 * 0.75), "Frenzied respects normal slow effects")
	one.statuses.clear()
	one.heal(one.get_max_hp())
	check(is_equal_approx(one.get_move_speed(), speed) and is_equal_approx(def.stats.move_speed, two.base_stats.move_speed),
		"healing removes Frenzied immediately without editing shared stats")
	one.free()
	two.free()


func _spawn_modifier(world: World, player: Player, key: String) -> Monster:
	var affix := load("res://data/elites/%s.tres" % key) as EliteAffixDef
	var monster := world.spawn_monster(load("res://data/monsters/rat.tres"), player.global_position)
	monster.make_ranked(CONTENT.dungeon.elite_rank, [affix])
	monster.process_mode = Node.PROCESS_MODE_DISABLED
	monster.target = player
	return monster


func _test_new_combat(game: Game) -> void:
	await game.debug.enter_floor(5)
	await _frames(3)
	var world := game.world
	await _clear_monsters(world)
	var player := game.player
	var player_mode := player.process_mode
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = world.map.cell_to_world(_open_cell_near(world, player.global_position, 2))
	player.invincible = false
	player.hp = player.get_max_hp()
	player.statuses.clear()
	var glacial := _spawn_modifier(world, player, "glacial")
	glacial.on_hit_player(player, Combat.make_tick(glacial, 1))
	check(is_equal_approx(player.statuses.speed_multiplier(), 1.0), "Glacial ignores secondary ticks")
	glacial.on_hit_player(player, HitInfo.new())
	check(is_equal_approx(player.statuses.speed_multiplier(), 0.75), "Glacial applies its configured slow to a direct hit")
	player.statuses.tick(player, 2.1)
	check(is_equal_approx(player.statuses.speed_multiplier(), 1.0), "Glacial's slow expires without being banked")
	var cold := glacial.get_trait(DeathBurstTrait) as DeathBurstTrait
	player._invulnerable_time = 0.0
	cold.on_died(glacial, null, false, true)
	check(is_equal_approx(player.statuses.speed_multiplier(), 1.0), "Glacial's death burst warns before slowing")
	await _frames(ceili(cold.fuse * 60) + 5)
	check(is_equal_approx(player.statuses.speed_multiplier(), 0.75), "Glacial's death burst delivers its cold payload")
	player.statuses.clear()
	glacial.free()

	# The existing Vampiric uses the actual mitigated, ward-adjusted damage callback.
	var vampire := _spawn_modifier(world, player, "vampiric")
	vampire.hp = maxi(1, vampire.get_max_hp() - 12)
	var before := vampire.hp
	var hit := HitInfo.new()
	hit.source = vampire
	hit.amount = Combat.hit_for(10, player.get_stats().defense)
	player.ward = 0
	player._invulnerable_time = 0.0
	var health := player.hp
	player.take_hit(hit)
	var taken := health - player.hp
	check(taken > 0 and vampire.hp - before == floori(taken * 0.6), "Vampiric heals from actual direct damage through Armor")
	before = vampire.hp
	player._invulnerable_time = 0.0
	player.take_hit(Combat.make_tick(vampire, 5))
	check(vampire.hp == before, "Vampiric cannot heal from damage-over-time ticks")
	player.ward = 1000
	player._invulnerable_time = 0.0
	player.take_hit(hit)
	check(vampire.hp == before, "Vampiric cannot heal from a hit absorbed by a ward")
	player.ward = 0
	vampire.free()

	var vengeful := _spawn_modifier(world, player, "vengeful")
	var pulse := vengeful.get_trait(WarnedPulseTrait) as WarnedPulseTrait
	var state := vengeful.trait_state(pulse) as WarnedPulseTrait.PulseState
	hit = HitInfo.new()
	hit.source = player
	hit.amount = 1
	vengeful.take_hit(Combat.make_tick(player, 1))
	check(state.hits == 0 and not is_instance_valid(state.pending), "Vengeful ignores secondary damage")
	vengeful.take_hit(hit)
	vengeful.take_hit(hit)
	check(state.hits == 2 and not is_instance_valid(state.pending), "Vengeful waits for all three direct hits")
	vengeful.take_hit(hit)
	check(is_instance_valid(state.pending) and state.pending.progress() == 0.0, "the third hit creates a fixed warning before the riposte")
	var first := state.pending
	vengeful.take_hit(hit)
	check(state.pending == first and state.hits == 0, "hits during a pending riposte cannot queue extra strikes")
	player.hp = player.get_max_hp()
	player._invulnerable_time = 0.0
	health = player.hp
	await _frames(ceili(pulse.fuse * vengeful.get_telegraph_scale() * 60) + 5)
	check(player.hp < health, "the warned riposte actually deals damage after its fuse")
	pulse.on_damaged(vengeful, hit, 1)
	check(not is_instance_valid(state.pending) and state.hits == 0, "the riposte cooldown prevents an immediate new charge")
	pulse.update(vengeful, pulse.cooldown + pulse.fuse)
	for i in 3:
		pulse.on_damaged(vengeful, hit, 1)
	check(is_instance_valid(state.pending), "Vengeful can charge a new riposte after cooldown")
	pulse.on_died(vengeful, null, false, true)
	await _frames(2)
	check(not is_instance_valid(state.pending), "a dying Vengeful cancels its pending warning")
	state.hits = 2
	state.cooldown = 0.0
	vengeful.hp = 0
	pulse.on_damaged(vengeful, hit, 1)
	check(not is_instance_valid(state.pending), "a lethal hit never starts a riposte")
	vengeful.free()

	var unstable := _spawn_modifier(world, player, "unstable")
	pulse = unstable.get_trait(WarnedPulseTrait) as WarnedPulseTrait
	state = unstable.trait_state(pulse) as WarnedPulseTrait.PulseState
	unstable.dormant = true
	pulse.update(unstable, pulse.interval + 1.0)
	check(not is_instance_valid(state.pending) and state.remaining == pulse.interval, "dormant monsters never charge periodic explosions")
	unstable.dormant = false
	pulse.update(unstable, pulse.interval - 0.1)
	check(not is_instance_valid(state.pending), "Instable waits its full interval in combat")
	pulse.update(unstable, 0.2)
	check(is_instance_valid(state.pending), "Instable begins its announced explosion after the interval")
	if is_instance_valid(state.pending):
		var at := state.pending.global_position
		unstable.global_position += Vector2(24, 0)
		check(state.pending.global_position == at, "the warning stays on its announced spot when the monster moves")
	player._invulnerable_time = 0.0
	health = player.hp
	unstable.is_falling = true
	await _frames(ceili(pulse.fuse * unstable.get_telegraph_scale() * 60) + 5)
	check(player.hp == health, "a falling source cannot land a pending pulse")
	unstable.is_falling = false
	unstable.global_position = player.global_position
	state.cooldown = 0.0
	pulse.update(unstable, pulse.interval + 1.0)
	check(is_instance_valid(state.pending), "a surviving Instable can repeat its pulse")
	var pending := state.pending
	world.floor_id += 1
	player._invulnerable_time = 0.0
	health = player.hp
	await _frames(ceili(pulse.fuse * unstable.get_telegraph_scale() * 60) + 5)
	check(player.hp == health and not is_instance_valid(pending), "leaving the source floor cancels a pending pulse")
	unstable.free()
	player.statuses.clear()
	player.process_mode = player_mode
	await _test_new_saves(game)


func _test_new_saves(game: Game) -> void:
	var world := game.world
	await _clear_monsters(world)
	for key in ["glacial", "frenzied", "vengeful", "unstable"]:
		var monster := _spawn_modifier(world, game.player, key)
		monster.hp = maxi(1, floori(monster.get_max_hp() * 0.4))
		var saved := world.floor_save.later_monsters()
		var speed := monster.get_move_speed()
		monster.free()
		world.floor_save.restore_later(JSON.parse_string(JSON.stringify(saved)))
		var restored: Monster
		for actor in world.get_actors():
			if actor is Monster:
				restored = actor as Monster
				break
		check(restored != null and restored.affixes.size() == 1 and restored.affixes[0].id == StringName(key)
			and restored.hp < restored.get_max_hp() and is_equal_approx(restored.get_move_speed(), speed),
			"%s restores its stable id, Health and derived speed" % key)
		if restored:
			var pulse := restored.get_trait(WarnedPulseTrait) as WarnedPulseTrait
			if pulse:
				var state := restored.trait_state(pulse) as WarnedPulseTrait.PulseState
				check(state.hits == 0 and not is_instance_valid(state.pending) and state.remaining == pulse.interval,
					"%s resumes with fresh transient state and no stale warning" % key)
			restored.free()
