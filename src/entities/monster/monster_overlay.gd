class_name MonsterOverlay
extends Node2D
## What is drawn around a monster besides its body: under it (elite aura, shields, the red
## warning of an attack or a cast), or over it (elite name, health bar). Two of these per monster,
## one behind the body (UNDER) and one in front (OVER), so the Monster script stays about behaviour.

enum Layer { UNDER, OVER }

const HP_BAR_WIDTH := 26.0

var layer := Layer.UNDER
var monster: Monster
## The attack warning (UNDER only).
var _telegraph: TelegraphView
## What the last _draw() showed (OVER: the health bar, the ward, the name; it moves with the
## monster, so it is drawn again only when one of these changes; docs/performance.md).
var _drawn_hp := -1
var _drawn_max_hp := -1
var _drawn_ward := -1
var _drawn_gone := false
## UNDER: something moves every frame (an elite's pulsing aura, a guard's arc, a weak point's
## pool); else nothing is drawn there and it is never drawn again.
var _animated_under := false
var _drawn_once := false


static func create(host: Monster, overlay_layer: Layer) -> MonsterOverlay:
	var overlay := MonsterOverlay.new()
	overlay.monster = host
	overlay.layer = overlay_layer
	overlay.name = "Under" if overlay_layer == Layer.UNDER else "Over"
	overlay.show_behind_parent = overlay_layer == Layer.UNDER
	if overlay_layer == Layer.OVER:
		overlay.z_index = LightField.Z + 1  # names and health bars stay readable in the dark
	if overlay_layer == Layer.UNDER:
		# The elite aura and the warning lie on the floor, under every body (VfxLayer).
		VfxLayer.apply(overlay, VfxLayer.Layer.GROUND)
		overlay._telegraph = TelegraphView.new()  # on the floor, lit by its own light
		overlay._telegraph.add_light()
		overlay.add_child(overlay._telegraph)
	return overlay


func _process(delta: float) -> void:
	if not Vfx.shown:
		return  # a simulation: nothing to see (Vfx.shown)
	# Off screen nothing needs drawing (the telegraph still follows what the monster does).
	if _needs_redraw() and monster.world and monster.world.view_rect().has_point(monster.global_position):
		queue_redraw()
	if _telegraph:
		_update_telegraph()
	# A shimmering rank (Shiny) sheds sparkles now and then.
	if layer == Layer.OVER and monster.rank and monster.rank.shimmer and not monster.is_dead and randf() < delta * 2.5:
		var at := monster.global_position + Vector2(randf_range(-1.0, 1.0) * monster.radius, -randf() * monster.head_height)
		Vfx.sparkles(monster.world, at, monster.rank.color)


func _draw() -> void:
	_drawn_hp = monster.hp
	_drawn_max_hp = monster.get_max_hp()
	_drawn_ward = monster.ward
	_drawn_gone = monster.is_dead or monster.is_falling
	if _drawn_gone:
		return
	if layer == Layer.UNDER:
		if monster.rank:
			_draw_elite_aura()
		for monster_trait in monster.behaviors.active:
			monster_trait.draw_under(monster, self)
	else:
		if monster.ward > 0:
			monster.draw_ward(self)
		if monster.rank and not monster.is_boss():
			_draw_elite_name()
		# Bosses have a big bar in the HUD instead.
		if monster.hp < monster.get_max_hp() and not monster.is_boss():
			var top_left := monster.head_position() - monster.global_position + Vector2(-HP_BAR_WIDTH * 0.5, -6.0)
			draw_rect(Rect2(top_left - Vector2.ONE, Vector2(HP_BAR_WIDTH + 2.0, 6.0)), Palette.INK)
			draw_rect(Rect2(top_left, Vector2(HP_BAR_WIDTH * monster.hp / monster.get_max_hp(), 4.0)), Palette.BLOOD)


## Whether what _draw() shows changed since it last drew (or moves every frame).
func _needs_redraw() -> bool:
	var gone := monster.is_dead or monster.is_falling
	if not _drawn_once:
		_drawn_once = true
		_animated_under = monster.behaviors.draws_under
		return true
	if gone != _drawn_gone:
		return true
	if layer == Layer.UNDER:
		return not gone and (_animated_under or monster.behaviors.draws_under or monster.rank != null)  # (a rank may come after the spawn)
	# A ward shimmers (every frame while it holds); an elite's name is redrawn with it (few of them).
	return monster.hp != _drawn_hp or monster.get_max_hp() != _drawn_max_hp or monster.ward != _drawn_ward \
		or monster.ward > 0 or (monster.rank != null and not monster.is_boss())


## Red warning (TelegraphView): the area of a skill being cast, the cone of a melee swing, the
## line of a shot, filling up until it lands.
func _update_telegraph() -> void:
	var telegraph := monster.telegraph
	if telegraph <= 0.0 or monster.is_dead or monster.is_falling:
		_telegraph.visible = false
		return
	var weapon := monster.get_weapon()
	var skill := monster.casting_skill()
	var angle := monster.facing.angle()
	_telegraph.position = Vector2.ZERO
	if skill:
		# Its area, the lanes of its shots (the aim is locked when the cast starts, so the gaps
		# shown are the real ones), the line of its dash; nothing for a summon or a heal.
		_telegraph.show_skill(skill, angle, telegraph, monster.radius)
	elif weapon and weapon.kind == WeaponDef.Kind.MELEE:
		var reach := monster.radius + weapon.reach
		if weapon.arc_degrees >= 359.0:
			_telegraph.show_shape(TelegraphView.Shape.CIRCLE, reach, 0.0, telegraph)
		else:
			# The blow's real zone: toward the pose's direction, swept to the locked aim (Blow).
			var cone := Blow.of_weapon(monster.global_position, monster.facing, weapon).cone(deg_to_rad(weapon.arc_degrees) * 0.5)
			_telegraph.show_shape(TelegraphView.Shape.CONE, reach, cone.x, telegraph, cone.y)
	elif weapon:
		# The path of its shots, as far as they fly (Combat.spec_from_weapon: the weapon's reach).
		_telegraph.show_shots(weapon.reach, angle, telegraph, weapon.projectile_count, weapon.spread_degrees, weapon.projectile_radius, monster.radius)
	else:
		_telegraph.visible = false


## Pulsing rings of the rank's color at its feet (more rings for rarer ranks), and for the
## rarest a slow crown of rays. Stepped rings of art pixels lying on the ground; the pulse steps
## the rings out by a whole pixel, the outer ones dithered (docs/vfx.md).
func _draw_elite_aura() -> void:
	var time := Time.get_ticks_msec() * 0.001
	var pulse := 1.0 if sin(time * 6.0) > 0.0 else 0.0
	var color := Color(monster.rank_color(), 1.0)
	var feet := Vector2(0, monster.radius * 0.7)
	var base := monster.radius + 6.0 + PixelDraw.PX * pulse
	PixelDraw.disc(self, feet, base, Color(color, 0.22 + 0.1 * pulse), 1.0, 0.45)
	for ring in maxi(monster.rank.aura_rings, 1):
		PixelDraw.ring(self, feet, base + ring * 6.0, color, 1, 1.0 - ring * 0.3, 0.45)
	if monster.rank.aura_rings >= 3:
		for i in 8:
			var angle := time * 0.8 + TAU * i / 8.0
			var way := Vector2.from_angle(angle) * Vector2(1.0, 0.45)
			PixelDraw.line(self, feet + way * (monster.radius + 8.0), feet + way * (monster.radius + 22.0 + 4.0 * pulse), color, 1, 0.5)


func _draw_elite_name() -> void:
	var at := monster.head_position() - monster.global_position + Vector2(0, -12.0)
	Fonts.draw(self, at, monster.display_name, Fonts.BODY, monster.rank_color().lightened(0.3), 0.5, Color(0, 0, 0, 0.8))
	# An Epic or Legendary: its affixes on a line above.
	if monster.rank.show_in_name and monster.affixes.size() > 0:
		Fonts.draw(self, at + Vector2(0, -14.0), monster.affix_names(), Fonts.BODY, Color(1, 1, 1, 0.85), 0.5, Color(0, 0, 0, 0.8))
