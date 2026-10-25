class_name StatusSet
extends RefCounted
## Statuses on an actor: damage over time (burn, poison...) and slows.
## Applying the same damage-over-time id again refreshes it instead of stacking a second copy.


class Dot:
	var id: StringName
	var damage: int
	var interval: float
	var time_left: float
	var next_tick: float
	var source: Actor
	var color: Color
	## What it is made of (its look's element: fire for a burn): its ticks carry it, so a body
	## burnt to death goes to ash (DeathLookDef).
	var element: VfxElementDef


## A slow from one source: how much, the seconds left, and what it is made of (frost when a
## hit or the cold slows; null for the ground's own slow): the element says how the body shows
## it (frost: rime and cold mist; sand or ink: nothing, VfxElementDef.slow_look).
class Slow:
	var amount := 0.0
	var time_left := 0.0
	var element: VfxElementDef

	func _init(slow_amount: float, seconds: float, made_of: VfxElementDef) -> void:
		amount = slow_amount
		time_left = seconds
		element = made_of


## The slow source of the ground itself (quicksand): it slows but is no status to show.
const GROUND_SLOW := &"ground"

var _dots: Array[Dot] = []
## Slows by source (a frost hit, the cold, quicksand...). The strongest active one counts; each
## runs out on its own.
var _slows: Dictionary[StringName, Slow] = {}
## Rebuilt only when membership/appearance changes. Consumers must not mutate these lists.
var _ids: Array[StringName] = []
var _elements: Array[VfxElementDef] = []
var _looks_dirty := true
## Stable tick snapshot: callbacks may clear or add statuses while damage is delivered.
var _ticking: Array[Dot] = []
var _expired_slows: Array[StringName] = []


## Deals `damage` every `interval` seconds for `duration` seconds.
func apply_dot(id: StringName, damage: int, interval: float, duration: float, source: Actor, color: Color) -> void:
	for dot in _dots:
		if dot.id == id:
			dot.damage = maxi(dot.damage, damage)
			dot.time_left = maxf(dot.time_left, duration)
			dot.source = source
			return
	var dot := Dot.new()
	dot.id = id
	dot.damage = damage
	dot.interval = maxf(interval, 0.05)
	dot.time_left = duration
	dot.next_tick = dot.interval
	dot.source = source
	dot.color = color
	var look := StatusFx.LOOKS.look(id)
	dot.element = look.element if look else null
	_dots.append(dot)
	_looks_dirty = true


## Slows by `amount` for `duration` seconds. `source` keeps different slows apart: things that
## re-apply every frame (cold, quicksand) don't stretch a frost hit forever. `element`: what
## slows it (frost when not given; the ground's own slow has none), which decides its look.
func apply_slow(amount: float, duration: float, source: StringName = &"hit", element: VfxElementDef = null) -> void:
	amount = clampf(amount, 0.0, 0.9)
	if element == null and source != GROUND_SLOW:
		element = VfxElementDef.named(&"frost")
	# (kept and changed in place: the cold and quicksand slow again every frame)
	var slow: Slow = _slows.get(source)
	if slow == null:
		slow = Slow.new(0.0, 0.0, null)
		_slows[source] = slow
		_looks_dirty = true
	var previous_element := slow.element
	if source == &"hit":
		# Hits: the strongest one, the longest one; a frost hit's look wins over a plain one.
		var kept: VfxElementDef = slow.element if slow.element != null and slow.time_left > 0.0 and (element == null or element.slow_look == &"") else element
		slow.amount = maxf(slow.amount, amount)
		slow.time_left = maxf(slow.time_left, duration)
		slow.element = kept
	else:
		slow.amount = amount
		slow.time_left = duration
		slow.element = element

	if slow.element != previous_element:
		_looks_dirty = true


## Multiplier for the move speed (1 = not slowed).
func speed_multiplier() -> float:
	var slow := 0.0
	for source in _slows:
		slow = maxf(slow, _slows[source].amount)
	return 1.0 - slow


func is_slowed() -> bool:
	return not _slows.is_empty()


## The strongest slow showing `look` on the body (frost's &"slow": a hit, the cold...), 0 if
## none: a strong one freezes the body over (BodyLook).
func slow_of(look: StringName) -> float:
	var strongest := 0.0
	for source in _slows:
		var element := _slows[source].element
		if element and element.slow_look == look:
			strongest = maxf(strongest, _slows[source].amount)
	return strongest


## Seconds since the damage-over-time `id` last ticked (or took hold), -1 when it is not on:
## the body's poison wave rises with each tick (BodyLook).
func since_tick(id: StringName) -> float:
	for dot in _dots:
		if dot.id == id:
			return maxf(dot.interval - dot.next_tick, 0.0)
	return -1.0


func has(id: StringName) -> bool:
	return _dots.any(func(dot: Dot) -> bool: return dot.id == id)


## The statuses on now: the damage-over-time ids, and the look of each element slowing the
## body (frost's is &"slow": StatusFx shows rime; sinking in quicksand, sand or ink show none).
func active_ids() -> Array[StringName]:
	_refresh_looks()
	return _ids


## Read-only cached elements; valid until the next call after a status changes.
func slow_elements() -> Array[VfxElementDef]:
	_refresh_looks()
	return _elements


func _refresh_looks() -> void:
	if not _looks_dirty:
		return
	_looks_dirty = false
	_ids.clear()
	_elements.clear()
	for dot in _dots:
		_ids.append(dot.id)
	for source in _slows:
		var element := _slows[source].element
		if element and not _elements.has(element):
			_elements.append(element)
			if element.slow_look != &"" and not _ids.has(element.slow_look):
				_ids.append(element.slow_look)


func is_empty() -> bool:
	return _dots.is_empty() and _slows.is_empty()


## Tint of the strongest active status (for the actor's body), or transparent: a slow tints
## only when its element shows on the body (frost), not sand or the ground.
func tint() -> Color:
	if not _dots.is_empty():
		return _dots[0].color
	for element in slow_elements():
		if element.slow_look != &"":
			return element.color()
	return Color.TRANSPARENT


func clear() -> void:
	_dots.clear()
	_slows.clear()
	_looks_dirty = true


func tick(owner: Actor, delta: float) -> void:
	for source: StringName in _slows:
		var slow := _slows[source]
		slow.time_left -= delta
		if slow.time_left <= 0.0:
			_expired_slows.append(source)
	if not _expired_slows.is_empty():
		for source in _expired_slows:
			_slows.erase(source)
		_expired_slows.clear()
		_looks_dirty = true
	if _ticking.size() != _dots.size():
		_ticking.resize(_dots.size())
	for i in _dots.size():
		_ticking[i] = _dots[i]
	for dot in _ticking:
		dot.time_left -= delta
		dot.next_tick -= delta
		if dot.next_tick <= 0.0:
			dot.next_tick += dot.interval
			var source: Actor = dot.source if is_instance_valid(dot.source) else null
			var dot_tick := Combat.make_tick(source, dot.damage)
			dot_tick.text_color = dot.color  # its number in the status's color
			dot_tick.element = dot.element  # burnt to death: ash (DeathLookDef)
			dot_tick.cause = dot.id  # "burn", "poison": how the Vigil-Keeper tells it (RunFacts)
			owner.take_hit(dot_tick)
			if owner.is_dead:
				_dots.clear()
				_looks_dirty = true
				return
		if dot.time_left <= 0.0:
			_dots.erase(dot)
			_looks_dirty = true
