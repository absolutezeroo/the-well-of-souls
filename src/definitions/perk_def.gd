class_name PerkDef
extends Resource
## A permanent upgrade for the run, picked on level up (common perks) or after a boss (rare relics).
## Stat bonuses and passives both stack: taking a perk twice doubles its effect.
## Most belong to a family or two (SynergyDef): three of a family wake its bonus.

enum Rarity { COMMON, RARE }

@export var id: StringName
@export var display_name: String
## Shown on the choice card. Leave empty for pure stat perks: the bonuses describe themselves.
@export_multiline var description: String
@export var icon: Texture2D
@export var color: Color = Color.WHITE
@export var rarity: Rarity = Rarity.COMMON
@export_range(1, 10) var max_stacks: int = 3
## Relative chance to be offered.
@export_range(0, 100) var weight: int = 10
## Its families (Inferno, Frost...): each different perk of a family counts once.
@export var synergies: Array[SynergyDef] = []

@export_group("Effects (per stack)")
@export var bonuses: StatBlock
@export var passives: Array[Passive] = []


## Text for the choice card.
func describe() -> String:
	var lines := PackedStringArray()
	if not description.is_empty():
		lines.append(tr(description))
	if bonuses:
		var stats := bonuses.describe()
		if not stats.is_empty():
			lines.append(stats)
	return "\n".join(lines)
