class_name OptionsPanel
extends Control
## Options window (title screen and pause menu), in the game's skin (MenuWindow). Five tabs (TABS,
## switched by a tap, a click, Q / E or LB / RB: MenuNav), each a page of grouped options with
## their name and a short line saying what it does:
## - Gameplay: the language, auto loot, boss stories, in a run (run timer, screen shake,
##   vibrations), the tutorial (hints, Replay tutorial);
## - Graphics: the screen (fullscreen on a computer, interface size), the touch controls (buttons
##   size, fixed joystick), effects and battery (fewer effects, screen flashes, battery saver);
## - Audio: the five volumes;
## - Controls: what does what on the device in use (its keys, buttons or touch, ControlsPage);
## - Privacy: online (with a server in the build: the leaderboards' name and switch, the gameplay
##   statistics, the online ID, the deletion), the privacy policy and the credits.
## Every change goes straight to Settings (applied and saved).
## Its rows are OptionRows'; the Controls and Privacy tabs are pages of their own (ControlsPage,
## PrivacyPage).
## Built in code; every control is reachable as %Name from the panel (%EnglishButton,
## %FrenchButton, %MasterSlider, %MusicSlider, %InterfaceSlider, %CombatSlider, %AmbienceSlider,
## %ShakeSlider, %ControlsSlider, %VibrationsCheck, %FixedStickCheck, %BatteryCheck,
## %FewerEffectsCheck, %FlashesCheck, %RunTimerCheck, %TutorialCheck, %ReplayTutorialButton, %AutoLootAll, %AutoLootBetter,
## %AutoLootOff, %StoriesFull, %StoriesShort, %StoriesOff, %FullscreenCheck (computers),
## %UiSizeBig, %UiSizeMedium, %UiSizeSmall, the tabs %GameplayTab, %GraphicsTab, %AudioTab,
## %ControlsTab, %PrivacyTab and their pages %GameplayPage, %GraphicsPage, %AudioPage,
## %ControlsPage, %PrivacyPage, %CloseButton; Privacy: %PolicyButton, %CreditsButton,
## %PolicyPanel, %CreditsPanel, and with a server in the build: %BoardsNameText,
## %BoardsNameButton, %BoardsShowCheck, %NameDialog, %AnalyticsCheck, %ConsentDialog,
## %OnlineIdText, %DeleteDataButton, %DeleteDialog).
## The leaderboards' pseudonym and "Publish my scores online" live in the Leaderboards autoload,
## the statistics' consent in Privacy (their own files), not in Settings.
## Picking a language rebuilds the window in it at once; the title screen behind is rebuilt when
## the window closes (other screens pick it up the next time they open).

signal closed
## The player picked another language (Settings.language is already set).
signal language_changed

## The window's tabs, in their order on screen.
enum Tab { GAMEPLAY, GRAPHICS, AUDIO, CONTROLS, PRIVACY }

## Each tab's name (translated where shown), also its nodes' names: %<name>Tab, %<name>Page.
## The Settings autoload's script, for its static functions.
const SettingsScript := preload("res://src/autoload/settings.gd")
const TAB_NAMES := {
	Tab.GAMEPLAY: "Gameplay",  # i18n
	Tab.GRAPHICS: "Graphics",  # i18n
	Tab.AUDIO: "Audio",  # i18n
	Tab.CONTROLS: "Controls",  # i18n
	Tab.PRIVACY: "Privacy",  # i18n
}


## Volume sliders: Settings key -> slider (general, music, interface, combat, ambience).
var _volumes := {}
var _shake: HSlider
var _controls: HSlider
var _vibrations: CheckButton
## Plain on/off options: check -> Settings key.
var _checks := {}
var _replay: Button
var _tutorial: CheckButton
## Language code -> its button.
var _languages := {}
## Auto loot: Settings.LOOT_* -> its button, and the line saying what the picked one does.
var _loot_modes := {}
var _loot_help: Label
## Boss stories: Settings.STORIES_* -> its button, and the line saying what the picked one does.
var _story_modes := {}
var _story_help: Label
## Interface size: Settings.UI_* -> its button.
var _ui_sizes := {}
## The tab buttons and their pages, by Tab; the tab shown.
var _tabs: TabRow
var _pages: Array[Control] = []
var _controls_page: ControlsPage
var _current := Tab.GAMEPLAY
## The language changed while the window was open.
var _language_changed := false
## Options > Privacy: the leaderboards, the player's data, the policy and the credits.
var _privacy: PrivacyPage


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()
	_wire()


## Connects the controls to Settings (after each build).
func _wire() -> void:
	for code: String in _languages:
		(_languages[code] as Button).pressed.connect(_pick_language.bind(code))
	for key: StringName in _volumes:
		_bind_slider(_volumes[key], key)
	_bind_slider(_shake, &"screen_shake")
	_bind_slider(_controls, &"controls_scale")
	_vibrations.toggled.connect(func(on: bool) -> void:
		Settings.set_option(&"vibrations", on)
		if on:
			Settings.vibrate(0.6))
	for check: CheckButton in _checks:
		var key: StringName = _checks[check]
		check.toggled.connect(func(on: bool) -> void:
			Settings.set_option(key, on)
			Sfx.play_ui(Sfx.bank.ui_click))
	for mode: int in _loot_modes:
		(_loot_modes[mode] as Button).pressed.connect(_pick_loot_mode.bind(mode))
	for mode: int in _story_modes:
		(_story_modes[mode] as Button).pressed.connect(_pick_story_mode.bind(mode))
	for ui_size: int in _ui_sizes:
		(_ui_sizes[ui_size] as Button).pressed.connect(func() -> void:
			Settings.set_option(&"ui_size", ui_size)
			Sfx.play_ui(Sfx.bank.ui_click)
			_show_ui_size())
	_tabs.picked.connect(func(tab: int) -> void: show_tab(tab as Tab))
	# Every hint shows again, from the first steps (and the hints come back on).
	_replay.pressed.connect(func() -> void:
		Profile.reset_hints()
		Settings.set_option(&"tutorial_hints", true)
		_tutorial.set_pressed_no_signal(true)
		_replay.text = tr("Done! Tips are back")
		Sfx.play_ui(Sfx.bank.ui_click))


func open() -> void:
	for slider: HSlider in _volumes.values() + [_shake, _controls]:
		var key: StringName = slider.get_meta(&"option")
		slider.set_value_no_signal(Settings.get(key))
		_show_value(slider)
	_vibrations.set_pressed_no_signal(Settings.vibrations)
	for check: CheckButton in _checks:
		check.set_pressed_no_signal(Settings.get(_checks[check]))
	_replay.text = tr("Replay tutorial")
	for code: String in _languages:
		(_languages[code] as Button).set_pressed_no_signal(code == Settings.language)
	_show_loot_mode()
	_show_story_mode()
	_show_ui_size()
	_privacy.refresh()
	show_tab(Tab.GAMEPLAY)
	show()


## Shows the page of `tab` (its button stays pressed, the others not).
func show_tab(tab: Tab) -> void:
	_current = tab
	for i in _pages.size():
		_pages[i].visible = i == tab
	_tabs.select(tab)
	if tab == Tab.CONTROLS:
		_controls_page.refresh()


## The tab shown.
func current_tab() -> Tab:
	return _current


## The page of `tab` (tests).
func page(tab: Tab) -> Control:
	return _pages[tab]


func close() -> void:
	if _privacy and _privacy.back():
		return
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()
	closed.emit()
	# The title screen was built in the old language: build it again.
	if _language_changed and get_tree().current_scene is TitleScreen:
		get_tree().reload_current_scene()
	_language_changed = false


## Switches the game to another language and rebuilds this window in it.
func _pick_language(code: String) -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	if code == Settings.language:
		(_languages[code] as Button).set_pressed_no_signal(true)
		return
	Settings.set_option(&"language", code)
	_language_changed = true
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_checks.clear()
	_volumes.clear()
	_languages.clear()
	_loot_modes.clear()
	_story_modes.clear()
	_ui_sizes.clear()
	_tabs = null
	_pages.clear()
	_privacy = null
	_build()
	_wire()
	open()
	language_changed.emit()


func _pick_loot_mode(mode: int) -> void:
	Settings.set_option(&"auto_loot", mode)
	Sfx.play_ui(Sfx.bank.ui_click)
	_show_loot_mode()


func _show_loot_mode() -> void:
	for mode: int in _loot_modes:
		(_loot_modes[mode] as Button).set_pressed_no_signal(mode == Settings.auto_loot)
	if _loot_help:
		_loot_help.text = _loot_help_text(Settings.auto_loot)


func _show_ui_size() -> void:
	for ui_size: int in _ui_sizes:
		(_ui_sizes[ui_size] as Button).set_pressed_no_signal(ui_size == Settings.ui_size)


func _pick_story_mode(mode: int) -> void:
	Settings.set_option(&"boss_stories", mode)
	Sfx.play_ui(Sfx.bank.ui_click)
	_show_story_mode()


func _show_story_mode() -> void:
	for mode: int in _story_modes:
		(_story_modes[mode] as Button).set_pressed_no_signal(mode == Settings.boss_stories)
	if _story_help:
		_story_help.text = _story_help_text(Settings.boss_stories)


## What a Boss stories mode does, in a line.
static func _story_help_text(mode: int) -> String:
	if mode == Settings.STORIES_SHORT:
		return TranslationServer.tr("Only its name and a line it remembers, about two seconds.")
	if mode == Settings.STORIES_OFF:
		return TranslationServer.tr("No scene: the fight starts at once.")
	return TranslationServer.tr("A new chapter of its story when there is one; otherwise two seconds.")


## What a mode does, in a line.
static func _loot_help_text(mode: int) -> String:
	if mode == Settings.LOOT_ALL:
		return TranslationServer.tr("Walking over an item takes it.")
	if mode == Settings.LOOT_OFF:
		return TranslationServer.tr("Gear stays on the ground: walk over it, then Take.")
	return TranslationServer.tr("Gear only if it beats what you wear; the rest stays on the ground.")


## While a finger or the mouse drags it, the value follows and applies at once (the volume heard)
## without writing the file at every step; letting go saves it and plays a sound of what it sets.
## A key or a gamepad's step saves at once.
func _bind_slider(slider: HSlider, option: StringName) -> void:
	slider.set_meta(&"option", option)
	slider.drag_started.connect(func() -> void: slider.set_meta(&"dragging", true))
	slider.value_changed.connect(func(value: float) -> void:
		if slider.has_meta(&"dragging"):
			Settings.preview_option(option, value)
		else:
			Settings.set_option(option, value)
		_show_value(slider))
	slider.drag_ended.connect(func(_changed: bool) -> void:
		slider.remove_meta(&"dragging")
		Settings.set_option(option, slider.value)
		_preview(option))


## A short sound of what a slider sets: a click for the interface, a hit for combat, coins for
## the ambience (the music is its own preview).
func _preview(option: StringName) -> void:
	match option:
		&"music_volume":
			pass
		&"combat_volume":
			Sfx.play_at(Sfx.bank.monster_hurt, Sfx.listener_position())
		&"ambience_volume":
			Sfx.play_world(Sfx.bank.coin, Sfx.listener_position())
		_:
			Sfx.play_ui(Sfx.bank.ui_click)


func _show_value(slider: HSlider) -> void:
	var label := slider.get_meta(OptionRows.VALUE_META) as Label
	if label:
		label.text = tr("%d%%") % roundi(slider.value * 100.0)


# --- Building -----------------------------------------------------------------------

func _build() -> void:
	var window := MenuWindow.new(tr("Options"))
	window.close_requested.connect(close)
	add_child(window)
	MenuWindow.expose(window.close_button, "CloseButton", self)
	# In a run, the menus already built keep their words until the next run: say so.
	var in_run := _language_changed and not get_tree().current_scene is TitleScreen
	var note := tr("Language changed: some menus follow from the next run.") if in_run else tr("Every change is saved right away.")
	var saved := UiSkin.label(note, Fonts.BODY, UiSkin.DIM, true)
	saved.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saved.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	window.header_left.add_child(saved)
	_build_tabs(window.body)


## The tabs over the window's body (switched with the tab keys too: MenuNav; not in the header:
## five French names and the header's Close don't fit a 1280-wide screen on one line), and under
## them each tab's page, built into the body by its own function (which returns it); one page
## shows at a time.
func _build_tabs(body: VBoxContainer) -> void:
	var builders := {
		Tab.GAMEPLAY: _build_gameplay,
		Tab.GRAPHICS: _build_graphics,
		Tab.AUDIO: _build_audio,
		Tab.CONTROLS: _build_controls,
		Tab.PRIVACY: _build_privacy,
	}
	_tabs = TabRow.new()
	body.add_child(_tabs)
	for tab: int in Tab.values():
		var tab_name: String = TAB_NAMES[tab]
		_tabs.add_tab(tr(tab_name), tab_name + "Tab", self)
		var page_node := (builders[tab] as Callable).call(body) as Control
		page_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
		MenuWindow.expose(page_node, tab_name + "Page", self)
		_pages.append(page_node)


## Gameplay: the language (first: a player who can't read the one in use finds it at once), auto
## loot and boss stories; what shows or shakes in a run, and the tutorial.
func _build_gameplay(body: VBoxContainer) -> Control:
	var page_node := OptionRows.page(body)
	var left := OptionRows.column(page_node)
	var right := OptionRows.column(page_node)
	_build_languages(OptionRows.section(left, tr("Language")))
	_build_loot(OptionRows.section(left, tr("Loot")))
	_build_stories(OptionRows.section(left, tr("Story")))
	var in_run := OptionRows.section(right, tr("In a run"))
	_checks[OptionRows.check(self, in_run, tr("Run timer"), tr("The run's time, under the map."), "RunTimerCheck")] = &"run_timer"
	_shake = OptionRows.slider(self, in_run, tr("Screen shake"), tr("On big hits."), 0.0, 1.5, 0.1, "ShakeSlider")
	_vibrations = OptionRows.check(self, in_run, tr("Vibrations"), tr("The phone buzzes on big hits and critical hits."), "VibrationsCheck")
	var tutorial := OptionRows.section(right, tr("Tutorial"))
	_tutorial = OptionRows.check(self, tutorial, tr("Tutorial hints"), tr("Short tips during your first runs."), "TutorialCheck")
	_checks[_tutorial] = &"tutorial_hints"
	var replay_row := HBoxContainer.new()
	replay_row.add_theme_constant_override("separation", 12)
	tutorial.add_child(replay_row)
	replay_row.add_child(OptionRows.words(tr("Replay tutorial"), tr("Every tip again, from the first steps.")))
	_replay = MenuWindow.button(tr("Replay tutorial"), Fonts.BODY, 44)
	_replay.custom_minimum_size.x = 190
	_replay.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	replay_row.add_child(_replay)
	MenuWindow.expose(_replay, "ReplayTutorialButton", self)
	return page_node


## Graphics: the screen (fullscreen, interface size), the touch controls' look, the effects and
## the battery.
func _build_graphics(body: VBoxContainer) -> Control:
	var page_node := OptionRows.page(body)
	var left := OptionRows.column(page_node)
	var right := OptionRows.column(page_node)
	var screen := OptionRows.section(left, tr("Screen"))
	if SettingsScript.has_window_modes():
		_checks[OptionRows.check(self, screen, tr("Fullscreen"), tr("The whole screen, or a window you can resize (F11, Alt+Enter)."), "FullscreenCheck")] = &"fullscreen"
	_build_ui_size(screen)
	var controls := OptionRows.section(left, tr("Touch controls"))
	_controls = OptionRows.slider(self, controls, tr("Buttons size"), tr("Joystick and buttons."), 0.7, 1.3, 0.05, "ControlsSlider")
	_checks[OptionRows.check(self, controls, tr("Fixed joystick"), tr("Stays in its corner instead of following your thumb."), "FixedStickCheck")] = &"fixed_joystick"
	var effects := OptionRows.section(right, tr("Effects and battery"))
	_checks[OptionRows.check(self, effects, tr("Fewer effects"), tr("Half the particles, no heat haze nor glow: smoother on older phones."), "FewerEffectsCheck")] = &"fewer_effects"
	_checks[OptionRows.check(self, effects, tr("Screen flashes"), tr("Lightning lights up the whole screen for an instant."), "FlashesCheck")] = &"screen_flashes"
	_checks[OptionRows.check(self, effects, tr("Battery saver"), tr("30 FPS: the phone stays cooler."), "BatteryCheck")] = &"battery_saver"
	return page_node


## Audio: the five volumes, one under the other, the sliders long (a single column).
func _build_audio(body: VBoxContainer) -> Control:
	var page_node := OptionRows.page(body)
	var sound := OptionRows.section(OptionRows.column(page_node), tr("Sound"))
	_volumes[&"master_volume"] = OptionRows.slider(self, sound, tr("General"), tr("Every sound at once."), 0.0, 1.0, 0.05, "MasterSlider", true)
	_volumes[&"music_volume"] = OptionRows.slider(self, sound, tr("Music"), tr("Background music."), 0.0, 1.0, 0.05, "MusicSlider", true)
	_volumes[&"ui_volume"] = OptionRows.slider(self, sound, tr("Interface"), tr("Menus, buttons, level up."), 0.0, 1.0, 0.05, "InterfaceSlider", true)
	_volumes[&"combat_volume"] = OptionRows.slider(self, sound, tr("Combat"), tr("Weapons, hits, cries, spells."), 0.0, 1.0, 0.05, "CombatSlider", true)
	_volumes[&"ambience_volume"] = OptionRows.slider(self, sound, tr("Ambience"), tr("Footsteps, wind, doors, chests."), 0.0, 1.0, 0.05, "AmbienceSlider", true)
	# (0.05: a key's or a gamepad's step; a finger moves them by the hundredth: OptionRows.slider(self, ))
	return page_node


## Controls: what does what on the device in use (ControlsPage, filled when shown).
func _build_controls(body: VBoxContainer) -> Control:
	_controls_page = ControlsPage.new()
	body.add_child(_controls_page)
	return _controls_page


## Privacy: the leaderboards, the player's data, the policy and the credits (PrivacyPage).
func _build_privacy(body: VBoxContainer) -> Control:
	_privacy = PrivacyPage.new()
	body.add_child(_privacy)
	_privacy.build(self)
	return _privacy


## Auto loot: its name, three buttons (one stays pressed), what the picked one does. Gold always
## flies to you.
func _build_loot(section: VBoxContainer) -> void:
	_loot_modes = OptionRows.choice(self, section, tr("Auto loot"), tr("Gold, potions, runes and keys: always."), [
		[Settings.LOOT_ALL, tr("All"), "AutoLootAll"],
		[Settings.LOOT_BETTER, tr("Better only"), "AutoLootBetter"],
		[Settings.LOOT_OFF, tr("By hand"), "AutoLootOff"],
	])
	_loot_help = UiSkin.label("", Fonts.BODY, UiSkin.GOLD, true)
	section.add_child(_loot_help)


## Boss stories: its name, three buttons (one stays pressed), what the picked one does. A tap
## skips a story anyway.
func _build_stories(section: VBoxContainer) -> void:
	_story_modes = OptionRows.choice(self, section, tr("Boss stories"), _story_note_text(), [
		[Settings.STORIES_FULL, tr("Full"), "StoriesFull"],
		[Settings.STORIES_SHORT, tr("Short"), "StoriesShort"],
		[Settings.STORIES_OFF, tr("Off"), "StoriesOff"],
	], "StoriesNote")
	# It names a control: its words follow the device in hand (design/interface.md, Devices).
	if not InputDevice.changed.is_connected(_say_story_note):
		InputDevice.changed.connect(_say_story_note)
	_story_help = UiSkin.label("", Fonts.BODY, UiSkin.GOLD, true)
	section.add_child(_story_help)


## Interface size: its name, three buttons (one stays pressed).
func _build_ui_size(section: VBoxContainer) -> void:
	_ui_sizes = OptionRows.choice(self, section, tr("Interface size"), tr("Smaller leaves more room on a big screen."), [
		[Settings.UI_BIG, tr("Big"), "UiSizeBig"],
		[Settings.UI_MEDIUM, tr("Medium"), "UiSizeMedium"],
		[Settings.UI_SMALL, tr("Small"), "UiSizeSmall"],
	])


## The language: two big buttons, each language's name in itself; the one in use stays pressed.
## First on the first page: a player who can't read the one in use finds it at once.
func _build_languages(section: VBoxContainer) -> void:
	var entries := []
	for code: String in Settings.LANGUAGES:
		entries.append([code, Settings.LANGUAGE_NAMES[code], "FrenchButton" if code == "fr" else "EnglishButton"])
	_languages = OptionRows.choice(self, section, "", tr("The game's words, at once."), entries)
	for button: Button in _languages.values():
		# A language's own name is never translated.
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		# Never focused first: an accept pressed at once must not switch the language.
		button.set_meta(MenuNav.NOT_FIRST, true)


## Boss stories' line: how a story is skipped, in the device's words.
func _story_note_text() -> String:
	return Prompts.pick("Before a warden's fight. A tap skips it.", "Before a warden's fight. {ui_accept} skips it.")  # i18n


func _say_story_note() -> void:
	var note := get_node_or_null("%StoriesNote") as Label
	if note:
		note.text = _story_note_text()

