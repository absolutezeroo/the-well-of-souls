class_name PauseMenu
extends Control
## Pause, in the game's skin (RpgDialog): resume, options, the bestiary (attacks and challenges
## of the monsters met), send feedback (a bug, an idea: FeedbackDialog, with this run's details),
## save and quit (Continue on the title screen), or give up the run; each button says what it
## does. Below, what gold and souls are for. The options and the bestiary open over it
## (instanced in the scene), the feedback form too (made here).

signal resume_requested
signal quit_requested
signal abandon_requested

const ABANDON_TEXT := "Give up the run"  # i18n
const CONFIRM_TEXT := "Really? Tap again"  # i18n
const CONFIRM_TEXT_BUTTONS := "Really? Press again"  # i18n
const ABANDON_NOTE := "Ends this run now. You keep the souls earned so far."  # i18n
const CONFIRM_NOTE := "Tap again to end the run. Anything else to cancel."  # i18n
const CONFIRM_NOTE_BUTTONS := "Press again to end the run. Anything else to cancel."  # i18n
const BUTTON_SIZE := Vector2(320, 54)
const NOTE_WIDTH := 460.0

## Set by the game (the bestiary needs it).
var content: ContentDB
## Set by the game: the run's details for the feedback form (FeedbackInfo.run()).
var run_info: Callable
## The feedback form, over the menu.
var feedback: FeedbackDialog

var _dialog: RpgDialog
var _abandon_note: Label
## Built nodes reachable as %Name once the panel is built.
var _named := ExposedNodes.new()

@onready var _options: OptionsPanel = %OptionsPanel
@onready var _codex: CodexPanel = %CodexPanel
var _confirm: Button
## Give up was tapped once: the next tap ends the run (anything else, or closing, disarms it).
var _armed := false


func _ready() -> void:
	hide()
	_build()
	_confirm = %AbandonButton
	_abandon_note = %AbandonButtonNote
	InputDevice.changed.connect(_say_abandon)


func open() -> void:
	_armed = false
	_say_abandon()
	_options.hide()
	_codex.hide()
	feedback.hide()
	show()


## Back button / Escape: closes the options first, then the menu.
func back() -> void:
	if _options.visible:
		_options.close()
	elif _codex.visible:
		_codex.back()
	elif feedback.visible:
		feedback.back()
	else:
		resume_requested.emit()


func _build() -> void:
	_dialog = RpgDialog.new(tr("Paused"), 0.0, 0.75)
	add_child(_dialog)
	move_child(_dialog, 0)  # under the options and the bestiary
	var resume := _row(tr("Resume"), "ResumeButton", tr("Back to the fight."), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_close)
		resume_requested.emit())
	resume.add_theme_font_size_override("font_size", Fonts.TITLE)
	PromptGlyph.badge(resume, &"pause", PromptGlyph.Place.INSIDE)  # Escape or Start resumes too
	_row(tr("Options"), "OptionsButton", tr("Sound, music, button size, effects."), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		_options.open())
	_row(tr("Bestiary"), "BestiaryButton", tr("The monsters you have met: how they attack and how to beat them."), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		if content:
			_codex.open(content, CodexPanel.Tab.BESTIARY))
	_row(tr("Quest journal"), "QuestsButton", tr("Village requests, current objectives and bounties."), func() -> void:
		if content:
			_codex.open(content, CodexPanel.Tab.QUESTS))
	_row(tr("Send feedback"), "FeedbackButton", tr("A bug, an idea? Tell the game's maker."), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		feedback.run_info = run_info
		feedback.open())
	_row(tr("Return to village"), "QuitButton", tr("Your run is saved. Resume it at the village well."), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		quit_requested.emit())
	# Giving up takes two taps, so it never happens by accident.
	var give_up := _row(tr(ABANDON_TEXT), "AbandonButton", tr(ABANDON_NOTE), _on_abandon)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		give_up.add_theme_color_override(state, Color(0.55, 0.06, 0.06))

	# Keep this help compact so seven touch-sized actions also fit a 720-pixel screen.
	_dialog.body.add_child(UiParts.text(tr("Gold lasts for one descent: spend it at the merchant or forge. Souls are kept; spend them at the village Shrine on permanent upgrades."), Fonts.BODY, UiSkin.DIM, BUTTON_SIZE.x + NOTE_WIDTH))
	_named.expose_to(self)
	feedback = FeedbackDialog.new()
	feedback.name = "FeedbackDialog"
	add_child(feedback)
	feedback.finished.connect(func() -> void:
		if InputDevice.uses_buttons():
			(get_node("%FeedbackButton") as Button).grab_focus())


func _on_abandon() -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	if not _armed:
		_armed = true
		_say_abandon()
	else:
		abandon_requested.emit()


## Give up's words: plain, or (armed) "Really?" in the device's words, following the device.
func _say_abandon() -> void:
	if _confirm == null:
		return
	_confirm.text = Prompts.pick(CONFIRM_TEXT, CONFIRM_TEXT_BUTTONS) if _armed else tr(ABANDON_TEXT)
	_abandon_note.text = Prompts.pick(CONFIRM_NOTE, CONFIRM_NOTE_BUTTONS) if _armed else tr(ABANDON_NOTE)


## Whether Give up waits for its second tap (tests).
func is_armed() -> bool:
	return _armed


## A button and what it does, beside it.
func _row(text: String, node_name: String, note: String, action: Callable) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_dialog.body.add_child(row)
	var button := UiParts.button(text, action, BUTTON_SIZE, Fonts.BODY)
	button.name = node_name
	row.add_child(button)
	_named.add(button)
	var words := UiParts.text(note, Fonts.BODY, UiSkin.DIM, NOTE_WIDTH)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.name = node_name + "Note"
	row.add_child(words)
	_named.add(words)
	return button
