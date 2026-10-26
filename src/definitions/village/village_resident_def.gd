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
