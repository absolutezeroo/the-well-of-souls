class_name VillageQuestDef
extends Resource
## A persistent village request, its recoverable evidence and its visible consequence.

@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var objective: String
@export var done_line: String
@export var evidence_name: String
@export var evidence_text: String
@export var evidence_icon: Texture2D
@export var accept_label: String
@export var hand_in_label: String
@export var pending_text: String
@export var return_text: String
## A returned request opens this one; accepting it is still the player's choice.
@export var requires_quest: VillageQuestDef
@export var locked_text: String
@export var offer_text: String
## Whole translated sentence with one %d for reward_souls; effects belong to content.
@export var reward_text: String
@export var floor_depth: int = 2
@export var reward_souls: int = 0
