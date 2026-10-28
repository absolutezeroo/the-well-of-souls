class_name SoundMixDef
extends Resource
## The mixing desk (data/audio/sound_mix.tres, used by the Sfx autoload): how loud each bus sits
## under its slider, the safety on Master (a limiter) and on the combat bus (a soft compressor and
## a high-shelf cut), how many voices may play at once, and per-sound trims for the sounds that
## came in too loud or too bright. Busy fights stacked dozens of hot sounds and clipped the
## output; these numbers keep them under 0 dB and easy on the ears.

@export_group("Buses")
## Gain of each bus at full slider (dB), under the player's volume: headroom so a crowded
## fight does not hit the ceiling. Keys: bus names (Combat, World, UI, Music, Ambience).
@export var bus_gain_db: Dictionary[StringName, float] = {}

@export_group("Master limiter")
## Nothing leaves the game louder than this (dB below full scale).
@export var limiter_ceiling_db: float = -1.0
## How fast the limiter lets go after a peak (seconds).
@export var limiter_release: float = 0.1

@export_group("Combat compressor")
## Above this level (dB) the combat bus is gently squeezed, so a dense fight stays one sound.
@export var compressor_threshold_db: float = -16.0
@export var compressor_ratio: float = 3.0
@export var compressor_attack_us: float = 2000.0
@export var compressor_release_ms: float = 180.0

@export_group("Brightness")
## High-shelf cut on the combat and interface buses: above this frequency the sound is
## lowered (whooshes, slashes, arrows, chimes were shrill).
@export var high_shelf_hz: float = 6500.0
## Linear gain above high_shelf_hz on the combat bus (0.5 = -6 dB).
@export_range(0.1, 1.0) var combat_high_shelf_gain: float = 0.5
## Same on the interface bus.
@export_range(0.1, 1.0) var ui_high_shelf_gain: float = 0.7
## Random pitch never goes higher than this (pitched up, sounds turn shrill); it still goes
## as far down as the sound allows.
@export var max_random_pitch_up: float = 1.06

@export_group("Voices")
## World sounds in flight at once (the pools). Past that, a new sound takes the place of the
## farthest one if it is nearer the hero, else it is not played.
@export var combat_voices: int = 16
@export var world_voices: int = 8
@export var ui_voices: int = 6
## The same sound playing at once, at most (a pack hit by one swing: a few hits, not ten).
@export var max_same_voices: int = 3
## The same sound started again within this time (seconds) counts as the same blow...
@export var same_window: float = 0.04
## ...it plays this many times at most within the window...
@export var max_same_in_window: int = 2
## ...and each repeat is this much quieter (dB).
@export var repeat_db: float = -5.0
## Past this many combat voices playing, each new one is a bit quieter (a crowded fight is
## loud enough already).
@export var crowd_start: int = 6
@export var crowd_db_per_voice: float = -0.6
@export var crowd_max_db: float = -6.0
## The wind-up warning (Sfx.play_warning()): a crowd winding up together makes a few cues, not a
## din: at most this many at once, one every `warning_gap` seconds at most, `warning_db` under
## the other fight sounds.
@export var warning_voices: int = 2
@export var warning_gap: float = 0.1
@export var warning_db: float = -3.0
## Distance (pixels) where a positional sound fades out, and how steep the fade is (1 = linear,
## higher = far sounds quieter sooner): a fight off screen should not add to the one at hand.
@export var max_distance: float = 1100.0
@export var combat_attenuation: float = 2.0
@export var world_attenuation: float = 1.5

@export_group("Music")
## The music player's level (dB) under the Music bus: every track is loudness-matched to about
## -19 LUFS when it is added (docs/design/presentation.md, "Music"), so one level fits all.
@export var music_volume_db: float = -8.0
## A new track fades in over this long while the old one fades out over `music_fade_out`: the
## two overlap (a crossfade, never a gap).
@export var music_fade_in: float = 1.2
@export var music_fade_out: float = 0.9
## After a sting (a warden slain, the end of a run), the next music waits this long so the
## sting is heard alone.
@export var sting_gap: float = 2.2
## How fast the music dips under a scene (a boss's story) and comes back (seconds).
@export var duck_time: float = 0.5

@export_group("Trims")
## Per-sound gain (dB) added wherever it plays: evens out sounds recorded too hot or too bright.
@export var trims: Dictionary[AudioStream, float] = {}


## A bus's gain at full slider (dB).
func gain_db(bus: StringName) -> float:
	return bus_gain_db.get(bus, 0.0)


## A sound's trim (dB).
func trim_db(stream: AudioStream) -> float:
	return trims.get(stream, 0.0)
