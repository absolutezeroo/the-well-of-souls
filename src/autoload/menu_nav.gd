extends CanvasLayer
## Menus with keys and gamepads (autoload "MenuNav"): every panel in the group "menu" (RpgWindow,
## RpgDialog, the title screen...) can be used without a finger or a mouse.
##
## - The topmost open menu holds the focus: when it opens (or the keys take over), its first
##   button gets it (the one it named, set_first(), or its first outside a header); when what
##   covered it closes, or the focused button goes away, the one focused there before; focus
##   never leaves it for a menu underneath.
## - Directions (arrows, WASD, the D-pad, the left stick) move to the nearest button that way, in
##   that menu only, and wrap around at its edges; a list too long for its box follows the focus
##   (ScrollContainer.follow_focus, set by TouchScrolling), and a box with nothing to focus
##   scrolls instead. A slider takes left and right for its value.
## - The tab actions (Q / E, LB / RB) press the next or previous of the menu's buttons in the
##   group "menu_tabs".
## - A pixel focus frame in gold shows around the focused button while keys or a gamepad drive
##   (InputDevice.navigating), never on touch.
## Accept is the buttons' own (ui_accept); Back (ui_cancel) stays each screen's (Game.back()...).
## - A text field (the leaderboards' pseudonym) keeps every key while it has the focus, but the
##   up and down arrows.

## Panels that hold the focus.
const GROUP := &"menu"
## A menu's tab buttons, switched by menu_prev_tab / menu_next_tab.
const TABS := &"menu_tabs"
## Meta on a menu: the control to focus first when it opens.
const FIRST := &"nav_first"
## Meta on a slider: what a key or a gamepad moves it by, when its own step is finer (for a
## finger: the options' sliders).
const KEY_STEP := &"nav_key_step"
## Meta on a control: neither it nor what it holds is focused first (a window's header, with
## its Close; the language buttons).
const NOT_FIRST := &"nav_not_first"
## How far one press scrolls a box with nothing to focus (UI units).
const SCROLL_STEP := 96.0
## Sideways distance counts this much more than distance along the way (picks the button in
## line rather than a nearer one off to the side).
const SIDEWAYS_WEIGHT := 2.5

const DIRECTIONS := {
	&"ui_up": Vector2.UP, &"ui_down": Vector2.DOWN, &"ui_left": Vector2.LEFT, &"ui_right": Vector2.RIGHT,
	&"move_up": Vector2.UP, &"move_down": Vector2.DOWN, &"move_left": Vector2.LEFT, &"move_right": Vector2.RIGHT,
}

var _frame: FocusFrame
## Menu (its instance id) -> the controls focused in it lately, the latest last (WeakRefs): when
## what covered it closes, or its focused button goes away, the focus comes back to them.
var _history := {}
## The menus open (instance id -> the frame they were last seen open, `_tick`): one no longer
## seen open has just closed. Kept, not built again every frame (docs/performance.md).
var _open := {}
var _tick := 0
## The group's menus as last asked of the tree: asked again only when it changed (a menu came or
## went), not every frame (a group scan builds an array).
var _menus: Array[Node] = []
## How many controls each menu remembers.
const HISTORY := 8
## The left stick's axes pushed past the dead zone (a stick sends many events: one move a push).
var _stick_held := {}


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_frame = FocusFrame.new()
	add_child(_frame)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


## Where the focus frame is drawn now, on screen (empty: no frame, or its control is scrolled
## out of its box). For the tests.
func frame_area() -> Rect2:
	return _frame.area()


## `menu`'s first focus when it opens (a panel's main button).
static func set_first(menu: Control, control: Control) -> void:
	menu.set_meta(FIRST, control)


## The open menu on top (the last drawn: highest canvas layer, then latest in the tree), or null.
func top_menu() -> Control:
	var best: Control = null
	var best_layer := -4096
	_refresh_menus()
	for node in _menus:
		var menu := node as Control
		if menu == null or not menu.is_visible_in_tree():
			continue
		var layer_index := _layer_of(menu)
		if best == null or layer_index > best_layer or (layer_index == best_layer and menu.is_greater_than(best)):
			best = menu
			best_layer = layer_index
	return best


## The group's menus (`_menus`) asked of the tree again only when one came or went: the group
## counts another number, or one kept is gone or out of the tree.
func _refresh_menus() -> void:
	var tree := get_tree()
	var stale := _menus.size() != tree.get_node_count_in_group(GROUP)
	if not stale:
		for node in _menus:
			if not is_instance_valid(node) or not node.is_inside_tree():
				stale = true
				break
	if stale:
		_menus = tree.get_nodes_in_group(GROUP)


## Focuses `menu`'s first control (see the class doc); false if it has none.
func focus_first(menu: Control) -> bool:
	var target := _first_of(menu)
	if target == null:
		return false
	target.grab_focus()
	return true


## Keys or a gamepad in use: moves the focus to the first control in `part` (a page shown inside
## a menu: a monster's page in the codex). Nothing on touch.
func focus_in(part: Control) -> void:
	if InputDevice.uses_buttons() and part.is_visible_in_tree():
		focus_first(part)


## The controls of `menu` the keys can reach, in tree order.
func focusables(menu: Control) -> Array[Control]:
	var found: Array[Control] = []
	_collect(menu, found)
	return found


func _process(_delta: float) -> void:
	_tick += 1
	_refresh_menus()
	for node in _menus:
		if node is Control and (node as Control).is_visible_in_tree():
			_open[node.get_instance_id()] = _tick
	var closed := 0
	for id: int in _open:
		if _open[id] != _tick:
			closed += 1
	if closed > 0:  # (rare: a list only then)
		for id: int in _open.keys():
			if _open[id] != _tick:
				_open.erase(id)
				_history.erase(id)  # closed: it starts afresh next time
	var top := top_menu() if InputDevice.uses_buttons() else null
	var focus := get_viewport().gui_get_focus_owner()
	if top != null and (focus == null or not top.is_ancestor_of(focus) or not focus.is_visible_in_tree()):
		if focus_first(top):
			focus = get_viewport().gui_get_focus_owner()
	var shown := top != null and focus != null and top.is_ancestor_of(focus) and InputDevice.navigating
	_frame.target = focus if shown else null


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	var top := top_menu()
	if top == null:
		return
	if event is InputEventKey and _typing(event as InputEventKey):
		return  # the keys write in the field (Q, E, WASD, left and right are letters and the caret)
	if _pressed(event, &"menu_next_tab") or _pressed(event, &"menu_prev_tab"):
		if switch_tab(top, 1 if event.is_action(&"menu_next_tab") else -1):
			get_viewport().set_input_as_handled()
		return
	var direction := _direction(event)
	if direction == Vector2.ZERO:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null or not top.is_ancestor_of(focus):
		if focus_first(top):
			get_viewport().set_input_as_handled()
		return
	if focus is Range and direction.x != 0.0:
		# A slider: left and right change its value (the arrows and the D-pad do it themselves).
		# (A fine slider, KEY_STEP: the arrows too, else they would move it by its tiny step.)
		if focus.has_meta(KEY_STEP) or not (event.is_action(&"ui_left") or event.is_action(&"ui_right")):
			var slider := focus as Range
			var stride := float(focus.get_meta(KEY_STEP, slider.step))
			slider.value += stride * signf(direction.x) if stride > 0.0 else (slider.max_value - slider.min_value) * 0.05 * signf(direction.x)
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	var next := neighbor(top, focus, direction)
	if next:
		next.grab_focus()
	elif not _scroll(top, focus, direction):
		var wrapped := wrap_target(top, focus, direction)
		if wrapped:
			wrapped.grab_focus()


## A text field has the focus and `event` is for it: every key but the up and down arrows (which
## still leave it for the buttons around).
func _typing(event: InputEventKey) -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	if not (focus is LineEdit or focus is TextEdit):
		return false
	return event.physical_keycode != KEY_UP and event.physical_keycode != KEY_DOWN \
		and event.keycode != KEY_UP and event.keycode != KEY_DOWN


## The next control from `from` going `direction` in `menu` (its own focus neighbour if it names
## one), or null at the menu's edge.
func neighbor(menu: Control, from: Control, direction: Vector2) -> Control:
	var named := _named_neighbor(from, direction)
	if named:
		return named
	var origin := _rect(from)
	var best: Control = null
	var best_score := INF
	for control in focusables(menu):
		if control == from:
			continue
		var rect := _rect(control)
		var along := (rect.get_center() - origin.get_center()).dot(direction)
		# Past `from`'s far edge that way (half a button's overlap allowed: rows of uneven heights).
		var past := _near_edge(rect, direction) - _far_edge(origin, direction)
		if along <= 1.0 or past < -minf(_extent(origin, direction), _extent(rect, direction)) * 0.5:
			continue
		var score := maxf(past, 0.0) + _sideways_gap(origin, rect, direction) * SIDEWAYS_WEIGHT
		if score < best_score:
			best_score = score
			best = control
	return best


## Where `from` wraps to going `direction` past the menu's edge: the farthest control the other
## way, the one most in line with `from`.
func wrap_target(menu: Control, from: Control, direction: Vector2) -> Control:
	var origin := _rect(from)
	var controls := focusables(menu)
	if controls.size() < 2:
		return null
	var far := INF
	for control in controls:
		far = minf(far, _rect(control).get_center().dot(direction))
	var best: Control = null
	var best_gap := INF
	for control in controls:
		if control == from:
			continue
		var rect := _rect(control)
		if rect.get_center().dot(direction) > far + _extent(rect, direction):
			continue  # not in the far row (or column)
		var gap := _sideways_gap(origin, rect, direction) + absf((rect.get_center() - origin.get_center()).dot(direction.orthogonal())) * 0.01
		if gap < best_gap:
			best_gap = gap
			best = control
	return best


## Presses the next (`step` 1) or previous (-1) tab of `menu` after the one pressed now; false if
## it has no tabs.
func switch_tab(menu: Control, step: int) -> bool:
	var tabs: Array[BaseButton] = []
	for node in get_tree().get_nodes_in_group(TABS):
		var tab := node as BaseButton
		if tab and tab.is_visible_in_tree() and menu.is_ancestor_of(tab) and not tab.disabled:
			tabs.append(tab)
	if tabs.size() < 2:
		return false
	var current := 0
	for i in tabs.size():
		if tabs[i].button_pressed or tabs[i].has_focus():
			current = i
			if tabs[i].button_pressed:
				break
	var next := tabs[posmod(current + step, tabs.size())]
	next.pressed.emit()
	if next.is_visible_in_tree() and next.focus_mode != Control.FOCUS_NONE:
		next.grab_focus()
	return true


# --- Inside ------------------------------------------------------------------------------

func _first_of(menu: Control) -> Control:
	var seen: Array = _history.get(menu.get_instance_id(), [])
	for i in range(seen.size() - 1, -1, -1):
		var control := (seen[i] as WeakRef).get_ref() as Control
		if control and menu.is_ancestor_of(control) and _can_focus(control):
			return control
	# The named one even while disabled (perk cards ignore presses for a moment: an accept
	# pressed too soon must not land on another button).
	var named: Variant = menu.get_meta(FIRST) if menu.has_meta(FIRST) else null
	if named is Control and is_instance_valid(named) and menu.is_ancestor_of(named) \
			and (named as Control).is_visible_in_tree() and (named as Control).focus_mode == Control.FOCUS_ALL:
		return named
	var fallback: Control = null
	for control in focusables(menu):
		if not _kept_from_first(control, menu):
			return control
		if fallback == null:
			fallback = control
	return fallback


func _kept_from_first(control: Control, menu: Control) -> bool:
	var node: Node = control
	while node and node != menu:
		if node.has_meta(NOT_FIRST):
			return true
		node = node.get_parent()
	return false


func _collect(node: Node, found: Array[Control]) -> void:
	for child in node.get_children():
		var control := child as Control
		if control == null:
			if child is CanvasItem and not (child as CanvasItem).visible:
				continue
			_collect(child, found)
			continue
		if not control.visible:
			continue
		if _can_focus(control):
			found.append(control)
		_collect(control, found)


func _can_focus(control: Control) -> bool:
	if control.focus_mode != Control.FOCUS_ALL or not control.is_visible_in_tree():
		return false
	if control is BaseButton and (control as BaseButton).disabled:
		return false
	return true


func _on_focus_changed(control: Control) -> void:
	var menu := _menu_of(control)
	if menu == null:
		return
	var seen: Array = _history.get(menu.get_instance_id(), [])
	seen = seen.filter(func(ref: WeakRef) -> bool: return ref.get_ref() != null and ref.get_ref() != control)
	seen.append(weakref(control))
	if seen.size() > HISTORY:
		seen.pop_front()
	_history[menu.get_instance_id()] = seen


func _menu_of(control: Control) -> Control:
	var node: Node = control
	while node:
		if node is Control and node.is_in_group(GROUP):
			return node as Control
		node = node.get_parent()
	return null


func _layer_of(node: Node) -> int:
	var parent := node.get_parent()
	while parent:
		if parent is CanvasLayer:
			return (parent as CanvasLayer).layer
		parent = parent.get_parent()
	return 0


func _pressed(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action, true, true)


## The way `event` points (zero if none): a key or D-pad press (and its repeats), or the left
## stick pushed past the dead zone (once per push).
func _direction(event: InputEvent) -> Vector2:
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis != JOY_AXIS_LEFT_X and motion.axis != JOY_AXIS_LEFT_Y:
			return Vector2.ZERO
		var pushed := absf(motion.axis_value) >= Prompts.DATA.stick_deadzone
		var was: bool = _stick_held.get(motion.axis, false)
		_stick_held[motion.axis] = pushed
		if not pushed or was:
			return Vector2.ZERO
		var way := signf(motion.axis_value)
		return Vector2(way, 0.0) if motion.axis == JOY_AXIS_LEFT_X else Vector2(0.0, way)
	for action: StringName in DIRECTIONS:
		if InputMap.has_action(action) and event.is_action_pressed(action, true):
			return DIRECTIONS[action]
	return Vector2.ZERO


func _named_neighbor(from: Control, direction: Vector2) -> Control:
	var path: NodePath = from.focus_neighbor_top
	if direction == Vector2.DOWN:
		path = from.focus_neighbor_bottom
	elif direction == Vector2.LEFT:
		path = from.focus_neighbor_left
	elif direction == Vector2.RIGHT:
		path = from.focus_neighbor_right
	if path.is_empty():
		return null
	var target := from.get_node_or_null(path) as Control
	return target if target and _can_focus(target) else null


## No button that way: a box that can still scroll that way does (a page of text, the codex's
## runs). True if something scrolled.
func _scroll(menu: Control, from: Control, direction: Vector2) -> bool:
	var node: Node = from
	var boxes: Array[ScrollContainer] = []
	while node and node != menu:
		if node is ScrollContainer:
			boxes.append(node)
		node = node.get_parent()
	if boxes.is_empty():
		for found in menu.find_children("*", "ScrollContainer", true, false):
			if (found as ScrollContainer).is_visible_in_tree():
				boxes.append(found)
	for box in boxes:
		var bar: ScrollBar = (box.get_v_scroll_bar() as ScrollBar) if direction.y != 0.0 else (box.get_h_scroll_bar() as ScrollBar)
		if bar == null or bar.max_value - bar.page <= 0.0:
			continue
		var before := bar.value
		bar.value = clampf(bar.value + SCROLL_STEP * (direction.y + direction.x), 0.0, bar.max_value - bar.page)
		if not is_equal_approx(before, bar.value):
			return true
	return false


func _rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


## How far along `direction` a rect begins (its top going down, its bottom going up).
func _near_edge(rect: Rect2, direction: Vector2) -> float:
	return (rect.position if direction.x + direction.y > 0.0 else rect.end).dot(direction)


## How far along `direction` a rect ends (its bottom going down).
func _far_edge(rect: Rect2, direction: Vector2) -> float:
	return (rect.end if direction.x + direction.y > 0.0 else rect.position).dot(direction)


func _extent(rect: Rect2, direction: Vector2) -> float:
	return absf(rect.size.dot(direction))


## How far apart two rects are sideways to `direction` (0 when they overlap that way).
func _sideways_gap(a: Rect2, b: Rect2, direction: Vector2) -> float:
	var side := direction.orthogonal().abs()
	var a_from := a.position.dot(side)
	var a_to := a.end.dot(side)
	var b_from := b.position.dot(side)
	var b_to := b.end.dot(side)
	return maxf(0.0, maxf(b_from - a_to, a_from - b_to))


## The gold frame around the focused control (pixel corners on the 2-unit grid, breathing by a
## pixel), drawn over every layer. Kept inside the boxes that clip its control (a list's
## ScrollContainer, an inset), give or take the frame's own width: a button scrolled out of its
## column has no frame over the tabs above it, one half out a frame cut at the box's edge.
class FocusFrame:
	extends Control

	const GOLD := Palette.GOLD
	const LIGHT := Color(1.0, 0.95, 0.75)
	const DARK := Color(0.12, 0.07, 0.05)
	const PIXEL := 2.0
	const ARM := 10.0
	## How far the frame reaches outside its control (the breath included, and the dark edge):
	## a clipping box lets it out that far, so a control at its edge keeps its whole frame.
	const REACH := PIXEL * 4.0

	## Where it is drawn (set by _draw()): what a clipping box leaves of the frame.
	var _clip := Rect2()

	## The focused control to frame (null: none). A freed one counts as none.
	var target: Control
	## A frame is on screen now (it stays drawn until redrawn: cleared once when it goes).
	var _shown := false

	func _init() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		var showing := is_instance_valid(target) and target.is_visible_in_tree()
		if showing or _shown:
			queue_redraw()  # it follows its control and breathes
		_shown = showing

	## The frame's rect on screen as it is drawn now, clipped (empty: none).
	func area() -> Rect2:
		if not is_instance_valid(target) or not target.is_visible_in_tree():
			return Rect2()
		var clip := _clip_rect()
		if not _inside(clip):
			return Rect2()
		return _frame_rect(1.0).intersection(clip)

	## Some of the control shows inside `clip` (less the frame's reach): else it is scrolled out.
	func _inside(clip: Rect2) -> bool:
		var target_rect := target.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, target.size)
		return clip.has_area() and clip.grow(-REACH).intersects(target_rect)

	## The control's rect grown by the frame (`beat`: the breath, 0 or 1 pixel), on the grid.
	func _frame_rect(beat: float) -> Rect2:
		var rect := target.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, target.size)
		rect = rect.grow(PIXEL * (2.0 + beat))
		return Rect2((rect.position / PIXEL).floor() * PIXEL, (rect.size / PIXEL).ceil() * PIXEL)

	## What the boxes around the control leave visible (each grown by REACH), on screen: the
	## whole screen when nothing clips it; empty when one of them hides it all.
	func _clip_rect() -> Rect2:
		var clip := Rect2(-Vector2.ONE * 1e6, Vector2.ONE * 2e6)
		var node := target.get_parent()
		while node:
			var box := node as Control
			if box and box.clip_contents or node is ScrollContainer:
				var rect := box.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, box.size)
				clip = clip.intersection(rect.grow(REACH))
				if not clip.has_area():
					return Rect2()
			if node is Window or node is CanvasLayer:
				break
			node = node.get_parent()
		return clip

	func _draw() -> void:
		if not is_instance_valid(target) or not target.is_visible_in_tree():
			return
		_clip = _clip_rect()
		if not _inside(_clip):
			return  # scrolled out of its box: no frame floating over what is next to it
		var beat := 1.0 if int(Time.get_ticks_msec() / 400.0) % 2 == 0 else 0.0
		var rect := _frame_rect(beat)
		# A thin gold line all round, dark outside it, and bright corners.
		_outline(rect.grow(PIXEL), DARK)
		_outline(rect, GOLD)
		var arm := minf(ARM, minf(rect.size.x, rect.size.y) * 0.4)
		for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var sx := 1.0 if corner.x <= rect.get_center().x else -1.0
			var sy := 1.0 if corner.y <= rect.get_center().y else -1.0
			var x0: float = corner.x if sx > 0.0 else corner.x - PIXEL * 2
			var y0: float = corner.y if sy > 0.0 else corner.y - PIXEL * 2
			_piece(Rect2(x0 if sx > 0.0 else corner.x - arm, y0, arm, PIXEL * 2), LIGHT)
			_piece(Rect2(x0, y0 if sy > 0.0 else corner.y - arm, PIXEL * 2, arm), LIGHT)

	func _outline(rect: Rect2, color: Color) -> void:
		_piece(Rect2(rect.position, Vector2(rect.size.x, PIXEL)), color)
		_piece(Rect2(rect.position.x, rect.end.y - PIXEL, rect.size.x, PIXEL), color)
		_piece(Rect2(rect.position, Vector2(PIXEL, rect.size.y)), color)
		_piece(Rect2(rect.end.x - PIXEL, rect.position.y, PIXEL, rect.size.y), color)

	## A piece of the frame, cut to what the boxes around the control leave visible.
	func _piece(rect: Rect2, color: Color) -> void:
		var shown := rect.intersection(_clip)
		if shown.has_area():
			draw_rect(shown, color)
