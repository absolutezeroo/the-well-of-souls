class_name DialogueTests
extends PcTests
## The dialogue (docs/design/presentation.md "The Vigil-Keeper and the keepers"): speakers, lines,
## Dialogues, the run's facts, the DialogueBox. Unit part (unit suite): every line's data (lengths,
## translations, codes, the reveal), which tale and which advice a staged death gets (a boss, its
## shockwave, a trap, the Deeps, a curse's cold, the Threshold, an early death streak, the Pilgrim's
## way, potions left), the memory (once, cooldowns, turns), the keepers' lines gated and kept, the
## save, the codex's Voices, the box by touch, keys and gamepad. Title part (title suite): the
## Vigil-Keeper at the shrine, her words by touch, keys and gamepad, the lamps, the layouts. Game
## part (game suite): a real death told on the end screen, a trap's, the keepers' panels, the end
## screen's layout in French.

const MAX_LINE := 150
## The codes a line may hold (RunFacts.codes()).
const CODES := ["killer", "floor", "act", "biome", "place", "level", "time", "kills", "curse", "weapon", "boss"]
var _ends := RegEx.create_from_string("(?<!\\.)[.?!](?!\\.)(?=\\s|$|\"|\u202f|»)")
var _code := RegEx.create_from_string("\\{([a-z_]+)\\}")


# --- Helpers ------------------------------------------------------------------------------

func _narrative() -> NarrativeDef:
	return CONTENT.narrative


func _dialogue(id: String) -> DialogueDef:
	for dialogue in _narrative().dialogues:
		if dialogue.id == StringName(id):
			return dialogue
	return null


## A death as the Game would have read it: `fields` set on fresh facts (a death on Keeper,
## floor 4 of Act II, level 8, by default).
func _death(fields: Dictionary = {}) -> RunFacts:
	var facts := RunFacts.new()
	facts.won = false
	facts.depth = 4
	facts.act = 2
	facts.act_title = "Ossuary of Kagari"
	facts.biome = "Catacombs"
	facts.place = "Ossuary of Kagari"
	facts.level = 8
	facts.seconds = 600.0
	facts.difficulty_id = &"normal"
	facts.marks = {"drank": true, "rolled": true}
	facts.armor_worn = 2
	for key: String in fields:
		facts.set(key, fields[key])
	return facts


func _killed_by(id: String, fields: Dictionary = {}) -> RunFacts:
	var monster := _monster(id)
	var all := {"killer_id": StringName(id), "killer_name": monster.display_name if monster else id,
		"killer_boss": monster is BossDef, "cause": &"monster"}
	all.merge(fields, true)
	return _death(all)


func _monster(id: String) -> MonsterDef:
	for monster in CONTENT.all_monsters():
		if monster.id == StringName(id):
			return monster
	for act in CONTENT.dungeon.acts:
		for boss in act.all_bosses():
			if boss and boss.id == StringName(id):
				return boss
	var finale := CONTENT.dungeon.finale
	if finale:
		for form in finale.all_bosses():
			if form.id == StringName(id):
				return form
	var hidden := CONTENT.dungeon.hidden_floor
	if hidden and hidden.boss and hidden.boss.id == StringName(id):
		return hidden.boss
	return null


## The line `dialogue` would say for `facts` now (its id, "" for none).
func _picks(dialogue: String, facts: RunFacts) -> String:
	var line := Dialogues.pick(_dialogue(dialogue), facts, _rng())
	return String(line.id) if line else ""


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return rng


func _snapshot() -> Dictionary:
	var saved := {}
	for field in ["lines_told", "lines_order", "deaths_by", "stats", "history", "souls", "runs", "wins",
			"victories", "kills_by_monster", "boss_meetings", "ending", "fragments_found", "deepest", "best_depth",
			"levels", "seen_monsters"]:
		var value: Variant = Profile.get(field)
		saved[field] = value.duplicate(true) if value is Dictionary or value is Array else value
	return saved


func _restore(saved: Dictionary) -> void:
	for field: String in saved:
		Profile.set(field, saved[field])


## A profile that heard nothing, won nothing, died nowhere.
func _fresh() -> void:
	Profile.lines_told = {}
	Profile.lines_order = {}
	Profile.deaths_by = {}
	Profile.stats = {}
	Profile.history = []
	Profile.souls = 0
	Profile.runs = 1
	Profile.wins = {}
	Profile.victories = 0
	Profile.kills_by_monster = {}
	Profile.boss_meetings = {}
	Profile.ending = &""
	Profile.fragments_found = {}
	Profile.deepest = 0
	Profile.best_depth = 0
	Profile.levels = {}
	Profile.seen_monsters = {}


## The keeper's name may be said (the Effigy slain and a run won).
func _reveal() -> void:
	Profile.record_kill(&"nameless_effigy")
	Profile.wins["normal"] = 1


func _died(depth: int) -> void:
	Profile.history.push_front({"depth": depth, "won": false})


func _names_keeper(text: String) -> bool:
	var fr := TranslationServer.get_translation_object("fr")
	var french := String(fr.get_message(text)) if fr else ""
	for word in _narrative().reveal_words:
		if text.contains(word) or french.contains(word):
			return true
	return false


func _gated_by_reveal(conditions: Array[ProgressCondition]) -> bool:
	var reveal := _narrative().keeper_reveal
	return conditions.any(func(c: ProgressCondition) -> bool:
		return c == reveal or (c is AllCondition and (c as AllCondition).contains(reveal)) \
			or (c is AnyCondition and (c as AnyCondition).contains(reveal)))


func _click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		get_viewport().push_input(event)


func _touch_at(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.pressed = pressed
		event.position = at
		Input.parse_input_event(event)  # as a phone sends it (the screen makes a click of it too)
		await _frames(1)


# --- Unit ---------------------------------------------------------------------------------

func run_unit() -> void:
	var saved := _snapshot()
	_fresh()
	_test_data()
	_test_reveal()
	_test_conditions()
	_test_tales()
	_test_advice()
	_test_memory()
	_test_keepers()
	_test_save()
	await _test_codex_voices()
	await _test_box()
	await _test_reading()
	_restore(saved)
	InputDevice.use(InputDevice.Kind.TOUCH)


## Every dialogue's data: unique ids, a speaker with a face, its lines translated, at most two
## sentences and 150 letters a page in both languages, no exclamation mark, only known codes, a
## line kept in the codex holds none; every hook listed; enough to say.
func _test_data() -> void:
	var narrative := _narrative()
	var fr := TranslationServer.get_translation_object("fr")
	check(narrative.shrine_speaker != null and narrative.shrine_speaker.portrait != null and narrative.shrine_speaker.figure != null, "someone keeps vigil at the shrine, with a face and a body")
	var hooks: Array[DialogueDef] = []
	hooks.append_array(narrative.shrine_dialogues)
	hooks.append_array(narrative.death_dialogues)
	hooks.append_array(narrative.victory_dialogues)
	for hook in [CONTENT.dungeon.merchant.dialogue, CONTENT.dungeon.forge.dialogue, (load("res://data/encounters/grinning_spirit.tres") as EncounterDef).dialogue]:
		check(hook != null, "the merchant, the smith and the grinning spirit have their dialogue")
		if hook:
			hooks.append(hook)
	for hook in hooks:
		check(narrative.dialogues.has(hook), "%s is listed in NarrativeDef.dialogues" % hook.id)
	var ids := {}
	var counts := {}
	for dialogue in narrative.dialogues:
		check(not ids.has(dialogue.id) and dialogue.id != &"", "dialogue ids are unique (%s)" % dialogue.id)
		ids[dialogue.id] = true
		var speaker := dialogue.speaker
		check(speaker != null and speaker.portrait != null and not speaker.display_name.is_empty(), "%s: a speaker with a name and a face" % dialogue.id)
		if speaker:
			for text in [speaker.display_name, speaker.title]:
				check(fr != null and not String(fr.get_message(text)).is_empty(), "%s: its speaker's name and title are translated" % dialogue.id)
		var line_ids := {}
		for line in dialogue.lines:
			var where := "%s/%s" % [dialogue.id, line.id]
			check(not line_ids.has(line.id) and line.id != &"", "%s: line ids are unique" % where)
			line_ids[line.id] = true
			check(line.lines.size() >= 1 and line.lines.size() <= 3, "%s: one to three pages" % where)
			for page in line.lines:
				_check_page(fr, page, where, line.remembered)
		counts[dialogue.id] = dialogue.lines.size()
	check(int(counts.get(&"vigil_tale", 0)) + int(counts.get(&"vigil_advice", 0)) >= 25, "the Vigil-Keeper has 25 death tales and pieces of advice or more")
	check(int(counts.get(&"vigil_shrine", 0)) >= 15, "and 15 lines at the shrine or more")
	for keeper in [&"wanderer", &"smith", &"grinning_spirit"]:
		check(int(counts.get(keeper, 0)) >= 8, "%s has 8 lines or more" % keeper)
	# The advice names only wardens that exist (KillerCondition ids are real monsters).
	for dialogue in narrative.dialogues:
		for line in dialogue.lines:
			for condition in line.conditions:
				if condition is KillerCondition:
					for id in (condition as KillerCondition).monster_ids:
						check(_monster(String(id)) != null, "%s/%s: its killer %s is a monster of the game" % [dialogue.id, line.id, id])


func _check_page(fr: Translation, page: String, where: String, remembered: bool) -> void:
	var french := String(fr.get_message(page)) if fr else ""
	check(not french.is_empty(), "%s: translated: %s" % [where, page.left(40)])
	for text: String in [page, french]:
		check(text.length() <= MAX_LINE, "%s: at most %d letters (%d): %s" % [where, MAX_LINE, text.length(), text.left(40)])
		check(_ends.search_all(text).size() <= 2, "%s: at most two sentences: %s" % [where, text.left(40)])
		check(not text.contains("!"), "%s: no exclamation mark: %s" % [where, text.left(40)])
		for found in _code.search_all(text):
			check(CODES.has(found.get_string(1)), "%s: {%s} is a known code" % [where, found.get_string(1)])
	var codes_en := _code.search_all(page).map(func(m: RegExMatch) -> String: return m.get_string(1))
	var codes_fr := _code.search_all(french).map(func(m: RegExMatch) -> String: return m.get_string(1))
	codes_en.sort()
	codes_fr.sort()
	check(codes_en == codes_fr, "%s: the French keeps the same codes" % where)
	check(not remembered or codes_en.is_empty(), "%s: a line kept in the codex holds no run's code" % where)


## No line naming Tôma before the reveal: in the data (every one asks for the reveal) and in play
## (everything else done, staged deaths: nothing open names him).
func _test_reveal() -> void:
	var named := 0
	for dialogue in _narrative().dialogues:
		for line in dialogue.lines:
			if _names_keeper(" ".join(line.lines)):
				named += 1
				check(_gated_by_reveal(line.conditions), "%s/%s names the keeper: it waits for the reveal" % [dialogue.id, line.id])
	check(named >= 4, "after the reveal, the Vigil-Keeper and the keepers name him (%d lines)" % named)
	_fresh()
	Profile.stats = {"bosses": 9, "fragments": 20, "deaths": 30, "talk:wanderer": 20, "talk:smith": 20, "talk:grinning_spirit": 20}
	Profile.wins["normal"] = 2
	Profile.runs = 30
	Profile.deepest = 12
	for id in ["gilded_hoarder", "azure_wyrm", "king_slime"]:
		Profile.record_kill(StringName(id))
		Profile.mark_seen(StringName(id))
	var leaks := PackedStringArray()
	var deaths: Array[RunFacts] = [_killed_by("gilded_hoarder"), _killed_by("skeleton"), _death({"cause": &"trap"}), _death({"in_deeps": true}), _death({"won": true})]
	for dialogue in _narrative().dialogues:
		for facts: RunFacts in deaths + [null]:
			for line in Dialogues.available(dialogue, facts):
				if _names_keeper(" ".join(line.lines)):
					leaks.append("%s/%s" % [dialogue.id, line.id])
	check(leaks.is_empty(), "nothing said names the keeper before the reveal: %s" % ", ".join(leaks))
	_reveal()
	check(Dialogues.available(_dialogue("vigil_shrine")).any(func(l: DialogueLineDef) -> bool: return l.id == &"she_breaks"), "after the reveal, the Vigil-Keeper breaks and names him")
	_fresh()


## The run's conditions read the facts, and only them (never met without).
func _test_conditions() -> void:
	_fresh()
	var boss := KillerCondition.new()
	boss.kind = KillerCondition.Kind.BOSS
	check(boss.is_met(_killed_by("demon_cyclops")) and not boss.is_met(_killed_by("skeleton")) and not boss.is_met(null), "KillerCondition: a boss, not a skeleton, nothing without facts")
	var ranged := KillerCondition.new()
	ranged.kind = KillerCondition.Kind.RANGED
	check(ranged.is_met(_death({"killer_id": &"x", "killer_ranged": true})) and not ranged.is_met(_death({"cause": &"trap"})), "a monster fighting from afar; a trap is no monster")
	var trap := CauseCondition.new()
	trap.causes = [&"trap"]
	check(trap.is_met(_death({"cause": &"trap"})) and not trap.is_met(_death({"cause": &"fall"})), "CauseCondition")
	var deeps := PlaceCondition.new()
	deeps.where = PlaceCondition.Where.DEEPS
	var early := PlaceCondition.new()
	early.max_depth = 2
	check(deeps.is_met(_death({"in_deeps": true})) and not deeps.is_met(_death()), "PlaceCondition: the Deeps")
	check(early.is_met(_death({"depth": 2})) and not early.is_met(_death({"depth": 3})), "PlaceCondition: depths")
	var no_potion := RunMarkCondition.new()
	no_potion.mark = &"drank"
	no_potion.present = false
	check(no_potion.is_met(_death({"marks": {}})) and not no_potion.is_met(_death()), "RunMarkCondition: a run that never drank")
	var behind := LevelCondition.new()
	check(behind.is_met(_death({"depth": 6, "level": 4})) and not behind.is_met(_death({"depth": 6, "level": 8})), "LevelCondition: level 4 on floor 6 is behind")
	var gear := GearCondition.new()
	gear.potions_at_least = 1
	check(gear.is_met(_death({"potions_left": 2})) and not gear.is_met(_death()), "GearCondition: potions left")
	var bare := GearCondition.new()
	bare.armor_at_most = 0
	check(bare.is_met(_death({"armor_worn": 0})) and not bare.is_met(_death()), "GearCondition: no armor")
	var won := OutcomeCondition.new()
	won.outcome = OutcomeCondition.Outcome.VICTORY
	won.ending = &"ring_the_bell"
	check(won.is_met(_death({"won": true, "ending": &"ring_the_bell"})) and not won.is_met(_death({"won": true})), "OutcomeCondition: a victory with its ending")
	var streak := DeathStreakCondition.new()
	streak.count = 3
	streak.max_depth = 3
	for depth in [2, 3, 1]:
		_died(depth)
	check(streak.is_met(_death()), "DeathStreakCondition: three early deaths in a row")
	_died(5)
	check(not streak.is_met(_death()), "a deeper death breaks the streak")
	var again := DeathCountCondition.new()
	again.at_least = 3
	for i in 3:
		Profile.record_death(&"demon_cyclops")
	check(again.is_met(_killed_by("demon_cyclops")) and not again.is_met(_killed_by("skeleton")), "DeathCountCondition: the same killer three times")
	var never := NotCondition.new()
	never.condition = _narrative().keeper_reveal
	check(never.is_met(), "NotCondition: before the reveal")
	_reveal()
	check(not never.is_met(), "and not after")
	var ending := EndingCondition.new()
	ending.ending = &"take_his_place"
	Profile.ending = &"take_his_place"
	check(ending.is_met(), "EndingCondition reads the ending chosen")
	_fresh()


## Which tale a staged death gets (the most precise one).
func _test_tales() -> void:
	_fresh()
	var tale := _dialogue("vigil_tale")
	Narrative.tell_line(tale, tale.line(&"first_death"))  # the first death is told once, first
	check(_picks("vigil_tale", _killed_by("demon_cyclops")) in ["boss", "boss_time"], "a warden's kill: a warden's tale (%s)" % _picks("vigil_tale", _killed_by("demon_cyclops")))
	check(_picks("vigil_tale", _killed_by("demon_cyclops", {"cause": &"shockwave"})) == "shockwave", "its shockwave: told as such")
	check(_picks("vigil_tale", _death({"cause": &"trap"})) == "trap", "a trap's death")
	check(_picks("vigil_tale", _killed_by("skeleton", {"in_deeps": true})) == "deeps", "a death in the Deeps")
	check(_picks("vigil_tale", _death({"cause": &"cold", "curse_id": &"frostbound"})) == "cold", "the cold of a cursed floor")
	check(_picks("vigil_tale", _killed_by("skeleton", {"threshold_lost": true})) == "threshold", "the Threshold lost")
	check(_picks("vigil_tale", _death({"cause": &"giving_up"})) == "giving_up", "giving up")
	check(_picks("vigil_tale", _killed_by("skeleton", {"depth": 1})) == "early", "an early death")
	check(_picks("vigil_tale", _death({"cause": &"unknown"})) == "unknown", "nothing known: still a tale")
	check(_picks("vigil_tale", _killed_by("the_maw")) == "by_maw", "the Maw")
	check(_picks("vigil_tale", _death({"won": true})) == "", "no death tale for a victory")
	# The first death: welcomed once, then never again.
	_fresh()
	Profile.record_death(&"skeleton")
	var first := Dialogues.say(_dialogue("vigil_tale"), _killed_by("skeleton"))
	check(first != null and first.line.id == &"first_death", "the first death ever: she welcomes the hero back")
	check(first != null and first.pages.size() == 2 and first.text().contains("Skeleton") and first.text().contains("floor 4"), "and tells who and where (%s)" % (first.text() if first else ""))
	check(_picks("vigil_tale", _killed_by("skeleton")) != "first_death", "only once")
	# Codes filled in French too.
	Settings.language = "fr"
	Settings.apply()
	var french := Dialogues.pages(_dialogue("vigil_tale").line(&"monster"), _killed_by("skeleton"))
	check(french[0].begins_with("Squelette, étage 4, Catacombes :"), "the tale in French, its codes filled: %s" % french[0])
	Settings.language = "en"
	Settings.apply()
	_fresh()


## Which advice a staged death gets: one, concrete, true to the game.
func _test_advice() -> void:
	_fresh()
	check(_picks("vigil_advice", _killed_by("demon_cyclops")) == "demon_cyclops", "killed by Gorr: how Gorr fights")
	check(_picks("vigil_advice", _killed_by("crimson_tengu")) == "crimson_tengu", "killed by the Tengu: how it steps")
	check(_picks("vigil_advice", _killed_by("demon_cyclops", {"cause": &"shockwave"})) == "shockwave", "its shockwave: stop striking or roll through the ring")
	check(_picks("vigil_advice", _death({"cause": &"trap"})) == "trap", "a trap: traps warn")
	check(_picks("vigil_advice", _killed_by("skeleton", {"in_deeps": true})) == "deeps", "the Deeps: seek the Dawn Breach")
	check(_picks("vigil_advice", _death({"cause": &"cold"})) == "cold", "the cold: stay by the campfires")
	check(_picks("vigil_advice", _killed_by("skeleton", {"threshold_lost": true})) == "threshold", "the Threshold: slay faster")
	check(_picks("vigil_advice", _killed_by("skeleton", {"potions_left": 3})) == "potions", "potions left: drink before the last breath")
	check(_picks("vigil_advice", _killed_by("skeleton", {"marks": {"drank": true}})) == "never_rolled", "never rolled: the roll goes through blows")
	check(_picks("vigil_advice", _killed_by("skeleton", {"armor_worn": 0})) == "no_armor", "no armor")
	check(_picks("vigil_advice", _killed_by("skeleton", {"depth": 7, "level": 4})) == "underlevel", "far behind in levels: slay on the way")
	var archer := _killed_by("skeleton", {"killer_ranged": true})
	check(_picks("vigil_advice", archer) == "ranged", "killed from afar: close in or use the walls")
	check(_picks("vigil_advice", _killed_by("skeleton")) in ["watch_shoulder", "charged", "families", "runes", "belt", "breathe"], "nothing precise: one of the master's lessons")
	# Early deaths, again and again: the shrine (souls to offer), else the Pilgrim's way.
	for depth in [2, 1, 3, 2]:
		_died(depth)
	Profile.souls = 80
	check(_picks("vigil_advice", _killed_by("skeleton", {"depth": 2})) == "early_shrine", "early deaths in a row with souls to offer: the Tree of Souls")
	Profile.souls = 0
	check(_picks("vigil_advice", _killed_by("skeleton", {"depth": 2})) == "pilgrim", "no souls to offer, four early deaths on Keeper: the Pilgrim's way")
	check(_picks("vigil_advice", _killed_by("skeleton", {"depth": 2, "difficulty_id": &"easy"})) != "pilgrim", "never told to a Pilgrim")
	Profile.wins["normal"] = 1
	check(_picks("vigil_advice", _killed_by("skeleton", {"depth": 2})) != "pilgrim", "nor to one who has won")
	# The same warden, again and again: the codex.
	_fresh()
	for i in 3:
		Profile.record_death(&"gilded_hoarder")
	check(_picks("vigil_advice", _killed_by("gilded_hoarder")) == "boss_codex", "the same warden three times: its page in the codex")
	# The advice the end screen says after the tale.
	var spoken := _narrative().tell_end(_killed_by("demon_cyclops"), _rng())
	check(spoken.size() == 2 and spoken[0].dialogue.id == &"vigil_tale" and spoken[1].dialogue.id == &"vigil_advice", "the end screen: her tale, then one piece of advice")
	check(spoken.size() == 2 and not spoken[0].accent and spoken[1].accent, "the advice stands apart")
	var victory := _narrative().tell_end(_death({"won": true}), _rng())
	check(victory.size() == 1 and victory[0].line.id == &"first", "a first victory: the lamps were blown out by hand")
	_fresh()


## Said once, said again after its runs, said in turn.
func _test_memory() -> void:
	_fresh()
	var advice := _dialogue("vigil_advice")
	var gorr := _killed_by("demon_cyclops")
	Profile.runs = 5
	var first := Dialogues.say(advice, gorr, _rng())
	check(first != null and first.line.id == &"demon_cyclops" and Narrative.is_line_told(advice, first.line), "said: kept as told")
	check(Narrative.line_told_run(advice, first.line) == 5, "with the run it was said in")
	check(_picks("vigil_advice", gorr) == "boss_windup", "the next death to Gorr in the same run: another advice (the wind-up)")
	Profile.runs = 6
	Dialogues.say(advice, gorr, _rng())
	Profile.runs = 7
	check(_picks("vigil_advice", gorr) == "demon_cyclops", "two runs later, Gorr's own again")
	# A line said once is never said again.
	var shrine := _dialogue("vigil_shrine")
	var welcome := Dialogues.say(shrine)
	check(welcome != null and welcome.line.id == &"welcome", "the shrine: her welcome first")
	check(Dialogues.pick(shrine).id != &"welcome", "and never again")
	# Equal lines go in turn: the oldest said first.
	var tale := _dialogue("vigil_tale")
	Profile.record_death(&"skeleton")
	Narrative.tell_line(tale, tale.line(&"first_death"))
	var seen := {}
	for i in 3:
		var said := Dialogues.say(tale, _killed_by("skeleton"), _rng())
		seen[said.line.id] = true
	check(seen.size() == 3, "three deaths to a skeleton, three different tales (%s)" % ", ".join(seen.keys()))
	_fresh()


## The keepers: a line as their panel opens, gated by meetings and progress, said once and kept;
## their greetings when nothing is open.
func _test_keepers() -> void:
	_fresh()
	var shop := CONTENT.dungeon.merchant
	var first := shop.opening_line()
	check(Array(shop.greetings).has(first), "the merchant met once: one of his greetings (%s)" % first)
	var second := shop.opening_line()
	var no_name := shop.dialogue.line(&"no_name")
	check(second == tr(no_name.lines[0]) and Narrative.is_line_told(shop.dialogue, no_name), "met again: his past, a line at a time")
	check(Narrative.told_lines(shop.dialogue).has(no_name), "kept for the codex")
	for i in 10:
		shop.opening_line()
	check(not Narrative.told_lines(shop.dialogue).any(func(l: DialogueLineDef) -> bool: return l.id == &"solhar" or l.id == &"wickless"), "Solhar waits for Act III, the keeper's name for the reveal")
	check(Array(shop.greetings).has(shop.opening_line()), "nothing new to say: a greeting again")
	var forge := CONTENT.dungeon.forge
	forge.opening_line()
	check(forge.opening_line() == tr(forge.dialogue.line(&"each_metal").lines[0]), "Brann too, a line at his second meeting")
	_reveal()
	check(forge.opening_line() == tr(forge.dialogue.line(&"chains").lines[0]), "after the reveal, Brann tells of the chains first")
	var spirit := (load("res://data/encounters/grinning_spirit.tres") as EncounterDef).dialogue
	var said := Dialogues.say(spirit)
	check(said != null and said.line.id == &"whole_village", "the grinning spirit too (the keeper's game, after the reveal)")
	_fresh()


## The dialogue's memory is saved, and a save from before it loads.
func _test_save() -> void:
	_fresh()
	var path := "user://test_dialogue_profile_%d.json" % OS.get_process_id()
	Profile.save_path = path
	Narrative.tell_line(_dialogue("vigil_shrine"), _dialogue("vigil_shrine").line(&"welcome"))
	Profile.record_death(&"demon_cyclops")
	Narrative.count_talk(_dialogue("smith"))
	Profile.save_profile()
	Profile.lines_told = {}
	Profile.deaths_by = {}
	Profile.load_profile()
	check(Narrative.is_line_told(_dialogue("vigil_shrine"), _dialogue("vigil_shrine").line(&"welcome")), "the lines said are saved")
	check(Profile.deaths_to(&"demon_cyclops") == 1 and Narrative.talks(_dialogue("smith")) == 1, "the deaths by killer and the meetings too")
	# A save from before the dialogue: no lines_told, no deaths_by.
	SafeFile.write_json(path, {"souls": 12, "runs": 3})
	Profile.load_profile()
	check(Profile.souls == 12 and Profile.lines_told.is_empty() and Profile.lines_order.is_empty() and Profile.deaths_by.is_empty(), "an older save loads: nothing said yet")
	Profile.save_path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_fresh()


## The codex keeps what each speaker said, by speaker.
func _test_codex_voices() -> void:
	_fresh()
	var shrine := _dialogue("vigil_shrine")
	Narrative.tell_line(shrine, shrine.line(&"welcome"))
	var codex := CodexPanel.new()
	add_child(codex)
	await _frames(2)
	codex.open(CONTENT, CodexPanel.Tab.VOICES)
	await _frames(2)
	var kept := codex.find_child("Voice_vigil_shrine_welcome", true, false) as Label
	check(kept != null and kept.text.contains(tr(shrine.line(&"welcome").lines[0])), "the Voices tab keeps her welcome, whole")
	var texts := PackedStringArray()
	for label: Label in codex.find_children("*", "Label", true, false):
		texts.append(label.text)
	var all := "\n".join(texts)
	check(all.contains("The Vigil-Keeper") and all.contains("Old Wanderer") and all.contains("Brann the Smith") and all.contains("Grinning Spirit"), "every speaker has its place")
	check(all.contains("Nothing heard yet.") and all.contains("Still unheard:"), "what is still to hear is counted, not shown")
	check(not all.contains(tr(shrine.line(&"moonless").lines[0])), "a line not said stays hidden")
	check(_off_grid_texts(codex).is_empty(), "the Voices' texts are on the font's grid")
	codex.queue_free()
	await _frames(1)
	_fresh()


## The box: typed, a tap writes the page out, the next goes on, the last ends it; keys and the
## gamepad's A do the same; stacked, it writes everything and leaves accept alone once written.
func _test_box() -> void:
	_fresh()
	var window := get_tree().root.size
	await _window(Vector2i(1280, 720))
	var holder := Control.new()
	holder.size = Vector2(1280, 720)
	add_child(holder)
	var box := DialogueBox.new(DialogueBox.Mode.PAGED, 900)
	holder.add_child(box)
	var ended := [false]
	box.finished.connect(func() -> void: ended[0] = true)
	var shrine := _dialogue("vigil_shrine")
	var spoken := Dialogues.Spoken.new()
	spoken.dialogue = shrine
	spoken.line = shrine.line(&"welcome")
	spoken.pages = Dialogues.pages(spoken.line)
	box.say([spoken] as Array[Dialogues.Spoken])
	await _frames(20)
	check(box.is_typing() and box.page_index() == 0, "typed letter by letter")
	check(box.shown_text().contains("The Vigil-Keeper"), "under her name")
	_click(box)
	await _frames(8)
	check(not box.is_typing() and box.page_index() == 0, "a click writes the page out")
	await _touch_at(box)
	await _frames(8)
	check(box.page_index() == 1 and box.is_typing(), "a tap goes on to the next page (once: the touch and its click are one tap)")
	_key(KEY_ENTER, true)
	await _frames(1)
	_key(KEY_ENTER, false)
	await _frames(8)
	check(box.page_index() == 1 and not box.is_typing() and not ended[0], "Enter writes it out")
	_pad_button(JOY_BUTTON_A, true)
	await _frames(1)
	_pad_button(JOY_BUTTON_A, false)
	await _frames(8)
	check(ended[0] and box.is_done(), "a gamepad's A ends it after the last page")
	box.queue_free()
	# Stacked: everything typed one line after the other, never waiting.
	var stacked := DialogueBox.new(DialogueBox.Mode.STACKED, 820)
	holder.add_child(stacked)
	var spoken_list := _narrative().tell_end(_killed_by("demon_cyclops"), _rng())
	stacked.say(spoken_list)
	await _frames(20)
	check(stacked.is_typing(), "stacked: typing")
	_key(KEY_ENTER, true)
	await _frames(1)
	_key(KEY_ENTER, false)
	await _frames(1)
	check(stacked.is_done() and stacked.shown_text().contains("Gorr"), "accept writes the tale and the advice out at once")
	check(not stacked.advance(), "written, it takes no more taps: accept is the buttons' again")
	var waiting := DialogueBox.new(DialogueBox.Mode.STACKED, 820)
	holder.add_child(waiting)
	waiting.say(_narrative().tell_end(_killed_by("skeleton"), _rng()))
	for i in 60 * 12:
		await _frames(1)
		if waiting.is_done():
			break
	check(waiting.is_done(), "stacked: it writes everything by itself, no tap needed")
	holder.queue_free()
	await _restore_window(window)
	InputDevice.use(InputDevice.Kind.TOUCH)
	_fresh()


# --- Title --------------------------------------------------------------------------------

func run_title() -> void:
	var saved := _snapshot()
	_fresh()
	var window := get_tree().root.size
	await _window(Vector2i(1280, 720))
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(3)
	var keeper := title.keeper
	check(keeper != null and keeper.is_visible_in_tree(), "the Vigil-Keeper stands at the shrine")
	if keeper == null:
		title.queue_free()
		await _restore_window(window)
		_restore(saved)
		return
	check(keeper.has_news, "with something to say (the bubble)")
	# By touch: a tap on her, a tap a page.
	await _frames(20)
	await _touch_at(keeper)
	await _frames(2)
	check(title.talk.visible and title.talk.box.shown_text().contains("The Vigil-Keeper"), "a tap on her: her words")
	check(Narrative.is_line_told(_dialogue("vigil_shrine"), _dialogue("vigil_shrine").line(&"welcome")), "her welcome first, kept")
	await _frames(20)
	for i in 6:
		if not title.talk.visible:
			break
		await _touch_at(title.talk.get_node("Dim") as Control)
		await _frames(8)
	check(not title.talk.visible, "taps anywhere read on, and the last one closes it")
	# With keys: the focus on her, Enter opens, Enter reads on, Escape closes.
	_keys_mode()
	keeper.grab_focus()
	await _frames(2)
	await _tap_key(KEY_ENTER)
	await _frames(2)
	check(title.talk.visible, "Enter on her: her words")
	check(_focus() == title.talk.box, "the box holds the focus")
	await _frames(20)
	await _tap_key(KEY_ENTER)
	await _frames(8)
	await _tap_key(KEY_ESCAPE)
	check(not title.talk.visible, "Escape closes it")
	await _frames(2)
	check(_focus() == keeper, "the focus back on her")
	# A gamepad.
	InputDevice.use(InputDevice.Kind.GAMEPAD)
	await _tap_pad(JOY_BUTTON_A)
	await _frames(2)
	check(title.talk.visible, "A on her: her words")
	await _frames(20)
	for i in 6:
		if not title.talk.visible:
			break
		await _tap_pad(JOY_BUTTON_A)
		await _frames(8)
	check(not title.talk.visible, "A reads on to the end")
	InputDevice.use(InputDevice.Kind.TOUCH)
	# The lamps burn again with the souls offered to the Tree.
	var backdrop := title.get_node("%Backdrop") as TitleBackdrop
	check(backdrop.lamps_lit == 0, "no soul offered: every lamp out")
	var node := CONTENT.soul_tree.nodes[0]
	Profile.levels[String(node.upgrade.id)] = 1
	title._refresh()
	check(backdrop.lamps_lit >= 1, "a soul offered: a lamp lit (%d)" % backdrop.lamps_lit)
	# Her place and her words fit every screen, in French.
	Settings.language = "fr"
	Settings.apply()
	for size in [Vector2i(1280, 720), Vector2i(2340, 1080), Vector2i(2548, 1296), Vector2i(1540, 720), Vector2i(1024, 768)]:
		await _window(size)
		var screen := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		check(screen.encloses(_rect_of(keeper)), "%s: she stands inside the screen" % size)
		var buttons := _rect_of(title.get_node("Margin/Columns/Left") as Control)
		check(not buttons.intersects(_rect_of(keeper)), "%s: and clear of the menu" % size)
		title.talk_to_keeper()
		await _frames(3)
		var outside := _panel_outside(title.talk)
		check(outside.is_empty(), "%s in French: her box fits (%s)" % [size, ", ".join(outside.slice(0, 3))])
		title.talk.close()
	await _restore_window(window)
	Settings.language = "en"
	Settings.apply()
	title.queue_free()
	await _frames(2)
	_restore(saved)


# --- Game ---------------------------------------------------------------------------------

func run_game(game: Game) -> void:
	var saved := _snapshot()
	_fresh()
	await _test_death_told(game)
	await _test_keeper_panels(game)
	_restore(saved)


## A real death: the facts read as it happened, told on the end screen with an advice; a trap's.
func _test_death_told(game: Game) -> void:
	game.start_run()
	await _frames(5)
	var player := game.player
	_clear_monsters(game.world)
	Profile.record_death(&"skeleton")  # (not the first death: that one welcomes)
	var skeleton := game.world.spawn_monster(load("res://data/monsters/skeleton.tres"), player.global_position + Vector2(40, 0))
	await _frames(2)
	player.perks.clear()
	_killing_blow(player, skeleton)
	check(player.is_dead and player.killer_def != null and player.killer_def.id == &"skeleton" and player.death_cause == &"monster", "the hero knows what killed him, and how")
	await _until(func() -> bool: return game.game_over_panel.visible)  # (the end screen comes a moment after the blow, under the hit stop)
	var facts := game.end_facts
	check(facts != null and facts.killer_id == &"skeleton" and facts.cause == &"monster" and facts.depth == game.depth and facts.level == player.level, "the run's facts are read as he falls")
	check(Profile.history[0].get("killer") == "skeleton" and Profile.deaths_to(&"skeleton") >= 2, "the history and the deaths by killer keep it")
	var panel := game.game_over_panel
	var voice := panel.voice()
	check(panel.visible and voice.is_visible_in_tree(), "the end screen: the Vigil-Keeper speaks")
	var text := panel.shown_text()
	check(text.contains("The Vigil-Keeper") and text.contains("Skeleton"), "she tells this death: %s" % text.left(160))
	check(not (panel.get_node("%Summary") as Label).visible, "her tale replaces the story's random line")
	var told := Narrative.told_lines(_dialogue("vigil_advice"))
	check(not told.is_empty(), "and gives one piece of advice, kept")
	# The buttons answer at once (never held back by her words).
	check(not (panel.get_node("%RestartButton") as Button).disabled, "the buttons are there while she speaks")
	# A trap's death, in French, on a phone and a computer: the screen still fits.
	game.start_run()
	await _frames(5)
	player = game.player
	player.perks.clear()
	player._invulnerable_time = 0.0
	var spikes := HitInfo.new()
	spikes.amount = 99999
	spikes.is_secondary = true
	spikes.cause = &"trap"
	player.take_hit(spikes)
	await _until(func() -> bool: return game.game_over_panel.visible)  # (the end screen comes a moment after the blow, under the hit stop)
	check(game.end_facts != null and game.end_facts.cause == &"trap" and game.end_facts.killer_id == &"", "a trap: no monster, the stone")
	check(panel.shown_text().contains(tr(_dialogue("vigil_tale").line(&"trap").lines[0]).get_slice("{", 0).left(20)), "told as the stone's teeth")
	# Nothing for her to say: a line of the story, as before.
	var tales := _narrative().death_dialogues
	_narrative().death_dialogues = []
	game._show_end(false, 3)
	var summary := panel.get_node("%Summary") as Label
	check(summary.visible and Array(CONTENT.story.death_lines).any(func(line: String) -> bool: return summary.text.begins_with(line)) and not voice.visible, "with nothing to say, the story's death line")
	_narrative().death_dialogues = tales
	Settings.language = "fr"
	Settings.apply()
	game._show_end(false, 3)
	var before := get_tree().root.size
	for size in [Vector2i(1280, 720), Vector2i(2340, 1080), Vector2i(2548, 1296), Vector2i(1540, 720)]:
		await _window(size)
		voice.advance()
		await _frames(2)
		var outside := _panel_outside(panel)
		check(outside.is_empty(), "%s in French: the end screen with her words fits (%s)" % [size, ", ".join(outside.slice(0, 3))])
	await _restore_window(before)
	Settings.language = "en"
	Settings.apply()
	game.start_run()
	await _frames(5)


## The merchant's panel and the grinning spirit's say a keeper's line, gated and kept.
func _test_keeper_panels(game: Game) -> void:
	_fresh()
	var world := game.world
	var player := game.player
	Profile.stats["talk:wanderer"] = 1
	var merchant := world.spawn_merchant(CONTENT.dungeon.merchant, world.map.world_to_cell(world.find_open_point_near(player.global_position + Vector2(60, 0), 40.0)))
	await _frames(2)
	game.open_shop(merchant)
	await _frames(2)
	var greeting := game.shop_panel.get_node("%Greeting") as Label
	var no_name := CONTENT.dungeon.merchant.dialogue.line(&"no_name")
	check(greeting.text.contains(tr(no_name.lines[0])), "the merchant's panel: a line of his past (%s)" % greeting.text)
	game.shop_panel.close()
	merchant.queue_free()
	Profile.stats["talk:grinning_spirit"] = 0
	var gambler := world.spawn_encounter(load("res://data/encounters/grinning_spirit.tres"), _open_cell_near(world, player.global_position, 2))
	game.open_encounter(gambler)
	await _frames(2)
	var speech := game.encounter_panel.get_node("%Speech") as Label
	check(speech.visible and speech.text.contains(tr(gambler.def.dialogue.line(&"dice").lines[0])), "the grinning spirit giggles a line over its dice")
	game.encounter_panel.close()
	# Its panel, the line under its text, in French: still inside a 720-line screen.
	Settings.language = "fr"
	Settings.apply()
	var before := get_tree().root.size
	for size in [Vector2i(1280, 720), Vector2i(1540, 720), Vector2i(2340, 1080)]:
		await _window(size)
		Profile.stats["talk:grinning_spirit"] = 1  # its longest line yet: "seven"
		Profile.lines_told.erase("grinning_spirit/seven")
		game.open_encounter(gambler)
		await _frames(3)
		var outside := _panel_outside(game.encounter_panel)
		check(speech.visible and outside.is_empty(), "%s in French: the spirit's panel with its line fits (%s)" % [size, ", ".join(outside.slice(0, 3))])
		game.encounter_panel.close()
	await _restore_window(before)
	Settings.language = "en"
	Settings.apply()
	gambler.queue_free()
	await _frames(2)
	_fresh()



## Reading (design/interface.md, Text): a typed word never jumps to the next line (laid out
## before it is typed), the text speed (slow, normal, fast, at once) sets the pace, a page longer
## than three lines goes on to another page, and the village's words are typed the same way and
## written out by a tap.
func _test_reading() -> void:
	var speed_before := Settings.text_speed
	var layer := CanvasLayer.new()
	get_tree().root.add_child(layer)
	var box := DialogueBox.new(DialogueBox.Mode.PAGED, 520.0)
	layer.add_child(box)
	var speaker := load("res://data/story/dialogue/speakers/vigil_keeper.tres") as SpeakerDef
	var text := "The Well woke on a moonless night. A cold breath went through every house of Kagari."
	var one: Array[Dictionary] = [{ "text": text, "accent": false }]
	Settings.text_speed = Settings.TEXT_NORMAL
	box.say_pages(speaker, one)
	await _frames(2)
	var label := box.get("_current") as Label
	check(label.visible_characters_behavior == TextServer.VC_CHARS_AFTER_SHAPING, "typing: the words are laid out before they are typed")
	var whole := label.get_line_count()
	var jumped := 0
	for n in range(1, text.length(), 3):
		label.visible_characters = n
		if label.get_line_count() != whole:
			jumped += 1
	check(whole > 1 and jumped == 0, "typing: every letter typed sits where it will stay (%d lines, %d moves)" % [whole, jumped])
	# The pace: slow types fewer letters than normal in the same time, fast more, at once all.
	var typed := {}
	for speed: int in [Settings.TEXT_SLOW, Settings.TEXT_NORMAL, Settings.TEXT_FAST, Settings.TEXT_INSTANT]:
		Settings.text_speed = speed
		box.say_pages(speaker, one)
		box._age = 1.0  # (past its opening grace)
		await _frames(30)
		var current := box.get("_current") as Label
		typed[speed] = current.get_total_character_count() if current.visible_characters < 0 else current.visible_characters
	check(typed[Settings.TEXT_SLOW] < typed[Settings.TEXT_NORMAL] and typed[Settings.TEXT_NORMAL] < typed[Settings.TEXT_FAST] and typed[Settings.TEXT_INSTANT] == text.length(), "the text speed sets the pace: slow, normal, fast, at once (%s)" % typed)
	check(not box.is_typing(), "at once: the page is written out, the more sign up")
	# Pages: a long one goes on in pieces of at most three lines, whole words.
	var long_text := " ".join(PackedStringArray([text, text, text]))
	var parts := DialogueBox.split_page(long_text, 300.0, Fonts.BODY)
	check(parts.size() > 1 and " ".join(parts) == long_text, "a page too long for three lines is cut at line ends into several (%d)" % parts.size())
	layer.queue_free()
	# The village's words: typed, a tap writes them out.
	Settings.text_speed = Settings.TEXT_NORMAL
	var village := VillagePanel.new()
	var village_layer := CanvasLayer.new()
	get_tree().root.add_child(village_layer)
	village_layer.add_child(village)
	village.open("Sayo", text)
	await _frames(3)
	check(village.is_typing() and village.words.visible_characters_behavior == TextServer.VC_CHARS_AFTER_SHAPING, "the village's words are typed, laid out first")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	village._on_words_input(tap)
	check(not village.is_typing() and village.words.visible_characters < 0, "a tap on them writes them out")
	village_layer.queue_free()
	Settings.text_speed = speed_before
	await _frames(1)
