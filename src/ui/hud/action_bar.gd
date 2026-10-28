class_name ActionBar
extends Control
## The HUD's fight controls on a keyboard or a gamepad (the touch buttons are put away): a compact
## row low in the middle of the screen, one slot per touch button it stands for (attack, the four
## skills, the three belt slots), each with its key or button under it (PromptGlyph) and its
## cooldown, charge and count; and, while something is in reach, what Interact does, beside it.
## Nothing is decided here: every slot mirrors its touch button (Hud keeps those up to date, shown
## or not), so both ways of playing always show the same thing.

## A slot's side (UI units); the attack's is bigger.
const SLOT := 52.0
const ATTACK_SLOT := 60.0
const GAP := 8.0
## Between the skills and the belt.
const GROUP_GAP := 22.0
## From the screen's bottom edge.
const BOTTOM := 12.0
const CHARGE_STEPS := 12

## The touch button each slot stands for (its unique name in the HUD).
var slots: Array[Slot] = []
## Interact's prompt: its key, the thing's picture and what it does.
var interact: InteractPrompt


## `buttons`: the touch buttons, in the bar's order; `belt_from`: the first belt slot (a gap
## before it).
func setup(buttons: Array[ActionButton], belt_from: int, interact_button: InteractButton) -> void:
	name = "ActionBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(GAP))
	add_child(row)
	for i in buttons.size():
		if i == belt_from:
			var gap := Control.new()
			gap.custom_minimum_size.x = GROUP_GAP - GAP
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(gap)
		var slot := Slot.new()
		slot.source = buttons[i]
		slot.side = ATTACK_SLOT if i == 0 else SLOT
		slot.name = String(buttons[i].name).replace("Button", "Slot")
		row.add_child(slot)
		slots.append(slot)
	interact = InteractPrompt.new()
	interact.source = interact_button
	interact.name = "InteractPrompt"
	add_child(interact)
	_fit()


## The slot standing for the touch button named `button_name` ("AttackButton"), or null.
func slot_for(button_name: StringName) -> Control:
	if button_name == &"InteractButton":
		return interact if interact.visible else null
	for slot in slots:
		if slot.source and slot.source.name == button_name:
			return slot if slot.visible else null
	return null


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var changed := false
	for slot in slots:
		changed = slot.mirror() or changed
	interact.mirror()
	if changed:
		_fit.call_deferred()


## As wide as the slots shown, centred; Interact's prompt just right of them (the slots never move
## when it comes and goes).
func _fit() -> void:
	var row := get_node("Row") as HBoxContainer
	var wanted := row.get_combined_minimum_size()
	offset_left = -wanted.x * 0.5
	offset_right = wanted.x * 0.5
	offset_top = -BOTTOM - wanted.y
	offset_bottom = -BOTTOM
	row.position = Vector2.ZERO
	row.size = wanted
	interact.position = Vector2(wanted.x + GROUP_GAP, wanted.y - PromptGlyph.HEIGHT - InteractPrompt.HEIGHT - 6.0)


## One slot of the bar: the picture of what it does, its cooldown (rows of shade, the art's
## pixels), a charge's steps along its lower edge, its count, and its key under it.
class Slot:
	extends VBoxContainer

	var source: ActionButton
	var side := SLOT
	var _face: SlotFace
	var _glyph: PromptGlyph

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		alignment = BoxContainer.ALIGNMENT_END
		add_theme_constant_override("separation", 4)
		_face = SlotFace.new()
		_face.custom_minimum_size = Vector2(side, side)
		_face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		add_child(_face)
		_glyph = PromptGlyph.make(source.action)
		_glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		add_child(_glyph)
		mirror()

	## Copies its touch button; true if it showed or hid.
	func mirror() -> bool:
		if source == null or _face == null:
			return false
		var was := visible
		visible = source.visible
		_face.copy(source)
		return was != visible

	func glyph() -> PromptGlyph:
		return _glyph


class SlotFace:
	extends Control

	var icon: Texture2D
	var icon_tint := Color.WHITE
	var label := ""
	var color := Color.WHITE
	var cooldown := 0.0
	var counter := -1
	var charge := 0.0
	var charge_full := false
	var charge_color := Color.WHITE
	var charge_core := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func copy(button: ActionButton) -> void:
		var before := [icon, icon_tint, label, color, snappedf(cooldown, 0.02), counter, snappedf(button.charge_ratio, 0.05), charge_full]
		icon = button.icon
		icon_tint = button.icon_tint
		label = button.label
		color = button.color
		cooldown = button.cooldown_ratio
		counter = button.counter
		charge = button.charge_ratio
		charge_full = button.charge_full
		charge_color = button.charge_color
		charge_core = button.charge_core
		if before != [icon, icon_tint, label, color, snappedf(cooldown, 0.02), counter, snappedf(charge, 0.05), charge_full] or charge_full:
			queue_redraw()

	func _draw() -> void:
		var area := Rect2(Vector2.ZERO, size)
		draw_style_box(ItemSlot.slot_box(), area)
		draw_rect(area.grow(-8), Color(color, 0.14))
		var inner := area.grow(-9)
		if icon:
			draw_texture_rect(icon, ItemSlot.fit(icon, inner), false, icon_tint)
		elif not label.is_empty():
			Fonts.draw(self, Vector2(size.x * 0.5, size.y * 0.5 + Fonts.half_cap(Fonts.BODY)), label, Fonts.BODY, Color.WHITE, 0.5)
		if cooldown > 0.01:
			# The time left as shade over the slot, falling a row of pixels at a time.
			var rows := floorf(inner.size.y * cooldown / PromptGlyph.PIXEL) * PromptGlyph.PIXEL
			draw_rect(Rect2(inner.position, Vector2(inner.size.x, rows)), Color(0.08, 0.04, 0.06, 0.7))
		if charge > 0.0 or charge_full:
			_draw_charge(inner)
		if counter >= 0:
			Fonts.draw(self, Vector2(size.x - 6.0, size.y - 5.0), str(counter), Fonts.BODY, Color.WHITE, 1.0)

	## Twelve steps along the lower edge, lit one after another; full, they beat.
	func _draw_charge(inner: Rect2) -> void:
		var lit := CHARGE_STEPS if charge_full else floori(charge * CHARGE_STEPS)
		var beat := charge_full and fmod(Time.get_ticks_msec() * 0.001 * 2.5, 1.0) < 0.5
		var step := floorf(inner.size.x / CHARGE_STEPS / PromptGlyph.PIXEL) * PromptGlyph.PIXEL
		var start := inner.position + Vector2((inner.size.x - step * CHARGE_STEPS) * 0.5, inner.size.y - PromptGlyph.PIXEL * 3)
		draw_rect(Rect2(start - Vector2(PromptGlyph.PIXEL, PromptGlyph.PIXEL), Vector2(step * CHARGE_STEPS + PromptGlyph.PIXEL, PromptGlyph.PIXEL * 4)), Fonts.OUTLINE)
		for i in CHARGE_STEPS:
			var lit_color := charge_core if beat else charge_color
			draw_rect(Rect2(start + Vector2(i * step, 0), Vector2(step - PromptGlyph.PIXEL, PromptGlyph.PIXEL * 2)), lit_color if i < lit else Color(0.35, 0.28, 0.25))


## While something is in reach: [E] its picture and what it does ("Trade"), on a dark plaque.
class InteractPrompt:
	extends PanelContainer

	const HEIGHT := 40.0

	var source: InteractButton
	## Its edge: the thing's color.
	var _edge := UiSkin.GOLD
	var _glyph: PromptGlyph
	var _icon: TextureRect
	var _verb: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The skin's dark recess, its edge in the thing's color (drawn over it).
		add_theme_stylebox_override("panel", UiSkin.note_box())
		draw.connect(func() -> void: UiSkin.draw_edge(self, Rect2(Vector2.ZERO, size), _edge))
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		_glyph = PromptGlyph.make(&"interact")
		row.add_child(_glyph)
		_icon = TextureRect.new()
		_icon.custom_minimum_size = Vector2(32, 32)
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_icon)
		_verb = UiSkin.label("", Fonts.BODY, Color.WHITE)
		_verb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_verb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_verb)
		visible = false

	func mirror() -> void:
		if source == null or _verb == null:
			return
		visible = source.visible
		if not visible:
			return
		if _verb.text != source.caption:
			_verb.text = source.caption
			size = Vector2.ZERO  # shrink to the new words
		_icon.texture = source.icon
		_icon.modulate = source.icon_tint
		if _edge != source.color:
			_edge = source.color
			queue_redraw()

	func caption() -> String:
		return _verb.text if _verb else ""
