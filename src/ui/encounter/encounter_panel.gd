class_name EncounterPanel
extends Control
## The question an encounter asks, in the game's skin (RpgDialog). Built in code.
## Its name on the ribbon, its picture and text; then one card per choice saying, before you
## pick, what it costs and everything that can come of it, with the odds ("55%  Heals you
## fully"), good things in green and risks in red; the card's button makes the choice (greyed,
## saying why, when you can't). Leave walks away (you can come back). After a choice: what
## happened, then Continue. The game is paused while it is open.

signal closed

const WIDTH := 960.0
const CARD_WIDTH := 350.0

var _encounter: Encounter
var _player: Player
var _buttons: Array[Button] = []

var _dialog: RpgDialog
var _icon: TextureRect
var _text: Label
## What it says as it opens (its dialogue's line, in its speaker's color), in place of its
## description; hidden if nothing.
var _speech: Label
## The empty niche beside it and its inscription (EncounterDef.niche), under its text.
var _niche: Label
var _result: Label
var _choices: HBoxContainer
var _leave_row: HBoxContainer
var _leave: Button
var _leave_note: Label
## Built nodes reachable as %Name once the panel is built.
var _named := ExposedNodes.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()


func open(encounter: Encounter, player: Player) -> void:
	_encounter = encounter
	_player = player
	_icon.texture = encounter.def.icon
	_icon.modulate = encounter.def.icon_tint
	_dialog.set_title(tr(encounter.def.display_name), encounter.def.color.lightened(0.45))
	_text.text = tr(encounter.def.description)
	_text.add_theme_color_override("font_color", UiSkin.TEXT)
	var spoken := Dialogues.say(encounter.def.dialogue) if encounter.def.dialogue else null
	_speech.text = tr("\"%s\"") % spoken.text() if spoken else ""
	_speech.visible = spoken != null
	# Its line says more than its description's (and a 720-line screen has room for one of them).
	_text.visible = spoken == null
	var niche := encounter.def.niche
	_niche.text = tr(niche.shown_text()) if niche else ""
	_niche.visible = niche != null
	if spoken and spoken.speaker():
		_speech.add_theme_color_override("font_color", spoken.speaker().color)
	_result.hide()
	UiParts.clear(_choices)
	_buttons.clear()
	var depth := player.world.depth
	for i in encounter.def.choices.size():
		_choices.add_child(_choice_card(encounter.def.choices[i], i, depth))
	_leave.text = tr(encounter.def.leave_label)
	_leave_row.show()
	show()


func close() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()
	closed.emit()


## The button that makes choice `index` (tests).
func choice_button(index: int) -> Button:
	return _buttons[index] if index >= 0 and index < _buttons.size() else null


func _choose(index: int) -> void:
	var outcome := _encounter.resolve(index, _player)
	if outcome == null:
		return
	Sfx.play_ui(Sfx.bank.perk_chosen)
	_speech.hide()
	_niche.hide()
	_text.show()
	_text.text = tr(outcome.text)
	_text.add_theme_color_override("font_color", outcome.color)
	var choice := _encounter.def.choices[index]
	var paid := choice.gold_cost > 0 or choice.max_hp_cost > 0.0
	_result.text = outcome.summary(_player, paid)
	_result.add_theme_color_override("font_color", UiSkin.BAD if outcome.is_bad() else UiSkin.GOOD)
	_result.show()
	UiParts.clear(_choices)
	_buttons.clear()
	_leave_row.hide()
	var go_on := UiParts.button(tr("Continue"), close, Vector2(320, 58), Fonts.BODY)
	_choices.add_child(go_on)


# --- Look -------------------------------------------------------------------------

## A choice as a card: its name, its cost, what can happen (with the odds), and its button.
func _choice_card(choice: EncounterChoice, index: int, depth: int) -> Control:
	var card: Dictionary = RpgWindow.section(tr(choice.label))
	var box := card.box as Control
	box.custom_minimum_size.x = CARD_WIDTH
	var column := card.column as VBoxContainer
	(card.title as Label).add_theme_font_size_override("font_size", Fonts.BODY)
	var reason := choice.cannot_afford_reason(_player, depth)
	var cost := UiSkin.label(choice.cost_text(_player, depth), Fonts.BODY, UiSkin.GOLD if reason.is_empty() else UiSkin.BAD, true)
	column.add_child(cost)
	var chances := choice.chances()
	var paid := choice.gold_cost > 0 or choice.max_hp_cost > 0.0
	column.add_child(UiSkin.label(tr("Always:") if chances.size() == 1 else tr("What can happen:"), Fonts.BODY, UiSkin.DIM))
	for i in choice.outcomes.size():
		var outcome := choice.outcomes[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		column.add_child(row)
		if chances.size() > 1:
			var odds := UiSkin.label(tr("%d%%") % roundi(chances[i] * 100.0), Fonts.BODY, UiSkin.TEXT)
			odds.custom_minimum_size.x = 48
			odds.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(odds)
		var words := UiSkin.label(outcome.summary(_player, paid), Fonts.BODY, UiSkin.BAD if outcome.is_bad() else UiSkin.GOOD, true)
		row.add_child(words)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var button := UiParts.button(choice.describe(_player, depth) if reason.is_empty() else reason, _choose.bind(index), Vector2(0, 54), Fonts.BODY)
	button.disabled = not reason.is_empty()
	column.add_child(button)
	_buttons.append(button)
	return box


# --- Building -----------------------------------------------------------------------

func _build() -> void:
	_dialog = RpgDialog.new("", WIDTH, 0.8)
	add_child(_dialog)
	# Tighter than a dialog's 10 (the choices' insets keep their buttons 16 apart): the words' inset
	# and finger-sized buttons fit a 720-line screen in French.
	_dialog.body.add_theme_constant_override("separation", 6)
	_dialog.title_label.name = "Title"
	_named.add(_dialog.title_label)
	# What it is and what it says in a dark inset (never dim or red words on the bare wood).
	var recess := UiSkin.section()
	_dialog.body.add_child(recess)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	recess.add_child(top)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(72, 72)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.name = "Icon"
	_named.add(_icon)
	top.add_child(_icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(words)
	_text = UiParts.text("", Fonts.BODY, UiSkin.TEXT, WIDTH - 160)
	_text.name = "Text"
	_named.add(_text)
	words.add_child(_text)
	_speech = UiParts.text("", Fonts.BODY, UiSkin.GOLD, WIDTH - 160)
	_speech.name = "Speech"
	_speech.hide()
	_named.add(_speech)
	words.add_child(_speech)
	_niche = UiParts.text("", Fonts.BODY, UiSkin.DIM, WIDTH - 160)
	_niche.name = "Niche"
	_niche.hide()
	_named.add(_niche)
	words.add_child(_niche)
	_result = UiParts.text("", Fonts.BODY, UiSkin.GOOD, WIDTH - 160)
	_result.name = "Result"
	_named.add(_result)
	words.add_child(_result)

	_choices = HBoxContainer.new()
	_choices.name = "Choices"
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("separation", MenuWindow.TOUCH_GAP)
	_named.add(_choices)
	_dialog.body.add_child(_choices)

	_leave_row = HBoxContainer.new()
	_leave_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_leave_row.add_theme_constant_override("separation", 14)
	_dialog.body.add_child(_leave_row)
	_leave = UiParts.button(tr("Leave"), close, Vector2(200, MenuWindow.TOUCH_MIN), Fonts.BODY)
	_leave.name = "LeaveButton"
	_named.add(_leave)
	_leave_row.add_child(_leave)
	PromptGlyph.badge(_leave, &"ui_cancel", PromptGlyph.Place.INSIDE)  # Back leaves too
	_leave_note = UiSkin.label(tr("Nothing happens. You can come back later."), Fonts.BODY, UiSkin.TEXT)
	_leave_row.add_child(_leave_note)
	_named.expose_to(self)

