class_name FeedbackDialog
extends RpgDialog
## "Send feedback" (the Feedback autoload; docs/online.md "Player feedback"): the player picks a
## kind (Bug, Idea, Other: FeedbackDef's categories), writes (a phone opens its keyboard), leaves
## or unticks "Include game info" (on by default: FeedbackInfo's details, and the run's when the
## opener gives `run_info`), ticks "Sign with my pseudonym" if they want (off; only shown when
## they have one), and sends. The form says plainly what goes and where; nothing goes before Send.
## Refusals are said under the text (too short, too long, too soon, no online service). Sent, the
## form closes and a note thanks the player in the Well's voice (show_toast(), over everything,
## even a paused game). Keys and gamepads go through it (MenuNav), the first kind focused first.
## Reachable as %Kind_<id>, %Text, %Counter, %Problem, %InfoSwitch, %InfoText, %SignSwitch,
## %PolicyButton, %CancelButton, %SendButton, %PolicyPanel.

const MenuNavScript := preload("res://src/autoload/menu_nav.gd")  # its static helpers are called on the script, not the autoload
const FeedbackScript := preload("res://src/autoload/feedback.gd")  # its Result enum, as a type

## Closed (sent or not).
signal finished

const WIDTH := 980.0
const TEXT_HEIGHT := 100.0
## Seconds the thank-you note stays.
const TOAST_SECONDS := 3.2
const TOAST_LAYER := 120
## The thank-you notes showing (the tests find them by it).
const TOAST_GROUP := &"feedback_toast"

## The run's details for "Include game info" (FeedbackInfo.run()), given by the opener in a run;
## not valid on the title.
var run_info: Callable
var policy: PrivacyPolicyPanel
## The kind picked (FeedbackCategoryDef.id).
var category: StringName = &""

var _text: TextEdit
var _counter: Label
var _problem: Label
var _info: CheckButton
var _info_text: Label
var _sign: CheckButton
var _send: Button
var _kinds: Array[Button] = []
## The form's right column (the switches and what is sent), and the inset holding the form.
var _right: VBoxContainer
var _inside: VBoxContainer


func _init() -> void:
	super._init(TranslationServer.tr("Send feedback"), WIDTH, 0.82)
	hide()


func _ready() -> void:
	_build()
	policy = PrivacyPolicyPanel.new()
	add_child(policy)
	MenuWindow.expose(policy, "PolicyPanel", self)
	policy.closed.connect(func() -> void:
		if InputDevice.uses_buttons():
			(get_node("%PolicyButton") as Button).grab_focus())
	Feedback.changed.connect(_refresh)


## Shows it empty, on the first kind, the game's details ticked, unsigned.
func open() -> void:
	_text.text = ""
	_info.set_pressed_no_signal(true)
	_sign.set_pressed_no_signal(false)
	var named := not Leaderboards.pseudonym.is_empty()
	_sign.visible = named
	if named:
		_sign.text = tr("Sign with my pseudonym: %s") % PlayerName.tagged(Leaderboards.pseudonym, Leaderboards.tag())
	_info_text.text = _info_words()
	_pick(Feedback.config.categories[0].id if not Feedback.config.categories.is_empty() else &"")
	_problem.text = ""
	show()
	_refresh()
	if not InputDevice.uses_buttons():
		_text.grab_focus.call_deferred()


## Back: the policy first, then the form (nothing sent).
func back() -> void:
	if policy and policy.visible:
		policy.close()
		return
	Sfx.play_ui(Sfx.bank.ui_close)
	_close()


## The words as typed (the tests write here).
func set_text(words: String) -> void:
	_text.text = words
	_on_text_changed()


## Sends what the form holds; returns what Feedback made of it (QUEUED: sent or on its way, the
## form closed and the note shown).
func send() -> FeedbackScript.Result:
	var details := {}
	if _info.button_pressed:
		details = FeedbackInfo.game()
		if run_info.is_valid():
			details.merge(run_info.call() as Dictionary)
		details.merge(FeedbackInfo.log_tail(Feedback.config.log_lines))
	var result := Feedback.submit(category, _text.text, details, _sign.visible and _sign.button_pressed)
	if result != FeedbackScript.Result.QUEUED:
		_problem.text = explain(result)
		Sfx.play_ui(Sfx.bank.ui_close)
		return result
	Sfx.play_ui(Sfx.bank.ui_click)
	_close()
	show_toast(self, tr("Thank you. Your words rise out of the Well to those who watch over it."), tr("Sent now, or as soon as the game is online."))
	return result


## Why a message wasn't taken, in plain words.
static func explain(result: FeedbackScript.Result) -> String:
	var config := Feedback.config
	match result:
		FeedbackScript.Result.EMPTY:
			return TranslationServer.tr("Write a few words first.")
		FeedbackScript.Result.TOO_SHORT:
			return TranslationServer.tr("A little more, please: at least %d characters.") % config.min_length
		FeedbackScript.Result.TOO_LONG:
			return TranslationServer.tr("Too long: %d characters at most.") % config.max_length
		FeedbackScript.Result.TOO_SOON:
			return TranslationServer.tr("Wait %d seconds before sending another message.") % Feedback.seconds_to_wait()
		FeedbackScript.Result.UNAVAILABLE:
			return TranslationServer.tr("No online service in this version: feedback can't be sent.")
		FeedbackScript.Result.UNKNOWN_CATEGORY:
			return TranslationServer.tr("Pick a kind of message.")
	return ""


## A note at the top of the screen, over everything (a paused game too), that fades: `voice` in
## gold, `plain` under it. Frees itself.
static func show_toast(from: Node, voice: String, plain: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "FeedbackToast"
	layer.add_to_group(TOAST_GROUP)
	layer.layer = TOAST_LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	var top := CenterContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 24
	top.offset_bottom = 24 + 120
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(top)
	var plate := PanelContainer.new()
	# The title's records plaque: dark wood, a gold edge (readable over the title and over a run).
	var style := MenuWindow.strip_style().duplicate() as StyleBoxTexture
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 14
	plate.add_theme_stylebox_override("panel", style)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(plate)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE  # (never takes a tap meant for the game)
	plate.add_child(column)
	for line: Array in [[voice, UiSkin.GOLD], [plain, UiSkin.DIM]]:
		if str(line[0]).is_empty():
			continue
		var label := UiSkin.label(str(line[0]), Fonts.BODY, line[1] as Color)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	from.get_tree().root.add_child(layer)
	holder.modulate.a = 0.0
	var tween := layer.create_tween()
	tween.tween_property(holder, "modulate:a", 1.0, 0.25)
	tween.tween_interval(TOAST_SECONDS)
	tween.tween_property(holder, "modulate:a", 0.0, 0.5)
	tween.tween_callback(layer.queue_free)
	return layer


func _build() -> void:
	var lore := UiSkin.label(tr("Speak, and your words will rise out of the Well. A bug, an idea, a thought: those who watch over it read them all."), Fonts.BODY, UiSkin.DIM, true)
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The words and the form's notes in a dark inset (never dim or red words on the bare wood).
	var recess := UiSkin.section()
	body.add_child(recess)
	_inside = VBoxContainer.new()
	_inside.add_theme_constant_override("separation", 10)
	recess.add_child(_inside)
	_inside.add_child(lore)
	# Two columns (what is written | what goes with it), so the form with finger-sized controls
	# fits a 720-line screen in French.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	_inside.add_child(columns)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	_right = VBoxContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.add_theme_constant_override("separation", 10)
	columns.add_child(_right)
	var kinds := HBoxContainer.new()
	kinds.add_theme_constant_override("separation", MenuWindow.TOUCH_GAP)
	left.add_child(kinds)
	var group := ButtonGroup.new()
	for def in Feedback.config.categories:
		var kind := MenuWindow.button(tr(def.display_name), Fonts.BODY, MenuWindow.TOUCH_MIN)
		kind.toggle_mode = true
		kind.button_group = group
		kind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kind.pressed.connect(func() -> void:
			Sfx.play_ui(Sfx.bank.ui_click)
			_pick(def.id))
		kinds.add_child(kind)
		MenuWindow.expose(kind, "Kind_%s" % def.id, self)
		_kinds.append(kind)
	# How much is written, beside the kinds (a line of its own would push the form past a 720-line
	# screen).
	_counter = UiSkin.label("", Fonts.BODY, UiSkin.DIM)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter.custom_minimum_size.x = Fonts.width("0000 / 0000", Fonts.BODY)
	_counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kinds.add_child(_counter)
	MenuWindow.expose(_counter, "Counter", self)
	_text = TextEdit.new()
	_text.custom_minimum_size = Vector2(0, TEXT_HEIGHT)
	_text.add_theme_font_size_override("font_size", Fonts.BODY)
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.virtual_keyboard_enabled = true
	_text.set_meta(SoftKeyboard.MAX_META, Feedback.config.max_length)  # (over the phone's keyboard: SoftKeyboard)
	_text.text_changed.connect(_on_text_changed)
	left.add_child(_text)
	MenuWindow.expose(_text, "Text", self)
	_problem = UiSkin.label("", Fonts.BODY, UiSkin.BAD, true)
	left.add_child(_problem)
	MenuWindow.expose(_problem, "Problem", self)
	_info = _switch(tr("Include game info"), "InfoSwitch")
	_info_text = UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	_right.add_child(_info_text)
	MenuWindow.expose(_info_text, "InfoText", self)
	_info.toggled.connect(func(_on: bool) -> void: _info_text.text = _info_words())
	_sign = _switch("", "SignSwitch")
	# Where it goes: across both columns (two lines, not five).
	_inside.add_child(UiSkin.label(tr("Sent to Talo (the game's online service), linked to this device's random ID; your name only if you sign. More in the privacy policy."), Fonts.BODY, UiSkin.DIM, true))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", MenuWindow.TOUCH_GAP)
	body.add_child(buttons)
	var link := UiParts.button(tr("Privacy policy"), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		policy.open(), Vector2(0, MenuWindow.TOUCH_MIN), Fonts.BODY)
	link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(link)
	MenuWindow.expose(link, "PolicyButton", self)
	var cancel := UiParts.button(tr("Cancel"), back, Vector2(0, MenuWindow.TOUCH_MIN), Fonts.BODY)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(cancel)
	MenuWindow.expose(cancel, "CancelButton", self)
	_send = UiParts.button(tr("Send"), func() -> void: send(), Vector2(0, MenuWindow.TOUCH_MIN), Fonts.BODY)
	_send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_send)
	MenuWindow.expose(_send, "SendButton", self)
	if not _kinds.is_empty():
		MenuNavScript.set_first(self, _kinds[0])


## An on/off line of the form, its words beside the switch (a tap on them flips it).
func _switch(words: String, node_name: String) -> CheckButton:
	var check := CheckButton.new()
	check.text = words
	check.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # (given translated; the pseudonym stays as it is)
	check.custom_minimum_size = Vector2(0, MenuWindow.TOUCH_MIN)
	check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # a long pseudonym never widens the form
	MenuWindow.style_switch(check)
	check.toggled.connect(func(_on: bool) -> void: Sfx.play_ui(Sfx.bank.ui_click))
	_right.add_child(check)
	MenuWindow.expose(check, node_name, self)
	return check


## What "Include game info" sends (in a run, the run too), or that nothing more goes.
func _info_words() -> String:
	if not _info.button_pressed:
		return tr("Only your words and their kind are sent.")
	if run_info.is_valid():
		return tr("Adds the version, system, device, screen, controls, language, this run (floor, act, difficulty, build, time) and the last lines of the log.")
	return tr("Adds the version, system, device, screen, controls, language and the last lines of the log.")


func _pick(id: StringName) -> void:
	category = id
	var defs := Feedback.config.categories
	for i in _kinds.size():
		_kinds[i].set_pressed_no_signal(defs[i].id == id)
	var def := Feedback.config.category(id)
	_text.placeholder_text = tr(def.hint) if def else ""


func _on_text_changed() -> void:
	var limit := Feedback.config.max_length
	if _text.text.length() > limit:
		_text.text = _text.text.left(limit)
		_text.set_caret_line(_text.get_line_count() - 1)
		_text.set_caret_column(_text.get_line(_text.get_line_count() - 1).length())
	_problem.text = ""
	_refresh()


## The counter, and Send while the game has no online service.
func _refresh() -> void:
	if _counter == null:
		return
	var length := _text.text.strip_edges().length()
	var limit := Feedback.config.max_length
	_counter.text = "%d / %d" % [length, limit]
	_counter.add_theme_color_override("font_color", UiSkin.BAD if length >= limit else UiSkin.DIM)
	_send.disabled = not Feedback.is_available()
	if not Feedback.is_available() and visible:
		_problem.text = explain(FeedbackScript.Result.UNAVAILABLE)


func _close() -> void:
	hide()
	finished.emit()

