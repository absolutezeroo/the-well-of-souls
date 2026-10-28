class_name DashStrikeEffect
extends Effect
## Dashes along the aim and cuts every enemy on the way (stops at walls). Without `moves`, the
## user stays put and the cut runs out along the aim (a lance's long thrust).
## Its `element` (Effect.element): what it is made of (data/vfx/elements/): the element's pieces are
## left along the path (Glacial Dive: ice crystals that grow behind it and shatter), a sheet takes
## its ramp.

@export var distance: float = 160.0
@export var duration: float = 0.14
## Width of the cut along the path.
@export var width: float = 28.0
## Damage = flat_damage + user's skill power x multiplier.
@export var damage_multiplier: float = 1.4
@export var flat_damage: int = 0
@export var knockback: float = 160.0
@export var status: OnHitStatus
## The cut drawn along the path (a thrust's streak: data/vfx/slashes/), instead of a sheet.
@export var slash: SlashDef
## Slash sheet drawn along the path.
@export var fx: Texture2D
@export var fx_tint: Color = Color.WHITE
## The user dashes along the cut (off: a thrust that reaches out, the user standing still).
@export var moves: bool = true
## A thrust from where the user stands (`moves` off) struck in the body's four directions, like
## a weapon's blow (Blow): drawn toward the nearest of them, its cut swept from there to the
## exact aim. Ignored when the user dashes: a rush goes where it is aimed (moving is free in
## every direction) and its cut is drawn along the path it takes. Off: at the exact aim.
@export var follows_facing: bool = false

## A second element its blow sheds a few bits of (not saved, never in data: a charged attack
## dressed in what the hero's weapon carries sets it, ChargedAttackDef).
var second_element: VfxElementDef
## Not saved, never in data: a weapon's skill dressed in what its runes and affixes carry
## (SkillDef.effects_for, docs/vfx.md "Elemental attacks") is drawn in this element, its hits
## staying in `element` (the rune's own rules decide when a hit lands in it). A blade's blow or a
## plain area is drawn in it; one of its own element keeps it, and this one rides it.
var look_element: VfxElementDef


## A copy dressed in the elements the hero's weapon carries (`carried`, the strongest first): a
## plain cut (Dash Strike, Piercing Thrust) is drawn in the first, the second adding its bits;
## one of its own element stays itself, the first other shedding its bits. Only the look.
func dressed_in(carried: Array[VfxElementDef]) -> DashStrikeEffect:
	var copy := copied() as DashStrikeEffect
	var others: Array[VfxElementDef] = []
	for other in carried:
		if other and other != element:
			others.append(other)
	if others.is_empty():
		return copy
	copy.look_element = others[0]
	copy.second_element = (others[1] if others.size() > 1 else null) if element == null else others[0]
	return copy


## A weapon's skill: Dash Strike's cut drawn in what the weapon carries.
func dressed_for_skill(carried: Array[VfxElementDef]) -> Effect:
	return dressed_in(carried)


## The Keeper's dive: narrowed to a band his body could cross (`dive_width_max`) and never
## slowing; dressed in the elements he carries. Always a copy.
func as_boss_skill(carried: Array[VfxElementDef], dive_width_max: float) -> Effect:
	var dive := dressed_in(carried)
	dive.width = minf(dive.width, dive_width_max)
	if dive.status and dive.status.slow > 0.0:
		dive.status = null
	return dive


func _shed(second: VfxElementDef) -> void:
	second_element = second


func copied() -> Effect:
	var copy := super.copied() as DashStrikeEffect
	copy.look_element = look_element
	copy.second_element = second_element
	return copy


func telegraph_kind() -> Telegraph:
	return Telegraph.DIVE


func moves_caster() -> bool:
	return moves


func ai_reach() -> float:
	return distance


func hit_status() -> OnHitStatus:
	return status


func with_hit_status(new_status: OnHitStatus) -> Effect:
	var copy := copied() as DashStrikeEffect
	copy.status = new_status
	return copy


func apply(user: Actor, aim: Vector2) -> void:
	var world := user.world
	var start := user.global_position
	var blow := Blow.at(start, aim, follows_facing and not moves)
	# Drawn (and dashed) toward the blow's facing: the aim itself unless it follows the body's pose.
	aim = blow.facing
	# Stop short of walls.
	var length := Combat.clear_length(world, start, aim, distance, user.radius)
	var end := start + aim * length
	var amount := hit_amount(user)
	if blow.facing != blow.aim:
		Combat.damage_blow_segment(world, user, blow, distance, width, amount, knockback, status, element)
	else:
		Combat.damage_segment(world, user, start, end, width, amount, knockback, status, element)
	if moves and length > 1.0:
		user.start_dash(aim * length / duration, duration, true, element)
	if element:
		Vfx.trail(world, start, end, element, duration)
	elif slash == null and fx == null and moves:
		Vfx.dust_trail(world, start, end, duration)  # a plain rush kicks up dust on its way
	# What the cut is drawn in (look_element: the weapon's runes and affixes on a plain cut).
	var drawn := element if element else look_element
	if slash:
		SwingVfx.slash(world, slash, start + Vector2(0, -6), aim, maxf(length, 40.0), drawn, user.faction != Actor.Faction.PLAYER, second_element, follows_facing and not moves)
	elif fx:
		# At the nearest whole size of the art's pixel along the path (SheetVfx snaps it).
		var size := maxf(length, 40.0) / fx.get_height()
		world.spawn_vfx(SheetVfx.create(fx, (start + end) * 0.5, aim.angle(), size, 20.0).with_color(fx_tint).in_element(drawn))


## The line it dives along, as wide as its cut (a shot's lane at least).
func show_warning(view: TelegraphView, angle: float, progress: float, _body_radius: float) -> bool:
	view.show_shape(TelegraphView.Shape.LINE, distance, angle, progress, 0.0, maxf(width, TelegraphView.LANE_WIDTH))
	return true


func play_preview(preview: EffectPreview) -> void:
	preview.lunge(distance, duration)
	preview.line(distance, width, fx_tint if fx else Color(1, 0.9, 0.7))


func hurts() -> bool:
	return true


## Its flat damage plus the user's skill power times its multiplier.
func hit_amount(user: Actor) -> int:
	return flat_damage + roundi(user.get_skill_power() * damage_multiplier)
