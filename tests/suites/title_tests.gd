class_name TitleTests
extends TestSuite
## The title screen and its panels.

## The Settings autoload's script, for its static functions.
const SettingsScript := preload("res://src/autoload/settings.gd")


## Each part alone (tests/run_tests.gd runs them one by one, timed: --test=title.<name>).
func test_cases() -> Array:
	return [
		["village", func() -> void: await _part(VillageTests.new(), func(suite: VillageTests) -> void: await suite.run_title())],
		["title_screen", _test_title_screen],
		["quests_paid_by_gameplay", _test_quests_paid_by_gameplay],
		["stat_bar_color", _test_stat_bar_color],
		["touch_scroll", _test_touch_scroll],
		["slider_drag", _test_slider_drag],
		["resume_button", _test_resume_button],
		["cards_fit_when_shown_late", _test_cards_fit_when_shown_late],
		["pc", func() -> void: await _part(PcTests.new(), func(suite: PcTests) -> void: await suite.run_title())],
		["leaderboard", func() -> void: await _part(LeaderboardTests.new(), func(suite: LeaderboardTests) -> void: await suite.run_title())],
		["privacy", func() -> void: await _part(PrivacyTests.new(), func(suite: PrivacyTests) -> void: await suite.run_title())],
		["world_stats", func() -> void: await _part(WorldStatsTests.new(), func(suite: WorldStatsTests) -> void: await suite.run_title())],
		["remote_config", func() -> void: await _part(RemoteConfigTests.new(), func(suite: RemoteConfigTests) -> void: await suite.run_title())],
		["feedback", func() -> void: await _part(FeedbackTests.new(), func(suite: FeedbackTests) -> void: await suite.run_title())],
		["accounts", func() -> void: await _part(AccountTests.new(), func(suite: AccountTests) -> void: await suite.run_title())],
		["soft_keyboard", func() -> void: await _part(SoftKeyboardTests.new(), func(suite: SoftKeyboardTests) -> void: await suite.run_title())],
		["tap", func() -> void: await _part(TapTests.new(), func(suite: TapTests) -> void: await suite.run_title())],
		["dialogue", func() -> void: await _part(DialogueTests.new(), func(suite: DialogueTests) -> void: await suite.run_title())],
		["wardrobe", func() -> void: await _part(CosmeticTests.new(), func(suite: CosmeticTests) -> void: await suite.run_title())],
		["first_run", func() -> void: await _part(FirstRunTests.new(), func(suite: FirstRunTests) -> void: await suite.run_title())],
	]


## A borrowed suite's part: `suite` in the tree while `body` runs on it, then freed.
func _part(suite: TestSuite, body: Callable) -> void:
	add_child(suite)
	await body.call(suite)
	suite.free()


## A run in progress: the Resume button sits in the column like the others, its floor on a line
## of its own (a long one-line label ran past the column on phones).
## Perk cards filled while their panel was still hidden (a level-up's choice put together before
## the panel shows) measured their wrapped text with no width, one letter a line: thousands of
## pixels tall, the family boxes and the Reroll / Banish / Later buttons pushed off the screen
## (seen on PC). Built hidden, then shown, every card must fit the screen and keep its text.
func _test_cards_fit_when_shown_late() -> void:
	var panel := (load("res://src/ui/perk_choice/perk_choice_panel.tscn") as PackedScene).instantiate() as PerkChoicePanel
	get_tree().root.add_child(panel)
	panel.hide()
	var perks: Array[PerkDef] = []
	for perk in CONTENT.perks:
		if perk.synergies.size() > 0 and perks.size() < 3:
			perks.append(perk)
	panel._owned = PerkSet.new()
	panel.show_cards(perks, false)
	for i in 6:
		await get_tree().process_frame
	panel.show()
	for i in 8:
		await get_tree().process_frame
	var screen := get_tree().root.get_visible_rect().size
	var cards := panel.get_node("%Cards").get_children()
	check(cards.size() == 3, "three cards built while hidden")
	for card: Control in cards:
		check(card.size.y < screen.y * 0.8, "a card built while its panel was hidden fits the screen once shown (%d px tall)" % card.size.y)
		var inside := card.get_node("Margin") as Control
		check(card.size.y + 1.0 >= inside.get_combined_minimum_size().y, "and its text still fits inside it")
	var later := panel.get_node("%LaterButton") as Control
	check(later.get_global_rect().end.y <= screen.y, "the Later button stays on the screen")
	panel.queue_free()
	await get_tree().process_frame


func _test_resume_button() -> void:
	var file := FileAccess.open(RunSave.path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": RunSave.VERSION, "depth": 11, "player": {"level": 23}}))
	file.close()
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	await get_tree().process_frame
	var resume: Button = title.get_node("%ContinueButton")
	var play: Button = title.get_node("%PlayButton")
	var labels := resume.find_children("*", "Label", true, false)
	check(resume.visible and resume.text.is_empty() and labels.size() == 2 and (labels[1] as Label).text.contains("11"), "a run in progress: Resume, its floor on a second line")
	check(is_equal_approx(resume.size.x, play.size.x), "Resume is as wide as Descend (%d vs %d)" % [resume.size.x, play.size.x])
	title.queue_free()
	RunSave.erase()
	await get_tree().process_frame


## A bar's color set alone (the HUD's temperature blinking) shows at once, without a new value.
func _test_stat_bar_color() -> void:
	var bar := StatBar.new()
	bar.size = Vector2(120, 20)
	add_child(bar)
	bar.set_values(5, 10)
	await _frames(2)
	var draws := [0]
	bar.draw.connect(func() -> void: draws[0] += 1)
	bar.set_values(5, 10)
	await _frames(2)
	var still: int = draws[0]
	bar.fill_color = Color(0.2, 0.6, 1.0)
	await _frames(2)
	check(still == 0 and draws[0] == 1, "a stat bar redraws when only its color changes (%d, %d)" % [still, draws[0]])
	bar.queue_free()


## A quest finished in a run that ended before it was paid (a crash, an old save) is paid by
## gameplay, once, with its Events.quest_completed, when the title screen comes up; looking at
## the codex's Quests tab pays nothing (it used to pay there, silently, and only there).
func _test_quests_paid_by_gameplay() -> void:
	Profile.reset()
	var quest: Dictionary = QuestBoard.current(CONTENT.quests, QuestDef.Period.DAILY)[0]
	var def: QuestDef = quest.def
	if def.best:
		Profile.raise_stat(def.stat, quest.target)
	else:
		Profile.add_stat(def.stat, quest.target)
	var souls := Profile.souls
	var told: Array[Dictionary] = []
	var listen := func(done: Dictionary) -> void: told.append(done)
	Events.quest_completed.connect(listen)
	var codex: CodexPanel = (load("res://src/ui/codex/codex_panel.tscn") as PackedScene).instantiate()
	add_child(codex)
	codex.open(CONTENT, CodexPanel.Tab.QUESTS)
	await _frames(2)
	check(Profile.souls == souls and not QuestBoard.is_claimed(quest) and told.is_empty(), "the codex's Quests tab only shows quests: it pays nothing")
	codex.queue_free()
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(2)
	var paid := told.filter(func(q: Dictionary) -> bool: return q.def == def)
	check(QuestBoard.is_claimed(quest) and Profile.souls >= souls + int(quest.reward) and paid.size() == 1, "a quest finished and never looked at is paid when the title comes up, and told (Events.quest_completed)")
	var souls_paid := Profile.souls
	title.queue_free()
	await _frames(1)
	var again: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(again)
	await _frames(2)
	check(told.filter(func(q: Dictionary) -> bool: return q.def == def).size() == 1 and Profile.souls == souls_paid, "...once only")
	again.queue_free()
	Events.quest_completed.disconnect(listen)
	Profile.reset()
	await _frames(1)


## Dragging over a list scrolls it, even when the drag starts on a card or a button, and a
## drag doesn't press the button.
func _test_touch_scroll() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(100, 100)
	scroll.size = Vector2(300, 200)
	var list := VBoxContainer.new()
	scroll.add_child(list)
	var pressed := [0]
	for i in 30:
		var button := Button.new()
		button.custom_minimum_size = Vector2(280, 40)
		button.pressed.connect(func() -> void: pressed[0] += 1)
		list.add_child(button)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(scroll)
	await _frames(3)
	check(scroll.get_children().any(func(n: Node) -> bool: return n is TouchScroll), "lists get drag-to-scroll by themselves")
	# A list built and freed in the same frame: its drag-to-scroll, deferred, finds nothing to
	# attach to (an engine error before: "Cannot convert argument 1 from Object to Object").
	var gone := ScrollContainer.new()
	layer.add_child(gone)
	var gone_ref: WeakRef = weakref(gone)
	gone.free()
	await _frames(2)
	check(gone_ref.get_ref() == null and layer.get_child_count() == 1, "a list freed at once is let go quietly")
	# A list built with its helper already (UiParts.scroll, TouchScroll.attach) gets no second
	# one from the autoload (two used to read every event and frame twice).
	var built := UiParts.scroll()
	TouchScroll.attach(built)
	layer.add_child(built)
	await _frames(3)
	check(built.get_children().filter(func(n: Node) -> bool: return n is TouchScroll).size() == 1 and built.follow_focus, "one drag-to-scroll per list, however it was attached")
	built.free()
	var at := Vector2(200, 250)
	_mouse(at, true)
	for i in 6:
		at.y -= 15.0
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion, true)
		await _frames(1)
	_mouse(at, false)
	await _frames(2)
	check(scroll.scroll_vertical >= 60, "dragging scrolls the list (%d px)" % scroll.scroll_vertical)
	check(pressed[0] == 0, "a drag doesn't press the button under the finger")
	await _frames(2)
	check(list.get_children().all(func(b: Node) -> bool: return (b as Button).get_draw_mode() != BaseButton.DRAW_PRESSED), "...nor leaves it looking pressed")
	layer.queue_free()


## A slider in a list that scrolls, dragged by a finger that wanders up and down: the value
## follows the finger all the way (before it lets go), the list never scrolls; a tap on the track
## jumps there; keys still step.
func _test_slider_drag() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(100, 100)
	scroll.size = Vector2(300, 200)
	var list := VBoxContainer.new()
	scroll.add_child(list)
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(280, 48)
	list.add_child(slider)
	for i in 30:
		var button := Button.new()
		button.custom_minimum_size = Vector2(280, 40)
		list.add_child(button)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(scroll)
	await _frames(3)
	var rect := slider.get_global_rect()
	var at := Vector2(rect.position.x + 4.0, rect.get_center().y)
	_mouse(at, true)
	await _frames(1)
	var values: Array[float] = [slider.value]
	var wander := [-18.0, -40.0, 10.0, -55.0, -30.0, -70.0, -45.0, -80.0, -60.0, -90.0]
	for i in wander.size():
		at = Vector2(rect.position.x + 4.0 + (rect.size.x - 8.0) * (i + 1) / wander.size(), rect.get_center().y + wander[i])
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion, true)
		await _frames(1)
		values.append(slider.value)
	var mid := values[5]
	_mouse(at, false)
	await _frames(2)
	var rising := true
	for i in range(1, values.size()):
		rising = rising and values[i] > values[i - 1]
	check(rising and mid > 0.4 and mid < 0.7, "a slider dragged sideways follows the finger at every move, before it lets go (%s)" % [values])
	check(slider.value > 0.9, "...to the end of its track (%.2f)" % slider.value)
	check(scroll.scroll_vertical == 0, "...and the list under it never scrolls, however far the finger wanders up or down (%d)" % scroll.scroll_vertical)
	# A tap on the track jumps there.
	var tap := Vector2(rect.position.x + rect.size.x * 0.25, rect.get_center().y)
	_mouse(tap, true)
	_mouse(tap, false)
	await _frames(2)
	check(absf(slider.value - 0.25) < 0.08, "a tap on a slider's track jumps there (%.2f)" % slider.value)
	# A drag on a button of the same list still scrolls it.
	at = Vector2(200, 290)
	_mouse(at, true)
	for i in 4:
		at.y -= 15.0
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion, true)
		await _frames(1)
	_mouse(at, false)
	await _frames(2)
	check(scroll.scroll_vertical > 0 and absf(slider.value - 0.25) < 0.08, "a drag started beside the slider still scrolls the list (%d)" % scroll.scroll_vertical)
	layer.queue_free()


func _mouse(at: Vector2, down: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = at
	click.pressed = down
	get_viewport().push_input(click, true)


func _test_title_screen() -> void:
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(2)
	check(title.get_node("%PlayButton").visible, "the title screen has a Play button")
	check((title.get_node("%Title") as Label).text == CONTENT.story.title and title.get_node("%StoryButton").visible, "the title screen shows the name and the story")
	check((title.get_node("%PlayButton") as Button).pressed.is_connected(title.play) and TitleScreen.VILLAGE_SCENE == VillageHub.SCENE, "Play enters the village instead of starting a run")
	(title.get_node("%DifficultyPanel") as DifficultyPanel).open(CONTENT.difficulties, CONTENT.ascensions)
	await _frames(2)
	var cards: HBoxContainer = title.get_node("%DifficultyCards")
	check(title.get_node("%DifficultyPanel").visible and cards.get_child_count() == 4, "the shared difficulty panel offers the four ordeals")
	check((cards.get_child(3) as Button).disabled and not (cards.get_child(2) as Button).disabled, "Nightmare locked, Hard open")
	check(not title.get_node("%AscensionRow").visible, "no ascension before a Nightmare win")
	Profile.ascension_unlocked = 2
	(title.get_node("%DifficultyPanel") as DifficultyPanel).open(CONTENT.difficulties, CONTENT.ascensions)
	(title.get_node("%AscensionPlus") as Button).pressed.emit()
	check(title.get_node("%AscensionRow").visible and Profile.ascension == 1 and (title.get_node("%AscensionLevel") as Label).text == "+1", "the ascension level is picked with Nightmare")
	Profile.ascension_unlocked = 0
	Profile.ascension = 0
	(title.get_node("%BackButton") as Button).pressed.emit()
	await _frames(1)
	check(not title.get_node("%DifficultyPanel").visible, "back to the title")
	(title.get_node("%DailyButton") as Button).pressed.emit()
	await _frames(2)
	check(title.daily_dialog.visible and not Game.daily_requested, "the daily run explains itself before it starts")
	check(title.daily_dialog.body.find_child("AnswerButton", true, false) != null, "...with a button to toll the knell")
	title.daily_dialog.hide()
	Profile.souls = 500
	var hints_were := Settings.tutorial_hints
	Settings.tutorial_hints = true
	Profile.hints_seen.erase("menu_shrine")
	(title.get_node("%ShrineButton") as Button).pressed.emit()
	await _frames(2)
	var shrine: ShrinePanel = title.get_node("%ShrinePanel")
	check(title.hint_box.visible and title.hint_box.shown_text().contains("Tree of Souls") or Profile.has_seen_hint(&"menu_shrine"), "the first visit explains the tree (%s)" % title.hint_box.shown_text())
	check(not title.show_menu_hint(&"menu_shrine"), "...once only")
	title.hint_box.hide_hint()
	Settings.tutorial_hints = hints_were
	var view: SoulTreeView = title.get_node("%TreeView")
	check(shrine.visible and view.buttons().size() == CONTENT.soul_tree.nodes.size(), "the shrine shows every node of the Tree of Souls")
	var vitality_node := CONTENT.soul_tree.find(&"vitality")
	view.button_of(vitality_node).pressed.emit()
	await _frames(1)
	check(shrine.picked() == vitality_node, "tapping a node picks it")
	var vow: Label = title.get_node("%OathLore")
	check(not vow.visible, "an upgrade's node has no vow")
	var colossus_node := CONTENT.soul_tree.find(&"oath_colossus")
	shrine.pick(colossus_node)
	check(vow.visible and vow.text == tr(colossus_node.oath.lore) and not vow.text.is_empty(), "an oath's node shows its vow, as a keeper of old swore it (%s)" % vow.text)
	shrine.pick(vitality_node)
	(title.get_node("%BuyButton") as Button).pressed.emit()
	await _frames(1)
	check(Profile.level_of(vitality_node.upgrade) == 1 and Profile.souls < 500, "buying at the shrine")
	check((title.get_node("%Souls") as Label).text.contains(str(Profile.souls)), "the shrine shows the souls left")
	var fork := CONTENT.soul_tree.find(&"toughness")
	shrine.pick(fork)
	check(shrine.buy_picked() and fork.partner().is_shut() and not Profile.can_buy_node(fork.partner()), "a fork: taking one side shuts the other")
	var spent := CONTENT.soul_tree.spent()
	var before := Profile.souls
	var reset_button: Button = title.get_node("%ResetButton")
	var saved_runs := Profile.runs_since_reset
	Profile.runs_since_reset = CONTENT.soul_tree.reset_runs - 2
	Profile.changed.emit()
	check(reset_button.disabled and reset_button.text == "Reset in 2 runs", "the reset waits for its runs: \"Reset in 2 runs\", disabled (%s)" % reset_button.text)
	reset_button.pressed.emit()
	await _frames(1)
	check(Profile.souls == before and CONTENT.soul_tree.spent() == spent, "...and does nothing then")
	Profile.record_run(0, 2, false, &"normal")
	await _frames(1)
	check(reset_button.disabled and reset_button.text == "Reset in 1 run", "a run later: \"Reset in 1 run\" (%s)" % reset_button.text)
	Profile.record_run(0, 2, false, &"normal")
	await _frames(1)
	check(not reset_button.disabled and reset_button.text == "Reset the tree", "the runs done: the reset is open (%s)" % reset_button.text)
	before = Profile.souls
	reset_button.pressed.emit()
	await _frames(1)
	check(Profile.souls == before + spent and CONTENT.soul_tree.spent() == 0 and not fork.partner().is_shut(), "resetting the tree gives every soul back (%d)" % spent)
	check(reset_button.disabled and reset_button.text == "Reset in %d runs" % CONTENT.soul_tree.reset_runs, "after a reset, the next one takes its runs again (%s)" % reset_button.text)
	Profile.runs_since_reset = saved_runs
	Profile.buy_node(vitality_node)
	_test_shrine_words(shrine)
	# At the Well's Edge: the oaths the tree opened, and the Armory's weapon.
	var saved_levels := Profile.levels.duplicate()
	check(not OathPanel.has_choices(CONTENT) or Profile.levels.has("armory"), "nothing to swear before the tree opens it")
	Profile.levels["oath_colossus"] = 1
	Profile.levels["armory"] = 1
	check(OathPanel.has_choices(CONTENT), "an oath bought: something to choose before a run")
	var oaths: OathPanel = title.oath_panel
	oaths.open(CONTENT)
	await _frames(1)
	var oath_cards: HBoxContainer = oaths.get_node("%OathCards")
	var order := CONTENT.soul_tree.oaths()
	# (the starting kits follow the tree's oaths, locked until their feat: progression.md "Oaths and kits")
	var locked_kits := CONTENT.kits.filter(func(k: OathDef) -> bool: return not k.is_unlocked()).size()
	check(oaths.visible and oath_cards.get_child_count() == order.size() + CONTENT.kits.size() + 1, "a card per oath and kit, and Unsworn")
	var colossus_index := order.find(CONTENT.soul_tree.find(&"oath_colossus").oath) + 1
	check(not (oath_cards.get_child(colossus_index) as Button).disabled and order.size() == 4 and oath_cards.get_children().filter(func(c: Node) -> bool: return (c as Button).disabled).size() == 3 + locked_kits, "the oath bought is open, the others locked")
	(oath_cards.get_child(colossus_index) as Button).pressed.emit()
	await _frames(1)
	check(Profile.oath == &"colossus" and Game.sworn_oath(CONTENT) != null, "tapping a card swears the oath")
	# Every card's words fit inside it, in English and in French: the row clips what spills over
	# (the window is full on a 720-line screen, the cards can't grow; a locked kit's feat, the
	# tree's branch, a name on two lines all count).
	for language in ["en", "fr"]:
		TranslationServer.set_locale(language)
		oaths.open(CONTENT)
		await _frames(2)
		var spilled: Array[String] = []
		for card: Control in oath_cards.get_children():
			var column := card.get_child(0) as Control
			var room := card.size.y - column.offset_top + column.offset_bottom
			if column.get_combined_minimum_size().y > room + 0.5:
				spilled.append("%s %d > %d" % [_texts(card)[0] if not _texts(card).is_empty() else "?", column.get_combined_minimum_size().y, room])
		check(spilled.is_empty(), "every oath and kit card's words fit inside it (%s: %s)" % [language, spilled])
	TranslationServer.set_locale("en")
	oaths.open(CONTENT)
	await _frames(1)
	var weapon_row: HBoxContainer = oaths.get_node("%WeaponRow")
	var armory: UpgradeDef = CONTENT.soul_tree.find(&"armory").upgrade
	var level_one := armory.armory_weapons.slice(0, armory.armory_count(1))
	var shown := weapon_row.get_children().map(func(slot: Node) -> ItemDef: return (slot as ItemSlot).item)
	check(weapon_row.is_visible_in_tree() and shown == level_one and OathPanel.weapons(CONTENT) == level_one, "the Armory level 1: a slot per weapon it opened, no other (%s)" % [shown.map(func(w: ItemDef) -> StringName: return w.id)])
	var armory_text: Label = oaths.get_node("%ArmoryText")
	check(armory_text.is_visible_in_tree() and armory_text.text == "Armory level 1: %d weapons. More in the Tree of Souls." % level_one.size(), "...and says its level and where to get more (%s)" % armory_text.text)
	(weapon_row.get_child(1) as ItemSlot).pressed.emit()
	await _frames(1)
	check(Profile.starting_weapon == level_one[1].id and Game.picked_weapon(CONTENT) == level_one[1] and (weapon_row.get_child(1) as ItemSlot).selected, "tapping a weapon picks it")
	Profile.levels["armory"] = 3
	oaths.open(CONTENT)
	await _frames(1)
	shown = weapon_row.get_children().map(func(slot: Node) -> ItemDef: return (slot as ItemSlot).item)
	var level_three := armory.armory_weapons.slice(0, armory.armory_count(3)).filter(func(w: WeaponDef) -> bool: return not CONTENT.locked_items.has(w))
	check(shown == level_three and shown.size() == level_one.size() + 2 * armory.armory_per_level and armory_text.text.begins_with("Armory level 3: %d weapons" % shown.size()), "the Armory level 3: two more weapons a level (%d)" % shown.size())
	check(not shown.any(func(w: ItemDef) -> bool: return CONTENT.locked_items.has(w) and not ShrineUpgrades.unlocked_items(CONTENT).has(w)), "never a weapon still locked in the dungeon")
	Profile.levels["armory"] = 1
	Profile.starting_weapon = level_three[level_three.size() - 1].id
	oaths.open(CONTENT)
	await _frames(1)
	check(Game.picked_weapon(CONTENT) == null and weapon_row.get_child_count() == level_one.size() and (weapon_row.get_child(0) as ItemSlot).selected, "a weapon the level no longer offers: the usual one, shown picked")
	# Opening the panel shows the choice and never changes it: a saved oath the tree no longer
	# opens (a reset tree) and a weapon the Armory no longer offers stay saved, read as none.
	var locked_oath: OathDef = order.filter(func(o: OathDef) -> bool: return o.id != &"colossus")[0]
	Profile.oath = locked_oath.id
	var weapon_saved := Profile.starting_weapon
	oaths.open(CONTENT)
	await _frames(1)
	check(Profile.oath == locked_oath.id and Profile.starting_weapon == weapon_saved, "opening the oath panel changes nothing saved")
	check(Game.sworn_oath(CONTENT) == null and _texts(oath_cards.get_child(0)).has("Sworn"), "...and a saved oath no longer open shows as Unsworn")
	oaths.hide()
	Profile.levels = saved_levels
	Profile.oath = &""
	Profile.starting_weapon = &""
	_test_difficulty_words()
	await _test_options_screen(title)
	# The codex: bestiary, achievements, runs.
	Profile.record_kill(&"slime")
	(title.get_node("%CodexButton") as Button).pressed.emit()
	await _frames(2)
	var codex: CodexPanel = title.get_node("%CodexPanel")
	var list: Container = codex.get_node("%List")
	var entries := codex.bestiary_entries()
	var monster_cards := codex.bestiary_cards()
	check(codex.visible and monster_cards.size() == entries.size() and monster_cards.map(func(c: CodexCard) -> MonsterDef: return c.monster) == entries, "the bestiary lists every monster and boss")
	check(entries.any(func(m: MonsterDef) -> bool: return m is BossDef), "bosses are in the bestiary")
	check(entries.size() == CONTENT.all_monsters().size() + CONTENT.abyss_monsters().size() + entries.filter(func(m: MonsterDef) -> bool: return m is BossDef).size(), "every monster once (the acts', the Deeps')")
	check(CONTENT.abyss_monsters().all(func(m: MonsterDef) -> bool: return entries.has(m)), "the Deeps' demons are in the bestiary")
	check(_texts(list).has(CONTENT.dungeon.abyss.display_name), "under their own heading")
	var slime_card := monster_cards[entries.find(load("res://data/monsters/slime.tres"))]
	var unseen := entries.filter(func(m: MonsterDef) -> bool: return Bestiary.rank_of(m, CONTENT.bestiary) == Bestiary.UNSEEN)
	check(not slime_card.disabled and monster_cards[entries.find(unseen[0])].disabled, "slain monsters open their page, unknown ones don't")
	check(_texts(slime_card).has("Known") and _texts(slime_card).has("1 slain") and _texts(monster_cards[entries.find(unseen[0])]).has("???"), "a card shows the rank and the kills (unknown ones: ???)")
	# The hidden floor's boss: after the acts and the Deeps (only the bottom of the Well's forms
	# follow it), its card and its floor's heading kept secret until met.
	var hidden_boss := CONTENT.dungeon.hidden_floor.boss
	var forms := CONTENT.dungeon.finale.all_bosses()
	var hidden_at := entries.size() - forms.size() - 1
	var list_texts := _texts(list)
	check(entries[hidden_at] == hidden_boss and monster_cards[hidden_at].disabled and _texts(monster_cards[hidden_at]).has("???"), "the hidden boss is last but the bottom's forms in the bestiary, a ??? card until met")
	check(not list_texts.any(func(line: String) -> bool: return line.contains(CONTENT.dungeon.hidden_floor.title) or line.contains(hidden_boss.display_name)), "nothing in the bestiary names the hidden floor or its boss before they are met")
	# The bottom of the Well's forms (Tôma, the Maw, then the Nameless Keeper): last, in order, ???
	# cards under a ??? heading until met.
	check(entries.slice(entries.size() - forms.size()) == forms and forms.size() == 3 and forms[2] == CONTENT.dungeon.finale.keeper, "the bottom of the Well's two forms and the Nameless Keeper close the bestiary, in order")
	for i in forms.size():
		var card := monster_cards[entries.size() - forms.size() + i]
		check(card.disabled and _texts(card).has("???"), "%s: a ??? card until met" % forms[i].id)
	check(not list_texts.any(func(line: String) -> bool: return line.contains(CONTENT.dungeon.finale.title) or forms.any(func(form: BossDef) -> bool: return line.contains(form.display_name))), "nothing in the bestiary names the bottom of the Well or its forms before they are met")
	check(Profile.bestiary_rank(&"slime") == 1, "the first kill pays the first rank")
	check((codex.get_node("%Help") as Label).text.contains("rank"), "the bestiary explains the hunter ranks")
	slime_card.pressed.emit()
	await _frames(2)
	check(codex.is_page_open() and not (codex.get_node("%Scroll") as Control).is_visible_in_tree(), "tapping a monster opens its page")
	var page_text := " ".join(_texts(codex.get_node("%MonsterPage")))
	check(page_text.contains("Health") and page_text.contains("Move speed") and page_text.contains("Mastered: slay") and page_text.contains("Celestial"), "the page explains the stats, the ranks and the Celestial")
	# Every page, every attack plays in the preview (warning, then what it does).
	for monster in entries:
		Profile.record_kill(monster.id)
		codex.open_monster(monster)
		await _frames(2)
		var buttons := _find_all(codex, func(n: Node) -> bool: return n is Button and n.toggle_mode and n.get_parent() is HFlowContainer)
		for button: Button in buttons:
			button.pressed.emit()
			await _frames(70)
		check(buttons.size() >= 1 or monster.weapon == null, "%s: its attacks are listed (%d)" % [monster.id, buttons.size()])
	var previews := _find_all(codex, func(n: Node) -> bool: return n is AttackPreview)
	check(previews.size() == 1, "one preview on the page")
	await _test_codex_fits(codex, entries)
	codex.back()
	check(not codex.is_page_open() and codex.visible, "back: from the page to the list")
	codex.back()
	check(not codex.visible, "back again: the codex closes")
	codex.open(CONTENT, CodexPanel.Tab.QUESTS)
	await _frames(1)
	var quest_text := " ".join(_texts(list))
	check((codex.get_node("%QuestsTab") as Button).button_pressed and quest_text.contains("Daily quests") and quest_text.contains("Weekly quests") and quest_text.contains("souls"), "the quests tab: daily and weekly quests and their souls")
	check(_find_all(list, func(n: Node) -> bool: return n is StatBar).size() == QuestBoard.DAILY_COUNT + QuestBoard.WEEKLY_COUNT, "a progress bar per quest")
	check((codex.get_node("%Help") as Label).text.contains("Shrine"), "the quests tab says what souls are for")
	check(codex.get_node("%QuestsTab").get_parent() is TabRow and title.leaderboards.get_node("%TollTab").get_parent() is TabRow, "the codex's and the leaderboards' tabs are TabRows, like every window's")
	codex.show_tab(CodexPanel.Tab.ACHIEVEMENTS)
	await _frames(1)
	# (then the weapons' evolutions: a line and a row each, loot.md "Weapon evolutions")
	check(list.get_child_count() == CONTENT.achievements.size() + 1 + WeaponEvolution.all(CONTENT).size() and not (codex.get_node("%QuestsTab") as Button).button_pressed, "the achievements are listed, then the evolutions")
	check(_texts(list.get_child(0)).any(func(t: String) -> bool: return t.begins_with("+") and t.ends_with("souls")), "an achievement shows its reward")
	Profile.add_history({ "depth": 3, "cause": "Skeleton", "won": false, "time": 1760000000, "duration": 600000 })
	codex.show_tab(CodexPanel.Tab.RUNS)
	await _frames(1)
	check(list.get_child_count() == 1, "the last runs are listed")
	var run_text := " ".join(_texts(list))
	check(run_text.contains("Died on floor 3") and run_text.contains("Slain by Skeleton") and run_text.contains("10:00"), "a run says how far it went, how it ended, how long it took")
	# Each fact its name over its value; a value wraps between words, never inside one.
	var split_words: Array[String] = []
	for language in ["fr", "en"]:
		TranslationServer.set_locale(language)
		codex.show_tab(CodexPanel.Tab.RUNS)
		await _frames(2)
		for label: Label in _find_all(list, func(n: Node) -> bool: return n is Label):
			if label.visible and label.get_line_count() > label.text.split(" ", false).size():
				split_words.append("%s: %s" % [language, label.text])
	TranslationServer.set_locale("en")
	codex.show_tab(CodexPanel.Tab.RUNS)
	await _frames(1)
	check(split_words.is_empty(), "no fact of a run is cut inside a word (%s)" % ", ".join(split_words))
	var records := codex.get_node("%Records") as Label
	check(not records.visible, "no win, no record")
	Profile.best_times = { "normal": 1930450, "hard/a3/bottom": 3062100, "normal/bottom": 2400000 }
	codex.show_tab(CodexPanel.Tab.RUNS)
	await _frames(1)
	var lines := records.text.split("\n")
	check(records.visible and lines.size() == 2 and lines[0].begins_with("Fastest wins:") and lines[0].contains("Keeper 32:10") and not lines[0].contains("Martyr"), "the fastest wins, without the bottom (%s)" % records.text)
	check(lines.size() == 2 and lines[1].begins_with("Fastest to the Well's Bottom:") and lines[1].contains("Martyr +3 51:02") and lines[1].contains("Keeper 40:00"), "and the runs won at the bottom on their own line")
	Profile.best_times = {}
	(codex.get_node("%BestiaryTab") as Button).pressed.emit()
	await _frames(1)
	check(codex.bestiary_cards().size() == entries.size(), "a tab button shows its tab")
	var lists := title.find_children("*", "ScrollContainer", true, false)
	check(not lists.is_empty() and lists.all(func(l: Node) -> bool: return l.get_children().filter(func(n: Node) -> bool: return n is TouchScroll).size() == 1), "every list of the title screen and its panels has one drag-to-scroll, no more")
	var off_grid := _off_grid_texts(title)
	check(off_grid.is_empty(), "every text of the title screen and its panels is on the font's grid (Fonts.SIZES, a one-pixel outline): %s" % ", ".join(off_grid.slice(0, 6)))
	title.queue_free()
	Profile.reset()
	await _frames(2)

	# The story: typed out page by page, a tap shows the whole page, the next tap the next page.
	check(not Profile.seen_intro, "the story was not told yet")
	var story_screen: StoryScreen = load("res://src/ui/story/story_screen.tscn").instantiate()
	add_child(story_screen)
	await _frames(3)
	var text: Label = story_screen.get_node("%Text")
	check(story_screen.page == 0 and story_screen.is_typing() and text.visible_ratio < 1.0, "the story types itself out")
	story_screen.advance()
	check(text.visible_ratio == 1.0 and not story_screen.is_typing(), "a tap shows the whole page")
	story_screen.advance()
	check(story_screen.page == 1 and text.text == CONTENT.story.intro_pages[1], "the next tap turns the page")
	story_screen.queue_free()
	await _frames(2)


## The shrine says each upgrade's level, what you have, what the next level adds, and why a
## Buy button is off.
func _test_shrine_words(shrine: ShrinePanel) -> void:
	var vitality: UpgradeDef = load("res://data/upgrades/vitality.tres")
	check(UpgradeRow.level_text(vitality, 2) == "Level 2 / 5", "shrine: the level out of the max")
	var status := UpgradeRow.status_text(vitality, 2)
	check(status.contains("Now: +16 max health") and status.contains("Next: +24 max health"), "shrine: now and next level (%s)" % status)
	check(UpgradeRow.status_text(vitality, 0).contains("+8 max health"), "shrine: what the first level gives")
	check(UpgradeRow.status_text(vitality, 5).contains("maxed"), "shrine: maxed")
	var unlock: UpgradeDef = load("res://data/upgrades/pyromancy.tres")
	check(UpgradeRow.level_text(unlock, 0) == "Locked" and UpgradeRow.level_text(unlock, 1) == "Unlocked", "shrine: unlocks say locked / unlocked")
	var node := CONTENT.soul_tree.find(&"vitality")
	shrine.pick(node)
	var buy: Button = shrine.get_node("%BuyButton") if shrine.has_node("%BuyButton") else shrine.owner.get_node("%BuyButton")
	var souls := Profile.souls
	Profile.souls = 0
	Profile.changed.emit()
	check(buy.disabled and buy.text.begins_with("Need"), "shrine: too few souls says how many are needed (%s)" % buy.text)
	Profile.levels[String(vitality.id)] = vitality.max_level
	Profile.changed.emit()
	check(buy.disabled and buy.text == "Maxed", "shrine: a maxed upgrade says so")
	var locked := CONTENT.soul_tree.find(&"armory")
	shrine.pick(locked)
	check(buy.disabled and buy.text == "Locked" and locked.blocker().begins_with("Needs"), "shrine: a node whose parents aren't bought says what it needs (%s)" % locked.blocker())
	Profile.levels.erase(String(vitality.id))
	Profile.souls = souls
	Profile.changed.emit()


## Each difficulty in plain words, and the ascension's twists.
func _test_difficulty_words() -> void:
	var normal: DifficultyDef = load("res://data/difficulties/normal.tres")
	var hard: DifficultyDef = load("res://data/difficulties/hard.tres")
	var easy: DifficultyDef = load("res://data/difficulties/easy.tres")
	var words := DifficultyCard.effects(hard, normal).map(func(e: Array) -> String: return e[0])
	for expected in ["Monster health +30%", "Monster damage +35%", "Time to dodge -15%", "+1 monster per room", "Monsters spot you sooner", "Bigger floors (+20%)"]:
		check(words.has(expected), "difficulty: Hard says \"%s\" (%s)" % [expected, words])
	var heal: Array = DifficultyCard.effects(easy, normal).filter(func(e: Array) -> bool: return (e[0] as String).begins_with("Heal"))
	check(heal.size() == 1 and heal[0][1] == 1, "difficulty: Easy's healing is a help")
	check(DifficultyCard.effects(normal, normal).size() == 1, "difficulty: Normal is the reference")
	var lines := DifficultyPanel.ascension_lines(CONTENT.ascensions, 2, 3)
	check(lines.size() == 3 and lines[0].begins_with("+1") and lines[2].begins_with("Next, +3"), "ascension: the twists so far, then the next (%s)" % lines)
	check(DifficultyPanel.ascension_lines(CONTENT.ascensions, 2, 2)[2].begins_with("Win Nightmare +2"), "ascension: how to open the next level")


## The options' tabs: each tab and its page there, the window opening on Gameplay, and every
## setting in exactly one tab, where a player would look for it; nothing outside the tabs.
func _test_options_tabs(options: OptionsPanel) -> void:
	var where := {
		OptionsPanel.Tab.GAMEPLAY: ["EnglishButton", "FrenchButton", "AutoLootAll", "AutoLootBetter", "AutoLootOff", "StoriesFull", "StoriesShort", "StoriesOff", "AssistCheck", "RunTimerCheck", "ShakeSlider", "VibrationsCheck", "TapChargeCheck", "LargeTextCheck", "TextSlow", "TextNormal", "TextFast", "TextInstant", "TutorialCheck", "ReplayTutorialButton"],
		OptionsPanel.Tab.GRAPHICS: ["UiSizeBig", "UiSizeMedium", "UiSizeSmall", "ControlsNormal", "ControlsLarge", "FixedStickCheck", "FewerEffectsCheck", "FlashesCheck", "BatteryCheck"],
		OptionsPanel.Tab.AUDIO: ["MasterSlider", "MusicSlider", "InterfaceSlider", "CombatSlider", "AmbienceSlider"],
		OptionsPanel.Tab.CONTROLS: [],
		OptionsPanel.Tab.PRIVACY: ["PolicyButton", "CreditsButton"],
	}
	if SettingsScript.has_window_modes():
		(where[OptionsPanel.Tab.GRAPHICS] as Array).append("FullscreenCheck")
	if Leaderboards.is_available():
		(where[OptionsPanel.Tab.PRIVACY] as Array).append_array(["BoardsNameButton", "BoardsShowCheck", "AnalyticsCheck", "DeleteDataButton"])
	if Account.is_available():
		(where[OptionsPanel.Tab.PRIVACY] as Array).append("AccountButton")
	check(OptionsPanel.Tab.size() == 5 and options.current_tab() == OptionsPanel.Tab.GAMEPLAY, "options: five tabs, opening on Gameplay")
	check(options.get_node("%GameplayTab").get_parent() is TabRow, "options: the tabs are a TabRow, like every window's")
	# Boss stories' line names a control: it follows the device in hand.
	var story_note := options.get_node("%StoriesNote") as Label
	check(story_note.text.contains("A tap skips it"), "options: on touch, a tap skips a story (%s)" % story_note.text)
	InputDevice.use(InputDevice.Kind.KEYBOARD)
	check(not story_note.text.contains("tap") and story_note.text.contains("skips it"), "options: with keys, the line names the key instead, as soon as the device changes (%s)" % story_note.text)
	InputDevice.use(InputDevice.Kind.TOUCH)
	check(story_note.text.contains("A tap skips it"), "options: and back to touch")
	var pages: Array[Control] = []
	for tab: int in OptionsPanel.Tab.values():
		var tab_name: String = OptionsPanel.TAB_NAMES[tab]
		var button := options.get_node_or_null("%" + tab_name + "Tab") as Button
		var page := options.get_node_or_null("%" + tab_name + "Page") as Control
		check(button != null and button.is_in_group(MenuNav.TABS) and page == options.page(tab as OptionsPanel.Tab), "options: the %s tab and its page" % tab_name)
		pages.append(page)
	check(options.page(OptionsPanel.Tab.CONTROLS) is ControlsPage, "options: the Controls tab is the controls page")
	var listed := []
	for tab: int in where:
		for node_name: String in where[tab]:
			listed.append(node_name)
			var control := options.get_node_or_null("%" + node_name) as Control
			var inside := pages.filter(func(page: Control) -> bool: return page != null and control != null and page.is_ancestor_of(control))
			check(inside.size() == 1 and inside[0] == pages[tab], "options: %s is in the %s tab only" % [node_name, OptionsPanel.TAB_NAMES[tab]])
	# Every setting the window holds (switches, sliders, toggles) is one of those, in a tab.
	var settings := _find_all(options, func(n: Node) -> bool:
		return (n is Range or n is CheckButton or (n is Button and (n as Button).toggle_mode)) and not n.is_in_group(MenuNav.TABS) \
			and pages.any(func(page: Control) -> bool: return page.is_ancestor_of(n)))
	var stray := settings.filter(func(n: Node) -> bool: return not listed.has(String(n.name)) and not n is ScrollBar)
	check(stray.is_empty(), "options: no setting outside the list (%s)" % [stray.map(func(n: Node) -> String: return n.name)])
	var outside := _find_all(options, func(n: Node) -> bool:
		return (n is Slider or n is CheckButton or (n is Button and (n as Button).toggle_mode and not n.is_in_group(MenuNav.TABS))) \
			and not pages.any(func(page: Control) -> bool: return page.is_ancestor_of(n)) and options.is_ancestor_of(n) \
			and not _in_dialog(options, n))
	check(outside.is_empty(), "options: no setting outside the tabs (%s)" % [outside.map(func(n: Node) -> String: return n.name)])


## The options' volume dragged with a finger: the volume applies while dragging (heard at once),
## finely (not by fifths of ten), and stays when let go; its keys' step is still 5%.
func _test_options_slider(options: OptionsPanel) -> void:
	options.show_tab(OptionsPanel.Tab.AUDIO)
	await _frames(2)
	var slider := options.get_node("%MusicSlider") as HSlider
	var before := Settings.music_volume
	check(slider.size.y >= 44.0 and is_equal_approx(float(slider.get_meta(MenuNav.KEY_STEP, 0.0)), 0.05) and slider.step <= 0.01 and not slider.scrollable, "options: a slider is finger-sized, fine under the finger, 5% a key")
	var rect := slider.get_global_rect()
	var at := Vector2(rect.position.x + 2.0, rect.get_center().y)
	_mouse(at, true)
	await _frames(1)
	var seen: Array[float] = []
	for i in 5:
		at = Vector2(rect.position.x + rect.size.x * (0.1 + 0.08 * i), rect.get_center().y + 12.0 * (i % 2))
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion, true)
		await _frames(1)
		seen.append(Settings.music_volume)
	check(seen.size() == 5 and seen[4] > seen[0] and absf(Settings.music_volume - slider.value) < 0.001, "options: the music follows the slider while it is dragged (%s)" % [seen])
	check(seen.any(func(v: float) -> bool: return absf(v * 20.0 - roundf(v * 20.0)) > 0.01), "...finer than 5%% steps (%s)" % [seen])
	_mouse(at, false)
	await _frames(2)
	check(absf(Settings.music_volume - slider.value) < 0.001 and not slider.has_meta(&"dragging"), "options: let go, the volume stays where it was let go")
	slider.value = before
	options.show_tab(OptionsPanel.Tab.GAMEPLAY)


## `node` belongs to one of the options' dialogs or pages over it (consent, name, policy...).
func _in_dialog(options: OptionsPanel, node: Node) -> bool:
	for dialog_name in ["ConsentDialog", "NameDialog", "DeleteDialog", "PolicyPanel", "CreditsPanel"]:
		var dialog := options.get_node_or_null("%" + dialog_name)
		if dialog and dialog.is_ancestor_of(node):
			return true
	return false


## The options: every control there, grouped, and tapping an option's name flips it.
func _test_options_screen(title: TitleScreen) -> void:
	var options: OptionsPanel = title.get_node("%OptionsPanel")
	(title.get_node("%OptionsButton") as Button).pressed.emit()
	await _frames(2)
	check(options.visible, "the options open from the title")
	for node_name in ["MasterSlider", "MusicSlider", "InterfaceSlider", "CombatSlider", "AmbienceSlider", "ShakeSlider", "ControlsNormal", "ControlsLarge", "LargeTextCheck", "TextNormal", "VibrationsCheck", "FixedStickCheck", "BatteryCheck", "FewerEffectsCheck", "FlashesCheck", "RunTimerCheck", "TutorialCheck", "ReplayTutorialButton", "CloseButton"]:
		check(options.get_node_or_null("%" + node_name) != null, "options: %s" % node_name)
	_test_options_tabs(options)
	await _test_options_slider(options)
	options.show_tab(OptionsPanel.Tab.GRAPHICS)
	await _frames(2)
	var battery: CheckButton = options.get_node("%BatteryCheck")
	var before := Settings.battery_saver
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.position = Vector2(4, 4)
	tap.pressed = false
	(battery.get_parent().get_child(0) as Control).gui_input.emit(tap)
	check(Settings.battery_saver != before and battery.button_pressed != before, "options: tapping the name flips the switch")
	battery.button_pressed = before
	# The language: French at once (the window rebuilt in it), then back to English.
	var french: Button = options.get_node_or_null("%FrenchButton")
	check(french != null and options.get_node_or_null("%EnglishButton") != null, "options: the language buttons")
	if french:
		french.pressed.emit()
		await _frames(2)
		check(Settings.language == "fr" and TranslationServer.get_locale() == "fr", "options: Français switches the game to French")
		var english: Button = options.get_node("%EnglishButton")
		check(english != null and options.visible and _texts(options).has("Langue") and _texts(options).has("Son"), "options: the window is rebuilt in French")
		check(options.current_tab() == OptionsPanel.Tab.GAMEPLAY and english.is_visible_in_tree(), "options: rebuilt on Gameplay, where the language is")
		check((options.get_node("%GameplayTab") as Button).text == "Jouabilité" and (options.get_node("%GraphicsTab") as Button).text == "Graphiques" and (options.get_node("%PrivacyTab") as Button).text == "Confidentialité", "options: the tabs' names in French")
		check((options.get_node("%FrenchButton") as Button).button_pressed and not english.button_pressed, "options: the language in use stays pressed")
		english.pressed.emit()
		await _frames(2)
		check(Settings.language == "en" and TranslationServer.get_locale() == "en" and _texts(options).has("Language"), "options: English switches back")
	(options.get_node("%CloseButton") as Button).pressed.emit()
	await _frames(1)
	check(not options.visible, "options: Close")


# --- Gameplay (bot) ----------------------------------------------------------


## The texts of every label under `root`.
## Every monster and boss shows whole on its page (its art inside its look's box, the box on
## the page and on screen), every card's name reads whole (on its two lines at most, no word cut,
## nothing left out), in English and French, on a phone (2340x1080, 2548x1296) and a 720-line
## window. Every kind slain already (the pages show all they hold).
func _test_codex_fits(codex: CodexPanel, entries: Array) -> void:
	var before := get_tree().root.size
	var page := codex.get_node("%MonsterPage") as MonsterPage
	for language: String in ["en", "fr"]:
		Settings.language = language
		Settings.apply()
		for screen: Vector2i in [Vector2i(2340, 1080), Vector2i(2548, 1296), Vector2i(1280, 720)]:
			get_tree().root.size = screen
			codex.open(CONTENT, CodexPanel.Tab.BESTIARY)
			await _frames(2)
			var cut := []
			for card: CodexCard in codex.bestiary_cards():
				var name_label := card.find_child("Name", true, false) as Label
				var inside := name_label.get_parent() as Control if name_label else null
				var whole := name_label != null and name_label.text == tr(card.monster.display_name) \
						and name_label.get_line_count() <= CodexCard.NAME_LINES \
						and name_label.get_visible_line_count() >= name_label.get_line_count() \
						and name_label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING \
						and inside.get_combined_minimum_size().y <= inside.size.y + 0.5
				# (A line may break after a hyphen: « Garde- / Carapace ».)
				for word in (name_label.text.replace("-", "- ").split(" ") if name_label else PackedStringArray()):
					if Fonts.width(word, Fonts.BODY) > name_label.size.x:
						whole = false
				if not whole:
					cut.append("%s [%s] lines %d/%d w %.0f min %.0f/%.0f" % [card.monster.id, name_label.text if name_label else "", name_label.get_line_count() if name_label else -1, name_label.get_visible_line_count() if name_label else -1, name_label.size.x if name_label else 0.0, inside.get_combined_minimum_size().y if inside else 0.0, inside.size.y if inside else 0.0])
			check(cut.is_empty(), "the bestiary: every card's name reads whole (two lines at most, no word cut) in %s at %s: %s" % [language, screen, cut])
			var outside := []
			var view := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(1.0)
			for monster: MonsterDef in entries:
				codex.open_monster(monster)
				await _frames(2)
				var rects := page.look_rects()
				var art: Rect2 = rects[0]
				var box: Rect2 = rects[1]
				if not (art.has_area() and box.grow(0.5).encloses(art) and page.get_global_rect().grow(0.5).encloses(box) and view.encloses(box)):
					outside.append("%s %s in %s" % [monster.id, art, box])
			check(outside.is_empty(), "the bestiary: every monster and boss shows whole on its page in %s at %s: %s" % [language, screen, outside.slice(0, 4)])
			codex.back()
	Settings.language = "en"
	Settings.apply()
	get_tree().root.size = before
	codex.open(CONTENT, CodexPanel.Tab.BESTIARY)
	codex.open_monster(entries[entries.size() - 1])
	await _frames(2)


func _texts(root: Node) -> Array:
	return _find_all(root, func(n: Node) -> bool: return n is Label).map(func(l: Label) -> String: return l.text)


## Every node under `root` for which `test` is true.
func _find_all(root: Node, test: Callable) -> Array:
	var found := []
	for child in root.get_children():
		if test.call(child):
			found.append(child)
		found.append_array(_find_all(child, test))
	return found
