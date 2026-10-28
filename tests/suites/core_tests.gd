class_name CoreTests
extends TestSuite
## The core of the gameplay after its audit (2026-10-24): the numbers moved from code to data
## kept their values, every floor number asked of FloorRules is what the hand-made products
## gave, one roller for a floor's twist, the loot odds told are the odds rolled, effects dressed
## by their own kind, delayed effects credited to their source, combat dice per floor, an arrow
## trap's volley on its own clock; the entities' parts asked by kind and holding typed records
## (task_193). Unit checks run in the unit suite, the rest on a game.


func run_unit() -> void:
	_test_numbers_in_data()
	_test_floor_rules_sweep()
	_test_twist_roller()
	_test_loot_odds()
	_test_effect_kinds()
	_test_combat_dice()
	_test_composed_parts()


func run_game(game: Game) -> void:
	await _test_delayed_source(game)
	_test_world_dice(game)
	_test_encounter_odds(game)
	await _test_arrow_volley(game)


## Every number moved out of the scripts kept the value it had there.
func _test_numbers_in_data() -> void:
	var rules := Combat.RULES
	check(rules.crit_multiplier == 1.75 and rules.damage_variance == 0.15 and rules.armor_weight == 1.0 and rules.max_cooldown_reduction == 0.5 and rules.delayed_blast_knockback == 260.0,
		"the combat rules in data are the ones the code had: crit x1.75, variance 15%, armor weight 1, cooldown cap 50%, a delayed blast's push 260")
	var hero := CONTENT.player
	check(hero.hit_invulnerability == 0.6 and hero.fall_invulnerability == 1.0 and hero.swap_cooldown == 1.5 and hero.skill_aim_range == 520.0 and hero.melee_aim_assist == 70.0 and is_equal_approx(hero.input_buffer, 0.12),
		"the hero's feel in data is the code's: 0.6 s i-frames, 1 s after a fall, 1.5 s swap cooldown, 520 aim range, 70 melee assist, 0.12 s input buffer (decision 0008's audit: 0.1-0.15 s for the attack, the roll and the skills)")
	var bosses: Array[BossDef] = []
	for act in CONTENT.dungeon.acts:
		for boss in act.all_bosses():
			if boss and not bosses.has(boss):
				bosses.append(boss)
	check(not bosses.is_empty(), "the acts have bosses to check")
	for boss in bosses:
		check(boss.shockwave_cooldown == 3.0 and boss.shockwave_base_damage == 4.0 and boss.shockwave_damage_per_depth == 0.6 and boss.shockwave_fallback_damage == 6 and boss.roar_shockwave_fuse == 0.35 and boss.streak_shockwave_fuse == 0.45,
			"%s keeps the shockwave the code gave every boss (3 s cooldown, 4 + 0.6 per floor, fuses 0.35 / 0.45)" % boss.id)
	for monster in CONTENT.all_monsters():
		check(monster.chase_sight_multiplier == 1.6 and monster.chase_give_up_after == 4.0 and monster.wander_speed == 0.35,
			"%s chases and wanders as the code had it (sight x1.6, gives up after 4 s, wanders at 35%%)" % monster.id)
	var config := CONTENT.dungeon
	check(config.ambush_depths_per_extra == 3.0 and config.ambush_spawn_interval == 0.25 and config.ambush_wave_pause == 1.0 and config.ambush_min_spawn_distance == 90.0,
		"the ambushes' rhythm in data is the code's (one more per 3 floors, 0.25 s, 1 s pause, 90 px)")
	check(config.consumable_gold_share == 0.3 and config.consumable_gold_min == 2 and config.gold_per_pile == 4.0 and config.gold_max_piles == 6 and config.boss_rank_loot_per_affix == 0.25,
		"the drops' numbers in data are the code's (30% of a potion over the cap as gold, 2 at least; piles of 4, 6 at most; a ranked boss +25% quality per affix)")
	check(not config.pacts.is_empty() and config.pacts.all(func(pact: PactDef) -> bool:
			return pact.depths_per_extra_foe == 3.0 and pact.foes_per_wave(7) == pact.wave_size + 2),
		"a pact's waves grow as the code had it: one more foe every 3 floors")
	var trap: ArrowTrapDef = load("res://data/hazards/arrow_trap.tres")
	check(trap.arrow_radius == 5.0 and trap.arrow_color == Color("d9d3c7"), "an arrow trap's arrows keep their body and color")


## FloorRules gives what the hand-made products gave, for every depth, difficulty, event and
## curse (the old formulas written out here).
func _test_floor_rules_sweep() -> void:
	var config := CONTENT.dungeon
	var events: Array = [null]
	events.append_array(CONTENT.floor_events)
	var curses: Array = [null]
	curses.append_array(CONTENT.curses)
	var difficulties: Array = [null]
	difficulties.append_array(CONTENT.difficulties)
	var boons := RunBoons.new()
	boons.loot_quality_scale = 1.35
	boons.gold_scale = 1.2
	var wrong := PackedStringArray()
	var compared := 0
	for depth in range(1, config.total_floors() + 3):
		for difficulty: DifficultyDef in difficulties:
			for i in maxi(events.size(), curses.size()):
				var event: FloorEventDef = events[i % events.size()]
				var curse: CurseDef = curses[i % curses.size()]
				var rules := FloorRules.make(config, difficulty, event, depth, curse)
				rules.boons = boons
				var level := rules.difficulty
				compared += 1
				var where := "depth %d, %s, %s, %s" % [depth, difficulty.id if difficulty else &"none", event.id if event else &"no event", curse.id if curse else &"no curse"]
				for rank in config.rare_ranks:
					if rank and rules.boss_rank_chance(rank) != rank.boss_chance * level.elite_chance:
						wrong.append("boss rank chance at " + where)
				if rules.max_monsters_per_room() != config.max_monsters_per_room + level.extra_monsters:
					wrong.append("monsters per room at " + where)
				if rules.ambush_wave_size() != config.ambush_wave_size + floori(depth / 3.0):
					wrong.append("ambush wave at " + where)
				var tint := rules.light()
				if event:
					tint *= event.ambient_tint
				if rules.ambient_light() != tint:
					wrong.append("light at " + where)
				for quality: float in [1.0, 1.5, 2.5, 5.0]:
					if rules.drop_quality(quality) != quality * rules.loot_quality() * boons.loot_quality_scale:
						wrong.append("drop quality at " + where)
				for amount in [1, 3, 7, 20, 150]:
					if rules.floor_gold(amount) != roundi(rules.gold(amount) * boons.gold_scale):
						wrong.append("gold at " + where)
	check(compared > 100 and wrong.is_empty(), "FloorRules' new answers equal the products made by hand before, %d floors compared (%s)" % [compared, ", ".join(wrong.slice(0, 5))])
	# The hidden floor's souls: RunState's own formula.
	for difficulty in CONTENT.difficulties:
		var run := RunState.new()
		run.difficulty = difficulty
		check(run.bonus_souls_worth(60) == roundi(60 * difficulty.souls), "bonus souls are worth what the end of the run counts (%s)" % difficulty.id)


## One roller for a floor's twist: what a way down offers and what a floor rolls itself are the
## same rolls as before, on the same random numbers.
func _test_twist_roller() -> void:
	var content := CONTENT
	var config := content.dungeon
	var difficulties: Array = [null]
	difficulties.append_array(content.difficulties)
	# The rolls only show with chances: the test's own, put back after.
	var event_chance := config.floor_event_chance
	config.floor_event_chance = 0.35
	var chances := {}
	for difficulty in content.difficulties:
		chances[difficulty] = difficulty.curse_chance
		difficulty.curse_chance = maxf(difficulty.curse_chance, 0.3)
	var same := true
	var twists := 0
	for depth in range(2, config.total_floors() + 1):
		for difficulty: DifficultyDef in difficulties:
			for seed_value in 12:
				var old_rng := RandomNumberGenerator.new()
				old_rng.seed = seed_value * 7919 + depth
				var new_rng := RandomNumberGenerator.new()
				new_rng.seed = old_rng.seed
				var old_twist := _old_floor_twist(content, depth, old_rng, difficulty)
				var rolled := FloorRoute.roll_twist(content, depth, new_rng, difficulty)
				same = same and old_twist[0] == rolled.curse and old_twist[1] == rolled.floor_event and old_rng.randi() == new_rng.randi()
				if rolled.curse or rolled.floor_event:
					twists += 1
				var offer_seed := FloorRoute.seed_for(seed_value, depth)
				var old_offer := _old_offer(content, depth, difficulty, offer_seed)
				var offer := FloorRoute.offer(content, depth, difficulty, offer_seed)
				same = same and old_offer.size() == offer.size()
				for i in mini(old_offer.size(), offer.size()):
					same = same and old_offer[i][0] == offer[i].biome and old_offer[i][1] == offer[i].curse and old_offer[i][2] == offer[i].floor_event
	config.floor_event_chance = event_chance
	for difficulty: DifficultyDef in chances:
		difficulty.curse_chance = chances[difficulty]
	check(same and twists > 50, "a floor's twist and the ways down roll as they did, on the same numbers (%d twists rolled)" % twists)


## The twist World.build_floor() rolled itself before FloorRoute.roll_twist(): [curse, event].
func _old_floor_twist(content: ContentDB, depth: int, rng: RandomNumberGenerator, difficulty: DifficultyDef) -> Array:
	var curse: CurseDef = null
	var floor_event: FloorEventDef = null
	var curse_chance := difficulty.curse_chance if difficulty else 0.0
	if rng.randf() < curse_chance:
		curse = ContentDB.pick_from(content.curses, depth, rng) as CurseDef
	if curse == null and rng.randf() < content.dungeon.floor_event_chance:
		floor_event = FloorRoute.pick_event(content, depth, rng)
	return [curse, floor_event]


## FloorRoute.offer() as it was written before the one roller: [biome, curse, event] per way.
func _old_offer(content: ContentDB, depth: int, difficulty: DifficultyDef, offer_seed: int) -> Array:
	var result: Array = []
	var config := content.dungeon
	if config.route_count < 2 or depth <= 1 or config.boss_for_depth(depth) != null:
		return result
	var act := config.act_for_depth(depth)
	if act == null:
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = offer_seed
	var worlds: Array = act.biomes.filter(func(b: BiomeDef) -> bool: return b != null and b.min_depth <= depth)
	if worlds.is_empty():
		return result
	var curse_chance := difficulty.curse_chance if difficulty else 0.0
	for i in config.route_count:
		var left: Array = worlds.filter(func(b: BiomeDef) -> bool: return not result.any(func(r: Array) -> bool: return r[0] == b))
		var biome := ContentDB.pick_from(left if not left.is_empty() else worlds, depth, rng) as BiomeDef
		var curse: CurseDef = null
		var floor_event: FloorEventDef = null
		if rng.randf() < curse_chance:
			curse = ContentDB.pick_from(content.curses, depth, rng) as CurseDef
		if curse == null and rng.randf() < config.floor_event_chance:
			floor_event = FloorRoute.pick_event(content, depth, rng)
		if i > 0 and curse == null and floor_event == null and rng.randf() < config.route_twist_chance:
			var curse_share := curse_chance / maxf(curse_chance + config.floor_event_chance, 0.01)
			if rng.randf() < curse_share:
				curse = ContentDB.pick_from(content.curses, depth, rng) as CurseDef
			if curse == null:
				floor_event = FloorRoute.pick_event(content, depth, rng)
		result.append([biome, curse, floor_event])
	return result


## The rarity odds are one function: what is rolled is what is told.
func _test_loot_odds() -> void:
	var config := CONTENT.dungeon
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for case: Array in [[1, 1.0], [6, 2.5], [14, 5.0]]:
		var depth: int = case[0]
		var quality: float = case[1]
		var levels := depth - 1
		var weights := LootRoller.rarity_weights(depth, quality, config)
		check(weights[0] == config.common_weight and weights[2] == (config.rare_weight + config.rare_weight_per_depth * levels) * quality and weights[3] == (config.epic_weight + config.epic_weight_per_depth * levels) * quality,
			"the rarity weights are the dungeon's, the depth's and the source's (floor %d, quality %.1f)" % [depth, quality])
		var rare := 0
		var rolls := 20000
		for i in rolls:
			if LootRoller.pick_rarity(depth, quality, config, rng) >= ItemRarity.RARE:
				rare += 1
		var told := LootRoller.rare_or_better_chance(depth, quality, config)
		check(absf(float(rare) / rolls - told) < 0.015, "the odds told (%.3f) are the odds rolled (%.3f) on floor %d at quality %.1f" % [told, float(rare) / rolls, depth, quality])


## Each effect kind dresses itself: a charged attack's element as the reflection-by-name gave it,
## a skill's shots and blows dressed, the rest left alone; a tamed slow keeps the dressing.
func _test_effect_kinds() -> void:
	var fire := VfxElementDef.named(&"fire")
	var frost := VfxElementDef.named(&"frost")
	var earth := VfxElementDef.named(&"earth")
	var kinds: Array[Effect] = [ProjectileEffect.new(), DamageAreaEffect.new(), DashStrikeEffect.new(), GroundStrikeEffect.new(), HealEffect.new(), BuffEffect.new(), AllyEffect.new(), SummonEffect.new(), DashEffect.new(), ChainLightningEffect.new()]
	for kind in kinds:
		for own: VfxElementDef in [null, earth, fire]:
			for second: VfxElementDef in [null, frost]:
				kind.element = own
				var dressed := kind.dressed_for_charge(fire, second)
				var kind_name := kind.get_script().get_global_name() as String
				if kind is ProjectileEffect:
					var charged_shot := dressed as ProjectileEffect
					var pair: Array[VfxElementDef] = [fire, second]
					var expected := (kind as ProjectileEffect).dressed_in(pair, true)
					check(charged_shot != kind and charged_shot.element == own and charged_shot.look_element == expected.look_element and charged_shot.lands_in_look == expected.lands_in_look, "a charged shot flies in the weapon's element (%s)" % kind_name)
					continue
				check(dressed != kind and dressed.element == fire, "a charged %s is made of the weapon's first element" % kind_name)
				# (The old rule, by property name: a kind with a second element sheds it.)
				if &"second_element" in dressed:
					var sheds: VfxElementDef = dressed.get(&"second_element")
					check(sheds == (second if second else (own if own != fire else null)), "a charged %s sheds the second element, or its own (%s)" % [kind_name, sheds])
		kind.element = null
	var carried: Array[VfxElementDef] = [fire, frost]
	for kind in kinds:
		var dressed := kind.dressed_for_skill(carried)
		var dresses := kind is ProjectileEffect or kind is DamageAreaEffect or kind is DashStrikeEffect
		check((dressed != kind) == dresses and (not dresses or dressed.get(&"look_element") == fire), "a weapon's skill dresses its shots and blows, nothing else (%s)" % kind.get_script().get_global_name())
	# Telegraphs by kind (the Nameless Keeper's cast times and ranges).
	var dive := DashStrikeEffect.new()
	var shot := ProjectileEffect.new()
	var area := DamageAreaEffect.new()
	area.offset = -20.0
	check(dive.telegraph_kind() == Effect.Telegraph.DIVE and dive.ai_reach() == dive.distance and shot.telegraph_kind() == Effect.Telegraph.SHOT and shot.ai_reach() == shot.max_distance \
		and area.telegraph_kind() == Effect.Telegraph.AREA and area.ai_reach() == area.offset + area.radius and area.warning_reach() == 20.0 + area.radius and HealEffect.new().telegraph_kind() == Effect.Telegraph.OTHER,
		"each kind tells how a boss warns of it and how far it reaches")
	# A tamed slow keeps the weapon's dressing (a duplicate() lost it).
	var keeper := NamelessKeeperDef.new()
	var slowing := ProjectileEffect.new()
	slowing.status = OnHitStatus.new()
	slowing.status.slow = 0.4
	slowing.status.slow_duration = 9.0
	var skill := SkillDef.new()
	var its_effects: Array[Effect] = [slowing]
	skill.effects = its_effects
	var made := keeper.boss_skill(skill, carried, false)
	var tamed := made.effects[0] as ProjectileEffect
	check(tamed.look_element == fire and tamed.status.slow == 0.0 and slowing.status.slow == 0.4, "the Keeper's tamed shot keeps the elements it was dressed in, the hero's own unchanged")
	var keeper_dive := DashStrikeEffect.new()
	keeper_dive.width = 400.0
	var as_his := keeper_dive.as_boss_skill(carried, keeper.dive_width_max) as DashStrikeEffect
	check(as_his != keeper_dive and as_his.width == keeper.dive_width_max and as_his.look_element == fire and keeper_dive.width == 400.0, "his dive is narrowed and dressed, a copy")


## The entities' parts answer by kind what was tested by type or read by name (task_193): a
## passive's look is the element its old lookup by property name found, the hero's hits wear his
## gear's elements and a monster's don't, a plain dash warns only in the preview, and the records
## that were dictionaries keep the save's format.
func _test_composed_parts() -> void:
	var fire := VfxElementDef.named(&"fire")
	var frost := VfxElementDef.named(&"frost")
	var names: Array[StringName] = [&"element", &"blast_element", &"shard_element", &"crit_element"]
	var dir := "res://src/definitions/passives/"
	var tried := 0
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".gd"):
			continue
		var script := load(dir + file) as GDScript
		var probe := script.new() as Passive
		if probe == null:
			continue
		var has: Array[StringName] = []
		for property in names:
			if property in probe:
				has.append(property)
		if has.is_empty():
			continue
		# Every mix of none, fire and frost on its element properties.
		for mix in int(pow(3, has.size())):
			var left := mix
			for property in has:
				probe.set(property, [null, fire, frost][left % 3])
				left = int(left / 3.0)
			var old: VfxElementDef = null
			for property in names:
				if property in probe and probe.get(property) is VfxElementDef:
					old = probe.get(property)
					break
			check(probe.look_element() == old, "%s shows as the element its old lookup by name found (%s)" % [file, old.id if old else &"none"])
			tried += 1
	check(tried > 20, "the passives striking in an element were all tried (%d mixes)" % tried)
	var hero := Player.new()
	var monster := Monster.new()
	check(hero.strikes_in_carried_elements() and not monster.strikes_in_carried_elements(), "the hero's hits wear his gear's elements, a monster's weapon strikes as written")
	hero.free()
	monster.free()
	var view := TelegraphView.new()
	var dash_skill := SkillDef.new()
	var dash_effects: Array[Effect] = [DashEffect.new()]
	dash_skill.effects = dash_effects
	check(not view.show_skill(dash_skill, 0.0, 0.5) and DashEffect.new().show_preview_warning(view, 0.0, 0.5) and not ProjectileEffect.new().show_preview_warning(view, 0.0, 0.5),
		"a plain dash warns of nothing in a fight, its line only in the bestiary's preview")
	var shot_skill := SkillDef.new()
	var shot_effects: Array[Effect] = [ProjectileEffect.new()]
	shot_skill.effects = shot_effects
	check(view.show_skill(shot_skill, 0.0, 0.5), "a shot warns of its lane")
	view.free()
	var belt := Belt.new()
	var potion := load("res://data/items/consumables/health_potion.tres") as ConsumableDef
	belt.add(potion)
	belt.add(potion)
	var saved := belt.to_data()
	check(saved.size() == Belt.SLOTS and (saved[0] as Dictionary).get("count") == 2 and (saved[1] as Dictionary).is_empty(), "a belt saves as it did: { item, count } per slot, {} for an empty one")
	var again := Belt.new()
	again.load_data(saved)
	check(again.item_at(0) == potion and again.count_at(0) == 2 and again.item_at(1) == null and again.count_of(potion) == 2, "and comes back the same")
	check(ThiefTrait.new().make_state() is ThiefTrait.ThiefState and WeakPointTrait.new().make_state() is WeakPointTrait.WeakPointState, "a trait's per-monster values are its own typed state")
	var statuses := StatusSet.new()
	statuses.apply_slow(0.3, 2.0)
	statuses.apply_slow(0.5, 1.0)
	statuses.apply_slow(0.2, 3.0, &"cold")
	check(is_equal_approx(statuses.speed_multiplier(), 0.5) and statuses.slow_of(&"slow") == 0.5, "slows by source: hits keep the strongest, the strongest of all counts")
	statuses.tick(null, 2.5)
	check(is_equal_approx(statuses.speed_multiplier(), 0.8), "each runs out on its own (the hits' after 2 s, the cold's after 3)")


## Hits roll on the dice they are given: the same seed, the same hits.
func _test_combat_dice() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	var same := true
	for i in 50:
		var one := Combat.make_hit(40, 0.3, null, a)
		var two := Combat.make_hit(40, 0.3, null, b)
		same = same and one.amount == two.amount and one.is_crit == two.is_crit
	check(same, "the same dice give the same hits (variance and crits)")
	var crit := RandomNumberGenerator.new()
	crit.seed = 1
	var lowest := 1000
	var highest := 0
	for i in 400:
		var hit := Combat.make_hit(100, 1.0, null, crit)
		lowest = mini(lowest, hit.amount)
		highest = maxi(highest, hit.amount)
	check(lowest >= roundi(100 * 0.85 * 1.75) and highest <= roundi(100 * 1.15 * 1.75), "a sure crit of 100 lands within x1.75 of the variance (%d-%d)" % [lowest, highest])


## Delayed effects are credited to what set them off (a skill), not to whatever acts later.
func _test_delayed_source(game: Game) -> void:
	var player := game.player
	var world := game.world
	player.hp = maxi(1, player.get_max_hp() - 30)
	var heal := HealEffect.new()
	heal.amount = 5
	heal.delay = 0.1
	var credited: Array[StringName] = []
	var on_healed := func(_amount: int, source: StringName) -> void: credited.append(source)
	player.healed.connect(on_healed)
	var effects: Array[Effect] = [heal]
	Actor.with_source(&"skill:test_delayed", func() -> void: Effect.apply_all(effects, player, Vector2.RIGHT))
	check(Actor.heal_source == &"", "the source is put back once the skill is cast")
	# Something else acting when it lands (a perk's call): the heal is still the skill's.
	Actor.heal_source = &"perk:something_else"
	await _frames(14)
	Actor.heal_source = &""
	player.healed.disconnect(on_healed)
	check(credited.size() == 1 and credited[0] == &"skill:test_delayed", "a delayed heal is credited to the skill that cast it, not to what acts when it lands (%s)" % [credited])
	# A delayed blast's hits too (HitInfo.via).
	await _clear_monsters(world)
	var slime := world.spawn_monster(load("res://data/monsters/slime.tres"), player.global_position + Vector2(140, 0))
	slime.dormant = true
	var vias: Array[StringName] = []
	var on_damaged := func(actor: Actor, hit: HitInfo, _damage: int) -> void:
		if actor == slime:
			vias.append(hit.via)
	Events.actor_damaged.connect(on_damaged)
	Actor.with_source(&"item:test_bomb", func() -> void: Combat.delayed_blast(world, slime.global_position, 40.0, 3, 0.1))
	await _frames(ceili(Combat.RULES.blast_warning(0.1) * 60.0) + 8)  # (its fuse, held to the fairness floor)
	Events.actor_damaged.disconnect(on_damaged)
	check(not vias.is_empty() and vias.all(func(v: StringName) -> bool: return v == &"item:test_bomb"), "a delayed blast's hits are credited to what set it off (%s)" % [vias])
	if is_instance_valid(slime):
		slime.queue_free()
	player.hp = player.get_max_hp()
	await _frames(1)


## The floor's combat dice: seeded from the floor's seed, apart from the floor's own rolls.
func _test_world_dice(game: Game) -> void:
	var world := game.world
	var player := game.player
	check(world.combat_rng.seed == hash("%d-combat" % world.rng.seed), "the floor's combat dice come from its seed")
	check(Combat.dice_of(player) == world.combat_rng and Combat.dice_of(null) != world.combat_rng, "the hero's hits roll on his floor's dice")
	var state := world.rng.state
	for i in 20:
		Combat.make_hit_from(player, 30)
	check(world.rng.state == state, "hits never use up the floor's own random numbers (what it rolls next stays the same)")
	var copy := RandomNumberGenerator.new()
	copy.seed = world.combat_rng.seed
	copy.state = world.combat_rng.state
	var first := Combat.make_hit(50, 0.5, player)
	var again := Combat.make_hit(50, 0.5, null, copy)
	check(first.amount == again.amount and first.is_crit == again.is_crit, "the same floor and the same blows: the same hits (a daily run plays alike for everyone)")


## An encounter tells the gold and the odds of the item it really gives (the run's boons too).
func _test_encounter_odds(game: Game) -> void:
	var world := game.world
	var player := game.player
	var boons_before := world.boons
	var boons := RunBoons.new()
	boons.loot_quality_scale = 1.6
	boons.gold_scale = 1.5
	world.boons = boons
	check(world.rules.boons == boons, "the floor's rules follow the run's boons")
	var outcome := EncounterOutcome.new()
	outcome.item_quality = 2.0
	outcome.gold = 30
	var text := outcome.summary(player)
	var odds := roundi(LootRoller.rare_or_better_chance(world.depth, world.rules.drop_quality(2.0), world.config()) * 100.0)
	var plain_odds := roundi(LootRoller.rare_or_better_chance(world.depth, 2.0 * world.rules.loot_quality(), world.config()) * 100.0)
	check(text.contains("%d%% chance" % odds) and odds != plain_odds, "the encounter's odds are the roll's, the boons' better loot in them (%s)" % text)
	check(text.contains("%d gold" % world.rules.floor_gold(30)) and world.rules.floor_gold(30) == roundi(world.rules.gold(30) * 1.5), "the encounter's gold is what drops, the boons' share in it (%s)" % text)
	# A secret room's hoard asks the same rules (FloorRules.floor_gold), never multiplies them itself.
	var hoard := SecretGoldReward.new()
	var dice := RandomNumberGenerator.new()
	dice.seed = 7
	var same := RandomNumberGenerator.new()
	same.seed = 7
	var coins := hoard.place(world, world.map.start_cell, dice)
	var told := world.rules.floor_gold(same.randi_range(hoard.gold.x, hoard.gold.y) + hoard.gold_per_depth * world.depth)
	var laid := 0
	for coin in coins:
		laid += (coin as GoldPickup).amount
		coin.queue_free()
	check(laid == told and told > 0, "a secret hoard holds the floor's gold, the boons' share in it (%d of %d)" % [laid, told])
	world.boons = boons_before


## An arrow trap's volley runs on the trap's clock: out of the tree (its floor waiting while the
## hero is at the Threshold) it shoots nothing, and the rest of the volley comes when it is back.
func _test_arrow_volley(game: Game) -> void:
	var world := game.world
	var player := game.player
	await _clear_monsters(world)
	var arrows: ArrowTrapDef = load("res://data/hazards/arrow_trap.tres")
	var plate_cell := _open_cell_near(world, player.global_position, 3)
	var trap := world.spawn_trap(arrows, plate_cell)
	trap.set_launcher(plate_cell + Vector2i.UP * 3, Vector2.DOWN)
	player.global_position = world.map.cell_to_world(plate_cell + Vector2i.RIGHT * 4)
	await _frames(2)
	var counted: Array[int] = []
	var on_added := func(node: Node) -> void:
		if node is Projectile:
			counted.append(1)
	var layer := world.get_node("Projectiles")
	layer.child_entered_tree.connect(on_added)
	arrows.on_fire(trap)
	await _frames(2)
	check(counted.size() == 1, "the first arrow flies at once")
	# Out of the tree (its floor waiting while the hero is at the Threshold): no arrow. (A volley
	# awaiting a timer on the shared ArrowTrapDef shot on into a floor out of the tree.)
	var parent := trap.get_parent()
	parent.remove_child(trap)
	for i in 30:
		await get_tree().physics_frame
	check(counted.size() == 1, "out of the tree, the trap shoots nothing")
	parent.add_child(trap)
	await _frames(int(arrows.arrow_interval * 60.0 * arrows.arrows) + 6)
	check(counted.size() == arrows.arrows, "back in the tree, the rest of the volley comes (%d of %d)" % [counted.size(), arrows.arrows])
	layer.child_entered_tree.disconnect(on_added)
	trap.queue_free()
	await _frames(2)
