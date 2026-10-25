class_name AccountDialog
extends RpgDialog
## "The Well's account" (Account, CloudSave; docs/online.md "Accounts and the online save"),
## opened from Options > Privacy. Signed out: what an account is for and what it sends, then Sign
## in or Create an account (a name, a password, an optional email for a lost password, "Stay
## signed in on this device"), and "Forgot your password?" (a code emailed, then a new password).
## Signed in: the name and its email, the online save's state and Sync now, "Stay signed in",
## Change password, Sign out and Delete the account (the password asked again). A conflict
## between this device's profile and the online one asks which to keep (CloudConflictDialog).
## Each page is built when shown; every refusal is said under the form in plain words
## (Account.explain()). Keys and gamepads go through it (MenuNav).
## Reachable as %AccountName, %AccountPassword, %AccountNewPassword, %AccountEmail,
## %AccountCode, %AccountStay, %AccountProblem, %AccountConfirm, %AccountBack, %SignInButton,
## %CreateButton, %ForgotButton, %SyncButton, %SignOutButton, %DeleteButton, %PasswordButton,
## %SaveState, %AccountText, %PolicyButton, %PolicyPanel, %ConflictDialog.

const MenuNavScript := preload("res://src/autoload/menu_nav.gd")  # its static helpers are called on the script, not the autoload
const AccountScript := preload("res://src/autoload/account.gd")  # its Result enum, as a type

## Closed.
signal finished

## The account dialogs (the title screen shows its own conflict dialog only when none is open).
const GROUP := &"account_dialog"
const WIDTH := 860.0

enum Page { CHOOSE, CREATE, SIGN_IN, FORGOT, RESET, ACCOUNT, PASSWORD, DELETE }

var page := Page.CHOOSE
var policy: PrivacyPolicyPanel
var conflict: CloudConflictDialog

var _name: LineEdit
var _password: LineEdit
var _new_password: LineEdit
var _email: LineEdit
var _code: LineEdit
var _stay: CheckButton
var _problem: Label
var _save_state: Label
var _confirm: Button


func _init() -> void:
	super._init(TranslationServer.tr("The Well's account"), WIDTH, 0.82)
	add_to_group(GROUP)
	hide()


func _ready() -> void:
	policy = PrivacyPolicyPanel.new()
	add_child(policy)
	MenuWindow.expose(policy, "PolicyPanel", self)
	conflict = CloudConflictDialog.new()
	add_child(conflict)
	MenuWindow.expose(conflict, "ConflictDialog", self)
	conflict.finished.connect(func() -> void: show_page(page))
	CloudSave.changed.connect(_show_save_state)
	CloudSave.conflict_found.connect(func() -> void:
		if visible:
			conflict.open())
	Account.changed.connect(func() -> void:
		if visible and page == Page.ACCOUNT and not Account.is_signed_in():
			show_page(Page.CHOOSE))


## Shown on the page that fits: the account if signed in, else what it is for.
func open() -> void:
	show()
	show_page(Page.ACCOUNT if Account.is_signed_in() else Page.CHOOSE)
	if CloudSave.state == CloudSave.Step.CONFLICT:
		conflict.open()


## Back: the policy or the conflict first, then the page before, then closed.
func back() -> void:
	if policy and policy.visible:
		policy.close()
		return
	if conflict and conflict.visible:
		return  # (a choice must be made)
	Sfx.play_ui(Sfx.bank.ui_close)
	match page:
		Page.CREATE, Page.SIGN_IN:
			show_page(Page.CHOOSE)
		Page.FORGOT:
			show_page(Page.SIGN_IN)
		Page.RESET:
			show_page(Page.FORGOT)
		Page.PASSWORD, Page.DELETE:
			show_page(Page.ACCOUNT)
		_:
			hide()
			finished.emit()


func show_page(which: Page) -> void:
	page = which
	UiParts.clear(body)
	_name = null
	_password = null
	_new_password = null
	_email = null
	_code = null
	_stay = null
	_save_state = null
	_confirm = null
	match which:
		Page.CHOOSE:
			_build_choose()
		Page.CREATE:
			_build_create()
		Page.SIGN_IN:
			_build_sign_in()
		Page.FORGOT:
			_build_forgot()
		Page.RESET:
			_build_reset()
		Page.ACCOUNT:
			_build_account()
		Page.PASSWORD:
			_build_password()
		Page.DELETE:
			_build_delete()
	_problem = UiSkin.label("", Fonts.BODY, UiSkin.BAD, true)
	body.add_child(_problem)
	body.move_child(_problem, body.get_child_count() - 2)  # (above the buttons)
	MenuWindow.expose(_problem, "AccountProblem", self)
	var first := _first_focus()
	if first:
		MenuNavScript.set_first(self, first)
		if InputDevice.uses_buttons() or first is LineEdit:
			first.grab_focus.call_deferred()


## What a step answered: said under the form (OK: nothing).
func say(result: AccountScript.Result) -> void:
	if _problem:
		_problem.text = Account.explain(result)
		_problem.add_theme_color_override("font_color", UiSkin.BAD)


# --- The pages --------------------------------------------------------------------------

func _build_choose() -> void:
	_lore(tr("Your name, written in the Well's book: wherever you go down, your souls and your deeds follow you."))
	if Account.session_ended:
		_line(Account.explain(AccountScript.Result.SESSION_ENDED), UiSkin.GOLD)
	_line(tr("An account keeps your progress online (souls, the Tree, records, the codex) so you find it on another device, a phone or a PC. It is optional: the game plays fully without it."), UiSkin.TEXT)
	_line(tr("Sent to Talo (the game's online service): the account's name, its password (stored scrambled), the email if you give one, and your progress. Not linked to the leaderboards. More in the privacy policy."), UiSkin.DIM)
	var row := _row()
	_button(row, tr("Sign in"), "SignInButton", func() -> void: _go(Page.SIGN_IN))
	_button(row, tr("Create an account"), "CreateButton", func() -> void: _go(Page.CREATE))
	var bottom := _row()
	_policy_button(bottom)
	_button(bottom, tr("Close"), "AccountBack", back)


func _build_create() -> void:
	_line(tr("The name can be found by other players: never your real name nor your email."), UiSkin.DIM)
	_name = _field(tr("Account name"), "AccountName", Account.explain(AccountScript.Result.BAD_NAME), false)
	_password = _field(tr("Password"), "AccountPassword", Account.explain(AccountScript.Result.BAD_PASSWORD), true)
	_email = _field(tr("Email (optional, only to reset a lost password)"), "AccountEmail", tr("Without one, a lost password can't be reset."), false)
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	_stay_switch()
	var row := _row()
	_button(row, tr("Back"), "AccountBack", back)
	_confirm = _button(row, tr("Create the account"), "AccountConfirm", _create)
	_password.text_submitted.connect(func(_t: String) -> void: _email.grab_focus())
	_email.text_submitted.connect(func(_t: String) -> void: _create())


func _build_sign_in() -> void:
	_name = _field(tr("Account name"), "AccountName", "", false)
	_name.text = Account.last_name
	_password = _field(tr("Password"), "AccountPassword", "", true)
	_stay_switch()
	var row := _row()
	_button(row, tr("Back"), "AccountBack", back)
	_button(row, tr("Forgot your password?"), "ForgotButton", func() -> void: _go(Page.FORGOT))
	_confirm = _button(row, tr("Sign in"), "AccountConfirm", _sign_in)
	_password.text_submitted.connect(func(_t: String) -> void: _sign_in())


func _build_forgot() -> void:
	_line(tr("Give the account's email: a code to choose a new password is sent to it (if an account has it)."), UiSkin.TEXT)
	_email = _field(tr("Email"), "AccountEmail", "", false)
	_email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	var row := _row()
	_button(row, tr("Back"), "AccountBack", back)
	_button(row, tr("I have a code"), "CodeButton", func() -> void: _go(Page.RESET))
	_confirm = _button(row, tr("Send the code"), "AccountConfirm", _forgot)
	_email.text_submitted.connect(func(_t: String) -> void: _forgot())


func _build_reset() -> void:
	_line(tr("Type the code from the email and your new password, then sign in with it."), UiSkin.TEXT)
	_code = _field(tr("Code (%d digits)") % Account.config.reset_code_digits, "AccountCode", "", false)
	_code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_code.max_length = Account.config.reset_code_digits
	_new_password = _field(tr("New password"), "AccountNewPassword", Account.explain(AccountScript.Result.BAD_PASSWORD), true)
	var row := _row()
	_button(row, tr("Back"), "AccountBack", back)
	_confirm = _button(row, tr("Set the password"), "AccountConfirm", _reset)
	_new_password.text_submitted.connect(func(_t: String) -> void: _reset())


func _build_account() -> void:
	var auth := Account.auth
	var who := UiSkin.label(tr("Signed in as %s") % (auth.identifier if auth else "-"), Fonts.BODY, UiSkin.GOLD, true)
	who.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # (a player's name; tr() above)
	body.add_child(who)
	MenuWindow.expose(who, "AccountText", self)
	var email := (tr("Recovery email: %s") % auth.email) if auth and not auth.email.is_empty() else tr("No recovery email: a lost password can't be reset.")
	var email_line := _line(email, UiSkin.DIM)
	email_line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_save_state = _line("", UiSkin.TEXT)
	MenuWindow.expose(_save_state, "SaveState", self)
	_show_save_state()
	_stay_switch()
	_stay.toggled.connect(func(on: bool) -> void: Account.set_stay_signed_in(on))
	var row := _row()
	_button(row, tr("Sync now"), "SyncButton", func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		CloudSave.sync())
	_button(row, tr("Change password"), "PasswordButton", func() -> void: _go(Page.PASSWORD))
	var bottom := _row()
	_button(bottom, tr("Sign out"), "SignOutButton", func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		await Account.sign_out()
		show_page(Page.CHOOSE))
	_button(bottom, tr("Delete the account"), "DeleteButton", func() -> void: _go(Page.DELETE))
	_button(bottom, tr("Close"), "AccountBack", back)


func _build_password() -> void:
	_password = _field(tr("Current password"), "AccountPassword", "", true)
	_new_password = _field(tr("New password"), "AccountNewPassword", Account.explain(AccountScript.Result.BAD_PASSWORD), true)
	var row := _row()
	_button(row, tr("Back"), "AccountBack", back)
	_confirm = _button(row, tr("Change password"), "AccountConfirm", _change_password)
	_new_password.text_submitted.connect(func(_t: String) -> void: _change_password())


func _build_delete() -> void:
	_line(tr("The account, its email and its online save are deleted for good. Your progress on this device stays. Type your password to confirm."), UiSkin.TEXT)
	_password = _field(tr("Password"), "AccountPassword", "", true)
	var row := _row()
	_button(row, tr("Back"), "AccountBack", back)
	_confirm = _button(row, tr("Delete for good"), "AccountConfirm", _delete)
	_password.text_submitted.connect(func(_t: String) -> void: _delete())


# --- The steps ------------------------------------------------------------------------

func _create() -> void:
	var result: AccountScript.Result = await _step(func() -> AccountScript.Result: return await Account.register(_name.text, _password.text, _email.text, _stay.button_pressed))
	if result == AccountScript.Result.OK:
		show_page(Page.ACCOUNT)


func _sign_in() -> void:
	var result: AccountScript.Result = await _step(func() -> AccountScript.Result: return await Account.sign_in(_name.text, _password.text, _stay.button_pressed))
	if result == AccountScript.Result.OK:
		show_page(Page.ACCOUNT)


func _forgot() -> void:
	var result: AccountScript.Result = await _step(func() -> AccountScript.Result: return await Account.forgot_password(_email.text))
	if result == AccountScript.Result.OK:
		show_page(Page.RESET)
		_said(tr("If an account has this email, a code was sent to it. Look in the spam folder too."))


func _reset() -> void:
	var result: AccountScript.Result = await _step(func() -> AccountScript.Result: return await Account.reset_password(_code.text, _new_password.text))
	if result == AccountScript.Result.OK:
		show_page(Page.SIGN_IN)
		_said(tr("Password changed: sign in with it."))


func _change_password() -> void:
	var result: AccountScript.Result = await _step(func() -> AccountScript.Result: return await Account.change_password(_password.text, _new_password.text))
	if result == AccountScript.Result.OK:
		show_page(Page.ACCOUNT)
		_said(tr("Password changed."))


func _delete() -> void:
	var result: AccountScript.Result = await _step(func() -> AccountScript.Result: return await Account.delete_account(_password.text))
	if result == AccountScript.Result.OK:
		show_page(Page.CHOOSE)
		_said(tr("The account and its online save are deleted."))


## A step run with the confirm button off and "Please wait..." meanwhile; its answer said.
func _step(run: Callable) -> AccountScript.Result:
	Sfx.play_ui(Sfx.bank.ui_click)
	if _confirm:
		_confirm.disabled = true
	_said(tr("Please wait..."), UiSkin.DIM)
	var result: AccountScript.Result = await run.call()
	if not is_instance_valid(_confirm) and result != AccountScript.Result.OK:
		return result
	if is_instance_valid(_confirm):
		_confirm.disabled = false
	if result != AccountScript.Result.OK:
		say(result)
		Sfx.play_ui(Sfx.bank.ui_close)
	elif _problem:
		_problem.text = ""
	return result


# --- Pieces ---------------------------------------------------------------------------

## The online save's state in words.
func _show_save_state() -> void:
	if _save_state == null or not is_instance_valid(_save_state):
		return
	_save_state.text = save_state_words()


static func save_state_words() -> String:
	match CloudSave.state:
		CloudSave.Step.SYNCING:
			return TranslationServer.tr("Saving online...")
		CloudSave.Step.OFFLINE:
			return TranslationServer.tr("No network: your progress goes online as soon as the game is.")
		CloudSave.Step.REFUSED:
			return TranslationServer.tr("The server refused the online save; it tries again later.")
		CloudSave.Step.CONFLICT:
			return TranslationServer.tr("Two different progressions: choose the one to keep.")
		CloudSave.Step.TOO_BIG:
			return TranslationServer.tr("Your profile is too big to be saved online.")
		CloudSave.Step.WAITING:
			return TranslationServer.tr("A newer save from another device comes in once this run is over.")
		CloudSave.Step.OFF:
			return TranslationServer.tr("Not signed in.")
	if CloudSave.synced_at <= 0:
		return TranslationServer.tr("Your progress goes online by itself.")
	return TranslationServer.tr("Saved online: %s.") % when(CloudSave.synced_at)


## A moment as this device's clock shows it ("2026-10-25 14:32").
static func when(unix: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var date := Time.get_datetime_dict_from_unix_time(unix + bias * 60)
	return "%04d-%02d-%02d %02d:%02d" % [date.year, date.month, date.day, date.hour, date.minute]


func _go(which: Page) -> void:
	Sfx.play_ui(Sfx.bank.ui_open)
	show_page(which)


func _said(words: String, color: Color = UiSkin.GOOD) -> void:
	if _problem:
		_problem.text = words
		_problem.add_theme_color_override("font_color", color)


func _lore(words: String) -> void:
	var lore := UiSkin.label(words, Fonts.BODY, UiSkin.DIM, true)
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(lore)


func _line(words: String, color: Color) -> Label:
	var label := UiSkin.label(words, Fonts.BODY, color, true)
	body.add_child(label)
	return label


## A field with its name above (`hint`: shown over a phone's keyboard; `secret`: a password).
func _field(title: String, node_name: String, hint: String, secret: bool) -> LineEdit:
	body.add_child(UiSkin.label(title, Fonts.BODY, UiSkin.GOLD, true))
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(0, 52)
	edit.add_theme_font_size_override("font_size", Fonts.BODY)
	edit.secret = secret
	edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD if secret else LineEdit.KEYBOARD_TYPE_DEFAULT
	edit.max_length = Account.config.password_max if secret else 254
	if not hint.is_empty():
		edit.set_meta(SoftKeyboard.HINT_META, hint)
	edit.text_changed.connect(func(_t: String) -> void:
		if _problem:
			_problem.text = "")
	body.add_child(edit)
	MenuWindow.expose(edit, node_name, self)
	return edit


func _stay_switch() -> void:
	_stay = CheckButton.new()
	_stay.text = tr("Stay signed in on this device")
	_stay.custom_minimum_size = Vector2(0, 40)
	MenuWindow.style_switch(_stay)
	_stay.set_pressed_no_signal(Account.stay_signed_in)
	_stay.toggled.connect(func(_on: bool) -> void: Sfx.play_ui(Sfx.bank.ui_click))
	body.add_child(_stay)
	MenuWindow.expose(_stay, "AccountStay", self)
	body.add_child(UiSkin.label(tr("Keeps your password on this device, to sign in again by itself when another device used the account."), Fonts.BODY, UiSkin.DIM, true))


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	return row


func _button(row: HBoxContainer, words: String, node_name: String, action: Callable) -> Button:
	var button := UiParts.button(words, action, Vector2(0, 52), Fonts.BODY)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(button)
	MenuWindow.expose(button, node_name, self)
	return button


func _policy_button(row: HBoxContainer) -> void:
	_button(row, tr("Privacy policy"), "PolicyButton", func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		policy.open())


func _first_focus() -> Control:
	for edit: LineEdit in [_code, _name, _email, _password]:
		if edit and edit.text.is_empty():
			return edit
	for edit: LineEdit in [_password, _new_password]:
		if edit:
			return edit
	for child in body.get_children():
		if child is HBoxContainer and child.get_child_count() > 0 and child.get_child(0) is Button:
			return child.get_child(0) as Button
	return null
