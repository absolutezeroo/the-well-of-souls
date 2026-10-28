class_name Effect
extends Resource
## Something that happens when a skill or a consumable is used.
## Subclasses override apply(). `aim` is a normalized direction chosen by the user.
## What a kind does when it is dressed in a weapon's elements, warned of by a boss or tamed is
## asked of it (the virtuals below), never tested by its type: a new kind overrides what fits it.

## How a boss warns of an effect (NamelessKeeperDef.boss_skill() picks its cast time and range
## by it): a dive along a line, a shot, an area, anything else.
enum Telegraph { OTHER, DIVE, SHOT, AREA }

## Seconds after the skill is used before this effect happens (combos: three quick stabs,
## a fissure running forward...). The aim is the one chosen when the skill was used.
@export var delay: float = 0.0
## What it is made of (data/vfx/elements/): how it is drawn and how its hits flash in the
## element's language (each kind says what it does with it, in its class doc). Empty: plain.
@export var element: VfxElementDef


func apply(_user: Actor, _aim: Vector2) -> void:
	pass


## A copy, its run-time look (what the dressing below sets, never saved) kept with it:
## Resource.duplicate() copies the exports only. Kinds with such a look add theirs.
func copied() -> Effect:
	return duplicate() as Effect


## As one of the hero's weapon's skills casts it (SkillDef.effects_for): dressed in the elements
## the weapon's runes and affixes carry (`carried`, the strongest first; only the look, the hits
## stay as written). Itself for a kind with nothing to dress.
func dressed_for_skill(_carried: Array[VfxElementDef]) -> Effect:
	return self


## As part of the weapon's charged attack (ChargedAttackDef.dressed): a copy made of `first`,
## the first element the weapon carries; `second` (or the effect's own element) sheds its bits
## where the kind has a blow to shed them from (_shed()).
func dressed_for_charge(first: VfxElementDef, second: VfxElementDef) -> Effect:
	var copy := copied()
	var own := element
	copy.element = first
	copy._shed(second if second else (own if own != first else null))
	return copy


## A second element whose bits its blow sheds (a blade's arc, an area: their `second_element`);
## nothing for the kinds without one.
func _shed(_second: VfxElementDef) -> void:
	pass


## As the Nameless Keeper casts it, one of the hero's own skills (NamelessKeeperDef._boss_effect):
## dressed in the elements the hero's weapon carried. `dive_width_max`: a dive's band no wider.
func as_boss_skill(carried: Array[VfxElementDef], _dive_width_max: float) -> Effect:
	return dressed_for_skill(carried) if not carried.is_empty() else self


## It carries its user along (a dash, a leap): what comes after it lands where the body will be.
func moves_caster() -> bool:
	return false


## How a boss warns of it (see Telegraph).
func telegraph_kind() -> Telegraph:
	return Telegraph.OTHER


## How far from its caster it reaches (a boss' AI range for it): a dive's length, a shot's
## flight, an area's far side. 0: no reach of its own.
func ai_reach() -> float:
	return 0.0


## The circle round its caster that holds it (a boss warning of several blows at once with one
## circle). 0: none.
func warning_reach() -> float:
	return 0.0


## Its hits hurt (a blast, a blow, a shot, a strike on the ground): a monster's cast of it is a
## wind-up the fairness contract holds to its floor (SkillDef.hurts(), docs/decisions/0008).
## False for a summon, a heal, a ward, a plain step.
func hurts() -> bool:
	return false


## What each of its hits carries from `user` before the hit's own roll and the target's armor
## (Combat.make_hit), 0 for a kind that hurts no one. Its apply() deals this; the damage budget's
## test reads it.
func hit_amount(_user: Actor) -> int:
	return 0


## Shows how it is coming on `view` (a monster's cast: TelegraphView.show_skill()), cast toward
## `angle` by a body of `body_radius`, `progress` 0 when the warning starts and 1 when it lands:
## a shot's lane, a dive's line, an area's circle. False when it has nothing to warn of (a summon,
## a heal): the view is left as it was.
func show_warning(_view: TelegraphView, _angle: float, _progress: float, _body_radius: float) -> bool:
	return false


## Its warning in the bestiary's preview when it draws one there that the game doesn't (a plain
## dash: its line); false: the game's own (show_warning()).
func show_preview_warning(_view: TelegraphView, _angle: float, _progress: float) -> bool:
	return false


## What it does, played in the bestiary's preview (EffectPreview): a pale ring round the caster
## for a kind with no picture of its own.
func play_preview(preview: EffectPreview) -> void:
	preview.ring(0.0, preview.caster_radius() + 26.0, Color(1, 1, 1, 0.7), false)


## The statuses its hits leave (burn, slow...); null: none, or it hits nothing.
func hit_status() -> OnHitStatus:
	return null


## A copy whose hits leave `status` instead (its look kept). Itself for a kind that hits nothing.
func with_hit_status(_status: OnHitStatus) -> Effect:
	return self


## Runs a list of effects, each after its own delay (skipped if the user died meanwhile).
static func apply_all(effects: Array[Effect], user: Actor, aim: Vector2) -> void:
	for effect in effects:
		if effect == null:
			continue
		if effect.delay <= 0.0:
			effect.apply(user, aim)
			continue
		var floor_id := user.world.floor_id
		# Who set it off (a skill, a potion: Actor.heal_source), for when it happens: its hits and
		# heals are credited to that source (HitInfo.via, Actor.healed), not to whatever acts then.
		var source := Actor.heal_source
		# A weak reference, not the user itself: the timer outlives a monster freed meanwhile, and
		# Godot checks a lambda's captured nodes before running it ("Lambda capture at index 0 was
		# freed"), even one whose first line asks is_instance_valid().
		var user_ref: WeakRef = weakref(user)
		user.get_tree().create_timer(effect.delay, false).timeout.connect(func() -> void:
			var who := user_ref.get_ref() as Actor
			if who and not who.is_dead and who.is_inside_tree() and who.world.floor_id == floor_id:
				Actor.with_source(source, effect.apply.bind(who, aim)))
