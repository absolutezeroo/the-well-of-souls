class_name AssistDef
extends Resource
## The Souls' Aid (decision 0011, design/progression.md "Help without judgement"): an option the
## Options offer plainly, never mocked, like Hades' God Mode. With it on, the hero takes less
## damage, a little less again after each death with it on (Profile.assist_deaths), up to a cap.
## Runs it touches are "aided" (RunState.assisted): they go on no online leaderboard and set no
## record; souls, the story, the codex and the achievements count as ever.

## Share of each hit taken away (after Armor: Player._incoming_damage), at first.
@export_range(0.0, 1.0, 0.01) var resistance := 0.2
## And this much more after each death with it on.
@export_range(0.0, 0.2, 0.005) var per_death := 0.02
## Never more than this.
@export_range(0.0, 0.95, 0.01) var most := 0.8


## The share of each hit taken away after `deaths` deaths with the aid on.
func resistance_after(deaths: int) -> float:
	return clampf(resistance + per_death * maxi(deaths, 0), 0.0, most)
