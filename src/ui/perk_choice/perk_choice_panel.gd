class_name PerkChoicePanel
extends Control
## "Choose 1 of 3": a level up's perks (when the player taps the HUD's perk button) and a boss'
## or a pact's relics, in the game's skin (RpgDialog, cards on dark wood). Built in code. The game
## pauses while it is open; it comes in softly (the world dims, the board rises a few UI pixels a
## whole pixel at a time, 0.15 s: design/interface.md "One skin").
## Tap a card, or use the arrows and confirm on a keyboard or gamepad.
## Under the cards: Reroll (three new cards) and Banish (tap Banish, then a card: that perk is
## gone for the run and another takes its place), while the run has charges left (RunState).
## The panel only asks (`reroll_requested`, `banish_requested`); the game decides and calls
## show_cards() with what replaces them. Later (or Back) puts the choice off: it waits behind the
## perk button with the same cards.

const MenuNavScript := preload("res://src/autoload/menu_nav.gd")  # its static helpers are called on the script, not the autoload

signal chosen(perk: PerkDef)
signal reroll_requested
signal banish_requested(index: int)
## Later: the choice waits (the game puts it back in line).
signal postponed

const CARD_SCENE: PackedScene = preload("res://src/ui/perk_choice/perk_card.tscn")
## Cards ignore input for a moment, so a player mashing attack doesn't pick by accident.
const INPUT_DELAY := 0.45
const BANISH_TINT := Color(1.0, 0.55, 0.55)
## Seconds the panel takes to come in.
const ENTER_TIME := 0.15
## How far below its place the board starts rising (UI units, even: whole screen pixels at x1.5).
const ENTER_RISE := 12.0

var _perks: Array[PerkDef] = []
var _owned: PerkSet
var _open_count := 0
var _subtitle_text := ""
## Banish armed: the next tapped card is banished instead of taken.
var _banishing := false
var _rerolls := 0
var _banishes := 0
## Under the subtitle: what the families are, in one line (when a card has one).
var _rule: Label
## Under Reroll and Banish: what they do.
var _tools_note: Label

var _dialog: RpgDialog
var _title: Label
var _subtitle: Label
var _cards: HBoxContainer
var _tools: HBoxContainer
var _reroll: Button
var _banish: Button
var _later: Button
var _enter_tween: Tween
var _card_box: StyleBoxTexture
var _card_hot: StyleBoxTexture


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()
	_reroll.pressed.connect(func() -> void:
		if _rerolls > 0 and visible:
			_set_banishing(false)
			reroll_requested.emit())
	_banish.pressed.connect(func() -> void: _set_banishing(not _banishing))
	_later.pressed.connect(postpone)


func open(title: String, subtitle: String, perks: Array[PerkDef], owned: PerkSet, rerolls: int = 0, banishes: int = 0) -> void:
	_title.text = tr(title)
	_subtitle_text = tr(subtitle)
	_owned = owned
	_banishing = false
	set_charges(rerolls, banishes)
	show_cards(perks, true)
	# Keys and gamepads start on the first card (MenuNav; never on touch, where it would look
	# like a picked card).
	if _cards.get_child_count() > 0:
		MenuNavScript.set_first(_dialog, _cards.get_child(0) as Control)
	show()
	_enter()
	Sfx.play_ui(Sfx.bank.ui_open)
	_open_count += 1
	var this_open := _open_count
	await get_tree().create_timer(INPUT_DELAY, true).timeout
	if not visible or this_open != _open_count:
		return  # already closed, or reopened with other cards
	for card: PerkCard in _cards.get_children():
		card.disabled = false


## The world dims and the board rises into place, instead of a hard cut over the fight.
func _enter() -> void:
	if _enter_tween:
		_enter_tween.kill()
	modulate.a = 0.0
	_rise(ENTER_RISE)
	_enter_tween = create_tween().set_parallel()
	_enter_tween.tween_property(self, "modulate:a", 1.0, ENTER_TIME).set_ease(Tween.EASE_OUT)
	_enter_tween.tween_method(_rise, ENTER_RISE, 0.0, ENTER_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## The board `height` units under its place, on even units (never between two screen pixels).
func _rise(height: float) -> void:
	_dialog.position.y = roundf(height * 0.5) * 2.0


## Puts the choice off (Later, or Back): it waits behind the HUD's perk button.
func postpone() -> void:
	if not visible:
		return
	_set_banishing(false)
	hide()
	Sfx.play_ui(Sfx.bank.ui_close)
	postponed.emit()


## Puts these cards on the table (a reroll, a banished card replaced...).
## `waiting`: they ignore taps for a moment (a fresh offer).
func show_cards(perks: Array[PerkDef], waiting: bool = false) -> void:
	_perks = perks
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for i in perks.size():
		var card := CARD_SCENE.instantiate() as PerkCard
		_skin_card(card)
		_cards.add_child(card)
		card.show_perk(perks[i], _owned)
		card.disabled = waiting
		card.pressed.connect(_on_card_pressed.bind(i))
		card.modulate.a = 0.0
		var tween := card.create_tween()
		tween.tween_interval(0.025 * i)
		tween.tween_property(card, "modulate:a", 1.0, 0.1)  # (all three in 0.15 s)
	_rule.visible = perks.any(func(perk: PerkDef) -> bool: return not perk.synergies.is_empty())
	_set_banishing(false)


## Rerolls and banishes left (the buttons hide when the run has none at all).
func set_charges(rerolls: int, banishes: int) -> void:
	_rerolls = rerolls
	_banishes = banishes
	_reroll.text = tr("Reroll (%d)") % rerolls
	_reroll.disabled = rerolls <= 0
	_banish.disabled = banishes <= 0
	_reroll.visible = rerolls > 0 or banishes > 0
	_banish.visible = _reroll.visible
	_tools_note.visible = _reroll.visible
	_refresh_banish()


func get_offered() -> Array[PerkDef]:
	return _perks


func is_banishing() -> bool:
	return _banishing


func _set_banishing(on: bool) -> void:
	_banishing = on and _banishes > 0
	_refresh_banish()


func _refresh_banish() -> void:
	if _banish == null:
		return
	_banish.text = tr("Cancel") if _banishing else tr("Banish (%d)") % _banishes
	_subtitle.text = tr("Choose the perk to banish: it won't be offered again this run") if _banishing else _subtitle_text
	_subtitle.add_theme_color_override("font_color", BANISH_TINT if _banishing else UiSkin.TEXT)
	for card: PerkCard in _cards.get_children():
		card.self_modulate = BANISH_TINT if _banishing else Color.WHITE


func _on_card_pressed(index: int) -> void:
	if _banishing:
		_set_banishing(false)
		if index >= 0 and index < _perks.size():
			Sfx.play_ui(Sfx.bank.ui_close)
			banish_requested.emit(index)
		return
	choose(index)


func choose(index: int) -> void:
	if not visible or index < 0 or index >= _perks.size():
		return
	var perk := _perks[index]
	hide()
	Sfx.play_ui(Sfx.bank.perk_chosen)
	chosen.emit(perk)


# --- Building -----------------------------------------------------------------------

func _build() -> void:
	_dialog = RpgDialog.new(tr("Level up!"))
	add_child(_dialog)
	# Tighter than a dialog's 10: three cards of long French text, two families each, fit 720 lines.
	_dialog.body.add_theme_constant_override("separation", 6)
	_title = _dialog.title_label
	_title.name = "Title"
	_subtitle = UiSkin.label(tr("Choose an upgrade"), Fonts.BODY, UiSkin.TEXT)
	_subtitle.name = "Subtitle"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog.body.add_child(_subtitle)
	_rule = UiParts.text(tr("Every perk belongs to a family. Hold 3 different perks of one family to awaken its bonus."), Fonts.SMALL, UiSkin.TEXT, 1100)  # (on the wood: never dim)
	_rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog.body.add_child(_rule)
	_cards = HBoxContainer.new()
	_cards.name = "Cards"
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 16)
	_dialog.body.add_child(_cards)
	_tools = HBoxContainer.new()
	_tools.name = "Tools"
	_tools.alignment = BoxContainer.ALIGNMENT_CENTER
	_tools.add_theme_constant_override("separation", 24)
	_dialog.body.add_child(_tools)
	_reroll = UiParts.button(tr("Reroll (%d)") % 1, Callable(), Vector2(220, MenuWindow.TOUCH_MIN), Fonts.BODY)
	_reroll.name = "RerollButton"
	_reroll.icon = load("res://assets/ui/icons/reroll.png")
	_tools.add_child(_reroll)
	_banish = UiParts.button(tr("Banish (%d)") % 1, Callable(), Vector2(220, MenuWindow.TOUCH_MIN), Fonts.BODY)
	_banish.name = "BanishButton"
	_banish.icon = load("res://assets/ui/icons/banish.png")
	_tools.add_child(_banish)
	_later = UiParts.button(tr("Later"), Callable(), Vector2(180, MenuWindow.TOUCH_MIN), Fonts.BODY)
	PromptGlyph.badge(_later, &"ui_cancel", PromptGlyph.Place.INSIDE)  # Back puts the choice off too
	_later.name = "LaterButton"
	_tools.add_child(_later)
	# Beside the buttons (as tall as them), not under: the row of finger-sized buttons and the
	# three cards fit a 720-line screen in French.
	_tools_note = UiParts.text(tr("Reroll: 3 new perks to choose from.   Banish: removes a perk from this run's offers (Banish, then the card)."), Fonts.SMALL, UiSkin.TEXT, 400)
	_tools_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tools.add_child(_tools_note)
	for node: Node in [_title, _subtitle, _cards, _tools, _reroll, _banish, _later]:
		node.owner = self
		node.unique_name_in_owner = true
	# The cards on dark wood; lighter under the finger.
	_card_box = UiSkin.inset()
	_card_hot = UiSkin.inset()
	_card_hot.modulate_color = Color(1.45, 1.3, 1.15)


func _skin_card(card: PerkCard) -> void:
	for state in ["normal", "disabled"]:
		card.add_theme_stylebox_override(state, _card_box)
	for state in ["hover", "pressed", "focus", "hover_pressed"]:
		card.add_theme_stylebox_override(state, _card_hot)
