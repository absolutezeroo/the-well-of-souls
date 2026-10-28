class_name CombatTests
extends TestSuite
## In the game: projectiles, perks, skills, monsters and their abilities, difficulty, weapons.


## Projectiles must stop on walls and hurt enemies.
func _test_projectiles(world: World, player: Player) -> void:
	var map := world.map
	var start := map.world_to_cell(player.global_position)
	# Closest wall in a straight line from the player.
	var best_dir := Vector2i.ZERO
	var best_distance := 999
	for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var distance := 1
		while map.is_floor(start + dir * distance):
			distance += 1
		if distance < best_distance:
			best_distance = distance
			best_dir = dir
	var wall_cell := start + best_dir * best_distance
	var wall_center := map.cell_to_world(wall_cell)

	var spec := ProjectileSpec.new()
	spec.speed = 400.0
	spec.max_distance = 5000.0
	world.fire_projectiles(player, Vector2(best_dir), spec)
	var crossed := false
	for i in 120:
		await get_tree().physics_frame
		for shot in world.get_node("Projectiles").get_children():
			var past: float = ((shot as Node2D).global_position - wall_center).dot(Vector2(best_dir))
			crossed = crossed or past > map.tile_size * 0.5
	check(not crossed, "projectiles stop on walls")
	check(world.get_node("Projectiles").get_child_count() == 0, "projectile removed after hitting a wall")

	# Shoot a monster standing in the open.
	var free_dir := -best_dir
	var target := world.spawn_monster(load("res://data/monsters/slime.tres"), player.global_position + Vector2(free_dir) * 60.0)
	var hp_before := target.hp
	spec.damage = 5
	world.fire_projectiles(player, Vector2(free_dir), spec)
	await _frames(20)
	check(target.hp < hp_before, "projectiles damage enemies")
	target.queue_free()
	await _frames(2)


## Each kind of perk does its job in the real game, then the level-up screen works.
func _test_perks_in_game(game: Game, world: World, player: Player) -> void:
	var weapon := player.get_weapon()
	player.perks.add(_perk("frenzy"))
	check(player.get_attack_cooldown(weapon) < weapon.cooldown, "Frenzy makes attacks faster")
	check(player.get_stats().attack_speed > 0.0, "perk stats count in the player's stats")

	var free_spot := world.find_open_point_near(player.global_position, 90.0)
	var rat := world.spawn_monster(load("res://data/monsters/rat.tres"), free_spot)
	await _frames(1)
	player.perks.add(_perk("vampirism"))
	player.hp = 10
	var kill := Combat.make_secondary_hit(player, 9999)
	kill.is_secondary = false
	rat.take_hit(kill)
	check(rat.is_dead and player.hp > 10, "Vampirism heals on kill")

	var slime := world.spawn_monster(load("res://data/monsters/slime.tres"), free_spot)
	await _frames(1)
	player.perks.add(_perk("ignite"))
	var poke := HitInfo.new()
	poke.amount = 1
	poke.source = player
	slime.take_hit(poke)
	check(slime.statuses.has(&"burn"), "Ignite sets enemies on fire")
	var hp_burning := slime.hp
	await _frames(70)
	check(slime.hp < hp_burning, "burning enemies lose HP over time")

	player.perks.add(_perk("executioner"))
	slime.hp = 1
	slime.base_stats.max_hp = 100
	slime.invalidate_stats()
	slime.hp = 20
	var finisher := HitInfo.new()
	finisher.amount = 10
	finisher.source = player
	var before := slime.hp
	slime.take_hit(finisher)
	check(before - slime.hp > Combat.mitigate(10, slime.get_stats().defense), "Executioner hits wounded enemies harder")
	slime.die(null)

	player.perks.add(_perk("thorns"))
	var skeleton := world.spawn_monster(load("res://data/monsters/skeleton.tres"), free_spot)
	await _frames(1)
	var skeleton_hp := skeleton.hp
	var stab := HitInfo.new()
	stab.amount = 1
	stab.source = skeleton
	player._invulnerable_time = 0.0
	player.take_hit(stab)
	check(skeleton.hp < skeleton_hp, "Thorns hurt melee attackers")
	check(skeleton.is_dead or skeleton.statuses.has(&"burn"), "Burning Thorns set them on fire")
	skeleton.die(null)

	player.perks.add(_perk("multishot"))
	var volley := ProjectileSpec.new()
	volley.max_distance = 10.0
	world.fire_projectiles(player, Vector2.RIGHT, volley)
	check(volley.count == 2 and volley.spread_degrees > 0.0, "Multishot adds a projectile")
	# Extra projectiles share the volley's damage, and every source together adds 2 at most.
	var prism: RuneDef = load("res://data/runes/prism.tres")
	player.perks.add(_perk("multishot"))
	player.perks.set_gear([], [prism, prism])
	var fan := ProjectileSpec.new()
	fan.max_distance = 10.0
	fan.damage = 30
	world.fire_projectiles(player, Vector2.RIGHT, fan)
	check(fan.count == 3, "Multishot 2 and two Prism runes: 2 extra projectiles at most (%d shots)" % fan.count)
	check(fan.damage == roundi(30 * (1.0 + 0.65 * 2) / 3.0), "the extra shots share the volley's damage (%d a shot)" % fan.damage)
	player.perks.set_gear([], [])

	var phoenix := _perk("phoenix_feather")
	player.perks.add(phoenix)
	var rig_scale := player.rig.scale
	_killing_blow(player)
	check(not player.is_dead and game.threshold.is_open(), "Phoenix Feather survives a killing blow (off to the Threshold)")
	check(player.perks.get_entry(phoenix).memory.get(&"used", 0) == 1, "the feather is used up")
	# His soul sinks: the body wavers and thins away on its own pixels, a few lower, never
	# squashed nor faded by alpha (decision 0007, task 424); whole again in the trial.
	var sink_scales := {}
	var sink_gone := 0.0
	for i in 20:
		sink_scales[player.rig.scale] = true
		sink_gone = maxf(sink_gone, player.rig.look.vanished())
		await _frames(1)
	check(sink_scales.keys() == [rig_scale] and sink_gone > 0.2, "sinking at the Threshold: the body thins away on its own pixels, never squashed (scales %s, %.2f gone)" % [sink_scales.keys(), sink_gone])
	check(await _win_trial(game) and not player.is_dead and player.hp >= int(player.get_max_hp() / 3.0), "won, the hero is back on his feet")
	check(player.rig.look.vanished() == 0.0 and player.rig.scale == rig_scale, "...his body whole again")
	# Where there is no Threshold (the balance tools' bare arena), a second life heals in place.
	var in_place := (phoenix.passives[0] as CheatDeathPassive).duplicate() as CheatDeathPassive
	in_place.trial = null
	var spare := PerkSet.Entry.new()
	spare.perk = phoenix
	player.hp = 0
	check(in_place.prevent_death(player, spare) and player.hp == roundi(player.get_max_hp() * in_place.heal_ratio) and not game.threshold.is_open(), "without a trial, a second life heals in place")
	player.perks.clear()
	player.hp = player.get_max_hp()
	await _frames(10)

	# Level up: a moment in the world, nothing opens, the fight goes on. The choice waits behind
	# the HUD's perk button (with how many wait); tapping it opens 3 perks and pauses.
	var offers_button := game.hud.get_node("%OffersButton") as OffersButton
	check(not offers_button.visible and game.pending_offers() == 0, "no perk button while no choice waits")
	player.gain_xp(player.xp_to_next_level())
	await _frames(2)
	check(not game.perk_panel.visible and not get_tree().paused and not game.is_menu_open(), "a level up opens nothing and doesn't pause")
	check(player.get_children().any(func(n: Node) -> bool: return n is LevelUpVfx), "a level up lights rings around the hero instead")
	check(offers_button.visible and offers_button.count == 1 and game.pending_offers() == 1, "the perk button shows 1 choice waiting")
	await _frames(120)
	check(not game.perk_panel.visible and game.pending_offers() == 1 and not player.get_children().any(func(n: Node) -> bool: return n is LevelUpVfx), "the moment passes, the choice keeps waiting")
	check(await _tap_offers(game), "the perk button can be tapped")
	check(game.perk_panel.visible and get_tree().paused, "tapping it opens the perk choice and pauses")
	check(game.perk_panel.modulate.a < 0.99, "the choice fades in (no hard cut): %.2f" % game.perk_panel.modulate.a)
	check(not offers_button.visible and game.pending_offers() == 0, "the choice on screen is no longer counted")
	var cards: HBoxContainer = game.perk_panel.get_node("%Cards")
	check(cards.get_child_count() == 3, "three cards")
	check((cards.get_child(0) as Button).disabled, "cards ignore taps for a moment (no accidental pick)")
	await get_tree().create_timer(0.6, true).timeout
	check(not (cards.get_child(0) as Button).disabled, "cards become pickable")
	check(is_equal_approx(game.perk_panel.modulate.a, 1.0), "the choice is fully in after its fade")
	# Reroll: three other cards. Banish: that perk is gone for the run, another takes its place.
	game.run.rerolls = 1
	game.run.banishes = 1
	game.perk_panel.set_charges(1, 1)
	var reroll_button: Button = game.perk_panel.get_node("%RerollButton")
	var banish_button: Button = game.perk_panel.get_node("%BanishButton")
	check(reroll_button.visible and reroll_button.text == "Reroll (1)" and not banish_button.disabled, "the choice shows its reroll and banish")
	var first_cards := game.perk_panel.get_offered().duplicate()
	reroll_button.pressed.emit()
	await _frames(1)
	var rerolled := game.perk_panel.get_offered()
	check(game.run.rerolls == 0 and reroll_button.disabled, "a reroll is spent")
	check(rerolled.size() == 3 and not rerolled.any(func(p: PerkDef) -> bool: return first_cards.has(p)), "a reroll deals three other cards")
	banish_button.pressed.emit()
	check(game.perk_panel.is_banishing(), "Banish, then tap a card")
	var gone: PerkDef = rerolled[0]
	(cards.get_child(0) as Button).pressed.emit()
	await _frames(1)
	check(game.perk_panel.visible and game.run.banished.has(gone) and game.run.banishes == 0, "the tapped perk is banished, the choice stays open")
	check(not game.perk_panel.get_offered().has(gone) and game.perk_panel.get_offered().size() == 3, "another card takes its place")
	var offered: PerkDef = game.perk_panel.get_offered()[1]
	(cards.get_child(1) as Button).pressed.emit()
	await _frames(2)
	check(player.perks.stacks_of(offered) == 1, "tapping a card gives its perk")
	check(not game.perk_panel.visible and not get_tree().paused, "the game resumes after choosing")
	check(game.hud.get_node("%PerkTray").get_child_count() == 1, "the HUD shows collected perks")

	player.gain_xp(player.xp_to_next_level() + player.def.xp_to_next_level(player.level + 1))
	await _frames(2)
	check(not game.perk_panel.visible and offers_button.visible and offers_button.count == 2, "two level ups: nothing opens, the button counts 2")
	# Later (and Back) put a choice off: back to the fight, it waits with the same cards.
	check(game.open_offers() and game.perk_panel.visible, "open_offers() opens the first choice")
	var put_off := game.perk_panel.get_offered().duplicate()
	(game.perk_panel.get_node("%LaterButton") as Button).pressed.emit()
	await _frames(2)
	check(not game.perk_panel.visible and not get_tree().paused and offers_button.count == 2, "Later: back to the game, both choices still wait")
	await _tap_offers(game)
	check(game.perk_panel.visible and game.perk_panel.get_offered() == put_off, "a choice put off comes back with the same cards (no free reroll)")
	game._back()
	await _frames(2)
	check(not game.perk_panel.visible and not get_tree().paused and game.pending_offers() == 2, "Back puts it off too")
	await _tap_offers(game)
	check(game.perk_panel.visible, "first of two choices")
	game.perk_panel.choose(0)
	await _frames(2)
	check(game.perk_panel.visible, "second choice follows right away")
	game.perk_panel.choose(0)
	await _frames(2)
	check(not offers_button.visible and game.pending_offers() == 0, "all taken: the perk button goes away")
	var total_levels := 0
	for entry in player.perks.entries:
		total_levels += entry.stacks
	check(not get_tree().paused and total_levels == 3, "both perks taken (%d perk levels), game resumed" % total_levels)
	check(not player.perks.entries.any(func(e: PerkSet.Entry) -> bool: return game.run.banished.has(e.perk)), "the banished perk never came back")

	# Long text makes a taller card: nothing spills out of the frame.
	var wordy := PerkDef.new()
	wordy.display_name = "A Perk With A Rather Long Name"
	wordy.description = "This perk does a great many things, all of them described at length, so that the text runs over several lines and would never fit in the card's usual height. ".repeat(3)
	wordy.synergies = [_perk("ignite").synergies[0], _perk("vampirism").synergies[0]]
	var card := (load("res://src/ui/perk_choice/perk_card.tscn") as PackedScene).instantiate() as PerkCard
	add_child(card)
	card.show_perk(wordy, player.perks)
	await _frames(5)
	check((card.get_node("Margin") as Control).get_combined_minimum_size().y <= card.size.y + 1.0 and card.size.y > 320.0, "a card grows to fit long text (%d px)" % card.size.y)
	card.queue_free()
	for perk in CONTENT.perks:
		var real := (load("res://src/ui/perk_choice/perk_card.tscn") as PackedScene).instantiate() as PerkCard
		add_child(real)
		real.show_perk(perk, player.perks)
		await _frames(4)
		check((real.get_node("Margin") as Control).get_combined_minimum_size().y <= real.size.y + 1.0, "%s: its text fits its card" % perk.id)
		real.queue_free()
	game.run.banished.clear()

	# A card spells its family out: its name, how many more it takes, what the bonus does.
	var family := _perk("ignite").synergies[0]
	var spelled := (load("res://src/ui/perk_choice/perk_card.tscn") as PackedScene).instantiate() as PerkCard
	add_child(spelled)
	spelled.show_perk(_perk("ignite"), PerkSet.new())
	var words := _texts(spelled)
	check(words.contains("%s family" % family.display_name) and words.contains("more %s perk" % family.display_name) and words.contains(family.description), "a card says what its family is and does: %s" % words.left(160))
	spelled.queue_free()
	var almost := PerkSet.new()
	for perk in CONTENT.perks:
		if perk.synergies.has(family) and almost.pieces_of(family) < family.pieces - 1 and perk != _perk("ignite"):
			almost.add(perk)
	var waking := (load("res://src/ui/perk_choice/perk_card.tscn") as PackedScene).instantiate() as PerkCard
	add_child(waking)
	waking.show_perk(_perk("ignite"), almost)
	check(waking.completes and _texts(waking).contains("AWAKENS"), "the card that completes a family says so")
	waking.queue_free()
	check(game.perk_panel._rule.text.contains("family"), "the perk screen explains families in one line")

	# The bag's Perks: every family in words, every perk taken.
	game.open_inventory()
	await _frames(2)
	game.inventory_panel.open_build()
	var build := game.inventory_panel.get_node("BuildWindow") as BuildWindow
	check(game.inventory_panel.is_build_open() and build._families.get_child_count() == CONTENT.synergies.size(), "the build lists every family (%d)" % build._families.get_child_count())
	check(build._perks.get_child_count() == maxi(player.perks.entries.size(), 1), "and every perk taken")
	game.inventory_panel.close()
	await _frames(2)
	check(not game.inventory_panel.is_build_open() and not get_tree().paused, "closing the bag closes the build")


## Every label's text under `node`, in one string.
func _texts(node: Node) -> String:
	var parts := PackedStringArray()
	for label in node.find_children("*", "Label", true, false):
		parts.append((label as Label).text)
	return " | ".join(parts)


## The new perks and the families' bonuses, in a real fight.
func _test_synergies_in_game(game: Game, world: World, player: Player) -> void:
	player.xp = -1000000  # no level up (and its pause) from these kills
	var spot := world.find_open_point_near(player.global_position, 90.0)
	var shots: Node = world.get_node("Projectiles")
	var slime_def: MonsterDef = load("res://data/monsters/slime.tres")

	# Ice Shards: a kill bursts into shards flying out of the body.
	player.perks.add(_perk("ice_shards"))
	var rat := world.spawn_monster(load("res://data/monsters/rat.tres"), spot)
	rat.dormant = true
	await _frames(1)
	var kill := HitInfo.new()
	kill.amount = 9999
	kill.source = player
	rat.take_hit(kill)
	await _frames(1)
	var shards := shots.get_children().filter(func(n: Node) -> bool: return (n as Projectile).global_position.distance_to(rat.global_position) < 40.0)
	check(shards.size() >= 4, "Ice Shards: the body bursts into shards (%d)" % shards.size())

	# Frost: three frost perks wake it; slowed enemies take more, crits freeze them.
	player.perks.add(_perk("frostbite"))
	player.perks.add(_perk("cold_snap"))
	var frost: SynergyDef = _perk("frostbite").synergies[0]
	check(player.perks.is_awake(frost), "three frost perks wake Frost")
	check((game.hud.get_node("%PerkTray") as Control).get_child(0) is Panel, "the HUD shows the awake family first")
	var slime := world.spawn_monster(slime_def, spot)
	slime.dormant = true
	slime.base_stats.max_hp = 9999
	slime.invalidate_stats()
	slime.hp = 9999
	await _frames(1)
	var plain := HitInfo.new()
	plain.amount = 20
	plain.source = player
	slime.statuses.clear()
	player.perks.modify_outgoing_hit(player, slime, plain)
	var normal := plain.amount
	slime.statuses.apply_slow(0.3, 2.0)
	var on_slowed := HitInfo.new()
	on_slowed.amount = 20
	on_slowed.source = player
	player.perks.modify_outgoing_hit(player, slime, on_slowed)
	check(on_slowed.amount >= roundi(normal * 1.4), "Frost: slowed enemies take more damage (%d vs %d)" % [on_slowed.amount, normal])
	var crit := HitInfo.new()
	crit.amount = 5
	crit.is_crit = true
	crit.source = player
	slime.take_hit(crit)
	check(slime.statuses.speed_multiplier() <= 0.15, "Frost: a critical hit freezes a slowed enemy")
	player.perks.clear()

	# Storm: every 4th hit, lightning jumps to the enemies around.
	for id in ["frenzy", "thunderclap", "shock_roll"]:
		player.perks.add(_perk(id))
	var others: Array[Monster] = []
	for i in 2:
		var other := world.spawn_monster(slime_def, slime.global_position + Vector2(40 + 30 * i, 0))
		other.dormant = true
		others.append(other)
	await _frames(1)
	var others_hp := others.map(func(m: Monster) -> int: return m.hp)
	for i in 4:
		var poke := HitInfo.new()
		poke.amount = 1
		poke.source = player
		slime.take_hit(poke)
	check(others[0].hp < others_hp[0] or others[1].hp < others_hp[1], "Storm: lightning jumps to the enemies nearby")
	player.perks.clear()

	# Thunderclap: a crit's shockwave hurts the enemies around, not the one struck.
	player.perks.add(_perk("thunderclap"))
	await _frames(1)
	var struck_hp := slime.hp
	others_hp = others.map(func(m: Monster) -> int: return m.hp)
	var crit_poke := HitInfo.new()
	crit_poke.amount = 7
	crit_poke.is_crit = true
	crit_poke.source = player
	slime.take_hit(crit_poke)
	check(struck_hp - slime.hp <= 7, "Thunderclap: the enemy struck takes only the crit (%d)" % (struck_hp - slime.hp))
	check(others[0].hp < others_hp[0] or others[1].hp < others_hp[1], "Thunderclap: the shockwave hurts the enemies around")
	player.perks.clear()

	# Echo: every source counts together and stops at the dungeon's cap (balance-log 2026-10-23:
	# three Echo runes, of Echoes and the Echo perk skipped 69% of cooldowns on top of the
	# cooldown cap).
	var config := world.rules.config
	var cap := config.skill_echo_max_chance
	check(cap > 0.0 and cap <= 0.5, "skill echoes are capped (%.2f)" % cap)
	var echo_perk := _perk("echo")
	var stacked: Array[PerkDef] = [echo_perk]
	for i in 3:
		var rune := PerkDef.new()
		rune.id = StringName("echo_rune_%d" % i)
		rune.passives = (load("res://data/runes/echo.tres") as RuneDef).passives
		stacked.append(rune)
	for perk in stacked:
		player.perks.add(perk)
	for i in 2:
		player.perks.add(echo_perk)  # the Echo perk at 3 levels: 45% on its own
	var uncapped := SkillEchoPassive.total_chance(player, 1.0)
	check(uncapped > cap and is_equal_approx(SkillEchoPassive.total_chance(player), cap),
		"Echo: the perk and three runes (%d%% together) echo %d%% of the time, the cap" % [roundi(uncapped * 100.0), roundi(SkillEchoPassive.total_chance(player) * 100.0)])
	player.perks.clear()
	# An echo can't echo (a skill is used at most twice per cooldown, whatever the sources).
	config.skill_echo_max_chance = 1.0
	var sure_echo: PerkDef = _perk("echo").duplicate()
	var always := SkillEchoPassive.new()
	always.chance_per_stack = 1.0
	sure_echo.passives = [always]
	player.perks.add(sure_echo)
	var echo_index := player.skills.skills.find_custom(func(s: SkillDef) -> bool: return s != null)
	var uses := 0
	for i in 4:
		player.skills._cooldowns[echo_index] = 0.0 if i == 0 else player.skills._cooldowns[echo_index]
		if player.skills.try_use(echo_index, player, Vector2.RIGHT):
			uses += 1
		await _frames(1)
	check(uses == 2, "Echo: a 100%% echo gives one free cast, not a loop (%d casts)" % uses)
	config.skill_echo_max_chance = cap
	player.perks.clear()

	# Healing spells heal in full outside a boss fight, and half during one.
	for id in ["holy_light", "holy_shield", "smite"]:
		var spell: SkillDef = load("res://data/skills/player/%s.tres" % id)
		for effect in spell.effects:
			if effect is HealEffect:
				var heal := effect as HealEffect
				check(heal.boss_fight_ratio <= 0.5 and not world.is_boss_fight()
					and heal.heal_amount(player) == heal.amount + roundi(player.get_max_hp() * heal.max_hp_ratio),
					"%s heals in full outside a boss fight, half during one" % id)

	# Arcane: using a skill fires a ring of bolts.
	for id in ["arcane_focus", "arcane_power", "devotion"]:
		player.perks.add(_perk(id))
	for n in shots.get_children():
		n.queue_free()
	await _frames(1)
	var index := player.skills.skills.find_custom(func(s: SkillDef) -> bool: return s != null)
	player.skills._cooldowns[index] = 0.0
	player.skills.try_use(index, player, Vector2.RIGHT)
	await _frames(1)
	var near_hero := shots.get_children().filter(func(n: Node) -> bool: return (n as Projectile).global_position.distance_to(player.global_position) < 60.0)
	check(near_hero.size() >= 8, "Arcane: a skill also fires a ring of bolts (%d)" % near_hero.size())
	player.perks.clear()

	# Stat perks that now do something: Precision opens with a crit, Swiftness hits harder
	# after a roll, Iron Skin throws enemies back, the Guardian Ring wards every floor.
	player.perks.add(_perk("precision"))
	var opener := HitInfo.new()
	opener.amount = 10
	opener.source = player
	slime.hp = slime.get_max_hp()
	player.perks.modify_outgoing_hit(player, slime, opener)
	check(opener.is_crit and opener.amount > 10, "Precision: the first blow on an unhurt enemy is a crit")
	player.perks.clear()
	player.perks.add(_perk("swiftness"))
	var after_roll := HitInfo.new()
	after_roll.amount = 20
	after_roll.source = player
	player.perks.on_dash(player)
	player.perks.modify_outgoing_hit(player, slime, after_roll)
	check(after_roll.amount > 20, "Swiftness: hits right after a roll deal more")
	player.perks.clear()
	player.perks.add(_perk("iron_skin"))
	var pushed := world.spawn_monster(load("res://data/monsters/rat.tres"), player.global_position + Vector2(36, 0))
	pushed.dormant = true
	await _frames(1)
	var pushed_hp := pushed.hp
	var bite := HitInfo.new()
	bite.amount = 3
	bite.source = pushed
	player._invulnerable_time = 0.0
	player.take_hit(bite)
	check(pushed.is_dead or pushed.hp < pushed_hp, "Frost Armor: getting hit throws enemies back")
	check(pushed.is_dead or pushed.statuses.is_slowed(), "Frost Armor: and chills them")
	player.perks.clear()
	player.perks.add(_perk("guardian_ring"))
	player.ward = 0
	player.perks.on_floor_started(player)
	check(player.ward >= 20, "Guardian Ring: every floor starts with a ward")
	player.ward = 0
	player.perks.clear()

	# Gear affixes that do something: a Vampiric weapon heals on kill.
	var weapon_before := player.get_weapon()
	var vampiric: ItemAffixDef = load("res://data/affixes/vampiric.tres")
	var affixes: Array[ItemAffixDef] = [vampiric]
	var fang := LootRoller.make(weapon_before.base_item if weapon_before.base_item else weapon_before, ItemRarity.MAGIC, affixes)
	player.equipment.equip(fang)
	check(fang.get_details().contains(vampiric.description), "the item says what its affix does")
	player.hp = 5
	var prey := world.spawn_monster(load("res://data/monsters/rat.tres"), spot)
	prey.dormant = true
	await _frames(1)
	var bite_back := HitInfo.new()
	bite_back.amount = 9999
	bite_back.source = player
	prey.take_hit(bite_back)
	check(player.hp > 5, "a Vampiric weapon heals on kill")
	player.equipment.equip(weapon_before)
	player.hp = 5
	var prey2 := world.spawn_monster(load("res://data/monsters/rat.tres"), spot)
	prey2.dormant = true
	await _frames(1)
	prey2.take_hit(bite_back)
	check(player.hp == 5, "taken off, it stops")

	# Bestiary challenges: an elite slain by the hero, untouched since it saw them.
	Profile.reset()
	var done: Array[StringName] = []
	var on_done := func(_m: MonsterDef, c: HuntChallenge) -> void: done.append(c.id)
	Events.hunt_challenge_done.connect(on_done)
	var target := world.spawn_monster(load("res://data/monsters/rat.tres"), spot)
	world.make_elite(target)
	target.dormant = true
	await _frames(1)
	target.wake_up(player)
	await _frames(2)
	var finish := HitInfo.new()
	finish.amount = 99999
	finish.source = player
	target.take_hit(finish)
	await _frames(1)
	check(done.has(&"elite") and Profile.is_challenge_done(&"rat", &"elite"), "slaying an elite rat does its challenge")
	check(done.has(&"untouched"), "untouched since it saw the hero")
	check(Profile.souls > 0, "challenges pay souls")
	Events.hunt_challenge_done.disconnect(on_done)
	Profile.reset()

	# Blood: wounded you hit harder, kills heal.
	for id in ["vampirism", "bloodrage", "vitality"]:
		player.perks.add(_perk(id))
	player.hp = 1
	var hard := HitInfo.new()
	hard.amount = 20
	hard.source = player
	player.perks.modify_outgoing_hit(player, slime, hard)
	check(hard.amount > 20 + 1, "Blood: wounded, you hit harder (%d)" % hard.amount)
	player.perks.clear()

	for monster in [slime] + others:
		if is_instance_valid(monster) and not monster.is_dead:
			monster.die(null)
	player.hp = player.get_max_hp()
	player.xp = 0
	await _frames(5)


## Healing from hits and kills in the real game: burns and side effects heal nothing, whole
## points only, summons feed no heal, shards fired by a perk trigger no on-hit perk, and the
## hero's healing per second stays under the limit (DungeonConfig > Sustain).
func _test_sustain_in_game(world: World, player: Player) -> void:
	player.xp = -1000000  # no level up (it heals to full) from these kills
	player.perks.clear()
	player.invincible = true  # nothing else may change the hero's health meanwhile
	var lane := _clear_lane(world, player.global_position, 96.0)
	if lane.is_empty():
		return
	var shot_direction: Vector2 = lane[1]
	var spot: Vector2 = lane[0] + shot_direction * 64.0
	var leech: RuneDef = load("res://data/runes/leech.tres")
	var ratio: float = (leech.passives[0] as LifestealPassive).ratio_per_stack
	var dummy := world.spawn_monster(load("res://data/monsters/slime.tres"), spot)
	dummy.dormant = true
	dummy.base_stats.max_hp = 999999
	dummy.base_stats.defense = 0
	dummy.invalidate_stats()
	dummy.hp = 999999
	await _frames(1)
	player.perks.set_gear([], [leech])
	player.sustain = SustainMeter.new()
	player.hp = 10
	dummy.take_hit(Combat.make_tick(player, 50))
	check(player.hp == 10, "Leech: a burn tick heals nothing")
	dummy.take_hit(Combat.make_secondary_hit(player, 50))
	check(player.hp == 10, "Leech: a secondary hit (shockwave, chain, thorns) heals nothing")
	# Small direct hits: the fractions add up, no point is given away per hit.
	var dealt := 0
	var healed := 0
	for i in 6:
		var before := dummy.hp
		var hp_before := player.hp
		var hit := HitInfo.new()
		hit.amount = 7
		hit.source = player
		dummy.take_hit(hit)
		dealt += before - dummy.hp
		healed += player.hp - hp_before
	check(healed == floori(dealt * ratio + 0.0001), "Leech: %d damage heals %d, not one point a hit (%d)" % [dealt, floori(dealt * ratio + 0.0001), healed])

	# Shards fired by a perk are secondary: they feed no lifesteal and no chains.
	var spec := ProjectileSpec.new()
	spec.secondary = true
	spec.damage = 30
	spec.speed = 600.0
	spec.max_distance = 300.0
	player.hp = 10
	player.sustain = SustainMeter.new()
	var dummy_hp := dummy.hp
	check(_body_fits(world, dummy.global_position - shot_direction * 24.0, spec.radius), "the sustain shard starts clear of walls and props")
	world.fire_projectiles(player, shot_direction, spec, dummy.global_position - shot_direction * 24.0)
	await _frames(10)
	check(dummy.hp < dummy_hp and player.hp == 10, "a shard fired by a perk hurts (%d -> %d) but heals nothing (%d)" % [dummy_hp, dummy.hp, player.hp])

	# The limit: three Leech runes on big hits every frame for a second heal no more than the
	# budget (burst + one second of refill).
	var rules: SustainRules = world.rules.config.sustain
	player.perks.set_gear([], [leech, leech, leech])
	player.sustain = SustainMeter.new()
	player.hp = 1
	var max_hp := player.get_max_hp()
	for frame in 60:
		var big := HitInfo.new()
		big.amount = 40
		big.source = player
		dummy.take_hit(big)
		await get_tree().physics_frame
	var gained := player.hp - 1
	var allowed := rules.capacity(max_hp) + rules.refill_per_second(max_hp, false) * 1.05
	check(gained <= ceili(allowed) and gained >= floori(rules.capacity(max_hp)), "stacked Leech heals %d in a second, the limit is %d (asked for %d)" % [gained, ceili(allowed), roundi(40 * ratio * 3 * 60)])
	player.perks.set_gear(player.equipment.affixes(), player.equipment.runes())

	# Summons feed no "on kill" heal; ordinary monsters do.
	player.perks.add(_perk("vampirism"))
	player.sustain = SustainMeter.new()
	player.hp = 10
	var called := world.spawn_monster(load("res://data/monsters/rat.tres"), spot + Vector2(30, 0))
	called.summoned = true
	called.dormant = true
	var plain := world.spawn_monster(load("res://data/monsters/rat.tres"), spot + Vector2(-30, 0))
	plain.dormant = true
	await _frames(1)
	var kill := HitInfo.new()
	kill.amount = 99999
	kill.source = player
	called.take_hit(kill)
	check(called.is_dead and player.hp == 10, "Vampirism: a summoned monster's death heals nothing")
	plain.take_hit(kill)
	check(plain.is_dead and player.hp > 10, "Vampirism: an ordinary kill heals")
	player.perks.clear()
	dummy.die(null)
	player.invincible = false
	player.hp = player.get_max_hp()
	player.xp = 0
	await _frames(5)


## Skills come from the weapon and from tomes; statuses, delays, dash strikes, skill stats.
func _test_skills(game: Game, world: World, player: Player) -> void:
	var katana: WeaponDef = load("res://data/items/weapons/katana.tres")
	var book: WeaponDef = load("res://data/items/weapons/book.tres")
	player.equipment.equip(katana)
	await _frames(1)
	var slots := player.skills.skills
	check(slots.size() == Player.SKILL_COUNT, "4 skill slots")
	check(slots[0] == player.def.innate_skills[0], "slot 1: the roll, always")
	check(slots[1] == katana.skills[0] and slots[2] == katana.skills[1], "slots 2-3: the weapon's skills")
	check(slots[3] == null and not game.hud.get_node("%Skill4Button").visible, "no spell learned yet: last button hidden")
	player.equipment.equip(book)
	await _frames(1)
	check(player.skills.skills[1] == book.skills[0] and player.skills.skills[2] == book.skills[1], "a tome-wielder gets fire skills")
	check(not player.skills.is_ready(1) and player.skills.is_ready(0), "swapping weapons: new skills on a short cooldown, the roll is kept")
	check((game.hud.get_node("%Skill2Button") as ActionButton).icon == book.skills[0].icon, "the HUD shows the new skills")

	var tome: SkillTomeDef = load("res://data/items/tomes/tome_frost.tres")
	player.inventory.add(tome)
	player.pack.use_item(tome)
	await _frames(1)
	check(player.learned_skill == tome.skill and player.skills.skills[3] == tome.skill, "a tome teaches a spell (last slot)")
	check(game.hud.get_node("%Skill4Button").visible, "the spell button appears")
	player.equipment.equip(katana)
	await _frames(1)
	check(player.skills.skills[3] == tome.skill, "the spell stays when changing weapons")

	# Frost Nova slows; Ice Shards would too.
	var spot := world.find_open_point_near(player.global_position, 60.0)
	var slime := world.spawn_monster(load("res://data/monsters/slime.tres"), spot)
	slime.dormant = true
	await _frames(70)
	var speed_before := slime.get_move_speed()
	check(player.skills.try_use(3, player, player.global_position.direction_to(slime.global_position)), "cast the learned spell")
	check(slime.statuses.is_slowed() and slime.get_move_speed() < speed_before, "Frost Nova slows enemies")
	slime.die(null)

	# Flurry: three stabs over time (effect delays).
	var sai: WeaponDef = load("res://data/items/weapons/sai.tres")
	player.equipment.equip(sai)
	await _frames(100)
	var dummy := world.spawn_monster(load("res://data/monsters/cyclops.tres"), player.global_position + Vector2(40, 0))
	dummy.dormant = true
	await _frames(1)
	var hp_start := dummy.hp
	player.skills.try_use(1, player, Vector2.RIGHT)
	await _frames(2)
	var hp_first := dummy.hp
	await _frames(20)
	check(hp_first < hp_start and dummy.hp < hp_first, "Flurry keeps stabbing after the first hit")
	dummy.die(null)

	# Dash strike: moves the hero and cuts what is on the way.
	player.equipment.equip(katana)
	await _frames(100)
	# Open floor all around, and a way the dash itself finds clear: it stops at whatever its ray
	# hits on the world's layer (a wall, but also a barrel or a pillar the sight goes past).
	# (Solid ground all along too: a hole at the end would drop the hero back where he started.)
	var dash := katana.skills[1].effects[0] as DashStrikeEffect
	var lane := _clear_lane(world, player.global_position, dash.distance + player.radius + 4.0)
	var free: Vector2 = lane[0] if not lane.is_empty() else player.global_position
	var dir: Vector2 = lane[1] if not lane.is_empty() else Vector2.RIGHT
	player.global_position = free
	var target := world.spawn_monster(load("res://data/monsters/cyclops.tres"), free + dir * 90.0)
	target.dormant = true
	await _frames(1)
	var target_hp := target.hp
	var before := player.global_position
	var dashed := player.skills.try_use(2, player, dir)
	await _frames(15)
	check(target.hp < target_hp, "Iaido Dash cuts enemies on the way (used %s)" % dashed)
	check(player.global_position.distance_to(before) > 60.0, "Iaido Dash moves the hero (%d px)" % roundi(player.global_position.distance_to(before)))
	target.die(null)

	# Skill stats from perks.
	var power_before := player.get_skill_power()
	player.perks.add(_perk("arcane_power"))
	check(player.get_skill_power() > power_before, "Arcane Power raises skill damage")
	player.perks.add(_perk("arcane_focus"))
	await _frames(400)
	player.skills.try_use(1, player, Vector2.RIGHT)
	check(player.skills._durations[1] < katana.skills[0].cooldown, "Arcane Focus shortens cooldowns")
	player.perks.clear()
	player.learned_skill = null
	player.equipment.equip(katana)
	await _frames(20)


## New monster abilities: poison, death bursts, splitting, charges.
func _test_bestiary(world: World, player: Player) -> void:
	player.base_stats.defense = 0
	player.invalidate_stats()
	# Poison bite.
	var snake := world.spawn_monster(load("res://data/monsters/snake.tres"), world.find_open_point_near(player.global_position, 30.0))
	await _frames(1)
	player._invulnerable_time = 0.0
	snake._attack_cooldown = 0.0
	snake.attack(snake.global_position.direction_to(player.global_position))
	check(player.statuses.has(&"poison"), "a viper bite poisons")
	var hp_poisoned := player.hp
	player._invulnerable_time = 0.0
	await _frames(100)
	check(player.hp < hp_poisoned, "poison hurts over time")
	player.statuses.clear()
	snake.die(null)

	# A giant slime splits in two.
	var big: MonsterDef = load("res://data/monsters/big_slime.tres")
	var already_there := world.get_hostiles(player.faction)
	var giant := world.spawn_monster(big, world.find_open_point_near(player.global_position, 120.0))
	await _frames(1)
	giant.die(null)
	await _frames(3)
	var newcomers := world.get_hostiles(player.faction).filter(func(m: Actor) -> bool: return not already_there.has(m))
	var split := big.traits.filter(func(t: MonsterTrait) -> bool: return t is DeathSpawnTrait)
	check(not split.is_empty() and newcomers.size() == (split[0] as DeathSpawnTrait).count, "a giant slime splits when it dies")
	for monster in newcomers:
		monster.queue_free()
	await _frames(2)

	# A flame spirit explodes a moment after dying.
	player.hp = player.get_max_hp()
	var flam := world.spawn_monster(load("res://data/monsters/flam.tres"), world.find_open_point_near(player.global_position, 30.0))
	await _frames(1)
	var hp_before := player.hp
	player._invulnerable_time = 0.0
	flam.die(null)
	check(player.hp == hp_before, "the burst waits (time to step away)")
	var burst := flam.get_trait(DeathBurstTrait) as DeathBurstTrait
	await _frames(int(Combat.RULES.blast_warning(burst.fuse) * 60.0) + 4)  # (held to the fairness floor)
	check(player.hp < hp_before, "a dying flame spirit explodes")
	player.statuses.clear()

	# Charges are telegraphed casts that cross the room.
	var beast: MonsterDef = load("res://data/monsters/beast.tres")
	check(beast.skills.any(func(skill: SkillDef) -> bool: return skill.cast_time > 0.0 and skill.effects[0] is DashStrikeEffect), "the beast charges (telegraphed)")
	player.hp = player.get_max_hp()
	player.base_stats.defense = 999
	player.invalidate_stats()
	await _frames(5)


## Difficulty multipliers reach monsters; the run uses the difficulty picked on the title screen.
func _test_difficulty_in_game(_game: Game, world: World, player: Player) -> void:
	var skeleton: MonsterDef = load("res://data/monsters/skeleton.tres")
	var spot := world.find_open_point_near(player.global_position, 150.0)
	check(world.difficulty == CONTENT.default_difficulty, "a run without choice is Normal")
	var normal_one := world.spawn_monster(skeleton, spot)
	world.difficulty = CONTENT.get_difficulty(&"nightmare")
	var nightmare_one := world.spawn_monster(skeleton, spot)
	world.difficulty = CONTENT.get_difficulty(&"easy")
	var easy_one := world.spawn_monster(skeleton, spot)
	world.difficulty = CONTENT.default_difficulty
	await _frames(1)
	check(nightmare_one.get_max_hp() > normal_one.get_max_hp() and easy_one.get_max_hp() < normal_one.get_max_hp(), "monster HP follows the difficulty")
	check(nightmare_one.get_power() > normal_one.get_power() and easy_one.get_power() < normal_one.get_power(), "monster damage follows the difficulty")
	# (A wind-up long enough to stay over the fairness floor shows the difficulty's share.)
	check(nightmare_one.windup_for(1.0) < normal_one.windup_for(1.0) and easy_one.windup_for(1.0) > normal_one.windup_for(1.0), "less time to dodge on harder difficulties")
	check(nightmare_one.get_attack_windup() >= Combat.RULES.min_monster_windup, "...never under the fairness floor (decision 0008: %.2f s)" % nightmare_one.get_attack_windup())
	for monster in [normal_one, nightmare_one, easy_one]:
		monster.queue_free()
	await _frames(2)


## Every weapon swings or shoots, and both its skills work, in the real game.
func _test_weapon_kits(game: Game) -> void:
	var player: Player = game.player
	var world: World = game.world
	player.xp = -1000000
	var weapon_before := player.get_weapon()
	# No perks meanwhile (an Echo would leave a skill ready again, a family fire extra bolts).
	var perks_before := player.perks.to_data()
	player.perks.clear()
	# Alone with the target: a wandering monster stepping in the way would take the hits.
	await _clear_monsters(world)
	var target := world.spawn_monster(load("res://data/monsters/slime.tres"), world.map.cell_to_world(_open_cell_near(world, player.global_position, 2)))
	target.dormant = true
	target.flies = true  # a big knockback must not send it down a hole
	target.base_stats.max_hp = 100000
	target.invalidate_stats()
	target.hp = 100000
	var target_spot := target.global_position
	for id in ["ninjaku", "rapier", "big_sword", "whip", "bow", "shuriken"]:
		var weapon: WeaponDef = load("res://data/items/weapons/%s.tres" % id)
		check(CONTENT.items.has(weapon), "%s can be found" % id)
		# Back in place: the previous weapons may have knocked it against a wall.
		target._knockback = Vector2.ZERO
		target.global_position = target_spot
		player.global_position = target_spot + Vector2(-50, 0)
		await _frames(2)
		player.equipment.equip(weapon)
		check(player.skills.skills[1] == weapon.skills[0] and player.skills.skills[2] == weapon.skills[1], "%s gives its two skills" % id)
		var hp_before := target.hp
		player._attack_cooldown = 0.0
		check(player.attack(Vector2.RIGHT) and player.rig.weapon.visible, "%s attacks with the weapon in hand" % id)
		await _frames(30)
		for slot in [1, 2]:
			player.skills._cooldowns[slot] = 0.0
			player.use_skill(slot)
			check(player.skills.cooldown_ratio(slot) > 0.0, "%s: %s is used" % [id, weapon.skills[slot - 1].id])
			await _frames(50)
		check(target.hp < hp_before, "%s hurts" % id)
	target.queue_free()
	player.equipment.equip(weapon_before)
	player.perks.load_data(perks_before)
	player.xp = 0
	await _frames(5)


## The attack button (docs/design/interface.md): a tap is one basic attack, holding no longer
## repeats it but charges the weapon's charged attack (after a delay: taps never charge), shown
## by a gauge at the hero's feet and on the button; let go full, it goes off; a roll cancels it,
## a hit doesn't; every hero's weapon's charged attack works; a save doesn't keep a charge. And
## the hero's own effects never hide him (docs/vfx.md 2b).
func _test_charged_attacks(game: Game) -> void:
	var player: Player = game.player
	var world: World = game.world
	player.xp = -1000000
	var weapon_before := player.get_weapon()
	var perks_before := player.perks.to_data()
	player.perks.clear()
	await _clear_monsters(world)
	var spot := world.map.cell_to_world(_open_cell_near(world, player.global_position, 3))
	var target := world.spawn_monster(load("res://data/monsters/slime.tres"), spot + Vector2(40, 0))
	target.dormant = true
	target.flies = true
	target.base_stats.max_hp = 100000
	target.invalidate_stats()
	target.hp = 100000
	var place := func() -> void:
		target._knockback = Vector2.ZERO
		target.global_position = spot + Vector2(40, 0)
		player.global_position = spot
		player._knockback = Vector2.ZERO
	var attacks := [0]
	var unleashed: Array[ChargedAttackDef] = []
	var count_attack := func() -> void: attacks[0] += 1
	var count_charged := func(attack: ChargedAttackDef) -> void: unleashed.append(attack)
	player.attacked.connect(count_attack)
	player.charged_attack.connect(count_charged)
	var katana: WeaponDef = load("res://data/items/weapons/katana.tres")
	player.equipment.equip(katana)
	place.call()
	await _frames(40)
	var button: ActionButton = game.hud.get_node("%AttackButton")

	# A tap: one basic attack, no charge.
	var hp_before := target.hp
	_set_action(&"attack", true)
	await _frames(3)
	_set_action(&"attack", false)
	await _frames(10)
	check(attacks[0] == 1 and target.hp < hp_before, "charged: a tap is one basic attack (%d)" % attacks[0])
	check(unleashed.is_empty() and player.charge.state == AttackCharge.State.IDLE and not player.charge_vfx.is_showing(), "charged: a tap never charges")
	await _frames(30)

	# Held: one attack, then it charges (no more swings), slower, the gauge shows; let go: off.
	attacks[0] = 0
	var speed := player.get_move_speed()
	_set_action(&"attack", true)
	await _frames(int(player.def.charge_delay * 60.0) - 4)
	check(not player.charge.is_charging(), "charged: not before the delay")
	await _frames(12)
	check(player.charge.is_charging() and player.charge.ratio < 0.5, "charged: held past the delay, it charges")
	check(player.get_move_speed() < speed * 0.8, "charged: the hero is slower while charging (%.0f / %.0f)" % [player.get_move_speed(), speed])
	await _frames(2)
	check(player.charge_vfx.is_showing(), "charged: its gauge is at his feet")
	check(button.charge_ratio > 0.0, "charged: and on the attack button")
	check(VfxLayer.of(player.charge_vfx._ring) == VfxLayer.Layer.GROUND and player.charge_vfx._ring.z_index < 0, "charged: the gauge lies on the floor, under his feet")
	check(player.charge_vfx.get_parent() == player and player.charge_vfx.z_as_relative and player.charge_vfx.z_index == 0, "charged: the glow in his hand is on his body, never over it all")
	check(player.rig.weapon.visible and not player.rig.shows_back_weapon(), "charged: the weapon is held ready in his hand, not on his back")
	player.take_hit(Combat.make_secondary_hit(target, 1))
	check(player.charge.is_charging(), "charged: being hit does not cancel it")
	for i in 90:
		if player.charge.is_full():
			break
		await _frames(1)
	await _frames(1)
	check(player.charge.is_full() and player.charge_vfx.lit_steps() == ChargeVfx.STEPS and button.charge_full, "charged: it fills, the gauge full")
	check(attacks[0] == 1, "charged: holding no longer repeats the attack (%d)" % attacks[0])
	hp_before = target.hp
	_set_action(&"attack", false)
	await _frames(20)
	check(unleashed.size() == 1 and unleashed[0] == katana.charged, "charged: let go full, the katana's charged attack goes off")
	check(target.hp < hp_before, "charged: and hits")
	check(player.charge.state == AttackCharge.State.IDLE and not button.charge_full, "charged: the charge is spent")
	await _frames(20)
	check(not player.charge_vfx.is_showing(), "charged: the gauge goes")

	# A roll cancels it, until the button is let go.
	place.call()
	player.skills._cooldowns[0] = 0.0
	_set_action(&"attack", true)
	await _frames(int(player.def.charge_delay * 60.0) + 10)
	check(player.charge.is_charging(), "charged: charging again")
	_set_action(&"skill_1", true)
	await _frames(2)
	_set_action(&"skill_1", false)
	await _frames(70)
	check(player.charge.state == AttackCharge.State.SPENT and not player.charge.is_charging(), "charged: a roll cancels it")
	_set_action(&"attack", false)
	await _frames(5)
	check(unleashed.size() == 1, "charged: nothing goes off after a roll")

	# A save keeps no charge; the weapon keeps its charged attack.
	_set_action(&"attack", true)
	await _frames(int(player.def.charge_delay * 60.0) + 10)
	var saved := player.save_state()
	check(not JSON.stringify(saved).contains("charge"), "charged: the save has no charge in it")
	player.load_state(saved)
	check(player.charge.state == AttackCharge.State.IDLE and player.get_weapon().charged == katana.charged, "charged: back from a save, no charge, the same charged attack")
	_set_action(&"attack", false)
	await _frames(30)

	# Every hero's weapon: held full, let go, its charged attack hits.
	for file in DirAccess.get_files_at("res://data/items/weapons"):
		if not file.ends_with(".tres"):
			continue
		var weapon: WeaponDef = load("res://data/items/weapons/" + file)
		player.equipment.equip(weapon)
		place.call()
		await _frames(30)
		place.call()
		hp_before = target.hp
		var before := unleashed.size()
		_set_action(&"attack", true)
		for i in 150:
			if player.charge.is_full():
				break
			await _frames(1)
		var full := player.charge.is_full()
		_set_action(&"attack", false)
		await _frames(50)
		check(full and unleashed.size() == before + 1 and unleashed[-1] == weapon.charged, "charged: %s's charged attack goes off" % weapon.id)
		check(target.hp < hp_before, "charged: %s's charged attack hits" % weapon.id)
	player.attacked.disconnect(count_attack)
	player.charged_attack.disconnect(count_charged)

	target.queue_free()
	player.equipment.equip(weapon_before)
	player.perks.load_data(perks_before)
	player.xp = 0
	await _frames(5)


## Melee blows in the body's four directions (Blow, docs/design/builds.md "Blows in four
## directions"), in the game: every melee weapon's blow at an enemy off the cardinals (30 degrees
## up from the right, the diagonals) is struck the way the body faces (the pose, the arc drawn)
## and still hits it; every charged blow too; a thrust's charged streak is drawn on the cardinal; a
## spin keeps the exact aim; a bow's arrow still flies at the exact angle; a skeleton's blow at a
## hero on a diagonal is drawn its body's way and still lands.
func _test_four_directions(game: Game) -> void:
	var player: Player = game.player
	var world: World = game.world
	player.xp = -1000000
	var weapon_before := player.get_weapon()
	var perks_before := player.perks.to_data()
	player.perks.clear()
	await _clear_monsters(world)
	var spot := world.map.cell_to_world(_open_cell_near(world, player.global_position, 4))
	var target := world.spawn_monster(load("res://data/monsters/slime.tres"), spot + Vector2(40, 0))
	target.dormant = true
	target.flies = true
	target.base_stats.max_hp = 100000
	target.invalidate_stats()
	target.hp = 100000
	var place := func(degrees: float, distance: float) -> Vector2:
		target._knockback = Vector2.ZERO
		target.velocity = Vector2.ZERO
		player._knockback = Vector2.ZERO
		player.global_position = spot
		target.global_position = spot + Vector2.from_angle(deg_to_rad(degrees)) * distance
		return spot.direction_to(target.global_position)
	var newest_swing := func() -> SwingVfx:
		var found: SwingVfx = null
		for layer: String in ["Entities", "Effects"]:
			for node in world.get_node(layer).get_children():
				if node is SwingVfx and not node.is_queued_for_deletion():
					found = node
		return found
	var clear_swings := func() -> void:
		for layer: String in ["Entities", "Effects"]:
			for node in world.get_node(layer).get_children():
				if node is SwingVfx or node is SwingMatter:
					node.queue_free()
	for file in DirAccess.get_files_at("res://data/items/weapons"):
		if not file.ends_with(".tres"):
			continue
		var weapon: WeaponDef = load("res://data/items/weapons/" + file)
		if weapon.kind != WeaponDef.Kind.MELEE:
			continue
		player.equipment.equip(weapon)
		await _frames(3)
		# Basic blows, at an enemy 30 degrees up from the right and on the diagonals.
		for degrees: float in [-30.0, 44.0, 136.0, -125.0]:
			var aim: Vector2 = place.call(degrees, player.radius + weapon.reach * 0.7)
			await _frames(1)
			clear_swings.call()
			player._attack_cooldown = 0.0
			var hp_before := target.hp
			player.attack(aim)
			var way := Blow.cardinal(aim)
			var case_name := "%s at %.0f degrees" % [weapon.id, degrees]
			check(player.rig.direction == ActorRig.direction_name(way), "four directions: %s: the body strikes %s" % [case_name, ActorRig.direction_name(way)])
			if weapon.shows_arc():
				var drawn_swing: SwingVfx = newest_swing.call()
				check(drawn_swing != null and absf(angle_difference(float(drawn_swing.material.get_shader_parameter("aim")), way.angle())) < 0.001, "four directions: %s: its arc is drawn %s, the way the body faces (%s)" % [case_name, ActorRig.direction_name(way), str(rad_to_deg(float(drawn_swing.material.get_shader_parameter("aim")))) if drawn_swing else "none"])
			await _frames(2)
			check(target.hp < hp_before, "four directions: %s: the enemy off the cardinal is still hit" % case_name)
			await _frames(int(player.get_attack_cooldown(weapon) * 60.0) + 2)
		# The charged blow, at an enemy 35 degrees down from the right (dashes come back first).
		var charged_aim: Vector2 = place.call(35.0, 40.0)
		await _frames(1)
		clear_swings.call()
		var hp_charged := target.hp
		player.unleash(weapon, weapon.charged)
		await _frames(2)
		var swing: SwingVfx = newest_swing.call()
		var blade := false
		for effect in weapon.charged.effects:
			blade = blade or (effect is DamageAreaEffect and (effect as DamageAreaEffect).follows_facing and (effect as DamageAreaEffect).slash != null and effect.delay <= 0.0) or (effect is DashStrikeEffect and not (effect as DashStrikeEffect).moves)
		if blade:
			check(swing != null and absf(angle_difference(float(swing.material.get_shader_parameter("aim")), Blow.cardinal(charged_aim).angle())) < 0.001, "four directions: %s: its charged blow is drawn the way the body faces" % weapon.id)
		await _frames(50)
		check(target.hp < hp_charged, "four directions: %s: its charged blow still hits an enemy 35 degrees off the cardinal" % weapon.id)
		await _frames(int(player.get_attack_cooldown(weapon) * 60.0) + 2)
	# A spin keeps the exact aim (the axe's wheel), drawn as before.
	player.equipment.equip(load("res://data/items/weapons/axe.tres"))
	await _frames(3)
	var spin_aim: Vector2 = place.call(-30.0, 40.0)
	clear_swings.call()
	player.unleash(player.get_weapon(), player.get_weapon().charged)
	await _frames(1)
	var spin: SwingVfx = newest_swing.call()
	check(spin != null and absf(angle_difference(float(spin.material.get_shader_parameter("aim")), spin_aim.angle())) < 0.001, "four directions: a spin keeps the exact aim")
	await _frames(40)
	# A shot flies at the exact angle.
	player.equipment.equip(load("res://data/items/weapons/bow.tres"))
	await _frames(3)
	var shot_aim: Vector2 = place.call(-30.0, 120.0)
	player._attack_cooldown = 0.0
	var projectiles := world.get_node("Projectiles")
	player.attack(shot_aim)
	await _frames(1)
	var arrow := projectiles.get_child(projectiles.get_child_count() - 1) as Projectile if projectiles.get_child_count() > 0 else null
	check(arrow != null and absf(arrow._direction.angle_to(shot_aim)) < 0.01, "four directions: an arrow still flies at the exact angle (%s)" % (str(rad_to_deg(arrow._direction.angle())) if arrow else "none"))
	await _frames(40)
	target.queue_free()
	# A monster's blow: a skeleton at a hero on a diagonal strikes its body's way, and lands.
	player.equipment.equip(weapon_before)
	player.global_position = spot
	var skeleton := world.spawn_monster(load("res://data/monsters/skeleton.tres"), spot + Vector2.from_angle(deg_to_rad(-140.0)) * 30.0)
	skeleton.dormant = true
	await _frames(3)
	player.global_position = spot
	skeleton.global_position = spot + Vector2.from_angle(deg_to_rad(-140.0)) * 30.0
	clear_swings.call()
	var hero_hp := player.hp
	player._invulnerable_time = 0.0
	var monster_aim := skeleton.global_position.direction_to(player.global_position)
	skeleton._attack_cooldown = 0.0
	skeleton.attack(monster_aim)
	var claw: SwingVfx = newest_swing.call()
	check(claw != null and absf(angle_difference(float(claw.material.get_shader_parameter("aim")), Blow.cardinal(monster_aim).angle())) < 0.001, "four directions: a skeleton's blow at the hero on a diagonal is drawn its body's way")
	await _frames(2)
	check(player.hp < hero_hp, "four directions: and still lands")
	player.hp = player.get_max_hp()
	skeleton.queue_free()
	player.perks.load_data(perks_before)
	player.xp = 0
	await _frames(5)


## The hero's own effects never hide him (docs/vfx.md 2b), in each of 8 directions: his shots
## leave his hand and start behind him going north, in front going south; his arcs and thrusts
## struck north (the pose's direction: Blow) sort behind him, the others are over him; a staff's shot plays no claw over him; his
## weapon's glow while charging goes behind him when his pose faces north; the level up's rings lie on
## the floor, its column stands behind him, only glints rise at his sides in front; Holy Shield's
## halo rises behind him.
func _test_own_effects(game: Game) -> void:
	var player: Player = game.player
	var world: World = game.world
	var weapon_before := player.get_weapon()
	player.xp = -1000000
	await _clear_monsters(world)
	var spot := world.map.cell_to_world(_open_cell_near(world, player.global_position, 4))
	var directions: Array[Vector2] = []
	for i in 8:
		directions.append(Vector2.from_angle(TAU * i / 8.0 - PI * 0.5).snapped(Vector2(0.001, 0.001)))
	var projectiles := world.get_node("Projectiles")
	for id: String in ["stick", "bow", "shuriken"]:
		player.equipment.equip(load("res://data/items/weapons/%s.tres" % id))
		await _frames(2)
		for direction in directions:
			player.global_position = spot
			player._attack_cooldown = 0.0
			var claws := player.rig.get_children().filter(func(n: Node) -> bool: return n is SheetVfx).size()
			player.attack(direction)
			await _frames(1)
			var shot := projectiles.get_child(projectiles.get_child_count() - 1) as Projectile if projectiles.get_child_count() > 0 else null
			var north := VfxLayer.goes_behind(shot._direction if shot else direction)  # a fan's star may turn north
			var case_name := "%s toward (%.1f, %.1f)" % [id, direction.x, direction.y]
			check(shot != null and shot.z_index == (VfxLayer.GROUND_Z if north else 0), "own effects: %s: the shot starts %s him" % [case_name, "behind" if north else "in front of"])
			var start: Vector2 = Vector2.INF
			if shot != null:
				start = shot._trail[0] if not shot._trail.is_empty() else shot.global_position
			check(start.distance_to(player.hand_point(direction) + direction * 6.0) < 12.0, "own effects: %s: it leaves his hand (%s, the hand %s)" % [case_name, start - player.global_position, player.hand_point(direction) - player.global_position])
			check(player.rig.get_children().filter(func(n: Node) -> bool: return n is SheetVfx).size() == claws, "own effects: %s: no claw or burst over him" % case_name)
			for child in projectiles.get_children():
				child.queue_free()
	for id: String in ["katana", "axe", "lance", "rapier"]:
		player.equipment.equip(load("res://data/items/weapons/%s.tres" % id))
		await _frames(2)
		for direction in directions:
			player.global_position = spot
			player._attack_cooldown = 0.0
			player.attack(direction)
			var swings: Array = world.get_node("Entities").get_children().filter(func(n: Node) -> bool: return n is SwingVfx and not n.is_queued_for_deletion())
			swings.append_array(world.get_node("Effects").get_children().filter(func(n: Node) -> bool: return n is SwingVfx and not n.is_queued_for_deletion()))
			var swing: SwingVfx = swings[-1] if not swings.is_empty() else null
			# A blow is struck the way the body faces (Blow): north only when the pose is.
			var north := VfxLayer.goes_behind(Blow.cardinal(direction))
			var case_name := "%s toward (%.1f, %.1f)" % [id, direction.x, direction.y]
			if north:
				check(swing != null and VfxLayer.of(swing) == VfxLayer.Layer.STANDING and swing.global_position.y < player.global_position.y, "own effects: %s: the blow sorts behind him" % case_name)
			else:
				check(swing != null and VfxLayer.of(swing) == VfxLayer.Layer.AIR, "own effects: %s: the blow is in front of him" % case_name)
			for node in swings:
				(node as Node).queue_free()
			await _frames(1)
	# His weapon's glow while charging: behind him facing north, in front facing us.
	player.equipment.equip(load("res://data/items/weapons/katana.tres"))
	player.global_position = spot
	await _frames(2)
	_set_action(&"attack", true)
	await _frames(int(player.def.charge_delay * 60.0) + 6)
	for direction in directions:
		player.facing = direction
		await _frames(2)
		# On the blade held in the body's pose (Blow): behind him when the pose faces north.
		var held := VfxLayer.goes_behind(Blow.cardinal(direction))
		check(VfxLayer.is_behind_body(player.charge_vfx) == held, "own effects: the glow in his hand toward (%.1f, %.1f) is %s him" % [direction.x, direction.y, "behind" if held else "in front of"])
	player.skills._cooldowns[0] = 0.0
	player.use_skill(0)  # a roll: the charge is lost
	_set_action(&"attack", false)
	await _frames(40)

	# The level up: rings on the floor, the column behind him, glints only at his sides.
	player.global_position = spot
	LevelUpVfx.attach(player)
	await _frames(2)
	var level_up: LevelUpVfx = null
	for child in player.get_children():
		if child is LevelUpVfx:
			level_up = child
	check(level_up != null and VfxLayer.is_behind_body(level_up) and level_up.z_as_relative and level_up.z_index == 0, "own effects: the level up's column stands behind the hero (drawn before his sprites, sorted with him)")
	check(level_up != null and VfxLayer.of(level_up._rings) == VfxLayer.Layer.GROUND and level_up._rings.z_index < 0, "own effects: its rings lie on the floor, under his feet")
	check(level_up != null and level_up._glints.z_index > LightField.Z and LevelUpVfx.GLINT_SIDE >= 18.0, "own effects: only a few glints at his sides shine in front, clear of his body (16 wide each side)")
	var shield: SkillDef = load("res://data/skills/player/holy_shield.tres")
	(shield.effects[0] as Effect).apply(player, Vector2.DOWN)
	var aegis := player.get_children().filter(func(n: Node) -> bool: return n is SheetVfx)
	check(not aegis.is_empty() and VfxLayer.is_behind_body(aegis[-1]), "own effects: Holy Shield's halo rises behind the hero")
	await _frames(100)
	player.equipment.equip(weapon_before)
	player.xp = 0
	await _frames(5)


## Elemental attacks (docs/vfx.md, "Elemental attacks"): every attack of a weapon carrying an
## element looks like it, never a steel arc tinted: its arc is in the element's ramp with its
## matter (the shader's `matter`, bits shed by SwingMatter), a hammer's smash bursts in it, a
## bow's arrow flies in it, the charged attack is dressed in it, and the hit lands in it when the
## element is sure to act (an affix's status every hit; a chance rune on the hits it fires on).
## Plain weapons stay steel. Two elements: the first draws the arc, the second adds bits.
func _test_elemental_attacks(game: Game) -> void:
	var player: Player = game.player
	var world: World = game.world
	var weapon_before := player.get_weapon()
	player.xp = -1000000
	var perks_before := player.perks.to_data()
	player.perks.clear()
	await _clear_monsters(world)
	var spot := world.map.cell_to_world(_open_cell_near(world, player.global_position, 4))
	var target := world.spawn_monster(load("res://data/monsters/slime.tres"), spot + Vector2(36, 0))
	target.dormant = true
	target.base_stats.max_hp = 100000
	target.invalidate_stats()
	target.hp = 100000
	var place := func() -> void:
		target._knockback = Vector2.ZERO
		target.global_position = spot + Vector2(36, 0)
		target.statuses.clear()
		player.global_position = spot
	var physical := VfxElementDef.named(&"physical")
	var carried := {
		&"fire": [load("res://data/runes/ember.tres")],
		&"frost": [load("res://data/runes/rime.tres")],
		&"storm": [load("res://data/runes/spark.tres")],
		&"poison": [],
	}
	var affixes := { &"poison": [load("res://data/affixes/venomous.tres")] }
	for id: String in ["katana", "axe", "lance", "hammer", "bow"]:
		var base := load("res://data/items/weapons/%s.tres" % id) as WeaponDef
		for element_id: StringName in [&"physical", &"fire", &"frost", &"storm", &"poison"]:
			var weapon := _imbued(base, carried.get(element_id, []), affixes.get(element_id, []))
			player.equipment.equip(weapon)
			place.call()
			await _frames(2)
			var element := VfxElementDef.named(element_id)
			var case_name := "%s %s" % [element_id, id]
			check(ItemLook.swing_element(weapon, true) == (null if element_id == &"physical" else element), "elemental: a %s swings in its element" % case_name)
			player._attack_cooldown = 0.0
			player.attack(Vector2.RIGHT)
			await _frames(2)
			var made: Array = world.get_node("Effects").get_children() + world.get_node("Entities").get_children()
			if base.kind == WeaponDef.Kind.RANGED:
				var shots := world.get_node("Projectiles").get_children()
				# The hero's own arrow (a trap's bolt or a monster's shot may be in the air too).
				var own := shots.filter(func(n: Node) -> bool: return n is Projectile and (n as Projectile)._shooter == player)
				var shot := own[-1] as Projectile if not own.is_empty() else null
				if element_id == &"physical":
					check(shot != null and shot._rides == null, "elemental: a plain bow's arrow is a plain arrow")
				else:
					check(shot != null and shot._rides == element, "elemental: a %s's arrow flies in it (%d of %d shots his, riding %s, target %d px away)" % [case_name, own.size(), shots.size(), shot._rides.id if shot and shot._rides else &"nothing", roundi(target.global_position.distance_to(player.global_position))])
				for child in shots:
					child.queue_free()
			elif base.shows_arc():
				var swing: SwingVfx = null
				var matter: SwingMatter = null
				for node in made:
					if node is SwingVfx and not node.is_queued_for_deletion():
						swing = node
					if node is SwingMatter and not node.is_queued_for_deletion():
						matter = node
				if element_id == &"physical":
					check(swing != null and swing.element == physical and int(swing.material.get_shader_parameter("matter")) == 0 and matter == null, "elemental: a plain %s swings steel, nothing shed" % id)
				else:
					check(swing != null and swing.element == element, "elemental: a %s's arc is in its ramp (not steel)" % case_name)
					check(swing != null and Color(swing.material.get_shader_parameter("core")) == element.shade(0.0) and int(swing.material.get_shader_parameter("matter")) == SwingVfx.matter_of(element) and SwingVfx.matter_of(element) != 0, "elemental: a %s's arc breaks into its matter" % case_name)
					check(matter != null and matter.bit_count(element) > 0, "elemental: a %s's blow sheds its bits" % case_name)
			else:
				# The War Hammer's smash on the floor: dust and steel sparks, or its element.
				var smashed := made.any(func(n: Node) -> bool: return n is SwingMatter and not n.is_queued_for_deletion())
				if element_id == &"physical":
					check(not smashed, "elemental: a plain hammer's smash sheds no element")
				else:
					check(smashed, "elemental: a %s's smash bursts in it" % case_name)
			for node in made:
				if node is SwingVfx or node is SwingMatter:
					(node as Node).queue_free()
			await _frames(12)
	# The hit lands in the element when it surely acts: a Venomous katana always, an Ember one on
	# the hits that catch (the flash and the burn agree), a plain one never.
	var katana := load("res://data/items/weapons/katana.tres") as WeaponDef
	check(ItemLook.hit_element(katana) == null and ItemLook.hit_element(_imbued(katana, [], [load("res://data/affixes/venomous.tres")])) == VfxElementDef.named(&"poison"), "elemental: a Venomous blade's hits land in poison, a plain one's in nothing")
	player.equipment.equip(_imbued(katana, [load("res://data/runes/ember.tres")], []))
	await _frames(2)
	var agree := 0
	var fire_hits := 0
	for i in 24:
		place.call()
		player._attack_cooldown = 0.0
		player.attack(Vector2.RIGHT)
		await _frames(1)
		var burning := target.statuses.active_ids().has(&"burn")
		var fiery := target.last_hit != null and target.last_hit.element == VfxElementDef.named(&"fire")
		if burning == fiery:
			agree += 1
		if fiery:
			fire_hits += 1
	check(agree == 24 and fire_hits > 0 and fire_hits < 24, "elemental: an Ember katana's hit flashes fire exactly when it sets the target burning (%d of 24 agree, %d fiery)" % [agree, fire_hits])
	# Two elements: the first draws the arc, the second sheds a few bits.
	var both := _imbued(katana, [load("res://data/runes/ember.tres"), load("res://data/runes/rime.tres")], [])
	player.equipment.equip(both)
	place.call()
	await _frames(2)
	player._attack_cooldown = 0.0
	player.attack(Vector2.RIGHT)
	await _frames(2)
	var shed: SwingMatter = null
	for node in world.get_node("Effects").get_children():
		if node is SwingMatter:
			shed = node
	check(shed != null and shed.bit_count(VfxElementDef.named(&"fire")) > shed.bit_count(VfxElementDef.named(&"frost")) and shed.bit_count(VfxElementDef.named(&"frost")) > 0, "elemental: fire and frost: the arc is fire, frost adds a few chips")
	# The charged attack takes what the weapon carries: a fire katana's crescent burns, the Frost
	# Staff's shard stays frost, a plain katana's stays steel.
	var fire_katana := _imbued(katana, [load("res://data/runes/ember.tres")], [])
	var cut := fire_katana.charged.dressed(fire_katana)[0] as DamageAreaEffect
	check(cut.element == VfxElementDef.named(&"fire") and katana.charged.effects[0].get(&"element") == null, "elemental: a fire katana's charged crescent burns (the data stays plain)")
	check(katana.charged.dressed(katana) == katana.charged.effects, "elemental: a plain katana's charged attack is steel")
	var frost_bow := _imbued(load("res://data/items/weapons/bow.tres"), [load("res://data/runes/rime.tres")], [])
	var heavy := frost_bow.charged.dressed(frost_bow)[0] as ProjectileEffect
	check(heavy.look_element == VfxElementDef.named(&"frost") and heavy.element == null, "elemental: a frost bow's heavy arrow flies in rime and stays an arrow")
	var hammer := _imbued(load("res://data/items/weapons/hammer.tres"), [load("res://data/runes/ember.tres")], [])
	var slam := hammer.charged.dressed(hammer)[0] as DamageAreaEffect
	check(slam.element == VfxElementDef.named(&"fire") and slam.second_element == VfxElementDef.named(&"earth"), "elemental: a fire hammer's slam bursts in fire, the ground's earth adding its bits")
	check(fire_katana.charged.element_for(fire_katana) == VfxElementDef.named(&"fire") and katana.charged.element_for(katana) == physical, "elemental: the charge glows in what the weapon carries (steel when plain)")
	await _test_rune_shots(game, place)
	target.queue_free()
	player.equipment.equip(weapon_before)
	player.perks.load_data(perks_before)
	player.xp = 0
	await _frames(5)


## Shots take a rune's element too (docs/vfx.md "Elemental attacks"): a magic weapon's shot stays
## itself with the rune riding it, the weapon's skills shoot in its runes (Volley's arrows ride
## an Ember Rune's flames, Ice Shards carry them), only the look: no hit is forced into the
## element, a weapon's `on_hit` (its basic attack's alone) dresses no skill, monsters' and a
## learned spell's shots stay as written.
func _test_rune_shots(game: Game, place: Callable) -> void:
	var player: Player = game.player
	var world: World = game.world
	var fire := VfxElementDef.named(&"fire")
	var ember: Array = [load("res://data/runes/ember.tres")]
	var shots := world.get_node("Projectiles")
	var fired := func() -> Array:
		return shots.get_children().filter(func(n: Node) -> bool: return n is Projectile and (n as Projectile)._shooter == player and not n.is_queued_for_deletion())
	var clear := func() -> void:
		for child in shots.get_children():
			child.queue_free()
	# A magic weapon's own shot: still a storm spark, the Ember Rune's flames riding it.
	var wand := _imbued(load("res://data/items/weapons/magic_wand.tres"), ember, [])
	player.equipment.equip(wand)
	place.call()
	await _frames(2)
	clear.call()
	player._attack_cooldown = 0.0
	player.attack(Vector2.LEFT)  # away from the target: the shot is still in the air
	await _frames(2)
	var own: Array = fired.call()
	var spark := own[-1] as Projectile if not own.is_empty() else null
	check(spark != null and spark._spec.element == VfxElementDef.named(&"storm") and spark._rides == fire, "rune shots: an Ember Spark Wand's spark stays storm, flames riding it")
	# The weapon's skills: Volley's arrows fly in the Ember Rune, landing in fire only when it burns.
	var cases := [
		["bow", "volley", ember, [], fire, "an Ember bow's Volley flies in fire"],
		["stick", "ice_shards", ember, [], fire, "an Ember Frost Staff's Ice Shards carry flames"],
		["bow", "volley", [], [], null, "a plain bow's Volley stays plain"],
		["bow", "volley", [], [load("res://data/affixes/burning.tres")], null, "a Burning bow's Volley stays plain (on_hit is its basic attack's)"],
	]
	for c: Array in cases:
		var weapon := _imbued(load("res://data/items/weapons/%s.tres" % c[0]), c[2], c[3])
		player.equipment.equip(weapon)
		place.call()
		await _frames(2)
		clear.call()
		var skill := load("res://data/skills/player/%s.tres" % c[1]) as SkillDef
		player.skills.reset_cooldown(skill)
		var used := player.skills.try_use(player.skills.skills.find(skill), player, Vector2.LEFT)  # away from the target
		await _frames(2)
		var arrows: Array = fired.call()
		var riding := arrows.filter(func(n: Projectile) -> bool: return n._rides == c[4])
		var forced := arrows.filter(func(n: Projectile) -> bool: return n._spec.hit_element != null)
		check(used and not arrows.is_empty() and riding.size() == arrows.size() and forced.is_empty(), "rune shots: %s (%d shots, %d riding it, %d forced)" % [c[5], arrows.size(), riding.size(), forced.size()])
		check((skill.effects[0] as ProjectileEffect).look_element == null, "rune shots: %s's data stays as written" % c[1])
	# Not the weapon's: a learned spell, a monster's cast.
	var bow := _imbued(load("res://data/items/weapons/bow.tres"), ember, [])
	var fireball := load("res://data/skills/player/fireball.tres") as SkillDef
	var volley := load("res://data/skills/player/volley.tres") as SkillDef
	player.equipment.equip(bow)
	await _frames(1)
	check(fireball.effects_for(player) == fireball.effects and volley.effects_for(player) != volley.effects, "rune shots: a spell not of the weapon isn't dressed in it")
	clear.call()
	# The skills that are no shot wear the rune too (only the look: their hits as written).
	var frost := VfxElementDef.named(&"frost")
	var spawned := func() -> Array:
		return world.get_node("Effects").get_children() + world.get_node("Entities").get_children()
	var area_cases := [
		["axe", "cleave", null, "an Ember axe's Cleave is a blade's arc in fire"],
		["bow", "arrow_rain", null, "an Ember bow's Arrow Rain falls in fire"],
		["stick", "frost_nova", frost, "an Ember Frost Staff's Frost Nova stays frost, flames riding it"],
		["katana", "dash_strike", null, "an Ember katana's Dash Strike cuts in fire"],
	]
	for c: Array in area_cases:
		var weapon := _imbued(load("res://data/items/weapons/%s.tres" % c[0]), ember, [])
		player.equipment.equip(weapon)
		place.call()
		await _frames(2)
		var skill := load("res://data/skills/player/%s.tres" % c[1]) as SkillDef
		var dressed := skill.effects_for(player)
		var as_written: Array = skill.effects.map(func(e: Effect) -> Variant: return e.get("element"))
		var kept: Array = dressed.map(func(e: Effect) -> Variant: return e.get("element"))
		check(dressed.all(func(e: Effect) -> bool: return e.get("look_element") == fire) and kept == as_written, "rune skills: %s (look %s, its own element kept: %s)" % [c[3], dressed.map(func(e: Effect) -> Variant: return e.get("look_element")), kept])
		check(skill.effects.all(func(e: Effect) -> bool: return e.get("look_element") == null), "rune skills: %s's data stays as written" % c[1])
		var before: Array = spawned.call()
		player.skills.reset_cooldown(skill)
		player.skills.try_use(player.skills.skills.find(skill), player, Vector2.LEFT)
		await _frames(int(dressed.map(func(e: Effect) -> float: return e.delay).max() * 60.0) + 3)
		var drawn: Array = (spawned.call() as Array).filter(func(n: Node) -> bool: return not before.has(n) and is_instance_valid(n) and n.get("element") == fire)
		check(not drawn.is_empty(), "rune skills: %s, seen (%s)" % [c[3], drawn.map(func(n: Node) -> String: return n.get_class() if n.get_script() == null else String((n.get_script() as Script).get_global_name()))])
		if c[2] != null:
			var own_drawn: Array = (spawned.call() as Array).filter(func(n: Node) -> bool: return not before.has(n) and is_instance_valid(n) and n.get("element") == c[2])
			check(not own_drawn.is_empty(), "rune skills: %s, its own element still drawn" % c[1])
		await _frames(30)
	clear.call()
	player.equipment.equip(load("res://data/items/weapons/katana.tres"))
	await _frames(2)
func _imbued(base: WeaponDef, runes: Array, affixes: Array) -> WeaponDef:
	var weapon := base.duplicate() as WeaponDef
	weapon.base_item = base
	weapon.rarity = ItemRarity.EPIC
	var sockets: Array[RuneDef] = []
	for rune in runes:
		sockets.append(rune)
	weapon.runes = sockets
	var rolled: Array[ItemAffixDef] = []
	for affix in affixes:
		rolled.append(affix)
		if affix.on_hit and weapon.on_hit == null:
			weapon.on_hit = affix.on_hit
	weapon.affixes = rolled
	return weapon


## Shields, thieves, summoners and bombers.
func _test_monster_behaviours(game: Game) -> void:
	var player: Player = game.player
	var world: World = game.world
	var acts: Array = []
	for act in CONTENT.dungeon.acts:
		for m: MonsterDef in act.monsters:
			acts.append(m.id)
	for id in [&"shell_guard", &"thief_racoon", &"brood_mother", &"bomber", &"sand_drake"]:
		check(acts.has(id), "%s roams the Well" % id)

	# The wyrms: a body follows the head's path, burns at a touch, only the head takes hits.
	var bosses: Array = []
	for act in CONTENT.dungeon.acts:
		bosses.append_array(act.all_bosses().map(func(b: BossDef) -> StringName: return b.id))
	check(bosses.has(&"jade_wyrm") and bosses.has(&"azure_wyrm"), "the two wyrms guard acts")
	var wyrm := world.spawn_monster(load("res://data/monsters/bosses/jade_wyrm.tres"), world.map.cell_to_world(_open_cell_near(world, player.global_position, 3)))
	wyrm.dormant = true
	await _frames(2)
	var bodies := wyrm.get_children().filter(func(n: Node) -> bool: return n is WyrmBody)
	check(bodies.size() == 1, "a wyrm has a body")
	var body: WyrmBody = bodies[0]
	var start: Vector2 = body._points[0]
	for i in 30:
		wyrm.global_position += Vector2(4, 0)
		await _frames(1)
	check(body._points[0] != start and body._points[0].distance_to(wyrm.global_position) < 60.0, "the body follows the head")
	wyrm.dormant = false
	wyrm.skills.set_skills([] as Array[SkillDef])
	wyrm._attack_cooldown = 99.0
	wyrm.target = null
	player.hp = player.get_max_hp()
	player.ward = 0  # a Guardian Ring taken earlier would soak it
	var hp_before := player.hp
	var keep_at := wyrm.global_position
	for i in 3:
		player._invulnerable_time = 0.0
		player.global_position = body._points[3]
		wyrm.global_position = keep_at
		await _frames(1)
	check(player.hp < hp_before, "touching the body burns")
	wyrm.queue_free()
	player.hp = player.get_max_hp()
	await _frames(2)

	# Shell Guard: hits from the front are mostly blocked, hits in the back land in full.
	var shell := world.spawn_monster(load("res://data/monsters/shell_guard.tres"), world.map.cell_to_world(_open_cell_near(world, player.global_position, 2)))
	shell.dormant = true
	await _frames(2)
	var lost := []
	var guard := shell.get_trait(GuardTrait) as GuardTrait
	check(guard != null, "the Shell Guard has a shield (GuardTrait)")
	for push: Vector2 in [Vector2.LEFT, Vector2.RIGHT]:
		shell.facing = Vector2.RIGHT
		guard.set_direction(shell, Vector2.RIGHT)
		shell._invulnerable_time = 0.0
		shell.hp = shell.get_max_hp()
		var hit := HitInfo.new()
		hit.amount = 20
		hit.knockback = push * 100.0  # pushed left = struck from the right, where the shell is
		shell.take_hit(hit)
		lost.append(shell.get_max_hp() - shell.hp)
	check(lost[0] * 3 < lost[1], "the shell blocks blows from the front (%d vs %d from behind)" % lost)
	var burn := Combat.make_secondary_hit(null, 10)
	shell.hp = shell.get_max_hp()
	shell.take_hit(burn)
	check(shell.get_max_hp() - shell.hp == Combat.mitigate(10, shell.get_stats().defense), "burns and blasts go around the shell")
	shell.queue_free()

	# Thief: grabs gold, runs, gives it back with interest when slain.
	var thief := world.spawn_monster(load("res://data/monsters/thief_racoon.tres"), world.map.cell_to_world(_open_cell_near(world, player.global_position, 2)))
	await _frames(2)
	player.gold = 60
	player.hp = player.get_max_hp()
	player._invulnerable_time = 0.0
	player.take_hit(Combat.make_hit(1, 0.0, thief))
	var thievery := thief.get_trait(ThiefTrait) as ThiefTrait
	check(player.gold < 60 and thievery.stolen(thief) == 60 - player.gold, "the thief steals gold (%d)" % thievery.stolen(thief))
	check(not thief.can_attack(), "and runs instead of fighting")
	var stolen := thievery.stolen(thief)
	thief.die(player)
	await _frames(3)
	var dropped := 0
	for node in world.get_node("Entities").get_children():
		if node is GoldPickup:
			dropped += (node as GoldPickup).amount
	check(dropped + player.gold - (60 - stolen) > stolen, "slaying it gives the gold back, and more (%d)" % dropped)

	# Brood Mother lays spiders (on a floor with room for them: SummonEffect.max_alive).
	await _clear_monsters(world)
	var mother := world.spawn_monster(load("res://data/monsters/brood_mother.tres"), world.map.cell_to_world(_open_cell_near(world, player.global_position, 2)))
	mother.dormant = true
	await _frames(2)
	var before := _count_monsters(world, &"spider")
	mother.skills.try_use(0, mother, Vector2.RIGHT)
	await _frames(2)
	check(_count_monsters(world, &"spider") == before + 2, "the Brood Mother lays spiders")
	for m in world.get_hostiles(Actor.Faction.PLAYER):
		if m is Monster and (m.def.id == &"spider" or m == mother):
			m.queue_free()

	# Sapper: lobbed bombs blow up.
	var bomber: MonsterDef = load("res://data/monsters/bomber.tres")
	var throw := bomber.skills[0].effects[0] as ProjectileEffect
	check(throw != null and throw.explosion_radius > 0.0 and bomber.keep_distance > 0.0, "the Sapper keeps away and throws bombs that explode")
	await _frames(2)


## Regressions found by the code review.
func _test_review_fixes(game: Game) -> void:
	var player: Player = game.player
	var world: World = game.world
	await _clear_monsters(world)
	player.hp = player.get_max_hp()
	player.ward = 0  # a Guardian Ring taken earlier would soak the burn
	while game.perk_panel.visible:  # a level up waiting would keep the game paused
		game.perk_panel.choose(0)
		await _frames(2)

	# A burn tick doesn't make the hero invulnerable (or monsters' hits would be swallowed).
	player._invulnerable_time = 0.0
	player.statuses.apply_dot(&"burn", 1, 0.1, 0.5, null, Color.ORANGE)
	await _frames(9)
	check(player.hp < player.get_max_hp() and player._invulnerable_time == 0.0, "burn ticks give no invulnerability frames")
	player.statuses.clear()
	player.hp = player.get_max_hp()

	# Slows: a frost hit wears off even while the cold keeps slowing a little.
	player.statuses.apply_slow(0.6, 0.2)
	for i in 30:
		player.statuses.apply_slow(0.1, 0.2, &"cold")
		await get_tree().physics_frame
	check(is_equal_approx(player.statuses.speed_multiplier(), 0.9), "a frost hit wears off under a lasting slow (%.2f)" % player.statuses.speed_multiplier())
	player.statuses.clear()

	# The same buff twice refreshes instead of stacking.
	var rage := StatBlock.new()
	rage.attack = 5
	var attack_before := player.get_stats().attack
	player.add_timed_bonus(rage, 1.0)
	player.add_timed_bonus(rage, 1.0)
	check(player.get_stats().attack == attack_before + 5, "a second elixir refreshes the first")

	# Shields know where a dash strike comes from (its knockback goes sideways).
	var shell := world.spawn_monster(load("res://data/monsters/shell_guard.tres"), world.map.cell_to_world(_open_cell_near(world, player.global_position, 2)))
	shell.dormant = true
	await _frames(2)
	shell.facing = Vector2.RIGHT
	(shell.get_trait(GuardTrait) as GuardTrait).set_direction(shell, Vector2.RIGHT)
	var dash := HitInfo.new()
	dash.amount = 20
	dash.knockback = Vector2.UP * 100.0
	dash.origin = shell.global_position + Vector2.RIGHT * 60.0
	var hp_before := shell.hp
	shell.take_hit(dash)
	check(hp_before - shell.hp <= 5, "the shell blocks a dash strike from the front (%d)" % (hp_before - shell.hp))
	shell.queue_free()

	# Summoned monsters give nothing (no farming a summoner).
	var summon := SummonEffect.new()
	summon.monsters = [load("res://data/monsters/slime.tres")]
	summon.count = 1
	summon.apply(player, Vector2.RIGHT)
	var minion: Monster = null
	for m in world.get_hostiles(Actor.Faction.PLAYER):
		if (m as Monster).summoned:
			minion = m
	check(minion != null, "summons are marked")
	if minion:
		var xp_before := player.xp
		var level_before := player.level
		minion.die(player)
		check(player.xp == xp_before and player.level == level_before, "a summoned monster gives no XP")
	await _frames(2)

	# No XP for a dead hero (a kill landing after the hero's death would heal him to full).
	var dead_xp := player.xp
	player.is_dead = true
	player.gain_xp(99999)
	check(player.xp == dead_xp, "a dead hero gains nothing")
	player.is_dead = false

	# Saves: written in one step, and a half-written file never replaces a good one.
	var path := "user://test_safe_%d.json" % OS.get_process_id()
	check(SafeFile.write_json(path, {"a": 1}) and SafeFile.read_json(path).a == 1.0, "safe save round trip")
	var cut := FileAccess.open(path, FileAccess.WRITE)
	cut.store_string("{\"a\": ")
	cut.close()
	var temp := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	temp.store_string("{\"a\": 2}")
	temp.close()
	check(SafeFile.read_json(path) != null and SafeFile.read_json(path).a == 2.0, "a damaged save falls back on the last full write")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))

	# Taking the stairs: no menu, no second descent until the next floor is there.
	var depth_before: int = game.depth
	game._on_stairs_reached()
	game._on_stairs_reached()
	check(game.is_menu_open() and game.depth == depth_before, "during the descent: no menus, and the depth changes only on arrival")
	game.open_pause_menu()
	check(not game.pause_menu.visible, "the pause menu can't open in the middle of the stairs")
	for i in 120:
		if not game._transitioning:
			break
		await _frames(1)
	check(game.depth == depth_before + 1 and not get_tree().paused, "one floor down, game running (depth %d)" % game.depth)
	await _frames(5)


## What isn't seen sleeps; monsters spot the hero further on harder difficulties; they walk
## around what their body can't cross and get unstuck; they find the hero from the next room.
func _test_ai_movement(game: Game) -> void:
	var world: World = game.world
	var player: Player = game.player
	player.invincible = true
	await _clear_monsters(world)
	var rat_def: MonsterDef = load("res://data/monsters/rat.tres")

	# Sleep and wake.
	var far_room := world.map.rooms[0]
	var far_distance := 0.0
	for room in world.map.rooms:
		var d := world.map.cell_to_world(room.get_center()).distance_to(player.global_position)
		if d > far_distance:
			far_distance = d
			far_room = room
	var sleeper := world.spawn_monster(rat_def, _solid_point_in(world, far_room))
	var near := world.spawn_monster(rat_def, player.global_position + Vector2(120, 0))
	await _frames(20)
	check(far_distance > 1200.0, "a room far off screen (%d px)" % far_distance)
	check(not sleeper.is_awake and sleeper.process_mode == Node.PROCESS_MODE_DISABLED, "a monster far off screen sleeps")
	check(near.is_awake and world.activity.awake.has(near) and not world.activity.awake.has(sleeper), "one in view thinks")
	var spot := sleeper.global_position
	await _frames(30)
	check(sleeper.global_position == spot, "a sleeping monster doesn't move")
	var hit := HitInfo.new()
	hit.amount = 1
	hit.source = player
	sleeper.take_hit(hit)
	check(sleeper.is_awake, "hit from afar, it wakes up")
	await _frames(20)
	check(sleeper.is_awake and sleeper.target == player, "and stays awake while it hunts")
	await _clear_monsters(world)

	# Further on harder difficulties.
	var before := world.difficulty
	world.difficulty = CONTENT.get_difficulty(&"easy")
	world.rules = FloorRules.make(CONTENT.dungeon, world.difficulty, null, world.depth)
	var easy_rat := world.spawn_monster(rat_def, player.global_position + Vector2(80, 0))
	world.difficulty = CONTENT.get_difficulty(&"nightmare")
	world.rules = FloorRules.make(CONTENT.dungeon, world.difficulty, null, world.depth)
	var nightmare_rat := world.spawn_monster(rat_def, player.global_position + Vector2(80, 0))
	check(nightmare_rat.detect_radius() > rat_def.detect_radius and easy_rat.detect_radius() < rat_def.detect_radius, "monsters spot the hero from further on Nightmare (%d), closer on Easy (%d)" % [nightmare_rat.detect_radius(), easy_rat.detect_radius()])
	world.difficulty = before
	world.rules = FloorRules.make(CONTENT.dungeon, before, world.floor_event, world.depth, world.curse)
	await _clear_monsters(world)

	# A clear walk: open floor yes; a blocked cell (a pond, a hole, a prop) on the way, no.
	var cell := _open_cell_near(world, player.global_position, 3)
	var walker := world.spawn_monster(rat_def, world.map.cell_to_world(cell))
	walker.get_node("StateMachine").process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(2)
	var ahead := world.map.cell_to_world(cell + Vector2i(3, 0))
	check(walker.has_clear_walk(ahead), "a clear walk on open floor")
	world.set_cell_blocked(cell + Vector2i(2, 0), true)
	walker.steering.forget_walks()
	check(not walker.has_clear_walk(ahead), "not across a blocked cell, even in sight")
	world.set_cell_blocked(cell + Vector2i(2, 0), false)
	walker.steering.forget_walks()
	var other_side := world.map.cell_to_world(cell) + Vector2(0, -2000)
	check(not walker.has_clear_walk(other_side), "nor through walls (from %s at cell %s to %s, map %dx%d, its cell a floor %s)" % [walker.global_position, world.map.world_to_cell(walker.global_position), other_side, world.map.width, world.map.height, world.map.is_floor(world.map.world_to_cell(walker.global_position))])

	# Walking into a wall: stuck.
	# (The wall with the most open floor behind it, so walking away really goes somewhere. The rat
	# is put down by it: that spot must be free and fit its body, or it starts inside a prop along
	# the wall, or a wall's shape reaching into the cell, and can't get out at all.)
	var wall_dir := Vector2.ZERO
	var best_room := -1
	for dir: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var c := cell
		var steps := 0
		while world.map.is_floor(c) and steps < 40:
			c += dir
			steps += 1
		if world.map.is_floor(c) or not world.is_free_cell(c - dir) or not _body_fits(world, world.map.cell_to_world(c - dir), walker.radius):
			continue
		var room := 0
		while room < 12 and world.map.is_floor(c - dir * (room + 2)) and not world.nav.is_blocked(c - dir * (room + 2)):
			room += 1
		if room > best_room:
			best_room = room
			wall_dir = Vector2(dir)
			walker.global_position = world.map.cell_to_world(c - dir)
	# The hero out of its way back: the free cells counted above say nothing of bodies, and the
	# rat walking away into him would not move at all.
	var tile := float(world.map.tile_size)
	var lane_from := walker.global_position
	var lane_to := lane_from - wall_dir * tile * (best_room + 1)
	var off_lane := func(point: Vector2) -> float:
		return Geometry2D.get_closest_point_to_segment(point, lane_from, lane_to).distance_to(point)
	if off_lane.call(player.global_position) < tile * 2.0:
		for point in _free_points_away(world, lane_from, 3, 10, 30):
			if off_lane.call(point) >= tile * 3.0:
				player.global_position = point
				break
	await _frames(1)
	walker.target = player  # (hunting: it stays awake wherever it stands)
	walker.move_direction = wall_dir
	await _frames(40)
	check(best_room >= 0, "a wall to walk into, with room for the rat by it")
	check(walker.is_stuck(), "walking into a wall for a moment: stuck")
	walker.move_direction = -wall_dir
	var stuck_at := walker.global_position
	for i in 120:  # (a prop or a pond a few steps back may slow it a moment)
		walker.target = player
		await _frames(1)
		if not walker.is_stuck():
			break
	var blocker := walker.move_and_collide(-wall_dir * 8.0, true)  # (test only: what it bumps into)
	var blocked_by := "nothing" if blocker == null else "%s (%s) at %s" % [blocker.get_collider(), (blocker.get_collider() as Node).get_parent() if blocker.get_collider() is Node else null, blocker.get_position()]
	check(not walker.is_stuck(), "walking away: not stuck any more (moved %d px, %d free cells behind, awake %s, hero %d px off its way, blocked by %s, wall %s)" % [walker.global_position.distance_to(stuck_at), best_room, world.activity.awake.has(walker), roundi(off_lane.call(player.global_position)), blocked_by, wall_dir])
	await _clear_monsters(world)

	# From another room, out of sight, around the walls: it finds the hero.
	# (The room whose walk is closest to 600 px: layouts change with the data, so no fixed window.
	# Some floors have none from where the hero stands: then the hero waits in another room.)
	var hunter_spot := Vector2.INF
	var hero_spots: Array[Vector2] = [player.global_position]
	for room in world.map.rooms:
		hero_spots.append(_solid_point_in(world, room))
	for hero_spot in hero_spots:
		var best_gap := INF
		for room in world.map.rooms:
			var candidate := _solid_point_in(world, room)
			if world.has_line_of_sight(candidate, hero_spot):
				continue
			var path := world.find_path(candidate, hero_spot)
			var length := 0.0
			for k in range(1, path.size()):
				length += path[k - 1].distance_to(path[k])
			if length >= 250.0 and length <= 1500.0 and absf(length - 600.0) < best_gap:
				best_gap = absf(length - 600.0)
				hunter_spot = candidate
		if hunter_spot != Vector2.INF:
			player.global_position = hero_spot
			player.velocity = Vector2.ZERO
			await _frames(2)
			break
	check(hunter_spot != Vector2.INF, "a room out of sight, a short walk away")
	if hunter_spot != Vector2.INF:
		var hunter := world.spawn_monster(rat_def, hunter_spot)
		hunter.get_node("StateMachine").transition_to(&"Chase")
		var reached := false
		var closest := INF
		for i in 60 * 12:
			hunter.target = player  # (it knows where the hero is: a hunt, not a search)
			await _frames(1)
			if not is_instance_valid(hunter) or hunter.is_dead:
				break
			var d := hunter.global_position.distance_to(player.global_position)
			closest = minf(closest, d)
			if d <= hunter.attack_range(player) + 24.0:
				reached = true
				break
		check(reached, "a monster finds its way to the hero around the walls (closest %d px)" % closest)
	await _clear_monsters(world)
	player.invincible = false



## The trial of the Threshold: a killing blow with a second life pulls the hero into the limbo
## while his floor waits out of the tree; won, he is back on the very spot with the floor as it
## was. Each feather opens one trial.
func _test_threshold(game: Game, world: World, player: Player) -> void:
	var threshold := game.threshold
	var feather := _perk("phoenix_feather")
	var trial := (feather.passives[0] as CheatDeathPassive).trial
	check(trial != null, "the Phoenix Feather opens the trial of the Threshold")
	await _clear_monsters(world)
	player.perks.clear()
	player.hp = player.get_max_hp()
	player.perks.add(feather)
	# He comes back on the very spot he stood when the floor froze (a frame after the blow): at
	# rest, that is where he fell. With a blast around him (CheatDeathPassive, 110 px) that
	# breaks props: none in its reach, so the floor is as it was.
	player.global_position = _point_without_props(world, player.global_position, 110.0)
	await _stand_still(world, player)
	# Two monsters wait on the floor, out of the blast's reach; one is hurt and burning.
	var skeleton: MonsterDef = load("res://data/monsters/skeleton.tres")
	var watchers: Array[Monster] = []
	for spot in _free_points_away(world, player.global_position, 6, 10, 2):
		var watcher := world.spawn_monster(skeleton, spot)
		watcher.dormant = true
		watchers.append(watcher)
	check(watchers.size() == 2, "two monsters to watch over")
	if watchers.size() < 2:
		return
	await _frames(1)
	watchers[0].hp -= 3
	watchers[0].statuses.apply_dot(&"burn", 1, 0.5, 30.0, player, Palette.FIRE)
	player.statuses.apply_dot(&"poison", 1, 0.5, 30.0, null, Color(0.5, 0.9, 0.6))
	game._save_run()
	var saved := RunSave.read()
	var floor_mode := world.process_mode
	var fell_at := player.global_position
	var floor_things := _floor_things(world)
	_killing_blow(player, watchers[1])
	check(not player.is_dead and threshold.is_open(), "a killing blow with a second life opens the Threshold")
	await get_tree().process_frame
	check(world.process_mode == Node.PROCESS_MODE_DISABLED, "the floor stops where it is")
	var frozen_at: Array[Vector2] = [watchers[0].global_position, watchers[1].global_position]
	var hp_then: Array[int] = [watchers[0].hp, watchers[1].hp]
	var burn_left: float = watchers[0].statuses._dots[0].time_left
	var clock := game.run.time
	check(await _until_trial(game), "the veil lifts on the trial")
	var limbo := threshold.limbo
	check(limbo != null and player.world == limbo and limbo.is_ancestor_of(player), "the hero is in the limbo")
	check(not world.is_inside_tree() and game.world == world, "his floor waits, out of the tree")
	check(player.hp == maxi(1, roundi(player.get_max_hp() * trial.hero_health)), "he fights at %d%% of his Health" % roundi(trial.hero_health * 100.0))
	check(player.statuses.is_empty(), "his statuses stay behind")
	check(threshold.needed == trial.kills_for(world.depth, CONTENT.dungeon) and threshold.time_left <= trial.time_for(world.depth, CONTENT.dungeon), "the rules of his act: %d spectres, %d s" % [threshold.needed, roundi(threshold.time_limit)])
	var spectres := limbo.get_hostiles(Actor.Faction.PLAYER)
	check(not spectres.is_empty(), "spectres rise")
	if not spectres.is_empty():
		var spectre := spectres[0] as Monster
		check(spectre.summoned and spectre.modulate.a < 1.0 and (spectre.rig == null or spectre.rig.pallor > 0.0), "pale, see-through and worth nothing (no XP, gold or loot)")
		check(spectre.target == player, "and they come for him")
	check((game.hud.get_node("ThresholdHud") as Control).visible and not (game.hud.get_node("%Minimap") as Control).visible, "the HUD shows the trial, not the floor's map")
	check(not (game.hud.get_node("%BagButton") as Control).visible, "no bag button in there")
	game._save_run()
	check(RunSave.read() == saved, "nothing is saved during the trial")
	game.open_inventory()
	check(not game.inventory_panel.visible, "the bag stays shut in the Threshold")
	await _frames(30)
	check(game.run.time > clock + 0.3, "the run's clock keeps counting")
	check(watchers[0].global_position == frozen_at[0] and watchers[1].global_position == frozen_at[1], "the floor's monsters wait where they stood")
	# Won: home, as if nothing had moved.
	var home := {}
	threshold.closed.connect(func(won: bool) -> void:
		home.won = won
		home.at = [watchers[0].global_position, watchers[1].global_position]
		home.hp = [watchers[0].hp, watchers[1].hp]
		home.burn = watchers[0].statuses._dots[0].time_left if watchers[0].statuses.has(&"burn") else -1.0, CONNECT_ONE_SHOT)
	check(await _win_trial(game) and home.get("won", false), "slaying them all wins the trial")
	check(player.world == world and world.is_inside_tree() and world.process_mode == floor_mode, "the hero is back on his floor, and it runs again")
	check(player.global_position == fell_at and player.get_parent() == world.get_node("Entities"), "on the very spot he fell (%.1f px away)" % player.global_position.distance_to(fell_at))
	check(home.get("at", []) == frozen_at and home.get("hp", []) == hp_then, "the floor's monsters as they were (same place, same Health)")
	check(is_equal_approx(float(home.get("burn", -1.0)), burn_left), "their statuses too (%.2f s of burn left)" % float(home.get("burn", -1.0)))
	var floor_changes := _things_diff(floor_things, _floor_things(world))
	check(floor_changes.is_empty(), "nothing came or went on the floor %s" % floor_changes)
	check(not player.is_dead and player.hp == roundi(player.get_max_hp() * (feather.passives[0] as CheatDeathPassive).heal_ratio), "back at half Health")
	check(player._invulnerable_time > 0.0, "with a moment of grace")
	check(threshold.limbo == null and (game.hud.get_node("%Minimap") as Control).visible and not (game.hud.get_node("ThresholdHud") as Control).visible, "the limbo is gone, the HUD is the floor's again")
	check(Profile.stat_value("thresholds") >= 1 and Profile.is_achieved(&"not_yet"), "it counts (the Not Yet achievement)")
	await _frames(2)
	check(not is_instance_valid(limbo), "the limbo is freed")
	# The feather is spent: one trial per stack.
	var entry := player.perks.get_entry(feather)
	check(not (feather.passives[0] as CheatDeathPassive).prevent_death(player, entry) and not threshold.is_open(), "a spent feather opens no trial (once per stack)")
	player.perks.add(feather)
	_killing_blow(player, watchers[0])
	check(threshold.is_open() and player.perks.get_entry(feather).memory.get(&"used", 0) == 2, "a second feather, a second trial")
	check(await _until_trial(game) and await _win_trial(game) and not player.is_dead, "won again")
	for watcher in watchers:
		watcher.die(null)
	player.perks.clear()
	player.hp = player.get_max_hp()
	await _frames(5)


## The trial lost: the hero dies for real, back where he fell, of what slew him the first time.
## Slain in there (a second feather doesn't help), or the knell tolls first; or he gives up in
## there (pause menu): his floor comes back all the same.
func _test_threshold_lost(game: Game) -> void:
	var skeleton: MonsterDef = load("res://data/monsters/skeleton.tres")
	for how in ["slain inside", "the knell tolled", "gave up"]:
		game.start_run()
		await _frames(5)
		var player := game.player
		var world := game.world
		var feather := _perk("phoenix_feather")
		player.perks.add(feather)
		# The blow lands at the top of a physics step, and the hero still takes that step before the
		# floor freezes (Threshold._enter is deferred): a monster bumping him, a trap's knockback or a
		# leftover push would carry him off the spot he fell on. Alone, at rest, on quiet floor.
		await _clear_monsters(world)
		player.global_position = _quiet_point(world, player.global_position, 2, 10)
		await _stand_still(world, player)
		var killer := world.spawn_monster(skeleton, _free_points_away(world, player.global_position, 6, 10, 1)[0])
		killer.dormant = true
		var fell_at := player.global_position
		_killing_blow(player, killer)
		check(await _until_trial(game), "the trial opens")
		match how:
			"the knell tolled":
				game.threshold.time_left = 0.05
			"gave up":
				player.give_up()
			_:
				player.perks.add(feather)  # a second feather: no help in there
				var spectre := game.threshold.limbo.get_hostiles(Actor.Faction.PLAYER)[0]
				_killing_blow(player, spectre)
				check(not player.is_dead and game.threshold.state == Threshold.State.LEAVING, "slain in the Threshold, the trial is lost")
				check(player.perks.get_entry(feather).memory.get(&"used", 0) == 1, "no second feather spent in there")
		check(await _until_home(game), "the hero is taken back (%s)" % how)
		check(player.is_dead, "the trial lost (%s), he dies for real" % how)
		var cause := tr("giving up") if how == "gave up" else killer.display_name
		check(player.killed_by == cause, "of what slew him (%s)" % player.killed_by)
		check(player.world == world and world.is_inside_tree() and player.global_position == fell_at, "where he fell (%s: %s, fell at %s)" % [how, player.global_position, fell_at])
		check(game.threshold.limbo == null and world.process_mode != Node.PROCESS_MODE_DISABLED, "the limbo is gone, the floor runs")
		await _until(func() -> bool: return game.game_over_panel.visible)  # (the end screen comes a moment after the blow, under the hit stop)
		check(game.game_over_panel.visible and not RunSave.exists(), "the run ends")
