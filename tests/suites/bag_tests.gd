class_name BagTests
extends PcTests
## The bag's compartments, tabs and quick actions (docs/design/interface.md "Bag", loot.md "Room
## in the bag"). Unit part (run by the unit suite): which compartment each item lands in
## (BagCategorySet), each compartment's own places (a full one refuses only what is new to it),
## upgrades, an old save's single list coming back (past its places: kept), the order inside a
## tab, which dismantles ask first. Game part (game suite): loot, auto loot and the merchant
## asking the item's compartment; the bag screen on touch (tabs tapped, the card's buttons, new
## marks, a full tab, Dismantle the worse for the tab open), with a gamepad (LB / RB, A, X, Y, B)
## and with keys (Q / E, Enter, X, G), the confirmation for rare pieces, what is worn never broken;
## the bag inside a 1280x720 screen in French. Borrows PcTests' helpers.

const CATEGORIES: BagCategorySet = preload("res://data/items/bag_categories.tres")


func _tab_of(id: StringName) -> int:
	for i in CATEGORIES.categories.size():
		if CATEGORIES.categories[i].id == id:
			return i
	return -1


func _item(path: String) -> ItemDef:
	return load(path) as ItemDef


func _katana(rarity: int, level: int) -> EquipmentDef:
	var none: Array[ItemAffixDef] = []
	return LootRoller.make(_item("res://data/items/weapons/katana.tres") as EquipmentDef, rarity, none, [], level)


func _mail(rarity: int, level: int) -> EquipmentDef:
	var none: Array[ItemAffixDef] = []
	return LootRoller.make(_item("res://data/items/armors/chain_mail.tres") as EquipmentDef, rarity, none, [], level)


# --- Unit ---------------------------------------------------------------------------------

func run_bag_unit() -> void:
	var weapons := _tab_of(&"weapons")
	var armor := _tab_of(&"armor")
	var runes := _tab_of(&"runes")
	var scrolls := _tab_of(&"scrolls")
	var consumables := _tab_of(&"consumables")
	var other := _tab_of(&"other")
	check(weapons >= 0 and armor >= 0 and runes >= 0 and scrolls >= 0 and consumables >= 0 and other >= 0, "the bag has its six compartments (bag_categories.tres)")
	for category in CATEGORIES.categories:
		check(not category.display_name.is_empty() and category.icon != null and not category.full_text.is_empty(), "the compartment %s has a name, an icon and its words when full" % category.id)
		check(category.icon != null and category.icon.resource_path.begins_with("res://assets/ui/placeholders/"), "the compartment %s shows a pictogram, not an item of the game" % category.id)
	for id: StringName in [&"weapons", &"armor", &"runes", &"scrolls"]:
		check(CATEGORIES.categories[_tab_of(id)].capacity == 16, "%s: 16 places of its own" % id)
	var wrong: Array[String] = []
	var everything: Array[ItemDef] = []
	everything.append_array(CONTENT.items)
	everything.append_array(CONTENT.locked_items)
	for rune in CONTENT.runes:
		everything.append(rune)
	everything.append(_item("res://data/items/keys/bone_key.tres"))
	for item in everything:
		var expected := other
		if item is WeaponDef:
			expected = weapons
		elif item is EquipmentDef:
			expected = armor
		elif item is RuneDef:
			expected = runes
		elif item is SkillTomeDef or item.id == &"fire_scroll":
			expected = scrolls
		elif item is ConsumableDef:
			expected = consumables
		if CATEGORIES.index_of(item) != expected:
			wrong.append("%s in %d" % [item.id, CATEGORIES.index_of(item)])
	check(wrong.is_empty(), "every item lands in its compartment: weapons, armor, runes, tomes and the scroll, consumables, keys (%s)" % ", ".join(wrong))
	var katana := _item("res://data/items/weapons/katana.tres") as EquipmentDef
	var helm := _item("res://data/items/armors/iron_helm.tres") as EquipmentDef
	var mail := _item("res://data/items/armors/chain_mail.tres") as EquipmentDef
	var rare := _katana(ItemRarity.RARE, 3)
	var epic := _mail(ItemRarity.EPIC, 2)
	check(CATEGORIES.index_of(rare) == weapons and CATEGORIES.index_of(epic) == armor, "rolled gear keeps its class: a weapon with the weapons, a body armor with the armor")
	check(CATEGORIES.index_of(ItemDef.new()) == other, "an item no tab names goes to the catch-all compartment")
	# Inside a tab: the rarest first, then helms before body armors, the higher level first.
	var bag := Inventory.new(16)
	for item: ItemDef in [mail, helm, katana, katana, rare, epic, _item("res://data/runes/ember.tres"), _item("res://data/runes/ember.tres")]:
		bag.add(item)
	var order: Array = CATEGORIES.entries_in(armor, bag.grouped()).map(func(entry: Dictionary) -> ItemDef: return entry.item)
	check(order == [epic, helm, mail], "a tab shows the rarest first, then head, body (%s)" % [order.map(func(item: ItemDef) -> String: return item.display_name)])
	order = CATEGORIES.entries_in(weapons, bag.grouped()).map(func(entry: Dictionary) -> ItemDef: return entry.item)
	check(order == [rare, katana], "the weapons' tab: the rare one first")
	check(CATEGORIES.count_in(weapons, bag.grouped()) == 3 and CATEGORIES.count_in(runes, bag.grouped()) == 2, "a tab counts items, a stack all of its own")
	# Which dismantles ask first (DismantleRules.needs_confirm).
	var rules := PlayerPack.DISMANTLE
	var magic := _katana(ItemRarity.MAGIC, 1)
	var socketed := LootRoller.make(katana, ItemRarity.COMMON, [] as Array[ItemAffixDef], [_item("res://data/runes/ember.tres") as RuneDef], 1)
	check(rules.confirm_rarity == ItemRarity.RARE, "rare and better ask before they break (dismantle.tres)")
	check(not rules.needs_confirm(katana) and not rules.needs_confirm(magic), "common and magic gear breaks down at once")
	check(rules.needs_confirm(rare) and rules.needs_confirm(epic), "rare and epic gear asks a second press")
	check(rules.needs_confirm(socketed), "gear with a rune set asks too (the rune breaks with it)")
	# The actions on a selection.
	var selection := BagSelection.new(null, katana)
	check(BagDropAction.new().available(selection) and BagUseAction.new().label(selection) == "Equip", "gear in the bag: Equip, Drop")
	var worn := BagSelection.new(null, katana, EquipmentDef.Slot.WEAPON)
	check(not BagDismantleAction.new().available(worn) and not BagDropAction.new().available(worn) and BagUseAction.new().label(worn) == "Unequip", "what is worn: Unequip only, never dismantled or dropped")
	var rune := BagSelection.new(null, _item("res://data/runes/ember.tres"))
	check(not BagUseAction.new().available(rune) and not BagDismantleAction.new().available(rune), "a rune: nothing to use, never dismantled")
	# The keys of the quick actions.
	for action: StringName in [&"menu_scroll_up", &"menu_scroll_down"]:
		check(InputMap.action_get_events(action).any(func(e: InputEvent) -> bool: return e is InputEventJoypadMotion and (e as InputEventJoypadMotion).axis == JOY_AXIS_RIGHT_Y), "%s is the right stick (the keys have the mouse's wheel)" % action)
	for action: StringName in [&"item_dismantle", &"item_drop"]:
		var events := InputMap.action_get_events(action)
		check(events.any(func(e: InputEvent) -> bool: return e is InputEventKey) and events.any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton or e is InputEventJoypadMotion), "%s works on keys and on a gamepad" % action)
	var pad_button := func(action: StringName) -> int:
		for e in InputMap.action_get_events(action):
			if e is InputEventJoypadButton:
				return (e as InputEventJoypadButton).button_index
		return -1
	check(pad_button.call(&"item_dismantle") == JOY_BUTTON_X and pad_button.call(&"item_drop") == JOY_BUTTON_Y, "X dismantles, Y drops on a gamepad")
	_test_compartments(weapons, armor, runes)
	_test_old_save(weapons, runes)


## Each compartment has its own places: a full one refuses what is new to it, and only it.
func _test_compartments(weapons: int, armor: int, runes: int) -> void:
	var mail := _item("res://data/items/armors/chain_mail.tres") as EquipmentDef
	var bag := Inventory.new(16, CATEGORIES)
	check(bag.compartment_count() == CATEGORIES.categories.size() and bag.capacity_of(weapons) == 16, "the hero's bag: one compartment per tab, 16 places in the weapons'")
	check(not BagFullMark.any_full(bag) and not BagFullMark.any_full(null), "an empty bag (or none): no red dot on the Bag button")
	var all_in := true
	for level in range(1, 17):
		all_in = bag.add(_katana(ItemRarity.COMMON, level)) and all_in
	check(all_in and bag.is_compartment_full(weapons) and bag.places_used_in(weapons) == 16, "16 weapons go in and fill the weapons' compartment")
	check(not bag.can_add(_katana(ItemRarity.COMMON, 30)) and not bag.add(_katana(ItemRarity.COMMON, 30)), "a 17th weapon finds no room")
	check(bag.can_add(_katana(ItemRarity.COMMON, 5)), "...but one that stacks does")
	check(bag.can_add(mail) and bag.can_add(_item("res://data/runes/ember.tres")) and bag.can_add(_item("res://data/items/tomes/tome_fire.tres")), "armor, runes and tomes still have all their room")
	check(bag.free_in(armor) == 16 and not bag.is_full(), "the bag is full only when every compartment is")
	check(BagFullMark.any_full(bag), "...but one full compartment is enough for the Bag button's red dot")
	check(bag.full_text(_katana(ItemRarity.COMMON, 1)) == "No room left for weapons" and bag.full_text(mail) == "No room left for armor", "a full compartment says which it is")
	# Equipping one of a stack: the worn piece needs a place in its own compartment.
	var stacked := _katana(ItemRarity.COMMON, 5)
	bag.add(stacked)
	check(not bag.fits_after_taking(stacked, _katana(ItemRarity.RARE, 2)), "a full weapons' compartment: the worn weapon can't come back to it")
	check(bag.fits_after_taking(stacked, mail), "an armor coming back asks the armor's room only")
	check(bag.fits_after_taking(bag.items[0], _katana(ItemRarity.RARE, 2)), "the last of a stack leaving frees its place")
	# Upgrades: places for every compartment, or for one.
	bag.extra_places = 2
	check(bag.capacity_of(weapons) == 18 and bag.capacity_of(runes) == 18 and not bag.is_compartment_full(weapons), "extra places go to every compartment")
	bag.extra_places = 0
	bag.extra_by_category[&"runes"] = 4
	check(bag.capacity_of(runes) == 20 and bag.capacity_of(weapons) == 16, "...or to one, by its id")
	# Over its places (an old save, a smaller compartment): kept, nothing new until room is made.
	var small := CATEGORIES.duplicate(true) as BagCategorySet
	small.categories[armor].capacity = 2
	var tight := Inventory.new(16, small)
	for level in range(1, 5):
		tight.force_add(_mail(ItemRarity.COMMON, level))
	check(tight.items.size() == 4 and tight.over_capacity(armor) == 2 and not tight.can_add(_mail(ItemRarity.MAGIC, 9)), "over its places: everything kept, nothing new comes in")
	tight.take(tight.items[0])
	tight.take(tight.items[0])
	check(tight.over_capacity(armor) == 0 and not tight.can_add(_mail(ItemRarity.MAGIC, 9)), "back to its places: still full")
	tight.take(tight.items[0])
	check(tight.can_add(_mail(ItemRarity.MAGIC, 9)), "a place freed: room again")


## A run saved with the single 16-place bag (one list) comes back into the compartments; more than
## a compartment holds (impossible with today's places, but a compartment may shrink) is kept.
func _test_old_save(weapons: int, runes: int) -> void:
	var hero := (load("res://src/entities/player/player.tscn") as PackedScene).instantiate() as Player
	hero.setup(CONTENT.player)
	check(hero.inventory.categories == CATEGORIES and hero.inventory.extra_places == CONTENT.player.bag_bonus, "the hero's bag has the compartments, and the hero's bonus places")
	var listed: Array = []
	for level in range(1, 21):
		listed.append(LootRoller.to_data(_katana(ItemRarity.COMMON, level)))
	for path in ["res://data/runes/ember.tres", "res://data/runes/ember.tres", "res://data/runes/rime.tres", "res://data/items/tomes/tome_fire.tres"]:
		listed.append(LootRoller.to_data(load(path)))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(hero.save_state()))
	saved["inventory"] = listed
	hero.load_state(saved)
	var bag := hero.inventory
	check(bag.items.size() == 24, "an old save's bag comes back whole (%d of 24 items)" % bag.items.size())
	check(bag.places_used_in(weapons) == 20 and bag.over_capacity(weapons) == 4, "20 weapons in a 16-place compartment: kept, 4 over")
	check(bag.places_used_in(runes) == 2 and bag.count_of(load("res://data/runes/ember.tres")) == 2, "the runes in theirs, stacked")
	check(not hero.pack.can_store(_katana(ItemRarity.COMMON, 40)) and hero.pack.can_store(load("res://data/runes/spark.tres")), "no new weapon until there is room; runes still come")
	var again: Dictionary = JSON.parse_string(JSON.stringify(hero.save_state()))
	check((again.inventory as Array).size() == 24, "saved again: still one list, nothing lost")
	hero.free()


# --- Game ---------------------------------------------------------------------------------

func run_bag_game(game: Game) -> void:
	var player := game.player
	var saved_bag := player.inventory.items.duplicate()
	var saved_weapon := player.equipment.get_item(EquipmentDef.Slot.WEAPON)
	var saved_body := player.equipment.get_item(EquipmentDef.Slot.BODY)
	var saved_gold := player.gold
	var saved_belt := player.belt.to_data()
	var saved_spell := player.learned_skill
	var saved_loot := Settings.auto_loot
	await _test_compartment_room(game)
	await _test_touch(game)
	await _test_gamepad(game)
	await _test_keys(game)
	await _test_french_fit(game)
	await _test_worn_marks(game)
	InputDevice.use(InputDevice.Kind.TOUCH)
	Settings.auto_loot = saved_loot
	player.inventory.items.assign(saved_bag)
	player.equipment.equip(saved_weapon)
	if saved_body:
		player.equipment.equip(saved_body)
	player.gold = saved_gold
	player.belt.load_data(saved_belt)
	if player.learned_skill != saved_spell:
		player.learned_skill = saved_spell
		player.rebuild_skills(0.0)
	for left in get_tree().get_nodes_in_group("pickups"):
		left.queue_free()
	get_tree().paused = false
	await _frames(2)


## Worn armor shows what its affixes carry (docs/vfx.md "Rarity and runes"): an affix of Echoes
## glitters arcane on a helm's brim, of Thorns turns a hem into steel points; a plain piece shows
## neither. The bag's portrait is the hero as he is (HeroPortrait), dressed as his body in the
## world: his weapon on his back with its elements, his armor with its trim and marks.
func _test_worn_marks(game: Game) -> void:
	var player := game.player
	var saved_head := player.equipment.get_item(EquipmentDef.Slot.HEAD)
	var saved_body := player.equipment.get_item(EquipmentDef.Slot.BODY)
	var katana := LootRoller.make(load("res://data/items/weapons/katana.tres"), ItemRarity.RARE, [load("res://data/affixes/sharp.tres")], [load("res://data/runes/ember.tres")], 2) as WeaponDef
	var helm := LootRoller.make(load("res://data/items/armors/iron_helm.tres"), ItemRarity.EPIC, [load("res://data/affixes/of_echoes.tres"), load("res://data/affixes/sturdy.tres")], [], 2) as ArmorDef
	var plate := LootRoller.make(load("res://data/items/armors/plate_armor.tres"), ItemRarity.RARE, [load("res://data/affixes/of_thorns.tres")], [], 2) as ArmorDef
	player.equipment.equip(katana)
	player.equipment.equip(helm)
	player.equipment.equip(plate)
	game.open_inventory()
	await _frames(3)
	var portrait := game.inventory_panel.get_node("%Portrait") as HeroPortrait
	var arcane := VfxElementDef.named(&"arcane")
	for pair: Array in [["the bag's portrait", portrait.rig() if portrait else null], ["his body", player.rig]]:
		var rig: ActorRig = pair[1]
		var pair_name: String = pair[0]
		check(rig != null and rig.back_weapon() != null and rig.back_weapon().texture == katana.back_sprite and rig.shows_back_weapon(), "worn marks: %s carries his katana" % pair_name)
		check(rig != null and rig.weapon_aura() != null and rig.weapon_aura().elements.has(VfxElementDef.named(&"fire")), "worn marks: %s's katana carries the Ember Rune's fire" % pair_name)
		check(rig != null and rig.helmet.visible and rig.helmet.sprite_frames == helm.wear_frames and rig.body_armor.sprite_frames == plate.wear_frames, "worn marks: %s wears his helm and his plate" % pair_name)
		var head := rig.wear_material(EquipmentDef.Slot.HEAD) if rig else null
		var body := rig.wear_material(EquipmentDef.Slot.BODY) if rig else null
		check(head != null and float(head.get_shader_parameter(&"imbue")) > 0.0 and int(head.get_shader_parameter(&"imbue_row")) == BodyLook.row(arcane) and not bool(head.get_shader_parameter(&"teeth")), "worn marks: on %s, a helm of Echoes glitters arcane on its brim" % pair_name)
		check(body != null and bool(body.get_shader_parameter(&"teeth")) and float(body.get_shader_parameter(&"imbue")) == 0.0 and int(body.get_shader_parameter(&"trim")) > 0, "worn marks: on %s, a plate of Thorns has steel points on its gold hem" % pair_name)
	# A plain piece of the same rarity: its trim alone.
	player.equipment.equip(LootRoller.make(load("res://data/items/armors/plate_armor.tres"), ItemRarity.RARE, [load("res://data/affixes/sturdy.tres")], [], 2))
	await _frames(2)
	for plain: ShaderMaterial in [portrait.rig().wear_material(EquipmentDef.Slot.BODY) if portrait else null, player.rig.wear_material(EquipmentDef.Slot.BODY)]:
		check(plain != null and not bool(plain.get_shader_parameter(&"teeth")) and float(plain.get_shader_parameter(&"imbue")) == 0.0, "worn marks: a Stalwart plate shows its rarity's trim alone (stats carry nothing), on him and on the open bag's portrait")
	game.inventory_panel.close()
	await _frames(2)
	if saved_head:
		player.equipment.equip(saved_head)
	else:
		player.equipment.unequip(EquipmentDef.Slot.HEAD)
	if saved_body:
		player.equipment.equip(saved_body)
	else:
		player.equipment.unequip(EquipmentDef.Slot.BODY)


## The floor's loot, auto loot and the merchant ask the item's own compartment: a full weapons'
## compartment leaves a weapon on the ground and still takes a rune; the merchant won't sell a
## weapon then, but sells armor. The bag shows the full tab, and an over-full one says so; the
## HUD's Bag button wears a red dot while a compartment is full.
func _test_compartment_room(game: Game) -> void:
	var player := game.player
	var world := game.world
	var panel := game.inventory_panel
	var weapons := _tab_of(&"weapons")
	var bag := player.inventory
	InputDevice.use(InputDevice.Kind.TOUCH)
	Settings.auto_loot = Settings.LOOT_ALL
	bag.items.clear()
	for level in range(1, bag.capacity_of(weapons) + 1):
		bag.add(_katana(ItemRarity.COMMON, level))
	check(bag.is_compartment_full(weapons), "the weapons' compartment filled (%d / %d)" % [bag.places_used_in(weapons), bag.capacity_of(weapons)])
	var mark := game.hud.get_node("%BagButton/BagFullMark") as BagFullMark
	check(mark != null and mark.visible, "a full compartment puts a red dot on the HUD's Bag button")
	if mark:
		var button := game.hud.get_node("%BagButton") as Control
		check(Rect2(Vector2.ZERO, button.size).encloses(Rect2(mark.position, mark.size)), "...inside the button's top right corner (%s in %s)" % [mark.position, button.size])
		bag.remove(bag.items[0])
		check(not mark.visible, "...and it goes once a place is free again")
		bag.add(_katana(ItemRarity.COMMON, 1))
		check(mark.visible, "...and comes back when it fills again")
	var spot := world.find_open_point_near(player.global_position + Vector2(30, 0), 30.0)
	var sword := world.spawn_item(_katana(ItemRarity.MAGIC, 40), spot)
	await _frames(2)
	player.global_position = spot
	await _frames(6)
	check(is_instance_valid(sword) and not sword.is_taken(), "auto loot (All): a new weapon stays on the ground")
	if is_instance_valid(sword):
		sword.queue_free()
	world.spawn_item(_item("res://data/runes/gale.tres"), spot)
	var helm := world.spawn_item(_mail(ItemRarity.MAGIC, 3), spot)
	await _frames(6)
	check(bag.count_of(_item("res://data/runes/gale.tres")) == 1, "...while a rune comes in (its own compartment)")
	check(not is_instance_valid(helm) or helm.is_taken(), "...and so does armor")
	# The merchant.
	var merchant := world.spawn_merchant(CONTENT.dungeon.merchant, world.map.world_to_cell(world.find_open_point_near(player.global_position + Vector2(-60, 0), 40.0)))
	await _frames(2)
	merchant.stock.clear()
	merchant.stock.append({ "item": _katana(ItemRarity.RARE, 5), "price": 1 })
	merchant.stock.append({ "item": _mail(ItemRarity.RARE, 5), "price": 1 })
	player.gold = 50
	check(not merchant.sell_to(player, 0) and player.gold == 50, "the merchant won't sell a weapon into a full weapons' compartment")
	game.open_shop(merchant)
	await _frames(2)
	game.shop_panel.select_stock(0)
	var buy := game.shop_panel.get_node("%BuyButton") as Button
	check(buy.disabled and buy.text == "No room left for weapons: sell something first", "the shop's Buy says which compartment is full: %s" % buy.text)
	game.shop_panel.close()
	await _frames(1)
	check(merchant.sell_to(player, 1), "...but sells armor")
	merchant.queue_free()
	# The bag screen: the full tab in red, its places.
	panel.show_category(weapons)
	game.open_inventory()
	await _frames(2)
	var places := panel.get_node("%CategoryName") as Label
	check(panel.tab(weapons).full and places.text == "Weapons  16 / 16", "the full tab says so: %s" % places.text)
	check(not panel.tab(_tab_of(&"runes")).full, "the runes' tab is not full")
	check(not (panel.get_node("%OverNote") as Label).visible, "not over its places: no warning")
	panel.close()
	await _frames(1)
	# Over its places (an old save): kept, and the tab says to make room.
	for level in range(50, 52):
		bag.force_add(_katana(ItemRarity.COMMON, level))
	game.open_inventory()
	await _frames(2)
	check((panel.get_node("%OverNote") as Label).visible and places.text == "Weapons  18 / 16", "over its places: the tab warns (%s)" % places.text)
	# Dismantle the worse: only the tab open.
	var junk := _mail(ItemRarity.COMMON, 1)
	player.equipment.equip(_mail(ItemRarity.EPIC, 20))
	bag.add(junk)
	panel.show_category(weapons)
	await _frames(1)
	var worse_weapons := player.pack.worse_gear(weapons)
	check(worse_weapons.all(func(item: ItemDef) -> bool: return item is WeaponDef) and not player.pack.worse_gear().is_empty(), "the worse gear of a tab is its own (weapons only here)")
	(panel.get_node("%DismantleWorseButton") as Button).pressed.emit()
	if panel.is_confirm_open():
		(panel.get_node("%ConfirmDismantleButton") as Button).pressed.emit()
	check(bag.items.has(junk), "Dismantle the worse in the weapons' tab leaves the armor alone")
	panel.close()
	await _frames(2)


## A bag of everything: weapons (a rare one, a stack of two commons), an epic armor, runes, a tome,
## the scroll, a potion.
func _fill(player: Player) -> Dictionary:
	var items := {
		"common": _katana(ItemRarity.COMMON, 1),
		"common2": _katana(ItemRarity.COMMON, 1),
		"rare": _katana(ItemRarity.RARE, 2),
		"epic": _mail(ItemRarity.EPIC, 2),
		"rune": _item("res://data/runes/ember.tres"),
		"rune2": _item("res://data/runes/spark.tres"),
		"tome": _item("res://data/items/tomes/tome_fire.tres"),
		"scroll": _item("res://data/items/consumables/fire_scroll.tres"),
		"potion": _item("res://data/items/consumables/haste_draught.tres"),
	}
	player.inventory.items.clear()
	for key: String in items:
		player.inventory.add(items[key])
	return items


func _shown_items(grid: GridContainer) -> Array:
	return grid.get_children().filter(func(slot: ItemSlot) -> bool: return slot.item != null).map(func(slot: ItemSlot) -> ItemDef: return slot.item)


func _test_touch(game: Game) -> void:
	var player := game.player
	var panel := game.inventory_panel
	InputDevice.use(InputDevice.Kind.TOUCH)
	var items := _fill(player)
	var weapons := _tab_of(&"weapons")
	var armor := _tab_of(&"armor")
	var runes := _tab_of(&"runes")
	var scrolls := _tab_of(&"scrolls")
	var consumables := _tab_of(&"consumables")
	game.open_inventory()
	await _frames(2)
	panel.show_category(weapons)
	await _frames(1)
	var grid: GridContainer = panel.get_node("%ItemGrid")
	var free := player.inventory.free_in(weapons)
	var shown := _shown_items(grid)
	check(shown.size() == 2 and grid.get_child_count() == 2 + free and free == 14, "the weapons' tab shows its 2 stacks, then its own 14 free places (%d slots)" % grid.get_child_count())
	check(shown == [items.rare, items.common], "the rare one first, then the commons' stack")
	check(panel.tab(0).get_parent() is TabRow and panel.tab(0).is_in_group(MenuNav.TABS), "the bag's compartments are a TabRow, like every window's tabs")
	check(panel.tab(weapons).count == 3 and panel.tab(armor).count == 1 and panel.tab(runes).count == 2 and panel.tab(scrolls).count == 2 and panel.tab(consumables).count == 1, "each tab counts its items (3, 1, 2, 2, 1)")
	check(not panel.tab(_tab_of(&"other")).visible, "the keys' tab hides while it holds nothing")
	check((panel.get_node("%CategoryName") as Label).text == "Weapons  2 / 16", "the tab's name and its own places under the tabs")
	check(panel.tab(runes).fresh and panel.slot_for(items.rare).fresh, "new things are marked, and their tab")
	# A tap on a tab.
	panel.tab(armor).pressed.emit()
	await _frames(1)
	check(panel.category_index() == armor and _shown_items(grid) == [items.epic] and grid.get_child_count() == 16, "tapping Armor shows the armor, with its own 15 free places")
	panel.tab(runes).pressed.emit()
	await _frames(1)
	var rune_items := _shown_items(grid)
	check(panel.category_index() == runes and rune_items.size() == 2 and rune_items.all(func(item: ItemDef) -> bool: return item is RuneDef), "tapping the Runes tab shows the runes only")
	check(panel.tab(runes).button_pressed and not panel.tab(weapons).button_pressed, "the tab shown stays pressed")
	panel.tab(scrolls).pressed.emit()
	await _frames(1)
	var scroll_items := _shown_items(grid)
	check(scroll_items.has(items.tome) and scroll_items.has(items.scroll) and scroll_items.size() == 2, "tomes and the scroll share a tab")
	panel.close()
	await _frames(2)
	game.open_inventory()
	await _frames(2)
	check(panel.category_index() == scrolls, "the bag opens again on the tab picked last")
	check(not panel.tab(runes).fresh, "what was shown is no longer new")
	panel.show_category(weapons)
	await _frames(1)
	# The card's buttons: a common goes at once, a rare asks again.
	var dismantle: Button = panel.get_node("%DismantleButton")
	panel.slot_for(items.common).pressed.emit()
	var gold := player.gold
	var gain := PlayerPack.DISMANTLE.gold_for(items.common)
	dismantle.pressed.emit()
	check(player.gold == gold + gain and player.inventory.count_of(items.common) == 1, "tapping Dismantle on a common breaks one of its stack at once (+%d gold)" % gain)
	check(panel._selected_item != null and panel._selected_item.stack_key() == items.common.stack_key(), "the rest of the stack stays picked")
	panel.slot_for(items.rare).pressed.emit()
	gold = player.gold
	dismantle.pressed.emit()
	var note := panel.get_node("%DismantleNote") as Label
	check(player.gold == gold and player.inventory.count_of(items.rare) == 1 and dismantle.text == "Sure?", "on a rare piece a first tap asks again (%s)" % dismantle.text)
	check(note.text == "Tap again to break it: +%d gold" % PlayerPack.DISMANTLE.gold_for(items.rare), "the card says what a second tap does, in touch words: %s" % note.text)
	panel.slot_for(items.common).pressed.emit()
	check(dismantle.text == "Dismantle", "picking another item takes the question back")
	panel.slot_for(items.rare).pressed.emit()
	dismantle.pressed.emit()
	dismantle.pressed.emit()
	check(player.gold > gold and player.inventory.count_of(items.rare) == 0, "a second tap breaks the rare piece")
	(panel.get_node("%WeaponSlot") as ItemSlot).pressed.emit()
	check(not dismantle.visible and not (panel.get_node("%DropButton") as Button).visible, "what is worn shows no Dismantle and no Drop")
	panel.slot_for(items.common).pressed.emit()
	(panel.get_node("%DropButton") as Button).pressed.emit()
	await _frames(1)
	check(player.inventory.count_of(items.common) == 0, "Drop leaves it on the ground")
	# A right click equips.
	panel.show_category(armor)
	await _frames(1)
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	panel.slot_for(items.epic).gui_input.emit(right)
	check(player.equipment.get_item(EquipmentDef.Slot.BODY) == items.epic, "a right click on an item equips it")
	panel.close()
	await _frames(2)


func _test_gamepad(game: Game) -> void:
	var player := game.player
	var panel := game.inventory_panel
	var items := _fill(player)
	var weapons := _tab_of(&"weapons")
	var armor := _tab_of(&"armor")
	panel.show_category(weapons)
	InputDevice.use(InputDevice.Kind.GAMEPAD, &"xbox")
	InputDevice.navigating = true
	game.open_inventory()
	await _frames(3)
	check(_focus() == panel.slot_for(items.rare) and panel._selected_item == items.rare, "a gamepad starts on the tab's first slot, its card shown")
	var dismantle_key := (panel.get_node("%DismantleButton") as Button).find_child("*Key", false, false) as PromptGlyph
	check(dismantle_key != null and dismantle_key.visible and dismantle_key.cap().get("text", "") == "X", "the Dismantle button shows its button (X)")
	# LB / RB switch tabs, the focus on the new tab's first slot.
	await _tap_pad(JOY_BUTTON_RIGHT_SHOULDER)
	await _frames(1)
	check(panel.category_index() == armor, "RB shows the next tab (Armor)")
	check(_focus() == panel.slot_for(items.epic) and panel._selected_item == items.epic, "...its first slot focused and picked")
	await _tap_pad(JOY_BUTTON_LEFT_SHOULDER)
	await _frames(1)
	check(panel.category_index() == weapons, "LB the previous one (Weapons)")
	# Moving the focus picks.
	await _tap_pad(JOY_BUTTON_DPAD_RIGHT)
	await _frames(1)
	check(panel._selected_item == items.common, "moving onto a slot shows its card")
	await _tap_pad(JOY_BUTTON_DPAD_LEFT)
	await _frames(1)
	check(panel._selected_item == items.rare, "...and back")
	# X on a rare: asks; B takes it back; X X breaks it.
	var gold := player.gold
	await _tap_pad(JOY_BUTTON_X)
	check(player.gold == gold and player.inventory.count_of(items.rare) == 1 and (panel.get_node("%DismantleButton") as Button).text == "Sure?", "X on a rare piece asks first")
	check((panel.get_node("%DismantleNote") as Label).text.begins_with("Press [X] again"), "...and the card names the button: %s" % (panel.get_node("%DismantleNote") as Label).text)
	await _tap_pad(JOY_BUTTON_B)
	check(panel.visible and (panel.get_node("%DismantleButton") as Button).text == "Dismantle", "B takes the question back (the bag stays open)")
	await _tap_pad(JOY_BUTTON_X)
	await _tap_pad(JOY_BUTTON_X)
	check(player.gold == gold + PlayerPack.DISMANTLE.gold_for(items.rare) and player.inventory.count_of(items.rare) == 0, "X twice breaks the rare piece")
	check(_focus() is ItemSlot and (_focus() as ItemSlot).item == items.common and panel._selected_item == items.common, "the focus goes on to the next item")
	# X on a common: at once, one of the stack.
	gold = player.gold
	await _tap_pad(JOY_BUTTON_X)
	check(player.gold == gold + PlayerPack.DISMANTLE.gold_for(items.common) and player.inventory.count_of(items.common) == 1, "X breaks a common at once, one of its stack")
	check(_focus() == panel.slot_for(items.common), "the focus stays on the rest of the stack")
	# Y drops.
	await _tap_pad(JOY_BUTTON_Y)
	await _frames(1)
	check(player.inventory.count_of(items.common) == 0, "Y drops it")
	# A equips (in the armor's tab).
	await _tap_pad(JOY_BUTTON_RIGHT_SHOULDER)
	await _frames(1)
	await _tap_pad(JOY_BUTTON_A)
	check(player.equipment.get_item(EquipmentDef.Slot.BODY) == items.epic, "A equips the focused gear")
	# What is worn is never broken down.
	(panel.get_node("%BodySlot") as ItemSlot).grab_focus()
	await _frames(1)
	gold = player.gold
	await _tap_pad(JOY_BUTTON_X)
	await _tap_pad(JOY_BUTTON_X)
	check(player.equipment.get_item(EquipmentDef.Slot.BODY) == items.epic and player.gold == gold, "X on what is worn breaks nothing")
	await _tap_pad(JOY_BUTTON_B)
	check(not panel.visible, "B closes the bag")
	await _frames(2)


func _test_keys(game: Game) -> void:
	var player := game.player
	var panel := game.inventory_panel
	var items := _fill(player)
	var weapons := _tab_of(&"weapons")
	var armor := _tab_of(&"armor")
	var runes := _tab_of(&"runes")
	var scrolls := _tab_of(&"scrolls")
	var consumables := _tab_of(&"consumables")
	panel.show_category(weapons)
	_keys_mode()
	game.open_inventory()
	await _frames(3)
	await _tap_key(KEY_E)
	await _frames(1)
	check(panel.category_index() == armor, "E shows the next tab")
	await _tap_key(KEY_E)
	await _frames(1)
	check(panel.category_index() == runes, "...and the next")
	await _tap_key(KEY_E)
	await _tap_key(KEY_E)
	await _frames(1)
	check(panel.category_index() == consumables, "...and on")
	await _tap_key(KEY_Q)
	await _frames(1)
	check(panel.category_index() == scrolls, "Q the previous one")
	# Alt+Enter and F11 switch fullscreen, and only that: the tome isn't learned.
	panel.slot_for(items.tome).grab_focus()
	await _frames(1)
	var full := Settings.fullscreen
	check(get_tree().root.get_child(-1) == Settings.window_keys(), "the window's keys come first (the root's last node: %s)" % get_tree().root.get_child(-1).name)
	_key(KEY_ENTER, true, true)
	await _frames(1)
	_key(KEY_ENTER, false, true)
	await _frames(1)
	check(Settings.fullscreen != full and player.inventory.count_of(items.tome) == 1 and panel.visible, "Alt+Enter on a tome switches fullscreen and doesn't learn it (fullscreen %s, tomes %d)" % [Settings.fullscreen, player.inventory.count_of(items.tome)])
	await _tap_key(KEY_F11)
	check(Settings.fullscreen == full and player.inventory.count_of(items.tome) == 1 and panel.visible, "F11 too")
	# Enter uses: the tome is learned.
	panel.slot_for(items.tome).grab_focus()
	await _frames(1)
	await _tap_key(KEY_ENTER)
	check(player.inventory.count_of(items.tome) == 0, "Enter on a tome learns it")
	panel.show_category(weapons)
	await _frames(1)
	panel.slot_for(items.common).grab_focus()
	await _frames(1)
	var gold := player.gold
	await _tap_key(KEY_X)
	check(player.gold > gold and player.inventory.count_of(items.common) == 1, "X dismantles on a keyboard")
	await _tap_key(KEY_G)
	await _frames(1)
	check(player.inventory.count_of(items.common) == 0, "G drops")
	panel.slot_for(items.rare).grab_focus()
	await _frames(1)
	gold = player.gold
	await _tap_key(KEY_DELETE)
	check(player.gold == gold and (panel.get_node("%DismantleButton") as Button).text == "Sure?", "Delete dismantles too, asking first on a rare piece")
	await _tap_key(KEY_ESCAPE)
	check(panel.visible, "Escape takes the question back first")
	await _tap_key(KEY_ESCAPE)
	check(not panel.visible, "then closes the bag")
	await _frames(2)


## French runs long: on a 1280x720 screen (and 1920x1080, the same layout at x1.5) the bag stays
## inside the screen on every tab, a consumable's three buttons, a rare piece's question and an
## over-full compartment's warning included.
func _test_french_fit(game: Game) -> void:
	var player := game.player
	var panel := game.inventory_panel
	var before := get_tree().root.size
	await _window(Vector2i(1280, 720))
	TranslationServer.set_locale("fr")
	var items := _fill(player)
	for level in range(60, 76):
		player.inventory.force_add(_katana(ItemRarity.COMMON, level))
	_keys_mode()
	panel.show_category(0)
	game.open_inventory()
	await _frames(3)
	var problems: Array[String] = []
	for i in InventoryPanel.CATEGORIES.categories.size():
		panel.show_category(i)
		await _frames(2)
		problems.append_array(_panel_outside(panel))
	panel.show_category(_tab_of(&"consumables"))
	panel.slot_for(items.potion).pressed.emit()
	await _frames(2)
	problems.append_array(_panel_outside(panel))
	panel.show_category(_tab_of(&"weapons"))
	panel.slot_for(items.rare).grab_focus()
	await _frames(1)
	await _tap_key(KEY_X)
	await _frames(2)
	problems.append_array(_panel_outside(panel))
	check(problems.is_empty(), "the bag fits a 1280x720 screen in French, on every tab: %s" % ", ".join(problems.slice(0, 4)))
	panel.close()
	await _frames(2)
	# The merchant too, its Buy saying why it can't (the longest words: a full compartment, gold
	# missing): the reason wraps, the panel stays inside the screen.
	var world := game.world
	var merchant := world.spawn_merchant(CONTENT.dungeon.merchant, world.map.world_to_cell(world.find_open_point_near(player.global_position + Vector2(-60, 0), 40.0)))
	await _frames(2)
	merchant.stock.clear()
	merchant.stock.append({ "item": _katana(ItemRarity.RARE, 5), "price": 1 })
	merchant.stock.append({ "item": _mail(ItemRarity.RARE, 5), "price": 9999 })
	var gold := player.gold
	player.gold = 0
	game.open_shop(merchant)
	await _frames(2)
	var shop_problems: Array[String] = []
	for index in 2:
		game.shop_panel.select_stock(index)
		await _frames(2)
		shop_problems.append_array(_panel_outside(game.shop_panel))
	var buy := game.shop_panel.get_node("%BuyButton") as Button
	check(shop_problems.is_empty(), "the merchant fits a 1280x720 screen in French, Buy saying why it can't (%s): %s" % [buy.text, ", ".join(shop_problems.slice(0, 3))])
	game.shop_panel.close()
	player.gold = gold
	merchant.queue_free()
	TranslationServer.set_locale("en")
	await _restore_window(before)
