class_name FragmentPanel
extends Control
## A fragment of the past, read (FragmentDef): in the game's skin (RpgDialog), its title on the
## ribbon, its picture, who wrote it and where, its lines, and whose chronicle keeps it now.
## The game is paused while it is open; a tap anywhere (or Back, or the button) closes it.
## The codex opens the same panel to read a found fragment again. Built in code.
## Its words are in a dark inset, its lines reading text (UiSkin.reading_size(): wider with Large
## text); one too long for the screen scrolls, and a touch on the words then scrolls instead of
## closing (Close, Back or a tap outside them still close it).

signal closed

const WIDTH := 780.0
## The board's width with Large text.
const LARGE_WIDTH := 1100.0
## Room the board keeps for its ribbon, margins, Close and the inset around the words: the words'
## box is at most the screen's height less this.
const ROOM_AROUND := 300.0
## Taps this few frames after it opened are not for it (about a quarter of a second).
const OPEN_GRACE_FRAMES := 15

var _dialog: RpgDialog
var _icon: TextureRect
var _source: Label
var _place: Label
var _lines: VBoxContainer
var _kept: Label
var _close: Button
## The words' box (scrolls when the fragment is longer than the screen) and what it holds.
var _scroll: ScrollContainer
var _words_box: VBoxContainer
## Built nodes reachable as %Name once the panel is built.
var _named := ExposedNodes.new()
var _gate := TapGate.new(TapGate.Keys.ANY, OPEN_GRACE_FRAMES)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()


## Shows `fragment` (about `boss`; `first_time`: just found, "Kept in the chronicle of ...").
func open(fragment: FragmentDef, boss: BossDef, first_time: bool = false) -> void:
	_dialog.set_title(tr(fragment.title), UiSkin.GOLD)
	var look := fragment.look
	_icon.texture = look.icon if look else null
	_icon.modulate = look.icon_tint if look else Color.WHITE
	_icon.visible = _icon.texture != null
	_source.text = tr(fragment.author)
	_place.text = tr(fragment.place)
	_place.visible = not fragment.place.is_empty()
	UiParts.clear(_lines)
	for line in fragment.lines:
		_lines.add_child(UiSkin.reading_label(tr(line)))
	_dialog.set_board_width(LARGE_WIDTH if UiSkin.reading_size() > Fonts.BODY else WIDTH)
	_scroll.scroll_vertical = 0
	_fit_words.call_deferred()
	_kept.visible = boss != null
	if boss:
		var boss_name := tr(boss.display_name)
		_kept.text = tr("A new page for its chronicle: %s.") % boss_name if first_time else tr("From its chronicle: %s.") % boss_name
	_gate.open()
	show()


func close() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()
	closed.emit()


## The lines shown (tests).
func lines_text() -> PackedStringArray:
	var result := PackedStringArray()
	for label: Label in _lines.get_children():
		result.append(label.text)
	return result


func board_rect() -> Rect2:
	return _dialog.board_rect()


## The words' box as tall as they are, at most the screen's height less ROOM_AROUND (then it
## scrolls).
func _fit_words() -> void:
	var most := maxf(get_viewport_rect().size.y - ROOM_AROUND, 120.0)
	_scroll.custom_minimum_size.y = minf(_words_box.get_combined_minimum_size().y, most)


## `event` is a touch, a drag or a click over the words while they scroll.
func _over_scrolling_words(event: InputEvent) -> bool:
	var at := Vector2.INF
	if event is InputEventScreenTouch:
		at = (event as InputEventScreenTouch).position
	elif event is InputEventScreenDrag:
		at = (event as InputEventScreenDrag).position
	elif event is InputEventMouseButton:
		at = (event as InputEventMouseButton).position
	else:
		return false
	return _scrolls() and _scroll.get_global_rect().has_point(at)


## The words are longer than their box.
func _scrolls() -> bool:
	return _words_box.get_combined_minimum_size().y > _scroll.size.y + 1.0


## Any tap, click or key closes it (not in its first moments: the tap that opened it).
## (TapGate: never the wheel; the touch and the click made of it are one press, and the twin
## that comes after the panel closed is swallowed too, so it never presses a HUD button.)
func _input(event: InputEvent) -> void:
	if visible and _over_scrolling_words(event):
		return  # (a finger or the wheel over words that scroll: it scrolls them)
	var read := _gate.read(event, visible)
	if read == TapGate.IGNORE:
		return
	get_viewport().set_input_as_handled()
	if read == TapGate.TAKE:
		close()


func _build() -> void:
	_dialog = RpgDialog.new("", WIDTH)
	_dialog.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_dialog)
	var inset := UiSkin.section()
	_dialog.body.add_child(inset)
	_scroll = UiParts.scroll()
	_scroll.name = "WordsScroll"
	inset.add_child(_scroll)
	_words_box = VBoxContainer.new()
	_words_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_words_box.add_theme_constant_override("separation", 10)
	_scroll.add_child(_words_box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	_words_box.add_child(top)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(64, 64)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(_icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 4)
	top.add_child(words)
	_source = UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	_source.name = "Source"
	words.add_child(_source)
	_place = UiSkin.label("", Fonts.BODY, UiSkin.DIM, true)
	_place.name = "Place"
	words.add_child(_place)
	_lines = VBoxContainer.new()
	_lines.name = "Lines"
	_lines.add_theme_constant_override("separation", 6)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	words.add_child(gap)
	words.add_child(_lines)
	_kept = UiSkin.label("", Fonts.BODY, UiSkin.GOLD, true)
	_kept.name = "Kept"
	_words_box.add_child(_kept)
	_close = MenuWindow.button(tr("Close"), Fonts.BODY, MenuWindow.TOUCH_MIN)
	_close.name = "CloseButton"
	_close.custom_minimum_size.x = 200
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(close)
	PromptGlyph.badge(_close, &"ui_cancel", PromptGlyph.Place.INSIDE)
	_dialog.body.add_child(_close)
	for node: Node in [_source, _place, _lines, _kept, _close]:
		_named.add(node)
	_named.expose_to(self)
