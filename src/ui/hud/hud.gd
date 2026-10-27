class_name Hud
extends CanvasLayer
## In-game overlay: bars, stats, messages and the controls. On touch, the joystick and the round
## buttons; on a keyboard or a gamepad (InputDevice), those are put away for the ActionBar (the
## same actions as compact slots with their keys) and the bag, pause, map and perk buttons show
## their key in a corner (PromptGlyph). The mouse fights with MouseControls.

signal inventory_requested
signal pause_requested
## The DBG button (debug builds only).
signal debug_requested
## The perk button: the player wants to make the waiting perk choices.
signal offers_requested

const BAG_ICON: Texture2D = preload("res://assets/ui/icons/bag.png")
## Room kept on each side of a banner's text (UI pixels).
const BANNER_MARGIN := 40.0
## The widest a banner's text may be at Fonts.HUGE (UI pixels): the space between the stats on
## the left and the map on the right.
const BANNER_WIDTH := 1000.0

var _player: Player
var _world: World
var _banner_tween: Tween
var _souls_tween: Tween
var _seal_tween: Tween
var _toasts: Array[String] = []
var _split_tween: Tween
## The run time's text on screen (rebuilt only when it changes).
var _time_text := ""
## What the belt buttons and the attack button show (_process() sets them again only when the
## belt or the weapon changed: docs/performance.md), and for which hero.
var _belt_shown: Array[ItemDef] = [null, null, null]
var _belt_counts := PackedInt32Array([0, 0, 0])
var _belt_shown_for: Player
var _weapon_shown: WeaponDef
## The temperature last shown (_refresh_temperature()): its value, the extreme's blink, the
## overlay's size; NAN: show it again.
var _temp_shown := Vector4(NAN, NAN, NAN, NAN)
## The note on screen (its fade in, wait and fade out), stopped when a banner comes up.
var _toast_tween: Tween
var _toast_busy := false
## The trial of the Threshold's counters (see bind_threshold()).
var _threshold_hud: ThresholdHud
## The Deeps' name, gift and arrow (see bind_abyss()).
var _abyss_hud: AbyssHud
## Who put the floor's widgets away (&"threshold", &"abyss": they nest) -> the widgets it hid,
## to show again when it is over (the boss bar, the map...).
var _put_away := {}
## A word, a space, a number: the space becomes unbreakable on the info line.
static var _word_and_number := RegEx.create_from_string("(\\S) (\\d)")

@onready var _hp_bar: StatBar = %HpBar
@onready var _xp_bar: StatBar = %XpBar
## Shown while the hero is cold or hot (BodyTemperature).
@onready var _temp_bar: StatBar = %TempBar
## Frost (or a burning haze) creeping in from the screen's edges.
@onready var _temp_overlay: ColorRect = %TemperatureOverlay
@onready var _info_label: Label = %InfoLabel
@onready var _souls_label: Label = %SoulsLabel
## Under the minimap: kills the stairs' seal still wants, then "Stairs open".
@onready var _seal_label: Label = %SealLabel
@onready var _depth_banner: Label = %DepthBanner
@onready var _message_log: MessageLog = %MessageLog
@onready var _attack_button: ActionButton = %AttackButton
## One button per belt slot (potions, bombs...); empty slots are hidden.
@onready var _belt_buttons: Array[ActionButton] = [%QuickItemButton, %Belt2Button, %Belt3Button]
@onready var _skill_buttons: Array[ActionButton] = [%Skill1Button, %Skill2Button, %Skill3Button, %Skill4Button]
@onready var _vignette: DamageVignette = %DamageVignette
@onready var _perk_tray: PerkTray = %PerkTray
@onready var _boss_bar: BossBar = %BossBar
@onready var _minimap: Minimap = %Minimap
@onready var _full_map: Minimap = %FullMap
## Under the map during a pact's fight: its rule and how it holds (built in code).
var pact_line := PactLine.new()
## The floor's room trial and its objective (in the pact line's place: never both on a floor).
var trial_line := TrialLine.new()
## Loot left on the ground (auto loot, a full bag) with its Take button (built in code).
var loot_prompt := LootPrompt.new()
## Left of the map while perk choices wait: their count, a glow (built in code).
var offers_button := OffersButton.new()
## Above the skills while the hero stands by something to use (built in code).
var interact_button := InteractButton.new()
## The perk choices the button counts (bind_offers()).
var _offers: OfferQueue
## During the trial of the Threshold the perk and Interact buttons are put away.
var _in_trial := false
## The fight's controls on a keyboard or a gamepad, mirroring the touch buttons (built in code).
var action_bar := ActionBar.new()
## Clicks in the fight (built in code).
var mouse_controls := MouseControls.new()
## On the Bag button while a compartment of the bag is full (built in code).
var bag_full_mark := BagFullMark.new()


func _ready() -> void:
	%BagButton.pressed.connect(func() -> void: inventory_requested.emit())
	%BagButton.icon = BAG_ICON
	%BagButton.add_child(bag_full_mark)
	%PauseButton.pressed.connect(func() -> void: pause_requested.emit())
	if DebugPanel.is_available():
		_add_debug_button()
	# Tap the minimap for the whole floor, tap again to close it.
	_minimap.tapped.connect(func() -> void: _full_map.visible = not _full_map.visible)
	_full_map.tapped.connect(func() -> void: _full_map.hide())
	Settings.changed.connect(_apply_settings)
	Events.achievement_unlocked.connect(func(achievement: AchievementDef) -> void:
		toast(tr("Achievement: %s  (+%d souls)") % [tr(achievement.display_name), achievement.reward_souls]))
	Events.bestiary_rank_reached.connect(func(monster: MonsterDef, rank: int, souls: int) -> void:
		var rules := _player.world.bestiary_rules() if _player and _player.world else null
		toast(tr("Bestiary: %s, %s  (+%d souls)") % [tr(monster.display_name), Bestiary.rank_name(rank, rules) if rules else str(rank), souls]))
	Events.hunt_challenge_done.connect(func(monster: MonsterDef, challenge: HuntChallenge) -> void:
		toast(tr("Challenge done: %s  (+%d souls)") % [challenge.describe(monster), challenge.souls]))
	Events.quest_completed.connect(func(quest: Dictionary) -> void:
		var done := tr("Daily quest done: %s  (+%d souls)") if (quest.def as QuestDef).period == QuestDef.Period.DAILY else tr("Weekly quest done: %s  (+%d souls)")
		toast(done % [QuestBoard.text(quest), quest.reward]))
	# An ambush springs: its banner (the HUD listens itself: gameplay only tells, Events).
	Events.ambush_started.connect(func(_room: AmbushRoom) -> void: show_banner(tr("Ambush!"), Palette.DANGER))
	# A cinematic (a warden's story) takes the screen: the HUD steps aside until it is over.
	Events.cinematic_started.connect(func() -> void: visible = false)
	Events.cinematic_finished.connect(func() -> void: visible = true)
	_apply_settings()
	pact_line.hud = self
	add_child(pact_line)
	trial_line.hud = self
	add_child(trial_line)
	loot_prompt.hud = self
	add_child(loot_prompt)
	_add_offers_button()
	_add_interact_button()
	_add_action_bar()
	_add_key_badges()
	mouse_controls.name = "MouseControls"
	add_child(mouse_controls)
	InputDevice.changed.connect(_apply_device)
	_apply_device()
	Events.depth_changed.connect(_on_depth_changed)
	_depth_banner.modulate.a = 0.0


## Dev builds: a DBG button left of the pause button, wherever the pause button really is (the
## theme's margins make both wider than their places, and they grow to the left: placed by the
## numbers, DBG sat under the pause button).
func _add_debug_button() -> void:
	var pause := %PauseButton as Button
	var button := Button.new()
	button.name = "DebugButton"
	button.text = "DBG"
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", Fonts.BODY)
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	button.offset_top = pause.offset_top
	button.offset_bottom = pause.offset_bottom
	var place := func() -> void:
		var right := pause.position.x - pause.get_parent_area_size().x - 8.0
		button.offset_right = right
		button.offset_left = right - 72.0
	pause.item_rect_changed.connect(place)
	place.call()
	button.modulate = Color(1, 1, 1, 0.75)
	button.pressed.connect(func() -> void: debug_requested.emit())
	add_child(button)


## The perk button, left of the minimap, under the pause button: in thumb's reach on the right,
## away from the joystick and the fight's buttons.
func _add_offers_button() -> void:
	offers_button.name = "OffersButton"
	offers_button.anchor_left = 1.0
	offers_button.anchor_right = 1.0
	offers_button.offset_left = -326.0
	offers_button.offset_right = -326.0 + OffersButton.SIZE
	offers_button.offset_top = 92.0
	offers_button.offset_bottom = 92.0 + OffersButton.SIZE
	offers_button.pressed.connect(func() -> void: offers_requested.emit())
	add_child(offers_button)
	move_child(offers_button, _minimap.get_index())  # under the full map
	offers_button.owner = self  # the tutorial points at it (hint_target())
	offers_button.unique_name_in_owner = true


## The Interact button, above the skills (left of the third one): the thumb on the attack button
## reaches it, and it never covers a skill.
func _add_interact_button() -> void:
	interact_button.name = "InteractButton"
	interact_button.position = Vector2(-262, -372)
	%Controls.add_child(interact_button)
	interact_button.owner = self
	interact_button.unique_name_in_owner = true


## The fight's controls for keys and gamepads, low in the middle: the touch buttons' twins.
func _add_action_bar() -> void:
	var buttons: Array[ActionButton] = [_attack_button]
	buttons.append_array(_skill_buttons)
	buttons.append_array(_belt_buttons)
	action_bar.setup(buttons, 1 + _skill_buttons.size(), interact_button)
	add_child(action_bar)
	move_child(action_bar, (%Controls as Control).get_index())
	action_bar.owner = self
	action_bar.unique_name_in_owner = true


## The keys of the buttons a keyboard or a gamepad can also use, on a corner of each (hidden on
## touch): the bag, pause, the map and the perk button.
func _add_key_badges() -> void:
	for pair: Array in [[%BagButton, &"inventory"], [%PauseButton, &"pause"], [_minimap, &"map"], [offers_button, &"offers"]]:
		# Over the middle of the control's top edge (the map: its top left corner); never over a
		# neighbour.
		PromptGlyph.badge(pair[0], pair[1], PromptGlyph.Place.CORNER if pair[0] == _minimap else PromptGlyph.Place.TOP)


## Touch: the joystick and the round buttons. Keys or a gamepad: the action bar instead.
func _apply_device() -> void:
	var touch := InputDevice.uses_touch()
	(%Controls as Control).visible = touch
	(%Joystick as Control).visible = touch
	action_bar.visible = not touch


## Whether the touch controls are on screen (false with keys or a gamepad).
func touch_controls_shown() -> bool:
	return (%Controls as Control).visible


## The map key: the whole floor, or back to the fight.
func toggle_full_map() -> void:
	if _minimap.visible:
		_full_map.visible = not _full_map.visible


## Interact on loot left on the ground, with nothing else in reach: takes it (like its button).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and loot_prompt.visible and not interact_button.visible:
		loot_prompt.press_take()
		get_viewport().set_input_as_handled()


## The perk choices waiting: the button shows how many.
func bind_offers(offers: OfferQueue) -> void:
	_offers = offers
	offers.changed.connect(_refresh_offers)
	_refresh_offers()


func _refresh_offers() -> void:
	offers_button.count = 0 if _offers == null or _in_trial else _offers.size()


## What the Interact button would use: shown by it, hidden when nothing is in reach.
func bind_interactor(interactor: Interactor) -> void:
	interactor.focus_changed.connect(func(target: Interactable) -> void:
		interact_button.show_for(null if _in_trial else target))


## Size of the touch controls (Options). They grow from their corner of the screen.
func _apply_settings() -> void:
	(%Controls as Control).scale = Vector2.ONE * Settings.controls_scale
	(%Joystick as TouchJoystick).max_distance = TouchJoystick.BASE_DISTANCE * Settings.controls_scale
	(%Joystick as TouchJoystick).fixed = Settings.fixed_joystick


## The floor shown on the minimap.
func bind_world(world: World) -> void:
	_minimap.bind_world(world)
	_full_map.bind_world(world)
	if _world == world:
		return
	_world = world
	world.seal.changed.connect(_refresh_seal)
	world.seal.broken.connect(_on_seal_broken)
	_refresh_seal()


## The trial of the Threshold: its name, countdown and kills while it is on; the floor's map,
## seal and boss bar (and the bag, closed in there) put away until the hero is back.
func bind_threshold(threshold: Threshold) -> void:
	_threshold_hud = ThresholdHud.new()
	_threshold_hud.name = "ThresholdHud"
	_threshold_hud.threshold = threshold
	add_child(_threshold_hud)
	move_child(_threshold_hud, (%Toast as Control).get_index())  # under the toasts and banners
	# The tutorial points at the counters by name (hint_target()).
	_threshold_hud.counters().owner = self
	_threshold_hud.counters().unique_name_in_owner = true
	threshold.opened.connect(func(trial: ThresholdDef, needed: int, _seconds: float) -> void:
		_show_floor_widgets(false, &"threshold")
		_threshold_hud.open(trial, needed))
	threshold.progressed.connect(_threshold_hud.set_progress)
	threshold.ended.connect(func(won: bool) -> void:
		_threshold_hud.close()
		if won:
			toast(tr("You come back from the Threshold."))
		else:
			show_banner(tr("The knell has tolled"), Palette.DANGER))
	threshold.closed.connect(func(_won: bool) -> void:
		_threshold_hud.close()
		_show_floor_widgets(true, &"threshold"))


## The Deeps: their name and rule when the hero lands, then the way out's name, the dawn's gift
## and an arrow toward the door; the floor's map, seal and boss bar put away until he is back
## (the bag stays: down there is a fight like any other).
func bind_abyss(abyss: Abyss) -> void:
	_abyss_hud = AbyssHud.new()
	_abyss_hud.name = "AbyssHud"
	_abyss_hud.abyss = abyss
	add_child(_abyss_hud)
	move_child(_abyss_hud, (%Toast as Control).get_index())  # under the toasts and banners
	# The tutorial points at the way out's name by name (hint_target()).
	_abyss_hud.banner().owner = self
	_abyss_hud.banner().unique_name_in_owner = true
	abyss.opened.connect(func(def: AbyssDef) -> void:
		_show_floor_widgets(false, &"abyss")
		_abyss_hud.open(def))
	abyss.ended.connect(func(_escaped: bool) -> void:
		_abyss_hud.close()
		toast(tr("You climb back into the light.")))
	abyss.closed.connect(func(_escaped: bool) -> void:
		_abyss_hud.close()
		_show_floor_widgets(true, &"abyss"))


## The floor's widgets put away (`shown` false) or back (true) for `who` (the Threshold: also the
## bag, the perk and Interact buttons; the Deeps: the floor's map, seal and boss bar). Each puts
## back only what it put away, so the Threshold opening from the Deeps nests.
func _show_floor_widgets(shown: bool, who: StringName) -> void:
	if not shown and not _put_away.has(who):
		var widgets: Array[Control] = [_minimap, _seal_label, _boss_bar, %SplitLabel]
		if who == &"threshold":
			widgets.append(%BagButton)
		var hidden: Array[Control] = []
		for widget in widgets:
			if widget.visible:
				hidden.append(widget)
				widget.hide()
		_put_away[who] = hidden
		_full_map.hide()
	elif shown and _put_away.has(who):
		for widget: Control in _put_away[who]:
			if is_instance_valid(widget):
				widget.show()
		_put_away.erase(who)
		if _put_away.is_empty() and _world:
			_refresh_seal()
	_in_trial = _put_away.has(&"threshold")
	if _in_trial:
		interact_button.show_for(null)
	_refresh_offers()


func _refresh_seal() -> void:
	var seal := _world.seal
	_seal_label.visible = seal.needed > 0 or _world.arena == null
	if seal.is_sealed():
		_seal_label.text = tr("Seal  %d / %d") % [seal.kills, seal.needed]
		_seal_label.add_theme_color_override("font_color", Palette.SEAL)
	else:
		_seal_label.text = tr("Stairs open")
		_seal_label.add_theme_color_override("font_color", Palette.GOLD)


func _on_seal_broken() -> void:
	show_banner(tr("The stairs are open"), Palette.GOLD)
	if _seal_tween:
		_seal_tween.kill()
	_seal_label.pivot_offset = _seal_label.size * Vector2(1.0, 0.5)
	_seal_label.scale = Vector2.ONE * 1.4
	_seal_tween = create_tween()
	_seal_tween.tween_property(_seal_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)


func bind_player(player: Player) -> void:
	if _player:
		_player.health_changed.disconnect(_on_health_changed)
		_player.health_changed.disconnect(_vignette.on_health_changed)
		_player.stats_changed.disconnect(_refresh_info)
		_player.xp_changed.disconnect(_on_xp_changed)
		_player.equipment.changed.disconnect(_refresh_info)
		_player.skills_changed.disconnect(_refresh_skill_buttons)
		_player.gold_changed.disconnect(_on_gold_changed)
		_player.perks.synergy_awakened.disconnect(_on_synergy_awakened)
	_player = player
	_weapon_shown = null
	_temp_shown = Vector4(NAN, NAN, NAN, NAN)
	loot_prompt.player = player
	bag_full_mark.watch(player.inventory)
	_player.health_changed.connect(_on_health_changed)
	_vignette.reset()
	_player.health_changed.connect(_vignette.on_health_changed)
	_player.stats_changed.connect(_refresh_info)
	_player.xp_changed.connect(_on_xp_changed)
	_player.equipment.changed.connect(_refresh_info)
	_player.skills_changed.connect(_refresh_skill_buttons)
	_player.gold_changed.connect(_on_gold_changed)
	_player.perks.synergy_awakened.connect(_on_synergy_awakened)
	_on_gold_changed(player.gold)
	_message_log.clear()
	_perk_tray.bind(player.perks)
	_boss_bar.hide_now()
	_full_map.hide()

	_refresh_skill_buttons()
	_on_health_changed(player.hp, player.get_max_hp())
	_on_xp_changed(player.xp, player.xp_to_next_level(), player.level)
	_refresh_info()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_temp_shown = Vector4(NAN, NAN, NAN, NAN)  # (its words, in the new language)


func _process(_delta: float) -> void:
	if _player == null:
		return
	_refresh_temperature()
	for i in _skill_buttons.size():
		if _skill_buttons[i].visible:
			_skill_buttons[i].cooldown_ratio = _player.skills.cooldown_ratio(i)
	for i in _belt_buttons.size():
		var item := _player.belt.item_at(i)
		var count := _player.belt.count_at(i) if item else 0
		if item == _belt_shown[i] and count == _belt_counts[i] and _belt_shown_for == _player:
			continue  # (as it was: nothing to set again)
		_belt_shown[i] = item
		_belt_counts[i] = count
		var button := _belt_buttons[i]
		button.visible = item != null
		if item:
			button.icon = item.icon
			button.icon_tint = item.icon_tint
			button.label = item.glyph
			button.color = item.color
			button.counter = count
	_belt_shown_for = _player
	var weapon := _player.get_weapon()
	if weapon != _weapon_shown or weapon == null:
		_weapon_shown = weapon
		_attack_button.icon = weapon.icon if weapon else null
		_attack_button.icon_tint = weapon.icon_tint if weapon else Color.WHITE
		_attack_button.label = weapon.glyph if weapon else "-"
	# The charge on the button too (the gauge at the hero's feet may be under a thumb).
	var charging := _player.charge.is_charging() and weapon != null and weapon.charged != null
	_attack_button.charge_ratio = _player.charge.ratio if charging else 0.0
	_attack_button.charge_full = charging and _player.charge.is_full()
	if charging:
		var element := weapon.charged.element_for(weapon)
		_attack_button.charge_color = element.shade(0.25)
		_attack_button.charge_core = element.core()


## One button per skill slot; empty slots (no weapon skill, no spell learned) are hidden.
func _refresh_skill_buttons() -> void:
	for i in _skill_buttons.size():
		var button := _skill_buttons[i]
		var skill: SkillDef = _player.skills.skills[i] if i < _player.skills.skills.size() else null
		button.visible = skill != null
		if skill:
			button.label = tr(skill.short_label)
			button.icon = skill.icon
			button.color = skill.color


func _refresh_temperature() -> void:
	var temperature := _player.temperature
	var blink := 1.0 if temperature.is_extreme() and int(Time.get_ticks_msec() / 250.0) % 2 == 0 else 0.0
	var key := Vector4(temperature.value, blink, _temp_overlay.size.x, _temp_overlay.size.y)
	if key == _temp_shown:
		return  # (as it was: no text, no uniform set again)
	_temp_shown = key
	var shown := absf(temperature.value) >= 1.0
	_temp_bar.visible = shown
	var cold := clampf((-temperature.value - 15.0) / 85.0, 0.0, 1.0)
	var heat := clampf((temperature.value - 15.0) / 85.0, 0.0, 1.0)
	_temp_overlay.visible = cold > 0.0 or heat > 0.0
	if _temp_overlay.visible:
		var look := _temp_overlay.material as ShaderMaterial
		look.set_shader_parameter("cold", cold)
		look.set_shader_parameter("heat", heat)
		look.set_shader_parameter("aspect", _temp_overlay.size / _temp_overlay.size.y * 9.0)
	if not shown:
		return
	var is_cold := temperature.value < 0.0
	var label := (tr("Freezing!") if is_cold else tr("Burning up!")) if temperature.is_extreme() else (tr("Cold") if is_cold else tr("Hot"))
	_temp_bar.fill_color = BodyTemperature.COLD_COLOR if is_cold else BodyTemperature.HOT_COLOR
	if blink > 0.0:
		_temp_bar.fill_color = _temp_bar.fill_color.lightened(0.4)
	_temp_bar.set_values(absf(temperature.value), BodyTemperature.LIMIT, label)


func _on_health_changed(current: int, maximum: int) -> void:
	_hp_bar.set_values(current, maximum, "%d / %d" % [current, maximum])


func _on_xp_changed(xp: int, needed: int, level: int) -> void:
	_xp_bar.set_values(xp, needed, tr("Lv %d") % level)


func _refresh_info() -> void:
	if _player == null:
		return
	var stats := _player.get_stats()
	var weapon := _player.get_weapon()
	var difficulty := _player.world.difficulty if _player.world else null
	# One sentence each, with or without the difficulty in front (never glued pieces).
	var facts := {
		"difficulty": difficulty.shown_name() if difficulty else "",
		"depth": _player.world.depth if _player.world else 1,
		"damage": _player.get_power(),
		"armor": stats.defense,
		"weapon": tr(weapon.display_name) if weapon else tr("Bare hands"),
	}
	var template := tr("{difficulty}   Depth {depth}   Damage {damage}   Armor {armor}   {weapon}") if difficulty \
		else tr("Depth {depth}   Damage {damage}   Armor {armor}   {weapon}")
	var line := template.format(facts)
	# When the line wraps, a stat keeps its number ("Armor" never ends a line, its 0 on the next).
	_info_label.text = _word_and_number.sub(line, "$1\u00a0$2", true)


func _on_gold_changed(gold: int) -> void:
	(%GoldLabel as Label).text = tr("Gold %d") % gold


## Three of a family: its name across the screen, what it does in the log.
func _on_synergy_awakened(synergy: SynergyDef) -> void:
	show_banner(tr("%s awakens") % tr(synergy.display_name), synergy.color)
	Events.log_message(tr("%s awakens: %s") % [tr(synergy.display_name), tr(synergy.description)], synergy.color)


## A short note at the top of the screen (achievements...). Several wait their turn, and none
## comes up while a banner shows (a boss's name, its words): they never stack in the middle.
func toast(text: String) -> void:
	_toasts.append(text)
	if not _toast_busy:
		_next_toast()


func _next_toast() -> void:
	if _toasts.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	if _depth_banner.modulate.a > 0.05:
		# A banner is up (a boss' name, its words): the note waits under it, never over it.
		get_tree().create_timer(0.3, false).timeout.connect(_next_toast)
		return
	(%ToastLabel as Label).text = _toasts.pop_front()
	Sfx.play_ui(Sfx.bank.level_up, -6.0)
	var toast_panel: Control = %Toast
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_next_toast)


## A banner comes up while a note shows: the note steps aside and comes back after it.
func _yield_toast() -> void:
	var toast_panel: Control = %Toast
	if toast_panel.modulate.a <= 0.05 or _toast_tween == null or not _toast_tween.is_valid():
		return
	_toast_tween.kill()
	toast_panel.modulate.a = 0.0
	_toasts.push_front((%ToastLabel as Label).text)
	get_tree().create_timer(0.3, false).timeout.connect(_next_toast)


## Souls gathered this run (what the shrine will get). `pulse` when a new one arrives.
func set_souls(count: int, pulse: bool = false) -> void:
	_souls_label.text = tr("Souls %d") % count
	if not pulse:
		return
	if _souls_tween:
		_souls_tween.kill()
	_souls_label.pivot_offset = _souls_label.size * Vector2(0.0, 0.5)
	_souls_label.scale = Vector2.ONE * 1.25
	_souls_tween = create_tween()
	_souls_tween.tween_property(_souls_label, "scale", Vector2.ONE, 0.2)


## Big centered text that fades out (floor names, boss names, a warden's last words...). A text
## too wide at Fonts.HUGE (a sentence: wider than BANNER_WIDTH or the screen) comes at TITLE,
## across the screen (banner_room()), and wraps to a second line if it is wider still.
func show_banner(text: String, color: Color = Palette.GOLD) -> void:
	_yield_toast()
	_depth_banner.text = text
	var font_size := Fonts.HUGE
	if Fonts.MAIN.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fonts.HUGE).x > banner_room(Fonts.HUGE):
		font_size = Fonts.TITLE
	var room := banner_room(font_size)
	_depth_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if font_size == Fonts.TITLE else TextServer.AUTOWRAP_OFF
	_depth_banner.offset_left = -room * 0.5
	_depth_banner.offset_right = room * 0.5
	_depth_banner.add_theme_font_size_override("font_size", font_size)
	_depth_banner.add_theme_constant_override("outline_size", Fonts.outline_size(font_size))
	_depth_banner.add_theme_color_override("font_color", color)
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_depth_banner.modulate.a = 1.0
	_banner_tween.tween_interval(1.4)
	_banner_tween.tween_property(_depth_banner, "modulate:a", 0.0, 0.6)


## How wide a banner's text may be at `font_size` (UI pixels): a name at HUGE between the stats
## and the map (BANNER_WIDTH), a sentence at TITLE across the screen (it shows a moment, over all).
func banner_room(font_size: int) -> float:
	var screen := _depth_banner.get_viewport_rect().size.x - 2.0 * BANNER_MARGIN
	return minf(screen, BANNER_WIDTH) if font_size == Fonts.HUGE else screen


## The run's time under the map (Settings.run_timer). Gold once the run is won (that time stays).
func show_run_time(seconds: float, finished: bool) -> void:
	var label := %TimerLabel as Label
	label.visible = Settings.run_timer
	if not label.visible:
		return
	var text := TimeText.of(seconds, 2 if finished else 1)
	if text == _time_text:
		return
	_time_text = text
	label.text = text
	label.add_theme_color_override("font_color", Palette.GOLD if finished else Color(1, 1, 1, 0.85))


## A floor done: its time, and how far ahead (green) or behind (red) the record run it is.
## `ahead`: seconds against the record's split (NAN: no record to race).
func show_split(depth: int, seconds: float, ahead: float) -> void:
	if not Settings.run_timer:
		return
	var label := %SplitLabel as Label
	var text := tr("Floor %d  %s") % [depth, TimeText.of(seconds, 1)]
	var color := Color(1, 1, 1, 0.85)
	if not is_nan(ahead):
		text = tr("Floor {floor}  {time}  {delta}").format({ "floor": depth, "time": TimeText.of(seconds, 1), "delta": TimeText.delta(ahead) })
		color = Palette.HEAL if ahead <= 0.0 else Palette.DANGER
	label.text = text
	label.add_theme_color_override("font_color", color)
	if _split_tween:
		_split_tween.kill()
	label.modulate.a = 1.0
	_split_tween = create_tween()
	_split_tween.tween_interval(4.0)
	_split_tween.tween_property(label, "modulate:a", 0.0, 0.6)


func split_text() -> String:
	return (%SplitLabel as Label).text if (%SplitLabel as Label).modulate.a > 0.0 else ""


## A big text is on screen (hints wait for it to go).
func is_banner_showing() -> bool:
	return _depth_banner.modulate.a > 0.05 or (_threshold_hud != null and _threshold_hud.is_card_showing()) \
		or (_abyss_hud != null and _abyss_hud.is_card_showing())


func is_boss_bar_showing() -> bool:
	return _boss_bar.visible


## Where a control of the HUD is on screen (unique name: "AttackButton", "Joystick",
## "SealLabel"...), for the tutorial to point at. Empty if it isn't there or is hidden.
func hint_target(control_name: StringName) -> Rect2:
	if not touch_controls_shown():
		# Keys or a gamepad: the action bar's twin of a touch button (none for the joystick).
		var slot := action_bar.slot_for(control_name)
		if slot:
			return slot.get_global_rect()
		if control_name == &"Joystick":
			return Rect2()
	var node := get_node_or_null("%" + String(control_name))
	if node == null or not node.is_visible_in_tree():
		return Rect2()
	if node is TouchJoystick:
		var stick := node as TouchJoystick
		var reach := stick.max_distance
		return Rect2(stick.get_global_rect().position + stick.home() - Vector2.ONE * reach, Vector2.ONE * reach * 2.0)
	if node is ActionButton:
		var button := node as ActionButton
		var radius := button.radius * button.get_global_transform().get_scale().x
		return Rect2(button.global_position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	if node is Control:
		return (node as Control).get_global_rect()
	return Rect2()


func _on_depth_changed(depth: int) -> void:
	_refresh_info()
	show_banner(tr("Depth %d") % depth)
