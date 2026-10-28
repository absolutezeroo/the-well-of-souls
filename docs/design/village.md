# Kagari, between descents

Le Puits des Âmes remains an action roguelike. Kagari is a small persistent, walkable hub,
not the archived RPG campaign. F5 still opens the title (privacy, account, options and records).
The very first Play (**Descend**: a profile with no run, none saved) tells the introduction, then
goes straight down the Well (see "The first return" below). Afterwards **Enter Kagari** brings
the hero to the square (the introduction first, if it was never told). Resume and
Daily requests also lead here. Walk to the central Well and interact to choose/resume a descent;
difficulty, ascensions, oaths and the daily explanation retain their normal rules. A new descent
asks before replacing an existing run. Closing that question or leaving the village loses nothing.

The pause menu's **Return to village** saves the current descent; the Well can resume it at its
saved floor, with its hero and equipment. After death/victory, **Return to village** closes that
expedition and leaves no resumable finished run. After a death, **Descend again** starts the next
descent at once, as the Well would (its difficulty, ascension and oath), without the walk back. The optional endless continuation is retained.
A village visit does not heal, equip or otherwise mutate a suspended dungeon hero.

## The first return

Decision 0010: a new player's first minutes are a fight, not a village. The first descent starts
from the title, after the privacy questions and the (skippable) story, on floor 1 at Keeper, with
no Kagari, Well cinematic, difficulty or oath before it. Kagari, the Vigil-Keeper and the choices
come at the first return: the death screen opens on her first-death line (`vigil_tale`,
`first_death`: "There you are, child. I never sleep: I was waiting for you."), and **Return to
village** brings the hero to the square for the first time. Nothing there assumed an earlier
visit: the HUD's objective is the first quest's offer ("Find the Vigil-Keeper at the Well or in
the temple."), her greeting ("There you are, child. Ren will not wake...") follows her line on the
death screen, the ember-box was never laid on floor 2 (no quest accepted yet: VillageExpedition
lays evidence only for an accepted one), and the Well offers the difficulty and oath choices from
then on. A first run left from the pause menu, or won, returns the same way.

## The first chapter

The Well is central, the temple north, the market southwest and the memorial court southeast.
The skills shrine is inside the temple, reached through its southern doorway.
The Veilleuse, Sayo, Ren and Gen make four inhabitants; the Old Wanderer is the merchant. Their
positions, figures and words are resources. Existing residents retain the CC0 Ninja Adventure
figures; the temple, the houses and the shop come from the pack's TilesetHouse. Sayo and Ren begin as
faint echoes of sleeping villagers, as Gen does, consistent with [the lore](../lore.md). The player must
approach and interact; walking by never launches a run or opens a conversation automatically.

**A Hearth Without a Flame** begins at the Veilleuse:

1. Accept her request for Ren's ember-box.
2. Explore floor 2 of an ordinary descent. A free cell of a room beyond the entrance holds
   the recoverable object. It uses the normal contextual Interact action and a warm light.
3. Recover it: the lantern keeps the evidence permanently, even through death or a restart.
4. Return to the Veilleuse, via the pause menu or after the descent ends, and hand it over.
5. Ren wakes, his eastern root barricade disappears (including collision), his house wakes
   from its moss and its workshop opens ("The homes"), and 15 souls are awarded once. His words and the other inhabitants' reactions change.

This is an explicit accepted → evidence found → returned sequence, not an automatically paid
kill counter. The existing daily/weekly QuestBoard remains separate. The first infestation
front is authored and static until pushed back by this quest: there is no time-based spread,
no offline deterioration and no penalty for failed runs.

**The Last Verse** continues at Sayo's western house once the ember-box has been **returned**:

1. Speak to Sayo and accept her request. Finding Ren's evidence alone does not unlock it.
2. Recover her written verse on floor 4 of an ordinary descent; the lantern keeps it through
   death/restart under the same rules as the ember-box.
3. Return it to Sayo. She wakes, the western roots and their collisions disappear, her house
   wakes and opens, and 20 souls are paid once. Ren's rescue and the memorials remain intact.

**Seeds of Mourning** continues at Gen's cottage on the southern lane once Sayo's verse has
been **returned** (task_377):

1. Speak to Gen's echo at his door and accept his request (Sayo, awake, asks the hero to listen
   at the southern lane; before her return the choice is disabled with its prerequisite).
2. Recover his seed pouch on floor 5 of an ordinary descent (Act II, the Ossuary, where he laid
   his white flowers in the first niches); the lantern keeps it under the same rules.
3. Return it to Gen. He wakes, the southern roots and their collision go, the shut door of his
   cottage opens, his white rows flower before the vegetable beds, and 25 souls are paid once.

The chain's rewards grow with the floor they send the hero to: 15 souls (floor 2), 20 (floor 4),
25 (floor 5), each once; `unit.village` checks every request waits for the one before, lies
deeper and pays in line (30 at most). A garden that paid souls every day was considered and
refused ([decision 0013](../decisions/0013-kagari-pays-once.md)): souls are Kagari's people
brought back, and a garden cannot grow them; the reward of the place is the place.

The three fronts are independent: each return removes only its own roots. A sleeper stays an
echo until their own quest is returned. **The Well's roots creep** from the Well's square toward
each sleeping home, through the grass at the edge of the street and toward the southern lane:
the pack's flat root decals (TilesetFloorDetail), drawn with the ground under everything that
walks (`VillagePropDef.flat`), never solid. Each trail withers with its sleeper's rescue, so the
square around the Well clears as Kagari wakes. The HUD points to the next available quest when
none is active, then shows its search/return objective. After the three rescues it says three
homes are awake again; the rest of Kagari still sleeps. Further fronts and autonomous
propagation are future content.

`VillageQuestDef.requires_quest` declares the predecessor, `VillageProgress.can_accept()` checks
its returned stage, and the disabled conversation choice explains the prerequisite. Gameplay
enforces this too, so an outdated panel cannot bypass it. Quests are never auto-accepted.
Existing profiles with Ren already awake can immediately accept Sayo's request. No save field
or format changes: the new id is absent/available until accepted. Failed acceptance/hand-in
leaves all progress and rewards unchanged. The next-objective and reward sentences live in data.

The Wanderer then offers permanent restorations: **Market Lanterns** (5 souls) and **Lights for
the Nameless** (8 souls) once Ren wakes, **Lanterns of the Lane** (10 souls, the two stone
lanterns at the southern lane's ends) once Gen wakes. Each is a one-time purchase with visible
lamps; none adds equipment, statistics or consumables to a run. Costs and prerequisite are in
the service resources. These are shop services, not a village equipment economy.

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
  only on change. `VillageGround` (shared with the layout editor) draws it from the manifest:
  Ninja Adventure grass with stable per-cell variants, dirt paths autotiled from the union of
  `paths` (edges and inner corners), and flowers kept off props, the Well, board and memorial.
  Every pick is a hash of the cell, so the square never changes between visits. The movement/interaction loops reuse their fixed registry without group scans.
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
Sayo's return, and every neighbour has a word for Gen's. Completed quests no longer fill the
conversation with objectives and rewards.
The dialogue keeps the practical objective separate from what the resident says.

`VillageTopicDef` holds a prompt/reply, an optional quest-stage interval and an optional
`after_quest` that must also be returned (Sayo asks the hero to listen at the southern lane only
once she is awake herself, and until Gen wakes). A resident's topics
are questions; its reactions use the same conditional reply without a prompt (first match).
`VillageProgress` selects the greeting and gates topics again when clicked, so an old button
cannot disclose a topic made unavailable by a profile replacement. All words, including short
ambient lines, live under `data/village/` and are translated.

`VillageResident` animates the existing idle/walk cells and follows a daily schedule of
`VillageActivityDef` appointments. Ren repairs his doorway, tends market lamps, visits the
memorial and goes home; Sayo visits the market and shrine; the Wanderer trades and visits Ren;
Gen tends his garden morning and afternoon, lays flowers at the memorial court mid-morning, sits
by his door at dusk and rests behind it at night (his cottage has no room yet).
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
in `data/village/clock.tres`. Time advances in the village and during descents, stops in menus (the end screen after a death too)
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

A woken Sayo and Ren rest inside their own homes ("The homes" below), where the hero can find
them at night. The Wanderer still rests behind his stall's door and Gen behind his cottage's;
interacting there knocks and
opens the normal conversation, so a quest or service is not time-locked. Kagari is an inhabited
village whose souls were taken; its houses are not a settlement of ruins to rebuild.

## The layout of Kagari

The square (1440x960) reads as a village, not as props dropped on grass. One avenue runs from
the open south edge, where the hero arrives, past the Well to the temple; one street crosses it
at the Well's square. Every place stands where its use puts it:

- **North, the sacred quarter:** the red-roofed temple at the avenue's end, a torii between it
  and the Well, a grove of pines behind it.
- **Centre, the Well's square:** the Well (the descent), the notice board at the square's
  corner, the Keeper's watch beside it, the return spawn just south of it.
- **West, the market:** the stall and the green shop face one small square at the street's end,
  crates and barrels by the shop, the two market lamps at its corners.
- **East, the memorial court:** the Keepers' statues, flowers laid before them, stones at the
  corners, the two memorial lamps.
- **North-west and north-east, the sleeping homes:** Sayo's and Ren's houses, each at the end of
  its own lane from the street. The Well's roots smother each house on both sides (never across
  its lane, so the echo at the door can still be reached), and the house itself stands overgrown:
  the pack's own moss-covered twin from TilesetVillageAbandoned. Returning the quest clears the
  roots and wakes the house: the same house from TilesetHouse takes its place (`shown_after`),
  its door at the lane's end, and it opens. Sayo's washing line and Ren's hay sit beside them.
- **South, the lane of cottages:** Gen's cottage with its vegetable rows (his hens in them) and
  the woodcutter's hut with its woodpile (his dog at the door), joined by a lane across the
  avenue, a stone lantern at each of its ends. While Gen sleeps, the Well's roots grip the
  cottage's west wall and roof and its door is shut (the pack's own door piece over the doorway).
- **The forest ring** closes the clearing on every side but the south.

Residents' homes, stall and lamp appointments are the doors and lamps of those places. The
layout lives in `data/village/kagari.tres` (and the residents' files); the layout editor
moves it by hand.

## Placement rules

Binding for any change to Kagari's layout, by hand, in the layout editor or by an agent (the
numbers are starting values chosen by the owner, see [the art bible](../art-bible.md)). One tile
is 32 world units; the S23 shows about 24 x 11 tiles of the village at once, so the village is
laid out in width, not height.

- **Districts first, then roads, then props.** Every district has a written purpose (above);
  moving a landmark or a district is the owner's decision.
- **The Well is the dominant landmark**, seen from the spawn; each district has one secondary
  landmark (torii, market awning, memorial, each sleeping house).
- **Roads go where people go.** The avenue and the street are 2-3 tiles wide, lanes 1-2. Every
  door has a road at its step; every road ends at a door, a service, a square or a junction.
  Points of interest stand 6 to 12 tiles apart.
- **Every prop has an owner** (a building, a resident, a district's function) within about 3
  tiles: crates by the shop, a washing line by Sayo's house, hay by Ren's, a woodpile by the
  woodcutter's hut. A prop without an owner is removed, not moved.
- **Props come in small groups** of 3 to 5 around one larger anchor, set against a wall, a fence,
  a road's edge or the forest; never alone in the middle of a road or a square.
- **Solid props never stand on a road** (a square may hold a stall and its crates); **nothing
  solid crowds a door, a home or the spawn**; a passage between two solid things is at least 2
  tiles wide so the touch stick never catches.
- **The forest closes the clearing**; no void is visible at the camera's limits.
- **The hub is calmer than the floors**: fewer props, more open ground. Empty is fixed with a
  purpose (a plot waiting for a resident, an unlit lamp), never with random filler.
- **Pack art only, whole scales, even positions, no tint** ([art bible](../art-bible.md),
  [decision 0009](../decisions/0009-world-tints.md)). A darker or other-coloured look is the
  pack's own piece or a recolour on its ramps, never a multiply: the Well's roots are the pack's
  dead trees in their own colours (gnarled dead wood smothering the sleeping houses), an unlit
  lamp is the pack's empty stone lantern (`VillagePropDef.unlit`, TilesetDungeon), the Well is
  the pack's well recoloured onto the grey stone of the pack's grey statues (`assets/props/well.png`).

- **Animated decor and animals are props too**: an owner, no tint, whole scales, even positions;
  an animal's home lies within about 3 tiles of its owner and it wanders a box of at most 3 tiles
  each way around it ("Ambient life" below).

**Checked** by `VillageTests._test_layout_rules` (unit.village): every service, home, appointment,
animal's place and door walkable from the spawn; animated props and animals stepping the pack's
whole frames inside their sheets; every animal's place inside the clearing and small; no solid prop on a road (paths 3 tiles wide or less) or
crowding a door, home or the spawn; a path at each interior door; whole art scales; the ground
and room floors never tinted; no prop tinted, every prop on even units, unlit lamps on their own
piece (and `title.village`: the Well untinted). The rest is checked by looking: `python3 tools/design/capture.py`
(the `village_map` shot shows the whole square).

## Ambient life

Kagari's people sleep; its flags, flowers and beasts do not. Small, cheap movements make the
square read as a place that waits, not a picture:

- **Animated decor** is the pack's own frames (`Backgrounds/Animated`), stepped whole by
  `VillagePropDef.frames` and `frame_time` like any prop: two red flags at the temple's front
  corners, the Wanderer's blue pennant at his stall (the blue of his shutters in the Sandchoked
  City), and the two white flowers laid before the Keepers' statues swaying. Neighbouring flags
  start at a phase taken from their position, so they never wave in step. `VillagePropView` sets
  a frame's region only when the frame changes, and only on screen.
- **Animals** (`VillageAnimalDef` in `VillageDef.animals`, drawn by `VillageAnimal`): two hens in
  the cottage's vegetable rows, the market cat by the Wanderer's stall, the woodcutter's dog
  waiting at his hut's door. Each belongs to a place as a prop to its owner: a home, and a box
  around it (`roam`) where it wanders. It waits a few seconds (`pause`), walks to a spot of its box
  on the village navigation, around the static collisions, and waits again. Outside its hours
  (`wakes_at`/`sleeps_at`: the hens 6 to 20, the dog 7 to 19, the cat at all hours) it walks home
  and stays. Animals have no conversation and do not block the hero, as residents do not; they
  stand still while a village window is open and survive profile refreshes. Each draws from its
  own seeded generator, never the dungeon's dice. `title.village` checks them wandering inside
  their place, stopping under a window and going home at night.

## The temple interior

The **Temple of the Last Flame**, north of the Well, is a red-roofed shrine house from
Ninja Adventure's TilesetHouse, a torii on the path from the Well, and a playable interior. Approach its door and use Interact. The same peaceful
hero enters a room with dark wooden boards, a golden aisle, red banners, seated stone monks,
pillars and the existing skills shrine (Ninja Adventure interior floor, simple walls and house
props). Approach the altar to open the normal ShrinePanel with its unchanged prices,
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
while outside still follows the day/night gradient. Its fixed camera shows the whole room.
Both cameras are designed at 1280×720 (the surface at zoom 2, the temple at 1.5) and, like a
floor's, made whole on every screen ([decision 0007](../decisions/0007-whole-pixels-on-screen.md),
`PixelGrid.camera_zoom()`): an art pixel is a whole number of screen pixels, the framing rounded
down to the wider view. The surface shows 6 screen pixels per art pixel at 1080 lines (4 at 720,
5 at 1600×900); the temple 4 at 1080 (3 at 720 and 1600×900), as the dungeon. A smaller interface
size never changes the framing. A room's `bounds` (its dark backdrop and the camera's limits) is
wider than its walls so the widest common view never leaves it (the temple's 1280 units: the
S23 sees 1170, a 21:9 1080p screen 1280) and never reaches the village beside it
(`PcTests._test_temple_framing()`). Exterior camera framing and bounds return when leaving. A room visit never overwrites a suspended dungeon save.

`VillageInteriorDef` owns doorway/return position, world offset, camera and walk bounds,
spawn/exit, shrine interaction, light, tiles, wall collisions and props. `VillageTilePatchDef`
records repeated atlas patches; `VillageInteriorFloor` draws them only on change. The shared
`VillagePropView` renders props inside and outside. `VillageNavigation` caches one grid per
registered room, and `VillageActivityDef.room` makes an appointment's destination room-local.
Register more interiors in `VillageDef.interiors`; the homes below reuse this mechanism.

All of Kagari is Ninja Adventure art (CC0, assets/LICENSE_NinjaAdventure.txt): TilesetHouse
(assets/tiles/house.png) for the temple, the houses and the shop, TilesetInteriorFloor and
TilesetWallSimple for the rooms, the pack's furniture, beds (tileset_bed) and camp pieces
(tileset_camp) inside the homes. The Craftpix temple used before clashed with that style and was
removed.

## The homes

Sayo's house and Ren's workshop (`data/village/sayo_home.tres`, `ren_home.tres`) open when their
resident wakes (`VillageInteriorDef.opens_after`: until that quest is returned the overgrown
facade stands, its door is no interaction and `VillageHub.enter_room()` refuses it). Each is a
small room at its own world offset, entered and left like the temple: the same hero, clock and
profile, a steady warm light, a fixed camera at the surface's zoom (2, made whole by
`PixelGrid.camera_zoom()`), the room filling a 1280x720 view.

- **The shell** is the pack's room frame (TilesetWallSimple's 9-slice: corners, edges, the
  capped pieces either side of the doorway), a wooden back wall from TilesetHouse, a floor of
  TilesetInteriorFloor: light boards for Sayo, the dark stone of a lantern-mender's workshop for
  Ren, in a stone frame like the temple's. Furniture stands against the walls and leaves the
  middle free; the threshold is a floor tile in the frame's gap.
- **Sayo's house**: her bed (blue, her colour), a paper lantern Ren made her, drawers, the
  shelves of her songs, the low table where she writes on a straw mat, two stools, a plant.
- **Ren's workshop**: a tool chest, shelves, two hanging lanterns, the workbench with paper
  lanterns waiting for wicks, oil barrels and crates by the door, his bed in the far corner.
- **Who is inside, when**: Sayo rests at home at night and welcomes neighbours inside from 16:00;
  Ren mends lanterns at his workbench in the early morning and at noon, and rests at home at
  night. Their appointments carry `room`, so they walk to their door, cross it and walk to their
  place inside, as in the temple. At night the hero finds them inside, awake enough to talk.

Doors stand below each facade's clearance (`unit.village`: every door walkable from the spawn,
with a path at its step, nothing solid crowding it). `title.village` checks a sleeping home
cannot be entered, then, once woken, the facades swap with their collisions, the door is a real
interaction, the room has its own bounds and light, and the threshold returns the hero to the
house's own door. `tools/design/capture.py` shoots each home (`homes`) and the woken square
(`village_woken`).

Sayo's figure and portrait share a teal palette material, distinguishing her from the Veilleuse
without duplicating or regenerating sprite textures; Gen wears the pack's old gardener in his
straw hat (OldMan3). Static props remain separate from these five moving residents and the four
animals. Routines do not consume dungeon random numbers or alter run state.

## Validation

`unit.village` checks ordered progression, failed-write rollback, one-time rewards/purchases,
old-profile migration, all memorials surviving reload and idempotent endings. It also validates
unique quest ids and acyclic registered prerequisites, ordered acceptance, cloud holds and
failed hand-in rollback. `title.village` checks the real hub, movement, locked/unlocked Sayo
and Gen conversations, independent root removal (Gen's with the Well's roots toward him and his
shut door) and saved-run protection. `game.village` checks evidence
on the three real procedural floors (2, 4, 5), its absence before acceptance and on a daily run, and no respawn
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

VillagePanel wears the game's own skin, like every window and the DialogueBox: the wooden
OrnateBoard with its gold border, the speaker's name in gold, the face on a plaque, the words
in a dark inset and the shared wood buttons (the white Ninja Adventure dialogue frames clashed
with the rest of the interface and were removed). The lower conversation card leaves the world visible, with
speaker/words on the left and quest details/replies on the right. Both text and replies scroll
when needed; focus follows into view for keyboard/gamepad and touch dragging never selects a
reply. Service/register cards use the same skin with more height. The compact layout rechecks its size after wrapped text changes its minimum.

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
