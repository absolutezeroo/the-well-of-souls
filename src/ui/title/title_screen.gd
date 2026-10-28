class_name TitleScreen
extends Control
## First screen: play (or today's daily run, see DailyRun), visit the shrine (permanent
## upgrades bought with souls), read the story, see your records. No class to pick: you become
## who you want with what you find in the dungeon. The very first run starts with the story, then
## goes straight down the Well (decision 0010: Descend, on Keeper, no Kagari nor choices before
## it; they come at the first return); later, Play enters Kagari. The privacy questions come
## first: Play waits for them when they are still to be asked.
## The Daily Descent button says what it is (same dungeon for everyone today, the day's weapon and
## relic, your score); the records sit on a plaque under the buttons; the Shrine button shows a
## badge when an upgrade can be bought. The Vigil-Keeper stands by the Well (ShrineKeeper): a
## tap on her (or the focus and accept) opens her words (DialogueScreen); the shrine's lamps burn
## again with the souls offered to the Tree (TitleBackdrop.lamps_lit). Under the records, the
## Leaderboards button opens the online leaderboards (LeaderboardsPanel), Credits the credits
## (CreditsPanel) and Feedback, beside it, the feedback form (FeedbackDialog). The first time it shows (and when a refusal's six months are over), it asks the
## gameplay statistics' questions (ConsentDialog, Privacy.should_ask()), over the title, never
## over a run. At the bottom, a discreet line turns through the world counters (WorldStats, "The
## Well's Toll": the demons slain in the Well by every player...), only once they were read. Under
## Credits, what the remote settings say (RemoteConfig): a running event's plaque and
## the message of the day; the title is a safe point where read values start to apply.

const GAME_SCENE := "res://src/game/game.tscn"
const VILLAGE_SCENE := "res://src/village/village_hub.tscn"
const STORY_SCENE := "res://src/ui/story/story_screen.tscn"
## Seconds before the shrine's bell tolls (the music first).
const TITLE_BELL_DELAY := 1.4
## Seconds after the title shows before the privacy questions come (the screen seen first).
const PRIVACY_DELAY := 0.8
## The dark text of the theme's orange buttons.
const BUTTON_TEXT := Color(0.16862746, 0.11372549, 0.14117648)
## The world counters' line: UI pixels between its baseline and the screen's bottom.
const WORLD_LINE_BOTTOM := 14.0

@export var content: ContentDB

@onready var _records: BoxContainer = %Records
@onready var _shrine: ShrinePanel = %ShrinePanel
@onready var _hero: AnimatedSprite2D = %Hero

var _daily_title: Label
var _daily_text: Label
var _shrine_badge: Control
var oath_panel: OathPanel
var daily_dialog: DailyDialog
## The online leaderboards (LeaderboardsPanel), from the button under the records.
var leaderboards: LeaderboardsPanel
## The credits (CreditsPanel), from the button under Leaderboards.
var credits: CreditsPanel
## The Wardrobe (WardrobePanel), from its button under Credits.
var wardrobe: WardrobePanel
## The aura the hero by the Well wears (the Wardrobe's), or null.
var hero_aura: AuraVfx
## "Send feedback" (FeedbackDialog), from the button beside Credits.
var feedback: FeedbackDialog
## The gameplay statistics' questions (age, then consent).
var consent: ConsentDialog
## The online save's conflict (CloudSave): which progress to keep.
var cloud_conflict: CloudConflictDialog
## The tutorial's title-screen hints (the Tree of Souls, the oaths), over everything.
var hint_box: HintBox
## Who keeps vigil at the shrine (NarrativeDef.shrine_speaker), and her words when she speaks.
var keeper: ShrineKeeper
var talk: DialogueScreen
## The world counters' line at the bottom (hidden while none is known), and which one it shows.
var world_line: Label
var _world_index := 0
## The remote settings' notes under Credits (RemoteConfig): a running event's plaque
## (its name, what it gives, the time left) and the message of the day; hidden when there are none.
var event_plaque: PanelContainer
var event_title: Label
var event_details: Label
var message_line: Label
## Play was pressed while the privacy questions were still to be asked: it goes on once they are.
var _play_after_consent := false


## The shrine's music (SoundBank.title_music: Kagari asleep above the Well), and its bell tolled
## once as the screen opens (title_bell); the first act's music if the bank has none.
func _play_music() -> void:
	var bank := Sfx.bank
	var music := bank.title_music
	if music == null and not content.dungeon.acts.is_empty():
		var biome := content.dungeon.acts[0].main_biome()
		music = Soundtrack.floor_music(biome.theme) if biome else null
	Sfx.play_music(music)
	if bank.title_bell:
		get_tree().create_timer(TITLE_BELL_DELAY).timeout.connect(func() -> void:
			if is_inside_tree() and visible:
				Sfx.play_ui(bank.title_bell, bank.title_bell_db))


func _ready() -> void:
	get_tree().paused = false
	add_to_group(MenuNav.GROUP)  # its buttons, for keys and gamepads
	if content.sounds:
		Sfx.bank = content.sounds
	_play_music()
	if content.story:
		(%Title as Label).text = tr(content.story.title)
		(%Subtitle as Label).text = tr(content.story.tagline)
		(%ShrineText as Label).text = tr(content.story.shrine_text)
	_hero.sprite_frames = content.player.frames
	_hero.play(&"idle_right")  # (looking at the Well)
	# The hero on the Well's rim, the souls rising from it (the picture follows the screen's size).
	var backdrop: TitleBackdrop = %Backdrop
	backdrop.resized.connect(_place_scene)
	_build_keeper()
	_place_scene.call_deferred()
	AchievementDef.unlock_reached(content.achievements)  # goals reached by older saves
	QuestBoard.pay_finished(content.quests)  # finished in a run that ended before paying them
	_build_daily_button()
	_build_shrine_badge()
	var plaque_style := MenuWindow.strip_style().duplicate() as StyleBoxTexture
	plaque_style.content_margin_left = 16
	plaque_style.content_margin_right = 16
	plaque_style.content_margin_top = 12
	plaque_style.content_margin_bottom = 14
	(%RecordsPlaque as PanelContainer).add_theme_stylebox_override("panel", plaque_style)
	(%RecordsPlaque as PanelContainer).custom_minimum_size.x = 250
	_setup_continue()
	(%PlayButton as Button).text = tr("Descend") if Game.first_descent_due() else tr("Enter Kagari")
	%PlayButton.pressed.connect(play)
	# Once the tree opened an oath or the Armory: "At the Well's Edge" between the two.
	oath_panel = OathPanel.new()
	add_child(oath_panel)
	oath_panel.started.connect(play)
	talk = DialogueScreen.new()
	talk.name = "KeeperTalk"
	add_child(talk)
	talk.closed.connect(func() -> void:
		_refresh_keeper()
		if keeper and InputDevice.uses_buttons():
			keeper.grab_focus())
	hint_box = HintBox.new()
	add_child(hint_box)
	hint_box.dismissed.connect(hint_box.hide_hint)
	(%DifficultyPanel as DifficultyPanel).chosen.connect(func(_difficulty: DifficultyDef) -> void:
		if OathPanel.has_choices(content):
			Sfx.play_ui(Sfx.bank.ui_open)
			oath_panel.open(content)
			show_menu_hint(&"menu_oath")
		else:
			play())
	# The daily run: tapping it explains it first (DailyDialog), then it starts.
	daily_dialog = DailyDialog.new()
	daily_dialog.hide()
	add_child(daily_dialog)
	daily_dialog.accepted.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		VillageHub.daily_requested = true
		_go(VILLAGE_SCENE))
	_build_leaderboards()
	_build_credits()
	_build_wardrobe()
	_build_consent()
	_build_cloud_conflict()
	_build_world_line()
	_build_remote_notes()
	%DailyButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		daily_dialog.open(content, DailyRun.today()))
	%ShrineButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		_shrine.open(content.soul_tree, content)
		show_menu_hint(&"menu_shrine"))
	%QuestsButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		(%CodexPanel as CodexPanel).open(content, CodexPanel.Tab.QUESTS))
	%CodexButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		(%CodexPanel as CodexPanel).open(content))
	%OptionsButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		(%OptionsPanel as OptionsPanel).open())
	%StoryButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		tell_story(""))
	Profile.changed.connect(_refresh)
	_refresh()
	(%PlayButton as Button).grab_focus()


## Play: the privacy questions first if they are still to be asked; then, for a profile with no
## run yet, the first descent at once (on Keeper: Game.prepare_first_descent()); otherwise Kagari.
## The story before either, the first time.
func play() -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	if Privacy.ask_on_title and Privacy.should_ask():
		_play_after_consent = true
		ask_privacy()
		return
	_go(play_scene())


## Where Play leads now: the game (the first descent) or Kagari.
func play_scene() -> String:
	if Game.first_descent_due():
		Game.prepare_first_descent(content)
		return GAME_SCENE
	return VILLAGE_SCENE


## `scene`, after the story the first time.
func _go(scene: String) -> void:
	if not Profile.seen_intro and content.story and not content.story.intro_pages.is_empty():
		tell_story(scene)
	else:
		Loader.go(scene)


## The run in progress, if the app was closed during one.
func _setup_continue() -> void:
	var saved := RunSave.read()
	var button: Button = %ContinueButton
	button.visible = not saved.is_empty()
	if saved.is_empty():
		return
	var player: Dictionary = saved.get("player", {})
	# Two lines like the Dawn Knell's, inside the column's width (one long line ran past it).
	var lines := _two_line_button(button, Fonts.BODY)
	lines[0].text = tr("Resume the descent")
	lines[1].text = tr("Floor %d, level %d") % [int(saved.get("depth", 1)), int(player.get("level", 1))]
	button.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		Loader.go(VILLAGE_SCENE))
	button.grab_focus.call_deferred()


## The story screen, then `next_scene` (empty = back here).
func tell_story(next_scene: String) -> void:
	StoryScreen.next_scene = next_scene if not next_scene.is_empty() else scene_file_path
	get_tree().change_scene_to_file(STORY_SCENE)


## The Vigil-Keeper by the Well, if the story has someone at the shrine.
func _build_keeper() -> void:
	var narrative := content.narrative
	if narrative == null or narrative.shrine_speaker == null or narrative.shrine_dialogues.is_empty():
		return
	keeper = ShrineKeeper.new(narrative.shrine_speaker)
	keeper.name = "Keeper"
	add_child(keeper)
	# Over the full-screen menu's margins (they would take her taps), under the panels.
	move_child(keeper, ($Margin as Control).get_index() + 1)
	keeper.pressed.connect(talk_to_keeper)


## She says the first of her dialogues with something to say (one line a tap), over the screen.
func talk_to_keeper() -> void:
	if content.narrative == null or talk.visible:
		return
	var spoken: Array[Dialogues.Spoken] = []
	for dialogue in content.narrative.shrine_dialogues:
		var said := Dialogues.say(dialogue)
		if said:
			spoken.append(said)
			break
	if spoken.is_empty():
		return
	Sfx.play_ui(Sfx.bank.ui_open)
	talk.open(spoken)
	_refresh_keeper()


func _refresh_keeper() -> void:
	if keeper:
		keeper.has_news = content.narrative.shrine_dialogues.any(func(dialogue: DialogueDef) -> bool:
			return Dialogues.has_new(dialogue))
	var tree := content.soul_tree
	if tree:
		var owned := 0
		var total := 0
		for node in tree.nodes:
			if node and node.upgrade:
				owned += mini(node.level(), node.max_level())
				total += node.max_level()
		var backdrop: TitleBackdrop = %Backdrop
		backdrop.lamps_lit = ceili(float(backdrop.lamps) * owned / total) if total > 0 and owned > 0 else 0


## The hero and the souls where the Well is drawn.
func _place_scene() -> void:
	var backdrop: TitleBackdrop = %Backdrop
	var moved := backdrop.hero_spot() - _hero.position
	_hero.position = backdrop.hero_spot()
	if hero_aura and is_instance_valid(hero_aura):
		hero_aura.position += moved
	if keeper:
		keeper.position = (backdrop.keeper_spot() - keeper.feet()).round()
	var wisps: CPUParticles2D = %Wisps
	wisps.position = backdrop.well_center() + Vector2(0, -backdrop.size.y * 0.3)
	wisps.emission_rect_extents = Vector2(backdrop.well_radius().x * 0.8, backdrop.size.y * 0.3)


## The Daily Descent button's three lines: name, what it is, your score.
func _build_daily_button() -> void:
	var lines := _two_line_button(%DailyButton, Fonts.BODY)
	_daily_title = lines[0]
	_daily_text = lines[1]


## A title and a line under it, centered in `button` and never wider than it: [title, line].
func _two_line_button(button: Button, title_size: int) -> Array[Label]:
	button.text = ""
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 10)
	button.add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	margin.add_child(column)
	var lines: Array[Label] = [_button_label(title_size), _button_label(Fonts.SMALL)]
	for label in lines:
		column.add_child(label)
	return lines


func _button_label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 0)  # dark words on the orange button
	label.add_theme_color_override("font_color", BUTTON_TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS  # never wider than the button
	return label


## "Leaderboards" under the records (the button column has no room left on a phone), and its
## page over the screen.
func _build_leaderboards() -> void:
	leaderboards = LeaderboardsPanel.new()
	leaderboards.name = "LeaderboardsPanel"
	add_child(leaderboards)
	leaderboards.closed.connect(func() -> void:
		if InputDevice.uses_buttons():
			(%LeaderboardsButton as Button).grab_focus())
	var button := MenuWindow.button(tr("Leaderboards"), Fonts.BODY, 56)
	button.size_flags_horizontal = Control.SIZE_FILL
	(%RecordsPlaque as Control).get_parent().add_child(button)
	MenuWindow.expose(button, "LeaderboardsButton", self)
	button.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		leaderboards.open())


## "Credits" and "Feedback" side by side under Leaderboards, and their page and form over the
## screen.
func _build_credits() -> void:
	credits = CreditsPanel.new()
	credits.name = "CreditsPanel"
	add_child(credits)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	(%RecordsPlaque as Control).get_parent().add_child(row)
	var button := MenuWindow.button(tr("Credits"), Fonts.BODY, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(button)
	MenuWindow.expose(button, "CreditsButton", self)
	feedback = FeedbackDialog.new()
	feedback.name = "FeedbackDialog"
	add_child(feedback)
	var send := MenuWindow.button(tr("Feedback"), Fonts.BODY, 44)
	send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(send)
	MenuWindow.expose(send, "FeedbackButton", self)
	send.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		feedback.open())
	feedback.finished.connect(func() -> void:
		if InputDevice.uses_buttons():
			send.grab_focus())
	button.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		credits.open())
	credits.closed.connect(func() -> void:
		if InputDevice.uses_buttons():
			button.grab_focus())


## "Wardrobe" under Credits and Feedback, its page over the screen; the hero by the Well wears
## what is worn there.
func _build_wardrobe() -> void:
	wardrobe = WardrobePanel.new()
	wardrobe.name = "WardrobePanel"
	add_child(wardrobe)
	var button := MenuWindow.button(tr("Wardrobe"), Fonts.BODY, 44)
	button.size_flags_horizontal = Control.SIZE_FILL
	(%RecordsPlaque as Control).get_parent().add_child(button)
	MenuWindow.expose(button, "WardrobeButton", self)
	button.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		wardrobe.open_with(content))
	wardrobe.closed.connect(func() -> void:
		dress_hero()
		if InputDevice.uses_buttons():
			button.grab_focus())
	dress_hero()


## The hero by the Well in the aura worn (none: none).
func dress_hero() -> void:
	if hero_aura and is_instance_valid(hero_aura):
		hero_aura.queue_free()
	hero_aura = AuraVfx.make(Wardrobe.aura(content), 30.0, 12.0)
	if hero_aura:
		hero_aura.wear_on_sprite(_hero, WardrobePanel.feet_of(content.player.frames, Vector2.ZERO))


## The gameplay statistics' questions, asked once the title has shown (Privacy.should_ask()).
func _build_consent() -> void:
	consent = ConsentDialog.new()
	consent.name = "ConsentDialog"
	add_child(consent)
	consent.finished.connect(func() -> void:
		if _play_after_consent:
			_play_after_consent = false
			play()
		elif InputDevice.uses_buttons():
			(%PlayButton as Button).grab_focus())
	if Privacy.ask_on_title and Privacy.should_ask():
		get_tree().create_timer(PRIVACY_DELAY).timeout.connect(ask_privacy)


## The online save's conflict (CloudSave): asked here, unless the account dialog is open (it asks
## itself).
func _build_cloud_conflict() -> void:
	cloud_conflict = CloudConflictDialog.new()
	cloud_conflict.name = "CloudConflict"
	add_child(cloud_conflict)
	cloud_conflict.finished.connect(func() -> void:
		if InputDevice.uses_buttons():
			(%PlayButton as Button).grab_focus())
	CloudSave.conflict_found.connect(ask_cloud_conflict)
	if CloudSave.state == CloudSave.Step.CONFLICT:
		ask_cloud_conflict.call_deferred()


func ask_cloud_conflict() -> void:
	if not is_inside_tree() or cloud_conflict.visible:
		return
	for dialog in get_tree().get_nodes_in_group(AccountDialog.GROUP):
		if (dialog as Control).is_visible_in_tree():
			return
	cloud_conflict.open()


## Asks the statistics' questions now, unless a panel is already open over the title.
func ask_privacy() -> void:
	if not is_inside_tree() or consent.visible or not Privacy.should_ask():
		return
	consent.ask()
	consent.move_to_front()


## The world counters' line, centered at the bottom over the Well, turning every
## title_line_seconds; the numbers are read (at most every few minutes: WorldStats.refresh()).
func _build_world_line() -> void:
	world_line = UiSkin.label("", Fonts.BODY, UiSkin.DIM)
	world_line.name = "WorldLine"
	world_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	world_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_KEEP_SIZE)
	world_line.anchor_left = 0.0
	world_line.anchor_right = 1.0
	world_line.offset_left = 0.0
	world_line.offset_right = 0.0
	world_line.offset_top = -WORLD_LINE_BOTTOM - Fonts.BODY * 2
	world_line.offset_bottom = -WORLD_LINE_BOTTOM
	world_line.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	world_line.hide()
	add_child(world_line)
	move_child(world_line, ($Margin as Control).get_index())  # (under the panels)
	world_line.owner = self
	world_line.unique_name_in_owner = true
	var turn := Timer.new()
	turn.wait_time = WorldStats.config.title_line_seconds
	turn.timeout.connect(func() -> void:
		_world_index += 1
		show_world_line(true))
	add_child(turn)
	turn.start()
	WorldStats.changed.connect(show_world_line)
	show_world_line()
	WorldStats.refresh()


## The line for the counter shown now (hidden when none is known: offline, no choice, no key).
## `fade`: the next counter comes in from the dark.
func show_world_line(fade: bool = false) -> void:
	var lines := WorldStats.title_lines()
	world_line.visible = not lines.is_empty()
	if lines.is_empty():
		return
	world_line.text = lines[_world_index % lines.size()]
	if fade and lines.size() > 1:
		world_line.modulate.a = 0.0
		create_tween().tween_property(world_line, "modulate:a", 1.0, 0.8)


## The remote settings' notes: the event's plaque in the records' column under Credits (the
## left column has no room for it on a phone once Resume shows), the message of the day in the
## tagline's place. The title screen is a safe point: what was read applies now
## (RemoteConfig.at_title()), and is read again if old.
func _build_remote_notes() -> void:
	event_plaque = PanelContainer.new()
	event_plaque.name = "EventPlaque"
	var style := MenuWindow.strip_style().duplicate() as StyleBoxTexture
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 14
	event_plaque.add_theme_stylebox_override("panel", style)
	event_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(%RecordsPlaque as Control).get_parent().add_child(event_plaque)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	event_plaque.add_child(lines)
	event_title = UiSkin.label("", Fonts.BODY, UiSkin.GOLD, true)
	event_title.name = "EventTitle"
	lines.add_child(event_title)
	event_details = UiSkin.label("", Fonts.SMALL, UiSkin.TEXT, true)
	event_details.name = "EventDetails"
	lines.add_child(event_details)
	message_line = UiSkin.label("", Fonts.BODY, UiSkin.GOLD, true)
	message_line.name = "MessageLine"
	message_line.custom_minimum_size.x = 680  # (the subtitle's width)
	message_line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	message_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# In the tagline's place while there is one (at most two lines, like it): the left column has
	# no room for one more line on a phone once Resume shows.
	var subtitle: Control = %Subtitle
	subtitle.get_parent().add_child(message_line)
	subtitle.get_parent().move_child(message_line, subtitle.get_index() + 1)
	RemoteConfig.applied.connect(show_remote_notes)
	# Checked again while the title stays open: an event that ends meanwhile leaves (a run started
	# after its end gets nothing of it: RemoteConfig.event_info() reads the clock at the start).
	var refresh := Timer.new()
	refresh.name = "RemoteNotesTimer"
	refresh.wait_time = RemoteConfig.config.title_refresh_seconds
	refresh.timeout.connect(show_remote_notes)
	add_child(refresh)
	refresh.start()
	show_remote_notes()
	RemoteConfig.at_title()


## Fills the notes from the remote settings in use (RemoteConfig.active), at the title's show,
## when a read applies and every RemoteConfigDef.title_refresh_seconds: the plaque hides once the
## event's end (event_ends) has passed.
func show_remote_notes() -> void:
	if event_plaque == null or not is_inside_tree():
		return
	var event := RemoteConfig.event_info()
	event_plaque.visible = not event.is_empty()
	if not event.is_empty():
		event_title.text = str(event.name)
		var details := PackedStringArray()
		if float(event.souls) > 1.0:
			details.append(tr("+%d%% souls each run") % roundi((float(event.souls) - 1.0) * 100.0))
		var boosted := DailyRun.twist(content, event.floor_event as StringName)
		if boosted and float(event.weight) > 1.0:
			details.append(tr("More floors with: %s") % tr(boosted.display_name))
		details.append(_time_left(int(event.ends) - RemoteConfig.now()))
		event_details.text = "\n".join(details)
	var message := RemoteConfig.message()
	message_line.visible = not message.is_empty()
	message_line.text = message
	(%Subtitle as Control).visible = message.is_empty()


## "3 days left", "5 hours left", "Ends within the hour".
func _time_left(seconds: int) -> String:
	var hours := floori(seconds / 3600.0)
	if hours >= 48:
		return tr("%d days left") % floori(hours / 24.0)
	if hours >= 2:
		return tr("%d hours left") % hours
	return tr("Ends within the hour")


## A small plaque on the Shrine button's corner when an upgrade can be bought.
func _build_shrine_badge() -> void:
	var button: Button = %ShrineButton
	_shrine_badge = MenuWindow.badge(tr("Souls to offer"), Fonts.BODY, MenuWindow.SOULS)
	# Its right edge just past the button's, over the top edge (it grows to the left).
	_shrine_badge.anchor_left = 1.0
	_shrine_badge.anchor_right = 1.0
	_shrine_badge.offset_left = 10.0
	_shrine_badge.offset_right = 10.0
	_shrine_badge.offset_top = -12.0
	_shrine_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	button.add_child(_shrine_badge)


## "Daily descent" (practice once played today), the same dungeon for everyone with the day's
## weapon and relic, and the score: today's (or "your first try counts"), best, streak.
func _refresh_daily() -> void:
	var day := DailyRun.today()
	var played := Profile.daily_played(day)
	_daily_title.text = tr("The Dawn Knell")
	_daily_text.text = tr("Tolled today: %d points") % Profile.daily_score if played else tr("The bell tolls: one descent, the same for all")


func _refresh() -> void:
	_refresh_daily()
	_refresh_keeper()
	_shrine_badge.visible = content.soul_tree != null and content.soul_tree.nodes.any(func(n: SoulNodeDef) -> bool: return Profile.can_buy_node(n))
	if _shrine_badge.visible and hint_box and not hint_box.visible and not _shrine.visible:
		show_menu_hint.call_deferred(&"menu_souls")
	for child in _records.get_children():
		_records.remove_child(child)
		child.queue_free()
	var difficulty := content.get_difficulty(Profile.difficulty)
	_record(tr("%d souls") % Profile.souls, tr("to spend"), MenuWindow.SOULS)
	_record(tr("Runs"), str(Profile.runs))
	_record(tr("Victories"), str(Profile.victories))
	_record(tr("Deepest floor"), str(Profile.best_depth))
	_record(tr("Difficulty"), difficulty.shown_name() if difficulty else tr("Keeper"),
		difficulty.color if difficulty else UiSkin.TEXT)


## One record on the plaque: a word, and its value on the right.
func _record(first: String, second: String, color: Color = UiSkin.TEXT) -> void:
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 18)
	var is_souls := color == MenuWindow.SOULS
	var word := UiSkin.label(first, Fonts.BODY, color if is_souls else UiSkin.DIM)
	word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pair.add_child(word)
	var value := UiSkin.label(second, Fonts.BODY, UiSkin.DIM if is_souls else color)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pair.add_child(value)
	_records.add_child(pair)


## A tutorial hint of the title screen, once ever (and only with the hints on in the options).
## Returns whether it showed.
func show_menu_hint(id: StringName) -> bool:
	if not Settings.tutorial_hints or Profile.has_seen_hint(id) or content.tutorial == null:
		return false
	var hint := content.tutorial.hint(id)
	if hint == null:
		return false
	var at := Rect2()
	if hint.target != &"" and has_node("%" + String(hint.target)):
		at = (get_node("%" + String(hint.target)) as Control).get_global_rect()
	hint_box.show_hint(hint, at)
	Profile.mark_hint(id)
	return true


## The phone's back button: closes what is open, or leaves the game.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not back():
		get_tree().quit()


## Escape or a gamepad's B: closes what is open (on a computer, the title stays).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and back():
		get_viewport().set_input_as_handled()


## Closes the panel on top (a hint first); false if none was open.
func back() -> bool:
	if hint_box and hint_box.visible:
		hint_box.hide_hint()
		return true
	if talk and talk.visible:
		talk.close()
		return true
	if cloud_conflict and cloud_conflict.visible:
		return true  # (a choice must be made)
	var options: OptionsPanel = %OptionsPanel
	if consent and consent.visible:
		consent.back()
	elif feedback and feedback.visible:
		feedback.back()
	elif credits and credits.visible:
		credits.back()
	elif wardrobe and wardrobe.visible:
		wardrobe.back()
	elif leaderboards and leaderboards.visible:
		leaderboards.back()
	elif options.visible:
		options.close()
	elif _shrine.visible:
		_shrine.close()
	elif oath_panel and oath_panel.visible:
		oath_panel.hide()
	elif daily_dialog and daily_dialog.visible:
		daily_dialog.back()
	elif (%CodexPanel as Control).visible:
		(%CodexPanel as CodexPanel).back()
	elif (%DifficultyPanel as Control).visible:
		(%DifficultyPanel as Control).hide()
	else:
		return false
	return true
