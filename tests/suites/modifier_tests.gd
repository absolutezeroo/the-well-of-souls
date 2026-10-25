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
