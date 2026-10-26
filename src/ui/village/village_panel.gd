class_name VillagePanel
extends RpgWindow
## A scrollable conversation/service/register presenter. Only emits choices to its owner.

signal picked(action: StringName, payload: Resource)
var list: VBoxContainer
var words: Label


func _init() -> void:
	super("")
	var scroll := UiParts.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)
	close_requested.connect(hide)
	hide()


func open(heading: String, message: String) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	set_title(heading)
	words = UiSkin.label(message, Fonts.BODY, UiSkin.TEXT, true)
	list.add_child(words)
	show()
	close_button.grab_focus()


func choice(label_text: String, action: StringName, payload: Resource = null, enabled: bool = true) -> Button:
	var button := MenuWindow.button(label_text, Fonts.BODY, 56)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.disabled = not enabled
	button.pressed.connect(func() -> void: picked.emit(action, payload))
	list.add_child(button)
	return button
