class_name AccountTests
extends TestSuite
## The Well's accounts (Account) and the online save (CloudSave) on a fake server
## (FakeBoardBackend: Talo's accounts and game saves in memory, one session per account like
## Talo's): never the network. run_unit(): the data and what may be typed; nothing without a
## server; making an account, a name or an email taken, signing out and in; a lost password reset
## by the emailed code; changing the password; the session taken by another device (signed out,
## or signed in again by itself with "Stay signed in"); deleting the account (a wrong password
## deletes nothing; then its save and itself); the file (the password only when kept). The online
## save: a first sign-in sends this profile up, or takes the online one into a fresh profile; a
## change goes up after upload_delay; another device's newer copy comes down; both changed: the
## conflict and either choice; in a run the online copy waits for the menus; offline, refused,
## too big; another account starts again.

## Per test process (parallel runs share one user:// folder).
var _file := "user://test_account_%d.json" % OS.get_process_id()

var _fake: FakeBoardBackend
## The player's profile before the tests (put back at the end).
var _kept_profile := {}


func run_unit() -> void:
	_kept_profile = Profile.to_data()
	_test_data()
	await _test_no_server()
	await _test_register_and_sign_in()
	await _test_reset_and_change()
	await _test_session_taken()
	await _test_delete()
	_test_file()
	await _test_first_sync()
	await _test_changes()
	await _test_conflict()
	await _test_in_run()
	await _test_failures()
	_restore()


func run_title() -> void:
	_kept_profile = Profile.to_data()
	await _test_account_window()
	await _test_title_conflict()
	_restore()


func _use_fake() -> FakeBoardBackend:
	_fake = FakeBoardBackend.new()
	Leaderboards.use_for_tests(_fake)
	Account.use_for_tests()
	CloudSave.use_for_tests()
	return _fake


func _restore() -> void:
	Account.use_for_tests()
	CloudSave.use_for_tests()
	Leaderboards.use_for_tests()
	Profile.from_data(_kept_profile)
	_fake = null


## A profile with something in it (`runs` runs, `souls` souls).
func _progress(runs: int, souls: int) -> Dictionary:
	Profile.reset()
	Profile.runs = runs
	Profile.souls = souls
	Profile.best_depth = runs
	return Profile.to_data()


func _test_data() -> void:
	var config := Account.config
	check(config != null and config.enabled and config.name_min >= 3 and config.password_min >= 8 and not config.save_name.is_empty(), "the accounts' data")
	check(config.max_bytes <= 1_000_000, "the online save fits Talo's 1 MB a request")
	var R := Account.Result
	check(Account.check_name("Kagari") == R.OK and Account.check_name("ka") == R.BAD_NAME and Account.check_name("le puits") == R.BAD_NAME and Account.check_name("kagari@mail.fr") == R.NAME_IS_EMAIL and Account.check_name("Kâgari") == R.BAD_NAME and Account.check_name("well_keeper-7.") == R.OK, "a name: letters, digits and - _ . never an email")
	check(Account.check_password("short") == R.BAD_PASSWORD and Account.check_password("long enough") == R.OK, "a password: %d characters at least" % config.password_min)
	check(Account.check_email("") == R.OK and Account.check_email("a@b.fr") == R.OK and Account.check_email("ab.fr") == R.BAD_EMAIL and Account.check_email("a@b") == R.BAD_EMAIL and Account.check_email("a@@b.fr") == R.BAD_EMAIL, "an email: none, or one that looks right")
	var words := PackedStringArray()
	for result: int in R.values():
		if result != R.OK and Account.explain(result as Account.Result).is_empty():
			words.append(R.keys()[result])
	check(words.is_empty(), "every refusal has its words (%s)" % ", ".join(words))


func _test_no_server() -> void:
	Leaderboards.use_for_tests()  # (the offline backend: no key)
	Account.use_for_tests()
	check(not Account.is_available(), "no server: no accounts")
	check(await Account.register("Kagari", "a long password", "", false) == Account.Result.NO_SERVER and not Account.is_signed_in(), "nothing made without a server")


func _test_register_and_sign_in() -> void:
	var fake := _use_fake()
	var signals := [0, 0]
	var on_in := func() -> void: signals[0] += 1
	var on_out := func() -> void: signals[1] += 1
	Account.signed_in.connect(on_in)
	Account.signed_out.connect(on_out)
	check(fake.account_calls == 0, "nothing asked before the player does")
	check(await Account.register("Kagari", "short", "", false) == Account.Result.BAD_PASSWORD and fake.account_calls == 0, "a refused password is caught before the server")
	check(await Account.register("Kagari", "a long password", "kagari@mail.fr", false) == Account.Result.OK, "an account made")
	check(Account.is_signed_in() and Account.account_name() == "Kagari" and Account.auth.email == "kagari@mail.fr" and signals[0] == 1, "made: signed in, its email known")
	check(Account.auth.player_id != OnlineSession.player_id, "its own player, not the device's")
	await Account.sign_out()
	check(not Account.is_signed_in() and signals[1] == 1 and str(fake.accounts["kagari"].token).is_empty(), "signed out here and on the server")
	check(Account.last_name == "Kagari", "its name kept to fill the form")
	check(await Account.register("kagari", "another password", "", false) == Account.Result.NAME_TAKEN, "a name taken")
	check(await Account.register("Kumo", "another password", "kagari@mail.fr", false) == Account.Result.EMAIL_TAKEN, "an email taken")
	check(await Account.sign_in("Kagari", "wrong password", false) == Account.Result.WRONG_LOGIN and not Account.is_signed_in(), "a wrong password: not signed in")
	check(await Account.sign_in("Kagari", "a long password", false) == Account.Result.OK and Account.is_signed_in() and signals[0] == 2, "signed in")
	fake.online = false
	await Account.sign_out()
	check(not Account.is_signed_in(), "signed out here even without network")
	check(await Account.sign_in("Kagari", "a long password", false) == Account.Result.OFFLINE, "no network: said so")
	fake.online = true
	Account.signed_in.disconnect(on_in)
	Account.signed_out.disconnect(on_out)


func _test_reset_and_change() -> void:
	var fake := _use_fake()
	await Account.register("Kagari", "a long password", "kagari@mail.fr", false)
	await Account.sign_out()
	check(await Account.forgot_password("nobody@mail.fr") == Account.Result.OK and fake.reset_codes.is_empty(), "an unknown email: the same answer, nothing sent")
	check(await Account.forgot_password("kagari@mail.fr") == Account.Result.OK and fake.reset_codes.has("kagari@mail.fr"), "a reset code emailed")
	check(await Account.reset_password("000000", "a new password") == Account.Result.WRONG_CODE, "a wrong code refused")
	check(await Account.reset_password("12", "a new password") == Account.Result.WRONG_CODE and fake.account_calls > 0, "a code of the wrong length caught before the server")
	check(await Account.reset_password(fake.reset_codes["kagari@mail.fr"], "a new password") == Account.Result.OK, "the password reset with the code")
	check(await Account.sign_in("Kagari", "a new password", false) == Account.Result.OK, "signed in with the new one")
	check(await Account.change_password("wrong password", "a third password") == Account.Result.WRONG_LOGIN, "changing: the current one checked")
	check(await Account.change_password("a new password", "a new password") == Account.Result.SAME_PASSWORD, "changing: a different one needed")
	check(await Account.change_password("a new password", "a third password") == Account.Result.OK and fake.accounts["kagari"].password == "a third password", "the password changed")


func _test_session_taken() -> void:
	var fake := _use_fake()
	await Account.register("Kagari", "a long password", "", false)
	await fake.account_login("Kagari", "a long password")  # (another device signs in)
	await CloudSave.sync()
	check(not Account.is_signed_in() and Account.session_ended and Account.explain(Account.Result.SESSION_ENDED) != "", "the session taken elsewhere: signed out here, asked to sign in again")
	await Account.sign_in("Kagari", "a long password", true)
	check(Account.stay_signed_in and Account.is_signed_in(), "Stay signed in")
	await fake.account_login("Kagari", "a long password")
	await CloudSave.sync()
	await _frames(10)
	check(Account.is_signed_in() and fake.accounts["kagari"].token == Account.auth.token, "with Stay signed in: signed in again by itself")
	Account.set_stay_signed_in(false)
	check(Account._password.is_empty(), "Stay signed in off: the password forgotten")
	fake.accounts["kagari"].password = "changed elsewhere"
	Account.set_stay_signed_in(true)
	Account._password = "a long password"
	await fake.account_login("Kagari", "changed elsewhere")
	await CloudSave.sync()
	check(not Account.is_signed_in() and Account._password.is_empty(), "the kept password no longer right: signed out, forgotten")


func _test_delete() -> void:
	var fake := _use_fake()
	_progress(3, 40)
	await Account.register("Kagari", "a long password", "", false)
	await _frames(2)
	check(not fake.online_profile("Kagari").is_empty(), "its online save exists")
	var deleted := [false]
	var on_deleted := func() -> void: deleted[0] = true
	Account.deleted.connect(on_deleted)
	check(await Account.delete_account("wrong password") == Account.Result.WRONG_PASSWORD and Account.is_signed_in() and not fake.online_profile("Kagari").is_empty(), "a wrong password deletes nothing")
	check(await Account.delete_account("a long password") == Account.Result.OK, "deleted")
	Account.deleted.disconnect(on_deleted)
	check(not Account.is_signed_in() and deleted[0] and fake.accounts["kagari"].deleted and fake.online_profile("Kagari").is_empty() and fake.saves_by_player[fake.accounts["kagari"].player].is_empty(), "its online save gone first, then the account; signed out")
	check(Profile.runs == 3 and Profile.souls == 40, "the profile on this device stays")
	check(CloudSave.state == CloudSave.Step.OFF and CloudSave.save_id == 0, "the online save forgotten here")


func _test_file() -> void:
	var fake := _use_fake()
	Account.path = _file
	await Account.register("Kagari", "a long password", "", false)
	var data: Variant = SafeFile.read_json(_file)
	check(data is Dictionary and (data as Dictionary).has("account") and not (data as Dictionary).has("password"), "the file: the account and its session, never the password unless kept")
	Account.set_stay_signed_in(true)
	Account._password = "a long password"
	Account.save_state()
	Account.load_state()
	check(Account.is_signed_in() and Account.account_name() == "Kagari" and Account._password == "a long password", "read back: signed in, the kept password with it")
	await Account.sign_out()
	data = SafeFile.read_json(_file)
	check(data is Dictionary and not (data as Dictionary).has("account") and not (data as Dictionary).has("password"), "signed out: neither the session nor the password left")
	Account.path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_file))
	fake.online = true


func _test_first_sync() -> void:
	var fake := _use_fake()
	_progress(5, 120)
	await Account.register("Kagari", "a long password", "", false)
	await _frames(2)
	var online := fake.online_profile("Kagari")
	check(int(online.get("rev", 0)) == 1 and int((online.get("profile", {}) as Dictionary).get("runs", 0)) == 5 and CloudSave.state == CloudSave.Step.IDLE and CloudSave.base_rev == 1, "first sign-in, nothing online: this profile goes up (rev 1)")
	check(online.has("saved_at") and online.has("platform") and online.has("version"), "with when, from what, which version")
	# A fresh device (nothing played) signs in: it takes the online profile.
	await Account.sign_out()
	CloudSave.use_for_tests()
	Profile.reset()
	var applied := [false]
	var on_applied := func() -> void: applied[0] = true
	CloudSave.applied.connect(on_applied)
	await Account.sign_in("Kagari", "a long password", false)
	await _frames(2)
	CloudSave.applied.disconnect(on_applied)
	check(Profile.runs == 5 and Profile.souls == 120 and applied[0] and CloudSave.base_rev == 1 and not CloudSave.dirty, "a fresh profile takes the online one, without asking")
	# A device with the same profile already: no question.
	await Account.sign_out()
	CloudSave.use_for_tests()
	await Account.sign_in("Kagari", "a long password", false)
	await _frames(2)
	check(CloudSave.state == CloudSave.Step.IDLE and CloudSave.base_rev == 1, "the same profile on both sides: in step, no question")


func _test_changes() -> void:
	var fake := _use_fake()
	_progress(5, 120)
	await Account.register("Kagari", "a long password", "", false)
	await _frames(2)
	Profile.souls = 200
	CloudSave.mark_dirty()
	check(CloudSave.dirty and int(fake.online_profile("Kagari").rev) == 1, "a change waits upload_delay")
	CloudSave._process(Account.config.upload_delay + 0.1)
	await _frames(2)
	var online := fake.online_profile("Kagari")
	check(int(online.rev) == 2 and int(online.profile.souls) == 200 and not CloudSave.dirty, "then goes up (rev 2)")
	# Another device sends rev 3: nothing changed here, it comes down.
	fake.put_online("Kagari", 3, _progress(9, 500))
	_progress(5, 200)
	await CloudSave.sync()
	await _frames(2)
	check(Profile.runs == 9 and Profile.souls == 500 and CloudSave.base_rev == 3, "another device's newer copy replaces this profile")
	await CloudSave.sync()
	check(int(fake.online_profile("Kagari").rev) == 3, "in step: nothing sent")


func _test_conflict() -> void:
	var fake := _use_fake()
	_progress(5, 120)
	await Account.register("Kagari", "a long password", "", false)
	await _frames(2)
	fake.put_online("Kagari", 2, _progress(8, 300))
	_progress(6, 150)
	CloudSave.mark_dirty()
	var asked := [0]
	var on_conflict := func() -> void: asked[0] += 1
	CloudSave.conflict_found.connect(on_conflict)
	await CloudSave.sync()
	check(CloudSave.state == CloudSave.Step.CONFLICT and asked[0] == 1, "both changed: the player is asked")
	var mine := CloudSave.local_summary()
	var theirs := CloudSave.online_summary()
	check(int(mine.runs) == 6 and int(theirs.runs) == 8 and int(theirs.souls) == 300 and str(theirs.platform) == "Windows" and int(theirs.saved_at) > 0, "both summarised (runs, souls, when, from what)")
	CloudSave._process(Account.config.upload_delay + 1.0)
	await CloudSave.sync()
	check(CloudSave.state == CloudSave.Step.CONFLICT and int(fake.online_profile("Kagari").rev) == 2, "nothing sent while the player hasn't chosen")
	await CloudSave.keep_this_device()
	var online := fake.online_profile("Kagari")
	check(int(online.rev) == 3 and int(online.profile.runs) == 6 and CloudSave.state == CloudSave.Step.IDLE, "kept this device's: it goes up over the online one")
	fake.put_online("Kagari", 4, _progress(10, 700))
	_progress(6, 160)
	CloudSave.mark_dirty()
	await CloudSave.sync()
	check(CloudSave.state == CloudSave.Step.CONFLICT and asked[0] == 2, "asked again")
	CloudSave.take_online()
	check(Profile.runs == 10 and Profile.souls == 700 and CloudSave.base_rev == 4 and not CloudSave.dirty, "took the online one: it replaces this profile")
	CloudSave.conflict_found.disconnect(on_conflict)
	# A first sign-in with progress on both sides that differs: asked too.
	await Account.sign_out()
	CloudSave.use_for_tests()
	_progress(2, 10)
	await Account.sign_in("Kagari", "a long password", false)
	await _frames(2)
	check(CloudSave.state == CloudSave.Step.CONFLICT, "a first sign-in with two different progressions: asked")


func _test_in_run() -> void:
	var fake := _use_fake()
	_progress(5, 120)
	await Account.register("Kagari", "a long password", "", false)
	await _frames(2)
	CloudSave.in_run = true
	fake.put_online("Kagari", 2, _progress(9, 999))
	_progress(5, 120)
	await CloudSave.sync()
	check(CloudSave.state == CloudSave.Step.WAITING and Profile.souls == 120, "in a run: the online copy waits, the profile untouched")
	CloudSave._out_of_run()
	check(Profile.souls == 999 and CloudSave.state == CloudSave.Step.IDLE and not CloudSave.in_run, "back in the menus: it comes down")


func _test_failures() -> void:
	var fake := _use_fake()
	_progress(5, 120)
	await Account.register("Kagari", "a long password", "", false)
	await _frames(2)
	fake.online = false
	Profile.souls = 130
	CloudSave.mark_dirty()
	await CloudSave.sync()
	check(CloudSave.state == CloudSave.Step.OFFLINE and CloudSave.dirty and CloudSave.store.is_retrying(), "no network: said so, tried again later, the change kept")
	fake.online = true
	await CloudSave.sync()
	check(CloudSave.state == CloudSave.Step.IDLE and int(fake.online_profile("Kagari").profile.souls) == 130, "the network back: sent")
	fake.saves_refused = true
	Profile.souls = 140
	CloudSave.mark_dirty()
	await CloudSave.sync()
	check(CloudSave.state == CloudSave.Step.REFUSED and CloudSave.dirty, "refused (the key's scope): said so, kept")
	fake.saves_refused = false
	var kept_max := Account.config.max_bytes
	Account.config.max_bytes = 100
	await CloudSave.sync()
	check(CloudSave.state == CloudSave.Step.TOO_BIG and int(fake.online_profile("Kagari").profile.souls) == 130, "too big: not sent, said so")
	Account.config.max_bytes = kept_max
	# Another account: what was known of the first one's save is not used for it.
	await Account.register("Kumo", "a long password", "", false)
	await _frames(2)
	check(CloudSave.account_player == Account.auth.player_id and int(fake.online_profile("Kumo").get("rev", 0)) == 1 and int(fake.online_profile("Kagari").profile.souls) == 130, "another account: its own save from rev 1")


## Options > Privacy > Account: the window's pages in French on three screens, an account made
## through the form (a refusal said under it), its page, signing out, Back.
func _test_account_window() -> void:
	var fake := _use_fake()
	Settings.language = "fr"
	Settings.apply()
	var before := get_tree().root.size
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(3)
	var options := title.get_node("%OptionsPanel") as OptionsPanel
	options.open()
	options.show_tab(OptionsPanel.Tab.PRIVACY)
	await _frames(2)
	var open := options.get_node_or_null("%AccountButton") as Button
	check(open != null and open.is_visible_in_tree(), "account: Options > Privacy has its button")
	check((options.get_node("%AccountStateText") as Label).text.contains("Pas connecté"), "account: not signed in, said so")
	open.pressed.emit()
	await _frames(2)
	var dialog := options.get_node("%AccountDialog") as AccountDialog
	check(dialog.visible and dialog.page == AccountDialog.Page.CHOOSE and fake.account_calls == 0, "account: the window opens on what an account is, nothing sent")
	(dialog.get_node("%CreateButton") as Button).pressed.emit()
	await _frames(2)
	check(dialog.page == AccountDialog.Page.CREATE, "account: Create an account")
	(dialog.get_node("%AccountName") as LineEdit).text = "kagari@mail.fr"
	await dialog._create()
	check((dialog.get_node("%AccountProblem") as Label).text.contains("e-mail") and not Account.is_signed_in(), "account: a refusal said under the form, in French")
	for screen: Vector2i in [Vector2i(2340, 1080), Vector2i(2548, 1296), Vector2i(1280, 720)]:
		get_tree().root.size = screen
		await _frames(3)
		var visible_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(1.0)
		check(visible_rect.encloses(dialog.board_rect()), "account: the form fits %s in French (%s)" % [screen, dialog.board_rect()])
	check(_off_grid_texts(dialog).is_empty(), "account: the window's texts are on the font's grid")
	(dialog.get_node("%AccountName") as LineEdit).text = "Kagari"
	(dialog.get_node("%AccountPassword") as LineEdit).text = "a long password"
	await dialog._create()
	await _frames(2)
	check(Account.is_signed_in() and dialog.page == AccountDialog.Page.ACCOUNT and (dialog.get_node("%AccountText") as Label).text.contains("Kagari"), "account: made through the form, its page shown")
	check((dialog.get_node("%SaveState") as Label).text.contains("Sauvegardé en ligne"), "account: the online save's state (%s)" % (dialog.get_node("%SaveState") as Label).text)
	for screen: Vector2i in [Vector2i(2340, 1080), Vector2i(1280, 720)]:
		get_tree().root.size = screen
		await _frames(3)
		check(Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(1.0).encloses(dialog.board_rect()), "account: its page fits %s" % screen)
	(dialog.get_node("%SignOutButton") as Button).pressed.emit()
	await _frames(3)
	check(not Account.is_signed_in() and dialog.page == AccountDialog.Page.CHOOSE, "account: signed out from its page")
	dialog.back()
	check(not dialog.visible, "account: Back closes it")
	get_tree().root.size = before
	options.close()
	title.queue_free()
	await _frames(2)
	Settings.language = "en"
	Settings.apply()


## A conflict found while on the title: the question there, both sides, no Back out; a choice
## made.
func _test_title_conflict() -> void:
	var fake := _use_fake()
	_progress(4, 50)
	await Account.register("Kagari", "a long password", "", false)
	await _frames(2)
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(3)
	fake.put_online("Kagari", 3, _progress(20, 800))
	_progress(5, 60)
	CloudSave.mark_dirty()
	await CloudSave.sync()
	await _frames(2)
	check(title.cloud_conflict.visible, "conflict: asked on the title")
	check((title.cloud_conflict.get_node("%OnlineSummary") as Label).text.contains("800") and (title.cloud_conflict.get_node("%DeviceSummary") as Label).text.contains("60"), "conflict: both sides summarised")
	check(title.back() and title.cloud_conflict.visible, "conflict: Back doesn't skip the choice")
	(title.cloud_conflict.get_node("%TakeOnlineButton") as Button).pressed.emit()
	await _frames(2)
	check(not title.cloud_conflict.visible and Profile.souls == 800 and CloudSave.state == CloudSave.Step.IDLE, "conflict: the online one taken")
	title.queue_free()
	await _frames(2)
