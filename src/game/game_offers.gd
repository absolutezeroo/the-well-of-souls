class_name GameOffers
extends Node
## Owns the perk-choice interaction: dealing, rerolls, banishes and postponement.
## Game owns this child and the run; panel signals go directly here and die with the child.

var game: Game
var _choosing := false


## Panel subscriptions belong to this child; freeing the Game disconnects them.
func bind_panel() -> void:
	game.perk_panel.chosen.connect(_on_perk_chosen)
	game.perk_panel.reroll_requested.connect(_on_perk_reroll)
	game.perk_panel.banish_requested.connect(_on_perk_banish)
	game.perk_panel.postponed.connect(_on_perk_postponed)


func reset() -> void:
	_choosing = false


## An explicit player request may show on-demand offers; automatic rewards use show_next.
func open() -> bool:
	if game.offers.is_empty() or not game._can_open_menu() or game.is_away():
		return false
	_choosing = true
	game.tutorial.action(&"opened_offers")
	show_next()
	return game.perk_panel.visible


## on_demand waits for the player; other rewards open after the current callback finishes.
func queue(rarity: PerkDef.Rarity, count: int, title: String, subtitle: String, on_demand: bool = false, level: int = 0) -> void:
	game.offers.add(rarity, count, title, subtitle, on_demand, level)
	if not on_demand:
		# Deferred: gifts are handed out in the middle of other code.
		show_next.call_deferred()


## Show due offers without interrupting a menu, a death or a pocket-world transition.
func show_next() -> void:
	while true:
		if game.is_menu_open() or game.player == null or game.player.is_dead or game.is_away():
			return
		var offer := game.offers.pop(not _choosing)
		if offer == null:
			_choosing = false
			return
		var perks := _cards_for(offer)
		if perks.is_empty():
			continue  # everything is maxed out
		game.offers.shown = offer
		game._set_paused(true)
		game.perk_panel.open(offer.shown_title(), tr(offer.subtitle), perks, game.player.perks, game.run.rerolls, game.run.banishes)
		Events.perks_offered.emit(perks)
		return


## Keep valid saved/postponed cards, dealing only missing places without a free reroll.
func _cards_for(offer: OfferQueue.Offer) -> Array[PerkDef]:
	var cards: Array[PerkDef] = []
	for perk in offer.cards:
		if perk and not game.run.banished.has(perk) and game.player.perks.can_take(perk) and not cards.has(perk):
			cards.append(perk)
	if cards.size() < offer.count:
		cards.append_array(_pick_offer(offer.count - cards.size(), offer.rarity, cards))
	return cards


## Family weighting and floor dice stay identical to the Game's original dealing order.
func _pick_offer(count: int, rarity: PerkDef.Rarity, also_left_out: Array[PerkDef]) -> Array[PerkDef]:
	var left_out: Array[PerkDef] = game.run.banished.duplicate()
	left_out.append_array(also_left_out)
	return game.content.pick_perks(game.player.perks, count, rarity, game.world.rng, left_out, game.content.dungeon.family_bias)


func _on_perk_reroll() -> void:
	var shown := game.offers.shown
	if shown == null or game.run.rerolls <= 0:
		return
	var current := game.perk_panel.get_offered()
	var fresh := _pick_offer(current.size(), shown.rarity, current)
	if fresh.is_empty():
		Events.log_message(tr("Nothing else to offer."), Palette.DANGER)
		return
	game.run.rerolls -= 1
	game.perk_panel.set_charges(game.run.rerolls, game.run.banishes)
	game.perk_panel.show_cards(fresh)
	Events.perks_offered.emit(fresh)
	Sfx.play_ui(Sfx.bank.ui_open)


func _on_perk_banish(index: int) -> void:
	var shown := game.offers.shown
	var current := game.perk_panel.get_offered()
	if shown == null or game.run.banishes <= 0 or index < 0 or index >= current.size():
		return
	var gone := current[index]
	game.run.banishes -= 1
	game.run.banished.append(gone)
	Events.log_message(tr("%s is banished for this run.") % tr(gone.display_name), Palette.DANGER)
	Events.perk_banished.emit(gone)
	var cards: Array[PerkDef] = current.duplicate()
	var replacement := _pick_offer(1, shown.rarity, current)
	if replacement.is_empty():
		cards.remove_at(index)
	else:
		cards[index] = replacement[0]
	game.perk_panel.set_charges(game.run.rerolls, game.run.banishes)
	if cards.is_empty():
		game.perk_panel.hide()
		game.offers.shown = null
		game._on_menu_closed()
		return
	game.perk_panel.show_cards(cards)


func _on_perk_postponed() -> void:
	var shown := game.offers.shown
	game.offers.shown = null
	_choosing = false
	if shown:
		shown.cards = game.perk_panel.get_offered().duplicate()
		game.offers.put_back(shown)
	game._on_menu_closed()


func _on_perk_chosen(perk: PerkDef) -> void:
	game.offers.shown = null
	game.player.perks.add(perk)
	Events.perk_chosen.emit(perk)
	Events.log_message(tr("%s (level %d)") % [tr(perk.display_name), game.player.perks.stacks_of(perk)], perk.color)
	Vfx.sparkles(game.world, game.player.global_position, perk.color)
	game.tutorial.cue(&"perk_chosen")
	game._on_menu_closed()
