class_name TouchScroll
extends Node
## Drag-to-scroll that works on phones whatever is inside the list (cards, buttons...): a drag
## that starts over the ScrollContainer scrolls it (with a little momentum when let go), and a
## drag never presses the button it started on. A tap still works as usual. A drag that starts on
## a slider (a volume...), a scroll bar or a control in the group KEEPS_DRAG stays that
## control's, however far the finger wanders up or down: the list never takes it. A list behind
## the menu on top (MenuNav) takes no drag at all.
## Every ScrollContainer gets one as it enters the tree (the TouchScrolling autoload); a list
## built in code may take it at once with TouchScroll.attach(scroll). Either way a list has one
## helper: attach() is the one path, and a second call returns the first helper.

const DRAG_START := 12.0  ## pixels before a touch becomes a drag
const FRICTION := 5.0
## Controls that keep a drag started on them for themselves (besides sliders and scroll bars).
const KEEPS_DRAG := &"keeps_drag"
## Set on a list once it has (or is about to get) its helper: the autoload skips it then.
const META := &"touch_scroll"

var scroll: ScrollContainer

var _tracking := false
var _dragging := false
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _velocity := Vector2.ZERO


static func attach(container: ScrollContainer) -> TouchScroll:
	var existing := of(container)
	if existing:
		return existing
	container.set_meta(META, true)
	container.follow_focus = true  # a button focused off the list's edge scrolls into sight
	var helper := TouchScroll.new()
	helper.scroll = container
	container.add_child(helper)
	return helper


## The list's helper, or null.
static func of(container: ScrollContainer) -> TouchScroll:
	for child in container.get_children():
		if child is TouchScroll:
			return child
	return null


func _input(event: InputEvent) -> void:
	if not scroll.is_visible_in_tree():
		_tracking = false
		return
	# One stream of events: touches arrive as (emulated) mouse events too.
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed:
			_tracking = scroll.get_global_rect().has_point(button.position) and _on_top() \
					and not _keeps_drag_at(scroll, button.position)
			_dragging = false
			_start = button.position
			_last = button.position
			_velocity = Vector2.ZERO
		elif _tracking:
			_tracking = false
			if _dragging:
				_dragging = false
				set_process(true)  # the momentum glides it on a moment
				get_viewport().set_input_as_handled()  # not a tap: no button fires
				# The button under the finger still waits for its release: give it one far away,
				# so it lets go without firing.
				# (A move out first: the button must know the finger left it.)
				var far := Vector2(-10000, -10000)
				var out := InputEventMouseMotion.new()
				out.position = far
				out.global_position = far
				out.button_mask = MOUSE_BUTTON_MASK_LEFT
				var away := button.duplicate() as InputEventMouseButton
				away.position = far
				away.global_position = far
				_let_go.call_deferred(out, away)
	elif event is InputEventMouseMotion and _tracking:
		var position := (event as InputEventMouseMotion).position
		if not _dragging and position.distance_to(_start) > DRAG_START:
			_dragging = true
			_last = position
		if _dragging:
			var delta := position - _last
			_last = position
			_move(delta)
			_velocity = _velocity.lerp(delta / maxf(get_process_delta_time(), 0.001), 0.5)
			get_viewport().set_input_as_handled()


## The list is in the menu on top, or no menu is open (MenuNav): a list behind a window (the
## title's, under the Options) never takes a drag meant for the window.
func _on_top() -> bool:
	var top := MenuNav.top_menu()
	return top == null or top.is_ancestor_of(scroll)


## A visible control under `point` in `node` that keeps its drags (a slider, a scroll bar, or in
## KEEPS_DRAG; not a progress bar, which a list scrolls over).
static func _keeps_drag_at(node: Node, point: Vector2) -> bool:
	for child in node.get_children(true):
		var control := child as Control
		if control == null:
			continue
		if not control.is_visible_in_tree():
			continue
		if (control is Slider or control is ScrollBar or control.is_in_group(KEEPS_DRAG)) and control.get_global_rect().has_point(point):
			return true
		if _keeps_drag_at(control, point):
			return true
	return false


func _ready() -> void:
	set_process(false)  # only while a let-go list glides on (see _glide())


func _process(delta: float) -> void:
	if _dragging:
		return
	if _velocity.length() < 20.0:
		set_process(false)
		return
	_move(_velocity * delta)
	_velocity = _velocity.lerp(Vector2.ZERO, minf(FRICTION * delta, 1.0))


func _move(delta: Vector2) -> void:
	if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroll.scroll_vertical -= roundi(delta.y)
	if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroll.scroll_horizontal -= roundi(delta.x)


func _let_go(out: InputEventMouseMotion, away: InputEventMouseButton) -> void:
	get_viewport().push_input(out, true)
	get_viewport().push_input(away, true)
