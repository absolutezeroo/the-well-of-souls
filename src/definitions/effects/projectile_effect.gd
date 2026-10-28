class_name ProjectileEffect
extends Effect
## Fires one or more projectiles along the aim direction.
## Its `element` (Effect.element): what it is made of (data/vfx/elements/): without a texture, the
## shot is the element's own projectile; it lands and hits in the element's language (docs/vfx.md).

## Damage = flat_damage + user's skill power (power boosted by skill power) x multiplier.
@export var damage_multiplier: float = 1.0
@export var flat_damage: int = 0
@export var speed: float = 380.0
@export var radius: float = 8.0
@export var max_distance: float = 520.0
@export var count: int = 1
## Fan width in degrees (360 = full ring).
@export var spread_degrees: float = 0.0
@export var pierce: int = 0
@export var knockback: float = 160.0
## Greater than 0: the projectile explodes on impact and hits everything around.
@export var explosion_radius: float = 0.0
@export var color: Color = Color(1.0, 0.5, 0.2)
## Sprite (or frames in a row) of the projectile. Without one (and no element), a glowing dot.
@export var texture: Texture2D
## Frames in a row of `texture` (0 = square frames).
@export_range(0, 64) var texture_frames: int = 0
## Drawn in flight instead of `texture` and the element's own projectile: a shot or a thing
## drawn in 16 directions so it never shears (an arrow, a kunai, a feather, the Demon Cyclops'
## rays of fire: data/vfx/sheets/). `texture` stays its picture elsewhere.
@export var sheet: VfxSheetDef
## Statuses left on the enemies hit (burn, slow...).
@export var status: OnHitStatus
## Magic shots glow and burst on impact; 0 for plain things (feathers, coins, arrows).
@export_range(0.0, 1.0) var glow: float = 1.0
## Fired by a passive (a family's ring of bolts...): its hits trigger no on-hit perk
## (HitInfo.is_secondary). Leave off for skills.
@export var secondary: bool = false
## Turns the aim (degrees): a second ring shifted by half a gap closes the safe lanes.
@export var angle_offset: float = 0.0
## With `explosion_radius`: it bursts into its element's nova (a ring of ice crystals) rather
## than a blast (the Frost Staff's charged shard shattering).
@export var nova_burst: bool = false
## A glow around the shot even when it is drawn from a sheet: a heavier, charged shot.
@export var halo: bool = false

## Not saved, never in data: set when a weapon's attack is dressed in what the hero's weapon
## carries (`dressed_in`: a charged attack, the weapon's skills): a plain thing (the heavy arrow,
## Volley's arrows, the stars) flies in `look_element`, a magic shot (Ice Shards) wears it riding
## its back; a second element adds bits to a plain thing's trail.
var look_element: VfxElementDef
var second_element: VfxElementDef
## Not saved: its hits land in `look_element` (a charged attack: the element gathered). Else a
## hit lands in it only when its own rules say so (the Ember Rune's roll: BurnOnHitPassive).
var lands_in_look := false


func apply(user: Actor, aim: Vector2) -> void:
	var spec := ProjectileSpec.new()
	spec.damage = hit_amount(user)
	spec.speed = speed
	spec.radius = radius
	spec.max_distance = max_distance
	spec.count = count
	spec.spread_degrees = spread_degrees
	spec.pierce = pierce
	spec.knockback = knockback
	spec.explosion_radius = explosion_radius
	spec.color = element.color() if element else color
	spec.texture = texture
	spec.texture_frames = texture_frames
	spec.sheet = sheet
	spec.element = element
	spec.status = status
	spec.glow = glow
	spec.secondary = secondary
	spec.nova_burst = nova_burst
	spec.halo = halo
	spec.look_element = look_element
	spec.hit_element = look_element if lands_in_look else null
	spec.second_element = second_element
	var direction := aim.rotated(deg_to_rad(angle_offset)) if angle_offset != 0.0 else aim
	# From the hand (the hero's weapon), a full ring from the middle of the body.
	var from := user.shot_origin(direction) if spread_degrees < 360.0 else Vector2.INF
	user.world.fire_projectiles(user, direction, spec, from)


## A copy dressed in the elements the hero's weapon carries (`carried`, the strongest first:
## docs/vfx.md "Elemental attacks"): a plain thing flies in the first (its matter riding it, its
## bits trailing) and the second adds bits; a magic shot stays itself (a frost shard is a frost
## shard) and the first other element rides its back. `lands`: its hits land in that element
## (a charged attack); else the hit's own rules decide (a rune's roll). The data stays as written.
func dressed_in(carried: Array[VfxElementDef], lands: bool) -> ProjectileEffect:
	var copy := copied() as ProjectileEffect
	var others: Array[VfxElementDef] = []
	for other in carried:
		if other and other != element:
			others.append(other)
	if others.is_empty():
		return copy
	copy.look_element = others[0]
	copy.second_element = others[1] if element == null and others.size() > 1 else null
	copy.lands_in_look = lands and element == null
	return copy


## A weapon's skill: its shots flying in what the weapon carries, landing as their rules say.
func dressed_for_skill(carried: Array[VfxElementDef]) -> Effect:
	return dressed_in(carried, false)


## A charged attack: a thing (the heavy arrow, the stars) flies in the element without being made
## of it and lands in it; a magic shot stays itself (the Frost Staff's shard) and another element
## rides it.
func dressed_for_charge(first: VfxElementDef, second: VfxElementDef) -> Effect:
	var carried: Array[VfxElementDef] = [first, second]
	return dressed_in(carried, true)


func copied() -> Effect:
	var copy := super.copied() as ProjectileEffect
	copy.look_element = look_element
	copy.second_element = second_element
	copy.lands_in_look = lands_in_look
	return copy


func telegraph_kind() -> Telegraph:
	return Telegraph.SHOT


func ai_reach() -> float:
	return max_distance


func hit_status() -> OnHitStatus:
	return status


func with_hit_status(new_status: OnHitStatus) -> Effect:
	var copy := copied() as ProjectileEffect
	copy.status = new_status
	return copy


## The lane of its shot (a line), or the lanes of a fan or a ring of them, as far as they fly and
## as wide as the shot (TelegraphView.show_shots(): the real area).
func show_warning(view: TelegraphView, angle: float, progress: float, body_radius: float) -> bool:
	view.show_shots(max_distance, angle + deg_to_rad(angle_offset), progress, count, spread_degrees, radius, body_radius)
	return true


func play_preview(preview: EffectPreview) -> void:
	preview.shots(count, spread_degrees, speed, max_distance, radius, element.color() if element else color, explosion_radius, sheet if sheet else EffectPreview.shot_sheet(texture, texture_frames, element), element, deg_to_rad(angle_offset))


func hurts() -> bool:
	return true


## Its flat damage plus the user's skill power times its multiplier.
func hit_amount(user: Actor) -> int:
	return flat_damage + roundi(user.get_skill_power() * damage_multiplier)
