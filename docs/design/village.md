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

The Well is central, the shrine north, the market southwest and the memorial court southeast.
The Veilleuse, Sayo and Ren make three inhabitants; the Old Wanderer is the merchant. Their
positions, figures and words are resources, using the existing CC0 art. Sayo and Ren begin as
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
no offline deterioration and no penalty for failed runs. Later fronts/quests are future content.

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
- Profile owns `village_quests`, `village_services`, `village_memorials`, `ending_receipts`.
  They share its atomic file, rather than a second independently committed village file.
  No existing user file is edited by deployment. Cloud synchronization uses its existing
  explicit account/consent gates; there are no new public props, telemetry fields or requests.
  A sufficiently large lifetime register can exceed the existing cloud payload limit: cloud
  reports TOO_LARGE, local progress stays intact. Nothing silently trims memorials.

The touch stick and contextual action feed the same movement/interact input actions as keys and
controllers. Modal windows stop movement and release touch input. The shrine is reachable in the
village; options, privacy, account and records remain reachable through Menu → Title screen.

## Validation

`unit.village` checks ordered progression, failed-write rollback, one-time rewards/purchases,
old-profile migration, all memorials surviving reload and idempotent endings. `title.village`
checks the real hub, movement, conversations, root removal and saved-run protection.
`game.village` checks evidence on the real procedural floor and its absence on a daily run.
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
