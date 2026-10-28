class_name BossTests
extends TestSuite
## In the game: a boss floor from start to finish, and winning the run.


## A boss floor from start to finish: arena, spikes, phases, skills, death, stairs and relic.
func _test_boss_fight(game: Game) -> void:
	game.world.run_bosses.clear()  # the acts' main bosses (the others are tested in _test_variety)
	game.depth = 3
	game._enter_floor()
	await _frames(5)
	var world: World = game.world
	var player: Player = game.player
	var arena := world.arena
	check(arena != null and arena.boss != null, "floor 3 is a boss arena")
	if arena == null:
		return
	var boss := arena.boss
	check(boss.is_boss() and boss.dormant, "the boss sleeps until you come in")
	check(world.monster_count() == 1, "only the boss on its floor")
	check(world.get_node("Entities").get_children().all(func(n: Node) -> bool: return not n is Stairs), "no stairs before the boss dies")
	await _frames(30)
	check(boss.target == null, "a dormant boss ignores the player")

	player.global_position = world.map.cell_to_world(world.map.boss_room.get_center() + Vector2i(0, 4))
	await _frames(5)
	check(arena.is_started and arena.is_closed(), "walking in starts the fight and closes the exits")
	check(not boss.dormant and boss.target == player, "the boss wakes up")
	check(game.hud.get_node("%BossBar").visible, "boss health bar shown")
	check(not arena.get_gate_cells().is_empty(), "the arena has spikes on its exits")

	# Slain mid-fight with a Phoenix Feather: the Threshold, then back to the same fight.
	var feather := _perk("phoenix_feather")
	player.perks.add(feather)
	var boss_hp := boss.hp
	var in_blast := player.global_position.distance_to(boss.global_position) <= 110.0 + boss.radius
	_killing_blow(player, boss)
	check(await _until_trial(game), "slain by the boss with a second life: the Threshold")
	check(not game.hud.get_node("%BossBar").visible, "no boss bar in the limbo")
	check(boss.hp == boss_hp and not world.is_inside_tree(), "the boss waits on its floor, untouched")
	check(await _win_trial(game), "the trial won")
	check(world.is_boss_fight() and arena.is_closed() and boss.target == player and not boss.is_dead, "back to the same boss fight, the exits still shut")
	check(boss.hp == boss_hp or (in_blast and boss.hp < boss_hp), "the boss' Health as it was (but for the blast)")
	check(player.hp == roundi(player.get_max_hp() * (feather.passives[0] as CheatDeathPassive).boss_fight_heal_ratio), "back at a quarter of Health in a boss fight")
	check(game.hud.get_node("%BossBar").visible, "the boss bar is back")
	player.hp = player.get_max_hp()

	# A fall in a boss fight: no Deeps (the boss must not be frozen), the old rule: the hero climbs
	# back out where he stood, hurt.
	check(not game.abyss.can_take(player), "no Deeps on a boss floor")
	var boss_skills_saved := boss.skills.skills.duplicate()
	var none: Array[SkillDef] = []
	boss.skills.set_skills(none)
	var safe := await _walk_into_hole(world, player, 2)
	var hp_before_fall := player.hp
	var scales := {}
	var vanished := 0.0
	for frame in int(Actor.FALL_TIME * 60.0) + 6:
		boss._attack_cooldown = 1.0  # (its blows would blur the fall's cost)
		if player.is_falling:
			scales[player.rig.scale] = true
			vanished = maxf(vanished, player.rig.look.vanished())
		await _frames(1)
	# The fall draws the body into the dark on its own pixels (an implosion), never shrunk nor
	# spun (decision 0007, task 424; it shrank to nothing and spun until 28 Oct 2026).
	check(scales.keys() == [Vector2.ONE] and vanished > 0.5, "a fall: the body drawn away on its own pixels, never shrunk (scales %s, %.2f gone)" % [scales.keys(), vanished])
	check(player.rig.look.vanished() == 0.0 and player.rig.rotation == 0.0, "climbed out: the body whole again")
	check(not game.abyss.is_open() and player.world == world, "the boss floor stays: no Deeps")
	check(not player.is_falling and player.global_position.distance_to(safe) < 24.0, "the hero climbs out where they stood")
	check(player.hp < hp_before_fall and player.rig.scale == Vector2.ONE, "falling hurts")
	check(hp_before_fall - player.hp <= roundi(player.get_max_hp() * 0.15) + 1, "a fall's cost there: up to 15%% of max Health (%d)" % (hp_before_fall - player.hp))
	boss.skills.set_skills(boss_skills_saved)
	_fill_holes()
	player.hp = player.get_max_hp()

	# Phase 2 at half HP: new skills.
	var def := boss.def as BossDef
	var hurt := HitInfo.new()
	hurt.amount = Combat.hit_for(boss.hp - roundi(boss.get_max_hp() * def.phases[0].hp_ratio) + 1, boss.get_stats().defense)
	boss.take_hit(hurt)
	check(boss.skills.skills == def.phases[0].skills, "below %d%% HP the boss enters its next phase" % roundi(def.phases[0].hp_ratio * 100))
	check(boss.invincible, "it roars into the phase: untouchable for a moment")
	check(boss.cooldown_speed > 1.0, "its skills come back sooner")
	await _frames(int(def.phase_roar_time * 60.0) + 6)
	check(not boss.invincible, "then the fight goes on")

	# Telegraphed skill: cast, then a ring of projectiles.
	world.get_node("Projectiles").get_children().map(func(n: Node) -> void: n.queue_free())
	await _frames(2)
	var phase_skills: Array[SkillDef] = []
	boss.skills.set_skills(phase_skills)  # it may have used them on its own meanwhile: fresh cooldowns
	boss.skills.set_skills(def.phases[0].skills)
	boss.casting_index = 0
	boss.get_node("StateMachine").transition_to(&"Cast")
	await _frames(2)
	check(boss.telegraph > 0.0, "the boss telegraphs its skill")
	await _frames(int(boss.skills.skills[0].cast_time * 60.0) + 6)
	check(world.get_node("Projectiles").get_child_count() >= 8, "the skill fires a ring of projectiles")

	var summon := SummonEffect.new()
	summon.monsters = [load("res://data/monsters/slime.tres")]
	summon.count = 2
	var count_before := world.monster_count()
	summon.apply(boss, Vector2.RIGHT)
	# The first at once, the next one a frame later (one heavy instantiation a frame at most).
	check(world.monster_count() == count_before + 1, "the first summon appears at once")
	await _frames(2)
	check(world.monster_count() == count_before + 2, "summons appear, one a frame")
	# A boss's adds feed no "on kill" heal (Vampirism, the Blood family), summoned or not.
	check(world.is_boss_fight(), "a boss fight is on")
	var stray := world.spawn_monster(load("res://data/monsters/slime.tres"), boss.global_position + Vector2(0, 70))
	stray.dormant = true
	var feast := HealOnKillPassive.new()
	var level := PerkSet.Entry.new()
	level.stacks = 3
	var bloodlust := BloodlustPassive.new()
	var wounded := maxi(1, int(player.get_max_hp() / 4.0))
	player.hp = wounded
	player.sustain = SustainMeter.new()
	for monster in world.get_hostiles(player.faction):
		if monster != boss:
			feast.on_kill(player, monster, level)
			bloodlust.on_kill(player, monster, level)
	check(player.hp == wounded, "the boss's adds heal nothing (%d -> %d)" % [wounded, player.hp])
	feast.on_kill(player, boss, level)
	check(player.hp > wounded, "the boss itself does")
	player.hp = player.get_max_hp()
	for monster in world.get_hostiles(player.faction):
		if monster != boss:
			monster.die(null)

	# Standing still and hitting it over and over: it throws the hero off.
	world.get_node("Projectiles").get_children().map(func(n: Node) -> void: n.queue_free())
	await _frames(2)
	# On the arena's open side of the boss (not against a wall, where nothing can throw you).
	var open_side := boss.global_position.direction_to(world.map.cell_to_world(world.map.stairs_cell))
	if open_side == Vector2.ZERO:
		open_side = Vector2.DOWN
	player.global_position = boss.global_position + open_side * (boss.radius + 30.0)
	player._invulnerable_time = 0.0
	var close := player.global_position.distance_to(boss.global_position)
	boss.brain.shockwave_cooldown = 0.0  # the roar's own shockwave a moment ago
	# Nothing else may touch the hero meanwhile (its hit frames would make the blast miss).
	var boss_skills := boss.skills.skills.duplicate()
	var no_skills: Array[SkillDef] = []
	boss.skills.set_skills(no_skills)
	boss._attack_cooldown = 1.0
	for i in boss.brain.shockwave_after:
		var poke := HitInfo.new()
		poke.amount = 1
		poke.source = player
		boss.take_hit(poke)
	check(boss.brain.shockwave_cooldown > 0.0, "too many hits in a row: it answers with a shockwave")
	var stood := player.global_position
	var boss_at := boss.global_position
	for frame in 50:
		player._invulnerable_time = 0.0  # its claws may have just hit the hero
		boss._attack_cooldown = 1.0  # and no more claws: their hit would make the blast miss
		if frame < 30:
			boss.global_position = boss_at  # not walking off (or dashing) before the blast
		await _frames(1)
	check(player.global_position.distance_to(stood) > 80.0 and player.global_position.distance_to(boss.global_position) > close, "the shockwave throws the hero off (%d px)" % roundi(player.global_position.distance_to(stood)))
	boss.skills.set_skills(boss_skills)

	# The last phase: fiercer skills, faster still.
	var speed_before := boss.cooldown_speed
	var hurt_more := HitInfo.new()
	hurt_more.amount = Combat.hit_for(boss.hp - roundi(boss.get_max_hp() * def.phases[1].hp_ratio) + 1, boss.get_stats().defense)
	boss.take_hit(hurt_more)
	check(boss.skills.skills == def.phases[1].skills and boss.cooldown_speed > speed_before, "a third of its HP left: its last phase")
	# Its roar (a hit stop may slow it down a little: the arena changing, the hero falling...).
	for i in int(def.phase_roar_time * 60.0) * 3:
		if not boss.invincible:
			break
		await _frames(1)

	# Kill it: exits open, stairs appear, a relic is offered.
	var finish := HitInfo.new()
	finish.amount = 999999
	finish.source = player
	boss.take_hit(finish)
	check(boss.is_dead, "the boss can die")
	await _frames(5)
	check(arena.is_defeated and not arena.is_closed(), "the exits open again")
	check(world.get_node("Entities").get_children().any(func(n: Node) -> bool: return n is Stairs), "stairs appear after the boss")
	# The relic comes up by itself after a moment; the boss' XP may level the hero up too, but
	# those choices wait behind the perk button (a level up never opens anything by itself).
	var relics: Array[PerkDef] = []
	var level_ups_shown := 0
	for attempt in 10:
		await get_tree().create_timer(game.RELIC_DELAY * 0.5, true).timeout
		if not game.perk_panel.visible:
			continue
		var offered: Array[PerkDef] = game.perk_panel.get_offered()
		# A relic offer leads with relics (filled with common perks once the hero holds them all,
		# which the earlier suites may have done: pacts, the Threshold).
		if not offered.is_empty() and offered[0].rarity == PerkDef.Rarity.RARE:
			relics = offered
			break
		level_ups_shown += 1
		game.perk_panel.choose(0)
	check(not relics.is_empty(), "the boss offers relics after the victory, by itself")
	check(level_ups_shown == 0, "no level up opened by itself before the relic")
	if relics.is_empty():
		return
	var stacks_before := player.perks.stacks_of(relics[0])
	var waiting := game.pending_offers()  # (the boss' level ups, if its XP brought any)
	game.perk_panel.choose(0)
	await _frames(2)
	check(player.perks.stacks_of(relics[0]) == stacks_before + 1 and not get_tree().paused and not game.perk_panel.visible, "relic taken, game resumed: the level ups don't follow by themselves")
	check(game.pending_offers() == waiting, "they still wait behind the perk button (%d)" % game.pending_offers())

	# The last act's boss wins the run; you may keep going (endless).
	game.depth = CONTENT.dungeon.total_floors()
	game._enter_floor()
	await _frames(5)
	check(world.arena != null and world.arena.boss.def == CONTENT.dungeon.acts.back().boss, "the last floor: the final boss")
	player.global_position = world.map.cell_to_world(world.map.boss_room.get_center() + Vector2i(0, 4))
	await _frames(5)
	var final_hit := HitInfo.new()
	final_hit.amount = 999999
	world.arena.boss.take_hit(final_hit)
	await _frames(3)
	check(game.has_won, "the win counts at once (taking the stairs right away can't lose it)")
	for attempt in 10:
		await get_tree().create_timer(game.RELIC_DELAY * 0.5, true).timeout
		if game.game_over_panel.visible:
			break
		if game.shop_panel.visible:
			game.shop_panel.close()
		if game.encounter_panel.visible:
			game.encounter_panel.close()
		if game.perk_panel.visible:
			game.perk_panel.choose(0)
	check(game.has_won and game.game_over_panel.visible and game.game_over_panel.get_node("%ContinueButton").visible, "beating the final boss wins the run")
	check(Profile.victories == 1 and Profile.souls > 0, "a victory is recorded with its souls")
	var won_at := game.run.finish_time
	check(won_at > 0.0 and game.run.splits.size() == game.depth and is_equal_approx(game.run.splits.back(), won_at), "the win's time is the last split")
	# (Records are kept in whole milliseconds, Profile.record_time(): a run's time is in 60ths.)
	check(roundi(Profile.best_time(game.run.record_key()) * 1000.0) == roundi(won_at * 1000.0), "a first win is the record (%.3f s for %.3f s)" % [Profile.best_time(game.run.record_key()), won_at])
	var summary := game.game_over_panel.shown_text()
	check(summary.contains("Time\n" + TimeText.of(won_at)) and summary.contains("New record!"), "the victory screen gives the time: %s" % summary)
	(game.game_over_panel.get_node("%ContinueButton") as Button).pressed.emit()
	await _frames(3)
	check(not game.game_over_panel.visible, "keep going: endless mode")
	if game.perk_panel.visible:
		game.perk_panel.choose(0)
	await _frames(3)
	check(not get_tree().paused, "the game resumes after the victory")
	await _frames(30)
	check(game.run.run_time() == won_at and (game.hud.get_node("%TimerLabel") as Label).text == TimeText.of(won_at), "endless mode: the win's time stays on screen")
