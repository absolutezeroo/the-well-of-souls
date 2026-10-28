class_name ChronicleRows
## A warden's chronicle in the codex (its page's Chronicle tab, MonsterPage): the chapters open
## in order with their lines, the locked ones as "???" with what opens them (plain words, or a
## deed's riddle until a fragment gives its rule away); what it says as it wakes and as it falls;
## its fragments, the found ones to read again (`read` is called with the fragment), the others
## as "???" with where they lie. Asks Narrative; decides nothing.

const LOCKED := Color(0.62, 0.58, 0.55)
const SPEECH := Color(0.78, 0.9, 1.0)


static func fill(column: VBoxContainer, boss: BossDef, content: ContentDB, read: Callable) -> void:
	if boss.chronicle == null:
		column.add_child(UiSkin.label(TranslationServer.tr("Its story is not known."), Fonts.BODY, UiSkin.DIM, true))
		return
	var chapters := Narrative.chapters(boss)
	var open := Narrative.open_chapters(boss)
	var fragments := Narrative.fragments(boss)
	column.add_child(UiSkin.label(TranslationServer.tr("Chapters %d of %d     Fragments %d of %d") % [open.size(), chapters.size(), Narrative.found_count(boss), fragments.size()], Fonts.BODY, UiSkin.GOLD, true))
	column.add_child(UiSkin.label(TranslationServer.tr("Each meeting tells the next open chapter before the fight. Slay it again, find its fragments and do what it asks of you to open the rest."), Fonts.BODY, UiSkin.DIM, true))
	for chapter in chapters:
		column.add_child(_chapter(chapter, boss))
	var lines := boss.chronicle.waking_lines.filter(func(line: WakingLine) -> bool: return line != null)
	if not lines.is_empty():
		column.add_child(_heading(TranslationServer.tr("Its words")))
		for line: WakingLine in lines:
			column.add_child(_speech(line, boss))
	var last := boss.chronicle.last_words.filter(func(line: WakingLine) -> bool: return line != null)
	if not last.is_empty():
		column.add_child(_heading(TranslationServer.tr("Its last words")))
		for line: WakingLine in last:
			column.add_child(_speech(line, boss))
	if not fragments.is_empty():
		column.add_child(_heading(TranslationServer.tr("Fragments")))
		var where := _where(boss, content)
		for fragment in fragments:
			column.add_child(_fragment(fragment, boss, where, read))
	# What it keeps of its own (the Nameless Keeper: the Keepers freed, with their weapon and day).
	var records := boss.records(content)
	if not boss.records_heading().is_empty() and not records.is_empty():
		column.add_child(_heading(TranslationServer.tr(boss.records_heading())))
		for line in records:
			column.add_child(UiSkin.label(line, Fonts.BODY, UiSkin.TEXT, true))


static func _chapter(chapter: ChronicleChapter, boss: BossDef) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	if chapter.is_open(boss):
		box.add_child(UiSkin.label(TranslationServer.tr(chapter.title), Fonts.BODY, UiSkin.GOLD, true))
		for line in chapter.lines:
			box.add_child(UiSkin.reading_label(TranslationServer.tr(line)))
	else:
		box.add_child(UiSkin.label("???", Fonts.BODY, LOCKED))
		for need in chapter.requirements(boss):
			box.add_child(UiSkin.label("-  " + need, Fonts.BODY, LOCKED, true))
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	box.add_child(gap)
	return box


static func _speech(line: WakingLine, boss: BossDef) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	if line.is_open(boss):
		box.add_child(UiSkin.reading_label(TranslationServer.tr("\"%s\"") % TranslationServer.tr(line.line), SPEECH))
	else:
		box.add_child(UiSkin.label(TranslationServer.tr("\"%s\"") % "???", Fonts.BODY, LOCKED))
		for need in ProgressCondition.describe_unmet(line.conditions, boss):
			box.add_child(UiSkin.label("-  " + need, Fonts.BODY, LOCKED, true))
	return box


static func _fragment(fragment: FragmentDef, boss: BossDef, where: String, read: Callable) -> Control:
	if Narrative.is_found(fragment):
		var button := Button.new()
		button.text = TranslationServer.tr(fragment.title)
		button.custom_minimum_size = Vector2(0, 44)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", Fonts.BODY)
		button.pressed.connect(func() -> void: read.call(fragment, boss))
		return button
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(UiSkin.label("???", Fonts.BODY, LOCKED))
	if not where.is_empty():
		box.add_child(UiSkin.label("-  " + where, Fonts.BODY, LOCKED, true))
	for need in ProgressCondition.describe_unmet(fragment.conditions, boss):
		box.add_child(UiSkin.label("-  " + need, Fonts.BODY, LOCKED, true))
	return box


## "Found on the floors of Act II": where its fragments lie.
static func _where(boss: BossDef, content: ContentDB) -> String:
	var acts := content.dungeon.acts
	var names := PackedStringArray()
	for i in acts.size():
		if acts[i].all_bosses().has(boss):
			names.append(TranslationServer.tr(acts[i].subtitle))
	var hidden := content.dungeon.hidden_floor
	if hidden and hidden.boss == boss:
		for i: int in hidden.key_acts:
			if i >= 0 and i < acts.size():
				names.append(TranslationServer.tr(acts[i].subtitle))
	var finale := content.dungeon.finale
	if finale and finale.boss and finale.boss.forms().has(boss) and not acts.is_empty():
		names.append(TranslationServer.tr(acts[acts.size() - 1].subtitle))  # (the way down to it)
	if names.is_empty():
		return ""
	return TranslationServer.tr("Found on the floors of %s") % TranslationServer.tr(", ").join(names)


static func _heading(text: String) -> Label:
	var label := UiSkin.label(text, Fonts.BODY, UiSkin.GOLD)
	label.custom_minimum_size.y = 28
	return label
