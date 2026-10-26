class_name VillageResident
extends CharacterBody2D
## A quiet surface routine, independent of combat and dungeon RNG. Reuses its frame list and
## proximity state; text is translated only when a new greeting is actually shown.

var def: VillageResidentDef
var hero: VillageWalker
var paused := false
var asleep := false
var indoors := false
var activity: VillageActivityDef
var navigation: VillageNavigation
var sprite := Sprite2D.new()
var bubble := PanelContainer.new()
var _words: Label
var _lines: PackedStringArray
var _line_index := 0
var _path := PackedVector2Array()
var _waypoint := 0
var _cooldown := 0.0
var _bubble_left := 0.0
var _near := false
var _clock := 0.0
var _frame := -1
var _walking := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CircleShape2D.new()
	shape.radius = 6.0
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	sprite.texture = def.speaker.figure
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, 16, 16)
	sprite.scale = Vector2(2, 2)
	sprite.offset = Vector2(0, -8)
	sprite.material = def.appearance
	add_child(sprite)
	refresh_progress()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.11, 0.94)
	style.border_color = def.speaker.color
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	bubble.add_theme_stylebox_override("panel", style)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.custom_minimum_size.x = 240
	bubble.scale = Vector2(0.5, 0.5)
	bubble.z_index = 10
	_words = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	_words.custom_minimum_size.x = 224
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.add_child(_words)
	add_child(bubble)
	bubble.resized.connect(_place_bubble)
	bubble.hide()


## A purchase or cloud replacement refreshes the voice/look without teleporting the resident.
func refresh_progress() -> void:
	asleep = def.echo and (def.wakes_after == null or VillageProgress.stage(def.wakes_after) != VillageProgress.Step.RETURNED)
	sprite.modulate = Color(0.5, 0.8, 1.0, 0.5) if asleep else Color.WHITE
	_lines = def.ambient_after if def.quest and VillageProgress.stage(def.quest) == VillageProgress.Step.RETURNED else def.ambient_before
	bubble.hide()


## A new appointment changes the route, never teleports a resident already in the village.
## On scene entry only, offscreen residents are placed at their current activity.
func apply_hour(hour: float, initial: bool = false, reroute: bool = false) -> void:
	if asleep:
		# An older cloud profile can undo a rescue while this resident is away from home.
		position = def.position
		activity = null
		indoors = false
		show()
		_path.clear()
		return
	var next := def.activity_at(hour)
	if next == activity and not reroute: return
	activity = next
	_path.clear()
	_waypoint = 0
	indoors = false
	show()
	if activity == null: return
	if initial:
		position = activity.destination
	elif navigation:
		_path = navigation.path(position, activity.destination)
		_waypoint = 1 if _path.size() > 1 else 0
	if position.distance_squared_to(activity.destination) <= 4.0:
		_arrive()


func _arrive() -> void:
	indoors = activity != null and activity.indoors
	visible = not indoors


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_bubble_left = maxf(0.0, _bubble_left - delta)
	if _bubble_left <= 0.0 or paused:
		bubble.hide()
	var distance := position.distance_squared_to(hero.position) if is_instance_valid(hero) else INF
	var near := distance < def.greeting_radius * def.greeting_radius
	if near and not _near and not paused and not indoors and _cooldown <= 0.0:
		_greet()
	_near = near
	velocity = Vector2.ZERO
	# Passing nearby does not freeze the village; opening a conversation does.
	if not paused and not asleep and _waypoint < _path.size():
		var target := _path[_waypoint]
		if position.distance_squared_to(target) <= 4.0:
			_waypoint += 1
			if _waypoint == _path.size(): _arrive()
		else:
			velocity = position.direction_to(target) * minf(def.walk_speed, position.distance_to(target) / maxf(delta, 0.001))
	move_and_slide()
	_animate(delta, velocity.length_squared() > 0.0)


func _animate(delta: float, moving: bool) -> void:
	if moving != _walking:
		_walking = moving
		_clock = 0.0
		_frame = -1
	_clock += delta
	var frames := def.walk_frames if moving and not def.walk_frames.is_empty() else def.idle_frames
	if frames.is_empty(): return
	var interval := def.walk_frame_time if moving else def.idle_frame_time
	var index := int(_clock / maxf(interval, 0.05)) % frames.size()
	if index != _frame:
		_frame = index
		sprite.region_rect = frames[index]
	if moving:
		sprite.flip_h = velocity.x < 0.0


func _greet() -> void:
	if _lines.is_empty(): return
	_words.text = tr(_lines[_line_index % _lines.size()])
	_line_index += 1
	_cooldown = def.greeting_cooldown
	_bubble_left = def.greeting_seconds
	bubble.show()
	_place_bubble.call_deferred()


func _place_bubble() -> void:
	bubble.position = Vector2(-bubble.size.x * 0.25, -38.0 - bubble.size.y * 0.5).floor()
