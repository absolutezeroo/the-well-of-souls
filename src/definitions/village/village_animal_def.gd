class_name VillageAnimalDef
extends Resource
## One of Kagari's animals (the pack's Actor/Animal sheets): it belongs to a place, like a prop to
## its owner (the cottage's hens, the Wanderer's cat, the woodcutter's dog), and wanders around it
## on the village's navigation. Ambient only: no conversation, no collision with the hero, no
## dungeon dice (docs/design/village.md "Animals").

@export var id: StringName
## A row of 16x16 frames facing right (the pack's two-frame animal sheets).
@export var texture: Texture2D
## Where it rests, and the middle of the place it wanders by day (within about 3 tiles of its
## owner, docs/design/village.md "Placement rules").
@export var home: Vector2
## Half the size of the box it wanders in, around its home.
@export var roam := Vector2(64, 48)
## Played in turn while it stands still; a frame may repeat (a hen pecks now and then).
@export var idle_frames: Array[Rect2] = []
@export var walk_frames: Array[Rect2] = []
@export var idle_frame_time: float = 0.5
@export var walk_frame_time: float = 0.15
@export var walk_speed: float = 20.0
## Seconds it stays between two walks: picked between x and y from its own seed.
@export var pause := Vector2(2.0, 6.0)
## Village hours it wanders; outside them it goes home and stays (hens roost, the dog lies by
## the door). Equal hours: it never sleeps.
@export_range(0.0, 24.0) var wakes_at: float = 6.0
@export_range(0.0, 24.0) var sleeps_at: float = 20.0
@export var art_scale: float = 2.0


## Whether it wanders at this village hour (a span may cross midnight).
func awake_at(hour: float) -> bool:
	if is_equal_approx(wakes_at, sleeps_at):
		return true
	if wakes_at < sleeps_at:
		return hour >= wakes_at and hour < sleeps_at
	return hour >= wakes_at or hour < sleeps_at
