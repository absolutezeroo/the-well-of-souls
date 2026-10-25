class_name ConsentDialog
extends RpgDialog
## The gameplay statistics' questions (Privacy; docs/privacy-ops.md): first a neutral age
## question (under the threshold, or at it and older: only that answer is kept, never an age;
## too young, the statistics stay off and the second question never comes), then the consent
## itself, in plain words: what is sent, to whom, for how long, how to change one's mind, and
## Decline and Accept side by side, the same size, neither one focused first (the policy's button
## is, for keys and gamepads). Closing it (Back) declines. Asked by the title screen the first
## time it shows (Privacy.should_ask()), and by the Options' switch.
## Reachable as %AgeUnder, %AgeOver, %Question, %DeclineButton, %AcceptButton, %PolicyButton,
## %PolicyPanel.

const MenuNavScript := preload("res://src/autoload/menu_nav.gd")  # its static helpers are called on the script, not the autoload

## Closed, whatever was answered.
signal finished

const WIDTH := 820.0

enum Step { AGE, CONSENT }

var step := Step.AGE
var policy: PrivacyPolicyPanel

var _question: Label


func _init() -> void:
	super._init("", WIDTH, 0.82)
	hide()


func _ready() -> void:
	policy = PrivacyPolicyPanel.new()
	add_child(policy)
	MenuWindow.expose(policy, "PolicyPanel", self)
	policy.closed.connect(func() -> void:
		var button := find_child("PolicyButton", true, false) as Button
		if button and InputDevice.uses_buttons():
			button.grab_focus())


## Asks what is needed: the age (unless already known to be old enough), then the consent.
func ask() -> void:
	if Privacy.needs_age():
		_show_age()
	else:
		_show_consent()
	show()


## Back: the policy first; otherwise closing declines.
func back() -> void:
	if policy.visible:
		policy.close()
		return
	Privacy.refuse()  # (closed without answering: as declined, asked again in 6 months)
	_close()


func _show_age() -> void:
	step = Step.AGE
	UiParts.clear(body)
	set_title(tr("Before you go down"))
	var age := Privacy.def.age_threshold
	_question = UiSkin.label(tr("How old are you?"), Fonts.BODY, UiSkin.GOLD, true)
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_question)
	MenuWindow.expose(_question, "Question", self)
	body.add_child(UiSkin.label(tr("Your answer only decides whether the game may ask you about gameplay statistics. Only \"under %d\" or \"%d or older\" is kept, on this device.") % [age, age], Fonts.BODY, UiSkin.TEXT, true))
	var under := _choice(tr("Under %d") % age, "AgeUnder", func() -> void:
		Privacy.answer_age(false)
		_close())
	var over := _choice(tr("%d or older") % age, "AgeOver", func() -> void:
		Privacy.answer_age(true)
		Sfx.play_ui(Sfx.bank.ui_click)
		_show_consent())
	_row([under, over])
	MenuNavScript.set_first(self, under)


func _show_consent() -> void:
	step = Step.CONSENT
	UiParts.clear(body)
	set_title(tr("Echoes of the Well"))
	_question = UiSkin.label(tr("Gameplay statistics (optional)"), Fonts.BODY, UiSkin.GOLD, true)
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_question)
	MenuWindow.expose(_question, "Question", self)
	body.add_child(UiSkin.label(Privacy.def.fill(tr("Help me balance the game! If you accept, at the end of each run, or when it is left or the app is closed, the game sends a summary of it to my provider Talo (servers in Germany): your build (weapons, armor, skills and their damage), potions, dodges, the cause and floor of your death, perks offered and picked, in-game purchases, boss fights, the kind of controls you use, plus the game version, the system and the screen size. It is linked to a random ID for this device, never to your name. Kept {months} months.")), Fonts.BODY, UiSkin.TEXT, true))
	body.add_child(UiSkin.label(tr("Your runs also add to the Well's Toll, the world counters every player sees (monsters slain, deaths, floors, endings...): only the sums of all players are shown."), Fonts.BODY, UiSkin.TEXT, true))
	body.add_child(UiSkin.label(tr("While the game is open, Talo also sees when your play sessions start and end (to count how long they last and how many players are online)."), Fonts.BODY, UiSkin.TEXT, true))
	body.add_child(UiSkin.label(tr("You can change your mind at any time in Options > Privacy. Refusing changes nothing in the game."), Fonts.BODY, UiSkin.DIM, true))
	var link := UiParts.button(tr("Privacy policy"), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		policy.open(), Vector2(260, 44), Fonts.BODY)
	link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(link)
	MenuWindow.expose(link, "PolicyButton", self)
	var decline := _choice(tr("Decline"), "DeclineButton", func() -> void:
		Privacy.refuse()
		_close())
	var accept := _choice(tr("Accept"), "AcceptButton", func() -> void:
		Privacy.grant()
		_close())
	_row([decline, accept])
	# Neither answer is focused first (the same weight): the policy's button is.
	MenuNavScript.set_first(self, link)


## A button of a pair: both the same size and look.
func _choice(text: String, node_name: String, action: Callable) -> Button:
	var button := UiParts.button(text, action, Vector2(0, 56), Fonts.BODY)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.name = node_name
	return button


func _row(buttons: Array[Button]) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for button in buttons:
		row.add_child(button)
	body.add_child(row)
	for button in buttons:
		MenuWindow.expose(button, button.name, self)


func _close() -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	hide()
	finished.emit()

