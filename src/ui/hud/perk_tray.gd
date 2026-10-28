class_name PerkTray
extends HFlowContainer
## Row of small icons showing the awakened families (framed in their color), then the perks
## collected this run, with their level.

const ICON_SIZE := Vector2(24, 24)

var _perks: PerkSet


func bind(perks: PerkSet) -> void:
	if _perks:
		_perks.changed.disconnect(_rebuild)
	_perks = perks
	_perks.changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for synergy in _perks.awakened():
		var badge := Control.new()
		badge.custom_minimum_size = ICON_SIZE + Vector2(8, 8)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The family's color as the skin's frame around its sign, over a faint wash of it.
		var color: Color = synergy.color
		badge.draw.connect(func() -> void:
			badge.draw_rect(Rect2(Vector2.ZERO, badge.size), Color(color, 0.25))
			UiSkin.draw_edge(badge, Rect2(Vector2.ZERO, badge.size), color))
		var icon := TextureRect.new()
		icon.texture = synergy.icon
		icon.position = Vector2(4, 4)
		icon.size = ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(icon)
		add_child(badge)
	for entry in _perks.entries:
		var icon := TextureRect.new()
		icon.texture = entry.perk.icon
		icon.custom_minimum_size = ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = tr(entry.perk.display_name)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if entry.stacks > 1:
			var level := Label.new()
			level.text = str(entry.stacks)
			UiSkin.set_text_style(level, Fonts.SMALL)
			level.position = Vector2(16, 10)
			icon.add_child(level)
		add_child(icon)
