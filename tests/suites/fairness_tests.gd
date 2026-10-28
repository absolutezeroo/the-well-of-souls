class_name FairnessTests
extends TestSuite
## The fairness contract (docs/decisions/0008, docs/design/pillars.md "The fairness contract",
## docs/design/monsters.md "Warnings"), checked after the audit of 2026-10-28: every wind-up of
## every monster and boss, at every difficulty (Nightmare at its highest ascension too) and in
## every phase, at least its floor; warnings as wide as the real blow and as long as the fuse;
## one readable twist per ascension; the damage budget on Keeper. On a game: arrows toward
## threats out of sight, the warning sound (a few at most).

const MONSTER_SCENE := "res://src/entities/monster/monster.tscn"


func run_unit() -> void:
	_test_floors_in_data()
	_test_windup_floors()
	_test_warning_truth()
	await _test_fuse_mark()
	_test_ascensions()
	_test_damage_budget()


func run_game(game: Game) -> void:
	await _test_threat_markers(game)
	await _test_warning_sound(game)


# --- Unit ----------------------------------------------------------------------

## The floors are decision 0008's: 0.4 s for a monster's blow, 0.5 s for a boss's, 0.4 s for a
## blast's or a trap's warning; and they hold whatever the wind-up written.
func _test_floors_in_data() -> void:
	var rules := Combat.RULES
	check(rules.min_monster_windup >= 0.4 and rules.min_boss_windup >= 0.5 and rules.min_blast_warning >= 0.4,
		"fairness: the floors in data are at least decision 0008's (%.2f / %.2f / %.2f)" % [rules.min_monster_windup, rules.min_boss_windup, rules.min_blast_warning])
	check(rules.monster_windup(0.1, false) == rules.min_monster_windup and rules.monster_windup(0.1, true) == rules.min_boss_windup
		and rules.monster_windup(0.9, false) == 0.9 and rules.blast_warning(0.2) == rules.min_blast_warning and rules.blast_warning(0.8) == 0.8,
		"fairness: a wind-up under the floor is raised to it, a longer one kept")
	for path in ["res://data/hazards/arrow_trap.tres", "res://data/hazards/spike_plate.tres", "res://data/hazards/flame_vent.tres"]:
		var trap := load(path) as TrapDef
		check(trap != null and trap.warning_seconds() >= rules.min_blast_warning, "fairness: %s warns %.2f s at least" % [path.get_file(), trap.warning_seconds() if trap else 0.0])
	var volley := load("res://data/skills/monster/volley.tres") as SkillDef
	check(volley.cast_time >= rules.min_monster_windup and volley.hurts(), "fairness: a monster's Volley has a real wind-up (%.2f s)" % volley.cast_time)


## Every monster and boss of data/monsters, at every difficulty (and Nightmare at its last
## ascension), in every phase: its blow, every skill that hurts, its warned pulse, its bite and
## its strikes on the ground wind up at least the floor; its shockwaves and its death's burst
## warn at least the blast floor. Asked the way the game asks (FloorRules, Monster, BossBrain).
func _test_windup_floors() -> void:
	var rules := Combat.RULES
	var difficulties: Array[DifficultyDef] = CONTENT.difficulties.duplicate()
	var nightmare := CONTENT.get_difficulty(&"nightmare")
	if nightmare:
		difficulties.append(AscensionDef.apply_levels(nightmare, CONTENT.ascensions, CONTENT.ascensions.size()))
	var scene := load(MONSTER_SCENE) as PackedScene
	var walked := 0
	var under: Array[String] = []
	for def in _all_monster_defs():
		var boss := def is BossDef
		var floor_seconds := rules.min_boss_windup if boss else rules.min_monster_windup
		for difficulty in difficulties:
			var monster := scene.instantiate() as Monster
			monster.setup(def, 1, CONTENT.dungeon)
			# What setup() asks of a floor's rules in a world (FloorRules.telegraph_time()).
			monster.scale_telegraph(FloorRules.make(CONTENT.dungeon, difficulty, null, 1).telegraph_time())
			var phases: Array[BossPhase] = [null]
			if boss:
				phases.append_array((def as BossDef).phases)
			for phase in phases:
				if phase:
					monster.brain.take_phase(phase)
				var where := "%s on %s%s, phase %d" % [def.id, difficulty.id, "+%d" % difficulty.ascension if difficulty.ascension > 0 else "", phases.find(phase) + 1]
				walked += 1
				if def.weapon and monster.get_attack_windup() < floor_seconds - 0.0001:
					under.append("%s: blow %.2f" % [where, monster.get_attack_windup()])
				for skill in monster.skills.skills:
					if skill == null or not skill.hurts():
						continue
					var cast := monster.skill_cast_time(skill)
					if cast < floor_seconds - 0.0001:
						under.append("%s: %s %.2f" % [where, skill.id, cast])
					for effect in skill.effects:
						var strike := effect as GroundStrikeEffect
						if strike and monster.floor_windup(strike.fuse) < floor_seconds - 0.0001:
							under.append("%s: %s's strike %.2f" % [where, skill.id, monster.floor_windup(strike.fuse)])
				for monster_trait in def.traits:
					var warning := -1.0
					if monster_trait is WarnedPulseTrait:
						warning = monster.windup_for((monster_trait as WarnedPulseTrait).fuse)
					elif monster_trait is WeakPointTrait:
						warning = monster.windup_for((monster_trait as WeakPointTrait).bite_windup)
					if warning >= 0.0 and warning < floor_seconds - 0.0001:
						under.append("%s: %s %.2f" % [where, monster_trait.get_script().get_global_name(), warning])
					var burst := monster_trait as DeathBurstTrait
					if burst and rules.blast_warning(burst.fuse) < rules.min_blast_warning - 0.0001:
						under.append("%s: its burst %.2f" % [where, rules.blast_warning(burst.fuse)])
				if boss:
					var boss_def := def as BossDef
					for fuse in [boss_def.roar_shockwave_fuse, boss_def.streak_shockwave_fuse]:
						if rules.blast_warning(fuse) < rules.min_blast_warning - 0.0001:
							under.append("%s: shockwave %.2f" % [where, rules.blast_warning(fuse)])
			monster.free()
	check(walked > 300, "fairness: every monster x difficulty x phase walked (%d)" % walked)
	check(under.is_empty(), "fairness: no wind-up under its floor, at any difficulty or phase (%s)" % ", ".join(under.slice(0, 8)))
	# The bestiary's preview shows the same wind-up (no longer half a second for everything).
	var bat := load("res://data/monsters/bat.tres") as MonsterDef
	check(is_equal_approx(AttackPreview.warning_time(bat, bat.weapon), rules.monster_windup(bat.attack_windup, false)),
		"fairness: the bestiary's preview warns as long as the fight does (%.2f s)" % AttackPreview.warning_time(bat, bat.weapon))


## A warning is as wide as the blow: a skill drawing its own circle holds only areas inside it
## (a ring of shots is never drawn as a small circle), shots are drawn as far as they fly, and a
## ranged monster's shot as far as its weapon reaches.
func _test_warning_truth() -> void:
	var view := TelegraphView.new()
	var skills := {}
	for def in _all_monster_defs():
		for skill in def.skills:
			if skill:
				skills[skill] = def
		if def is BossDef:
			for phase in (def as BossDef).phases:
				for skill in phase.skills:
					if skill:
						skills[skill] = def
	var wrong: Array[String] = []
	for skill: SkillDef in skills:
		if not skill.hurts():
			continue
		# (Strikes on the ground mark their own spots, each for its fuse: GroundStrike.)
		var own_marks := skill.effects.all(func(effect: Effect) -> bool: return effect == null or not effect.hurts() or effect is GroundStrikeEffect)
		if not view.show_skill(skill, 0.0, 0.5, 12.0):
			if not own_marks:
				wrong.append("%s: no mark" % skill.id)
			continue
		var first: Effect = skill.effects[0]
		var shown_radius := float(view.material.get(&"shader_parameter/radius"))
		if skill.telegraph_radius > 0.0:
			for effect in skill.effects:
				if effect is ProjectileEffect or effect is DashStrikeEffect:
					wrong.append("%s: its shots or its dive drawn as a circle" % skill.id)
				elif effect and effect.hurts() and effect.warning_reach() > skill.telegraph_radius + 0.5:
					wrong.append("%s: an area of %.0f in a circle of %.0f" % [skill.id, effect.warning_reach(), skill.telegraph_radius])
		elif first is ProjectileEffect and not is_equal_approx(shown_radius, (first as ProjectileEffect).max_distance):
			wrong.append("%s: lanes of %.0f for shots flying %.0f" % [skill.id, shown_radius, (first as ProjectileEffect).max_distance])
	check(skills.size() > 60, "warnings: the monsters' skills were found (%d)" % skills.size())
	check(wrong.is_empty(), "warnings: every mark covers the real blow (%s)" % ", ".join(wrong.slice(0, 8)))
	view.free()
	# A ranged monster's shot: its line as long as the shot flies, as wide as the shot.
	var eye := load("res://data/monsters/eye.tres") as MonsterDef
	var monster := (load(MONSTER_SCENE) as PackedScene).instantiate() as Monster
	monster.setup(eye, 1, CONTENT.dungeon)
	var overlay := MonsterOverlay.create(monster, MonsterOverlay.Layer.UNDER)
	monster.telegraph = 0.5
	overlay._update_telegraph()
	var mark := overlay._telegraph
	check(eye.weapon.kind == WeaponDef.Kind.RANGED and mark.visible and is_equal_approx(float(mark.material.get(&"shader_parameter/radius")), eye.weapon.reach),
		"warnings: a ranged monster's shot is drawn as far as it flies (%.0f / %.0f)" % [float(mark.material.get(&"shader_parameter/radius")), eye.weapon.reach])
	check(mark.area().size.x < eye.weapon.reach * 2.0 and mark.area().size.y < eye.weapon.reach * 2.0,
		"warnings: a long line shades its own box, not a square the size of the room (%s)" % mark.area())
	overlay.free()
	monster.free()


## A blast's warning lasts its whole fuse (the old ring was gone after 0.36 s) and follows a
## boss that moves.
func _test_fuse_mark() -> void:
	var source := Node2D.new()
	add_child(source)
	source.global_position = Vector2(100, 100)
	var mark := FuseMark.create(source.global_position, 80.0, 0.6, source)
	add_child(mark)
	for i in 5:
		mark._process(0.1)
		source.global_position += Vector2(10, 0)
	check(not mark.is_queued_for_deletion() and mark.progress() > 0.8 and mark.progress() < 1.0, "warnings: a blast's mark still shows near the end of its fuse (%.2f)" % mark.progress())
	mark._process(0.0)
	check(mark.global_position == source.global_position, "warnings: a shockwave's mark follows the boss")
	mark._process(0.15)
	check(mark.is_queued_for_deletion(), "warnings: the mark goes when the blast lands")
	source.free()
	await get_tree().process_frame


## Each ascension adds exactly one readable twist, and none shortens the time to dodge (the
## floor would take it back anyway).
func _test_ascensions() -> void:
	var neutral := AscensionDef.new()
	var keys := ["monster_hp", "monster_damage", "monster_speed", "telegraph_time", "elite_chance", "boss_hp", "light", "shop_prices", "hero_max_hp", "extra_monsters"]
	for level in CONTENT.ascensions:
		var twists := 0
		for key: String in keys:
			if level.get(key) != neutral.get(key):
				twists += 1
		check(twists == 1, "ascension: %s adds one twist (%d)" % [level.title, twists])
		check(level.telegraph_time >= 1.0, "ascension: %s doesn't shorten the time to dodge" % level.title)


## On Keeper the expected hero at each depth (BalanceBuild.hero_at: the balance curve's) loses at
## most 20 % of his Health to an ordinary monster's hit and 30 % to a boss's, at the top of the
## hits' roll (the decision's budget; elites and the harder difficulties are above it on purpose).
func _test_damage_budget() -> void:
	var builds := BalanceBuild.load_all()
	var keeper := CONTENT.get_difficulty(&"normal")
	var dungeon := CONTENT.dungeon
	var scene := load(MONSTER_SCENE) as PackedScene
	var heroes := {}
	var worst := { false: [0.0, ""], true: [0.0, ""] }
	var placed := {}
	var walk := func(def: MonsterDef, depth: int) -> void:
		if not heroes.has(depth):
			var player := BalanceBuild.make_player(BalanceBuild.hero_at(builds, CONTENT, depth), CONTENT, keeper)
			heroes[depth] = [player.get_max_hp(), player.get_stats().defense]
			player.free()
		var hero: Array = heroes[depth]
		var monster := scene.instantiate() as Monster
		monster.setup(def, depth, dungeon)
		var rules := FloorRules.make(dungeon, keeper, null, depth)
		var phases: Array[BossPhase] = [null]
		if def is BossDef:
			phases.append_array((def as BossDef).phases)
		for phase in phases:
			if phase:
				monster.brain.take_phase(phase)
			for hit: Array in _hits(monster, rules):
				var top := Combat.mitigate(maxi(1, roundi(int(hit[0]) * (1.0 + Combat.RULES.damage_variance))), int(hero[1]))
				var share := float(top) / float(hero[0])
				var record: Array = worst[def is BossDef]
				if share > float(record[0]):
					worst[def is BossDef] = [share, "%s at %d: %s %d of %d" % [def.id, depth, hit[1], top, hero[0]]]
		monster.free()
	for i in dungeon.acts.size():
		var act := dungeon.acts[i]
		for def in act.monsters:
			if def and not placed.has(def):
				placed[def] = true
				for depth in BalanceContent.monster_depths(CONTENT, i + 1, def):
					walk.call(def, depth)
		for boss in act.all_bosses():
			for form in boss.forms():
				placed[form] = true
				walk.call(form, BalanceContent.boss_depth(CONTENT, i + 1))
	# The bosses of no act (the bottom of the Well, the hidden floor's): at the last floor.
	for def in _all_monster_defs():
		if def is BossDef and not placed.has(def) and not def is NamelessKeeperDef:
			walk.call(def, dungeon.total_floors())
	print("Damage budget on Keeper: ordinary %.1f%% (%s), boss %.1f%% (%s)" % [float(worst[false][0]) * 100.0, worst[false][1], float(worst[true][0]) * 100.0, worst[true][1]])
	check(float(worst[false][0]) > 0.0 and float(worst[true][0]) > 0.0, "budget: hits were measured")
	check(float(worst[false][0]) <= 0.2, "budget: an ordinary hit takes at most 20%% of the expected hero's Health on Keeper (worst %.0f%%: %s)" % [float(worst[false][0]) * 100.0, worst[false][1]])
	check(float(worst[true][0]) <= 0.3, "budget: a boss's hit takes at most 30%% of it (worst %.0f%%: %s)" % [float(worst[true][0]) * 100.0, worst[true][1]])


## What each of `monster`'s attacks carries under `rules`, before the roll and the armor:
## [amount, what]. Its blow, its skills' hits (Effect.hit_amount(): what apply() deals), its
## traits', its shockwave (BossBrain.shockwave_damage()).
func _hits(monster: Monster, rules: FloorRules) -> Array[Array]:
	var hits: Array[Array] = []
	var weapon := monster.get_weapon()
	if weapon:
		var blow := monster.get_power() if weapon.kind == WeaponDef.Kind.MELEE else Combat.spec_from_weapon(monster, weapon).damage
		hits.append([blow, "blow"])
	for skill in monster.skills.skills:
		if skill == null:
			continue
		for effect in skill.effects:
			if effect and effect.hurts():
				hits.append([effect.hit_amount(monster), String(skill.id)])
	for monster_trait in monster.def.traits:
		if monster_trait is DeathBurstTrait:
			hits.append([rules.dungeon_damage((monster_trait as DeathBurstTrait).damage), "burst"])
		elif monster_trait is WarnedPulseTrait:
			hits.append([rules.dungeon_damage((monster_trait as WarnedPulseTrait).damage), "pulse"])
		elif monster_trait is WeakPointTrait:
			hits.append([maxi(1, roundi(monster.get_power() * (monster_trait as WeakPointTrait).bite_power)), "bite"])
		elif monster_trait is WyrmTrait:
			hits.append([rules.dungeon_damage((monster_trait as WyrmTrait).contact_damage), "body"])
	if monster.brain:
		hits.append([monster.brain.shockwave_damage(rules), "shockwave"])
	return hits


# --- Game ----------------------------------------------------------------------

## An arrow at the edge of the screen toward a monster winding up out of sight, or a shot coming;
## nothing for one in sight, or asleep; over the whole HUD.
func _test_threat_markers(game: Game) -> void:
	var player := game.player
	var world := game.world
	await _clear_monsters(world)
	var markers := game.hud.threat_markers
	check(markers.get_parent() == game.hud and markers.player == player, "threats: the HUD keeps the arrows, bound to the hero")
	var on_top := true
	for child in game.hud.get_children():
		var item := child as CanvasItem
		if item and item != markers and item.z_index >= markers.z_index:
			on_top = false
	check(on_top, "threats: the arrows are drawn over the whole HUD")
	markers.scan()
	check(markers.count() == 0, "threats: no arrow without a threat")
	var view := world.view_rect(0.0)
	var far := view.get_center() + Vector2(view.size.x * 0.5 + 200.0, 0.0)
	var rat := world.spawn_monster(load("res://data/monsters/rat.tres"), far)
	rat.dormant = true
	await _frames(2)
	rat.set_awake(true)
	rat.telegraph = 0.6
	markers.scan()
	check(markers.count() == 1 and absf(angle_difference(markers.direction_of(0), 0.0)) < 0.01, "threats: a monster winding up out of sight on the right gets an arrow pointing right")
	check(markers.count() == 1 and markers.tip_of(0).x > markers.size.x * 0.8, "threats: ...at the screen's edge")
	rat.telegraph = 0.0
	markers.scan()
	check(markers.count() == 0, "threats: not when it isn't winding up")
	rat.global_position = player.global_position + Vector2(60, 0)
	rat.telegraph = 0.6
	markers.scan()
	check(markers.count() == 0, "threats: not for a monster in sight")
	rat.global_position = far
	rat.set_awake(false)
	rat.telegraph = 0.6
	markers.scan()
	check(markers.count() == 0, "threats: not for one asleep")
	rat.telegraph = 0.0
	# A shot flying in from out of sight, on open floor (a wall would stop it at once).
	var from := _free_point_outside(world, view)
	check(from != Vector2.INF, "threats: open floor out of sight to shoot from")
	if from != Vector2.INF:
		var spec := ProjectileSpec.new()
		spec.damage = 1
		spec.speed = 30.0
		spec.max_distance = 2000.0
		var shooter := world.spawn_monster(load("res://data/monsters/rat.tres"), from)
		shooter.dormant = true
		await _frames(1)
		world.fire_projectiles(shooter, from.direction_to(player.global_position), spec, from)
		await _frames(2)
		markers.scan()
		var middle := markers.get_rect().get_center()
		var expected := snappedf((player.get_canvas_transform() * from - middle).angle(), TAU / 16.0)
		check(markers.count() == 1 and absf(angle_difference(markers.direction_of(0), expected)) < 0.01, "threats: a shot coming from out of sight gets an arrow toward it")
		shooter.queue_free()
	rat.queue_free()
	for i in world.projectile_layer().get_child_count():
		world.projectile_layer().get_child(i).queue_free()
	await _frames(2)


## A monster winding up sounds its warning; a crowd winding up together makes one, not a din.
func _test_warning_sound(game: Game) -> void:
	var player := game.player
	var world := game.world
	await _clear_monsters(world)
	check(Sfx.bank.telegraph != null, "warning sound: in the bank")
	var played := Sfx.warnings_played
	Sfx._last_warning = -1000.0
	for i in 6:
		Sfx.play_warning(player.global_position)
	check(Sfx.warnings_played == played + 1, "warning sound: six at once make one (%d)" % (Sfx.warnings_played - played))
	Sfx._last_warning = -1000.0
	played = Sfx.warnings_played
	var rat := world.spawn_monster(load("res://data/monsters/rat.tres"), world.find_open_point_near(player.global_position, 40.0))
	var winding := func() -> bool: return rat.telegraph > 0.0
	var wound := await _until(winding, 6.0)
	check(wound, "warning sound: a rat next to the hero winds up")
	check(Sfx.warnings_played > played, "warning sound: ...and its wind-up sounds")
	rat.queue_free()
	await _frames(5)


# --- Helpers --------------------------------------------------------------------

## A free floor point just out of `view` (left, right, above or below), or INF.
func _free_point_outside(world: World, view: Rect2) -> Vector2:
	var tile := float(world.map.tile_size)
	for way: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var edge := absf(way.x) * view.size.x * 0.5 + absf(way.y) * view.size.y * 0.5
		for step in 12:
			var point := view.get_center() + way * (edge + tile * (2 + step))
			if world.is_free_cell(world.map.world_to_cell(point)):
				return world.map.cell_to_world(world.map.world_to_cell(point))
	return Vector2.INF


## Every MonsterDef and BossDef under data/monsters.
func _all_monster_defs() -> Array[MonsterDef]:
	var found: Array[MonsterDef] = []
	var dirs := ["res://data/monsters"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			dirs.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			var path := dir.path_join(file.trim_suffix(".remap"))
			if path.ends_with(".tres"):
				var def := load(path) as MonsterDef
				if def:
					found.append(def)
	return found
