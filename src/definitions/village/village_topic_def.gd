class_name VillageTopicDef
extends Resource
## A conditional reply: with a prompt it is a question, without one a resident's reaction.

@export var prompt: String
@export_multiline var reply: String
@export var quest: VillageQuestDef
@export_range(0, 3) var min_stage: int = 0
@export_range(0, 3) var max_stage: int = 3
## Also needs this quest returned: a woken neighbour speaking of the next sleeper, only once they
## are awake themselves (Sayo of Gen, for instance).
@export var after_quest: VillageQuestDef
