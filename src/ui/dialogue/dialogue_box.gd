class_name DialogueBox
extends PanelContainer
## Someone speaking, in the game's skin: their face in a frame, their name in their color, their
## words typed letter by letter (SpeakerDef.letters_per_second) with their voice as each line
## begins. Every speaker uses this one box (the Vigil-Keeper at the shrine and on the end screen,
## any NPC later). Built in code.
##
## Two ways to show what is said (Dialogues.Spoken):
## - PAGED (a conversation: the shrine): one page at a time; a tap, Enter or a gamepad's A
##   writes the page out at once, the next one goes on; after the last one, `finished`.
## - STACKED (beside other things: the end screen): every line under the last, typed one after
##   the other without waiting (an accent line, the advice, in its own color); a tap or accept
##   writes everything out. It never holds the screen: once written, accept is the buttons'.
## Taps in its first quarter of a second are not for it (a thumb still on the screen).
## The words are reading text (UiSkin.reading_size(): bigger with Large text), typed at the
## speaker's pace times the player's text speed (Settings.text_speed, "at once" writes each page
## out), laid out before they are typed so no word jumps a line (UiSkin.typed()). PAGED, a page
## longer than MAX_LINES at the box's width is split into pages of MAX_LINES.

signal finished
## A new page or line began (its speaker's voice).
signal page_started(index: int)

enum Mode { PAGED, STACKED }

## The face's size in UI units: a 38-pixel faceset at x2.
const PORTRAIT := 76.0
## A breath between two stacked lines (seconds).
const LINE_PAUSE := 0.35
const OPEN_GRACE := 0.25
const ACCENT := Palette.GOLD
## The most lines a page shows (PAGED): longer ones go on to another page.
const MAX_LINES := 3
## What the box keeps around its words: the inset's margins, the face's frame and the room beside
## it (the words' width is the box's less this, before it is laid out).
const SIDE_ROOM := 32.0 + PORTRAIT + 32.0 + 14.0

var mode: Mode = Mode.PAGED
## Typing speed when the speaker gives none.
var letters_per_second := 45.0

var _speaker: SpeakerDef
## What is to be shown: [{text, accent}], one per page (PAGED) or per paragraph (STACKED).
var _pages: Array[Dictionary] = []
var _page := 0
var _letters := 0.0
var _pause := 0.0
var _age := 0.0
var _done := true
## Taps, clicks and accept, read the one way (TapGate: a touch and its click are one tap, the
## wheel is none).
var _gate := TapGate.new(TapGate.Keys.ACCEPT)

var _portrait: PixelPortrait
var _portrait_frame: PanelContainer
var _name: Label
var _title: Label
var _lines: VBoxContainer
var _more: Control
## Holds the accept key's cap (the cap shows and hides itself with the device; this, with the
## page).
var _more_key: Control
var _more_shown := false
var _current: Label
## The page on screen is written out and what follows it was done (the more sign, the next line).
var _page_written := false


func _init(box_mode: Mode = Mode.PAGED, width: float = 760.0) -> void:
	mode = box_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = width
	add_theme_stylebox_override("panel", UiSkin.inset())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_portrait_frame = PanelContainer.new()
	_portrait_frame.add_theme_stylebox_override("panel", UiSkin.plaque())
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_portrait_frame)
	_portrait = PixelPortrait.new(PORTRAIT)
	_portrait.name = "Portrait"
	_portrait_frame.add_child(_portrait)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(heading)
	_name = UiSkin.label("", Fonts.BODY, ACCENT)
	_name.name = "SpeakerName"
	heading.add_child(_name)
	_title = UiSkin.label("", Fonts.BODY, UiSkin.DIM)
	_title.name = "SpeakerTitle"
	heading.add_child(_title)
	_lines = VBoxContainer.new()
	_lines.name = "Lines"
	_lines.add_theme_constant_override("separation", 6)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_lines)
	# "More to read": a small arrow bobbing on touch, the accept key's cap on keys and gamepads.
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.custom_minimum_size.y = PromptGlyph.HEIGHT
	foot.visible = mode == Mode.PAGED  # stacked, nothing waits for a tap
	column.add_child(foot)
	_more = MoreArrow.new()
	_more.name = "More"
	foot.add_child(_more)
	_more_key = HBoxContainer.new()
	_more_key.name = "MoreKey"
	_more_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_more_key.add_child(PromptGlyph.make(&"ui_accept"))
	foot.add_child(_more_key)
	_set_more(false)


func _ready() -> void:
	InputDevice.changed.connect(func() -> void: _set_more(_more_shown))


## Says `spoken` (Dialogues.Spoken, one or more lines of one speaker: the first one's).
func say(spoken: Array[Dialogues.Spoken]) -> void:
	var pages: Array[Dictionary] = []
	var speaker: SpeakerDef = null
	for entry in spoken:
		if entry == null:
			continue
		if speaker == null:
			speaker = entry.speaker()
		if mode == Mode.STACKED:
			pages.append({"text": "\n".join(entry.pages), "accent": entry.accent})
		else:
			for page in entry.pages:
				for part in split_page(page, words_width(), UiSkin.reading_size()):
					pages.append({"text": part, "accent": entry.accent})
	say_pages(speaker, pages)


## How wide the words are: the box's width less its face and margins.
func words_width() -> float:
	var whole := size.x if size.x > 0.0 else custom_minimum_size.x
	return maxf(whole - SIDE_ROOM, 120.0)


## `text` wrapped at `width` (UI units) and `font_size` as a Label wraps it, cut into pieces of at
## most MAX_LINES lines (at line ends: whole words).
static func split_page(text: String, width: float, font_size: int) -> PackedStringArray:
	var paragraph := TextParagraph.new()
	paragraph.add_string(text, Fonts.MAIN, font_size)
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var count := paragraph.get_line_count()
	var parts := PackedStringArray()
	if count <= MAX_LINES:
		parts.append(text)
		return parts
	var start := 0
	for line in range(MAX_LINES - 1, count, MAX_LINES):
		var end := paragraph.get_line_range(line).y if line < count - 1 else text.length()
		parts.append(text.substr(start, end - start).strip_edges())
		start = end
	if start < text.length():
		var rest := text.substr(start).strip_edges()
		if not rest.is_empty():
			parts.append(rest)
	return parts


## Says `pages` ([{text, accent}], already translated) as `speaker`.
func say_pages(speaker: SpeakerDef, pages: Array[Dictionary]) -> void:
	_speaker = speaker
	_pages = pages
	_portrait.texture = speaker.portrait if speaker else null
	_portrait_frame.visible = _portrait.texture != null
	_name.text = tr(speaker.display_name) if speaker else ""
	_name.add_theme_color_override("font_color", speaker.color if speaker else ACCENT)
	_title.text = tr(speaker.title) if speaker and not speaker.title.is_empty() else ""
	_title.visible = not _title.text.is_empty()
	UiParts.clear(_lines)
	_current = null
	_page = -1
	_age = 0.0
	_done = pages.is_empty()
	if not _done:
		_start_page(0)
	_set_more(false)


## Still writing (a tap writes it out).
func is_typing() -> bool:
	return not _done and _current != null and _current.visible_characters >= 0 \
		and _current.visible_characters < _current.get_total_character_count()


## Everything was shown (and, paged, the last page read on).
func is_done() -> bool:
	return _done


## The page shown now (PAGED; -1 before the first).
func page_index() -> int:
	return _page


## Every word in the box (tests): its speaker's name and every line shown so far, whole.
func shown_text() -> String:
	var parts := PackedStringArray([_name.text])
	for child in _lines.get_children():
		parts.append((child as Label).text)
	return "\n".join(parts)


## A tap, a click, Enter or A seen by the box or by its screen (DialogueScreen's backdrop):
## true when it was the box's (the caller marks it handled). See advance().
func press(event: InputEvent) -> bool:
	var read := _gate.read(event, not _pages.is_empty() and not (mode == Mode.STACKED and _done))
	if read == TapGate.TAKE:
		advance()
	return read != TapGate.IGNORE


## Writes the page (STACKED: everything) out, else goes on to the next page,
## else it is over. False if it took nothing (STACKED and already written: the tap is not its).
func advance() -> bool:
	if _pages.is_empty() or (mode == Mode.STACKED and _done):
		return false
	if _age < OPEN_GRACE:
		return true  # a thumb still on the screen: not for it, but not for what is under it either
	if mode == Mode.STACKED:
		while _page < _pages.size() - 1:
			_current.visible_characters = -1
			_start_page(_page + 1, false)
		_current.visible_characters = -1
		_finish()
		return true
	if is_typing():
		_current.visible_characters = -1
		_page_written = true
		_set_more(true)
		return true
	if _page < _pages.size() - 1:
		_start_page(_page + 1)
		return true
	if not _done:
		_finish()
	return true


func _start_page(index: int, voice := true) -> void:
	_page = index
	if mode == Mode.PAGED:
		UiParts.clear(_lines)
	var page: Dictionary = _pages[index]
	_current = UiSkin.typed(UiSkin.label(str(page.text), UiSkin.reading_size(), ACCENT if page.accent else UiSkin.TEXT, true))
	_current.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_current.visible_characters = 0
	_lines.add_child(_current)
	_letters = 0.0
	_pause = 0.0
	_page_written = false
	_set_more(false)
	if is_inf(Settings.text_speed_factor()):
		_current.visible_characters = -1  # (the text speed "at once": written out, the voice still heard)
	if voice and _speaker and _speaker.voice:
		Sfx.play_ui(_speaker.voice, _speaker.voice_db)
	page_started.emit(index)


func _process(delta: float) -> void:
	_age += delta
	if _done or _current == null or not is_visible_in_tree():
		return
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			_start_page(_page + 1)
		return
	if is_typing():
		_letters += delta * (_speaker.letters_per_second if _speaker else letters_per_second) * Settings.text_speed_factor()
		_current.visible_characters = mini(int(_letters), _current.get_total_character_count())
		if is_typing():
			return
	if _page_written:
		return
	_page_written = true
	_current.visible_characters = -1
	if mode == Mode.STACKED:
		if _page < _pages.size() - 1:
			_pause = LINE_PAUSE
		else:
			_finish()
	else:
		_set_more(true)


func _finish() -> void:
	_done = true
	_set_more(false)
	finished.emit()


func _set_more(shown: bool) -> void:
	_more_shown = shown
	var buttons := InputDevice.uses_buttons()
	_more.visible = shown and not buttons
	_more_key.visible = shown and buttons


## Taps and clicks on the box.
func _gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and press(event):
		accept_event()


## Accept (Enter, Space, A) while it speaks: PAGED, always (it is what is on top); STACKED, only
## while it writes (then accept is the buttons' again). Only when its menu is the one on top.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey or event is InputEventJoypadButton):
		return
	var top := MenuNav.top_menu()
	if top != null and not top.is_ancestor_of(self):
		return
	if press(event):
		get_viewport().set_input_as_handled()


## The little arrow saying there is more: a gold triangle bobbing a pixel.
class MoreArrow extends Control:

	var _time := 0.0
	## Up or down a pixel (drawn again only when it changes).
	var _bob := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(16, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_READY:
			set_process(is_visible_in_tree())  # hidden, it costs nothing

	func _process(delta: float) -> void:
		_time += delta
		var bob := 2.0 if fmod(_time, 0.8) < 0.4 else 0.0
		if bob != _bob:
			_bob = bob
			queue_redraw()

	func _draw() -> void:
		var bob := _bob
		var points := PackedVector2Array([Vector2(2, 4 + bob), Vector2(14, 4 + bob), Vector2(8, 12 + bob)])
		draw_colored_polygon(points, Fonts.OUTLINE)
		var inner := PackedVector2Array([Vector2(4, 6 + bob), Vector2(12, 6 + bob), Vector2(8, 10 + bob)])
		draw_colored_polygon(inner, ACCENT)
