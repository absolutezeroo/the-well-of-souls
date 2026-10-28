class_name DifficultyCard
extends Button
## One difficulty in the difficulty window, in the game's skin: its name, a sentence, what
## changes in plain words ("Monster health +30%", "Bigger floors"...), helpful lines in green and
## harder ones in red, the souls it pays, and how to unlock it when locked. The last choice has a
## gold frame. Tap it to play.

const PADDING := 14

var difficulty: DifficultyDef

var _name: Label
var _tag: Label
var _description: Label
var _effects: VBoxContainer
var _souls: Label
var _footer: Label
var _selected := false


func _ready() -> void:
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	custom_minimum_size = Vector2(220, 300)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = false
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var box := UiSkin.inset()
		box.content_margin_left = PADDING
		box.content_margin_right = PADDING
		box.content_margin_top = PADDING
		box.content_margin_bottom = PADDING
		if state == "hover" or state == "hover_pressed":
			box.modulate_color = Color(1.25, 1.15, 1.0)
		elif state == "pressed":
			box.modulate_color = Color(1.4, 1.3, 1.1)
		add_theme_stylebox_override(state, box)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_build()


## `reference` (Normal) is what the floors' size is compared with.
func show_difficulty(def: DifficultyDef, unlocked: bool, selected: bool, reference: DifficultyDef = null) -> void:
	difficulty = def
	_selected = selected and unlocked
	_name.text = tr(def.display_name)
	_name.add_theme_color_override("font_color", def.color)
	_tag.text = tr("Your last choice") if _selected else (tr("Locked") if not unlocked else "")
	_tag.add_theme_color_override("font_color", UiSkin.GOLD if _selected else UiSkin.BAD)
	_tag.visible = not _tag.text.is_empty()
	_description.text = tr(def.description)
	for child in _effects.get_children():
		_effects.remove_child(child)
		child.queue_free()
	for effect: Array in effects(def, reference):
		var color: Color = UiSkin.TEXT
		if effect[1] > 0:
			color = UiSkin.GOOD
		elif effect[1] < 0:
			color = UiSkin.BAD
		_effects.add_child(UiSkin.label(effect[0], Fonts.SMALL, color, true))  # fine print: a long list
	_souls.text = tr("Souls earned x%s") % number(def.souls)
	# Fewer souls is a cost, more a reward: said in the same red and green as the rest.
	_souls.add_theme_color_override("font_color", UiSkin.BAD if def.souls < 0.99 else (UiSkin.GOOD if def.souls > 1.01 else MenuWindow.SOULS))
	if not unlocked:
		var by := tr(def.unlocked_by.display_name) if def.unlocked_by else "?"
		_footer.text = tr("To unlock: win a run on %s.") % by
		_footer.add_theme_color_override("font_color", UiSkin.GOLD)
	elif def.has_ascensions and Profile.ascension_unlocked <= 0:
		_footer.text = tr("A win opens Nightmare +1, +2...: harder, more souls.")
		_footer.add_theme_color_override("font_color", UiSkin.DIM)
	else:
		_footer.text = ""
	_footer.visible = not _footer.text.is_empty()
	disabled = not unlocked
	modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.6)
	queue_redraw()
	FitToContent.grow_later(self, get_child(0) as Control)


## What changes on `def`, in plain words: [text, +1 helps the hero / -1 harder / 0 neither].
## Floors are compared with `reference` (Normal), everything else with the game as made.
static func effects(def: DifficultyDef, reference: DifficultyDef = null) -> Array:
	var lines := []
	_percent(lines, def.monster_hp, TranslationServer.tr("Monster health"), -1)
	_percent(lines, def.monster_damage, TranslationServer.tr("Monster damage"), -1)
	_percent(lines, def.telegraph_time, TranslationServer.tr("Time to dodge"), 1)
	if def.extra_monsters > 0:
		var more := TranslationServer.tr("+%d monsters per room") if def.extra_monsters > 1 else TranslationServer.tr("+%d monster per room")
		lines.append([more % def.extra_monsters, -1])
	if def.detect_range > 1.05:
		lines.append([TranslationServer.tr("Monsters spot you sooner"), -1])
	elif def.detect_range < 0.95:
		lines.append([TranslationServer.tr("Monsters spot you later"), 1])
	var rooms := def.rooms / reference.rooms if reference and reference.rooms > 0.0 else def.rooms
	if rooms > 1.05:
		lines.append([TranslationServer.tr("Bigger floors (+%d%%)") % roundi((rooms - 1.0) * 100.0), 0])
	elif rooms < 0.95:
		lines.append([TranslationServer.tr("Smaller floors (-%d%%)") % roundi((1.0 - rooms) * 100.0), 0])
	if def.elite_chance > 1.05:
		lines.append([TranslationServer.tr("Elite monsters x%s") % number(def.elite_chance), -1])
	elif def.elite_chance < 0.95:
		lines.append([TranslationServer.tr("Fewer elite monsters"), 1])
	if def.heal_on_new_floor > 0.0:
		lines.append([TranslationServer.tr("Heal %d%% each new floor") % roundi(def.heal_on_new_floor * 100.0), 1])
	if def.light < 0.95:
		lines.append([TranslationServer.tr("Darker floors"), -1])
	elif def.light > 1.05:
		lines.append([TranslationServer.tr("Brighter floors"), 1])
	if def.loot_chance > 1.05:
		lines.append([TranslationServer.tr("More drops"), 1])
	elif def.loot_chance < 0.95:
		lines.append([TranslationServer.tr("Fewer drops"), -1])
	if def.loot_quality < 0.95:
		lines.append([TranslationServer.tr("Magic, Rare and Epic gear come rarer"), -1])
	elif def.loot_quality > 1.05:
		lines.append([TranslationServer.tr("Magic, Rare and Epic gear come more often"), 1])
	if not def.counts_feats:
		lines.append([TranslationServer.tr("No feats: achievements, the Tree's feats and records don't count"), -1])
	if def.hero_max_hp < 0.99:
		lines.append([TranslationServer.tr("%d%% less max health") % roundi((1.0 - def.hero_max_hp) * 100.0), -1])
	if lines.is_empty():
		lines.append([TranslationServer.tr("Everything as the game was made: the other difficulties are compared with it."), 0])
	return lines


## "Monster health +30%" (`helps` = +1 when more of it helps the hero, -1 when it hurts).
static func _percent(lines: Array, factor: float, what: String, helps: int) -> void:
	var change := roundi((factor - 1.0) * 100.0)
	if change == 0:
		return
	lines.append([TranslationServer.tr("%s %+d%%") % [what, change], helps if change > 0 else -helps])


## 1.35 -> "1.35", 2.0 -> "2" (`decimals` at most).
static func number(value: float, decimals: int = 2) -> String:
	return (("%." + str(decimals) + "f") % value).rstrip("0").rstrip(".")


## The gold frame of the last choice (fainter around the keyboard's focus).
func _draw() -> void:
	if _selected or has_focus():
		UiSkin.draw_edge(self, Rect2(Vector2.ZERO, size).grow(2), Color(1.0, 0.85, 0.35, 1.0 if _selected else 0.45))


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, PADDING + 2)
	add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	_name = UiSkin.label("", Fonts.TITLE)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_name)
	_tag = UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_tag)
	_description = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_description)
	column.add_child(MenuWindow.separator())
	_effects = VBoxContainer.new()
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects.add_theme_constant_override("separation", 2)
	column.add_child(_effects)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	_souls = UiSkin.label("", Fonts.BODY, MenuWindow.SOULS)
	_souls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_souls)
	_footer = UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_footer)
	for node in column.get_children():
		if node is Control:
			(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
