class_name OfferQueue
extends RefCounted
## Perk choices waiting to be made, in order: level ups, relics, encounters' gifts.
## Two kinds (Offer.on_demand): a level up's choice waits for the player to ask for it (the HUD's
## perk button, Game.open_offers()); the others (a boss' or a pact's relics, an encounter's gift)
## come up by themselves when no menu is open (Game._show_next_offer()). A choice put off with
## "Later" waits like a level up, with the same cards.
## Saved with the run, the one on screen included (with its cards: quitting can't reroll them).

## The waiting choices changed (one more, one taken): the HUD's count.
signal changed


class Offer:
	var rarity: PerkDef.Rarity = PerkDef.Rarity.COMMON
	var count: int
	var title := ""
	var subtitle := ""
	## A level-up title keeps the number separately, so changing language can translate it.
	var level := 0
	## Waits for the player to open it (a level up, or a choice put off).
	var on_demand := false
	## The cards dealt (after rerolls and banishes), kept when the choice is put off or saved;
	## empty until it is first shown.
	var cards: Array[PerkDef] = []


	func shown_title() -> String:
		return tr("Level %d!") % level if level > 0 else tr(title)


	func to_data() -> Dictionary:
		return { "rarity": rarity, "count": count, "title": title, "subtitle": subtitle,
			"on_demand": on_demand, "cards": RunSave.refs(cards), "level": level }


	static func from_data(data: Dictionary) -> Offer:
		var offer := Offer.new()
		offer.rarity = int(data.get("rarity", 0)) as PerkDef.Rarity
		offer.count = int(data.get("count", (load("res://data/player/player_def.tres") as PlayerDef).perk_choices))
		offer.title = str(data.get("title", ""))
		offer.subtitle = str(data.get("subtitle", ""))
		offer.level = int(data.get("level", 0))
		OfferQueue._migrate_words(offer)
		# Saves from before choices waited: whatever was pending waits for the player.
		offer.on_demand = bool(data.get("on_demand", true))
		for ref: Variant in data.get("cards", []):
			var perk := RunSave.load_ref(ref) as PerkDef
			if perk:
				offer.cards.append(perk)
		return offer


## The choice on screen right now (null when none).
var shown: Offer

var _pending: Array[Offer] = []


## `on_demand`: it waits for the player (a level up) instead of coming up by itself.
func add(rarity: PerkDef.Rarity, count: int, title: String, subtitle: String, on_demand: bool = false, level: int = 0) -> Offer:
	var offer := Offer.new()
	offer.rarity = rarity
	offer.count = count
	offer.title = title
	offer.subtitle = subtitle
	offer.on_demand = on_demand
	offer.level = level
	_pending.append(offer)
	changed.emit()
	return offer


## The relics a boss leaves behind (if it has any).
## `extra`: more relics to choose from (a Legendary or Shiny boss).
func add_relic(boss: BossDef, extra: int = 0) -> void:
	if boss and boss.relic_choices > 0:
		add(PerkDef.Rarity.RARE, boss.relic_choices + extra, "Relic", "A relic lies in the warden's remains. Choose one.")  # i18n


func is_empty() -> bool:
	return _pending.is_empty()


## How many choices wait (the one on screen not counted).
func size() -> int:
	return _pending.size()


## Takes the next offer out of the queue: the first one, or with `automatic_only` the first one
## that comes up by itself (null if none).
func pop(automatic_only: bool = false) -> Offer:
	for i in _pending.size():
		if not automatic_only or not _pending[i].on_demand:
			var offer: Offer = _pending.pop_at(i)
			changed.emit()
			return offer
	return null


## Puts `offer` back at the head of the line, waiting for the player (the choice was put off).
func put_back(offer: Offer) -> void:
	offer.on_demand = true
	_pending.push_front(offer)
	changed.emit()


func clear() -> void:
	_pending.clear()
	shown = null
	changed.emit()


## The offers to save: the one on screen first, then the waiting ones.
func to_data(include_shown: bool) -> Array:
	var data := []
	if include_shown and shown:
		data.append(shown.to_data())
	for offer in _pending:
		data.append(offer.to_data())
	return data


func load_data(data: Array) -> void:
	for entry: Variant in data:
		if entry is Dictionary:
			_pending.append(Offer.from_data(entry))
	changed.emit()


## Older runs saved rendered words. Recover the known keys in every loaded language,
## including a formatted level title, without changing the current locale.
static func _migrate_words(offer: Offer) -> void:
	for locale in TranslationServer.get_loaded_locales():
		var translation := TranslationServer.get_translation_object(locale)
		if translation == null:
			continue
		for key: String in ["A boon", "Relic", "Choose an upgrade", "Choose a relic", "The pact is kept. Choose a relic.", "The trial is done. Choose a relic.", "A relic lies in the warden's remains. Choose one."]:  # i18n
			var rendered := String(translation.get_message(key))
			if not rendered.is_empty() and offer.title == rendered:
				offer.title = key
			if not rendered.is_empty() and offer.subtitle == rendered:
				offer.subtitle = key
		var template := String(translation.get_message("Level %d!"))
		if template.is_empty():
			template = "Level %d!"  # i18n
		var parts := template.split("%d")
		if offer.level == 0 and parts.size() == 2 and offer.title.begins_with(parts[0]) and offer.title.ends_with(parts[1]):
			var number := offer.title.trim_prefix(parts[0]).trim_suffix(parts[1])
			if number.is_valid_int() and int(number) > 0:
				offer.level = int(number)
				offer.title = "Level %d!"  # i18n
