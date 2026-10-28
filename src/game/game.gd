class_name Game
extends Node
## Runs a play session: creates the hero, moves between floors, offers perks and relics, pauses
## for menus and handles the end of the run. Main scene of the project.
## The run itself is a RunState; the profile's records follow it in RunRecords; perk choices
## wait in an OfferQueue (a level up's until the player opens them: open_offers()); the panels
## live in GameMenus; the merchant, the forge, encounters and pacts open through the Interactor
## (the HUD's Interact button), never by walking up to them.
## The first runs start gently (FirstSteps); the Souls' Aid (AssistDef) follows the profile, and
## the pause menu may lower the run's difficulty (lower_difficulty()): both make the run aided
## (RunState.assisted: no records, no leaderboards). The end screen's Descend again starts the
## next descent at once (descend_again()).
## What the run says and shows (banners, toasts, the souls, the clock, the log's lines) is the
## RunAnnouncer's, listening to Events: the Game emits and keeps to the flow. Its debug entry
## points are GameDebug's (`debug`). Every floor is reached through transition_to_floor().

const PLAYER_SCENE := preload("res://src/entities/player/player.tscn")
const VILLAGE_SCENE := "res://src/village/village_hub.tscn"
const TITLE_SCENE := "res://src/ui/title/title_screen.tscn"
## Pause between the boss' death and the relic choice, to enjoy the explosions.
const RELIC_DELAY := 1.6
## Pause between the last form's death at the bottom of the Well and the choice of an ending
## (its death plays out: the mask crumbles, its keeper is set down).
const ENDING_DELAY := 2.8
## Seconds of fade to black when taking the stairs.
const FADE_TIME := 0.3

## Set by the title screen's Continue button: pick up the saved run instead of starting one.
static var resume_requested := false
## Set by the title screen's Daily button: today's daily run (DailyRun) instead of a normal one.
static var daily_requested := false
## The tests' seeds (the test runner's --seed, seed_runs()): each new run's world takes the next
## one instead of a random seed, so a failed test plays the same floors again. Null in the game.
static var _run_seeds: RandomNumberGenerator = null

@export var content: ContentDB
## Title cards on black (a new act, a curse). Tests turn them off to save time.
@export var show_act_cards := true

## Session lifetime is distinct from its current expedition and live hero.
var session := GameSession.new()
## Compatibility view for existing run systems while the RPG ownership is introduced.
var run: RunState:
	get: return session.expedition
var player: Player:
	get: return session.character
	set(value): session.character = value
## The facts of the run that just ended (the Vigil-Keeper's tale), null while it goes on.
var end_facts: RunFacts
var offers := OfferQueue.new()

## Shortcuts to the run.
var depth: int:
	get: return run.depth
	set(value): run.depth = value
var kills: int:
	get: return run.kills
	set(value): run.kills = value
var bosses_slain: int:
	get: return run.bosses_slain
	set(value): run.bosses_slain = value
var has_won: bool:
	get: return run.has_won
	set(value): run.has_won = value
var difficulty: DifficultyDef:
	get: return run.difficulty

## Between taking the stairs and the next floor showing: no menus, no saves, no second descent.
var _transitioning := false

@onready var world: World = $World
@onready var hud: Hud = $Hud
@onready var menus: GameMenus = $Menus
@onready var inventory_panel: InventoryPanel = $Menus/InventoryPanel
@onready var perk_panel: PerkChoicePanel = $Menus/PerkChoicePanel
@onready var game_over_panel: GameOverPanel = $Menus/GameOverPanel
@onready var pause_menu: PauseMenu = $Menus/PauseMenu
@onready var shop_panel: ShopPanel = $Menus/ShopPanel
@onready var encounter_panel: EncounterPanel = $Menus/EncounterPanel
@onready var screen_fx: ScreenEffects = $ScreenFx/Effects
@onready var ambience: Ambience = $Ambience
@onready var _fade: ColorRect = $Fade/Black
@onready var act_card: ActCard = $Fade/ActCard
@onready var curse_card: CurseCard = $Fade/CurseCard

var _records := RunRecords.new()
## The bestiary challenges (how monsters are slain).
var _hunt := HuntTracker.new()
## The tutorial's hints, shown in `hint_box` (above the HUD, under the menus).
var tutorial := Tutorial.new()
var hint_box := HintBox.new()
## The run's in-game time (speedruns).
var run_timer := RunTimer.new()
## The trial of the Threshold, where a second life (Phoenix Feather) takes the hero.
var threshold := Threshold.new()
## The Deeps, where a fall into a floor's hole takes the hero (AbyssDef).
var abyss := Abyss.new()
## The way to the hidden floor (its key, the sealed way, its boss' hoard).
var hidden := HiddenPassage.new()
## The hero took the hidden way: the next floor is the hidden one (same depth).
var _into_hidden := false
## The Interact button's brain: what the hero stands by, and using it.
var interactor := Interactor.new()
## A warden's story told as the hero walks into its arena (the World's storyteller).
var meeting := BossMeeting.new()
## Shows and says what the run does (Events -> the HUD and the log).
var announcer := RunAnnouncer.new()
## The debug entry points (the debug panel, the tests, the tools).
var debug := GameDebug.new(self)
## The player opened the perk choices (the HUD's perk button): they follow one another until
## none is left or one is put off. Otherwise only those that come up by themselves show (relics).
var choices := GameOffers.new()
## The souls and the record of a win at the bottom of the Well, kept for the victory screen
## shown once an ending is chosen.
var _ending_earned := 0
var _ending_record := false
## The first runs' gentle start on their first floor (decision 0010).
var first_steps := FirstSteps.new()


func _ready() -> void:
	if content.sounds:
		Sfx.bank = content.sounds
	_records.content = content
	add_child(_records)
	_hunt.content = content
	add_child(_hunt)
	_setup_tutorial()
	run_timer.name = "RunTimer"
	run_timer.is_counting = _is_clock_running
	add_child(run_timer)
	_setup_threshold()
	_setup_abyss()
	_setup_interactor()
	meeting.name = "BossMeeting"
	meeting.game = self
	meeting.narrative = content.narrative
	add_child(meeting)
	world.storyteller = meeting
	first_steps.name = "FirstSteps"
	add_child(first_steps)
	hidden.name = "HiddenPassage"
	hidden.game = self
	hidden.def = content.dungeon.hidden_floor
	add_child(hidden)  # (before the Game's own boss handler: its hoard is in the save)
	announcer.name = "RunAnnouncer"
	announcer.game = self
	announcer.hud = hud
	add_child(announcer)  # (before the Game's own Events: its lines come first, as they did)
	world.stairs_reached.connect(_on_stairs_reached)
	hud.bind_world(world)
	hud.inventory_requested.connect(open_inventory)
	hud.pause_requested.connect(open_pause_menu)
	hud.debug_requested.connect(open_debug)
	hud.offers_requested.connect(open_offers)
	hud.bind_offers(offers)
	if menus.debug:
		menus.debug.closed.connect(_on_menu_closed)
	choices.name = "Offers"
	choices.game = self
	add_child(choices)
	choices.bind_panel()
	_connect_menus()
	_connect_events()
	Profile.changed.connect(_follow_assist)
	var village := VillageExpedition.new()
	village.game = self
	add_child(village)
	var saved := RunSave.read() if resume_requested else {}
	var daily := daily_requested
	resume_requested = false
	daily_requested = false
	if saved.is_empty():
		start_run(daily)
	else:
		resume_run(saved)


func _connect_menus() -> void:
	pause_menu.content = content
	pause_menu.run_info = func() -> Dictionary: return FeedbackInfo.run(run, player, content, world.biome if world else null)
	inventory_panel.content = content
	pause_menu.resume_requested.connect(func() -> void:
		pause_menu.hide()
		_on_menu_closed())
	pause_menu.quit_requested.connect(func() -> void:
		_save_run()
		_records.report_left(true)
		_set_paused(false)
		Loader.go(VILLAGE_SCENE))
	pause_menu.abandon_requested.connect(func() -> void:
		pause_menu.hide()
		_set_paused(false)
		player.give_up())
	pause_menu.run_difficulty = func() -> DifficultyDef: return run.difficulty if run else null
	pause_menu.lower_options = _lower_options
	pause_menu.difficulty_lowered.connect(lower_difficulty)
	inventory_panel.closed.connect(_on_menu_closed)
	shop_panel.closed.connect(_on_menu_closed)
	menus.forge.closed.connect(_on_menu_closed)
	menus.pact.closed.connect(_on_menu_closed)
	menus.fragment.closed.connect(_on_menu_closed)
	encounter_panel.closed.connect(_on_menu_closed)
	game_over_panel.restart_requested.connect(return_to_village)
	game_over_panel.descend_requested.connect(descend_again)
	game_over_panel.continue_requested.connect(_on_continue_endless)
	game_over_panel.title_requested.connect(return_to_title)


func _connect_events() -> void:
	Events.shop_requested.connect(open_shop)
	Events.forge_requested.connect(open_forge)
	Events.encounter_requested.connect(open_encounter)
	Events.pact_requested.connect(open_pact)
	Events.fragment_requested.connect(open_fragment)
	Events.pact_ended.connect(_on_pact_ended)
	Events.trial_completed.connect(_on_trial_completed)
	Events.perk_offer_requested.connect(func(rarity: int, title: String, subtitle: String) -> void:
		_queue_offer(rarity as PerkDef.Rarity, content.player.perk_choices, title, subtitle))
	Events.boss_started.connect(_on_boss_started)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.boss_rising.connect(_on_boss_rising)
	Events.monster_killed.connect(func(monster: Monster) -> void:
		if monster.world == world and monster.def is BossDef and (monster.def as BossDef).next_boss:
			Sfx.stop_music(0.6))  # its music dies with it: silence while the next form rises
	menus.ending.chosen.connect(_on_ending_chosen)


# --- Runs --------------------------------------------------------------------

## The tests: every run from now on seeded from `value` (the runner gives each test its own),
## or random again (the game's way) with a negative value.
static func seed_runs(value: int) -> void:
	if value < 0:
		_run_seeds = null
		return
	_run_seeds = RandomNumberGenerator.new()
	_run_seeds.seed = value


## `daily`: today's daily run (DailyRun) instead of a normal one.
func start_run(daily: bool = false) -> void:
	_begin_run({}, daily)


## Picks up a run saved by RunSave: same depth (a new floor), the hero as saved.
func resume_run(saved: Dictionary) -> void:
	_begin_run(saved)


func _begin_run(saved: Dictionary, daily: bool = false) -> void:
	if run and run.has_won:
		_records.record_history()  # leaving a won run for a new one
	DebugCheats.reset()  # a new run plays the real rules (a debug run's profile is read back)
	threshold.abort()
	abyss.abort()  # (after the Threshold: it may have opened from the Deeps)
	end_facts = null
	_set_paused(false)
	_fade.color.a = 0.0
	menus.hide_all()
	inventory_panel.forget_run()  # the last run's new marks and tab
	offers.clear()
	choices.reset()
	_transitioning = false
	_into_hidden = false
	if player:
		player.get_parent().remove_child(player)
		player.queue_free()
	player = null
	world.player = null  # (the new floor is built before the new hero is placed: nobody on it)

	if _run_seeds:
		world.rng.seed = _run_seeds.randi()
	else:
		world.rng.randomize()
	var day := DailyRun.today() if daily and saved.is_empty() else -1
	if day >= 0:
		world.rng.seed = DailyRun.seed_of(day)  # the same bosses all day
	RemoteTuning.run_starting()  # (a safe point: the remote settings read meanwhile apply now, then wait)
	session.enter_expedition(RunState.create(content, saved, world.rng, day), world)
	if saved.is_empty():
		run.assisted = Profile.assist  # (a saved run keeps its own: RunState)
	var ticket := session.capture()
	world.tuning = run.tuning
	if day >= 0:
		run.daily_official = not Profile.daily_played(day)
		if run.daily_official:
			Profile.start_daily(day)
	world.difficulty = run.difficulty
	world.run_bosses = run.bosses
	world.luck = run.luck
	world.clear_floor()  # the last run's merchant must not pass its locked stock on
	world.floors_without_forge = int(saved.get("floors_without_forge", 0))
	world.kept_stock.clear()
	var saved_stock: Variant = saved.get("kept_stock", [])
	for saved_entry: Variant in saved_stock if saved_stock is Array else []:
		if not saved_entry is Dictionary:
			continue
		var item := LootRoller.from_data((saved_entry as Dictionary).get("item"))
		if item:
			world.kept_stock.append({ "item": item, "price": int((saved_entry as Dictionary).get("price", 1)), "locked": true })
	player = PLAYER_SCENE.instantiate() as Player
	player.setup(content.player)
	player.wear_aura(Wardrobe.aura(content))  # (the Wardrobe's: for the look alone)
	player.died.connect(_on_player_died)
	# A level up opens nothing: its choice waits behind the HUD's perk button.
	player.leveled_up.connect(func(level: int) -> void:
		_queue_offer(PerkDef.Rarity.COMMON, content.player.perk_choices, "Level %d!", "Choose an upgrade", true, level)  # i18n
		tutorial.cue(&"offer_waiting"))
	player.damaged.connect(func(damage: int) -> void:
		screen_fx.kick(clampf(float(damage) / player.get_max_hp() * 5.0, 0.3, 1.0)))
	content.unlocked_items = ShrineUpgrades.unlocked_items(content)
	if saved.is_empty():
		if not run.is_daily():
			run.oath = sworn_oath(content)
		ShrineUpgrades.apply_to(player, content, run.difficulty, run.oath, null if run.is_daily() else picked_weapon(content))
		if run.is_daily():
			_give_daily_start()
		Profile.count_run()
	else:
		player.load_state(saved.get("player", {}))
		offers.load_data(saved.get("offers", []))
		# Chests opened, stock bought, items taken... before quitting; nothing if another build
		# saved it (the same seed may lay another floor: it is laid fresh, said below).
		# (Saved after the bottom of the Well's fall, the run goes on past that floor: its block
		# is not this one's.)
		world.restore_spent({} if saved.get("boss_slain", false) else RunSave.floor_of(saved))
	# The tree's run rules and the oath's (gold, loot, the merchant, heals, crits, the minimap).
	world.boons = RunBoons.build(content, run.oath) if not run.is_daily() else RunBoons.new()
	player.healing_scale = world.boons.healing_scale
	player.crit_damage_bonus = world.boons.crit_damage_bonus
	_follow_assist()
	_records.bind(run, player)
	Events.run_started.emit(run, player)  # (whatever follows a whole run: the gameplay statistics)
	run_timer.run = run
	_hunt.bind(player, run)
	interactor.player = player
	hud.bind_player(player)
	tutorial.bind(player, world, hud)
	if show_act_cards:
		# Start on black: the first act's card, then the floor fades in.
		_fade.color.a = 1.0
		_set_paused(true)
		await transition_to_floor(not saved.is_empty(), false)  # (the offers left open: below)
		if not session.is_current(ticket):
			return
		create_tween().tween_method(_set_session_fade.bind(ticket), _fade.color.a, 0.0, FADE_TIME * 1.5)
	else:
		_enter_floor(not saved.is_empty())
	if RunSave.floor_outdated(saved):
		Events.floor_laid_anew.emit()
	tutorial.cue(&"run_start")
	if run.ending_due:
		# Won at the bottom, the ending not chosen yet: the souls were given at the win, and the
		# victory screen still says how many (all the run gave: souls are given only at its end).
		_offer_ending.call_deferred(run.souls_awarded, false)
		return
	_show_next_offer.call_deferred()  # choices left open in a saved run


## The run's time counts while playing and in the bag, the shop or a perk choice; not in the
## pause menu, nor while a floor loads (with its title cards), nor once the hero is dead.
func _is_clock_running() -> bool:
	return player != null and not player.is_dead and not _transitioning and not pause_menu.visible \
		and not game_over_panel.visible and not act_card.visible and not curse_card.visible


## The floor `floor_depth` is done: its split kept (RunState.split()), and shown.
func _split(floor_depth: int) -> void:
	Events.split_timed.emit(floor_depth, run.split(floor_depth))


func _setup_tutorial() -> void:
	tutorial.name = "Tutorial"
	tutorial.def = content.tutorial
	tutorial.box = hint_box
	tutorial.is_blocked = func() -> bool:
		return is_menu_open() or hud.is_banner_showing() or act_card.visible or curse_card.visible
	tutorial.hint_shown.connect(func(_hint: HintDef) -> void: hint_box.lowered = hud.is_boss_bar_showing())
	add_child(tutorial)
	var layer := CanvasLayer.new()
	layer.name = "Hints"
	layer.layer = 6  # above the HUD (5), under the menus (10)
	add_child(layer)
	hint_box.name = "HintBox"
	hint_box.top_room = hud.top_room
	hint_box.dismissed.connect(tutorial.dismiss)
	layer.add_child(hint_box)


func _setup_threshold() -> void:
	threshold.name = "Threshold"
	threshold.game = self
	add_child(threshold)
	hud.bind_threshold(threshold)
	threshold.opened.connect(func(_trial: ThresholdDef, _needed: int, _seconds: float) -> void:
		tutorial.cue(&"threshold"))
	threshold.closed.connect(func(won: bool) -> void:
		if won:
			_show_next_offer())


## The Deeps: a hole's fall on a floor takes the hero there (Abyss).
func _setup_abyss() -> void:
	abyss.name = "Abyss"
	abyss.game = self
	abyss.def = content.dungeon.abyss
	add_child(abyss)
	hud.bind_abyss(abyss)
	abyss.opened.connect(func(_def: AbyssDef) -> void: tutorial.cue(&"abyss"))
	abyss.closed.connect(func(escaped: bool) -> void:
		if escaped:
			_show_next_offer())


## The hero is somewhere menus must wait: the Threshold's trial, or on his way into or out of
## the Deeps.
func is_away() -> bool:
	return threshold.is_open() or abyss.is_passing()


func _setup_interactor() -> void:
	interactor.name = "Interactor"
	interactor.is_blocked = func() -> bool: return is_menu_open() or is_away()
	interactor.used.connect(func(_target: Interactable) -> void: tutorial.action(&"interacted"))
	add_child(interactor)
	hud.bind_interactor(interactor)


## Uses what the hero stands by (the merchant, the forge...), like the Interact button.
## False if nothing is in reach.
func interact() -> bool:
	return interactor.interact()


## The daily run's weapon and relic (the same for everyone that day).
func _give_daily_start() -> void:
	var weapon := DailyRun.weapon(content, run.daily_day)
	if weapon:
		player.equipment.equip(weapon)
	var relic := DailyRun.relic(content, run.daily_day)
	if relic:
		player.perks.add(relic)
	player.invalidate_stats()
	player.hp = player.get_max_hp()


## A profile with no run yet and no run saved (decision 0010): Play goes straight down the Well,
## Kagari and its choices waiting for the first return.
static func first_descent_due() -> bool:
	return Profile.runs == 0 and RunSave.read().is_empty()


## The first descent is on Keeper (ContentDB.default_difficulty), whatever an older profile held;
## never a Dawn Knell.
static func prepare_first_descent(content_db: ContentDB) -> void:
	daily_requested = false
	resume_requested = false
	VillageHub.daily_requested = false
	if content_db.default_difficulty and Profile.difficulty != content_db.default_difficulty.id:
		Profile.select_difficulty(content_db.default_difficulty)


## The oath chosen for the next run (Profile.oath), if its node was bought; null otherwise.
static func sworn_oath(content_db: ContentDB) -> OathDef:
	if Profile.oath == &"" or content_db.soul_tree == null:
		return null
	for oath in content_db.soul_tree.open_oaths():
		if oath.id == Profile.oath:
			return oath
	return null


## The weapon picked to start with (the Armory node), or null: none picked, or one its level
## doesn't offer (an older save, a reset tree), and the run starts with the usual one.
static func picked_weapon(content_db: ContentDB) -> WeaponDef:
	if Profile.starting_weapon == &"":
		return null
	for weapon in ShrineUpgrades.armory_weapons(content_db):
		if weapon.id == Profile.starting_weapon:
			return weapon
	return null


## Souls this run is worth so far (what the shrine gets when it ends).
func run_souls() -> int:
	return run.souls()


func _award_souls(won_now: bool) -> int:
	var earned := run.award_souls(won_now, content.ascensions.size())
	if run.daily_official and run.ranked():
		Profile.finish_daily(run.daily_day, DailyRun.score(run))  # (an aided Dawn Knell scores nothing)
	_records.check_achievements()
	_records.report_end()  # (the online leaderboards: Leaderboards)
	return earned


## The Souls' Aid as the profile has it now (the Options, title or pause): the hero takes its
## share less of each hit, and a run it is on in is aided for good (RunState.assisted).
func _follow_assist() -> void:
	if run == null or player == null or not is_instance_valid(player):
		return
	if Profile.assist:
		run.assisted = true
	player.aid = content.assist.resistance_after(Profile.assist_deaths) if Profile.assist and content.assist else 0.0


## The difficulties the pause menu may lower the run to (RunState.lower_difficulties()).
func _lower_options() -> Array[DifficultyDef]:
	var options: Array[DifficultyDef] = []
	if run:
		options = run.lower_difficulties(content)
	return options


## The pause menu's Difficulty (decision 0011): the run goes on at `lower` (RunState), aided from
## now on; the floor, its monsters and its light follow at once (World.lower_difficulty()), the
## next floors are built on it, and the save keeps it. False if `lower` isn't lower.
func lower_difficulty(lower: DifficultyDef) -> bool:
	if run == null or player == null or not run.lower_difficulty(content, lower):
		return false
	world.lower_difficulty(run.difficulty)
	player.invalidate_stats()  # (the HUD's line names the difficulty)
	_save_run()
	Events.log_message(tr("The descent goes on as %s. It sets no records now.") % run.difficulty.shown_name(), Palette.GOLD)
	return true


# --- Menus -------------------------------------------------------------------

func is_menu_open() -> bool:
	return _transitioning or menus.any_open() or meeting.is_playing()


## A cinematic (a warden's story) freezes the world while it plays.
func pause_for_cinematic(on: bool) -> void:
	_set_paused(on or is_menu_open())


func open_encounter(encounter: Encounter) -> void:
	if _can_open_menu():
		Sfx.play_ui(Sfx.bank.ui_open)
		_set_paused(true)
		encounter_panel.open(encounter, player)


func open_pact(pact: PactRoom) -> void:
	if _can_open_menu():
		Sfx.play_ui(Sfx.bank.ui_open)
		_set_paused(true)
		menus.pact.open(pact, player)


## A kept pact pays like a boss: a choice of relics, queued at once (a save keeps it) and shown
## after a moment to enjoy the burst.
func _on_pact_ended(pact: PactRoom) -> void:
	if pact.outcome != PactRoom.Outcome.KEPT:
		return
	offers.add(PerkDef.Rarity.RARE, pact.def.relic_choices, "Relic", "The pact is kept. Choose a relic.")  # i18n
	var ticket := session.capture()
	await get_tree().create_timer(RELIC_DELAY, false).timeout
	if session.is_current(ticket) and is_instance_valid(player) and not player.is_dead:
		_show_next_offer()


## A room trial done (RoomTrial): its souls to the run (paid at its end, as the hidden floor's),
## its relics offered after a moment if it gives any, counted for the feats.
func _on_trial_completed(trial: RoomTrial) -> void:
	var def := trial.def
	Events.stat_counted.emit("trials", 1)
	if def.bonus_souls > 0:
		run.bonus_souls += def.bonus_souls
		Events.log_message(tr("+%d souls for the descent.") % run.bonus_souls_worth(def.bonus_souls), def.color)
		Events.run_souls_changed.emit()
	if def.relic_choices <= 0:
		return
	offers.add(PerkDef.Rarity.RARE, def.relic_choices, "Relic", "The trial is done. Choose a relic.")  # i18n
	var ticket := session.capture()
	await get_tree().create_timer(RELIC_DELAY, false).timeout
	if session.is_current(ticket) and is_instance_valid(player) and not player.is_dead:
		_show_next_offer()


## A fragment lying on the floor is read: kept for good (Narrative), gone from the floor.
func open_fragment(piece: Fragment) -> void:
	if piece == null or piece.taken or not _can_open_menu():
		return
	var first := Narrative.find(piece.def)
	if first:
		Events.fragment_found.emit(piece.def, piece.boss)
		if content.narrative:
			Events.log_message(tr(content.narrative.fragment_message) % tr(piece.def.title), UiSkin.GOLD)
	world.fragment_taken = true
	piece.take()
	Sfx.play_ui(Sfx.bank.fragment_found if first and Sfx.bank.fragment_found else Sfx.bank.ui_open)
	_set_paused(true)
	menus.fragment.open(piece.def, piece.boss, first)


func open_shop(merchant: Merchant) -> void:
	if _can_open_menu():
		Sfx.play_ui(Sfx.bank.ui_open)
		_set_paused(true)
		shop_panel.open(merchant, player)


func open_forge(forge: Forge) -> void:
	if _can_open_menu():
		Sfx.play_ui(Sfx.bank.ui_open)
		_set_paused(true)
		menus.forge.open(forge, player, content)


func open_pause_menu() -> void:
	if _can_open_menu() and not act_card.visible and not curse_card.visible:
		Sfx.play_ui(Sfx.bank.ui_open)
		_set_paused(true)
		pause_menu.open()


## Not during the trial of the Threshold (a fight against the clock), nor on the way into or out
## of the Deeps.
func open_inventory() -> void:
	if _can_open_menu() and not is_away():
		_set_paused(true)
		inventory_panel.open(player)
		tutorial.action(&"opened_bag")


## Dev tools (debug builds only).
func open_debug() -> void:
	if menus.debug and _can_open_menu():
		_set_paused(true)
		menus.debug.open(self)


func _can_open_menu() -> bool:
	return player != null and not player.is_dead and not is_menu_open()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_F1:
		get_viewport().set_input_as_handled()
		open_debug()
	elif event.is_action_pressed("inventory") and not is_menu_open():
		get_viewport().set_input_as_handled()
		open_inventory()
	elif event.is_action_pressed("offers") and not is_menu_open():
		get_viewport().set_input_as_handled()
		open_offers()
	elif event.is_action_pressed("map") and not is_menu_open():
		get_viewport().set_input_as_handled()
		hud.toggle_full_map()
	elif event.is_action_pressed("pause"):
		# Escape or Start: closes what is open, or pauses.
		get_viewport().set_input_as_handled()
		_back()
	elif event.is_action_pressed("ui_cancel") and is_menu_open():
		# A gamepad's B only closes: in a fight it is a skill, never a pause.
		get_viewport().set_input_as_handled()
		menus.back()


## Escape, Start or the phone's back button: closes what is open, or pauses.
func _back() -> void:
	if not menus.back() and not is_menu_open():
		open_pause_menu()


## Resumes the game, or shows the next perk choice if one is due (see _show_next_offer()).
func _on_menu_closed() -> void:
	if player and player.is_dead:
		return  # the end of the run takes it from here
	_set_paused(is_menu_open())
	_show_next_offer()


func _set_paused(paused: bool) -> void:
	HitStop.reset()
	get_tree().paused = paused


# --- Floors ------------------------------------------------------------------

## `resumed`: picking a saved run back up (no free heal for quitting and coming back).
func _enter_floor(resumed: bool = false) -> void:
	if run.is_daily():
		world.rng.seed = DailyRun.floor_seed(run.daily_day, depth)  # the same floors all day
	else:
		world.rng.seed = hash("%d-floor-%d" % [run.run_seed, depth])  # quitting can't reroll a floor
	if run.hidden_floor:
		world.rng.seed = hash("hidden-%d" % world.rng.seed)  # not the boss floor of the same depth
	world.hidden_floor = content.dungeon.hidden_floor if run.hidden_floor else null
	world.hidden_floor_done = run.hidden_done
	if run.finale:
		world.rng.seed = hash("finale-%d" % world.rng.seed)  # not the boss floor of the same depth
	world.finale = content.dungeon.finale if run.finale else null
	world.finale_boss = run.bottom_boss() if run.finale else null
	if run.leads_to_finale():
		world.next_routes = [content.dungeon.finale.route()] as Array[FloorRoute]  # one way: down
	else:
		world.next_routes = _offer(depth + 1)
	first_steps.begin_floor(FirstSteps.wanted(content, run), player, world)  # (before the floor is laid)
	world.build_floor(depth, content, _route_to(depth))
	world.place_player(player)
	if resumed and world.arena and world.arena.is_defeated:
		hidden.resume_cleared()  # (the way torn open again, or the hoard waiting again)
	if DebugCheats.reveal_maps:
		world.reveal_all()  # the debug panel's Reveal maps
	player.camera.lean_toward(null, 0.0)
	play_floor_mood()
	if not resumed and depth > 1 and difficulty.heal_on_new_floor > 0.0:
		player.heal(roundi(player.get_max_hp() * difficulty.heal_on_new_floor))
	_save_run()
	Profile.reach_depth(depth)
	if run.difficulty.counts_feats:
		Profile.best_depth = maxi(Profile.best_depth, depth)
	_records.check_achievements()
	Events.depth_changed.emit(depth)
	Events.floor_entered.emit(world)  # (the RunAnnouncer: the souls, the act, the twist, the goal)
	tutorial.cue(&"floor_start")
	if world.curse:
		tutorial.cue(&"cursed_floor")
	if world.floor_event:
		tutorial.cue(&"event_floor")


## The floor's sound and look (its biome, its curse or event), and its music (the boss' during
## its fight). Also when the hero comes back from the Threshold (the Deeps' own, if that is where
## he comes back to).
func play_floor_mood() -> void:
	if abyss.holds(player):
		abyss.play_mood()
		return
	var mood := world.theme.ambience if world.theme else null
	if world.curse and world.curse.ambience:
		mood = world.curse.ambience
	ambience.play(mood, world, player, world.floor_event.atmosphere if world.floor_event else null)
	var boss_def := world.arena.boss.def as BossDef if world.is_boss_fight() else null
	if boss_def:
		Sfx.play_music(Soundtrack.boss_music(boss_def, _fight_act(), Sfx.bank))
	else:
		Sfx.play_music(Soundtrack.floor_music(world.theme))


## The act whose warden is fought on this floor (its boss music); null on the hidden floor and at
## the bottom of the Well (their bosses bring their own).
func _fight_act() -> ActDef:
	if world == null or world.hidden_floor or world.finale:
		return null
	return content.dungeon.act_for_depth(depth)


## The way the hero took to floor `floor_depth`, or null (no choice there).
func _route_to(floor_depth: int) -> FloorRoute:
	if not run.routes.has(floor_depth):
		return null
	var offered := _offer(floor_depth)
	var index: int = run.routes[floor_depth]
	return offered[index] if index >= 0 and index < offered.size() else null


## The ways down to floor `floor_depth`, offered on the floor above it: the same whenever they are
## asked (when that floor is laid, when the next one rebuilds the way taken), so the curses and
## events they leave out (RunLuck: no repeats) are those of the floors above the one showing them,
## and that floor's own twist when a way led to it (recorded when its stairs were taken).
func _offer(floor_depth: int) -> Array[FloorRoute]:
	var shown_on := floor_depth - 1
	var below := shown_on + 1 if run.routes.has(shown_on) else shown_on
	return FloorRoute.offer(content, floor_depth, difficulty, run.route_seed(floor_depth), run.tuning, run.luck, below)


func _on_stairs_reached(route: int = 0) -> void:
	if _transitioning or player == null or player.is_dead:
		return
	_into_hidden = route == HiddenPassage.ROUTE
	if _into_hidden:
		hidden.spend_key()
	elif world.next_routes.size() >= 2:
		run.routes[depth + 1] = clampi(route, 0, world.next_routes.size() - 1)
		var way := world.next_routes[run.routes[depth + 1]]
		run.luck.record(RunLuck.CURSE, way.curse, depth + 1)  # (what the next floor's offer leaves out)
		run.luck.record(RunLuck.EVENT, way.floor_event, depth + 1)
	Sfx.play_ui(Sfx.bank.stairs)
	_transitioning = true
	# Fade to black, build the next floor, fade back in.
	# (Deferred: we are inside a physics callback, where the level can't be rebuilt.)
	_descend.call_deferred(session.capture())


func _descend(ticket: GameSession.Ticket) -> void:
	if not session.is_current(ticket):
		return
	_set_paused(true)
	var fade_out := create_tween()
	fade_out.tween_method(_set_session_fade.bind(ticket), _fade.color.a, 1.0, FADE_TIME)
	await fade_out.finished
	if not session.is_current(ticket):
		return
	if run.finish_time < 0.0 and not run.hidden_floor:
		_split(run.split_depth())  # (the hidden floor's time goes to the next floor's split)
	# The hidden floor and the bottom of the Well keep the depth of the boss before them
	# (RunState.hidden_floor, RunState.finale).
	var into_finale := run.leads_to_finale() and not _into_hidden
	run.hidden_floor = _into_hidden
	_into_hidden = false
	run.finale = into_finale
	if not run.hidden_floor and not run.finale:
		depth += 1  # only now: a save during the fade still points at the floor being left
	await transition_to_floor()
	if not session.is_current(ticket):
		return
	create_tween().tween_method(_set_session_fade.bind(ticket), _fade.color.a, 0.0, FADE_TIME * 1.5)


## A tween may finish normally after a restart, but must no longer paint over the new session.
func _set_session_fade(alpha: float, ticket: GameSession.Ticket) -> void:
	if session.is_current(ticket):
		_fade.color.a = alpha


## The one way onto a floor (the stairs, a run's first floor under its cards, the debug panel's):
## held like a menu while it builds (no menus, no saves, no second descent), the floor built
## (_enter_floor(); `resumed`: a saved run picked up, or the debug panel), its cards over black,
## then the game goes on: unpaused unless a menu is open, and the perk choice that is due shown
## (`show_offers` false: the caller shows them itself).
func transition_to_floor(resumed: bool = false, show_offers: bool = true) -> void:
	var ticket := session.capture()
	_transitioning = true
	_enter_floor(resumed)
	await _show_cards()
	if not session.is_current(ticket):
		return
	_transitioning = false
	_set_paused(is_menu_open())
	if show_offers:
		_show_next_offer()


## Over black, with cards on: the act's title card on its first floor, then the curse's card
## on a cursed floor.
func _show_cards() -> void:
	if not show_act_cards:
		return
	var ticket := session.capture()
	var act := content.dungeon.act_for_depth(depth)
	if world.hidden_floor:
		await act_card.play(world.hidden_floor.as_act())
	elif world.finale:
		await act_card.play(world.finale.as_act())
	elif act and content.dungeon.floor_in_act(depth) == 1:
		await act_card.play(act)
	if not session.is_current(ticket):
		return
	if world.curse:
		await curse_card.play(world.curse)


# --- Bosses ------------------------------------------------------------------

## The view leans toward the warden, its music plays (its name: the RunAnnouncer).
func _on_boss_started(boss: Monster) -> void:
	var def := boss.def as BossDef
	if def and player:
		player.camera.lean_toward(boss, def.camera_lean, boss.head_height * 0.45)
	Sfx.play_music(Soundtrack.boss_music(def, _fight_act(), Sfx.bank))


## A boss' next form rises (BossDef.next_boss): no relic, no stairs; the screen darkens a moment
## and the view turns to it.
func _on_boss_rising(_fallen: Monster, risen: Monster, seconds: float) -> void:
	var def := risen.def as BossDef
	# (Silent since the first form fell: its own music begins once it fights, _on_boss_started.)
	if def and player:
		player.camera.lean_toward(risen, def.camera_lean, risen.head_height * 0.45)
	var darken := create_tween()
	var ticket := session.capture()
	darken.tween_method(_set_session_fade.bind(ticket), _fade.color.a, 0.55, seconds * 0.3)
	darken.tween_interval(seconds * 0.3)
	darken.tween_method(_set_session_fade.bind(ticket), 0.55, 0.0, seconds * 0.35)


func _on_boss_defeated(boss: Monster) -> void:
	run.bosses_slain += 1
	var fallen := boss.def as BossDef
	if player and not (fallen and fallen.body_stays):
		player.camera.lean_toward(null, 0.0)  # (a body that stays is still worth looking at)
	if content.dungeon.rerolls_per_boss > 0:
		run.rerolls += content.dungeon.rerolls_per_boss  # (said by the RunAnnouncer, with the banner)
	# The fight's music gives way to the sting, then the floor's comes back.
	Sfx.stop_music(0.4)
	Sfx.play_music(Soundtrack.floor_music(world.theme), Sfx.mix.sting_gap)
	var def := boss.def as BossDef
	run.last_boss = def
	var ticket := session.capture()
	# Decided now, not after the pause: the stairs are already there, and a save (app put away)
	# in between must keep the win or the relic.
	var won_now := run.wins_with(def)
	var earned := 0
	var new_record := false
	var bottom := content.dungeon.finale if run.finale else null
	if won_now:
		run.has_won = true
		run.finish_time = run.time
		run.ending_due = bottom != null and not bottom.endings.is_empty()
		if bottom and run.meets_keeper():
			Profile.record_keeper_freed(run.keeper)  # (the codex's list of the Keepers freed)
		_split(run.split_depth())
		new_record = run.ranked() and Profile.record_time(run.record_key(), run.finish_time, run.splits)
		if new_record:
			Events.log_message(tr("New record: %s!") % TimeText.of(run.finish_time), Palette.GOLD)
		earned = _award_souls(true)
	else:
		offers.add_relic(def, boss.rank.extra_relics if boss.rank else 0)
	_save_run()
	await get_tree().create_timer(ENDING_DELAY if run.ending_due and won_now else RELIC_DELAY, false).timeout
	if not session.is_current(ticket) or not is_instance_valid(player) or player.is_dead:
		return  # the run ended in the meantime
	if won_now and run.ending_due:
		_offer_ending(earned, new_record)
		return
	if won_now:
		# The last boss: the run is won. Keep going offers the relic, then endless floors.
		_set_paused(true)
		Sfx.play_ui(Sfx.bank.stairs)
		menus.show_on_top(game_over_panel)
		_show_end(true, earned, new_record)
		return
	_show_next_offer()


## The last form fell at the bottom of the Well: the hero chooses an ending (EndingPanel), then
## the victory screen tells it. Also when a run won there is picked up before the choice.
func _offer_ending(earned: int, new_record: bool) -> void:
	var bottom := content.dungeon.finale
	if bottom == null or bottom.endings.is_empty() or player == null:
		return
	_ending_earned = earned
	_ending_record = new_record
	_set_paused(true)
	# A profile write may have succeeded just before the old run file stopped. Recover the
	# recorded ending directly instead of offering two choices and then ignoring one.
	var journey := run.journey_id
	if Profile.ending_receipts.has(journey):
		for prior in bottom.endings:
			if String(prior.id) == String(Profile.ending_receipts[journey]):
				_on_ending_chosen(prior)
				return
	menus.show_on_top(menus.ending)
	menus.ending.open(bottom, run.meets_keeper())


func _on_ending_chosen(ending: EndingDef) -> void:
	var feats := run.difficulty == null or run.difficulty.counts_feats
	var journey := run.journey_id
	var chosen := ending
	var already_recorded := Profile.ending_receipts.has(journey)
	# If the profile committed before a crash, replay its original choice, never a second one.
	if Profile.ending_receipts.has(journey):
		for prior in content.dungeon.finale.endings:
			if String(prior.id) == String(Profile.ending_receipts[journey]):
				chosen = prior
	var snapshot := KeeperSnapshot.take(player, run, Leaderboards.pseudonym if Leaderboards.name_chosen else "")
	if not Profile.finish_ending(chosen, snapshot, journey, feats):
		Events.log_message(tr("Could not save village progress. Try again."), Palette.DANGER)
		menus.ending.open(content.dungeon.finale, run.meets_keeper())
		return
	run.ending_due = false
	ending = chosen
	if not already_recorded:
		Events.ending_chosen.emit(ending)  # (the world counters: WorldStats)
	_records.check_achievements()
	_save_run()
	Sfx.play_ui(Sfx.bank.stairs)
	menus.show_on_top(game_over_panel)
	_show_end(true, _ending_earned, _ending_record, ending)


## The run ends at its village, where another descent can be chosen at the well.
func return_to_village() -> void:
	_records.record_history()
	RunSave.erase()
	_set_paused(false)
	Loader.go(VILLAGE_SCENE)


## The death screen's Descend again (decision 0010): the next descent at once, as the Well would
## start it (the difficulty, ascension and oath chosen there; a Dawn Knell again, as practice, if
## this one was), without the walk back through Kagari. The run that ended is recorded and its
## save erased first, as when returning to the village.
func descend_again() -> void:
	if run == null or (Profile.held and not DebugCheats.debug_run):
		return
	var daily := run.is_daily()
	_records.record_history()
	RunSave.erase()
	Profile.save_profile()
	start_run(daily)


## The end screen's Title button ends the run as Return to village does: the won (or lost) run
## is erased, never left behind for the Well to resume into endless mode or record twice.
func return_to_title() -> void:
	_records.record_history()
	RunSave.erase()
	_set_paused(false)
	Loader.go(TITLE_SCENE)


func _on_continue_endless() -> void:
	_set_paused(false)
	Events.log_message(tr("Endless mode: the dungeon goes on, harder and harder."), Palette.DANGER)
	offers.add_relic(run.last_boss)
	Sfx.play_music(Soundtrack.floor_music(world.theme))
	_show_next_offer()


## Beside a win's time: a new record, or the record to beat.
func _record_text(new_record: bool) -> String:
	if new_record:
		return tr("New record!")
	var record := Profile.best_time(run.record_key())
	return tr("(record %s)") % TimeText.of(record) if record > 0.0 else ""


## The end-of-run screen: how it ended (a line of the story, or the ending chosen at the bottom
## of the Well), the run's numbers, the souls.
func _show_end(victory: bool, earned: int, new_record: bool = false, ending: EndingDef = null) -> void:
	# The Vigil-Keeper tells it (NarrativeDef.death_dialogues, victory_dialogues): this death's
	# facts, read as it happened; a victory's, now.
	var facts := end_facts if not victory and end_facts else RunFacts.of_victory(run, player, content, world, ending)
	end_facts = facts
	var spoken: Array[Dialogues.Spoken] = content.narrative.tell_end(facts) if content.narrative else []
	var story := ""
	if ending:
		story = tr(ending.text_for(run.meets_keeper()))
	elif content.story and (victory or spoken.is_empty()):
		story = tr(content.story.victory_text if victory else content.story.random_death_line())
	var rows := run.summary_rows(content, player.level, _record_text(new_record) if victory else "")
	game_over_panel.show_leaderboards = run.is_daily()  # (the Dawn Knell's board)
	if victory:
		Sfx.play_music(ending.music if ending and ending.music else Sfx.bank.victory_music)
	else:
		Sfx.play_music(Sfx.bank.defeat_music, Sfx.mix.sting_gap)  # after the game_over sting
	game_over_panel.show_end(victory, story, rows, earned, Profile.souls, tr(ending.title) if ending else "", spoken)


# --- Perks -------------------------------------------------------------------

## Perk choices waiting (a level up's wait until the player opens them; see open_offers()).
func pending_offers() -> int:
	return offers.size()


## Opens the waiting perk choices (the HUD's perk button): they follow one another, with
## rerolls and banishes, until none is left or one is put off. False if none waits or a menu
## can't open now.
func open_offers() -> bool:
	return choices.open()


## `on_demand`: it waits for the player (a level up); otherwise it comes up by itself as soon as
## no menu is open (relics, an encounter's gift).
func _queue_offer(rarity: PerkDef.Rarity, count: int, title: String, subtitle: String, on_demand: bool = false, level: int = 0) -> void:
	choices.queue(rarity, count, title, subtitle, on_demand, level)


## Shows the next choice that is due: any of them while the player is choosing (open_offers()),
## otherwise only those that come up by themselves.
func _show_next_offer() -> void:
	choices.show_next()


# --- End of the run -------------------------------------------------------------

func _on_player_died(_actor: Actor) -> void:
	var ticket := session.capture()
	# What the Vigil-Keeper will tell (read now: the floor may change during the pause).
	end_facts = RunFacts.of_death(run, player, content, world, abyss.holds(player))
	RunSave.erase()
	offers.clear()
	if Profile.assist:
		Profile.count_assist_death()  # (the aid weighs a little more from the next hit)
	# Souls and history right away (the app may be closed during the pause below).
	var earned := _award_souls(false)
	_records.record_history()
	Profile.save_profile()
	Sfx.stop_music(1.0)  # the floor falls silent; the sting, then the end screen's music
	await get_tree().create_timer(1.2).timeout
	if not session.is_current(ticket):
		return
	Sfx.play_ui(Sfx.bank.game_over)
	menus.show_on_top(game_over_panel)
	_show_end(false, earned)


# --- Saving ------------------------------------------------------------------

## Saves the run (see RunSave). Called when a floor begins and when the app is put away.
## Never during the trial of the Threshold nor in the Deeps: picked up again, the run is as it
## was before the killing blow or the fall. Never a debug run (DebugCheats.debug_run): the save
## stays as it was before its first cheat.
func _save_run() -> void:
	if player == null or player.is_dead or run == null or threshold.is_open() or abyss.is_open() \
			or DebugCheats.debug_run:
		return
	Events.run_saving.emit(run)  # (the gameplay statistics' counts, into run.telemetry)
	var data := run.to_data()
	# A warden's arena cleared is picked up as it is (FloorSave "arena_cleared"); only the bottom
	# of the Well's fall goes on at once (to its ending).
	data.boss_slain = world.arena != null and world.arena.is_defeated and not world.floor_save.arena_cleared()
	data.player = player.save_state()
	if perk_panel.visible and offers.shown:
		offers.shown.cards = perk_panel.get_offered().duplicate()  # quitting can't reroll them
	data.offers = offers.to_data(perk_panel.visible)
	data.floors_without_forge = world.forge_drought_at_start
	data.floor = world.spent_data()
	data.kept_stock = world.locked_stock().map(func(entry: Dictionary) -> Dictionary:
		return { "item": LootRoller.to_data(entry.item), "price": entry.price })
	RunSave.write(data)


## Leaving the game (to the title): the debug panel's cheats end with it, and a debug run's
## profile is read back (DebugCheats).
func _exit_tree() -> void:
	session.close()
	var slowed := DebugCheats.time_step > 0
	DebugCheats.reset()
	Events.run_closed.emit()
	if slowed:
		HitStop.reset()  # the next scene runs at the real speed


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			_save_run()
			Profile.save_profile()  # kills and stats since the last save
			# Closed for good, or maybe killed in the background: the run's "abandoned" end.
			_records.report_left(what == NOTIFICATION_WM_CLOSE_REQUEST)
			# Coming back to the phone (or from the notification shade, a call), the game waits on
			# the pause menu.
			# (On a computer, clicking another window must not stop the game.)
			if what == NOTIFICATION_APPLICATION_PAUSED or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile")):
				open_pause_menu()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_back()
