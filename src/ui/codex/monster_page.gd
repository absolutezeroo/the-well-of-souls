class_name MonsterPage
extends HBoxContainer
## One monster's page in the bestiary, in three dark insets. Left: its look (animated), name,
## what it is, where it lives, its Shiny. Middle: its attacks (tap one to watch it in the AttackPreview),
## how it behaves and its stats, each with what the number means. Right: your hunter rank with
## it (what each rank needs and pays) and its challenges (HuntChallenge). A monster
## only seen shows its look, ranks and challenges; slay one to learn the rest.
## A warden's middle column has two tabs: its attacks, and its Chronicle (ChronicleRows: the
## chapters of its story, its words, its fragments).

signal back_requested
## A found fragment is to be read again (the codex opens its panel).
signal fragment_requested(fragment: FragmentDef, boss: BossDef)

enum Middle { ATTACKS, CHRONICLE }

## (Wide enough for the longest word of a name at TITLE size: « L'Accapareur ».)
const LEFT_WIDTH := 376.0
const RIGHT_WIDTH := 294.0  # (with the left one, as wide as they were: 670)
const SHINY_COLOR := CodexCard.SHINY_COLOR
## The look at the top of the left column: a monster's art drawn this many times (a warden's
## smaller: it is bigger art), in a box at least LOOK_MIN_HEIGHT tall; art that would not fit
## LOOK_MAX_HEIGHT (or the column) at that scale is drawn smaller (MonsterPage._look()).
const MONSTER_LOOK_SCALE := 3.5
const BOSS_LOOK_SCALE := 2.2
const LOOK_MIN_HEIGHT := 104.0
const LOOK_MAX_HEIGHT := 220.0
const LOOK_PADDING := 6.0
## Art no taller than this (art pixels) is drawn at MONSTER_LOOK_SCALE, a warden's too.
const SMALL_ART := 24.0

## Painted rects of the frames' animations (art_rect()), read once.
static var _art_rects := {}

var _monster: MonsterDef
var _content: ContentDB
## The Nameless Keeper waiting now (his template built from Profile.keeper), whose weapon and blow
## the page shows instead of the template's stand-in; null for any other monster, or none waiting.
var _waiting_keeper: NamelessKeeperDef
var _preview: AttackPreview
var _attack_text: Label
var _attack_buttons: Array[Button] = []
## A warden's middle column: which tab, its buttons, and the box under them.
var _middle := Middle.ATTACKS
var _middle_tabs: Array[Button] = []
var _middle_body: VBoxContainer
var _rank := 0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 12)
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func show_monster(monster: MonsterDef, content: ContentDB) -> void:
	_monster = monster
	_content = content
	_waiting_keeper = null
	var keeper := monster as NamelessKeeperDef
	if keeper and KeeperSnapshot.is_valid(Profile.keeper):
		_waiting_keeper = keeper.build(KeeperSnapshot.new(Profile.keeper), content)
	clear()
	var rules := content.bestiary
	var rank := Bestiary.rank_of(monster, rules)
	_rank = rank
	_middle = Middle.ATTACKS
	add_child(_column(LEFT_WIDTH, _fill_identity.bind(rank, rules)))
	var middle := _column(0.0, _fill_middle)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(middle)
	add_child(_column(RIGHT_WIDTH, _fill_hunt.bind(rank, rules)))
	if rank >= 1:
		var attacks := _attacks()
		if not attacks.is_empty():
			_show_attack.call_deferred(attacks[0], 0)


## Every column back at its top. A page's first button is focused before its columns are laid
## out (they are new), and a list following the focus then scrolls by the button's height out of
## a box it measures as empty: the button ends up just above its column.
func scroll_to_top() -> void:
	for scroll: ScrollContainer in find_children("*", "ScrollContainer", true, false):
		scroll.scroll_vertical = 0


func clear() -> void:
	_preview = null
	_attack_buttons.clear()
	_middle_tabs.clear()
	_middle_body = null
	for child in get_children():
		remove_child(child)
		child.queue_free()


## A dark inset that scrolls with a finger, filled by `fill` (it gets the inner column).
func _column(width: float, fill: Callable) -> Control:
	var box := UiSkin.section()
	box.custom_minimum_size.x = width
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 12)  # room for the scroll bar
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	TouchScroll.attach(scroll)
	fill.call(column)
	return box


# --- Left: look, name, what it is --------------------------------------------------

func _fill_identity(column: VBoxContainer, rank: int, rules: BestiaryRules) -> void:
	var back := Button.new()
	back.text = tr("< All monsters")
	back.name = "BackButton"
	back.custom_minimum_size = Vector2(0, 46)
	back.add_theme_font_size_override("font_size", Fonts.BODY)
	back.pressed.connect(func() -> void: back_requested.emit())
	column.add_child(back)
	column.add_child(_look())
	# Wrapped: a long name in French ("Sentinelle de la Brèche") is wider than the column at TITLE.
	var name_label := UiSkin.label(tr(_monster.display_name), Fonts.TITLE, Palette.DANGER if _monster is BossDef else UiSkin.GOLD, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	var boss := _monster as BossDef
	if boss:
		var kind_label := UiSkin.label(tr("Boss  -  %s") % tr(boss.title) if not boss.title.is_empty() else tr("Boss"), Fonts.BODY, UiSkin.DIM, true)
		kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(kind_label)
	var kills := Profile.kill_count(_monster.id)
	var status := UiSkin.label(tr("%s  -  %d slain") % [Bestiary.rank_name(rank, rules), kills], Fonts.BODY, CodexRows.DONE if Bestiary.is_mastered(_monster, rules) else UiSkin.TEXT, true)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(status)
	if rank < 1:
		column.add_child(UiSkin.label(tr("You have seen it, but never slain one. Slay one to learn what it is, its stats and how it attacks."), Fonts.BODY, UiSkin.DIM, true))
		_add_shiny(column)
		return
	if not _monster.description.is_empty():
		column.add_child(UiSkin.reading_label(tr(_monster.description)))  # (bigger with Large text; the column scrolls)
	var home := _home()
	if not home.is_empty():
		column.add_child(CodexRows.fact(tr("Lives in"), home))
	_add_shiny(column)



## "Act I, floors 1 to 3" (bosses: "Act I, floor 3"): where it first shows up.
func _home() -> String:
	var acts := _content.dungeon.acts
	for i in acts.size():
		var act := acts[i]
		var first := _content.dungeon.first_depth(i)
		var last := first + act.floors - 1
		# A typed Array[BossDef] can't be asked about a plain monster (engine error).
		if _monster is BossDef and act.all_bosses().has(_monster):
			return tr("%s, floor %d") % [tr(act.subtitle), last]
		if act.monsters.has(_monster):
			if act.floors <= 1:
				return tr("%s, floor %d") % [tr(act.subtitle), first]
			return tr("%s, floors %d to %d") % [tr(act.subtitle), first, last]
	var hidden_def := _content.dungeon.hidden_floor
	if hidden_def and hidden_def.boss == _monster:
		return tr(hidden_def.title)
	var finale := _content.dungeon.finale
	if finale and finale.all_bosses().any(func(form: BossDef) -> bool: return form == _monster):
		return tr(finale.title)
	if _content.abyss_monsters().has(_monster):
		return tr(_content.dungeon.abyss.display_name)
	return ""


## [name, value, what it means] for Health, Damage, Armor and Move speed.
func _stats() -> Array[Array]:
	var stats := _monster.stats
	var weapon := _monster.weapon
	var hero := _content.player.base_stats if _content.player else null
	var health := stats.max_hp if stats else 0
	var damage := weapon.damage if weapon else 0
	if _monster is NamelessKeeperDef:
		damage = _keeper_blow()
	var armor := stats.defense if stats else 0
	var speed := roundi(stats.move_speed) if stats else 0
	var health_note := tr("How much damage it takes to slay it.")
	var damage_note := tr("Health you lose when its basic attack hits you.")
	if hero:
		damage_note += " " + tr("You start a run with %d Health.") % hero.max_hp
	var armor_note := tr("Softens your hits, small ones most: a 10-damage hit does %d, a 30-damage hit %d.") % [Combat.mitigate(10, armor), Combat.mitigate(30, armor)] if armor > 0 else tr("None: your hits land in full.")
	var speed_note := tr("How fast it walks.")
	if hero and stats:
		var ratio := stats.move_speed / maxf(hero.move_speed, 1.0)
		speed_note = tr("Slower than you (%d).") % roundi(hero.move_speed)
		if ratio > 1.08:
			speed_note = tr("Faster than you (%d): you can't outrun it.") % roundi(hero.move_speed)
		elif ratio > 0.92:
			speed_note = tr("About as fast as you (%d).") % roundi(hero.move_speed)
	return [
		[tr("Health"), str(health), health_note],
		[tr("Damage"), str(damage), damage_note],
		[tr("Armor"), str(armor), armor_note],
		[tr("Move speed"), str(speed), speed_note],
	]


## The monster, big and moving (unknown ones as a shadow), dressed as it is in a fight (the
## Nameless Keeper a dark shade: MonsterTrait.dress_look()). Its box is as tall as its art drawn
## at its scale (LOOK_MIN_HEIGHT at least); art too big for LOOK_MAX_HEIGHT or the column's width
## is drawn smaller (the Maw, the Gilded Hoarder), so every monster shows whole.
func _look() -> Control:
	var width := LEFT_WIDTH - 44
	var box := Control.new()
	box.name = "LookBox"
	box.clip_contents = true
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Look"
	sprite.sprite_frames = _monster.frames
	sprite.offset = _monster.frames_offset
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	AttackPreview._play_anim(sprite, [&"walk_down", &"idle_down", &"walk", &"idle"])
	var art := art_rect(sprite.sprite_frames, sprite.animation, sprite.offset)
	var room := Vector2(width, LOOK_MAX_HEIGHT) - Vector2.ONE * LOOK_PADDING * 2.0
	# (A warden on a common body's art, the Nameless Keeper on the hero's, is drawn as big as one.)
	var big := _monster is BossDef and art.size.y > SMALL_ART
	var look_scale := minf(BOSS_LOOK_SCALE if big else MONSTER_LOOK_SCALE, minf(room.x / art.size.x, room.y / art.size.y))
	var height := maxf(LOOK_MIN_HEIGHT, ceilf(art.size.y * look_scale + LOOK_PADDING * 2.0))
	box.custom_minimum_size = Vector2(width, height)
	sprite.scale = Vector2.ONE * look_scale
	# The art's middle in the box's middle (on a whole UI pixel).
	sprite.position = (Vector2(width, height) * 0.5 - art.get_center() * look_scale).round()
	for monster_trait in _monster.traits:
		if monster_trait:
			monster_trait.dress_look(sprite)
	if Bestiary.rank_of(_monster, _content.bestiary) == Bestiary.UNSEEN:
		sprite.modulate = Color(0, 0, 0, 0.8)
	box.add_child(sprite)
	return box


## Where the look's art is drawn on screen (its frames' painted pixels, in the viewport's
## coordinates), and the box it is drawn in: the art must stay inside (a check in the title
## suite). Empty rects before a page is shown.
func look_rects() -> Array[Rect2]:
	var box := find_child("LookBox", true, false) as Control
	var sprite := box.get_node_or_null("Look") as AnimatedSprite2D if box else null
	if sprite == null:
		return [Rect2(), Rect2()]
	var art := art_rect(sprite.sprite_frames, sprite.animation, sprite.offset)
	return [sprite.get_global_transform() * art, box.get_global_rect()]


## The pixels painted in any frame of `animation` (a bob, a breath: all of them), in the
## sprite's own coordinates (centered, moved by `offset`); a 16x16 square without frames.
## Read from the frames' images once per animation.
static func art_rect(frames: SpriteFrames, animation: StringName, offset: Vector2) -> Rect2:
	if frames == null or not frames.has_animation(animation) or frames.get_frame_count(animation) == 0:
		return Rect2(offset - Vector2(8, 8), Vector2(16, 16))
	var key := "%d/%s" % [frames.get_instance_id(), animation]
	if not _art_rects.has(key):
		var used := Rect2()
		var frame_size := Vector2.ZERO
		for i in frames.get_frame_count(animation):
			var texture := frames.get_frame_texture(animation, i)
			if texture == null:
				continue
			frame_size = texture.get_size()
			var image := texture.get_image()
			var painted := Rect2(image.get_used_rect()) if image else Rect2(Vector2.ZERO, frame_size)
			if painted.has_area():
				used = painted if not used.has_area() else used.merge(painted)
		if not used.has_area():
			used = Rect2(Vector2.ZERO, frame_size if frame_size != Vector2.ZERO else Vector2(16, 16))
		_art_rects[key] = Rect2(used.position - frame_size * 0.5, used.size)
	var rect: Rect2 = _art_rects[key]
	return Rect2(rect.position + offset, rect.size)


# --- Middle: how it fights, a warden's chronicle --------------------------------------

## The attacks; for a warden with a chronicle, two tabs above them: Attacks and Chronicle.
func _fill_middle(column: VBoxContainer) -> void:
	var boss := _monster as BossDef
	if boss == null or boss.chronicle == null:
		_fill_attacks(column, _rank)
		return
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	for entry: Array in [[Middle.ATTACKS, tr("Attacks"), "AttacksTab"], [Middle.CHRONICLE, tr("Chronicle"), "ChronicleTab"]]:
		var button := Button.new()
		button.text = entry[1]
		button.name = entry[2]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(150, 44)
		button.add_theme_font_size_override("font_size", Fonts.BODY)
		button.pressed.connect(show_middle.bind(entry[0]))
		tabs.add_child(button)
		_middle_tabs.append(button)
	_middle_body = VBoxContainer.new()
	_middle_body.add_theme_constant_override("separation", 6)
	column.add_child(_middle_body)
	show_middle(_middle)


## A warden's page: shows its attacks or its chronicle.
func show_middle(which: int) -> void:
	_middle = which as Middle
	for i in _middle_tabs.size():
		_middle_tabs[i].set_pressed_no_signal(i == which)
	if _middle_body == null:
		return
	_preview = null
	_attack_buttons.clear()
	for child in _middle_body.get_children():
		_middle_body.remove_child(child)
		child.queue_free()
	if _middle == Middle.CHRONICLE:
		if _rank == Bestiary.UNSEEN:
			_middle_body.add_child(UiSkin.label(tr("Meet it to begin its chronicle."), Fonts.BODY, UiSkin.DIM, true))
		else:
			ChronicleRows.fill(_middle_body, _monster as BossDef, _content, func(fragment: FragmentDef, boss: BossDef) -> void:
				fragment_requested.emit(fragment, boss))
	else:
		_fill_attacks(_middle_body, _rank)
		var attacks := _attacks()
		if _rank >= 1 and not attacks.is_empty():
			_show_attack.call_deferred(attacks[0], 0)

func _fill_attacks(column: VBoxContainer, rank: int) -> void:
	column.add_child(_heading(tr("Attacks")))
	if rank < 1:
		column.add_child(UiSkin.label(tr("Slay one to see how it attacks."), Fonts.BODY, UiSkin.DIM, true))
		return
	column.add_child(UiSkin.label(tr("Choose an attack to watch it. Red marks on the ground show where it will land: step out!"), Fonts.BODY, UiSkin.DIM, true))
	_preview = AttackPreview.new()
	_preview.custom_minimum_size = Vector2(0, 184)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_preview)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	column.add_child(row)
	var attacks := _attacks()
	for i in attacks.size():
		var button := Button.new()
		button.text = attacks[i].name
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 44)
		button.add_theme_font_size_override("font_size", Fonts.BODY)
		button.pressed.connect(_show_attack.bind(attacks[i], i))
		row.add_child(button)
		_attack_buttons.append(button)
	_attack_text = UiSkin.label("", Fonts.BODY, UiSkin.TEXT, true)
	column.add_child(_attack_text)
	var ways := _ways()
	if not ways.is_empty():
		column.add_child(_heading(tr("How it behaves")))
		for line in ways:
			column.add_child(UiSkin.label("-  " + line, Fonts.BODY, UiSkin.TEXT, true))
	column.add_child(_heading(tr("Stats")))
	column.add_child(UiSkin.label(tr("On the floors where it first shows up: deeper down, it grows stronger."), Fonts.BODY, UiSkin.DIM, true))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	for line in _stats():
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		cell.add_child(CodexRows.fact(line[0], line[1], UiSkin.GOLD))
		cell.add_child(UiSkin.label(line[2], Fonts.BODY, UiSkin.DIM, true))
		grid.add_child(cell)


## The Nameless Keeper's blow before the floor's rules: his weapon's damage and his attack
## together (NamelessKeeperDef.blow_power, more for a finer weapon); none waiting, the template's.
func _keeper_blow() -> int:
	if _waiting_keeper:
		var weapon_damage := _waiting_keeper.weapon.damage if _waiting_keeper.weapon else 0
		return weapon_damage + _waiting_keeper.stats.attack
	return (_monster as NamelessKeeperDef).blow_power


## Its basic attack, its skills, and a boss' phase skills: [{ name, attack, text }].
func _attacks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var weapon := _monster.weapon
	if _monster is NamelessKeeperDef:
		# Not the template's stand-in: the weapon of the hero he was (none waiting: said so).
		if _waiting_keeper and _waiting_keeper.weapon:
			var his := _waiting_keeper.weapon
			result.append({ "name": tr(his.display_name), "attack": his, "text": tr("Basic attack: the weapon he carried as a hero, %d damage.") % _keeper_blow() })
		elif weapon:
			result.append({ "name": tr("Your weapon"), "attack": weapon, "text": tr("Basic attack: the weapon you carried as a hero, %d damage.") % _keeper_blow() })
		weapon = null
	if weapon:
		var how := tr("Up close")
		if weapon.kind == WeaponDef.Kind.RANGED:
			how = tr("Shoots %d at once, from afar") % weapon.projectile_count if weapon.projectile_count > 1 else tr("Shoots from afar")
		elif weapon.reach >= 40.0:
			how = tr("Up close, with a long reach")
		result.append({ "name": tr(weapon.display_name) if not weapon.display_name.is_empty() else tr("Attack"), "attack": weapon, "text": tr("Basic attack. %s: %d damage.") % [how, weapon.damage] })
	var skills: Array[SkillDef] = []
	for skill in _monster.skills:
		if skill and not skills.has(skill):
			skills.append(skill)
	var boss := _monster as BossDef
	var phase_of := {}
	if boss:
		for p in boss.phases.size():
			for skill in boss.phases[p].skills:
				if skill and not skills.has(skill):
					skills.append(skill)
					phase_of[skill] = p + 2
	var names := {}
	for skill in skills:
		var text := tr(skill.description) if not skill.description.is_empty() else ""
		text += (" " if not text.is_empty() else "") + tr("Used every %.0f seconds.") % skill.cooldown
		var skill_name := tr(skill.display_name)
		if phase_of.has(skill):
			text = tr("From phase %d. %s") % [phase_of[skill], text]
			if names.has(skill_name):
				# Its fiercer form; on a line of its own, so a long French name (« Cercle des
				# Lamentations (phase 3) ») never makes the column wider than the screen.
				skill_name += "\n" + tr("(phase %d)") % phase_of[skill]
		names[tr(skill.display_name)] = true
		result.append({ "name": skill_name, "attack": skill, "text": text })
	return result


func _show_attack(attack: Dictionary, index: int) -> void:
	if _preview == null or not is_instance_valid(_preview):
		return
	for i in _attack_buttons.size():
		_attack_buttons[i].set_pressed_no_signal(i == index)
	_attack_text.text = attack.text
	var hero_frames := _content.player.frames if _content.player else null
	_preview.play(_monster, attack.attack, hero_frames)


## How it behaves, in a few lines.
func _ways() -> PackedStringArray:
	var lines := PackedStringArray()
	if _monster.flies:
		lines.append(tr("Flies: holes and water don't stop it."))
	if _monster.keep_distance > 0.0:
		lines.append(tr("Keeps its distance: close in on it."))
	if _monster.knockback_resistance >= 0.5:
		lines.append(tr("Hard to push around (or into holes)."))
	for monster_trait in _monster.traits:
		if monster_trait and not monster_trait.describe().is_empty():
			lines.append(monster_trait.describe())
	var boss := _monster as BossDef
	if boss:
		if not boss.phases.is_empty():
			var at := PackedStringArray()
			for phase in boss.phases:
				at.append(tr("%d%%") % roundi(phase.hp_ratio * 100.0))
			lines.append(tr("Fights in %d phases: stronger and faster once its Health drops to %s.") % [boss.phases.size() + 1, tr(", then ").join(at)])
		if boss.shockwave_after_hits > 0:
			lines.append(tr("Hit it too many times in a row and it throws you off with a shockwave."))
	return lines


# --- Right: your hunt ------------------------------------------------------------------

## The Shiny: a rare glowing one of this kind, found (slain) or not yet. Nothing for a kind that
## can never come Celestial (Bestiary.can_be_celestial(): Tôma, the Maw, the Nameless Keeper,
## the Deeps' demons), unless one was found anyway (an older game's).
func _add_shiny(column: VBoxContainer) -> void:
	if not Bestiary.can_be_celestial(_monster, _content) and not Profile.has_shiny(_monster.id):
		return
	column.add_child(_heading(tr("Celestial")))
	var found := Profile.has_shiny(_monster.id)
	column.add_child(_goal_row(found, tr("Found!") if found else tr("Not found yet"), ""))
	column.add_child(UiSkin.label(tr("A rare glowing version%s: tougher, but it drops plenty of loot and gold. Slay one to add it to your collection.") % _shiny_odds(), Fonts.BODY, UiSkin.DIM, true))


## " (about 1 in 400)", from the Shiny rank's chance ("" if there is none).
func _shiny_odds() -> String:
	for rank in _content.dungeon.rare_ranks:
		if rank and rank.shimmer:
			var chance := rank.boss_chance if _monster is BossDef else rank.chance
			return tr(" (about 1 in %d)") % roundi(1.0 / chance) if chance > 0.0 else ""
	return ""


func _fill_hunt(column: VBoxContainer, rank: int, rules: BestiaryRules) -> void:
	var kills := Profile.kill_count(_monster.id)
	column.add_child(_heading(tr("Hunter rank")))
	column.add_child(UiSkin.label(tr("Slay more of this kind to rank up. Each rank pays its souls once."), Fonts.BODY, UiSkin.DIM, true))
	var thresholds := rules.kills_for(_monster)
	var souls := rules.souls_for(_monster)
	for i in thresholds.size():
		var reward := CodexRows.souls(souls[i]) if i < souls.size() else ""
		var extra := ""
		if i == thresholds.size() - 1:
			extra = tr("and +%d%% damage to this kind, for good") % roundi(rules.mastery_damage * 100.0)
		column.add_child(_goal_row(rank > i, tr("%s: slay %d") % [tr(rules.rank_names[i]), thresholds[i]], reward, extra))
	var next := Bestiary.next_kills(_monster, rules)
	if next > 0:
		column.add_child(CodexRows.bar(kills, next, tr("%d / %d slain, to %s") % [kills, next, Bestiary.rank_name(maxi(rank, 0) + 1, rules)]))
	else:
		column.add_child(CodexRows.bar(1, 1, tr("Mastered!")))

	var challenges := rules.challenges_for(_monster)
	if not challenges.is_empty():
		column.add_child(_heading(tr("Challenges")))
		column.add_child(UiSkin.label(tr("Slay it in a special way. Each one pays its souls once."), Fonts.BODY, UiSkin.DIM, true))
		for challenge in challenges:
			column.add_child(_goal_row(Profile.is_challenge_done(_monster.id, challenge.id), challenge.describe(_monster), CodexRows.souls(challenge.souls)))



## A goal with its mark: done or not, what to do, the souls it pays (and what else).
func _goal_row(done: bool, text: String, reward: String, extra := "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(CodexRows.check(done, false))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	words.add_child(UiSkin.label(text, Fonts.BODY, CodexRows.DONE if done else UiSkin.TEXT, true))
	# The souls under the goal, not beside it: the column is narrow, and a goal squeezed beside its
	# souls would break inside its words.
	if not reward.is_empty():
		words.add_child(UiSkin.label(reward, Fonts.BODY, CodexRows.SOUL, true))
	if not extra.is_empty():
		words.add_child(UiSkin.label(extra, Fonts.BODY, CodexRows.SOUL, true))
	return row


func _heading(text: String) -> Label:
	var label := UiSkin.label(text, Fonts.BODY, UiSkin.GOLD)
	label.custom_minimum_size.y = 28
	return label
