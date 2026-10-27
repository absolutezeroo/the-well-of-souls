class_name KeeperTests
extends TestSuite
## The Nameless Keeper (task "Prendre sa place", docs/design/monsters.md "The Nameless Keeper").
## Rules and data (run_unit(), from the unit suite): the snapshot taken of a hero (KeeperSnapshot)
## and read back after JSON, skipping what the game no longer has; the profile keeping it through
## a save; a run picking it up when it begins (never a daily one) and keeping it in its save; the
## boss built from it (his weapon, armor, skills made a boss', kept relics, phases, health) and the
## numbers that keep him beatable but not a pushover. The game (run_game(), from the game suite):
## the bottom of the Well with him waiting instead of Tôma, his look, his fall the last one (no
## Maw), the ending choice again (taking his place replaces him), the codex's record, the debug
## panel's way down to him.

const PLAYER: PackedScene = preload("res://src/entities/player/player.tscn")


# --- Fixtures --------------------------------------------------------------------------------

## A hero out of the world (nothing processes), dressed as a late run's: `weapon_path`'s weapon
## (Rare, an affix, a rune, item level 12), a helm and a mail, `tome`'s skill learned, perks,
## level 18.
func hero(weapon_path: String = "res://data/items/weapons/katana.tres", tome: String = "res://data/items/tomes/tome_fire.tres") -> Player:
	var player := PLAYER.instantiate() as Player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(player)
	player.setup(CONTENT.player)
	var affixes: Array[ItemAffixDef] = []
	for affix in CONTENT.item_affixes:
		if affix and affix.bonuses and affix.bonuses.attack > 0:
			affixes.append(affix)
			break
	var runes: Array[RuneDef] = [CONTENT.runes[1]] as Array[RuneDef]
	player.equipment.equip(LootRoller.make(load(weapon_path) as EquipmentDef, ItemRarity.RARE, affixes, runes, 12))
	player.equipment.equip(LootRoller.make(load("res://data/items/armors/iron_helm.tres") as EquipmentDef, ItemRarity.MAGIC, [] as Array[ItemAffixDef], [] as Array[RuneDef], 10))
	player.equipment.equip(load("res://data/items/armors/chain_mail.tres") as EquipmentDef)
	if not tome.is_empty():
		player.learned_skill = (load(tome) as SkillTomeDef).skill
		player.rebuild_skills(0.0)  # (learn_skill() shows it in a world this hero isn't in)
	for id: String in ["ignite", "ignite", "ignite", "strength", "vitality", "multishot"]:
		player.perks.add(_perk(id))
	player.level = 18
	player.base_stats = CONTENT.player.base_stats.plus(CONTENT.player.level_bonus.times(17))  # (as his levels gave him)
	player.invalidate_stats()
	return player


func _run() -> RunState:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return RunState.create(CONTENT, {}, rng)


## A snapshot of `player` as read back from the profile's file (JSON: numbers come back floats).
func _through_json(snapshot: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(snapshot))


## Built Keepers of every weapon the hero can carry (Common, its skills, a tome's), for the
## readability checks every boss passes (UnitTests._test_boss_warnings, _test_boss_slows).
static func sample_keepers(content: ContentDB) -> Array[BossDef]:
	var result: Array[BossDef] = []
	var finale := content.dungeon.finale
	if finale == null or finale.keeper == null:
		return result
	var tomes: Array[String] = []
	for item in content.items:
		if item is SkillTomeDef and (item as SkillTomeDef).skill:
			tomes.append(String((item as SkillTomeDef).skill.id))
	var t := 0
	var carried: Array = []
	carried.append_array(content.player.starting_equipment)
	carried.append_array(content.items)
	for item: ItemDef in carried:
		var weapon := item as WeaponDef
		if weapon == null:
			continue
		var skills: Array = weapon.skills.filter(func(s: SkillDef) -> bool: return s != null).map(func(s: SkillDef) -> String: return String(s.id))
		if not tomes.is_empty():
			skills.append(tomes[t % tomes.size()])
			t += 1
		var snapshot := { "version": 1, "level": 20, "gear": [{ "id": String(weapon.id), "rarity": ItemRarity.EPIC, "affixes": [], "runes": [], "level": 12 }], "skills": skills, "perks": [] }
		result.append(finale.keeper.build(KeeperSnapshot.new(snapshot), content))
	return result


# --- Rules and data --------------------------------------------------------------------------

func run_unit() -> void:
	var saved_profile := Profile.keeper.duplicate(true)
	Profile.reset()
	_test_snapshot()
	_test_unknown_ids()
	_test_profile_keeps_him()
	_test_run_keeps_him()
	_test_built_boss()
	_test_skill_ranges()
	_test_balance_numbers()
	_test_chronicle()
	_test_codex_page()
	Profile.reset()
	Profile.keeper = saved_profile


func _test_snapshot() -> void:
	var player := hero()
	var run := _run()
	var snapshot := KeeperSnapshot.take(player, run, "Ash")
	var weapon := player.get_weapon()
	check(int(snapshot.version) == KeeperSnapshot.VERSION and int(snapshot.date) > 0 and str(snapshot.pseudonym) == "Ash", "the snapshot is versioned, dated, with the pseudonym")
	check(int(snapshot.level) == 18 and int(snapshot.max_health) == player.get_max_hp() and int(snapshot.power) == player.get_power() and str(snapshot.difficulty) == String(run.difficulty.id), "it keeps his level, his numbers and the run's difficulty")
	var gear: Array = snapshot.gear
	check(gear.size() == 3 and str(gear[0].id) == "katana" and int(gear[0].rarity) == ItemRarity.RARE and (gear[0].runes as Array).size() == 1 and int(gear[0].level) == 12, "his weapon first, by its id, with its rarity, runes and item level")
	var wanted: Array = (weapon as WeaponDef).skills.map(func(s: SkillDef) -> String: return String(s.id))
	wanted.append(String((load("res://data/items/tomes/tome_fire.tres") as SkillTomeDef).skill.id))
	check(snapshot.skills == wanted, "his weapon's skills and the tome's (%s)" % str(snapshot.skills))
	check(not (snapshot.skills as Array).has(String(CONTENT.player.innate_skills[0].id)), "not the roll (every hero has it)")
	var ignite := (snapshot.perks as Array).filter(func(p: Dictionary) -> bool: return p.id == "ignite")
	check(ignite.size() == 1 and int(ignite[0].stacks) == 3, "his perks with their levels")
	# Read back after the profile's JSON: the same hero.
	var back := KeeperSnapshot.new(_through_json(snapshot))
	var made := back.weapon(CONTENT)
	check(made != null and made.base_item == (weapon as EquipmentDef).base_item and made.rarity == ItemRarity.RARE and made.runes == (weapon as EquipmentDef).runes and made.affixes == (weapon as EquipmentDef).affixes and made.item_level == 12, "read back: the same weapon, rarity, affixes, runes, item level")
	check(made.damage == (weapon as WeaponDef).damage and made.display_name == weapon.display_name, "the same damage and name (%s)" % made.display_name)
	var armor := back.armor(CONTENT)
	check(armor.size() == 2 and armor.any(func(a: EquipmentDef) -> bool: return a.slot == EquipmentDef.Slot.HEAD and a.rarity == ItemRarity.MAGIC) and armor.any(func(a: EquipmentDef) -> bool: return a.id == &"chain_mail"), "the same armor")
	var skills := back.skills(CONTENT)
	check(skills.size() == (snapshot.skills as Array).size() and skills.all(func(s: SkillDef) -> bool: return player.skills.skills.has(s)), "the same skills")
	check(back.perks(CONTENT).size() == 4 and back.level() == 18 and back.pseudonym() == "Ash" and back.difficulty_id() == run.difficulty.id, "the same perks, level and name")
	player.queue_free()


func _test_unknown_ids() -> void:
	var player := hero()
	var snapshot := _through_json(KeeperSnapshot.take(player, _run()))
	player.queue_free()
	(snapshot.gear[0].affixes as Array).append("no_such_affix")
	(snapshot.gear[0].runes as Array).append("no_such_rune")
	(snapshot.gear as Array).append({ "id": "no_such_helm", "rarity": 2 })
	(snapshot.gear as Array).append("not even a dictionary")
	(snapshot.skills as Array).append("no_such_skill")
	(snapshot.perks as Array).append({ "id": "no_such_perk", "stacks": 2 })
	(snapshot.perks as Array).append(42)
	var back := KeeperSnapshot.new(snapshot)
	check(back.weapon(CONTENT) != null and back.weapon(CONTENT).runes.size() == 1, "an affix or a rune the game no longer has is left out of his weapon")
	check(back.armor(CONTENT).size() == 2 and back.skills(CONTENT).size() == 3 and back.perks(CONTENT).size() == 4, "pieces, skills and perks it no longer has are skipped")
	var lost := { "version": 1, "level": 9, "gear": [{ "id": "a_weapon_since_removed" }], "skills": ["gone"], "perks": [] }
	var keeper := CONTENT.dungeon.finale.keeper.build(KeeperSnapshot.new(lost), CONTENT)
	check(keeper != null and keeper.weapon == CONTENT.dungeon.finale.keeper.weapon and not keeper.phases.is_empty(), "with nothing left of his gear he still waits, with the keeper's blade")
	check(not KeeperSnapshot.is_valid({ "version": KeeperSnapshot.VERSION + 1, "gear": [] }) and not KeeperSnapshot.is_valid({}) and not KeeperSnapshot.is_valid("x"), "a snapshot of a later version (or none) is not read")


func _test_profile_keeps_him() -> void:
	var player := hero("res://data/items/weapons/bow.tres")
	var snapshot := KeeperSnapshot.take(player, _run(), "Ash")
	player.queue_free()
	var path := "user://test_keeper_%d.json" % OS.get_process_id()
	Profile.reset()
	Profile.save_path = path
	Profile.take_keeper(snapshot)
	Profile.record_keeper_freed(snapshot)
	Profile.keeper = {}
	Profile.keepers_freed = []
	Profile.load_profile()
	check(KeeperSnapshot.is_valid(Profile.keeper) and str(Profile.keeper.gear[0].id) == "bow" and int(Profile.keeper.level) == 18, "the Nameless Keeper waiting survives a restart (the profile's file)")
	check(Profile.keepers_freed.size() == 1 and str(Profile.keepers_freed[0].gear[0].id) == "bow" and int(Profile.keepers_freed[0].date) > 0, "and the list of the Keepers freed")
	var other := snapshot.duplicate(true)
	other.level = 30
	Profile.take_keeper(other)
	check(int(Profile.keeper.level) == 30, "one at a time: a new one replaces him")
	Profile.free_keeper()
	Profile.keeper = { "x": 1 }
	Profile.load_profile()
	check(Profile.keeper.is_empty(), "the bell frees him, for good")
	# A file from a later version of the game: no Keeper rather than a broken one.
	SafeFile.write_json(path, { "keeper": { "version": KeeperSnapshot.VERSION + 1, "gear": [] }, "keepers_freed": [1, { "level": 3 }] })
	Profile.load_profile()
	check(Profile.keeper.is_empty() and Profile.keepers_freed.size() == 1, "a snapshot it can't read waits no more; damaged records are dropped")
	for i in Profile.KEEPERS_KEPT + 3:
		Profile.record_keeper_freed(snapshot)
	check(Profile.keepers_freed.size() == Profile.KEEPERS_KEPT, "the codex keeps the last %d Keepers freed" % Profile.KEEPERS_KEPT)
	Profile.save_path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for file_name in DirAccess.get_files_at(path.get_base_dir()):
		if file_name.begins_with(path.get_file() + ".damaged"):  # (the damaged file above, set aside by Profile)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path.get_base_dir().path_join(file_name)))
	Profile.reset()


func _test_run_keeps_him() -> void:
	var player := hero()
	var snapshot := KeeperSnapshot.take(player, _run())
	player.queue_free()
	var finale := CONTENT.dungeon.finale
	Profile.reset()
	Profile.keeper = snapshot
	var closed := _run()
	check(closed.keeper.is_empty() and closed.keeper_boss == null and closed.bottom_boss() == finale.boss, "the bottom closed (no win): no Keeper for this run")
	Profile.wins = { "normal": 1 }
	var run := _run()
	check(run.keeper == snapshot and run.keeper_boss is NamelessKeeperDef and run.bottom_boss() == run.keeper_boss and run.meets_keeper(), "a won profile with a Keeper waiting: this run's bottom is his")
	var rng := RandomNumberGenerator.new()
	var daily := RunState.create(CONTENT, {}, rng, 20000)
	check(daily.keeper.is_empty() and not daily.meets_keeper(), "never in a Dawn Knell (the same race for everyone)")
	Profile.keeper = {}
	var data: Dictionary = _through_json(run.to_data())
	var resumed := RunState.create(CONTENT, data, rng)
	check(resumed.meets_keeper() and resumed.keeper_boss.weapon.id == run.keeper_boss.weapon.id, "a run saved with him picks him up again, even if the profile let him go meanwhile")
	resumed.depth = CONTENT.dungeon.total_floors()
	resumed.finale = true
	check(resumed.wins_with(resumed.keeper_boss) and not resumed.wins_with(finale.boss) and not resumed.wins_with(finale.final_boss()), "his fall wins the run (the last fight), not Tôma's nor the Maw's")
	check(resumed.keeper_boss.next_boss == null and resumed.keeper_boss.last_form() == resumed.keeper_boss, "no form rises after him")
	data.erase("keeper")
	Profile.keeper = snapshot
	check(not RunState.create(CONTENT, data, rng).meets_keeper(), "a run saved before he waited keeps its course (Tôma and the Maw)")
	Profile.reset()


func _test_built_boss() -> void:
	var template := CONTENT.dungeon.finale.keeper
	check(template != null and template.id == &"nameless_keeper" and template.chronicle != null and template.frames == CONTENT.player.frames and template.shows_gear, "the Nameless Keeper is data: the hero's frames, his gear shown, a chronicle")
	check(template.phases.size() == 2 and template.next_boss == null and template.relic_choices > 0, "three phases, no next form")
	var player := hero("res://data/items/weapons/bow.tres")
	var snapshot := KeeperSnapshot.new(_through_json(KeeperSnapshot.take(player, _run(), "Ash")))
	var keeper := template.build(snapshot, CONTENT)
	check(keeper != template and keeper.weapon.id == &"bow" and keeper.weapon.kind == WeaponDef.Kind.RANGED and (keeper.weapon as EquipmentDef).rarity == ItemRarity.RARE, "built: he carries the hero's weapon, its rarity")
	check(keeper.keep_distance == template.ranged_keep_distance and template.keep_distance == 0.0, "a ranged weapon: he keeps his distance (the template untouched)")
	var hero_bow := player.get_weapon()
	check(keeper.weapon.projectile_speed <= template.ranged_shot_speed and keeper.weapon.cooldown >= template.ranged_cooldown_min and keeper.attack_windup >= template.ranged_attack_windup, "his bow shoots as a boss: shots no faster than %.0f, %.1f s apart at least, drawn %.2f s (a hero's bow from a boss can't be dodged)" % [template.ranged_shot_speed, template.ranged_cooldown_min, template.ranged_attack_windup])
	check(hero_bow.projectile_speed > template.ranged_shot_speed and hero_bow.cooldown < template.ranged_cooldown_min and template.attack_windup < template.ranged_attack_windup, "the hero's bow and the template untouched")
	var with_blade := template.build(KeeperSnapshot.new(_through_json(KeeperSnapshot.take(hero(), _run()))), CONTENT)
	check(is_equal_approx(with_blade.attack_windup, template.attack_windup) and with_blade.weapon.cooldown < template.ranged_cooldown_min, "a blade keeps its own pace (the ranged rules are for shots)")
	check(keeper.title == "Ash" and template.title == "Who You Were", "the pseudonym he played under as his title")
	var hero_skills := player.skills.skills.filter(func(s: SkillDef) -> bool: return s != null and not CONTENT.player.innate_skills.has(s))
	var all_skills: Array[SkillDef] = keeper.phases[0].skills
	check(all_skills.size() == mini(hero_skills.size(), template.max_skills) + template.phases[0].skills.size(), "his skills: the hero's (%d), made his" % all_skills.size())
	for i in mini(hero_skills.size(), template.max_skills):
		var made := all_skills[i]
		var own: SkillDef = hero_skills[i]
		check(made != own and made.id == own.id and made.cast_time > 0.0 and is_equal_approx(made.cooldown, own.cooldown * template.cooldown_scale), "%s: his copy is warned (%.2f s) and slower to come back" % [own.id, made.cast_time])
	check(keeper.skills.size() >= 1 and keeper.skills.size() <= 2 + template.skills.size(), "he opens with his weapon's skills")
	var every: Array[SkillDef] = keeper.skills.duplicate()
	for phase in keeper.phases:
		every.append_array(phase.skills)
	check(every.all(func(s: SkillDef) -> bool: return s.cast_animation == template.cast_pose) and not template.cast_pose.is_empty(), "every skill of his is cast in his pose (%s: the hero's frames have no cast animation), not his blow's" % template.cast_pose)
	check(template.phases[1].skills.all(func(s: SkillDef) -> bool: return s.cast_animation == &"cast"), "the lantern's skill file untouched (Tôma casts it in his own way)")
	check(CONTENT.player.frames.has_animation(StringName(String(template.cast_pose) + "_down")) and CONTENT.player.frames.get_animation_loop(StringName(String(template.cast_pose) + "_down")), "his cast pose is one the hero's frames have, looping (held for the warning)")
	var shade := template.traits[0] as ShadeTrait
	check(shade.cast_step(false, 0.5) == 0 and shade.cast_step(true, 0.0) == 1 and shade.cast_step(true, 1.0) == shade.cast_glow_steps and shade.glow_size_at(0) == shade.glow_size and shade.glow_size_at(shade.cast_glow_steps) == PixelDraw.snap_length(shade.cast_glow_size), "casting, his lantern's glow swells in whole steps, on the grid")
	check(shade.cast_lantern_offset.y < shade.lantern_offset.y - 8.0, "casting, his lantern is raised over his head")
	var picture := AnimatedSprite2D.new()
	picture.sprite_frames = template.frames
	picture.offset = template.frames_offset
	picture.animation = &"walk_down"
	shade.dress_look(picture)
	var look := picture.material as ShaderMaterial
	check(look != null and look.shader == BodyLook.SHADER and is_equal_approx(float(look.get_shader_parameter(&"flash_amount")), shade.pallor) and Color(look.get_shader_parameter(&"flash_color")) == shade.color and picture.get_node_or_null("Lantern") is Sprite2D, "in the codex he is the same shade as in his fight (pallor, rim, lantern), not the hero")
	picture.free()
	check(keeper.phases[1].skills.any(func(s: SkillDef) -> bool: return s.effects.any(func(e: Effect) -> bool: return e is GroundStrikeEffect)), "in the last phase the lantern burns too")
	var gear := keeper.traits.filter(func(t: MonsterTrait) -> bool: return t is WornGearTrait)
	check(gear.size() == 1 and (gear[0] as WornGearTrait).pieces.size() == 2, "he wears the hero's helm and mail")
	var relics := keeper.traits.filter(func(t: MonsterTrait) -> bool: return t is PerkTrait)
	var kept: Array = (relics[0] as PerkTrait).perks if not relics.is_empty() else []
	check(kept.count(_perk("ignite")) == template.max_perk_stacks and kept.has(_perk("multishot")) and not kept.has(_perk("strength")) and not kept.has(_perk("vitality")), "his relics: the kept ones (Ignite at %d at most, Hydra's Quiver), not the plain stats" % template.max_perk_stacks)
	check(template.traits.size() == 1 and template.traits[0] is ShadeTrait, "the template's own traits untouched")
	# Health from his level, within bounds.
	var low := template.build(KeeperSnapshot.new({ "version": 1, "level": 1, "gear": [] }), CONTENT)
	var high := template.build(KeeperSnapshot.new({ "version": 1, "level": 99, "gear": [] }), CONTENT)
	check(low.stats.max_hp == roundi(template.stats.max_hp * template.health_scale_min) and high.stats.max_hp == roundi(template.stats.max_hp * template.health_scale_max) and template.stats.max_hp == CONTENT.dungeon.finale.keeper.stats.max_hp, "his health follows the hero's level, within %.2f-%.2f of the template's" % [template.health_scale_min, template.health_scale_max])
	# A blow of about the same weight, whatever the weapon.
	for path in ["res://data/items/weapons/rapier.tres", "res://data/items/weapons/hammer.tres"]:
		var with_it := template.build(KeeperSnapshot.new({ "version": 1, "level": 15, "gear": [{ "id": String((load(path) as WeaponDef).id) }] }), CONTENT)
		check(with_it.weapon.damage + with_it.stats.attack == template.blow_power, "%s: his blow comes to %d before the floor's rules" % [path.get_file(), template.blow_power])
	player.queue_free()


## His codex page shows the weapon of the hero waiting and his blow, not the template's stand-in.
func _test_codex_page() -> void:
	var template := CONTENT.dungeon.finale.keeper
	var page := MonsterPage.new()
	add_child(page)
	var hammer := load("res://data/items/weapons/hammer.tres") as WeaponDef
	Profile.keeper = { "version": 1, "level": 15, "gear": [{ "id": String(hammer.id) }] }
	page.show_monster(template, CONTENT)
	var attacks := page._attacks()
	var damage: String = page._stats()[1][1]
	check(attacks[0].name == hammer.display_name and (attacks[0].attack as WeaponDef).id == hammer.id and damage == str(template.blow_power), "his codex page: the hero's %s and his blow (%s), not the template's %s" % [hammer.display_name, damage, template.weapon.display_name])
	Profile.keeper = {}
	page.show_monster(template, CONTENT)
	attacks = page._attacks()
	check(attacks[0].name == "Your weapon" and attacks.all(func(a: Dictionary) -> bool: return a.name != template.weapon.display_name), "none waiting: his basic attack is the weapon you carried, never the template's %s" % template.weapon.display_name)
	page.free()


## Where his AI uses the hero's skills is data (the "His skills" group), and the same as when it
## was written in the script (50 and +30 for a dive, shots to 360 at most, +20 around a circle, 260
## for the rest): every hero skill, made his, keeps those ranges.
func _test_skill_ranges() -> void:
	var template := CONTENT.dungeon.finale.keeper
	check(is_equal_approx(template.shot_min_range, 90.0), "his shots from 90 out, in his data (balance-log 2026-10-24: a bolt let go in the hero's face can't be stepped out of)")
	check(is_equal_approx(template.dive_min_range, 50.0) and is_equal_approx(template.dive_range_margin, 30.0) and is_equal_approx(template.shot_max_range, 360.0) and is_equal_approx(template.area_range_margin, 20.0) and is_equal_approx(template.other_max_range, 260.0), "his AI's ranges are in his data, as they were (50, +30, 360, +20, 260)")
	var hero_skills: Array[SkillDef] = []
	for item in CONTENT.items + CONTENT.player.starting_equipment:
		if item is WeaponDef:
			for skill in (item as WeaponDef).skills:
				if skill and not hero_skills.has(skill):
					hero_skills.append(skill)
		elif item is SkillTomeDef and (item as SkillTomeDef).skill and not hero_skills.has((item as SkillTomeDef).skill):
			hero_skills.append((item as SkillTomeDef).skill)
	var kinds := {}
	for skill in hero_skills:
		var made := template.build(KeeperSnapshot.new({ "version": 1, "level": 15, "gear": [] }), CONTENT).boss_skill(skill)
		if made == null:
			continue
		var first := made.effects[0]
		var expected := Vector2(0.0, 260.0)
		var kind := "other"
		if first is DashStrikeEffect:
			expected = Vector2(50.0, (first as DashStrikeEffect).distance + 30.0)
			kind = "dive"
		elif first is ProjectileEffect:
			# (From 90 out since the ranged Keepers' measure: no bolt in the hero's face.)
			expected = Vector2(90.0, minf((first as ProjectileEffect).max_distance, 360.0))
			kind = "shot"
		elif first is DamageAreaEffect:
			expected = Vector2(0.0, (first as DamageAreaEffect).offset + (first as DamageAreaEffect).radius + 20.0)
			kind = "area"
		kinds[kind] = true
		check(is_equal_approx(made.ai_min_range, expected.x) and is_equal_approx(made.ai_max_range, expected.y), "%s (%s): his AI uses it from %.0f to %.0f, as before (%.0f to %.0f)" % [skill.id, kind, made.ai_min_range, made.ai_max_range, expected.x, expected.y])
	check(kinds.size() >= 3, "the hero's skills cover the kinds of range (%s)" % ", ".join(kinds.keys()))


## Beatable, not a pushover: his health against Tôma's and the Maw's together, his blows against
## a late hero's health, at the bottom on Keeper.
func _test_balance_numbers() -> void:
	var finale := CONTENT.dungeon.finale
	var depth := CONTENT.dungeon.total_floors()
	var rules := FloorRules.make(CONTENT.dungeon, CONTENT.get_difficulty(&"normal"), null, depth)
	var toma := rules.scale_monster(finale.boss.stats, true).max_hp
	var maw := rules.scale_monster(finale.boss.next_boss.stats, true).max_hp
	var player := hero()
	var keeper := finale.keeper.build(KeeperSnapshot.new(KeeperSnapshot.take(player, _run())), CONTENT)
	var health := rules.scale_monster(keeper.stats, true).max_hp
	check(health > toma and health < toma + maw, "his health (%d) between Tôma's (%d) and Tôma's and the Maw's together (%d): one fight in place of two" % [health, toma, toma + maw])
	var power := roundi((keeper.weapon.damage + rules.scale_monster(keeper.stats, true).attack + finale.boss.phases[-1].bonuses.attack) * rules.monster_damage(true))
	var toma_power := roundi((finale.boss.weapon.damage + rules.scale_monster(finale.boss.stats, true).attack + finale.boss.phases[-1].bonuses.attack) * rules.monster_damage(true))
	check(power <= roundi(toma_power * 1.25) and power >= roundi(toma_power * 0.75), "his blow in his last phase (%d) weighs about Tôma's (%d)" % [power, toma_power])
	var late_hp := CONTENT.player.base_stats.max_hp + 17 * CONTENT.player.level_bonus.max_hp
	check(power * 4 <= late_hp, "no one-shot: a level 18 hero (%d Health before his gear) takes four of his heaviest blows at least (%d)" % [late_hp, power])
	player.queue_free()


## His story (not a warden's: no fragments, no deed, few words): every line in both languages,
## Tôma named only once the keeper may be (docs/lore.md section 7), his last words, his records.
func _test_chronicle() -> void:
	var keeper := CONTENT.dungeon.finale.keeper
	var chronicle := keeper.chronicle
	var fr := TranslationServer.get_translation_object("fr")
	var texts: Array[String] = [keeper.display_name, keeper.description, keeper.title, keeper.records_title, keeper.record_line]
	for phase in keeper.phases:
		texts.append(phase.message)
	for chapter in chronicle.chapters:
		texts.append(chapter.title)
		for line in chapter.lines:
			texts.append(line)
			if line.contains("Tôma") or fr.get_message(line).contains("Tôma"):
				check(chapter.conditions.has(CONTENT.narrative.keeper_reveal), "%s: naming Tôma, it waits until the keeper may be named" % chapter.id)
	for line in chronicle.waking_lines + chronicle.last_words:
		texts.append(line.line)
	for ending in CONTENT.dungeon.finale.endings:
		texts.append(ending.keeper_hint)
		texts.append(ending.keeper_text)
	texts.append(CONTENT.dungeon.finale.keeper_choice_lore)
	for text in texts:
		check(not text.is_empty() and not String(fr.get_message(text)).is_empty() and String(fr.get_message(text)) != text, "translated: %s" % text.left(40))
	check(chronicle.chapters.size() >= 3 and chronicle.fragments.is_empty() and not chronicle.last_words.is_empty(), "his story: three chapters, no fragments (his past is the hero's own run), last words")
	check(chronicle.waking_lines.all(func(line: WakingLine) -> bool: return tr(line.line).length() <= 12), "he says almost nothing as he wakes")
