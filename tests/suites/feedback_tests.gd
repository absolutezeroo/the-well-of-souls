class_name FeedbackTests
extends TestSuite
## "Send feedback" (the Feedback autoload, FeedbackDialog) on a fake server (FakeBoardBackend):
## never the network. run_unit(): the data, nothing sent without an online service, the queue kept
## offline (and in its file) and sent when the network is back, a refused message dropped, the
## game's details only when ticked (the run's when given), the pseudonym only when ticked, the
## delay between two messages, the length limits, the device's id made without publishing
## anything, deleting one's data, the log's folders hidden. run_title(): the title's button and
## the form in French on a phone, a large PC screen and 1280x720, the thank-you note, and the pause
## menu's button reached and pressed with a gamepad.

## Per test process (worktrees and parallel runs share one user:// folder).
var _file := "user://test_feedback_%d.json" % OS.get_process_id()
const FeedbackScript := preload("res://src/autoload/feedback.gd")

var _fake: FakeBoardBackend


func run_unit() -> void:
	_test_data()
	_test_unavailable()
	await _test_offline_queue()
	await _test_refused()
	await _test_details()
	await _test_signed()
	await _test_rate_limit()
	await _test_lengths()
	await _test_identity_and_forget()
	_test_scrub()
	_restore()


func run_title() -> void:
	await _test_title_form()
	await _test_pause_gamepad()
	_restore()


func _use_fake() -> FakeBoardBackend:
	_fake = FakeBoardBackend.new()
	Leaderboards.use_for_tests(_fake)
	Privacy.use_for_tests()
	Feedback.use_for_tests()
	OnlineSession.fake_now = 100000
	return _fake


func _restore() -> void:
	Leaderboards.use_for_tests()
	Privacy.use_for_tests()
	Feedback.use_for_tests()
	_fake = null


## A dialog in the tree, opened, with `words` typed (removed by the caller).
func _form(words: String) -> FeedbackDialog:
	var dialog := FeedbackDialog.new()
	add_child(dialog)
	dialog.open()
	dialog.set_text(words)
	return dialog


func _test_data() -> void:
	var config := Feedback.config
	check(config != null and config.categories.size() >= 3, "feedback: the data has its categories")
	var ids := {}
	var names := {}
	for def in config.categories:
		ids[def.id] = true
		names[def.internal_name] = true
		check(not def.internal_name.is_empty() and def.internal_name == def.internal_name.to_lower(), "feedback: %s has a lower-case Talo internal name" % def.id)
		check(not def.display_name.is_empty() and not def.hint.is_empty(), "feedback: %s has its button and its hint" % def.id)
	check(ids.size() == config.categories.size() and names.size() == config.categories.size(), "feedback: ids and internal names are unique")
	check(config.category(&"bug") != null and config.category(&"idea") != null and config.category(&"other") != null, "feedback: Bug, Idea and Other exist")
	check(config.max_length <= 5000 and config.min_length >= 1, "feedback: the length limits are inside Talo's (5000)")


func _test_unavailable() -> void:
	Leaderboards.use_for_tests()  # (offline: no key)
	Feedback.use_for_tests()
	check(Feedback.submit(&"bug", "The door won't open.", {}, false) == FeedbackScript.Result.UNAVAILABLE, "feedback: without an online service nothing is taken")
	check(Feedback.queue.is_empty(), "feedback: ... and nothing waits")
	var dialog := _form("The door won't open.")
	check((dialog.get_node("%SendButton") as Button).disabled, "feedback: Send is off without an online service")
	check(not (dialog.get_node("%Problem") as Label).text.is_empty(), "feedback: the form says why")
	dialog.free()


func _test_offline_queue() -> void:
	var fake := _use_fake()
	fake.online = false
	Feedback.path = _file
	var result := Feedback.submit(&"bug", "  The lantern went out on floor 3.  ", {}, false)
	await _frames(2)
	check(result == FeedbackScript.Result.QUEUED, "feedback: a message is taken offline")
	check(Feedback.queue.size() == 1 and fake.feedback.is_empty(), "feedback: offline, it waits")
	check(Feedback.store.is_retrying(), "feedback: offline, another try is planned")
	Feedback.load_state()
	check(Feedback.queue.size() == 1 and str(Feedback.queue[0].comment) == "The lantern went out on floor 3.", "feedback: what waits is kept in its file, trimmed")
	check(Feedback.last_at == 100000, "feedback: the time of the last message is kept in the file too")
	fake.online = true
	await Feedback.flush()
	check(fake.feedback.size() == 1 and str(fake.feedback[0].category) == "bug", "feedback: sent once the network is back, to its category")
	check(Feedback.queue.is_empty(), "feedback: ... and no longer waits")
	await Feedback.flush()
	check(fake.feedback.size() == 1, "feedback: never sent twice")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_file))
	Feedback.path = ""


func _test_refused() -> void:
	var fake := _use_fake()
	fake.feedback_categories = PackedStringArray(["idea"])  # (no "bug" in the dashboard)
	Feedback.submit(&"bug", "A bug the server has no category for.", {}, false)
	await _frames(3)
	check(Feedback.queue.is_empty() and fake.feedback.is_empty(), "feedback: a message the server refuses for good is dropped, not retried")


func _test_details() -> void:
	var fake := _use_fake()
	var dialog := _form("The boss got stuck in a wall.")
	(dialog.get_node("%InfoSwitch") as CheckButton).button_pressed = false
	check(not (dialog.get_node("%InfoText") as Label).text.contains("version"), "feedback: unticked, the form says only the words go")
	dialog.send()
	await _frames(3)
	check(fake.feedback.size() == 1 and (fake.feedback[0].props as Dictionary).is_empty(), "feedback: unticked, no game info goes (%s)" % [fake.feedback[0].props if not fake.feedback.is_empty() else {}])
	check(not dialog.visible, "feedback: sent, the form closes")
	OnlineSession.fake_now += Feedback.config.min_seconds_between
	dialog.run_info = func() -> Dictionary: return { "depth": "7", "weapon": "katana" }
	dialog.open()
	check((dialog.get_node("%InfoSwitch") as CheckButton).button_pressed, "feedback: the game info is ticked by default")
	check((dialog.get_node("%InfoText") as Label).text.contains("this run"), "feedback: in a run, the form says the run goes too")
	dialog.set_text("The boss got stuck in a wall again.")
	dialog.send()
	await _frames(3)
	var props: Dictionary = fake.feedback[1].props if fake.feedback.size() > 1 else {}
	for key in ["v", "build", "os", "input", "lang", "depth", "weapon"]:
		check(props.has(key), "feedback: ticked, the game info has %s" % key)
	check(str(props.get("depth", "")) == "7", "feedback: the run's details are the ones the game gave")
	check(not props.has(TaloBackend.NAME_PROP), "feedback: the game info never holds the pseudonym")
	for key: String in props:
		check(str(props[key]).length() <= 512 and key.length() <= 128, "feedback: %s is inside Talo's limits" % key)
	dialog.free()
	_free_toasts()


func _test_signed() -> void:
	var fake := _use_fake()
	Leaderboards.pseudonym = "Ashen"
	var dialog := _form("A thought from the deep.")
	var signing := dialog.get_node("%SignSwitch") as CheckButton
	check(signing.visible and not signing.button_pressed, "feedback: with a pseudonym, signing is offered, unticked")
	check(signing.text.contains("Ashen#" + Leaderboards.tag()), "feedback: the switch names the pseudonym with its tag (%s)" % signing.text)
	dialog.send()
	await _frames(3)
	check(fake.feedback.size() == 1 and not (fake.feedback[0].props as Dictionary).has(TaloBackend.NAME_PROP), "feedback: unsigned, no pseudonym goes")
	OnlineSession.fake_now += Feedback.config.min_seconds_between
	dialog.open()
	dialog.set_text("Signed this time.")
	(dialog.get_node("%SignSwitch") as CheckButton).button_pressed = true
	dialog.send()
	await _frames(3)
	check(fake.feedback.size() == 2 and str((fake.feedback[1].props as Dictionary).get(TaloBackend.NAME_PROP, "")) == "Ashen#" + PlayerName.tag_of(OnlineSession.device_id), "feedback: signed, the pseudonym goes with its tag (which Ashen wrote)")
	Leaderboards.pseudonym = ""
	dialog.open()
	check(not (dialog.get_node("%SignSwitch") as CheckButton).visible, "feedback: without a pseudonym, no signing")
	OnlineSession.fake_now += Feedback.config.min_seconds_between
	Feedback.submit(&"other", "No name to sign with.", { TaloBackend.NAME_PROP: "Smuggled" }, true)
	await _frames(3)
	check(fake.feedback.size() == 3 and not (fake.feedback[2].props as Dictionary).has(TaloBackend.NAME_PROP), "feedback: no name goes without a pseudonym, nor one slipped into the details")
	dialog.free()
	_free_toasts()


func _test_rate_limit() -> void:
	var fake := _use_fake()
	check(Feedback.submit(&"idea", "More bells.", {}, false) == FeedbackScript.Result.QUEUED, "feedback: a first message goes")
	check(Feedback.submit(&"idea", "Even more bells.", {}, false) == FeedbackScript.Result.TOO_SOON, "feedback: a second one at once is refused")
	check(Feedback.seconds_to_wait() == Feedback.config.min_seconds_between, "feedback: the form can say how long to wait")
	var dialog := _form("Even more bells.")
	check(dialog.send() == FeedbackScript.Result.TOO_SOON and dialog.visible, "feedback: the form stays open when it is too soon")
	check((dialog.get_node("%Problem") as Label).text.contains(str(Feedback.config.min_seconds_between)), "feedback: ... and says how long")
	dialog.free()
	OnlineSession.fake_now += Feedback.config.min_seconds_between
	check(Feedback.submit(&"idea", "Even more bells.", {}, false) == FeedbackScript.Result.QUEUED, "feedback: after the delay, another goes")
	await _frames(3)
	check(fake.feedback.size() == 2, "feedback: both were sent")


func _test_lengths() -> void:
	_use_fake()
	var config := Feedback.config
	check(Feedback.submit(&"bug", "   ", {}, false) == FeedbackScript.Result.EMPTY, "feedback: nothing written is refused")
	check(Feedback.submit(&"bug", "ok", {}, false) == FeedbackScript.Result.TOO_SHORT, "feedback: too short is refused")
	check(Feedback.submit(&"bug", "x".repeat(config.max_length + 1), {}, false) == FeedbackScript.Result.TOO_LONG, "feedback: too long is refused")
	check(Feedback.submit(&"nothing", "A good long message.", {}, false) == FeedbackScript.Result.UNKNOWN_CATEGORY, "feedback: an unknown category is refused")
	check(Feedback.queue.is_empty() and Feedback.last_at == 0, "feedback: a refused message neither waits nor starts the delay")
	var dialog := _form("y".repeat(config.max_length + 200))
	check((dialog.get_node("%Text") as TextEdit).text.length() == config.max_length, "feedback: the form stops typing at the limit")
	check((dialog.get_node("%Counter") as Label).text == "%d / %d" % [config.max_length, config.max_length], "feedback: the counter says it is full")
	check(dialog.send() == FeedbackScript.Result.QUEUED, "feedback: exactly at the limit goes")
	await _frames(3)
	dialog.free()
	_free_toasts()


func _test_identity_and_forget() -> void:
	var fake := _use_fake()
	check(OnlineSession.device_id.is_empty(), "feedback: (no online id before)")
	Feedback.submit(&"other", "Hello from the deep.", {}, false)
	await _frames(3)
	check(not OnlineSession.device_id.is_empty() and fake.feedback.size() == 1 and int(fake.feedback[0].alias) > 0, "feedback: sent as the device's random player (made then)")
	check(not Leaderboards.shown and fake.sent.is_empty() and fake.names.is_empty(), "feedback: sending one publishes nothing on the leaderboards")
	fake.online = false
	OnlineSession.fake_now += Feedback.config.min_seconds_between
	Feedback.submit(&"other", "Waiting for the network.", {}, false)
	await _frames(2)
	Privacy.forget_online()
	check(Feedback.queue.is_empty(), "feedback: deleting one's online data drops what waits")


func _test_scrub() -> void:
	var folder := OS.get_user_data_dir()
	var line := FeedbackInfo.scrub("ERROR: cannot open %s/run.json" % folder)
	check(not line.contains(folder) and line.contains("~/run.json"), "feedback: the log's lines hide the player's folders (%s)" % line)
	check(FeedbackInfo.clean({ "a": "x".repeat(900), "b": "" }).get("a", "").length() <= 512 and not FeedbackInfo.clean({ "b": "" }).has("b"), "feedback: values are cut to Talo's limit, empty ones left out")


## The title's button, and the form in French on a phone, a large PC screen and 1280x720.
func _test_title_form() -> void:
	_use_fake()
	Leaderboards.pseudonym = "Wwwwwwwwwwwwwwww"
	Settings.language = "fr"
	Settings.apply()
	var before := get_tree().root.size
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(3)
	var button := title.get_node("%FeedbackButton") as Button
	check(button != null and button.is_visible_in_tree(), "feedback: the title has its button")
	button.pressed.emit()
	await _frames(2)
	check(title.feedback.visible, "feedback: the title's button opens the form")
	title.feedback.set_text("Un bug, ici.")
	for screen: Vector2i in [Vector2i(2340, 1080), Vector2i(2548, 1296), Vector2i(1280, 720), Vector2i(1024, 768)]:
		get_tree().root.size = screen
		await _frames(3)
		var visible_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(1.0)
		check(visible_rect.encloses(title.feedback.board_rect()), "feedback: the form fits %s in French (%s)" % [screen, title.feedback.board_rect()])
		check(visible_rect.encloses((title.get_node("%FeedbackButton") as Control).get_global_rect()), "feedback: the title's button is on screen at %s" % screen)
	check(_off_grid_texts(title.feedback).is_empty(), "feedback: the form's texts are on the font's grid")
	check(title.back() and not title.feedback.visible, "feedback: Back closes the form")
	title.feedback.open()
	title.feedback.set_text("Un message envoyé.")
	title.feedback.send()
	await _frames(2)
	var toasts := get_tree().get_nodes_in_group(FeedbackDialog.TOAST_GROUP)
	check(toasts.size() == 1, "feedback: sent, a note thanks the player")
	if toasts.size() == 1:
		check(_off_grid_texts(toasts[0]).is_empty(), "feedback: the note's texts are on the font's grid")
		var labels := (toasts[0] as Node).find_children("*", "Label", true, false)
		check(labels.size() == 2 and (labels[0] as Label).text.begins_with("Merci"), "feedback: the note is in French, in the Well's voice")
	await _frames(roundi((FeedbackDialog.TOAST_SECONDS + 1.0) * 60.0))
	check(get_tree().get_nodes_in_group(FeedbackDialog.TOAST_GROUP).is_empty(), "feedback: the note goes away by itself")
	_free_toasts()
	title.queue_free()
	Leaderboards.pseudonym = ""
	Settings.language = "en"
	Settings.apply()
	get_tree().root.size = before
	await _frames(2)


## In a run: the pause menu's button, reached with a gamepad's D-pad and pressed with A; B closes
## the form and gives the focus back to the button.
func _test_pause_gamepad() -> void:
	_use_fake()
	var game: Game = GAME_SCENE.instantiate()
	game.show_act_cards = false
	add_child(game)
	await _frames(10)
	game.open_pause_menu()
	await _frames(2)
	var pause := game.pause_menu
	var button := pause.get_node("%FeedbackButton") as Button
	check(button != null and button.is_visible_in_tree(), "feedback: the pause menu has its button")
	InputDevice.use(InputDevice.Kind.GAMEPAD, &"xbox")
	InputDevice.navigating = true
	await _frames(2)
	if get_viewport().gui_get_focus_owner() == null:
		MenuNav.focus_first(MenuNav.top_menu())
	for i in 8:
		if get_viewport().gui_get_focus_owner() == button:
			break
		await _tap_pad(JOY_BUTTON_DPAD_DOWN)
	check(get_viewport().gui_get_focus_owner() == button, "feedback: the D-pad reaches the pause menu's button")
	await _tap_pad(JOY_BUTTON_A)
	await _frames(2)
	check(pause.feedback.visible, "feedback: A opens the form")
	var focus := get_viewport().gui_get_focus_owner()
	check(focus != null and pause.feedback.is_ancestor_of(focus), "feedback: the gamepad's focus is in the form")
	var info := FeedbackInfo.run(game.run, game.player, game.content, game.world.biome)
	check(info.has("depth") and info.has("act") and info.has("diff") and info.has("weapon") and info.has("time"), "feedback: the run's details are there (%s)" % [info.keys()])
	await _tap_pad(JOY_BUTTON_B)
	await _frames(2)
	check(not pause.feedback.visible and pause.visible, "feedback: B closes the form, the pause stays")
	check(get_viewport().gui_get_focus_owner() == button, "feedback: the focus goes back to the button")
	InputDevice.use(InputDevice.Kind.TOUCH)
	game.queue_free()
	get_tree().paused = false
	await _frames(2)


## The thank-you notes still showing, gone (they would sit over the next tests' taps).
func _free_toasts() -> void:
	for node in get_tree().get_nodes_in_group(FeedbackDialog.TOAST_GROUP):
		node.free()


func _pad_button(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap_pad(button: JoyButton) -> void:
	_pad_button(button, true)
	await _frames(1)
	_pad_button(button, false)
	await _frames(1)
