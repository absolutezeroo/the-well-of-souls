class_name VarietyTests
extends TestSuite
## What makes runs differ (docs/design/builds.md "Behaviour perks", "Rule-bending relics",
## "Weapon evolutions"; progression.md "Oaths"): perks that change how you play rather than add
## numbers, relics that bend a rule, weapons that evolve, kits sworn at the Well.
## run_unit() on the unit suite (data and rules, no game); the run_* parts on fresh games of the
## game suite.

## The perks that do something in the world on a roll, a shot, a crit, a kill or by themselves.
const BEHAVIOUR_PERKS := ["cinder_wake", "riven_glyph", "leaping_bolt", "burst_veins", "rime_halo"]


# --- The unit suite --------------------------------------------------------------------

func run_unit() -> void:
	_test_behaviour_share()


## A third of the perks that are not plain staples change how you play (a new action in the
## world), and each family has one of the new kinds; the four staples stay plain.
func _test_behaviour_share() -> void:
	var families := {}
	for id: String in BEHAVIOUR_PERKS:
		var perk := _perk(id)
		check(perk != null and CONTENT.perks.has(perk), "%s is offered" % id)
		if perk == null:
			continue
		check(perk.role == BuildRole.Role.BUILD_AROUND and perk.synergies.size() == 1 and not perk.description.is_empty(), "%s: a build-around of one family that says what it does" % id)
		check(perk.weight >= 5 and perk.weight <= 7 and perk.rarity == PerkDef.Rarity.COMMON, "%s: offered as often as the other build-arounds (weight %d)" % [id, perk.weight])
		families[perk.synergies[0]] = true
	check(families.size() == 5, "one new behaviour perk in each of the five families")
	var behaviour := 0
	var others := 0
	for perk in CONTENT.perks:
		if ["strength", "precision", "fortune", "war_banner"].has(String(perk.id)):
			continue
		others += 1
		if perk.passives.any(func(p: Passive) -> bool: return _acts_in_world(p)):
			behaviour += 1
	check(behaviour * 3 >= others, "a third of the perks past the four staples act in the world (%d of %d)" % [behaviour, others])


## A passive that makes something happen in the world (a wave, a shot, a trail, a leap, a ring),
## rather than changing a number of the hit.
static func _acts_in_world(passive: Passive) -> bool:
	return passive is EmberTrailPassive or passive is SplitShotPassive or passive is CritLeapPassive \
		or passive is OverkillBurstPassive or passive is FrostOrbitPassive or passive is DashShockwavePassive \
		or passive is CritShockwavePassive or passive is KillBurstPassive or passive is RetaliatePassive \
		or passive is ChainLightningPassive or passive is ExtraProjectilesPassive \
		or passive is SkillEchoPassive or passive is CheatDeathPassive or passive is FloorWardPassive


# --- The game suite ----------------------------------------------------------------------

## The five behaviour perks, each doing its thing on a real floor.
func run_behaviour_perks(game: Game) -> void:
	var world := game.world
	var player := game.player
	player.base_stats.defense = 999
	player.invalidate_stats()
	await _clear_monsters(world)
	await _test_cinder_wake(world, player)
	await _test_riven_glyph(world, player)
	await _test_leaping_bolt(world, player)
	await _test_burst_veins(world, player)
	await _test_rime_halo(world, player)


## A monster that stands where it is put and lasts.
func _dummy(world: World, at: Vector2, health: int = 9999) -> Monster:
	var monster := world.spawn_monster(load("res://data/monsters/slime.tres"), at)
	monster.dormant = true
	monster.base_stats.max_hp = health
	monster.base_stats.defense = 0
	monster.invalidate_stats()
	monster.hp = health
	return monster


## A clear line of `length` from near the hero: [start, direction] (the hero moved to its start).
func _lane(world: World, player: Player, length: float) -> Vector2:
	var lane := _clear_lane(world, player.global_position, length)
	player.global_position = lane[0]
	await _stand_still(world, player)
	return lane[1]


func _trails(world: World) -> Array[EmberTrail]:
	var found: Array[EmberTrail] = []
	for node in world.find_children("*", "Node2D", true, false):
		if node is EmberTrail and not node.is_queued_for_deletion():
			found.append(node)
	return found


func _test_cinder_wake(world: World, player: Player) -> void:
	var direction := await _lane(world, player, 200.0)
	player.perks.add(_perk("cinder_wake"))
	var start := player.global_position
	player.start_dash(direction * 300.0, 0.3, true)
	await _frames(24)
	var trails := _trails(world)
	check(trails.size() == 1, "Cinder Wake: a roll leaves a trail of embers (%d)" % trails.size())
	var middle := start.lerp(player.global_position, 0.5)
	var victim := _dummy(world, middle)
	await _frames(45)
	check(victim.statuses.has(&"burn") and victim.hp < victim.get_max_hp(), "...an enemy standing in it catches fire and is hurt")
	await _frames(200)
	check(_trails(world).is_empty(), "...and the embers go out after their 3 s")
	victim.queue_free()
	player.perks.clear()
	await _frames(2)


func _test_riven_glyph(world: World, player: Player) -> void:
	var direction := await _lane(world, player, 220.0)
	player.perks.add(_perk("riven_glyph"))
	var front := _dummy(world, player.global_position + direction * 60.0)
	var behind := _dummy(world, player.global_position + direction * 120.0)
	var spec := ProjectileSpec.new()
	spec.damage = 40
	spec.speed = 500.0
	spec.max_distance = 400.0
	world.fire_projectiles(player, direction, spec)
	await _frames(40)
	check(front.hp < front.get_max_hp(), "Riven Glyph: the shot strikes the first enemy")
	check(behind.hp < behind.get_max_hp(), "...and splits: its bolts fly on into the one behind")
	var lost := behind.get_max_hp() - behind.hp
	check(lost <= roundi(40 * 0.3 * 1.15) * 3, "...each bolt a share of the hit (%d lost)" % lost)
	# A bolt never splits again: hits it deals are secondary.
	var bolt := Combat.make_secondary_hit(player, 10)
	bolt.shot = direction
	var count_before := world.get_node("Projectiles").get_child_count()
	behind.take_hit(bolt)
	await _frames(2)
	check(world.get_node("Projectiles").get_child_count() <= count_before, "...and its bolts never split again")
	front.queue_free()
	behind.queue_free()
	player.perks.clear()
	await _frames(2)


func _test_leaping_bolt(world: World, player: Player) -> void:
	var direction := await _lane(world, player, 200.0)
	player.perks.add(_perk("leaping_bolt"))
	var struck := _dummy(world, player.global_position + direction * 60.0)
	var apart := _dummy(world, player.global_position + direction * 150.0)
	var plain := HitInfo.new()
	plain.amount = 20
	plain.source = player
	struck.take_hit(plain)
	check(apart.hp == apart.get_max_hp(), "Leaping Bolt: a plain hit leaps nowhere")
	var crit := HitInfo.new()
	crit.amount = 40
	crit.is_crit = true
	crit.source = player
	struck.take_hit(crit)
	check(apart.get_max_hp() - apart.hp == roundi(40 * 0.7), "...a critical hit leaps to the enemy standing apart, 70%% of it (%d)" % (apart.get_max_hp() - apart.hp))
	struck.queue_free()
	apart.queue_free()
	player.perks.clear()
	await _frames(2)


func _test_burst_veins(world: World, player: Player) -> void:
	var direction := await _lane(world, player, 200.0)
	var veins := _perk("burst_veins")
	var burst := veins.passives[0] as OverkillBurstPassive
	player.perks.add(veins)
	var weak := _dummy(world, player.global_position + direction * 70.0, 10)
	var near := _dummy(world, player.global_position + direction * 100.0)
	var blow := HitInfo.new()
	blow.amount = 60
	blow.source = player
	weak.take_hit(blow)
	check(weak.is_dead, "Burst Veins: the blow kills")
	var power := player.get_power()
	var expected := clampi(60 - 10, roundi(power * burst.minimum), roundi(power * burst.cap))
	check(near.get_max_hp() - near.hp == expected, "...and what it dealt beyond the Health left bursts onto the enemy beside (%d, expected %d)" % [near.get_max_hp() - near.hp, expected])
	var far := _dummy(world, player.global_position + direction * 190.0)
	var light := _dummy(world, player.global_position + direction * 70.0, 3)
	var tap := HitInfo.new()
	tap.amount = 3
	tap.source = player
	var near_before := near.hp
	light.take_hit(tap)
	check(near_before - near.hp == maxi(1, roundi(power * burst.minimum)), "...a blow that only just kills still splashes its minimum")
	check(far.hp == far.get_max_hp(), "...and only the enemies around the body")
	near.queue_free()
	far.queue_free()
	player.perks.clear()
	await _frames(2)


func _test_rime_halo(world: World, player: Player) -> void:
	var direction := await _lane(world, player, 160.0)
	var halo := _perk("rime_halo")
	player.perks.add(halo)
	var orbit := (halo.passives[0] as FrostOrbitPassive).orbit
	var near := _dummy(world, player.global_position + direction * orbit)
	var far := _dummy(world, player.global_position + direction * (orbit + 70.0))
	var slowed := false
	for i in 150:
		await _frames(1)
		slowed = slowed or near.statuses.is_slowed()
	check(near.hp < near.get_max_hp() and slowed, "Rime Halo: its shards cut and chill an enemy at the ring's distance")
	check(far.hp == far.get_max_hp(), "...not one out of their reach")
	var hits := 0
	var last := near.hp
	for i in 60:
		await _frames(1)
		if near.hp < last:
			hits += 1
			last = near.hp
	check(hits <= 2, "...each enemy at most once every 0.6 s (%d hits in a second)" % hits)
	var looks := player.find_children("*", "Node2D", false, false).filter(func(n: Node) -> bool: return n is FrostOrbitVfx)
	check(looks.size() == 1, "...its shards are drawn circling the hero")
	player.perks.clear()
	await _frames(30)
	looks = player.find_children("*", "Node2D", false, false).filter(func(n: Node) -> bool: return n is FrostOrbitVfx and not n.is_queued_for_deletion())
	check(looks.is_empty(), "...and they go with the perk")
	near.queue_free()
	far.queue_free()
	await _frames(2)
