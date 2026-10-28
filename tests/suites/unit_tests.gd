class_name UnitTests
extends TestSuite
## Rules and data, no game running: stats, combat, content, generation, items, perks, bosses, profile.

const SettingsScript := preload("res://src/autoload/settings.gd")  # its static helpers are called on the script, not the autoload

const PLAYER: PackedScene = preload("res://src/entities/player/player.tscn")


## Each part alone (tests/run_tests.gd runs them one by one, timed: --test=unit.<name>).
func test_cases() -> Array:
	return [
		["village", func() -> void: await _part(VillageTests.new(), func(suite: VillageTests) -> void: suite.run_unit())],
		["roguelike_entry", func() -> void: check(ProjectSettings.get_setting("application/run/main_scene") == "res://src/ui/title/title_screen.tscn", "F5 and exports launch the roguelike title and descent flow")],
		["rpg_foundations", func() -> void: await _part(RpgFoundationTests.new(), func(suite: RpgFoundationTests) -> void: suite.run_unit())],
		["modifiers", func() -> void: await _part(ModifierTests.new(), func(suite: ModifierTests) -> void: suite.run_unit())],
		["architecture", func() -> void: await _part(ArchitectureTests.new(), func(suite: ArchitectureTests) -> void: suite.run_unit())],
		["stat_block", _test_stat_block],
		["combat_rules", _test_combat_rules],
		["content", _test_content],
		["sprite_frames_whole", _test_sprite_frames_whole],
		["attack_preview_fans", _test_attack_preview_fans],
		["biome_content", _test_biome_content],
		["quests", _test_quests],
		["generation", _test_generation],
		["secret_rooms", _test_secret_rooms],
		["hidden_floor", _test_hidden_floor],
		["finale", _test_finale],
		["stairs_seal", _test_stairs_seal],
		["save_rules", _test_save_rules],
		["inventory_and_equipment", _test_inventory_and_equipment],
		["bag_stacks_and_dismantle", _test_bag_stacks_and_dismantle],
		["perks", _test_perks],
		["sustain", _test_sustain],
		["synergies", _test_synergies],
		["roles", _test_roles],
		["family_themes", _test_family_themes],
		["bestiary", _test_bestiary],
		["monster_ranks", _test_monster_ranks],
		["arenas", _test_arenas],
		["lighting", _test_lighting],
		["runes", _test_runes],
		["item_levels", _test_item_levels],
		["routes", _test_routes],
		["pacts", _test_pacts],
		["soul_tree", _test_soul_tree],
		["armory_levels", _test_armory_levels],
		["tree_reset_runs", _test_tree_reset_runs],
		["loader", _test_loader],
		["export_presets", _test_export_presets],
		["pilgrim_costs", _test_pilgrim_costs],
		["bosses", _test_bosses],
		["boss_slows", _test_boss_slows],
		["nameless_keeper", _test_nameless_keeper],
		["profile", _test_profile],
		["profile_damaged", _test_profile_damaged],
		["audit_regressions", func() -> void: await _part(AuditRegressionTests.new(), func(suite: AuditRegressionTests) -> void: await suite.run_unit())],
		["soul_economy", _test_soul_economy],
		["run_time", _test_run_time],
		["floor_size", _test_floor_size],
		["plateau_mist", _test_plateau_mist],
		["languages", _test_languages],
		["threshold", _test_threshold],
		["abyss", _test_abyss],
		["text_grid", _test_text_grid],
		["charged_attacks", _test_charged_attacks],
		["blows_in_four_directions", _test_blows_in_four_directions],
		["perf", func() -> void: await _part(PerfTests.new(), func(suite: PerfTests) -> void: suite.run_unit())],
		["sound", func() -> void: await _part(SoundTests.new(), func(suite: SoundTests) -> void: suite.run())],
		["vfx", func() -> void: await _part(VfxTests.new(), func(suite: VfxTests) -> void: suite.run())],
		["level", func() -> void: await _part(LevelTests.new(), func(suite: LevelTests) -> void: suite.run_unit())],
		["pacing", func() -> void: await _part(PacingTests.new(), func(suite: PacingTests) -> void: suite.run_unit())],
		["luck", func() -> void: await _part(LuckTests.new(), func(suite: LuckTests) -> void: suite.run_unit())],
		["floor_determinism", func() -> void: await _part(FloorDeterminismTests.new(), func(suite: FloorDeterminismTests) -> void: await suite.run_unit())],
		["debug", func() -> void: await _part(DebugTests.new(), func(suite: DebugTests) -> void: suite.run_unit())],
		["leaderboard", func() -> void: await _part(LeaderboardTests.new(), func(suite: LeaderboardTests) -> void: await suite.run_unit())],
		["privacy", func() -> void: await _part(PrivacyTests.new(), func(suite: PrivacyTests) -> void: await suite.run_unit())],
		["world_stats", func() -> void: await _part(WorldStatsTests.new(), func(suite: WorldStatsTests) -> void: await suite.run_unit())],
		["remote_config", func() -> void: await _part(RemoteConfigTests.new(), func(suite: RemoteConfigTests) -> void: await suite.run_unit())],
		["feedback", func() -> void: await _part(FeedbackTests.new(), func(suite: FeedbackTests) -> void: await suite.run_unit())],
		["cosmetics", func() -> void: await _part(CosmeticTests.new(), func(suite: CosmeticTests) -> void: await suite.run_unit())],
		["trials", func() -> void: await _part(TrialTests.new(), func(suite: TrialTests) -> void: suite.run_unit())],
		["online_session", func() -> void: await _part(OnlineSessionTests.new(), func(suite: OnlineSessionTests) -> void: await suite.run_unit())],
		["presence", func() -> void: await _part(PresenceTests.new(), func(suite: PresenceTests) -> void: await suite.run_unit())],
		["accounts", func() -> void: await _part(AccountTests.new(), func(suite: AccountTests) -> void: await suite.run_unit())],
		["talo_contract", func() -> void: await _part(TaloContractTests.new(), func(suite: TaloContractTests) -> void: await suite.run_unit())],
		["gear_look", func() -> void: await _part(GearLookTests.new(), func(suite: GearLookTests) -> void: suite.run())],
		["story", func() -> void: await _part(StoryTests.new(), func(suite: StoryTests) -> void: await suite.run_unit())],
		["pc", func() -> void: await _part(PcTests.new(), func(suite: PcTests) -> void: await suite.run_unit())],
		["bag", func() -> void: await _part(BagTests.new(), func(suite: BagTests) -> void: suite.run_bag_unit())],
		["dialogue", func() -> void: await _part(DialogueTests.new(), func(suite: DialogueTests) -> void: await suite.run_unit())],
		["core", func() -> void: await _part(CoreTests.new(), func(suite: CoreTests) -> void: suite.run_unit())],
	]


## A borrowed suite's part: `suite` in the tree while `body` runs on it, then freed.
func _part(suite: TestSuite, body: Callable) -> void:
	add_child(suite)
	await body.call(suite)
	suite.free()


## Text keeps whole pixels (Fonts, docs/design/interface.md "Text"): the font (Pixel Operator 8) is
## drawn sharp, on its 8-pixel grid, at sizes whose font pixel is a whole number of screen pixels
## at the UI's x1, x1.5 (a phone's 1080 lines) and x2: multiples of 16, SMALL the one documented
## exception; scenes and the theme use only those sizes, and outlines of one font pixel.
func _test_text_grid() -> void:
	var variation := Fonts.MAIN as FontVariation
	var font := variation.base_font as FontFile if variation else null
	check(font != null and font.resource_path == "res://assets/fonts/PixelOperator8.ttf", "the game's font is Pixel Operator 8")
	check(variation != null and variation.spacing_top % 2 == 0 and variation.spacing_bottom % 2 == 0 and variation.spacing_glyph == 0 and variation.spacing_space == 0, "the room over and under its lines is whole font pixels at BODY, its letters as drawn")
	check(font != null and font.antialiasing == TextServer.FONT_ANTIALIASING_NONE and font.hinting == TextServer.HINTING_NONE and font.subpixel_positioning == TextServer.SUBPIXEL_POSITIONING_DISABLED and not font.generate_mipmaps, "the pixel font is drawn sharp: no smoothing, no hinting, whole-pixel positions, no mipmaps")
	check(Fonts.GRID == 8 and is_equal_approx(font.get_ascent(Fonts.GRID * 10) + font.get_descent(Fonts.GRID * 10), Fonts.GRID * 10.0), "the font's em is %d pixels (ascent and descent fill it)" % Fonts.GRID)
	for font_size in Fonts.SIZES:
		if Fonts.WHOLE_SIZES.has(font_size):
			for stretch in [1.0, 1.5, 2.0]:
				var pixel: float = font_size * stretch / Fonts.GRID
				check(is_equal_approx(pixel, roundf(pixel)), "size %d: whole font pixels at x%s" % [font_size, stretch])
			check(font_size % (Fonts.GRID * 2) == 0, "size %d is on the 16-grid" % font_size)
		else:
			# The one exception (Fonts.SMALL): smaller than BODY, whole at x2 at least.
			check(font_size == Fonts.SMALL and font_size < Fonts.BODY and font_size * 2 % Fonts.GRID == 0, "size %d off the 16-grid is only the documented SMALL" % font_size)
	check(Fonts.WHOLE_SIZES.size() == Fonts.SIZES.size() - 1 and not Fonts.WHOLE_SIZES.has(Fonts.SMALL), "only SMALL is off the 16-grid")
	check(Fonts.outline_size(Fonts.BODY) == 8 and Fonts.outline_size(Fonts.TITLE) == 16 and Fonts.outline_size(Fonts.HUGE) == 24, "outlines are one font pixel (a quarter of a pixel per unit)")
	check(is_equal_approx(Fonts.cap_height(Fonts.BODY), 14.0) and is_equal_approx(Fonts.half_cap(Fonts.TITLE), 14.0), "a capital stands %d font pixels" % Fonts.CAPS)
	var theme: Theme = load("res://assets/theme/main_theme.tres")
	check(theme.default_font == Fonts.MAIN, "the theme's default font is the game's font (Pixel Operator 8)")
	check(Fonts.WHOLE_SIZES.has(theme.default_font_size) and theme.get_constant(&"outline_size", &"Label") == Fonts.outline_size(theme.default_font_size), "the theme's text is on the grid (%d, outline %d)" % [theme.default_font_size, theme.get_constant(&"outline_size", &"Label")])
	var spacing := theme.get_constant(&"line_spacing", &"Label")
	check(spacing % 2 == 0, "a Label's lines stay whole font pixels apart at BODY (line spacing %d)" % spacing)
	var off: Array[String] = []
	for path in _files_under("res://src", ".tscn"):
		var scene := (load(path) as PackedScene).instantiate()
		for line in _off_grid_texts(scene):
			off.append("%s %s" % [path.get_file(), line])
		scene.free()
	check(off.is_empty(), "every Label and Button in the scenes is on the font's grid: %s" % ", ".join(off.slice(0, 6)))


func _files_under(dir: String, extension: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(extension):
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_files_under(dir.path_join(sub), extension))
	return found


## Every hero's weapon has a charged attack in data, with valid effects, about 2.2 to 3 times a
## basic hit for the price of the charge; monsters' weapons have none. The charge's rules
## (AttackCharge): a tap never charges, a full charge fires on release, a cancel waits for the
## button to be let go.
## Melee blows in the body's four directions (Blow, docs/design/builds.md "Blows in four
## directions"): drawn toward the cardinal of the pose, their zone swept to the exact aim; shots,
## spins and spells placed far off stay at the exact aim; every blade blow of the hero's weapons
## (their skills and charged attacks) follows the facing.
func _test_blows_in_four_directions() -> void:
	for i in 32:
		var aim := Vector2.from_angle(TAU * i / 32.0)
		var way := Blow.cardinal(aim)
		var named := {&"right": Vector2.RIGHT, &"left": Vector2.LEFT, &"down": Vector2.DOWN, &"up": Vector2.UP}
		check(named[ActorRig.direction_name(aim)] == way, "four directions: the blow toward %.0f degrees is drawn the way the body faces (%s, %s)" % [rad_to_deg(aim.angle()), way, ActorRig.direction_name(aim)])
	var up_right := Vector2.from_angle(deg_to_rad(-30.0))
	var blow := Blow.at(Vector2.ZERO, up_right)
	check(blow.facing == Vector2.RIGHT and blow.aim.is_equal_approx(up_right), "four directions: a blow at an enemy 30 degrees up from the right is struck to the right")
	var rapier := deg_to_rad(30.0) * 0.5
	check(blow.in_arc(up_right * 40.0, rapier), "four directions: a narrow thrust still reaches the enemy it was aimed at")
	check(blow.in_arc(Vector2.RIGHT * 40.0, rapier) and blow.in_arc(Vector2.from_angle(deg_to_rad(12.0)) * 40.0, rapier), "four directions: and hits what it draws, to the right")
	check(blow.in_arc(Vector2.from_angle(deg_to_rad(-42.0)) * 40.0, rapier), "four directions: and what the same blow aimed straight would have hit")
	check(not blow.in_arc(Vector2.from_angle(deg_to_rad(-50.0)) * 40.0, rapier) and not blow.in_arc(Vector2.from_angle(deg_to_rad(20.0)) * 40.0, rapier), "four directions: but nothing outside its sweep")
	for degrees: float in [45.0, -45.0, 135.0, -135.0, 40.0, -100.0]:
		var aim := Vector2.from_angle(deg_to_rad(degrees))
		var diagonal := Blow.at(Vector2(10, 20), aim)
		check(diagonal.in_arc(Vector2(10, 20) + aim * 50.0, deg_to_rad(11.0)), "four directions: an enemy on a diagonal (%.0f degrees) is still hit by the narrowest blow (the whip's 22)" % degrees)
		var cone := diagonal.cone(deg_to_rad(60.0))
		for edge: float in [-60.0, 60.0]:
			for from: Vector2 in [diagonal.facing, diagonal.aim]:
				var point := Vector2(10, 20) + from.rotated(deg_to_rad(edge) * 0.999) * 30.0
				check(absf(angle_difference(cone.x, (point - Vector2(10, 20)).angle())) <= cone.y + 0.001, "four directions: an enemy's warning cone covers the whole swept zone (%.0f degrees)" % degrees)
	var shot := Blow.of_weapon(Vector2.ZERO, up_right, load("res://data/items/weapons/bow.tres") as WeaponDef)
	check(shot.facing.is_equal_approx(up_right), "four directions: a shot is no blow, it flies at the exact aim")
	var slam := Blow.of_weapon(Vector2.ZERO, up_right, load("res://data/items/weapons/monster/slam.tres") as WeaponDef)
	check(slam.facing.is_equal_approx(up_right) and slam.in_arc(Vector2.LEFT * 10.0, PI), "four directions: a blow all around stays as it is")
	var katana_blow := Blow.of_weapon(Vector2.ZERO, up_right, load("res://data/items/weapons/katana.tres") as WeaponDef)
	check(katana_blow.facing == Vector2.RIGHT, "four directions: a katana's blow follows the body's pose")
	# The data: every blade blow of a hero's weapon follows the facing; spins and spells don't need to.
	var blades := 0
	for file in DirAccess.get_files_at("res://data/items/weapons"):
		if not file.ends_with(".tres"):
			continue
		var weapon := load("res://data/items/weapons/" + file) as WeaponDef
		if weapon.kind != WeaponDef.Kind.MELEE:
			continue
		var effects: Array[Effect] = []
		if weapon.charged:
			effects.append_array(weapon.charged.effects)
		for skill in weapon.skills:
			effects.append_array(skill.effects)
		for effect in effects:
			var area := effect as DamageAreaEffect
			if area and area.slash and area.slash.shape != SlashDef.Shape.SPIN:
				blades += 1
				check(area.follows_facing, "four directions: %s: its blade blow (%s) follows the body's four directions" % [weapon.id, area.slash.resource_path.get_file() if area.slash.resource_path else "a crescent"])
			var strike := effect as DashStrikeEffect
			if strike and not strike.moves:
				blades += 1
				check(strike.follows_facing, "four directions: %s: its thrust from where he stands follows the body's four directions" % weapon.id)
	check(blades >= 12, "four directions: the hero's blade blows checked (%d)" % blades)
	for path in ["res://data/skills/player/thunder.tres", "res://data/skills/player/arrow_rain.tres", "res://data/skills/player/fissure.tres"]:
		for effect in (load(path) as SkillDef).effects:
			if effect is DamageAreaEffect:
				check(not (effect as DamageAreaEffect).follows_facing, "four directions: %s is a spell placed far off, at the exact aim" % path.get_file())


func _test_charged_attacks() -> void:
	var player_def := load("res://data/player/player_def.tres") as PlayerDef
	check(player_def.charge_delay >= 0.18 and player_def.charge_delay <= 0.25, "charged: a tap never charges (the delay is %.2f s)" % player_def.charge_delay)
	check(player_def.charge_full_sound != null, "charged: a full charge has its sound")
	var weapons := 0
	for file in DirAccess.get_files_at("res://data/items/weapons"):
		if not file.ends_with(".tres"):
			continue
		var weapon := load("res://data/items/weapons/" + file) as WeaponDef
		var charged := weapon.charged
		weapons += 1
		check(charged != null, "charged: %s has a charged attack" % weapon.id)
		if charged == null:
			continue
		check(charged.id == weapon.id and charged.resource_path.begins_with("res://data/skills/charged/"), "charged: %s's is its own (data/skills/charged/%s.tres)" % [weapon.id, weapon.id])
		check(not charged.display_name.is_empty() and not charged.description.is_empty(), "charged: %s's has a name and a description" % weapon.id)
		check(charged.charge_time >= 0.6 and charged.charge_time <= 1.3, "charged: %s charges in 0.6-1.3 s (%.2f)" % [weapon.id, charged.charge_time])
		check(charged.move_speed_scale > 0.2 and charged.move_speed_scale < 1.0, "charged: %s slows the hero while charging" % weapon.id)
		check(not charged.effects.is_empty() and charged.effects.all(func(e: Effect) -> bool: return e != null), "charged: %s's effects are all there" % weapon.id)
		# One target's share: every hit of every effect (a fan's stars all landing).
		var total := 0.0
		for effect in charged.effects:
			var multiplier: float = effect.get("damage_multiplier") if effect.get("damage_multiplier") != null else 0.0
			var shots: int = effect.get("count") if effect is ProjectileEffect else 1
			total += multiplier * shots
		var basic := weapon.projectile_damage * weapon.projectile_count if weapon.kind == WeaponDef.Kind.RANGED else 1.0
		var ratio := total / basic
		check(ratio >= 2.2 and ratio <= 3.0, "charged: %s's hits %.2fx a basic attack (2.2-3)" % [weapon.id, ratio])
		check(weapon.get_details().contains(charged.describe()) and charged.describe().begins_with("Hold: "), "charged: %s's card says it (%s)" % [weapon.id, charged.describe()])
	check(weapons >= 16, "charged: every hero's weapon checked (%d)" % weapons)
	for file in DirAccess.get_files_at("res://data/items/weapons/monster"):
		if file.ends_with(".tres"):
			check((load("res://data/items/weapons/monster/" + file) as WeaponDef).charged == null, "charged: monsters' weapons have none (%s)" % file)
	var frost := (load("res://data/items/weapons/stick.tres") as WeaponDef).charged
	var shard := frost.effects[0] as ProjectileEffect
	check(shard and shard.nova_burst and shard.explosion_radius > 0.0 and shard.element == VfxElementDef.named(&"frost") and shard.status and shard.status.slow > 0.0, "charged: the Frost Staff's great shard shatters into a chilling frost nova")
	check(shard.sheet and shard.sheet.frame_size() == Vector2i(24, 24) and shard.sheet.texel == 2 and shard.sheet.directions == 16, "charged: the great shard is drawn bigger in 16 directions, at the art's 2x (not stretched)")
	check((load("res://data/items/weapons/magic_wand.tres") as WeaponDef).charged.effects[0] is ChainLightningEffect, "charged: the Spark Wand's bolt chains")
	check(((load("res://data/items/weapons/hammer.tres") as WeaponDef).charged.effects[0] as DamageAreaEffect).explosive, "charged: the War Hammer slams the ground")
	check(((load("res://data/items/weapons/bow.tres") as WeaponDef).charged.effects[0] as ProjectileEffect).pierce >= 10, "charged: the Bow's heavy arrow runs through")
	check(not ((load("res://data/items/weapons/lance.tres") as WeaponDef).charged.effects[0] as DashStrikeEffect).moves, "charged: the Lance thrusts without moving")

	var charge := AttackCharge.new()
	var delay := 0.22
	charge.press()
	check(charge.hold(0.1, delay, 0.8) == -1 and not charge.is_charging(), "charged: held 0.1 s is still a tap")
	check(not charge.release() and charge.state == AttackCharge.State.IDLE, "charged: a tap let go fires nothing more")
	charge.press()
	charge.hold(0.1, delay, 0.8)
	check(charge.hold(0.15, delay, 0.8) == AttackCharge.State.CHARGING and charge.is_charging(), "charged: past the delay it charges")
	check(not charge.is_full() and charge.ratio > 0.0 and charge.ratio < 0.1, "charged: ...from empty (%.2f)" % charge.ratio)
	charge.hold(0.4, delay, 0.8)
	check(charge.ratio > 0.4 and charge.ratio < 0.7 and not charge.is_full(), "charged: it fills over the charge time")
	check(charge.hold(0.5, delay, 0.8) == AttackCharge.State.FULL and charge.is_full(), "charged: then it is full")
	check(charge.release() and charge.state == AttackCharge.State.IDLE, "charged: let go full: it goes off")
	charge.press()
	charge.hold(0.4, delay, 0.5)
	check(not charge.release(), "charged: let go before full: wasted")
	charge.press()
	charge.hold(2.0, delay, 0.5)
	charge.cancel()
	check(charge.state == AttackCharge.State.SPENT and not charge.is_charging(), "charged: a roll cancels it")
	charge.hold(2.0, delay, 0.5)
	check(not charge.is_charging() and not charge.release(), "charged: cancelled, it waits for the button to be let go")


## Speedrun times: how they read, the splits, the save, the records.
func _test_run_time() -> void:
	check(TimeText.of(0.0) == "0:00.00", "time zero: got %s" % TimeText.of(0.0))
	check(TimeText.of(65.432) == "1:05.43", "minutes, seconds, hundredths: got %s" % TimeText.of(65.432))
	check(TimeText.of(65.999, 1) == "1:05.9", "cut, never rounded up: got %s" % TimeText.of(65.999, 1))
	check(TimeText.of(3725.5, 0) == "1:02:05", "hours when there are some: got %s" % TimeText.of(3725.5, 0))
	check(TimeText.delta(-5.25) == "-0:05.2" and TimeText.delta(12.0) == "+0:12.0", "ahead or behind: got %s / %s" % [TimeText.delta(-5.25), TimeText.delta(12.0)])

	var rng := RandomNumberGenerator.new()
	var state := RunState.create(CONTENT, {}, rng)
	check(state.time == 0.0 and state.splits.is_empty() and state.finish_time < 0.0, "a new run starts at zero")
	state.time = 30.0
	state.split(1)
	state.time = 75.0
	state.split(3)  # (a floor skipped: the debug panel)
	check(state.splits.size() == 3 and state.splits[0] == 30.0 and state.splits[1] == 75.0 and state.splits[2] == 75.0, "splits: the time at the end of each floor (%s)" % [state.splits])
	state.time = 80.0
	check(state.run_time() == 80.0, "the time so far")
	state.finish_time = 78.5
	check(state.run_time() == 78.5, "won: the win's time")
	var again := RunState.create(CONTENT, state.to_data(), rng)
	check(again.time == 80.0 and again.finish_time == 78.5 and again.splits == state.splits, "the time and splits are saved with the run")
	check(state.record_key() == String(state.difficulty.id), "records by difficulty (%s)" % state.record_key())
	var daily := RunState.create(CONTENT, {}, rng, 20000)
	check(daily.record_key() == "", "a daily run keeps no record")
	var rows := state.summary_rows(CONTENT, 3)
	check(rows.any(func(row: Array) -> bool: return row[0] == "Time" and str(row[1]).begins_with("1:18.50")), "the end-of-run numbers give the time: %s" % [rows])

	var splits: Array[float] = [30.0, 60.0, 95.0]
	check(Profile.record_time("normal", 95.0, splits), "a first win is a record")
	check(is_equal_approx(Profile.best_time("normal"), 95.0) and is_equal_approx(Profile.best_split("normal", 2), 60.0), "the record and its splits are kept")
	check(not Profile.record_time("normal", 120.0, splits), "a slower win is not")
	check(Profile.record_time("normal", 90.0, splits) and is_equal_approx(Profile.best_time("normal"), 90.0), "a faster one is")
	check(Profile.best_time("hard") == 0.0 and Profile.best_split("normal", 9) == 0.0 and Profile.best_time("") == 0.0, "nothing where nothing was won")
	check(not Profile.record_time("", 10.0, splits), "no record without a key (daily runs)")
	var path := "user://test_profile_time_%d.json" % OS.get_process_id()
	Profile.save_path = path
	Profile.save_profile()
	Profile.best_times = {}
	Profile.best_splits = {}
	Profile.load_profile()
	check(is_equal_approx(Profile.best_time("normal"), 90.0) and is_equal_approx(Profile.best_split("normal", 3), 95.0), "records are saved with the profile")
	Profile.save_path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Profile.best_times = {}
	Profile.best_splits = {}
	# A run won at the bottom of the Well is a longer race: its own record, the first win's kept.
	var deep := RunState.create(CONTENT, {}, rng)
	deep.finale_open = true
	check(deep.goes_to_bottom() and deep.record_key() == String(deep.difficulty.id) + "/bottom" and RunState.is_bottom_record(deep.record_key()) and not RunState.is_bottom_record(state.record_key()), "a run to the bottom is raced under its own record (%s)" % deep.record_key())
	var deep_again := RunState.create(CONTENT, deep.to_data(), rng)
	check(deep_again.record_key() == deep.record_key(), "...still when the run is picked up again")
	check(Profile.record_time(deep.record_key(), 200.0, splits) and Profile.best_time("normal") == 0.0 and is_equal_approx(Profile.best_time("normal/bottom"), 200.0), "a win at the bottom doesn't take the first win's record, nor the other way")
	check(Profile.record_time("normal", 85.0, splits) and is_equal_approx(Profile.best_time("normal"), 85.0) and is_equal_approx(Profile.best_time("normal/bottom"), 200.0), "a faster first win leaves the bottom's record alone")
	Profile.best_times = {}
	Profile.best_splits = {}


func _test_stat_block() -> void:
	var a := StatBlock.new()
	a.max_hp = 10
	a.attack = 2
	var b := StatBlock.new()
	b.attack = 3
	b.defense = 1
	var sum := a.plus(b)
	check(sum.max_hp == 10 and sum.attack == 5 and sum.defense == 1, "StatBlock.plus adds every stat")
	check(a.attack == 2, "StatBlock.plus does not modify its operands")
	check(b.describe() == "+3 damage, +1 armor", "StatBlock.describe: got '%s'" % b.describe())
	var tripled := b.times(3)
	check(tripled.attack == 9 and tripled.defense == 3 and b.attack == 3, "StatBlock.times multiplies a copy")
	var fast := StatBlock.new()
	fast.attack_speed = 0.25
	check(is_equal_approx(a.plus(fast).attack_speed, 0.25), "attack speed adds up")
	check(fast.describe() == "+25% attack speed", "attack speed is described: got '%s'" % fast.describe())


func _test_combat_rules() -> void:
	check(Combat.mitigate(10, 3) == 8, "defense softens a hit: 10 x 10 / (10 + 3)")
	check(Combat.mitigate(10, 0) == 10 and Combat.mitigate(10, -2) == 12, "no armor: the hit in full; negative armor adds")
	check(Combat.mitigate(2, 50) == 1, "a hit always deals at least 1")
	# Diminishing returns: armor is worth about its points against big hits, never makes a hit
	# harmless (flat armor brought every act IV monster hit on a 36-armor build down to 1).
	check(Combat.mitigate(35, 5) >= 30 and Combat.mitigate(35, 5) <= 31, "a big hit loses about the armor's points")
	check(Combat.mitigate(20, 20) == 10, "armor the size of the hit halves it")
	check(Combat.mitigate(20, 36) == 7 and Combat.mitigate(14, 36) >= 3, "high armor never makes ordinary hits harmless")
	var previous := 1000
	for armor in range(0, 61, 4):
		var dealt := Combat.mitigate(30, armor)
		check(dealt <= previous and dealt >= 1, "more armor never lets more through (%d armor: %d)" % [armor, dealt])
		previous = dealt
	# Floor rules: difficulty x event x depth, in one place.
	var nightmare := CONTENT.get_difficulty(&"nightmare")
	var blood_moon: FloorEventDef = load("res://data/floor_events/blood_moon.tres")
	var plain := FloorRules.make(CONTENT.dungeon, null, null, 1)
	var hard := FloorRules.make(CONTENT.dungeon, nightmare, blood_moon, 5)
	var act_one := CONTENT.dungeon.act_for_depth(1)
	var act_two := CONTENT.dungeon.act_for_depth(5)
	check(is_equal_approx(plain.monster_damage(), act_one.monster_damage) and is_equal_approx(plain.monster_damage(true), 1.0), "no difficulty: the act's own threat for its monsters, none for bosses")
	check(plain.dungeon_damage(4) == 5, "no difficulty: a trap deals its own damage (trap 4 + depth 1)")
	check(is_equal_approx(hard.monster_damage(), act_two.monster_damage * nightmare.monster_damage * blood_moon.monster_damage), "the act's threat, the difficulty and the event multiply")
	check(is_equal_approx(hard.monster_hp(true), nightmare.boss_hp * blood_moon.monster_hp) and is_equal_approx(hard.monster_damage(true), nightmare.monster_damage * blood_moon.monster_damage), "a boss leaves the act's threat out (tuned one by one)")
	check(hard.dungeon_damage(4) == roundi(9 * nightmare.monster_damage * blood_moon.monster_damage), "dungeon damage grows with depth and the difficulty's and event's multipliers")
	# Keeper's curve (balance-log 2026-10-22): act I gentle, acts II and III carry their own
	# threat (floors 4-8 were a stroll), act IV as the owner likes it; a nudge, never a wall.
	var acts := CONTENT.dungeon.acts
	check(acts[0].monster_hp == 1.0 and acts[0].monster_damage == 1.0, "act I's monsters keep the depth's own numbers: floors 1-2 are where a player learns")
	check(acts[1].monster_hp > 1.0 and acts[1].monster_damage > 1.0 and acts[2].monster_hp > 1.0 and acts[2].monster_damage > 1.0, "acts II and III add their own threat to their monsters")
	check(acts[3].monster_hp == 1.0 and acts[3].monster_damage == 1.0, "act IV's monsters keep the depth's own numbers")
	for act in acts:
		check(act.monster_hp <= 1.5 and act.monster_damage <= 1.5, "an act's own threat is a nudge, x1.5 at most (%s)" % act.title)
	check(hard.gold(10) == roundi(10 * blood_moon.gold), "the event changes the gold")
	var slime: MonsterDef = load("res://data/monsters/slime.tres")
	check(hard.scale_monster(slime.stats, false).max_hp > plain.scale_monster(slime.stats, false).max_hp and roundi(slime.stats.max_hp * act_one.monster_hp) == plain.scale_monster(slime.stats, false).max_hp, "monster stats scale without touching the def")


func _test_content() -> void:
	var chances: Array = []
	for id in [&"easy", &"normal", &"hard", &"nightmare"]:
		chances.append(CONTENT.get_difficulty(id).curse_chance)
	check(chances[0] < chances[1] and chances[1] < chances[2] and chances[2] < chances[3], "curses: rare on Easy, often on Nightmare %s" % str(chances))
	check(CONTENT.player != null and CONTENT.dungeon != null, "content db has player and dungeon config")
	var unlisted := BalanceContent.unlisted(CONTENT)
	check(unlisted.is_empty(), "every content file appears in a run: listed in content_db.tres, an act, the bottom of the Well or the hidden floor (%s)" % ", ".join(unlisted))
	check(CONTENT.all_monsters().size() >= 20, "a big bestiary (%d monsters)" % CONTENT.all_monsters().size())
	var ids := {}
	for monster in CONTENT.all_monsters():
		check(monster.weapon != null, "%s has a weapon" % monster.id)
		check(monster.stats != null and monster.stats.max_hp > 0, "%s has HP" % monster.id)
		check(not ids.has(monster.id), "duplicate id %s" % monster.id)
		ids[monster.id] = true
	for item in CONTENT.items:
		check(not item.display_name.is_empty(), "%s has a name" % item.id)
		check(not ids.has(item.id), "duplicate id %s" % item.id)
		ids[item.id] = true
	var rng := RandomNumberGenerator.new()
	for depth in range(1, 8):
		check(CONTENT.pick_monster(depth, rng) != null, "a monster can spawn at depth %d" % depth)
		check(CONTENT.pick_item(depth, rng) != null, "an item can spawn at depth %d" % depth)
	var act_one := CONTENT.dungeon.acts[0]
	check(act_one.monsters.has(CONTENT.pick_monster(1, rng)), "floors spawn monsters of their act")
	var too_early := false
	for i in 300:
		var picked := CONTENT.pick_monster(1, rng)
		too_early = too_early or picked.min_depth > 1
	check(not too_early, "no monster before its min_depth")
	check(CONTENT.dungeon.acts[2].monsters.has(CONTENT.pick_monster(8, rng)), "act 3 floors spawn act 3 monsters")
	check(CONTENT.sounds != null, "content db has a sound bank")
	for property in CONTENT.sounds.get_property_list():
		if property.type == TYPE_OBJECT and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			check(CONTENT.sounds.get(property.name) != null, "sound bank: %s is set" % property.name)
	for item in CONTENT.items:
		if item is WeaponDef:
			check(item.attack_sound != null, "%s has an attack sound" % item.id)
		check(item.icon != null, "%s has an icon" % item.id)
	for monster in CONTENT.all_monsters():
		check(monster.frames != null and monster.frames.has_animation(&"walk_down"), "%s is animated" % monster.id)
		check(monster.icon != null, "%s has a sprite" % monster.id)
	for item in CONTENT.items:
		if item is WeaponDef:
			check(item.skills.size() == 2, "%s grants 2 skills" % item.id)
			for skill in item.skills:
				check(skill != null and skill.icon != null and skill.cooldown > 0.0 and not skill.effects.is_empty(), "%s: skill set up" % item.id)
		if item is SkillTomeDef:
			check(item.skill != null and item.skill.icon != null, "%s teaches a skill" % item.id)
			check(item.get_details().begins_with(item.description), "%s: its card opens on the tome's own line" % item.id)
	check(CONTENT.items.any(func(i: ItemDef) -> bool: return i is SkillTomeDef), "tomes can be found")
	for item in CONTENT.items + CONTENT.locked_items:
		check(item.resource_path.begins_with("res://data/items/") and not item.resource_path.contains("::"), "%s is its own file (saves point to it)" % item.id)
		check(item.value > 0, "%s has a price" % item.id)
	check(CONTENT.item_affixes.size() >= 10 and CONTENT.dungeon.merchant != null, "affixes and the merchant are set")
	check(CONTENT.props.size() >= 3, "props listed")
	for prop in CONTENT.props:
		check(prop.icon != null and prop.is_breakable(), "%s is a breakable prop with a sprite" % prop.id)
	check(CONTENT.props.any(func(p: PropDef) -> bool: return p.is_explosive()), "there is an explosive prop")
	for act in CONTENT.dungeon.acts:
		check(act.hazards.size() >= 4, "%s has its hazards" % act.title)
		check(act.hazards.any(func(h: HazardDef) -> bool: return h.min_depth <= 1), "%s has hazards from its first floor" % act.title)
	var hazards := CONTENT.all_hazards()
	for hazard in hazards:
		if hazard is ArrowTrapDef:
			check(hazard.launcher_texture != null and hazard.arrow_texture != null and hazard.damage > 0, "%s has a slit, arrows and damage" % hazard.id)
		elif hazard is TrapDef:
			check(hazard.active_sheet != null and hazard.damage > 0, "%s has art and damage" % hazard.id)
		elif hazard is PitDef:
			check(hazard.tileset != null and hazard.fall_damage > 0.0, "%s has art and hurts" % hazard.id)
			check(not hazard.is_crumbling() or hazard.crack_texture != null, "%s shows its cracks" % hazard.id)
		elif hazard is QuicksandDef:
			check(hazard.sheet != null and hazard.slow > 0.0, "%s has art and slows" % hazard.id)
	for kind: Script in [TrapDef, ArrowTrapDef, PitDef, QuicksandDef]:
		check(hazards.any(func(h: HazardDef) -> bool: return h.get_script() == kind), "a hazard of each kind (%s)" % kind.get_global_name())
	check(hazards.any(func(h: HazardDef) -> bool: return h is PitDef and h.is_crumbling()), "there is crumbling floor")
	check(CONTENT.elite_affixes.size() >= 5, "elite affixes listed")
	for affix in CONTENT.elite_affixes:
		check((affix.perk != null or not affix.traits.is_empty()) and not affix.display_name.is_empty(), "%s elite affix supplies a perk or behaviours" % affix.id)
	check(CONTENT.dungeon.chest != null and CONTENT.dungeon.chest.trapped_chance > 0.0 and CONTENT.dungeon.ambush_chest != null, "chests and ambush rewards set")
	check(CONTENT.all_monsters().any(func(m: MonsterDef) -> bool: return m.flies), "some monsters fly")
	check(CONTENT.sounds.fall != null and CONTENT.sounds.ambush != null and CONTENT.sounds.soul != null, "falls, ambushes and souls have sounds")
	var story := CONTENT.story
	check(story != null and story.title == "The Well of Souls" and not story.tagline.is_empty(), "the game has its name")
	check(story.intro_pages.size() >= 4 and not story.victory_text.is_empty() and story.death_lines.size() >= 2, "the story is written")
	check(CONTENT.floor_events.size() >= 5, "special floors listed")
	for act in CONTENT.dungeon.acts:
		check(act.all_bosses().size() >= 2, "%s has two possible bosses" % act.title)
		for boss in act.all_bosses():
			check(boss.portrait != null and boss.frames != null and boss.frames.has_animation(&"idle"), "%s has a portrait and animations" % boss.id)
			check(not boss.skills.is_empty() and boss.phases.size() >= 1 and not boss.title.is_empty(), "%s has skills, phases and a title" % boss.id)
	for act in CONTENT.dungeon.acts:
		check(not act.lore.is_empty(), "%s has its story line" % act.title)
		check(act.boss and not act.boss.title.is_empty(), "%s's boss has a title" % act.title)
	check(CONTENT.dungeon.room_light != null and CONTENT.dungeon.room_light.light_level > 0, "rooms get lanterns")


func _test_generation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in 100:
		var map := DungeonGenerator.generate(CONTENT.dungeon, rng)
		check(map.rooms.size() >= 4, "enough rooms (%d)" % map.rooms.size())
		var reachable := _flood(map, map.start_cell)
		for room in map.rooms:
			check(reachable.has(room.get_center()), "room %s reachable" % room)
		check(reachable.has(map.stairs_cell), "stairs reachable")
		check(map.start_cell != map.stairs_cell, "stairs not on start")
		# Only solid-looking walls: none thinner than DungeonGenerator.MIN_WALL_THICKNESS between floors, no corner-only contact.
		var bad := _bad_wall_cells(map)
		check(bad.is_empty(), "no thin walls or pinches (%s)" % str(bad.slice(0, 3)))
		# Border must stay solid so nothing can leave the map.
		for x in map.width:
			check(not map.is_floor(Vector2i(x, 0)) and not map.is_floor(Vector2i(x, map.height - 1)), "closed border")
			break


## Secret rooms (SecretRoomPlan): planned off a room, behind rock, reachable only through their
## crack once it breaks; never on the main path; the same for the same seed.
func _test_secret_rooms() -> void:
	var config := CONTENT.dungeon
	check(config.secret_room_chance > 0.0 and config.secret_rooms_max >= 1 and config.cracked_wall != null, "floors may hide a secret room (dungeon_config.tres)")
	check(config.secret_rewards.size() >= 4 and config.secret_rewards.all(func(r: SecretRewardDef) -> bool: return r.spawn_weight > 0 and not r.display_name.is_empty()), "secret rooms hold one of several rewards, by weight")
	var kinds := {}
	for reward in config.secret_rewards:
		kinds[reward.get_script()] = true
	check(kinds.size() >= 4, "chests, shrines, items and gold among them (%d kinds)" % kinds.size())
	var chance := config.secret_room_chance
	config.secret_room_chance = 1.0
	var rng := RandomNumberGenerator.new()
	var planned := 0
	var upward := 0
	for i in 60:
		rng.seed = 7000 + i
		var map := DungeonGenerator.generate(config, rng, 1.0 + (i % 3) * 0.2, 1.0 + (i % 3) * 0.4)
		if map.secrets.is_empty():
			continue
		planned += 1
		var before := _flood(map, map.start_cell)
		var stairs_distance := _distance(map, map.start_cell, map.stairs_cell)
		for plan in map.secrets:
			upward += 1 if plan.direction == Vector2i.UP else 0
			var cells := plan.cells()
			check(cells.all(func(c: Vector2i) -> bool: return not map.is_floor(c)), "a secret room is rock until it opens")
			check(plan.host > 0 and not map.exit_cells().any(func(c: Vector2i) -> bool: return map.rooms[plan.host].grow(1).has_point(c)), "never off the first room nor a room with the stairs")
			check(plan.crack.all(func(c: Vector2i) -> bool: return map.rooms[plan.host].has_point(c - plan.direction)), "its crack is on its room's wall")
		var opened := DungeonMap.new(map.width, map.height, map.tile_size)
		opened.tiles = map.tiles.duplicate()
		opened.rooms = map.rooms
		var inside := {}
		for plan in map.secrets:
			for cell in plan.cells():
				opened.set_floor(cell)
				inside[cell] = true
		# Its only way in is through its crack.
		var doors: Array[Vector2i] = []
		for cell: Vector2i in inside:
			for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if map.is_floor(cell + dir):
					doors.append(cell)
		var cracks: Array[Vector2i] = []
		for plan in map.secrets:
			cracks.append_array(plan.crack)
		check(not doors.is_empty() and doors.all(func(c: Vector2i) -> bool: return cracks.has(c)), "a secret room touches the floor only at its crack")
		var after := _flood(opened, map.start_cell)
		check(map.secrets.all(func(plan: SecretRoomPlan) -> bool: return after.has(plan.room.get_center())), "broken open, it is reachable")
		check(not before.keys().any(func(c: Vector2i) -> bool: return inside.has(c)), "the main path never goes through it")
		check(_distance(opened, map.start_cell, map.stairs_cell) == stairs_distance, "and opening it never shortens the way to the stairs")
		var bad := _bad_wall_cells(opened)
		check(bad.is_empty(), "opened, no thin walls or pinches (%s)" % str(bad.slice(0, 3)))
		var again_rng := RandomNumberGenerator.new()
		again_rng.seed = 7000 + i
		var again := DungeonGenerator.generate(config, again_rng, 1.0 + (i % 3) * 0.2, 1.0 + (i % 3) * 0.4)
		check(again.secrets.size() == map.secrets.size() and again.secrets[0].room == map.secrets[0].room and again.secrets[0].crack == map.secrets[0].crack, "the same seed hides the same secret rooms")
	check(planned >= 40, "most floors find room for a secret (%d of 60)" % planned)
	check(upward > 0, "some behind a cliff face")
	config.secret_room_chance = 0.0
	rng.seed = 7001
	check(DungeonGenerator.generate(config, rng).secrets.is_empty(), "chance 0: no secret room")
	config.secret_room_chance = chance
	# The secrets have their own stream: with or without them, the rest of a floor is the same.
	rng.seed = 99
	var with_secrets := DungeonGenerator.generate(config, rng)
	var next_with := rng.randi()
	config.secret_room_chance = 0.0
	rng.seed = 99
	var without := DungeonGenerator.generate(config, rng)
	config.secret_room_chance = chance
	check(with_secrets.tiles == without.tiles and rng.randi() == next_with, "secret rooms change nothing else on the floor")


## Steps from `from` to `to` on the floor (-1: no way).
func _distance(map: DungeonMap, from: Vector2i, to: Vector2i) -> int:
	var steps := { from: 0 }
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if cell == to:
			return steps[cell]
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + dir
			if map.is_floor(next) and not steps.has(next):
				steps[next] = steps[cell] + 1
				queue.append(next)
	return -1


## The hidden floor's data: its key, its acts, its floor and its boss, balanced between the two
## acts' bosses; and its map (a way in, one arena).
## The bottom of the Well (FinaleDef): its data, the gate, the save rules, its numbers.
func _test_finale() -> void:
	var config := CONTENT.dungeon
	var finale := config.finale
	check(finale != null and finale.boss != null and finale.biome != null and finale.arena != null, "the bottom of the Well has its boss, its look and its arena")
	if finale == null or finale.boss == null:
		return
	var forms := finale.boss.forms()
	check(forms.size() == 2 and finale.final_boss() == forms[1] and finale.boss.last_form() == forms[1], "two forms: Tôma, then the Maw")
	check(not config.acts.any(func(act: ActDef) -> bool: return act.all_bosses().has(forms[0]) or act.all_bosses().has(forms[1]) or act.biomes.has(finale.biome)), "they and the bottom's world belong to no act")
	for form in forms:
		check(form.portrait != null and form.frames != null and form.frames.has_animation(&"idle") and form.frames.has_animation(&"dead") and form.frames.has_animation(&"attack"), "%s has a portrait and its animations" % form.id)
		check(form.body_stays and form.phases.size() == 2 and not form.title.is_empty(), "%s keeps its body, has two phases and a title" % form.id)
		check(form.chronicle != null and not form.chronicle.waking_lines.is_empty() and not form.chronicle.last_words.is_empty(), "%s has its story, its waking and its last words (its chronicle)" % form.id)
		check(form.phases[1].windup_multiplier < form.phases[0].windup_multiplier and form.phases[1].cooldown_multiplier < form.phases[0].cooldown_multiplier, "%s: its last phase is faster" % form.id)
	var toma := forms[0]
	check(toma.frames.has_animation(&"intro") and toma.frames.has_animation(&"cast") and toma.frames.has_animation(&"windup"), "Tôma wakes (intro), raises his lantern (cast), draws his blade (windup)")
	check(toma.relic_choices == 0 and toma.arena_anchor.y > 0.5 and toma.waits_intro, "Tôma: no relic (the fight goes on), kneeling below the middle, his waking a moment of its own")
	var kinds := {}
	for skill: SkillDef in toma.skills + toma.phases[0].skills + toma.phases[1].skills:
		for effect in skill.effects:
			kinds[effect.get_script()] = true
	check(kinds.has(DashStrikeEffect) and kinds.has(DamageAreaEffect) and kinds.has(GroundStrikeEffect), "Tôma fights with the hero's techniques: a dash strike, a charged slash, the lantern")
	var slash: SkillDef = toma.phases[0].skills.filter(func(s: SkillDef) -> bool: return s.effects[0] is DamageAreaEffect)[0]
	check(slash.cast_time >= 1.0 and slash.cast_animation == &"windup", "his wide slash has a long wind-up")
	var maw := forms[1]
	var jaw := maw.traits[0] as WeakPointTrait if not maw.traits.is_empty() else null
	check(jaw != null and jaw.rooted and maw.knockback_resistance >= 1.0, "the Maw: a weak point, rooted, never pushed")
	if jaw:
		check(jaw.closed_times.size() == 3 and jaw.closed_times[2] < jaw.closed_times[1] and jaw.closed_times[1] < jaw.closed_times[0], "its phases shorten the closed time")
		check(jaw.open_times[0] >= 3.0 and jaw.open_times[0] <= 4.0, "its window: 3-4 s")
		check(maw.frames.has_animation(jaw.open_animation) and maw.frames.has_animation(jaw.open_pose), "its jaw opens (an animation, then the open pose)")
		check(jaw.pull_speed < CONTENT.player.base_stats.move_speed * 0.5, "its pull never outruns the hero")
	check(maw.shockwave_after_hits == 0 and maw.phases.all(func(p: BossPhase) -> bool: return p.shockwave_after_hits == 0), "no shockwave for hitting the open jaw (its bite answers)")
	check(maw.arena_anchor.y < 0.3 and maw.relic_choices > 0 and maw.loot != null, "the Maw rises at the top of the arena; its relic and its spoils")
	var summons := maw.phases[1].skills.filter(func(s: SkillDef) -> bool: return s.effects[0] is SummonEffect)
	check(not summons.is_empty() and (summons[0].effects[0] as SummonEffect).monsters.all(func(m: MonsterDef) -> bool: return CONTENT.abyss_monsters().has(m)), "it calls the Damned (the Deeps' demons)")
	check(maw.phases[1].skills.size() > maw.skills.size(), "its last phase adds attacks")
	# The endings: two, counted for their achievements.
	var stats := AchievementDef.STAT_KEYS.values()
	for ending in finale.endings:
		check(not ending.choice.is_empty() and not ending.hint.is_empty() and not ending.title.is_empty() and ending.text.split("\n").size() <= 3, "%s: a button, a line, a title, a short text" % ending.id)
		check(stats.has(ending.stat) and CONTENT.achievements.any(func(a: AchievementDef) -> bool: return a.stat_key() == ending.stat and a.secret), "%s has its secret achievement" % ending.id)
	check(AchievementDef.Stat.HIDDEN_BOSSES == 17 and AchievementDef.Stat.ENDING_BELL == 18 and AchievementDef.Stat.ENDING_KEEPER == 19, "the endings' stats come after the others (saved achievements keep their numbers)")
	# Floor 12 is no longer the last for a profile that won: the Abyss Walker says what it is.
	var walkers := CONTENT.achievements.filter(func(a: AchievementDef) -> bool: return a.id == &"deep_diver")
	var walker: AchievementDef = walkers[0] if walkers.size() == 1 else null
	check(walker != null and walker.stat == AchievementDef.Stat.BEST_DEPTH and walker.target == CONTENT.dungeon.total_floors() and CONTENT.dungeon.boss_for_depth(walker.target) == CONTENT.dungeon.acts.back().boss, "the Abyss Walker: the floor of the last act's warden")
	check(walker != null and walker.description.contains("last act's warden") and not walker.description.contains("the last one"), "...and its text says so, not \"the last one\" (%s)" % (walker.description if walker else "?"))
	# The gate: a won profile, the last act's floor of the first pass, not won yet.
	Profile.reset()
	var rng := RandomNumberGenerator.new()
	var state := RunState.create(CONTENT, {}, rng)
	check(not state.finale_open, "no win yet: the bottom is closed")
	state.depth = config.total_floors()
	check(not state.leads_to_finale() and state.wins_with(config.acts.back().boss), "closed: the last act's boss wins the run (the first ending)")
	Profile.wins = { "easy": 1 }
	check(finale.is_open(), "a win (even on Pilgrim) opens it")
	state = RunState.create(CONTENT, {}, rng)
	state.depth = config.total_floors()
	check(state.finale_open and state.leads_to_finale() and not state.wins_with(config.acts.back().boss), "open: the last act's boss leads down instead of winning")
	state.depth = config.total_floors() - 1
	check(not state.leads_to_finale(), "only from the last act's floor")
	state.depth = config.total_floors()
	var data := state.to_data()
	data.boss_slain = true
	var resumed := RunState.create(CONTENT, data, rng)
	check(resumed.finale and resumed.depth == config.total_floors(), "saved once the last act's boss fell: picked up at the bottom, same depth")
	check(resumed.split_depth() == config.total_floors() + 1 and resumed.wins_with(finale.final_boss()) and not resumed.wins_with(finale.boss), "there, only the last form wins the run, its split after the last act's")
	Profile.reset()
	data.finale = true
	data.boss_slain = false
	resumed = RunState.create(CONTENT, data, rng)
	check(resumed.finale_open and resumed.finale and resumed.depth == config.total_floors(), "a run saved at the bottom stays there (the gate decided when it began)")
	data.has_won = true
	data.boss_slain = true
	data.ending_due = true
	resumed = RunState.create(CONTENT, data, rng)
	check(not resumed.finale and resumed.depth == config.total_floors() + 1 and resumed.ending_due, "won at the bottom: on to the endless floors, the ending still due")
	var old := state.to_data()
	old.erase("finale_open")
	old.erase("finale")
	old.erase("ending_due")
	resumed = RunState.create(CONTENT, old, rng)
	check(not resumed.finale_open and not resumed.finale and not resumed.ending_due, "an older save without these keys is read")
	# Its numbers: the hardest fight, 1.3 to 1.5 times the last act's boss' Health (Keeper).
	var keeper := CONTENT.default_difficulty
	var depth := config.total_floors()
	var health := func(def: BossDef) -> int: return FloorRules.make(config, keeper, null, depth).scale_monster(def.stats, true).max_hp
	var total: int = health.call(forms[0]) + health.call(forms[1])
	for last in config.acts.back().all_bosses():
		var ratio: float = float(total) / float(health.call(last))
		check(ratio >= 1.3 and ratio <= 1.5, "the final fight is 1.3-1.5x %s's Health (%.2f)" % [last.id, ratio])
	# Profile: the ending chosen is kept (and an older profile has none).
	Profile.choose_ending(&"ring_the_bell", "ending_bell")
	check(Profile.ending == &"ring_the_bell" and Profile.stat_value("ending_bell") == 1, "the ending chosen is kept and counted")
	Profile.reset()
	check(Profile.ending == &"", "none by default")


func _test_hidden_floor() -> void:
	var config := CONTENT.dungeon
	var hidden := config.hidden_floor
	check(hidden != null and hidden.key is KeyItemDef and hidden.boss != null and hidden.biome != null, "the hidden floor has its key, its look and its boss")
	if hidden == null or hidden.boss == null:
		return
	check(hidden.key.value == 0 and hidden.key.resource_path.begins_with("res://data/items/") and hidden.key.icon != null, "its key is its own file, can't be sold and has an icon")
	check(not hidden.key_acts.is_empty() and hidden.key_acts.all(func(i: int) -> bool: return i >= 0 and i < config.acts.size() - 1), "its key belongs to acts before the last")
	check(hidden.opens_after(config, config.first_depth(hidden.key_acts[0]) + config.acts[hidden.key_acts[0]].floors - 1) and not hidden.opens_after(config, config.first_depth(hidden.key_acts[0])), "the way opens after its act's boss only")
	check(not config.acts.any(func(each_act: ActDef) -> bool: return each_act.biomes.has(hidden.biome)), "its world is its own")
	check(hidden.monsters.size() >= 4 and hidden.monsters.all(func(m: MonsterDef) -> bool: return m != null and m.spawn_weight > 0), "its own mix of monsters")
	var boss := hidden.boss
	check(boss.portrait != null and boss.frames != null and boss.frames.has_animation(&"idle") and boss.frames.has_animation(&"walk"), "its boss has a portrait and animations")
	check(boss.weapon != null and boss.loot != null and not boss.title.is_empty() and boss.relic_choices > 0, "its boss has a weapon, loot, a title and relics")
	check(boss.phases.size() == 2 and boss.phases[1].skills.any(func(s: SkillDef) -> bool: return String(s.id).ends_with("_fierce")) and boss.phases[1].windup_multiplier < boss.phases[0].windup_multiplier, "its boss has three phases, the last fierce and faster")
	check(not boss.challenges.is_empty(), "its boss has its bestiary challenge")
	# Between the bosses of the acts around it, each at its own floor (Keeper).
	var act := hidden.key_acts[0]
	var depth := config.first_depth(act) + config.acts[act].floors - 1
	var next_depth := depth + config.acts[act + 1].floors
	var keeper := CONTENT.default_difficulty
	var health := func(def: BossDef, at: int) -> int: return FloorRules.make(config, keeper, null, at).scale_monster(def.stats, true).max_hp
	var hp: int = health.call(boss, depth)
	for before in config.acts[act].all_bosses():
		check(hp > health.call(before, depth), "%s is tougher than %s (%d)" % [boss.id, before.id, hp])
	for after in config.acts[act + 1].all_bosses():
		check(hp < health.call(after, next_depth), "%s is weaker than %s at floor %d (%d)" % [boss.id, after.id, next_depth, hp])
	var rng := RandomNumberGenerator.new()
	for i in 20:
		rng.seed = 300 + i
		var plan := boss.arenas[i % boss.arenas.size()] if not boss.arenas.is_empty() else null
		var map := DungeonGenerator.generate_hidden(config, rng, plan, hidden.rooms)
		var reach := _flood(map, map.start_cell)
		check(map.rooms.size() == hidden.rooms + 2 and map.boss_room == map.rooms.back(), "the hidden floor: a start, its rooms, then the arena (%d rooms)" % map.rooms.size())
		check(map.rooms.all(func(room: Rect2i) -> bool: return reach.has(room.get_center())) and reach.has(map.stairs_cell), "every room and the arena reachable")
		check(_bad_wall_cells(map).is_empty(), "no thin walls on the hidden floor")


## Pact doors: every pact's data, how its rule is watched, and the rooms they may seal.
func _test_pacts() -> void:
	var config := CONTENT.dungeon
	check(config.pacts.size() >= 3, "pacts: at least three (%d)" % config.pacts.size())
	check(config.pact_chance > 0.0 and config.pact_chance < 1.0, "pacts: a chance per floor (%.2f)" % config.pact_chance)
	check(config.pact_light != null, "pacts: candles light their doors")
	var ids := {}
	for pact in config.pacts:
		check(pact != null and not pact.id.is_empty() and not ids.has(pact.id), "pact %s: a unique id" % (pact.id if pact else &"?"))
		if pact == null:
			continue
		ids[pact.id] = true
		check(pact.display_name.begins_with("Pact of ") and not pact.description.is_empty(), "pact %s: a name and a lore line" % pact.id)
		check(not tr(pact.display_name).is_empty() and pact.description.length() <= 120, "pact %s: lore short enough for its card" % pact.id)
		check(pact.rule != null and not pact.rule.describe(null).is_empty(), "pact %s: a rule said in plain words" % pact.id)
		check(pact.max_hp_cost >= 0.1 and pact.max_hp_cost <= 0.15, "pact %s: costs 10-15%% of max Health when broken (%.2f)" % [pact.id, pact.max_hp_cost])
		check(pact.waves >= 1 and pact.wave_size >= 1 and pact.relic_choices >= 1, "pact %s: waves to fight, relics to win" % pact.id)
		check(pact.min_depth >= 2 and pact.spawn_weight > 0, "pact %s: never on the first floor, can come up" % pact.id)
		check(pact.color.a > 0.0 and pact.icon != null, "pact %s: a look" % pact.id)
	check(config.pacts.any(func(p: PactDef) -> bool: return p.elite_share >= 1.0), "pacts: one sends nothing but elites")

	# The rules, watched on copies (the data files keep no fight's state).
	var untouched := DamageTakenRule.new()
	untouched._allowed = 0
	untouched._on_damaged(0)
	check(not untouched.is_broken, "untouched: a blow soaked whole (0 damage) keeps it")
	untouched._on_damaged(1)
	check(untouched.is_broken, "untouched: one point of damage breaks it")
	var tithe := DamageTakenRule.new()
	tithe.allowed_share = 0.5
	tithe._allowed = 20
	tithe._on_damaged(20)
	check(not tithe.is_broken, "a Health budget: losing all of it keeps the rule")
	tithe._on_damaged(1)
	check(tithe.is_broken, "...one more point breaks it")
	var knell := TimeLimitRule.new()
	knell.seconds = 30.0
	knell.seconds_per_depth = 2.0
	check(is_equal_approx(knell.limit(4), 36.0), "the knell: more time deeper (%.0f s on floor 4)" % knell.limit(4))
	knell.time_left = 2.0
	var tolled := [0]
	knell.broken.connect(func() -> void: tolled[0] += 1)
	knell.tick(1.5)
	check(not knell.is_broken and knell.status_text() == "1 s left", "the knell: a countdown (%s)" % knell.status_text())
	knell.tick(1.0)
	knell.tick(1.0)
	check(knell.is_broken and tolled[0] == 1, "the knell tolls once, when time runs out")
	var fast := NoConsumableRule.new()
	fast._on_used(null)
	check(fast.is_broken, "the fast: using a consumable breaks it")
	var copy := (config.pacts[0].rule.duplicate() as PactRule)
	copy._break()
	check(not config.pacts[0].rule.is_broken, "pacts: the rule watched is a copy, the data stays clean")

	# The rooms: not the first one, no stairs, one door on one side, nothing else cut off.
	var rng := RandomNumberGenerator.new()
	var found := 0
	for i in 40:
		rng.seed = 7000 + i
		var map := DungeonGenerator.generate(config, rng)
		rng.seed = 99 + i
		var index := PactRoom.find_room(map, rng, [], config.corridor_width + 3)
		rng.seed = 99 + i
		check(PactRoom.find_room(map, rng, [], config.corridor_width + 3) == index, "pact rooms: the same seed, the same room")
		if index < 0:
			continue
		found += 1
		var room := map.rooms[index]
		check(index != 0 and not room.grow(1).has_point(map.start_cell), "pact rooms: never where the hero starts")
		check(not map.exit_cells().any(func(c: Vector2i) -> bool: return room.grow(1).has_point(c)), "pact rooms: never by the stairs")
		var door := PactRoom.door_of(map, room)
		check(not door.is_empty() and door.size() <= config.corridor_width + 3, "pact rooms: one door (%d cells)" % door.size())
		var sealed := PactRoom._flood(map, room, door)
		var all_rooms_joined := true
		for other in map.rooms:
			if other != room and not sealed.has(other.get_center()) and map.is_floor(other.get_center()):
				all_rooms_joined = false
		check(all_rooms_joined and map.exit_cells().all(func(c: Vector2i) -> bool: return sealed.has(c)), "pact rooms: sealed, the rest of the floor and its stairs stay joined")
	check(found >= 10, "pact rooms: most floors have one to give (%d of 40)" % found)


## The stairs' seal: a share of the floor's monsters, the last few shown, broken once.
func _test_stairs_seal() -> void:
	var seal := StairsSeal.new()
	var broken := [0]
	seal.broken.connect(func() -> void: broken[0] += 1)
	seal.reset(10, 0.7, 4)
	check(seal.needed == 7 and seal.is_sealed() and not seal.reveals_monsters(), "a floor of 10 monsters asks for 7 kills")
	for i in 3:
		seal.add_kill()
	check(seal.left() == 4 and seal.reveals_monsters(), "the last few kills show the monsters left")
	for i in 3:
		check(not seal.add_kill(), "still sealed")
	check(seal.add_kill() and not seal.is_sealed() and broken[0] == 1, "the 7th kill breaks the seal")
	check(not seal.add_kill() and broken[0] == 1 and not seal.reveals_monsters(), "it breaks only once")
	seal.reset(0, 0.7, 4)
	check(not seal.is_sealed(), "no monsters: no seal")
	seal.reset(9, 0.7, 4)
	seal.break_now()
	check(not seal.is_sealed() and broken[0] == 2, "debug: break it at once")
	var config := CONTENT.dungeon
	check(config.seal_share >= 0.5 and config.seal_share < 1.0, "the seal wants most monsters, not every last one")
	seal.reset(200, 0.7, 4, 50)
	check(seal.needed == 50, "a crowded floor asks for no more than the most (%d)" % seal.needed)
	check(config.seal_max > 0, "the config caps the seal")


## Biomes: every act has 2 or more, each complete; scenes are sound plans.
func _test_biome_content() -> void:
	var seen := {}
	for act in CONTENT.dungeon.acts:
		check(act.biomes.size() >= 2, "%s has several biomes (%d)" % [act.title, act.biomes.size()])
		for biome in act.biomes:
			check(not seen.has(biome), "%s belongs to one act only" % biome.id)
			seen[biome] = true
			check(biome.theme != null and biome.theme.floor_atlas != null and biome.theme.wall_atlas != null, "%s has its tiles" % biome.id)
			check(not biome.display_name.is_empty() and not biome.description.is_empty(), "%s has a name and a line" % biome.id)
			check(biome.scenes.size() >= 5, "%s has its scenes (%d)" % [biome.id, biome.scenes.size()])
			check(not biome.grounds.is_empty() and not biome.decor.is_empty(), "%s has grounds and decor" % biome.id)
			for layer in biome.grounds:
				check(layer.texture != null and layer.coverage > 0.0, "%s: a ground with a look" % biome.id)
			for scene in biome.scenes:
				_check_scene(biome, scene)
	var rng := RandomNumberGenerator.new()
	var act: ActDef = CONTENT.dungeon.acts[0]
	check(act.pick_biome(3, true, rng) == act.main_biome(), "the boss arena has its biome")
	var picked := {}
	for i in 60:
		picked[act.pick_biome(2, false, rng)] = true
	check(picked.size() == act.biomes.size(), "every biome of an act comes up (%d)" % picked.size())


func _check_scene(biome: BiomeDef, scene: SceneDef) -> void:
	var case_name := "%s/%s" % [biome.id, scene.id]
	check(not scene.rows.is_empty() and scene.size().x > 0, "%s has a plan" % case_name)
	for row in scene.rows:
		for symbol in row:
			if symbol != " " and symbol != ".":
				check(scene.key(symbol) != null, "%s: '%s' means something" % [case_name, symbol])
	for k in scene.keys:
		match k.kind:
			SceneKey.Kind.PROP:
				check(not k.props.is_empty(), "%s: '%s' has props" % [case_name, k.symbol])
				var foot := k.props[0].footprint if not k.props.is_empty() else Vector2i.ONE
				for prop in k.props:
					check(prop.icon != null and prop.footprint == foot, "%s: %s drawn, same footprint as its kin" % [case_name, prop.id])
				# A footprint bigger than a cell: the symbol covers it whole, every time (read
				# row by row, as the scene is built).
				var cells := scene.plan(false)
				var ordered := cells.keys().filter(func(offset: Vector2i) -> bool: return cells[offset] == k.symbol)
				ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
				var used := {}
				for offset: Vector2i in ordered:
					if used.has(offset):
						continue
					for y in foot.y:
						for x in foot.x:
							used[offset + Vector2i(x, y)] = true
							check(cells.get(offset + Vector2i(x, y), "") == k.symbol, "%s: '%s' covers its %s footprint" % [case_name, k.symbol, foot])
			SceneKey.Kind.DECOR:
				check(not k.pieces.is_empty(), "%s: '%s' has pieces" % [case_name, k.symbol])
			SceneKey.Kind.CARPET:
				check(k.carpet != null, "%s: '%s' has a carpet" % [case_name, k.symbol])
			SceneKey.Kind.POND:
				check(k.pond != null and k.pond.pond != null and k.pond.heat == 0.0, "%s: '%s' is plain water" % [case_name, k.symbol])
				# Water fills the rectangle around its cells: the plan shows it whole.
				var cells := scene.plan(false)
				var rect := SceneDef._span_of(cells, k.symbol)
				var whole := true
				for y in range(rect.position.y, rect.end.y):
					for x in range(rect.position.x, rect.end.x):
						whole = whole and cells.get(Vector2i(x, y), "") == k.symbol
				check(whole, "%s: its water is a rectangle in the plan" % case_name)


## Daily and weekly quests: the same for everyone on a given day, counted, paid once.
func _test_quests() -> void:
	var quests := CONTENT.quests
	check(quests.filter(func(q: QuestDef) -> bool: return q.period == QuestDef.Period.DAILY).size() >= 6, "a pool of daily quests")
	check(quests.filter(func(q: QuestDef) -> bool: return q.period == QuestDef.Period.WEEKLY).size() >= 5, "a pool of weekly quests")
	var monday := 1760918400  # 2025-10-20 00:00 UTC, a Monday
	var daily := QuestBoard.current(quests, QuestDef.Period.DAILY, monday + 3600)
	var again := QuestBoard.current(quests, QuestDef.Period.DAILY, monday + 80000)
	check(daily.size() == QuestBoard.DAILY_COUNT, "%d daily quests" % daily.size())
	check(daily.map(func(q: Dictionary) -> StringName: return q.def.id) == again.map(func(q: Dictionary) -> StringName: return q.def.id) \
		and daily.map(func(q: Dictionary) -> int: return q.target) == again.map(func(q: Dictionary) -> int: return q.target), "the same quests all day long (and for everyone)")
	var ids := {}
	for q in daily:
		ids[q.def.id] = true
	check(ids.size() == daily.size(), "three different quests")
	var days_differ := false
	for d in range(1, 6):
		var other := QuestBoard.current(quests, QuestDef.Period.DAILY, monday + d * QuestBoard.DAY + 10)
		days_differ = days_differ or other.map(func(q: Dictionary) -> StringName: return q.def.id) != daily.map(func(q: Dictionary) -> StringName: return q.def.id)
	check(days_differ, "new quests on other days")
	check(QuestBoard.period_key(QuestDef.Period.WEEKLY, monday + 10) == QuestBoard.period_key(QuestDef.Period.WEEKLY, monday + 6 * QuestBoard.DAY + 80000)
		and QuestBoard.period_key(QuestDef.Period.WEEKLY, monday - 10) != QuestBoard.period_key(QuestDef.Period.WEEKLY, monday + 10), "weeks start on Monday")
	check(QuestBoard.seconds_left(QuestDef.Period.DAILY, monday + 3600) == QuestBoard.DAY - 3600, "time left until the next daily quests")
	for q in daily:
		var quest_def: QuestDef = q.def
		check(q.target >= quest_def.target.x - quest_def.step and q.target <= quest_def.target.y + quest_def.step and q.reward >= quest_def.reward.x and q.reward <= quest_def.reward.y, "%s: goal and reward in range" % quest_def.id)
	# Counting and paying, on today's quests.
	var today := QuestBoard.current(quests, QuestDef.Period.DAILY)
	var quest: Dictionary = today[0]
	var def: QuestDef = quest.def
	var souls := Profile.souls
	if def.best:
		Profile.raise_stat(def.stat, quest.target)
	else:
		Profile.add_stat(def.stat, quest.target)
	check(QuestBoard.is_done(quest), "doing it fills the quest (%s)" % def.id)
	var paid := QuestBoard.claim_finished(quests)
	check(paid.any(func(q: Dictionary) -> bool: return q.def == def) and Profile.souls >= souls + int(quest.reward), "a finished quest pays its souls")
	check(QuestBoard.claim_finished(quests).filter(func(q: Dictionary) -> bool: return q.def == def).is_empty(), "only once")


func _bad_wall_cells(map: DungeonMap) -> Array[Vector2i]:
	var bad: Array[Vector2i] = []
	for y in range(1, map.height - 1):
		for x in range(1, map.width - 1):
			var c := Vector2i(x, y)
			if map.is_floor(c):
				continue
			if DungeonGenerator.is_thin_wall(map, c, Vector2i.RIGHT) or DungeonGenerator.is_thin_wall(map, c, Vector2i.DOWN) \
					or DungeonGenerator._is_pinch(map, c):
				bad.append(c)
	return bad


func _flood(map: DungeonMap, from: Vector2i) -> Dictionary:
	var seen := { from: true }
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + dir
			if map.is_floor(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen


func _test_inventory_and_equipment() -> void:
	var inventory := Inventory.new(2)
	var potion: ItemDef = load("res://data/items/consumables/health_potion.tres")
	var bomb: ItemDef = load("res://data/items/consumables/bomb.tres")
	var scroll: ItemDef = load("res://data/items/consumables/fire_scroll.tres")
	check(inventory.add(potion) and inventory.add(potion) and inventory.add(bomb), "inventory accepts items")
	check(not inventory.add(scroll), "inventory refuses items when full")
	check(inventory.add(potion), "...but a full bag still takes one more of a stack")
	check(inventory.grouped().size() == 2 and inventory.grouped()[0].count == 3, "identical items are grouped")

	var equipment := Equipment.new()
	var cap: EquipmentDef = load("res://data/items/armors/leather_cap.tres")
	var helm: EquipmentDef = load("res://data/items/armors/iron_helm.tres")
	check(equipment.equip(cap) == null, "equip into empty slot")
	check(equipment.equip(helm) == cap, "equip returns the replaced item")
	check(equipment.total_bonuses().defense == helm.bonuses.defense, "bonuses come from equipped items")


## A full bag: identical drops stack (one place), gear breaks down for gold (never above what the
## merchant pays), "Dismantle the worse" and "Better only" agree on what is worse, stacks survive
## a saved run.
func _test_bag_stacks_and_dismantle() -> void:
	var katana: WeaponDef = load("res://data/items/weapons/katana.tres")
	var axe: WeaponDef = load("res://data/items/weapons/axe.tres")
	var cap: EquipmentDef = load("res://data/items/armors/leather_cap.tres")
	var sharp: ItemAffixDef = load("res://data/affixes/sharp.tres")
	var bear: ItemAffixDef = load("res://data/affixes/of_the_bear.tres")
	var vampiric: ItemAffixDef = load("res://data/affixes/vampiric.tres")
	var potion: ItemDef = load("res://data/items/consumables/health_potion.tres")
	var key: ItemDef = load("res://data/items/keys/bone_key.tres")
	var tome: ItemDef = load("res://data/items/tomes/tome_fire.tres")
	var rune: RuneDef = CONTENT.runes[0]
	var none: Array[ItemAffixDef] = []
	var no_runes: Array[RuneDef] = []
	var one_rune: Array[RuneDef] = [rune]

	# The stack key: two drops rolled apart are one thing when everything about them is the same.
	var one := LootRoller.make(katana, ItemRarity.RARE, [sharp, bear] as Array[ItemAffixDef], no_runes, 4)
	var two := LootRoller.make(katana, ItemRarity.RARE, [sharp, bear] as Array[ItemAffixDef], no_runes, 4)
	check(one != two and one.stack_key() == two.stack_key(), "same base, rarity, level and affixes: the same stack key")
	check(one.stack_key() != LootRoller.make(katana, ItemRarity.RARE, [sharp, vampiric] as Array[ItemAffixDef], no_runes, 4).stack_key(), "a different affix: no stack")
	check(one.stack_key() != LootRoller.make(katana, ItemRarity.RARE, [bear, sharp] as Array[ItemAffixDef], no_runes, 4).stack_key(), "affixes in another order (another name): no stack")
	check(one.stack_key() != LootRoller.make(katana, ItemRarity.RARE, [sharp, bear] as Array[ItemAffixDef], no_runes, 5).stack_key(), "another item level: no stack")
	check(one.stack_key() != LootRoller.make(katana, ItemRarity.EPIC, [sharp, bear] as Array[ItemAffixDef], no_runes, 4).stack_key(), "another rarity: no stack")
	check(one.stack_key() != LootRoller.make(axe, ItemRarity.RARE, [sharp, bear] as Array[ItemAffixDef], no_runes, 4).stack_key(), "another base item: no stack")
	check(one.stack_key() != LootRoller.make(katana, ItemRarity.RARE, [sharp, bear] as Array[ItemAffixDef], one_rune, 4).stack_key(), "a rune set in it: no stack")
	check(katana.stack_key() == (load("res://data/items/weapons/katana.tres") as ItemDef).stack_key() and katana.stack_key() != LootRoller.make(katana, ItemRarity.COMMON, none, no_runes, 2).stack_key(), "plain items stack with themselves, not with a deeper copy")

	# Capacity counts stacks.
	var bag := Inventory.new(3)
	for item: ItemDef in [one, two, potion, potion, katana]:
		check(bag.add(item), "the bag takes %s" % item.display_name)
	check(bag.items.size() == 5 and bag.places_used() == 3 and bag.is_full(), "5 items in 3 stacks: 3 places of 3")
	check(bag.add(LootRoller.make(katana, ItemRarity.RARE, [sharp, bear] as Array[ItemAffixDef], no_runes, 4)), "full, it still takes a third of a stack")
	check(not bag.add(cap) and not bag.can_add(cap), "but nothing new")
	check(bag.grouped().size() == 3 and bag.grouped()[0].count == 3 and bag.count_of(two) == 3, "one slot per stack, with its count")
	# Taking one from a stack.
	var taken := bag.take(LootRoller.make(katana, ItemRarity.RARE, [sharp, bear] as Array[ItemAffixDef], no_runes, 4))
	check(taken != null and not bag.items.has(taken) and bag.count_of(one) == 2 and bag.places_used() == 3, "take one from a stack: the rest stays, in its place")
	check(bag.remove(one) and bag.count_of(two) == 1 and bag.find_like(one) != null, "remove takes one too")
	check(not bag.fits_after_taking(potion, cap), "equipping one of a stack frees no place for what was worn")
	check(bag.fits_after_taking(katana, cap), "the last of a stack frees its place")

	# Dismantle gold: from data, below what the merchant pays.
	var rules: DismantleRules = PlayerPack.DISMANTLE
	check(rules.gold_share > 0.0 and rules.gold_for(katana) == roundi(katana.value * rules.gold_share), "a plain katana gives its value x %.2f (%d gold)" % [rules.gold_share, rules.gold_for(katana)])
	check(rules.gold_for(one) > rules.gold_for(katana) and rules.gold_for(LootRoller.make(katana, ItemRarity.EPIC, none, no_runes, 4)) > rules.gold_for(LootRoller.make(katana, ItemRarity.MAGIC, none, no_runes, 4)), "rarer and deeper gear gives more")
	check(rules.gold_for(potion) == 0 and rules.gold_for(key) == 0 and rules.gold_for(rune) == 0 and rules.gold_for(tome) == 0, "potions, keys, runes and tomes don't break down")
	var merchant: ShopDef = CONTENT.dungeon.merchant
	var cheaper := true
	for base: ItemDef in CONTENT.items:
		if not base is EquipmentDef:
			continue
		for rarity: int in [ItemRarity.COMMON, ItemRarity.MAGIC, ItemRarity.RARE, ItemRarity.EPIC]:
			for level: int in [1, 3, 8, 15]:
				var gear := LootRoller.make(base as EquipmentDef, rarity, none, one_rune if base is WeaponDef else no_runes, level)
				if rules.gold_for(gear) >= merchant.sell_price(gear, level):
					cheaper = false
	check(cheaper, "dismantling always gives less than the merchant pays on the item's own floor")

	# What is worse than what is worn.
	var worn := LootRoller.make(katana, ItemRarity.RARE, [sharp, bear] as Array[ItemAffixDef], no_runes, 5)
	check(ItemCompare.is_worse(LootRoller.make(katana, ItemRarity.COMMON, none, no_runes, 3), worn), "a lower, plainer katana is worse")
	check(ItemCompare.is_worse(LootRoller.make(katana, ItemRarity.RARE, [sharp, bear] as Array[ItemAffixDef], no_runes, 5), worn), "a copy of what is worn is worse (nothing to gain)")
	check(not ItemCompare.is_worse(LootRoller.make(katana, ItemRarity.COMMON, none, no_runes, 6), worn), "a higher item level is not")
	check(not ItemCompare.is_worse(LootRoller.make(katana, ItemRarity.EPIC, none, no_runes, 2), worn), "a higher rarity is not")
	check(not ItemCompare.is_worse(LootRoller.make(katana, ItemRarity.MAGIC, [vampiric] as Array[ItemAffixDef], no_runes, 2), worn), "an affix that does something the worn one doesn't is not")
	check(not ItemCompare.is_worse(LootRoller.make(katana, ItemRarity.COMMON, none, one_rune, 1), worn), "a weapon with a rune set is not")
	check(not ItemCompare.is_worse(cap, null), "nothing is worse than an empty slot")
	var deep_axe := LootRoller.make(axe, ItemRarity.RARE, none, no_runes, 6)
	var quick := LootRoller.make(katana, ItemRarity.COMMON, none, no_runes, 2)
	check(ItemCompare.lines(quick, deep_axe).any(func(change: Dictionary) -> bool: return change.good) and ItemCompare.is_worse(quick, deep_axe), "a shallower katana is worse than a deep axe, quicker as it is")
	var leather: EquipmentDef = load("res://data/items/armors/leather_armor.tres")
	var plate: EquipmentDef = load("res://data/items/armors/plate_armor.tres")
	check(not ItemCompare.is_worse(LootRoller.make(plate, ItemRarity.COMMON, none, no_runes, 3), LootRoller.make(leather, ItemRarity.MAGIC, none, no_runes, 5)), "a shallower armor with more Armor and Health is not worse")
	check(ItemCompare.is_worse(LootRoller.make(leather, ItemRarity.COMMON, none, no_runes, 3), LootRoller.make(plate, ItemRarity.MAGIC, none, no_runes, 5)), "a shallower, thinner one is, lighter as it is")

	# The hero: dismantling, the worse gear, auto loot.
	var hero := PLAYER.instantiate() as Player
	hero.setup(CONTENT.player)
	hero.inventory.items.clear()
	hero.equipment.equip(worn)
	hero.equipment.equip(LootRoller.make(cap, ItemRarity.MAGIC, none, no_runes, 5))
	var junk := LootRoller.make(katana, ItemRarity.COMMON, none, no_runes, 2)
	var junk2 := LootRoller.make(katana, ItemRarity.COMMON, none, no_runes, 2)
	var keeper := LootRoller.make(katana, ItemRarity.EPIC, none, no_runes, 7)
	var old_cap := LootRoller.make(cap, ItemRarity.COMMON, none, no_runes, 1)
	for item: ItemDef in [junk, junk2, keeper, old_cap, potion, key, tome, rune]:
		hero.inventory.add(item)
	var worse := hero.pack.worse_gear()
	check(worse.size() == 3 and worse.has(junk) and worse.has(junk2) and worse.has(old_cap), "the worse gear: both plain katanas and the old cap (%d)" % worse.size())
	hero.gold = 0
	var expected := rules.gold_for(junk) * 2 + rules.gold_for(old_cap)
	var got := hero.pack.dismantle_all(hero.pack.worse_gear())
	check(got == expected and hero.gold == expected, "dismantling the worse gives their gold (%d)" % got)
	check(hero.inventory.items.has(keeper) and hero.inventory.items.has(potion) and hero.inventory.items.has(key) and hero.inventory.items.has(tome) and hero.inventory.items.has(rune), "and keeps the better gear, potions, keys, tomes, runes")
	check(hero.equipment.get_item(EquipmentDef.Slot.WEAPON) == worn and hero.equipment.get_item(EquipmentDef.Slot.HEAD) != null, "and never touches what is worn")
	var count_before := hero.inventory.items.size()
	check(hero.pack.dismantle(key) == 0 and hero.pack.dismantle(potion) == 0 and hero.pack.dismantle(rune) == 0 and hero.pack.dismantle(tome) == 0 and hero.pack.dismantle(worn) == 0, "keys, potions, runes, tomes and worn gear can't be dismantled")
	check(hero.inventory.items.size() == count_before and hero.gold == expected and hero.equipment.get_item(EquipmentDef.Slot.WEAPON) == worn, "(nothing taken, no gold)")
	check(hero.pack.dismantle(keeper) == rules.gold_for(keeper) and not hero.inventory.items.has(keeper), "one piece dismantled: its gold")
	check(hero.pack.wants(junk, Settings.LOOT_ALL), "auto loot All: everything")
	check(not hero.pack.wants(junk, Settings.LOOT_BETTER) and hero.pack.wants(keeper, Settings.LOOT_BETTER), "Better only: worse gear stays, better comes")
	var plain_axe := LootRoller.make(axe, ItemRarity.COMMON, none, no_runes, 1)
	check(hero.pack.wants(plain_axe, Settings.LOOT_BETTER) == not ItemCompare.is_worse(plain_axe, worn), "Better only and Dismantle the worse agree")
	check(not hero.pack.wants(keeper, Settings.LOOT_OFF), "By hand: no gear")
	for always: ItemDef in [potion, key, rune, tome]:
		check(hero.pack.wants(always, Settings.LOOT_OFF) and hero.pack.wants(always, Settings.LOOT_BETTER), "%s is always taken" % always.display_name)
	var defaults: Node = (load("res://src/autoload/settings.gd") as GDScript).new()
	check(defaults.get(&"auto_loot") == Settings.LOOT_BETTER, "Better only by default")
	defaults.free()

	# Stacks survive a saved run.
	hero.inventory.items.clear()
	for item: ItemDef in [junk, junk2, keeper, potion, potion]:
		hero.inventory.add(item)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(hero.save_state()))
	var resumed := PLAYER.instantiate() as Player
	resumed.setup(CONTENT.player)
	resumed.load_state(saved)
	var stacks := resumed.inventory.grouped()
	check(resumed.inventory.items.size() == 5 and resumed.inventory.places_used() == 3 and stacks.size() == 3 and stacks[0].count == 2 and stacks[2].count == 2, "a saved bag comes back with its stacks (%d places)" % resumed.inventory.places_used())
	hero.free()
	resumed.free()


func _test_perks() -> void:
	check(CONTENT.perks.size() >= 12, "content db lists perks (%d)" % CONTENT.perks.size())
	var ids := {}
	var rares := 0
	for perk in CONTENT.perks:
		check(perk.icon != null and not perk.display_name.is_empty(), "%s has an icon and a name" % perk.id)
		check(not perk.describe().is_empty(), "%s describes itself" % perk.id)
		check(not ids.has(perk.id), "duplicate perk id %s" % perk.id)
		ids[perk.id] = true
		if perk.rarity == PerkDef.Rarity.RARE:
			rares += 1
	check(rares >= 3, "enough relics for a boss reward (%d)" % rares)

	var owned := PerkSet.new()
	var vitality := _perk("vitality")
	owned.add(vitality)
	owned.add(vitality)
	check(owned.stacks_of(vitality) == 2 and owned.entries.size() == 1, "taking a perk again stacks it")
	check(owned.total_bonuses().max_hp == vitality.bonuses.max_hp * 2, "stacked perks add their stats per level")
	for i in 10:
		owned.add(vitality)
	check(owned.stacks_of(vitality) == vitality.max_stacks, "stacks are capped")
	check(not owned.can_take(vitality), "a maxed perk can't be taken again")

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 30:
		var offer := CONTENT.pick_perks(owned, 3, PerkDef.Rarity.COMMON, rng)
		check(offer.size() == 3, "level up offers 3 perks")
		check(not offer.has(vitality), "maxed perks are not offered")
		check(offer[0] != offer[1] and offer[1] != offer[2] and offer[0] != offer[2], "offered perks are all different")
		check(offer.all(func(p: PerkDef) -> bool: return p.rarity == PerkDef.Rarity.COMMON), "level up offers common perks")
	var relics := CONTENT.pick_perks(owned, 3, PerkDef.Rarity.RARE, rng)
	check(relics.all(func(p: PerkDef) -> bool: return p.rarity == PerkDef.Rarity.RARE), "bosses offer relics")

	# The waiting choices: a level up's waits for the player, a relic comes by itself; a choice put
	# off goes first and waits; a save keeps both kinds and the cards dealt.
	var queue := OfferQueue.new()
	var changes := [0]
	queue.changed.connect(func() -> void: changes[0] += 1)
	queue.add(PerkDef.Rarity.COMMON, 3, "Level 2!", "Choose an upgrade", true)
	queue.add_relic(CONTENT.dungeon.acts[0].boss)
	check(queue.size() == 2 and changes[0] == 2, "the queue counts its choices and says when they change")
	var automatic := queue.pop(true)
	check(automatic != null and automatic.rarity == PerkDef.Rarity.RARE and not automatic.on_demand and queue.size() == 1, "only the relic comes by itself")
	check(queue.pop(true) == null, "a level up's choice never comes by itself")
	automatic.cards = relics.duplicate()
	queue.put_back(automatic)
	check(queue.size() == 2 and automatic.on_demand, "a choice put off waits like a level up")
	var reloaded := OfferQueue.new()
	reloaded.load_data(queue.to_data(false))
	var first := reloaded.pop()
	check(first.rarity == PerkDef.Rarity.RARE and first.on_demand and first.cards == relics, "a save keeps the put-off choice first, with its cards")
	check(reloaded.pop().on_demand and reloaded.is_empty(), "...and the level up's, still waiting")
	var old_save := OfferQueue.new()
	old_save.load_data([{ "rarity": 0, "count": 3, "title": "Level 2!", "subtitle": "" }])
	check(old_save.pop().on_demand, "an old save's pending choice waits for the player")
	var everything := PerkSet.new()
	for perk in CONTENT.perks:
		if perk.rarity == PerkDef.Rarity.RARE:
			for i in perk.max_stacks:
				everything.add(perk)
	var fallback := CONTENT.pick_perks(everything, 3, PerkDef.Rarity.RARE, rng)
	check(fallback.size() == 3, "with every relic maxed, common perks fill the offer")


## Healing from hits, kills and skills (Leech, Vampirism, the Blood family...): fractions add up
## and are paid in whole points; the hero's share one budget per second, slower in boss fights.
func _test_sustain() -> void:
	var rules: SustainRules = CONTENT.dungeon.sustain
	check(rules != null and rules.rate_per_second > 0.0 and rules.rate_per_second <= 0.1 and rules.burst > 0.0 and rules.boss_fight_rate <= 1.0, "the hero's healing from hits and kills is limited (DungeonConfig > Sustain)")
	# No rounding up: 8% of a 7-damage hit is 0.56, not 1.
	check(SustainMeter.new().take(7 * 0.08, 100, 50, 0.0) == 0, "one small hit heals nothing yet")
	var meter := SustainMeter.new()
	var paid := 0
	for i in 10:
		paid += meter.take(7 * 0.08, 100, 50, i * 0.1)
	check(paid == 5, "10 hits of 7 at 8%% heal 5 (5.6), not 10 (%d)" % paid)
	var full := SustainMeter.new()
	full.take(0.9, 100, 0, 0.0)
	check(full.pending == 0.0 and full.take(0.5, 100, 10, 0.1) == 0, "nothing is banked at full health")
	check(SustainMeter.new().take(30.0, 100, 4, 0.0) == 4, "never more than the missing health")
	# One budget: `burst` at once, then `rate_per_second` a second, half that in a boss fight.
	var limit := SustainRules.new()
	limit.rate_per_second = 0.04
	limit.burst = 0.2
	limit.boss_fight_rate = 0.5
	var capped := SustainMeter.new()
	check(capped.take(50.0, 100, 90, 0.0, limit) == 20, "a burst heals at most 20% of max health")
	check(capped.take(10.0, 100, 70, 0.0, limit) == 0, "then nothing more at once")
	check(capped.take(10.0, 100, 70, 1.0, limit) == 4, "then 4% of max health per second")
	var in_boss_fight := SustainMeter.new()
	in_boss_fight.take(50.0, 100, 90, 0.0, limit, true)
	check(in_boss_fight.take(10.0, 100, 70, 1.0, limit, true) == 2, "half as fast during a boss fight")
	# A smaller budget in a boss fight (SustainRules.boss_fight_burst): 25% of 20% = 5 at once.
	limit.boss_fight_burst = 0.25
	var small := SustainMeter.new()
	small.take(0.0, 100, 50, 0.0, limit)  # out of the fight: the full budget (20)
	check(small.take(50.0, 100, 90, 0.1, limit, true) == 5, "a boss fight starts with at most 5% of max health in the budget")
	limit.boss_fight_burst = 1.0
	# The game's rules: in a boss fight, one second of the budget is under 1% of max health,
	# and the budget holds under 10%: healing forgives a mistake, it doesn't out-heal a boss.
	check(rules.refill_per_second(100, true) <= 1.0 and rules.capacity(100, true) <= 10.0,
		"boss fights: refill %.1f/s, budget %.0f for 100 Health" % [rules.refill_per_second(100, true), rules.capacity(100, true)])
	# Stacked sustain never out-heals the limit: three Leech runes on 12-damage hits five times a
	# second, plus Vampirism and the Blood family on a kill every second, for a minute.
	var stacked := SustainMeter.new()
	var total := 0
	for step in 300:
		var now := step * 0.2
		total += stacked.take(12 * 0.3, 100, 100, now, limit)
		if step % 5 == 0:
			total += stacked.take(6.0 + 4.0, 100, 100, now, limit)
	var most := 100 * limit.burst + 100 * limit.rate_per_second * 299 * 0.2
	check(total <= ceili(most) and total >= floori(most) - 2, "a minute of stacked sustain heals %d, the limit is %d" % [total, roundi(most)])
	# Light sustain is untouched: one Leech rune (10%) on a katana's hits in a pack.
	var light := SustainMeter.new()
	var leech := 0
	for step in 50:
		leech += light.take(9 * 0.1, 100, 100, step * 0.38, limit)
	check(leech == 45, "a single Leech rune is never cut by the limit (%d of 45)" % leech)


## Families read as their fantasy and stay comparable (see docs/balance.md).
func _test_family_themes() -> void:
	var commons := {}
	var members := {}
	for perk in CONTENT.perks:
		for synergy in perk.synergies:
			members[synergy] = members.get(synergy, 0) + 1
			if perk.rarity == PerkDef.Rarity.COMMON:
				commons[synergy] = commons.get(synergy, 0) + 1
	var sizes: Array[int] = []
	for synergy in CONTENT.synergies:
		check(commons.get(synergy, 0) >= 4, "%s: 4 or more perks to level up into (%d)" % [synergy.id, commons.get(synergy, 0)])
		sizes.append(members.get(synergy, 0))
	check(sizes.max() - sizes.min() <= 2, "families are about the same size %s" % [sizes])
	var placed := {
		&"frenzy": &"storm", &"thorns": &"inferno", &"iron_skin": &"frost", &"bloodrage": &"blood",
		&"multishot": &"arcane",
	}
	for id: StringName in placed:
		var perk := _perk(id)
		check(perk.synergies.size() == 1 and perk.synergies[0].id == placed[id], "%s belongs to %s" % [id, placed[id]])
	for id in ["strength", "precision", "war_banner", "fortune"]:
		check(_perk(id).synergies.is_empty(), "%s (plain numbers) belongs to no family" % id)
	check(_perk("devotion").synergies.size() == 2, "Devotion heals with skills: Arcane and Blood")
	# Player-facing words: Health, Damage, Armor, never HP/ATK/DEF.
	var texts: Array[String] = []
	for perk in CONTENT.perks:
		texts.append(perk.describe())
	for synergy in CONTENT.synergies:
		texts.append(synergy.description)
	for rune in CONTENT.runes:
		texts.append(rune.description)
	for text in texts:
		check(not RegEx.create_from_string("\\b(HP|ATK|DEF)\\b").search(text), "plain words: %s" % text)


## Arenas: shapes, and changes that keep the hero, the boss and the middle clear.
func _test_arenas() -> void:
	var config := CONTENT.dungeon
	check(config.arenas.size() >= 4, "several arenas")
	for arena in config.arenas:
		check(arena.size.x <= config.width - 22 and arena.shifts.size() >= 2, "%s fits the floor and changes twice" % arena.id)
	var plan := ArenaDef.new()
	plan.size = Vector2i(21, 15)
	var rect := plan.cells(Vector2i.ZERO).size()
	plan.shape = ArenaDef.Shape.OVAL
	var oval := plan.cells(Vector2i.ZERO)
	plan.shape = ArenaDef.Shape.CROSS
	plan.arm = 7
	var cross := plan.cells(Vector2i.ZERO)
	check(rect == 21 * 15 and oval.size() < rect and cross.size() < rect, "rect, oval and cross shapes")
	check(oval.has(Vector2i(10, 7)) and not oval.has(Vector2i(0, 0)) and cross.has(Vector2i(0, 7)) and not cross.has(Vector2i(0, 0)), "the oval has no corners, the cross has arms")
	plan.shape = ArenaDef.Shape.RECT
	var room := Rect2i(Vector2i.ZERO, plan.size)
	var all := plan.cells(Vector2i.ZERO)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var hero := Vector2i(3, 3)
	for pattern in ArenaShiftDef.Pattern.values():
		var shift := ArenaShiftDef.new()
		shift.pattern = pattern
		shift.width = 2
		shift.count = 12
		var keep: Array[Vector2i] = [hero, room.get_center()]
		var picked := shift.pick_cells(all, room, keep, 1, rng)
		check(not picked.is_empty() and not picked.has(hero) and not picked.has(room.get_center()), "pattern %d takes cells, never under the hero or in the middle" % pattern)
	var edge := ArenaShiftDef.new()
	edge.pattern = ArenaShiftDef.Pattern.EDGE
	var ring := edge.pick_cells(all, room, [] as Array[Vector2i], 0, rng)
	check(ring.has(Vector2i(10, 0)) and not ring.has(Vector2i(10, 7)), "the edge band is on the edge")


## Monster ranks: rarer is rarer, and only from their depth.
## The stepped light: one level less per tile, around corners, never through walls.
func _test_lighting() -> void:
	# Two rooms with a thick wall between them, joined by a corridor along the bottom.
	var map := DungeonMap.new(13, 7, 32)
	for y in range(1, 5):
		for x in range(1, 5):
			map.set_floor(Vector2i(x, y))
			map.set_floor(Vector2i(x + 7, y))
	for x in range(5, 8):
		map.set_floor(Vector2i(x, 5))
	map.set_floor(Vector2i(4, 5))
	map.set_floor(Vector2i(8, 5))
	var lighting := LightingDef.new()
	lighting.ambient_level = 3
	lighting.ramp = Gradient.new()
	lighting.ramp.set_color(0, Color.BLACK)
	lighting.ramp.set_color(1, Color.WHITE)
	var field := LightField.new()
	add_child(field)
	field.setup(map, lighting)
	var at := func(x: int, y: int) -> int: return field.level_at(map.cell_to_world(Vector2i(x, y)))
	check(at.call(2, 2) == 3, "no lamp: the floor's own light")
	var lamp := LightSource.new()
	lamp.level = 15
	lamp.position = map.cell_to_world(Vector2i(2, 2))
	field.add_child(lamp)
	check(at.call(2, 2) == 15 and at.call(3, 2) == 14 and at.call(4, 2) == 13, "a lamp: 15 on its tile, then 14, 13...")
	check(at.call(1, 2) == 14 and at.call(2, 1) == 14 and at.call(2, 3) == 14, "...the same on every side")
	check(at.call(2, 0) == 13, "the cliff face above catches the light")
	var mist_near: int = at.call(5, 2)
	var mist_far: int = at.call(6, 2)
	check(mist_near > 3 and mist_near < at.call(4, 2), "the mist over the wall catches the lamp's light (%d)" % mist_near)
	check(mist_far <= mist_near - 2, "and it fades twice as fast in the mist (%d, then %d)" % [mist_near, mist_far])
	check(at.call(8, 2) < at.call(8, 4) or at.call(8, 2) == 3, "no light through the mist into the next room (%d)" % at.call(8, 2))
	var behind: int = at.call(9, 2)
	check(behind > 3 and behind < 15 - 7, "around the corner, but weaker than straight through (%d)" % behind)
	check(field.color_at(map.cell_to_world(Vector2i(2, 2))) == lighting.color_of(15), "each level has its color")
	check(lighting.color_of(12).v > lighting.color_of(11).v, "brighter level, brighter color")
	lamp.visible = false
	check(at.call(2, 2) == 3, "a hidden lamp is out")
	var torch := LightSource.new()
	torch.moves = true
	torch.level = 8
	torch.position = map.cell_to_world(Vector2i(10, 2))
	field.add_child(torch)
	check(at.call(10, 2) == 8 and at.call(9, 2) == 7, "a moving light too")
	check(at.call(2, 2) == 3, "...not through the walls")
	var flash := LightSource.new()
	flash.moves = true
	flash.relative = true
	flash.level = 4
	flash.position = map.cell_to_world(Vector2i(3, 4))
	field.add_child(flash)
	check(at.call(3, 4) == 7, "a flash counts above the floor's light")
	field.setup(map, lighting, Color(0.5, 0.5, 0.5))
	check(field.ambient_level == 2, "a darker floor (darkness, harder difficulty) has less light")
	field.queue_free()
	# Every theme: lit, darker as the light fades, never brighter than the art.
	for act in CONTENT.dungeon.acts:
		for biome in act.biomes:
			var theme_light := biome.theme.lighting
			check(theme_light != null and theme_light.ramp != null, "%s is lit" % biome.id)
			if theme_light == null:
				continue
			var ok := true
			for level in LightField.MAX_LEVEL:
				var low := theme_light.color_of(level)
				var high := theme_light.color_of(level + 1)
				ok = ok and high.get_luminance() >= low.get_luminance() - 0.001 and high.r <= 1.0 and high.g <= 1.0 and high.b <= 1.0
			check(ok, "%s: its light dims step by step" % biome.id)


## Runes and sockets: 1 to 3 by rarity, saved with the weapon, working like a perk while worn.
## Item level: gear is as strong as the floor it came from and never grows; deeper is better.
func _test_item_levels() -> void:
	var rules: ItemLevelRules = LootRoller.LEVELS
	check(rules != null and rules.weapon_dps_per_level > 0.0, "item level rules load (data/items/item_levels.tres)")
	var katana: WeaponDef = load("res://data/items/weapons/katana.tres")
	var hammer: WeaponDef = load("res://data/items/weapons/hammer.tres")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var config := CONTENT.dungeon
	var none: Array[ItemAffixDef] = []
	check(LootRoller.roll(katana, 1, 0.0, config, none, rng) == katana, "a common floor-1 find is the plain item (level 1)")
	var floor5 := LootRoller.roll(katana, 5, 0.0, config, none, rng) as WeaponDef
	check(floor5 != katana and floor5.item_level == 5 and floor5.rarity == ItemRarity.COMMON, "a common floor-5 find is a level-5 copy")
	var levels: Array[WeaponDef] = []
	for level in [1, 2, 6, 12]:
		levels.append(LootRoller.make(katana, ItemRarity.COMMON, none, [], level) as WeaponDef)
	check(levels[0].damage == katana.damage, "level 1: the plain damage")
	check(levels[1].damage >= levels[0].damage and levels[2].damage > levels[1].damage and levels[3].damage > levels[2].damage, "deeper gear hits harder (%s)" % str(levels.map(func(w: WeaponDef) -> int: return w.damage)))
	# Same damage per second gained, whatever the weapon's speed.
	var fast := float(levels[3].damage - katana.damage) / katana.cooldown
	var slow_weapon := LootRoller.make(hammer, ItemRarity.COMMON, none, [], 12) as WeaponDef
	var slow := float(slow_weapon.damage - hammer.damage) / hammer.cooldown
	check(absf(fast - slow) <= 2.5 and slow_weapon.damage - hammer.damage > levels[3].damage - katana.damage, "a level gives a quick and a slow weapon the same damage per second (%.1f vs %.1f)" % [fast, slow])
	var rare12 := LootRoller.make(katana, ItemRarity.RARE, none, [], 12) as WeaponDef
	check(rare12.damage > levels[3].damage, "rarity adds on top of the level")
	var rare2 := LootRoller.make(katana, ItemRarity.RARE, none, [], 2) as WeaponDef
	check(levels[3].damage > rare2.damage, "a common floor-12 weapon beats a rare floor-2 one: loot to get stronger")
	var armor: ArmorDef = null
	for item in CONTENT.items:
		if item is ArmorDef and (item as ArmorDef).slot == EquipmentDef.Slot.BODY:
			armor = item
			break
	if armor:
		var base_hp := armor.bonuses.max_hp if armor.bonuses else 0
		var deep := LootRoller.make(armor, ItemRarity.COMMON, none, [], 10)
		check(deep.bonuses.max_hp > base_hp, "deeper armor gives more Health (%d vs %d)" % [deep.bonuses.max_hp, base_hp])
	var back := LootRoller.from_data(JSON.parse_string(JSON.stringify(LootRoller.to_data(rare12)))) as WeaponDef
	check(back.item_level == 12 and back.damage == rare12.damage, "the item level comes back from a save")
	check(LootRoller.from_data({ "base": RunSave.ref(katana), "rarity": 1, "affixes": [], "runes": [] }).item_level == 1, "old saves without a level: level 1")
	check(rare12.get_details().begins_with("Item level 12"), "the item card says its level")
	var compare := ItemCompare.lines(rare12, levels[1])
	check(compare.size() > 0 and String(compare[0].text) == "+10 item levels" and compare[0].good, "the comparison starts with the level difference")


## Two ways down: where the second stairs go, and what each way offers.
func _test_routes() -> void:
	var rng := RandomNumberGenerator.new()
	var seconds := 0
	for i in 12:
		rng.seed = 900 + i
		var map := DungeonGenerator.generate(CONTENT.dungeon, rng)
		if map.second_stairs_cell == DungeonMap.NO_CELL:
			continue
		seconds += 1
		var second := Vector2(map.second_stairs_cell)
		check(map.is_floor(map.second_stairs_cell) and second.distance_to(Vector2(map.start_cell)) > 12.0 and second.distance_to(Vector2(map.stairs_cell)) > 12.0, "the second stairs stand far from the start and the first (seed %d)" % (900 + i))
		check(map.exit_cells().size() == 2 and map.exit_cells()[0] == map.stairs_cell, "exit_cells lists both")
	check(seconds >= 10, "most floors have room for a second way down (%d of 12)" % seconds)
	var arena := DungeonGenerator.generate_arena(CONTENT.dungeon, rng)
	check(arena.second_stairs_cell != DungeonMap.NO_CELL and arena.boss_room.has_point(arena.second_stairs_cell), "a boss arena has room for two stairs")
	var normal := CONTENT.get_difficulty(&"normal")
	check(FloorRoute.offer(CONTENT, 1, normal, 1).is_empty(), "no choice toward floor 1")
	check(FloorRoute.offer(CONTENT, 3, normal, 1).is_empty(), "nor toward a boss floor")
	var twists := 0
	for offer_seed in 40:
		var ways := FloorRoute.offer(CONTENT, 2, normal, offer_seed)
		check(ways.size() == 2 and ways[0].biome != ways[1].biome, "two ways to two worlds (seed %d)" % offer_seed)
		var act := CONTENT.dungeon.act_for_depth(2)
		check(ways.all(func(w: FloorRoute) -> bool: return act.biomes.has(w.biome) and not (w.curse and w.floor_event)), "worlds of the act; a curse or an event, never both")
		if not ways[1].is_plain():
			twists += 1
		var same := FloorRoute.offer(CONTENT, 2, normal, offer_seed)
		check(same[0].biome == ways[0].biome and same[1].curse == ways[1].curse and same[1].floor_event == ways[1].floor_event, "the same seed, the same ways")
	check(twists >= 16, "the second way often has a twist (%d of 40)" % twists)


## The Tree of Souls: every upgrade on it once, branches that end on an oath, forks, feats,
## a reset that gives every soul back, and what the nodes and oaths do to a run.
func _test_soul_tree() -> void:
	var tree := CONTENT.soul_tree
	check(tree != null and tree.nodes.size() >= 24 and tree.branches.size() == 4, "a Tree of Souls with four branches (%d nodes)" % (tree.nodes.size() if tree else 0))
	if tree == null:
		return
	var on_tree := tree.nodes.map(func(n: SoulNodeDef) -> UpgradeDef: return n.upgrade)
	check(CONTENT.upgrades.all(func(u: UpgradeDef) -> bool: return on_tree.count(u) == 1), "every shrine upgrade sits on the tree, once")
	check(on_tree.all(func(u: UpgradeDef) -> bool: return CONTENT.upgrades.has(u)), "and every node's upgrade is in the content")
	var cells := {}
	for node in tree.nodes:
		check(not cells.has(node.cell), "%s: its own spot" % node.id())
		cells[node.cell] = true
		check(int(node.cell.x / 3.0) == node.branch, "%s: in its branch's columns" % node.id())
		check(node.requires.all(func(p: SoulNodeDef) -> bool: return p.cell.y < node.cell.y and p.branch == node.branch), "%s: its parents sit above it, in its branch" % node.id())
		if node.partner():
			check(node.partner().partner() == node and node.partner().cell.y == node.cell.y, "%s: a fork both ways, side by side" % node.id())
		check(not node.display_name().is_empty() and (node.oath != null or not UpgradeRow.status_text(node.upgrade, 0).ends_with(": ")), "%s: says what it gives" % node.id())
	for branch in tree.branches.size():
		var roots := tree.nodes.filter(func(n: SoulNodeDef) -> bool: return n.branch == branch and n.requires.is_empty())
		var ends := tree.nodes.filter(func(n: SoulNodeDef) -> bool: return n.branch == branch and n.oath != null)
		check(roots.size() == 1 and ends.size() == 1, "branch %s: one root, one oath at the end" % tree.branches[branch])
	check(tree.oaths().size() == 4, "four oaths")
	for oath: OathDef in tree.oaths():
		var gains := oath.effects().filter(func(line: Array) -> bool: return line[1] > 0)
		var costs := oath.effects().filter(func(line: Array) -> bool: return line[1] < 0)
		check(not gains.is_empty() and not costs.is_empty(), "%s: its card shows a gain and a cost (%d, %d)" % [oath.id, gains.size(), costs.size()])
		check(oath.lore.begins_with("\"") and oath.lore.ends_with("\"") and oath.lore.length() <= 120 and not oath.lore.contains("%"), "%s: its vow is one quoted line, never a rule (%s)" % [oath.id, oath.lore])

	var saved_levels := Profile.levels.duplicate()
	var saved_souls := Profile.souls
	var saved_achievements := Profile.achievements.duplicate()
	Profile.levels = {}
	Profile.achievements = {}
	Profile.souls = 100000
	var might := tree.find(&"might")
	var keen := tree.find(&"precision_training")
	var armory := tree.find(&"armory")
	check(not Profile.buy_node(keen), "a node can't be bought before the one above it")
	check(Profile.buy_node(might) and Profile.buy_node(keen), "...and can once it is")
	check(not Profile.buy_node(keen.partner()) and keen.partner().blocker().contains("instead"), "the other side of a fork is shut")
	check(Profile.buy_node(armory), "a node after a fork opens with either side")
	var trophy := tree.find(&"trophy_hunter")
	check(trophy.feat != null and not Profile.buy_node(trophy) and trophy.blocker().begins_with("Feat"), "a feat node waits for its feat")
	Profile.achievements[String(trophy.feat.id)] = 1
	check(Profile.buy_node(trophy), "...then opens")
	var spent := tree.spent()
	var souls := Profile.souls
	Profile.runs_since_reset = tree.reset_runs
	check(Profile.reset_tree(tree) and Profile.souls == souls + spent and tree.spent() == 0 and Profile.level_of(might.upgrade) == 0, "a reset gives every soul back")

	# What they do to a run.
	Profile.levels = { "haggler": 1, "full_stalls": 0, "regeneration": 2, "blood_pact": 1, "trophy_hunter": 1, "cartographer": 1 }
	var plunderer: OathDef = load("res://data/oaths/plunderer.tres")
	var boons := RunBoons.build(CONTENT, plunderer)
	check(is_equal_approx(boons.shop_price_scale, 0.85 * plunderer.shop_price_scale) and is_equal_approx(boons.heal_on_clear, 0.1), "run rules add up (prices %.2f, heal %.2f)" % [boons.shop_price_scale, boons.heal_on_clear])
	check(boons.elite_magic_drop and boons.cartographer and is_equal_approx(boons.healing_scale, 0.7) and boons.gold_scale > 1.0, "flags, heals and the oath's gold")
	Profile.levels = {}
	var colossus: OathDef = load("res://data/oaths/colossus.tres")
	var plain := PLAYER.instantiate() as Player
	plain.setup(CONTENT.player)
	ShrineUpgrades.apply_to(plain, CONTENT, CONTENT.get_difficulty(&"normal"))
	var sworn := PLAYER.instantiate() as Player
	sworn.setup(CONTENT.player)
	ShrineUpgrades.apply_to(sworn, CONTENT, CONTENT.get_difficulty(&"normal"), colossus)
	check(sworn.equipment.get_item(EquipmentDef.Slot.WEAPON) == colossus.starting_weapon, "the Colossus starts with the Hammer")
	check(sworn.get_max_hp() == roundi(plain.get_max_hp() * 1.3) and sworn.base_stats.move_speed < plain.base_stats.move_speed, "with more Health and a slower step (%d vs %d)" % [sworn.get_max_hp(), plain.get_max_hp()])
	Profile.levels = { "armory": 1 }
	var bow: WeaponDef = load("res://data/items/weapons/bow.tres")
	var armed := PLAYER.instantiate() as Player
	armed.setup(CONTENT.player)
	ShrineUpgrades.apply_to(armed, CONTENT, CONTENT.get_difficulty(&"normal"), null, bow)
	check(armed.equipment.get_item(EquipmentDef.Slot.WEAPON) == bow, "the Armory: the run starts with the weapon picked")
	var duelist := PLAYER.instantiate() as Player
	duelist.crit_damage_bonus = 0.75
	var crit := Combat.make_hit(100, 1.0, duelist)
	check(crit.is_crit and crit.amount >= roundi(100 * 0.85 * 2.5) - 1, "the Duelist's crits hit x2.5 (%d)" % crit.amount)
	duelist.healing_scale = 0.5
	duelist.base_stats.max_hp = 100
	duelist.invalidate_stats()
	duelist.hp = 10
	check(duelist.heal(20) == 10, "a weaker heal heals less")
	for hero in [plain, sworn, armed, duelist]:
		hero.free()
	Profile.levels = saved_levels
	Profile.souls = saved_souls
	Profile.achievements = saved_achievements


## The Armory is bought in levels: level 1 a weapon per way to fight, each next level two more,
## in the order its data lists them (the rare ones last); weapons still locked in the dungeon are
## never offered; a starting weapon the level doesn't offer falls back to the usual one.
func _test_armory_levels() -> void:
	var armory: UpgradeDef = load("res://data/upgrades/armory.tres")
	check(armory.armory and armory.max_level >= 4 and armory.max_level <= 6, "the Armory has 4-6 levels (%d)" % armory.max_level)
	check(armory.armory_count(armory.max_level) == armory.armory_weapons.size() and armory.armory_count(armory.max_level - 1) < armory.armory_weapons.size(), "its last level opens the last weapon of its list, not before")
	var ids := armory.armory_weapons.map(func(w: WeaponDef) -> StringName: return w.id)
	check(ids.slice(0, 3) == [&"katana", &"bow", &"stick"], "level 1: the Katana, the Bow and the Frost Staff (%s)" % [ids.slice(0, 3)])
	var oath_weapons := CONTENT.soul_tree.oaths().map(func(o: OathDef) -> WeaponDef: return o.starting_weapon)
	check(armory.armory_weapons.all(func(w: WeaponDef) -> bool: return w != null and not oath_weapons.has(w) and ids.count(w.id) == 1), "each weapon once, none an oath's (they come with their oath)")
	for level in range(1, armory.max_level):
		check(armory.cost_for_level(level) > armory.cost_for_level(level - 1), "Armory level %d costs more than the one before (%d > %d)" % [level + 1, armory.cost_for_level(level), armory.cost_for_level(level - 1)])
	check(armory.cost_for_level(0) <= 150, "its first level is cheap (%d souls)" % armory.cost_for_level(0))
	var saved_levels := Profile.levels.duplicate()
	var saved_weapon := Profile.starting_weapon
	Profile.levels = {}
	check(ShrineUpgrades.armory_weapons(CONTENT).is_empty() and not OathPanel.has_armory(CONTENT), "no Armory: no weapon to pick")
	var offered: Array[WeaponDef] = []
	for level in range(1, armory.max_level + 1):
		Profile.levels = { "armory": level }
		var weapons := ShrineUpgrades.armory_weapons(CONTENT)
		var expected := armory.armory_weapons.slice(0, armory.armory_count(level)).filter(func(w: WeaponDef) -> bool: return not CONTENT.locked_items.has(w))
		check(weapons == expected, "Armory level %d: its weapons in data order (%s)" % [level, weapons.map(func(w: WeaponDef) -> StringName: return w.id)])
		check(weapons.slice(0, offered.size()) == offered and (level == 1 or armory.armory_added(level).size() == armory.armory_per_level), "Armory level %d keeps the ones before and adds %d" % [level, armory.armory_per_level])
		check(weapons.all(func(w: WeaponDef) -> bool: return not CONTENT.locked_items.has(w)), "Armory level %d: nothing still locked in the dungeon" % level)
		offered = weapons
	check(offered.size() >= 9, "the whole Armory offers most of the roster (%d)" % offered.size())
	var templar: WeaponDef = load("res://data/items/weapons/templar_sword.tres")
	check(CONTENT.locked_items.has(templar) and armory.armory_weapons.has(templar) and not offered.has(templar), "the Templar Sword waits for its unlock (Templar's Vow)")
	var next := UpgradeRow.armory_status(armory, armory.max_level - 1, CONTENT)
	check(next.contains(templar.display_name + " (locked)"), "the detail marks a weapon still locked (%s)" % next)
	var unlock := CONTENT.upgrades.filter(func(u: UpgradeDef) -> bool: return u.kind == UpgradeDef.Kind.UNLOCK and u.items.has(templar))
	check(unlock.size() == 1, "an upgrade unlocks the Templar Sword")
	if unlock.size() == 1:
		Profile.levels[String(unlock[0].id)] = 1
		check(ShrineUpgrades.armory_weapons(CONTENT).has(templar), "...then the Armory offers it")
		check(not UpgradeRow.armory_status(armory, armory.max_level - 1, CONTENT).contains("(locked)"), "...and the detail no longer says locked")
	var status := UpgradeRow.armory_status(armory, 2, CONTENT)
	check(status.contains("Next: +2 weapons: %s, %s" % [armory.armory_weapons[5].display_name, armory.armory_weapons[6].display_name]), "the Armory's detail names the next level's weapons (%s)" % status)
	check(UpgradeRow.armory_status(armory, 0).contains("Katana, Bow, Frost Staff") and UpgradeRow.armory_status(armory, armory.max_level).contains("maxed"), "...what level 1 gives, and maxed")
	# An older save: the Armory bought once (now level 1), and any weapon picked then.
	Profile.levels = { "armory": 1 }
	Profile.starting_weapon = &"big_sword"
	check(Game.picked_weapon(CONTENT) == null, "a starting weapon the Armory's level doesn't offer: the usual one")
	var hero := PLAYER.instantiate() as Player
	hero.setup(CONTENT.player)
	ShrineUpgrades.apply_to(hero, CONTENT, CONTENT.get_difficulty(&"normal"), null, load("res://data/items/weapons/big_sword.tres"))
	check(hero.equipment.get_item(EquipmentDef.Slot.WEAPON) == OathPanel.usual_weapon(CONTENT), "...and the run starts with it, whatever is asked")
	hero.free()
	Profile.starting_weapon = &"bow"
	check(Game.picked_weapon(CONTENT) == load("res://data/items/weapons/bow.tres"), "a weapon of level 1 is kept")
	Profile.starting_weapon = &"no_such_weapon"
	check(Game.picked_weapon(CONTENT) == null, "an unknown id: the usual one, no crash")
	Profile.levels = saved_levels
	Profile.starting_weapon = saved_weapon


## Resetting the Tree of Souls is earned: once every `reset_runs` finished runs (daily ones too),
## counted by Profile.record_run; it gives back every soul spent, every level; older saves start
## with one earned.
func _test_tree_reset_runs() -> void:
	var tree := CONTENT.soul_tree
	check(tree.reset_runs == 3, "a reset takes 3 runs (%d)" % tree.reset_runs)
	# The profile as it is, put back at the end (runs are recorded and saves loaded below).
	var backup := "user://test_profile_backup_%d.json" % OS.get_process_id()
	Profile.save_path = backup
	Profile.save_profile()
	Profile.save_path = ""
	Profile.levels = {}
	Profile.runs_since_reset = 0
	Profile.souls = 100000
	var might := tree.find(&"might")
	var fury := tree.find(&"fury_training")
	var armory := tree.find(&"armory")
	check(Profile.buy_node(might) and Profile.buy_node(might) and Profile.buy_node(might) and Profile.buy_node(fury), "a few levels bought")
	for i in 3:
		check(Profile.buy_node(armory), "Armory level %d bought" % (i + 1))
	check(armory.level() == 3 and might.level() == 3, "levels on two nodes")
	var spent := tree.spent()
	var paid := fury.upgrade.cost_for_level(0)
	for level in 3:
		paid += might.upgrade.cost_for_level(level) + armory.upgrade.cost_for_level(level)
	check(spent == paid and spent == 100000 - Profile.souls, "the tree knows every soul spent, every level (%d)" % spent)
	check(Profile.reset_runs_left(tree) == 3 and not Profile.can_reset_tree(tree) and not Profile.reset_tree(tree) and armory.level() == 3, "no reset before its runs")
	check(ShrinePanel.reset_label(Profile.reset_runs_left(tree)) == "Reset in 3 runs" and ShrinePanel.reset_label(1) == "Reset in 1 run" and ShrinePanel.reset_label(0) == "Reset the tree", "the button says how many runs are left")
	Profile.record_run(0, 3, false, &"normal")
	Profile.record_run(0, 5, false, &"easy", false, true)
	check(Profile.reset_runs_left(tree) == 1, "each finished run counts, Pilgrim's too (%d left)" % Profile.reset_runs_left(tree))
	Profile.record_run(10, 12, false, &"normal", true, false)
	check(Profile.reset_runs_left(tree) == 1, "the endless floors after a win are not another run")
	var quit := RunState.create(CONTENT, {}, RandomNumberGenerator.new())
	quit.award_souls(false, CONTENT.ascensions.size())
	check(Profile.reset_runs_left(tree) == 1, "a run given up on its first floor doesn't count toward the reset")
	var daily := RunState.create(CONTENT, {}, RandomNumberGenerator.new(), 20000)
	daily.depth = tree.reset_min_depth
	daily.award_souls(false, CONTENT.ascensions.size())
	check(daily.is_daily() and Profile.reset_runs_left(tree) == 0 and Profile.can_reset_tree(tree), "a daily run counts too: the reset is earned")
	var won := RunState.create(CONTENT, {}, RandomNumberGenerator.new())
	won.depth = 12
	won.has_won = true
	won.award_souls(true, CONTENT.ascensions.size())
	var count := Profile.runs_since_reset
	won.award_souls(false, CONTENT.ascensions.size())
	check(Profile.runs_since_reset == count, "a won run dying later in the endless floors counted once")
	var souls := Profile.souls
	check(Profile.reset_tree(tree) and Profile.souls == souls + spent and tree.spent() == 0 and armory.level() == 0 and might.level() == 0, "the reset gives back every level's souls (%d)" % spent)
	check(Profile.runs_since_reset == 0 and Profile.reset_runs_left(tree) == 3 and not Profile.can_reset_tree(tree), "then the count starts again")
	# An older save (no count kept) starts with a reset earned; the count is saved after that.
	var path := "user://test_profile_reset_%d.json" % OS.get_process_id()
	SafeFile.write_json(path, { "souls": 5, "levels": { "might": 2, "armory": 1 }, "starting_weapon": "big_sword" })
	Profile.save_path = path
	Profile.load_profile()
	check(Profile.reset_runs_left(tree) == 0 and Profile.can_reset_tree(tree) and might.level() == 2, "an older save starts with a reset earned")
	check(armory.level() == 1 and Game.picked_weapon(CONTENT) == null, "an older save's Armory is level 1, its weapon out of it falls back to the usual one")
	Profile.runs_since_reset = 2
	Profile.save_profile()
	Profile.runs_since_reset = 0
	Profile.load_profile()
	check(Profile.runs_since_reset == 2, "the count is saved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Profile.save_path = backup
	Profile.load_profile()
	Profile.save_path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))


## Pilgrim spares the hero but pays less: fewer souls, rarer good gear, no feats; and says so.
func _test_pilgrim_costs() -> void:
	var pilgrim := CONTENT.get_difficulty(&"easy")
	var keeper := CONTENT.get_difficulty(&"normal")
	check(pilgrim.souls < 1.0 and pilgrim.loot_quality < 1.0 and not pilgrim.counts_feats and keeper.counts_feats, "Pilgrim: fewer souls, rarer good gear, no feats")
	# Its souls (balance-log 2026-10-23): a Pilgrim career must still fill the tree (x0.5 paid
	# under half a Keeper run's souls for the same run, with smaller floors on top: 77 runs to the
	# tree vs Keeper's 47), and never as fast as Keeper (less risk). x0.65: 64 runs.
	check(pilgrim.souls >= 0.6 and pilgrim.souls <= 0.75 and pilgrim.souls < keeper.souls, "Pilgrim pays about two thirds of Keeper's souls (x%s)" % pilgrim.souls)
	var costs := DifficultyCard.effects(pilgrim, keeper).filter(func(e: Array) -> bool: return e[1] < 0)
	check(costs.size() >= 2, "its card lists what it costs, in red (%d lines)" % costs.size())
	var rules := FloorRules.make(CONTENT.dungeon, pilgrim, null, 3)
	check(is_equal_approx(rules.loot_quality(), pilgrim.loot_quality), "its loot quality reaches the floor's rules")
	var saved_stats := Profile.stats.duplicate()
	var saved_periods := Profile.period_stats.duplicate(true)
	var before := Profile.stat_value("kills")
	var period: String = Profile._current_periods()[0]
	var period_before := Profile.period_stat(period, "kills")
	Profile.add_stat("kills", 1, false)
	check(Profile.stat_value("kills") == before and Profile.period_stat(period, "kills") == period_before + 1, "a Pilgrim kill counts for quests, not for feats")
	Profile.stats = saved_stats
	Profile.period_stats = saved_periods


## The loading screen: an autoload, idle, with tips to show.
func _test_loader() -> void:
	var loader := get_node_or_null("/root/Loader")
	check(loader != null and loader.has_method("go") and not loader.busy, "the Loader autoload is there, idle")
	var tips: LoadingTipsDef = load("res://data/ui/loading_tips.tres")
	check(tips.tips.size() >= 10 and Array(tips.tips).all(func(t: String) -> bool: return t.length() > 20 and t.length() <= 110), "loading tips: at least 10, each one short line or two")


## The builds (export_presets.cfg) leave out what is only for making the game: the tests, the
## tools, the docs, the roadmap (a .json is a resource: it would ship), and hold no password.
func _test_export_presets() -> void:
	var presets := ConfigFile.new()
	check(presets.load("res://export_presets.cfg") == OK, "the export presets are readable")
	var names: Array[String] = []
	for section in presets.get_sections():
		if section.ends_with(".options") or not section.begins_with("preset."):
			if section.ends_with(".options"):
				for key in presets.get_section_keys(section):
					var value := str(presets.get_value(section, key))
					check(not ("password" in key and not value.is_empty()), "%s: no password in the presets (%s)" % [section, key])
			continue
		var preset_name := str(presets.get_value(section, "name", section))
		names.append(preset_name)
		var excluded := str(presets.get_value(section, "exclude_filter", "")).split(",", false)
		for i in excluded.size():
			excluded[i] = excluded[i].strip_edges()
		for folder in ["tests/*", "tools/*", "_tool/*", "docs/*", "data/balance/*", "godoban_boards/*"]:
			check(excluded.has(folder), "the %s build leaves out %s" % [preset_name, folder])
	check(names.has("Android") and names.has("Windows Desktop"), "Android and Windows builds (%s)" % [names])


func _test_runes() -> void:
	check(CONTENT.runes.size() >= 10, "runes to find (%d)" % CONTENT.runes.size())
	var families := {}
	for rune in CONTENT.runes:
		check(rune.family != null and not rune.passives.is_empty() and rune.icon != null and not rune.description.is_empty(), "%s: a family, a power, a look, words" % rune.id)
		check(not CONTENT.items.has(rune), "%s: not in the random items" % rune.id)
		if rune.family:
			families[rune.family] = true
	check(families.size() >= 5, "runes of every family")
	var katana: WeaponDef = load("res://data/items/weapons/katana.tres")
	var armor: EquipmentDef = null
	for item in CONTENT.items:
		if item is EquipmentDef and (item as EquipmentDef).slot == EquipmentDef.Slot.BODY:
			armor = item
			break
	check(katana.socket_count() == 1 and (armor == null or armor.socket_count() == 0), "a plain weapon has 1 socket, armor none")
	var rare := LootRoller.make(katana, ItemRarity.RARE, [])
	var epic := LootRoller.make(katana, ItemRarity.EPIC, [])
	check(rare.socket_count() == 2 and epic.socket_count() == 3, "rare 2 sockets, epic 3")
	var ember: RuneDef = CONTENT.runes[0]
	var copy := LootRoller.make(katana, ItemRarity.COMMON, [])
	copy.runes.append(ember)
	check(katana.runes.is_empty(), "a rune in a copy never touches the plain weapon")
	var back := LootRoller.from_data(LootRoller.to_data(copy)) as EquipmentDef
	check(back.rarity == ItemRarity.COMMON and back.runes == copy.runes and back.base_item == katana, "a common weapon with a rune comes back from a save")
	var perks := PerkSet.new()
	perks.set_gear([], [ember, ember])
	check(perks._gear.size() == 2, "each set rune works like a perk")
	var smith: ForgeDef = CONTENT.dungeon.forge
	check(smith != null and smith.removal_cost(8) > smith.removal_cost(1), "the smith charges more deeper down")
	check(CONTENT.dungeon.forge_chance > 0.0 and CONTENT.dungeon.boss_runes >= 1, "forges show up, bosses drop runes")
	var bare: Array[StringName] = []
	for act in CONTENT.dungeon.acts:
		for monster in act.monsters:
			if monster and monster.material == null:
				bare.append(monster.id)
		for boss in act.all_bosses():
			if boss.material == null:
				bare.append(boss.id)
	check(bare.is_empty(), "every monster and boss is made of something %s" % str(bare))


func _test_monster_ranks() -> void:
	var config := CONTENT.dungeon
	check(config.elite_rank != null and config.rare_ranks.size() >= 3, "elite, epic, legendary and shiny ranks")
	for rank in config.rare_ranks:
		check(rank.chance_at(rank.min_depth - 1) == 0.0 and rank.chance_at(40) <= rank.max_chance, "%s: from its depth, capped" % rank.id)
		check(rank.boss_chance > 0.0, "%s: bosses can come at it" % rank.id)
	var ids := config.rare_ranks.map(func(r: MonsterRankDef) -> StringName: return r.id)
	check(ids.find(&"shiny") < ids.find(&"legendary") and ids.find(&"legendary") < ids.find(&"epic"), "rarest first")
	# The ladder (balance phase 2B): each rank tougher and more dangerous than the one below, at
	# every depth, and tougher deeper (the hero's power outgrows the depth scaling).
	var elite := config.elite_rank
	var epic: MonsterRankDef = load("res://data/monster_ranks/epic.tres")
	var legendary: MonsterRankDef = load("res://data/monster_ranks/legendary.tres")
	var shiny: MonsterRankDef = load("res://data/monster_ranks/shiny.tres")
	for depth in [1, 2, 5, 8, 11, 20]:
		check(1.0 < elite.hp_multiplier_at(depth) and elite.hp_multiplier_at(depth) < epic.hp_multiplier_at(depth)
			and epic.hp_multiplier_at(depth) < legendary.hp_multiplier_at(depth), "depth %d: Elite < Epic < Legendary in health" % depth)
		check(shiny.hp_multiplier_at(depth) < epic.hp_multiplier_at(depth), "depth %d: a Shiny is a treasure, not a duel" % depth)
		for rank in [elite, epic, legendary, shiny]:
			check(rank.hp_multiplier_at(depth + 1) >= rank.hp_multiplier_at(depth), "%s: no weaker deeper" % rank.id)
	check(1.0 < elite.damage_multiplier and elite.damage_multiplier <= epic.damage_multiplier and epic.damage_multiplier <= legendary.damage_multiplier
		and legendary.damage_multiplier <= 1.5, "ranks hit harder, a little (Elite <= Epic <= Legendary <= x1.5)")
	check(shiny.damage_multiplier == 1.0, "a Shiny hits like its kind")
	# Bosses keep their own depth scaling (tuned one by one); monsters grow by theirs.
	var deep := FloorRules.make(config, null, null, 9)
	var slime: MonsterDef = load("res://data/monsters/slime.tres")
	var boss: BossDef = config.acts[0].boss
	check(deep.scale_monster(boss.stats, true).max_hp == roundi(boss.stats.max_hp * (1.0 + config.boss_hp_scale_per_depth * 8))
		and deep.scale_monster(boss.stats, true).attack == boss.stats.attack + roundi(config.boss_attack_per_depth * 8), "bosses scale with the boss depth values")
	check(deep.scale_monster(slime.stats, false).max_hp == roundi(slime.stats.max_hp * (1.0 + config.monster_hp_scale_per_depth * 8) * config.act_for_depth(9).monster_hp)
		and deep.scale_monster(slime.stats, false).attack == slime.stats.attack + roundi(config.monster_attack_per_depth * 8), "monsters scale with the monster depth values (and their act's own threat)")


## The bestiary: ranks paid once, challenges met by the right kills, mastery.
func _test_bestiary() -> void:
	var rules := CONTENT.bestiary
	check(rules != null and rules.monster_kills.size() == rules.rank_count() and rules.monster_souls.size() == rules.rank_count() and rules.boss_kills.size() == rules.boss_souls.size(), "the bestiary's ranks are complete")
	var slime: MonsterDef = load("res://data/monsters/slime.tres")
	var frog: MonsterDef = load("res://data/monsters/bosses/giant_frog.tres")
	var bat: MonsterDef = load("res://data/monsters/bat.tres")
	Profile.reset()
	check(Bestiary.rank_of(slime, rules) == Bestiary.UNSEEN, "never met: unknown")
	Profile.mark_seen(slime.id)
	check(Bestiary.rank_of(slime, rules) == Bestiary.SEEN, "met: seen")
	for i in rules.monster_kills[1]:
		Profile.record_kill(slime.id)
	var paid := Bestiary.claim(slime, rules)
	check(paid.size() == 2 and Profile.souls == rules.monster_souls[0] + rules.monster_souls[1], "two ranks reached, both paid (%d souls)" % Profile.souls)
	check(Bestiary.claim(slime, rules).is_empty(), "paid once")
	check(Bestiary.damage_multiplier(slime, rules) == 1.0, "not mastered yet")
	for i in rules.monster_kills[2]:
		Profile.record_kill(slime.id)
	Bestiary.claim(slime, rules)
	check(Bestiary.is_mastered(slime, rules) and is_equal_approx(Bestiary.damage_multiplier(slime, rules), 1.0 + rules.mastery_damage), "mastered: more damage to it")
	# The Celestial on a page only for a kind that can come at that rank (the rare ranks' rules).
	var finale := CONTENT.dungeon.finale
	check(Bestiary.can_be_celestial(slime, CONTENT) and Bestiary.can_be_celestial(frog, CONTENT), "a floor's own monster and an act's warden can come Celestial")
	check(not Bestiary.can_be_celestial(finale.boss, CONTENT) and not Bestiary.can_be_celestial(finale.boss.next_boss, CONTENT) and not Bestiary.can_be_celestial(finale.keeper, CONTENT), "never Tôma, the Maw (a fight of two forms) nor the Nameless Keeper (as written): their pages list no Celestial")
	check(not finale.keeper.rolls_rank() and not finale.boss.rolls_rank() and frog.rolls_rank(), "a boss rolls a rare rank only fought alone and not as written (BossArena)")
	var deeps := CONTENT.abyss_monsters().filter(func(m: MonsterDef) -> bool: return not CONTENT.all_monsters().has(m))
	check(not deeps.is_empty() and deeps.all(func(m: MonsterDef) -> bool: return not Bestiary.can_be_celestial(m, CONTENT)), "never the Deeps' demons (plain elites at most)")
	if CONTENT.dungeon.hidden_floor:
		check(Bestiary.can_be_celestial(CONTENT.dungeon.hidden_floor.boss, CONTENT), "the hidden floor's warden can (its arena rolls it)")
	# Challenges: the common ones that apply, and a boss' own.
	var ids := rules.challenges_for(slime).map(func(c: HuntChallenge) -> StringName: return c.id)
	check(ids.has(&"elite") and ids.has(&"pit") and not ids.has(&"fast"), "a monster gets the monster challenges")
	check(not rules.challenges_for(bat).any(func(c: HuntChallenge) -> bool: return c.goal == HuntChallenge.Goal.PIT), "no hole challenge for flyers")
	var boss_list := rules.challenges_for(frog)
	check(boss_list.any(func(c: HuntChallenge) -> bool: return c.goal == HuntChallenge.Goal.FAST) and boss_list.any(func(c: HuntChallenge) -> bool: return c.goal == HuntChallenge.Goal.WEAPON and c.weapon != null), "a boss gets the boss challenges and its own")
	for monster in CONTENT.all_monsters():
		for challenge in rules.challenges_for(monster):
			check(not challenge.describe(monster).is_empty() and challenge.souls > 0, "%s/%s is described and paid" % [monster.id, challenge.id])
	var kill := { "elite": true, "pushed_in": false, "crit": false, "weapon": null, "weapon_base": null, "untouched": false,
		"kill_times": [1.0, 2.0, 4.0], "now": 4.5, "fight_time": 70.0, "potions_in_fight": 1, "hp_lost_in_fight": 0.1 }
	var by_goal := func(goal: HuntChallenge.Goal, list: Array) -> HuntChallenge:
		for c: HuntChallenge in list:
			if c.goal == goal:
				return c
		return null
	var slime_list := rules.challenges_for(slime)
	check(by_goal.call(HuntChallenge.Goal.ELITE, slime_list).met(kill) and not by_goal.call(HuntChallenge.Goal.PIT, slime_list).met(kill), "an elite kill meets the elite challenge only")
	check(by_goal.call(HuntChallenge.Goal.STREAK, slime_list).met(kill), "three kills within 5 s: a streak")
	kill.kill_times = [0.5, 4.0]
	check(not by_goal.call(HuntChallenge.Goal.STREAK, slime_list).met(kill), "two are not a streak")
	check(by_goal.call(HuntChallenge.Goal.FAST, boss_list).met(kill) and by_goal.call(HuntChallenge.Goal.HEALTHY, boss_list).met(kill) and not by_goal.call(HuntChallenge.Goal.NO_POTION, boss_list).met(kill), "boss fight: fast and healthy, but a potion was drunk")
	var own: HuntChallenge = by_goal.call(HuntChallenge.Goal.WEAPON, boss_list)
	kill.weapon_base = own.weapon
	check(own.met(kill), "its own challenge: with the right weapon")
	check(Profile.complete_challenge(frog.id, own.id, own.souls) and not Profile.complete_challenge(frog.id, own.id, own.souls) and Profile.is_challenge_done(frog.id, own.id), "a challenge is done (and paid) once")
	Profile.reset()


## Every perk, relic and affix has a purpose; a build-around belongs to a family.
func _test_roles() -> void:
	var unset: Array[String] = []
	var lone: Array[String] = []
	for perk in CONTENT.perks:
		if perk.role == BuildRole.Role.UNSET:
			unset.append(String(perk.id))
		elif perk.role == BuildRole.Role.BUILD_AROUND and not perk.synergies.any(func(s: SynergyDef) -> bool: return CONTENT.synergies.has(s)):
			lone.append(String(perk.id))
	for affix in CONTENT.item_affixes:
		if affix.role == BuildRole.Role.UNSET:
			unset.append(String(affix.id))
		elif affix.role == BuildRole.Role.BUILD_AROUND and not CONTENT.synergies.has(affix.family):
			lone.append(String(affix.id))
		if affix.family:
			check(CONTENT.synergies.has(affix.family), "%s: its family %s is listed" % [affix.id, affix.family.id])
	check(unset.is_empty(), "every perk, relic and affix says if it is a staple or a build-around (decision 0012: %s)" % ", ".join(unset))
	check(lone.is_empty(), "every build-around belongs to a family (%s)" % ", ".join(lone))
	for id: String in ["strength", "precision", "fortune", "war_banner"]:
		var perk := _perk(id)
		check(perk != null and perk.role == BuildRole.Role.STAPLE and perk.synergies.is_empty(), "%s: a staple, in no family (docs/design/builds.md)" % id)
	var themed := {&"burning": &"inferno", &"of_embers": &"inferno", &"frozen": &"frost", &"shattering": &"frost", &"shocking": &"storm", &"vampiric": &"blood", &"of_echoes": &"arcane"}
	for id: StringName in themed:
		var affix := _affix_named(id)
		check(affix != null and affix.role == BuildRole.Role.BUILD_AROUND and affix.family != null and affix.family.id == themed[id], "%s joins its element's family, %s" % [id, themed[id]])
	var families := {}
	for perk in CONTENT.perks:
		if perk.role == BuildRole.Role.BUILD_AROUND:
			for synergy in perk.synergies:
				families[synergy] = true
	check(CONTENT.synergies.all(func(s: SynergyDef) -> bool: return families.has(s)), "every family has something to build around")


func _affix_named(id: StringName) -> ItemAffixDef:
	for affix in CONTENT.item_affixes:
		if affix.id == id:
			return affix
	return null


## Perk families: sound data, waking at 3 different perks, saved and loaded.
func _test_synergies() -> void:
	check(CONTENT.synergies.size() >= 5, "at least 5 perk families")
	# Choices that change how you play, not just numbers.
	var doers := CONTENT.perks.filter(func(p: PerkDef) -> bool: return not p.passives.is_empty())
	check(doers.size() * 3 >= CONTENT.perks.size() * 2, "two perks in three do something (%d/%d)" % [doers.size(), CONTENT.perks.size()])
	var active_affixes := CONTENT.item_affixes.filter(func(a: ItemAffixDef) -> bool: return a.on_hit != null or not a.passives.is_empty())
	check(active_affixes.size() * 3 >= CONTENT.item_affixes.size(), "a third of the affixes do something (%d/%d)" % [active_affixes.size(), CONTENT.item_affixes.size()])
	for affix in CONTENT.item_affixes:
		if not affix.passives.is_empty():
			check(not affix.description.is_empty(), "%s says what it does" % affix.id)
	var members := {}
	for perk in CONTENT.perks:
		for synergy in perk.synergies:
			check(CONTENT.synergies.has(synergy), "%s: its family %s is listed" % [perk.id, synergy.id if synergy else &"null"])
			members[synergy] = members.get(synergy, 0) + 1
	for synergy in CONTENT.synergies:
		check(synergy.icon != null and not synergy.description.is_empty() and not synergy.passives.is_empty(), "%s: icon, text and a bonus that does something" % synergy.id)
		check(members.get(synergy, 0) >= synergy.pieces + 1, "%s: enough perks to choose from (%d)" % [synergy.id, members.get(synergy, 0)])
	var inferno: SynergyDef = _perk("ignite").synergies[0]
	var perk_set := PerkSet.new()
	var woke: Array[SynergyDef] = []
	perk_set.synergy_awakened.connect(func(synergy: SynergyDef) -> void: woke.append(synergy))
	perk_set.add(_perk("ignite"))
	perk_set.add(_perk("ignite"))
	perk_set.add(_perk("blazing_roll"))
	check(perk_set.pieces_of(inferno) == 2 and not perk_set.is_awake(inferno), "two stacks of one perk count once")
	check(perk_set.would_complete(_perk("kindling"), inferno) and not perk_set.would_complete(_perk("ignite"), inferno), "a third different perk would wake the family")
	perk_set.add(_perk("kindling"))
	check(perk_set.is_awake(inferno) and woke == [inferno], "three different perks wake it, once")
	check(perk_set.awakened() == [inferno] and perk_set.families().has(inferno), "awake families are listed")
	var copy := PerkSet.new()
	copy.synergy_awakened.connect(func(synergy: SynergyDef) -> void: woke.append(synergy))
	copy.load_data(perk_set.to_data())
	check(copy.is_awake(inferno) and woke.size() == 1, "a loaded run keeps it awake (without announcing it again)")
	perk_set.clear()
	check(not perk_set.is_awake(inferno), "a new run starts asleep")
	var skills := SkillSet.new()
	var skill := SkillDef.new()
	skill.cooldown = 5.0
	var list: Array[SkillDef] = [skill]
	skills.set_skills(list)
	skills._cooldowns[0] = 4.0
	skills.reset_cooldown(skill)
	check(skills.is_ready(0), "an echo leaves the skill ready again")

	# Offers: banished perks never come back; started families come more often.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var owned := PerkSet.new()
	var banished: Array[PerkDef] = [_perk("strength")]
	var never := true
	for i in 200:
		if CONTENT.pick_perks(owned, 3, PerkDef.Rarity.COMMON, rng, banished).has(_perk("strength")):
			never = false
	check(never, "a banished perk is never offered")
	owned.add(_perk("ignite"))
	owned.add(_perk("frenzy"))
	var inferno_count := [0, 0]
	for bias_index in 2:
		for i in 400:
			var picked: PerkDef = CONTENT.pick_perks(owned, 1, PerkDef.Rarity.COMMON, rng, [], [0.0, 1.0][bias_index])[0]
			if picked.synergies.has(inferno):
				inferno_count[bias_index] += 1
	check(inferno_count[1] > inferno_count[0] * 1.4, "offers lean toward a started family (%d vs %d of 400)" % [inferno_count[1], inferno_count[0]])
	var shop: ShopDef = CONTENT.dungeon.merchant
	check(shop.reroll_price(1, 1) > shop.reroll_price(0, 1) and shop.reroll_price(0, 8) > shop.reroll_price(0, 1), "shop rerolls cost more each time and deeper")
	# The daily run: the same day gives the same start; scores; the streak.
	check(DailyRun.weapon(CONTENT, 20000) == DailyRun.weapon(CONTENT, 20000) and DailyRun.relic(CONTENT, 20000) == DailyRun.relic(CONTENT, 20000), "a day always gives the same weapon and relic")
	var weapons := {}
	for d in 20:
		weapons[DailyRun.weapon(CONTENT, 20000 + d)] = true
	check(weapons.size() >= 3, "days differ (%d weapons in 20 days)" % weapons.size())
	check(DailyRun.floor_seed(20000, 2) != DailyRun.floor_seed(20000, 3) and DailyRun.floor_seed(20000, 2) == DailyRun.floor_seed(20000, 2), "one seed per floor")
	Profile.reset()
	Profile.start_daily(20000)
	Profile.finish_daily(20000, 120)
	Profile.start_daily(20001)
	check(Profile.daily_streak == 2 and Profile.daily_score == 0 and Profile.daily_best == 120, "two days in a row")
	Profile.finish_daily(20001, 80)
	Profile.finish_daily(20000, 999)
	check(Profile.daily_score == 80 and Profile.daily_best == 120, "only today's attempt counts")
	Profile.start_daily(20005)
	check(Profile.daily_streak == 1, "a day missed: the streak starts over")
	Profile.reset()
	var daily := RunState.create(CONTENT, {}, rng, 20000)
	check(daily.is_daily() and daily.difficulty == CONTENT.default_difficulty, "a daily run is on Normal")
	daily.daily_official = true
	var daily_again := RunState.create(CONTENT, daily.to_data(), rng)
	check(daily_again.daily_day == 20000 and daily_again.daily_official, "a saved daily run stays one")

	var state := RunState.create(CONTENT, {}, rng)
	check(state.rerolls >= CONTENT.dungeon.base_rerolls and state.banishes >= CONTENT.dungeon.base_banishes, "a new run starts with its rerolls and banishes")
	state.rerolls = 2
	state.banished.append(_perk("strength"))
	var again := RunState.create(CONTENT, state.to_data(), rng)
	check(again.rerolls == 2 and again.banished == banished, "a saved run keeps its rerolls and banished perks")


func _test_bosses() -> void:
	var config := CONTENT.dungeon
	check(config.acts.size() == 4 and config.total_floors() == 12, "4 acts of 3 floors")
	var bosses: Array[BossDef] = []
	for act in config.acts:
		check(act.boss != null and act.main_biome() != null and act.monsters.size() >= 6, "%s has a boss, a look and monsters" % act.title)
		bosses.append(act.boss)
	check(config.boss_for_depth(1) == null and config.boss_for_depth(2) == null and config.boss_for_depth(4) == null, "normal floors have no boss")
	check(config.boss_for_depth(3) == bosses[0] and config.boss_for_depth(6) == bosses[1] and config.boss_for_depth(9) == bosses[2] and config.boss_for_depth(12) == bosses[3], "each act ends with its boss")
	check(config.act_for_depth(4) == config.acts[1] and config.floor_in_act(4) == 1, "floor 4 starts act 2")
	check(config.act_for_depth(10) == config.acts[3] and config.first_depth(3) == 10, "floor 10 starts act 4")
	check(config.is_final_floor(12) and not config.is_final_floor(9), "floor 12 ends the run")
	check(config.act_for_depth(13) == config.acts[0] and config.boss_for_depth(15) == bosses[0], "endless mode loops the acts")
	for boss in bosses:
		check(boss.frames != null and boss.frames.has_animation(&"idle"), "%s has animations" % boss.id)
		check(boss.portrait != null, "%s has a portrait" % boss.id)
		check(boss.weapon != null and boss.loot != null, "%s has a weapon and loot" % boss.id)
		check(boss.phases.size() == 2 and is_equal_approx(boss.phases[0].hp_ratio, 0.66) and is_equal_approx(boss.phases[1].hp_ratio, 0.33), "%s: three phases (full, two thirds, one third)" % boss.id)
		check(boss.shockwave_after_hits > 0, "%s answers a hail of hits" % boss.id)
		if boss.phases.size() == 2:
			var fierce := boss.phases[1].skills.filter(func(s: SkillDef) -> bool: return String(s.id).ends_with("_fierce"))
			check(not fierce.is_empty() and boss.phases[1].skills != boss.phases[0].skills, "%s: new patterns in its last phase" % boss.id)
			check(boss.phases[1].windup_multiplier < boss.phases[0].windup_multiplier and boss.phases[1].cooldown_multiplier < 1.0, "%s: each phase faster" % boss.id)
		var last := 1.0
		for phase in boss.phases:
			check(phase.hp_ratio < last, "%s phases go down in HP" % boss.id)
			last = phase.hp_ratio
		for skill in boss.skills:
			check(skill.cooldown > 0.0, "%s: %s has a cooldown" % [boss.id, skill.id])

	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 40:
		var map := DungeonGenerator.generate_arena(config, rng)
		check(map.boss_room.size == config.arena_size, "arena has the configured size")
		check(not map.boss_room.has_point(map.start_cell), "the player starts outside the arena")
		var reachable := _flood(map, map.start_cell)
		check(reachable.has(map.boss_room.get_center()), "arena reachable from the start")
		# Exits of the arena: floor cells right around it. They must all be closable spikes.
		var ring := map.boss_room.grow(1)
		var exits := 0
		for y in range(ring.position.y, ring.end.y):
			for x in range(ring.position.x, ring.end.x):
				if not map.boss_room.has_point(Vector2i(x, y)) and map.is_floor(Vector2i(x, y)):
					exits += 1
		check(exits >= 1 and exits <= ring.size.x + ring.size.y, "arena has a closable entrance (%d cells)" % exits)
		check(_bad_wall_cells(map).is_empty(), "arena floors have clean walls")


## Typical kills before each act's boss on Keeper (economy, 2026-10-21: 80/75/65/60% of the
## monsters of the act's floors, bosses included), for the soul checks below.
const KEEPER_KILLS_BEFORE_BOSS := [49, 145, 251, 365]


## The Tree of Souls is a campaign (docs/balance-log.md, 2026-10-21): a run's souls, the
## one-time pools (bestiary, achievements) and the first run, against the tree's cost.
func _test_soul_economy() -> void:
	var config := CONTENT.dungeon
	var tree := CONTENT.soul_tree
	var full_tree := BalanceSouls.full_tree_cost(tree)
	check(full_tree > 0 and full_tree <= BalanceSouls.all_nodes_cost(tree), "a full tree costs souls (%d)" % full_tree)
	# Kills pay a share of a soul that adds up over the run, rounded once.
	check(config.souls_for_run(20, 1, 0, false) == roundi(20 * config.souls_per_kill), "kills' shares of a soul add up (%d for 20)" % config.souls_for_run(20, 1, 0, false))
	# Going deeper pays, farming monsters doesn't: in a run dying at act III's boss, kills are
	# under half of the souls.
	var act3 := config.souls_for_run(KEEPER_KILLS_BEFORE_BOSS[2], BalanceContent.boss_depth(CONTENT, 3), 2, false)
	check(KEEPER_KILLS_BEFORE_BOSS[2] * config.souls_per_kill < act3 * 0.5, "kills are under half of a run's souls (%.0f of %d)" % [KEEPER_KILLS_BEFORE_BOSS[2] * config.souls_per_kill, act3])
	# A late-career Keeper run (half win, half die at act IV's boss) alone fills the tree in
	# 40-80 runs (with the bestiary, achievements and quests: 40-60, BalanceSouls).
	var acts := config.acts.size()
	var died := config.souls_for_run(KEEPER_KILLS_BEFORE_BOSS[acts - 1], BalanceContent.boss_depth(CONTENT, acts), acts - 1, false)
	var won := config.souls_for_run(KEEPER_KILLS_BEFORE_BOSS[acts - 1] + 1, config.total_floors(), acts, true)
	var late_runs := full_tree / ((died + won) * 0.5)
	check(late_runs >= 40.0 and late_runs <= 80.0, "late Keeper runs alone fill the tree in 40-80 runs (%.0f: %d souls a run, tree %d)" % [late_runs, int((died + won) / 2.0), full_tree])
	# The one-time pools (hunter ranks, challenges, achievements) are a bonus, not the tree.
	var pools := BalanceSouls.one_time_pools(CONTENT)
	var one_time: int = pools.ranks + pools.challenges + pools.achievements
	check(one_time <= full_tree * 0.6, "the bestiary and achievements pay at most 60%% of the tree (%d of %d)" % [one_time, full_tree])
	# A first run dying at act I's boss buys a node: its souls, the Known rank of two thirds of
	# the act's kinds and the first kill's feat.
	var first_run := config.souls_for_run(KEEPER_KILLS_BEFORE_BOSS[0], BalanceContent.boss_depth(CONTENT, 1), 0, false)
	first_run += roundi(config.acts[0].monsters.size() * 2.0 / 3.0) * CONTENT.bestiary.monster_souls[0]
	var first_blood: AchievementDef = load("res://data/achievements/first_blood.tres")
	first_run += first_blood.reward_souls
	check(first_run >= BalanceSouls.first_node_cost(tree), "a first run buys a node (%d souls, the cheapest costs %d)" % [first_run, BalanceSouls.first_node_cost(tree)])



## Slows from a boss must not chain into a lock (balance-log 2026-10-23, the Azure Wyrm: her fang,
## breath, dive and hail all slowed 40% for 2 s, so the hero was slowed nearly the whole last
## phase and could neither outrun her nor clear her short-warned dives).
## The Nameless Keeper's rules and data (KeeperTests).
func _test_nameless_keeper() -> void:
	var keeper := KeeperTests.new()
	add_child(keeper)
	keeper.run_unit()
	keeper.queue_free()


func _test_boss_slows() -> void:
	var bosses: Array[BossDef] = []
	for act in CONTENT.dungeon.acts:
		bosses.append_array(act.all_bosses())
	if CONTENT.dungeon.finale and CONTENT.dungeon.finale.boss:
		bosses.append_array(CONTENT.dungeon.finale.boss.forms())
	# The Nameless Keeper, built from the hero's every weapon and its skills (a tome's too).
	var keepers := KeeperTests.sample_keepers(CONTENT)
	check(keepers.size() >= 10, "the Nameless Keeper is checked with every weapon (%d)" % keepers.size())
	bosses.append_array(keepers)
	for boss in bosses:
		var phases: Array = [boss.skills]
		for phase in boss.phases:
			if not phase.skills.is_empty():
				phases.append(phase.skills)
		for i in phases.size():
			var sources := PackedStringArray()
			if boss.weapon and boss.weapon.on_hit and boss.weapon.on_hit.slow > 0.0:
				sources.append(String(boss.weapon.id))
				check(boss.weapon.on_hit.slow_duration <= 2.0, "%s: its weapon's slow lasts 2 s at most" % boss.id)
			for skill: SkillDef in phases[i]:
				for effect in skill.effects:
					var status := effect.get("status") as OnHitStatus
					if status and status.slow > 0.0:
						if not sources.has(String(skill.id)):
							sources.append(String(skill.id))
						check(status.slow_duration <= 2.0, "%s: %s slows 2 s at most" % [boss.id, skill.id])
			check(sources.size() <= 2, "%s, phase %d: two things at most slow the hero (%s)" % [boss.id, i + 1, ", ".join(sources)])
	_test_boss_warnings(bosses)


## Readable boss attacks (balance-log 2026-10-23, the Azure Wyrm, Gorr and the Jade Wyrm), on every
## boss, with the numbers of data/balance/targets.tres: a dive (a rush or leap along a line) warns
## long enough in the boss' last phase on Keeper, hits a band its body could cross and doesn't
## slow (a slowed hero could not clear its second leg); the later blows of a circle's warning (a
## fierce Quake's wider ring) land inside the circle it drew.
func _test_boss_warnings(bosses: Array[BossDef]) -> void:
	var targets: BalanceTargets = load("res://data/balance/targets.tres")
	var keeper := CONTENT.get_difficulty(&"normal").telegraph_time
	var dives := 0
	var ids := bosses.map(func(b: BossDef) -> StringName: return b.id)
	check(ids.has(&"azure_wyrm") and ids.has(&"jade_wyrm") and ids.has(&"demon_cyclops"), "the wyrms and Gorr are among the bosses checked")
	for boss in bosses:
		# Each phase: the skills it uses (a phase without its own keeps the last ones) and its
		# warnings' scale on Keeper (the phases' wind-up multipliers compound).
		var skills: Array[SkillDef] = boss.skills
		var scale := keeper
		for p in boss.phases.size() + 1:
			if p > 0:
				scale *= boss.phases[p - 1].windup_multiplier
				if not boss.phases[p - 1].skills.is_empty():
					skills = boss.phases[p - 1].skills
			for skill in skills:
				var first: Effect = skill.effects[0] if not skill.effects.is_empty() else null
				for effect in skill.effects:
					var dive := effect as DashStrikeEffect
					if dive:
						dives += 1
						check(skill.cast_time * scale >= targets.dive_warning_min - 0.005, "%s: %s warns %.2f s on Keeper in phase %d (%.2f s at least)" % [boss.id, skill.id, skill.cast_time * scale, p + 1, targets.dive_warning_min])
						check(dive.width <= boss.radius + targets.dive_band_margin, "%s: %s hits a band its body could cross (%.0f vs radius %.0f + %.0f)" % [boss.id, skill.id, dive.width, boss.radius, targets.dive_band_margin])
						check(dive.status == null or dive.status.slow <= 0.0, "%s: %s does not slow" % [boss.id, skill.id])
					var area := effect as DamageAreaEffect
					if area == null or effect == first:
						continue
					# The circle the warning draws (TelegraphView.show_skill): the skill's own
					# radius around the caster, else its first circle. A leap's landing slam
					# (after a dive's line) is where the line ends: not a circle's warning.
					if skill.telegraph_radius > 0.0:
						check(area.offset + area.radius <= skill.telegraph_radius + 0.5, "%s: %s's blow %.2f s in (reach %.0f) lands inside the circle its warning drew (%.0f)" % [boss.id, skill.id, area.delay, area.offset + area.radius, skill.telegraph_radius])
					elif first is DamageAreaEffect:
						var drawn := first as DamageAreaEffect
						check(absf(area.offset - drawn.offset) + area.radius <= drawn.radius + 0.5, "%s: %s's blow %.2f s in (radius %.0f) lands inside the circle its warning drew (%.0f)" % [boss.id, skill.id, area.delay, area.radius, drawn.radius])
	check(dives >= 8, "the dives of every boss are checked (%d)" % dives)

func _test_profile() -> void:
	check(CONTENT.upgrades.size() >= 8, "the shrine sells upgrades")
	var config := CONTENT.dungeon
	check(config.souls_for_run(10, 4, 1, false) == roundi(10 * config.souls_per_kill + 3 * config.souls_per_floor + config.souls_per_boss), "souls: kills + depth + bosses")
	check(config.souls_for_run(0, 9, 3, true) > config.souls_for_run(0, 9, 3, false), "winning gives a big bonus")
	var vitality := _upgrade("vitality")
	Profile.runs_since_reset = 2
	Profile.reset()
	check(Profile.runs_since_reset == 0, "a new profile counts its runs toward a reset from zero")
	check(not Profile.buy(vitality), "no souls, no upgrade")
	Profile.souls = 1000
	check(Profile.buy(vitality) and Profile.level_of(vitality) == 1, "buying an upgrade")
	check(Profile.souls == 1000 - vitality.cost_for_level(0), "it costs souls")
	check(vitality.cost_for_level(1) > vitality.cost_for_level(0), "each level costs more")
	for i in 10:
		Profile.buy(vitality)
	check(Profile.level_of(vitality) == vitality.max_level and not Profile.can_buy(vitality), "levels are capped")

	# Locked items only appear once unlocked.
	check(not CONTENT.locked_items.is_empty(), "some items must be unlocked first")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	CONTENT.unlocked_items.clear()
	var seen_locked := false
	for i in 400:
		seen_locked = seen_locked or CONTENT.locked_items.has(CONTENT.pick_item(9, rng))
	check(not seen_locked, "locked items never spawn")
	CONTENT.unlocked_items.append_array(CONTENT.locked_items)
	var seen_unlocked := false
	for i in 400:
		seen_unlocked = seen_unlocked or CONTENT.locked_items.has(CONTENT.pick_item(9, rng))
	check(seen_unlocked, "unlocked items do spawn")
	CONTENT.unlocked_items.clear()
	Profile.reset()

	# Difficulties
	check(CONTENT.difficulties.size() == 4 and CONTENT.default_difficulty.id == &"normal", "4 difficulties, Normal by default")
	var hard := CONTENT.get_difficulty(&"hard")
	var nightmare := CONTENT.get_difficulty(&"nightmare")
	check(Profile.is_unlocked(CONTENT.get_difficulty(&"easy")) and Profile.is_unlocked(hard), "Easy to Hard are open")
	check(not Profile.is_unlocked(nightmare), "Nightmare starts locked")
	Profile.record_run(0, 9, true, &"normal")
	check(not Profile.is_unlocked(nightmare), "a Normal win doesn't unlock Nightmare")
	Profile.record_run(0, 9, true, &"hard")
	check(Profile.is_unlocked(nightmare), "a Hard win unlocks Nightmare")
	check(config.souls_for_run(10, 5, 1, false, nightmare.souls) > config.souls_for_run(10, 5, 1, false), "harder difficulties give more souls")
	var previous := 0.0
	for difficulty in CONTENT.difficulties:
		check(difficulty.monster_hp >= previous, "difficulties get harder in order (%s)" % difficulty.id)
		previous = difficulty.monster_hp
	Profile.reset()

	# Ascension: Nightmare +1, +2... each level stacks its twist.
	check(CONTENT.ascensions.size() >= 10 and nightmare.has_ascensions, "Nightmare has ascension levels")
	var climbed := AscensionDef.apply_levels(nightmare, CONTENT.ascensions, 3)
	check(climbed.shown_name() == "Nightmare +3" and climbed.display_name == nightmare.display_name and climbed.id == nightmare.id and climbed.ascension == 3, "Nightmare +3 is still Nightmare")
	check(climbed.monster_hp > nightmare.monster_hp and climbed.elite_chance > nightmare.elite_chance and climbed.souls > nightmare.souls, "each level makes it harder (and pays more souls)")
	check(nightmare.ascension == 0 and nightmare.display_name == "Nightmare", "the Nightmare file is untouched")
	var top := AscensionDef.apply_levels(nightmare, CONTENT.ascensions, 99)
	check(top.ascension == CONTENT.ascensions.size() and top.hero_max_hp < 1.0 and top.shop_prices > 1.0 and top.extra_monsters > nightmare.extra_monsters, "the last level has every twist")
	Profile.select_ascension(4)
	check(Profile.ascension == 0, "no ascension before a Nightmare win")
	Profile.win_ascension(0, CONTENT.ascensions.size())
	check(Profile.ascension_unlocked == 1 and Profile.stat_value("ascension") == 0, "a Nightmare win opens +1")
	Profile.win_ascension(5, CONTENT.ascensions.size())
	Profile.select_ascension(99)
	check(Profile.ascension == 6 and Profile.stat_value("ascension") == 5, "winning +5 opens +6")
	Profile.reset()

	# Records: the bestiary, counters, achievements, the run history; all saved.
	Profile.record_kill(&"slime")
	Profile.record_kill(&"slime")
	Profile.add_stat("kills", 2)
	Profile.raise_stat("run_gold", 50)
	Profile.raise_stat("run_gold", 20)
	check(Profile.kill_count(&"slime") == 2 and Profile.stat_value("species") == 1, "the bestiary counts kills per monster")
	check(Profile.stat_value("kills") == 2 and Profile.stat_value("run_gold") == 50, "counters add up, bests stay the best")
	check(CONTENT.achievements.size() >= 15, "achievements listed")
	var ids := {}
	for achievement in CONTENT.achievements:
		check(achievement.icon != null and achievement.target > 0 and achievement.reward_souls > 0, "%s is set up" % achievement.id)
		check(not ids.has(achievement.id), "%s is unique" % achievement.id)
		ids[achievement.id] = true
	var first: AchievementDef = load("res://data/achievements/first_blood.tres")
	check(first.is_met() and not first.is_unlocked(), "an achievement knows when its goal is reached")
	var souls_before := Profile.souls
	check(Profile.unlock_achievement(first) and Profile.souls == souls_before + first.reward_souls, "unlocking pays souls")
	check(not Profile.unlock_achievement(first) and Profile.souls == souls_before + first.reward_souls, "only once")
	for i in Profile.HISTORY_SIZE + 5:
		Profile.add_history({ "depth": i })
	check(Profile.history.size() == Profile.HISTORY_SIZE and int(Profile.history[0].depth) == Profile.HISTORY_SIZE + 4, "the history keeps the last runs, newest first")
	Profile.save_path = "user://test_profile_%d.json" % OS.get_process_id()
	Profile.save_profile()
	Profile.kills_by_monster = {}
	Profile.achievements = {}
	Profile.load_profile()
	check(Profile.kill_count(&"slime") == 2 and Profile.is_achieved(&"first_blood") and Profile.history.size() == Profile.HISTORY_SIZE, "records survive a save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.save_path))
	Profile.save_path = ""
	Profile.reset()


## A profile file with a damaged field (a hand edit, a disk fault, a newer game's record) keeps
## everything else, and the file as it was is set aside before the next save replaces it.
func _test_profile_damaged() -> void:
	var path := "user://test_damaged_profile_%d.json" % OS.get_process_id()
	Profile.reset()
	Profile.save_path = path
	SafeFile.write_json(path, { "souls": 420, "runs": 12, "levels": { "vitality": 2 }, "history": [{ "depth": 3 }, 7], "village_quests": { "kagari": 99 } })
	Profile.load_profile()
	check(Profile.souls == 420 and Profile.runs == 12 and int(Profile.levels.get("vitality", 0)) == 2, "a damaged field never costs the rest of the profile")
	check(Profile.history.size() == 1 and Profile.village_quests.is_empty(), "only the damaged entries are dropped")
	var aside := _set_aside_profiles(path)
	var copy: Variant = SafeFile.read_json(path.get_base_dir().path_join(aside[0])) if aside.size() == 1 else null
	check(copy is Dictionary and (copy as Dictionary).history.size() == 2, "the damaged file is set aside whole before a save replaces it")
	# Not JSON at all: nothing can be read, the profile in memory stays, the file is kept aside.
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{\"souls\": 9")
	file.close()
	Profile.load_profile()
	check(Profile.souls == 420 and _set_aside_profiles(path).size() == 2, "an unreadable file is set aside too, never overwritten unseen")
	Profile.save_profile()
	Profile.load_profile()
	check(Profile.souls == 420 and _set_aside_profiles(path).size() == 2, "a sound file sets nothing aside")
	for file_name in _set_aside_profiles(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.get_base_dir().path_join(file_name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Profile.save_path = ""
	Profile.reset()


## The copies Profile set aside for the profile file at `path` (file names).
func _set_aside_profiles(path: String) -> Array[String]:
	var found: Array[String] = []
	for file_name in DirAccess.get_files_at(path.get_base_dir()):
		if file_name.begins_with(path.get_file() + ".damaged"):
			found.append(file_name)
	return found


## Bigger floors on harder difficulties: more rooms, the same clean walls, everything reachable.
func _test_floor_size() -> void:
	var rng := RandomNumberGenerator.new()
	var config := CONTENT.dungeon
	var last_area := 0
	var last_rooms := 0
	for id in [&"easy", &"normal", &"hard", &"nightmare"]:
		var difficulty := CONTENT.get_difficulty(id)
		check(difficulty.floor_size >= 1.0 and difficulty.rooms >= 1.0, "%s: floors at least the base size" % id)
		var area := 0
		var rooms := 0
		var bad := 0
		var cut_off := 0
		for i in 8:
			rng.seed = 4242 + i
			var map := DungeonGenerator.generate(config, rng, difficulty.floor_size, difficulty.rooms)
			check(map.width == roundi(config.width * difficulty.floor_size), "%s: the map's width follows the difficulty" % id)
			area += map.width * map.height
			rooms += map.rooms.size()
			bad += _bad_wall_cells(map).size()
			var reached := _flood(map, map.start_cell)
			for room in map.rooms:
				if not reached.has(room.get_center()):
					cut_off += 1
		check(bad == 0, "%s: no thin or pinched walls on big floors (%d)" % [id, bad])
		check(cut_off == 0, "%s: every room reachable" % id)
		check(area >= last_area and rooms >= last_rooms, "%s: as big as the easier one or bigger (%d rooms over 8 floors)" % [id, rooms])
		last_area = area
		last_rooms = rooms
	check(CONTENT.get_difficulty(&"nightmare").rooms > CONTENT.get_difficulty(&"easy").rooms, "Nightmare has more rooms than Easy")
	check(config.max_monsters_per_floor >= 60, "a floor may hold many monsters, with a cap for the phone")


## The plateau's mist: none on the floor and the cliff faces, thin at the rim, thick further in.
func _test_plateau_mist() -> void:
	var map := DungeonMap.new(12, 12, 32)
	for y in range(4, 8):
		for x in range(4, 8):
			map.set_floor(Vector2i(x, y))
	var margin := 3
	var image := PlateauMist.mask_image(map, margin)
	var at := func(x: int, y: int) -> float: return image.get_pixel(x + margin, y + margin).r
	check(image.get_size() == Vector2i(18, 18), "the mask covers the map and its margin")
	check(at.call(5, 5) < 0.01, "no mist on the floor")
	check(at.call(5, 3) < 0.01 and at.call(5, 2) < 0.01, "nor on a cliff face (both its cells: its foot over the floor, its top: DungeonView)")
	check(at.call(5, 1) > 0.1 and at.call(5, 1) < 0.5, "thin at the rim (%.2f)" % at.call(5, 1))
	check(at.call(0, 0) > 0.95 and image.get_pixel(0, 0).r > 0.95, "thick deep in the plateau and all around the map")
	# The walls' tiles (DungeonView): a wall three cells thick between two rooms is the plateau's
	# top edge (floor above), then the face's top, then its foot; one cell thick, the short edge.
	var between := DungeonMap.new(10, 12, 32)
	for x in range(2, 8):
		between.set_floor(Vector2i(x, 2))
		between.set_floor(Vector2i(x, 6))
		between.set_floor(Vector2i(x, 8))
	var cave: DungeonTheme = load("res://data/dungeon/themes/cave.tres")
	var view := DungeonView.new()
	view._map = between
	view._theme = cave
	check(view._wall_top_tile(Vector2i(4, 3)) == cave.wall_top, "floor above a face: the plateau's top edge, its rim on top (not a plain middle)")
	check(view._face_row(Vector2i(4, 4)) == DungeonView.FaceRow.TOP and view._face_row(Vector2i(4, 5)) == DungeonView.FaceRow.FOOT, "then the face's top over its foot")
	check(view._face_row(Vector2i(4, 7)) == DungeonView.FaceRow.SHORT, "a wall one cell thick between two floors: the short edge")
	view.free()
	for theme_path in DirAccess.get_files_at("res://data/dungeon/themes"):
		if not theme_path.ends_with(".tres"):
			continue
		var theme: DungeonTheme = load("res://data/dungeon/themes/" + theme_path)
		check(theme.mist_density > 0.3 and theme.mist_density <= 1.0 and theme.mist_wisp.get_luminance() > theme.mist_deep.get_luminance(), "%s has its mist (darker depths, lighter wisps)" % theme_path)



## The languages: the translations load, every text has its French, tr() follows the locale
## (code texts, data texts, the grammar of rolled names), the setting persists. Back to English.
func _test_languages() -> void:
	var file := FileAccess.open("res://locale/strings.csv", FileAccess.READ)
	check(file != null, "languages: locale/strings.csv is there")
	if file == null:
		return
	var header := file.get_csv_line()
	check(Array(header) == ["keys", "en", "fr"], "languages: the CSV's columns are keys, en, fr (%s)" % header)
	var rows := 0
	var missing := PackedStringArray()
	var broken := PackedStringArray()
	var codes := RegEx.create_from_string("%[-+0#]*\\d*(?:\\.\\d+)?[a-zA-Z%]|\\{\\w+\\}")
	var no_glyph := {}  # a character the pixel font lacks shows in a fallback font
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 3 or row[0].is_empty():
			continue
		rows += 1
		for text: String in [row[1], row[2]]:
			for i in text.length():
				var code := text.unicode_at(i)
				if code >= 32 and not Fonts.MAIN.has_char(code):
					no_glyph[text[i]] = row[0]
		if row[2].strip_edges().is_empty():
			missing.append(row[0])
		elif row[0].begins_with(" ") != row[2].begins_with(" ") or row[0].ends_with(" ") != row[2].ends_with(" "):
			broken.append(row[0])  # " and " joins words: its spaces matter
		elif not row[0].begins_with("grammar:") and _codes(codes, row[0]) != _codes(codes, row[2]) and not row[0].contains("{rarity}"):
			broken.append(row[0])
	check(rows > 1000, "languages: the CSV holds the game's texts (%d)" % rows)
	check(missing.is_empty(), "languages: every text has its French (missing: %s)" % ", ".join(missing.slice(0, 5)))
	check(broken.is_empty(), "languages: the French keeps the numbers' places (%s)" % ", ".join(broken.slice(0, 5)))
	check(no_glyph.is_empty(), "languages: the pixel font draws every character of the texts (missing: %s)" % ", ".join(no_glyph.keys().map(func(c: String) -> String: return "%s in \"%s\"" % [c, no_glyph[c]])))
	check(TranslationServer.get_loaded_locales().has("fr"), "languages: the French translation is loaded")

	TranslationServer.set_locale("fr")
	check(tr("Level up!") == "Niveau supérieur !", "languages: tr() in French (%s)" % tr("Level up!"))
	check(tr("Seal  %d / %d") % [3, 7] == "Sceau  3 / 7", "languages: a format, translated then filled")
	var skeleton: MonsterDef = load("res://data/monsters/skeleton.tres")
	check(tr(skeleton.display_name) == "Squelette", "languages: a monster's name (%s)" % tr(skeleton.display_name))
	var vampirism := _perk("vampirism")
	check(vampirism != null and vampirism.describe().begins_with("Abattre un ennemi rend 3 de Vie"), "languages: a perk's description (%s)" % (vampirism.describe() if vampirism else "?"))
	var hint := CONTENT.tutorial.hint(&"move")
	check(hint != null and tr(hint.text).begins_with("Fais glisser ton pouce"), "languages: a tutorial hint")
	check(LootRoller.rolled_name("Battle Axe", "Sharp", "of the Bear") == "Hache de Guerre Affûtée de l'Ours", "languages: a rolled name agrees in French (%s)" % LootRoller.rolled_name("Battle Axe", "Sharp", "of the Bear"))
	check(LootRoller.rolled_name("Katana", "Sharp", "") == "Katana Affûté", "languages: ...and with a masculine item")
	var stats := StatBlock.from_dict({ "attack": 3, "cooldown_reduction": 0.05 })
	check(stats.describe() == "+3 Dégâts, compétences rechargées 5 % plus vite", "languages: stats in plain French words (%s)" % stats.describe())
	TranslationServer.set_locale("en")
	check(tr("Level up!") == "Level up!", "languages: tr() back in English")
	check(LootRoller.rolled_name("Battle Axe", "Sharp", "of the Bear") == "Sharp Battle Axe of the Bear", "languages: a rolled name in English")

	# The setting: picked, applied, saved and read back.
	var path := "user://test_settings_%d.cfg" % OS.get_process_id()
	Settings.path = path
	Settings.set_option(&"language", "fr")
	check(TranslationServer.get_locale() == "fr", "languages: the setting changes the locale")
	Settings.language = "en"
	Settings.load_settings()
	check(Settings.language == "fr", "languages: the setting is saved")
	check(not FileAccess.file_exists(path + ".tmp"), "settings: written beside, then renamed over the file")
	DirAccess.rename_absolute(path, path + ".tmp")  # (the app killed between the write and its rename)
	Settings.language = "en"
	Settings.load_settings()
	check(Settings.language == "fr", "settings: a save cut short before its rename is read back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Settings.path = ""
	Settings.set_option(&"language", "en")
	check(TranslationServer.get_locale() == "en" and Settings.language == "en", "languages: back to English for the other tests")
	check(SettingsScript.device_language() in Settings.LANGUAGES, "languages: the first launch follows the phone's language")


func _codes(pattern: RegEx, text: String) -> Array:
	var found := pattern.search_all(text).map(func(m: RegExMatch) -> String: return m.get_string())
	found.sort()
	return found


## The trial of the Threshold's rules: harder in each act, stated on the relic and the Tree's node,
## a limbo the hero can stand in.
func _test_threshold() -> void:
	var feather := _perk("phoenix_feather")
	var passive := feather.passives[0] as CheatDeathPassive
	var trial := passive.trial
	check(trial != null, "the Phoenix Feather's second life is the trial of the Threshold")
	if trial == null:
		return
	var config := CONTENT.dungeon
	var first := trial.kills_for(1, config)
	check(first == trial.kills and is_equal_approx(trial.time_for(1, config), trial.time_limit), "act I: %d spectres in %d s" % [first, roundi(trial.time_limit)])
	var second_act := config.first_depth(1)
	check(trial.kills_for(second_act, config) == first + trial.kills_per_act and trial.time_for(second_act, config) > trial.time_for(1, config), "each act asks for more")
	check(trial.kills_for(config.total_floors(), config) == first + trial.kills_per_act * (config.acts.size() - 1), "the last act asks for %d" % trial.kills_for(config.total_floors(), config))
	var rule := "slay %d foes in %d s" % [first, roundi(trial.time_limit)]
	check(feather.description.contains(rule), "the relic states the act I rule (%s)" % rule)
	check(feather.description.contains("half Health") and feather.description.contains("quarter"), "and what it brings back")
	check(is_equal_approx(passive.heal_ratio, 0.5) and is_equal_approx(passive.boss_fight_heal_ratio, 0.25), "half Health, a quarter in a boss fight (as its text says)")
	check(_upgrade("second_chance").description.contains("Threshold"), "Death Denied says where the killing blow sends you")
	check(trial.hero_health > 0.0 and trial.time_limit > 0.0 and trial.alive_at_once >= 1, "the hero can fight in there")
	var map := ThresholdWorld.make_map(trial, config)
	var room := map.boss_room
	check(map.is_floor(map.start_cell) and room.has_point(map.start_cell), "the hero starts on the arena's floor")
	check(room.position.x >= trial.margin and map.width - room.end.x >= trial.margin, "mist all around the arena")
	var floor_cells := 0
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			if map.is_floor(Vector2i(x, y)):
				floor_cells += 1
	check(floor_cells > 120, "room to fight (%d cells)" % floor_cells)
	check(trial.theme != null and trial.ambience != null and trial.knell != null, "the limbo has its look and its bell")


## The Deeps (AbyssDef): their numbers grow by act, their demons are sound and live nowhere else,
## every maze leads to its door, and the first fall has its hint.
func _test_abyss() -> void:
	var def := CONTENT.dungeon.abyss
	check(def != null, "the floors have their Deeps (DungeonConfig > Abyss)")
	if def == null:
		return
	var config := CONTENT.dungeon
	var last := config.total_floors()
	check(def.fall_damage > 0.0 and def.fall_damage < 0.15, "the fall down there costs less than climbing out of a hole (%d%%)" % roundi(def.fall_damage * 100.0))
	check(def.quick_time_for(last, config) > def.quick_time_for(1, config) and def.gift_gold_for(last, config) > def.gift_gold_for(1, config), "the dawn's gift: more time and more gold deeper")
	check(def.wave_size_for(3, 1, config) > def.wave_size_for(0, 1, config), "each wave brings more demons")
	check(def.wave_size_for(0, last, config) > def.wave_size_for(0, 1, config) and def.wave_every_for(last, config) < def.wave_every_for(1, config) and def.max_alive_for(last, config) > def.max_alive_for(1, config), "deeper acts: bigger, quicker waves")
	check(not def.has_warden(1, config) and def.has_warden(last, config), "the warden stands at the door of the deep acts only")
	check(def.theme != null and def.lighting != null and def.ambience != null and def.lighting.ambient_level < 5 and def.torch_level < 12, "the Deeps are dark (light %d, torch %d)" % [def.lighting.ambient_level, def.torch_level])
	check(def.hazards.any(func(h: HazardDef) -> bool: return h is PitDef and not (h as PitDef).is_crumbling()), "holes down there too (the hole challenge can be met on their walkers)")
	# The demons: sound, in no act, unique.
	var in_acts := CONTENT.all_monsters()
	for act in config.acts:
		in_acts.append_array(act.all_bosses())
	var ids := {}
	for monster in CONTENT.all_monsters():
		ids[monster.id] = true
	for item in CONTENT.items:
		ids[item.id] = true
	var demons := CONTENT.abyss_monsters()
	check(demons.size() >= 6 and demons.has(def.warden), "%d demons and the warden" % demons.size())
	for monster in demons:
		check(monster.weapon != null and monster.stats != null and monster.stats.max_hp > 0 and monster.xp_reward > 0, "%s has a weapon, Health and XP" % monster.id)
		check(monster.frames != null and (monster.frames.has_animation(&"walk_down") or monster.frames.has_animation(&"walk")) and monster.icon != null, "%s is animated" % monster.id)
		check(not ids.has(monster.id), "%s: a new id" % monster.id)
		ids[monster.id] = true
		check(not in_acts.has(monster), "%s lives in the Deeps only, in no act" % monster.id)
		check(not monster.display_name.is_empty() and not monster.description.is_empty(), "%s is named and described" % monster.id)
		check(monster.resource_path.begins_with("res://data/monsters/abyss/"), "%s is its own file" % monster.id)
	for monster in def.monsters:
		check(monster.spawn_weight > 0, "%s comes in the waves" % monster.id)
	check(def.warden.spawn_weight == 0 and not def.monsters.has(def.warden), "the warden only stands at the door")
	check(def.monsters.any(func(m: MonsterDef) -> bool: return m.flies) and def.monsters.any(func(m: MonsterDef) -> bool: return m.keep_distance > 0.0) and def.monsters.any(func(m: MonsterDef) -> bool: return m.keep_distance <= 0.0), "brutes, shooters and flyers")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var early := {}
	for i in 300:
		early[def.pick_monster(1, rng)] = true
	check(early.keys().all(func(m: MonsterDef) -> bool: return m.min_depth <= 1 and def.monsters.has(m)), "Act I's waves: no demon before its depth")
	var drinker: MonsterDef = load("res://data/monsters/abyss/blood_drinker.tres")
	var drinks := false
	for monster_trait in drinker.traits:
		if monster_trait is PerkTrait:
			for perk in (monster_trait as PerkTrait).perks:
				drinks = drinks or perk.passives.any(func(x: Passive) -> bool: return x is LifestealPassive)
	check(drinks, "the Blood Drinker drinks from its blows")
	# Every maze: rooms, a start and a door apart, a way between them (no holes yet: AbyssWorld
	# adds them without cutting the way, see FloorTests).
	var cut := []
	for seed_value in 200:
		rng.seed = seed_value
		var map := AbyssWorld.make_map(def, config, rng)
		if map.rooms.size() < 3 or map.start_cell == map.stairs_cell or not _reachable(map, map.start_cell, map.stairs_cell):
			cut.append(seed_value)
	check(cut.is_empty(), "every maze leads from where the hero lands to the door (200 seeds; failed: %s)" % str(cut))
	# Its hint, the first time.
	var hint: HintDef = null
	for h in CONTENT.tutorial.hints:
		if h.cue == &"abyss":
			hint = h
	check(hint != null and Tutorial.CUES.has(&"abyss"), "the first fall has its hint")
	if hint:
		check(hint.text.length() <= 120 and hint.duration > 0.0, "a short hint (%d characters), on screen a while" % hint.text.length())


## Whether `to` can be walked to from `from` on `map`'s floor (4 ways).
static func _reachable(map: DungeonMap, from: Vector2i, to: Vector2i) -> bool:
	var seen := {from: true}
	var open: Array[Vector2i] = [from]
	while not open.is_empty():
		var cell: Vector2i = open.pop_back()
		if cell == to:
			return true
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + step
			if not seen.has(next) and map.is_floor(next):
				seen[next] = true
				open.append(next)
	return false


## Every big character frame holds a whole figure: a frame cut through the middle of the drawing
## (the Ember Ronin's 96-wide frames once sliced at 48 showed a half samurai) shows as a long run
## of drawn pixels on both sides of a frame's edge. (16x16 packs fill their cells edge to edge
## by design, so only frames of 32 pixels and more are looked at.)
## The codex's attack preview draws a weapon's swing as a fan: every weapon's swing must be a
## polygon the engine can triangulate, or a full circle for spins (360 or 450 degrees used to
## log "Invalid polygon data, triangulation failed").
func _test_attack_preview_fans() -> void:
	var checked := 0
	for path in _files_under("res://data/items/weapons", ".tres"):
		var weapon := load(path)
		if weapon == null or not "arc_degrees" in weapon:
			continue
		checked += 1
		var half := deg_to_rad(float(weapon.arc_degrees)) * 0.5
		if AttackPreview.is_full_turn(half):
			continue
		var points := AttackPreview.fan_points(Vector2.ZERO, half, 40.0)
		check(points.is_empty() or not Geometry2D.triangulate_polygon(points).is_empty(), "%s: its swing's fan in the codex triangulates (%s degrees)" % [path.get_file(), weapon.arc_degrees])
	check(checked >= 20, "weapons' swing fans checked (%d)" % checked)
	check(AttackPreview.is_full_turn(deg_to_rad(450.0) * 0.5) and AttackPreview.fan_points(Vector2.ZERO, deg_to_rad(360.0) * 0.5, 40.0).is_empty(), "a spin is drawn as a circle, never as a fan")


func _test_sprite_frames_whole() -> void:
	var checked := 0
	for folder: String in ["res://data/visuals/bosses/", "res://data/visuals/monsters/", "res://data/visuals/"]:
		for file in DirAccess.get_files_at(folder):
			if not file.ends_with(".tres"):
				continue
			var frames := load(folder + file) as SpriteFrames
			if frames == null:
				continue
			for anim in frames.get_animation_names():
				for i in frames.get_frame_count(anim):
					var atlas := frames.get_frame_texture(anim, i) as AtlasTexture
					if atlas == null or atlas.atlas == null or atlas.region.size.x < 32.0:
						continue
					checked += 1
					var image := atlas.atlas.get_image()
					if image.is_compressed():
						image.decompress()
					var region := Rect2i(atlas.region)
					var cut_rows := 0
					for edge_x: int in [region.position.x, region.end.x]:
						if edge_x <= 0 or edge_x >= image.get_width():
							continue
						var streak := 0
						for y in range(region.position.y, region.end.y):
							var both := image.get_pixel(edge_x - 1, y).a > 0.0 and image.get_pixel(edge_x, y).a > 0.0
							streak = streak + 1 if both else 0
							cut_rows = maxi(cut_rows, streak)
					check(cut_rows < 10, "%s %s frame %d: not cut through the drawing (%d rows drawn across its edge)" % [file, anim, i, cut_rows])
	check(checked >= 20, "big character frames checked (%d)" % checked)


## The run's save (RunSave): older versions migrated, a newer one refused, damaged fields dropped
## (never a script error), the floor's stamp. The floor's ledger (FloorLedger); the stairs' seal
## restored quietly; NavGrid's nearest open cell; the flat heal boons; place_name_key() stays a
## key; the last boss saved.
func _test_save_rules() -> void:
	check(RunSave.parse({ "version": RunSave.VERSION + 1, "depth": 3 }).is_empty(), "a save from a newer game is not read")
	check(RunSave.parse({ "version": RunSave.OLDEST_VERSION - 1, "depth": 3 }).is_empty() and RunSave.parse({ "version": "2" }).is_empty(), "nor one older than every migration, nor one without a version")
	check(RunSave.parse("x").is_empty() and RunSave.parse([1]).is_empty() and RunSave.parse(null).is_empty(), "nor something that isn't a run")
	var old := RunSave.parse(JSON.parse_string(JSON.stringify({ "version": 1, "depth": 4, "kills": 9, "player": { "level": 3 }, "floor": { "chests": [[3, 4]] } })))
	check(int(old.get("version", 0)) == RunSave.VERSION and int(old.get("depth", 0)) == 4 and int(old.get("kills", 0)) == 9 and int((old.get("player", {}) as Dictionary).get("level", 0)) == 3, "a version 1 save is migrated: the run and the hero kept (%s)" % [old])
	check(RunSave.floor_outdated(old) and RunSave.floor_of(old).is_empty(), "...and its floor, saved without a stamp, is laid fresh")
	var current := { "floor": { "stamp": RunSave.floor_stamp(), "chests": [[3, 4]] } }
	check(not RunSave.floor_outdated(current) and RunSave.floor_of(current).has("chests"), "a floor this build saved is restored")
	var other_build := { "floor": { "stamp": RunSave.floor_stamp() + "-older", "chests": [[3, 4]] } }
	check(RunSave.floor_outdated(other_build) and RunSave.floor_of(other_build).is_empty(), "one another build saved is laid fresh")
	check(not RunSave.floor_outdated({}) and not RunSave.floor_outdated({ "floor": {} }), "nothing saved on the floor: nothing to say")
	check(RunSave.floor_stamp().begins_with(str(ProjectSettings.get_setting("application/config/version"))), "the stamp names the game's version (%s)" % RunSave.floor_stamp())
	# A damaged file: what doesn't fit is dropped, the rest kept; making the run raises no error.
	var damaged := RunSave.parse(JSON.parse_string(JSON.stringify({
		"version": RunSave.VERSION, "depth": [1], "kills": 7, "routes": { "2": "x", "3": 1 }, "splits": [1.5, "a", [2]],
		"difficulty": 5, "has_won": "yes", "kept_stock": [3, { "price": "a" }, { "price": 4 }], "offers": [2, { "rarity": "a" }],
		"player": { "level": "high", "xp": 4, "perks": [7, { "stacks": [1] }, { "stacks": 2 }], "base_stats": { "max_hp": "a", "damage": 3 } },
		"floor": { "chests": 4, "seal_kills": "x", "slain": [[1, "rat"]] }, "last_boss": [1], "seed": { "a": 1 },
	})))
	check(not damaged.has("depth") and not damaged.has("difficulty") and not damaged.has("has_won") and not damaged.has("last_boss") and not damaged.has("seed") and int(damaged.get("kills", 0)) == 7, "damaged fields are dropped, the others kept")
	check(damaged.get("routes") == { "3": 1.0 } and damaged.get("splits") == [1.5] and damaged.get("kept_stock") == [{}, { "price": 4.0 }] and damaged.get("offers") == [{}], "damaged entries of a list or a table too, and damaged fields of an entry (%s)" % [damaged])
	var hero: Dictionary = damaged.get("player", {})
	check(not hero.has("level") and int(hero.get("xp", 0)) == 4 and hero.get("perks") == [{}, { "stacks": 2.0 }] and hero.get("base_stats") == { "damage": 3.0 }, "and inside the hero's (%s)" % [hero])
	var floor_data: Dictionary = damaged.get("floor", {})
	check(not floor_data.has("chests") and not floor_data.has("seal_kills") and floor_data.has("slain"), "and the floor's")
	var from_damaged := RunState.create(CONTENT, damaged, RandomNumberGenerator.new())
	check(from_damaged.depth == 1 and from_damaged.kills == 7 and from_damaged.routes == { 3: 1 } and from_damaged.splits.size() == 1 and from_damaged.splits[0] == 1.5, "a damaged save still makes a run, with what it kept")
	check(RunSave.parse({ "version": RunSave.VERSION, "player": [1] }).is_empty(), "a damaged hero: the run can't come back")

	# The last boss comes back with the run (Continue in endless mode after a resumed win); the
	# Nameless Keeper is saved by a mark (made again from the run's snapshot).
	var state := RunState.create(CONTENT, {}, RandomNumberGenerator.new())
	var boss := CONTENT.dungeon.acts[0].boss
	state.last_boss = boss
	check(RunState.create(CONTENT, JSON.parse_string(JSON.stringify(state.to_data())), RandomNumberGenerator.new()).last_boss == boss, "the last boss slain is saved with the run")
	state.keeper_boss = NamelessKeeperDef.new()
	state.last_boss = state.keeper_boss
	check(state.to_data().get("last_boss") == RunState.KEEPER_BOSS, "the Nameless Keeper is saved as himself, not as a file")
	# place_name_key() is an English key, translated where it is shown.
	var bare := ContentDB.new()
	bare.dungeon = DungeonConfig.new()
	TranslationServer.set_locale("fr")
	check(state.place_name_key(bare) == "Dungeon" and state.place_name(bare) == tr("Dungeon"), "with no act, the place's key is \"Dungeon\" whatever the language (%s)" % state.place_name_key(bare))
	TranslationServer.set_locale(Settings.language)

	# The floor's ledger: numbers in the seed's order per kind, spent once, an id as a guard.
	var ledger := FloorLedger.new()
	var nodes: Array[Node] = [Node.new(), Node.new(), Node.new(), Node.new()]
	check(ledger.lay(FloorLedger.ITEM, nodes[0], "potion") == -1, "nothing is numbered outside the floor's laying")
	ledger.numbering = true
	check(ledger.lay(FloorLedger.ITEM, nodes[0], "potion") == 0 and ledger.lay(FloorLedger.ITEM, nodes[1], "katana") == 1 and ledger.lay(FloorLedger.PROP, nodes[2], "crate") == 0, "numbered in order, each kind on its own")
	ledger.spend(FloorLedger.ITEM, nodes[1])
	ledger.spend(FloorLedger.ITEM, nodes[1])
	ledger.spend(FloorLedger.ITEM, nodes[3])  # never laid
	check(ledger.to_data() == { "items": [[1, "katana"]] }, "spent once, with its id (%s)" % [ledger.to_data()])
	var saved: Variant = JSON.parse_string(JSON.stringify({ "items": [[1, "katana"], [0, "sword"], "x", [9, "potion"], [1.5]], "props": [[0, "crate"]], "gold": 3 }))
	var rebuilt := FloorLedger.new()
	rebuilt.numbering = true
	rebuilt.lay(FloorLedger.ITEM, nodes[0], "potion")
	rebuilt.lay(FloorLedger.ITEM, nodes[1], "katana")
	rebuilt.lay(FloorLedger.PROP, nodes[2], "crate")
	rebuilt.numbering = false
	var taken_back: Array[Node] = []
	rebuilt.restore(saved, func(_kind: String, node: Object) -> void: taken_back.append(node as Node))
	check(taken_back.size() == 2 and taken_back[0] == nodes[1] and taken_back[1] == nodes[2],"resumed, the things spent go again; another kind under a number, or a damaged entry, takes nothing (%d taken)" % taken_back.size())
	check(rebuilt.spent_count(FloorLedger.ITEM) == 1 and rebuilt.spent_count(FloorLedger.PROP) == 1, "and they are spent again for the next save")
	for node in nodes:
		node.free()

	# The stairs' seal restored from a save: open again, without its fanfare (no `broken`).
	var seal := StairsSeal.new()
	var broken := [0]
	var changed := [0]
	seal.broken.connect(func() -> void: broken[0] += 1)
	seal.reset(10, 0.7, 4)
	seal.changed.connect(func() -> void: changed[0] += 1)
	seal.restore(9)
	check(not seal.is_sealed() and broken[0] == 0 and changed[0] == 1, "a seal broken before quitting comes back open, quietly")

	# NavGrid: a blocked end of a path goes to the nearest open cell, not the first in reading order.
	var map := DungeonMap.new(9, 9, 32)
	for y in range(1, 8):
		for x in range(1, 8):
			map.set_floor(Vector2i(x, y))
	var nav := NavGrid.new()
	nav.build(map)
	for cell: Vector2i in [Vector2i(4, 4), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 5)]:
		nav.set_blocked(cell, true)
	check(nav.nearest_open(Vector2i(4, 4)) == Vector2i(5, 4), "the nearest open cell: the one beside, not a corner (%s)" % nav.nearest_open(Vector2i(4, 4)))
	check(nav.nearest_open(Vector2i(2, 2)) == Vector2i(2, 2), "an open cell is its own")

	# The tree's heal and max Health scales are flat: an upgrade that sets one has one level.
	for upgrade in CONTENT.upgrades:
		if upgrade.kind == UpgradeDef.Kind.RULES and (upgrade.healing_scale != 1.0 or upgrade.max_hp_scale != 1.0):
			check(upgrade.max_level == 1, "%s scales heals or max Health once: one level (%d)" % [upgrade.id, upgrade.max_level])
