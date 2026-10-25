class_name CloudConflictDialog
extends RpgDialog
## "Two paths in the Well" (CloudSave's conflict): this device's profile and the account's online
## one both changed (or differ at a first sign-in). Each is summarised side by side (runs, souls,
## deepest floor, victories; the online one with when and from what it was saved), and the player
## keeps one; the other is replaced. No way out without choosing (Back does nothing): until then
## nothing is sent nor replaced. Shown by the title screen and the account dialog.
## Reachable as %KeepDeviceButton, %TakeOnlineButton, %DeviceSummary, %OnlineSummary.

const MenuNavScript := preload("res://src/autoload/menu_nav.gd")  # its static helpers are called on the script, not the autoload

## A choice made.
signal finished

const WIDTH := 900.0

var _device: Label
var _online: Label


func _init() -> void:
	super._init(TranslationServer.tr("Two paths in the Well"), WIDTH, 0.86)
	hide()


func _ready() -> void:
	var lore := UiSkin.label(tr("Two echoes of your soul answer the Well's call. Only one may go on."), Fonts.BODY, UiSkin.DIM, true)
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(lore)
	body.add_child(UiSkin.label(tr("This device and your account hold different progress. Choose the one to keep: the other is replaced by it."), Fonts.BODY, UiSkin.TEXT, true))
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 14)
	body.add_child(sides)
	_device = _side(sides, tr("This device"), "DeviceSummary")
	_online = _side(sides, tr("Online"), "OnlineSummary")
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	body.add_child(buttons)
	var keep := UiParts.button(tr("Keep this device's"), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		hide()
		await CloudSave.keep_this_device()
		finished.emit(), Vector2(0, 56), Fonts.BODY)
	keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(keep)
	MenuWindow.expose(keep, "KeepDeviceButton", self)
	var take := UiParts.button(tr("Take the online one"), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		hide()
		CloudSave.take_online()
		finished.emit(), Vector2(0, 56), Fonts.BODY)
	take.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(take)
	MenuWindow.expose(take, "TakeOnlineButton", self)
	MenuNavScript.set_first(self, keep)


func open() -> void:
	if CloudSave.state != CloudSave.Step.CONFLICT:
		return
	_device.text = describe(CloudSave.local_summary(), false)
	_online.text = describe(CloudSave.online_summary(), true)
	show()
	move_to_front()
	if InputDevice.uses_buttons():
		(get_node("%KeepDeviceButton") as Button).grab_focus.call_deferred()


## Back: a choice must be made.
func back() -> void:
	pass


## A profile's summary in words (`online`: with when and from what).
static func describe(summary: Dictionary, online: bool) -> String:
	var lines := PackedStringArray([
		TranslationServer.tr("Runs: %d") % int(summary.get("runs", 0)),
		TranslationServer.tr("Souls: %d") % int(summary.get("souls", 0)),
		TranslationServer.tr("Deepest floor: %d") % int(summary.get("depth", 0)),
		TranslationServer.tr("Victories: %d") % int(summary.get("victories", 0)),
	])
	if online:
		var at := int(summary.get("saved_at", 0))
		if at > 0:
			lines.append(TranslationServer.tr("Saved %s") % AccountDialog.when(at))
		var platform := str(summary.get("platform", ""))
		if not platform.is_empty():
			lines.append(TranslationServer.tr("From: %s") % platform)
	return "\n".join(lines)


func _side(row: HBoxContainer, title: String, node_name: String) -> Label:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	var head := UiSkin.label(title, Fonts.BODY, UiSkin.GOLD, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var words := UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	words.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # (built translated)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(words)
	MenuWindow.expose(words, node_name, self)
	return words
