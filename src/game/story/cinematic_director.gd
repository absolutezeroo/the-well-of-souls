class_name CinematicDirector
extends Node
## Plays a CinematicDef: runs its steps in order over the frozen world and gives them the stage
## (the camera, the subject, the hero, the view drawing bars and words, the story told). Whoever
## starts it pauses the game around it (BossMeeting); the director, its view, the camera and
## the subject's rig keep running meanwhile (keep_running()).
## Skipping: a tap (any key, a touch) hurries the scene (every step done at once, all its text
## written), the next one ends it; the steps marked `always_run` then still put the camera back
## and lift the bars, quickly. Taps in the first `tap_grace` seconds are ignored.

signal finished

var def: CinematicDef
var view: CinematicView
## The view's camera (the hero's, his child) and the hero.
var camera: Camera2D
var hero: Node2D
## Whom the scene is about (a warden), and what is told.
var subject: Node2D
var story: StoryBeat
## The first tap: everything at once. The second: the end.
var hurried := false
var ended := false
## The subject's intro animation was played (the warden woke on screen).
var played_animation := false

var _playing := false
var _elapsed := 0.0
var _camera_tween: Tween
## Nodes made to run while paused -> their own process mode, given back at the end.
var _kept := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _playing:
		_elapsed += delta


func is_playing() -> bool:
	return _playing


## Plays `cinematic` about `about` (null: no one), telling `beat`. Returns when it is over.
func play(cinematic: CinematicDef, about: Node2D, beat: StoryBeat) -> void:
	if _playing or cinematic == null or view == null:
		return
	def = cinematic
	subject = about
	story = beat
	hurried = false
	ended = false
	played_animation = false
	_elapsed = 0.0
	_playing = true
	if camera:
		keep_running(camera)
		if camera is GameCamera:
			(camera as GameCamera).lean_toward(null, 0.0)  # the scene frames its subject itself (the fight leans again)
	view.tapped.connect(tap)
	view.open()
	Events.cinematic_started.emit()
	for step in def.steps:
		if step == null or (ended and not step.always_run):
			continue
		@warning_ignore("redundant_await")  # a coroutine in the steps that wait (the base CinematicStep.play answers at once)
		await step.play(self)
	_restore()
	view.tapped.disconnect(tap)
	view.close()
	_playing = false
	Events.cinematic_finished.emit()
	finished.emit()


## A tap, a key: hurries the scene, or ends it.
func tap() -> void:
	if not _playing or _elapsed < def.tap_grace:
		return
	if def.tap_completes_first and not hurried:
		hurried = true
	else:
		ended = true


## Waits `seconds` (real time, while paused), less if the scene is hurried or ended.
## `even_if_skipped`: the steps that always run wait their (short) time anyway.
func wait(seconds: float, even_if_skipped := false) -> void:
	var left := seconds
	while left > 0.0 and _playing:
		if not even_if_skipped and (hurried or ended):
			return
		if even_if_skipped and ended and left > seconds * 0.5:
			left = seconds * 0.5
		await get_tree().process_frame
		left -= get_process_delta_time()


## Writes a block of text in the view: first `speech` (the subject's own words, in
## `speech_color`; "" for none), then `lines` under `heading` ("New" beside it if `is_new`), one
## after the other, each typed or faded, then left to be read. Hurried (the first tap), the
## whole block is written at once and waits for the tap that ends the scene (or its reading time).
func narrate(heading: String, is_new: bool, lines: PackedStringArray, color: Color, typed: bool, speech := "", speech_color := Color.WHITE) -> void:
	if ended or (lines.is_empty() and speech.is_empty()):
		return
	view.begin_text(heading if not lines.is_empty() else "", is_new)
	var reading := 0.0
	var labels: Array[Label] = []
	if not speech.is_empty():
		labels.append(view.set_speech(speech, speech_color))
	for line in lines:
		labels.append(view.add_line(line, color))
	for label in labels:
		reading += def.read_time(label.text)
		await _write(label, typed)
		if ended:
			return
		await wait(def.read_time(label.text))
	if hurried and not ended:
		# Everything is on screen: the next tap ends it (or it is read in its time).
		var left := reading
		while left > 0.0 and not ended and _playing:
			await get_tree().process_frame
			left -= get_process_delta_time()


func _write(label: Label, typed: bool) -> void:
	var count := label.get_total_character_count()
	if hurried or ended:
		label.visible_characters = -1
		label.modulate.a = 1.0
		return
	if typed and def.chars_per_second > 0.0 and not is_inf(Settings.text_speed_factor()):
		label.visible_characters = 0
		var shown := 0.0
		while shown < count and not hurried and not ended and _playing:
			await get_tree().process_frame
			shown += get_process_delta_time() * def.chars_per_second * Settings.text_speed_factor()  # (the player's text speed)
			label.visible_characters = mini(int(shown), count)
		label.visible_characters = -1
	elif typed and def.chars_per_second > 0.0:
		label.visible_characters = -1  # (text speed "at once")
		label.modulate.a = 1.0
	else:
		label.visible_characters = -1
		label.modulate.a = 0.0
		var time := 0.0
		while time < def.fade_time and not hurried and not ended and _playing:
			await get_tree().process_frame
			time += get_process_delta_time()
			label.modulate.a = minf(time / def.fade_time, 1.0)
		label.modulate.a = 1.0


func has_subject() -> bool:
	return subject != null and is_instance_valid(subject) and subject.is_inside_tree()


## Eases the view to `point` (world) over `time` seconds.
func move_camera(point: Vector2, time: float) -> void:
	if camera == null or hero == null or not is_instance_valid(hero):
		return
	_tween_camera(point - hero.global_position, time)


## Eases the view back onto the hero.
func camera_home(time: float) -> void:
	_tween_camera(Vector2.ZERO, time)


func _tween_camera(to: Vector2, time: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	if _camera_tween:
		_camera_tween.kill()
	_camera_tween = create_tween()
	_camera_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(camera, "position", to, maxf(time, 0.01))


## Plays the subject's animation `animation` (its rig, made to run while paused). Returns its
## length in seconds (0: it has none).
func play_subject_animation(animation: StringName) -> float:
	if not has_subject() or not subject is Actor:
		return 0.0
	var rig := (subject as Actor).rig
	if rig == null:
		return 0.0
	var length := rig.animation_length(animation)
	if length <= 0.0:
		return 0.0
	keep_running(rig)
	rig.play_named(animation)
	played_animation = true
	return length


## `node` runs while the game is paused, until the scene ends.
func keep_running(node: Node) -> void:
	if node and is_instance_valid(node) and not _kept.has(node):
		_kept[node] = node.process_mode
		node.process_mode = Node.PROCESS_MODE_ALWAYS


func _restore() -> void:
	if _camera_tween:
		_camera_tween.kill()
	if camera and is_instance_valid(camera):
		camera.position = Vector2.ZERO
	for node: Node in _kept:
		if is_instance_valid(node):
			node.process_mode = _kept[node]
	_kept.clear()
