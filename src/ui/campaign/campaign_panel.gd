class_name CampaignPanel
extends MenuWindow
## Campaign menus share the established game skin/navigation. Rows are rebuilt only on an
## explicit menu action; no polling or per-frame content allocations.

var rows: VBoxContainer
var note: Label


func _init() -> void:
	super._init(TranslationServer.tr("Campaign"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)
	note = UiSkin.label("", Fonts.BODY, UiSkin.TEXT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)


func clear(title_text: String) -> void:
	set_title(title_text)
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	note.text = ""


func words(text: String) -> Label:
	var label := UiSkin.label(text, Fonts.BODY, UiSkin.TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(label)
	return label


func action(text: String, callback: Callable, enabled: bool = true) -> Button:
	var entry := MenuWindow.button(text)
	entry.disabled = not enabled
	entry.pressed.connect(callback)
	rows.add_child(entry)
	return entry
