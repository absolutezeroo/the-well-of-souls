extends CanvasLayer
## Loading screen (autoload "Loader"): between the title and a run, and back. The screen fades to
## the Well's dark, the scene loads in the background (a bar fills, souls rise, a tip), then the
## new scene takes over and the screen fades away once it has built itself (a run builds its
## first floor in its _ready()). Loader.go(path) instead of change_scene_to_file().

const TIPS: LoadingTipsDef = preload("res://data/ui/loading_tips.tres")
const EMBLEM: Texture2D = preload("res://assets/icon/splash.png")
const BACK := Color(0.0705882, 0.0470588, 0.117647)
const FADE := 0.22
## Shown at least this long, so it never just flickers.
const MIN_TIME := 0.7

var _screen: Control
var _souls: Control
var _bar: ProgressBar
var _tip: Label
var _status: Label
var _path := ""
var _shown_at := 0.0
var _progress := []
var _time := 0.0
var busy := false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


## Fades out, loads `path` in the background, changes to it, fades in.
func go(path: String) -> void:
	if busy:
		return
	busy = true
	_path = path
	_tip.text = TIPS.pick()
	_bar.value = 0.0
	_status.text = tr("The dark gathers...")
	_screen.modulate.a = 0.0
	_screen.show()
	var fade_in := create_tween()
	fade_in.tween_property(_screen, "modulate:a", 1.0, FADE)
	await fade_in.finished
	_shown_at = _time
	if ResourceLoader.load_threaded_request(path) != OK:
		push_warning("Loader: can't load %s" % path)
		get_tree().change_scene_to_file(path)
		_finish()
		return
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, _progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_warning("Loader: failed to load %s" % path)
			get_tree().change_scene_to_file(path)
			_finish()
			return
		_bar.value = float(_progress[0]) * 90.0 if not _progress.is_empty() else _bar.value
		await get_tree().process_frame
	_bar.value = 90.0
	_status.text = tr("Rekindling the lantern...")
	while _time - _shown_at < MIN_TIME:
		await get_tree().process_frame
	var scene := ResourceLoader.load_threaded_get(path) as PackedScene
	get_tree().change_scene_to_packed(scene)
	# The new scene builds itself (a run: its first floor) in the next frames.
	await get_tree().process_frame
	await get_tree().process_frame
	_bar.value = 100.0
	await get_tree().process_frame
	_finish()


func _finish() -> void:
	var fade_out := create_tween()
	fade_out.tween_property(_screen, "modulate:a", 0.0, FADE * 1.5)
	await fade_out.finished
	_screen.hide()
	busy = false


func _process(delta: float) -> void:
	_time += delta
	if _screen and _screen.visible:
		_souls.queue_redraw()


func _build() -> void:
	_screen = Control.new()
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP  # nothing under it takes taps meanwhile
	_screen.hide()
	add_child(_screen)
	var back := ColorRect.new()
	back.color = BACK
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(back)
	_souls = Control.new()
	_souls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_souls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_souls.draw.connect(_draw_souls)
	_screen.add_child(_souls)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.custom_minimum_size.x = 560
	center.add_child(column)
	var emblem := TextureRect.new()
	emblem.texture = EMBLEM
	emblem.custom_minimum_size = Vector2(0, 132)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	column.add_child(emblem)
	var title := UiSkin.label(tr("The Well of Souls"), Fonts.HUGE, UiSkin.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_status = UiSkin.label("", Fonts.BODY, UiSkin.DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(560, 18)
	UiSkin.style_loading_bar(_bar)
	column.add_child(_bar)
	_tip = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.custom_minimum_size.x = 560
	column.add_child(_tip)


## Souls rising slowly behind the words, like in the Well.
func _draw_souls() -> void:
	var area := _souls.size
	for i in 28:
		var salt := float(i) * 12.9898
		var x := fposmod(sin(salt) * 43758.5453, 1.0) * area.x
		var speed := 14.0 + fposmod(salt * 3.1, 1.0) * 22.0
		var y := area.y - fposmod(_time * speed + fposmod(salt * 7.7, 1.0) * area.y, area.y + 40.0)
		var sway := sin(_time * 0.7 + salt) * 10.0
		var glow := 0.25 + 0.25 * sin(_time * 1.7 + salt)
		_souls.draw_rect(Rect2(Vector2(x + sway, y).snapped(Vector2(4, 4)), Vector2(4, 4)), Color(0.55, 0.95, 0.95, glow))
