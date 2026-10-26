class_name PerkTrait
extends MonsterTrait
## Born with perks, as the hero earns them and as an elite gets its affix's: a Blood Drinker drinks
## from every wound it gives (the Vampiric affix's lifesteal). The perks work as they do anywhere
## (PerkSet on the actor); `text` says it in the bestiary.

@export var perks: Array[PerkDef] = []
## A line for the bestiary (plain rule words).
@export var text: String


func on_spawn(monster: Monster) -> void:
	for perk in perks:
		if perk:
			monster.perks.add(perk)


func describe() -> String:
	return tr(text) if not text.is_empty() else ""
