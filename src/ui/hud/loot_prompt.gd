class_name LootPrompt
extends PanelContainer
## Standing on an item that auto loot leaves on the ground (Settings.auto_loot), or that the bag
## has no room for: a small board low on the screen, above the buttons, shows it (its slot, and in
## a dark inset its name in its rarity, how it compares with what is worn) with a Take button.
## With no room, the button opens the bag instead (dismantle or drop something, then take it).
## Gone when the hero walks off. On touch it sits above the belt and the roll, left of the skills
## (place()); where Take would fall in the joystick's zone (Large buttons on a narrow screen), at
## the top middle instead.
## Also says, in a toast, when the bag is full (Events.bag_full), at most every few seconds.
## Built by the HUD; listens to Events.

const WIDTH := 600.0
## Under the screen's bottom edge with keys and a gamepad (over the action bar), and the top
## spot's height (under the boss bar).
const BOTTOM_KEYS := 140.0
const TOP := 96.0
## Seconds between two "bag full" toasts (walking over loot again and again).
const FULL_TOAST_GAP := 4.0
const REFRESH := 0.25
## The round buttons the board sits above (the bottom row: the belt and the roll).
const LOW_ROW: Array[String] = ["QuickItemButton", "Belt2Button", "Belt3Button", "Skill1Button"]

## Toasts, and the bag button's signal.
var hud: Hud
var player: Player

## Pickups the hero stands on, the last one shown.
var _offers: Array[ItemPickup] = []
var _shown: ItemPickup
var _slot: ItemSlot
var _name: Label
var _type: Label
var _compare: RichTextLabel
var _take: Button
var _last_full_toast := -100.0
var _refresh_in := 0.0


func _ready() -> void:
	name = "LootPrompt"
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # the joystick's thumb may slide under it
	# Placed by place(), from the top left of the HUD's safe area.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_theme_stylebox_override("panel", _panel())
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_slot = ItemSlot.new(68.0)
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_slot)
	# The words in a dark inset (never colors straight on the wood: design/interface.md).
	var recess := UiSkin.section()
	recess.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recess.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(recess)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	recess.add_child(words)
	_name = UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(_name)
	_type = UiSkin.label("", Fonts.BODY, UiSkin.DIM)
	_type.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_type.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(_type)
	_compare = RichTextLabel.new()
	_compare.name = "LootCompare"
	_compare.bbcode_enabled = true
	_compare.fit_content = true
	_compare.scroll_active = false
	_compare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compare.add_theme_font_size_override("normal_font_size", Fonts.BODY)
	_compare.add_theme_constant_override("outline_size", Fonts.outline_size(Fonts.BODY))
	_compare.add_theme_color_override("font_outline_color", Fonts.OUTLINE)
	_compare.add_theme_color_override("default_color", UiSkin.TEXT)
	words.add_child(_compare)
	_take = UiParts.button(tr("Take"), _on_take, Vector2(130, 64))
	_take.name = "TakeButton"
	_take.focus_mode = Control.FOCUS_NONE  # nothing on the HUD keeps the focus (Space attacks)
	_take.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Interact takes it too on keys and gamepads (Hud): its key, left of the button.
	row.add_child(PromptGlyph.make(&"interact"))
	row.add_child(_take)
	hide()
	resized.connect(place)
	Events.loot_offered.connect(_on_offered)
	Events.loot_left.connect(_on_left)
	Events.bag_full.connect(_on_bag_full)
	Events.depth_changed.connect(func(_depth: int) -> void:
		_offers.clear()
		_show_last())


## The item shown (tests), null when hidden.
func shown_item() -> ItemDef:
	return _shown.item if visible and is_instance_valid(_shown) else null


## Puts the board where nothing to tap is under its Take button: with keys, low in the middle
## over the action bar; on touch above the belt row and the roll, left of every other round
## button beside it (16 units clear), or at the top middle when that would put Take in the
## joystick's zone.
func place() -> void:
	var parent := get_parent() as Control
	if hud == null or parent == null or not is_inside_tree():
		return
	var area := parent.size
	var height := get_combined_minimum_size().y
	var rect := Rect2(roundf((area.x - WIDTH) * 0.5), area.y - BOTTOM_KEYS - height, WIDTH, height)
	if hud.touch_controls_shown():
		var buttons := hud.touch_rects()
		var bottom := area.y
		for low in LOW_ROW:
			if buttons.has(low):
				bottom = minf(bottom, (buttons[low] as Rect2).position.y - Hud.TOUCH_GAP)
		var right := roundf((area.x + WIDTH) * 0.5)
		for button_name: String in buttons:
			var button: Rect2 = buttons[button_name]
			if not button_name in LOW_ROW and button.position.y < bottom + Hud.TOUCH_GAP and button.end.y > bottom - height - Hud.TOUCH_GAP:
				right = minf(right, button.position.x - Hud.TOUCH_GAP)
		rect = Rect2(right - WIDTH, bottom - height, WIDTH, height)
		var take_left := rect.end.x - _panel().content_margin_right - _take.get_combined_minimum_size().x
		if take_left < hud.stick_zone().end.x + Hud.TOUCH_GAP:
			rect = Rect2(roundf((area.x - WIDTH) * 0.5), TOP, WIDTH, height)
	rect.position = (rect.position / 2.0).round() * 2.0  # (even units: whole screen pixels at x1.5)
	if not position.is_equal_approx(rect.position) or not size.is_equal_approx(rect.size):
		position = rect.position
		size = rect.size


## The Take button (or "Open the bag" when there is no room), as if tapped (tests).
func press_take() -> void:
	_on_take()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_show_last()  # the bag may have room now, gear may have changed


func _on_offered(pickup: ItemPickup) -> void:
	_offers.erase(pickup)
	_offers.append(pickup)
	_show_last()


func _on_left(pickup: ItemPickup) -> void:
	_offers.erase(pickup)
	_show_last()


func _on_bag_full(item: ItemDef) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if hud == null or now - _last_full_toast < FULL_TOAST_GAP:
		return
	_last_full_toast = now
	var room := player.inventory.full_text(item) if player else tr("Your bag is full")
	hud.toast(tr("{room}: {item} stays on the ground. Dismantle or drop something in the bag.").format({ "room": room, "item": tr(item.display_name) }) if item \
		else tr("{room}. Dismantle or drop something in the bag.").format({ "room": room }))


func _on_take() -> void:
	if not is_instance_valid(_shown) or player == null:
		return
	if not player.pack.can_store(_shown.item) and not _fits_by_equipping(_shown.item):
		if hud:
			hud.inventory_requested.emit()
		return
	Sfx.play_ui(Sfx.bank.ui_click)
	_shown.take(player)


## Gear for an empty slot is put on at once, needing no room in the bag.
func _fits_by_equipping(item: ItemDef) -> bool:
	return item is EquipmentDef and player.equipment.get_item((item as EquipmentDef).slot) == null


func _show_last() -> void:
	_refresh_in = REFRESH
	while not _offers.is_empty() and (not is_instance_valid(_offers[-1]) or _offers[-1].is_taken()):
		_offers.pop_back()
	_shown = _offers[-1] if not _offers.is_empty() else null
	visible = _shown != null and player != null and not player.is_dead
	if not visible:
		return
	var item := _shown.item
	_slot.item = item
	_name.text = tr(item.display_name)
	_name.add_theme_color_override("font_color", item.rarity_color())
	_type.text = item.get_type_label()
	var room := player.pack.can_store(item) or _fits_by_equipping(item)
	_take.text = tr("Take") if room else tr("Open the bag")
	_compare.text = _compare_line(item) if room else "[color=#%s]%s[/color]" % [UiSkin.BAD.to_html(false), player.inventory.full_text(item)]
	place.call_deferred()


## "+3 damage, -1 armor": the first changes against what is worn, green or red.
func _compare_line(item: ItemDef) -> String:
	var gear := item as EquipmentDef
	if gear == null:
		return ""
	var worn := player.equipment.get_item(gear.slot)
	if worn == null:
		return "[color=#%s]%s[/color]" % [UiSkin.GOOD.to_html(false), tr("Nothing worn there yet.")]
	var parts := PackedStringArray()
	for change in ItemCompare.lines(gear, worn).slice(0, 3):
		parts.append("[color=#%s]%s[/color]" % [(UiSkin.GOOD if change.good else UiSkin.BAD).to_html(false), change.text])
	return ", ".join(parts) if not parts.is_empty() else tr("The same as what you wear.")


static func _panel() -> StyleBoxTexture:
	var box := UiSkin.panel()
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


## The Take button (tests: where it lies, what it says).
func take_button() -> Button:
	return _take
