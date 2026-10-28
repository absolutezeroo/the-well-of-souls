class_name TutorialDef
extends Resource
## The tutorial: the first steps of the first run (move, the seal, attack, roll...) and the hints
## that come up the first time something new happens (an elite, the forge, a rune, a boss...).
## Each hint shows once ever (Profile.hints_seen) once read (tapped, or done); one whose time runs
## out unread comes back on a later floor (`unread_returns` times). The codex's Tips tab lists the
## ones seen. The Options can turn them off or replay them.

@export var hints: Array[HintDef] = []
## Pixels walked that count as "moved".
@export var move_distance := 110.0
## How close (pixels, in sight) a merchant, a forge or a chest must be to bring up its hint.
@export var near_distance := 220.0
## Health ratio that brings up the low-health hint.
@export var low_health := 0.4
## Body temperature (BodyTemperature.value, either way) that brings up the cold or heat hint.
@export var temperature := 30.0
## Seconds between two hints.
@export var gap := 1.2
## A hint whose time runs out unread (not tapped, its action not done) comes back this many times,
## each on a later floor, before it counts as seen.
@export_range(0, 5) var unread_returns := 1


func hint(id: StringName) -> HintDef:
	for each in hints:
		if each.id == id:
			return each
	return null
