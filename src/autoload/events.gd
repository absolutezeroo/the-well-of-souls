extends Node
## Global signal bus (autoload "Events").
## Gameplay code emits, UI listens: neither side needs a reference to the other.

# The bus's signals are emitted and connected by other classes, never here.
@warning_ignore_start("unused_signal")
signal message_logged(text: String, color: Color)
signal depth_changed(depth: int)
signal monster_killed(monster: Monster)
## A monster spotted the hero for the first time (its bestiary page opens).
signal monster_noticed(monster: Monster)
## A goal was reached (souls already paid).
signal achievement_unlocked(achievement: AchievementDef)
## A hunter rank reached with a kind of monster, souls paid (see Bestiary).
signal bestiary_rank_reached(monster: MonsterDef, rank: int, souls: int)
## A bestiary challenge done and paid (see HuntTracker).
signal hunt_challenge_done(monster: MonsterDef, challenge: HuntChallenge)
## A daily or weekly quest finished and paid (see QuestBoard).
signal quest_completed(quest: Dictionary)
## Something worth counting happened (opened a chest, used an encounter, found an epic...):
## stat is an AchievementDef.STAT_KEYS value.
signal stat_counted(stat: String, amount: int)
## The hero walked up to an encounter (spring, altar...).
signal encounter_requested(encounter: Encounter)
## Something (an encounter...) grants a choice of perks: rarity is PerkDef.Rarity.
signal perk_offer_requested(rarity: int, title: String, subtitle: String)
## The hero could not take `item`: the bag has no room for it (the HUD says so).
signal bag_full(item: ItemDef)
## Walking over an item that auto loot leaves on the ground (or that has no room): the HUD
## shows it with a Take button until the hero walks off (`loot_left`).
signal loot_offered(pickup: ItemPickup)
signal loot_left(pickup: ItemPickup)
## The hero walked up to the merchant.
signal shop_requested(merchant: Merchant)
## The hero walked up to the smith's forge.
signal forge_requested(forge: Forge)
## A soul set free by a kill reached the hero's lantern (see SoulWisp).
signal soul_gathered
## The souls the run is worth went up another way than a wisp (the hidden floor's hoard): the
## HUD counts them up (RunAnnouncer).
signal run_souls_changed
## Something big happened near the hero: the camera shakes (0..1, see GameCamera.shake()).
signal screen_shake(amount: float)
## A short push of the camera (pixels, along `direction`): the weight of a blow, a shot's recoil.
signal camera_kick(direction: Vector2, pixels: float)
## The player entered a boss arena and the fight began.
signal boss_started(boss: Monster)
## The boss of the floor died: the arena opens and the stairs appear.
signal boss_defeated(boss: Monster)
## A boss with a next form fell (BossDef.next_boss) and `risen` comes up in the same arena: it
## takes the fight in `seconds` (no relic, no stairs between; boss_started follows for it).
signal boss_rising(fallen: Monster, risen: Monster, seconds: float)
## The hero walked into an ambush room: the exits closed, monsters are coming.
signal ambush_started(room: AmbushRoom)
## Every wave of the ambush is dead: the exits open.
signal ambush_cleared(room: AmbushRoom)
## A cracked wall broke and a secret room opened (SecretRoom).
signal secret_found(room: Node2D)
## The hero walked up to a pact door (PactRoom): its rule, reward and cost are shown.
signal pact_requested(pact: PactRoom)
## The hero walked into a sworn pact's room: the door sealed, its rule is watched.
signal pact_started(pact: PactRoom)
## The pact's rule was broken: its cost is paid (the fight goes on).
signal pact_broken(pact: PactRoom)
## The pact's last foe fell and the door opened (`pact.outcome`: kept or broken).
signal pact_ended(pact: PactRoom)
## A room trial's step was done (a soul freed, a lantern lit): `trial.done` of `trial.total`.
signal trial_progressed(trial: RoomTrial)
## A room trial's last step was done: its reward (the Game).
signal trial_completed(trial: RoomTrial)
## A cinematic began over the frozen world (a warden's story, CinematicDirector): the HUD steps
## aside until it is finished.
signal cinematic_started
signal cinematic_finished
## The hero tapped Interact by a fragment lying on the floor (Fragment): it is read.
signal fragment_requested(fragment: Fragment)
## A fragment was found for the first time (Narrative): kept in the warden's chronicle.
signal fragment_found(fragment: FragmentDef, boss: BossDef)
## A warden fell the way one of its chronicle's deeds asks (DeedCondition): done for good.
signal deed_done(boss: BossDef, deed: DeedCondition)
## The hero bought something from the merchant (RunState.marks: "bought").
signal item_bought(item: ItemDef)
## An encounter was used (a choice made at a spring, an altar...).
signal encounter_used(encounter: Encounter)
## Something a warden's deed may ask about happened, told by whatever saw it (a monster's trait:
## "bitten", the Maw's jaw closed on the hero): kept in RunState.marks (MarkDeed).
signal run_marked(mark: String)
## A run began (new or resumed) with its hero: what follows a whole run binds to them (the
## gameplay statistics: Telemetry).
signal run_started(run: RunState, player: Player)
## The Game built a floor and put the hero on it (after depth_changed, a resumed run's too): the
## RunAnnouncer names it (the act, its twist, its goal).
signal floor_entered(world: World)
## A run picked up again found its floor laid anew (another build saved it: RunSave.floor_of()).
signal floor_laid_anew
## A floor is done in `time` of the run's clock (RunState.split()): its split, on the HUD.
signal split_timed(floor_depth: int, time: float)
## An actor lost Health to a hit (after armor and wards: `damage`, maybe 0). Who dealt it and with
## what are on the hit (HitInfo.source, via, element, cause). The gameplay statistics count it.
signal actor_damaged(actor: Actor, hit: HitInfo, damage: int)
## A hit went through an actor rolling (a dash's invulnerability): dodged.
signal hit_dodged(actor: Actor, hit: HitInfo)
## Perk (or relic) cards dealt to the player: a choice opened, or rerolled.
signal perks_offered(perks: Array)
## The player took `perk` from a choice.
signal perk_chosen(perk: PerkDef)
## The player banished `perk` for the run.
signal perk_banished(perk: PerkDef)
## The run is about to be saved (RunSave: a floor begins, quitting, the app put away): what
## follows a whole run may keep its own in it (the gameplay statistics: RunState.telemetry).
signal run_saving(run: RunState)
## The player left a run that goes on, saved (RunSave). `for_good`: quit to the title, or the app
## closed; false: the app put in the background (it may come back, or be killed there). The
## gameplay statistics tell it as an "abandoned" end (Telemetry).
signal run_left(summary: RunSummary, for_good: bool)
## A run ended, souls given: a death, or a win (a win then a death in endless mode tells it twice,
## the second time with more). What the online leaderboards need (RunSummary; Leaderboards).
signal run_ended(summary: RunSummary)
## The gameplay scene actually closed (a victory may instead continue in endless mode).
signal run_closed
## The hero chose `ending` at the bottom of the Well (after run_ended: the win was told first).
## The world counters count it (WorldStats).
signal ending_chosen(ending: EndingDef)
## Souls were offered to the Tree of Souls at the shrine (an upgrade bought): the world counters.
signal souls_offered(amount: int)
@warning_ignore_restore("unused_signal")


func log_message(text: String, color: Color = Color.WHITE) -> void:
	message_logged.emit(text, color)
