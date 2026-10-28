class_name FirstRunTests
extends TestSuite
## The first minutes' hints: one line each, back when they ran out unread, read again in the
## codex's Tips. run_hints() on a fresh game of the game suite.


# --- Hints --------------------------------------------------------------------------------

## Every hint fits one line of the HintBox, in English and French, by touch, keys and gamepad, the
## board clear of the minimap; one that runs out unread comes back on a later floor (once), its
## chain with it; read ones are in the codex's Tips.
func run_hints(game: Game) -> void:
	var box := game.hint_box
	var minimap := game.hud.hint_target(&"Minimap")
	var screen := get_viewport().get_visible_rect()
	var long := PackedStringArray()
	for language in ["en", "fr"]:
		TranslationServer.set_locale(language)
		for kind in [InputDevice.Kind.TOUCH, InputDevice.Kind.KEYBOARD, InputDevice.Kind.GAMEPAD]:
			InputDevice.use(kind)
			for hint in CONTENT.tutorial.hints:
				box.show_hint(hint, Rect2())
				await _frames(1)
				var board := box.board_rect()
				if box.text_lines() != 1 or not screen.encloses(board) or (minimap.has_area() and board.end.x > minimap.position.x):
					long.append("%s/%d %s (%d lines, %s)" % [language, kind, hint.id, box.text_lines(), board])
	box.hide_hint()
	TranslationServer.set_locale("en")
	InputDevice.use(InputDevice.Kind.TOUCH)
	check(long.is_empty(), "every hint is one line, the board on screen and clear of the minimap: %s" % ", ".join(long.slice(0, 6)))
	# Run out unread: not seen, back on a later floor, then seen.
	var tutorial := game.tutorial
	Settings.tutorial_hints = true
	Profile.reset_hints()
	game.player.invincible = true
	var ambush := CONTENT.tutorial.hint(&"ambush")
	tutorial.cue(&"ambush")
	await _until(func() -> bool: return tutorial.current == ambush, 3.0)
	check(tutorial.current == ambush, "a hint shows")
	await _until(func() -> bool: return tutorial.current == null, ambush.duration + 1.0)
	check(not Profile.has_seen_hint(&"ambush"), "its time out, unread: not seen")
	tutorial.cue(&"ambush")
	await _frames(roundi((CONTENT.tutorial.gap + 0.5) * 60.0))
	check(tutorial.current != ambush, "not again on the same floor")
	game.world.floor_id += 1  # (another floor)
	tutorial.cue(&"ambush")
	await _until(func() -> bool: return tutorial.current == ambush, 3.0)
	check(tutorial.current == ambush, "back on a later floor")
	await _until(func() -> bool: return tutorial.current == null, ambush.duration + 1.0)
	check(Profile.has_seen_hint(&"ambush"), "run out again: now it counts as seen")
	# A chained hint (no cue of its own) that ran out comes back as a floor starts.
	Profile.mark_hint(&"move")
	tutorial.cue(&"monster_noticed")
	await _until(func() -> bool: return tutorial.current != null and tutorial.current.id == &"attack", 3.0)
	tutorial.action(&"attacked")
	check(Profile.has_seen_hint(&"attack"), "done: seen")
	var roll := CONTENT.tutorial.hint(&"roll")
	await _until(func() -> bool: return tutorial.current == roll, 3.0)
	check(tutorial.current == roll, "the next step of the chain shows")
	await _until(func() -> bool: return tutorial.current == null, roll.duration + 1.0)
	check(not Profile.has_seen_hint(&"roll"), "run out unread: not seen")
	game.world.floor_id += 1
	tutorial.cue(&"floor_start")
	await _until(func() -> bool: return tutorial.current == roll, 3.0)
	check(tutorial.current == roll, "the chain's step comes back as the next floor starts")
	tutorial.dismiss()
	check(Profile.has_seen_hint(&"roll"), "a tap: read, seen")
	Settings.tutorial_hints = false
	# The codex's Tips: the hints seen, and only those.
	var codex := (load("res://src/ui/codex/codex_panel.tscn") as PackedScene).instantiate() as CodexPanel
	add_child(codex)
	await _frames(1)
	codex.open(CONTENT, CodexPanel.Tab.TIPS)
	await _frames(1)
	var list := codex.get_node("%List")
	var shown := list.get_children().filter(func(n: Node) -> bool: return String(n.name).begins_with("Tip_")).map(func(n: Node) -> String: return String(n.name).trim_prefix("Tip_"))
	var seen := CONTENT.tutorial.hints.filter(func(h: HintDef) -> bool: return Profile.has_seen_hint(h.id)).map(func(h: HintDef) -> String: return String(h.id))
	check(shown == seen and seen.has("ambush") and seen.has("roll") and not shown.has("charge"), "the Tips tab lists the hints seen, and only those (%s)" % [shown])
	check((codex.get_node("%Summary") as Label).text == tr("Tips seen: %d of %d") % [seen.size(), CONTENT.tutorial.hints.size()], "...and says how many")
	codex.queue_free()
	Profile.reset_hints()
	game.player.invincible = false
	await _frames(1)
