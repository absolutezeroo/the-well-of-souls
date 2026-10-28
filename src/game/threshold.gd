class_name Threshold
extends Node
## Runs the trial of the Threshold (ThresholdDef) for the Game. A second life (CheatDeathPassive)
## asks for it on a killing blow (`open()`): the bell tolls, the hero's soul sinks, and the floor's
## World leaves the tree just as it is (its monsters, their health and statuses, a boss mid-fight,
## the shots in the air: nothing moves, nothing is lost). The hero is moved into a ThresholdWorld
## built beside it and must slay `needed` spectres before `time_left` runs out. Won, he comes back
## to the very spot he fell on and the passive heals him (`on_won`). Lost (time up, or slain in
## there), he is put back where he fell and dies for real, of what slew him the first time.
## Meanwhile the run's clock keeps counting, nothing is saved (Game._save_run()), the bag and the
## perk choices wait. The HUD follows the signals (Hud.bind_threshold()).

## The hero is in: the limbo is built, the HUD can show the trial.
signal opened(trial: ThresholdDef, needed: int, seconds: float)
## The veil lifted: the countdown runs, spectres rise.
signal started
signal progressed(kills: int, needed: int)
## The trial is decided (the way back starts).
signal ended(won: bool)
## The hero is back on his floor (alive or about to die), or the trial was cut short.
signal closed(won: bool)

const GROUP := &"threshold"
const WORLD_SCENE := preload("res://src/world/threshold_world.tscn")
## Over the HUD and the hints, under the menus (the pause menu shows over the veil).
const VEIL_LAYER := 9
## Spectres up at once when the veil lifts (then one by one: ThresholdDef.spawn_every).
const FIRST_RISE := 3

enum State { CLOSED, ENTERING, FIGHTING, LEAVING }

var state := State.CLOSED
var trial: ThresholdDef
var kills := 0
var needed := 0
var time_left := 0.0
var time_limit := 0.0
## The limbo while the hero is in it.
var limbo: ThresholdWorld
## Set by the Game: its world, hero, ambience and content.
var game: Game

var _hero: Player
## The hero's stay in the limbo: the world he fell in (his floor, or the Deeps) waits out of the
## tree meanwhile, and he comes back to the spot he fell on.
var _stay: SubWorld
var _rig_position := Vector2.ZERO
var _rig_scale := Vector2.ONE
## The rig's place and size were noted (the soul started sinking): put them back.
var _rig_saved := false
## What slew him the first time (kept if the trial is lost).
var _killer: Actor
var _cause := ""
## How (RunFacts.CAUSES), for the Vigil-Keeper's tale if the trial is lost.
var _cause_id: StringName = &""
var _on_won: Callable
var _won := false
var _tween: Tween
var _veil: ColorRect


func _ready() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var layer := CanvasLayer.new()
	layer.name = "Veil"
	layer.layer = VEIL_LAYER
	add_child(layer)
	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.color = Color(0, 0, 0, 0)
	layer.add_child(_veil)
	Events.monster_killed.connect(_on_monster_killed)


## The game goes (quit to the title mid-trial): the world waiting out of the tree goes with it.
func _exit_tree() -> void:
	if _stay:
		_stay.discard()


## The Threshold of the game `node` is in (null: none, e.g. the balance tools' bare arena).
static func of(node: Node) -> Threshold:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as Threshold


## The trial is on (or the hero is on his way in or out).
func is_open() -> bool:
	return state != State.CLOSED


func is_fighting() -> bool:
	return state == State.FIGHTING


## It can take `hero` in now: the game's hero, in a world in play (his floor, or the Deeps he
## fell into: the trial then brings him back there), no trial already on.
func can_host(hero: Actor) -> bool:
	return state == State.CLOSED and game != null and hero is Player and hero == game.player \
		and not hero.is_dead and hero.world != null and hero.world.is_inside_tree() and hero.world.map != null


## A killing blow on `hero`, who has a second life: off to the trial. `on_won` brings him back
## to life once he is home (the passive's heal and blast).
func open(hero: Player, threshold: ThresholdDef, on_won: Callable) -> void:
	state = State.ENTERING
	trial = threshold
	_hero = hero
	_on_won = on_won
	_won = false
	_stay = SubWorld.new(game, hero)
	var source := hero.last_hit.source if hero.last_hit else null
	_killer = source if is_instance_valid(source) and source != hero else null
	# A fall names itself ("a fall") before the blow lands; otherwise the one who struck it.
	_cause = hero.killed_by if not hero.killed_by.is_empty() else (_killer.display_name if _killer else tr("the dungeon"))
	_cause_id = hero.cause_of_death(_killer)
	needed = trial.kills_for(_stay.home.depth, game.content.dungeon)
	time_limit = trial.time_for(_stay.home.depth, game.content.dungeon)
	time_left = time_limit
	kills = 0
	if not hero.died.is_connected(_on_hero_died):
		hero.died.connect(_on_hero_died)
	# Not now: this is the middle of a hit, in a physics callback.
	_enter.call_deferred()


## A blow that would kill the hero while the trial is on: the trial is lost (on the way in or
## out, nothing: it was the same moment). The hero stays up until he is home.
func absorb_death(_owner: Actor) -> bool:
	if state == State.FIGHTING:
		_end(false)
	return true


## Cuts the trial short at once (a new run, the debug panel): the floor and the hero go back as
## they were, without effects.
func abort() -> void:
	if state == State.CLOSED:
		return
	if _tween:
		_tween.kill()
	_veil.color.a = 0.0
	_bring_back()
	state = State.CLOSED
	closed.emit(false)


func _physics_process(delta: float) -> void:
	if state != State.FIGHTING:
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0:
		_end(false)


# --- The way in --------------------------------------------------------------

func _enter() -> void:
	if state != State.ENTERING or not is_instance_valid(_hero):
		return
	HitStop.reset()
	_stay.freeze()
	if trial.knell:
		Sfx.play_ui(trial.knell)
	# The bell tolls and the floor drains of its colors; the soul sinks out of the body.
	var screen := get_tree().get_first_node_in_group(&"screen_effects") as ScreenEffects
	if screen:
		screen.set_mood(trial.ambience)
	_sink_soul()
	_tween = create_tween()
	_tween.tween_interval(trial.sink_time)
	_veil.color = Color(trial.veil_color, 0.0)
	_tween.tween_property(_veil, "color:a", 1.0, trial.fade_time)
	_tween.tween_callback(_cross_over)
	_tween.tween_interval(0.15)
	_tween.tween_property(_veil, "color:a", 0.0, trial.fade_time)
	_tween.tween_callback(_begin)


## The hero's body fades and sinks, and his soul is pulled down into the floor.
func _sink_soul() -> void:
	var rig := _hero.rig
	if rig:
		_rig_position = rig.position
		_rig_scale = rig.scale
		_rig_saved = true
		var sink := create_tween().set_parallel()
		# The body wavers and thins away into the floor, dithered on its own pixels in the souls'
		# cold light, its last pixels five lower (never squashed nor faded by alpha: decision 0007).
		if rig.look:
			rig.look.vanish(DeathLookDef.Style.WISP, VfxElementDef.named(&"spirit"))
			sink.tween_method(rig.look.set_vanishing, 0.0, 1.0, trial.sink_time + trial.fade_time * 0.5).set_ease(Tween.EASE_IN)
		sink.tween_method(_sink_rig.bind(rig), 0.0, 1.0, trial.sink_time + trial.fade_time * 0.5)
	var soul := SinkingSoul.new()
	soul.color = trial.color
	soul.position = _hero.global_position + Vector2(0, -18)
	add_child(soul)
	soul.play(trial.sink_time + trial.fade_time)


## The rig `t` of the way down (0..1): lower by whole art pixels, five at most (10 units).
func _sink_rig(t: float, rig: Node2D) -> void:
	if is_instance_valid(rig):
		rig.position = _rig_position + Vector2(0, floorf(t * 5.0) * PixelGrid.ART_PIXEL)


## Under the veil: the world he fell in leaves the tree as it is, the limbo takes the hero.
func _cross_over() -> void:
	var hero := _hero
	_restore_rig()
	limbo = WORLD_SCENE.instantiate() as ThresholdWorld
	limbo.name = "ThresholdWorld"
	_stay.cross(limbo)
	limbo.build_trial(_stay.home.depth, game.content, trial, randi())
	limbo.take_in(hero)
	# He came from 0: enough to fight, his statuses left behind.
	hero.statuses.clear()
	hero.temperature.reset()
	hero.hp = maxi(1, roundi(hero.get_max_hp() * trial.hero_health))
	hero.health_changed.emit(hero.hp, hero.get_max_hp())
	game.ambience.play(trial.ambience, limbo, hero)
	if trial.music:
		Sfx.play_music(trial.music)
	if not trial.lore.is_empty():
		Events.log_message(tr(trial.lore), trial.color)
	Events.log_message(tr("%s: slay %d spectres in %d seconds to come back where you fell.") % [tr(trial.display_name), needed, roundi(time_limit)], trial.color)
	opened.emit(trial, needed, time_limit)


func _begin() -> void:
	if state != State.ENTERING:
		return
	state = State.FIGHTING
	limbo.spectres_wanted = trial.alive_at_once
	for i in mini(FIRST_RISE, trial.alive_at_once):
		limbo.raise_spectre()
	started.emit()


func _on_monster_killed(monster: Monster) -> void:
	if state != State.FIGHTING or limbo == null or monster.world != limbo:
		return
	kills += 1
	progressed.emit(kills, needed)
	if kills >= needed:
		_end(true)


# --- The way out -------------------------------------------------------------

## Won or lost: the limbo stops, the bell tolls again, the veil falls, and the hero goes home.
func _end(won: bool) -> void:
	state = State.LEAVING
	_won = won
	limbo.spectres_wanted = 0
	limbo.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED)
	if trial.knell:
		Sfx.play_ui(trial.knell, 0.0 if won else -3.0)
	if won:
		Events.log_message(tr("The knell falls silent. The Well lets you go."), trial.color)
	else:
		Events.log_message(tr("The knell has tolled. The Threshold keeps you."), Palette.DANGER)
		Events.run_marked.emit("threshold_lost")  # the Vigil-Keeper knows (RunFacts)
	ended.emit(won)
	_tween = create_tween()
	_veil.color = Color(trial.return_veil_color if won else trial.veil_color, 0.0)
	_tween.tween_property(_veil, "color:a", 1.0, trial.fade_time)
	_tween.tween_callback(_go_home)
	_tween.tween_property(_veil, "color:a", 0.0, trial.fade_time)


func _go_home() -> void:
	var hero := _hero
	_bring_back()
	state = State.CLOSED
	if not is_instance_valid(hero):
		closed.emit(_won)
		return
	if _won:
		_on_won.call()
		hero.shield_for(trial.return_grace)
		Events.stat_counted.emit("thresholds", 1)
	else:
		hero.killed_by = _cause
		hero.death_cause = _cause_id
		hero.hp = 0
		hero.health_changed.emit(0, hero.get_max_hp())
		hero.die(_killer if is_instance_valid(_killer) else null)
	closed.emit(_won)


## The world he fell in back in the tree as it was, the limbo gone, the hero on the spot he
## fell on.
func _bring_back() -> void:
	var hero := _hero if is_instance_valid(_hero) else null
	if hero and hero.died.is_connected(_on_hero_died):
		hero.died.disconnect(_on_hero_died)
	if hero:
		_restore_rig()
	if _stay:
		_stay.come_back()
	limbo = null
	game.play_floor_mood()


func _restore_rig() -> void:
	if _rig_saved and is_instance_valid(_hero) and _hero.rig:
		_rig_saved = false
		_hero.rig.position = _rig_position
		_hero.rig.scale = _rig_scale
		_hero.rig.modulate = Color.WHITE
		if _hero.rig.look:
			_hero.rig.look.come_back()


## Dead in there some other way (giving up from the pause menu): straight home, no ceremony.
func _on_hero_died(_actor: Actor) -> void:
	if state != State.CLOSED:
		abort.call_deferred()


## The hero's soul, pulled down out of his body into the floor (drawn over the frozen floor):
## a wisp in the spirit element's ramp, on the art's grid, its tail streaming up behind it, a
## hollow ring spreading on the floor where it goes under, all dithering out (docs/vfx.md).
class SinkingSoul extends Node2D:
	## Kept for the caller; the soul takes the spirit element's colors.
	var color := Color.WHITE
	var _age := 0.0
	var _length := 1.0

	func play(seconds: float) -> void:
		_length = maxf(seconds, 0.1)
		z_index = 20
		var glow := CanvasItemMaterial.new()
		glow.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = glow

	func _process(delta: float) -> void:
		_age += delta
		if _age >= _length:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var spirit := VfxElementDef.named(&"spirit")
		var t := _age / _length
		# It rises a little out of the body, then is dragged down and fades.
		var y := -10.0 * sin(minf(t * 2.5, 1.0) * PI * 0.5) + 70.0 * pow(maxf(t - 0.35, 0.0) / 0.65, 2.0)
		var fade := 1.0 - smoothstep(0.6, 1.0, t)
		for i in 6:
			var back := float(i + 1) * 5.0 * t
			var at := Vector2(sin(_age * 9.0 + i) * 2.0 * i * 0.3, y - back)
			if PixelDraw.dither(PixelDraw.cell_of(at), fade * (1.0 - i / 7.0)):
				PixelDraw.pixel(self, at, spirit.shade(0.25 + i * 0.12), 2 if i < 2 else 1)
		PixelDraw.disc(self, Vector2(0, y), 8.0, spirit.shade(0.5), fade)
		PixelDraw.disc(self, Vector2(0, y), 4.0, spirit.core(), fade)
		PixelDraw.ring(self, Vector2(0, 26), 16.0 + 20.0 * t, spirit.shade(0.75), 1, 0.8 * fade, 0.5)
