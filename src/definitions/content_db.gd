class_name ContentDB
extends Resource
## Index of all game content. To add an item, perk, prop or elite affix, create its .tres
## and add it to the matching list in res://data/content_db.tres.
## Monsters and hazards (traps, holes...) are listed per act in the dungeon config (dungeon.acts).

@export var player: PlayerDef
@export var dungeon: DungeonConfig
@export var sounds: SoundBank
## The game's name, its story and the texts that tell it.
@export var story: StoryDef
## How the story is told around the fights: the wardens' cinematics, the fragments on the floors,
## the reveals' gate (the chronicles hang on each BossDef).
@export var narrative: NarrativeDef
## Items that can be found lying on the floor. Loot tables can also reference items not listed here.
@export var items: Array[ItemDef] = []
## Perks offered on level up (common) and after bosses (rare relics).
@export var perks: Array[PerkDef] = []
## The bestiary's hunter ranks and their rewards.
@export var bestiary: BestiaryRules
## Perk families and their bonuses (the codex lists them; perks point at theirs).
@export var synergies: Array[SynergyDef] = []
## Difficulties, easiest first (picked on the title screen).
@export var difficulties: Array[DifficultyDef] = []
## Used when nothing was picked yet (tests, first launch).
@export var default_difficulty: DifficultyDef
## Permanent upgrades sold at the shrine (title screen): every node's effect of the tree below.
@export var upgrades: Array[UpgradeDef] = []
## The shrine's Tree of Souls: where each upgrade sits, what opens it, the oaths.
@export var soul_tree: SoulTreeDef
## Items that only appear in the dungeon once a shrine upgrade unlocked them.
@export var locked_items: Array[ItemDef] = []
## Breakable props placed in rooms (lanterns are set in the dungeon config).
@export var props: Array[PropDef] = []
## What makes elite monsters special (Swift, Vampiric, Explosive...).
@export var elite_affixes: Array[EliteAffixDef] = []
## Special floors (haunted, treasure vault, swarm...).
@export var floor_events: Array[FloorEventDef] = []
## Whole-floor curses (frozen, burning, lightless...). See CurseDef.
@export var curses: Array[CurseDef] = []
## Nightmare +1, +2...: each level adds its twist (in order).
@export var ascensions: Array[AscensionDef] = []
## Goals across runs (they pay souls).
@export var achievements: Array[AchievementDef] = []
## Daily and weekly quests (QuestBoard draws a few of each from the date).
@export var quests: Array[QuestDef] = []
## What the hero wears for the look alone (the Wardrobe: auras...), in its order.
@export var cosmetics: Array[CosmeticDef] = []
## Springs, altars, spirits and statues met in rooms.
@export var encounters: Array[EncounterDef] = []
## Random bonuses on found equipment (Magic, Rare and Epic items).
@export var item_affixes: Array[ItemAffixDef] = []
## Rune stones (RuneDef): dropped by elites and bosses, found in chests, set at the forge.
@export var runes: Array[RuneDef] = []
## The first steps and the hints of the tutorial.
@export var tutorial: TutorialDef
## The first runs' gentle start: a sheltered first room, a slow first monster (decision 0010).
@export var first_steps: FirstStepsDef


## A monster of the act holding `depth`, by spawn weight, from its `min_depth` on.
func pick_monster(depth: int, rng: RandomNumberGenerator) -> MonsterDef:
	var act := dungeon.act_for_depth(depth)
	if act == null:
		return null
	return _pick(act.monsters, depth, rng) as MonsterDef


func get_difficulty(id: StringName) -> DifficultyDef:
	for difficulty in difficulties:
		if difficulty.id == id:
			return difficulty
	return default_difficulty


## Every monster of every act (bosses excluded).
func all_monsters() -> Array[MonsterDef]:
	var result: Array[MonsterDef] = []
	for act in dungeon.acts:
		for monster in act.monsters:
			if monster and not result.has(monster):
				result.append(monster)
	return result


## The Deeps' demons and their warden (AbyssDef): in no act's pool, never on a floor.
func abyss_monsters() -> Array[MonsterDef]:
	var result: Array[MonsterDef] = []
	var abyss := dungeon.abyss if dungeon else null
	if abyss == null:
		return result
	var kinds: Array[MonsterDef] = abyss.monsters.duplicate()
	kinds.append(abyss.warden)
	for monster in kinds:
		if monster and not result.has(monster):
			result.append(monster)
	return result


## Locked items unlocked for the current run (set by the game from the profile).
var unlocked_items: Array[ItemDef] = []


func pick_item(depth: int, rng: RandomNumberGenerator) -> ItemDef:
	return _pick(items.filter(is_available), depth, rng)


## A rune for `depth`, by spawn weight (null if none).
func pick_rune(depth: int, rng: RandomNumberGenerator) -> RuneDef:
	return _pick(runes, depth, rng) as RuneDef


func is_available(item: ItemDef) -> bool:
	return not locked_items.has(item) or unlocked_items.has(item)


func pick_prop(depth: int, rng: RandomNumberGenerator) -> PropDef:
	return _pick(props, depth, rng)


func pick_affix(depth: int, rng: RandomNumberGenerator) -> EliteAffixDef:
	return _pick(elite_affixes, depth, rng)


## Every hazard of every act.
func all_hazards() -> Array[HazardDef]:
	var result: Array[HazardDef] = []
	for act in dungeon.acts:
		for hazard in act.hazards:
			if hazard and not result.has(hazard):
				result.append(hazard)
	return result


## Up to `count` different perks of `rarity` that `owned` can still take.
## Tops up with perks of the other rarity when there are not enough.
## Never `left_out` ones (banished for the run, the cards on the table being rerolled...).
## `family_bias`: perks of a family `owned` has started but not woken weigh (1 + bias) times
## more per such family, so families come together.
func pick_perks(owned: PerkSet, count: int, rarity: PerkDef.Rarity, rng: RandomNumberGenerator, left_out: Array[PerkDef] = [], family_bias: float = 0.0) -> Array[PerkDef]:
	var result: Array[PerkDef] = []
	var started: Array[SynergyDef] = []
	for synergy in owned.families():
		if not owned.is_awake(synergy):
			started.append(synergy)
	for wanted_rarity in [rarity, PerkDef.Rarity.COMMON if rarity == PerkDef.Rarity.RARE else PerkDef.Rarity.RARE]:
		var candidates: Array = []
		var weights := PackedInt32Array()
		for perk in perks:
			if perk and perk.rarity == wanted_rarity and owned.can_take(perk) and not result.has(perk) and not left_out.has(perk):
				var shared := perk.synergies.filter(func(s: SynergyDef) -> bool: return started.has(s)).size()
				candidates.append(perk)
				weights.append(roundi(perk.weight * 10.0 * (1.0 + family_bias * shared)))
		while result.size() < count and not candidates.is_empty():
			var picked: PerkDef = RandomUtils.pick_weighted(candidates, weights, rng)
			if picked == null:
				break
			var index := candidates.find(picked)
			candidates.remove_at(index)
			weights.remove_at(index)
			result.append(picked)
	return result


## A ContentDef of `pool` allowed at `depth`, by spawn weight (null if none). `boost`: id ->
## a multiplier of that one's weight (a remote event's floor event: RemoteTuning.event_boost).
static func pick_from(pool: Array, depth: int, rng: RandomNumberGenerator, boost: Dictionary = {}) -> ContentDef:
	return _pick(pool, depth, rng, boost)


static func _pick(pool: Array, depth: int, rng: RandomNumberGenerator, boost: Dictionary = {}) -> ContentDef:
	var candidates: Array = []
	var weights := PackedInt32Array()
	for def: ContentDef in pool:
		if def != null and def.min_depth <= depth and def.spawn_weight > 0:
			candidates.append(def)
			weights.append(roundi(def.spawn_weight * float(boost.get(String(def.id), 1.0))) if not boost.is_empty() else def.spawn_weight)
	return RandomUtils.pick_weighted(candidates, weights, rng)


## The cosmetics of `slot`, in their Wardrobe order.
func cosmetics_of(slot: CosmeticDef.Slot) -> Array[CosmeticDef]:
	var result: Array[CosmeticDef] = []
	for cosmetic in cosmetics:
		if cosmetic and cosmetic.slot == slot:
			result.append(cosmetic)
	result.sort_custom(func(a: CosmeticDef, b: CosmeticDef) -> bool: return a.order < b.order)
	return result


## The cosmetic called `id`, or null.
func get_cosmetic(id: StringName) -> CosmeticDef:
	for cosmetic in cosmetics:
		if cosmetic and cosmetic.id == id:
			return cosmetic
	return null

