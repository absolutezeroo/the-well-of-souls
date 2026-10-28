class_name SkillDef
extends Resource
## An active ability on a cooldown. Usable by the player and by monsters.
## A skill is just a list of effects, so new skills rarely need new code.

## Stable save key override for historical ids shared by player and monster skills.
## Empty uses id; never change a released save_id.
@export var save_id: StringName
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Very short text drawn on the skill button.
@export var short_label: String = "SK"
@export var icon: Texture2D
@export var color: Color = Color.WHITE
@export var cooldown: float = 6.0
@export var effects: Array[Effect] = []
@export var sound: AudioStream

@export_group("Monster AI")
## Monsters only use the skill when their target is between these distances.
@export var ai_min_range: float = 0.0
@export var ai_max_range: float = 240.0
## Monsters only use the skill below this fraction of their HP (1 = any time).
@export_range(0.0, 1.0) var ai_below_hp_ratio: float = 1.0
## Supports: only when an ally (not the caster) within `ai_ally_radius` is hurt below
## `ai_ally_hurt_ratio` of its HP (heals), or when at least one ally is there (buffs, wards).
enum AllyNeed { NONE, HURT_ALLY, ALLY_NEAR }
@export var ai_ally_need: AllyNeed = AllyNeed.NONE
@export var ai_ally_radius: float = 220.0
@export_range(0.0, 1.0) var ai_ally_hurt_ratio: float = 0.7
## Monsters: telegraph time before the skill goes off (glow, cast animation). 0 = instant.
@export var cast_time: float = 0.0
## Monsters: red circle drawn around the caster while casting (0 = none).
@export var telegraph_radius: float = 0.0
## Monsters: the body's animation while casting (a swordsman drawing his blade: "windup"),
## fitted to the cast time. Without it in the monster's frames: "cast", else the attack pose.
@export var cast_animation: StringName = &"cast"


## Its shots dressed in what the hero's weapon carries, per list of elements (`effects_for`).
var _dressed := {}


## One of its effects hurts (Effect.hurts()): a monster's cast of it is a wind-up the fairness
## contract holds to its floor (docs/decisions/0008).
func hurts() -> bool:
	for effect in effects:
		if effect and effect.hurts():
			return true
	return false


## How long a monster's cast of it lasts: `cast_time` times `scale` (the difficulty's, an
## ascension's and a boss's phases' multipliers: Monster.get_telegraph_scale()), never under the
## fairness floor of a monster's attack (`boss`: a boss's) when it hurts, even one written instant
## (CombatRulesDef.monster_windup()); one that hurts no one (a summon, a heal, a step) keeps its
## own, 0 for instant.
func monster_cast_time(scale: float, boss: bool) -> float:
	var seconds := cast_time * scale
	return Combat.RULES.monster_windup(seconds, boss) if hurts() else seconds


func activate(user: Actor, aim: Vector2) -> void:
	Sfx.play_at(sound, user.global_position)
	Effect.apply_all(effects_for(user), user, aim)


## Its effects as `user` casts it. A skill of the hero's weapon (Volley on a bow, Ice Shards on a
## staff) shoots in the elements of the runes and affixes set in it, as his basic shots do
## (docs/vfx.md "Elemental attacks"): Volley's arrows ride an Ember Rune's flames, a frost shard
## carries them on its back; what is no shot too (Cleave's arc burns, Arrow Rain's area falls in
## flames, a Frost Nova has licks of fire among its crystals). Only the elements that act on a skill's hits (`ItemLook.
## passive_elements`: runes and affixes work like perks; the weapon's `on_hit` doesn't reach
## skills), and only the look: each hit lands in an element when its own rules say so.
## Copies, made once per list of elements (the data stays as written).
func effects_for(user: Actor) -> Array[Effect]:
	var weapon := user.get_weapon() if user is Player else null
	if weapon == null or not weapon.skills.has(self):
		return effects
	var carried := ItemLook.passive_elements(weapon)
	if carried.is_empty():
		return effects
	if not _dressed.has(carried):
		var copies: Array[Effect] = []
		for effect in effects:
			copies.append(effect.dressed_for_skill(carried) if effect else effect)
		_dressed[carried] = copies
	return _dressed[carried]
