extends OnlineService
## The Well's account (autoload "Account"; docs/online.md "Accounts and the online save"): an
## optional name and password on Talo (its player auth), with an optional email to reset a lost
## password, so the profile can follow the player from a phone to a PC (CloudSave). The account
## is its own player on the server, apart from the device's (the leaderboards, the statistics and
## the feedback keep the device's): only the online save goes with it.
##
## Made or used only when the player asks (Options > Privacy > Account): nothing is sent before.
## Talo keeps **one session per account**: signing in on another device ends this one's (its
## token refused: INVALID_SESSION). "Stay signed in" (off by default) keeps the password on this
## device to sign in again by itself then; without it, the game asks for the password again.
##
## Its file, user://account.json: the account's name, ids and session token (and the password
## only with "Stay signed in"). The tests give it no file and the session a fake server.

## Signed in or out, or the email or the "stay signed in" choice changed.
signal changed
## Signed in (made, signed in, or signed in again by itself): CloudSave syncs.
signal signed_in
## Signed out (by the player, the account deleted, or the session ended elsewhere).
signal signed_out
## The account and its online save deleted on the server (CloudSave forgets what it knew).
signal deleted

const PATH := "user://account.json"
const DEFS := "res://data/online/account.tres"
const VERSION := 1

## What an account step answers, for the window's words (explain()).
enum Result { OK, OFFLINE, NO_SERVER, BUSY, NAME_TAKEN, EMAIL_TAKEN, WRONG_LOGIN, WRONG_PASSWORD, WRONG_CODE, BAD_NAME, NAME_IS_EMAIL, BAD_PASSWORD, BAD_EMAIL, SAME_PASSWORD, NOT_SIGNED_IN, SESSION_ENDED, REFUSED }

var config: AccountDef
## The account signed in (null: none).
var auth: BoardBackend.AccountAuth
## The last name used on this device (kept after signing out, to fill the sign-in form).
var last_name := ""
## The password kept for signing in again by itself (only with stay_signed_in).
var stay_signed_in := false
## The server's reason for the last refusal (shown with "The server refused it": Talo's
## errorCode, or "HTTP 403").
var last_error := ""
## Signed out because another device took the session (the window says so, once).
var session_ended := false

var store: PersistedQueue
var path: String:
	get:
		return store.path
	set(value):
		store.path = value
var _password := ""
var _busy := false


func _init() -> void:
	store = PersistedQueue.new(PATH, VERSION)
	add_child(store)
	config = load(DEFS) as AccountDef
	load_state()


func _ready() -> void:
	OnlineSession.register(self)


## The tests: no file, signed out, nothing kept.
func use_for_tests(_fake: BoardBackend = null) -> void:
	path = ""
	reset()


func reset() -> void:
	auth = null
	last_name = ""
	stay_signed_in = false
	session_ended = false
	_password = ""
	_busy = false
	store.reset()


## Accounts can be used: this build has a server and the feature is on.
func is_available() -> bool:
	return config != null and config.enabled and OnlineSession.is_available()


func is_signed_in() -> bool:
	return auth != null and auth.is_valid()


## The account's name ("" signed out).
func account_name() -> String:
	return auth.identifier if is_signed_in() else ""


## A step is on its way (the window waits; another one is refused: BUSY).
func is_busy() -> bool:
	return _busy


# --- What the player types ------------------------------------------------------------------

## What is wrong with a name, a password, an email ("" email: none, allowed): Result.OK if nothing.
func check_name(text: String) -> Result:
	var name_text := text.strip_edges()
	if name_text.contains("@"):
		return Result.NAME_IS_EMAIL
	if name_text.length() < config.name_min or name_text.length() > config.name_max:
		return Result.BAD_NAME
	for c in name_text:
		if not (c.unicode_at(0) < 128 and (c.is_valid_identifier() or c.is_valid_int() or c in "-_.")):
			return Result.BAD_NAME
	return Result.OK


func check_password(text: String) -> Result:
	return Result.OK if text.length() >= config.password_min and text.length() <= config.password_max else Result.BAD_PASSWORD


func check_email(text: String) -> Result:
	var email := text.strip_edges()
	if email.is_empty():
		return Result.OK
	var at := email.find("@")
	if at <= 0 or at != email.rfind("@") or not email.substr(at + 1).contains(".") or email.ends_with(".") or email.contains(" "):
		return Result.BAD_EMAIL
	return Result.OK


## The words for `result` (what the window shows under the form).
func explain(result: Result) -> String:
	match result:
		Result.OK:
			return ""
		Result.OFFLINE:
			return tr("No answer from the server. Check the network and try again.")
		Result.NO_SERVER:
			return tr("Accounts aren't available in this version of the game.")
		Result.BUSY:
			return tr("Wait a moment: the last step isn't finished.")
		Result.NAME_TAKEN:
			return tr("This name is already taken.")
		Result.EMAIL_TAKEN:
			return tr("This email is already used by another account.")
		Result.WRONG_LOGIN:
			return tr("Wrong name or password.")
		Result.WRONG_PASSWORD:
			return tr("Wrong password.")
		Result.WRONG_CODE:
			return tr("This code is wrong or too old. Ask for a new one.")
		Result.BAD_NAME:
			return tr("Name: %d to %d letters, digits and - _ . (no spaces).") % [config.name_min, config.name_max]
		Result.NAME_IS_EMAIL:
			return tr("The account's name can be found by other players: don't use your email.")
		Result.BAD_PASSWORD:
			return tr("Password: %d to %d characters.") % [config.password_min, config.password_max]
		Result.BAD_EMAIL:
			return tr("This email doesn't look right.")
		Result.SAME_PASSWORD:
			return tr("Choose a password different from the current one.")
		Result.NOT_SIGNED_IN:
			return tr("Sign in first.")
		Result.SESSION_ENDED:
			return tr("You signed in on another device: sign in again here.")
	return tr("The server refused it (%s).") % (last_error if not last_error.is_empty() else "?")


# --- The steps ------------------------------------------------------------------------

## A new account, signed in: `email` ("" none) only to reset a lost password.
func register(name_text: String, password: String, email: String, keep: bool) -> Result:
	var problem := _first_problem([check_name(name_text), check_password(password), check_email(email)])
	if problem != Result.OK:
		return problem
	if not _begin():
		return Result.BUSY if _busy else Result.NO_SERVER
	@warning_ignore("redundant_await")  # a coroutine in TaloBackend; the offline BoardBackend answers at once
	var answer: BoardBackend.AccountAnswer = await OnlineSession.backend.account_register(name_text.strip_edges(), password, email.strip_edges().to_lower())
	_busy = false
	var result := _result_of(answer)
	if result == Result.OK:
		_adopt(answer.auth, password, keep)
	return result


func sign_in(name_text: String, password: String, keep: bool) -> Result:
	if name_text.strip_edges().is_empty() or password.is_empty():
		return Result.WRONG_LOGIN
	if not _begin():
		return Result.BUSY if _busy else Result.NO_SERVER
	@warning_ignore("redundant_await")
	var answer: BoardBackend.AccountAnswer = await OnlineSession.backend.account_login(name_text.strip_edges(), password)
	_busy = false
	var result := _result_of(answer)
	if result == Result.OK:
		_adopt(answer.auth, password, keep)
	return result


## Signed out here (and on the server, if it answers): the online save stays online.
func sign_out() -> void:
	var was := auth
	_forget_session(true)
	if was:
		@warning_ignore("redundant_await")
		await OnlineSession.backend.account_logout(was)


## Another device took the session (a call answered INVALID_SESSION): signed in again by itself
## with the kept password ("Stay signed in"), else signed out (the window asks for the password).
## True: signed in again.
func session_refused() -> bool:
	if stay_signed_in and not _password.is_empty() and not last_name.is_empty() and not _busy:
		var result := await sign_in(last_name, _password, true)
		if result == Result.OK:
			return true
		if result == Result.OFFLINE:
			return false  # (tried again at the next sync)
	session_ended = true
	_forget_session(true)
	return false


## The reset code sent to `email` (the server answers the same whether an account has it).
func forgot_password(email: String) -> Result:
	if email.strip_edges().is_empty() or check_email(email) != Result.OK:
		return Result.BAD_EMAIL
	if not _begin():
		return Result.BUSY if _busy else Result.NO_SERVER
	@warning_ignore("redundant_await")
	var status: BoardBackend.Status = await OnlineSession.backend.account_forgot_password(email.strip_edges().to_lower())
	_busy = false
	return _status_result(status)


## The new password set with the emailed code (then sign in with it).
func reset_password(code: String, password: String) -> Result:
	var digits := code.strip_edges()
	if digits.length() != config.reset_code_digits or not digits.is_valid_int():
		return Result.WRONG_CODE
	var problem := check_password(password)
	if problem != Result.OK:
		return problem
	if not _begin():
		return Result.BUSY if _busy else Result.NO_SERVER
	@warning_ignore("redundant_await")
	var answer: BoardBackend.AccountAnswer = await OnlineSession.backend.account_reset_password(digits, password)
	_busy = false
	return _result_of(answer)


func change_password(current: String, new_password: String) -> Result:
	if not is_signed_in():
		return Result.NOT_SIGNED_IN
	var problem := check_password(new_password)
	if problem != Result.OK:
		return problem
	if not _begin():
		return Result.BUSY if _busy else Result.NO_SERVER
	@warning_ignore("redundant_await")
	var answer: BoardBackend.AccountAnswer = await OnlineSession.backend.account_change_password(auth, current, new_password)
	_busy = false
	var result := _result_of(answer)
	if result == Result.OK and stay_signed_in:
		_password = new_password
		save_state()
	return result


## The account deleted on the server, its online save first (the password asked again), then
## signed out here. The profile on this device stays.
func delete_account(password: String) -> Result:
	if not is_signed_in():
		return Result.NOT_SIGNED_IN
	if password.is_empty():
		return Result.WRONG_PASSWORD
	if not _begin():
		return Result.BUSY if _busy else Result.NO_SERVER
	var backend := OnlineSession.backend
	# The password checked first by signing in with it (a wrong one deletes nothing; the new
	# session replaces this one), then the online saves, then the account (its alias gone, its
	# saves could no longer be reached).
	@warning_ignore("redundant_await")
	var check: BoardBackend.AccountAnswer = await backend.account_login(auth.identifier, password)
	var result := _result_of(check)
	if result != Result.OK:
		_busy = false
		return Result.WRONG_PASSWORD if result == Result.WRONG_LOGIN else result
	auth = check.auth
	save_state()
	@warning_ignore("redundant_await")
	var listed: BoardBackend.SaveAnswer = await backend.saves_list(auth)
	if listed.status != BoardBackend.Status.OK:
		_busy = false
		return _status_result(listed.status)
	for slot in listed.saves:
		@warning_ignore("redundant_await")
		var gone: BoardBackend.Status = await backend.save_delete(auth, slot.id)
		if gone != BoardBackend.Status.OK:
			_busy = false
			return _status_result(gone)
	@warning_ignore("redundant_await")
	var answer: BoardBackend.AccountAnswer = await backend.account_delete(auth, password)
	_busy = false
	result = _result_of(answer)
	if result != Result.OK:
		return Result.WRONG_PASSWORD if result == Result.WRONG_LOGIN else result
	last_name = ""
	_forget_session(true)
	deleted.emit()
	return Result.OK


## Stay signed in on this device (the password kept to sign in again by itself), or not.
func set_stay_signed_in(on: bool) -> void:
	stay_signed_in = on
	if not on:
		_password = ""
	save_state()
	changed.emit()


# --- Inside ---------------------------------------------------------------------------

func _begin() -> bool:
	if _busy or not is_available():
		return false
	_busy = true
	return true


func _adopt(new_auth: BoardBackend.AccountAuth, password: String, keep: bool) -> void:
	auth = new_auth
	last_name = new_auth.identifier
	stay_signed_in = keep
	_password = password if keep else ""
	session_ended = false
	save_state()
	changed.emit()
	signed_in.emit()


## Signed out here; `clear_password`: the kept password forgotten too.
func _forget_session(clear_password: bool) -> void:
	var was := auth != null
	auth = null
	if clear_password:
		_password = ""
	save_state()
	changed.emit()
	if was:
		signed_out.emit()


static func _first_problem(results: Array) -> Result:
	for result: Result in results:
		if result != Result.OK:
			return result
	return Result.OK


func _status_result(status: BoardBackend.Status) -> Result:
	match status:
		BoardBackend.Status.OK:
			return Result.OK
		BoardBackend.Status.OFFLINE:
			return Result.OFFLINE
		BoardBackend.Status.UNAVAILABLE:
			return Result.NO_SERVER
	return Result.REFUSED


## The server's answer as a Result, from its errorCode when refused.
func _result_of(answer: BoardBackend.AccountAnswer) -> Result:
	last_error = answer.error
	if answer.status != BoardBackend.Status.REJECTED:
		return _status_result(answer.status)
	match answer.error:
		"IDENTIFIER_TAKEN":
			return Result.NAME_TAKEN
		"EMAIL_TAKEN":
			return Result.EMAIL_TAKEN
		"INVALID_CREDENTIALS":
			return Result.WRONG_LOGIN
		"PASSWORD_RESET_CODE_INVALID":
			return Result.WRONG_CODE
		"INVALID_EMAIL":
			return Result.BAD_EMAIL
		"NEW_PASSWORD_MATCHES_CURRENT_PASSWORD":
			return Result.SAME_PASSWORD
		"IDENTIFIER_PROFANITY":
			return Result.BAD_NAME
		"INVALID_SESSION", "MISSING_SESSION":
			return Result.SESSION_ENDED
	return Result.REFUSED


# --- The file ------------------------------------------------------------------

func save_state() -> void:
	var data := { "last_name": last_name, "stay_signed_in": stay_signed_in, "session_ended": session_ended }
	if auth:
		data["account"] = { "alias": auth.alias_id, "player": auth.player_id, "token": auth.token, "name": auth.identifier, "email": auth.email }
	if stay_signed_in and not _password.is_empty():
		data["password"] = _password
	store.write(data)


func load_state() -> void:
	auth = null
	var data := store.read()
	last_name = str(data.get("last_name", ""))
	stay_signed_in = bool(data.get("stay_signed_in", false))
	session_ended = bool(data.get("session_ended", false))
	_password = str(data.get("password", "")) if stay_signed_in else ""
	var saved: Variant = data.get("account")
	if saved is Dictionary:
		var kept := BoardBackend.AccountAuth.new()
		kept.alias_id = int((saved as Dictionary).get("alias", 0))
		kept.player_id = str((saved as Dictionary).get("player", ""))
		kept.token = str((saved as Dictionary).get("token", ""))
		kept.identifier = str((saved as Dictionary).get("name", ""))
		kept.email = str((saved as Dictionary).get("email", ""))
		if kept.is_valid():
			auth = kept
