class_name Forge
extends StaticBody2D
## The smith's forge (ForgeDef): an anvil, hot coals and the smith. Stand by it and press
## Interact ("Forge") to open the forge (ForgePanel): runes from the bag go into a weapon's free sockets (RuneDef, 1 to 3 by
## rarity) for free; taking one back out, intact, costs gold. Works on the worn weapon and on
## weapons in the bag. A plain weapon becomes its own copy the first time a rune goes in.

const SIZE := 32.0
## The Interact button offers the forge from this close.
const OPEN_DISTANCE := 68.0
const SET_SOUND := preload("res://data/audio/forge_set.tres")
const TAKE_SOUND := preload("res://data/audio/forge_take.tres")

var def: ForgeDef

var _world: World
var _time := 0.0
## Where the hero presses Interact to work at the anvil.
var _spot := Interactable.new()


func setup(forge: ForgeDef, world: World) -> void:
	def = forge
	_world = world
	collision_layer = Layers.WORLD
	collision_mask = 0
	add_to_group("forges")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 14)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, 6)
	add_child(collision)
	# The coals light the room.
	var coals := LightSource.new()
	coals.color = Color(1, 0.55, 0.25)
	coals.level = 12
	coals.position = Vector2(14, 4)
	add_child(coals)
	_spot.verb = "Forge"  # i18n
	_spot.reach = OPEN_DISTANCE
	_spot.color = Color(1, 0.7, 0.35)
	_spot.icon = def.anvil
	_spot.used.connect(func(_by: Player) -> void: Events.forge_requested.emit(self))
	add_child(_spot)


func world_of() -> World:
	return _world


## Gold to take a rune out here.
func removal_cost() -> int:
	return def.removal_cost(_world.depth, _world.rules.shop_prices())


## The weapons the hero can work on here: the worn one first, then those in the bag.
static func weapons_of(player: Player) -> Array[EquipmentDef]:
	var result: Array[EquipmentDef] = []
	var worn := player.equipment.get_item(EquipmentDef.Slot.WEAPON)
	if worn:
		result.append(worn)
	for entry in player.inventory.grouped():  # one per stack
		var weapon := entry.item as EquipmentDef
		if weapon and weapon.slot == EquipmentDef.Slot.WEAPON and not result.has(weapon):
			result.append(weapon)
	return result


## Sets `rune` (from the bag) into `weapon` (worn or in the bag). Returns the weapon as it is
## now (a plain weapon becomes its own copy), or null if it can't (no free socket...).
static func set_rune(player: Player, weapon: EquipmentDef, rune: RuneDef) -> EquipmentDef:
	if weapon == null or rune == null or weapon.free_sockets() <= 0 or not player.inventory.items.has(rune):
		return null
	# One of a stack in the bag leaves it and needs a place of its own, in the weapons'
	# compartment (the rune leaving frees one in the runes', not there).
	var bag := player.inventory
	if bag.items.has(weapon) and bag.count_of(weapon) > 1 and bag.is_compartment_full(bag.compartment_of(weapon)):
		Events.log_message(bag.full_text(weapon), Palette.DANGER)
		return null
	var worked := weapon if weapon.is_rolled() else LootRoller.make(weapon, weapon.rarity, weapon.affixes.duplicate(), [], weapon.item_level)
	worked.runes.append(rune)
	player.inventory.remove(rune)
	_put_back(player, weapon, worked)
	Events.log_message(TranslationServer.tr("%s set into %s") % [TranslationServer.tr(rune.display_name), TranslationServer.tr(worked.display_name)], rune.rarity_color())
	return worked


## Takes the rune in socket `index` of `weapon` back out, intact, into the bag, for `price` gold.
## False if the bag is full or the gold is short.
static func take_rune(player: Player, weapon: EquipmentDef, index: int, price: int) -> bool:
	if weapon == null or index < 0 or index >= weapon.runes.size():
		return false
	var rune := weapon.runes[index]
	if not player.inventory.can_add(rune) or player.gold < price or not player.spend_gold(price):
		return false
	weapon.runes.remove_at(index)
	player.inventory.add(rune)
	_put_back(player, weapon, weapon)
	Events.log_message(TranslationServer.tr("%s taken out of %s") % [TranslationServer.tr(rune.display_name), TranslationServer.tr(weapon.display_name)], rune.rarity_color())
	return true


## Tempers `weapon` into its evolved form `into` (WeaponEvolution: its sockets all hold the
## family's runes, the family awake). The runes melt into it; the profile remembers the evolution
## (the codex, the recipe at the forge). Returns the new weapon, or null if it can't.
static func evolve(player: Player, weapon: EquipmentDef, into: WeaponDef) -> EquipmentDef:
	if not WeaponEvolution.is_ready(weapon, into, player.perks):
		return null
	var bag := player.inventory
	if bag.items.has(weapon) and bag.count_of(weapon) > 1 and bag.is_compartment_full(bag.compartment_of(weapon)):
		Events.log_message(bag.full_text(weapon), Palette.DANGER)
		return null
	var evolved := WeaponEvolution.evolve(weapon, into)
	_put_back(player, weapon, evolved)
	Profile.record_evolution(into.id)
	Events.run_marked.emit("evolved")
	Events.log_message(TranslationServer.tr("The runes melt into the steel: %s.") % TranslationServer.tr(evolved.display_name), evolved.rarity_color())
	return evolved


## `worked` takes `weapon`'s place, worn or in the bag, and the hero feels the change.
static func _put_back(player: Player, weapon: EquipmentDef, worked: EquipmentDef) -> void:
	if player.equipment.get_item(EquipmentDef.Slot.WEAPON) == weapon:
		if worked != weapon:
			player.equipment.equip(worked)
		else:
			player.equipment.refresh()
		return
	var index := player.inventory.items.find(weapon)
	if index >= 0:
		player.inventory.items[index] = worked
		player.inventory.changed.emit()


## Sparks fly off the anvil, and its sound.
func strike(taking_out: bool) -> void:
	Sfx.play_world(TAKE_SOUND if taking_out else SET_SOUND, global_position)
	Vfx.burst(_world, Vfx.HIT_SPARKS, global_position + Vector2(-6, -8), Color(1, 0.75, 0.35), Vector2.UP)
	Events.screen_shake.emit(0.15)


func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	PixelDraw.disc(self, Vector2(0, 14), 22.0, Color(0, 0, 0, 0.35), 1.0, 0.35)
	# The coal pit, glowing and breathing.
	var glow := 0.75 + 0.25 * sin(_time * 3.1) * sin(_time * 1.7 + 1.0)
	draw_rect(Rect2(8, -2, 16, 12), Color("2b1d1a"))
	draw_rect(Rect2(10, 0, 12, 8), Color(1.0, 0.42, 0.12).darkened(0.35 * (1.0 - glow)))
	for i in 3:
		var x := 11.0 + i * 4.0
		draw_rect(Rect2(x - 1.0, 2.0 * (int(_time * 4.0 + i) % 3), 2, 2), Color(Color(1.0, 0.85, 0.4) * glow, 1.0))
	if def.anvil:
		draw_texture_rect(def.anvil, Rect2(-24, -10, 32, 32), false)
	if def.sprite_sheet:
		var bob := roundf(sin(_time * 2.0))
		draw_texture_rect_region(def.sprite_sheet, Rect2(-8, -40 + bob, 32, 32), Rect2(0, 0, 16, 16))
	# A hammer sign over the smith: he waits for work.
	Fonts.draw(self, Vector2(8, -46), "T", Fonts.BODY, Color(1, 0.7, 0.35), 0.5, Color.BLACK)
