class_name OathPanel
extends Control
## "At the Well's Edge", between the difficulty and the run, once the Tree of Souls opened an oath
## or the Armory, or a feat opened a starting kit: swear an oath (OathDef, "X, but Y": the tree's,
## then the kits, ContentDB.kits) or none, and pick the weapon to start with.
## The choice is remembered for the next runs (Profile.oath, Profile.starting_weapon). The Armory
## offers only the weapons its level opened (UpgradeDef.armory_weapons), and says so.
## Built in code; %OathCards, %WeaponRow, %ArmoryText and %StartRunButton are reachable from the
## title screen.

signal started

## A card: wide enough for an oath's name on one line in French ("Serment de la Tempête"), its
## words wrapping under it; the row scrolls sideways. The height is fixed: on a 720-line screen the
## window is full (the Armory's strip below), so a card's words must fit it (title_tests).
const CARD_SIZE := Vector2(290, 296)
## The Armory's line, right of the weapon slots (two lines at most beside them).
const ARMORY_TEXT_WIDTH := 440.0

var _content: ContentDB
var _window: MenuWindow
var _cards: HBoxContainer
var _weapons_box: Control
var _weapons: HBoxContainer
var _weapon_text: Label
## "Armory level 2: 5 weapons. More in the Tree of Souls."
var _armory_text: Label
var _start: Button
## The oath shown as sworn: the saved one while the tree still opens it, else none.
var _sworn: OathDef


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()


## Something to choose: an open oath, or the Armory bought.
static func has_choices(content: ContentDB) -> bool:
	if not content.open_kits().is_empty():
		return true
	return content.soul_tree != null and (not content.soul_tree.open_oaths().is_empty() or has_armory(content))


static func has_armory(content: ContentDB) -> bool:
	return content.upgrades.any(func(u: UpgradeDef) -> bool: return u.kind == UpgradeDef.Kind.RULES and u.armory and Profile.level_of(u) > 0)


## The weapons the hero may start with: those the Armory's level opened, in its order, minus
## the ones still locked in the dungeon.
static func weapons(content: ContentDB) -> Array[WeaponDef]:
	return ShrineUpgrades.armory_weapons(content)


## The Armory's level and its words: "Armory level 2: 5 weapons. More in the Tree of Souls."
static func armory_line(content: ContentDB) -> String:
	for upgrade in content.upgrades:
		if upgrade.kind == UpgradeDef.Kind.RULES and upgrade.armory and Profile.level_of(upgrade) > 0:
			var level := Profile.level_of(upgrade)
			var count := weapons(content).size()
			if level >= upgrade.max_level:
				return TranslationServer.tr("Armory level %d (max): %d weapons.") % [level, count]
			return TranslationServer.tr("Armory level %d: %d weapons. More in the Tree of Souls.") % [level, count]
	return ""


## The weapon a run starts with when none is picked (the hero's usual one).
static func usual_weapon(content: ContentDB) -> WeaponDef:
	for item in content.player.starting_equipment:
		if item is WeaponDef:
			return item
	return null


func open(content: ContentDB) -> void:
	# Only shows the choice: a saved oath the tree no longer opens reads as Unsworn
	# (Game.sworn_oath) but stays saved; only the player's taps change it (Profile.select_*).
	_content = content
	_fill_cards()
	_fill_weapons()
	show()


## The player tapped an oath's card (null: Unsworn).
func choose_oath(oath: OathDef) -> void:
	Profile.select_oath(oath)
	_fill_cards()
	_fill_weapons()


## The player tapped a weapon's slot (null: the usual one).
func choose_weapon(weapon: WeaponDef) -> void:
	Profile.select_start_weapon(weapon)
	_fill_weapons()


func start() -> void:
	hide()
	started.emit()


func _fill_cards() -> void:
	_sworn = Game.sworn_oath(_content)
	UiParts.clear(_cards)
	_cards.add_child(_card(null, true))
	if _content.soul_tree:
		for oath in _content.soul_tree.oaths():
			var is_open := _content.soul_tree.open_oaths().has(oath)
			_cards.add_child(_card(oath, is_open))
	for kit in _content.kits:
		if kit:
			_cards.add_child(_card(kit, kit.is_unlocked()))


func _card(oath: OathDef, is_open: bool) -> Control:
	var chosen := oath == _sworn
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.disabled = not is_open
	# A dark recess; the sworn one wears a gold frame over it, over a faint gold wash.
	var style := UiSkin.inset()
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		card.add_theme_stylebox_override(state, style)
	if chosen:
		card.draw.connect(func() -> void:
			card.draw_rect(Rect2(Vector2.ZERO, card.size).grow(-6), Color(1.0, 0.8, 0.35, 0.16))
			UiSkin.draw_edge(card, Rect2(Vector2.ZERO, card.size), UiSkin.GOLD))
	card.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		choose_oath(oath))
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 12
	column.offset_right = -12
	column.offset_top = 10
	column.offset_bottom = -10
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(0, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = oath.icon if oath else _content.player.starting_equipment[0].icon if not _content.player.starting_equipment.is_empty() else null
	icon.modulate = Color.WHITE if is_open else Color(0.4, 0.38, 0.36)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon)
	var label_name := UiSkin.label(tr(oath.display_name) if oath else tr("Unsworn"), Fonts.BODY, (oath.color.lerp(Color.WHITE, 0.3) if oath else UiSkin.TEXT) if is_open else UiSkin.DIM, true)  # (a long name wraps: "Serment de la Tempête")
	label_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label_name)
	# What it changes: gains in green, costs in red (faded while it is locked).
	var lines: Array = oath.effects() if oath else [[tr("The usual start: the Katana, no rule changed."), 0]]
	for line: Array in lines:
		var color: Color = UiSkin.TEXT
		if line[1] > 0:
			color = UiSkin.GOOD
		elif line[1] < 0:
			color = UiSkin.BAD
		var words := UiSkin.label(line[0], Fonts.SMALL, color if is_open else Color(color, 0.55), true)  # fine print: five cards abreast
		words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(words)
	if not is_open and oath.is_kit():
		# A kit: the feat that opens it (named even when secret: kits ask for plain feats).
		var feat := UiSkin.label(tr("Opens with a feat: %s") % tr(oath.unlocked_by.description), Fonts.SMALL, UiSkin.DIM, true)
		feat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(feat)
	elif not is_open:
		var branch := ""
		for node in _content.soul_tree.nodes:
			if node.oath == oath and node.branch < _content.soul_tree.branches.size():
				branch = tr(_content.soul_tree.branches[node.branch])
		var lock := UiSkin.label(tr("Opens at the end of the %s branch of the Tree of Souls, at the shrine.") % branch, Fonts.SMALL, UiSkin.DIM, true)
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(lock)
	if chosen:
		var mark := UiSkin.label(tr("Sworn"), Fonts.BODY, UiSkin.GOLD)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(mark)
	for child in column.get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _fill_weapons() -> void:
	UiParts.clear(_weapons)
	_weapons_box.visible = has_armory(_content)
	if not _weapons_box.visible:
		return
	var oath := Game.sworn_oath(_content)
	var usual := usual_weapon(_content)
	var picked := Game.picked_weapon(_content)
	var shown := picked if picked else usual
	if oath and oath.starting_weapon:
		_weapon_text.text = tr("Your starting weapon (Armory): your oath brings its own, the %s. Without the oath, pick one below.") % tr(oath.starting_weapon.display_name)
	else:
		_weapon_text.text = tr("Your starting weapon (Armory): %s.") % (tr(shown.display_name) if shown else tr("the usual one"))
	_armory_text.text = armory_line(_content)
	for weapon in weapons(_content):
		var slot := ItemSlot.new(56.0)
		slot.item = weapon
		slot.tooltip_text = tr(weapon.display_name)
		slot.selected = weapon == shown
		slot.show_level = false
		# Tapping the usual weapon, or the one picked again, goes back to the usual start.
		slot.pressed.connect(func() -> void:
			Sfx.play_ui(Sfx.bank.ui_click)
			choose_weapon(null if weapon == picked or weapon == usual else weapon))
		_weapons.add_child(slot)


func _build() -> void:
	_window = MenuWindow.new(tr("At the Well's Edge"))
	add_child(_window)
	var scene_owner: Node = owner if owner != null else self
	_window.close_button.text = tr("Back")
	_window.close_button.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_close)
		hide())
	var intro := UiSkin.label(tr("Swear an oath for this run, or go down unsworn. It changes how you start: pick one, then Begin the descent."), Fonts.BODY, UiSkin.TEXT, true)
	intro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_window.header_left.add_child(intro)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = CARD_SIZE.y + 8
	_window.body.add_child(scroll)
	TouchScroll.attach(scroll)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 12)
	scroll.add_child(_cards)
	MenuWindow.expose(_cards, "OathCards", scene_owner)
	_weapons_box = MenuWindow.strip()
	_window.body.add_child(_weapons_box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_weapons_box.add_child(column)
	_weapon_text = UiSkin.label("", Fonts.BODY, UiSkin.GOLD, true)
	column.add_child(_weapon_text)
	# The slots, and beside them the Armory's level (on one line with them: the window is full
	# on a 720-line screen).
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	var weapon_scroll := ScrollContainer.new()
	weapon_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	weapon_scroll.custom_minimum_size.y = 64
	weapon_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(weapon_scroll)
	_armory_text = UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	_armory_text.custom_minimum_size.x = ARMORY_TEXT_WIDTH
	_armory_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_armory_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_armory_text)
	MenuWindow.expose(_armory_text, "ArmoryText", scene_owner)
	TouchScroll.attach(weapon_scroll)
	_weapons = HBoxContainer.new()
	_weapons.add_theme_constant_override("separation", 6)
	weapon_scroll.add_child(_weapons)
	MenuWindow.expose(_weapons, "WeaponRow", scene_owner)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_window.body.add_child(spacer)
	_start = MenuWindow.button(tr("Begin the descent"), Fonts.BODY, 60)
	_start.pressed.connect(start)
	_window.body.add_child(_start)
	MenuWindow.expose(_start, "StartRunButton", scene_owner)
