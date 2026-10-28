class_name FirstRunTests
extends TestSuite
## The first minutes (decision 0010): the first launch going straight down the Well (the privacy
## questions first), the time from launch to the first monster noticing the hero, the first runs'
## sheltered first room and slow first monster, the death screen's Descend again; and the hints
## (one line each, back when they ran out unread, read again in the codex's Tips).
## run_title() on the title suite; the run_* parts on fresh games of the game suite.

## What a new player takes, as the audit timed the first launch: the privacy questions come
## after TitleScreen.PRIVACY_DELAY and take two answers; then Play; then Skip on the story's
## first page; then a look at the first floor once it shows.
const ANSWER_SECONDS := 5.0
const PLAY_SECONDS := 1.5
const SKIP_SECONDS := 1.0
const LOOK_SECONDS := 1.0
## Launch to the first monster noticing the hero, story skipped (pillars.md "First run").
const FIRST_FIGHT_SECONDS := 30.0


# --- The title suite --------------------------------------------------------------

func run_title() -> void:
	await _test_first_descent()
	await _test_privacy_first()
	await _test_launch_to_first_fight()


## A profile with no run: Play says Descend and leads to the game, on Keeper; once a run was
## played (or one is saved), Play enters Kagari again.
func _test_first_descent() -> void:
	Profile.reset()
	Profile.difficulty = &"easy"
	check(Game.first_descent_due(), "a new profile: the first descent is due")
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(2)
	var play := title.get_node("%PlayButton") as Button
	check(play.text == tr("Descend"), "the first Play says Descend (%s)" % play.text)
	check(title.play_scene() == TitleScreen.GAME_SCENE, "the first Play goes straight down the Well, no Kagari")
	check(Profile.difficulty == CONTENT.default_difficulty.id and CONTENT.default_difficulty.id == &"normal", "...on Keeper, whatever the profile held")
	check(not Game.daily_requested and not Game.resume_requested, "...a plain descent")
	title.queue_free()
	await _frames(1)
	Profile.runs = 1
	check(not Game.first_descent_due(), "after a first run: no more first descent")
	var again: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(again)
	await _frames(2)
	check((again.get_node("%PlayButton") as Button).text == tr("Enter Kagari") and again.play_scene() == TitleScreen.VILLAGE_SCENE, "then Play enters Kagari, where the choices are")
	again.queue_free()
	Profile.reset()
	var file := FileAccess.open(RunSave.path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": RunSave.VERSION, "depth": 2, "player": {"level": 3}}))
	file.close()
	check(not Game.first_descent_due(), "a run saved: it is resumed at the Well, no first descent")
	RunSave.erase()
	await _frames(2)


## The privacy questions come first (docs/privacy-ops.md): a Play pressed before they were
## answered asks them, and the descent goes on once they are.
func _test_privacy_first() -> void:
	Profile.reset()
	Profile.difficulty = &"easy"
	Profile.seen_intro = true  # (no story: the scene change is the Loader's, held below)
	var privacy := PrivacyTests.new()
	add_child(privacy)
	privacy._use_fake()
	Privacy.reset()
	Privacy.ask_on_title = true
	var was_busy := Loader.busy
	Loader.busy = true  # (the scene change itself is not for this test)
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(2)
	check(Privacy.should_ask(), "a server and no answer yet: the questions are due")
	title.play()
	await _frames(1)
	check(title.consent.visible and Profile.difficulty == &"easy", "Play before the questions: they are asked first, the descent waits")
	(title.consent.get_node("%AgeOver") as Button).pressed.emit()
	await _frames(1)
	(title.consent.get_node("%DeclineButton") as Button).pressed.emit()
	await _frames(2)
	check(not title.consent.visible and not Privacy.should_ask(), "answered: the questions are gone")
	check(Profile.difficulty == &"normal", "...and the first descent goes on by itself")
	title.queue_free()
	Loader.busy = was_busy
	privacy._restore()
	privacy.queue_free()
	Profile.reset()
	await _frames(2)


## Launch to the first monster that notices the hero, for a new profile skipping the story, on
## the real flow's pieces at 60 fixed frames a second: the title (its questions answered, Play),
## the story (Skip), the loading screen, the first floor with its act card, a hero walking to the
## first monster (hints on, as for a new player). Under 30 s. (The phone's real loading times
## add to it: not measured here.)
func _test_launch_to_first_fight() -> void:
	Profile.reset()
	FirstSteps.enabled = true
	Settings.tutorial_hints = true
	var seconds := TitleScreen.PRIVACY_DELAY + ANSWER_SECONDS
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(roundi(PLAY_SECONDS * 60.0))
	seconds += PLAY_SECONDS
	var next := title.play_scene()
	check(next == TitleScreen.GAME_SCENE, "the first Play leads to the game")
	title.queue_free()
	StoryScreen.next_scene = next
	var was_busy := Loader.busy
	Loader.busy = true  # (Skip asks the Loader for the game: made below instead)
	var story: StoryScreen = load("res://src/ui/story/story_screen.tscn").instantiate()
	add_child(story)
	await _frames(roundi(SKIP_SECONDS * 60.0))
	seconds += SKIP_SECONDS
	(story.get_node("%SkipButton") as Button).pressed.emit()
	check(Profile.seen_intro, "Skip ends the story")
	story.queue_free()
	Loader.busy = was_busy
	# The loading screen's own time (Loader.go: fade in, at least MIN_TIME shown, three frames).
	seconds += Loader.FADE + Loader.MIN_TIME + 3.0 / 60.0
	var noticed := [false]
	var on_noticed := func(_monster: Monster) -> void: noticed[0] = true
	Events.monster_noticed.connect(on_noticed)
	var game := GAME_SCENE.instantiate() as Game
	add_child(game)  # (act cards on: the real first floor)
	var frames := 0
	var looked := 0
	var path := PackedVector2Array()
	while not noticed[0] and frames < 60 * 40:
		var player := game.player
		if player and not game.act_card.visible and game._fade.color.a < 0.05 and not get_tree().paused:
			looked += 1
			if looked > roundi(LOOK_SECONDS * 60.0):
				var target := _nearest_monster(game.world, player)
				var direction := Vector2.ZERO
				if target:
					if frames % 20 == 0 or path.is_empty():
						path = game.world.find_path(player.global_position, target.global_position)
					while path.size() > 0 and player.global_position.distance_to(path[0]) < 10.0:
						path.remove_at(0)
					direction = player.global_position.direction_to(path[0] if path.size() > 0 else target.global_position)
				_set_move(direction)
				_set_action(&"attack", frames % 30 == 0)  # (a swing now and then, as a new player does)
		await get_tree().physics_frame
		frames += 1
	_set_move(Vector2.ZERO)
	Input.action_release(&"attack")
	Events.monster_noticed.disconnect(on_noticed)
	seconds += frames / 60.0
	print("launch to the first monster noticing the hero: %.1f s (%.1f s of it on the first floor)" % [seconds, frames / 60.0])
	check(noticed[0] and seconds < FIRST_FIGHT_SECONDS, "a new player meets the first monster within %d s of launching, story skipped (%.1f s)" % [FIRST_FIGHT_SECONDS, seconds])
	game.queue_free()
	Settings.tutorial_hints = false
	Profile.reset_hints()
	await _frames(3)


# --- The game suite: the first steps --------------------------------------------------

## The first runs' first floor: the slow first monster alone in the next room, the hero
## sheltered in his first room until he has walked and struck, the same floor again from a save;
## none of it on the fourth run nor in a Dawn Knell.
func run_first_steps(game: Game) -> void:
	var rules := CONTENT.first_steps
	check(rules != null and rules.monster != null and rules.runs == 3, "the first steps' rules: the first three runs")
	Profile.reset()
	FirstSteps.enabled = true
	game.start_run()
	await _frames(5)
	var world := game.world
	var player := game.player
	check(Profile.runs == 1 and world.first_steps == game.first_steps and game.first_steps.def == rules, "the first run's first floor starts gently")
	var first := _first_monster(game)
	check(first != null, "the slow first monster is laid")
	if first == null:
		return
	var laid_at := first.global_position  # (where it was laid: it may wander off before the save)
	var map := world.map
	var its_room := map.room_at(map.world_to_cell(first.global_position))
	var nearest_room := 999
	for monster in world.get_hostiles(Actor.Faction.PLAYER):
		var index := map.room_at(map.world_to_cell(monster.global_position))
		if index >= 1 and (monster as Monster).floor_index >= 0:
			nearest_room = mini(nearest_room, index)
			if index == its_room:
				check(monster == first, "it is alone in its room (%s there)" % (monster as Monster).def.id)
	check(its_room == nearest_room, "in the nearest room holding monsters (room %d, nearest %d)" % [its_room, nearest_room])
	check(first.def.id == rules.monster.id, "of its kind for the bestiary and the kills (%s)" % first.def.id)
	check(first.def.attack_windup * first.get_telegraph_scale() >= 0.6 and first.get_move_speed() < player.get_move_speed() * 0.4, "slow and plainly telegraphed (wind-up %.2f s, speed %d)" % [first.def.attack_windup * first.get_telegraph_scale(), first.get_move_speed()])
	# Ordinary blows, their variance both ways (a critical one may end it sooner).
	var power := player.get_power()
	var defense := first.get_stats().defense
	var weakest := Combat.mitigate(roundi(power * (1.0 - Combat.RULES.damage_variance)), defense)
	var strongest := Combat.mitigate(roundi(power * (1.0 + Combat.RULES.damage_variance)), defense)
	var most_blows := ceili(float(first.get_max_hp()) / weakest)
	var fewest_blows := ceili(float(first.get_max_hp()) / strongest)
	check(player.get_weapon().id == &"katana" and fewest_blows >= 2 and most_blows <= 3, "it dies in 2 or 3 blows of the starting katana (%d to %d, %d Health)" % [fewest_blows, most_blows, first.get_max_hp()])
	# Sheltered: a rat right beside him in his first room doesn't notice him, standing still.
	var noticed := [0]
	var on_noticed := func(_monster: Monster) -> void: noticed[0] += 1
	Events.monster_noticed.connect(on_noticed)
	var hp := player.hp
	var rat_def: MonsterDef = load("res://data/monsters/rat.tres")
	var rat := world.spawn_monster(rat_def, world.find_open_point_near(player.global_position + Vector2(40, 0), 32.0, WorldSpace.room_for(rat_def)))
	await _frames(180)
	check(noticed[0] == 0 and rat.target == null and player.hp == hp, "standing in his first room, the hero is left alone (noticed %d, Health %d of %d)" % [noticed[0], player.hp, hp])
	check(world.shelters(player), "...sheltered")
	# Walked but not struck yet: still sheltered.
	for i in 40:
		_set_move(Vector2.LEFT if i < 20 else Vector2.RIGHT)
		await _frames(1)
	_set_move(Vector2.ZERO)
	await _frames(30)
	check(world.shelters(player) and noticed[0] == 0, "walked but not struck: still left alone")
	_set_action(&"attack", true)
	await _frames(2)
	_set_action(&"attack", false)
	await _frames(2)
	check(not world.shelters(player) and game.first_steps.is_lifted(), "walked and struck: the shelter is over")
	if is_instance_valid(rat):
		rat.queue_free()  # (the swing may have slain it: another one)
	var watcher := world.spawn_monster(rat_def, world.find_open_point_near(player.global_position + Vector2(48, 0), 32.0, WorldSpace.room_for(rat_def)))
	await _until(func() -> bool: return noticed[0] > 0, 3.0)
	check(noticed[0] > 0, "then the monsters see him")
	Events.monster_noticed.disconnect(on_noticed)
	watcher.queue_free()
	# The same floor from its save: the first monster again, with its number.
	var number := first.floor_index
	game._save_run()
	var saved := RunSave.read()
	game.resume_run(saved)
	await _frames(5)
	var again := _first_monster(game)
	check(again != null and again.floor_index == number and again.global_position.distance_to(laid_at) < 8.0, "picked up again, the floor has its first monster where it was laid (%s, %s)" % [again.global_position if again else Vector2.INF, laid_at])
	# The fourth run, and a Dawn Knell: an ordinary first floor.
	Profile.runs = rules.runs
	RunSave.erase()
	game.start_run()
	await _frames(5)
	check(Profile.runs == rules.runs + 1 and game.first_steps.def == null and game.world.first_steps == null and _first_monster(game) == null, "the fourth run starts as any other")
	Profile.runs = 0
	game.start_run(true)
	await _frames(5)
	check(game.run.is_daily() and game.world.first_steps == null, "a Dawn Knell is the same for everyone: no gentle start")
	FirstSteps.enabled = false


## The first steps' monster on the floor (its gentle numbers), or null.
func _first_monster(game: Game) -> Monster:
	var rules := CONTENT.first_steps
	for monster in game.world.get_hostiles(Actor.Faction.PLAYER):
		var each := monster as Monster
		if each and each.def.id == rules.monster.id and is_equal_approx(each.def.attack_windup, rules.attack_windup) and each.def != rules.monster:
			return each
	return null


# --- Descend again ----------------------------------------------------------------------

## The death screen's Descend again: straight into the next descent (same difficulty and oath, no
## Kagari), the run that ended recorded once and its save gone; not on a victory's screen.
func run_descend_again(game: Game) -> void:
	Profile.reset()
	Profile.difficulty = &"hard"
	game.start_run()
	await _frames(5)
	var ended := game.run
	check(ended.difficulty.id == &"hard" and Profile.runs == 1, "a run on Martyr")
	_killing_blow(game.player)
	check(await _until(func() -> bool: return game.game_over_panel.visible, 4.0), "death: the end screen")
	var descend := game.game_over_panel.get_node("%DescendButton") as Button
	check(descend.is_visible_in_tree() and descend.text == tr("Descend again"), "the death screen offers Descend again")
	check(Profile.history.size() == 1 and not FileAccess.file_exists(RunSave.path), "the run is in the history, its save erased")
	descend.pressed.emit()
	await _frames(5)
	check(game.run != ended and game.run.depth == 1 and not game.player.is_dead and not game.game_over_panel.visible and not get_tree().paused, "a new descent at once, on floor 1")
	check(game.run.difficulty.id == &"hard" and Profile.runs == 2, "...on the same difficulty, counted as a run")
	check(Profile.history.size() == 1, "...the last run recorded once")
	check(FileAccess.file_exists(RunSave.path) and int(RunSave.read().get("depth", 0)) == 1, "...and the new one saved as its floor begins")
	game.game_over_panel.show_end(true, "", [], 0, 0)
	check(not descend.is_visible_in_tree() and (game.game_over_panel.get_node("%ContinueButton") as Button).is_visible_in_tree(), "a victory's screen keeps its own choices")
	game.game_over_panel.hide()


# --- Hints --------------------------------------------------------------------------------

## Every hint fits one line of the HintBox, in English and French, by touch, keys and gamepad, the
## board clear of the minimap; one that runs out unread comes back on a later floor (once), its
## chain with it; read ones are in the codex's Tips.
func run_hints(game: Game) -> void:
	var box := game.hint_box
	var minimap := game.hud.hint_target(&"Minimap")
	var screen := get_viewport().get_visible_rect()
	var long := PackedStringArray()
	for language in ["en", "fr"]:
		TranslationServer.set_locale(language)
		for kind in [InputDevice.Kind.TOUCH, InputDevice.Kind.KEYBOARD, InputDevice.Kind.GAMEPAD]:
			InputDevice.use(kind)
			for hint in CONTENT.tutorial.hints:
				box.show_hint(hint, Rect2())
				await _frames(1)
				var board := box.board_rect()
				if box.text_lines() != 1 or not screen.encloses(board) or (minimap.has_area() and board.end.x > minimap.position.x):
					long.append("%s/%d %s (%d lines, %s)" % [language, kind, hint.id, box.text_lines(), board])
	box.hide_hint()
	TranslationServer.set_locale("en")
	InputDevice.use(InputDevice.Kind.TOUCH)
	check(long.is_empty(), "every hint is one line, the board on screen and clear of the minimap: %s" % ", ".join(long.slice(0, 6)))
	# Run out unread: not seen, back on a later floor, then seen.
	var tutorial := game.tutorial
	Settings.tutorial_hints = true
	Profile.reset_hints()
	game.player.invincible = true
	var ambush := CONTENT.tutorial.hint(&"ambush")
	tutorial.cue(&"ambush")
	await _until(func() -> bool: return tutorial.current == ambush, 3.0)
	check(tutorial.current == ambush, "a hint shows")
	await _until(func() -> bool: return tutorial.current == null, ambush.duration + 1.0)
	check(not Profile.has_seen_hint(&"ambush"), "its time out, unread: not seen")
	tutorial.cue(&"ambush")
	await _frames(roundi((CONTENT.tutorial.gap + 0.5) * 60.0))
	check(tutorial.current != ambush, "not again on the same floor")
	game.world.floor_id += 1  # (another floor)
	tutorial.cue(&"ambush")
	await _until(func() -> bool: return tutorial.current == ambush, 3.0)
	check(tutorial.current == ambush, "back on a later floor")
	await _until(func() -> bool: return tutorial.current == null, ambush.duration + 1.0)
	check(Profile.has_seen_hint(&"ambush"), "run out again: now it counts as seen")
	# A chained hint (no cue of its own) that ran out comes back as a floor starts.
	Profile.mark_hint(&"move")
	tutorial.cue(&"monster_noticed")
	await _until(func() -> bool: return tutorial.current != null and tutorial.current.id == &"attack", 3.0)
	tutorial.action(&"attacked")
	check(Profile.has_seen_hint(&"attack"), "done: seen")
	var roll := CONTENT.tutorial.hint(&"roll")
	await _until(func() -> bool: return tutorial.current == roll, 3.0)
	check(tutorial.current == roll, "the next step of the chain shows")
	await _until(func() -> bool: return tutorial.current == null, roll.duration + 1.0)
	check(not Profile.has_seen_hint(&"roll"), "run out unread: not seen")
	game.world.floor_id += 1
	tutorial.cue(&"floor_start")
	await _until(func() -> bool: return tutorial.current == roll, 3.0)
	check(tutorial.current == roll, "the chain's step comes back as the next floor starts")
	tutorial.dismiss()
	check(Profile.has_seen_hint(&"roll"), "a tap: read, seen")
	Settings.tutorial_hints = false
	# The codex's Tips: the hints seen, and only those.
	var codex := (load("res://src/ui/codex/codex_panel.tscn") as PackedScene).instantiate() as CodexPanel
	add_child(codex)
	await _frames(1)
	codex.open(CONTENT, CodexPanel.Tab.TIPS)
	await _frames(1)
	var list := codex.get_node("%List")
	var shown := list.get_children().filter(func(n: Node) -> bool: return String(n.name).begins_with("Tip_")).map(func(n: Node) -> String: return String(n.name).trim_prefix("Tip_"))
	var seen := CONTENT.tutorial.hints.filter(func(h: HintDef) -> bool: return Profile.has_seen_hint(h.id)).map(func(h: HintDef) -> String: return String(h.id))
	check(shown == seen and seen.has("ambush") and seen.has("roll") and not shown.has("charge"), "the Tips tab lists the hints seen, and only those (%s)" % [shown])
	check((codex.get_node("%Summary") as Label).text == tr("Tips seen: %d of %d") % [seen.size(), CONTENT.tutorial.hints.size()], "...and says how many")
	codex.queue_free()
	Profile.reset_hints()
	game.player.invincible = false
	await _frames(1)
