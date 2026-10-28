class_name ShopPanel
extends Control
## The merchant's shop, in the game's skin (RpgWindow, ItemSlot). Built in code.
## The merchant and his words on top, your gold beside them. Left: what he sells, as slots with
## their price (a padlock on the locked ones), and Reroll. Middle: what you carry, with what he
## pays for each. Right: the picked item's card: what it is, its stats in words, how it compares
## with what you wear, its price, and Buy (or why you can't), Lock, or Sell.
## Reroll buys a new stock (locked entries stay); Lock keeps an entry through rerolls and, if it
## isn't bought, the next merchant sells it at the same price (Merchant). The game is paused.

signal closed

const STOCK_COLUMNS := 3
const STOCK_SLOT := 72.0
## Three columns of finger-sized slots 16 units apart (MenuWindow.TOUCH_MIN, TOUCH_GAP).
const BAG_COLUMNS := 3
const BAG_SLOT := 64.0
## Room between two slots side by side.
const GAP := MenuWindow.TOUCH_GAP
const CARD_SLOT := 84.0

enum Pick { NONE, STOCK, OWN }

var _merchant: Merchant
var _player: Player
var _pick := Pick.NONE
## The stock entry picked (Pick.STOCK).
var _pick_index := -1
## The item of yours picked (Pick.OWN), and whether it is the belt's.
var _pick_item: ItemDef
var _pick_belt := false

var _window: RpgWindow
var _portrait: TextureRect
var _name: Label
var _greeting: Label
var _gold: Label
var _for_sale: GridContainer
var _bag: GridContainer
var _bag_note: Label
var _reroll: Button
var _reroll_note: Label
## The picked item (ItemCard, as the bag's), its price under its name.
var _card: ItemCard
var _price: Label
var _lock_note: Label
var _buy: Button
var _sell: Button
var _lock: Button
## Built nodes reachable as %Name once the panel is built.
var _named := ExposedNodes.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()


func open(merchant: Merchant, player: Player) -> void:
	_merchant = merchant
	_player = player
	_name.text = tr(merchant.def.display_name)
	_greeting.text = tr("\"%s\"") % merchant.def.opening_line()
	_portrait.texture = merchant.def.portrait
	if merchant.stock.is_empty():
		_pick = Pick.NONE
	else:
		_pick = Pick.STOCK
		_pick_index = 0
	_refresh()
	show()


func close() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()
	closed.emit()


## Shows stock entry `index` in the card (Buy, Lock).
func select_stock(index: int) -> void:
	if index < 0 or index >= _merchant.stock.size():
		return
	_pick = Pick.STOCK
	_pick_index = index
	_refresh()


## Shows one of the hero's items in the card (Sell). `from_belt`: the belt's stack.
func select_own(item: ItemDef, from_belt := false) -> void:
	_pick = Pick.OWN
	_pick_item = item
	_pick_belt = from_belt
	_refresh()


## Buys the picked stock entry. False if it can't be bought (gold, full bag).
func buy_selected() -> bool:
	return _pick == Pick.STOCK and _buy_entry(_pick_index)


## Sells the picked item of yours.
func sell_selected() -> bool:
	return _pick == Pick.OWN and _sell_item(_pick_item, _pick_belt)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory")):
		get_viewport().set_input_as_handled()
		close()


# --- Actions ----------------------------------------------------------------------

func _buy_entry(index: int) -> bool:
	if not _merchant.sell_to(_player, index):
		return false
	if _merchant.stock.is_empty():
		_pick = Pick.NONE
	else:
		_pick_index = mini(index, _merchant.stock.size() - 1)
	_refresh()
	return true


func _sell_item(item: ItemDef, from_belt: bool) -> bool:
	if not _merchant.buy_from(_player, item, from_belt):
		return false
	var rest := _player.inventory.find_like(item) if not from_belt else null
	if rest:
		_pick_item = rest  # the rest of its stack stays picked
	elif not _carries(item, from_belt):
		_pick = Pick.NONE
	_refresh()
	return true


func _reroll_stock() -> void:
	if _merchant.reroll(_player):
		_pick = Pick.STOCK if not _merchant.stock.is_empty() else Pick.NONE
		_pick_index = 0
		_refresh()


func _toggle_lock() -> void:
	if _pick == Pick.STOCK:
		_merchant.toggle_lock(_pick_index)
		_refresh()


func _carries(item: ItemDef, from_belt: bool) -> bool:
	if from_belt:
		for i in Belt.SLOTS:
			if _player.belt.item_at(i) == item:
				return true
		return false
	return _player.inventory.items.has(item)


# --- Look -------------------------------------------------------------------------

func _refresh() -> void:
	_gold.text = tr("Gold %d") % _player.gold
	_fill_stock()
	_fill_bag()
	var price := _merchant.reroll_price()
	_reroll.text = tr("Reroll  -  %d gold") % price
	_reroll.disabled = _player.gold < price
	_reroll_note.text = tr("New items for sale. Locked ones stay.") if _player.gold >= price \
		else tr("New items for sale. You need %d more gold.") % (price - _player.gold)
	_refresh_card()


func _fill_stock() -> void:
	UiParts.clear(_for_sale)
	for i in _merchant.stock.size():
		var entry: Dictionary = _merchant.stock[i]
		var slot := ShopSlot.new(STOCK_SLOT)
		slot.item = entry.item
		slot.locked = entry.get("locked", false)
		slot.selected = _pick == Pick.STOCK and _pick_index == i
		slot.pressed.connect(_on_slot.bind(func() -> void: select_stock(i)))
		var affordable: bool = _player.gold >= entry.price
		_for_sale.add_child(_cell(slot, tr("%d gold") % entry.price, UiSkin.GOLD if affordable else UiSkin.BAD))
	if _merchant.stock.is_empty():
		var empty := UiSkin.label(tr("Sold out!"), Fonts.BODY, UiSkin.DIM)
		empty.custom_minimum_size.x = STOCK_SLOT * 2
		_for_sale.add_child(empty)


func _fill_bag() -> void:
	UiParts.clear(_bag)
	var count := 0
	for i in Belt.SLOTS:
		var item := _player.belt.item_at(i)
		if item:
			_bag.add_child(_own_cell(item, _player.belt.count_at(i), true))
			count += 1
	for entry in _player.inventory.grouped():
		_bag.add_child(_own_cell(entry.item, entry.count, false))
		count += 1
	_bag_note.visible = count == 0


func _own_cell(item: ItemDef, count: int, from_belt: bool) -> Control:
	var slot := ItemSlot.new(BAG_SLOT)
	slot.item = item
	slot.count = count
	slot.selected = _pick == Pick.OWN and _pick_item == item and _pick_belt == from_belt
	slot.tooltip_text = tr("Belt: %s") % tr(item.display_name) if from_belt else tr(item.display_name)
	slot.pressed.connect(_on_slot.bind(func() -> void: select_own(item, from_belt)))
	var price := _merchant.def.sell_price(item, _player.world.depth)
	return _cell(slot, tr("+%d gold") % price if price > 0 else "-", UiSkin.DIM)


## A slot with a line under it (its price).
func _cell(slot: ItemSlot, words: String, color: Color) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 0)
	cell.add_child(slot)
	var label := UiSkin.label(words, Fonts.BODY, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = slot.custom_minimum_size.x
	cell.add_child(label)
	return cell


func _on_slot(action: Callable) -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	action.call()


func _refresh_card() -> void:
	var item := _picked_item()
	_buy.visible = _pick == Pick.STOCK and item != null
	_lock.visible = _buy.visible
	_sell.visible = _pick == Pick.OWN and item != null
	_lock_note.visible = _buy.visible
	if item == null:
		_card.show_empty(tr("Pick an item"), tr("Choose something for sale to see what it does, or one of your things to sell it."),
			tr("Gold is only for this run: spend it here and at the forge."))
		_price.text = ""
		return
	_card.show_item(item)
	_fill_compare(item)
	if _pick == Pick.STOCK:
		_refresh_buy(_merchant.stock[_pick_index])
	else:
		var price := _merchant.def.sell_price(item, _player.world.depth)
		_price.text = tr("Sell price: %d gold") % price if price > 0 else tr("The merchant doesn't buy this")
		_price.add_theme_color_override("font_color", UiSkin.GOLD)
		_sell.disabled = price <= 0
		_sell.text = tr("Sell for %d gold") % price if price > 0 else tr("Can't be sold")


func _refresh_buy(entry: Dictionary) -> void:
	var price: int = entry.price
	_price.text = tr("Price: %d gold") % price
	var fits := _player.pack.can_store(entry.item)
	_buy.disabled = _player.gold < price or not fits
	_price.add_theme_color_override("font_color", UiSkin.GOLD if _player.gold >= price else UiSkin.BAD)
	if not fits:
		_buy.text = tr("{room}: sell something first").format({ "room": _player.inventory.full_text(entry.item) })
	elif _player.gold < price:
		_buy.text = tr("Not enough gold (%d more)") % (price - _player.gold)
	else:
		_buy.text = tr("Buy for %d gold") % price
	var locked: bool = entry.get("locked", false)
	_lock.text = tr("Unlock") if locked else tr("Lock")
	_lock_note.text = tr("Locked: it stays when you reroll, and if you don't buy it, the next merchant sells it to you at this price.") if locked \
		else tr("Lock keeps this item: it stays when you reroll, and the next merchant sells it at this price.")
	_lock_note.add_theme_color_override("font_color", UiSkin.GOLD if locked else UiSkin.DIM)


## Equipment: how it compares with what the hero wears. Consumables: how many they carry.
func _fill_compare(item: ItemDef) -> void:
	var equipment := item as EquipmentDef
	if equipment:
		_card.show_compare(equipment, _player.equipment.get_item(equipment.slot))
	elif item is ConsumableDef and _pick == Pick.STOCK:
		var carried := _player.pack.carried_count(item)
		_card.show_note(tr("You carry %d. It goes on your belt if there is room.") % carried if carried > 0 \
			else tr("You carry none. It goes on your belt if there is room."))


func _picked_item() -> ItemDef:
	match _pick:
		Pick.STOCK:
			if _pick_index >= 0 and _pick_index < _merchant.stock.size():
				return _merchant.stock[_pick_index].item
		Pick.OWN:
			if _pick_item and _carries(_pick_item, _pick_belt):
				return _pick_item
	_pick = Pick.NONE
	return null


# --- Building -----------------------------------------------------------------------

func _build() -> void:
	_window = RpgWindow.new(tr("Merchant"))
	_window.close_requested.connect(close)
	add_child(_window)
	# The merchant, at the left of the header row (the window's title is on its ribbon).
	var who := _window.header_left
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.size_flags_stretch_ratio = 20.0
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(56, 56)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.name = "Portrait"
	_named.add(_portrait)
	who.add_child(_portrait)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	who.add_child(words)
	_name = UiSkin.label(tr("Merchant"), Fonts.BODY, Color(1, 0.7, 0.35))
	_name.name = "MerchantName"
	_named.add(_name)
	words.add_child(_name)
	_greeting = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	_greeting.name = "Greeting"
	_named.add(_greeting)
	words.add_child(_greeting)
	_gold = UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
	_gold.name = "Gold"
	_named.add(_gold)
	_window.header_right.add_child(_gold)
	var close_button := _window.close_button
	close_button.text = tr("Leave")
	close_button.name = "CloseButton"
	_named.add(close_button)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	_window.body.add_child(columns)

	# Left: for sale, and Reroll.
	var sale: Dictionary = RpgWindow.section(tr("For sale"))
	columns.add_child(sale.box)
	var sale_scroll := UiParts.scroll()
	sale_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sale_scroll.custom_minimum_size.x = STOCK_COLUMNS * (STOCK_SLOT + GAP)
	sale.column.add_child(sale_scroll)
	_for_sale = GridContainer.new()
	_for_sale.columns = STOCK_COLUMNS
	_for_sale.name = "ForSale"
	_for_sale.add_theme_constant_override("h_separation", GAP)
	_for_sale.add_theme_constant_override("v_separation", 6)
	_named.add(_for_sale)
	sale_scroll.add_child(_for_sale)
	_reroll = UiParts.button(tr("Reroll"), _reroll_stock, Vector2(0, 50), Fonts.BODY)
	_reroll.name = "RerollButton"
	_reroll.icon = load("res://assets/ui/icons/reroll.png")
	_reroll.expand_icon = false
	_named.add(_reroll)
	sale.column.add_child(_reroll)
	_reroll_note = UiParts.text("", Fonts.BODY, UiSkin.DIM, STOCK_COLUMNS * (STOCK_SLOT + GAP))
	sale.column.add_child(_reroll_note)

	# Middle: what the hero carries, to sell.
	var mine: Dictionary = RpgWindow.section(tr("Sell your things"))
	columns.add_child(mine.box)
	var bag_scroll := UiParts.scroll()
	bag_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bag_scroll.custom_minimum_size.x = BAG_COLUMNS * (BAG_SLOT + GAP)
	mine.column.add_child(bag_scroll)
	var bag_column := VBoxContainer.new()
	bag_scroll.add_child(bag_column)
	_bag = GridContainer.new()
	_bag.columns = BAG_COLUMNS
	_bag.name = "Bag"
	_bag.add_theme_constant_override("h_separation", GAP)
	_bag.add_theme_constant_override("v_separation", 6)
	_named.add(_bag)
	bag_column.add_child(_bag)
	_bag_note = UiParts.text(tr("Your bag and belt are empty."), Fonts.BODY, UiSkin.DIM, BAG_COLUMNS * (BAG_SLOT + GAP))
	bag_column.add_child(_bag_note)
	mine.column.add_child(UiParts.text(tr("Choose one to see what the merchant pays."), Fonts.BODY, UiSkin.DIM, BAG_COLUMNS * (BAG_SLOT + GAP)))

	# Right: the picked item.
	var card: Dictionary = RpgWindow.section(tr("Item"))
	(card.box as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(card.title as Label).hide()
	columns.add_child(card.box)
	_card = ItemCard.build(card.column, CARD_SLOT)
	_price = UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
	_named.add(_price, "Price")
	_card.naming.add_child(_price)
	_named.add(_card.details, "Details")
	_named.add(_card.compare, "Compare")
	_lock_note = UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	card.column.add_child(_lock_note)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", GAP)
	card.column.add_child(actions)
	_buy = UiParts.button(tr("Buy"), func() -> void: buy_selected(), Vector2(0, 52), Fonts.BODY)
	_buy.name = "BuyButton"
	_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Its words say why it can't buy ("Plus de place pour les grimoires et parchemins : vends
	# d'abord quelque chose"): on two lines, never a merchant wider than the screen.
	_buy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_named.add(_buy)
	actions.add_child(_buy)
	_sell = UiParts.button(tr("Sell"), func() -> void: sell_selected(), Vector2(0, 52), Fonts.BODY)
	_sell.name = "SellButton"
	_sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_named.add(_sell)
	actions.add_child(_sell)
	_lock = UiParts.button(tr("Lock"), _toggle_lock, Vector2(130, 52), Fonts.BODY)
	_lock.name = "LockButton"
	_named.add(_lock)
	actions.add_child(_lock)
	_named.expose_to(self)



## A slot of the stock: a padlock in its corner when the entry is locked.
class ShopSlot:
	extends ItemSlot

	var locked := false:
		set(value):
			locked = value
			queue_redraw()

	func _init(side: float = 60.0) -> void:
		super(side)

	func _draw() -> void:
		super._draw()
		if not locked:
			return
		# A little gold padlock, top right.
		var at := Vector2(size.x - 22, 6)
		var dark := Color(0.12, 0.07, 0.05)
		draw_arc(at + Vector2(8, 8), 5.0, PI, TAU, 10, dark, 5.0)
		draw_arc(at + Vector2(8, 8), 5.0, PI, TAU, 10, UiSkin.GOLD, 2.5)
		draw_rect(Rect2(at + Vector2(1, 7), Vector2(14, 11)), dark)
		draw_rect(Rect2(at + Vector2(2.5, 8.5), Vector2(11, 8)), UiSkin.GOLD)
		draw_rect(Rect2(at + Vector2(7, 11), Vector2(2, 3)), dark)
