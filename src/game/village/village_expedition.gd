class_name VillageExpedition
extends Node
## Adds accepted village evidence without consuming the dungeon's random stream or save ledger.
## Profile state is authoritative: an uncollected object reappears on resume, a collected one
## does not. Daily, hidden and debug floors never gain village objects.

const VILLAGE := preload("res://data/village/kagari.tres")
var game: Game


func _ready() -> void:
	Events.floor_entered.connect(_on_floor)


func _on_floor(world: World) -> void:
	if game == null or world != game.world or game.run.is_daily() or DebugCheats.debug_run \
			or game.run.hidden_floor or game.run.finale:
		return
	for quest in VILLAGE.quests:
		if game.depth != quest.floor_depth or VillageProgress.stage(quest) != VillageProgress.Step.ACCEPTED:
			continue
		# Deterministic scan, away from the entrance. Native props/holes already exist here.
		for room_index in range(world.map.rooms.size() - 1, 0, -1):
			var room := world.map.rooms[room_index]
			var placed := false
			for y in range(room.position.y + 1, room.end.y - 1):
				for x in range(room.position.x + 1, room.end.x - 1):
					var cell := Vector2i(x, y)
					if not world.is_free_cell(cell) or world.has_pit(cell):
						continue
					var evidence := VillageEvidence.new()
					evidence.quest = quest
					evidence.position = world.map.cell_to_world(cell)
					world.add_entity(evidence)
					Events.log_message(tr(quest.objective), Palette.GOLD)
					placed = true
					break
				if placed:
					break
			if placed:
				break
