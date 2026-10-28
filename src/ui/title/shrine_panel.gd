class_name ShrinePanel
extends Control
## The shrine, in the game's skin (MenuWindow): the Tree of Souls (SoulTreeDef). Four branches of
## nodes bought with souls; a node opens once a node above it is bought, some need a feat, and
## side-by-side nodes are forks (taking one shuts the other). Each branch ends on an oath, a way to
## start a run. Left, the tree (SoulTreeView); right, the picked node: what it does, now and next,
## what opens it, and Buy. "Reset the tree" gives every soul back, to try another path, once
## earned: every SoulTreeDef.reset_runs runs ("Reset in 2 runs" until then).
## Built in code; %Souls, %ShrineText, %TreeView, %OathLore, %BuyButton and %ResetButton are reachable from
## the title screen.

const DETAIL_WIDTH := 360.0

var _tree: SoulTreeDef
## For the words that need the dungeon's items (the Armory's weapons still locked); may be null.
var _content: ContentDB
var _picked: SoulNodeDef

var _window: MenuWindow
var _souls: Label
var _view: SoulTreeView
var _icon: TextureRect
var _name: Label
var _branch: Label
var _level: Label
## An oath's vow, as a keeper of old swore it (OathDef.lore), above its rule.
var _lore: Label
var _text: Label
var _status: Label
var _blocker: Label
## An oath's costs, in red (its gains go in green in _status).
var _costs: Label
var _buy: Button
var _reset: Button
var _reset_text: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()
	Profile.changed.connect(_refresh)


func open(tree: SoulTreeDef, content: ContentDB = null) -> void:
	_tree = tree
	_content = content
	_view.show_tree(tree)
	_view.fit(_view.get_parent().get_parent().size - Vector2(4, 4))
	# Start on something worth reading: the first node you can buy, or the first root.
	var first: SoulNodeDef = null
	for node in tree.nodes:
		if node and Profile.can_buy_node(node):
			first = node
			break
	pick(first if first else tree.nodes[0])
	show()


func close() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()


func picked() -> SoulNodeDef:
	return _picked


func pick(node: SoulNodeDef) -> void:
	_picked = node
	_view.select(node)
	_refresh()


func buy_picked() -> bool:
	if _picked and Profile.buy_node(_picked):
		Sfx.play_ui(Sfx.bank.perk_chosen)
		return true
	return false


func reset_tree() -> bool:
	if Profile.reset_tree(_tree):
		Sfx.play_ui(Sfx.bank.ui_click)
		return true
	return false


## An oath's gains (`kind` 1), costs (-1) or plain facts like its weapon (0), one per line.
static func _oath_lines(oath: OathDef, kind: int) -> String:
	var lines := PackedStringArray()
	for line: Array in oath.effects():
		if signi(line[1]) == kind:
			lines.append(line[0])
	return "\n".join(lines)


## The words for a node: what it does now and next (UpgradeRow's), and the oath's rule.
static func status_of(node: SoulNodeDef, content: ContentDB = null) -> String:
	if node.oath:
		return (TranslationServer.tr("Sworn before a run: %s") if node.is_owned() else TranslationServer.tr("Opens: %s")) % TranslationServer.tr(node.oath.description)
	return UpgradeRow.status_text(node.upgrade, node.level(), content)


## The reset button's words: "Reset the tree", or how many runs until it is earned.
static func reset_label(runs_left: int) -> String:
	if runs_left <= 0:
		return TranslationServer.tr("Reset the tree")
	return (TranslationServer.tr("Reset in %d runs") if runs_left > 1 else TranslationServer.tr("Reset in %d run")) % runs_left


func _refresh() -> void:
	if _tree == null:
		return
	_souls.text = tr("Souls %d") % Profile.souls
	_view.refresh()
	var spent := _tree.spent()
	var runs_left := Profile.reset_runs_left(_tree)
	_reset.text = reset_label(runs_left)
	_reset.disabled = not Profile.can_reset_tree(_tree)
	if spent <= 0:
		_reset_text.text = tr("Nothing bought yet.")
	elif runs_left > 0:
		_reset_text.text = tr("Earned every %d runs.") % _tree.reset_runs
	elif _tree.reset_cost <= 0:
		_reset_text.text = tr("Every soul spent comes back (%d), for free.") % spent
	else:
		_reset_text.text = tr("Every soul spent comes back (%d), minus %d.") % [spent, _tree.reset_cost]
	var node := _picked
	if node == null:
		return
	var upgrade := node.upgrade
	_icon.texture = node.oath.icon if node.oath else upgrade.icon
	_name.text = node.display_name()
	var color := node.oath.color if node.oath else upgrade.color
	_name.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.35))
	var branch_color := _tree.branch_colors[node.branch] if node.branch < _tree.branch_colors.size() else UiSkin.DIM
	var branch_name := tr(_tree.branches[node.branch]) if node.branch < _tree.branches.size() else ""
	_branch.text = (tr("%s branch  -  pick one of two") if node.partner() else tr("%s branch")) % branch_name
	_branch.add_theme_color_override("font_color", branch_color.lerp(Color.WHITE, 0.3))
	_level.text = UpgradeRow.level_text(upgrade, node.level()) if not node.oath else (tr("Oath open") if node.is_owned() else tr("Oath locked"))
	_lore.text = tr(node.oath.lore) if node.oath and not node.oath.lore.is_empty() else ""
	_lore.visible = not _lore.text.is_empty()
	_text.text = (tr("Pick it before a run, after the difficulty.") + "\n" + _oath_lines(node.oath, 0)).strip_edges() if node.oath else UpgradeRow.description_of(upgrade)
	_status.text = status_of(node, _content) if not node.oath else _oath_lines(node.oath, 1)
	_status.visible = not _status.text.is_empty()
	_costs.text = _oath_lines(node.oath, -1) if node.oath else ""
	_costs.visible = not _costs.text.is_empty()
	var blocker := node.blocker()
	_blocker.text = blocker
	_blocker.visible = not blocker.is_empty()
	if node.is_maxed():
		_buy.text = tr("Owned") if node.max_level() <= 1 else tr("Maxed")
		_buy.disabled = true
	elif not blocker.is_empty():
		_buy.text = tr("Locked")
		_buy.disabled = true
	elif Profile.can_buy_node(node):
		_buy.text = tr("Buy  -  %d souls") % node.next_cost()
		_buy.disabled = false
	else:
		_buy.text = tr("Need %d souls") % node.next_cost()
		_buy.disabled = true


# --- Building -----------------------------------------------------------------------

func _build() -> void:
	_window = MenuWindow.new(tr("The Shrine: Tree of Souls"))
	_window.close_requested.connect(close)
	add_child(_window)
	var scene_owner: Node = owner if owner != null else self
	var flavor := UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	flavor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_window.header_left.add_child(flavor)
	MenuWindow.expose(flavor, "ShrineText", scene_owner)
	_souls = UiSkin.label("", Fonts.BODY, MenuWindow.SOULS)
	_window.header_right.add_child(_souls)
	MenuWindow.expose(_souls, "Souls", scene_owner)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	_window.body.add_child(columns)

	# Left: the tree, scrolled with a finger when the screen is small.
	var left := UiSkin.section()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	TouchScroll.attach(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_view = SoulTreeView.new()
	scroll.resized.connect(func() -> void: _view.fit(scroll.size - Vector2(4, 4)))
	_view.node_picked.connect(func(node: SoulNodeDef) -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		pick(node))
	center.add_child(_view)
	MenuWindow.expose(_view, "TreeView", scene_owner)

	# Right: the picked node.
	var right: Dictionary = RpgWindow.section(tr("The node"))
	(right.box as Control).custom_minimum_size.x = DETAIL_WIDTH
	columns.add_child(right.box)
	var column: VBoxContainer = right.column
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	column.add_child(head)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiSkin.slot_frame(10))
	frame.custom_minimum_size = Vector2(68, 68)
	head.add_child(frame)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(_icon)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	_name = UiSkin.label("", Fonts.BODY)
	titles.add_child(_name)
	_branch = UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	titles.add_child(_branch)
	_level = UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
	titles.add_child(_level)
	var words := ScrollContainer.new()
	words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	words.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(words)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 8)
	words.add_child(text)
	_lore = UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	text.add_child(_lore)
	MenuWindow.expose(_lore, "OathLore", scene_owner)
	_text = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	text.add_child(_text)
	_status = UiSkin.label("", Fonts.BODY, UiSkin.GOOD, true)
	text.add_child(_status)
	_costs = UiSkin.label("", Fonts.BODY, UiSkin.BAD, true)
	text.add_child(_costs)
	_blocker = UiSkin.label("", Fonts.BODY, UiSkin.BAD, true)
	text.add_child(_blocker)
	var legend := UiSkin.label(tr("Gold ring: bought. Glowing: you can buy it. Dark: buy a node above it first. \"or\": pick one of the two. ?: a feat opens it."), Fonts.BODY, UiSkin.DIM, true)
	text.add_child(legend)
	_buy = MenuWindow.button("", Fonts.BODY, 58)
	_buy.pressed.connect(buy_picked)
	column.add_child(_buy)
	MenuWindow.expose(_buy, "BuyButton", scene_owner)
	_reset = MenuWindow.button(tr("Reset the tree"), Fonts.BODY, 44)
	_reset.pressed.connect(reset_tree)
	column.add_child(_reset)
	MenuWindow.expose(_reset, "ResetButton", scene_owner)
	_reset_text = UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	column.add_child(_reset_text)
