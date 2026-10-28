class_name InventoryPanel
extends Control
## Bag screen, in the game's skin (RpgWindow, ItemSlot): the hero and what they wear (weapon,
## head, body) with the belt and their stats on the left, the bag in the middle, the picked item's
## card on the right (rarity, stats, rune sockets, what to do with it). Pauses the game while
## open. Built in code. "Perks" in the header opens the build (BuildWindow): the families and the
## perks taken, in words.
##
## - **Compartments and their tabs** (Inventory, BagCategorySet, data/items/bag_categories.tres):
##   weapons, armor, runes, tomes and scrolls, consumables, the rest, each with its own places
##   ("Runes  3 / 16" under the tabs) and a tab with its count (red when full) and a gold gem while
##   something new waits in it; inside a tab the rarest come first. The tab shown is kept while
##   the run lasts. Tap a tab, or Q / E, LB / RB (MenuNav).
## - **Actions** (BagAction): Equip / Use, To belt, Drop, Dismantle, each a button on the card
##   and, on keys and gamepads, a key straight on the focused slot (Enter or A uses, X
##   dismantles, G or Y drops), its cap on its button. A rare piece (or one with runes) asks a
##   second press before it breaks (DismantleRules.needs_confirm).
## - With keys and a gamepad the focus is the pick: moving onto a slot shows its card.
## Identical items stack (Inventory): one slot, "x2", one place of its compartment. "Dismantle the
## worse" breaks down, after a confirmation, every piece of the tab open worse than what is worn
## (PlayerPack.worse_gear()).

const MenuNavScript := preload("res://src/autoload/menu_nav.gd")  # its static helpers are called on the script, not the autoload

signal closed

const NO_SLOT := -1
## Three columns of finger-sized slots 16 units apart (four would widen the bag past a 1280-wide
## screen in French); the grid scrolls.
const BAG_COLUMNS := 3
const BAG_SLOT := 66.0
## Room between two slots or buttons: a finger's (MenuWindow.TOUCH_GAP).
const GAP := MenuWindow.TOUCH_GAP
## The compartments' tabs per row.
const TAB_COLUMNS := 3
## The bag's grid width (its tabs, its notes share it).
const BAG_WIDTH := BAG_COLUMNS * BAG_SLOT + (BAG_COLUMNS - 1) * GAP
const GEAR_SLOT := 74.0
## The pictogram an empty equipment slot shows.
const GEAR_PLACEHOLDERS := {
	EquipmentDef.Slot.WEAPON: "res://assets/ui/placeholders/weapon.png",
	EquipmentDef.Slot.HEAD: "res://assets/ui/placeholders/head.png",
	EquipmentDef.Slot.BODY: "res://assets/ui/placeholders/body.png",
}
## How fast the right stick scrolls the item's details, UI units a second.
const DETAILS_SCROLL_SPEED := 720.0
## The bag's compartments (their tabs) and what goes in each.
const CATEGORIES: BagCategorySet = Inventory.CATEGORIES

## Every family of perks (for the build window).
var content: ContentDB
var _player: Player
var _selected_item: ItemDef
var _selected_slot := NO_SLOT
## Belt slot selected (-1 = none).
var _selected_belt := NO_SLOT
## The tab shown (an index of CATEGORIES.categories). The tab picked stays picked until the run
## ends (forget_run(): the Game, and its panel, live on through a restart).
var _category := 0
## The stacks (ItemDef.stack_key()) the player has looked at: any other one in the bag is new.
var _seen := {}
## The stacks shown in the bag since it opened (seen once it closes).
var _shown := {}
## What the card's buttons do, in their order.
var _actions: Array[BagAction] = [BagUseAction.new(), BagBeltAction.new(), BagDropAction.new(), BagDismantleAction.new()]
## BagAction -> its Button.
var _action_buttons := {}
## The action a first press armed (it asks again), and on what (BagSelection.key()).
var _armed_action: BagAction
var _armed_on := ""

var _window: RpgWindow
var _slot_buttons := {}
var _belt_slots: Array[ItemSlot] = []
## The bag's slots shown (items first, then the free places), in order.
var _bag_slots: Array[ItemSlot] = []
var _tabs: Array[BagTab] = []
var _tab_row: TabRow
var _category_name: Label
## "Over its places": a compartment holding more than it has room for (an old save).
var _over_note: Label
var _portrait: HeroPortrait
var _stats: GridContainer
var _item_grid: GridContainer
## The picked item (ItemCard, as the merchant's).
var _card: ItemCard
var _details_scroll: ScrollContainer
## The right stick's cap by the card, while its details are longer than their box.
var _scroll_hint: Control
var _sockets: HBoxContainer
var _dismantle_button: Button
## The card's "Dismantle value: 12 gold" line.
var _dismantle_note: Label
var _worse_button: Button
## "Dismantle the worse": the list, the gold, Dismantle / Keep them.
var _confirm: DismantleWorseDialog
var _gold: Label
## Built nodes reachable as %Name once the panel is built.
var _named := ExposedNodes.new()
var _build_window: BuildWindow
var _perks_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()


func open(player: Player) -> void:
	if _player != player:
		if is_instance_valid(_player):
			_player.dismantled.disconnect(_on_dismantled)
		player.dismantled.connect(_on_dismantled)
	_player = player
	_confirm.hide()
	_shown.clear()
	_clear_selection()
	_refresh()
	show()
	Sfx.play_ui(Sfx.bank.ui_open)


func close() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	_build_window.hide()
	_confirm.hide()
	_seen.merge(_shown, true)  # what was shown is no longer new
	_shown.clear()
	hide()
	closed.emit()


## The build: families and perks, over the bag (Close comes back to it).
func open_build() -> void:
	var families: Array[SynergyDef] = content.synergies if content else ([] as Array[SynergyDef])
	_build_window.show_build(_player.perks, families)
	Sfx.play_ui(Sfx.bank.ui_open)


func is_build_open() -> bool:
	return _build_window.visible


## A new run begins in the same Game (Restart): nothing seen yet, the first tab.
func forget_run() -> void:
	_seen.clear()
	_shown.clear()
	_category = 0
	_clear_selection()


## The tab shown (an index of CATEGORIES.categories).
func category_index() -> int:
	return _category


## Shows tab `index` (a tap on it, Q / E, LB / RB). With keys or a gamepad the focus goes to its
## first slot.
func show_category(index: int) -> void:
	if index < 0 or index >= CATEGORIES.categories.size():
		return
	if index == _category:
		_update_tab_buttons()
		return
	_category = index
	if _player == null or not visible:
		return  # shown when the bag opens
	Sfx.play_ui(Sfx.bank.ui_click)
	_disarm()
	if _selected_item and CATEGORIES.index_of(_selected_item) != _category:
		_clear_selection()
	_refresh()
	if InputDevice.navigating and InputDevice.uses_buttons() and not _bag_slots.is_empty():
		_bag_slots[0].grab_focus()


## The bag slot showing `item`'s stack in the tab shown (null if it isn't there).
func slot_for(item: ItemDef) -> ItemSlot:
	if item == null:
		return null
	var key := item.stack_key()
	for slot in _bag_slots:
		if slot.item and slot.item.stack_key() == key:
			return slot
	return null


## The tab of CATEGORIES.categories[index] (tests).
func tab(index: int) -> BagTab:
	return _tabs[index]


## Is the confirmation of "Dismantle the worse" up? (tests)
func is_confirm_open() -> bool:
	return _confirm.visible


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		if _confirm.visible and event.is_action_pressed("ui_cancel"):
			_confirm.hide()
		elif _build_window.visible and event.is_action_pressed("ui_cancel"):
			_build_window.hide()
		elif _armed_action and event.is_action_pressed("ui_cancel"):
			_disarm()  # Back first takes back the "Sure?"
			_refresh_details()
		else:
			close()


## The quick actions: a key or gamepad button does an action on the item picked (the focused
## slot), without going to its button. Before the GUI: Enter on a slot uses its item rather than
## pressing the slot.
func _input(event: InputEvent) -> void:
	if not visible or _player == null or _confirm.visible or _build_window.visible:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	for action in _actions:
		if action.input == &"" or not event.is_action_pressed(action.input):
			continue
		if action.input == &"ui_accept" and not _item_slot_focused():
			return  # Enter on a button presses the button
		get_viewport().set_input_as_handled()
		_do(action)
		return


## The right stick scrolls the card's details (the mouse has its wheel, a finger drags).
func _process(delta: float) -> void:
	if not visible or _confirm.visible or _build_window.visible:
		return
	var way := Input.get_axis(&"menu_scroll_up", &"menu_scroll_down")
	if way != 0.0:
		_details_scroll.scroll_vertical += roundi(way * DETAILS_SCROLL_SPEED * delta)
	# On a gamepad only (keys and mouse: the wheel).
	var bar := _details_scroll.get_v_scroll_bar()
	_scroll_hint.visible = InputDevice.uses_gamepad() and bar.max_value - bar.page > 1.0


func _item_slot_focused() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is ItemSlot and (_bag_slots.has(focus) or _belt_slots.has(focus) or _slot_buttons.values().has(focus))


# --- Display -----------------------------------------------------------------

func _refresh() -> void:
	_perks_button.text = tr("Perks (%d)") % _player.perks.entries.size()
	for slot: EquipmentDef.Slot in _slot_buttons:
		var button: ItemSlot = _slot_buttons[slot]
		button.item = _player.equipment.get_item(slot)
	for i in _belt_slots.size():
		var button := _belt_slots[i]
		button.item = _player.belt.item_at(i)
		button.count = _player.belt.count_at(i)
	_gold.text = tr("Gold %d") % _player.gold
	_portrait.show_hero(_player)
	_fill_stats()

	var inventory := _player.inventory
	var grouped := inventory.grouped()
	_know_worn()
	if not _tab_shown(_category, grouped):
		_category = _first_tab(grouped)
	_update_tabs(grouped)
	_fill_grid(grouped)
	var worse := _player.pack.worse_gear(_category)
	_worse_button.text = tr("Dismantle the worse (%d)") % worse.size()
	_worse_button.disabled = worse.is_empty()
	_show_selection()


## The tab's stacks, rarest first, then its compartment's free places.
func _fill_grid(grouped: Array[Dictionary]) -> void:
	UiParts.clear(_item_grid)
	_bag_slots.clear()
	for entry in CATEGORIES.entries_in(_category, grouped):
		var item: ItemDef = entry.item
		var button := ItemSlot.new(BAG_SLOT)
		button.item = item
		button.count = entry.count
		button.fresh = not _seen.has(item.stack_key())
		button.pressed.connect(_select_item.bind(item))
		button.focus_entered.connect(_on_slot_focused.bind(button))
		button.gui_input.connect(_on_slot_input.bind(button))
		_item_grid.add_child(button)
		_bag_slots.append(button)
		_shown[item.stack_key()] = true
	# The empty places left in the compartment: the keys can stand on them (nothing to do there).
	for i in _player.inventory.free_in(_category):
		var empty := ItemSlot.new(BAG_SLOT)
		empty.focus_entered.connect(_on_slot_focused.bind(empty))
		_item_grid.add_child(empty)
		_bag_slots.append(empty)
	MenuNavScript.set_first(_window, _bag_slots[0] if not _bag_slots.is_empty() else _slot_buttons[EquipmentDef.Slot.WEAPON])


## Each tab's count (red when its compartment is full) and new mark; the ones that hide when
## empty are put away. Under them, the tab open and its places ("Runes  3 / 16").
func _update_tabs(grouped: Array[Dictionary]) -> void:
	var inventory := _player.inventory
	for i in _tabs.size():
		var bag_tab := _tabs[i]
		bag_tab.count = CATEGORIES.count_in(i, grouped)
		bag_tab.full = inventory.is_compartment_full(i)
		bag_tab.visible = _tab_shown(i, grouped)
		bag_tab.fresh = grouped.any(func(entry: Dictionary) -> bool:
			return CATEGORIES.index_of(entry.item) == i and not _seen.has((entry.item as ItemDef).stack_key()))
	_update_tab_buttons()
	_category_name.text = tr("{tab}  {used} / {places}").format({
		"tab": tr(CATEGORIES.categories[_category].display_name),
		"used": inventory.places_used_in(_category), "places": inventory.capacity_of(_category) })
	var over := inventory.over_capacity(_category) > 0
	_category_name.add_theme_color_override("font_color", UiSkin.BAD if over or inventory.is_compartment_full(_category) else UiSkin.GOLD)
	_over_note.visible = over


func _update_tab_buttons() -> void:
	_tab_row.select(_category)
	for bag_tab in _tabs:
		bag_tab.queue_redraw()


func _tab_shown(index: int, grouped: Array[Dictionary]) -> bool:
	return not CATEGORIES.categories[index].hidden_when_empty or CATEGORIES.count_in(index, grouped) > 0


func _first_tab(grouped: Array[Dictionary]) -> int:
	for i in CATEGORIES.categories.size():
		if _tab_shown(i, grouped):
			return i
	return 0


## What is worn or on the belt is known: back in the bag, it is not new.
func _know_worn() -> void:
	for slot: EquipmentDef.Slot in _slot_buttons:
		var worn := _player.equipment.get_item(slot)
		if worn:
			_seen[worn.stack_key()] = true
	for i in Belt.SLOTS:
		if _player.belt.item_at(i):
			_seen[_player.belt.item_at(i).stack_key()] = true


func _fill_stats() -> void:
	var stats := _player.get_stats()
	var lines := [
		[tr("Level"), str(_player.level)],
		[tr("Health"), "%d / %d" % [_player.hp, _player.get_max_hp()]],
		[tr("Damage"), str(_player.get_power())],
		[tr("Armor"), str(stats.defense)],
		[tr("Move speed"), str(roundi(stats.move_speed))],
		[tr("Critical hits"), tr("%d%%") % roundi(stats.crit_chance * 100.0)],
		[tr("Attack speed"), tr("%+d%%") % roundi(stats.attack_speed * 100.0)],
		[tr("Skill damage"), tr("%+d%%") % roundi(stats.skill_power * 100.0)],
		[tr("Skill recharge"), tr("%+d%%") % roundi(minf(stats.cooldown_reduction, Combat.RULES.max_cooldown_reduction) * 100.0)],
	]
	UiParts.stat_rows(_stats, lines)


## The pick shown on the slots (the pulsing frame) and on the card.
func _show_selection() -> void:
	for slot: EquipmentDef.Slot in _slot_buttons:
		(_slot_buttons[slot] as ItemSlot).selected = _selected_slot == slot
	for i in _belt_slots.size():
		_belt_slots[i].selected = _selected_belt == i
	var key := _selected_item.stack_key() if _selected_item and _selected_slot == NO_SLOT and _selected_belt == NO_SLOT else ""
	for slot in _bag_slots:
		slot.selected = slot.item != null and slot.item.stack_key() == key
		if slot.selected:
			slot.fresh = false
	_refresh_details()


func _selection() -> BagSelection:
	if _selected_slot != NO_SLOT:
		return BagSelection.new(_player, _player.equipment.get_item(_selected_slot), _selected_slot)
	if _selected_belt != NO_SLOT:
		return BagSelection.new(_player, _player.belt.item_at(_selected_belt), BagSelection.NONE, _selected_belt)
	return BagSelection.new(_player, _selected_item)


func _refresh_details() -> void:
	var selection := _selection()
	var item := selection.item
	if _armed_action and _armed_on != selection.key():
		_disarm()
	for action in _actions:
		var button: Button = _action_buttons[action]
		button.visible = action.available(selection)
		var armed := _armed_action == action
		button.text = action.confirm_label(selection) if armed else action.label(selection)
		button.add_theme_color_override("font_color", UiSkin.GOLD if armed else UiSkin.TEXT)
	# Gear in the bag breaks down for gold (never what is worn).
	var gold := (_actions[3] as BagDismantleAction).gold(selection) if selection.in_bag() else 0
	_dismantle_note.visible = gold > 0
	_dismantle_note.text = tr("Dismantle value: %d gold") % gold
	if gold > 0 and not (item as EquipmentDef).runes.is_empty():
		_dismantle_note.text += "\n" + tr("The runes set in it break with it (counted in the gold).")
	# An armed action says how to go on (on the card's note: its button keeps a short word).
	if _armed_action:
		_dismantle_note.visible = true
		_dismantle_note.text = _armed_action.confirm_note(selection)
	UiParts.clear(_sockets)
	if item == null:
		_card.show_empty(tr("Pick an item"), tr("Choose a slot to see what it does."))
		return
	_card.show_item(item, _player.belt.count_at(_selected_belt) if selection.on_belt() else (_player.inventory.count_of(item) if selection.in_bag() else 1))
	# Gear in the bag: what wearing it would change (green better, red worse; nothing for what
	# is worn).
	var equipment := item as EquipmentDef
	if equipment and _selected_slot == NO_SLOT:
		_card.show_compare(equipment, _player.equipment.get_item(equipment.slot))
	_fill_sockets(equipment)


## The card's words: details and comparison (tests).
func card_text() -> String:
	return _card.text()


## A weapon's rune sockets, as slots (set at a forge).
func _fill_sockets(equipment: EquipmentDef) -> void:
	if equipment == null or equipment.socket_count() <= 0:
		return
	_sockets.add_child(UiSkin.label(tr("Runes"), Fonts.BODY, UiSkin.DIM))
	for i in equipment.socket_count():
		var socket := ItemSlot.new(46.0)
		socket.item = equipment.runes[i] if i < equipment.runes.size() else null
		socket.caption = "-"
		socket.tooltip_text = tr(socket.item.description) if socket.item else tr("An empty socket: a forge sets runes in it.")
		socket.mouse_filter = Control.MOUSE_FILTER_PASS
		socket.focus_mode = Control.FOCUS_NONE
		_sockets.add_child(socket)


# --- Selection & actions -----------------------------------------------------

func _select_item(item: ItemDef, sound := true) -> void:
	if sound:
		Sfx.play_ui(Sfx.bank.ui_click)
	_selected_item = item
	_selected_slot = NO_SLOT
	_selected_belt = NO_SLOT
	if item:
		_seen[item.stack_key()] = true
	_show_selection()


func _select_slot(slot: EquipmentDef.Slot, sound := true) -> void:
	if sound:
		Sfx.play_ui(Sfx.bank.ui_click)
	_selected_item = null
	_selected_belt = NO_SLOT
	_selected_slot = slot
	_show_selection()


func _select_belt(index: int, sound := true) -> void:
	if _player.belt.item_at(index) == null:
		if not sound:  # the keys came onto an empty belt slot: nothing picked
			_clear_selection()
			_show_selection()
		return
	if sound:
		Sfx.play_ui(Sfx.bank.ui_click)
	_selected_item = null
	_selected_slot = NO_SLOT
	_selected_belt = index
	_show_selection()


func _clear_selection() -> void:
	_selected_item = null
	_selected_slot = NO_SLOT
	_selected_belt = NO_SLOT
	_disarm()


## Keys and gamepads: the slot the focus comes onto is the one picked (its card shows). Not when
## the mouse or a finger gave it the focus: a click picks it as a press.
func _on_slot_focused(slot: ItemSlot) -> void:
	if not visible or _player == null or not InputDevice.navigating:
		return
	if _bag_slots.has(slot):
		if slot.item:
			_select_item(slot.item, false)
		else:
			_clear_selection()
			_show_selection()
		return
	var belt_index := _belt_slots.find(slot)
	if belt_index >= 0:
		_select_belt(belt_index, false)
		return
	for worn: EquipmentDef.Slot in _slot_buttons:
		if _slot_buttons[worn] == slot:
			_select_slot(worn, false)


## A right click on a slot uses its item at once (Equip, Use, Learn, Unequip).
func _on_slot_input(event: InputEvent, slot: ItemSlot) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_RIGHT or slot.item == null:
		return
	slot.accept_event()
	if _bag_slots.has(slot):
		_select_item(slot.item, false)
	elif _belt_slots.has(slot):
		_select_belt(_belt_slots.find(slot), false)
	else:
		for worn: EquipmentDef.Slot in _slot_buttons:
			if _slot_buttons[worn] == slot:
				_select_slot(worn, false)
	_do(_actions[0])


## Does `action` on the pick: at once, or, if it asks first, on the second press (the first one
## arms it: its button says "Sure? ..."). Then the bag is shown again and, with keys, the focus
## stays on the stack (or the slot that took its place), so pressing again goes on through it.
func _do(action: BagAction) -> void:
	var selection := _selection()
	if not action.available(selection):
		return
	if action.needs_confirm(selection) and not (_armed_action == action and _armed_on == selection.key()):
		_armed_action = action
		_armed_on = selection.key()
		Sfx.play_ui(Sfx.bank.ui_click)
		_refresh_details()
		return
	_disarm()
	var focus := get_viewport().gui_get_focus_owner()
	var index := _bag_slots.find(focus) if focus is ItemSlot else -1  # (a button may hold the focus)
	if not action.run(selection):
		_refresh()
		return
	_keep_picked(selection)
	_refresh()
	if index >= 0 and InputDevice.navigating and InputDevice.uses_buttons():
		_focus_after(index)


## After an action: what was picked stays picked while it is still there (the rest of a stack, a
## belt slot not empty yet), else nothing is.
func _keep_picked(selection: BagSelection) -> void:
	if selection.in_bag():
		_keep_stack_selected()
	elif selection.on_belt() and _player.belt.item_at(selection.belt) == null:
		_clear_selection()
	elif selection.is_worn() and _player.equipment.get_item(selection.worn_slot as EquipmentDef.Slot) == null:
		_clear_selection()


## The focus after the bag was shown again: on the picked stack, else on the slot that took the
## place of the one gone (the next item), else the last one.
func _focus_after(index: int) -> void:
	var target := slot_for(_selected_item) if _selected_item else null
	if target == null and not _bag_slots.is_empty():
		target = _bag_slots[mini(index, _bag_slots.size() - 1)]
	if target:
		target.grab_focus()


func _disarm() -> void:
	_armed_action = null
	_armed_on = ""


## After one of a stack is gone, the rest of it stays picked (else nothing is).
func _keep_stack_selected() -> void:
	var rest := _player.inventory.find_like(_selected_item)
	if rest:
		_selected_item = rest
	else:
		_clear_selection()


## "Dismantle the worse": what would go, and the gold, before anything breaks.
func _on_worse_pressed() -> void:
	var worse := _player.pack.worse_gear(_category)
	if worse.is_empty():
		return
	Sfx.play_ui(Sfx.bank.ui_open)
	_disarm()
	_confirm.ask(worse)


func _on_worse_confirmed() -> void:
	_player.pack.dismantle_all(_player.pack.worse_gear(_category))
	if _selected_item:
		_keep_stack_selected()
	_refresh()


## Coins fly from the bag (or the card) to the gold counter.
func _on_dismantled(_items: Array[ItemDef], gold: int) -> void:
	if not visible:
		return
	var from := _dismantle_button.get_global_rect().get_center() if _dismantle_button.is_visible_in_tree() else _item_grid.get_global_rect().get_center()
	GoldBurst.play(self, from, _gold.get_global_rect().get_center(), gold)
	# As the coins land: brackets flash round the count (its words never swell).
	get_tree().create_timer(0.6, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(_gold):
			TextCue.ping(_gold, UiSkin.GOLD, 0.35))


# --- Building ----------------------------------------------------------------

func _build() -> void:
	_window = RpgWindow.new(tr("Inventory"))
	_window.close_requested.connect(close)
	add_child(_window)
	_gold = UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
	_window.header_right.add_child(_gold)
	_perks_button = Button.new()
	_perks_button.text = tr("Perks")
	_perks_button.custom_minimum_size = Vector2(140, MenuWindow.TOUCH_MIN)
	_perks_button.pressed.connect(open_build)
	_window.header_right.add_child(_perks_button)
	_build_window = BuildWindow.new()
	_build_window.name = "BuildWindow"
	_build_window.hide()
	_build_window.close_requested.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_close)
		_build_window.hide())
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	_window.body.add_child(columns)
	_build_hero(columns)
	_build_bag(columns)
	_build_card(columns)
	_build_confirm()
	_named.expose_to(self)
	add_child(_build_window)  # over the bag


## Left: the hero, what they wear, the belt, their stats.
func _build_hero(columns: HBoxContainer) -> void:
	var hero: Dictionary = RpgWindow.section(tr("Hero"))
	(hero.box as Control).custom_minimum_size.x = 330
	columns.add_child(hero.box)
	var gear_row := HBoxContainer.new()
	gear_row.add_theme_constant_override("separation", GAP)
	hero.column.add_child(gear_row)
	_portrait = HeroPortrait.new()
	_portrait.name = "Portrait"
	_named.add(_portrait)
	gear_row.add_child(_portrait)
	for slot: EquipmentDef.Slot in [EquipmentDef.Slot.WEAPON, EquipmentDef.Slot.HEAD, EquipmentDef.Slot.BODY]:
		var button := ItemSlot.new(GEAR_SLOT)
		button.caption = tr(EquipmentDef.SLOT_NAMES[slot])
		button.placeholder = load(GEAR_PLACEHOLDERS[slot])
		button.name = "%sSlot" % EquipmentDef.SLOT_NAMES[slot]
		button.pressed.connect(_select_slot.bind(slot, true))
		button.focus_entered.connect(_on_slot_focused.bind(button))
		button.gui_input.connect(_on_slot_input.bind(button))
		_named.add(button)
		gear_row.add_child(button)
		_slot_buttons[slot] = button
	hero.column.add_child(UiSkin.label(tr("Belt"), Fonts.BODY, UiSkin.GOLD))
	var belt_row := HBoxContainer.new()
	belt_row.add_theme_constant_override("separation", GAP)
	hero.column.add_child(belt_row)
	for i in Belt.SLOTS:
		var button := ItemSlot.new(MenuWindow.TOUCH_MIN)
		button.caption = str(i + 1)
		button.name = "BeltSlot%d" % (i + 1)
		button.pressed.connect(_select_belt.bind(i, true))
		button.focus_entered.connect(_on_slot_focused.bind(button))
		button.gui_input.connect(_on_slot_input.bind(button))
		_named.add(button)
		belt_row.add_child(button)
		_belt_slots.append(button)
	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 10)
	_stats.add_theme_constant_override("v_separation", 0)
	_stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.column.add_child(_stats)


## Middle: the tabs, the tab's name between its keys, the bag's slots, Dismantle the worse.
func _build_bag(columns: HBoxContainer) -> void:
	var bag: Dictionary = RpgWindow.section(tr("Bag"))
	(bag.column as VBoxContainer).add_theme_constant_override("separation", GAP)  # (the grid's last row and the button under it)
	columns.add_child(bag.box)
	# The compartments: a TabRow of BagTabs (their keys' caps stand around the name below).
	_tab_row = TabRow.new(false)
	_tab_row.name = "BagTabs"
	_tab_row.sound = false  # show_category() clicks
	_tab_row.custom_minimum_size.x = BAG_WIDTH
	bag.column.add_child(_tab_row)
	# Two rows of finger-sized tabs, 16 units apart: six in one row would widen the bag past a
	# 1280-wide screen.
	var tab_grid := GridContainer.new()
	tab_grid.columns = TAB_COLUMNS
	tab_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_grid.add_theme_constant_override("h_separation", GAP)
	tab_grid.add_theme_constant_override("v_separation", GAP)
	_tab_row.add_child(tab_grid)
	for i in CATEGORIES.categories.size():
		var bag_tab := BagTab.new(CATEGORIES.categories[i])
		tab_grid.add_child(bag_tab)
		_tab_row.add_button(bag_tab)
		_tabs.append(bag_tab)
		_named.add(bag_tab)
	_tab_row.picked.connect(show_category)
	var naming := HBoxContainer.new()
	naming.add_theme_constant_override("separation", 6)
	bag.column.add_child(naming)
	naming.add_child(PromptGlyph.make(&"menu_prev_tab"))
	_category_name = UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
	_category_name.name = "CategoryName"
	_category_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_category_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_category_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # a long name never widens the bag
	_named.add(_category_name)
	naming.add_child(_category_name)
	naming.add_child(PromptGlyph.make(&"menu_next_tab"))
	_over_note = UiSkin.label(tr("More than it has room for: make room before anything new goes in."), Fonts.BODY, UiSkin.BAD, true)
	_over_note.name = "OverNote"
	_over_note.custom_minimum_size.x = BAG_WIDTH
	_over_note.hide()
	_named.add(_over_note)
	bag.column.add_child(_over_note)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.x = BAG_WIDTH + 6
	bag.column.add_child(scroll)
	_item_grid = GridContainer.new()
	_item_grid.columns = BAG_COLUMNS
	_item_grid.name = "ItemGrid"
	_item_grid.add_theme_constant_override("h_separation", GAP)
	_item_grid.add_theme_constant_override("v_separation", GAP)
	_named.add(_item_grid)
	scroll.add_child(_item_grid)
	_worse_button = _button(tr("Dismantle the worse (%d)") % 0, "DismantleWorseButton", _on_worse_pressed)
	_worse_button.add_theme_font_size_override("font_size", Fonts.BODY)
	_worse_button.custom_minimum_size = Vector2(0, MenuWindow.TOUCH_MIN)
	_worse_button.size_flags_horizontal = Control.SIZE_FILL
	_worse_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # French is long: two lines, not a wider bag
	bag.column.add_child(_worse_button)


## Right: the picked item, and what to do with it (each action's button, its key on it).
func _build_card(columns: HBoxContainer) -> void:
	var card: Dictionary = RpgWindow.section(tr("Item"))
	(card.box as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(card.box)
	(card.title as Label).hide()
	_card = ItemCard.build(card.column, 84.0)
	_details_scroll = _card.details_scroll
	_details_scroll.name = "DetailsScroll"
	_named.add(_details_scroll)
	_card.details.name = "ItemDetails"
	# The right stick scrolls a long card: its cap, top right, while there is more to see.
	_scroll_hint = Control.new()
	_scroll_hint.name = "ScrollHint"
	_scroll_hint.custom_minimum_size = Vector2(0, 28)
	_scroll_hint.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scroll_glyph := PromptGlyph.make(&"menu_scroll")
	_scroll_hint.add_child(scroll_glyph)
	scroll_glyph.resized.connect(func() -> void: _scroll_hint.custom_minimum_size.x = scroll_glyph.size.x)
	_named.add(_scroll_hint)
	_card.top.add_child(_scroll_hint)
	_sockets = HBoxContainer.new()
	_sockets.alignment = BoxContainer.ALIGNMENT_BEGIN
	_sockets.add_theme_constant_override("separation", 6)
	card.column.add_child(_sockets)
	_dismantle_note = UiSkin.label("", Fonts.BODY, UiSkin.GOLD, true)
	_dismantle_note.name = "DismantleNote"
	_named.add(_dismantle_note)
	card.column.add_child(_dismantle_note)
	# Room over the buttons for their keys' caps (PromptGlyph.badge: over their top edge).
	var room := Control.new()
	room.custom_minimum_size.y = 6
	card.column.add_child(room)
	# A flow: the buttons share a row, and one that no longer fits (French on a 1280-wide
	# screen: Use, To belt, Drop) goes to a second row instead of widening the window.
	var actions := HFlowContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("h_separation", GAP)
	actions.add_theme_constant_override("v_separation", 16)
	card.column.add_child(actions)
	for action in _actions:
		var button := _button(action.label(BagSelection.new(null)), action.node_name, _do.bind(action))
		button.add_theme_font_size_override("font_size", Fonts.BODY)
		actions.add_child(button)
		_action_buttons[action] = button
		if action.input != &"":
			PromptGlyph.badge(button, action.input, PromptGlyph.Place.TOP)
	_dismantle_button = _action_buttons[_actions[3]]


func _build_confirm() -> void:
	_confirm = DismantleWorseDialog.new()
	_confirm.confirmed.connect(_on_worse_confirmed)
	add_child(_confirm)  # over the window (the build window comes over both)
	_named.add(_confirm.yes_button)
	_named.add(_confirm.keep_button)


## A card's button (three in a row on a 16:9 phone: Equip, Drop, Dismantle).
func _button(text: String, node_name: String, callback: Callable) -> Button:
	var button := UiParts.button(text, callback, Vector2(96, MenuWindow.TOUCH_MIN))
	button.name = node_name
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_named.add(button)
	return button

