class_name PrivacyPage
extends HBoxContainer
## Options > Privacy (design/interface.md, "Privacy and credits"): with a server in the build,
## the leaderboards on the left (the name shown, Change: PseudonymDialog; "Publish my scores
## online") and the player's data on the right (the gameplay statistics' switch: ConsentDialog;
## the device's online ID; "Delete my online data": DeleteDataDialog); always, the privacy
## policy and the credits (InfoPanels). Its dialogs open over the whole window (`window`, the
## OptionsPanel, which also owns every %Name). With accounts in the build, the Well's account
## too (who is signed in, the online save's state; Account opens AccountDialog). Built by build(),
## after it is in the window.

var window: Control
var _boards_name: Label
var _boards_show: CheckButton
var _name_dialog: PseudonymDialog
var _analytics: CheckButton
var _consent: ConsentDialog
var _online_id: Label
var _policy: PrivacyPolicyPanel
var _credits: CreditsPanel
var _delete: DeleteDataDialog
var _account_text: Label
var _account: AccountDialog


func _init() -> void:
	add_theme_constant_override("separation", 14)


## Builds the page; `options` owns its controls' names and shows its dialogs.
func build(options: Control) -> void:
	window = options
	var left := OptionRows.column(self)
	if Leaderboards.is_available():
		_build_boards(OptionRows.section(left, tr("Leaderboards")))
		var right := OptionRows.column(self)
		if Account.is_available():
			_build_account(OptionRows.section(right, tr("Account")))
		_build_analytics(OptionRows.section(right, tr("Your data")))
	var about := OptionRows.section(left, tr("Policy and credits"))
	about.add_child(UiSkin.label(tr("What is sent, to whom and why; who made the game and its licenses."), Fonts.BODY, UiSkin.DIM, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	about.add_child(row)
	var policy := MenuWindow.button(tr("Privacy policy"), Fonts.BODY, 44)
	policy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(policy)
	MenuWindow.expose(policy, "PolicyButton", window)
	var credits := MenuWindow.button(tr("Credits"), Fonts.BODY, 44)
	credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(credits)
	MenuWindow.expose(credits, "CreditsButton", window)
	_policy = PrivacyPolicyPanel.new()
	_overlay(_policy, "PolicyPanel")
	_credits = CreditsPanel.new()
	_overlay(_credits, "CreditsPanel")
	policy.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		_policy.open())
	credits.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		_credits.open())
	_policy.closed.connect(func() -> void: _refocus(policy))
	_credits.closed.connect(func() -> void: _refocus(credits))


## The online choices as Leaderboards and Privacy have them.
func refresh() -> void:
	if _boards_name:
		_boards_name.text = Leaderboards.tagged_name()
		_boards_show.set_pressed_no_signal(Leaderboards.shown)
	if _analytics:
		_analytics.set_pressed_no_signal(Privacy.analytics_allowed())
	if _account_text:
		_account_text.text = (tr("Signed in as %s") % Account.account_name()) + "\n" + AccountDialog.save_state_words() if Account.is_signed_in() else tr("Not signed in: your progress stays on this device.")
	if _online_id:
		_online_id.text = OnlineSession.device_id if not OnlineSession.device_id.is_empty() else tr("None yet (nothing was sent)")


## Back: closes the dialog or page open over the window. False when none was open.
func back() -> bool:
	if _name_dialog and _name_dialog.visible:
		_name_dialog.cancel()
		return true
	if _consent and _consent.visible:
		_consent.back()
		return true
	if _delete and _delete.visible:
		_delete.back()
		return true
	if _account and _account.visible:
		_account.back()
		return true
	for info: InfoPanel in [_policy, _credits]:
		if info and info.back():
			return true
	return false


## A dialog or page over the whole window, reachable as %`node_name` from it.
func _overlay(node: Control, node_name: String) -> void:
	window.add_child(node)
	MenuWindow.expose(node, node_name, window)


## The gameplay statistics' switch (on: the age and consent questions, ConsentDialog; off: at
## once), the device's online ID, and the deletion request.
func _build_analytics(section: VBoxContainer) -> void:
	_analytics = OptionRows.check(window, section, tr("Gameplay statistics"), tr("A summary of each run sent to help balance the game (asked first). Off: nothing is sent."), "AnalyticsCheck")
	_consent = ConsentDialog.new()
	_overlay(_consent, "ConsentDialog")
	_consent.finished.connect(func() -> void:
		refresh()
		_refocus(_analytics))
	_analytics.toggled.connect(func(on: bool) -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		if on:
			_analytics.set_pressed_no_signal(false)  # (on only once accepted)
			_consent.ask()
		else:
			Privacy.refuse()
		refresh())
	var id_row := OptionRows.words(tr("Your online ID"), "")
	_online_id = OptionRows.note_of(id_row)
	_online_id.add_theme_color_override("font_color", UiSkin.GOLD)
	_online_id.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # (an ID)
	section.add_child(id_row)
	MenuWindow.expose(_online_id, "OnlineIdText", window)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	section.add_child(row)
	row.add_child(OptionRows.words(tr("Delete my online data"), tr("Asks by email for what was sent to be deleted, then turns everything online off.")))
	var delete := MenuWindow.button(tr("Delete"), Fonts.BODY, 44)
	delete.custom_minimum_size.x = 150
	delete.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(delete)
	MenuWindow.expose(delete, "DeleteDataButton", window)
	_delete = DeleteDataDialog.new()
	_overlay(_delete, "DeleteDialog")
	_delete.finished.connect(func() -> void:
		refresh()
		_refocus(delete))
	delete.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		_delete.open())


## The Well's account: who is signed in and the online save's state, and the button that opens
## AccountDialog (sign in, create, the account's page).
func _build_account(section: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	section.add_child(row)
	var words := OptionRows.words(tr("Online save"), "")
	_account_text = OptionRows.note_of(words)
	_account_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # (holds a name; tr() in refresh())
	row.add_child(words)
	MenuWindow.expose(_account_text, "AccountStateText", window)
	var open := MenuWindow.button(tr("Account"), Fonts.BODY, 44)
	open.custom_minimum_size.x = 150
	open.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(open)
	MenuWindow.expose(open, "AccountButton", window)
	_account = AccountDialog.new()
	_overlay(_account, "AccountDialog")
	_account.finished.connect(func() -> void:
		refresh()
		_refocus(open))
	Account.changed.connect(refresh)
	CloudSave.changed.connect(refresh)
	open.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		_account.open())


## The online leaderboards: the name shown (Change opens PseudonymDialog), and the switch that
## publishes the scores or keeps every score home.
func _build_boards(section: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	section.add_child(row)
	var name_row := OptionRows.words(tr("Your name"), "")
	_boards_name = OptionRows.note_of(name_row)
	_boards_name.add_theme_color_override("font_color", UiSkin.GOLD)
	_boards_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # (a player's name)
	row.add_child(name_row)
	MenuWindow.expose(_boards_name, "BoardsNameText", window)
	var change := MenuWindow.button(tr("Change"), Fonts.BODY, 44)
	change.custom_minimum_size.x = 150
	change.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(change)
	MenuWindow.expose(change, "BoardsNameButton", window)
	_boards_show = OptionRows.check(window, section, tr("Publish my scores online"), tr("Your Dawn Knell scores and this name, public on the leaderboards. Off: nothing is sent nor read."), "BoardsShowCheck")
	_boards_show.toggled.connect(func(on: bool) -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		if on and not Leaderboards.name_chosen:
			# Never chosen: the question with what it means first.
			_boards_show.set_pressed_no_signal(false)
			_name_dialog.open()
			return
		Leaderboards.set_shown(on)
		refresh())
	_name_dialog = PseudonymDialog.new()
	_overlay(_name_dialog, "NameDialog")
	_name_dialog.finished.connect(refresh)
	change.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		_name_dialog.open())


## Keys or a gamepad: the focus back on `control` once what it opened closed.
func _refocus(control: Control) -> void:
	if is_instance_valid(control) and control.is_visible_in_tree() and InputDevice.uses_buttons():
		control.grab_focus()
