class_name VillageResidentDef
extends Resource
## A resident's place, voice and service. Sleeping residents appear as lantern echoes.

enum Role { TALK, QUEST, MERCHANT }

@export var id: StringName
@export var speaker: SpeakerDef
@export var position: Vector2
@export var role: Role = Role.TALK
@export var quest: VillageQuestDef
@export var wakes_after: VillageQuestDef
@export_multiline var text: String
@export_multiline var used_text: String
@export var echo: bool = false
@export_multiline var accepted_text: String
@export_multiline var found_text: String
@export var topics: Array[VillageTopicDef] = []
## First matching reaction replaces the greeting (for another home's rescue, for example).
@export var reactions: Array[VillageTopicDef] = []
## The same optional palette is applied to the figure and the conversation portrait.
@export var appearance: Material
@export var idle_frames: Array[Rect2] = []
@export var walk_frames: Array[Rect2] = []
@export var idle_frame_time: float = 0.65
@export var walk_frame_time: float = 0.18
## Appointments sorted by start_hour, with a midnight entry; only awake residents follow them.
@export var schedule: Array[VillageActivityDef] = []
@export var walk_speed: float = 24.0
@export var greeting_radius: float = 100.0
@export var greeting_cooldown: float = 18.0
@export var greeting_seconds: float = 4.0
@export var ambient_before: PackedStringArray = []
@export var ambient_after: PackedStringArray = []


func activity_at(hour: float) -> VillageActivityDef:
	var active: VillageActivityDef = null
	for appointment in schedule:
		if appointment.start_hour <= hour:
			active = appointment
		else:
			break
	return active
