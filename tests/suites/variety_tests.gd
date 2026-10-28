class_name VarietyTests
extends TestSuite
## What makes runs differ (docs/design/builds.md "Behaviour perks", "Rule-bending relics",
## "Weapon evolutions"; progression.md "Oaths"): perks that change how you play rather than add
## numbers, relics that bend a rule, weapons that evolve, kits sworn at the Well.
## run_unit() on the unit suite (data and rules, no game); the run_* parts on fresh games of the
## game suite.

## The perks that do something in the world on a roll, a shot, a crit, a kill or by themselves.
const BEHAVIOUR_PERKS := ["cinder_wake", "riven_glyph", "leaping_bolt", "burst_veins", "rime_halo"]
## The relics that bend a rule (PerkDef.twist).
const TWISTS := ["bleeding_stride", "starving_litany", "restless_storm", "funeral_pyre", "heart_of_winter"]


# --- The unit suite --------------------------------------------------------------------

func run_unit() -> void:
	_test_behaviour_share()
	_test_twists()


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


## Relics that bend a rule: one in every warden's choice, never anywhere else.
func _test_twists() -> void:
	var families := {}
	for id: String in TWISTS:
		var relic := _perk(id)
		check(relic != null and CONTENT.perks.has(relic), "%s is offered" % id)
		if relic == null:
			continue
		check(relic.twist and relic.rarity == PerkDef.Rarity.RARE and relic.max_stacks == 1, "%s: a relic that bends a rule, taken once" % id)
		check(relic.role == BuildRole.Role.BUILD_AROUND and relic.synergies.size() == 1, "%s: a build-around of one family" % id)
		check(not relic.description.is_empty() and tr(relic.description).length() <= 160, "%s: its rule reads in one line (%d characters)" % [id, tr(relic.description).length()])
		families[relic.synergies[0]] = true
	check(families.size() == 5, "one relic that bends a rule in each family")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var owned := PerkSet.new()
	var warden_ok := true
	var plain_ok := true
	for i in 300:
		var warden := CONTENT.pick_perks(owned, 3, PerkDef.Rarity.RARE, rng, [], 1.0, OfferQueue.BOSS_TWISTS)
		warden_ok = warden_ok and warden.size() == 3 and warden.filter(func(p: PerkDef) -> bool: return p.twist).size() == 1
		for rarity in [PerkDef.Rarity.RARE, PerkDef.Rarity.COMMON]:
			plain_ok = plain_ok and not CONTENT.pick_perks(owned, 3, rarity, rng).any(func(p: PerkDef) -> bool: return p.twist)
	check(warden_ok, "a warden's 3 relics hold exactly one that bends a rule")
	check(plain_ok, "level ups, pacts, trials and gifts never offer one")
	var queue := OfferQueue.new()
	queue.add_relic(CONTENT.dungeon.acts[0].boss)
	var offer := queue.pop()
	check(offer.twists == OfferQueue.BOSS_TWISTS, "a warden's offer asks for one")
	var saved := OfferQueue.new()
	saved.load_data([offer.to_data()])
	check(saved.pop().twists == OfferQueue.BOSS_TWISTS, "...and a saved run keeps it")
	var daily_ok := true
	for day in 400:
		var relic := DailyRun.relic(CONTENT, 20000 + day)
		daily_ok = daily_ok and relic != null and not relic.twist
	check(daily_ok, "the daily run's relic is never one (the day is the same for everyone)")


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


# --- Relics that bend a rule ---------------------------------------------------------------

## The five relics that bend a rule, each on a real floor, and a warden's choice holding one.
func run_twist_relics(game: Game) -> void:
	var world := game.world
	var player := game.player
	await _clear_monsters(world)
	await _test_bleeding_stride(world, player)
	await _test_starving_litany(world, player)
	await _test_restless_storm(world, player)
	await _test_funeral_pyre(world, player)
	await _test_heart_of_winter(world, player)
	await _test_warden_choice(game)


func _full(player: Player) -> void:
	player.hp = player.get_max_hp()
	player._invulnerable_time = 0.0


func _test_bleeding_stride(world: World, player: Player) -> void:
	var direction := await _lane(world, player, 200.0)
	_full(player)
	player.perks.add(_perk("bleeding_stride"))
	var passed := _dummy(world, player.global_position + direction * 60.0)
	var hp := player.hp
	player.facing = direction
	_set_move(direction)
	player.use_skill(0)
	await _frames(30)
	_set_move(Vector2.ZERO)
	check(hp - player.hp == roundi(player.get_max_hp() * 0.04), "Bleeding Stride: a roll costs 4%% of max Health (%d)" % (hp - player.hp))
	check(passed.hp < passed.get_max_hp(), "...and cuts the enemy it rolls through")
	player.hp = 1
	player.skills.reset_cooldown(player.def.innate_skills[0])
	await _frames(2)
	player.use_skill(0)
	await _frames(25)
	check(player.hp == 1 and not player.is_dead, "...a price that never deals the last blow")
	passed.queue_free()
	player.perks.clear()
	await _stand_still(world, player)


func _test_starving_litany(world: World, player: Player) -> void:
	var direction := await _lane(world, player, 160.0)
	_full(player)
	player.perks.add(_perk("starving_litany"))
	var slot := -1
	for i in player.skills.skills.size():
		if i > 0 and player.skills.skills[i] != null:
			slot = i
			break
	check(slot > 0, "the hero has a weapon skill to starve")
	if slot < 0:
		player.perks.clear()
		return
	player.skills.reset_cooldown(player.skills.skills[slot])
	var foe := _dummy(world, player.global_position + direction * 50.0)
	player.facing = direction
	check(player.skills.try_use(slot, player, direction), "...a skill is used")
	var waiting := player.skills.cooldown_left(slot)
	await _frames(60)
	check(waiting > 0.0 and is_equal_approx(player.skills.cooldown_left(slot), waiting), "Starving Litany: a used skill does not recharge with time (%.2f s left)" % player.skills.cooldown_left(slot))
	var roll := player.def.innate_skills[0]
	player.use_skill(0)
	var roll_wait := player.skills.cooldown_left(0)
	await _frames(20)
	check(roll_wait > 0.0 and player.skills.cooldown_left(0) < roll_wait, "...the roll still recharges (%s)" % roll.id)
	var weak := _dummy(world, player.global_position + direction * 90.0, 1)
	var kill := Combat.make_hit_from(player, 50)
	weak.take_hit(kill)
	check(weak.is_dead and player.skills.cooldown_left(slot) <= waiting - player.skills.skills[slot].cooldown * 0.25 + 0.01, "...a kill takes a quarter of its wait off")
	foe.queue_free()
	player.perks.clear()
	await _stand_still(world, player)


func _test_restless_storm(world: World, player: Player) -> void:
	var direction := await _lane(world, player, 200.0)
	_full(player)
	player.perks.add(_perk("restless_storm"))
	var hp := player.hp
	await _frames(90)
	check(player.hp == hp, "Restless Storm: no foe near, standing still costs nothing")
	var foe := _dummy(world, player.global_position + direction * 140.0)
	_set_move(direction)
	await _frames(50)
	_set_move(Vector2.ZERO)
	check(foe.hp < foe.get_max_hp(), "...moving, lightning strikes the foe nearby")
	check(player.hp == hp, "...and spares the hero")
	await _stand_still(world, player)
	foe.global_position = player.global_position + direction * 100.0
	await _frames(100)
	check(player.hp < hp and player.hp >= hp - roundi(player.get_max_hp() * 0.03) * 2, "...standing still over a second, it strikes him (%d lost)" % (hp - player.hp))
	foe.queue_free()
	player.perks.clear()
	await _frames(2)


func _test_funeral_pyre(world: World, player: Player) -> void:
	var direction := await _lane(world, player, 200.0)
	_full(player)
	player.perks.add(_perk("funeral_pyre"))
	var neighbour := _dummy(world, player.global_position + direction * 150.0)
	var far_one := _dummy(world, player.global_position + direction * 110.0, 1)
	var hp := player.hp
	far_one.take_hit(Combat.make_hit_from(player, 50))
	await _frames(2)
	check(far_one.is_dead and neighbour.hp < neighbour.get_max_hp(), "Funeral Pyre: a slain foe explodes onto the one beside it")
	check(player.hp == hp, "...and spares the hero standing out of the blast")
	var close := _dummy(world, player.global_position + direction * 30.0, 1)
	close.take_hit(Combat.make_hit_from(player, 50))
	await _frames(2)
	check(hp - player.hp == roundi(player.get_max_hp() * 0.06), "...the blast burns the hero standing in it (%d)" % (hp - player.hp))
	neighbour.queue_free()
	player.perks.clear()
	await _frames(2)


func _test_heart_of_winter(world: World, player: Player) -> void:
	var direction := await _lane(world, player, 200.0)
	_full(player)
	var speed := player.get_move_speed()
	player.perks.add(_perk("heart_of_winter"))
	check(player.get_move_speed() < speed, "Heart of Winter: the hero moves slower (%d -> %d)" % [speed, player.get_move_speed()])
	var near := _dummy(world, player.global_position + direction * 70.0)
	var far := _dummy(world, player.global_position + direction * 180.0)
	await _frames(30)
	check(near.statuses.is_slowed() and not far.statuses.is_slowed(), "...foes close to him are slowed, not the ones away")
	near.queue_free()
	far.queue_free()
	player.perks.clear()
	await _frames(2)


func _test_warden_choice(game: Game) -> void:
	game.offers.clear()
	game.offers.add_relic(game.content.dungeon.acts[0].boss)
	game.choices.show_next()
	await _frames(2)
	var shown := game.perk_panel.get_offered()
	check(game.perk_panel.visible and shown.size() == 3 and shown.filter(func(p: PerkDef) -> bool: return p.twist).size() == 1, "a warden's relics: 3 cards, one that bends a rule")
	game.run.rerolls = 1
	game.choices._on_perk_reroll()
	var rerolled := game.perk_panel.get_offered()
	check(rerolled.filter(func(p: PerkDef) -> bool: return p.twist).size() == 1, "...a reroll keeps one")
	var at := -1
	for i in rerolled.size():
		if rerolled[i].twist:
			at = i
	game.run.banishes = 1
	game.choices._on_perk_banish(at)
	var after := game.perk_panel.get_offered()
	check(after.filter(func(p: PerkDef) -> bool: return p.twist).size() == 1 and not after.has(rerolled[at]), "...banishing it brings another one")
	game.perk_panel.chosen.emit(after[0])
	await _frames(2)
