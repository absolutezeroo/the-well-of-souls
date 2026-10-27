class_name Ambience
extends Node
## Plays a floor's ambience (AmbienceDef): background loop, distant one-shot sounds around the
## hero, the echo of the SFX bus, floating particles, drifting fog. Also the low-health mood:
## heartbeat and muffled music.

const LOW_HEALTH := 0.3
const FOG_SHADER: Shader = preload("res://assets/shaders/fog.gdshader")

var _def: AmbienceDef
var _player: Player
var _one_shot_timer := 0.0
var _particles: CPUParticles2D
var _low_health := false
var _heartbeat_timer := 0.0
var _atmosphere: AtmosphereLayer

@onready var _bed: AudioStreamPlayer = $Bed
@onready var _heartbeat: AudioStreamPlayer = $Heartbeat
@onready var _fog: TextureRect = $FogLayer/Fog


func _ready() -> void:
	_fog.visible = false


## Switches to a new floor's ambience. `world` hosts the particles. `look`: another ambience's
## visuals over this one's sounds (a Blood Moon over the biome).
func play(def: AmbienceDef, world: World, player: Player, look: AmbienceDef = null) -> void:
	_def = def
	var visuals := look if look else def
	if _player != player:
		if _player and is_instance_valid(_player):
			_player.health_changed.disconnect(_on_health_changed)
		_player = player
		_player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.hp, player.get_max_hp())
	_one_shot_timer = _next_delay()
	_set_reverb(def.reverb_room_size if def else 0.3, def.reverb_wet if def else 0.0)
	_play_bed(def.bed if def else null, def.bed_volume_db if def else -16.0)
	_spawn_particles(world, visuals)
	_spawn_atmosphere(world, visuals)
	var screen := get_tree().get_first_node_in_group(&"screen_effects") as ScreenEffects
	if screen:
		screen.set_mood(visuals)
	_fog.visible = visuals != null and visuals.fog != null
	if _fog.visible:
		_fog.texture = visuals.fog
		var shader := ShaderMaterial.new()
		shader.shader = FOG_SHADER
		shader.set_shader_parameter("tint", visuals.fog_color)
		shader.set_shader_parameter("speed", visuals.fog_speed)
		_fog.material = shader


func is_low_health() -> bool:
	return _low_health


func _process(delta: float) -> void:
	if not Vfx.shown:
		return  # a simulation: nothing to see (Vfx.shown)
	if _player == null or not is_instance_valid(_player):
		return
	if _particles and is_instance_valid(_particles):
		var camera := get_viewport().get_camera_2d()
		_particles.global_position = camera.get_screen_center_position() if camera else _player.global_position
	if _fog.visible and _fog.material:
		var camera := get_viewport().get_camera_2d()
		if camera:
			(_fog.material as ShaderMaterial).set_shader_parameter("camera_offset", camera.get_screen_center_position())
	if _def and not _def.one_shots.is_empty():
		_one_shot_timer -= delta
		if _one_shot_timer <= 0.0:
			_one_shot_timer = _next_delay()
			# Somewhere off to the side, so it sounds distant and directional.
			var at := _player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(250.0, 500.0)
			Sfx.play_world(_def.one_shots.pick_random(), at, _def.one_shot_volume_db, randf_range(0.85, 1.1))
	if _low_health and not _player.is_dead:
		_heartbeat_timer -= delta
		if _heartbeat_timer <= 0.0:
			var ratio := float(_player.hp) / _player.get_max_hp()
			_heartbeat_timer = lerpf(0.55, 1.0, ratio / LOW_HEALTH)
			if Sfx.enabled:
				_heartbeat.play()


func _next_delay() -> float:
	if _def == null:
		return 999.0
	return randf_range(_def.one_shot_every.x, _def.one_shot_every.y)


func _play_bed(stream: AudioStream, volume_db: float) -> void:
	if not Sfx.enabled or stream == null:
		_bed.stop()
		return
	if _bed.stream == stream and _bed.playing:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_bed.stream = stream
	_bed.volume_db = -40.0
	_bed.play()
	create_tween().tween_property(_bed, "volume_db", volume_db, 1.5)


func _set_reverb(room_size: float, wet: float) -> void:
	var bus := AudioServer.get_bus_index(&"SFX")
	if bus < 0 or AudioServer.get_bus_effect_count(bus) == 0:
		return
	var reverb := AudioServer.get_bus_effect(bus, 0) as AudioEffectReverb
	if reverb:
		reverb.room_size = room_size
		reverb.wet = wet


func _spawn_particles(world: World, visuals: AmbienceDef) -> void:
	if _particles and is_instance_valid(_particles):
		_particles.queue_free()
	_particles = null
	if visuals == null or visuals.particles == null:
		return
	_particles = visuals.particles.instantiate() as CPUParticles2D
	world.spawn_vfx(_particles)


func _spawn_atmosphere(world: World, def: AmbienceDef) -> void:
	if _atmosphere and is_instance_valid(_atmosphere):
		_atmosphere.queue_free()
	_atmosphere = AtmosphereLayer.create(def, world.map) if world.map else null
	if _atmosphere:
		world.spawn_vfx(_atmosphere)


func _on_health_changed(current: int, maximum: int) -> void:
	var low := current > 0 and float(current) / maxi(maximum, 1) <= LOW_HEALTH
	if low == _low_health:
		return
	_low_health = low
	_heartbeat_timer = 0.0
	_muffle(low)


## Muffled music while close to death. The filter is the Music bus's, shared by every scene.
static func _muffle(on: bool) -> void:
	var bus := AudioServer.get_bus_index(&"Music")
	if bus >= 0 and AudioServer.get_bus_effect_count(bus) > 0:
		AudioServer.set_bus_effect_enabled(bus, 0, on)


## Leaving the game close to death (back to the village or the title): the muffle goes too, or
## the village's music and the next run (whose hero starts healthy) would stay muffled.
func _exit_tree() -> void:
	if _low_health:
		_low_health = false
		_muffle(false)
