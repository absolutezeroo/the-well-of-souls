class_name SoundBank
extends Resource
## Sounds for game events that do not belong to one piece of content.
## Content can override some of them (a weapon's hit sound, a monster's death sound...).
## Tip: use an AudioStreamRandomizer to get variations and random pitch for free.

@export_group("Player")
@export var player_hurt: AudioStream
@export var player_death: AudioStream
@export var footstep: AudioStream
@export var level_up: AudioStream
## A perk or relic was chosen.
@export var perk_chosen: AudioStream
## A freed soul reaches the hero's lantern.
@export var soul: AudioStream

@export_group("Monsters")
@export var monster_hurt: AudioStream
@export var monster_death: AudioStream
@export var monster_alert: AudioStream

@export_group("Combat")
@export var projectile_impact: AudioStream
@export var explosion: AudioStream
## The short cue at the start of a monster's wind-up, a blast's fuse, a trap's click
## (Sfx.play_warning(): every warning has a sound, docs/decisions/0008).
@export var telegraph: AudioStream

@export_group("Items")
@export var pickup: AudioStream
## Gold picked up, bought or sold.
@export var coin: AudioStream
@export var equip: AudioStream
## Something dropped from the bag at the hero's feet.
@export var drop: AudioStream
## A piece of gear broken down for gold (before its coins).
@export var dismantle: AudioStream
## A fragment of the past found for the first time (its panel opens on it).
@export var fragment_found: AudioStream

@export_group("World")
@export var stairs: AudioStream
@export var game_over: AudioStream
## Someone drops into a hole.
@export var fall: AudioStream
## The exits of an ambush room slam shut.
@export var ambush: AudioStream

@export_group("Bosses")
## The boss wakes up when you enter its arena.
@export var boss_roar: AudioStream
## Spikes rising or falling across the arena exits.
@export var gate: AudioStream
@export var boss_defeated: AudioStream
## Played while fighting a boss whose BossDef.music and act's ActDef.boss_music are both empty.
@export var boss_music: AudioStream

@export_group("Music")
## Where the music lives (docs/design/presentation.md, "Music"): a floor's in its DungeonTheme, a
## warden's in its BossDef or its act's ActDef.boss_music, the Deeps' and the Threshold's in their
## defs, a true ending's in its EndingDef, a boss story's bed in its CinematicDef. The screens
## outside the dungeon are here; Soundtrack lists every place and what it plays.
## The title screen and the shrine (Kagari asleep above the Well).
@export var title_music: AudioStream
## The shrine's bell, tolled once as the title screen opens (null: none), and how loud.
@export var title_bell: AudioStream
@export_range(-30.0, 6.0, 0.5) var title_bell_db: float = -12.0
## Under the end screen of a run lost (after the game_over sting).
@export var defeat_music: AudioStream
## Under the end screen of a run won (after the boss_defeated sting); a true ending plays its own
## (EndingDef.music).
@export var victory_music: AudioStream

@export_group("Interface")
@export var ui_click: AudioStream
@export var ui_open: AudioStream
@export var ui_close: AudioStream
