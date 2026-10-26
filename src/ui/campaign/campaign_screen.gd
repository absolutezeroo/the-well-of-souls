class_name CampaignScreen
extends Node
## Product entry point for the persistent solo RPG. Legacy runs remain readable by their
## editor scenes, but no daily run, death reset or shrine grind appears in this player flow.

const RUNTIME := preload("res://src/game/campaign_runtime.tscn")
const INVENTORY := preload("res://src/ui/inventory/inventory_panel.tscn")
const OPTIONS := preload("res://src/ui/options/options_panel.tscn")
const SAVE_PATH := "user://campaign.json"
## Let the title appear before asking; never interrupt a campaign already launched.
const PRIVACY_DELAY := 0.8


## Tests supply an isolated path before adding this scene. Never import or erase run/profile.
@export var checkpoint_path := SAVE_PATH
var runtime: CampaignRuntime
var panel: CampaignPanel
var inventory: InventoryPanel
var options: OptionsPanel
var credits: CreditsPanel
var consent: ConsentDialog
var _page := "title"
var _quitting := false
var _shown_hero: Player
var _shown_floor := -1
@onready var hud: Hud = $Hud
@onready var menus: CanvasLayer = $Menus
@onready var ambience: Ambience = $Ambience


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	hud.hide()
	panel = CampaignPanel.new()
	menus.add_child(panel)
	panel.close_requested.connect(_back)
	inventory = INVENTORY.instantiate() as InventoryPanel
	menus.add_child(inventory)
	inventory.closed.connect(_bag_closed)
	options = OPTIONS.instantiate() as OptionsPanel
	options.campaign_mode = true
	menus.add_child(options)
	options.closed.connect(_options_closed)
	credits = CreditsPanel.new()
	menus.add_child(credits)
	consent = ConsentDialog.new()
	menus.add_child(consent)
	hud.inventory_requested.connect(_bag)
	hud.pause_requested.connect(_pause)
	hud.offers_requested.connect(_talents)
	_title()
	if Privacy.ask_on_title and Privacy.should_ask():
		get_tree().create_timer(PRIVACY_DELAY, true).timeout.connect(_ask_privacy)


func _ask_privacy() -> void:
	if is_inside_tree() and runtime == null and Privacy.should_ask():
		consent.ask()


func _title() -> void:
	_page = "title"
	get_tree().paused = true
	panel.clear(tr("Le Puits des Âmes"))
	panel.close_button.hide()
	panel.words(tr("A persistent adventure. Your character, equipment and progress survive death."))
	var store := CampaignSave.new(checkpoint_path)
	var state := store.load_state()
	if state:
		panel.action(tr("Resume the campaign"), begin_campaign.bind(true))
		panel.words(tr("Level %d") % int(state.hero.to_data().player.level))
		if store.recovered:
			panel.words(tr("The last save is damaged. Resume will recover the previous valid checkpoint."))
	elif store.last_failure == CampaignSave.Failure.MISSING:
		panel.action(tr("Begin the adventure"), begin_campaign.bind(false))
	else:
		panel.words(_save_error(store.last_failure))
		panel.action(tr("Retry"), _title)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(checkpoint_path + ".lock")):
		panel.action(tr("Recover an abandoned save lock"), _lock_recovery)
	panel.action(tr("Options"), options.open)
	panel.action(tr("Credits"), credits.open)
	panel.action(tr("Quit"), _quit)
	panel.show()
	Sfx.play_music(Sfx.bank.title_music)


func begin_campaign(resume: bool) -> void:
	if runtime:
		return
	var next := RUNTIME.instantiate() as CampaignRuntime
	add_child(next)
	if next.content.sounds:
		Sfx.bank = next.content.sounds
	if not next.begin(checkpoint_path, resume):
		panel.note.text = _save_error(next.storage.last_failure if next.storage else CampaignSave.Failure.INVALID_STATE)
		next.free()
		return
	runtime = next
	runtime.changed.connect(_place_changed)
	runtime.journal_requested.connect(_journal)
	hud.bind_interactor(runtime.interactor)
	runtime.save_failed.connect(_save_failed)
	runtime.returned_to_refuge.connect(_returned)
	runtime.regions.travel_failed.connect(_travel_failed)
	_place_changed()
	_close_menu()
	hud.show()


func _place_changed() -> void:
	if not runtime or not runtime.started:
		return
	var hero := runtime.session.character
	hud.offers_button.count = runtime.progress.points()
	if hero != _shown_hero:
		hud.bind_player(hero)
		_shown_hero = hero
	if _shown_floor == runtime.world.floor_id:
		return
	_shown_floor = runtime.world.floor_id
	hud.bind_world(runtime.world)
	var place := runtime.definition.atlas.find(runtime.regions.current_id)
	hud.show_campaign_place(tr(place.display_name))
	ambience.play(runtime.world.theme.ambience, runtime.world, hero)
	Sfx.play_music(Soundtrack.floor_music(runtime.world.theme))


func _returned() -> void:
	if inventory.visible:
		inventory.close()
	else:
		_close_menu()
	hud.toast(tr("You awaken at the refuge. Your possessions and progress are safe."))


func _pause() -> void:
	if not runtime:
		return
	if runtime.session.character.is_dead:
		_save_failed(runtime.storage.last_failure)
		return
	_open(tr("Campaign"), "pause")
	panel.action(tr("Continue"), _close_menu)
	panel.action(tr("Journal"), _journal)
	panel.action(tr("Refuge supplies"), _supplies, runtime.regions.current_id == runtime.definition.refuge_region)
	panel.action(tr("Talents (%d)") % runtime.progress.points(), _talents)
	panel.action(tr("Rest at the refuge"), _rest, runtime.regions.current_id == runtime.definition.refuge_region)
	panel.words(tr("Rest restores Health and renews defeated common enemies. Unique guardians and chests stay completed."))
	panel.action(tr("Save"), _save)
	panel.action(tr("Options"), options.open)
	panel.action(tr("Save and return to title"), _leave)


func _open(title_text: String, page_id: String) -> void:
	if runtime:
		runtime.session.character.controls.cancel_actions()
	get_tree().paused = true
	_page = page_id
	panel.clear(title_text)
	panel.close_button.show()
	panel.show()


func _journal() -> void:
	if not runtime or runtime.session.character.is_dead:
		return
	_open(tr("Journal"), "journal")
	for quest in runtime.definition.quests:
		panel.words(tr(quest.display_name))
		panel.words(tr(quest.description))
		if runtime.progress.paid(quest):
			panel.words(tr("Completed"))
		elif not runtime.progress.accepted(quest):
			panel.action(tr("Accept the Vigil-Keeper's request"), _quest.bind(quest), runtime.regions.current_id == runtime.definition.refuge_region)
		elif quest.completed(runtime.session.campaign):
			panel.action(tr("Report to the Vigil-Keeper: %d gold") % quest.reward_gold, _quest.bind(quest), runtime.regions.current_id == runtime.definition.refuge_region)
		else:
			panel.words(tr("In progress"))
	panel.note.text = tr("Accept requests and report your discoveries at the refuge." )


func _quest(quest: CampaignQuestDef) -> void:
	if runtime.progress.advance(quest):
		_journal()
	else:
		panel.note.text = _save_error(runtime.storage.last_failure)


func _talents() -> void:
	if not runtime or runtime.session.character.is_dead:
		return
	hud.offers_button.count = runtime.progress.points()
	_open(tr("Talents"), "talents")
	panel.words(tr("Unspent talent points: %d") % runtime.progress.points())
	for talent in runtime.definition.talents:
		panel.words(tr(talent.display_name))
		panel.words(talent.describe())
		panel.action(tr("Learn: %d / %d") % [runtime.session.character.perks.stacks_of(talent), talent.max_stacks],
			_learn.bind(talent), runtime.progress.points() > 0 and runtime.session.character.perks.can_take(talent))


func _supplies() -> void:
	if not runtime or runtime.regions.current_id != runtime.definition.refuge_region or runtime.session.character.is_dead:
		return
	_open(tr("Refuge supplies"), "supplies")
	panel.words(tr("Gold %d") % runtime.session.character.gold)
	for supply in runtime.definition.supplies:
		panel.words(tr(supply.item.display_name))
		panel.words(supply.item.get_details())
		panel.action(tr("Buy for %d gold") % supply.price, _buy.bind(supply), not runtime.progress.purchased(supply)
			and runtime.session.character.gold >= supply.price and runtime.session.character.pack.can_store(supply.item))
	panel.note.text = tr("Each supply is available once per campaign. Rest and death do not refill this stock.")


func _buy(supply: CampaignSupplyDef) -> void:
	if runtime.progress.purchase(supply):
		_supplies()
	else:
		panel.note.text = _save_error(runtime.storage.last_failure)


func _learn(talent: PerkDef) -> void:
	if runtime.progress.learn(talent):
		_talents()
	else:
		panel.note.text = _save_error(runtime.storage.last_failure)


func _rest() -> void:
	if runtime.rest():
		_close_menu()
		hud.toast(tr("You rest. The common creatures stir again in the depths."))
	else:
		panel.note.text = _save_error(runtime.storage.last_failure)


func _bag() -> void:
	if not runtime or runtime.session.character.is_dead:
		return
	panel.hide()
	get_tree().paused = true
	inventory.open(runtime.session.character)


func _save() -> void:
	if runtime.save():
		panel.note.text = tr("Campaign saved." )
	else:
		panel.note.text = _save_error(runtime.storage.last_failure)


func _leave() -> void:
	if not runtime.save():
		panel.note.text = _save_error(runtime.storage.last_failure)
		return
	# Reload only after acknowledged publication; a failed write never discards live play.
	Loader.go(scene_file_path)


func _save_failed(reason: CampaignSave.Failure) -> void:
	if runtime and runtime.session.character.is_dead:
		_open(tr("Return to the refuge"), "death")
		panel.close_button.hide()
		panel.words(tr("Your progress is still in memory. Retry saving to return safely."))
		panel.action(tr("Retry"), _retry_recovery)
		panel.note.text = _save_error(reason)
	else:
		hud.toast(_save_error(reason))


func _retry_recovery() -> void:
	if runtime.recover():
		_close_menu()


func _travel_failed(reason: RegionCoordinator.Failure) -> void:
	if reason == RegionCoordinator.Failure.SETTLING:
		return
	if runtime and reason == RegionCoordinator.Failure.SAVE:
		_save_failed(runtime.storage.last_failure)
	else:
		hud.toast(tr("This passage could not be loaded. Your current place has been kept."))


func _save_error(reason: CampaignSave.Failure) -> String:
	match reason:
		CampaignSave.Failure.BUSY:
			return tr("The campaign is locked by another writer. Close other game instances and retry. A stale lock requires explicit recovery.")
		CampaignSave.Failure.INCOMPATIBLE:
			return tr("This campaign needs a compatible game version. No progress has been replaced.")
		CampaignSave.Failure.CONFLICT:
			return tr("The campaign changed in another instance. This instance cannot overwrite it.")
		CampaignSave.Failure.CORRUPT:
			return tr("The campaign and its backup could not be read. The files have been kept for recovery.")
		_:
			return tr("The campaign could not be saved or loaded. Check the available storage and retry.")


func _close_menu() -> void:
	if not runtime:
		return
	panel.hide()
	get_tree().paused = false
	runtime.session.character.controls.mute_presses()


func _lock_recovery() -> void:
	_open(tr("Recover an abandoned save lock"), "lock")
	panel.words(tr("Close every other instance of the game first. Removing a lock while another instance is saving can damage progress."))
	panel.action(tr("All other instances are closed: release the lock"), _release_lock)
	panel.action(tr("Cancel"), _title)


func _release_lock() -> void:
	var store := CampaignSave.new(checkpoint_path)
	if store.release_abandoned_lock():
		_title()
	else:
		panel.note.text = _save_error(store.last_failure)


func _bag_closed() -> void:
	if runtime and not runtime.session.character.is_dead:
		runtime.save()
	_close_menu()


func _options_closed() -> void:
	if runtime:
		_pause()
	else:
		_title()


func _back() -> void:
	if _page == "death":
		return
	if runtime:
		_close_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if consent.visible:
			consent.back()
		elif credits.visible:
			credits.back()
		elif options.visible:
			options.close()
		elif inventory.visible:
			inventory.close()
		elif panel.visible:
			_back()
		else:
			_pause()
	elif runtime and not panel.visible and not inventory.visible and event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		_bag()
	elif runtime and not panel.visible and event.is_action_pressed("offers"):
		get_viewport().set_input_as_handled()
		_talents()


func _quit() -> void:
	if _quitting:
		return
	if runtime and (not runtime.world.spawns.is_settled() or not (runtime.recover() if runtime.session.character.is_dead else runtime.save())):
		_pause()
		panel.note.text = _save_error(runtime.storage.last_failure)
		return
	_quitting = true
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if runtime:
			_pause()


func _exit_tree() -> void:
	get_tree().paused = false
	get_tree().auto_accept_quit = true
