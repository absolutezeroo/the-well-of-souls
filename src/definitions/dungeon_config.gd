class_name DungeonConfig
extends Resource
## The run (acts, in order) and tuning for floor generation and difficulty.

## The acts of a run, in order. Beating the last act's boss wins the run; after that the
## acts loop (endless mode), harder every time because monsters scale with depth.
@export var acts: Array[ActDef] = []

@export_group("Layout")
@export var tile_size: int = 32
## Floor size and rooms before the difficulty (DifficultyDef.floor_size, rooms); boss floors
## always use these.
@export var width: int = 64
@export var height: int = 64
@export var max_rooms: int = 12
@export var room_min_size: int = 7
@export var room_max_size: int = 13
@export_range(1, 5) var corridor_width: int = 3
## Rock kept between two rooms of a normal floor, in cells. Less than
## DungeonGenerator.MIN_WALL_THICKNESS and smooth() opens the wall between them: the two rooms
## merge into one sprawling space (decision 0012).
@export_range(2, 6) var room_gap: int = 3
## The chasms and pools of shaped rooms (RoomShapeDef) in a biome without its own
## (BiomeDef.chasm, BiomeDef.pool), and the pillars of a shape without one.
@export var chasm: PitDef
@export var pool: GroundLayerDef
@export var pillar: PropDef

@export_group("Stairs seal")
## The stairs of a normal floor open once the hero has slain this share of the floor's
## monsters (0 = always open). Every kill counts: ambush waves, summons... See StairsSeal.
@export_range(0.0, 1.0) var seal_share: float = 0.7
## When this few kills are left, the minimap shows where the remaining monsters are.
@export_range(0, 20) var seal_reveal_left: int = 4
## The most kills a seal asks for, however crowded the floor.
@export_range(0, 200) var seal_max: int = 50

@export_group("Perk choices")
## Rerolls (three new cards) and banishes (a perk gone for the run) the hero starts every run
## with; the shrine adds more (UpgradeDef REROLLS / BANISHES).
@export_range(0, 10) var base_rerolls: int = 1
@export_range(0, 10) var base_banishes: int = 1
## Rerolls gained for every boss slain.
@export_range(0, 5) var rerolls_per_boss: int = 1
## Offers favour perks of the families the hero has started but not woken yet: their weight
## is multiplied by (1 + this) for each such family.
@export_range(0.0, 5.0) var family_bias: float = 1.0

@export_group("Population")
## Monsters follow a room's size (decision 0012): a room of `room_cells` open ground cells gets
## `monsters_per_room` on the first floor, plus the floor's extra ones (FloorRules.extra_monsters());
## a room twice as big gets twice as many (FloorRules.room_monsters()). A fight room gets
## `monsters_per_room_min` at least, `max_monsters_per_room` at most.
@export_range(20, 400) var room_cells: int = 104
@export_range(0.5, 6.0, 0.05) var monsters_per_room: float = 2.0
@export var monsters_per_room_min: int = 1
## Extra monsters per room (of `room_cells`) for each depth below the first.
@export var extra_monsters_per_depth: float = 0.5
@export var max_monsters_per_room: int = 6
## A tough monster takes more of its room's share: an elite (any rank) or a big body (its radius at
## least `tough_radius`) counts as `tough_cost` monsters.
@export_range(1, 4) var tough_cost: int = 2
@export var tough_radius: float = 14.0
## The most monsters a floor starts with (the phone keeps up; rooms get fewer when over).
@export var max_monsters_per_floor: int = 110
@export var items_per_floor: int = 4

@export_group("Props and hazards")
## Lantern placed along the walls of every room (light in the dark).
@export var room_light: PropDef
@export_range(0, 6) var lights_per_room: int = 2
## Small groups of crates, pots and barrels per room.
@export_range(0, 10) var prop_clusters_min: int = 0
@export_range(0, 10) var prop_clusters_max: int = 2
## Groups of hazards per floor (a row of spikes, a few holes...), picked from the act's list.
@export_range(0, 20) var hazard_groups_min: int = 3
@export_range(0, 20) var hazard_groups_max: int = 5

@export_group("Chests")
## Chests lying around a floor (some are trapped: see ChestDef), times the floor's size. One at
## least (decision 0012: a treasure on every floor), the first in a dead end, else a calm room on
## the way (FloorPacing).
@export var chest: ChestDef
@export_range(1, 6) var chests_min: int = 1
@export_range(1, 6) var chests_max: int = 1

@export_group("Pacing")
## Fight rooms in a row at most on the way from the start to the stairs: the one after is kept
## calm (no monsters; an encounter, a chest or nothing but its crates). See FloorPacing.
@export_range(0, 10) var max_fights_in_a_row: int = 3
## Where along the way (0 the start, 1 the stairs) the floor peaks: the ambush, the pact door, or
## else an elite in a fight room there. The merchant and the forge come after it (the release).
@export_range(0.0, 1.0, 0.05) var peak_from: float = 0.6
@export_range(0.0, 1.0, 0.05) var peak_to: float = 0.8
## From this floor on, a floor with neither ambush nor pact door at its peak gets an elite there.
@export_range(1, 20) var peak_elite_min_depth: int = 2

@export_group("Ambushes")
## Chance for a floor to have an ambush room: it looks empty, then the exits close and
## monsters pour in, wave after wave. A big chest waits for whoever survives.
@export_range(0.0, 1.0) var ambush_chance: float = 0.6
@export_range(1, 5) var ambush_waves: int = 2
## Monsters per wave, plus one every `ambush_depths_per_extra` floors (FloorRules.ambush_wave_size).
@export_range(1, 12) var ambush_wave_size: int = 3
@export_range(1.0, 10.0, 0.5) var ambush_depths_per_extra: float = 3.0
## Seconds between two monsters of a wave coming in, and between two waves.
@export_range(0.05, 2.0, 0.05) var ambush_spawn_interval: float = 0.25
@export_range(0.0, 5.0, 0.1) var ambush_wave_pause: float = 1.0
## Monsters of a wave come in at least this far from the hero.
@export var ambush_min_spawn_distance: float = 90.0
## Reward for clearing an ambush.
@export var ambush_chest: ChestDef

@export_group("Loot")
## Chances for found equipment to be Common, Magic, Rare or Epic (relative weights), and how
## the better ones grow per floor. Bosses, elites and chests multiply the better ones (quality).
@export var common_weight: float = 70.0
@export var magic_weight: float = 22.0
@export var magic_weight_per_depth: float = 1.0
@export var rare_weight: float = 5.0
@export var rare_weight_per_depth: float = 1.0
@export var epic_weight: float = 0.6
@export var epic_weight_per_depth: float = 0.4
## Bad-luck protection (decision 0012): after `pity_after` pieces of equipment found in a row
## without a Rare or better (RunLuck.rare_drought; not the merchant's, not what a floor lays), the
## Rare and Epic weights grow by `pity_growth` for each further piece, until one comes
## (LootRoller.pity_scale()). 0: no protection.
@export_range(0, 100) var pity_after: int = 20
@export_range(0.0, 5.0, 0.05) var pity_growth: float = 1.0
## Quality of what bosses drop (1 = a common monster; elites: MonsterRankDef.loot_quality).
@export var boss_loot_quality: float = 5.0
## A boss at a rare rank (Fell, Legendary...) drops better still: its quality times 1 + this per
## affix (one at least).
@export_range(0.0, 2.0, 0.05) var boss_rank_loot_per_affix: float = 0.25
## Consumables found while the hero already carries this many of the same one (belt and bag)
## drop as gold instead: no bag full of potions. The gold: this share of the item's value, this
## many coins at least.
@export_range(1, 20) var consumable_carry_cap: int = 4
@export_range(0.0, 1.0, 0.05) var consumable_gold_share: float = 0.3
@export_range(0, 50) var consumable_gold_min: int = 2

@export_group("Gold")
## Chance for a monster to drop gold (elites and bosses always do).
@export_range(0.0, 1.0) var gold_drop_chance: float = 0.45
## Coins on the floor come in piles of about this much (at most `gold_max_piles`), each flying
## to the hero on its own.
@export_range(1.0, 50.0, 1.0) var gold_per_pile: float = 4.0
@export_range(1, 20) var gold_max_piles: int = 6
@export var gold_per_kill: Vector2i = Vector2i(1, 4)
## Extra gold per floor below the first.
@export var gold_per_depth: float = 0.6
@export var boss_gold_multiplier: float = 15.0
## Crates and pots sometimes hold a few coins.
@export_range(0.0, 1.0) var prop_gold_chance: float = 0.25
@export var prop_gold: Vector2i = Vector2i(1, 3)
@export var prop_gold_per_depth: float = 0.5

@export_group("Souls")
## What a run earns for the Tree of Souls (souls_for_run, times the difficulty's `souls`): a
## share of a soul per monster slain (the shares add up over the run and the total is rounded
## once, so 0.25 is a soul every four kills)...
@export_range(0.0, 5.0) var souls_per_kill: float = 1.0
## ...souls per floor gone down (the bulk: going deeper pays, farming monsters doesn't)...
@export_range(0, 100) var souls_per_floor: int = 5
## ...per boss slain, and for winning the run.
@export_range(0, 200) var souls_per_boss: int = 20
@export_range(0, 1000) var souls_for_victory: int = 100

@export_group("Temperature")
## The hero's body temperature (BodyTemperature): -100 frozen, 0 fine, 100 burning up.
## Back to normal by this much per second when nothing warms or chills.
@export var temperature_recovery: float = 25.0
## Campfires bring it back to normal this fast (per second).
@export var temperature_comfort_rate: float = 70.0
## Damage every `temperature_tick` seconds at either end (grows with depth).
@export var temperature_damage: int = 3
@export var temperature_tick: float = 1.0
## Slowed by up to this much when cold (from halfway to frozen).
@export_range(0.0, 0.9) var cold_slow: float = 0.35

@export_group("Floor events")
## Chance for a normal floor (not the first) to be special (content_db.tres > Floor Events).
@export_range(0.0, 1.0) var floor_event_chance: float = 0.3

@export_group("Routes")
## Ways down at the end of a floor (FloorRoute): each leads to a different world of the next
## floor, its curse or event shown over the stairs. 1: a single way, as in the old days.
## Floors before a boss always have one way.
@export_range(1, 3) var route_count: int = 2
## Chance that the second way gets a curse or an event when it rolled none, so the choice is
## often between a calm way and a bold one.
@export_range(0.0, 1.0) var route_twist_chance: float = 0.6

@export_group("Secret rooms")
## Chance for a normal floor to hide a small room behind a cracked wall (SecretRoomPlan): any
## hit or blast breaks the crack and opens it. Rolled `secret_rooms_max` times (at most one
## room per roll), `secret_rooms_big` times on floors of `secret_big_floor_rooms` rooms or more.
@export_range(0.0, 1.0) var secret_room_chance: float = 0.5
@export_range(0, 4) var secret_rooms_max: int = 1
@export_range(0, 4) var secret_rooms_big: int = 2
## 0: never a second roll.
@export_range(0, 60) var secret_big_floor_rooms: int = 20
## The hidden room's size and the passage through the rock to it (length at least
## DungeonGenerator.MIN_WALL_THICKNESS; width: the crack's width in cells).
@export var secret_room_size: Vector2i = Vector2i(7, 5)
@export_range(3, 8) var secret_passage_length: int = 3
@export_range(1, 3) var secret_passage_width: int = 1
## The crack on the cliff face (a PropDef: its hits, sound, debris color; see CrackedWall).
@export var cracked_wall: PropDef
## What a secret room may hold (weights, min_depth). See SecretRewardDef.
@export var secret_rewards: Array[SecretRewardDef] = []
## A faint whisper from the crack when the hero is close (played now and then).
@export var secret_whisper: AudioStream
## The hidden floor between two acts, reached with its key (null: none).
@export var hidden_floor: HiddenFloorDef

@export_group("The bottom")
## The true last floor, below the last act's boss once the profile has won (null: the last
## act's boss always ends the run). See FinaleDef.
@export var finale: FinaleDef

@export_group("The Deeps")
## Where a fall into a floor's hole takes the hero (null: he climbs back out, hurt).
@export var abyss: AbyssDef

@export_group("Encounters")
## Encounters per floor (springs, altars...), from content_db.tres > Encounters.
@export_range(0, 6) var encounters_min: int = 0
@export_range(0, 6) var encounters_max: int = 2
## Cells kept clear around an encounter: no chest, prop, hazard or other encounter that close
## (each encounter also gets a room of its own), so a spring or an altar never sits against
## another object.
@export_range(1, 4) var encounter_clearance: int = 2

@export_group("Pacts")
## Chance for a normal floor (never the first, never a boss floor) to try for a pact door: a
## dead-end room sealed behind a marked door, with a hard rule for its fight (PactRoom). It
## also needs a dead-end room nobody else took (about half the floors have one): at 0.7,
## about a third of the floors get a pact door.
@export_range(0.0, 1.0) var pact_chance: float = 0.7
## The pacts a door may hold (`min_depth`, `spawn_weight`).
@export var pacts: Array[PactDef] = []
## Lights either side of a pact door, inside the room (candles).
@export var pact_light: PropDef

@export_group("Room trials")
## Chance for a normal floor with no other event (no curse, no floor event; never the first,
## never a boss floor) to hold a room trial (RoomTrial: the Souls of Kagari, the Unbound Seal):
## one thing of its own per floor. A floor with a trial has no pact door.
@export_range(0.0, 1.0) var trial_chance: float = 0.45
## The trials a floor may hold (`min_depth`, `spawn_weight`).
@export var trials: Array[TrialDef] = []

@export_group("Merchant")
## Chance for a floor to have the merchant (never on boss floors).
@export_range(0.0, 1.0) var merchant_chance: float = 0.55
@export var merchant: ShopDef

@export_group("Forge and runes")
## Chance for a floor to have the smith's forge (never on boss floors), plus this much for
## every floor since the last one (so it never stays away too long).
@export_range(0.0, 1.0) var forge_chance: float = 0.3
@export_range(0.0, 1.0) var forge_chance_growth: float = 0.15
@export var forge: ForgeDef
## Chance for a monster to drop a rune: plain ones, and elites and up (MonsterRankDef).
@export_range(0.0, 1.0) var rune_chance: float = 0.01
@export_range(0.0, 1.0) var ranked_rune_chance: float = 0.3
## Runes a slain boss always drops.
@export var boss_runes: int = 1
## Chance for an opened chest to hold a rune too.
@export_range(0.0, 1.0) var chest_rune_chance: float = 0.2

@export_group("Elites")
## Chance for a monster to be an elite on the first floor, and more per floor below.
@export_range(0.0, 1.0) var elite_chance: float = 0.04
@export_range(0.0, 1.0) var elite_chance_per_depth: float = 0.015
## What an elite is (one affix, tougher, better loot: MonsterRankDef).
@export var elite_rank: MonsterRankDef
## Rarer ranks, rarest first (Shiny, Legendary, Epic): each rolled with its own chance before
## the elite one. Bosses roll them too (MonsterRankDef.boss_chance).
@export var rare_ranks: Array[MonsterRankDef] = []

@export_group("Bosses")
## Size of the arena room, in cells (when there is no ArenaDef to pick).
@export var arena_size: Vector2i = Vector2i(21, 15)
## Arenas the bosses fight in (shapes, pillars, changes by phase), one picked per boss floor.
@export var arenas: Array[ArenaDef] = []
## A heal before every boss (decision 0012): this spring stands by where the hero arrives on a
## boss floor (and the hidden floor, and the bottom of the Well), on every difficulty.
@export var boss_spring: EncounterDef

@export_group("Sustain")
## How much the hero heals from hits, kills and skills (Leech, Vampirism, the Blood family...):
## one budget for all of them, per second of max health (see SustainRules). Null: no limit.
@export var sustain: SustainRules
## A skill's chance to be ready again at once (SkillEchoPassive: the Echo perk, Echo runes, of
## Echoes) counts every source together and stops at this: stacking echoes reaches a cap like
## cooldown reduction does (CombatRulesDef.max_cooldown_reduction), instead of skipping one cooldown in
## three on top of it. 1 = no cap.
@export_range(0.0, 1.0, 0.01) var skill_echo_max_chance: float = 1.0

@export_group("Difficulty")
## Monster HP grows by this fraction per depth (0.15 = +15% per floor). Not bosses (below).
@export var monster_hp_scale_per_depth: float = 0.15
## Attack added per depth below the first (rounded). Not bosses (below).
@export var monster_attack_per_depth: float = 1.0
## The same for bosses: they are tuned one by one (BossDef), so they keep their own scaling.
@export var boss_hp_scale_per_depth: float = 0.15
@export var boss_attack_per_depth: float = 1.0


## Chance for a monster spawned at `depth` to be an elite, before the difficulty.
func elite_chance_at(depth: int) -> float:
	return elite_chance + elite_chance_per_depth * (depth - 1)


## Gold dropped by a monster at `depth` (`multiplier`: elites, bosses).
func gold_for_kill(depth: int, multiplier: float, rng: RandomNumberGenerator) -> int:
	var base := rng.randi_range(gold_per_kill.x, gold_per_kill.y) + gold_per_depth * (depth - 1)
	return roundi(base * multiplier)


## Souls for a run: monsters, depth reached, bosses, winning, times the difficulty (`multiplier`).
func souls_for_run(kills: int, depth: int, bosses: int, won: bool, multiplier: float = 1.0) -> int:
	var earned := kills * souls_per_kill + (depth - 1) * souls_per_floor + bosses * souls_per_boss + (souls_for_victory if won else 0)
	return roundi(earned * multiplier)


## Floors in one pass through every act.
func total_floors() -> int:
	var total := 0
	for act in acts:
		total += act.floors
	return total


## Index in `acts` of the act holding `depth` (looping after the last one).
func act_index(depth: int) -> int:
	if acts.is_empty():
		return -1
	var floor_number := (depth - 1) % maxi(total_floors(), 1)
	for i in acts.size():
		if floor_number < acts[i].floors:
			return i
		floor_number -= acts[i].floors
	return acts.size() - 1


## The first floor of act `index` (1 for the first act).
func first_depth(index: int) -> int:
	var depth := 1
	for i in mini(index, acts.size()):
		depth += acts[i].floors
	return depth


func act_for_depth(depth: int) -> ActDef:
	var index := act_index(depth)
	return acts[index] if index >= 0 else null


## 1 for the first floor of an act.
func floor_in_act(depth: int) -> int:
	var floor_number := (depth - 1) % maxi(total_floors(), 1)
	for act in acts:
		if floor_number < act.floors:
			return floor_number + 1
		floor_number -= act.floors
	return 1


## The boss guarding `depth` (the last floor of each act), or null on a normal floor.
func boss_for_depth(depth: int) -> BossDef:
	var act := act_for_depth(depth)
	if act == null or floor_in_act(depth) != act.floors:
		return null
	return act.boss


## The floor whose boss ends the run.
func is_final_floor(depth: int) -> bool:
	return depth == total_floors()
