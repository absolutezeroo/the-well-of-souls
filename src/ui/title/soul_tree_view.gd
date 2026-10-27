class_name SoulTreeView
extends Control
## The Tree of Souls laid out: four branches side by side (their name and what they are about on
## top, a faint band of their color behind), the nodes on a grid, and the paths between them,
## lit gold once both ends are bought. Tapping a node selects it (`node_picked`).

signal node_picked(node: SoulNodeDef)

## Room per column and per row: as much as the screen gives, within these bounds.
const COLUMN_RANGE := Vector2(74.0, 96.0)
const ROW_RANGE := Vector2(76.0, 104.0)
const HEAD := 60.0

var column := 86.0
var row := 98.0

var tree: SoulTreeDef
var _buttons: Array[SoulNodeButton] = []


func show_tree(def: SoulTreeDef) -> void:
	tree = def
	for button in _buttons:
		remove_child(button)
		button.queue_free()
	_buttons.clear()
	for node in tree.nodes:
		if node == null:
			continue
		var button := SoulNodeButton.new(node)
		button.pressed.connect(func() -> void: node_picked.emit(node))
		add_child(button)
		_buttons.append(button)
	fit(_room)


var _room := Vector2.ZERO


## Spreads the tree over `room` (the space shown), within the bounds; scrolls past them.
func fit(room: Vector2) -> void:
	_room = room
	if tree == null:
		return
	column = clampf(room.x / maxf(tree.columns(), 1), COLUMN_RANGE.x, COLUMN_RANGE.y)
	row = clampf((room.y - HEAD) / maxf(tree.rows(), 1), ROW_RANGE.x, ROW_RANGE.y)
	custom_minimum_size = Vector2(tree.columns() * column, HEAD + tree.rows() * row)
	for button in _buttons:
		button.position = center_of(button.node) - button.size * 0.5
	queue_redraw()


func buttons() -> Array[SoulNodeButton]:
	return _buttons


func button_of(node: SoulNodeDef) -> SoulNodeButton:
	for button in _buttons:
		if button.node == node:
			return button
	return null


func select(node: SoulNodeDef) -> void:
	for button in _buttons:
		button.selected = button.node == node


func center_of(node: SoulNodeDef) -> Vector2:
	return Vector2((node.cell.x + 0.5) * column, HEAD + (node.cell.y + 0.5) * row)


func refresh() -> void:
	for button in _buttons:
		button.refresh()
	queue_redraw()


func _draw() -> void:
	if tree == null:
		return
	var font := get_theme_default_font()
	# The branches: a band and a heading each (three columns per branch).
	for i in tree.branches.size():
		var color := tree.branch_colors[i] if i < tree.branch_colors.size() else Color.WHITE
		var band := Rect2(i * 3 * column + 4.0, 0.0, 3 * column - 8.0, size.y)
		draw_rect(band, Color(color, 0.07))
		var title := tr(tree.branches[i])
		Fonts.draw(self, Vector2(band.get_center().x, 24), title, Fonts.BODY, color.lerp(Color.WHITE, 0.3), 0.5)
		if i < tree.branch_texts.size():
			draw_multiline_string(font, Vector2(band.position.x + 6, 42).round(), tr(tree.branch_texts[i]), HORIZONTAL_ALIGNMENT_CENTER, roundf(band.size.x - 12), Fonts.SMALL, 2, UiSkin.DIM)
	# The paths: from each node up to the nodes it needs.
	for node in tree.nodes:
		if node == null:
			continue
		for parent in node.requires:
			if parent == null:
				continue
			var lit := parent.is_owned() and node.is_owned()
			var open := parent.is_owned() and not node.is_shut()
			var color := UiSkin.GOLD if lit else (Color(UiSkin.TEXT, 0.55) if open else Color(0, 0, 0, 0.45))
			draw_line(center_of(parent), center_of(node), color, 4.0 if lit else 3.0, true)
	# A fork: a little "or" between its two sides.
	for node in tree.nodes:
		if node and node.partner() and node.cell.x < node.partner().cell.x:
			var mid := (center_of(node) + center_of(node.partner())) * 0.5
			var word := tr("or")
			Fonts.draw(self, mid + Vector2(0, Fonts.half_cap(Fonts.BODY)), word, Fonts.BODY, UiSkin.GOLD, 0.5)
