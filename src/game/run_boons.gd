class_name RunBoons
extends RefCounted
## The rules a run gets from the Tree of Souls (UpgradeDef kind RULES) and its oath (OathDef),
## gathered once at the start of the run (and again when a saved run comes back). The World and
## the hero read them: gold, loot, the merchant, healing, crits, the minimap.

var gold_scale := 1.0
var loot_quality_scale := 1.0
var shop_price_scale := 1.0
var shop_extra_items := 0
var healing_scale := 1.0
var heal_on_clear := 0.0
var elite_magic_drop := false
var cartographer := false
var crit_damage_bonus := 0.0
var oath: OathDef


static func build(content: ContentDB, sworn: OathDef = null) -> RunBoons:
	var boons := RunBoons.new()
	for upgrade in content.upgrades:
		var level := Profile.level_of(upgrade)
		if level <= 0 or upgrade.kind != UpgradeDef.Kind.RULES:
			continue
		# Flat, whatever the level (as max_hp_scale in ShrineUpgrades): a trade-off bought once
		# (Blood Pact has one level; the unit tests keep it so). The others grow with the level.
		boons.healing_scale *= upgrade.healing_scale
		boons.heal_on_clear += upgrade.heal_on_clear * level
		boons.shop_price_scale *= pow(upgrade.shop_price_scale, level)
		boons.shop_extra_items += upgrade.shop_extra_items * level
		boons.elite_magic_drop = boons.elite_magic_drop or upgrade.elite_magic_drop
		boons.cartographer = boons.cartographer or upgrade.cartographer
	if sworn:
		boons.oath = sworn
		boons.gold_scale *= sworn.gold_scale
		boons.loot_quality_scale *= sworn.loot_quality_scale
		boons.shop_price_scale *= sworn.shop_price_scale
		boons.crit_damage_bonus += sworn.crit_damage_bonus
		boons.healing_scale *= sworn.healing_scale
	return boons
