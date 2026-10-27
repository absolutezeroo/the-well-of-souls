# Kagari, between descents

Le Puits des Âmes remains an action roguelike. Kagari is a small persistent, walkable hub,
not the archived RPG campaign. F5 still opens the title (privacy, account, options and records).
**Enter Kagari** tells the introduction once, then brings the hero to the square. Resume and
Daily requests also lead here. Walk to the central Well and interact to choose/resume a descent;
difficulty, ascensions, oaths and the daily explanation retain their normal rules. A new descent
asks before replacing an existing run. Closing that question or leaving the village loses nothing.

The pause menu's **Return to village** saves the current descent; the Well can resume it at its
saved floor, with its hero and equipment. After death/victory, **Return to village** closes that
expedition and leaves no resumable finished run. The optional endless continuation is retained.
A village visit does not heal, equip or otherwise mutate a suspended dungeon hero.

## The first chapter

The Well is central, the temple north, the market southwest and the memorial court southeast.
The skills shrine is inside the temple, reached through its southern doorway.
The Veilleuse, Sayo and Ren make three inhabitants; the Old Wanderer is the merchant. Their
positions, figures and words are resources. Existing residents retain the CC0 Ninja Adventure
figures; the temple uses the user-supplied Craftpix Free Ruined Temple pack (its own license). Sayo and Ren begin as
faint echoes of sleeping villagers, consistent with [the lore](../lore.md). The player must
approach and interact; walking by never launches a run or opens a conversation automatically.

**A Hearth Without a Flame** begins at the Veilleuse:

1. Accept her request for Ren's ember-box.
2. Explore floor 2 of an ordinary descent. A free cell of a room beyond the entrance holds
   the recoverable object. It uses the normal contextual Interact action and a warm light.
3. Recover it: the lantern keeps the evidence permanently, even through death or a restart.
4. Return to the Veilleuse, via the pause menu or after the descent ends, and hand it over.
5. Ren wakes, his eastern root barricade disappears (including collision), a window lights,
   and 15 souls are awarded once. His words and the other inhabitants' reactions change.

This is an explicit accepted → evidence found → returned sequence, not an automatically paid
kill counter. The existing daily/weekly QuestBoard remains separate. The first infestation
front is authored and static until pushed back by this quest: there is no time-based spread,
no offline deterioration and no penalty for failed runs.

**The Last Verse** continues at Sayo's western house once the ember-box has been **returned**:

1. Speak to Sayo and accept her request. Finding Ren's evidence alone does not unlock it.
2. Recover her written verse on floor 4 of an ordinary descent; the lantern keeps it through
   death/restart under the same rules as the ember-box.
3. Return it to Sayo. She wakes, the western roots and their collisions disappear, her window
   lights, and 20 souls are paid once. Ren's rescue and the memorials remain intact.

The two fronts are independent: Ren's return removes only the eastern roots. Sayo stays an echo
until her own quest is returned. The HUD points to the next available quest when none is active,
then shows its search/return objective. After both rescues it acknowledges the two lit windows;
the rest of Kagari still sleeps. Further fronts and autonomous propagation are future content.

`VillageQuestDef.requires_quest` declares the predecessor, `VillageProgress.can_accept()` checks
its returned stage, and the disabled conversation choice explains the prerequisite. Gameplay
enforces this too, so an outdated panel cannot bypass it. Quests are never auto-accepted.
Existing profiles with Ren already awake can immediately accept Sayo's request. No save field
or format changes: the new id is absent/available until accepted. Failed acceptance/hand-in
leaves all progress and rewards unchanged. The next-objective and reward sentences live in data.

The Wanderer then offers two permanent restorations: **Market Lanterns** (5 souls) and
**Lights for the Nameless** (8 souls). Both are one-time purchases with visible lamps; neither
adds equipment, statistics or consumables to a run. Costs and prerequisite are in the service
resources. These are the first shop services, not a full village equipment economy.

## Memorials

Every **Take his place** ending creates a permanent memorial of that hero: level, date, full
worn equipment (including its rolled identity), skills/perks and the existing snapshot metadata.
The latest statue stands in the court. Interact with its plinth to browse every earlier memorial
with its stone appearance and equipment list. Older records are paged; only the current statue
and one register preview are rendered. There is no 20-run-history truncation of memorials.

Taking a new Keeper's place or freeing him leaves previous statues intact. Only the active
Keeper still controls the next run's bottom boss. An older profile without a memorial field
imports its current Keeper into the register in memory; the next normal save keeps it. Old
freed-Keeper codex entries lack full equipment, so their missing appearances are not fabricated.

`RunState.journey_id` is an opaque local receipt id, independent of gameplay random numbers.
New attempts (including repeated daily seeds) get distinct ids; resume keeps its id. An older
run receives a deterministic legacy identity. An ending transaction writes its profile statistic,
Keeper, memorial and receipt together. If the application stops before RunSave can clear
`ending_due`, the original choice is recovered; it cannot pay or create a memorial twice.

## Ownership and persistence

- `data/village/kagari.tres` is the hub manifest: layout/paths, props, residents, quests and services.
- `src/definitions/village/` holds typed resource schemas; no resident or quest-id branches in
  Actor, Monster or World. Add content by registering resources on the manifest.
- `VillageHub` owns surface input, modal requests and launch flow. `VillageWalker` is a peaceful
  body with the hero's existing rig; it has no RunState, combat, inventory or online run session.
- `VillageView` rebuilds dressing only on profile change. Static ground records draw commands
  only on change. The movement/interaction loops reuse their fixed registry without group scans.
- `VillagePanel` presents text and emits choices. `VillageProgress` performs the gameplay
  transactions; rejected writes leave money, quest stage and restoration flags unchanged.
- `VillageExpedition`, owned by Game, listens to `floor_entered`; it places `VillageEvidence`
  without consuming generation/combat dice. No village evidence appears in daily, hidden,
  finale or debug descents. Profile state makes reconstruction idempotent. Existing floor
  ledger/stamp and run save version remain compatible.
- Profile owns `village_quests`, `village_services`, `village_memorials`, `ending_receipts`, `village_seconds`.
  They share its atomic file, rather than a second independently committed village file.
  No existing user file is edited by deployment. Cloud synchronization uses its existing
  explicit account/consent gates; there are no new public props, telemetry fields or requests.
  A sufficiently large lifetime register can exceed the existing cloud payload limit: cloud
  reports TOO_LARGE, local progress stays intact. Nothing silently trims memorials.

The touch stick and contextual action feed the same movement/interact input actions as keys and
controllers. Modal windows stop movement and release touch input. The shrine is reachable in the
village; options, privacy, account and records remain reachable through Menu → Title screen.

## Conversations and village life

Residents have different greetings before acceptance, during the search, when the evidence is
found and after return. Optional questions have their own replies; they spend nothing and do
not advance a quest. Stage-gated reactions let the Veilleuse, Ren and the Wanderer acknowledge
Sayo's return. Completed quests no longer fill the conversation with objectives and rewards.
The dialogue keeps the practical objective separate from what the resident says.

`VillageTopicDef` holds a prompt/reply and an optional quest-stage interval. A resident's topics
are questions; its reactions use the same conditional reply without a prompt (first match).
`VillageProgress` selects the greeting and gates topics again when clicked, so an old button
cannot disclose a topic made unavailable by a profile replacement. All words, including short
ambient lines, live under `data/village/` and are translated.

`VillageResident` animates the existing idle/walk cells and follows a daily schedule of
`VillageActivityDef` appointments. Ren repairs his doorway, tends market lamps, visits the
memorial and goes home; Sayo visits the market and shrine; the Wanderer trades and visits Ren.
The Veilleuse alternates between the shrine and Well, keeping watch through the night.
Unrecovered echoes stay at their doors. People walk around static collisions using a shared
navigation grid. An appointment changes their destination without teleporting them. Scene
entry alone places residents at the current appointment after an offscreen absence.

Passing nearby no longer stops a routine. Opening any village modal pauses both routines and
time; the interaction registry follows residents' actual positions. A new approach can show
one short speech bubble, with a cooldown. Conversations use the speaker's existing voice cue.
Residents survive profile refreshes, so buying a lamp does not reset their positions.

## Day, night and the quest board

The first visit starts at 08:00. One fictional day lasts **16 minutes of active play**, authored
in `data/village/clock.tres`. Time advances in the village and during descents, stops in menus
and in the mobile background, and does not advance while the app is closed. Day number and
hour appear on the village HUD; a Gradient tints only the world at dawn, day, dusk and night.
It never changes dungeon seeds, real UTC bounty dates or infestation. There is no missed-day
penalty. `Profile.village_seconds` is optional for old saves and joins normal atomic profile
writes, including leaving the village and application close/background notifications.

The **Quests** HUD button, the physical noticeboard southwest of the Well, and **Quest journal**
in the dungeon pause menu all open the same read-only codex tab. It lists village requests,
their prerequisites/status, current search or return objective, rewards, contact and current
schedule, followed by daily/weekly bounties. Found requests come first and completed ones last.
Reading a board never accepts or pays a request: return to the resident for those actions.
Bounties continue to use real-world dates, independently of the village clock.

Ordinary night rest still hides Ren, Sayo or the Wanderer behind home/stall doors; interacting
there knocks and opens the normal conversation, so a quest or service is not time-locked.
Their actual home interiors await a residential asset pack. Kagari is an inhabited village
whose souls were taken; its houses are not a settlement of ruins to rebuild.

## The temple interior

The **Temple of the Last Flame**, north of the Well, now has a facade from the supplied
Craftpix pack and a playable interior. Approach its door and use Interact. The same peaceful
hero enters a room with stone paving, an aisle, banners, offering tables, lamps and the existing
skills shrine. Approach the altar to open the normal ShrinePanel with its unchanged prices,
prerequisites and permanent upgrades. The southern threshold returns to the matching exterior
door. Entry/exit is explicit, works with keyboard/gamepad/touch and requires a fresh action
press; holding Interact cannot bounce through the door. Modals prevent transitions.

The Veilleuse tends the shrine inside at 08:00 and 18:00, and returns to the Well at 12:00
and 22:00. Sayo visits the temple at noon after her rescue. Residents walk to each door, cross
its threshold, and walk to their appointment inside; they then retrace the exit when their
next activity is outside. The journal names their scheduled room. A purchase or profile
refresh preserves the existing walker, residents and their current rooms. Replacing progress
with an older profile returns a newly unrecovered echo to its original home doorway.

Rooms occupy separate world coordinates in the same VillageHub. There is no scene reload,
second clock, combat actor, additional profile file or RunState change. A new launch returns
to the village spawn as before; the hero's room is session state, not new saved progression.
Time continues while walking inside and freezes in menus. The room has steady warm lighting,
while outside still follows the day/night gradient. Its fixed camera shows the whole room;
2× atlas art at a 1.5× camera zoom keeps source pixels on a 3× grid. Exterior camera framing
and bounds return when leaving. A room visit never overwrites a suspended dungeon save.

`VillageInteriorDef` owns doorway/return position, world offset, camera and walk bounds,
spawn/exit, shrine interaction, light, tiles, wall collisions and props. `VillageTilePatchDef`
records repeated atlas patches; `VillageInteriorFloor` draws them only on change. The shared
`VillagePropView` renders props inside and outside. `VillageNavigation` caches one grid per
registered room, and `VillageActivityDef.room` makes an appointment's destination room-local.
Register more interiors in `VillageDef.interiors`; future houses can reuse this mechanism.

Only three original PNG atlases from the archive are used. Editable PSD/Aseprite files,
demo levels, enemies and traps are not imported. Credits and the Craftpix license reference
are in `assets/village/temple/CREDITS.txt`. The residential houses remain a separate next step.

Sayo's figure and portrait share a teal palette material, distinguishing her from the Veilleuse
without duplicating or regenerating sprite textures. Static props remain separate from these
four moving residents. Routines do not consume dungeon random numbers or alter run state.

## Validation

`unit.village` checks ordered progression, failed-write rollback, one-time rewards/purchases,
old-profile migration, all memorials surviving reload and idempotent endings. It also validates
unique quest ids and acyclic registered prerequisites, ordered acceptance, cloud holds and
failed hand-in rollback. `title.village` checks the real hub, movement, locked/unlocked Sayo
conversations, independent root removal and saved-run protection. `game.village` checks evidence
on both real procedural floors, its absence before acceptance and on a daily run, and no respawn
after collection. Calendar checks cover old saves, midnight, cloud holds, UTC independence,
all authored paths before/after restoration, a full day of real resident physics, pause/resume
in village and dungeon, night entry, read-only journal access and a cloud rollback returning
a formerly rescued resident's echo to its original doorway. Temple checks exercise real
entry/exit, shrine interaction and modal blocking, altar/wall collisions, warm lighting, the
shared clock, unchanged progression/run file and full NPC door-to-appointment journeys.
The existing finale test now checks both recovery of the same ending and the other ending on
an independent expedition, with its original achievement/keeper-release assertions retained.

For an isolated rendered review (never point this at a real user's folder):

```
XDG_DATA_HOME=/tmp/puits-village-review godot --path . --resolution 1540x720 \
  res://tools/village/review.tscn -- --locale=fr
```

The review resets only its in-memory test profile and writes screenshots under that isolated
folder's `Mini Roguelike/village_review/`. Repeat at 2340x1080 and in English. Desktop software
OpenGL captures can check layout; they do not prove touch feel, S23 performance or Windows exports.

## Conversation presentation and descent

VillagePanel uses Ninja Adventure's original nine-patch speech, portrait and reply frames,
not the ornate inventory window. The lower conversation card leaves the world visible, with
speaker/words on the left and quest details/replies on the right. Both text and replies scroll
when needed; focus follows into view for keyboard/gamepad and touch dragging never selects a
reply. Service/register cards use the same skin with more height. Other game menus retain their
normal skin. The compact layout rechecks its size after wrapped text changes its minimum.

The Well plays an authored 2.2-second sequence after the final descent confirmation: approach,
converging spirit motes, the hero swallowed by the mouth, then an opaque stepped iris into
Loader. No animation starts on proximity or while deciding whether to replace a save. A failed
profile save leaves the request retryable. Movement, village time, menus and repeated launch
requests are blocked during the sequence. The owner sets new/resumed/daily flags only on
completion; freeing the scene first cancels the sequence and preserves RunSave. The effect has
no timers or awaits that can outlive its scene. Ambient souls and restored lantern flames use
one bounded low-frequency draw node and no gameplay randomness. Reduced effects keeps four
motes and removes trails, the column and lamp flames; no screen flash or shake is added.

For direct visual editing, see the French [village editing guide](../modifier-village.md).
The tool scene previews resources without constructing VillageHub or reading Profile. Draggable
handles copy positions back only with Apply; room-local coordinates and path dimensions are
preserved. Props, home positions, appointment destinations and doors remain explicit independent
resources, so moving a facade does not silently rewrite a resident's schedule.
