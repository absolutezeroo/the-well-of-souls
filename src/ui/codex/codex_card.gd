class_name CodexCard
extends Button
## A monster's card in the bestiary: its picture, its name, your hunter rank with it and how
## many you slew, a little bar toward the next rank (the name on two lines if it must). Never met: a dark shape and "???".
## Gold frame once Mastered; badges for bosses and Shiny ones found. Tap it for its page.

## (Wide enough for a name's longest word or first words at BODY, with the room a wrapped line
## keeps after them: « L'Accapareur », « The Nameless »; tall enough for a name on two lines.)
const SIZE := Vector2(192, 206)
## Lines a name may take (a check in the title suite: every name fits them, in French and English,
## no word cut).
const NAME_LINES := 2
## UI pixels between its lines (the theme's Label: an even number, docs/design/interface.md "Text").
const NAME_LINE_GAP := 2
const UNKNOWN_COLOR := Color(0.08, 0.06, 0.1)
const SHINY_COLOR := Color(1.0, 0.6, 0.95)

var monster: MonsterDef
var _mastered := false
var _slot: StyleBoxTexture
var _frame: StyleBoxTexture


func _init(def: MonsterDef, rules: BestiaryRules) -> void:
	monster = def
	custom_minimum_size = SIZE
	var none := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, none)
	_slot = ItemSlot.slot_box().duplicate() as StyleBoxTexture  # (its own: dimmed or lit as the card is)
	_frame = ItemSlot.frame_box(UiSkin.GOLD)

	var kills := Profile.kill_count(def.id)
	var rank := Bestiary.rank_of(def, rules) if rules else (1 if kills > 0 else Bestiary.UNSEEN)
	_mastered = rules != null and Bestiary.is_mastered(def, rules)
	disabled = rank == Bestiary.UNSEEN
	var inside := VBoxContainer.new()
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.offset_left = 8
	inside.offset_right = -8
	inside.offset_top = 14
	inside.offset_bottom = -20
	inside.alignment = BoxContainer.ALIGNMENT_CENTER
	inside.add_theme_constant_override("separation", 0)  # (even units: art-bible, steps of 2)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inside)
	var picture := CodexRows.icon(CodexPanel.portrait(def), 64)
	picture.modulate = Color.WHITE if rank >= Bestiary.SEEN else UNKNOWN_COLOR
	inside.add_child(picture)
	var is_boss := def is BossDef
	# On two lines when it must, never cut (« Gluant Géant », « Sentinelle de la Brèche »): the
	# room for two is always kept, so every card's picture and rank sit at the same height.
	var name_label := _centered(tr(def.display_name) if rank >= Bestiary.SEEN else "???", Fonts.BODY, Palette.DANGER if is_boss else UiSkin.TEXT)
	name_label.name = "Name"
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = NAME_LINES
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_constant_override(&"line_spacing", NAME_LINE_GAP)
	name_label.custom_minimum_size.y = Fonts.MAIN.get_height(Fonts.BODY) * NAME_LINES + NAME_LINE_GAP * (NAME_LINES - 1)
	inside.add_child(name_label)
	if rank == Bestiary.UNSEEN:
		var unmet := _centered(tr("Not met yet"), Fonts.BODY, UiSkin.DIM)
		unmet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # on two lines if it must, as the others use
		inside.add_child(unmet)
	elif rank == Bestiary.SEEN:
		inside.add_child(_centered(tr("Seen"), Fonts.BODY, UiSkin.TEXT))
		inside.add_child(_centered(tr("not slain yet"), Fonts.BODY, UiSkin.DIM))
	else:
		inside.add_child(_centered(Bestiary.rank_name(rank, rules), Fonts.BODY, CodexRows.DONE if _mastered else UiSkin.GOLD))
		inside.add_child(_centered(tr("%d slain") % kills, Fonts.BODY, UiSkin.DIM))
	# Toward the next rank (full and green once mastered). Unknown ones keep its room empty.
	var next := Bestiary.next_kills(def, rules) if rules else 0
	var meter := CodexRows.bar(kills if next > 0 else 1, next if next > 0 else 1, "", 10)
	meter.show_text = false
	meter.modulate.a = 1.0 if rules and rank >= Bestiary.SEEN else 0.0
	var room := MarginContainer.new()
	room.add_theme_constant_override("margin_left", 8)
	room.add_theme_constant_override("margin_right", 8)
	room.add_theme_constant_override("margin_top", 4)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(meter)
	inside.add_child(room)
	if is_boss:
		add_child(_badge(tr("Boss"), Palette.DANGER, false))
	if Profile.has_shiny(def.id):
		add_child(_badge(tr("Celestial"), SHINY_COLOR, true))


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	_slot.modulate_color = Color(0.55, 0.5, 0.5) if disabled else (Color(1.15, 1.1, 1.0) if is_hovered() else Color.WHITE)
	draw_style_box(_slot, area)
	if _mastered:
		draw_style_box(_frame, area.grow(-3))


func _centered(words: String, font_size: int, color: Color) -> Label:
	var label := UiSkin.label(words, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## A word in a top corner ("Boss", "Shiny").
func _badge(words: String, color: Color, right: bool) -> Label:
	var badge := UiSkin.label(words, Fonts.BODY, color)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(SIZE.x - 14 - badge.get_minimum_size().x if right else 14.0, 11)
	return badge
