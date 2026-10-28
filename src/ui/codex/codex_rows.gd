class_name CodexRows
## The building blocks of the codex's lists, in the game's skin (UiSkin): a quest, an
## achievement, a finished run, plus the small pieces they share (a progress bar, a done mark,
## "+25 souls"). Every number comes with what it means, for players new to roguelikes.

## Souls: the soft blue of the soul wisps (kept between runs, spent at the Shrine).
const SOUL := Color(0.65, 0.95, 1.0)
const DONE := Palette.HEAL
## The widths of a run's fact columns.
const RUN_COLUMNS := [190.0, 290.0, 170.0]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]  # i18n


static func souls(amount: int) -> String:
	return TranslationServer.tr("+%d souls") % amount


## A bar with its numbers written on it ("12 / 40"), gold while running, green once full.
static func bar(value: float, max_value: float, text: String, height := 22.0, font_size := Fonts.BODY) -> StatBar:
	var result := StatBar.new()
	result.custom_minimum_size = Vector2(0, height)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	result.font_size = font_size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.fill_color = DONE if value >= max_value else Palette.GOLD
	result.set_values(value, max_value, text)
	return result


## A little box, ticked when `done`: the same mark for quests, ranks, challenges, achievements.
## `center`: in the middle of its row's height (else at the top, by a first line of text).
static func check(done: bool, center := true) -> Control:
	var mark := Control.new()
	mark.custom_minimum_size = Vector2(24, 24)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER if center else Control.SIZE_SHRINK_BEGIN
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(func() -> void:
		var box := Rect2(Vector2(2, 2), Vector2(20, 20))
		mark.draw_rect(box.grow(2), Color(0.12, 0.07, 0.05))
		mark.draw_rect(box, Color(0.3, 0.2, 0.14) if not done else Color(0.16, 0.34, 0.18))
		if done:
			var points := PackedVector2Array([Vector2(6, 12), Vector2(10, 16), Vector2(18, 7)])
			mark.draw_polyline(points, DONE, 3.0))
	return mark


## A row of a list: a slightly darker band on the inset, so rows read apart.
static func row_box() -> PanelContainer:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.02, 0.32)
	style.border_color = Color(1.0, 0.85, 0.6, 0.08)
	style.set_border_width_all(1)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	box.add_theme_stylebox_override("panel", style)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return box


## "Label  value": a dim name and its value, on one line.
static func fact(name: String, value: String, value_color: Color = UiSkin.TEXT) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	var label := UiSkin.label(name, Fonts.BODY, UiSkin.DIM)
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(label)
	line.add_child(_value_label(value, value_color))
	return line


## A fact of a past run: its name over its value, so the value has the column's whole width and
## lines up with its name whatever its length ("Difficulty" over "Keeper").
static func stacked_fact(name: String, value: String, value_color: Color = UiSkin.TEXT) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 0)
	cell.add_child(UiSkin.label(name, Fonts.BODY, UiSkin.DIM))
	cell.add_child(_value_label(value, value_color))
	return cell


## A fact's value: wraps between words only (never inside one: "Veille" / "ur"), top-aligned
## with its name.
static func _value_label(value: String, value_color: Color) -> Label:
	var label := UiSkin.label(value, Fonts.BODY, value_color, true)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return label


## An icon at a whole-pixel scale.
static func icon(texture: Texture2D, side: float, faded := false) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.custom_minimum_size = Vector2(side, side)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if faded:
		picture.modulate = Color(0.4, 0.38, 0.42)
	return picture


# --- Quests -----------------------------------------------------------------------

## A quest: its goal, how far along you are, the souls it pays (and whether they were paid).
static func quest_row(quest: Dictionary) -> Control:
	var done := QuestBoard.is_done(quest)
	var box := row_box()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	row.add_child(check(done))
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 4)
	row.add_child(middle)
	middle.add_child(UiSkin.label(QuestBoard.text(quest), Fonts.BODY, DONE if done else UiSkin.TEXT, true))
	var progress := QuestBoard.progress(quest)
	var target := int(quest.target)
	middle.add_child(bar(progress, target, TranslationServer.tr("Done!") if done else "%d / %d" % [progress, target]))
	var reward := VBoxContainer.new()
	reward.custom_minimum_size.x = 118
	reward.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(reward)
	var amount := UiSkin.label(souls(int(quest.reward)), Fonts.BODY, SOUL)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward.add_child(amount)
	var status := UiSkin.label(TranslationServer.tr("Received") if done else TranslationServer.tr("Reward"), Fonts.BODY, DONE if done else UiSkin.DIM)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward.add_child(status)
	return box


# --- Achievements -------------------------------------------------------------------

## An achievement: its icon, name, goal, a progress bar and the souls it pays.
static func achievement_row(achievement: AchievementDef) -> Control:
	var unlocked := achievement.is_unlocked()
	var box := row_box()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	row.add_child(icon(achievement.icon, 44, not unlocked))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var hidden := achievement.secret and not unlocked
	text.add_child(UiSkin.label("???" if hidden else TranslationServer.tr(achievement.display_name), Fonts.BODY, UiSkin.GOLD if unlocked else UiSkin.TEXT))
	text.add_child(UiSkin.label(TranslationServer.tr("A secret feat. Some doors only open from the other side.") if hidden else TranslationServer.tr(achievement.description), Fonts.BODY, UiSkin.DIM, true))
	var progress := achievement.target if unlocked else achievement.progress()
	var meter := bar(progress, achievement.target, TranslationServer.tr("Done!") if unlocked else "%d / %d" % [progress, achievement.target])
	meter.custom_minimum_size.x = 240
	meter.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(meter)
	var reward := VBoxContainer.new()
	reward.custom_minimum_size.x = 118
	reward.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(reward)
	var amount := UiSkin.label(souls(achievement.reward_souls), Fonts.BODY, SOUL)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward.add_child(amount)
	var status := UiSkin.label(TranslationServer.tr("Received") if unlocked else TranslationServer.tr("Reward"), Fonts.BODY, DONE if unlocked else UiSkin.DIM)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward.add_child(status)
	return box


# --- Runs -----------------------------------------------------------------------------

## A finished run (Profile.history): how it ended, then when, how hard, how far, how long...
static func run_row(entry: Dictionary, content: ContentDB) -> Control:
	var won := bool(entry.get("won", false))
	var cause := TranslationServer.tr(str(entry.get("cause", "")))
	var depth := int(entry.get("depth", 1))
	var box := row_box()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	var ending := VBoxContainer.new()
	ending.custom_minimum_size.x = 240
	ending.alignment = BoxContainer.ALIGNMENT_CENTER
	ending.add_theme_constant_override("separation", 0)
	row.add_child(ending)
	var headline := TranslationServer.tr("Victory achieved") if won else TranslationServer.tr("Died on floor %d") % depth
	ending.add_child(UiSkin.label(headline, Fonts.BODY, DONE if won else Palette.DANGER))
	var how := TranslationServer.tr("Reached the bottom of the Well")
	if won and not cause.is_empty():
		how = TranslationServer.tr("Won, then slain by %s") % cause
	elif not won:
		how = TranslationServer.tr("Slain by %s") % (cause if not cause.is_empty() else "?")
	ending.add_child(UiSkin.label(how, Fonts.BODY, UiSkin.TEXT, true))
	# Three columns of facts (each its name over its value), the same widths on every row so they
	# line up.
	var facts := GridContainer.new()
	facts.columns = 3
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.add_theme_constant_override("h_separation", 20)
	facts.add_theme_constant_override("v_separation", 6)
	row.add_child(facts)
	var bosses := int(entry.get("bosses", 0))
	var cells := [
		stacked_fact(TranslationServer.tr("Difficulty"), DifficultyDef.named(str(entry.get("difficulty", "?")), int(entry.get("ascension", 0)))),
		stacked_fact(TranslationServer.tr("Reached"), depth_text(depth, content)),
		stacked_fact(TranslationServer.tr("Time"), TimeText.of(int(entry.duration) / 1000.0, 0) if entry.has("duration") else "-"),
		stacked_fact(TranslationServer.tr("When"), date_text(int(entry.get("time", 0)))),
		stacked_fact(TranslationServer.tr("Slain"), (TranslationServer.tr("%d monsters, %d boss") if bosses == 1 else TranslationServer.tr("%d monsters, %d bosses")) % [int(entry.get("kills", 0)), bosses]),
		stacked_fact(TranslationServer.tr("Earned"), souls(int(entry.get("souls", 0))), SOUL),
		stacked_fact(TranslationServer.tr("Hero level"), str(int(entry.get("level", 1)))),
		stacked_fact(TranslationServer.tr("Weapon"), TranslationServer.tr(str(entry.get("weapon", "?")))),
	]
	for i in cells.size():
		(cells[i] as Control).custom_minimum_size.x = RUN_COLUMNS[i % RUN_COLUMNS.size()]
		facts.add_child(cells[i])
	return box


## "Oct 20, 14:33" in the player's time zone ("-" when unknown).
static func date_text(unix: int) -> String:
	if unix <= 0:
		return "-"
	var local := unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var date := Time.get_datetime_dict_from_unix_time(local)
	return TranslationServer.tr("{month} {day}, {time}").format({
		"month": TranslationServer.tr(MONTHS[int(date.month) - 1]), "day": int(date.day),
		"time": "%02d:%02d" % [int(date.hour), int(date.minute)] })


## "floor 5 of 12", or "floor 15 (endless)" past the last one.
static func depth_text(depth: int, content: ContentDB) -> String:
	var total := content.dungeon.total_floors() if content and content.dungeon else 0
	if total <= 0:
		return TranslationServer.tr("floor %d") % depth
	if depth > total:
		return TranslationServer.tr("floor %d (endless)") % depth
	return TranslationServer.tr("floor %d of %d") % [depth, total]
