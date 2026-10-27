class_name OathDef
extends Resource
## An oath: a way to start a run, sworn before it begins ("X, but Y"). Opened at the end of a
## branch of the Tree of Souls (SoulNodeDef.oath). Not in the daily run (everyone starts the same).

@export var id: StringName
@export var display_name: String
## The rule, in plain words: what you get and what it costs.
@export_multiline var description: String
## The vow itself, as a keeper of old swore it at the bell (docs/lore.md 6: each oath was a
## keeper's way): one solemn line in quotes, shown at the shrine above the rule. Never a rule.
@export_multiline var lore: String
@export var icon: Texture2D
@export var color: Color = Color.WHITE
## The weapon the run starts with (null: the usual one).
@export var starting_weapon: WeaponDef

@export_group("The hero")
## Added to the hero's starting stats.
@export var bonuses: StatBlock
## Multiplies the hero's starting max Health and move speed.
@export var max_hp_scale: float = 1.0
@export var move_speed_scale: float = 1.0
## Added to the critical hit multiplier (CombatRulesDef.crit_multiplier, x1.75 + this).
@export var crit_damage_bonus: float = 0.0

@export_group("The run")
@export var gold_scale: float = 1.0
@export var loot_quality_scale: float = 1.0
@export var shop_price_scale: float = 1.0


## What it changes, one line each, in plain words: [text, +1 a gain / -1 a cost / 0 neither].
## Built from its numbers, so the cards can't drift from the rules: gains in green, costs in red.
func effects() -> Array:
	var lines := []
	if starting_weapon:
		lines.append([tr("Starts with the %s") % tr(starting_weapon.display_name), 0])
	_percent(lines, max_hp_scale, tr("%+d%% max Health"), 1)
	_percent(lines, move_speed_scale, tr("%+d%% move speed"), 1)
	if bonuses:
		if bonuses.crit_chance != 0.0:
			lines.append([tr("%+d%% critical hit chance") % roundi(bonuses.crit_chance * 100.0), signi(roundi(bonuses.crit_chance * 100.0))])
		if bonuses.skill_power != 0.0:
			lines.append([tr("%+d%% skill damage") % roundi(bonuses.skill_power * 100.0), signi(roundi(bonuses.skill_power * 100.0))])
		if bonuses.attack_speed != 0.0:
			lines.append([tr("%+d%% attack speed") % roundi(bonuses.attack_speed * 100.0), signi(roundi(bonuses.attack_speed * 100.0))])
		if bonuses.max_hp != 0:
			lines.append([tr("%+d max Health") % bonuses.max_hp, signi(bonuses.max_hp)])
		if bonuses.attack != 0:
			lines.append([tr("%+d Damage") % bonuses.attack, signi(bonuses.attack)])
		if bonuses.defense != 0:
			lines.append([tr("%+d Armor") % bonuses.defense, signi(bonuses.defense)])
	if crit_damage_bonus != 0.0:
		var multiplier := Combat.RULES.crit_multiplier + crit_damage_bonus
		lines.append([tr("Critical hits deal x%s (instead of x%s)") % [_number(multiplier), _number(Combat.RULES.crit_multiplier)], signi(roundi(crit_damage_bonus * 100.0))])
	_percent(lines, gold_scale, tr("%+d%% gold"), 1)
	_percent(lines, loot_quality_scale, tr("%+d%% chance of better gear"), 1)
	_percent(lines, shop_price_scale, tr("Merchant prices %+d%%"), -1)
	return lines


## "+30% max Health" when `factor` isn't 1; `helps` +1 when more of it is good for the hero.
static func _percent(lines: Array, factor: float, words: String, helps: int) -> void:
	var change := roundi((factor - 1.0) * 100.0)
	if change != 0:
		lines.append([words % change, helps * signi(change)])


static func _number(value: float) -> String:
	return ("%.2f" % value).rstrip("0").rstrip(".")
