class_name FinaleTests
extends TestSuite
## In the game: the bottom of the Well (FinaleDef). The gate (no win: the last act's boss ends
## the run as before; a won profile: it leads down instead), saving between the last act's boss
## and the bottom, Tôma's fall and the Maw rising (no relic), the Maw's jaw (hits glance off
## while closed, land while open; it draws the hero in and bites), the win, the ending chosen
## (kept in the profile, its achievement), and a run picked up before the choice.


func _test_finale(game: Game) -> void:
	var finale := CONTENT.dungeon.finale
	check(finale != null and finale.boss != null and finale.boss.next_boss != null and finale.endings.size() == 2, "the bottom of the Well has its two forms and its two endings")
	if finale == null or finale.boss == null:
		return
	var total := CONTENT.dungeon.total_floors()

	# No win yet: the bottom is closed, the last act's boss wins the run (the first ending).
	Profile.reset()
	game.start_run()
	await _frames(3)
	check(not game.run.finale_open, "no win yet: the way to the bottom of the Well is closed")
	game.depth = total
	game._enter_floor()
	await _frames(3)
	check(not game.run.leads_to_finale() and game.world.next_routes.all(func(r: FloorRoute) -> bool: return r.biome != finale.biome), "the last act's arena leads to no bottom before a win")
	check(game.run.wins_with(game.world.arena.boss.def as BossDef), "its boss still wins the run (the first ending)")

	# A won profile (a Pilgrim win counts): the last act's boss leads down instead.
	Profile.wins = { "easy": 1 }
	game.start_run()
	await _frames(3)
	check(game.run.finale_open, "a won profile (even on Pilgrim): the way down to the bottom opens")
	var finish_floor := await _slay_last_act_boss(game)
	check(finish_floor, "the last act's boss falls")
	check(not game.has_won and game.run.finish_time < 0.0, "with the bottom open, the last act's boss no longer ends the run")
	check(game.world.next_routes.size() == 1 and game.world.next_routes[0].biome == finale.biome, "its arena opens one way down: to the bottom")
	var stairs := game.world.get_node("Entities").get_children().filter(func(n: Node) -> bool: return n is Stairs)
	check(stairs.size() == 1 and (stairs[0] as Stairs).route != null and (stairs[0] as Stairs).route.biome == finale.biome, "its stairs are signed with the bottom's name")
	check(await _relic_offered(game), "the last act's boss still offers its relic")

	# Saved between the last act's boss and the bottom: picked up in his cleared arena, its one
	# way down to the bottom.
	game._save_run()
	var saved := RunSave.read()
	check(bool(saved.get("floor", {}).get("arena_cleared", false)) and not bool(saved.get("boss_slain", false)) and bool(saved.get("finale_open", false)) and not bool(saved.get("finale", true)), "the save knows the boss fell and the bottom waits")
	game.resume_run(saved)
	await _frames(5)
	_close_offers(game)
	check(not game.run.finale and game.depth == total and game.world.arena.is_defeated and game.world.arena.boss == null, "a run saved there picks up in the cleared arena, its warden gone")
	var down := game.world.get_node("Entities").get_children().filter(func(n: Node) -> bool: return n is Stairs)
	check(down.size() == 1 and (down[0] as Stairs).route != null and (down[0] as Stairs).route.biome == finale.biome, "its stairs still lead to the bottom")
	game.world.stairs_reached.emit(0)
	for i in 120:
		await _frames(1)
		if game.world.finale:
			break
	_close_offers(game)
	check(game.run.finale and game.depth == total and game.world.finale == finale, "down them: the bottom of the Well, at the same depth")
	check(game.world.arena != null and game.world.arena.boss.def == finale.boss and game.world.arena.boss.dormant, "Tôma kneels in its arena, asleep")
	check(game.run.place_name(CONTENT) == finale.title, "the run says where it is")

	# Taking the stairs there works too (and its split is the last act's floor's).
	game.run.finale = false
	game.depth = total
	game._enter_floor()
	await _frames(3)
	await _slay_last_act_boss(game)
	_close_offers(game)
	game.world.stairs_reached.emit(0)
	for i in 60:
		await _frames(1)
		if not game._transitioning:
			break
	_close_offers(game)
	check(game.run.finale and game.depth == total and game.world.finale == finale and game.world.arena.boss.def == finale.boss, "the stairs lead down to the bottom, at the same depth")
	check(game.run.splits.size() == total and game.run.splits[total - 1] > 0.0, "the last act's floor gets its split on the way down")

	# The fight: Tôma wakes.
	var world: World = game.world
	var arena := world.arena
	var player: Player = game.player
	player.invincible = true
	var toma := arena.boss
	check(toma.global_position.y > world.map.cell_to_world(world.map.boss_room.get_center()).y, "Tôma waits below the middle (the Maw rises behind him)")
	player.global_position = world.map.cell_to_world(world.map.boss_room.get_center() + Vector2i(0, 6))
	await _frames(3)
	check(arena.is_started and not toma.dormant and toma.rig.body.animation == &"intro", "walking in wakes Tôma: he opens his eyes and draws (intro)")
	check(toma.pick_skill(150.0) < 0 and not toma.can_attack() and toma.casting_index < 0, "he waits his waking out: no blow, no skill meanwhile")
	check(game.hud.get_node("%BossBar").visible and (game.hud.get_node("%BossName") as Label).text == finale.boss.display_name, "his name on the boss bar")
	check(toma.skills.skills.any(func(s: SkillDef) -> bool: return s.effects.any(func(e: Effect) -> bool: return e is GroundStrikeEffect)), "he turns the lantern's light on the hero (a strike on the ground)")

	# His lantern: a warning on the ground where the hero stands, then the strike.
	var lantern: SkillDef = load("res://data/skills/boss/toma_lantern.tres")
	var max_hp := _sturdy(player)
	var hp_before := player.hp
	var spot := player.global_position
	lantern.effects[0].apply(toma, Vector2.DOWN)
	var warnings := world.get_node("Effects").get_children().filter(func(n: Node) -> bool: return n is GroundStrike)
	check(warnings.size() == 1 and (warnings[0] as GroundStrike).global_position.distance_to(spot) < 1.0, "the lantern marks the ground under the hero")
	toma._attack_cooldown = 5.0
	for i in 70:
		toma._attack_cooldown = 5.0
		toma.casting_index = -1
		player.global_position = spot
		player._invulnerable_time = 0.0
		await _frames(1)
	check(player.hp < hp_before, "standing in it hurts")
	check(not player.is_dead, "(the hero stands: one strike, a crit or not, can't end the test's run)")
	_steady(player, max_hp)

	# Tôma falls: no relic, the arena stays shut, the Maw rises and takes his body. The music
	# (heard for this part only: the tests run silent) is his, then silence, then the Maw's.
	Sfx.enabled = true
	game.play_floor_mood()
	var toma_music := Soundtrack.boss_music(toma.def as BossDef, null, Sfx.bank)
	check(toma_music != null and Sfx.current_music() == toma_music, "music: Tôma fights to his own theme")
	var finish := HitInfo.new()
	finish.amount = 999999
	finish.source = player
	toma.take_hit(finish)
	await _frames(3)
	check(Sfx.current_music() == null, "music: it falls silent as he falls (the rise)")
	check(toma.is_dead and is_instance_valid(toma) and toma.rig.body.animation == &"dead", "Tôma falls to his knees (his body stays)")
	check(arena.is_rising and not arena.is_defeated and arena.is_closed() and not game.has_won, "his fall doesn't end the fight: the arena stays shut")
	check(world.get_node("Entities").get_children().all(func(n: Node) -> bool: return not n is Stairs), "no stairs")
	# Polled, not a fixed wait: a level-up or an offer opening on the way pauses the game for a
	# few frames.
	for i in ceili((finale.boss.rise_time + 4.0) * 60.0):
		_close_offers(game)
		await _frames(1)
		if i >= ceili((finale.boss.rise_time + 0.6) * 60.0) and arena.boss != toma and is_instance_valid(arena.boss) and not arena.boss.dormant:
			break
	_close_offers(game)
	var maw := arena.boss
	var risen := maw != toma and maw.def == finale.boss.next_boss and not maw.dormant and maw.target == player
	check(risen, "the Maw rises in the same arena and takes the fight (hero dead: %s, boss %s, asleep: %s)" % [player.is_dead, maw.def.id, maw.dormant])
	check(not is_instance_valid(toma) or toma.is_queued_for_deletion(), "it takes Tôma's body")
	var maw_music := Soundtrack.boss_music(maw.def as BossDef, null, Sfx.bank)
	check(maw_music != null and maw_music != toma_music and Sfx.current_music() == maw_music, "music: risen, the Maw's own theme takes over")
	Sfx.stop_all()
	Sfx.enabled = false
	check(game.offers.to_data(false).all(func(o: Dictionary) -> bool: return int(o.rarity) != PerkDef.Rarity.RARE) and not game.perk_panel.visible, "no relic between the two forms (Tôma's XP may level the hero up)")
	check((game.hud.get_node("%BossName") as Label).text == finale.boss.next_boss.display_name, "the boss bar passes to the Maw")
	check(maw.global_position.y < world.map.cell_to_world(world.map.boss_room.get_center()).y - world.map.tile_size * 4, "it rises at the top of the arena")
	# The false sun: lit from within (over the floor's light and the wall mist), its halo behind
	# its mask a step up holy's ramp; casting, it warns by a red rim and keeps its gold.
	var halos := maw.get_children().filter(func(n: Node) -> bool: return n is GlowHalo)
	check(maw.rig.z_index == PlateauMist.Z + 1 and not maw.rig.z_as_relative, "the Maw is lit from within: drawn over the floor's light and the wall mist")
	check(halos.size() == 1 and (halos[0] as GlowHalo).bright and (halos[0] as Node).get_index() < maw.rig.get_index() and (halos[0] as GlowHalo).size >= 80.0, "a bright halo behind its mask, wider than the mask")
	maw.dormant = true  # (its own casts would set the telegraph meanwhile)
	maw.casting_index = -1
	maw.telegraph = 0.0
	await _wait(game, 0.05)
	var own_rim := maw.rig.look.outline
	maw.telegraph = 0.8
	await _wait(game, 0.05)
	var tint := maw._body_modulate()
	check(maw.rig.look.outline == Monster.WARNING_RIM and is_equal_approx(tint.g, tint.r) and is_equal_approx(tint.b, tint.r), "casting, the Maw warns by a red rim and keeps its colors (no red tint dulling the gold)")
	maw.telegraph = 0.0
	await _wait(game, 0.05)
	check(maw.rig.look.outline == own_rim and own_rim != Monster.WARNING_RIM, "the cast over, the red rim goes (its own rim back: %s)" % own_rim)
	maw.dormant = false
	# Drawn over every actor, it never hides the hero: in front of its lower body he is drawn
	# over it; away from it, among the actors again.
	var jaw0 := maw.def.traits[0] as WeakPointTrait
	player.global_position = jaw0.mouth_of(maw) + Vector2(60, 10)
	await _wait(game, 0.05)
	check(not player.z_as_relative and player.z_index > maw.rig.z_index, "in front of the Maw's lower body, the hero is drawn over it")
	player.global_position = jaw0.mouth_of(maw) + Vector2(0, 260)
	await _wait(game, 0.05)
	check(player.z_as_relative and player.z_index == 0, "away from it, the hero is among the actors again")

	# The jaw: closed, blows glance off; open, they land.
	var jaw := maw.def.traits[0] as WeakPointTrait
	check(jaw != null and jaw.stage_of(maw) == WeakPointTrait.Stage.CLOSED, "its jaw starts closed")
	var maw_hp := maw.hp
	var poke := HitInfo.new()
	poke.amount = 60
	poke.source = player
	maw.take_hit(poke)
	check(maw.hp == maw_hp and maw.brain.hit_streak == 0, "closed, a blow glances off whole (no damage, no streak toward a shockwave)")
	check(world.get_node("Effects").get_children().any(func(n: Node) -> bool: return n is FloatingText), "and says so over it")
	var burn := OnHitStatus.new()
	burn.burn_damage = 5
	var burning := HitInfo.new()
	burning.amount = 20
	burning.source = player
	burning.status = burn
	maw.take_hit(burning)
	check(maw.statuses.is_empty(), "no status catches on the closed jaw")
	check(maw.pick_skill(200.0) >= 0 or maw.skills.skills.all(func(s: SkillDef) -> bool: return not maw.skills.is_ready(maw.skills.skills.find(s))), "closed, it may use its skills")
	maw.casting_index = -1
	jaw.open_now(maw)
	check(not jaw.is_open(maw), "opening takes a moment (blows still glance off)")
	await _wait(game, jaw.opening_time + 0.1)
	check(jaw.is_open(maw) and maw.rig.body.animation == jaw.open_pose, "then it holds its jaw open, Tôma inside")
	check(maw.pick_skill(200.0) < 0, "open, it uses no skill")
	maw.take_hit(poke)
	check(maw.hp < maw_hp, "open, the blow lands")
	# It draws the hero in, and bites him close.
	var mouth := jaw.mouth_of(maw)
	player.global_position = mouth + Vector2(0, 240)
	var far := player.global_position.distance_to(mouth)
	await _frames(20)
	check(player.global_position.distance_to(mouth) < far - 5.0, "open, it draws the hero toward its mouth")
	max_hp = _sturdy(player)
	hp_before = player.hp
	player.global_position = mouth + Vector2(0, 40)
	for i in int((jaw.bite_windup + 0.3) * 60.0):
		player.global_position = mouth + Vector2(0, 40)
		player._invulnerable_time = 0.0
		await _frames(1)
	check(player.hp < hp_before, "too close to the open mouth: it bites")
	check(game.run.marks.has("bitten"), "the run remembers it was bitten (the Maw's deed asks for a run never bitten)")
	check(not player.is_dead, "(the hero stands after the bite)")
	_steady(player, max_hp)
	player.global_position = mouth + Vector2(0, 260)
	await _wait(game, jaw.time_left(maw) + jaw.closing_time + 0.2)
	check(jaw.stage_of(maw) == WeakPointTrait.Stage.CLOSED and maw.rig.body.animation != jaw.open_pose, "after its window the jaw shuts again")
	check(jaw.time_left(maw) <= jaw.closed_times[0] + 0.01, "for its closed time")

	# The Maw falls: the run is won, then an ending is chosen.
	var wins_before := Profile.total_wins()
	jaw.open_now(maw)
	await _wait(game, jaw.opening_time + 0.1)
	var lying := get_tree().get_nodes_in_group(&"pickups")
	maw.take_hit(finish)
	await _frames(3)
	check(maw.is_dead and game.has_won and game.run.finish_time > 0.0, "the Maw's fall wins the run")
	# Its loot lands in front of it, past its jaw and its pool, where the hero can walk to it.
	var dropped := get_tree().get_nodes_in_group(&"pickups").filter(func(n: Node) -> bool: return not lying.has(n))
	var pool_edge := maw.global_position.y + jaw.pool_offset.y + jaw.pool_size.y * 0.5
	var in_front := dropped.filter(func(n: Node2D) -> bool: return n.global_position.y > pool_edge and n.global_position.y > jaw.mouth_of(maw).y + jaw.bite_radius * 0.5 and not world.find_path(player.global_position, n.global_position).is_empty() and world.is_solid_ground(n.global_position))
	check(not dropped.is_empty() and in_front.size() == dropped.size(), "the Maw's loot lands in front of it, reachable (%d of %d)" % [in_front.size(), dropped.size()])
	check(player.z_as_relative and player.z_index == 0, "fallen, the Maw leaves the hero among the actors")
	check(not Narrative.is_deed_done(maw.def as BossDef, (maw.def as BossDef).chronicle.deeds()[0]), "bitten this run: not its deed")
	check(Profile.total_wins() == wins_before + 1 and game.run.splits.size() == total + 1, "the win counts at once, the bottom with its own split")
	check(game.run.ending_due, "an ending is due")
	var maw_def := maw.def as BossDef  # (the body goes with its floor)
	game._save_run()
	var won_save := RunSave.read()
	check(bool(won_save.get("ending_due", false)), "a save before the choice keeps it due")
	await _wait(game, Game.ENDING_DELAY + 0.3)
	var panel := game.menus.ending
	check(panel.visible and get_tree().paused and not game.game_over_panel.visible, "the choice of an ending comes up, the game paused")
	check(panel.buttons().size() == 2 and panel.buttons()[0].text == finale.endings[0].choice and panel.buttons()[1].text == finale.endings[1].choice, "two endings, by touch: %s / %s" % [finale.endings[0].choice, finale.endings[1].choice])
	game._back()
	check(panel.visible, "Back doesn't dodge the choice")
	panel.buttons()[1].pressed.emit()
	await _frames(3)
	var ending := finale.endings[1]
	check(Profile.ending == ending.id, "the ending chosen is kept in the profile")
	# Taking his place: the hero becomes the Nameless Keeper, waiting at the bottom of the next runs.
	var weapon_id := String((player.get_weapon() as EquipmentDef).base_item.id if (player.get_weapon() as EquipmentDef).is_rolled() else player.get_weapon().id)
	check(ending.keeper_change == EndingDef.KeeperChange.TAKE and KeeperSnapshot.is_valid(Profile.keeper) and str(Profile.keeper.gear[0].id) == weapon_id and int(Profile.keeper.level) == player.level, "taking his place: this hero is kept as the Nameless Keeper (his %s, level %d)" % [weapon_id, player.level])
	check(Profile.keepers_freed.is_empty(), "(no Keeper was beaten: Tôma and the Maw were)")
	check(Profile.stat_value(ending.stat) == 1 and Profile.is_achieved(&"he_who_keeps_watch"), "its achievement is earned")
	check(not Profile.is_achieved(&"the_last_knell"), "not the other one")
	var shown := game.game_over_panel.shown_text()
	check(game.game_over_panel.visible and shown.contains(ending.title) and shown.contains(ending.text.get_slice("\n", 0)), "the victory screen tells that ending")
	check(not game.run.ending_due, "no ending due any more")
	var souls_shown := (game.game_over_panel.get_node("%SoulsEarned") as Label).text
	check(game.run.souls_awarded > 0 and souls_shown == "+%d souls" % game.run.souls_awarded, "the victory screen gives the run's souls (%s)" % souls_shown)

	# A run won at the bottom and picked up before the choice: the choice first.
	game.resume_run(won_save)
	await _frames(5)
	check(game.run.has_won and game.game_over_panel.visible and not game.menus.ending.visible and get_tree().paused, "a profile-committed ending is recovered directly even when the old run file still says a choice is due")
	check(game.run.last_boss == maw_def, "the last boss slain comes back with the run (%s)" % [game.run.last_boss])
	check(Profile.ending == ending.id and Profile.village_memorials.size() == 1 and Profile.stat_value(ending.stat) == 1,
		"an old run save cannot change a committed ending or duplicate its memorial and statistic")
	# Exercise the other ending as a distinct completed expedition. Replaying the SAME old
	# file is now an idempotent recovery, not a second victory with a different choice.
	var other_win := won_save.duplicate(true)
	other_win["journey_id"] = "test/independent-bell-ending"
	game.resume_run(other_win)
	await _frames(5)
	game.menus.ending.choose(0)
	await _frames(3)
	check(Profile.ending == finale.endings[0].id and Profile.is_achieved(&"the_last_knell"), "the other ending, its achievement")
	check(Profile.keeper.is_empty(), "ringing the bell frees the Nameless Keeper waiting: Tôma and the Maw wait again")
	check(game.game_over_panel.visible, "then the victory screen")
	var souls_again := (game.game_over_panel.get_node("%SoulsEarned") as Label).text
	check(souls_again == souls_shown, "with the souls the run gave at its win, not +0 (%s, at the win %s)" % [souls_again, souls_shown])
	var offers_before := game.pending_offers() + (1 if game.perk_panel.visible else 0)
	(game.game_over_panel.get_node("%ContinueButton") as Button).pressed.emit()
	await _frames(3)
	var relic_offered := maw_def.relic_choices <= 0 or game.pending_offers() + (1 if game.perk_panel.visible else 0) > offers_before
	check(relic_offered, "keep going after a resumed win: the last boss's relic is offered")
	_close_offers(game)
	check(not get_tree().paused and not game.run.finale and game.depth == total + 1, "keep going: endless mode, past the bottom")
	# Leaving a won run for the title screen ends it: nothing is left for the Well to resume.
	game._save_run()
	var was_busy := Loader.busy
	Loader.busy = true  # (the scene change itself is not for this test)
	game.game_over_panel.title_requested.emit()
	Loader.busy = was_busy
	check(not RunSave.exists(), "the Title button erases the won run, as Return to village does")
	Profile.reset()


## The story at the bottom (Boss stories on, as players have them): Tôma's meeting plays with
## his waking and names him (the reveal), the Maw is met once risen, each says its last words,
## their deeds, their meeting keys apart from the last act's arena at the same depth, and their
## past on the last act's floors.
func _test_finale_story(game: Game) -> void:
	var finale := CONTENT.dungeon.finale
	var narrative := CONTENT.narrative
	var stories := Settings.boss_stories
	Profile.reset()
	Profile.wins = { "easy": 1 }
	Settings.boss_stories = Settings.STORIES_FULL
	game.start_run()
	await _frames(3)
	var toma_def := finale.boss
	var maw_def := toma_def.next_boss
	var total := CONTENT.dungeon.total_floors()
	check(not narrative.keeper_reveal.is_met(), "a won profile that never slew the Effigy: the keeper is not named yet")
	var ahead := FragmentPlacer.wardens_ahead(game.world, CONTENT.dungeon, total - 1)
	check(ahead.has(toma_def) and ahead.has(maw_def), "the last act's floors may hold Tôma's and the Maw's past (the bottom open)")
	check(not FragmentPlacer.wardens_ahead(game.world, CONTENT.dungeon, 1).has(toma_def), "not the first act's")
	check(Narrative.fragments_to_place(toma_def).is_empty(), "his journal waits for the reveal")
	var said := PackedStringArray()
	var listen := func(text: String, _color: Color) -> void: said.append(text)
	Events.message_logged.connect(listen)

	# The last act's arena is met at depth 12; the bottom, at the same depth, has its own key.
	game.run.met_floors.clear()
	game.depth = total
	game.run.finale = false
	game.run.meet_here()
	game.run.finale = true
	check(not game.run.has_met_here() and game.run.floor_key() == "%df" % total, "the bottom's meeting is kept apart from the last act's arena")
	game._enter_floor()
	await _frames(3)
	var arena := game.world.arena
	var toma := arena.boss
	var meeting := game.meeting
	var view := meeting.view
	game.player.invincible = true
	game.player.global_position = game.world.map.cell_to_world(game.world.map.boss_room.get_center() + Vector2i(0, 6))
	await _frames(3)
	check(meeting.is_playing() and toma.dormant and meeting.director.subject == toma, "walking in: Tôma's story plays first, over the frozen world")
	var woke := false
	var spoke := false
	for i in 600:
		woke = woke or (meeting.director.played_animation and toma.rig.body.animation == &"intro")
		spoke = spoke or view.speech_text() == "\"%s\"" % toma_def.chronicle.waking_lines[0].line
		if view.heading_text() == toma_def.chronicle.chapters[0].title:
			break
		await _frames(1)
	check(woke, "his waking (intro) plays in the scene")
	check(view.name_text() == toma_def.display_name and spoke, "his name, and his first words: \"%s\"" % toma_def.chronicle.waking_lines[0].line)
	check(view.heading_text() == toma_def.chronicle.chapters[0].title, "then the first chapter of his story")
	await _end_scene(meeting)
	check(not meeting.is_playing() and not toma.dormant and not get_tree().paused, "then he fights")
	check(narrative.keeper_reveal.is_met(), "met at the bottom of the Well, the keeper may be named")
	check(Narrative.next_chapter(toma_def) == toma_def.chronicle.chapter_by_id(&"your_master"), "his next meeting tells who he is, by his name")

	# He falls to a hero who never rolled: his deed, his last words; the Maw rises, and is met.
	var finish := HitInfo.new()
	finish.amount = 999999
	finish.source = game.player
	toma.take_hit(finish)
	await _frames(3)
	var stood: DeedCondition = toma_def.chronicle.deeds()[0]
	check(Narrative.is_deed_done(toma_def, stood), "slain without a single roll: his deed is done")
	var maw_met := false
	for i in int((toma_def.rise_time + 2.0) * 60.0):
		_close_offers(game)
		if meeting.is_playing() and meeting.director.subject == arena.boss and arena.boss != toma:
			maw_met = true
			break
		await _frames(1)
	var last_words := "\"%s\"" % Narrative.last_words(toma_def).line
	check(said.has(last_words), "his last words, on his banner and in the log: %s" % last_words)
	var maw := arena.boss
	check(maw_met and maw.def == maw_def and arena.is_rising and maw.dormant, "risen, the Maw is met in its turn (a scene of its own)")
	check(maw.rig.modulate.a > 0.9, "after its rise, which the scene doesn't cut short")
	for i in 300:
		if view.name_text() == maw_def.display_name:
			break
		await _frames(1)
	check(view.name_text() == maw_def.display_name, "its name in the scene")
	await _end_scene(meeting)
	check(not meeting.is_playing() and not maw.dormant and not arena.is_rising and maw.target == game.player, "then it fights")
	check(game.run.has_met_here(maw_def.id) and game.run.met_floors.has("%df/%s" % [total, maw_def.id]), "its meeting is kept, apart from Tôma's")

	# Struck while open, never bitten: its deed; its last words.
	var jaw := maw.def.traits[0] as WeakPointTrait
	jaw.open_now(maw)
	await _wait(game, jaw.opening_time + 0.1)
	said.clear()
	maw.take_hit(finish)
	await _wait(game, RunAnnouncer.LAST_WORDS_DELAY + 0.3)
	var never: DeedCondition = maw_def.chronicle.deeds()[0]
	check(not game.run.marks.has("bitten") and Narrative.is_deed_done(maw_def, never), "never bitten: the Maw's deed is done")
	check(said.has("\"%s\"" % Narrative.last_words(maw_def).line), "its last words: the sun sets")
	# A sentence on the banner comes smaller, on the screen; a name stays big.
	var banner := game.hud.get_node("%DepthBanner") as Label
	var longest := "\"%s\"" % tr(toma_def.chronicle.last_words[1].line)
	game.hud.show_banner(longest)
	var width := Fonts.MAIN.get_string_size(banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, banner.get_theme_font_size(&"font_size")).x
	var room := game.hud.banner_room(Fonts.TITLE)
	check(is_equal_approx(game.hud.banner_room(Fonts.HUGE), minf(banner.get_viewport_rect().size.x - 2.0 * Hud.BANNER_MARGIN, Hud.BANNER_WIDTH)), "a name at HUGE keeps between the stats and the map")
	var too_wide := Fonts.MAIN.get_string_size(banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fonts.HUGE).x > game.hud.banner_room(Fonts.HUGE)
	check((banner.get_theme_font_size(&"font_size") == Fonts.TITLE) == too_wide and width < room, "his longest last words fit the screen on the banner (%d of %d UI pixels)" % [roundi(width), roundi(room)])
	# The longest last words of all: wrapped on the screen, never past its edges.
	var longest_of_all := ""
	for file in DirAccess.get_files_at("res://data/story/chronicles"):
		var chronicle: Resource = load("res://data/story/chronicles".path_join(file.trim_suffix(".remap")))
		if chronicle == null or chronicle.get("last_words") == null:
			continue
		for words in chronicle.last_words:
			if tr(words.line).length() > longest_of_all.length():
				longest_of_all = tr(words.line)
	game.hud.show_banner("\"%s\"" % longest_of_all)
	await _frames(2)
	check(not longest_of_all.is_empty() and banner.get_viewport_rect().encloses(banner.get_global_rect()) and banner.get_line_count() <= 2, "the longest last words of all fit the screen on the banner, in two lines at most (%s)" % banner.get_global_rect())
	game.hud.show_banner(tr(maw_def.display_name))
	check(banner.get_theme_font_size(&"font_size") == Fonts.HUGE and _off_grid_texts(game.hud).is_empty(), "a name stays big, on the font's grid")
	await _wait(game, Game.ENDING_DELAY)
	check(game.menus.ending.visible, "then the choice of an ending, as without the story")
	if game.menus.ending.visible:
		game.menus.ending.choose(0)
		await _frames(3)
	(game.game_over_panel.get_node("%ContinueButton") as Button).pressed.emit()
	await _frames(3)
	_close_offers(game)
	Events.message_logged.disconnect(listen)
	Settings.boss_stories = stories
	Profile.reset()


## Hurries the scene, then ends it (two taps), and waits for it to be over.
func _end_scene(meeting: BossMeeting) -> void:
	for tap in 2:
		meeting.director.tap()
		await _frames(3)
	for i in 120:
		if not meeting.is_playing():
			return
		await _frames(1)


## The hero can be hurt, but no blow can kill him: Tôma's lantern (38 at the bottom, x1.75 on a
## crit) or the Maw's bite can be more than his Health, all the more with a relic that costs
## Health. Dead without a second life, the Maw rose with no one to wake against (asleep, its jaw
## never opening); with one, the floor waited out the Threshold. Either way the rest failed, now
## and then. Returns his own max Health, for _steady().
func _sturdy(player: Player) -> int:
	var own := player.base_stats.max_hp
	player.base_stats.max_hp = 100000
	player.invalidate_stats()
	player.hp = player.get_max_hp()
	player.invincible = false
	return own


## Back to his own max Health, untouchable again.
func _steady(player: Player, max_hp: int) -> void:
	player.invincible = true
	player.base_stats.max_hp = max_hp
	player.invalidate_stats()
	player.hp = player.get_max_hp()


## Puts the hero in the last act's arena (a fresh floor) and slays its boss. True once it fell.
func _slay_last_act_boss(game: Game) -> bool:
	game.depth = CONTENT.dungeon.total_floors()
	game.run.finale = false
	game._enter_floor()
	await _frames(3)
	var world := game.world
	if world.arena == null:
		return false
	game.player.invincible = true
	game.player.global_position = world.map.cell_to_world(world.map.boss_room.get_center() + Vector2i(0, 4))
	await _frames(3)
	var hit := HitInfo.new()
	hit.amount = 999999
	world.arena.boss.take_hit(hit)
	await _frames(4)
	return world.arena.is_defeated


## The boss' relic comes up by itself after a moment.
func _relic_offered(game: Game) -> bool:
	for attempt in 8:
		await get_tree().create_timer(Game.RELIC_DELAY * 0.5, true).timeout
		if game.perk_panel.visible:
			var offered := game.perk_panel.get_offered()
			var relic := not offered.is_empty() and offered[0].rarity == PerkDef.Rarity.RARE
			game.perk_panel.choose(0)
			await _frames(2)
			if relic:
				return true
	return false


## Waits `seconds` of play, taking any choice that comes up meanwhile (a relic).
func _wait(game: Game, seconds: float) -> void:
	for i in ceili(seconds * 60.0):
		_close_offers(game)
		await _frames(1)


## Takes whatever choice is on screen (a relic, a level up), so the test goes on.
func _close_offers(game: Game) -> void:
	for i in 4:
		if game.perk_panel.visible:
			game.perk_panel.choose(0)


## The Nameless Keeper (a hero who took the keeper's place waits in the profile): the bottom of
## the next run is his, not Tôma's; he carries that hero's bow, armor, skills and relics, a shade
## with a lantern, his name and who he was on the boss bar; he fights a sturdy hero without
## one-shotting him; his fall is the last (no Maw), the codex keeps it, the choice comes again and
## taking his place puts this hero there instead. The debug panel's way down to him.
func _test_nameless_keeper(game: Game) -> void:
	var finale := CONTENT.dungeon.finale
	var total := CONTENT.dungeon.total_floors()
	var fixtures := KeeperTests.new()
	add_child(fixtures)
	Profile.reset()
	Profile.wins = { "easy": 1 }
	var former := fixtures.hero("res://data/items/weapons/bow.tres", "res://data/items/tomes/tome_frost.tres")
	var snapshot := KeeperSnapshot.take(former, game.run, "Ash")
	var late_hp := former.get_max_hp()
	former.queue_free()
	Profile.take_keeper(snapshot)
	game.start_run()
	await _frames(3)
	check(game.run.meets_keeper() and game.run.keeper == Profile.keeper, "a run begun with a Nameless Keeper waiting goes down to him")
	game.depth = total
	game.run.finale = true
	game._enter_floor()
	await _frames(3)
	var world: World = game.world
	var arena := world.arena
	var keeper := arena.boss
	var player: Player = game.player
	check(keeper.def is NamelessKeeperDef and keeper.def.id == &"nameless_keeper" and keeper.dormant, "at the bottom of the Well, he waits instead of Tôma")
	check(keeper.rank == null and keeper.affixes.is_empty(), "as he was: never at a rare rank (no Legendary Keeper)")
	check(world.get_node("Entities").get_children().all(func(n: Node) -> bool: return not (n is Monster and ((n as Monster).def == finale.boss or (n as Monster).def == finale.boss.next_boss))), "neither Tôma nor the Maw is there")
	var bow := keeper.get_weapon() as EquipmentDef
	check(bow != null and bow.id == &"bow" and bow.rarity == ItemRarity.RARE and bow.runes.size() == 1, "he carries the hero's bow, its rarity and rune")
	var helm := keeper.equipment.get_item(EquipmentDef.Slot.HEAD)
	var mail := keeper.equipment.get_item(EquipmentDef.Slot.BODY)
	check(helm != null and helm.base_item != null and helm.base_item.id == &"iron_helm" and mail != null and mail.id == &"chain_mail", "and wears his helm and mail")
	var ids := snapshot.skills as Array
	var own := keeper.skills.skills.filter(func(s: SkillDef) -> bool: return s != null and ids.has(String(s.id)))
	check(own.size() >= 1 and own.all(func(s: SkillDef) -> bool: return s.cast_time > 0.0), "he uses the hero's skills, warned (%s)" % ", ".join(own.map(func(s: SkillDef) -> String: return String(s.id))))
	check(keeper.perks.stacks_of(_find_perk("ignite")) == finale.keeper.max_perk_stacks and keeper.perks.stacks_of(_find_perk("multishot")) == 1 and keeper.perks.stacks_of(_find_perk("strength")) == 0, "his relics that make sense on him: Ignite, Hydra's Quiver")
	check(keeper.rig.pallor >= 0.5 and keeper.rig.visual.get_node_or_null("Lantern") is Sprite2D and keeper.rig.carries_weapon and keeper.rig.helmet.visible, "a shade of the hero: darkened, faceless, his lantern in hand, his gear on him")
	check(keeper.get_children().any(func(n: Node) -> bool: return n is LightSource or n is GlowHalo), "his lantern lights the dark")
	# He wakes, named.
	player.invincible = true
	player.global_position = world.map.cell_to_world(world.map.boss_room.get_center() + Vector2i(0, 6))
	await _frames(3)
	check(arena.is_started and not keeper.dormant, "walking in wakes him")
	var bar_name := (game.hud.get_node("%BossName") as Label).text
	check(bar_name == "%s  (%s)" % [finale.keeper.display_name, "Ash"], "his name on the boss bar, and who he was (%s)" % bar_name)
	# He fights a sturdy hero: he hurts, never in one blow what a late hero has.
	var max_hp := _sturdy(player)
	var hits: Array[int] = []
	var last := [player.hp]
	var on_health := func(current: int, _maximum: int) -> void:
		if current < int(last[0]):
			hits.append(int(last[0]) - current)
		last[0] = current
	player.health_changed.connect(on_health)
	var cast := false
	var posed := false
	var trembled := false
	var shade := finale.keeper.traits[0] as ShadeTrait
	for i in 60 * 10:
		_close_offers(game)
		if player.global_position.distance_to(keeper.global_position) > 140.0:
			player.global_position = keeper.global_position + Vector2(0, 90)
		if keeper.casting_index >= 0:
			var animation := String(keeper.rig.body.animation)
			var lantern := keeper.rig.visual.get_node_or_null("Lantern") as Sprite2D
			posed = posed or (cast and animation.begins_with(String(finale.keeper.cast_pose)) and lantern != null and is_equal_approx(lantern.position.y, shade.cast_lantern_offset.y))
			trembled = trembled or (cast and animation.begins_with("attack"))
			cast = true
		await _frames(1)
	check(posed and not trembled, "casting, he holds his pose with his lantern raised, never his blow's trembling attack pose")
	player.health_changed.disconnect(on_health)
	var biggest: int = hits.max() if not hits.is_empty() else 0
	check(not hits.is_empty() and cast, "he fights: his bow and his skills hurt the hero (%d hits)" % hits.size())
	check(biggest * 3 < late_hp, "no blow of his takes a third of the hero he was (%d of %d Health)" % [biggest, late_hp])
	_steady(player, max_hp)
	# His fall is the last: no Maw, the run won, the choice again.
	var finish := HitInfo.new()
	finish.amount = 999999
	finish.source = player
	keeper.take_hit(finish)
	await _frames(3)
	check(keeper.is_dead and not arena.is_rising and game.has_won and game.run.ending_due, "his fall wins the run: no Maw rises after him")
	check(Profile.keepers_freed.size() == 1 and str(Profile.keepers_freed[0].gear[0].id) == "bow", "the codex keeps the Keeper freed")
	var lines := finale.keeper.records(CONTENT)
	check(lines.size() == 1 and lines[0].contains(bow.display_name), "his page lists him: %s" % (lines[0] if not lines.is_empty() else ""))
	await _wait(game, Game.ENDING_DELAY + 0.3)
	var panel := game.menus.ending
	var lore := panel.find_child("Lore", true, false) as Label
	check(panel.visible and panel.buttons().size() == 2 and lore != null and lore.text == finale.keeper_choice_lore, "beating himself frees him: the choice comes again, told for him")
	panel.buttons()[1].pressed.emit()
	await _frames(3)
	check(KeeperSnapshot.is_valid(Profile.keeper) and str(Profile.keeper.gear[0].id) != "bow" and str(Profile.keeper.pseudonym) != "Ash", "taking his place again: this hero waits now, in place of the other")
	check(game.game_over_panel.shown_text().contains(finale.endings[1].keeper_text.get_slice("\n", 0)), "the victory screen tells it for him")
	(game.game_over_panel.get_node("%ContinueButton") as Button).pressed.emit()
	await _frames(3)
	_close_offers(game)
	# The debug panel's way down: to him (made from the hero as he is), or to Tôma.
	var debug := game.menus.debug
	if debug:
		var waiting := Profile.keeper.duplicate(true)
		game.open_debug()
		await _frames(2)
		var button := debug.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "Nameless Keeper")
		check(button.size() == 1, "the debug panel has a way down to the Nameless Keeper")
		if button.size() == 1:
			(button[0] as Button).pressed.emit()
			for i in 60:
				await _frames(1)
				if not game._transitioning:
					break
			_close_offers(game)
			var made := game.world.arena.boss if game.world.arena else null
			check(made != null and made.def is NamelessKeeperDef and made.get_weapon().id == game.player.get_weapon().id, "it takes the hero down to himself as the Keeper")
			check(Profile.keeper == waiting, "without touching the one waiting in the profile")
		await game.debug.enter_finale()
		check(game.world.arena.boss.def == finale.boss, "the Well's bottom, as before: Tôma")
		DebugCheats.reset()
	fixtures.queue_free()
	Profile.reset()


func _find_perk(id: String) -> PerkDef:
	for perk in CONTENT.perks:
		if perk.id == StringName(id):
			return perk
	return null
