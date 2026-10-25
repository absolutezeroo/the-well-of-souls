class_name EncounterOutcome
extends Resource
## What happens after a choice. Everything is optional and adds up.

enum Gift { NONE, PERK, RELIC }

@export_range(0, 100) var weight: int = 10
@export_multiline var text: String = ""
@export var color: Color = Color.WHITE
## Fractions of the hero's max HP healed / lost.
@export_range(0.0, 1.0, 0.05) var heal_ratio: float = 0.0
@export_range(0.0, 1.0, 0.05) var damage_ratio: float = 0.0
@export var gold: int = 0
## Greater than 0: an item drops, rolled with this quality (see LootRoller).
@export var item_quality: float = 0.0
## A choice of perks (or of relics) right after.
@export var gift: Gift = Gift.NONE
## Monsters of the act appearing around the hero.
@export_range(0, 6) var monsters: int = 0
@export var elite_monsters: bool = false
## Anything else (buffs...), applied to the hero.
@export var effects: Array[Effect] = []


func apply(player: Player, at: Vector2) -> void:
	var world := player.world
	if heal_ratio > 0.0:
		player.heal(roundi(player.get_max_hp() * heal_ratio))
		Vfx.magic(world, player.global_position, Palette.HEAL)
	if damage_ratio > 0.0:
		var price := Combat.make_secondary_hit(null, roundi(player.get_max_hp() * damage_ratio))
		price.cause = &"altar"
		price.unavoidable = true
		player.take_hit(price)
	if gold > 0:
		world.spawn_gold(at, gold)
	if item_quality > 0.0:
		var item := world.pick_random_item()
		for attempt in 10:
			if item is EquipmentDef:
				break
			item = world.pick_random_item()
		if item:
			world.spawn_loot(item, at + Vector2(0, 28), item_quality)
	match gift:
		Gift.PERK:
			Events.perk_offer_requested.emit(PerkDef.Rarity.COMMON, "A boon", "Choose an upgrade")  # i18n
		Gift.RELIC:
			Events.perk_offer_requested.emit(PerkDef.Rarity.RARE, "Relic", "Choose a relic")  # i18n
	if monsters > 0:
		# Next frame (not while the encounter's panel is answered). Weak references: the hero or
		# the floor may be gone by then (conventions.md, "Lambdas that run later").
		_spawn_monsters.call_deferred(weakref(world), weakref(player), at)
	Effect.apply_all(effects, player, Vector2.DOWN)


## The monsters it calls, around `at`, going for the hero.
func _spawn_monsters(world_ref: WeakRef, player_ref: WeakRef, at: Vector2) -> void:
	var world := world_ref.get_ref() as World
	var player := player_ref.get_ref() as Player
	if world == null or player == null:
		return
	for i in monsters:
		var def := world.pick_monster()
		if def == null:
			return
		var monster := world.spawn_monster(def, world.find_open_point_near(at, 60.0, WorldSpace.room_for(def)))
		if elite_monsters:
			world.make_elite(monster)
		monster.target = player
		Vfx.puff(world, monster.global_position)


## Bad for the hero (hurt, monsters, or nothing for what was paid): shown in red before choosing.
func is_bad() -> bool:
	var good := heal_ratio > 0.0 or gold > 0 or item_quality > 0.0 or gift != Gift.NONE or not effects.is_empty()
	return damage_ratio > 0.0 or monsters > 0 or not good


## What it does, in plain words, before choosing: "Heals you fully", "An item (12% chance it is
## Rare or Epic)", "2 elite monsters appear and attack"... `paid`: the choice cost something.
func summary(player: Player, paid: bool = false) -> String:
	var parts := PackedStringArray()
	var max_hp := player.get_max_hp()
	if heal_ratio >= 1.0:
		parts.append(tr("heals you fully"))
	elif heal_ratio > 0.0:
		parts.append(tr("heals %d health") % roundi(max_hp * heal_ratio))
	if damage_ratio > 0.0:
		parts.append(tr("hurts you: you lose %d health") % roundi(max_hp * damage_ratio))
	if gold > 0:
		parts.append(tr("%d gold") % (player.world.rules.floor_gold(gold) if player.world and player.world.rules else gold))
	if item_quality > 0.0:
		parts.append(_item_words(player))
	match gift:
		Gift.PERK:
			parts.append(tr("a free perk: choose 1 of 3"))
		Gift.RELIC:
			parts.append(tr("a relic: choose 1 of 3 strong perks, like after a boss"))
	if monsters > 0:
		var appear := ""
		if elite_monsters:
			appear = tr("%d elite monsters appear and attack") if monsters > 1 else tr("%d elite monster appears and attacks")
		else:
			appear = tr("%d monsters appear and attack") if monsters > 1 else tr("%d monster appears and attacks")
		parts.append(appear % monsters)
	for effect in effects:
		var buff := effect as BuffEffect
		if buff and buff.bonuses:
			parts.append(tr("for %d seconds: %s") % [roundi(buff.duration), buff.bonuses.describe()])
	if parts.is_empty():
		return tr("Nothing: what you paid is lost") if paid else tr("Nothing happens")
	var listed := ", ".join(parts)
	return listed.left(1).to_upper() + listed.substr(1)


## "a piece of equipment (25% chance it is Rare or Epic)", with this floor's real odds.
func _item_words(player: Player) -> String:
	var world := player.world
	if world == null:
		return tr("a piece of equipment")
	# The quality the item is really rolled with (World.spawn_loot: the floor's and the run's
	# boons'), and the roll's own odds.
	var quality := world.rules.drop_quality(item_quality) if world.rules else item_quality
	return tr("a piece of equipment (%d%% chance it is Rare or Epic)") % roundi(LootRoller.rare_or_better_chance(world.depth, quality, world.config()) * 100.0)
