class_name HitFeedback
extends RefCounted
## What a blow taken shows and sounds like (Actor.take_hit()): the sparks off the body in the
## hit's element and the body's material, the cry and the material's knock (direct hits only:
## a burn's tick or a blast's splash stays quiet), and the damage number over the head. The
## Actor says what it is made of and how it cries (its hooks); this plays it.

const HIT_TEXT_COLOR := Color("ffffff")
const CRIT_TEXT_COLOR := Palette.GOLD
const SECONDARY_TEXT_COLOR := Color("ffb26b")
## A body's damage number still rising takes the next hits of its color within this many real
## seconds, summed: in a crowd (a spin, a volley, ticks) one number per body, not one per blow
## (docs/design/presentation.md "Feel limits").
const MERGE_WINDOW_MS := 300

## The number each body shows now (by its instance id): [the FloatingText, the text it was given,
## the sum, its color, when it began (real msec)]. Merging only: who makes and frees the
## numbers is World.spawn_floating_text()'s business.
static var _numbers := {}


## `actor` took `hit` for `damage`: `spark` its sparks' color, `cry` its hurt sound, `impact`
## what its body is made of (null: nothing particular).
static func play(actor: Actor, hit: HitInfo, damage: int, spark: Color, cry: AudioStream, impact: ImpactMaterialDef) -> void:
	var world := actor.world
	if not hit.is_secondary:
		var spark_direction := hit.knockback.normalized() if hit.knockback != Vector2.ZERO else Vector2.UP
		Vfx.hit(world, actor.global_position + Vector2(0, -actor.radius * 0.5), spark_direction, spark, hit.is_crit, hit.element, impact)
		Sfx.play_at(cry, actor.global_position)
		if impact and impact.sound:
			Sfx.play_at(impact.sound, actor.global_position, impact.volume_db)
	show_damage(actor, damage, text_color(hit), hit.is_crit)


## `actor`'s damage number for `damage`: added to the one it shows of `color` if that began less
## than MERGE_WINDOW_MS ago (and still shows the sum it was given), else a new one.
static func show_damage(actor: Actor, damage: int, color: Color, crit: bool) -> void:
	var now := Time.get_ticks_msec()
	var key := actor.get_instance_id()
	var entry: Array = _numbers.get(key, [])
	if not entry.is_empty():
		var shown: FloatingText = null
		if is_instance_valid(entry[0]) and (entry[0] as Node).is_inside_tree():  # (not back in its pool)
			shown = entry[0] as FloatingText
		if shown and now - int(entry[4]) <= MERGE_WINDOW_MS and entry[3] == color and shown.shown_text() == entry[1]:
			var total: int = entry[2] + damage
			var merged := str(total) + ("!" if crit else "")
			shown.retext(merged)
			entry[1] = merged
			entry[2] = total
			return
	var text := str(damage) + ("!" if crit else "")
	var made := actor.world.spawn_floating_text(actor.head_position(), text, color)
	if made == null:
		return
	if _numbers.size() > 64:
		_forget_old(now)
	_numbers[key] = [made, text, damage, color, now]


## Drops the numbers too old to take another hit.
static func _forget_old(now: int) -> void:
	for key: int in _numbers.keys():
		if now - int(_numbers[key][4]) > MERGE_WINDOW_MS:
			_numbers.erase(key)


## The damage number's color: the hit's own, else pale orange for a secondary hit, gold for a
## crit, white otherwise.
static func text_color(hit: HitInfo) -> Color:
	if hit.text_color.a > 0.0:
		return hit.text_color
	if hit.is_secondary:
		return SECONDARY_TEXT_COLOR
	return CRIT_TEXT_COLOR if hit.is_crit else HIT_TEXT_COLOR


## A body's sparks: gold on a crit, else its material's (white for none).
static func spark_color(hit: HitInfo, impact: ImpactMaterialDef) -> Color:
	if hit.is_crit:
		return CRIT_TEXT_COLOR
	return impact.spark_color if impact else Color.WHITE
