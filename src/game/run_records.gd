class_name RunRecords
extends Node
## Keeps the profile's records up to date during a run: kills (the bestiary), stats, gold,
## achievements, and the history entry when the run ends. Listens to Events; owned by the Game.

var run: RunState
var player: Player
var content: ContentDB

## The purse a moment ago (gold_changed only gives the new total).
var _last_gold := 0


func _ready() -> void:
	Events.monster_killed.connect(_on_monster_killed)
	Events.depth_changed.connect(_on_depth_changed)
	Events.stat_counted.connect(func(stat: String, amount: int) -> void:
		Profile.add_stat(stat, amount, _feats())
		check_achievements())
	Events.secret_found.connect(func(_room: Node2D) -> void:
		if run:
			run.secrets_found += 1
			run.mark("secret")
		Profile.add_stat("secrets", 1, _feats())
		check_achievements())
	# What a warden's deeds may ask about (MarkDeed).
	Events.item_bought.connect(func(_item: ItemDef) -> void:
		if run:
			run.mark("bought"))
	Events.encounter_used.connect(func(encounter: Encounter) -> void:
		if run and encounter.def:
			run.mark("encounter:%s" % encounter.def.id))
	Events.run_marked.connect(func(mark: String) -> void:
		if run:
			run.mark(mark))


## Follows a new run (and its hero).
func bind(new_run: RunState, new_player: Player) -> void:
	run = new_run
	player = new_player
	_last_gold = player.gold  # a saved purse is not new gold
	if run.oath:
		run.mark("oath")
	player.gold_changed.connect(_on_gold_changed)
	player.leveled_up.connect(func(level: int) -> void:
		Profile.raise_stat("run_level", level, _feats())
		check_achievements())
	# What the Vigil-Keeper reads in a death (RunMarkCondition): a potion drunk, a roll.
	player.consumable_used.connect(func(item: ItemDef) -> void:
		if run and item is ConsumableDef and PlayerPack.heals(item as ConsumableDef):
			run.mark("drank"))
	player.skill_used.connect(func(index: int) -> void:
		if run and index == 0:
			run.mark("rolled"))


## Feats count on this run's difficulty (not on Pilgrim: DifficultyDef.counts_feats).
func _feats() -> bool:
	return run == null or run.difficulty == null or run.difficulty.counts_feats


## Unlocks (and pays) every achievement whose goal is reached, and every finished quest.
func check_achievements() -> void:
	for achievement in AchievementDef.unlock_reached(content.achievements):
		Events.achievement_unlocked.emit(achievement)
	QuestBoard.pay_finished(content.quests)


## The run ended (a death, a win; souls given): tells it to whoever keeps scores
## (Events.run_ended: the online leaderboards).
func report_end() -> void:
	if run == null or player == null:
		return
	Events.run_ended.emit(RunSummary.of(run, player, content))


## The player leaves the run, saved, without it ending (Events.run_left; `for_good`: quit to the
## title or the app closed, else put in the background). Nothing for a hero already dead (that
## run ended: report_end()).
func report_left(for_good: bool) -> void:
	if run == null or not is_instance_valid(player) or player.is_dead:
		return
	Events.run_left.emit(RunSummary.of(run, player, content), for_good)


## Adds the run to the history (once).
func record_history() -> void:
	if run == null or run.history_recorded or player == null:
		return
	run.history_recorded = true
	var weapon := player.get_weapon()
	Profile.add_history({
		"difficulty": run.difficulty.display_name,
		"ascension": run.difficulty.ascension,
		"depth": run.depth,
		"level": player.level,
		"kills": run.kills,
		"bosses": run.bosses_slain,
		"won": run.has_won,
		"souls": run.souls_awarded,
		"weapon": weapon.display_name if weapon else "Bare hands",
		"oath": run.oath.display_name if run.oath else "",  # (the kit or oath sworn: its name, an English key)
		"cause": player.killed_by if player.is_dead else "",
		"duration": roundi(run.run_time() * 1000.0),  # ms: the win's time, or how long it lasted
		# What the Vigil-Keeper remembers of it (DeathStreakCondition): who, how.
		"killer": String(player.killer_def.id) if player.is_dead and player.killer_def else "",
		"death": String(player.death_cause) if player.is_dead else "",
	})
	if player.is_dead:
		Profile.record_death(player.killer_def.id if player.killer_def else &"")


func _on_monster_killed(monster: Monster) -> void:
	if run == null or monster.summoned:
		return  # called in by another monster: no kill to count, no souls, no bestiary farming
	run.kills += 1
	Profile.record_kill(monster.def.id)
	if content and content.bestiary:
		for reached in Bestiary.claim(monster.def, content.bestiary):
			Events.bestiary_rank_reached.emit(monster.def, reached.rank, reached.souls)
	Profile.add_stat("kills", 1, _feats())
	if monster.is_elite():
		Profile.add_stat("elites", 1, _feats())
	if monster.rank and monster.rank.shimmer and Profile.add_shiny(monster.def.id):
		Events.log_message(tr("A Celestial %s! It joins the bestiary's collection.") % tr(monster.def.display_name), monster.rank.color)
	if monster.is_boss():
		Profile.add_stat("bosses", 1, _feats())
	if monster.has_fallen() and is_instance_valid(monster.last_attacker) and monster.last_attacker is Player:
		Profile.add_stat("pushed", 1, _feats())
	check_achievements()


## A new floor: counted (quests), and a cursed one too.
func _on_depth_changed(depth: int) -> void:
	if run == null or player == null or not is_instance_valid(player):
		return
	if depth > 1:
		Profile.add_stat("floors", 1, _feats())
	Profile.raise_stat("run_depth", depth, _feats())
	if player.world and player.world.curse:
		Profile.add_stat("cursed_floors", 1, _feats())
		run.mark("cursed")
	if run.hidden_floor:
		run.mark("hidden_floor")
	check_achievements()


func _on_gold_changed(gold: int) -> void:
	if gold > _last_gold:
		Profile.add_stat("gold", gold - _last_gold, _feats())
		run.run_gold += gold - _last_gold
		Profile.raise_stat("run_gold", run.run_gold, _feats())
		check_achievements()
	_last_gold = gold
