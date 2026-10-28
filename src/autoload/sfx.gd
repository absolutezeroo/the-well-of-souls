extends Node
## Sound effects player (autoload "Sfx"). Every sound goes to the bus of its slider in Options:
## - play_at(): the fight (weapons, hits, cries, skills, spells, shots, explosions, traps,
##   statuses, deaths) on the Combat bus, positional;
## - play_world(): the place and its things (footsteps, distant sounds, doors and gates, chests,
##   coins and pickups, crates breaking, crumbling floors, fires, the forge) on the World bus,
##   positional, under the Ambience slider;
## - play_ui(): menus, buttons and jingles (level up, stairs, a boss slain, the knell) on the UI bus.
## Music on the Music bus (play_music: a crossfade between two players; which track where: Soundtrack); the floor's background loop and the heartbeat are played by Ambience
## on the Ambience bus. Combat and World send to the SFX bus (the room's reverb), then Master
## (a limiter).
## Busy fights used to stack dozens of sounds and clip: voices are capped (per sound, per pool),
## the same sound started again within a few milliseconds plays quieter or not at all, and a
## crowded fight lowers each new voice a little. The numbers are in SoundMixDef
## (data/audio/sound_mix.tres).

const MIX: SoundMixDef = preload("res://data/audio/sound_mix.tres")
const COMBAT := &"Combat"
const WORLD := &"World"
const UI := &"UI"
const MUSIC := &"Music"
const AMBIENCE := &"Ambience"
## The room's reverb, shared by the Combat and World buses.
const ROOM := &"SFX"
## Every sound is played on one of these (tests check it).
const BUSES: Array[StringName] = [COMBAT, WORLD, UI, MUSIC, AMBIENCE]
## Where a fading track ends (dB).
const SILENT_DB := -40.0

## Generic sounds, set by the Game from the ContentDB.
var bank := SoundBank.new()
## Master switch (the headless tests turn sound off).
var enabled := true
var mix: SoundMixDef = MIX

## Two music players take turns, so the old track fades out while the new one fades in.
var _music_main: AudioStreamPlayer
var _music_other: AudioStreamPlayer
## The one playing (or about to) the current track; the other one fades out or rests.
var _music: AudioStreamPlayer
var _music_stream: AudioStream
var _duck_db := 0.0
var _tweens := {}  # music player -> its fade
var _combat: Array[AudioStreamPlayer2D] = []
var _world: Array[AudioStreamPlayer2D] = []
var _ui: Array[AudioStreamPlayer] = []
var _next_ui := 0
var _recent := {}  # AudioStream -> PackedFloat64Array of start times
## When the last wind-up warning was let through (seconds, real time), and how many were (tests).
var _last_warning := -1000.0
var warnings_played := 0
var _source := {}  # player -> the AudioStream it was asked to play (not the picked variation)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in mix.combat_voices:
		_combat.append(_make_2d(COMBAT, mix.combat_attenuation))
	for i in mix.world_voices:
		_world.append(_make_2d(WORLD, mix.world_attenuation))
	_music_main = _make_music_player("Music")
	_music_other = _make_music_player("MusicCrossfade")
	_music = _music_main
	for i in mix.ui_voices:
		var player := AudioStreamPlayer.new()
		player.bus = UI
		add_child(player)
		_ui.append(player)
	apply_mix()


## Copies the mix's numbers into the bus effects (limiter, compressor, high shelves).
func apply_mix() -> void:
	var limiter := _effect(&"Master", "AudioEffectHardLimiter") as AudioEffectHardLimiter
	if limiter:
		limiter.ceiling_db = mix.limiter_ceiling_db
		limiter.release = mix.limiter_release
	var compressor := _effect(COMBAT, "AudioEffectCompressor") as AudioEffectCompressor
	if compressor:
		compressor.threshold = mix.compressor_threshold_db
		compressor.ratio = mix.compressor_ratio
		compressor.attack_us = mix.compressor_attack_us
		compressor.release_ms = mix.compressor_release_ms
	for bus: StringName in [COMBAT, UI]:
		var shelf := _effect(bus, "AudioEffectHighShelfFilter") as AudioEffectHighShelfFilter
		if shelf:
			shelf.cutoff_hz = mix.high_shelf_hz
			shelf.gain = mix.combat_high_shelf_gain if bus == COMBAT else mix.ui_high_shelf_gain


## A fight sound in the world at `position` (Combat bus).
func play_at(stream: AudioStream, position: Vector2, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	_play_2d(_combat, stream, position, volume_db, pitch, true)


## A sound of the place or its things at `position` (World bus, under the Ambience slider).
func play_world(stream: AudioStream, position: Vector2, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	_play_2d(_world, stream, position, volume_db, pitch, false)


## The short cue at the start of a monster's wind-up, a blast's fuse or a trap's click, at
## `position` (Combat bus): every warning has a sound as well as its pose and its mark on the
## ground (docs/decisions/0008). A crowd winding up together makes a few cues, not a din: one
## every mix.warning_gap seconds (real time: a hit stop doesn't bunch them), mix.warning_voices
## at most at once. Returns whether it was let through.
func play_warning(position: Vector2) -> bool:
	if bank.telegraph == null:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_warning < mix.warning_gap:
		return false
	var playing := 0
	for player: AudioStreamPlayer2D in _combat:
		if player.playing and _source.get(player) == bank.telegraph:
			playing += 1
	if playing >= mix.warning_voices:
		return false
	_last_warning = now
	warnings_played += 1
	play_at(bank.telegraph, position, mix.warning_db)
	return true


## Plays a non-positional sound (menus, jingles) on the UI bus.
func play_ui(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null or not enabled:
		return
	var gain := _admit(stream, _ui)
	if is_nan(gain):
		return
	var player := _ui[_next_ui]
	_next_ui = (_next_ui + 1) % _ui.size()
	var variation := _pick_variation(stream)
	_source[player] = stream
	player.stream = variation[0]
	player.volume_db = volume_db + gain + variation[2]
	player.pitch_scale = variation[1]
	player.play()


## The buses of the voices last given `stream` (tests).
func buses_playing(stream: AudioStream) -> Array[StringName]:
	var buses: Array[StringName] = []
	for player: Node in _source:
		if _source[player] == stream:
			buses.append(player.get(&"bus"))
	return buses


func _play_2d(pool: Array[AudioStreamPlayer2D], stream: AudioStream, position: Vector2, volume_db: float, pitch: float, crowd: bool) -> void:
	if stream == null or not enabled:
		return
	var gain := _admit(stream, pool)
	if is_nan(gain):
		return
	var player := _free_voice(pool, position)
	if player == null:
		return
	if crowd:
		gain += _crowd_db(pool)
	var variation := _pick_variation(stream)
	_source[player] = stream
	player.stream = variation[0]
	player.global_position = position
	player.volume_db = volume_db + gain + variation[2]
	player.pitch_scale = pitch * variation[1]
	player.play()


## Whether `stream` may start now, and its gain (trim, quieter repeats); NAN = not played.
## The same sound at most max_same_voices at once, and max_same_in_window times within
## same_window (one swing on a pack: a couple of hits, not ten stacked).
func _admit(stream: AudioStream, pool: Array) -> float:
	var same := 0
	for player: Node in pool:
		if _source.get(player) == stream and player.get(&"playing"):
			same += 1
	if same >= mix.max_same_voices:
		return NAN
	var now := Time.get_ticks_msec() / 1000.0
	var kept := PackedFloat64Array()
	for t: float in _recent.get(stream, PackedFloat64Array()):
		if now - t < mix.same_window:
			kept.append(t)
	if kept.size() >= mix.max_same_in_window:
		_recent[stream] = kept
		return NAN
	var gain := mix.trim_db(stream) + mix.repeat_db * kept.size()
	kept.append(now)
	_recent[stream] = kept
	return gain


## A player that is free, else the one farthest from the hero if this sound is nearer
## (it is cut), else null (the sound is not played).
func _free_voice(pool: Array[AudioStreamPlayer2D], position: Vector2) -> AudioStreamPlayer2D:
	var listener := listener_position()
	var farthest: AudioStreamPlayer2D = null
	var far := -1.0
	for player in pool:
		if not player.playing:
			return player
		var distance := player.global_position.distance_squared_to(listener)
		if distance > far:
			far = distance
			farthest = player
	if farthest and position.distance_squared_to(listener) < far:
		farthest.stop()
		return farthest
	return null


## Past crowd_start voices playing, each new one a bit quieter.
func _crowd_db(pool: Array[AudioStreamPlayer2D]) -> float:
	var playing := 0
	for player in pool:
		if player.playing:
			playing += 1
	return maxf(mix.crowd_max_db, mix.crowd_db_per_voice * maxi(0, playing - mix.crowd_start))


## Where the ears are: the middle of the screen, in world space (the camera's, if any).
func listener_position() -> Vector2:
	var viewport := get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect().get_center()


func _make_music_player(node_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.bus = MUSIC
	player.volume_db = SILENT_DB
	add_child(player)
	return player


func _make_2d(bus: StringName, attenuation: float) -> AudioStreamPlayer2D:
	var player := AudioStreamPlayer2D.new()
	player.bus = bus
	player.max_distance = mix.max_distance
	player.attenuation = attenuation
	add_child(player)
	return player


func _effect(bus_name: StringName, type: String) -> AudioEffect:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return null
	for i in AudioServer.get_bus_effect_count(bus):
		var effect := AudioServer.get_bus_effect(bus, i)
		if effect.is_class(type):
			return effect
	return null


## AudioStreamRandomizer is used as data (variations + pitch/volume ranges), but we pick
## the variation ourselves: playing the randomizer directly leaks its playbacks in Godot 4.
## The pitch goes down as far as the randomizer says, up only to mix.max_random_pitch_up
## (pitched up, sounds turn shrill).
## Returns [stream, pitch multiplier, volume offset in dB].
func _pick_variation(stream: AudioStream) -> Array:
	var randomizer := stream as AudioStreamRandomizer
	if randomizer == null or randomizer.streams_count == 0:
		return [stream, 1.0, 0.0]
	var picked := randomizer.get_stream(randi() % randomizer.streams_count)
	var pitch_range := maxf(randomizer.random_pitch, 1.0)
	var pitch := exp(randf_range(-log(pitch_range), log(minf(pitch_range, maxf(mix.max_random_pitch_up, 1.0)))))
	var volume := randf_range(-randomizer.random_volume_offset_db, randomizer.random_volume_offset_db)
	return [picked, pitch, volume]


## Starts a looping track, crossfading from the one playing (both overlap: the old one fades out
## over mix.music_fade_out while the new one comes in over mix.music_fade_in). The same track asked
## again keeps playing where it is, never restarted (two floors of a biome, a floor's music after
## its warden's). `delay`: seconds of silence first (after a sting). Returns true if the music
## changes.
func play_music(stream: AudioStream, delay: float = 0.0) -> bool:
	if not enabled or stream == null:
		return false
	if stream == _music_stream:
		_fade_music_to(_music_level(), mix.duck_time)  # (back up if it was being silenced)
		return false
	_music_stream = stream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true  # (the .import says so too; tests check it)
	var old := _music
	_music = _music_other if _music == _music_main else _music_main
	_music_other = old
	_kill_tween(old)
	if old.playing:
		var out := old.create_tween()
		out.tween_property(old, "volume_db", SILENT_DB, mix.music_fade_out)
		out.tween_callback(old.stop)
		_tweens[old] = out
	var player := _music
	_kill_tween(player)
	player.stop()
	player.stream = stream
	player.volume_db = SILENT_DB
	var fade := player.create_tween()
	if delay > 0.0:
		fade.tween_interval(delay)
	fade.tween_callback(player.play)
	fade.tween_property(player, "volume_db", _music_level(), mix.music_fade_in)
	_tweens[player] = fade
	return true


## Fades the music out to silence (`fade` seconds; negative: mix.music_fade_out). The next
## play_music() starts its track afresh, even the same one.
func stop_music(fade: float = -1.0) -> void:
	_music_stream = null
	for player: AudioStreamPlayer in [_music_main, _music_other]:
		_kill_tween(player)  # (a track still waiting out its delay never starts)
		if not player.playing:
			continue
		var out := player.create_tween()
		out.tween_property(player, "volume_db", SILENT_DB, mix.music_fade_out if fade < 0.0 else fade)
		out.tween_callback(player.stop)
		_tweens[player] = out


## Lowers the music by `db` under a scene (a boss's story); 0 brings it back.
func duck_music(db: float) -> void:
	_duck_db = minf(db, 0.0)
	if _music_stream != null:
		_fade_music_to(_music_level(), mix.duck_time)


## The track playing or coming in (null: silence, or fading out to it).
func current_music() -> AudioStream:
	return _music_stream


func _music_level() -> float:
	return mix.music_volume_db + _duck_db


func _fade_music_to(volume_db: float, seconds: float) -> void:
	var player := _music
	if not player.playing and player.stream != _music_stream:
		return
	var running: Tween = _tweens.get(player)
	if running and running.is_valid() and running.is_running() and not player.playing:
		return  # still waiting out its delay: it comes in at the right level by itself
	_kill_tween(player)
	var fade := player.create_tween()
	fade.tween_property(player, "volume_db", volume_db, seconds)
	_tweens[player] = fade


func _kill_tween(player: AudioStreamPlayer) -> void:
	var running: Tween = _tweens.get(player)
	if running and running.is_valid():
		running.kill()
	_tweens.erase(player)


## Stops everything (used before quitting or when restarting).
func stop_all() -> void:
	for player: AudioStreamPlayer in [_music_main, _music_other]:
		_kill_tween(player)
		player.stop()
		player.stream = null
	_music_stream = null
	_duck_db = 0.0
	for player in _combat + _world:
		player.stop()
		player.stream = null
	for player in _ui:
		player.stop()
		player.stream = null
	_recent.clear()
	_source.clear()
