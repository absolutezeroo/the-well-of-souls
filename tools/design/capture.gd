extends Node
## Captures for reviewing a visual change (docs/art-bible.md "Check with your eyes"): each shot
## at 1:1, a x4 nearest-neighbour crop of its centre (whole pixels?) and a greyscale copy
## (readability by value). A tool, not exported; tools/design/capture.py runs it per resolution.
## godot --rendering-driver opengl3 --resolution WxH res://tools/design/capture.tscn -- <outdir> <tag> [shots]
## shots (comma-separated, default all): village, village_map, temple, talk.

const SHOTS := ["village", "village_map", "temple", "talk"]
const HUB := "res://src/village/village_hub.tscn"


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
		var hub := (load(HUB) as PackedScene).instantiate()
		add_child(hub)
		await _frames(30)
		match shot:
			"village_map":
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
