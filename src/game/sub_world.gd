class_name SubWorld
extends RefCounted
## One stay of the hero in a world built beside the one he stands in (a PocketWorld: the
## Threshold's limbo, the Deeps). The world he leaves (`home`) is frozen, then leaves the scene
## tree just as it is: its monsters, their Health and statuses, a boss mid-fight, the shots in
## the air, nothing moves and nothing is lost. The `away` world takes its place under the Game;
## on the way back everything goes back where it was and the away world is freed.
## Stays nest: the Threshold can open from the Deeps, and then its home is the Deeps.
## Used by Threshold and Abyss, which hold the rules; this only moves worlds and the hero.

## Where the worlds hang (the Game).
var host: Node
var hero: Player
## The world he left (a floor, or another pocket world).
var home: World
## The world he is in meanwhile (null until `cross()`).
var away: PocketWorld
## Where the hero stood when he crossed over.
var stood_at := Vector2.ZERO

var _home_index := 0
var _home_process := Node.PROCESS_MODE_INHERIT
var _frozen := false
var _hero_parent: Node
var _temperature := 0.0


func _init(game: Node, who: Player) -> void:
	host = game
	hero = who
	home = who.world


## The home stops where it is (still on screen: the way in can play over it).
func freeze() -> void:
	if _frozen or home == null:
		return
	_home_process = home.process_mode
	home.process_mode = Node.PROCESS_MODE_DISABLED
	_frozen = true


## The hero crossed over (he is in `away`, or on his way there).
func is_away() -> bool:
	return away != null


## Under a veil: the home leaves the tree as it is, `world` takes its place (built by the caller
## next, then `world.take_in(hero)`). The hero is out of the tree until then.
func cross(world: PocketWorld) -> void:
	freeze()
	_hero_parent = hero.get_parent()
	stood_at = hero.global_position
	_temperature = hero.temperature.value
	if _hero_parent:
		_hero_parent.remove_child(hero)
	_home_index = home.get_index()
	host.remove_child(home)
	away = world
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.difficulty = home.difficulty
	world.boons = home.boons
	world.luck = home.luck
	host.add_child(world)
	host.move_child(world, _home_index)


## The home back in the tree as it was, the away world gone, the hero at `at` in his home
## (where he stood when he crossed, by default), his statuses left behind.
func come_back(at: Vector2 = Vector2.INF) -> void:
	var who := hero if is_instance_valid(hero) else null
	if away:
		if who:
			away.let_go(who)
		if away.get_parent():
			away.get_parent().remove_child(away)
		away.queue_free()
		away = null
	if home and is_instance_valid(home):
		if not home.is_inside_tree() and home.get_parent() == null:
			host.add_child(home)
			host.move_child(home, mini(_home_index, host.get_child_count() - 1))
		if _frozen:
			home.process_mode = _home_process
			_frozen = false
	if who and who.get_parent() == null and is_instance_valid(_hero_parent):
		_hero_parent.add_child(who)
		who.world = home
		who.global_position = stood_at if at == Vector2.INF else at
		who.reset_safe_position()
		who.temperature.value = _temperature
		who.statuses.clear()
		who.camera.reset_smoothing()


## The game goes while the hero is away (quit to the title): the home waiting out of the tree
## goes with it.
func discard() -> void:
	if home and is_instance_valid(home) and not home.is_inside_tree() and home.get_parent() == null:
		home.queue_free()
