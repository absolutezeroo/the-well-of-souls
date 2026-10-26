class_name MonsterTrait
extends Resource
## A special way a kind of monster fights: a shield, stealing gold, bursting when it dies,
## splitting into smaller ones... Listed in MonsterDef.traits, the monster calls these hooks.
## One trait resource is shared by every monster of that kind: keep per-monster values in
## `monster.trait_state(self)`, never in the trait itself: a trait with such values declares an
## inner state class (`ThiefState`...: typed fields, no dictionary keys to mistype) and makes it in make_state().


## A new monster's values of this trait (an instance of its inner state class), made the first
## time Monster.trait_state() asks for them. The base has none to keep.
func make_state() -> RefCounted:
	return RefCounted.new()


## Once, when the monster is set up.
func on_spawn(_monster: Monster) -> void:
	pass


## Every physics frame, while alive.
func update(_monster: Monster, _delta: float) -> void:
	pass


## Changes where the monster walks (`direction` from its AI).
func steer(_monster: Monster, direction: Vector2) -> Vector2:
	return direction


## Multiplies walking speed without rebuilding stats or changing shared definitions.
func move_speed_multiplier(_monster: Monster) -> float:
	return 1.0


## After damage is applied. Reactions must reject lethal, secondary and friendly hits.
func on_damaged(_monster: Monster, _hit: HitInfo, _damage: int) -> void:
	pass


## False to stop the monster from attacking for now.
func can_attack(_monster: Monster) -> bool:
	return true


## False to stop the monster from starting a skill for now (the AI picks none).
func can_cast(_monster: Monster) -> bool:
	return true


## True when the hit glances off before anything happens (no damage, no flash, no status, no
## streak toward the shockwave): the trait shows how it was turned away itself.
func deflects(_monster: Monster, _hit: HitInfo) -> bool:
	return false


## Last say on the damage of a hit, after armor.
func incoming_damage(_monster: Monster, _hit: HitInfo, damage: int) -> int:
	return damage


## The monster just hurt the hero.
func on_hit_player(_monster: Monster, _player: Player, _hit: HitInfo = null) -> void:
	pass


## The monster died. `fell`: down a hole (nothing comes out of it).
## `rewards`: false for summoned monsters (they give nothing).
func on_died(_monster: Monster, _killer: Actor, _fell: bool, _rewards: bool) -> void:
	pass


## Drawn under the monster's body (see MonsterOverlay).
func draw_under(_monster: Monster, _canvas: CanvasItem) -> void:
	pass


## Whether draw_under() draws anything (the overlay under a monster redraws every frame only
## then: docs/performance.md, "Redraw on change").
func draws_under() -> bool:
	return false


## Its look drawn outside a fight (the bestiary's page and its attack preview): what on_spawn()
## does to the body that a picture of it needs too (a shade's darkness, its lantern). `sprite`
## shows the monster's frames, one unit an art pixel, its origin at the feet.
func dress_look(_sprite: AnimatedSprite2D) -> void:
	pass


## A line for the bestiary.
func describe() -> String:
	return ""
