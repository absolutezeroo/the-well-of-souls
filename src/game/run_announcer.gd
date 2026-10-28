class_name RunAnnouncer
extends Node
## The run's presenter: gameplay emits (the Events bus, the World's and the RunTimer's signals),
## the announcer shows it on the HUD (banners, toasts, the souls, the clock and its splits) and
## says it in the log: a new act, a floor's twist and goal, a signature room, a warden's name, its
## fall and its last words, an ambush, a deed, the remote settings on a new run. Owned by the
## Game, which hands it the HUD and itself (to read the run and the floor); it never drives
## gameplay, and nothing in gameplay calls the HUD to say these things.
##
## Added before the Game connects its own Events, so on a shared signal (a boss falling) its lines
## come in the log before the Game's (a new record), as they always did.

## Seconds a warden's last words wait after its fall (its death starts to play).
const LAST_WORDS_DELAY := 0.4

var game: Game
var hud: Hud


func _ready() -> void:
	Events.run_started.connect(_on_run_started)
	Events.floor_entered.connect(_on_floor_entered)
	Events.floor_laid_anew.connect(func() -> void:
		hud.toast(tr("The Well has shifted since you left: this floor is laid anew.")))
	Events.soul_gathered.connect(_show_souls_gained)
	Events.run_souls_changed.connect(_show_souls_gained)
	Events.split_timed.connect(_on_split_timed)
	Events.deed_done.connect(_on_deed_done)
	Events.boss_started.connect(_on_boss_started)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.monster_killed.connect(func(monster: Monster) -> void:
		if monster.world == game.world and monster.def is BossDef:
			_say_last_words(monster.def as BossDef))
	Events.ambush_started.connect(func(_room: AmbushRoom) -> void:
		Events.log_message(tr("It's a trap! Survive the waves."), Palette.DANGER))
	Events.ambush_cleared.connect(func(_room: AmbushRoom) -> void:
		Sfx.play_ui(Sfx.bank.boss_defeated)
		Events.log_message(tr("The room falls silent. A chest appears..."), Palette.GOLD))
	game.world.set_piece_entered.connect(_on_set_piece_entered)
	game.run_timer.ticked.connect(hud.show_run_time)


## A new run says in the log what the remote settings put on it (RemoteConfig): a running event,
## the Dawn Knell's omen. A run picked up again said it when it began.
func _on_run_started(run: RunState, _player: Player) -> void:
	if run.resumed:
		return
	if not run.tuning.event_name.is_empty():
		Events.log_message(tr("The Well's event: %s") % run.tuning.event_name, Palette.GOLD)
	var omen := DailyRun.twist(game.content, run.tuning.omen)
	if omen:
		Events.log_message(tr("Today's omen: %s") % tr(omen.display_name), omen.color)


## The souls the run is worth, counted up (a wisp gathered, a hoard given).
func _show_souls_gained() -> void:
	hud.set_souls(game.run_souls(), true)


## A floor is done: its split, against the record run's.
func _on_split_timed(floor_depth: int, time: float) -> void:
	var record := Profile.best_split(game.run.record_key(), floor_depth)
	hud.show_split(floor_depth, time, time - record if record > 0.0 else NAN)


## The souls, then the log (and banners when the cards are off): the act, the floor's event or
## curse, the hidden floor or the bottom of the Well, the goal.
func _on_floor_entered(world: World) -> void:
	hud.set_souls(game.run_souls())
	var dungeon := game.content.dungeon
	var depth := world.depth
	var cards := game.show_act_cards
	var act := dungeon.act_for_depth(depth)
	if act and dungeon.floor_in_act(depth) == 1:
		if not cards:
			hud.show_banner(tr(act.title))
		Events.log_message(tr("%s: %s") % [tr(act.subtitle), tr(act.title)], Palette.GOLD)
	if world.floor_event:
		hud.show_banner(tr(world.floor_event.display_name), world.floor_event.color)
		Events.log_message(tr(world.floor_event.description), world.floor_event.color)
	if world.curse:
		if not cards:
			hud.show_banner(tr(world.curse.display_name), world.curse.color)
		Events.log_message(tr("Cursed: %s. %s") % [tr(world.curse.display_name), tr(world.curse.description)], world.curse.color)
	if world.hidden_floor:
		hud.show_banner(tr(world.hidden_floor.title), world.hidden_floor.color)
		Events.log_message(tr(world.hidden_floor.lore), world.hidden_floor.color)
	if world.finale:
		hud.show_banner(tr(world.finale.title), world.finale.color)
		Events.log_message(tr(world.finale.lore), world.finale.color)
	if world.arena:
		Events.log_message(tr("Depth %d. Something vast waits in the dark...") % depth, Palette.DANGER)
	elif world.seal.is_sealed():
		Events.log_message(tr("Depth %d. The stairs are sealed: slay %d monsters to open them.") % [depth, world.seal.needed], Palette.SEAL)
	else:
		Events.log_message(tr("Depth %d. Find the stairs!") % depth, Palette.GOLD)


## A signature room of the floor (RoomShapeDef.set_piece), the first time: its name on a banner,
## its line in the log.
func _on_set_piece_entered(shape: RoomShapeDef) -> void:
	hud.show_banner(tr(shape.display_name), shape.color)
	if not shape.description.is_empty():
		Events.log_message(tr(shape.description), shape.color)


## A warden fell the way one of its deeds asks: the Well remembers.
func _on_deed_done(boss: BossDef, _deed: DeedCondition) -> void:
	var narrative := game.content.narrative
	if narrative and not narrative.deed_message.is_empty():
		var line := tr(narrative.deed_message) % tr(boss.display_name)
		Events.log_message(line, UiSkin.GOLD)
		hud.toast(line)


## Its name on a banner (unless its cinematic just named it), its title in the log.
func _on_boss_started(boss: Monster) -> void:
	var def := boss.def as BossDef
	if game.meeting.last_told != boss.get_instance_id():
		hud.show_banner(tr(boss.display_name), Palette.DANGER)
	if def and not def.title.is_empty():
		Events.log_message(tr("{name}, {title}").format({ "name": tr(boss.display_name), "title": tr(def.title) }), Palette.DANGER)


## The fight is won: the rerolls it gave (the Game adds them), the banner, the way down.
func _on_boss_defeated(boss: Monster) -> void:
	var rerolls := game.content.dungeon.rerolls_per_boss
	if rerolls > 0:
		Events.log_message(tr("+%d reroll for the perk choices.") % rerolls, Palette.GOLD)
	hud.show_banner(tr("Victory achieved"))
	Sfx.play_ui(Sfx.bank.boss_defeated)
	Events.log_message(tr("%s falls. The way down lies open.") % tr(boss.display_name), Palette.GOLD)


## A warden's last words (BossMeeting.last_words()), a moment after its fall (a deed just done
## by that fall counts): in quotes on its banner, and in the log. Not if the floor or the hero
## changed meanwhile.
func _say_last_words(def: BossDef) -> void:
	var speaker := game.player
	var floor_id := game.world.floor_id
	await get_tree().create_timer(LAST_WORDS_DELAY, false).timeout
	if game.player != speaker or game.world.floor_id != floor_id:
		return
	var line := game.meeting.last_words(def)
	if line.is_empty():
		return
	var color := def.color.lightened(0.25)
	var words := tr("\"%s\"") % tr(line)
	hud.show_banner(words, color)
	Events.log_message(words, color)
