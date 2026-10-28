class_name Tutorial
extends Node
## Shows the tutorial's hints (TutorialDef) in a HintBox: the first steps of the first run, then
## a note the first time something new comes up. Each hint shows once ever (Profile) once read: a
## tap on it, or what it asks done. One whose time runs out unread comes back on a later floor
## (TutorialDef.unread_returns times: _ran_out), and the hints after it in its chain get in line
## again then. Never over a menu, one at a time with a short gap. Settings.tutorial_hints turns
## them all off.
##
## Cues bring hints up: the Game calls cue() (a run or a floor starts, a perk is picked), signals
## of the hero and the world call it (a monster noticed the hero, a boss, an ambush, the seal
## breaks), and a few things are checked a few times a second (low health, a forge in sight...).

## What can bring a hint up.
const CUES: Array[StringName] = [
	&"run_start", &"floor_start", &"cursed_floor", &"event_floor", &"monster_noticed", &"elite_noticed",
	&"monster_killed", &"boss_started", &"boss_defeated", &"ambush", &"seal_broken", &"perk_chosen",
	&"synergy", &"low_health", &"cold", &"hot", &"merchant_near", &"forge_near", &"chest_near",
	&"gear_carried", &"rune_carried", &"spell_learned", &"two_ways", &"cracked_wall_near", &"pact_near",
	&"encounter_near",
	# The Game: a level up's perk choice waits behind the HUD's perk button.
	&"offer_waiting",
	# The Game: a second life opened the trial of the Threshold.
	&"threshold",
	# The Game: a fall took the hero into the Deeps (Abyss).
	&"abyss",
	# Title screen only (TitleScreen.show_menu_hint()): the Tree of Souls and the oaths.
	&"menu_souls", &"menu_shrine", &"menu_oath",
]
## What a hint can wait for (`done_when`).
const ACTIONS: Array[StringName] = [
	&"moved", &"attacked", &"rolled", &"weapon_skill", &"used_item", &"opened_bag",
	# A charged attack was unleashed (the attack button held, then let go).
	&"charged",
	# The Interact button was used; the perk button was tapped.
	&"interacted", &"opened_offers",
]
## What `only_if` can ask.
const CONDITIONS: Array[StringName] = [&"sealed", &"has_belt_item", &"has_weapon_skill"]
## Seconds between two looks at the polled cues.
const POLL := 0.25
## The cues _check_world() looks for (nobody signals them).
const WORLD_CUES: Array[StringName] = [&"low_health", &"cold", &"hot", &"merchant_near", &"forge_near",
	&"chest_near", &"cracked_wall_near", &"pact_near", &"encounter_near", &"rune_carried", &"gear_carried", &"spell_learned"]

signal hint_shown(hint: HintDef)
signal hint_closed(hint: HintDef)

var def: TutorialDef
var box: HintBox
var hud: Hud
var player: Player
var world: World
## Whether a menu is open (the Game's); hints wait.
var is_blocked := func() -> bool: return false

var current: HintDef
var _queue: Array[HintDef] = []
## Cued too early (their `after` is not seen yet).
var _waiting: Array[HintDef] = []
var _time_left := 0.0
var _gap := 0.0
var _poll := 0.0
var _walked := 0.0
var _last_position := Vector2.INF
## Hints whose time ran out unread, this session: id -> [how many times, the World.floor_id it
## last did on]. Not again on that floor; seen once it has run out more than unread_returns times.
var _ran_out := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Events.monster_noticed.connect(_on_monster_noticed)
	Events.monster_killed.connect(func(_monster: Monster) -> void: cue(&"monster_killed"))
	Events.boss_started.connect(func(_boss: Monster) -> void: cue(&"boss_started"))
	Events.boss_defeated.connect(func(_boss: Monster) -> void: cue(&"boss_defeated"))
	Events.ambush_started.connect(func(_room: AmbushRoom) -> void: cue(&"ambush"))
	Settings.changed.connect(func() -> void:
		if not is_enabled():
			_queue.clear()
			_waiting.clear()
			_close(false))


func is_enabled() -> bool:
	return def != null and Settings.tutorial_hints


## A new hero (a run begins): what the old one was doing is forgotten.
func bind(new_player: Player, new_world: World, new_hud: Hud) -> void:
	if player and is_instance_valid(player):
		player.attacked.disconnect(_on_attacked)
		player.charged_attack.disconnect(_on_charged)
		player.skill_used.disconnect(_on_skill_used)
		player.consumable_used.disconnect(_on_consumable_used)
		player.perks.synergy_awakened.disconnect(_on_synergy)
		player.died.disconnect(_on_died)
	player = new_player
	hud = new_hud
	player.attacked.connect(_on_attacked)
	player.charged_attack.connect(_on_charged)
	player.skill_used.connect(_on_skill_used)
	player.consumable_used.connect(_on_consumable_used)
	player.perks.synergy_awakened.connect(_on_synergy)
	player.died.connect(_on_died)
	if world != new_world:
		world = new_world
		world.seal.broken.connect(func() -> void:
			cue(&"seal_broken")
			if world.stairs_cells.size() >= 2:
				cue(&"two_ways"))
	_queue.clear()
	_waiting.clear()
	_close(false)
	_walked = 0.0
	_last_position = Vector2.INF


## Something happened: the hints it brings up get in line (once ever each). A new floor also
## brings back the chained hints (no cue of their own) that ran out unread.
func cue(cue_name: StringName) -> void:
	if not is_enabled():
		return
	if cue_name == &"floor_start":
		for hint in def.hints:
			if hint.cue == &"" and hint.after != &"" and _ran_out.has(hint.id) and Profile.has_seen_hint(hint.after) and _wants(hint):
				_add(hint)
	for hint in def.hints:
		if hint.cue == cue_name and _wants(hint):
			if hint.after == &"" or Profile.has_seen_hint(hint.after):
				_add(hint)
			elif not _waiting.has(hint):
				_waiting.append(hint)


## The player did something: the hint waiting for it is done.
func action(action_name: StringName) -> void:
	if current and current.done_when == action_name:
		_close(true)


## Closes the hint on screen (a tap on it).
func dismiss() -> void:
	_close(true)


func _process(delta: float) -> void:
	if not is_enabled() or player == null or not is_instance_valid(player) or player.is_dead:
		return
	_track_walk()
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL
		if _world_cues_left():
			_check_world()
	if current:
		_follow_target()
		if current.duration > 0.0:
			_time_left -= delta
			if _time_left <= 0.0:
				_run_out()
		return
	_gap -= delta
	if _gap <= 0.0 and not _queue.is_empty() and not is_blocked.call():
		_show_next()


func _track_walk() -> void:
	var at := player.global_position
	if _last_position != Vector2.INF and not player.is_dashing():
		_walked += minf(at.distance_to(_last_position), 40.0)  # a fall or a teleport is no walk
	_last_position = at
	if _walked >= def.move_distance:
		action(&"moved")


## The control a hint points at may come and go (the Interact button shows only by something to
## use): the ring follows it.
func _follow_target() -> void:
	if box and hud and current.target != &"":
		box.set_target(hud.hint_target(current.target))


## The cues nobody signals: checked a few times a second, each only while a hint it brings is
## still to see (once every hint is seen, nothing is scanned: docs/performance.md).
func _check_world() -> void:
	if _cue_left(&"low_health") and player.get_max_hp() > 0 and float(player.hp) / player.get_max_hp() <= def.low_health:
		cue(&"low_health")
	if player.temperature.value <= -def.temperature:
		cue(&"cold")
	elif player.temperature.value >= def.temperature:
		cue(&"hot")
	if _cue_left(&"merchant_near") and _near(&"merchants"):
		cue(&"merchant_near")
	if _cue_left(&"forge_near") and _near(&"forges"):
		cue(&"forge_near")
	if _cue_left(&"chest_near") and _near(&"chests"):
		cue(&"chest_near")
	if _cue_left(&"cracked_wall_near") and _near(&"cracked_walls"):
		cue(&"cracked_wall_near")
	if _cue_left(&"pact_near") and _near(&"pact_doors"):
		cue(&"pact_near")
	if _cue_left(&"encounter_near") and _near(&"encounters"):
		cue(&"encounter_near")
	if _cue_left(&"rune_carried") or _cue_left(&"gear_carried"):
		for item in player.inventory.items:
			if item is RuneDef:
				cue(&"rune_carried")
			elif item is EquipmentDef:
				cue(&"gear_carried")
	if player.learned_skill:
		cue(&"spell_learned")


## A hint `cue_name` brings up is still to see (not seen on this profile).
func _cue_left(cue_name: StringName) -> bool:
	for hint in def.hints:
		if hint.cue == cue_name and not Profile.has_seen_hint(hint.id):
			return true
	return false


## Some hint the world's cues bring up is still to see (_check_world() has something to do).
func _world_cues_left() -> bool:
	for cue_name in WORLD_CUES:
		if _cue_left(cue_name):
			return true
	return false


func _near(group: StringName) -> bool:
	if world == null:
		return false
	for node in get_tree().get_nodes_in_group(group):
		var thing := node as Node2D
		if thing == null or not thing.is_inside_tree():
			continue
		# Seen from where it can be seen (a crack in the rock: from the floor in front of it).
		var spot: Vector2 = thing.call(&"sight_point") if thing.has_method(&"sight_point") else thing.global_position
		# (A solid thing, the merchant or the forge, doesn't hide itself.)
		var own: Array[RID] = []
		if thing is CollisionObject2D:
			own.append((thing as CollisionObject2D).get_rid())
		if spot.distance_to(player.global_position) <= def.near_distance and world.has_line_of_sight(player.global_position, spot, own):
			return true
	return false


func _wants(hint: HintDef) -> bool:
	return not Profile.has_seen_hint(hint.id) and hint != current and not _queue.has(hint) and not _ran_out_here(hint)


## Its time ran out unread on this floor: it waits for another.
func _ran_out_here(hint: HintDef) -> bool:
	return _ran_out.has(hint.id) and world != null and int(_ran_out[hint.id][1]) == world.floor_id


## The hint on screen stayed its whole time without a tap or its action: unread, it comes back
## on a later floor, unless it already did unread_returns times (then it counts as seen).
func _run_out() -> void:
	var hint := current
	var times := int(_ran_out.get(hint.id, [0, 0])[0]) + 1
	_ran_out[hint.id] = [times, world.floor_id if world else 0]
	_close(times > def.unread_returns)


func _add(hint: HintDef) -> void:
	_waiting.erase(hint)
	_queue.append(hint)
	_queue.sort_custom(func(a: HintDef, b: HintDef) -> bool: return a.priority > b.priority)


func _show_next() -> void:
	while not _queue.is_empty():
		var hint: HintDef = _queue.pop_front()
		if Profile.has_seen_hint(hint.id) or not holds(hint.only_if):
			continue
		current = hint
		_time_left = hint.duration
		if box:
			box.show_hint(hint, hud.hint_target(hint.target) if hud and hint.target != &"" else Rect2())
		hint_shown.emit(hint)
		return


## `only_if` of a hint.
func holds(condition: StringName) -> bool:
	match condition:
		&"":
			return true
		&"sealed":
			return world != null and world.seal.is_sealed()
		&"has_belt_item":
			return player != null and not player.belt.is_empty()
		&"has_weapon_skill":
			return player != null and player.skills.skills.size() > 1 and player.skills.skills[1] != null
	push_warning("Unknown tutorial condition: %s" % condition)
	return true


## `seen`: done with it for good (and the hints that come right after it get in line).
func _close(seen: bool) -> void:
	if current == null:
		return
	var hint := current
	current = null
	_gap = def.gap if def else 0.0
	if box:
		box.hide_hint()
	if seen:
		Profile.mark_hint(hint.id)
		for next in def.hints:
			if next.after == hint.id and (next.cue == &"" or _waiting.has(next)) and _wants(next):
				_add(next)
	hint_closed.emit(hint)


func _on_monster_noticed(monster: Monster) -> void:
	if monster.is_boss():
		return
	cue(&"monster_noticed")
	if monster.is_elite():
		cue(&"elite_noticed")


func _on_attacked() -> void:
	action(&"attacked")


func _on_charged(_attack: ChargedAttackDef) -> void:
	action(&"charged")


## Slot 0 is the roll; 1 and 2 the weapon's skills (Player.rebuild_skills).
func _on_skill_used(index: int) -> void:
	if index == 0:
		action(&"rolled")
	elif index <= Player.WEAPON_SKILL_SLOTS:
		action(&"weapon_skill")


func _on_consumable_used(_item: ItemDef) -> void:
	action(&"used_item")


## The run is over: the hint on screen goes, unread (it will come back).
func _on_died(_actor: Actor) -> void:
	_queue.clear()
	_waiting.clear()
	_close(false)


func _on_synergy(_synergy: SynergyDef) -> void:
	cue(&"synergy")
