class_name AttackPreview
extends Control
## A little stage in the bestiary that plays one of a monster's attacks on a loop, the way it
## comes in a fight: the warning first (the same red telegraph), then what it does (shots
## flying, a blast, a charge, summons, a heal...), toward a stand-in hero. Built from the
## attack's data (WeaponDef or SkillDef and its effects), so new attacks show up by themselves.
## Runs while the game is paused (the codex opens from the pause menu).

## The stage is drawn at this many screen pixels per world pixel, at most.
const MAX_SCALE := 1.0
## World pixels between the monster and the stand-in hero.
const GAP := 330.0
const LOOP := 3.0
## At most this share of the stage's height for the monster's art.
const STAGE_ART_SHARE := 0.8
const START := 0.35
const FLOOR_COLOR := Color(0.12, 0.1, 0.14)
const GRID_COLOR := Color(1, 1, 1, 0.04)
const SHOT_COLOR := Color(1.0, 0.75, 0.35)

## The stage as an effect sees it (Effect.play_preview()): its strokes drawn here.
class Strokes:
	extends EffectPreview
	var _preview: AttackPreview

	func _init(preview: AttackPreview) -> void:
		_preview = preview

	func caster_radius() -> float:
		return _preview._monster.radius

	func shots(count: int, spread: float, speed: float, distance: float, radius: float, color: Color, blast: float, sheet: VfxSheetDef, element: VfxElementDef, aim: float) -> void:
		_preview._fire(count, spread, speed, distance, radius, color, blast, sheet, element, aim)

	func ring(forward: float, radius: float, color: Color, filled: bool) -> void:
		_preview._ring(_preview._sprite.position + Vector2.RIGHT * forward, radius, color, filled)

	func lunge(distance: float, duration: float) -> void:
		_preview._lunge(distance, duration)

	func line(distance: float, width: float, color: Color) -> void:
		_preview._arcs.append({ "line": distance, "width": width, "color": color, "age": 0.0 })

	func summon(summon_effect: SummonEffect) -> void:
		_preview._summon(summon_effect)


var _monster: MonsterDef
var _attack: Resource
var _time := 0.0
var _released := false
var _pending: Array = []  # [seconds after the release, Effect]
var _shots: Array[Dictionary] = []
var _arcs: Array[Dictionary] = []
var _extras: Array[Node] = []

var _stage := Node2D.new()
var _overlay := Node2D.new()
var _telegraph := TelegraphView.new()
## What the effects play on (Strokes).
var _strokes := Strokes.new(self)
var _sprite := AnimatedSprite2D.new()
var _hero := AnimatedSprite2D.new()
var _home := Vector2.ZERO
var _target := Vector2.ZERO


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(640, 240)
	add_child(_stage)
	_stage.add_child(_telegraph)
	_stage.add_child(_hero)
	_stage.add_child(_sprite)
	_stage.add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)
	for sprite in [_sprite, _hero]:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(_layout)


## Plays `attack` (the monster's WeaponDef or one of its SkillDefs) of `monster`, against a
## stand-in drawn with `hero_frames`.
func play(monster: MonsterDef, attack: Resource, hero_frames: SpriteFrames) -> void:
	_monster = monster
	_attack = attack
	_sprite.sprite_frames = monster.frames
	_sprite.offset = monster.frames_offset
	# Dressed as in a fight (the Nameless Keeper's shade and lantern: MonsterTrait.dress_look).
	_sprite.material = null
	for child in _sprite.get_children():
		_sprite.remove_child(child)
		child.queue_free()
	for monster_trait in monster.traits:
		if monster_trait:
			monster_trait.dress_look(_sprite)
	_hero.sprite_frames = hero_frames
	_play_anim(_hero, [&"idle_left", &"idle_down", &"idle"])
	_hero.modulate = Color(1, 1, 1, 0.75)
	_layout()
	_restart()


func _layout() -> void:
	if _monster == null:
		return
	var scale_factor := minf(MAX_SCALE, size.x / (GAP + 260.0))
	_stage.scale = Vector2.ONE * scale_factor
	var world_size := size / scale_factor
	_home = Vector2(world_size.x * 0.5 - GAP * 0.5, world_size.y * 0.58)
	_target = _home + Vector2(GAP, 0)
	var body := 3.0 if not _monster is BossDef else 2.2
	# A warden too tall for the stage at that scale (the Maw) is drawn smaller: whole.
	var art := MonsterPage.art_rect(_sprite.sprite_frames, &"idle_right" if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(&"idle_right") else &"idle", _sprite.offset)
	if art.size.y <= MonsterPage.SMALL_ART:
		body = 3.0  # (a warden on a common body's art: as big as one)
	if world_size.y > 0.0:
		body = minf(body, world_size.y * STAGE_ART_SHARE / maxf(art.size.y, 1.0))
		# Its feet low enough that its head stays on the stage (a big warden stands taller).
		var margin := world_size.y * (1.0 - STAGE_ART_SHARE) * 0.5
		var lowest := world_size.y - margin - art.end.y * body
		_home.y = minf(maxf(_home.y, margin - art.position.y * body), maxf(lowest, _home.y))
		_target = _home + Vector2(GAP, 0)
	_sprite.scale = Vector2.ONE * body
	_hero.scale = Vector2.ONE * 3.0
	_hero.position = _target
	_restart()


func _restart() -> void:
	_time = 0.0
	_released = false
	_pending.clear()
	_shots.clear()
	_arcs.clear()
	for node in _extras:
		if is_instance_valid(node):
			node.queue_free()
	_extras.clear()
	_sprite.position = _home
	_sprite.modulate = Color.WHITE
	_telegraph.visible = false
	_play_anim(_sprite, [&"idle_right", &"idle", &"idle_down", &"walk_right", &"walk"])
	queue_redraw()


func _process(delta: float) -> void:
	if _monster == null or not is_visible_in_tree():
		return
	_time += delta
	var warning := _warning_time()
	if not _released:
		if _time >= START:
			_show_warning(clampf((_time - START) / maxf(warning, 0.001), 0.0, 1.0))
		if _time >= START + warning:
			_release()
	else:
		var since := _time - START - warning
		for entry in _pending.duplicate():
			if since >= entry[0]:
				_pending.erase(entry)
				_apply(entry[1])
	_move_shots(delta)
	for arc in _arcs:
		arc.age += delta
	_arcs = _arcs.filter(func(arc: Dictionary) -> bool: return arc.age < 0.3)
	_overlay.queue_redraw()
	if _time >= LOOP + warning:
		_restart()


## The wind-up as it comes in a fight on Keeper: its own, never under the fairness floor
## (SkillDef.monster_cast_time(), CombatRulesDef.monster_windup(): decision 0008).
func _warning_time() -> float:
	return warning_time(_monster, _attack)


## How long `attack` (a WeaponDef or a SkillDef) of `monster` warns on Keeper (tests).
static func warning_time(monster: MonsterDef, attack: Resource) -> float:
	var boss := monster is BossDef
	if attack is SkillDef:
		return (attack as SkillDef).monster_cast_time(1.0, boss)
	return Combat.RULES.monster_windup(monster.attack_windup, boss)


# --- The warning ----------------------------------------------------------------

func _show_warning(progress: float) -> void:
	_telegraph.position = _home
	var aim := 0.0
	if _attack is SkillDef:
		var skill := _attack as SkillDef
		_play_anim(_sprite, [&"cast", &"idle_right", &"idle"])
		# The game's own warning (TelegraphView.show_skill), around the preview's monster.
		_telegraph.position = Vector2.ZERO
		var first: Effect = skill.effects[0] if not skill.effects.is_empty() else null
		# (a kind may draw one here the game doesn't: Effect.show_preview_warning())
		var own := first != null and first.show_preview_warning(_telegraph, aim, progress)
		if not own and not _telegraph.show_skill(skill, aim, progress, _monster.radius):
			_telegraph.show_shape(TelegraphView.Shape.CIRCLE, _monster.radius + 30.0, aim, progress)
		_telegraph.position += _home
		return
	var weapon := _attack as WeaponDef
	if weapon == null:
		return
	if weapon.kind == WeaponDef.Kind.MELEE:
		var reach := _monster.radius + weapon.reach
		if weapon.arc_degrees >= 359.0:
			_telegraph.show_shape(TelegraphView.Shape.CIRCLE, reach, aim, progress)
		else:
			_telegraph.show_shape(TelegraphView.Shape.CONE, reach, aim, progress, deg_to_rad(weapon.arc_degrees) * 0.5)
	else:
		# The path of its shots as far as they fly, as in a fight (MonsterOverlay).
		_telegraph.show_shots(weapon.reach, aim, progress, weapon.projectile_count, weapon.spread_degrees, weapon.projectile_radius, _monster.radius)


# --- What it does ------------------------------------------------------------------

func _release() -> void:
	_released = true
	_telegraph.visible = false
	_play_anim(_sprite, [&"walk_right", &"walk", &"idle_right", &"idle"])
	if _attack is SkillDef:
		for effect in (_attack as SkillDef).effects:
			if effect:
				_pending.append([effect.delay, effect])
	elif _attack is WeaponDef:
		var weapon := _attack as WeaponDef
		if weapon.kind == WeaponDef.Kind.MELEE:
			_arcs.append({ "radius": _monster.radius + weapon.reach, "half": deg_to_rad(weapon.arc_degrees) * 0.5, "color": weapon.trail_color, "age": 0.0 })
			_lunge(14.0, 0.1)
		else:
			_fire(weapon.projectile_count, weapon.spread_degrees, weapon.projectile_speed, maxf(weapon.reach, GAP + 40.0), weapon.projectile_radius, weapon.element.color() if weapon.element else SHOT_COLOR, 0.0, weapon.projectile_sheet if weapon.projectile_sheet else EffectPreview.shot_sheet(weapon.projectile_texture, weapon.projectile_frames, weapon.element), weapon.element)


## What `effect` does, as it says (Effect.play_preview()) on this stage.
func _apply(effect: Effect) -> void:
	effect.play_preview(_strokes)


func _fire(count: int, spread: float, speed: float, distance: float, radius: float, color: Color, blast: float, sheet: VfxSheetDef, element: VfxElementDef, aim: float = 0.0) -> void:
	count = maxi(count, 1)
	for i in count:
		var angle := 0.0
		if spread >= 360.0:
			angle = 360.0 * i / count
		elif count > 1:
			angle = lerpf(-spread * 0.5, spread * 0.5, float(i) / (count - 1))
		var direction := Vector2.RIGHT.rotated(aim + deg_to_rad(angle))
		_shots.append({
			"pos": _sprite.position + direction * _monster.radius,
			"vel": direction * maxf(speed, 120.0),
			"left": distance,
			"radius": maxf(radius, 4.0),
			"color": color,
			"blast": blast,
			"sheet": sheet,
			"element": element,
		})


func _move_shots(delta: float) -> void:
	for shot in _shots.duplicate():
		var step: Vector2 = shot.vel * delta
		shot.pos += step
		shot.left -= step.length()
		if shot.left <= 0.0:
			_shots.erase(shot)
			if shot.blast > 0.0:
				_ring(shot.pos, shot.blast, shot.color, true)


func _lunge(distance: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "position", _home + Vector2.RIGHT * distance, maxf(duration, 0.08))
	tween.tween_interval(0.35)
	tween.tween_property(_sprite, "position", _home, 0.3)


func _summon(summon: SummonEffect) -> void:
	var kind: MonsterDef = summon.monsters[0] if not summon.monsters.is_empty() else null
	if kind == null or kind.frames == null:
		return
	for i in mini(summon.count, 6):
		var minion := AnimatedSprite2D.new()
		minion.sprite_frames = kind.frames
		minion.offset = kind.frames_offset
		minion.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		minion.scale = Vector2.ONE * 1.6
		minion.position = _home + Vector2.from_angle(TAU * i / mini(summon.count, 6) + 0.4) * minf(summon.radius, 90.0)
		minion.modulate.a = 0.0
		_play_anim(minion, [&"idle_down", &"idle", &"walk_down"])
		_stage.add_child(minion)
		_extras.append(minion)
		minion.create_tween().tween_property(minion, "modulate:a", 1.0, 0.3)
		_ring(minion.position, 18.0, Color(0.8, 0.6, 1.0), false)


func _ring(at: Vector2, radius: float, color: Color, filled: bool) -> void:
	var ring := RingVfx.create(at, radius, color)
	_stage.add_child(ring)
	_extras.append(ring)
	if filled:
		_arcs.append({ "circle": at, "radius": radius, "color": color, "age": 0.0 })


# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FLOOR_COLOR)
	var step := 32.0 * _stage.scale.x
	if step > 4.0:
		var x := fmod(size.x * 0.5, step)
		while x < size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), GRID_COLOR)
			x += step
		var y := fmod(size.y * 0.5, step)
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), GRID_COLOR)
			y += step
	draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.GOLD, 0.35), false, 2.0)


func _draw_overlay() -> void:
	for arc in _arcs:
		var fade: float = 1.0 - arc.age / 0.3
		if arc.has("circle"):
			_overlay.draw_circle(arc.circle, arc.radius, Color(arc.color, 0.35 * fade))
		elif arc.has("line"):
			var start := _home + Vector2(0, -arc.width * 0.5)
			_overlay.draw_rect(Rect2(start, Vector2(arc.line, arc.width)), Color(arc.color, 0.45 * fade))
		elif is_full_turn(arc.half):
			# A spin: a fan would close on itself and fail to triangulate.
			_overlay.draw_circle(_sprite.position, arc.radius, Color(arc.color, 0.55 * fade))
		else:
			var points := fan_points(_sprite.position, arc.half, arc.radius)
			if not points.is_empty():
				_overlay.draw_colored_polygon(points, Color(arc.color, 0.55 * fade))
	for shot in _shots:
		if shot.sheet:
			# Its first frame, cut and turned as in the game (drawn directions, or snapped).
			PixelDraw.sheet(_overlay, shot.sheet, 0, shot.pos, shot.vel, shot.element)
		else:
			_overlay.draw_circle(shot.pos, shot.radius * 2.2, Color(shot.color, 0.3))
			_overlay.draw_circle(shot.pos, shot.radius, shot.color)
			_overlay.draw_circle(shot.pos, shot.radius * 0.45, Color.WHITE)


## A swing of `half` radians to each side covers the whole turn (spins: 360, 450...).
static func is_full_turn(half: float) -> bool:
	return half >= PI - 0.01


## The swing's fan as a polygon (centre, then the arc), or nothing when it would be too thin
## or a full turn to triangulate (see is_full_turn).
static func fan_points(center: Vector2, half: float, radius: float) -> PackedVector2Array:
	if is_full_turn(half) or half <= 0.01 or radius <= 0.5:
		return PackedVector2Array()
	var points := PackedVector2Array([center])
	for i in 13:
		points.append(center + Vector2.from_angle(lerpf(-half, half, i / 12.0)) * radius)
	return points


## Plays the first of `names` the sprite has.
static func _play_anim(sprite: AnimatedSprite2D, names: Array) -> void:
	if sprite.sprite_frames == null:
		return
	for anim: StringName in names:
		if sprite.sprite_frames.has_animation(anim):
			if sprite.animation != anim or not sprite.is_playing():
				sprite.play(anim)
			return
