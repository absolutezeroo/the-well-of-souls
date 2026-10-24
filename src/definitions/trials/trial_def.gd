class_name TrialDef
extends ContentDef
## A room trial (« épreuve »: docs/design/dungeon.md, "Room trials"): something to do on a floor
## besides reaching its stairs, optional, told in the Well's voice. At most one per floor, and
## only on a floor with no other event (no curse, no floor event: a floor has one thing of its
## own), never the first floor nor a boss floor (DungeonConfig > Trials). `display_name` is its
## name, `description` its lore line, `color` its glow. Each kind is a subclass that lays itself
## on a floor (plan(), make()) and a RoomTrial node that runs it.

@export_group("The objective")
## The objective's line under the minimap: one sentence, "%d" the done and the total
## ("Souls freed: %d / %d").
@export var objective: String = "%d / %d"
## The line the log says when the floor begins (the trial's call).
@export var call_line: String = ""
## The line said when it is done.
@export var done_line: String = ""

@export_group("Waves")
## Foes coming at each step (a soul freed, a lantern lit), plus one every
## `depths_per_extra_foe` floors.
@export_range(0, 8) var foes_per_step: int = 2
@export_range(1.0, 12.0, 0.5) var depths_per_extra_foe: float = 4.0

@export_group("Reward")
## Souls added to the run (paid at its end, as the hidden floor's) once it is done.
@export_range(0, 200) var bonus_souls: int = 0
## A choice of this many relics once it is done (0: none).
@export_range(0, 5) var relic_choices: int = 0


## Foes at each step at `depth`.
func foes_at(depth: int) -> int:
	return foes_per_step + floori(depth / depths_per_extra_foe) if foes_per_step > 0 else 0


## Where it goes on `world`'s floor, or {} if it finds no room (`excluded`: rooms given away).
## Rolls on `rng` only (its own: the rest of the floor is the same with or without it).
func plan(_world: World, _rng: RandomNumberGenerator, _excluded: Array[int]) -> Dictionary:
	return {}


## Its node, laid on `world` as `planned` said; `taken`: cells claimed (it claims its own).
func make(_world: World, _planned: Dictionary, _taken: Dictionary) -> RoomTrial:
	return null
