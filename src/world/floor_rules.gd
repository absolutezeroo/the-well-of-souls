class_name FloorRules
extends RefCounted
## How hard and how rewarding the current floor is: the run's difficulty (and ascension), the
## floor's event (Blood Moon, Treasure Vault...) and the depth, combined in one place.
## Built by World.build_floor(); everything that scales asks it instead of multiplying
## difficulty and event values by hand.

var depth := 1
var config: DungeonConfig
## Never null: a neutral difficulty when the run has none.
var difficulty: DifficultyDef
## Null on most floors.
var event: FloorEventDef
## Null on most floors.
var curse: CurseDef
## The run's boons (the Tree of Souls, an oath): what they add to drops and gold. Never null;
## the World keeps it its own (World.boons).
var boons := RunBoons.new()

static var _neutral := DifficultyDef.new()


static func make(floor_config: DungeonConfig, run_difficulty: DifficultyDef, floor_event: FloorEventDef, floor_depth: int, floor_curse: CurseDef = null) -> FloorRules:
	var rules := FloorRules.new()
	rules.config = floor_config
	rules.difficulty = run_difficulty if run_difficulty else _neutral
	rules.event = floor_event
	rules.curse = floor_curse
	rules.depth = floor_depth
	return rules


# --- Monsters ----------------------------------------------------------------

## Multiplies a monster's HP (after the depth scaling, see scale_monster()): the act's (not
## bosses), the difficulty's, the event's.
func monster_hp(is_boss: bool) -> float:
	var act := _act()
	var scale := difficulty.boss_hp if is_boss else difficulty.monster_hp
	return (act.monster_hp if act and not is_boss else 1.0) * scale * (event.monster_hp if event else 1.0)


## Multiplies a monster's attacks and skills: the act's (ActDef.monster_damage, not bosses), the
## difficulty's and the event's.
func monster_damage(is_boss: bool = false) -> float:
	var act := _act()
	return (act.monster_damage if act and not is_boss else 1.0) * floor_damage()


## The act this floor is in (null outside the acts' floors, or without a config).
func _act() -> ActDef:
	return config.act_for_depth(depth) if config else null


## Multiplies everything the floor deals: the difficulty's and the event's (monsters, traps,
## bursts, the cold).
func floor_damage() -> float:
	return difficulty.monster_damage * (event.monster_damage if event else 1.0)


func monster_speed() -> float:
	return difficulty.monster_speed


## Multiplies the warning time before monster attacks and skills.
func telegraph_time() -> float:
	return difficulty.telegraph_time


## Multiplies how far monsters spot the hero.
func detect_range() -> float:
	return difficulty.detect_range if difficulty else 1.0


## A monster's stats for this floor: grows with depth, then the difficulty and the event.
func scale_monster(base: StatBlock, is_boss: bool) -> StatBlock:
	var stats := base.duplicate() as StatBlock
	var levels := depth - 1
	var hp_scale := config.boss_hp_scale_per_depth if is_boss else config.monster_hp_scale_per_depth
	var attack_scale := config.boss_attack_per_depth if is_boss else config.monster_attack_per_depth
	stats.max_hp = roundi(stats.max_hp * (1.0 + hp_scale * levels) * monster_hp(is_boss))
	stats.attack += roundi(attack_scale * levels)
	stats.move_speed *= monster_speed()
	return stats


## Damage from the dungeon itself (a trap, quicksand, a blast, the cold): `base`, plus
## `per_depth` for each floor, times the floor's damage multiplier (not the monsters' own
## threat: ActDef.monster_damage is for their attacks).
func dungeon_damage(base: float, per_depth: float = 1.0) -> int:
	return maxi(1, roundi((base + depth * per_depth) * floor_damage()))


## Chance for a monster to come at a rare rank (Epic, Legendary, Shiny): its own chance at
## this depth, times the difficulty's taste for elites.
func rank_chance(rank: MonsterRankDef) -> float:
	return rank.chance_at(depth) * difficulty.elite_chance


func elite_chance() -> float:
	return config.elite_chance_at(depth) * difficulty.elite_chance + (event.elite_chance_bonus if event else 0.0)


## Extra monsters in each room of DungeonConfig.room_cells (and on top of the per-room cap).
func extra_monsters() -> int:
	return floori(config.extra_monsters_per_depth * (depth - 1)) + difficulty.extra_monsters


## A fight room's share of monsters (decision 0012): its open ground `cells` against
## DungeonConfig.room_cells, times the first floor's DungeonConfig.monsters_per_room plus the
## floor's extra ones; between monsters_per_room_min and max_monsters_per_room(), then the event's
## count. A share, not bodies: a tough monster takes DungeonConfig.tough_cost of it
## (FloorPopulator). `roll` in [0, 1) rounds the fraction up that often (the floor's dice: the same
## seed lays the same count).
func room_monsters(cells: int, roll: float) -> int:
	var share := float(cells) / maxf(config.room_cells, 1.0) * (config.monsters_per_room + extra_monsters())
	var count := clampi(floori(share + roll), config.monsters_per_room_min, max_monsters_per_room())
	return roundi(count * monster_count_scale())


func monster_count_scale() -> float:
	return event.monster_count if event else 1.0


## Monsters a room starts with at most (DungeonConfig.max_monsters_per_room), the difficulty's
## extra ones on top.
func max_monsters_per_room() -> int:
	return config.max_monsters_per_room + difficulty.extra_monsters


## Monsters per ambush wave: the dungeon's, one more every DungeonConfig.ambush_depths_per_extra
## floors.
func ambush_wave_size() -> int:
	return config.ambush_wave_size + floori(depth / config.ambush_depths_per_extra)


## Chance for a boss to come at a rare rank (`rank`'s own boss chance, times the difficulty's
## taste for elites: World.roll_boss_rank()).
func boss_rank_chance(rank: MonsterRankDef) -> float:
	return rank.boss_chance * difficulty.elite_chance


# --- Rewards -----------------------------------------------------------------

## Multiplies drop chances.
func loot_chance() -> float:
	return difficulty.loot_chance


## Multiplies the quality of what drops (see LootRoller): the floor's own, before the run's
## boons (drop_quality() has them).
func loot_quality() -> float:
	return (event.loot_quality if event else 1.0) * (curse.loot_quality if curse else 1.0) * (difficulty.loot_quality if difficulty else 1.0)


## The quality something of `quality` drops at on this floor (a crate 1, a boss
## DungeonConfig.boss_loot_quality...): the floor's loot quality, then the run's boons' (the
## Tree of Souls, an oath: RunBoons.loot_quality_scale). What every drop is rolled with, and what
## an encounter's odds are told with.
func drop_quality(quality: float = 1.0) -> float:
	return quality * loot_quality() * boons.loot_quality_scale


## Gold the floor itself gives for `amount` (its event, its curse), before the run's boons.
func gold(amount: float) -> int:
	return roundi(amount * (event.gold if event else 1.0) * (curse.gold if curse else 1.0))


## Gold that actually drops for `amount`: the floor's (gold()), then the run's boons' share
## (RunBoons.gold_scale). What a pile on the floor holds, and what an encounter says it gives.
func floor_gold(amount: float) -> int:
	return roundi(gold(amount) * boons.gold_scale)


func shop_prices() -> float:
	return difficulty.shop_prices


# --- Floor -------------------------------------------------------------------

## Multiplies the theme's ambient light color.
func light() -> Color:
	var color := Color.WHITE * difficulty.light
	if event:
		color *= event.light
	if curse:
		color *= curse.tint
	return Color(color, 1.0)


## The floor's light tint (World): light(), then the event's ambient tint.
func ambient_light() -> Color:
	var color := light()
	if event:
		color *= event.ambient_tint
	return color


## Body temperature change per second everywhere on the floor (see BodyTemperature).
func temperature_drift() -> float:
	return curse.temperature if curse else 0.0
