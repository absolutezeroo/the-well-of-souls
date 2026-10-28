class_name DamageAreaEffect
extends Effect
## Hits every enemy inside a circle, centred on the user or pushed forward along the aim.
## Its `element` (Effect.element): what it is made of (data/vfx/elements/): without a sheet, the
## element's nova (Frost Nova's ring of crystals); a sheet is painted in the element's ramp; an
## explosion takes its colors (Quake: earth, not fire). Its hits flash in its language.

@export var radius: float = 80.0
## Damage = flat_damage + user's skill power (power boosted by skill power) x multiplier.
@export var damage_multiplier: float = 1.5
@export var flat_damage: int = 0
## Distance of the circle centre along the aim direction. 0 = around the user.
@export var offset: float = 0.0
@export var knockback: float = 220.0
@export var color: Color = Color(1.0, 0.8, 0.3)
## Statuses left on the enemies hit (burn, slow...).
@export var status: OnHitStatus
## A blast (its element's burst, a ripple, screen shake) instead of a simple ring.
@export var explosive: bool = false
## A sheet of its own played on the area's middle at the art's size, never stretched to the
## radius (Thunder's bolt from the sky, Smite's column of light), over the element's nova.
@export var strike: VfxSheetDef
## A blow struck in the body's four directions, like a weapon's (Blow: a charged crescent, a
## flurry's stabs, a hammer's slam ahead): drawn toward the nearest of them, the way the body
## faces, its circle swept from there to the exact aim so a foe on a diagonal is still hit. Off:
## at the exact aim (a spell placed far off: Thunder, Arrow Rain, Fissure). Nothing changes for
## an area around the user (`offset` 0) but the way its blade is drawn.
@export var follows_facing: bool = false

@export_group("Effect sheet")
## Drawn as a blade's blow (Cleave's crescent, Whirlwind's spin: data/vfx/slashes/) from the
## user toward the aim, its edge at the area's far side, instead of a sheet or a nova.
@export var slash: SlashDef
## Played on the area, e.g. a circular slash or rock spikes. Without one, a ring is drawn.
@export var fx: Texture2D
## Frames in the sheet. 0 = square frames.
@export var fx_frames: int = 0
## Turn the sheet toward the aim (slashes in front of the user). Without a sheet, the element's
## pieces sweep across the front of the area instead of ringing it (Flame Arc).
@export var fx_follow_aim: bool = false
@export var fx_tint: Color = Color.WHITE

## A second element its blow sheds a few bits of (not saved, never in data: a charged attack
## dressed in what the hero's weapon carries sets it, ChargedAttackDef).
var second_element: VfxElementDef
## Not saved, never in data: a weapon's skill dressed in what its runes and affixes carry
## (SkillDef.effects_for, docs/vfx.md "Elemental attacks") is drawn in this element, its hits
## staying in `element` (the rune's own rules decide when a hit lands in it). A blade's blow or a
## plain area is drawn in it; one of its own element keeps it, and this one rides it.
var look_element: VfxElementDef


## A copy dressed in the elements the hero's weapon carries (`carried`, the strongest first): a
## plain one (Cleave's arc, Arrow Rain's area) is drawn in the first and the second adds its bits;
## one of its own element (Frost Nova, Ground Slam) stays itself and the first other rides it (a
## few of its pieces inside). Only the look: the data stays as written, the hits as they were.
func dressed_in(carried: Array[VfxElementDef]) -> DamageAreaEffect:
	var copy := copied() as DamageAreaEffect
	var others: Array[VfxElementDef] = []
	for other in carried:
		if other and other != element:
			others.append(other)
	if others.is_empty():
		return copy
	copy.look_element = others[0]
	copy.second_element = others[1] if element == null and others.size() > 1 else null
	return copy


## A weapon's skill: Cleave's arc, a nova, drawn in what the weapon carries.
func dressed_for_skill(carried: Array[VfxElementDef]) -> Effect:
	return dressed_in(carried)


func _shed(second: VfxElementDef) -> void:
	second_element = second


func copied() -> Effect:
	var copy := super.copied() as DamageAreaEffect
	copy.look_element = look_element
	copy.second_element = second_element
	return copy


func telegraph_kind() -> Telegraph:
	return Telegraph.AREA


func ai_reach() -> float:
	return offset + radius


func warning_reach() -> float:
	return absf(offset) + radius


func hit_status() -> OnHitStatus:
	return status


func with_hit_status(new_status: OnHitStatus) -> Effect:
	var copy := copied() as DamageAreaEffect
	copy.status = new_status
	return copy


func apply(user: Actor, aim: Vector2) -> void:
	var blow := Blow.at(user.global_position, aim, follows_facing)
	# Everything below is drawn toward the blow's facing: the aim itself unless it follows the
	# body's pose.
	aim = blow.facing
	var center := blow.drawn_center(offset)
	var base := hit_amount(user)
	if blow.facing != blow.aim and offset > 0.0:
		Combat.damage_blow_area(user.world, user, blow, offset, radius, base, knockback, status, element)
	else:
		Combat.damage_area(user.world, user, center, radius, base, knockback, false, status, element)
	# What it is drawn in, and what rides it (look_element: the weapon's runes and affixes).
	var drawn := element if element else look_element
	var riding := look_element if element else null
	if explosive:
		Vfx.explosion(user.world, center, radius, drawn)
	elif slash:
		var reach := offset + radius if slash.shape != SlashDef.Shape.SPIN else radius
		SwingVfx.slash(user.world, slash, user.global_position + Vector2(0, -6), aim, reach, drawn, user.faction != Actor.Faction.PLAYER, riding if riding else second_element, follows_facing)
		riding = null  # (its bits are shed by the blade's arc)
	elif fx:
		# The sheet at the nearest whole size of the art's pixel (SheetVfx snaps it), not
		# stretched to the radius: a 32-pixel sheet over a 110 radius is drawn 6x, never 6.9x.
		var frame := VfxSheetDef.cell_size(fx, fx_frames)
		var size := radius * 2.0 / maxi(frame.x, frame.y)
		var sheet := SheetVfx.create(fx, center, aim.angle() if fx_follow_aim else 0.0, size, SheetVfx.DEFAULT_FPS, frame.x)
		user.world.spawn_vfx(sheet.with_color(fx_tint).in_element(drawn))
	elif drawn and fx_follow_aim:
		Vfx.arc(user.world, center, radius, aim, drawn)
	elif drawn:
		Vfx.nova(user.world, center, radius, drawn)
	else:
		user.world.spawn_vfx(RingVfx.create(center, radius, color))
	if strike:
		user.world.spawn_vfx(SheetVfx.play(strike, center, aim, drawn))
	if riding:
		Vfx.riding(user.world, center, radius, riding)


## The circle it strikes, pushed forward along the aim by `offset` (the view moved there).
func show_warning(view: TelegraphView, angle: float, progress: float, _body_radius: float) -> bool:
	view.position = Vector2.from_angle(angle) * offset
	view.show_shape(TelegraphView.Shape.CIRCLE, radius, angle, progress)
	return true


func play_preview(preview: EffectPreview) -> void:
	preview.ring(offset, radius, color, true)


func hurts() -> bool:
	return true


## Its flat damage plus the user's skill power times its multiplier.
func hit_amount(user: Actor) -> int:
	return flat_damage + roundi(user.get_skill_power() * damage_multiplier)
