extends Node
## Captures for reviewing a visual change (docs/art-bible.md "Check with your eyes"): each shot
## at 1:1, a x4 nearest-neighbour crop of its centre (whole pixels?) and a greyscale copy
## (readability by value). A tool, not exported; tools/design/capture.py runs it per resolution.
## godot --rendering-driver opengl3 --resolution WxH res://tools/design/capture.tscn -- <outdir> <tag> [shots]
## shots (comma-separated, default all): village, village_map, temple, talk, village_woken (the map
## once every sleeper is woken), homes (each resident's room, at an hour they are in).

const SHOTS := ["village", "village_map", "temple", "talk", "village_woken", "homes"]
const HUB := "res://src/village/village_hub.tscn"
const VILLAGE := "res://data/village/kagari.tres"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://captures"
	var tag := args[1] if args.size() > 1 else "%dx%d" % [get_window().size.x, get_window().size.y]
	var wanted := (args[2].split(",") as Array) if args.size() > 2 else SHOTS
	Profile.save_path = ""
	Profile.reset()
	Settings.path = ""
	Settings.language = "fr"
	Settings.apply()
	Sfx.enabled = false
	DirAccess.make_dir_recursive_absolute(out)
	for shot: String in wanted:
		if shot == "homes":
			await _homes(out, tag)
			continue
		Profile.reset()
		if shot == "village_woken":
			_wake_all()
		var hub := (load(HUB) as PackedScene).instantiate()
		add_child(hub)
		await _frames(30)
		match shot:
			"village_map", "village_woken":
				# The whole square at 1:1, in daylight: the layout, not the framing.
				var camera := get_viewport().get_camera_2d()
				camera.position_smoothing_enabled = false
				camera.zoom = Vector2.ONE * minf(get_viewport().get_visible_rect().size.x / hub.def.bounds.size.x, get_viewport().get_visible_rect().size.y / hub.def.bounds.size.y)
				camera.global_position = hub.def.bounds.get_center()
				hub.view.daylight.color = Color.WHITE
			"temple":
				hub.enter_room(hub.def.interiors[0])
				await _frames(30)
			"talk":
				hub._talk(hub.def.residents[0])
		await _frames(20)
		_save(get_viewport().get_texture().get_image(), "%s/%s_%s" % [out, shot, tag])
		hub.queue_free()
		await _frames(3)
	print("captures: %s" % ProjectSettings.globalize_path(out))
	get_tree().quit()


## Every village request returned: the woken facades, no roots, the residents' own routines.
func _wake_all() -> void:
	for quest in (load(VILLAGE) as VillageDef).quests:
		Profile.village_quests[String(quest.id)] = VillageProgress.Step.RETURNED


## Each room a resident lives in, entered at the first hour its resident is there.
func _homes(out: String, tag: String) -> void:
	Profile.reset()
	_wake_all()
	var village := load(VILLAGE) as VillageDef
	for room in village.interiors:
		if room.opens_after == null:
			continue
		var hour := -1.0
		for resident in village.residents:
			for appointment in resident.schedule:
				if appointment.room == room and hour < 0.0 and appointment.start_hour >= 6.0:
					hour = appointment.start_hour + 0.5
		Profile.village_seconds = village.clock.day_seconds * fposmod((hour if hour >= 0.0 else 12.0) - village.clock.start_hour, 24.0) / 24.0
		var hub := (load(HUB) as PackedScene).instantiate() as VillageHub
		add_child(hub)
		await _frames(30)
		hub.enter_room(room)
		await _frames(30)
		_save(get_viewport().get_texture().get_image(), "%s/home_%s_%s" % [out, room.id, tag])
		hub.queue_free()
		await _frames(3)


func _save(image: Image, base: String) -> void:
	image.save_png(base + ".png")
	var size := Vector2i(image.get_width() >> 2, image.get_height() >> 2)
	var crop := image.get_region(Rect2i((image.get_width() - size.x) >> 1, (image.get_height() - size.y) >> 1, size.x, size.y))
	crop.resize(size.x * 4, size.y * 4, Image.INTERPOLATE_NEAREST)
	crop.save_png(base + "_zoom.png")
	var grey := image.duplicate() as Image
	grey.convert(Image.FORMAT_L8)
	grey.save_png(base + "_grey.png")


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
