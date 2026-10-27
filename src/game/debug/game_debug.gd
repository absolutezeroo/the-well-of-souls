class_name GameDebug
extends RefCounted
## The Game's debug entry points (the debug panel, the tests and the level and balance tools):
## going straight to a floor, the bottom of the Well or the hidden floor, the trial of the
## Threshold or the Deeps' Dawn Breach, a warden's story told again, a save picked up at once. Part of the Game (Game.debug), kept apart so the Game's own
## code is the run's flow; each goes through the same floor transition as the stairs
## (Game.transition_to_floor()).

var game: Game


func _init(owner: Game) -> void:
	game = owner


## Builds floor `target` right away, with that curse or event (or a plain floor). A floor of the
## dungeon, even from the hidden floor or the bottom of the Well.
func enter_floor(target: int, curse: CurseDef = null, event: FloorEventDef = null, plain: bool = false) -> void:
	var overrides := game.world.overrides
	overrides.curse = curse
	overrides.event = event
	overrides.plain = plain or (curse == null and event == null)
	_leave_pockets()
	game.run.hidden_floor = false
	game.run.finale = false
	game.depth = target
	await game.transition_to_floor(true)


## The bottom of the Well right away (FinaleDef), as if the last act's boss had led there.
## `keeper`: the Nameless Keeper waits there, made from the hero as he is now (a snapshot of this
## run, never the profile's); otherwise Tôma and the Maw.
func enter_finale(keeper: bool = false) -> void:
	var content := game.content
	if content.dungeon.finale == null:
		return
	_leave_pockets()
	var run := game.run
	run.keeper = KeeperSnapshot.take(game.player, run) if keeper else {}
	run.build_keeper(content)
	run.finale_open = true
	run.has_won = false
	run.hidden_floor = false
	run.finale = true
	game.depth = content.dungeon.total_floors()
	await game.transition_to_floor(true)


## The hidden floor right away (HiddenFloorDef), as if its key had opened the way after the boss
## of its first key act.
func enter_hidden() -> void:
	var dungeon := game.content.dungeon
	var hidden_def := dungeon.hidden_floor
	if hidden_def == null:
		return
	_leave_pockets()
	game.run.finale = false
	game.run.hidden_floor = true
	var act := clampi(hidden_def.key_acts[0] if not hidden_def.key_acts.is_empty() else 0, 0, dungeon.acts.size() - 1)
	game.depth = dungeon.first_depth(act) + dungeon.acts[act].floors - 1
	await game.transition_to_floor(true)


## Is there a warden standing on this floor whose story can be told (boss_story())?
func boss_story_ready() -> bool:
	var arena := game.world.arena
	return arena != null and is_instance_valid(arena.boss) and not arena.boss.is_dead and not game.meeting.is_playing()


## The warden of this floor tells its story now (its cinematic, as when the hero walks into its
## arena), even if it was told on this floor already; the fight starts as usual, when the hero
## walks in. A debug run (the meeting counts in the profile). False if no warden stands here.
func boss_story() -> bool:
	if not boss_story_ready():
		return false
	DebugCheats.mark_run()
	game.run.met_floors.erase(game.run.floor_key())
	game.meeting.meet(game.world.arena.boss)
	return true


## Saves the run and picks it up again at once, as the title's Continue would (a fresh floor at
## the same depth, the hero as saved). False when nothing could be saved (a debug run, the
## Threshold, the Deeps).
func reload() -> bool:
	if DebugCheats.debug_run or game.threshold.is_open() or game.abyss.is_open():
		return false
	game._save_run()  # (the Game's own save: GameDebug is part of it)
	var saved := RunSave.read()
	if saved.is_empty():
		return false
	game.resume_run(saved)
	return true


## The trial of the Threshold right away, as if a killing blow had met a second life (the first
## perk whose CheatDeathPassive names a trial: the Phoenix Feather's). No feather is spent and
## nothing heals: won, the hero is back where he stood as he was; lost, he dies, as for real.
## False when it can't open here (already in a trial, no trial in the content).
func enter_threshold() -> bool:
	var trial := threshold_trial(game.content)
	if trial == null or not game.threshold.can_host(game.player):
		return false
	game.threshold.open(game.player, trial, func() -> void: pass)
	return true


## The trial a second life opens (null: none in the content).
static func threshold_trial(content: ContentDB) -> ThresholdDef:
	for perk in content.perks:
		for passive in perk.passives:
			if passive is CheatDeathPassive and (passive as CheatDeathPassive).trial:
				return (passive as CheatDeathPassive).trial
	return null


## The hero by the Dawn Breach, the Deeps' way out: down into the Deeps first if he isn't there
## (from where he stands: Abyss.can_take()). He still steps into it himself. False if the Deeps
## can't be reached from here or have no way to the breach.
func to_dawn_breach() -> bool:
	var abyss := game.abyss
	var player := game.player
	if not abyss.is_open():
		if not abyss.can_take(player):
			return false
		abyss.open(player, player.global_position)
		await abyss.started
	if not abyss.is_searching() or abyss.depths == null:
		return false
	var way := abyss.depths.way_to_door(player.global_position)
	if way.is_empty():
		return false
	# A few steps short of it along the way (on it, he would be out at once).
	var spot := way[maxi(way.size() - 1 - BREACH_STEPS_SHORT, 0)]
	player.global_position = abyss.depths.nearest_free_point(spot)
	player.velocity = Vector2.ZERO
	player.camera.reset_smoothing()
	return true


## How many cells of the way short of the Dawn Breach to_dawn_breach() leaves the hero.
const BREACH_STEPS_SHORT := 2


## Out of the Threshold's trial and the Deeps first (a floor is built under the hero).
func _leave_pockets() -> void:
	game.threshold.abort()
	game.abyss.abort()  # (after the Threshold: it may have opened from the Deeps)
