class_name ArchitectureTests
extends TestSuite
## Stable-reference migration and explicit service wiring; game suites exercise the
## extracted offer flow and world factories through their unchanged public entry points.


func run_unit() -> void:
	var catalog := RunSave.catalog()
	check(catalog.entries.size() > 250, "the save catalog covers the shipped content")
	for key in catalog.entries:
		var resource := catalog.entries[key]
		check(resource != null and RunSave.ref(resource) == "@" + key and RunSave.load_ref("@" + key) == resource,
			"stable content round trip: %s" % key)
	var sword: ItemDef = load("res://data/items/weapons/katana.tres")
	var old := {"version": 2, "player": {"inventory": [sword.resource_path]},
		"floor": {"later": [{"def": "res://data/monsters/rat.tres", "id": "rat", "at": [10, 20]}]}}
	var migrated := RunSave.parse(old)
	check(migrated.version == 3 and migrated.player.inventory[0] == RunSave.ref(sword)
		and migrated.floor.later[0].def == "@monster:rat", "version 2 migrates nested item and monster references to stable ids")
	check(old.version == 2 and old.player.inventory[0] == sword.resource_path, "migration never changes the caller's legacy data")
	var rolled := LootRoller.make(sword as EquipmentDef, ItemRarity.RARE, [CONTENT.item_affixes[0]], [CONTENT.runes[0]], 4)
	var saved: Dictionary = LootRoller.to_data(rolled)
	var restored := LootRoller.from_data(saved) as EquipmentDef
	check(str(saved.base).begins_with("@item:") and str(saved.affixes[0]).begins_with("@affix:")
		and str(saved.runes[0]).begins_with("@item:") and restored.base_item == sword and restored.item_level == 4
		and restored.affixes == rolled.affixes and restored.runes == rolled.runes, "rolled items preserve affixes, runes and level through stable ids")
	var relocated := ContentCatalog.new()
	var target := Resource.new()
	relocated.entries["item:kept"] = target
	relocated.legacy_paths["res://data/old_folder/deleted_name.tres"] = "item:kept"
	check(relocated.resolve("res://data/old_folder/deleted_name.tres") == target
		and relocated.resolve("@item:kept") == target, "a historical path resolves after its old file no longer exists")
	check(relocated.resolve("@item:removed") == null and relocated.resolve({}) == null
		and relocated.resolve("res://src/autoload/account.gd") == null, "unknown, malformed and non-content references never load arbitrary files")
	var player_volley := load("res://data/skills/player/volley.tres") as SkillDef
	var monster_volley := load("res://data/skills/monster/volley.tres") as SkillDef
	check(player_volley.id == monster_volley.id and RunSave.ref(player_volley) != RunSave.ref(monster_volley)
		and RunSave.load_ref(RunSave.ref(monster_volley)) == monster_volley, "historically shared skill ids have distinct stable references without changing gameplay ids")
	var connections := Privacy.changed.get_connections().size()
	OnlineLinks.bind()
	OnlineLinks.bind()
	check(Privacy.changed.get_connections().size() == connections
		and Privacy.changed.is_connected(Presence.reconcile_privacy)
		and Account.signed_out.is_connected(CloudSave.on_signed_out), "the explicit online composition is idempotent and retains consent/account subscriptions")
