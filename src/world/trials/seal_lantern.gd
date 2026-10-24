class_name SealLantern
extends Node2D
## A lantern of the Unbound Seal (SealTrial), put out, standing in a room of the floor: stand by
## it and press Interact ("Light") to light it. Lit, it burns in the trial's color with a light
## of its own and a flame flickering on top (12 fps, on the art's grid), and its point of the
## seal lights up.

signal lit(lantern: SealLantern)

const OUT := Color(0.38, 0.36, 0.42)

var def: PropDef
var index := 0
var color := Color.WHITE
var is_lit := false

var _spot := Interactable.new()
var _light: LightSource
var _time := 0.0
var _drawn_key := -1


func setup(prop: PropDef, at_index: int, flame_color: Color) -> void:
	def = prop
	index = at_index
	color = flame_color
	name = "SealLantern_%d" % at_index
	y_sort_enabled = true
	add_to_group("seal_lanterns")
	_spot.verb = "Kindle"  # i18n ("Light" is the weight's word: Léger)
	_spot.reach = 44.0
	_spot.color = flame_color
	_spot.icon = prop.icon if prop else null
	_spot.used.connect(func(_by: Player) -> void: light(false))
	add_child(_spot)


## Lit (`quiet`: a resumed floor's, no foes, no step counted by its trial).
func light(quiet: bool) -> void:
	if is_lit:
		return
	is_lit = true
	_spot.enabled = false
	_light = LightSource.new()
	_light.color = color
	_light.level = 11
	_light.relative = true
	_light.position = Vector2(0, -14)
	add_child(_light)
	_drawn_key = -1
	queue_redraw()
	if not quiet:
		Sfx.play_world(Sfx.bank.gate, global_position, -4.0)
		lit.emit(self)


func _process(delta: float) -> void:
	_time += delta
	if not Vfx.on_screen(self, 32.0):
		return
	var key := (floori(_time * 12.0) if is_lit else 0) * 2 + (1 if is_lit else 0)
	if key != _drawn_key:
		_drawn_key = key
		queue_redraw()


func _draw() -> void:
	var icon: Texture2D = def.icon if def else null
	PixelDraw.disc(self, Vector2(0, 2), 8.0, Color(0, 0, 0, 0.35), 1.0, 0.4)
	if icon:
		var size := icon.get_size() * 2.0
		draw_texture_rect(icon, Rect2(PixelDraw.snap(Vector2(-size.x * 0.5, -size.y)), size), false, Color.WHITE if is_lit else OUT)
	if is_lit:
		# The flame: a few pixels of its color over the lantern, flickering by whole pixels.
		var flick := floori(_time * 12.0) % 3
		var top := Vector2(0, -20 - flick * PixelDraw.PX * 0.5)
		PixelDraw.pixel(self, top, color.lightened(0.4))
		PixelDraw.pixel(self, top + Vector2(-PixelDraw.PX, PixelDraw.PX), color)
		PixelDraw.pixel(self, top + Vector2(PixelDraw.PX * (flick - 1), PixelDraw.PX), color)
