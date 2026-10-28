class_name PerkCard
extends Button
## One choice of the perk screen: icon, name, level, what it does, and its families
## (SynergyDef) spelled out: the family's name, how many of its perks you hold (squares), how
## many more it takes and what its bonus does; lit up when this card would wake it.
## The card grows to fit its text (never less than its base size), so nothing spills out.

const RARE_COLOR := Palette.GOLD
## A relic that bends a rule says so in the danger color (its price is part of it).
const TWIST_COLOR := UiSkin.BAD

@onready var _rarity: Label = %Rarity
@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _level: Label = %Level
@onready var _description: Label = %Description
@onready var _families: VBoxContainer = %Families

## This card would wake a family.
var completes := false


func show_perk(perk: PerkDef, owned: PerkSet) -> void:
	var owned_stacks := owned.stacks_of(perk)
	_rarity.text = tr("Relic that bends a rule") if perk.twist else tr("Relic") if perk.rarity == PerkDef.Rarity.RARE else ""
	_rarity.visible = perk.rarity == PerkDef.Rarity.RARE or perk.twist
	_rarity.add_theme_color_override("font_color", TWIST_COLOR if perk.twist else RARE_COLOR)
	_icon.texture = perk.icon
	_name.text = tr(perk.display_name)
	_name.add_theme_color_override("font_color", perk.color.lerp(Color.WHITE, 0.4))
	_level.text = level_text(owned_stacks, perk.max_stacks)
	_description.text = perk.describe()
	completes = false
	for synergy in perk.synergies:
		if synergy:
			_families.add_child(family_box(synergy, owned, perk))
			completes = completes or owned.would_complete(perk, synergy)
	FitToContent.grow_later(self, $Margin)  # long text: a taller card, nothing spills out


## "New perk  (up to level 3)", "Level 1 > 2  (max 3)", "New relic".
static func level_text(owned_stacks: int, max_stacks: int) -> String:
	if owned_stacks == 0:
		return TranslationServer.tr("New perk") if max_stacks == 1 else TranslationServer.tr("New perk  (up to level %d)") % max_stacks
	return TranslationServer.tr("Level %d > %d  (max %d)") % [owned_stacks, owned_stacks + 1, max_stacks]


## What the card's family means, spelled out: its name and how many of its perks you hold (with
## this one), then what holding enough of them does. Lit up when this card would wake it.
static func family_box(synergy: SynergyDef, owned: PerkSet, perk: PerkDef) -> PanelContainer:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var have := owned.pieces_of(synergy)
	var after := have + (1 if perk and owned.stacks_of(perk) == 0 else 0)
	var wakes := perk != null and owned.would_complete(perk, synergy)
	var awake := owned.is_awake(synergy)
	# A wash of the family's color, its edge the skin's frame in that color.
	box.add_theme_stylebox_override("panel", UiSkin.band(Color(synergy.color, 0.28 if wakes else 0.14), 6, 6))
	var edge: Color = synergy.color if wakes or awake else Color(synergy.color, 0.55)
	box.draw.connect(func() -> void: UiSkin.draw_edge(box, Rect2(Vector2.ZERO, box.size), edge))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	box.add_child(column)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 6)
	column.add_child(head)
	var picture := TextureRect.new()
	picture.texture = synergy.icon
	picture.custom_minimum_size = Vector2(20, 20)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(picture)
	var family_name := TranslationServer.tr(synergy.display_name)
	var bonus := TranslationServer.tr(synergy.description)
	var title := _label(TranslationServer.tr("%s family") % family_name, Fonts.BODY, synergy.color.lerp(Color.WHITE, 0.35))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(Pips.new(mini(after, synergy.pieces) if not awake else synergy.pieces, synergy.pieces, synergy.color))
	var blurb := ""
	if wakes:
		blurb = TranslationServer.tr("This one makes %d/%d: the family bonus AWAKENS!") % [synergy.pieces, synergy.pieces] + "\n" + bonus
	elif awake:
		blurb = (TranslationServer.tr("Bonus active: %s") if perk == null else TranslationServer.tr("Bonus already active: %s")) % bonus
	else:
		var missing := synergy.pieces - after
		var more := TranslationServer.tr("%d more %s perk to awaken its bonus: %s") if missing == 1 else TranslationServer.tr("%d more %s perks to awaken its bonus: %s")
		blurb = more % [missing, family_name, bonus]
	var words := _label(blurb, Fonts.SMALL, Color(1, 1, 1, 0.95) if wakes else Color(1, 0.95, 0.88, 0.78))
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(words)
	if wakes:
		var tween := box.create_tween().set_loops()
		tween.tween_property(box, "modulate", Color(1.25, 1.25, 1.25), 0.5)
		tween.tween_property(box, "modulate", Color.WHITE, 0.5)
	return box


static func _label(words: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = words
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", Fonts.outline_size(font_size))
	return label


## Small squares, one per perk the family needs: filled for those held.
class Pips:
	extends Control
	var filled := 0
	var total := 3
	var color := Color.WHITE

	func _init(have: int, count: int, tint: Color) -> void:
		filled = have
		total = count
		color = tint
		custom_minimum_size = Vector2(count * 12 + 2, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in total:
			var rect := Rect2(Vector2(i * 12 + 1, 5), Vector2(9, 9))
			draw_rect(rect.grow(1), Color(0, 0, 0, 0.8))
			draw_rect(rect, color if i < filled else Color(color, 0.18))
