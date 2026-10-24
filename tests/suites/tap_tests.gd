class_name TapTests
extends TestSuite
## "Tap or press to continue", read the one way (TapGate) on every screen that waits for it: the
## act and curse cards, a fragment of the past, a cinematic, the story and someone speaking. The
## mouse wheel never skips (its steps come as pressed buttons), one touch is one action (a phone
## sends the touch and the click it makes of it), and the tap that closes a panel never reaches
## the HUD's touch buttons under it. Run by the title suite.

var _layer: CanvasLayer


func run_title() -> void:
	_test_gate()
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	await _test_act_card()
	await _test_curse_card()
	await _test_fragment()
	await _test_cinematic()
	await _test_story()
	await _test_dialogue()
	await _test_hint_box()
	_layer.queue_free()
	await _frames(1)


## The gate on its own, with events made by hand.
func _test_gate() -> void:
	var gate := TapGate.new()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	check(gate.read(wheel) == TapGate.IGNORE and not TapGate.is_press(wheel), "TapGate: a wheel step is no press")
	var click := _click_event(true)
	click.device = InputEvent.DEVICE_ID_EMULATION
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	check(gate.read(click) == TapGate.TAKE and gate.read(touch) == TapGate.SWALLOW, "TapGate: a touch and the click made of it are one press")
	var click_up := _click_event(false)
	click_up.device = InputEvent.DEVICE_ID_EMULATION
	var touch_up := InputEventScreenTouch.new()
	check(gate.read(click_up) == TapGate.SWALLOW and gate.read(touch_up) == TapGate.SWALLOW and gate.read(touch_up) == TapGate.IGNORE, "TapGate: the finger's release is swallowed too, once")
	var echo := InputEventKey.new()
	echo.keycode = KEY_A
	echo.pressed = true
	echo.echo = true
	check(not TapGate.is_press(echo), "TapGate: a key's echo is no press")
	var accept_only := TapGate.new(TapGate.Keys.ACCEPT)
	var letter := InputEventKey.new()
	letter.keycode = KEY_A
	letter.pressed = true
	check(accept_only.read(letter) == TapGate.IGNORE, "TapGate ACCEPT: a key that is not accept is no press")
	var hidden := TapGate.new()
	check(hidden.read(click, false) == TapGate.IGNORE, "TapGate: a hidden screen takes nothing")
	var graced := TapGate.new(TapGate.Keys.ANY, 600)
	graced.open()
	check(graced.read(_click_event(true)) == TapGate.IGNORE, "TapGate: nothing is taken in the grace after open()")


func _test_act_card() -> void:
	var card := (load("res://src/ui/act_card/act_card.tscn") as PackedScene).instantiate() as ActCard
	var under := _touch_button()
	_layer.add_child(card)
	var ended := [false]
	card.finished.connect(func() -> void: ended[0] = true)
	card.play(CONTENT.dungeon.acts[0])
	await _frames(int(ActCard.FADE_TIME * 60.0) + 4)
	_wheel(card.get_global_rect().get_center())
	await _frames(int(ActCard.FADE_TIME * 60.0) + 8)
	check(card.visible and not ended[0] and is_equal_approx(card.modulate.a, 1.0), "the act card: the mouse wheel doesn't skip it")
	await _finger(card.get_global_rect().get_center())
	await _frames(int(ActCard.FADE_TIME * 60.0) + 8)
	check(ended[0] and not card.visible, "the act card: a tap skips it")
	check(under.get_meta(&"presses", 0) == 0, "...and the tap reaches no touch button under it")
	card.queue_free()
	under.queue_free()
	await _frames(1)


func _test_curse_card() -> void:
	var card := (load("res://src/ui/curse_card/curse_card.tscn") as PackedScene).instantiate() as CurseCard
	var under := _touch_button()
	_layer.add_child(card)
	var ended := [false]
	card.finished.connect(func() -> void: ended[0] = true)
	card.play(CONTENT.curses[0])
	await _frames(60)
	_wheel(card.get_global_rect().get_center())
	await _frames(int(CurseCard.FADE_TIME * 60.0) + 8)
	check(card.visible and not ended[0], "the curse card: the mouse wheel doesn't skip it")
	await _finger(card.get_global_rect().get_center())
	await _frames(int(CurseCard.FADE_TIME * 60.0) + 8)
	check(ended[0] and not card.visible, "the curse card: a tap skips it")
	check(under.get_meta(&"presses", 0) == 0, "...and the tap reaches no touch button under it")
	card.queue_free()
	under.queue_free()
	await _frames(1)


func _test_fragment() -> void:
	var fragment: FragmentDef = null
	for boss in CONTENT.dungeon.acts[0].all_bosses():
		if boss.chronicle and not boss.chronicle.fragments.is_empty():
			fragment = boss.chronicle.fragments[0]
			break
	if fragment == null:
		return
	var under := _touch_button()
	var panel := FragmentPanel.new()
	_layer.add_child(panel)
	var closed := [0]
	panel.closed.connect(func() -> void: closed[0] += 1)
	panel.open(fragment, null)
	await _frames(FragmentPanel.OPEN_GRACE_FRAMES + 2)
	_wheel(panel.board_rect().get_center())
	await _frames(3)
	check(panel.visible and closed[0] == 0, "a fragment: the mouse wheel doesn't close it")
	await _finger(panel.board_rect().get_center())
	await _frames(3)
	check(not panel.visible and closed[0] == 1, "a fragment: one tap closes it, once")
	check(under.get_meta(&"presses", 0) == 0, "...and the touch that closed it never reaches the HUD's touch button under it")
	await _frames(TapGate.GAP_FRAMES + 1)
	await _finger(panel.board_rect().get_center())
	check(under.get_meta(&"presses", 0) == 1, "(the next touch, the panel closed, does reach it)")
	panel.queue_free()
	under.queue_free()
	await _frames(1)


func _test_cinematic() -> void:
	var view := CinematicView.new()
	_layer.add_child(view)
	view.show()
	var taps := [0]
	view.tapped.connect(func() -> void: taps[0] += 1)
	await _frames(2)
	_wheel(view.get_global_rect().get_center())
	await _frames(4)
	check(taps[0] == 0, "a cinematic: the mouse wheel is no tap")
	await _finger(view.get_global_rect().get_center())
	await _frames(4)
	check(taps[0] == 1, "a cinematic: one touch is one tap (%d)" % taps[0])
	_key(KEY_SPACE)
	await _frames(4)
	check(taps[0] == 2, "a cinematic: a key is a tap")
	# The chapter's title first, then the warden's words, then the lines (never the title
	# between the words and the story).
	view.begin_text("A chapter", true)
	view.set_speech("\"Words\"", UiSkin.TEXT)
	view.add_line("A line", UiSkin.TEXT)
	await _frames(1)
	var heading_row: Control = view.get("_heading_row")
	var speech: Control = view.get("_speech")
	var lines: Control = view.get("_lines")
	check(heading_row.get_index() < speech.get_index() and speech.get_index() < lines.get_index(), "a cinematic: the chapter's title, then the words, then the lines")
	view.queue_free()
	await _frames(1)


func _test_story() -> void:
	var story: StoryScreen = load("res://src/ui/story/story_screen.tscn").instantiate()
	add_child(story)
	await _frames(3)
	_wheel(story.get_global_rect().get_center())
	await _frames(3)
	check(story.page == 0 and story.is_typing(), "the story: the mouse wheel turns no page")
	await _finger(story.get_global_rect().get_center())
	await _frames(3)
	check(story.page == 0 and not story.is_typing(), "the story: one touch writes the page out, and only that (not the next page too)")
	_key(KEY_ENTER)
	await _frames(3)
	check(story.page == 1, "the story: Enter turns the page")
	story.queue_free()
	await _frames(1)


func _test_dialogue() -> void:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(holder)
	var box := DialogueBox.new(DialogueBox.Mode.PAGED, 900)
	holder.add_child(box)
	var dialogue: DialogueDef = null
	for candidate in CONTENT.narrative.dialogues:
		if candidate.id == &"vigil_shrine":
			dialogue = candidate
	if dialogue == null:
		holder.queue_free()
		return
	var spoken := Dialogues.Spoken.new()
	spoken.dialogue = dialogue
	spoken.line = dialogue.line(&"welcome")
	spoken.pages = Dialogues.pages(spoken.line)
	box.say([spoken] as Array[Dialogues.Spoken])
	await _frames(20)
	box.position = Vector2(100, 100)
	await _frames(1)
	_wheel(box.get_global_rect().get_center())
	await _frames(3)
	check(box.is_typing() and box.page_index() == 0, "someone speaking: the mouse wheel writes nothing out")
	await _finger(box.get_global_rect().get_center())
	await _frames(3)
	check(not box.is_typing() and box.page_index() == 0, "someone speaking: one touch writes the page out, and only that")
	holder.queue_free()
	await _frames(1)


## A tutorial hint: a tap on its board dismisses it once (the next hint, shown at once in its
## place, stays up under the same finger); the wheel dismisses nothing.
func _test_hint_box() -> void:
	check(CONTENT.tutorial != null and not CONTENT.tutorial.hints.is_empty(), "the tutorial has hints to show")
	if CONTENT.tutorial == null or CONTENT.tutorial.hints.is_empty():
		return
	var hint := CONTENT.tutorial.hints[0]
	var box := HintBox.new()
	_layer.add_child(box)
	var dismissed := [0]
	box.dismissed.connect(func() -> void:
		dismissed[0] += 1
		box.show_hint(hint, Rect2()))  # as the tutorial does: the next one up at once
	box.show_hint(hint, Rect2())
	await _frames(20)
	var board := box.get_child(0) as Control
	var on_board := board.get_global_rect().get_center()
	_wheel(on_board)
	await _frames(3)
	check(dismissed[0] == 0 and box.visible, "a hint: the mouse wheel doesn't dismiss it")
	await _finger(on_board)
	await _frames(3)
	check(dismissed[0] == 1 and box.visible, "a hint: one touch dismisses it once, not the next one too (%d)" % dismissed[0])
	box.queue_free()
	await _frames(1)


## A touch button covering the screen, under what is tested (as the HUD's attack button lies
## under the panels): it counts its presses in the meta "presses".
func _touch_button() -> TouchScreenButton:
	var under := CanvasLayer.new()
	under.layer = 5
	var button := TouchScreenButton.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4000, 4000)
	button.shape = shape
	button.pressed.connect(func() -> void: button.set_meta(&"presses", int(button.get_meta(&"presses", 0)) + 1))
	under.add_child(button)
	add_child(under)
	move_child(under, 0)  # before the screens, as the HUD is before the menus: they read input first
	button.tree_exited.connect(under.queue_free)
	return button


func _click_event(pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event


## A wheel step, as a mouse sends it (a press and a release of the wheel "button").
func _wheel(where: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		event.pressed = pressed
		event.position = where
		event.global_position = where
		get_viewport().push_input(event, true)


## A finger down and up, as a phone sends it: the click the engine makes of the touch first
## (device DEVICE_ID_EMULATION), then the touch, for the press and for the release. Pushed to the
## viewport at `where` (its own coordinates), so the GUI gets them where the finger is.
func _finger(where: Vector2) -> void:
	for pressed in [true, false]:
		var click := _click_event(pressed)
		click.device = InputEvent.DEVICE_ID_EMULATION
		click.position = where
		click.global_position = where
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		get_viewport().push_input(click, true)
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = pressed
		touch.position = where
		get_viewport().push_input(touch, true)
		await _frames(1)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
	InputDevice.use(InputDevice.Kind.TOUCH)
