class_name VillageQuestRows
extends RefCounted
## Read-only village journal, shared by the title, surface board and dungeon pause codex.

const ORDER := [VillageProgress.Step.FOUND, VillageProgress.Step.ACCEPTED, VillageProgress.Step.AVAILABLE, VillageProgress.Step.RETURNED]


static func fill(parent: VBoxContainer, village: VillageDef) -> void:
	parent.add_child(UiSkin.label(TranslationServer.tr("Kagari's requests"), Fonts.TITLE, UiSkin.GOLD))
	for stage: int in ORDER:
		for quest in village.quests:
			if VillageProgress.stage(quest) != stage: continue
			var box := CodexRows.row_box()
			var column := VBoxContainer.new()
			column.add_theme_constant_override("separation", 6)
			box.add_child(column)
			parent.add_child(box)
			column.add_child(UiSkin.label(TranslationServer.tr(quest.title), Fonts.BODY, UiSkin.GOLD))
			var status := ""
			match stage:
				VillageProgress.Step.AVAILABLE:
					var locked := quest.requires_quest and VillageProgress.stage(quest.requires_quest) != VillageProgress.Step.RETURNED
					status = TranslationServer.tr(quest.locked_text) if locked else TranslationServer.tr("Available — speak to the resident")
				VillageProgress.Step.ACCEPTED: status = TranslationServer.tr("In progress")
				VillageProgress.Step.FOUND: status = TranslationServer.tr("Ready to return")
				VillageProgress.Step.RETURNED: status = TranslationServer.tr("Completed — reward received")
			column.add_child(UiSkin.label(status, Fonts.BODY, UiSkin.TEXT, true))
			var objective := quest.objective
			if stage == VillageProgress.Step.FOUND: objective = quest.return_text
			if stage == VillageProgress.Step.RETURNED: objective = quest.done_line
			column.add_child(UiSkin.label(TranslationServer.tr(objective), Fonts.BODY, UiSkin.DIM, true))
			if stage != VillageProgress.Step.RETURNED:
				column.add_child(UiSkin.label(TranslationServer.tr(quest.reward_text) % quest.reward_souls, Fonts.BODY, UiSkin.GOLD, true))
			for resident in village.residents:
				if resident.role != VillageResidentDef.Role.QUEST or resident.quest != quest: continue
				column.add_child(UiSkin.label(TranslationServer.tr("Speak to %s in Kagari.") % TranslationServer.tr(resident.speaker.display_name), Fonts.BODY, UiSkin.TEXT, true))
				var activity := resident.activity_at(VillageClock.hour(village.clock))
				var echo := resident.echo and (resident.wakes_after == null or VillageProgress.stage(resident.wakes_after) != VillageProgress.Step.RETURNED)
				if activity and not echo:
					column.add_child(UiSkin.label(TranslationServer.tr("Schedule: %s") % TranslationServer.tr(activity.display_name), Fonts.BODY, UiSkin.DIM, true))
