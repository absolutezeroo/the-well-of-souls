class_name ForgePanel
extends Control
## The smith's forge (Forge), in the game's skin (RpgWindow, ItemSlot): the smith and his words
## on top; on the left the weapons you can work on (the worn one first) and the picked one's
## rune sockets, big; on the right the runes in your bag. Pick a rune to read it and set it into
## the first free socket (free); pick a socket to take its rune back out, intact, for gold.
## The game is paused while it is open.

signal closed

const WEAPON_SLOT := 66.0
const SOCKET_SLOT := 76.0
const RUNE_SLOT := 66.0
## Four columns of finger-sized rune slots 16 units apart (five would widen the forge).
const RUNE_COLUMNS := 4

var _forge: Forge
var _player: Player
var _weapon: EquipmentDef
## The socket picked on the weapon (-1: none): its rune can be taken out.
var _socket := -1
## The rune picked in the bag (null: none): it can be set.
var _rune: RuneDef

var _window: RpgWindow
var _portrait: TextureRect
var _name: Label
var _greeting: Label
var _gold: Label
var _weapons: HBoxContainer
var _weapon_slot: ItemSlot
var _weapon_title: Label
var _weapon_details: Label
var _sockets: HBoxContainer
var _action: Button
var _runes: GridContainer
var _rune_name: Label
var _rune_text: Label
var _set_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()


func open(forge: Forge, player: Player) -> void:
	_forge = forge
	_player = player
	_name.text = tr(forge.def.display_name)
	_greeting.text = tr("\"%s\"") % forge.def.opening_line()
	_portrait.texture = forge.def.portrait
	var weapons := Forge.weapons_of(player)
	_weapon = weapons[0] if not weapons.is_empty() else null
	_socket = -1
	_rune = null
	_refresh()
	show()


func close() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()
	closed.emit()


## The weapon being worked on (tests, and after a rune goes in: it may be a new copy).
func weapon() -> EquipmentDef:
	return _weapon


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory")):
		get_viewport().set_input_as_handled()
		close()


# --- Actions ----------------------------------------------------------------------

func _select_weapon(picked: EquipmentDef) -> void:
	_weapon = picked
	_socket = -1
	Sfx.play_ui(Sfx.bank.ui_click)
	_refresh()


func _select_socket(index: int) -> void:
	_socket = index if _socket != index else -1
	Sfx.play_ui(Sfx.bank.ui_click)
	_refresh()


func _select_rune(rune: RuneDef) -> void:
	_rune = rune if _rune != rune else null
	Sfx.play_ui(Sfx.bank.ui_click)
	_refresh()


## Sets `rune` into the picked weapon's first free socket.
func set_rune(rune: RuneDef) -> bool:
	var worked := Forge.set_rune(_player, _weapon, rune)
	if worked == null:
		return false
	_weapon = worked
	_socket = -1
	if not _player.inventory.items.has(_rune):
		_rune = null
	_forge.strike(false)
	_refresh()
	return true


## Takes the picked socket's rune back out, for gold.
func take_rune() -> bool:
	if not Forge.take_rune(_player, _weapon, _socket, _forge.removal_cost()):
		return false
	_socket = -1
	_forge.strike(true)
	_refresh()
	return true


# --- Look -------------------------------------------------------------------------

func _refresh() -> void:
	_gold.text = tr("Gold %d") % _player.gold
	_clear(_weapons)
	_clear(_sockets)
	_clear(_runes)
	var weapons := Forge.weapons_of(_player)
	if not weapons.has(_weapon):
		_weapon = weapons[0] if not weapons.is_empty() else null
	var worn := _player.equipment.get_item(EquipmentDef.Slot.WEAPON)
	for each in weapons:
		var slot := ItemSlot.new(WEAPON_SLOT)
		slot.item = each
		slot.selected = each == _weapon
		slot.tooltip_text = tr("Worn: %s") % tr(each.display_name) if each == worn else tr(each.display_name)
		slot.pressed.connect(_select_weapon.bind(each))
		_weapons.add_child(slot)
	_weapon_slot.item = _weapon
	if _weapon == null:
		_weapon_title.text = tr("No weapon to work on")
		_weapon_details.text = ""
		_action.hide()
	else:
		_weapon_title.text = tr(_weapon.display_name)
		_weapon_title.add_theme_color_override("font_color", _weapon.rarity_color())
		# Whole lines: "Worn  -  12 damage  -  2 rune sockets" (French puts them its own way).
		var sockets := (tr("%d rune sockets") if _weapon.socket_count() > 1 else tr("%d rune socket")) % _weapon.socket_count()
		var details := tr("{damage} damage  -  {sockets}").format({ "damage": (_weapon as WeaponDef).damage, "sockets": sockets }) if _weapon is WeaponDef else sockets
		_weapon_details.text = tr("Worn  -  {details}").format({ "details": details }) if _weapon == worn else details
		for i in _weapon.socket_count():
			_sockets.add_child(_socket_slot(i))
		_refresh_action()
	_fill_runes()


func _refresh_action() -> void:
	_action.show()
	if _socket < 0 or _socket >= _weapon.runes.size():
		_action.disabled = true
		_action.text = tr("Pick a socket to take its rune out")
		return
	var rune := _weapon.runes[_socket]
	var price := _forge.removal_cost()
	var room := _player.inventory.can_add(rune)
	_action.disabled = _player.gold < price or not room
	_action.text = _player.inventory.full_text(rune) if not room else tr("Take out %s  (%d gold)") % [tr(rune.display_name), price]


func _fill_runes() -> void:
	var count := 0
	for entry in _player.inventory.grouped():
		var rune := entry.item as RuneDef
		if rune == null:
			continue
		count += 1
		var slot := ItemSlot.new(RUNE_SLOT)
		slot.item = rune
		slot.count = entry.count
		slot.selected = rune == _rune
		slot.pressed.connect(_select_rune.bind(rune))
		_runes.add_child(slot)
	for i in maxi(0, RUNE_COLUMNS * 2 - count):
		var empty := ItemSlot.new(RUNE_SLOT)
		empty.disabled = true
		_runes.add_child(empty)
	if _rune and not _player.inventory.items.has(_rune):
		_rune = null
	if _rune:
		_rune_name.text = tr(_rune.display_name)
		_rune_name.add_theme_color_override("font_color", _rune.rarity_color())
		_rune_text.text = tr("{type}  -  {description}").format({ "type": _rune.get_type_label(), "description": tr(_rune.description) })
	elif count == 0:
		_rune_name.text = tr("No runes in your bag")
		_rune_name.add_theme_color_override("font_color", UiSkin.GOLD)
		_rune_text.text = tr("Elites, bosses and chests drop them.")
	else:
		_rune_name.text = tr("Pick a rune")
		_rune_name.add_theme_color_override("font_color", UiSkin.GOLD)
		_rune_text.text = tr("Setting one is free. Taking one out costs gold; you get it back.")
	var free := _weapon != null and _weapon.free_sockets() > 0
	_set_button.disabled = _rune == null or not free
	_set_button.text = (tr("Set it in") if free else tr("No free socket")) if _rune else tr("Set")


## A socket of the weapon: its rune (tap it to take it out), or empty.
func _socket_slot(index: int) -> ItemSlot:
	var slot := ItemSlot.new(SOCKET_SLOT)
	slot.caption = tr("Empty")
	if index < _weapon.runes.size():
		slot.item = _weapon.runes[index]
		slot.selected = index == _socket
		slot.tooltip_text = tr(_weapon.runes[index].description)
		slot.pressed.connect(_select_socket.bind(index))
	else:
		slot.disabled = true
	return slot


# --- Building -----------------------------------------------------------------------

func _build() -> void:
	_window = RpgWindow.new(tr("The Forge"))
	_window.close_requested.connect(close)
	add_child(_window)
	_gold = UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
	_window.header_right.add_child(_gold)

	# The smith, and what he says.
	var smith := HBoxContainer.new()
	smith.add_theme_constant_override("separation", 14)
	_window.body.add_child(smith)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(64, 64)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	smith.add_child(_portrait)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	smith.add_child(words)
	_name = UiSkin.label(tr("Smith"), Fonts.BODY, Color(1, 0.7, 0.35))
	words.add_child(_name)
	_greeting = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	words.add_child(_greeting)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	_window.body.add_child(columns)

	# Left: the weapons, and the picked one's sockets.
	var left: Dictionary = RpgWindow.section(tr("Weapon"))
	(left.box as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left.box)
	var weapon_scroll := ScrollContainer.new()
	weapon_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	weapon_scroll.custom_minimum_size.y = WEAPON_SLOT + 8
	left.column.add_child(weapon_scroll)
	_weapons = HBoxContainer.new()
	_weapons.add_theme_constant_override("separation", MenuWindow.TOUCH_GAP)
	weapon_scroll.add_child(_weapons)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	left.column.add_child(top)
	_weapon_slot = ItemSlot.new(74.0)
	_weapon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_weapon_slot)
	var naming := VBoxContainer.new()
	naming.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	naming.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(naming)
	_weapon_title = UiSkin.label("", Fonts.BODY, UiSkin.GOLD, true)
	naming.add_child(_weapon_title)
	_weapon_details = UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	naming.add_child(_weapon_details)
	left.column.add_child(UiSkin.label(tr("Sockets"), Fonts.BODY, UiSkin.GOLD))
	_sockets = HBoxContainer.new()
	_sockets.add_theme_constant_override("separation", MenuWindow.TOUCH_GAP)
	left.column.add_child(_sockets)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.column.add_child(spacer)
	_action = _button("", take_rune)
	_action.name = "TakeOutButton"
	# Its words may say why the rune can't come out (« Plus de place pour les runes : ... »):
	# on two lines, never a forge wider than the screen.
	_action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.column.add_child(_action)

	# Right: the runes in the bag.
	var right: Dictionary = RpgWindow.section(tr("Your runes"))
	columns.add_child(right.box)
	var rune_scroll := ScrollContainer.new()
	rune_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rune_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rune_scroll.custom_minimum_size = Vector2(RUNE_COLUMNS * (RUNE_SLOT + MenuWindow.TOUCH_GAP) + 4, RUNE_SLOT * 2 + MenuWindow.TOUCH_GAP + 6)
	right.column.add_child(rune_scroll)
	_runes = GridContainer.new()
	_runes.columns = RUNE_COLUMNS
	_runes.add_theme_constant_override("h_separation", MenuWindow.TOUCH_GAP)
	_runes.add_theme_constant_override("v_separation", MenuWindow.TOUCH_GAP)
	rune_scroll.add_child(_runes)
	_rune_name = UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
	right.column.add_child(_rune_name)
	_rune_text = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	_rune_text.custom_minimum_size.x = RUNE_COLUMNS * (RUNE_SLOT + MenuWindow.TOUCH_GAP)
	right.column.add_child(_rune_text)
	_set_button = _button(tr("Set"), func() -> void:
		if _rune:
			set_rune(_rune))
	right.column.add_child(_set_button)


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, MenuWindow.TOUCH_MIN)
	button.add_theme_font_size_override("font_size", Fonts.BODY)
	button.pressed.connect(action)
	return button


## A dark edge around colored text on the orange buttons (rune colors, rarities).
static func _outline(control: Control) -> void:
	control.add_theme_constant_override("outline_size", Fonts.outline_size(Fonts.BODY))
	control.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.08))
