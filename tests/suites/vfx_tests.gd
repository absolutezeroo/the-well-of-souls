class_name VfxTests
extends TestSuite
## Effects, no game running (run by the unit suite): the elements' data, the pixel grid rules,
## the frame slicer, the palette swap, and which slows show frost (docs/vfx.md).

## Every resource under these folders is checked for sheets that slice and scales on the grid.
const DATA_DIRS: Array[String] = ["res://data/skills", "res://data/items/weapons", "res://data/perks", "res://data/runes", "res://data/affixes", "res://data/monsters", "res://data/vfx"]


func run() -> void:
	_test_elements()
	_test_frame_slicer()
	_test_palette_swap()
	_test_pixel_grid()
	_test_slow_looks()
	_test_data_sheets()
	_test_frost_kit()
	_test_storm_kit()
	_test_holy_kit()
	_test_shadow_kit()
	_test_arcane_kit()
	_test_borrowed_art()
	_test_poison_kit()
	_test_blood_kit()
	_test_spirit_kit()
	_test_fire_kit()
	_test_earth_kit()
	_test_physical_kit()
	_test_particles()
	_test_smooth_shapes()
	_test_grid_rule_breaks()
	_test_one_ui_palette()
	_test_telegraphs()
	_test_layers()
	_test_own_effects()
	_test_elemental_swings()
	_test_body_shader()
	_test_shaders()
	_test_no_squared_colors()
	_test_whole_scales()
	_test_world_tints()
	_test_simulation()


## Each element: an id, a ramp of 3 to 5 colors from a bright core to a dark edge (shadow turned
## inside out), its kit's sheets cut into whole frames at a whole even texel size.
func _test_elements() -> void:
	var all := VfxElementDef.all()
	check(all.size() >= 12, "vfx: the twelve elements are listed (%d)" % all.size())
	var ids := {}
	for element in all:
		check(element != null and element.id != &"", "vfx: an element has an id")
		if element == null:
			continue
		check(not ids.has(element.id), "vfx: element %s listed once" % element.id)
		ids[element.id] = true
		check(element.ramp.size() >= 3 and element.ramp.size() <= 5, "vfx: %s has a ramp of 3 to 5 colors (%d)" % [element.id, element.ramp.size()])
		check(element.accent >= 0 and element.accent < element.ramp.size(), "vfx: %s's accent is a step of its ramp" % element.id)
		var bright := element.core().get_luminance()
		var dark := element.edge().get_luminance()
		if element.id == &"shadow":
			check(bright < dark, "vfx: shadow is the inside-out one (dark core, bright edge)")
		else:
			check(bright > dark, "vfx: %s goes from a bright core to a dark edge" % element.id)
		for color in element.ramp:
			check(color.a == 1.0, "vfx: %s's ramp is opaque" % element.id)
		for sheet: VfxSheetDef in [element.projectile, element.impact, element.piece, element.claw, element.blast]:
			if sheet:
				_check_sheet(sheet, "%s's kit" % element.id)
		if element.slow_look != &"":
			check(StatusFx.LOOKS.look(element.slow_look) != null, "vfx: %s's slow look %s exists" % [element.id, element.slow_look])
	for id: StringName in [&"fire", &"frost", &"water", &"poison", &"storm", &"holy", &"shadow", &"arcane", &"blood", &"spirit", &"earth", &"physical"]:
		check(VfxElementDef.named(id) != null, "vfx: the %s element exists" % id)
	# Every file in the folder is in the list (an unlisted element can't be found by id).
	var listed := 0
	for file in DirAccess.get_files_at("res://data/vfx/elements"):
		if file.ends_with(".tres"):
			listed += 1
	check(listed == all.size(), "vfx: every element file is listed in data/vfx/elements.tres (%d files, %d listed)" % [listed, all.size()])
	check(Palette.FROST.to_html(false) == VfxElementDef.named(&"frost").color().to_html(false), "vfx: Palette.FROST is the frost element's color")
	check(Palette.FIRE.to_html(false) == VfxElementDef.named(&"fire").color().to_html(false), "vfx: Palette.FIRE is the fire element's color")
	check(Palette.BLOOD.to_html(false) == VfxElementDef.named(&"blood").color().to_html(false), "vfx: Palette.BLOOD is the blood element's color")
	# Old content giving only a color gets a ramp of its own hue, not fire's bands.
	var made := VfxElementDef.or_color(null, Color("80ed99"))
	check(made.ramp.size() == 4 and made.color().to_html(false) != VfxElementDef.named(&"fire").color().to_html(false), "vfx: a plain color makes a ramp of its own hue")


func _check_sheet(sheet: VfxSheetDef, what: String) -> void:
	check(sheet.texture != null, "vfx: %s sheet has a texture" % what)
	if sheet.texture == null:
		return
	var size := sheet.frame_size()
	check(size.x * sheet.frame_count() == sheet.texture.get_width() and size.y * sheet.rows() == sheet.texture.get_height(), "vfx: %s sheet (%s) cuts into whole frames" % [what, sheet.texture.resource_path])
	check(sheet.texel >= 2 and sheet.texel % 2 == 0, "vfx: %s sheet is drawn at a whole even texel size (%d)" % [what, sheet.texel])


## Frames in a row: square by default, and a strip of non-square frames cut by its count (the
## 144x10 ice strip is 8 frames of 18x10, not one bar).
func _test_frame_slicer() -> void:
	var strip := ImageTexture.create_from_image(Image.create(144, 10, false, Image.FORMAT_RGBA8))
	check(VfxSheetDef.columns(strip, 8) == 8 and VfxSheetDef.cell_size(strip, 8) == Vector2i(18, 10), "slicer: 144x10 in 8 frames is 18x10 each")
	check(VfxSheetDef.columns(strip, 0) == 1, "slicer: a strip that isn't whole squares is one frame unless told (so data must say)")
	check(not VfxSheetDef.slices_evenly(strip, 0) and VfxSheetDef.slices_evenly(strip, 8) and not VfxSheetDef.slices_evenly(strip, 7), "slicer: says when a count cuts whole frames")
	var orb := ImageTexture.create_from_image(Image.create(64, 16, false, Image.FORMAT_RGBA8))
	check(VfxSheetDef.columns(orb, 0) == 4 and VfxSheetDef.cell_size(orb, 0) == Vector2i(16, 16), "slicer: 64x16 is 4 square frames")
	var long_shot := VfxSheetDef.from_texture(strip, 8)
	check(long_shot.orient == VfxSheetDef.Orient.SNAPPED and long_shot.directions == 16, "slicer: a long shot turns, snapped to 16 directions")
	var round_shot := VfxSheetDef.from_texture(orb)
	check(round_shot.orient == VfxSheetDef.Orient.NONE and round_shot.angle_for(Vector2(1, 1)) == 0.0, "slicer: a round orb is never turned")
	check(is_equal_approx(long_shot.angle_for(Vector2.from_angle(0.3)), TAU / 16.0), "slicer: a turned sheet snaps to the nearest 22.5 degrees")
	check(VfxSheetDef.direction_index(Vector2.RIGHT, 16) == 0 and VfxSheetDef.direction_index(Vector2.DOWN, 16) == 4 and VfxSheetDef.direction_index(Vector2.UP, 16) == 12, "slicer: directions go clockwise from the right")
	var rows := VfxSheetDef.new()
	rows.texture = ImageTexture.create_from_image(Image.create(32, 256, false, Image.FORMAT_RGBA8))
	rows.frames = 2
	rows.orient = VfxSheetDef.Orient.ROWS
	rows.directions = 16
	check(rows.frame_size() == Vector2i(16, 16) and rows.region(1, Vector2.DOWN) == Rect2(16, 64, 16, 16), "slicer: a drawn direction is a row (down: the fifth)")
	var variants := VfxSheetDef.new()
	variants.texture = ImageTexture.create_from_image(Image.create(128, 72, false, Image.FORMAT_RGBA8))
	variants.frames = 8
	variants.variants = 3
	check(variants.frame_size() == Vector2i(16, 24) and variants.region(2, Vector2.RIGHT, 1) == Rect2(32, 24, 16, 24), "slicer: rows of variants")


## The palette swap paints every opaque pixel in the ramp's exact colors, brightest to core,
## darkest to edge, and makes alpha hard.
func _test_palette_swap() -> void:
	var image := Image.create(4, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color.WHITE)
	image.set_pixel(1, 0, Color(0.5, 0.9, 0.95))
	image.set_pixel(2, 0, Color(0.3, 0.5, 0.6, 0.8))
	image.set_pixel(3, 0, Color(1, 1, 1, 0.2))
	var poison := VfxElementDef.named(&"poison")
	var out := VfxRamp.recolor_image(image, poison.ramp)
	check(out.get_pixel(0, 0).to_html(false) == poison.core().to_html(false), "palette swap: the brightest shade takes the core")
	check(out.get_pixel(2, 0).to_html(false) == poison.edge().to_html(false), "palette swap: the darkest shade takes the edge")
	check(out.get_pixel(1, 0).to_html(false) in Array(poison.ramp).map(func(c: Color) -> String: return c.to_html(false)), "palette swap: the shades between take ramp colors")
	check(out.get_pixel(2, 0).a == 1.0 and out.get_pixel(3, 0).a == 0.0, "palette swap: alpha is hard")


func _test_pixel_grid() -> void:
	check(PixelDraw.snap(Vector2(3.1, -2.9)) == Vector2(4, -2), "grid: positions snap to the 2-unit art pixel")
	check(PixelDraw.sheet_scale(6.875) == 6.0 and PixelDraw.sheet_scale(1.78) == 2.0 and PixelDraw.sheet_scale(0.4) == 2.0, "grid: sheet scales snap to whole even sizes, 2 at least")
	var on := 0
	for y in 4:
		for x in 4:
			if PixelDraw.dither(Vector2i(x, y), 0.5):
				on += 1
	check(on == 8 and not PixelDraw.dither(Vector2i(1, 1), 0.0) and PixelDraw.dither(Vector2i(1, 1), 1.0), "grid: dithering at 50% keeps half the pixels, all or none at the ends")
	# Legacy calls with stretched sizes land on whole texels.
	var texture := load("res://assets/fx/magic_circle.png") as Texture2D
	for size: float in [2.5, 3.75, 6.875, 1.5, 5.3]:
		var vfx := SheetVfx.create(texture, Vector2(3, 3), 0.7, size)
		check(vfx.sheet.texel % 2 == 0 and vfx.sheet.texel >= 2, "grid: a sheet wanted at %.2fx is drawn at %dx (whole art pixels)" % [size, vfx.sheet.texel])
		check(vfx.position == PixelDraw.snap(vfx.position), "grid: a sheet effect sits on the grid")
		check(is_equal_approx(fmod(vfx.sheet.angle_for(Vector2.from_angle(0.7)), TAU / 16.0), 0.0), "grid: a turned sheet snaps to 16 directions")
		vfx.free()


## A slow shows frost only when frost (or the cold) causes it: sand, ink, spores, a wail and
## the ground slow without rime.
func _test_slow_looks() -> void:
	var frost := StatusSet.new()
	frost.apply_slow(0.4, 2.0)
	check(frost.active_ids().has(&"slow") and frost.tint().a > 0.0, "slow look: a hit's slow is frost by default (rime, a cold tint)")
	var sand := StatusSet.new()
	sand.apply_slow(0.4, 2.0, &"hit", VfxElementDef.named(&"earth"))
	check(sand.is_slowed() and not sand.active_ids().has(&"slow") and sand.tint().a == 0.0, "slow look: sand slows without frost")
	var ground := StatusSet.new()
	ground.apply_slow(0.5, 0.2, StatusSet.GROUND_SLOW)
	check(ground.is_slowed() and ground.active_ids().is_empty(), "slow look: quicksand shows nothing")
	var cold := StatusSet.new()
	cold.apply_slow(0.3, 0.2, &"cold")
	check(cold.active_ids().has(&"slow"), "slow look: the cold of a frostbound floor shows frost")
	var both := StatusSet.new()
	both.apply_slow(0.4, 2.0, &"hit", VfxElementDef.named(&"shadow"))
	both.apply_slow(0.2, 2.0, &"hit", VfxElementDef.named(&"frost"))
	check(both.active_ids().has(&"slow"), "slow look: frost on a body already inked still shows")
	# The content: what isn't frost says so.
	for path: String in ["res://data/items/weapons/monster/sand_breath.tres", "res://data/skills/boss/sandstorm.tres", "res://data/skills/monster/ink_ring.tres", "res://data/skills/boss/wailing_ring.tres", "res://data/skills/boss/wailing_ring_fierce.tres", "res://data/skills/monster/spore_cloud.tres", "res://data/items/weapons/monster/water_jet.tres"]:
		for status in _statuses(load(path)):
			if status.slow > 0.0:
				check(status.slow_element != null and status.slow_element.slow_look != &"slow", "slow look: %s slows without frost" % path.get_file())
				# Only the spirit's wail shows on the body (a pale flicker); sand, ink, spores, water show nothing.
				var wail := status.slow_element == VfxElementDef.named(&"spirit")
				check(status.slow_element.slow_look == (&"haunt" if wail else &""), "slow look: %s shows %s" % [path.get_file(), "the spirit's pale flicker" if wail else "nothing"])


## Every sheet the data points to cuts into whole frames, and every scale is whole art pixels.
func _test_data_sheets() -> void:
	for resource in _all_resources():
		var where := resource.resource_path.get_file()
		for effect in _effects_of(resource):
			if effect is ProjectileEffect and (effect as ProjectileEffect).texture:
				var shot := effect as ProjectileEffect
				check(VfxSheetDef.slices_evenly(shot.texture, shot.texture_frames), "sheets: %s's shot %s cuts into whole frames" % [where, shot.texture.resource_path.get_file()])
			elif effect is DamageAreaEffect and (effect as DamageAreaEffect).fx:
				var area := effect as DamageAreaEffect
				check(VfxSheetDef.slices_evenly(area.fx, area.fx_frames), "sheets: %s's area sheet cuts into whole frames" % where)
				var frame := VfxSheetDef.cell_size(area.fx, area.fx_frames)
				var vfx := SheetVfx.create(area.fx, Vector2.ZERO, 0.0, area.radius * 2.0 / maxi(frame.x, frame.y), 16.0, frame.x)
				check(vfx.sheet.texel % 2 == 0, "sheets: %s's area sheet is drawn at a whole even scale" % where)
				vfx.free()
			elif effect is DashStrikeEffect and (effect as DashStrikeEffect).fx:
				var dash := effect as DashStrikeEffect
				var vfx := SheetVfx.create(dash.fx, Vector2.ZERO, 0.4, maxf(dash.distance, 40.0) / dash.fx.get_height())
				check(vfx.sheet.texel % 2 == 0, "sheets: %s's dash sheet is drawn at a whole even scale" % where)
				vfx.free()
			if effect is DamageAreaEffect and (effect as DamageAreaEffect).strike:
				_check_sheet((effect as DamageAreaEffect).strike, "%s's strike" % where)
			if effect is BuffEffect and (effect as BuffEffect).sheet:
				_check_sheet((effect as BuffEffect).sheet, "%s's blessing" % where)
		if resource is WeaponDef:
			var weapon := resource as WeaponDef
			if weapon.projectile_texture:
				check(VfxSheetDef.slices_evenly(weapon.projectile_texture, weapon.projectile_frames), "sheets: %s's shot cuts into whole frames" % where)
			check(not (weapon.shows_arc() and weapon.attack_fx), "sheets: %s draws its swing's arc or a sheet, not a sheet it would never show" % where)
		if resource is StatusLookDef:
			var look := resource as StatusLookDef
			for pair: Array in [[look.particle, look.particle_frames], [look.burst, look.burst_frames], [look.crust, look.crust_frames]]:
				if pair[0]:
					check((pair[0] as Texture2D).get_width() % int(pair[1]) == 0, "sheets: %s's sheets cut into whole frames" % where)
			check(look.texel % 2 == 0, "sheets: %s is drawn at a whole even scale" % where)
	var campfire := load("res://data/hazards/campfire.tres") as HeatSourceDef
	check(VfxSheetDef.cell_size(campfire.flames, campfire.flame_frames) == Vector2i(8, 12), "sheets: the campfire's flames are 8x12, not squares cut across two flames")
	# Thunder's bolt from the sky is drawn whole at the art's size, not a strip of little bolts
	# stretched 4.4x (the old thunder.png).
	var thunder := load("res://data/skills/player/thunder.tres") as SkillDef
	var bolt := (thunder.effects[0] as DamageAreaEffect).strike
	check(bolt != null and bolt.frame_size() == Vector2i(48, 96) and bolt.texel == 2, "sheets: Thunder's bolt is one 48x96 strike drawn at 2x")
	check(Vfx.SIGIL.recolor and VfxSheetDef.slices_evenly(Vfx.SIGIL.texture, Vfx.SIGIL.frames) and Vfx.SIGIL.texel == 2, "sheets: the sigil of heals and buffs cuts into whole frames at 2x and takes any ramp")


## Frost is the reference kit: every frost user is frost, none shoots a shuriken.
func _test_frost_kit() -> void:
	var frost := VfxElementDef.named(&"frost")
	check(frost.projectile and frost.impact and frost.piece and frost.claw and frost.slow_look == &"slow", "frost: its kit is full (shot, impact, nova piece, claw, chilled look)")
	check(frost.projectile.orient == VfxSheetDef.Orient.ROWS and frost.projectile.directions == 16, "frost: the shard is drawn in 16 directions, never rotated")
	var look := StatusFx.LOOKS.look(&"slow")
	check(look.element == frost and look.crust != null and look.mist_rate > 0.0 and look.particle == null, "frost: the chilled look is rime and cold mist, no snowflake")
	var staff := load("res://data/items/weapons/stick.tres") as WeaponDef
	check(staff.element == frost and staff.projectile_texture == null, "frost: the Frost Staff fires the frost shard")
	check(staff.on_hit != null and staff.on_hit.slow > 0.0, "frost: the Frost Staff's shards chill")
	var users := {
		"res://data/skills/player/ice_shards.tres": "projectile", "res://data/skills/player/frost_nova.tres": "area",
		"res://data/skills/boss/frost_breath.tres": "projectile", "res://data/skills/boss/frost_breath_fierce.tres": "projectile",
		"res://data/skills/boss/hailstorm.tres": "projectile", "res://data/skills/boss/hailstorm_fierce.tres": "projectile",
		"res://data/skills/boss/glacial_dive.tres": "dash", "res://data/skills/boss/glacial_dive_fierce.tres": "dash",
	}
	for path: String in users:
		for effect in _effects_of(load(path)):
			var element: VfxElementDef = effect.get("element")
			check(element == frost, "frost: %s is frost" % path.get_file())
			if effect is ProjectileEffect:
				check((effect as ProjectileEffect).texture == null, "frost: %s shoots the frost shard (no other sprite)" % path.get_file())
			if effect is DamageAreaEffect:
				check((effect as DamageAreaEffect).fx == null, "frost: %s is the nova of crystals, not a stretched sheet" % path.get_file())
	var shards := load("res://data/perks/common/ice_shards.tres") as PerkDef
	check((shards.passives[0] as KillBurstPassive).shard_element == frost, "frost: the Ice Shards perk throws the same shards as the skill")
	for path: String in ["res://data/perks/common/cold_snap.tres", "res://data/perks/common/iron_skin.tres", "res://data/runes/shatter.tres"]:
		check((load(path) as Resource).get("passives")[0].get("element") == frost, "frost: %s's wave is frost" % path.get_file())
	check((load("res://data/perks/synergies/frost.tres") as SynergyDef).passives[0].get("crit_element") == frost, "frost: the Frost synergy freezes in frost")
	check((load("res://data/perks/common/thunderclap.tres") as PerkDef).passives[0].get("element") == VfxElementDef.named(&"storm"), "storm: Thunderclap's wave is the storm, not frost")
	check((load("res://data/items/weapons/monster/water_jet.tres") as WeaponDef).element == VfxElementDef.named(&"water"), "water: the Kappa's jet is water, not ice")
	var fang := load("res://data/items/weapons/monster/frost_fang.tres") as WeaponDef
	check(fang.element == frost and fang.attack_fx == null, "frost: the Azure Wyrm's Frost Fang strikes with frost claws, not blood")
	var skull := load("res://data/monsters/frost_skull.tres") as MonsterDef
	check(skull.weapon.element == frost, "frost: the Frost Skull bites with frost")
	check((skull.traits[0] as DeathBurstTrait).element == frost, "frost: the Frost Skull bursts into a ring of ice")
	# No frost user anywhere shoots a shuriken.
	for resource in _all_resources():
		var shuriken := "shuriken"
		if resource is WeaponDef and (resource as WeaponDef).element == frost and (resource as WeaponDef).projectile_texture:
			check(not (resource as WeaponDef).projectile_texture.resource_path.contains(shuriken), "frost: %s shoots no shuriken" % resource.resource_path.get_file())
		for effect in _effects_of(resource):
			if effect is ProjectileEffect and (effect as ProjectileEffect).element == frost and (effect as ProjectileEffect).texture:
				check(not (effect as ProjectileEffect).texture.resource_path.contains(shuriken), "frost: %s shoots no shuriken" % resource.resource_path.get_file())


## Storm: violet-white lightning everywhere it strikes, one identity (the synergy, Thunder and its
## tome share the element's color), forks and flicker instead of orbs.
func _test_storm_kit() -> void:
	var storm := VfxElementDef.named(&"storm")
	check(storm.projectile and storm.impact and storm.piece and storm.bit == VfxElementDef.Bit.FORK, "storm: its kit is full (spark, impact, crackle piece) and its bits are forks")
	var thunder := (load("res://data/skills/player/thunder.tres") as SkillDef).effects[0] as DamageAreaEffect
	check(thunder.element == storm and thunder.fx == null and thunder.strike != null, "storm: Thunder strikes a bolt from the sky over a ring of crackles, not a stretched sheet")
	var nova := (load("res://data/skills/player/spark_nova.tres") as SkillDef).effects[0] as ProjectileEffect
	check(nova.element == storm and nova.texture == null, "storm: Spark Nova throws storm sparks, not cyan orbs")
	var wand := load("res://data/items/weapons/magic_wand.tres") as WeaponDef
	check(wand.element == storm and wand.projectile_texture == null, "storm: the Spark Wand fires storm sparks")
	for path: String in ["res://data/perks/synergies/storm.tres", "res://data/runes/spark.tres", "res://data/affixes/shocking.tres", "res://data/perks/common/shock_roll.tres", "res://data/runes/gale.tres", "res://data/perks/common/thunderclap.tres"]:
		check((load(path) as Resource).get("passives")[0].get("element") == storm, "storm: %s is storm" % path.get_file())
	var accent := storm.color().to_html(false)
	for path: String in ["res://data/perks/synergies/storm.tres", "res://data/skills/player/thunder.tres", "res://data/skills/player/spark_nova.tres", "res://data/items/tomes/tome_thunder.tres", "res://data/items/weapons/magic_wand.tres"]:
		check((load(path) as Resource).get("color").to_html(false) == accent, "storm: %s wears the storm's color" % path.get_file())
	# A chain of lightning is a jagged fork on the grid that ends where it struck.
	var beam := BeamVfx.create(Vector2(1, 3), Vector2(121, 47), Color.WHITE, storm)
	var on_grid := beam._knees.size() >= 3
	for knee in beam._knees:
		on_grid = on_grid and knee == PixelDraw.snap(knee)
	check(on_grid and beam._knees[beam._knees.size() - 1] == PixelDraw.snap(Vector2(121, 47)) - beam.position, "storm: chain lightning forks in knees on the art grid, from target to target")
	beam.free()


## Holy: rays, columns and rings of light; the 4-point glint is its own.
func _test_holy_kit() -> void:
	var holy := VfxElementDef.named(&"holy")
	check(holy.piece != null and holy.bit == VfxElementDef.Bit.GLINT, "holy: its nova is made of rays and its bits are 4-point glints")
	for element in VfxElementDef.all():
		if element != holy:
			check(element.bit != VfxElementDef.Bit.GLINT, "holy: only holy throws 4-point glints (%s doesn't)" % element.id)
	for path: String in ["res://data/skills/player/smite.tres", "res://data/skills/player/holy_light.tres", "res://data/skills/player/holy_shield.tres"]:
		for effect in _effects_of(load(path)):
			check(effect.get("element") == holy, "holy: %s's %s is holy" % [path.get_file(), effect.get_script().get_global_name()])
			if effect is DamageAreaEffect:
				check((effect as DamageAreaEffect).fx == null, "holy: %s is a ring of rays, not holy_circle stretched 5x" % path.get_file())
	var smite := (load("res://data/skills/player/smite.tres") as SkillDef).effects[0] as DamageAreaEffect
	check(smite.strike != null and smite.strike.texel == 2, "holy: Smite brings a column of light down, at the art's size")
	var shield := (load("res://data/skills/player/holy_shield.tres") as SkillDef).effects[0] as BuffEffect
	check(shield.sheet != null, "holy: Holy Shield raises a ring of light into a halo")


## Shadow: every shadow shot is a dark knot with a burning rim (they are all enemy threats).
func _test_shadow_kit() -> void:
	var shadow := VfxElementDef.named(&"shadow")
	check(shadow.projectile and shadow.impact and shadow.piece and shadow.motion == VfxElementDef.Motion.CONVERGE, "shadow: its kit is full (knot, collapsing ring, smoke) and it pulls inward")
	for path: String in ["res://data/items/weapons/monster/shadow_staff.tres", "res://data/items/weapons/monster/ink_bolt.tres", "res://data/items/weapons/monster/hex_staff.tres"]:
		var weapon := load(path) as WeaponDef
		check(weapon.element == shadow and weapon.projectile_texture == null, "shadow: %s fires the shadow knot" % path.get_file())
	for path: String in ["res://data/skills/monster/volley.tres", "res://data/skills/monster/ink_ring.tres"]:
		for effect in _effects_of(load(path)):
			check(effect.get("element") == shadow and effect.get("texture") == null, "shadow: %s fires shadow knots" % path.get_file())
	var step := load("res://data/skills/player/shadow_step.tres") as SkillDef
	check(step.effects[0] is DashEffect and (step.effects[0] as DashEffect).element == shadow, "shadow: Shadow Step leaves in a burst of shadow and a trail of smoke")
	check((step.effects[1] as ProjectileEffect).element == shadow, "shadow: Shadow Step's kunai land in shadow")


## Arcane: a magenta missile with orbiting motes and rune-diamonds, no borrowed orb.
func _test_arcane_kit() -> void:
	var arcane := VfxElementDef.named(&"arcane")
	check(arcane.projectile and arcane.impact and arcane.piece and arcane.bit == VfxElementDef.Bit.RUNE, "arcane: its kit is full (missile, ring of runes, rune piece) and its bits are rune-diamonds")
	check(not arcane.projectile.recolor and not arcane.projectile.texture.resource_path.contains("energyball"), "arcane: its missile is drawn on its ramp, not the ice orb repainted")
	var bolt := (load("res://data/skills/player/arcane_bolt.tres") as SkillDef).effects[0] as ProjectileEffect
	check(bolt.element == arcane and bolt.texture == null, "arcane: Arcane Bolt is the arcane missile")
	var ring := (load("res://data/perks/synergies/arcane.tres") as SynergyDef).passives[0].get("effects")[0] as ProjectileEffect
	check(ring.element == arcane and ring.texture == null, "arcane: the Arcane synergy's ring is arcane missiles, not smooth dots")


## No storm, holy, shadow or arcane content borrows another element's art (the cyan ice orb,
## the fire-colored throwing star).
func _test_borrowed_art() -> void:
	var mine: Array[StringName] = [&"storm", &"holy", &"shadow", &"arcane"]
	for resource in _all_resources():
		var where := resource.resource_path.get_file()
		if resource is WeaponDef and (resource as WeaponDef).element and mine.has((resource as WeaponDef).element.id) and (resource as WeaponDef).projectile_texture:
			var texture := (resource as WeaponDef).projectile_texture.resource_path
			check(not texture.contains("energyball") and not texture.contains("shuriken"), "borrowed art: %s shoots its element's own shot" % where)
		for effect in _effects_of(resource):
			var element: VfxElementDef = effect.get("element")
			if element and mine.has(element.id) and effect is ProjectileEffect and (effect as ProjectileEffect).texture:
				var texture := (effect as ProjectileEffect).texture.resource_path
				check(not texture.contains("energyball") and not texture.contains("shuriken"), "borrowed art: %s shoots its element's own shot" % where)
## Poison: a glob drawn in 16 directions, a splash that leaves a puddle, gas clouds for its
## novas, venom fangs; every poison user points at it and none borrows the energy orb.
func _test_poison_kit() -> void:
	var poison := VfxElementDef.named(&"poison")
	check(poison.projectile and poison.impact and poison.piece and poison.claw, "poison: its kit is full (glob, splash, gas cloud, fangs)")
	check(poison.projectile.orient == VfxSheetDef.Orient.ROWS and poison.projectile.directions == 16 and not poison.projectile.recolor, "poison: the glob is drawn in 16 directions on its own ramp (no painted orb)")
	check(poison.claw.orient == VfxSheetDef.Orient.ROWS, "poison: the fangs are drawn per direction, never rotated")
	check(poison.impact_mark > 0.0 and poison.mark.a > 0.0, "poison: a glob landing leaves a puddle")
	check(poison.mark.to_html(false) in Array(poison.ramp).map(func(c: Color) -> String: return c.to_html(false)), "poison: its puddle is a color of its ramp")
	var look := StatusFx.LOOKS.look(&"poison")
	check(look.element == poison and look.particle != null and look.mist_rate > 0.0, "poison: a poisoned body bubbles (a sheet on the grid) and leaks a sinking haze")
	check(look.text_color.to_html(false) == poison.color().to_html(false), "poison: its ticks are numbered in its own green (not a free 80ed99)")
	var spore := ((load("res://data/skills/monster/spore_cloud.tres") as SkillDef).effects[0] as DamageAreaEffect)
	check(spore.element == poison and spore.fx == null, "poison: Spore Cloud is a nova of gas clouds")
	for path: String in ["res://data/skills/boss/poison_spit.tres", "res://data/skills/boss/poison_spit_fierce.tres", "res://data/skills/boss/venom_spit.tres", "res://data/skills/boss/venom_spit_fierce.tres", "res://data/skills/boss/toxic_bloom.tres", "res://data/skills/boss/toxic_bloom_fierce.tres"]:
		for effect in _effects_of(load(path)):
			check(effect.get("element") == poison and effect.get("texture") == null, "poison: %s spits globs of venom" % path.get_file())
	for path: String in ["res://data/items/weapons/monster/acid_spit.tres", "res://data/items/weapons/monster/poison_fang.tres", "res://data/items/weapons/monster/jade_fang.tres"]:
		var weapon := load(path) as WeaponDef
		check(weapon.element == poison and weapon.attack_fx == null and weapon.projectile_texture == null, "poison: %s is venom (its glob or its fangs, not a borrowed sheet)" % path.get_file())
	var wyrm := load("res://data/monsters/bosses/jade_wyrm.tres") as MonsterDef
	check(wyrm.weapon.element == poison, "poison: the Jade Wyrm bites with venom fangs, not a blood claw")
	# Its novas are one pool of gas on the ground (not a ring of lumps): its rim where the area
	# ends, under every actor, on the world's grid, in its ramp, bubbles welling in it.
	check(poison.pool and poison.pool_bubble != null and poison.pool_bubble.texture != null and poison.pool_bubble.frames > 0, "poison: its novas lie as a pool of gas, bubbles welling in it")
	var pool := GasPoolVfx.create(Vector2(13, 7), 70.0, poison)
	var gas_look := pool.material as ShaderMaterial
	check(VfxLayer.of(pool) == VfxLayer.Layer.GROUND and pool.z_index < 0 and not pool.z_as_relative, "poison: the pool of gas lies under every actor (never over the hero's feet)")
	check(pool.position == PixelDraw.snap(Vector2(13, 7)) and is_equal_approx(pool.radius, 70.0) and is_equal_approx(float(gas_look.get_shader_parameter(&"radius")), 70.0), "poison: the pool sits on the grid and covers exactly the area it hit")
	check(gas_look.shader == GasPoolVfx.SHADER and FxLook.ALL.has(GasPoolVfx.SHADER), "poison: the pool is drawn by gas_pool.gdshader, warmed at load")
	var ramp: Array = gas_look.get_shader_parameter(&"ramp")
	check(ramp.size() == 5 and Color(ramp[1]) == poison.ramp[1] and Color(gas_look.get_shader_parameter(&"residue")) == poison.residue, "poison: the pool is drawn in poison's ramp and its murk")
	pool.free()
	check(not VfxElementDef.named(&"frost").pool, "poison: other elements keep their ring of pieces (a Frost Nova's crystals)")
	# Its trails and arcs are the same gas lying along a line or a sweep (not standing lumps).
	var from := Vector2(-61, 20)
	var to := Vector2(83, -14)
	var trail := ComposedVfx.line(from, to, poison) as GasPoolVfx
	check(trail != null, "poison: a trail through poison is gas lying along it (GasPoolVfx), not a row of lumps")
	if trail:
		var trail_look := trail.material as ShaderMaterial
		check(VfxLayer.of(trail) == VfxLayer.Layer.GROUND and trail_look.shader == GasPoolVfx.SHADER and int(trail_look.get_shader_parameter(&"shape")) == 1, "poison: the trail lies on the ground, drawn by gas_pool.gdshader along a segment")
		var axis: Vector2 = trail_look.get_shader_parameter(&"axis")
		check(trail.position.distance_to((from + to) * 0.5) <= 2.0 and (trail.position - axis).distance_to(from) <= 3.0 and (trail.position + axis).distance_to(to) <= 3.0, "poison: the trail runs from where it starts to where it ends, on the grid (%s, %s)" % [trail.position, axis])
		check(trail._extent.grow(-trail.radius).has_point(axis) and trail._extent.grow(-trail.radius).has_point(-axis), "poison: the trail's quad holds all of it")
		check(float(trail_look.get_shader_parameter(&"sweep")) > 0.0, "poison: the trail wells out from its start to its end")
		trail.free()
	var sweep := ComposedVfx.arc(Vector2(5, 9), 70.0, Vector2.UP, poison) as GasPoolVfx
	check(sweep != null, "poison: an arc of poison is gas swept across the front, not a row of lumps")
	if sweep:
		var sweep_look := sweep.material as ShaderMaterial
		var spine := float(sweep_look.get_shader_parameter(&"arc_radius"))
		check(int(sweep_look.get_shader_parameter(&"shape")) == 2 and VfxLayer.of(sweep) == VfxLayer.Layer.GROUND, "poison: the arc lies on the ground along an arc")
		check(spine + sweep.radius <= 70.0 + 0.5 and spine - sweep.radius >= 70.0 * 0.4, "poison: the arc's gas stays inside the area it hit (%.0f +- %.0f of 70)" % [spine, sweep.radius])
		check(is_equal_approx(float(sweep_look.get_shader_parameter(&"arc_from")) + float(sweep_look.get_shader_parameter(&"arc_span")) * 0.5, Vector2.UP.angle()), "poison: the arc faces where the blow went")
		sweep.free()
	var frost_trail := ComposedVfx.line(from, to, VfxElementDef.named(&"frost"))
	check(frost_trail is ComposedVfx, "poison: other elements keep their trail of pieces (a dash leaving ice)")
	frost_trail.free()


## Blood: claws rake in blood, a wound spurts and stains, Battle Cry bursts jets of blood, and
## what drinks blood draws it out of its victim.
func _test_blood_kit() -> void:
	var blood := VfxElementDef.named(&"blood")
	check(blood.impact and blood.piece and blood.claw and not blood.emissive, "blood: its kit is full (spurt, jet, claws), matter that doesn't shine")
	check(blood.claw.orient == VfxSheetDef.Orient.ROWS, "blood: the claws are drawn per direction, never rotated")
	check(blood.impact_mark > 0.0 and blood.mark.to_html(false) == blood.edge().to_html(false), "blood: a spurt leaves a stain in its darkest red")
	var claws := load("res://data/items/weapons/monster/claws.tres") as WeaponDef
	check(claws.element == blood and claws.attack_fx == null, "blood: Claws rake in blood (the spider, the racoons, the moles, the owl)")
	for id: String in ["spider", "thief_racoon", "gold_racoon", "owl", "mole", "stone_mole"]:
		var monster := load("res://data/monsters/%s.tres" % id) as MonsterDef
		check(monster.weapon == claws, "blood: the %s strikes with the blood claws" % id)
	var cry := (load("res://data/skills/player/battle_cry.tres") as SkillDef).effects[0] as BuffEffect
	check(cry.element == blood, "blood: Battle Cry bursts in blood, not a magic circle")
	check(MonsterDef.new().splat_color.to_html(false) == blood.edge().to_html(false), "blood: a monster bleeds the blood element's dark red")
	var ash := (load("res://src/vfx/ambient/blood_ash.tscn") as PackedScene).instantiate()
	check(ash is PixelMotes and (ash as PixelMotes).element == blood, "blood: the blood moon's ash falls on the grid in the blood ramp")
	ash.free()
	# Drinking blood shows it.
	var world_less := BloodDrainVfx.create(Vector2(10, 10), null, 3)
	check(world_less._drops.size() == 3, "blood: a drain throws its drops")
	world_less.free()


## Spirit: wisps, hollow rings, pale flames; ghosts' touch, wails, calls, wards and blinks are
## all spirit, and a wail shows on the body as a pale flicker, never as rime.
func _test_spirit_kit() -> void:
	var spirit := VfxElementDef.named(&"spirit")
	check(spirit.projectile and spirit.impact and spirit.piece and spirit.claw and spirit.slow_look == &"haunt", "spirit: its kit is full (wisp, ring, pale flame, spectral claws, a wailed look)")
	check(spirit.projectile.orient == VfxSheetDef.Orient.ROWS and spirit.projectile.directions == 16, "spirit: the wisp is drawn in 16 directions, its tail behind it")
	var look := StatusFx.LOOKS.look(&"haunt")
	check(look != null and look.element == spirit and look.crust == null and look.particle != null, "spirit: a wailed body flickers with pale flames, no rime")
	for path: String in ["res://data/skills/boss/wailing_ring.tres", "res://data/skills/boss/wailing_ring_fierce.tres"]:
		for effect in _effects_of(load(path)):
			check(effect.get("element") == spirit and effect.get("texture") == null, "spirit: %s is a ring of wisps, not cyan orbs" % path.get_file())
	for path: String in ["res://data/skills/boss/call_spirits.tres", "res://data/skills/boss/call_spirits_fierce.tres", "res://data/skills/monster/soul_ward.tres", "res://data/skills/monster/blink.tres", "res://data/skills/player/blink.tres"]:
		for effect in _effects_of(load(path)):
			check(effect.get("element") == spirit, "spirit: %s is spirit" % path.get_file())
	var touch := load("res://data/items/weapons/monster/spirit_touch.tres") as WeaponDef
	check(touch.element == spirit and touch.attack_fx == null, "spirit: the Lost Soul's Cold Touch is a spectral claw, not a warm one")
	var moth := load("res://data/monsters/soul_moth.tres") as MonsterDef
	check(moth.weapon.element == spirit and moth.weapon.projectile_texture == null and (moth.weapon.on_hit == null or moth.weapon.on_hit.burn_damage == 0), "spirit: the Soul Moth throws soul flames, not burning fireballs")
	# Burrowers dig: they don't blink like ghosts.
	for id: String in ["mole", "stone_mole"]:
		for skill in (load("res://data/monsters/%s.tres" % id) as MonsterDef).skills:
			for effect in skill.effects:
				check(effect.get("element") != spirit, "spirit: the %s burrows, it doesn't vanish like a ghost" % id)
## Fire: a full kit (a ball licking back in 16 directions, a burst, licks for novas and arcs, a
## burning claw, an explosion), and every fire user on it: no borrowed fireball.png, no white
## slash for the Flame Arc, no eye beam that is a fireball.
func _test_fire_kit() -> void:
	var fire := VfxElementDef.named(&"fire")
	check(fire.projectile and fire.impact and fire.piece and fire.claw and fire.blast and fire.impact_sound, "fire: its kit is full (shot, impact, licks, claw, explosion, sound)")
	check(fire.projectile.orient == VfxSheetDef.Orient.ROWS and fire.projectile.directions == 16, "fire: the fireball is drawn in 16 directions, its tail never rotated")
	for sheet: VfxSheetDef in [fire.projectile, fire.impact, fire.piece, fire.claw, fire.blast]:
		check(sheet.texture.resource_path.begins_with("res://assets/fx/fire/"), "fire: %s is fire's own art" % sheet.texture.resource_path.get_file())
	var look := StatusFx.LOOKS.look(&"burn")
	check(look.element == fire and look.particle.resource_path.begins_with("res://assets/fx/fire/") and look.burst.resource_path.begins_with("res://assets/fx/fire/"), "fire: a burning body throws the kit's flames")
	check(look.particle.get_width() == look.particle_frames * 8, "fire: the burn's flames are cut 8 wide (12 frames)")
	var shots: Array[String] = ["res://data/skills/player/fireball.tres", "res://data/skills/player/fire_wave.tres",
		"res://data/skills/boss/fire_ring.tres", "res://data/skills/boss/fire_ring_fierce.tres", "res://data/skills/boss/solar_flare.tres",
		"res://data/skills/boss/solar_flare_fierce.tres", "res://data/skills/boss/eye_beam.tres", "res://data/skills/boss/eye_beam_fierce.tres"]
	for path in shots:
		for effect in _effects_of(load(path)):
			var shot := effect as ProjectileEffect
			check(shot.element == fire and shot.texture == null, "fire: %s shoots fire, not a borrowed sprite" % path.get_file())
	var scroll := (load("res://data/items/consumables/fire_scroll.tres") as ConsumableDef).effects[0] as ProjectileEffect
	check(scroll.element == fire and scroll.texture == null, "fire: the Scroll of Fire shoots fire")
	for path: String in ["res://data/skills/boss/eye_beam.tres", "res://data/skills/boss/eye_beam_fierce.tres"]:
		for effect in _effects_of(load(path)):
			var ray := (effect as ProjectileEffect).sheet
			check(ray != null and ray.orient == VfxSheetDef.Orient.ROWS and ray.directions == 16 and ray.frame_size().x > fire.projectile.frame_size().x, "fire: the Demon Cyclops' eye shoots long rays drawn in 16 directions, not fireballs")
			if ray:
				_check_sheet(ray, "the eye beam's")
	for path: String in ["res://data/items/weapons/book.tres", "res://data/items/weapons/monster/fire_breath.tres", "res://data/items/weapons/monster/ghost_flame.tres"]:
		var weapon := load(path) as WeaponDef
		check(weapon.element == fire and weapon.projectile_texture == null, "fire: %s shoots fire" % path.get_file())
	var touch := load("res://data/items/weapons/monster/fire_touch.tres") as WeaponDef
	check(touch.element == fire and touch.attack_fx == null, "fire: the Flame Spirit strikes with a burning claw")
	for path: String in ["res://data/skills/boss/flame_arc.tres", "res://data/skills/boss/flame_arc_fierce.tres"]:
		for effect in _effects_of(load(path)):
			var area := effect as DamageAreaEffect
			check(area.element == fire and area.fx == null and area.fx_follow_aim, "fire: %s sweeps fire licks across its front, not a white slash" % path.get_file())
	check((load("res://data/perks/common/blazing_roll.tres") as PerkDef).passives[0].get("element") == fire, "fire: Blazing Roll leaves a ring of fire")
	for path: String in ["res://data/perks/common/ignite.tres", "res://data/perks/common/kindling.tres"]:
		check((load(path) as PerkDef).passives[0].get("element") == fire, "fire: %s is fire" % path.get_file())
	check((load("res://data/runes/ember.tres") as Resource).get("passives")[0].get("element") == fire, "fire: the Ember rune is fire")
	check((load("res://data/perks/synergies/inferno.tres") as SynergyDef).passives[0].get("blast_element") == fire, "fire: the Inferno synergy bursts in fire")
	for path: String in ["res://data/runes/pyre.tres", "res://data/affixes/of_embers.tres"]:
		check((load(path) as Resource).get("passives")[0].get("blast_element") == fire, "fire: %s bursts in fire" % path.get_file())
	# The dungeon's own flames are the kit's: the campfire, the flame vent, the brazier.
	check((load("res://data/hazards/campfire.tres") as HeatSourceDef).flames.resource_path.begins_with("res://assets/fx/fire/"), "fire: the campfire burns with the kit's flames")
	check((load("res://data/hazards/flame_vent.tres") as TrapDef).active_sheet.resource_path.begins_with("res://assets/fx/fire/"), "fire: the flame vent roars with the kit's column of fire")
	check((load("res://data/props/furniture/brazier.tres") as PropDef).flame.resource_path == "res://src/vfx/flame_vfx.tscn", "fire: a brazier burns with the kit's flames, not soft particles")
	# What only borrowed the fireball isn't fire: a spirit, moss, gold and sand shoot their own.
	var own := {"soul_moth": &"spirit", "moss_heart": &"poison", "gilded_moth": &"holy", "sand_drummer": &"earth"}
	for id: String in own:
		var weapon := (load("res://data/monsters/%s.tres" % id) as MonsterDef).weapon
		check(weapon.element == VfxElementDef.named(own[id]) and weapon.projectile_texture == null, "fire: the %s shoots %s, not fire" % [id, own[id]])
		check(weapon.on_hit == null or weapon.on_hit.burn_damage == 0, "fire: the %s doesn't set you burning" % id)


## Earth: rock spikes, a clod, the ground bursting in dust and rubble; its explosions are dust
## and chunks in its ramp, never fire bands; every earth user on it.
func _test_earth_kit() -> void:
	var earth := VfxElementDef.named(&"earth")
	var fire := VfxElementDef.named(&"fire")
	check(earth.projectile and earth.impact and earth.piece and earth.blast and not earth.emissive, "earth: its kit is full (a clod, an impact, spikes, the ground bursting), and it doesn't glow")
	for sheet: VfxSheetDef in [earth.projectile, earth.impact, earth.piece, earth.blast]:
		check(sheet.texture.resource_path.begins_with("res://assets/fx/earth/"), "earth: %s is earth's own art" % sheet.texture.resource_path.get_file())
	check(earth.blast.linger >= 0.5, "earth: the cracks of a burst stay a moment")
	check(earth.slow_look == &"", "earth: sand slows without frost's rime")
	# Explosion sheets are drawn in their own ramp: no fire band in the ground bursting.
	for element: VfxElementDef in [earth, fire]:
		var allowed: Array = Array(element.ramp).map(func(c: Color) -> String: return c.to_html(false))
		allowed.append(Color(element.residue, 1.0).to_html(false))
		var stray := {}
		var image := element.blast.texture.get_image()
		for y in image.get_height():
			for x in image.get_width():
				var c := image.get_pixel(x, y)
				if c.a > 0.0 and not allowed.has(c.to_html(false)):
					stray[c.to_html(false)] = true
		check(stray.is_empty(), "%s: its explosion sheet is drawn in its ramp only (%s)" % [element.id, ", ".join(stray.keys())])
	for color in earth.ramp:
		check(not fire.ramp.has(color), "earth: no step of its ramp is a fire color")
	for path: String in ["res://data/skills/boss/quake.tres", "res://data/skills/boss/quake_fierce.tres", "res://data/skills/player/sundering_blow.tres"]:
		for effect in _effects_of(load(path)):
			var area := effect as DamageAreaEffect
			check(area.explosive and area.element == earth, "earth: %s bursts the ground (earth), not a fireball" % path.get_file())
	for path: String in ["res://data/skills/player/rock_spike.tres", "res://data/skills/player/fissure.tres", "res://data/skills/player/ground_slam.tres"]:
		for effect in _effects_of(load(path)):
			var area := effect as DamageAreaEffect
			check(area.element == earth, "earth: %s is earth (its rock spikes painted in earth, not lava)" % path.get_file())
			if area.fx:
				var frame := VfxSheetDef.cell_size(area.fx, area.fx_frames)
				check(PixelDraw.sheet_scale(area.radius * 2.0 / maxi(frame.x, frame.y)) == 2.0, "earth: %s's spikes are drawn at the art's 2x" % path.get_file())
	var slam := _effects_of(load("res://data/skills/player/ground_slam.tres"))[0] as DamageAreaEffect
	check(slam.fx == null, "earth: Ground Slam is a ring of spikes composed at 2x, not one sheet at 4x")
	var breath := load("res://data/items/weapons/monster/sand_breath.tres") as WeaponDef
	check(breath.element == earth and breath.projectile_texture == null, "earth: Sand Breath throws clods of sand, no orange halo")
	for effect in _effects_of(load("res://data/skills/boss/sandstorm.tres")):
		var gust := effect as ProjectileEffect
		check(gust.element == earth and gust.texture != null and gust.texture.resource_path.begins_with("res://assets/fx/earth/"), "earth: Sandstorm blows whirls of sand")


## Physical: steel blows drawn on the grid in their element (steel when none), things in flight
## drawn in 16 directions, hits throwing what the target is made of.
func _test_physical_kit() -> void:
	var steel := VfxElementDef.named(&"physical")
	var swing := SwingVfx.create(Vector2.ZERO, Vector2(1, 1), 40.0, 110.0, false, null, 0.12)
	var look := swing.material as ShaderMaterial
	check(look.get_shader_parameter("core") == steel.core() and look.get_shader_parameter("body") == steel.shade(0.67), "physical: a plain blade swings a steel arc (the physical ramp), not a pale blue one")
	check(swing.rotation == 0.0 and is_equal_approx(float(look.get_shader_parameter("aim")), Vector2(1, 1).angle()), "physical: the arc's node is never turned: the shader points it on the world's grid")
	swing.free()
	var frost := VfxElementDef.named(&"frost")
	var icy := SwingVfx.create(Vector2.ZERO, Vector2.RIGHT, 40.0, 110.0, false, frost, 0.12)
	check((icy.material as ShaderMaterial).get_shader_parameter("core") == frost.core(), "physical: a blade with an element swings in its element's ramp")
	icy.free()
	for path: String in ["cleave", "whirlwind", "lash", "flurry", "piercing_thrust", "dash_strike"]:
		for effect in _effects_of(load("res://data/skills/player/%s.tres" % path)):
			check(effect.get("slash") != null and effect.get("fx") == null, "physical: %s draws a slash on the grid, not a sheet stretched 4-6x" % path)
	for path: String in ["club", "demon_club", "tengu_blade"]:
		var blow := load("res://data/items/weapons/monster/%s.tres" % path) as WeaponDef
		check(blow.slash != null and blow.attack_fx == null and blow.shows_arc(), "physical: the %s's blow is a slash on the grid, not a turned sheet" % path)
	var finisher := (load("res://data/skills/player/flurry.tres") as SkillDef).effects[2].get("slash") as SlashDef
	check(finisher.finisher == Vfx.CRIT_CROSS, "physical: Flurry ends on the cross that crits cut")
	_check_sheet(Vfx.CRIT_CROSS, "the crit cross")
	var bow := load("res://data/items/weapons/bow.tres") as WeaponDef
	var things := {"bow": bow.projectile_sheet}
	for path: String in ["volley", "kunai_fan", "spear_throw"]:
		things[path] = ((load("res://data/skills/player/%s.tres" % path) as SkillDef).effects[0] as ProjectileEffect).sheet
	for path: String in ["feather_storm", "feather_tempest", "feather_tempest_fierce"]:
		for effect in _effects_of(load("res://data/skills/boss/%s.tres" % path)):
			things[path] = (effect as ProjectileEffect).sheet
			check((effect as ProjectileEffect).texture == null, "physical: %s throws feathers, not shurikens" % path)
	for what: String in things:
		var sheet := things[what] as VfxSheetDef
		check(sheet != null and sheet.orient == VfxSheetDef.Orient.ROWS and sheet.directions == 16, "physical: %s's thing in flight is drawn in 16 directions, never turned" % what)
		if sheet:
			_check_sheet(sheet, what)
	for file in DirAccess.get_files_at("res://data/materials"):
		if file.ends_with(".tres"):
			var material := load("res://data/materials/" + file) as ImpactMaterialDef
			var bits := material.sparks_element()
			check(bits.ramp.size() >= 3 and not bits.emissive, "physical: a hit on %s throws its own bits (a ramp of its colors)" % material.display_name)
	var flesh := (load("res://data/materials/flesh.tres") as ImpactMaterialDef).sparks_element()
	var armor := (load("res://data/materials/armor.tres") as ImpactMaterialDef).sparks_element()
	check(flesh.bit == VfxElementDef.Bit.DROP and armor.bit != flesh.bit, "physical: flesh bleeds drops, armor throws sparks")


## Every particle scene is on the art's grid: whole even sizes in steps, no spin, stepped color
## ramps, the pixel_particles shader (which snaps them and dithers their fades), no texture.
func _test_particles() -> void:
	for dir: String in ["res://src/vfx/particles", "res://src/vfx/ambient"]:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".tscn"):
				continue
			var particles := (load(dir.path_join(file)) as PackedScene).instantiate() as CPUParticles2D
			if particles is PixelMotes:
				# Simulated and drawn by hand as whole art pixels on the grid (blood moon's ash).
				check((particles as PixelMotes).element != null, "particles: %s draws its motes on the grid in an element's ramp" % file)
				particles.free()
				continue
			var size := particles.scale_amount_min
			var whole := is_equal_approx(size, particles.scale_amount_max) and is_equal_approx(fposmod(size, 2.0), 0.0)
			if particles.scale_amount_curve:
				var curve := particles.scale_amount_curve
				for i in curve.point_count:
					var step := size * curve.get_point_position(i).y
					whole = whole and absf(step - roundf(step / 2.0) * 2.0) < 0.02
			check(whole, "particles: %s draws whole even sizes in steps" % file)
			check(particles.angular_velocity_min == 0.0 and particles.angular_velocity_max == 0.0, "particles: %s's pixel squares never spin" % file)
			check(particles.color_ramp != null and particles.color_ramp.interpolation_mode == Gradient.GRADIENT_INTERPOLATE_CONSTANT, "particles: %s steps down its ramp, no blend" % file)
			var shader := (particles.material as ShaderMaterial).shader if particles.material is ShaderMaterial else null
			check(shader != null and shader.resource_path.get_file().begins_with("pixel_particles") and particles.texture == null, "particles: %s snaps to the grid and dithers its fades" % file)
			particles.free()


## The props and overlays that drew smooth circles and arcs (mixels, alpha gradients) draw on
## the grid now (PixelDraw); the round touch buttons and the curse card's sigil too.
func _test_smooth_shapes() -> void:
	for path: String in ["res://src/entities/monster/monster_overlay.gd", "res://src/definitions/monster_traits/guard_trait.gd",
			"res://src/entities/hazards/heat_source.gd", "res://src/world/pact_room.gd", "res://src/game/threshold.gd",
			"res://src/entities/stairs/stairs.gd", "res://src/entities/stairs/hidden_way.gd", "res://src/entities/encounter/encounter.gd",
			"res://src/entities/pickup/item_pickup.gd", "res://src/entities/gold/gold_pickup.gd", "res://src/entities/hazards/chest.gd",
			"res://src/entities/forge/forge.gd", "res://src/entities/interactable.gd", "res://src/entities/merchant/merchant.gd",
			"res://src/entities/prop/prop.gd", "res://src/entities/hazards/quicksand.gd",
			"res://src/ui/controls/action_button.gd", "res://src/ui/curse_card/curse_card.gd"]:
		var source := FileAccess.get_file_as_string(path)
		var smooth := source.contains("draw_circle(") or source.contains("draw_arc(") or source.contains("draw_polyline(") or source.contains("draw_colored_polygon(")
		check(not smooth, "smooth shapes: %s draws on the art's grid (PixelDraw)" % path.get_file())


## The small effects the audit found off the grid (docs/vfx.md section 1): footprints, emotes,
## damage numbers, an arena's cell warning, splats and the plain beam now keep whole art
## pixels, never turn off the grid, fade by dithering (or, for text, in a few cuts) and take
## their colors from a ramp or the danger red.
func _test_grid_rule_breaks() -> void:
	var foot := FootprintVfx.create(Vector2(10.6, 7.3), Vector2(1, 1), Color(0, 0, 0, 0.2))
	check(foot.rotation == 0.0 and foot.position == PixelDraw.snap(foot.position), "grid: a footprint is never turned and stands on a whole art pixel (%s)" % foot.position)
	check(FootprintVfx.turned(Vector2.DOWN).has(Vector2i(0, 1)) and FootprintVfx.turned(Vector2.LEFT).has(Vector2i(-1, 0)), "grid: a footprint's sole is turned by whole cells, toward the step")
	foot.free()
	for i in 6:
		var number := FloatingText.create(Vector2(13.3, 9.9), "12", Color.WHITE)
		check(number.position == PixelDraw.snap(number.position), "grid: a damage number starts on a whole art pixel (%s)" % number.position)
		number.free()
	var beam := BeamVfx.create(Vector2(3.3, 5.1), Vector2(40.7, 9.2), Color(0.6, 1.0, 0.7))
	check(beam.position == PixelDraw.snap(beam.position), "grid: a plain beam starts on the grid")
	beam.free()
	var emote := EmoteVfx.create(load("res://icon.svg"), Vector2(5.5, 3.3))
	check(emote.position == PixelDraw.snap(emote.position), "grid: an emote stands on the grid")
	emote.free()
	for path: String in ["res://src/vfx/footprint_vfx.gd", "res://src/vfx/emote_vfx.gd", "res://src/vfx/cell_warning.gd", "res://src/vfx/splat_layer.gd", "res://src/vfx/beam_vfx.gd", "res://src/vfx/floating_text.gd"]:
		var source := FileAccess.get_file_as_string(path)
		var breaks := source.contains("rotation =") or source.contains(".a *=") or source.contains("lerpf(") or source.contains("draw_circle(") \
			or source.contains("Color(_color,") or source.contains("sin(_age")
		check(not breaks, "grid: %s turns, blends or fades in alpha nowhere" % path.get_file())
	check(FileAccess.get_file_as_string("res://src/vfx/cell_warning.gd").contains("TelegraphView.DANGER") and not FileAccess.get_file_as_string("res://src/vfx/cell_warning.gd").contains("Color(1"),
		"grid: an arena's cell warning is in the telegraphs' danger red, no color of its own")
	var warning := CellWarning.create([Vector2i(1, 1)] as Array[Vector2i], 32, 1.0)
	var states := {}
	for frame in 60:
		warning._age = frame / 60.0
		states[warning.is_lit()] = true
	check(states.size() == 2, "grid: the cell warning blinks on and off (no smooth pulse)")
	warning.free()


## Decision 0007: pack art is never drawn at a fractional scale (pixels of two sizes side by
## side). A rig's art stays at 2 through a hit (it drops one art pixel, no squash x1.25); a rank
## has no art scale (rim, aura and name show it); a prop's flame is a scene at its own size; a
## wyrm's wings fold by whole rows of their art and its tail turns by quarter turns; a plant
## leans by whole art pixels, row by row.
func _test_whole_scales() -> void:
	var rig := (load("res://src/entities/rig/actor_rig.tscn") as PackedScene).instantiate() as ActorRig
	add_child(rig)
	rig.setup(load("res://data/visuals/monsters/bat.tres") as SpriteFrames, Vector2.ZERO)
	rig.play_hurt()
	rig._process(0.016)
	check(rig.visual.scale == Vector2(2, 2) and rig.squash_node.scale == Vector2.ONE and rig.visual.position == Vector2(0, PixelDraw.PX),
		"whole scales: a hit drops the body one art pixel, its art kept at scale 2 (Visual %s, Squash %s)" % [rig.visual.scale, rig.squash_node.scale])
	rig._process(ActorRig.FLINCH_TIME)
	check(rig.visual.position == Vector2.ZERO and rig.squash_node.scale == Vector2.ONE, "whole scales: the flinch over, the body is back on its feet")
	rig.free()
	for file in DirAccess.get_files_at("res://data/monster_ranks"):
		var rank := load("res://data/monster_ranks".path_join(file)) as MonsterRankDef
		if rank:
			check(rank.get("scale") == null and rank.radius_multiplier >= 1.0, "whole scales: rank %s has no art scale, only a wider body" % rank.id)
	var props := 0
	for path in _resources_under("res://data/props"):
		var prop := load(path) as PropDef
		if prop == null:
			continue
		props += 1
		check(prop.get("flame_scale") == null, "whole scales: %s has no flame scale" % prop.id)
		if prop.flame:
			var flame := prop.flame.instantiate()
			var odd: Array[String] = []
			for node: Node in [flame] + flame.find_children("*", "Node2D", true, false):
				var scale := (node as Node2D).scale if node is Node2D else Vector2.ONE
				if not is_equal_approx(scale.x, roundf(scale.x)) or not is_equal_approx(scale.y, roundf(scale.y)) or absf(scale.x) < 1.0 or absf(scale.y) < 1.0:
					odd.append("%s %s" % [node.name, scale])
			check(odd.is_empty(), "whole scales: %s's flame is drawn at its own size, never scaled (%s)" % [prop.id, odd])
			flame.free()
	check(props >= 10, "whole scales: every prop checked (%d)" % props)
	var turns := {}
	for i in 32:
		var turn := WyrmBody.tail_turn(Vector2.ZERO, Vector2.from_angle(TAU * i / 32.0))
		turns[snappedf(fposmod(turn, TAU), 0.001)] = true
		check(is_equal_approx(fposmod(turn, PI * 0.5), 0.0) or is_equal_approx(fposmod(turn, PI * 0.5), PI * 0.5), "whole scales: the wyrm's tail turns by quarter turns only (%s)" % turn)
	check(turns.size() == 4, "whole scales: the tail points four ways")
	var rows_ok := true
	for shown in range(34, 58):
		var last := -1
		for row in shown:
			var source := WyrmBody._wing_row(row, shown, 57)
			rows_ok = rows_ok and source > last and source < 57
			last = source
	check(rows_ok, "whole scales: a folded wing shows whole rows of its art, in order, none twice")
	var shifts := PackedInt32Array()
	for row in 16:
		shifts.append(DecorLayer.row_shift(row, 16, 0.55))
	check(shifts[0] == -9 and shifts[15] == 0, "whole scales: a plant bent hard moves its top row 9 art pixels, its foot none (%s)" % shifts)
	var monotonic := true
	for row in 15:
		monotonic = monotonic and shifts[row] <= shifts[row + 1]
	check(monotonic, "whole scales: each row of a leaning plant moves less than the one above it")


## Decision 0009: a dungeon theme's tint is a neutral dim (every channel 0.75 or more, within
## 0.12 of each other: a multiply turns the pack's colours to mud), and with any floor's screen
## grading (AmbienceDef) a mid-tone keeps every channel at 0.6 or more. Only the places the
## decision lists may go further, flagged in their data (`narrative_exception`): the Threshold,
## the Deeps, the Well's Bottom, the Blood Moon and the curses.
func _test_world_tints() -> void:
	var listed: Array[String] = ["res://data/threshold/limbo_theme.tres", "res://data/abyss/abyss_theme.tres",
		"res://data/dungeon/themes/well_bottom.tres", "res://data/threshold/limbo_ambience.tres",
		"res://data/abyss/abyss_ambience.tres", "res://data/dungeon/ambience/blood_moon.tres"]
	for path in _resources_under("res://data/curses"):
		var curse := load(path) as CurseDef
		if curse and curse.ambience:
			listed.append(curse.ambience.resource_path)
	var themes: Array[DungeonTheme] = []
	var moods: Array[AmbienceDef] = []
	for dir: String in ["res://data/dungeon", "res://data/abyss", "res://data/threshold"]:
		for path in _resources_under(dir):
			var resource := load(path)
			if resource is DungeonTheme:
				themes.append(resource)
			elif resource is AmbienceDef:
				moods.append(resource)
	check(themes.size() >= 13 and moods.size() >= 15, "tints: every theme and mood checked (%d, %d)" % [themes.size(), moods.size()])
	for theme in themes:
		if theme.narrative_exception:
			check(listed.has(theme.resource_path), "tints: %s is no exception decision 0009 lists" % theme.resource_path)
			continue
		var low := minf(theme.tint.r, minf(theme.tint.g, theme.tint.b))
		var high := maxf(theme.tint.r, maxf(theme.tint.g, theme.tint.b))
		check(low >= 0.75 and high - low <= 0.12, "tints: %s dims the floor neutrally, its biome shown by its tiles and light (%s)" % [theme.resource_path.get_file(), theme.tint])
	var dull: Array[String] = []
	for mood in moods:
		if mood.narrative_exception:
			check(listed.has(mood.resource_path), "tints: %s is no exception decision 0009 lists" % mood.resource_path)
			continue
		for theme in themes:
			if theme.narrative_exception:
				continue
			for mid: float in [0.25, 0.35, 0.5]:
				var graded := _graded(Color(mid, mid, mid) * theme.tint, mood)
				var lowest := minf(graded.r, minf(graded.g, graded.b)) / mid
				if lowest < 0.6:
					dull.append("%s x %s at %.2f: %.2f" % [theme.resource_path.get_file(), mood.resource_path.get_file(), mid, lowest])
	check(dull.is_empty(), "tints: a theme's tint and a floor's grading together keep a mid-tone's every channel at 0.6 or more (%s)" % [dull])


## `color` after the screen's grading by `mood` (screen.gdshader: shadows and highlights pulled
## toward two tints by the grade's strength).
static func _graded(color: Color, mood: AmbienceDef) -> Color:
	var gray := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	var t := clampf((gray - 0.12) / (0.7 - 0.12), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var tint := mood.grade_shadows.lerp(mood.grade_highlights, t)
	var strength := mood.grade_strength
	return Color(color.r * lerpf(1.0, tint.r, strength), color.g * lerpf(1.0, tint.g, strength), color.b * lerpf(1.0, tint.b, strength))


## Every .tres under `dir` and its subfolders.
func _resources_under(dir: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tres"):
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_resources_under(dir.path_join(sub)))
	return found


## One source for the interface's colors (UiSkin; gold is Palette.GOLD): no panel keeps its own
## gold, good or bad, nor the windows' dim backdrop.
func _test_one_ui_palette() -> void:
	check(UiSkin.GOLD == Palette.GOLD, "ui colors: UiSkin's gold is the Palette's")
	var copies: Array[String] = []
	for path in _scripts_under("res://src/ui"):
		var source := FileAccess.get_file_as_string(path)
		for copy in ["0.82, 0.4", "const GOOD", "const BAD", "Color(0.03, 0.02, 0.05"]:
			if source.contains(copy) and not path.ends_with("ui_skin.gd"):
				copies.append("%s (%s)" % [path.get_file(), copy])
	check(copies.is_empty(), "ui colors: gold, good, bad and the backdrop come from UiSkin only: %s" % ", ".join(copies))


func _scripts_under(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_scripts_under(folder.path_join(sub)))
	return found


## The balance tools simulate fights with nothing to see (Vfx.shown off): only what is seen is
## left out, never what a rule or a bot reads; the game and the tests always show everything.
func _test_simulation() -> void:
	check(Vfx.shown, "vfx: effects are shown in the game and the tests (only the balance tools turn them off)")
	var number := FloatingText.create(Vector2.ZERO, "7", Color.WHITE)
	check(Vfx.is_cosmetic(number), "vfx: a floating number is only seen (a simulation leaves it out)")
	number.free()
	var warning := CellWarning.new()
	check(not Vfx.is_cosmetic(warning), "vfx: an arena's cell warning is read (by the bots): a simulation keeps it")
	warning.free()


## A monster's shots and dashes warn before they come: the lanes of its shots, the line of its
## dash (an area keeps its circle).
func _test_telegraphs() -> void:
	var view := TelegraphView.new()
	for path: String in ["frost_breath", "poison_spit", "venom_spit", "eye_beam", "fire_ring", "solar_flare", "wailing_ring", "slime_storm", "feather_storm", "coin_storm", "coil_rush", "frog_leap", "hoard_leap"]:
		var skill := load("res://data/skills/boss/%s.tres" % path) as SkillDef
		check(view.show_skill(skill, 0.3, 0.5, 12.0) and view.visible, "telegraphs: %s warns before it comes" % path)
	view.show_skill(load("res://data/skills/boss/wailing_ring.tres"), 0.0, 0.5, 12.0)
	check(int((view.material as ShaderMaterial).get_shader_parameter("shape")) == TelegraphView.Shape.LANES, "telegraphs: a ring of shots shows its lanes (the gaps read)")
	check(view.show_skill(load("res://data/skills/monster/charge.tres"), 0.0, 0.5) and int((view.material as ShaderMaterial).get_shader_parameter("shape")) == TelegraphView.Shape.LINE, "telegraphs: a charge shows its line")
	check(not view.show_skill(load("res://data/skills/boss/call_skeletons.tres"), 0.0, 0.5), "telegraphs: a summon has nothing to warn about")
	check(view.rotation == 0.0, "telegraphs: the warning's node is never turned (its pixels stay on the world's grid)")
	view.free()


## Layers (docs/vfx.md): flat things under the actors, upright ones sorted with them by their
## base, things in the air over them. Every element's nova piece lies on the floor or stands on
## it; shots, impacts and claws fly.
func _test_layers() -> void:
	for element in VfxElementDef.all():
		if element.piece:
			check(element.piece.layer != VfxLayer.Layer.AIR, "layers: %s's nova piece is on the floor (GROUND or STANDING), not over the actors" % element.id)
		for sheet: VfxSheetDef in [element.projectile, element.impact, element.claw]:
			if sheet:
				check(sheet.layer == VfxLayer.Layer.AIR, "layers: %s's shots, impacts and claws are in the air" % element.id)
	check(VfxElementDef.named(&"frost").piece.layer == VfxLayer.Layer.STANDING, "layers: ice crystals stand among the actors")
	check(VfxElementDef.named(&"storm").piece.layer == VfxLayer.Layer.GROUND, "layers: storm's crackles lie under the actors")
	check(VfxElementDef.named(&"earth").blast.layer == VfxLayer.Layer.STANDING, "layers: the ground bursting stands among the actors, sorted by its base")
	check((load("res://data/skills/player/shadow_step.tres") as SkillDef).effects[1].get("sheet") == load("res://data/vfx/sheets/kunai.tres"), "physical: Shadow Step's kunai is drawn in 16 directions too")
	check(Vfx.SIGIL.layer == VfxLayer.Layer.GROUND, "layers: the sigil of heals and buffs lies under whoever stands in it")
	for path: String in ["smite", "thunder"]:
		var strike := ((load("res://data/skills/player/%s.tres" % path) as SkillDef).effects[0] as DamageAreaEffect).strike
		check(strike.layer == VfxLayer.Layer.STANDING, "layers: %s's strike stands among the actors" % path)
	# Ground under the actors (z 0), air over them and the floor's light.
	var ring := RingVfx.create(Vector2.ZERO, 40.0, Color.RED)
	check(ring.z_index < 0 and not ring.z_as_relative, "layers: a ring on the floor is under every actor")
	ring.free()
	var sigil := SheetVfx.play(Vfx.SIGIL, Vector2(10, 10))
	check(sigil.z_index < 0 and VfxLayer.of(sigil) == VfxLayer.Layer.GROUND, "layers: the sigil is drawn under every actor")
	sigil.free()
	var telegraph := TelegraphView.new()
	check(telegraph.z_index < 0 and not telegraph.z_as_relative, "layers: a monster's warning lies under every actor")
	telegraph.free()
	var impact := SheetVfx.play(VfxElementDef.named(&"frost").impact, Vector2.ZERO)
	check(impact.z_index > LightField.Z, "layers: an impact is over the actors and the floor's light")
	impact.free()
	var column := ((load("res://data/skills/player/smite.tres") as SkillDef).effects[0] as DamageAreaEffect).strike
	var standing := SheetVfx.play(column, Vector2(20, 40))
	check(VfxLayer.of(standing) == VfxLayer.Layer.STANDING and standing.z_index == 0 and standing.y_sort_enabled, "layers: a standing sheet sorts with the actors")
	check(is_equal_approx(standing.position.y, PixelDraw.snap(Vector2(20, 40)).y + roundf(column.base_offset() / PixelDraw.PX) * PixelDraw.PX), "layers: a standing sheet sorts by its base (the bottom of its frame)")
	standing.free()
	var nova := ComposedVfx.ring(Vector2.ZERO, 80.0, VfxElementDef.named(&"frost"))
	var pieces := nova.get_children().filter(func(n: Node) -> bool: return n is ComposedVfx.StandingPiece)
	check(VfxLayer.of(nova) == VfxLayer.Layer.STANDING and nova.z_index < 0 and pieces.size() >= 5, "layers: a Frost Nova's crystals are pieces among the actors, its edge and mist under them")
	var sorted := true
	for piece: Node2D in pieces:
		sorted = sorted and piece.z_index == 0 and not piece.z_as_relative and piece.y_sort_enabled
	check(sorted, "layers: each crystal sorts with the actors by its base")
	nova.free()


## The hero's own effects never hide him (docs/vfx.md 2b): toward the north they start behind
## his body, toward us in front; a thrust starts at his hand; what is attached to him (a halo, a
## column of light, his weapon's glow) sits behind his body. (In the game: CombatTests.)
func _test_own_effects() -> void:
	check(VfxLayer.goes_behind(Vector2.UP) and VfxLayer.goes_behind(Vector2(0.7, -0.7)), "own effects: north and north-east go behind the body")
	check(not VfxLayer.goes_behind(Vector2.DOWN) and not VfxLayer.goes_behind(Vector2.RIGHT) and not VfxLayer.goes_behind(Vector2(-0.7, 0.7)), "own effects: east, west and the south half go in front")
	var look := load("res://data/vfx/slashes/blade.tres") as SlashDef
	for case: Array in [[Vector2.UP, false, VfxLayer.Layer.STANDING], [Vector2(-0.7, -0.7), false, VfxLayer.Layer.STANDING], [Vector2.DOWN, false, VfxLayer.Layer.AIR], [Vector2.RIGHT, false, VfxLayer.Layer.AIR], [Vector2.UP, true, VfxLayer.Layer.AIR]]:
		var swing := SwingVfx._make(look, Vector2(0, -6), case[0], 40.0, null, case[1], 0)
		check(VfxLayer.of(swing) == case[2], "own effects: a %s blow toward %s is %s" % ["monster's" if case[1] else "hero's", case[0], VfxLayer.Layer.keys()[case[2]]])
		swing.free()
	var thrust := SwingVfx.create(Vector2.ZERO, Vector2.RIGHT, 70.0, 40.0, true, null, 0.12)
	check(float(thrust.material.get_shader_parameter("inner")) >= 10.0, "own effects: a thrust's streak starts at the hand, clear of the body")
	thrust.free()
	# Behind is the body's children's order (an actor draws nothing itself: its sprites are its
	# Rig, a sibling): show_behind_parent would leave it over the Rig.
	var body := Node2D.new()
	var rig := ActorRig.new()
	body.add_child(Node2D.new())
	body.add_child(rig)
	body.add_child(Node2D.new())
	var halo := SheetVfx.play(load("res://data/vfx/sheets/holy_sigil.tres"), Vector2.ZERO)
	VfxLayer.on_body(body, halo, true)
	check(halo.get_parent() == body and halo.get_index() < rig.get_index() and VfxLayer.is_behind_body(halo) and halo.z_as_relative and halo.z_index == 0, "own effects: an effect on the hero's body is drawn before his sprites (behind him), sorted with him")
	var glow := Node2D.new()
	VfxLayer.on_body(body, glow, false)
	check(glow.get_index() > rig.get_index() and not VfxLayer.is_behind_body(glow), "own effects: one in front is drawn after his sprites")
	VfxLayer.set_behind(glow, true)
	check(VfxLayer.is_behind_body(glow), "own effects: and moves behind them when he turns north")
	body.free()


## Elemental attacks (docs/vfx.md 11): every element but steel breaks a blow's edge into its own
## matter (never steel's 0) and sheds its bits; steel and no element shed nothing; the main
## elements each have their own matter; a second element adds fewer bits than the first.
func _test_elemental_swings() -> void:
	var physical := VfxElementDef.named(&"physical")
	check(SwingVfx.matter_of(null) == 0 and SwingVfx.matter_of(physical) == 0, "elemental: steel's blow is plain steel")
	check(SwingMatter.create(Vector2.ZERO, Vector2.RIGHT, 40.0, 16.0, 2.0, false, 0.0, 0.12, 0.0, physical) == null, "elemental: steel sheds nothing")
	var seen := {}
	for element in VfxElementDef.all():
		if element.id == &"physical":
			continue
		check(SwingVfx.matter_of(element) != 0, "elemental: %s's blow breaks into its matter" % element.id)
		var matter := SwingMatter.create(Vector2.ZERO, Vector2.RIGHT, 40.0, 16.0, 2.0, false, 0.0, 0.12, 0.0, element)
		check(matter != null and matter.bit_count(element) >= 3, "elemental: %s's blow sheds its bits" % element.id)
		if matter:
			matter.free()
		seen[SwingVfx.matter_of(element)] = true
	for id: StringName in [&"fire", &"frost", &"poison", &"storm", &"holy", &"shadow", &"arcane", &"blood", &"earth"]:
		check(seen.has(SwingVfx.matter_of(VfxElementDef.named(id))), "elemental: %s has a matter" % id)
	var mattered := {}
	for id: StringName in [&"fire", &"frost", &"poison", &"storm", &"holy", &"arcane"]:
		mattered[SwingVfx.matter_of(VfxElementDef.named(id))] = id
	check(mattered.size() == 6, "elemental: fire, frost, poison, storm, holy and arcane each break in their own way")
	var fire := VfxElementDef.named(&"fire")
	var frost := VfxElementDef.named(&"frost")
	var both := SwingMatter.create(Vector2.ZERO, Vector2.RIGHT, 40.0, 16.0, 2.0, false, 0.0, 0.12, 0.0, fire, frost)
	check(both.bit_count(fire) > both.bit_count(frost) and both.bit_count(frost) > 0, "elemental: a second element adds fewer bits than the first")
	both.free()
	var swing := SwingVfx.create(Vector2.ZERO, Vector2.RIGHT, 40.0, 110.0, false, fire, 0.12, false, frost)
	check(swing.matter != null and int(swing.material.get_shader_parameter("matter")) == SwingVfx.matter_of(fire) and bool(swing.material.get_shader_parameter("emissive")), "elemental: a fire arc is drawn in fire's matter, shining")
	swing.free()
	var plain := SwingVfx.create(Vector2.ZERO, Vector2.RIGHT, 40.0, 110.0, false, null, 0.12)
	check(plain.matter == null and int(plain.material.get_shader_parameter("matter")) == 0 and not bool(plain.material.get_shader_parameter("emissive")), "elemental: a plain arc is steel, nothing shed")
	plain.free()


## Shaders on bodies (docs/vfx.md): every element has a death look, the statuses each paint
## the body in their element's ramp through the rig's one material and stop when they end,
## fewer effects turns them off, a storm hit crackles a few frames.
func _test_body_shader() -> void:
	var styles := {}
	for element in VfxElementDef.all():
		check(element.death != null, "body shader: %s has a death look (VfxElementDef.death)" % element.id)
		if element.death:
			styles[element.death.style] = true
			check(element.death.duration > 0.0 and element.death.duration <= 1.0, "body shader: %s's death is over within a second" % element.id)
	check(styles.size() == DeathLookDef.Style.size(), "body shader: every death style is someone's (%d of %d)" % [styles.size(), DeathLookDef.Style.size()])
	check(DeathLookDef.of(null) == VfxElementDef.named(&"physical").death and DeathLookDef.of(null).style == DeathLookDef.Style.DISSOLVE, "body shader: a plain blow dissolves the body as before")
	check(DeathLookDef.of(VfxElementDef.named(&"fire")).style == DeathLookDef.Style.ASH and DeathLookDef.of(VfxElementDef.named(&"frost")).shards, "body shader: fire burns to ash, frost shatters")
	check(DeathLookDef.of(VfxElementDef.named(&"poison")).mark > 0.0, "body shader: poison melts into a puddle")
	check(VfxElementDef.named(&"storm").crackles and not VfxElementDef.named(&"fire").crackles, "body shader: storm crackles over the bodies it hits")
	for id: StringName in [&"burn", &"slow", &"poison", &"haunt"]:
		var status_look := StatusFx.LOOKS.look(id)
		check(status_look != null and status_look.body != StatusLookDef.Body.NONE, "body shader: %s paints the body" % id)
	# The shader parses, with the uniforms BodyLook drives (a parse error leaves none).
	var shader: Shader = load("res://assets/shaders/flash.gdshader")
	var uniforms := shader.get_shader_uniform_list().map(func(u: Dictionary) -> String: return u.name)
	for param_name: String in ["flash_amount", "dissolve", "ramps", "frame_rect", "burn", "chill", "frozen", "poison", "poison_wave", "haunt", "crackle", "outline_color", "death_style", "death_row"]:
		check(uniforms.has(param_name), "body shader: the rig shader has its %s uniform" % param_name)
	# The ramps: a row per element, each step an exact color of its ramp.
	var ramps := BodyLook.ramps().get_image()
	var exact := true
	for element in VfxElementDef.all():
		var row := BodyLook.row(element)
		for x in BodyLook.STEPS:
			exact = exact and ramps.get_pixel(x, row).to_html(false) == element.shade(float(x) / (BodyLook.STEPS - 1)).to_html(false)
	check(exact, "body shader: the ramp texture holds every element's steps, exactly")
	# Statuses set their uniforms and clear them.
	var material := ShaderMaterial.new()
	material.shader = shader
	var look := BodyLook.new(material)
	var statuses := StatusSet.new()
	statuses.apply_dot(&"burn", 1, 0.5, 3.0, null, Palette.FIRE)
	look.show_statuses(statuses, 0.3, true)
	check(float(material.get_shader_parameter("burn")) > 0.0 and int(material.get_shader_parameter("burn_row")) == BodyLook.row(VfxElementDef.named(&"fire")), "body shader: a burn paints the body in fire")
	check(statuses._dots[0].element == VfxElementDef.named(&"fire"), "body shader: a burn's ticks are fire (burnt to death: ash)")
	statuses.apply_slow(0.3, 3.0)
	look.show_statuses(statuses, 0.1, true)
	check(float(material.get_shader_parameter("chill")) > 0.0 and float(material.get_shader_parameter("frozen")) == 0.0, "body shader: a chill grows rime, a light one doesn't freeze")
	statuses.apply_slow(0.7, 3.0, &"freeze")
	look.show_statuses(statuses, 0.1, true)
	check(float(material.get_shader_parameter("frozen")) == 1.0, "body shader: a heavy chill freezes the body over")
	look.show_statuses(statuses, 0.1, false)
	check(float(material.get_shader_parameter("burn")) == 0.0 and float(material.get_shader_parameter("chill")) == 0.0, "body shader: fewer effects turns the statuses off")
	statuses.clear()
	statuses.apply_dot(&"poison", 1, 1.0, 3.0, null, Palette.FIRE)
	look.show_statuses(statuses, 0.1, true)
	check(float(material.get_shader_parameter("poison")) == 1.0 and float(material.get_shader_parameter("poison_wave")) <= 1.0, "body shader: poison takes hold with a wave up the body")
	statuses.clear()
	look.show_statuses(statuses, 0.1, true)
	var off := true
	for param_name: String in ["burn", "chill", "frozen", "poison", "haunt", "crackle"]:
		off = off and float(material.get_shader_parameter(param_name)) == 0.0
	check(off, "body shader: statuses gone, the body is itself again")
	statuses.apply_slow(0.3, 3.0, &"hit", VfxElementDef.named(&"spirit"))
	look.show_statuses(statuses, 0.1, true)
	check(float(material.get_shader_parameter("haunt")) == 1.0 and float(material.get_shader_parameter("chill")) == 0.0, "body shader: a wail haunts, it doesn't freeze")
	statuses.clear()
	look.hit(VfxElementDef.named(&"storm"))
	look.show_statuses(statuses, 0.016, true)
	var crackled := float(material.get_shader_parameter("crackle")) == 1.0
	for i in BodyLook.CRACKLE.size():
		look.show_statuses(statuses, 0.016, true)
	check(crackled and float(material.get_shader_parameter("crackle")) == 0.0, "body shader: a storm hit crackles a few frames, then stops")
	look.hit(VfxElementDef.named(&"fire"))
	look.show_statuses(statuses, 0.016, true)
	check(float(material.get_shader_parameter("crackle")) == 0.0, "body shader: a fire hit doesn't crackle")
	look.die(DeathLookDef.of(VfxElementDef.named(&"holy")), VfxElementDef.named(&"holy"))
	check(int(material.get_shader_parameter("death_style")) == DeathLookDef.Style.ASCEND and int(material.get_shader_parameter("death_row")) == BodyLook.row(VfxElementDef.named(&"holy")), "body shader: a holy death lifts the body away in holy's ramp")
## The light, space and screen shaders (docs/vfx.md, "Shaders"): every shader compiles, one
## alone reads the screen (one copy of it a frame), the elements bend space and glow as they
## should, sheets get their look, fewer effects drops the heavy passes, flashes are capped.
func _test_shaders() -> void:
	var readers: Array[String] = []
	for dir: String in ["res://assets/shaders", "res://src"]:
		for path in _shader_files(dir):
			var shader := load(path) as Shader
			# A shader that fails to compile lists no uniforms (all of ours have some).
			check(shader != null and not shader.get_shader_uniform_list().is_empty(), "shaders: %s compiles" % path.get_file())
			if FileAccess.get_file_as_string(path).contains("hint_screen_texture"):
				readers.append(path.get_file())
	check(readers.size() == 1 and readers[0] == "screen.gdshader", "shaders: only the screen pass reads the screen, one copy a frame (%s)" % ", ".join(readers))
	for shader in ShaderWarmup.shaders():
		check(shader.get_shader_uniform_list().size() > 0, "shaders: %s is warmed at load" % shader.resource_path.get_file())
	check(ShaderWarmup.shaders().has(FxLook.FLAME) and ShaderWarmup.shaders().has(FxLook.RUNE) and ShaderWarmup.shaders().has(FxLook.GAS), "shaders: every new effect shader is warmed at load")
	# Space: each element bends it its own way.
	var kinds := { &"fire": VfxElementDef.Distortion.HEAT, &"frost": VfxElementDef.Distortion.COLD, &"shadow": VfxElementDef.Distortion.PULL, &"arcane": VfxElementDef.Distortion.PULL, &"earth": VfxElementDef.Distortion.NONE }
	for id: StringName in kinds:
		check(VfxElementDef.named(id).distortion == kinds[id], "shaders: %s bends space as it should" % id)
	var host := Node2D.new()
	var heat := DistortionStamp.of_element(host, VfxElementDef.named(&"fire"), 20.0)
	check(heat != null and heat.kind == DistortionStamp.Kind.HEAT, "shaders: fire's heat is a stamp of the one screen pass")
	check(DistortionStamp.of_element(host, VfxElementDef.named(&"earth"), 20.0) == null, "shaders: earth bends nothing")
	var fewer := Settings.fewer_effects
	Settings.fewer_effects = true
	check(DistortionStamp.of_element(host, VfxElementDef.named(&"frost"), 20.0) == null, "shaders: fewer effects, no cold shimmer")
	check(DistortionStamp.attach(host, DistortionStamp.Kind.SHOCK, 40.0, 2.0) != null, "shaders: fewer effects keeps a blast's shockwave")
	Settings.fewer_effects = fewer
	var shock := ShockwaveVfx.create(Vector2.ZERO, 80.0)
	check(shock.material == null and shock.get_children().any(func(n: Node) -> bool: return n is DistortionStamp and n.kind == DistortionStamp.Kind.SHOCK), "shaders: a shockwave is a stamp, not a screen-reading node")
	shock.free()
	# Light: a halo around what shines, one light per glow.
	check(GlowHalo.attach(host, VfxElementDef.named(&"earth"), 6.0) == null, "glow: matter has no halo")
	var halo := GlowHalo.attach(host, VfxElementDef.named(&"fire"), 6.0, Vector2.ZERO, GlowHalo.Pulse.BREATHE, 10)
	check(halo != null, "glow: fire has a halo")
	GlowHalo.attach(host, VfxElementDef.named(&"fire"), 6.0, Vector2.ZERO, GlowHalo.Pulse.BREATHE, 10)
	check(host.get_children().filter(func(n: Node) -> bool: return n is LightSource).size() == 1, "glow: a second glow on the same effect lights nothing twice")
	host.free()
	# Looks: each sheet its shader, the emissive mask for what shines.
	var sigil := FxLook.for_sheet(Vfx.SIGIL, VfxElementDef.named(&"holy"))
	check(sigil.shader == FxLook.RUNE and sigil.get_shader_parameter("emissive") == true, "looks: the sigil draws itself (rune) and keeps its colors (emissive mask)")
	check(VfxElementDef.named(&"arcane").piece.look == VfxSheetDef.Look.RUNE and VfxElementDef.named(&"arcane").piece.glyph, "looks: arcane glyphs draw themselves top-down")
	check(FxLook.for_piece(VfxElementDef.named(&"poison").piece, VfxElementDef.named(&"poison")).shader == FxLook.GAS, "looks: poison clouds are gas (churning, see-through, a glowing rim)")
	var smite := ((load("res://data/skills/player/smite.tres") as SkillDef).effects[0] as DamageAreaEffect).strike
	check(FxLook.for_sheet(smite, VfxElementDef.named(&"holy")).shader == FxLook.SHIMMER and smite.halo > 0.0, "looks: Smite's column shimmers and glows at its foot")
	var bolt := ((load("res://data/skills/player/thunder.tres") as SkillDef).effects[0] as DamageAreaEffect).strike
	check(not bolt.flash_frames.is_empty() and bolt.halo > 0.0, "looks: Thunder's bolt flashes the screen and glows where it strikes")
	check(FxLook.for_sheet(VfxElementDef.named(&"earth").impact, VfxElementDef.named(&"earth")).get_shader_parameter("emissive") == false, "looks: matter is graded with the floor (no emissive mask)")
	check(FxLook.for_sheet(VfxElementDef.named(&"frost").impact, VfxElementDef.named(&"frost")).get_shader_parameter("emissive") == true, "looks: frost keeps its cyan in a warm biome (emissive mask)")
	check(FxLook.flame().shader == FxLook.FLAME and FxLook.five(VfxElementDef.named(&"fire")).size() == 5, "looks: flames lick in fire's ramp")
	# Flashes: at most 3 a second, never when turned off.
	var screen := ScreenEffects.new()
	var look := ShaderMaterial.new()
	look.shader = load("res://assets/shaders/screen.gdshader")
	screen.material = look
	var flashes := Settings.screen_flashes
	Settings.screen_flashes = true
	check(screen.flash(Color.WHITE) and screen.is_flashing(), "flash: lightning lights the screen")
	check(not screen.flash(Color.WHITE), "flash: never more than 3 a second")
	Settings.screen_flashes = false
	screen._last_flash_ms = -100000
	check(not screen.flash(Color.WHITE), "flash: none when the player turned flashes off")
	Settings.screen_flashes = flashes
	screen.free()


static func _shader_files(dir: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gdshader"):
			found.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_shader_files(dir.path_join(sub)))
	return found


# --- Helpers -------------------------------------------------------------------

var _cache: Array[Resource] = []


func _all_resources() -> Array[Resource]:
	if _cache.is_empty():
		for dir in DATA_DIRS:
			_collect(dir)
	return _cache


func _collect(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(sub))
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tres"):
			var resource := load(dir.path_join(file))
			if resource:
				_cache.append(resource)


## The effects of a skill (and of a perk's skill-like passives: none here).
func _effects_of(resource: Resource) -> Array:
	if resource is SkillDef:
		return (resource as SkillDef).effects.filter(func(e: Effect) -> bool: return e != null)
	if resource is ChargedAttackDef:
		return (resource as ChargedAttackDef).effects.filter(func(e: Effect) -> bool: return e != null)
	return []


## The OnHitStatus of a skill's effects or a weapon.
func _statuses(resource: Resource) -> Array[OnHitStatus]:
	var found: Array[OnHitStatus] = []
	if resource is WeaponDef and (resource as WeaponDef).on_hit:
		found.append((resource as WeaponDef).on_hit)
	for effect in _effects_of(resource):
		var status: OnHitStatus = effect.get("status")
		if status:
			found.append(status)
	return found


## In a Godot 4 canvas shader the fragment's COLOR already holds the texture's color: a texture
## read multiplied by COLOR squares every color (the bodies were drawn far darker than their art
## until the rig's shader took its tint from vertex() instead). No shader may do it again.
func _test_no_squared_colors() -> void:
	var regex := RegEx.create_from_string("texture\\(\\s*TEXTURE[^;]*\\)\\s*\\*\\s*COLOR\\b")
	var scanned := 0
	for folder: String in ["res://assets/shaders/", "res://src/vfx/", "res://src/world/atmosphere/", "res://src/entities/hazards/"]:
		for file in DirAccess.get_files_at(folder):
			if not (file.ends_with(".gdshader") or file.ends_with(".gdshaderinc")):
				continue
			scanned += 1
			var code := FileAccess.get_file_as_string(folder + file)
			check(regex.search(code) == null, "shaders: %s never multiplies a texture read by COLOR (it squares the colors)" % file)
	check(scanned >= 8, "shaders scanned for squared colors (%d)" % scanned)

