class_name RunDifficultyDialog
extends RpgDialog
## The pause menu's Difficulty (decision 0011): lowers the difficulty of the run in progress, never
## raises it. What it does in plain words (for this descent only, no records nor leaderboards from
## now on), then a button for each lower difficulty (RunState.lower_difficulties(), each with its
## description), and Back. A pick closes it and is said (`chosen`); the Game applies it.
## Reachable as %Lower_<id> (each difficulty's button) and %BackButton.

## A lower difficulty was picked for the run.
signal chosen(difficulty: DifficultyDef)
## Closed without a pick.
signal closed

const WIDTH := 640.0
const BUTTON_SIZE := Vector2(240, 54)


func _init() -> void:
	super._init(tr("Difficulty"), WIDTH, 0.8)
	hide()


## Shows the run's difficulty (`current`) and the lower ones it may go on at (`lower`).
func open(current: DifficultyDef, lower: Array[DifficultyDef]) -> void:
	UiParts.clear(body)
	var now := UiSkin.label(tr("This descent: %s") % current.shown_name(), Fonts.BODY, current.color, true)
	now.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(now)
	var rule := UiSkin.label(tr("Lower it for the rest of this descent only. It then sets no records and goes on no leaderboard; souls and achievements still count."), Fonts.BODY, UiSkin.TEXT, true)
	rule.custom_minimum_size.x = WIDTH - 60.0
	body.add_child(rule)
	if lower.is_empty():
		body.add_child(UiSkin.label(tr("Nothing is gentler than this."), Fonts.BODY, UiSkin.DIM, true))
	for each in lower:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		body.add_child(row)
		var pick := UiParts.button(each.shown_name(), func() -> void:
			Sfx.play_ui(Sfx.bank.ui_click)
			hide()
			chosen.emit(each), BUTTON_SIZE, Fonts.BODY)
		pick.add_theme_color_override("font_color", each.color)
		row.add_child(pick)
		MenuWindow.expose(pick, "Lower_%s" % each.id, self)
		var words := UiParts.text(tr(each.description), Fonts.BODY, UiSkin.DIM, WIDTH - 60.0 - BUTTON_SIZE.x - 14.0)
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(words)
	var back_button := UiParts.button(tr("Back"), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_close)
		back(), Vector2(200, 54), Fonts.BODY)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(back_button)
	MenuWindow.expose(back_button, "BackButton", self)
	show()


## Back, Escape, B: closes it, nothing changed.
func back() -> void:
	hide()
	closed.emit()
